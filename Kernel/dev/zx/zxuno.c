#include <kernel.h>
#include <printf.h>
#include <zxuno.h>

extern uint8_t fuller, kempston, kmouse, kempston_mbmask;

/*
 *	Support routines for the ZX Uno. Can be built into _DISCARD.
 *
 *	Turn on all the I/O devices and mark them present
 *	Set the CPU to 14Mhz
 *	Turn off all the contention we can
 *	Check for 50 v 60Hz (only 50 works right now)
 *	Turn on the video and MMU modes
 *
 *	We don't do anything with the MMU and video.
 */

#define UNO_CTRL	0xFC3B
#define UNO_DATA	0xFD3B
#define ULA_CTRL	0xBF3B
#define ULA_DATA	0xFF3B

uint8_t probe_zxuno(void)
{
	uint8_t n;
	uint8_t c;
	out(UNO_CTRL, 0xff);
	out(UNO_DATA, 0x00);

	/* Check if Uno is present */
	for (n = 0; n < 64; n++) {
		c = in(UNO_DATA);
		/* Don't get fooled by a single 0 read */
		if (c == 0 && n > 4)
			return 1;
		if (c < 32 || c > 127)
			return 0;
	}
	return 0;
}

static const uint8_t palette[] = {
	/* Normal */
	0x00,
	0x02,
	0x10,
	0x12,
	0x80,
	0x82,
	0x90,
	0x92,
	0x00,
	0x02,
	0x10,
	0x12,
	0x80,
	0x82,
	0x90,
	0x92,
	/* Bright */
	0x00,
	0x03,
	0x1C,
	0x1F,
	0xE0,
	0xE3,
	0xEC,
	0xFF,
	0x00,
	0x03,
	0x1C,
	0x1F,
	0xE0,
	0xE3,
	0xEC,
	0xFF
};

/* Turn on all the I/O devices, and fire up the turbos */
void configure_zxuno(void)
{
	uint8_t c;
	uint8_t d;
	uint8_t *p;

	out(UNO_CTRL, 0xFF);
	out(UNO_DATA, 0x00);

	kputs("ZX Uno Detected\n");
	for (c = 0; c < 64; c++) {
		d = in(UNO_DATA);
		if (d == 0) break;
		kputchar(d);
	}
	kputchar('\n');

	out(UNO_CTRL, 0);
	if (in(UNO_DATA) & 0x80)
		kputs("Warning: ZX Uno configuration is locked.\n");
	else {
		c = in(UNO_DATA);
		/* Contention off, Pentagon timing (as best), NMI off,
		   DIVMMC on */
		c &= ~0x10;
		c |= 0x66;
		out(UNO_DATA, c);
	}
	out(UNO_CTRL, 6);
	out(UNO_DATA, 0x12);	/* Plug in stick is Kempston, alt is fuller */
	kempston = 1;
	fuller = 1;
	kmouse = 1;

	/* Vroooomm.... */
	out(UNO_CTRL, 0x0B);
	c = in(UNO_DATA);
	c &= 0x3F;
	c |= 0x80;		/* 14MHz (don't set C0!!!) */
	out(UNO_DATA, c);

	out(UNO_CTRL, 0x0E);
	c = in(UNO_DATA);
	c &= ~0x80;		/* SD on */
	c |= 0x40;		/* Horizontal MMU and Timex video on */
	out(UNO_DATA, c);

	out(UNO_CTRL, 0x0F);
	c = in(UNO_DATA);
	c &= 0xF8;		/* ULAplus, Radistano, Timex on */
	out(UNO_DATA, c);

	/* FIXME: do we need to set radasctrl |= 3 */
	out(UNO_CTRL,  0xFB);
	if (in(UNO_DATA) & 1) 	/* 60 HZ */
		kputs("Warning 60Hz not yet supported.\n");

	p = palette;
	/* Initial palette */
	for (c = 0; c < 32; c++) {
		out(ULA_CTRL, c);
		out(ULA_DATA, *p);
		out(ULA_CTRL, c + 32);
		out(ULA_DATA, *p++);
	}
}

uint8_t locked_zxuno(void)
{
	out(UNO_CTRL, 0);
	return in(UNO_DATA) & 0x80;
}
