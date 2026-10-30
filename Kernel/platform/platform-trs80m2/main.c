#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <devm2.h>

uint16_t ramtop = PROGTOP;

struct blkbuf *bufpool_end = bufpool + NBUFS;

/* RTC ticks seen by the NMI handler and ticks we have processed */
static uint8_t nmi_seen;

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

/*
 *	We get here from a SIO interrupt or from the real time clock NMI
 *	(when it arrived with interrupts enabled). The NMI handler bumps
 *	nmi_count every tick even when it cannot run us, so catch up on any
 *	ticks we missed.
 */
void plt_interrupt(void)
{
	tty_interrupt();
	while (nmi_seen != nmi_count) {
		nmi_seen++;
		kbd_poll();
		timer_interrupt();
	}
}

/*
 *	Once we are about to load init we can throw the boot code away
 *	and convert it into disk cache. The discard area runs up to the
 *	video memory so this is a useful gain.
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

/*
 *	Work out how much memory we have. Page 0 (low 32K) and page 1 (the
 *	upper kernel) must be present or we would never have booted.
 *
 *	The core code calls pagemap_init() before map_init(), and the first
 *	process is allocated straight after, so the probe has to be done
 *	here. Without pages the first process gets no memory and the kernel
 *	ends up writing through a NULL pointer over the vectors in page 0.
 */
void pagemap_init(void)
{
	uint8_t i;
	uint8_t n = 0;
	uint16_t pagemask = m2_pages();

	for (i = 2; i < 16; i++) {
		if (pagemask & (1 << i)) {
			pagemap_add(i);
			n++;
		}
	}
	procmem = 32 * n;
	ramsize = 64 + procmem;
	if (n == 0)
		panic("need 96K or more");
}

void map_init(void)
{
}
