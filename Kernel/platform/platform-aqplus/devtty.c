#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <stdbool.h>
#include <tty.h>
#include <vt.h>
#include <devtty.h>
#include <aqplus.h>

static char tbuf1[TTYSIZ];
static uint8_t sleeping;
struct vt_repeat keyrepeat = { 40 , 4 };
static uint8_t kbd_timer;

uint8_t vtattr_cap = 0;	/* For the moment */

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

	/* FIXME: needs debounce somewhere */
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
		}
	}
}

static void keydecode(void)
{
	uint8_t c;
	/* Table index */
	c = keybyte * 6 + keybit;
	if (keymap[0] & 16)	/* shift */
		c += 48;
	c = keytab[c];
	/* TODO need to put some chars on control */
	if (keymap[0] & 32) {	/* control */
		if (c > 31 && c < 127)
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
