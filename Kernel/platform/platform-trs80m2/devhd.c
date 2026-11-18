/*
 *	WD1010 hard disk driver
 *
 *	The Tandy 8MB (and compatible) hard disk for the Model II/12/16 uses
 *	the same WD1010 register layout at 0xC0-0xCF as the Model 4 drives.
 */

#define _HD_PRIVATE
#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devhd.h>
#include <diskgeom.h>

/* Used by the asm helpers */
uint8_t hd_page;

/* Swap is scanned for so not constant */
uint16_t swap_dev;

/* Seek and restore low 4 bits are the step rate, read/write support
   multi-sector mode but not all emulators do .. */

struct minipart parts[MAX_HD];

/* Wait for the drive to show ready */
uint8_t hd_waitready(void)
{
	uint8_t st;
	do {
		st = in(HD_STATUS);
	} while (!(st & 0x40));
	return st;
}

/* Wait for DRQ or an error */
uint8_t hd_waitdrq(void)
{
	uint8_t st;
	do {
		st = in(HD_STATUS);
	} while (!(st & 0x09));
	return st;
}

uint8_t hd_xfer(bool is_read, uint8_t *dptr)
{
	/* Error ? */
	if (in(HD_STATUS) & 0x01)
		return in(HD_STATUS);
	if (is_read)
		hd_xfer_in(dptr);
	else
		hd_xfer_out(dptr);
	/* After the data the controller is busy until the command is done:
	   a write goes to the disk (a FreHD writes its SD card) only now.
	   The other status bits mean nothing while it is busy. */
	while (in(HD_STATUS) & 0x80);
	/* Should be returning READY, and maybe SEEKDONE */
	return in(HD_STATUS);
}

/*
 *	The Model II drives use 512 byte sectors. The number per track comes
 *	from the label (which counts 256 byte units, so it is halved here);
 *	trs80gp uses 32 per track. Depending on how the drive was formatted
 *	the sectors are numbered from 0 or from 1; hd_probe() finds out.
 */
uint8_t hd_secbase;

int hd_transfer(uint_fast8_t minor, bool is_read, uint_fast8_t rawflag)
{
	uint16_t ct = 0;
	staticfast uint8_t tries;
	uint8_t err = 0;
	uint8_t cmd = HDCMD_READ;
	uint8_t head;
	uint8_t sector;
	staticfast uint16_t cyl;
	uint8_t dev = minor >> 4;
	uint8_t *dptr;
	uint16_t nblock;
	uint8_t spt;

	staticfast struct minipart *p;

	p = &parts[dev];
	spt = p->g.sec >> 1;

	hd_page = 0;
	if (rawflag == 1) {
		if (d_blkoff(BLKSHIFT))
			return -1;
		hd_page = udata.u_page;		/* User space */
	} else if (rawflag == 2)
		hd_page = swappage;

	if (!is_read)
		cmd = HDCMD_WRITE;

	out(HD_PRECOMP, p->g.precomp);
	out(HD_SECCNT, 1);

	/* One 512 byte Fuzix block is one sector */
	sector = udata.u_block % spt;
	cyl = udata.u_block / spt;

	/* Do the maths once and on 16 bit numbers */
	head = cyl % p->g.head;
	cyl /= p->g.head;
	if (minor & 0x0F)
		cyl += p->cyl[(minor - 1) & 0x0F];

	dptr = udata.u_dptr;
	nblock = udata.u_nblock;

	/* Here be dragons. In the swap case we will load over udata so we
	   must cache everything we needed from udata before we load data */

	while (ct < nblock) {
		/* Head next bits, plus drive and sector size */
		out(HD_SDH, HDSDH_ECC | HDSDH_512 | head | (dev << 3));
		out(HD_SECNUM, sector + hd_secbase);
		/* cylinder bits */
		out(HD_CYLLO, cyl & 0xFF);
		out(HD_CYLHI, cyl >> 8);

		for (tries = 0; tries < 4; tries++) {
			/* issue the command */
			out(HD_CMD, cmd);
			/* DRQ will go high once the controller is ready
			   for us */
			err = hd_waitdrq();
			if (!(err & 1)) {
				err = hd_xfer(is_read, dptr);
				/* Ready, no error ? */
				if ((err & 0x41) == 0x40)
					break;
			} else
				kprintf("hd%d: err %x\n", minor, err);

			if (tries > 1) {
				out(HD_CMD, HDCMD_RESTORE | p->g.seek);
				if (hd_waitready() & 1)
					kprintf("hd%d: restore error %x\n", minor, err);
			}
		}
		if (tries == 4)
			goto bad;
		ct++;
		dptr += 512;
		sector++;
		/* Cheaper than division! */
		if (sector == spt) {
			sector = 0;
			head++;
			if (head == p->g.head) {
				head = 0;
				cyl++;
			}
		}
	}
	return ct << 9;
bad:
	if (err & 1)
		kprintf("hd%d: error %x\n", minor, in(HD_ERR));
	else
		kprintf("hd%d: status %x\n", minor, err);
bad2:
	udata.u_error = EIO;
	return -1;
}

int hd_open(uint_fast8_t minor, uint16_t flag)
{
	uint8_t dev = minor >> 4;
	flag;
	if (dev >= MAX_HD || parts[dev].g.head == 0 ||
		(minor && parts[dev].cyl[(minor-1)&0x0F] == 0xFFFF)) {
		udata.u_error = ENODEV;
		return -1;
	}
	return 0;
}

int hd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	flag;
	return hd_transfer(minor, true, rawflag);
}

int hd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	flag;
	return hd_transfer(minor, false, rawflag);
}

