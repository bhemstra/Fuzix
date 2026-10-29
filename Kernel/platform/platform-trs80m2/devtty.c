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

__sfr __at 0xF0 ctc0;
__sfr __at 0xF1 ctc1;
__sfr __at 0xF2 ctc2;

__sfr __at 0xF4 sioa_data;
__sfr __at 0xF5 siob_data;
__sfr __at 0xF6 sioa_ctrl;
__sfr __at 0xF7 siob_ctrl;

__sfr __at 0xFC kbd_data;	/* read */
__sfr __at 0xFC crtc_addr;	/* write */
__sfr __at 0xFD crtc_data;
__sfr __at 0xFF nmi_status;	/* bit 7 is set when a key is waiting */

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
void kputchar(char c)
{
	if (c == '\n')
		tty_putc(1, '\r');
	tty_putc(1, c);
}

static uint8_t sio_rr0(uint8_t minor)
{
	if (minor == 2)
		return sioa_ctrl;
	return siob_ctrl;
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

	if (minor == 2)
		sioa_data = c;
	else if (minor == 3)
		siob_data = c;
	else {
		irq = di();
		vtoutput(&c, 1);
		irqrestore(irq);
	}
}

static void sio_rx(uint8_t minor)
{
	uint8_t c;
	while (sio_rr0(minor) & 0x01) {
		if (minor == 2)
			c = sioa_data;
		else
			c = siob_data;
		tty_inproc(minor, c);
	}
	/* Clear any overrun/framing error so the receiver keeps going */
	if (minor == 2)
		sioa_ctrl = 0x30;
	else
		siob_ctrl = 0x30;
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

static void sio_write(uint8_t minor, uint8_t reg, uint8_t val)
{
	if (minor == 2) {
		sioa_ctrl = reg;
		sioa_ctrl = val;
	} else {
		siob_ctrl = reg;
		siob_ctrl = val;
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
		ctc0 = 0x57;
		ctc0 = ctcdiv[baud];
		ctc1 = 0x57;
		ctc1 = ctcdiv[baud];
		sioa_ctrl = 0x18;	/* channel reset */
	} else {
		ctc2 = 0x57;
		ctc2 = ctcdiv[baud];
		siob_ctrl = 0x18;
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
	crtc_addr = reg;
	crtc_data = val;
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

void scroll_up(void)
{
	memmove(VIDEO, VIDEO + VT_WIDTH, VT_WIDTH * VT_BOTTOM);
}

void scroll_down(void)
{
	memmove(VIDEO + VT_WIDTH, VIDEO, VT_WIDTH * VT_BOTTOM);
}

/*
 *	Keyboard
 *
 *	Most keys are plain ASCII. The specials are
 *	00 HOLD  01 F1  02 F2  03 BREAK  1C left  1D right  1E up  1F down
 */

static uint8_t held;

static void keydecode(uint8_t c)
{
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
		c = KEY_F2;
		break;
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
	while (nmi_status & 0x80)
		keydecode(kbd_data);
}
