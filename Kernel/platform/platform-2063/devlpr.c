#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <printer.h>
#include <devlpr.h>
#include <2063.h>

#define LP		0x20
#define GPIO_IN		0x00
#define GPIO_OUT	0x10

int lpr_open(uint_fast8_t minor, uint16_t flag)
{
	if (!minor)
		return 0;
	udata.u_error = ENODEV;
	return -1;
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
		while (in(GPIO_IN) & 0x08) {
			/* Report what we have written, not what is left */
			if ((n = iopoll(p - udata.u_base)) != 0)
				return n;
		}
		out(LP, ugetc(p++));
		irq = di();
		/* Strobe low for 1us */
		lp_strobe();
#if 0
		gpio_out = gpio & ~8;
		__asm
			nop
			nop
		__endasm;
		gpio_out = gpio;
#endif
		irqrestore(irq);
	}
	return udata.u_count;
}

int lpr_ioctl(uint_fast8_t minor, uarg_t arg, char *ptr)
{
	uint8_t s, r = 0;

	used(ptr);

	/* TODO : check polarity versus IBM - esp BUSY */
	if (arg == LPIOCSTAT) {
	        s = in(GPIO_IN);
		if (s & 0x01)
			r |= LP_ERROR;
		if (s & 0x02)
			r |= LP_SELECT;
		if (s & 0x04)
			r |= LP_PAPER;
		if (s & 0x08)
			r |= LP_BUSY;
		if (s & 0x10)
			r |= LP_ACK;
		return r;
	}
	return -1;
}
