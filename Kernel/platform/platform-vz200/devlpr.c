#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <devlpr.h>

#define	STATUS	0x00
#define DATA	0x0E

int lpr_open(uint_fast8_t minor, uint16_t flag)
{
	if (minor == 0)
		return 0;
	udata.u_error = ENODEV;
	return -1;
}

int lpr_close(uint_fast8_t minor)
{
	return 0;
}

static int iopoll(int sofar)
{
	/* Ought to be a core helper for this lot ? */
	if (need_reschedule())
		_sched_yield();
	if (chksigs()) {
		if (sofar)
			return sofar;
		udata.u_error = EINTR;
		return -1;
	}
	return 0;
}

int lpr_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
	uint8_t *p = udata.u_base;
	uint8_t *pe = p + udata.u_count;
	int n;
	irqflags_t irq;

	while (p < pe) {
		/* Printer busy ? */
		while (in(STATUS) & 1) {
			if ((n = iopoll(p - udata.u_base)) != 0)
				return n;
		}
		out(DATA, ugetc(p++));
	}
	return udata.u_count;
}
