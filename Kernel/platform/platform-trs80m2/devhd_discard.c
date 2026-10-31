#define _HD_PRIVATE
#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devhd.h>
#include <diskgeom.h>

/*
 *	Mini part processing. This and mbr and other things all one day
 *	need to become a bit more unified.
 */
static void hd_swapon(struct minipart *p, unsigned int d, unsigned int i)
{
	uint16_t cyls;
	if (i == 14 || p->cyl[i+1] == 0xFFFF)
		cyls = p->g.cyl;
	else
		cyls = p->cyl[i+1];
	cyls -= p->cyl[i];
	cyls *= p->g.head;
	/* This is now the number of tracks in swap, each g.sec * 256 bytes.
	   We need 32K per process: hardwire it here - FIX if you change the
	   mapping model */
	cyls = (cyls * p->g.sec) / 128;

	swap_dev = (d << 4) + i + 1;

	if (cyls >= MAX_SWAPS)
		cyls = MAX_SWAPS - 1;
	for (i = 0; i < cyls; i++) {
		swapmap_init(i);
	}
	kputs("swap-");
}

void hd_probe(void)
{
	unsigned int dev = 0;
	unsigned int i;
	/* Second half of second block */
	struct minipart *p;

	/* Reset the host adapter and enable the controller */
	hd_ctrl = HDCTRL_SOFTRESET;
	for (i = 0; i < 255; i++)
		hd_wpbits;
	hd_ctrl = HDCTRL_ENABLE | HDCTRL_WAITENABLE;

	udata.u_dptr = tmpbuf();
	/* The label lives at offset 384 of the first sector */
	p = (struct minipart *)(udata.u_dptr + 384);

	for (dev = 0; dev < 4; dev++) {
		hd_sdh = HDSDH_ECC | HDSDH_512 | (dev << 3);
		hd_cmd = HDCMD_RESTORE | RATE_4MS;
		if (hd_waitready() & 1) {
			if ((hd_err & 0x12) == 0x12)
				continue;
		}
		/* Read the first sector. Drives formatted with sectors
		   numbered from 1 have no sector 0 */
		for (hd_secbase = 0; hd_secbase < 2; hd_secbase++) {
			hd_seccnt = 1;
			hd_sdh = HDSDH_ECC | HDSDH_512 | (dev << 3);
			hd_secnum = hd_secbase;
			hd_cyllo = 0;
			hd_cylhi = 0;
			hd_cmd = HDCMD_READ;
			if (hd_waitdrq() & 1)
				continue;
			if ((hd_xfer(1, udata.u_dptr) & 0x41) == 0x40)
				break;
		}
		if (hd_secbase == 2) {
			hd_secbase = 0;
			continue;
		}
		kprintf("hd%c: ", dev + 'a');
		if (p->g.magic != MP_SIG_0) {
			p->g.cyl = 1;
			p->g.head = 1;
			p->g.sec = 64;
			p->g.precomp = 0;
			p->g.seek = 10;
			p->g.secsize = 9;
			for (i = 0; i < 15; i++)
				p->cyl[i] = 0xFFFFU;
			kputs("(unlabelled)\n");
		} else {
			for (i = 0; i < 15; i++) {
				if (p->cyl[i] != 0xFFFFU) {
					if (p->type[i] == 0x56) {
						/* Configure swap */
						hd_swapon(p, dev, i);
					}
					kprintf("hd%c%d ", dev + 'a', i + 1);
				}
			}
			kputs("\n");
		}
		if (p->g.seek) {
			p->g.seek /= 2;
			if (p->g.seek == 0)
				p->g.seek = 1;
		}
		/* Set the step rate */
		hd_cmd = HDCMD_SEEK | p->g.seek;
		hd_waitready();
		memcpy(&parts[dev], p, sizeof(parts[dev]));
	}
	tmpfree(udata.u_dptr);
}
