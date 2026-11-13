#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <tinydisk.h>
#include <tinyide.h>
#include <devtty.h>

uint16_t swap_dev = 0xFFFF;

void plt_idle(void)
{
	/* Just spin */
}

void do_beep(void)
{
}

void map_init(void)
{
}

uint_fast8_t plt_param(char *p)
{
    return 0;
}

static volatile uint8_t *via = (volatile uint8_t *)0xFE60;

extern void bufsetup(void);

void device_init(void)
{
	bufsetup();
#ifdef CONFIG_TD_IDE
	ide_probe();
#endif
}

void plt_interrupt(void)
{
	if (keybrk || keyrx)
		tty_poll();
	if (vbticks >= 6) {
		timer_interrupt();
		vbticks = 0;
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

