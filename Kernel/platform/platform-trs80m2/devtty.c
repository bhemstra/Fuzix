/*
 *	TRS-80 Model II console and serial ports
 *
 *	tty1	80x24 video and keyboard
 *	tty2	Z80 SIO channel A (CTC channels 0 and 1 give the clocks)
 *	tty3	Z80 SIO channel B (CTC channel 2 gives the clock)
 *
 *	The keyboard controller sends ASCII codes and handles repeat
 *	itself. It holds off until we read the byte so polling it on the
 *	clock tick loses nothing.
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <vt.h>
#include <devtty.h>

static char tbuf1[TTYSIZ];
static char tbuf2[TTYSIZ];
static char tbuf3[TTYSIZ];

#define CTC0	0xF0
#define CTC1	0xF1
#define CTC2	0xF2

#define SIOA_DATA	0xF4
#define SIOB_DATA	0xF5
#define SIOA_CTRL	0xF6
#define SIOB_CTRL	0xF7

#define KBD_DATA	0xFC	/* read */
#define CRTC_ADDR	0xFC	/* write */
#define CRTC_DATA	0xFD
#define NMI_STATUS	0xFF	/* bit 7 is set when a key is waiting */

#define VIDEO	((uint8_t *)0xF800)

uint8_t vtattr_cap = VTA_INVERSE;
struct vt_repeat keyrepeat;	/* The keyboard repeats by itself */

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2},
	{tbuf2, tbuf2, tbuf2, TTYSIZ, 0, TTYSIZ / 2},
	{tbuf3, tbuf3, tbuf3, TTYSIZ, 0, TTYSIZ / 2}
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS,
	CSIZE | CBAUD | CSTOPB | PARENB | PARODD | _CSYS,
	CSIZE | CBAUD | CSTOPB | PARENB | PARODD | _CSYS
};

/* Write to system console */
void kputchar(uint_fast8_t c)
{
	if (c == '\n')
		tty_putc(1, '\r');
	tty_putc(1, c);
}

static uint8_t sio_rr0(uint_fast8_t minor)
{
	if (minor == 2)
		return in(SIOA_CTRL);
	return in(SIOB_CTRL);
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
	if (minor == 1)
		return TTY_READY_NOW;
	return (sio_rr0(minor) & 0x04) ? TTY_READY_NOW : TTY_READY_SOON;
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	irqflags_t irq;
	char ch = c;

	if (minor == 2)
		out(SIOA_DATA, c);
	else if (minor == 3)
		out(SIOB_DATA, c);
	else {
		irq = di();
		vtoutput(&ch, 1);
		irqrestore(irq);
	}
}

static void sio_rx(uint_fast8_t minor)
{
	uint8_t c;
	while (sio_rr0(minor) & 0x01) {
		if (minor == 2)
			c = in(SIOA_DATA);
		else
			c = in(SIOB_DATA);
		tty_inproc(minor, c);
	}
	/* Clear any overrun/framing error so the receiver keeps going */
	if (minor == 2)
		out(SIOA_CTRL, 0x30);
	else
		out(SIOB_CTRL, 0x30);
}

void tty_interrupt(void)
{
	sio_rx(2);
	sio_rx(3);
}

/*
 *	The CTC counts the 2MHz system clock / 2 and the SIO divides the
 *	result by 16 or 64. 9600 baud is the fastest rate that comes out
 *	accurately.
 */
static const uint8_t ctcdiv[] = {
	0, 0, 0, 0, 0,
	208,		/* 150 (x64) */
	104,		/* 300 (x64) */
	208,		/* 600 */
	104,		/* 1200 */
	52,		/* 2400 */
	26,		/* 4800 */
	13		/* 9600 */
};

static const uint8_t sio_rxbits[4] = { 0x00, 0x80, 0x40, 0xC0 };	/* 5 6 7 8 */
static const uint8_t sio_txbits[4] = { 0x00, 0x40, 0x20, 0x60 };

static void sio_write(uint_fast8_t minor, uint8_t reg, uint8_t val)
{
	if (minor == 2) {
		out(SIOA_CTRL, reg);
		out(SIOA_CTRL, val);
	} else {
		out(SIOB_CTRL, reg);
		out(SIOB_CTRL, val);
	}
}

void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
	tcflag_t cflag;
	uint8_t baud;
	uint8_t bits;
	uint8_t r4 = 0x44;	/* x16, 1 stop bit */

	used(flags);

	if (minor == 1)
		return;

	cflag = ttydata[minor].termios.c_cflag;
	baud = cflag & CBAUD;
	if (baud > B9600)
		baud = B9600;
	if (baud < B150)
		baud = B150;
	cflag &= ~CBAUD;
	cflag |= baud;
	ttydata[minor].termios.c_cflag = cflag;

	if (baud < B600)
		r4 = 0xC4;	/* x64 */
	if (cflag & CSTOPB)
		r4 |= 0x08;	/* 2 stop bits */
	if (cflag & PARENB) {
		r4 |= 0x01;
		if (!(cflag & PARODD))
			r4 |= 0x02;
	}
	bits = (cflag & CSIZE) >> 4;

	/* Counter mode, time constant follows, reset */
	if (minor == 2) {
		out(CTC0, 0x57);
		out(CTC0, ctcdiv[baud]);
		out(CTC1, 0x57);
		out(CTC1, ctcdiv[baud]);
		out(SIOA_CTRL, 0x18);	/* channel reset */
	} else {
		out(CTC2, 0x57);
		out(CTC2, ctcdiv[baud]);
		out(SIOB_CTRL, 0x18);
		sio_write(3, 2, 0x00);	/* vector (unused in IM 1) */
	}
	sio_write(minor, 4, r4);
	sio_write(minor, 3, sio_rxbits[bits] | 0x01);		/* RX on */
	sio_write(minor, 5, sio_txbits[bits] | 0x8A);		/* DTR RTS TX */
	sio_write(minor, 1, 0x18);	/* interrupt on every received byte */
}

void sio_init(void)
{
	tty_setup(2, 0);
	tty_setup(3, 0);
}

int tty_carrier(uint_fast8_t minor)
{
	used(minor);
	return 1;
}

void tty_sleeping(uint_fast8_t minor)
{
	used(minor);
}

void tty_data_consumed(uint_fast8_t minor)
{
	used(minor);
}

/*
 *	Video: 80x24 characters at F800 (only visible in the kernel map),
 *	bit 7 selects reverse video. The cursor is the 6845 hardware
 *	cursor.
 */

static void crtc_set(uint8_t reg, uint8_t val)
{
	out(CRTC_ADDR, reg);
	out(CRTC_DATA, val);
}

static uint8_t *char_addr(uint8_t y, uint8_t x)
{
	return VIDEO + VT_WIDTH * (uint16_t)y + x;
}

void cursor_off(void)
{
	crtc_set(10, 0x20);		/* cursor not displayed */
}

void cursor_disable(void)
{
	cursor_off();
}

void cursor_on(int8_t y, int8_t x)
{
	uint16_t pos = VT_WIDTH * (uint16_t)y + x;
	crtc_set(14, pos >> 8);
	crtc_set(15, pos);
	crtc_set(10, 0x65);		/* blinking, lines 5-9 */
}

void plot_char(int8_t y, int8_t x, uint16_t c)
{
	uint8_t ch = c & 0x7F;
	if (vtattr & VTA_INVERSE)
		ch |= 0x80;
	*char_addr(y, x) = ch;
}

void clear_lines(int8_t y, int8_t ct)
{
	memset(char_addr(y, 0), ' ', ct * VT_WIDTH);
}

void clear_across(int8_t y, int8_t x, int16_t l)
{
	memset(char_addr(y, x), ' ', l);
}

void vtattr_notify(void)
{
}

/* memcpy copies upwards, so it can move the screen up over itself */
void scroll_up(void)
{
	memcpy(VIDEO, VIDEO + VT_WIDTH, VT_WIDTH * VT_BOTTOM);
}

/* and down a line at a time, from the bottom */
void scroll_down(void)
{
	uint8_t *p = VIDEO + VT_WIDTH * VT_BOTTOM;
	uint_fast8_t n;
	for (n = 0; n < VT_BOTTOM; n++) {
		memcpy(p, p - VT_WIDTH, VT_WIDTH);
		p -= VT_WIDTH;
	}
}

/*
 *	Keyboard
 *
 *	Most keys are plain ASCII. The specials are
 *	00 HOLD  01 F1  02 F2  03 BREAK  1C left  1D right  1E up  1F down
 *
 *	F2 is used to toggle case swapping (see keydecode)
 */

static uint8_t held;
static uint8_t swapcase;

static void keydecode(uint8_t c)
{
	/* The keyboard has its own CAPS lock which may be on (everything
	   arrives in upper case). F2 swaps the case of letters in software
	   for when that cannot be turned off */
	if (swapcase && ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')))
		c ^= 0x20;
	switch (c) {
	case 0x00:
		/* HOLD acts as a ^S / ^Q toggle */
		held ^= 1;
		c = held ? 0x13 : 0x11;
		break;
	case 0x01:
		c = KEY_F1;
		break;
	case 0x02:
		swapcase ^= 1;
		return;
	case 0x1C:
		c = KEY_LEFT;
		break;
	case 0x1D:
		c = KEY_RIGHT;
		break;
	case 0x1E:
		c = KEY_UP;
		break;
	case 0x1F:
		c = KEY_DOWN;
		break;
	}
	vt_inproc(1, c);
}

void kbd_poll(void)
{
	while (in(NMI_STATUS) & 0x80)
		keydecode(in(KBD_DATA));
}
