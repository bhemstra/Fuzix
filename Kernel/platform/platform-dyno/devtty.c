#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <vt.h>
#include <devtty.h>
#include <z180.h>

/* TODO: An SIO style vectors ASCI driver template */

static uint8_t tbuf1[TTYSIZ];
static uint8_t tbuf2[TTYSIZ];

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{ NULL, NULL, NULL, 0, 0, 0 },
	{ tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2 },
	{ tbuf2, tbuf2, tbuf2, TTYSIZ, 0, TTYSIZ / 2 },
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS | CBAUD | PARENB | PARODD | CSIZE | CSTOPB | CRTSCTS,
	_CSYS | CBAUD | PARENB | PARODD | CSIZE | CSTOPB | CRTSCTS,
};

/* bit 5: turn on divide by 30 v 10
   bit 3: turn on scale by 64 not 16
   bit 2-0: 2^n for scaling (not 111) */
static const uint8_t baudtable[] = {
	/* Dividers for our clock. Table is smaller than the maths by far */
	0,
	0,			/* 50 */
	0,			/* 75 */
	0,			/* 110 */
	0,			/* 134.5 */
	0x2E,			/* 150 */
	0x2D,			/* 300 */
	0x2C,			/* 600 */
	0x2B,			/* 1200 */
	0x2A,			/* 2400 */
	0x29,			/* 4800 */
	0x28,			/* 9600 */
	/* Now switch to 16x clock */
	0x21,			/* 19200 */
	0x20,			/* 38400 */
	/* And 10x scaler */
	0x01,			/* 57600 */
	0x00,			/* 115200 */
};

void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
	struct termios *t = &ttydata[minor].termios;
	uint8_t cntla = 0x60;
	uint8_t cntlb = 0;
	uint16_t cflag = t->c_cflag;
	uint8_t baud;
	uint8_t ecr = 0;

	used(flags);

	/* Calculate the control bits */
	if (cflag & PARENB) {
		cntla |= 2;
		if (cflag & PARODD)
			cntlb |= 0x10;
	}
	if ((cflag & CSIZE) == CS8)
		cntla |= 4;
	else {
		cflag &= ~CSIZE;
		cflag |= CS7;
	}
	if (cflag & CSTOPB)
		cntla |= 1;

	/* Handle the baud table. Right now this is hardcoded for our clock */

	baud = cflag & CBAUD;
	/* We can't get below 150 easily. We might be able to do this with the
	   BRG on one channel - need to check FIXME */
	if (baud && baud < B150) {
		baud = B150;
		cflag &= ~CBAUD;
		cflag |= B150;
	}
	cntlb |= baudtable[baud];

	if (minor == 1) {
		if (cflag & CRTSCTS)
			ecr = 0x20;
		/* FIXME: need to do software RTS side */
	} else {
		cflag &= ~CRTSCTS;
	}

	t->c_cflag = cflag;

	/* ASCI serial set up */
	if (minor == 1) {
		out(ASCI_CNTLA0, cntla);
		out(ASCI_CNTLB0, cntlb);
		out(ASCI_ASEXT0, in(ASCI_ASEXT0) & ~0x20);
		out(ASCI_ASEXT1, in(ASCI_ASEXT1) | ecr);
	} else if (minor == 2) {
		out(ASCI_CNTLA1, cntla);
		out(ASCI_CNTLB1, cntlb);
	}
}

/* For the moment */
int tty_carrier(uint_fast8_t minor)
{
	minor;
	return 1;
}

void tty_pirq_asci0(void)
{
	while (in(ASCI_STAT0) & 0x80)
		tty_inproc(1, in(ASCI_RDR0));
	if (in(ASCI_STAT0) & 0x70)
		out(ASCI_CNTLA0, in(ASCI_CNTLA0) & ~0x08);
}

void tty_pirq_asci1(void)
{
	while (in(ASCI_STAT1) & 0x80)
		tty_inproc(2, in(ASCI_RDR1));
	if (in(ASCI_STAT1) & 0x70)
		out(ASCI_CNTLA1, in(ASCI_CNTLA1) & ~0x08);
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	char ch;
	switch (minor) {
	case 1:
		while (!(in(ASCI_STAT0) & 2));
		out(ASCI_TDR0, c);
		break;
	case 2:
		while (!(in(ASCI_STAT1) & 2));
		out(ASCI_TDR1, c);
		break;
	}
}

void tty_sleeping(uint_fast8_t minor)
{
}

void tty_data_consumed(uint_fast8_t minor)
{
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
    if (minor == 1)
	    return in(ASCI_STAT0) & 2 ? TTY_READY_NOW: TTY_READY_SOON;
    return in(ASCI_STAT1) & 2 ? TTY_READY_NOW: TTY_READY_SOON;
}

/* kernel writes to system console -- never sleep! */
void kputchar(uint_fast8_t c)
{
	tty_putc(TTYDEV & 0xFF, c);
	if (c == '\n')
		tty_putc(TTYDEV & 0xFF, '\r');
}
