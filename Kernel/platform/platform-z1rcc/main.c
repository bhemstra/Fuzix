#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <kmod.h>
#include <devtty.h>
#include <tinysd.h>
#include <z180.h>

uint16_t ramtop = PROGTOP;
extern unsigned char irqvector;
uint16_t swap_dev = 0xFFFF;

uint16_t rtc_port = 0x0C;
uint8_t rtc_shadow = 0x00;

struct blkbuf *bufpool_end = bufpool + NBUFS;	/* minimal for boot -- expanded after we're done with _DISCARD */

void plt_discard(void)
{
#ifdef CONFIG_KMOD
	kmod_init(bufpool_end, (void *) KERNTOP);
#endif
	while (bufpool_end < (struct blkbuf *) (KERNTOP - sizeof(struct blkbuf))) {
		memset(bufpool_end, 0, sizeof(struct blkbuf));
#if BF_FREE != 0
		bufpool_end->bf_busy = BF_FREE;	/* redundant when BF_FREE == 0 */
#endif
		bufpool_end->bf_dev = NO_DEVICE;
		bufpool_end++;
	}
}

unsigned plt_kmod_set(uint8_t *top)
{
	/* Make sure all disk buffers are on disk */
	sync();
	/* Wind back until bufpool end is below the modules */
	while (bufpool_end > (void *) top)
		bufpool_end--;
	/* Any buffers lost we already wrote to disk, any new lookups will
	   not find them, and we know there are no other outstanding references
	   - sometimes having a dumb I/O layer is a win */
	return 0;
}

void z180_timer_interrupt(void)
{
	/* we have to read both of these registers in order to reset the timer */
	in(TIME_TCR);
	in(TIME_TMDR0L);
	timer_interrupt();
}

void plt_interrupt(void)
{
	switch (irqvector) {
	case Z180_INT_TIMER0:
		z180_timer_interrupt();
		return;
	case Z180_INT_ASCI0:
		tty_pirq_asci0();
		return;
	case Z180_INT_ASCI1:
		tty_pirq_asci1();
		return;
	default:
		return;
	}
}

void plt_ds1302_setup(void)
{
}

void plt_ds1302_restore(void)
{
}
