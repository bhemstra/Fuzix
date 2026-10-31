#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <tinydisk.h>
#include <tinyide.h>
#include <devtty.h>

uint16_t swap_dev = 0xFFFF;
uint16_t reu_size;

void plt_idle(void)
{
    irqflags_t flags = di();
    tty_poll();
    irqrestore(flags);
}

void do_beep(void)
{
}

static uint8_t last_t = 0;

void plt_interrupt(void)
{
	/* Oddly the 24 bit tick is big endian */
	uint8_t t = *(volatile uint8_t *)0x00A2;
	uint8_t delta;
	/* Calc difference between 60th ticks and current ticks. Wrap as needed */
	delta = t - last_t;
	tty_poll();
	/* Run our 10Hz internal processing */
	if (delta >= 6) {
		last_t = t;
		timer_interrupt();
	}
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

