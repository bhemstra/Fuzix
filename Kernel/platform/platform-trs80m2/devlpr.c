/*
 *	Model II parallel printer on the FDC/printer board PIO
 *
 *	E0	PIO port A: bit 7 busy, bit 6 paper empty, bit 5 not selected,
 *		bit 4 fault (0 = fault)
 *	E1	PIO port B: printer data, the PIO generates the strobe
 */

#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <devlpr.h>

__sfr __at 0xE0 lpstat;
__sfr __at 0xE1 lpdata;

int lpr_open(uint8_t minor, uint16_t flag)
{
	used(minor);
	used(flag);
	return 0;
}

int lpr_close(uint8_t minor)
{
	used(minor);
	return 0;
}

static uint8_t lpr_ready(void)
{
	/* Not busy, paper, selected and no fault */
	return (lpstat & 0xF0) == 0x10;
}

int lpr_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
	uint16_t ct = 0;
	char *p = udata.u_base;

	used(minor);
	used(rawflag);

	while (ct < udata.u_count) {
		/* Nothing interrupts us when the printer becomes ready so
		   just spin, unless the caller asked not to block */
		while (!lpr_ready()) {
			if (flag & O_NDELAY) {
				if (ct)
					return ct;
				udata.u_error = EAGAIN;
				return -1;
			}
		}
		lpdata = ugetc(p++);
		ct++;
	}
	return ct;
}
