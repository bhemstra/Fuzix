#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <rtc.h>

#define RTC(x)		((x << 8) | 0x55)
#define INRTC(x)	in(RTC(x))

/* Full RTC support (for read - no write yet) */
int plt_rtc_read(void)
{
        irqflags_t irq;
	uint16_t len = sizeof(struct cmos_rtc);
	struct cmos_rtc cmos;
	uint8_t *p = cmos.data.bytes;

	if (udata.u_count < len)
		len = udata.u_count;

        irq = di();
        out(RTC(0x0D), INRTC(0x0D) | 1);	/* Set hold and then */
        while(INRTC(0x0D) & 0x02);		/* spin until not busy */

        /* Now safe to read the clock */
        /* FIXME: we assume 24hr mode */
        p[6] = RTC(0) | (RTC(1) << 4);
        p[5] = RTC(2) | (RTC(3) << 4);
        p[4] = RTC(4) | ((RTC(5) << 4) & 0x30);
        p[3] = RTC(6) | (RTC(7) << 4);
        p[2] = RTC(8) | (RTC(9) << 4);
        p[1] = RTC(10) | (RTC(11) << 4);
        /* Assume 2000 based for now FIXME */
        p[0] = 0x20;

        out(RTC(0x0D), INRTC(0x0D) & ~1);	/* Hold off */

        irqrestore(irq);
	cmos.type = CMOS_RTC_BCD;

	if (uput(&cmos, udata.u_base, len) == -1)
		return -1;
	return len;
}

int plt_rtc_write(void)
{
	udata.u_error = EOPNOTSUPP;
	return -1;
}

uint_fast8_t plt_rtc_secs(void)
{
        irqflags_t irq;
        uint8_t s;
        irq = di();
        out(RTC(0x0D), INRTC(0x0D) | 0x01);	/* Set hold and then */
        while(INRTC(0x0D) & 0x02);	/* spin until not busy */
        s = INRTC(0) + 10 * INRTC(1);
        out(RTC(0x0D), INRTC(0x0D) & ~0x01);
        irqrestore(irq);
        return s;
}
