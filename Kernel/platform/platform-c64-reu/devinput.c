#include <kernel.h>
#include <kdata.h>
#include <input.h>
#include <devinput.h>
#include <devtty.h>
#include <tty.h>

/*
 *	TODO Port 2 is joystick on 0xDC00 bits 4-0
 *	4: fire 3: right 2: left 1: down 0: up
 ;	low = active
 */

static uint8_t buf[32];

static struct s_queue kqueue = {
    buf, buf, buf, sizeof(buf), 0, sizeof(buf) / 2
};

/* Queue a character to the input device */
void queue_input(uint8_t c)
{
    insq(&kqueue, c);
    wakeup(&kqueue);
}

static uint8_t oldbut;

int plt_input_read(uint8_t *slot)
{
    static uint8_t j;
    uint8_t r, k;
    irqflags_t irq;

    /* Key event */
    if (remq(&kqueue, &r)) {
        remq(&kqueue, &k);
	*slot++ = KEYPRESS_CODE | r;
	*slot = k;
	return 2;
    }
    /* Mouse event */
    if (vtmouse == VTMOUSE_INPUT) {
        irq = di();
        /* Button change or movement if tracking */
        /* Read the buttons off the CIA */
        r = *((volatile uint8_t *)0xDC00) & 0x11;
        if (r != oldbut || (mousetrack && mousemoved)) {
            k = 0;
            if (!(r & 0x10))
                k |= BUTTON(0);
            if (!(r & 0x01))
                k |= BUTTON(1);
            *slot++ = MOUSE_ABS;
            *slot++ = k;
            *slot++ = mousex;
            *slot++ = mousexh;
            *slot++ = mousey;
            *slot++ = mouseyh;
            mousemoved = 0;
            oldbut = r;
        }
        irqrestore(irq);
    }
    return 0;
}

void plt_input_wait(void)
{
    psleep(&kqueue);	/* We wake this on timers so it works for sticks */
}

void poll_input(void)
{
    uint8_t r = *((volatile uint8_t *)0xDC00) & 0x11;
    if (r != oldbut || (mousetrack && mousemoved)) {
        if (vtmouse == 1)
            wakeup(&kqueue);
        else if (vtmouse == 2) {
            uint16_t v = (mousexh << 8) | mousex;
            oldbut = r;
            r = 0x20;
            /* FIXME: should track shift/meta/ctrl here
               as bits 2 3 4 */
            /* 00 = left 01 = right 10 */
            /* FIXME: if we go from up to both down we should generate
               two events! */
            if ((oldbut & 0x11) == 0x11)
                r |= 3;
            if (!(oldbut & 0x01))
                r |= 1;

            /* keyboard event codes */
            /* Use the X10 style tracking code */
            tty_inproc(1, 27);
            tty_inproc(1, '[');
            tty_inproc(1, 'M');
            tty_inproc(1, r);
            tty_inproc(1, 0x21 + (v >> 3));
            tty_inproc(1, 0x21 + (mousey >> 3));
            mousemoved = 0;
        }
    }
}

int plt_input_write(uint8_t flag)
{
    flag;
    udata.u_error = EINVAL;
    return -1;
}
