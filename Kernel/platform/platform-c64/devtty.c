#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <devtty.h>
#include <device.h>
#include <vt.h>
#include <tty.h>
#include "devtty.h"

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
	vtoutput(&c, 1);
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

uint8_t keyboard[8][8] = {
	{KEY_STOP, 'q', 0/*C=*/, ' ', '2', 0/*CTRL*/, 8, '1' },
	{'/', '^', '=', 0/*RSHIFT*/, KEY_HOME, ';', '*', KEY_POUND },
	{',', '@', ':', '.', '-', 'l', 'p', '+' },
	{'n', 'o', 'k', 'm', '0', 'j', 'i', '9' },
	{'v', 'u', 'h', 'b', '8', 'g', 'y', '7' },
	{'x', 't', 'f', 'c', '6', 'd', 'r', '5' },
	{ /*LSHIFT*/0, 'e', 's', 'z', '4', 'a', 'w', '3'},
	{ KEY_DOWN, KEY_F5, KEY_F3, KEY_F1, KEY_F7, KEY_RIGHT, 13, 127 }
};

/* Need | ^ [] - added _ as shift-*/
uint8_t shiftkeyboard[8][8] = {
	{KEY_STOP, 'Q', 0/*C=*/, ' ', '"', 0/*CTRL*/, 8, '!' },
	{'?', '^', '=', 0/*RSHIFT*/, KEY_HOME, '}', '*', KEY_POUND },
	{'<', '@', '}', '>', '_', 'L', 'P', '+' },
	{'N', 'O', 'K', 'M', '0', 'J', 'I', ')' },
	{'V', 'U', 'H', 'B', '(', 'G', 'Y', 35/*quoteFIXME*/ },
	{'X', 'T', 'F', 'C', '&', 'D', 'R', '%' },
	{ /*LSHIFT*/0, 'E', 'S', 'Z', '$', 'A', 'W', '#'},
	{ KEY_UP, KEY_F6, KEY_F4, KEY_F2, KEY_F8, KEY_LEFT, 13, 127 }
};

/* For now use the ROM rather than doing our own matrix scan */
void tty_poll(void)
{
	uint8_t c = keyread();
	if (c == 0)
		return;
	if (c > 0x40 && c < 0x5B)
		c += 0x20;
	else if (c >= 0xC0 && c <= 0xDB) {
		c &= 31;
		c += 0x40;
	}
	if (c > 0x80)
		kprintf("?%x", c);
	else if (c)
		vt_inproc(1, c);
#if 0
	uint8_t c = keyscan();
	if (c)
		c = keyboard[c >> 3][c & 7];
	if (c)
		vt_inproc(1, c);
#endif
}

int c64tty_ioctl(uint_fast8_t minor, uarg_t request, register char *data)
{
	switch(request)
	{
	case VTPAPER:
		vidpaper = ugetc(data);
		vtattr_notify();
		return 0;
	case VTBORDER:
		vtborder = ugetc(data);
		vtattr_notify();
		return 0;
	}
	return vt_ioctl(minor, request, data);
}
