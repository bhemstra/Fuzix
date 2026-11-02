#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <ports.h>
#include <devhd.h>

uint8_t kernel_flag = 1;
uint16_t swap_dev = 0xFFFF;

void plt_idle(void)
{
	irqflags_t flags = di();
	tty_poll();
	irqrestore(flags);
}

void do_beep(void)
{
}

/*
 * Map handling: allocate 3 banks per process
 */

void pagemap_init(void)
{
	int i;
	/* Add the user banks, taking care to land 4 as the last one as we
	use that for init (0/1/2/3 are the kernel) */
	for (i = 6; i >= 0; i--)
		pagemap_add(4 + i * 4);
}

void map_init(void)
{
}

uint8_t plt_param(char *p)
{
	used(p);
	return 0;
}

void device_init(void)
{
	//set 100Hz
	//IRQ-timer counts 900 ticks per sec
	io_timer_target = 900 / TICKSPERSEC;
	hd_init();
}

void plt_interrupt(void)
{
	tty_poll();
	// writing any value will ack IRQ and restart timer
	io_timer_reset = 0;
	timer_interrupt();
}

/* TODO: put these into the asm bits */
unsigned strlen(const char *p)
{
	unsigned n = 0;
	while(*p++)
		n++;
	return n;
}

void *memcpy(void *to, const void *from, unsigned len)
{
	const uint8_t *f = from;
	uint8_t *t = to;
	while(len--)
		*t++ = *f++;
	return to;
}

void *memset(void *to, int v, unsigned len)
{
	uint8_t *t = to;
	while(len--)
		*t++ = v;
	return to;
}

