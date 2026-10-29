/*
 *	TRS-80 Model II floppy disk driver (FD1791 and Z80 DMA)
 *
 *	The drives are 8" 77 cylinder drives. Cylinder 0 side 0 is the
 *	single density boot track (26 x 128 bytes) that the boot ROM reads,
 *	so the Fuzix device starts at cylinder 1. Every other track is
 *	double density, 26 sectors of 256 bytes (IBM 2D layout). Double
 *	sided media is detected from the drive and the second side follows
 *	the first on each cylinder.
 *
 *	Ports
 *	E0	PIO A: bit 0 FDC interrupt, bit 1 two sided media,
 *		bit 2 disk changed, bits 4-7 printer status
 *	E4-E7	FD1791 command/status, track, sector, data
 *	EF	Drive select latch: bits 0-3 select (active low),
 *		bit 6 0 = side 1, bit 7 1 = MFM
 *
 *	TODO
 *	- Formatting (needs a write track helper)
 *	- Single density data tracks for reading old media
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devfd.h>

__sfr __at 0xE0 fd_pio;
__sfr __at 0xE4 fd_status;
__sfr __at 0xE4 fd_cmdreg;
__sfr __at 0xE5 fd_track;
__sfr __at 0xE6 fd_sector;
__sfr __at 0xE7 fd_data;
__sfr __at 0xEF fd_select;

#define MAX_FD		4

#define FD_SECTORS	26
#define FD_CYLS		77
#define FD_FIRSTCYL	1

#define STEP_RATE	0x02	/* 10ms at 2MHz, good for SA800 class drives */

#define CMD_RESTORE	(0x08 | STEP_RATE)	/* load head */
#define CMD_SEEK	(0x1C | STEP_RATE)	/* load head, verify */
#define CMD_READ	0x80
#define CMD_WRITE	0xA0
#define CMD_SETTLE	0x04			/* 15ms head settle */
#define CMD_FORCE	0xD0

#define ST_NOTREADY	0x80
#define ST_WPROT	0x40
#define ST_RNF		0x10
#define ST_SEEKERR	0x10
#define ST_CRC		0x08
#define ST_LOST		0x04
#define ST_BUSY		0x01

/* Used by the DMA helper */
uint8_t fd_page;
uint8_t fd_wr;
uint8_t *fd_addr;
uint16_t fd_len;

static uint8_t curtrack[MAX_FD] = { 0xFF, 0xFF, 0xFF, 0xFF };
static uint8_t sides[MAX_FD];
static uint8_t lastdrive = 0xFF;

/* Wait for a type 1 command to finish */
static uint8_t fd_wait(void)
{
	uint16_t n = 0;
	uint8_t outer = 4;	/* A restore across 77 cylinders takes ~0.8s */
	uint8_t st;
	/* Give the FDC time to go busy */
	for (n = 0; n < 20; n++)
		st = fd_status;
	n = 0;
	do {
		do {
			st = fd_status;
			if (!(st & ST_BUSY))
				return st;
		} while (--n);
	} while (--outer);
	fd_cmdreg = CMD_FORCE;
	return 0xFF;
}

static void fd_selectdrive(uint8_t drive, uint8_t side)
{
	uint8_t r = 0x80 | (0x0F & ~(1 << drive));
	if (side == 0)
		r |= 0x40;
	fd_select = r;
	if (drive != lastdrive) {
		/* The FDC only has one track register */
		fd_track = curtrack[drive];
		lastdrive = drive;
	}
}

static uint8_t fd_restore(uint8_t drive)
{
	uint8_t st;
	fd_selectdrive(drive, 0);
	fd_cmdreg = CMD_RESTORE;
	st = fd_wait();
	if (st & (ST_NOTREADY | ST_SEEKERR | ST_BUSY))
		curtrack[drive] = 0xFF;
	else
		curtrack[drive] = 0;
	return st;
}

static uint8_t fd_seek(uint8_t drive, uint8_t cyl)
{
	uint8_t st;
	if (curtrack[drive] == cyl)
		return 0;
	if (curtrack[drive] == 0xFF) {
		st = fd_restore(drive);
		if (curtrack[drive] == 0xFF)
			return st | ST_SEEKERR;
	}
	fd_data = cyl;
	fd_cmdreg = CMD_SEEK;
	st = fd_wait();
	if (st & (ST_NOTREADY | ST_SEEKERR | ST_CRC | ST_BUSY)) {
		curtrack[drive] = 0xFF;
		return st | ST_SEEKERR;
	}
	curtrack[drive] = cyl;
	return 0;
}

static int fd_transfer(uint8_t minor, bool is_read, uint8_t rawflag)
{
	uint8_t drive = minor & 3;
	uint16_t lsec;
	uint16_t nsec;
	uint16_t spc;
	uint8_t cyl, side, sec;
	uint8_t tries;
	uint8_t st = 0;
	uint8_t cmd;
	uint8_t settle = CMD_SETTLE;
	uint16_t done = 0;
	irqflags_t irq;

	fd_page = 0;
	if (rawflag == 1) {
		if (d_blkoff(BLKSHIFT))
			return -1;
		fd_page = udata.u_page;
	} else if (rawflag == 2)
		fd_page = swappage;

	fd_addr = udata.u_dptr;
	fd_len = 256;
	fd_wr = !is_read;

	/* Work in 256 byte physical sectors */
	lsec = udata.u_block << 1;
	nsec = udata.u_nblock << 1;
	spc = FD_SECTORS * sides[drive];

	while (done < nsec) {
		cyl = FD_FIRSTCYL + lsec / spc;
		sec = lsec % spc;
		side = 0;
		if (sec >= FD_SECTORS) {
			side = 1;
			sec -= FD_SECTORS;
		}
		if (cyl >= FD_CYLS)
			goto bad;

		for (tries = 0; tries < 5; tries++) {
			if (tries == 3)
				fd_restore(drive);
			fd_selectdrive(drive, side);
			st = fd_seek(drive, cyl);
			if (st)
				continue;
			fd_sector = sec + 1;
			cmd = (is_read ? CMD_READ : CMD_WRITE) | settle;
			/* The DMA follows whatever page is mapped so nothing
			   may remap while it runs */
			irq = di();
			st = fd_dma(cmd);
			irqrestore(irq);
			settle = 0;
			if (!(st & (is_read ? 0x9D : 0xFD)))
				break;
			settle = CMD_SETTLE;
		}
		if (tries == 5)
			goto bad;
		fd_addr += 256;
		lsec++;
		done++;
	}
	return done << 8;
bad:
	kprintf("fd%d: error %x\n", drive, st);
	udata.u_error = (st & ST_WPROT) ? EROFS : EIO;
	return -1;
}

int fd_open(uint8_t minor, uint16_t flag)
{
	uint8_t drive = minor & 3;
	used(flag);
	if (minor >= MAX_FD) {
		udata.u_error = ENODEV;
		return -1;
	}
	fd_selectdrive(drive, 0);
	if (fd_restore(drive) & (ST_NOTREADY | ST_BUSY)) {
		udata.u_error = ENXIO;
		return -1;
	}
	/* PIO bit 1 reports two sided media in the selected drive */
	sides[drive] = (fd_pio & 0x02) ? 2 : 1;
	return 0;
}

int fd_read(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
	used(flag);
	return fd_transfer(minor, true, rawflag);
}

int fd_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
	used(flag);
	return fd_transfer(minor, false, rawflag);
}
