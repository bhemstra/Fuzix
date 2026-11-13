#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <devtty.h>
#include <device.h>
//#include <vt.h>
#include <tty.h>

extern uint8_t vtputchar(char c);

static char tbuf1[TTYSIZ];

uint8_t vtattr_cap;

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2},
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS	/* TODO */
};

/* Output for the system console (kprintf etc) */
void kputchar(uint8_t c)
{
	if (c == '\n')
		tty_putc(1, '\r');
	tty_putc(1, c);
}

ttyready_t tty_writeready(uint8_t minor)
{
        return TTY_READY_NOW;
}

void tty_putc(uint8_t minor, unsigned char c)
{
	vtputchar(c);
//	vtoutput(&c, 1);
}

void tty_setup(uint8_t minor, uint8_t flag)
{
}

void tty_sleeping(uint8_t minor)
{
}

/* For the moment */
int tty_carrier(uint8_t minor)
{
	return 1;
}

void tty_data_consumed(uint8_t minor)
{
}

void tty_poll(void)
{
	uint8_t c;
	if (keybrk) {
		keybrk = 0;
		tty_inproc(1, 3);
	}
	if (keyrx) {
		c = keyrx;
		keyrx = 0;
		tty_inproc(1, c);
	}
}

int vt_ioctl(uint_fast8_t minor, uarg_t request, register char *data)
{
	switch(request) {
	case VTSIZE:
		return (VT_BOTTOM + 1) << 8 | (VT_RIGHT + 1);
	case VTATTRS:
		return vtattr_cap;
	}
	return tty_ioctl(minor, request, data);
}
