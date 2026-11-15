#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <vt.h>
#include <devtty.h>
#include <graphics.h>
#include <aqplus.h>

static char tbuf1[TTYSIZ];
static uint8_t sleeping;
struct vt_repeat keyrepeat = { 40 , 4 };
static uint8_t kbd_timer;

uint8_t vtmode = 0;
uint8_t vtwidth = 80;
uint8_t vtright = 79;
uint8_t vtborder = 0;

uint8_t vtattr_cap = VTA_INVERSE;

struct s_queue ttyinq[NUM_DEV_TTY + 1] = {	/* ttyinq[0] is never used */
	{NULL, NULL, NULL, 0, 0, 0},
	{tbuf1, tbuf1, tbuf1, TTYSIZ, 0, TTYSIZ / 2},
};

tcflag_t termios_mask[NUM_DEV_TTY + 1] = {
	0,
	_CSYS,
};

void tty_setup(uint_fast8_t minor, uint_fast8_t flags)
{
}

int tty_carrier(uint_fast8_t minor)
{
	return 1;
}

void tty_putc(uint_fast8_t minor, uint_fast8_t c)
{
	char ch = c;
	vtoutput(&ch, 1);
}

void tty_sleeping(uint_fast8_t minor)
{
	sleeping |= (1 << minor);
}

ttyready_t tty_writeready(uint_fast8_t minor)
{
	return TTY_READY_NOW;
}

void tty_data_consumed(uint_fast8_t minor)
{
}

/* kernel writes to system console -- never sleep! */

void kputchar(uint_fast8_t c)
{
	if (c == '\n')
		kputchar('\r');
	tty_putc(1, c);
}

static uint8_t shiftmask[8] = {
	0x30, 0, 0, 0, 0, 0, 0, 0
};

uint8_t keymap[8];
uint8_t keyin[8];
static unsigned keysdown;
static unsigned keybyte;
static unsigned keybit;
static unsigned newkey;

static void keyproc(void)
{
	int i;
	uint8_t key;

	if (keyscan()) {
		/* Something changed */
		for (i = 0; i < 8; i++) {
			key = keyin[i] ^ keymap[i];
			if (key) {
				int n;
				int m = 1;
				for (n = 0; n < 6; n++) {
					if ((key & m) && (keymap[i] & m)) {
						if (!(shiftmask[i] & m))
							keysdown--;
					}
					if ((key & m) && !(keymap[i] & m)) {
						if (!(shiftmask[i] & m)) {
							keysdown++;
							newkey = 1;
							keybyte = i;
							keybit = n;
						}
					}
					m += m;
				}
			}
			keymap[i] = keyin[i];
			/* If we saw a new key but something then changed under
			   us assume it's bouncing */
			if (newkey && keyscan())
				newkey = 0;
		}
	}
}

static void keydecode(void)
{
	uint8_t c;
	/* Table index */
	if (keymap[0] & 16)	/* shift */
		c = shiftkeyboard[keybyte][keybit];
	else
		c = keyboard[keybyte][keybit];

	if (keymap[0] & 32) {	/* control */
		/* Borrow some codes for missing keys */
		if (c == '(')
			c = '{';
		else if (c == ')')
			c = '}';
		else if (c == '8')
			c = '[';
		else if (c == '9')
			c = ']';
		else if (c == '1')
			c = '|';
		else if (c > 31 && c < 127)
			c &= 31;
	}
	vt_inproc(1, c);
}

void tty_poll(void)
{
	if (keysdown || anykey()) {
		newkey = 0;
		keyproc();
		if (keysdown && keysdown < 3) {
			if (newkey) {
				keydecode();
				kbd_timer = keyrepeat.first;
			} else if (! --kbd_timer) {
				keydecode();
				kbd_timer = keyrepeat.continual;
			}
		}
	}
}

void do_beep(void)
{
}

/* Base colours are BGR, second set are more misc */
static uint8_t colmap[32] = {
	0, 4, 1, 5,	/* black blue red magenta */
	2, 6, 3, 7,	/* green, cyan, yellow, white */
	/* No bright forms */
	0, 4, 1, 5,	/* black blue red magenta */
	2, 6, 3, 7,	/* green, cyan, yellow, white */
	/* Native */
	0, 1, 2, 3, 4, 5, 6, 7,
	8, 9, 10, 11, 12, 13, 14, 15
};


void vtattr_notify(void)
{
	if (vtattr & VTA_INVERSE)
		vtcol = (colmap[vtpaper & 31] << 4) | colmap[vtink & 31];
	else
		vtcol = (colmap[vtink & 31] << 4) | colmap[vtpaper & 31];
}

static struct display modes[2] = {
	/* Text 80 */
	{
		0,
		80, 25,
		80, 25,
		255, 255,
		FMT_TEXT,
		HW_UNACCEL,
		GFX_MULTIMODE | GFX_TEXT,
		4,
		0,	/* To do */
		80,
		25
	},
	/* Text 40 */
	{
		1,
		40, 25,
		40, 25,
		255, 255,
		FMT_TEXT,
		HW_UNACCEL,
		GFX_MULTIMODE | GFX_TEXT | GFX_VBLANK,
		4,
		0,	/* To do */
		40,
		25
	}
	/* TODO: graphics overlay modes */
};

static struct fontinfo font = {
	0, 255, 128, 255, FONT_INFO_8X8
};

int gfx_ioctl(uint_fast8_t minor, uarg_t request, register char *data)
{
	uint8_t m = vtmode;
	unsigned base = 0;
	unsigned limit = 255;
	uint8_t cbit[8];
	/* Until/if we do multi console */
	if (minor != 1)
		return tty_ioctl(minor, request, data);
	switch(request)
	{
	case VTFONTINFO:
		return uput(&font, data, sizeof(struct fontinfo));
	case VTSETUDG:
		base = ugetc(data++);
		if (base < 128)
			break;
		limit = base;
	case VTSETFONT:
		while(base <= limit) {
			if (uget(cbit, data, 8) == -1)
				return -1;
			data += 16;
			load_character(base, cbit);
			++base;
		}
		return 0;
	case GFXIOC_GETMODE:
		m = ugetc(data);
		if (m > 1)
			break;
	case GFXIOC_GETINFO:
		return uput(modes + m, data, sizeof(struct display));
	case GFXIOC_SETMODE:
		m = ugetc(data);
		if (m > 1)
			break;
		vtmode = m;
		if (m) {
			vtwidth = 40;
			vtright = 39;
		} else {
			vtwidth = 80;
			vtright = 79;
		}
		set_mode();
		set_border(vtborder);
		clear_lines(0, 25);
		return 0;
	case GFXIOC_WAITVB:
		while(in(0xFD) & 1);
		return 0;
	case VTBORDER:
		vtborder = colmap[ugetc(data) & 31];
		set_border(vtborder);
		return 0;
	}
	return vt_ioctl(minor, request, data);
}
