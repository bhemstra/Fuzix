#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <rtc.h>

uint16_t ramtop = PROGTOP;
__sfr __at 0xE0 irqstat;
__sfr __at 0xEF irqack;

uint8_t banktype;
uint8_t vtattr_cap;
uint8_t gfxtype;

struct blkbuf *bufpool_end = bufpool + NBUFS;

void plt_idle(void)
{
    __asm
    halt
    __endasm;
}

void do_beep(void)
{
}

uint8_t plt_param(char *p)
{
    used(p);
    return 0;
}

void plt_interrupt(void)
{
  uint8_t irq = ~irqstat;
  uint8_t dummy;
  if (irq & 0x20)
    tty_interrupt();
  if (irq & 0x04) {
    kbd_interrupt();
    timer_interrupt();
    dummy = irqack;
  }
}

/*
 *	Once we are about to load init we can throw the boot code away
 *	and convert it into disk cache. This gets us 7 or so buffer
 *	back which more than doubles our cache size !
 */
void plt_discard(void)
{
  extern uint16_t discard_size;
  bufptr bp = bufpool_end;

  discard_size /= sizeof(struct blkbuf);

  kprintf("%d buffers reclaimed from discard\n", discard_size);

  bufpool_end += discard_size;	/* Reclaim the discard space */

  memset(bp, 0, discard_size * sizeof(struct blkbuf));
  /* discard_size is in discard so it dies here */
  for (bp = bufpool + NBUFS; bp < bufpool_end; ++bp) {
    bp->bf_dev = NO_DEVICE;
    bp->bf_busy = BF_FREE;
  }
}

#ifdef CONFIG_RTC

/*
 *	Two clocks: the clock chip on ports B0-BC (BCD digits), and the
 *	clock of a FreHD. The chip is used when it is there; it also gives
 *	the seconds for the timer (plt_rtc_secs). The FreHD clock is only
 *	read by /dev/rtc (setdate at boot) and set by writing it: never from
 *	an interrupt, as it shares the controller with the hard disk.
 *
 *	FreHD: write a command to port C4, wait until the status (CF) is no
 *	longer busy, then move the data through port C2. GET_TIME gives and
 *	SET_TIME takes 6 binary bytes: seconds, minutes, hours, year (from
 *	2000), day, month (1-12).
 */

__sfr __at 0xB0 rtc_secl;
__sfr __at 0xB1 rtc_sech;
__sfr __at 0xB2 rtc_minl;
__sfr __at 0xB3 rtc_minh;
__sfr __at 0xB4 rtc_hourl;
__sfr __at 0xB5 rtc_hourh;
/* day of week is B6 */
__sfr __at 0xB7 rtc_dayl;
__sfr __at 0xB8 rtc_dayh;
__sfr __at 0xB9 rtc_monl;
__sfr __at 0xBA rtc_monh;
__sfr __at 0xBB rtc_yearl;
__sfr __at 0xBC rtc_yearh;

__sfr __at 0xC2 frehd_data;
__sfr __at 0xC4 frehd_cmd;
__sfr __at 0xCF frehd_status;

#define FREHD_GET_TIME	0x01
#define FREHD_SET_TIME	0x02

/* The order of the FreHD time bytes */
#define FT_SEC		0
#define FT_MIN		1
#define FT_HOUR		2
#define FT_YEAR		3
#define FT_DAY		4
#define FT_MONTH	5

static uint8_t frehd_absent;	/* set once a FreHD did not answer */

/* Wait for the FreHD to finish a command: 0 if it did, without error */
static uint8_t frehd_wait(void)
{
    uint16_t n = 0;
    while (frehd_status & 0x80)	/* busy: no hard disk at all reads FF */
        if (--n == 0)
            return 1;
    return frehd_status & 0x01;
}

/* Read the FreHD clock into t (6 bytes): 0 if there is a FreHD and the
   time it gives is sane */
static uint8_t frehd_get_time(uint8_t *t)
{
    uint8_t i;
    if (frehd_absent)
        return 1;
    frehd_cmd = FREHD_GET_TIME;
    if (frehd_wait() == 0) {
        for (i = 0; i < 6; i++)
            t[i] = frehd_data;
        if (t[FT_SEC] < 60 && t[FT_MIN] < 60 && t[FT_HOUR] < 24 &&
            t[FT_YEAR] < 100 && t[FT_DAY] >= 1 && t[FT_DAY] <= 31 &&
            t[FT_MONTH] >= 1 && t[FT_MONTH] <= 12)
            return 0;
    }
    frehd_absent = 1;
    return 1;
}

static uint8_t digits(uint8_t h, uint8_t l)
{
    return h * 10 + l;
}

/* FIXME: the RTC is optional so we should test for it first */
uint8_t plt_rtc_secs(void)
{
    uint8_t sl, rv;
    /* BCD encoded */
    do {
        sl = rtc_secl;
        /* RTC may be absent */
        if (sl == 255)
          return 255;
        rv = sl + rtc_sech * 10;
    } while (sl != rtc_secl);
    return rv;
}

/* If the compiler segfaults here you need at least SDCC #10471 */

/* The time as setdate wants it: CMOS_RTC_DEC, binary, the year in two
   bytes (little endian), the month counted from 0 */
int plt_rtc_read(void)
{
    uint16_t len = sizeof(struct cmos_rtc);
    struct cmos_rtc cmos;
    uint8_t *p = cmos.data.bytes;
    uint8_t t[6];
    uint8_t r;
    uint16_t y;

    if (udata.u_count < len)
        len = udata.u_count;

    if (rtc_secl != 255) {
        /* We do a full set of reads and if the seconds change retry - we
           need to retry the lost as we might read as the second changes
           for new year */
        do {
            r = rtc_secl;
            t[FT_YEAR] = digits(rtc_yearh, rtc_yearl);
            t[FT_MONTH] = digits(rtc_monh & 1, rtc_monl);
            t[FT_DAY] = digits(rtc_dayh & 3, rtc_dayl);
            t[FT_HOUR] = digits(rtc_hourh & 3, rtc_hourl);
            t[FT_MIN] = digits(rtc_minh & 7, rtc_minl);
            t[FT_SEC] = digits(rtc_sech & 7, rtc_secl);
        } while ((r ^ rtc_secl) & 0x0F);
        y = t[FT_YEAR] + (t[FT_YEAR] >= 70 ? 1900 : 2000);
    } else if (frehd_get_time(t) == 0) {
        y = t[FT_YEAR] + 2000;
    } else {
        udata.u_error = EOPNOTSUPP;
        return -1;
    }

    *p++ = y;
    *p++ = y >> 8;
    *p++ = t[FT_MONTH] - 1;
    *p++ = t[FT_DAY];
    *p++ = t[FT_HOUR];
    *p++ = t[FT_MIN];
    *p++ = t[FT_SEC];
    *p = 0;
    cmos.type = CMOS_RTC_DEC;
    if (uput(&cmos, udata.u_base, len) == -1)
        return -1;
    return len;
}

/* Set the FreHD clock (setdate -w). The clock chip cannot be set: on any
   change it sets the seconds to 0, and leap years need handling. */
int plt_rtc_write(void)
{
    struct cmos_rtc cmos;
    uint8_t t[6];
    uint8_t *p = cmos.data.bytes;
    uint16_t y;
    uint8_t i;

    if (rtc_secl != 255 || frehd_get_time(t)) {
        udata.u_error = EOPNOTSUPP;
        return -1;
    }
    if (udata.u_count != sizeof(struct cmos_rtc)) {
        udata.u_error = EINVAL;
        return -1;
    }
    if (uget(udata.u_base, &cmos, sizeof(struct cmos_rtc)) == -1)
        return -1;
    y = p[0] | (p[1] << 8);
    if (cmos.type != CMOS_RTC_DEC || y < 2000 || y > 2099 || p[2] > 11) {
        udata.u_error = EINVAL;
        return -1;
    }
    t[FT_YEAR] = y - 2000;
    t[FT_MONTH] = p[2] + 1;
    t[FT_DAY] = p[3];
    t[FT_HOUR] = p[4];
    t[FT_MIN] = p[5];
    t[FT_SEC] = p[6];
    frehd_cmd = FREHD_SET_TIME;
    if (frehd_wait() == 0) {
        for (i = 0; i < 6; i++)
            frehd_data = t[i];
        if (frehd_wait() == 0)
            return sizeof(struct cmos_rtc);
    }
    udata.u_error = EIO;
    return -1;
}

#endif

