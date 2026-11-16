#include <kernel.h>
#include <kdata.h>
#include <input.h>
#include <devgfx.h>
#include <devinput.h>

#define STICK	0x00
static uint8_t old_stick;

#define CHROMA0	0x7C
#define CHROMA1	0x7E

static uint8_t old_cj[2];

static char buf[32];
static struct s_queue kqueue = {
 buf, buf, buf, sizeof(buf), 0, sizeof(buf) / 2
};

/* Queue a character to the input device */
void queue_input(uint8_t c)
{
    insq(&kqueue, c);
    wakeup(&kqueue);
}

/* If both are present number the Chroma joysticks 1 and 2 */
static int chroma_js(uint8_t *slot, uint8_t n, uint8_t v)
{
    uint8_t k = 0;
    if (v == old_cj[n])
        return 0;
    old_cj[n] = v;
    if (v & 1)
        k |= STICK_DIGITAL_L;
    if (v & 2)
        k |= STICK_DIGITAL_R;
    if (v & 4)
        k |= STICK_DIGITAL_U;
    if (v & 8)
        k |= STICK_DIGITAL_D;
    if (v & 16)
        k |= BUTTON(0);
    *slot++ = STICK_DIGITAL | (n + 1);
    *slot = k;
    return 2;
}

int plt_input_read(uint8_t *slot)
{
    uint_fast8_t r, k;
    if (remq(&kqueue, &r)) {
        remq(&kqueue, &k);
	*slot++ = KEYPRESS_CODE | r;
	*slot++ = k;
	return 2;
    }

    if (has_chroma) {
        if (chroma_js(slot, 0, ~in(CHROMA0)))
	    return 2;
        if (chroma_js(slot, 1, ~in(CHROMA1)))
	    return 2;
    }
    /* Clashes with Alpha joystick */
    if (has_hrg1)
        return 0;

    r = ~in(STICK);
    if (r == old_stick)
        return 0;

    old_stick = r;

    k = 0;
    /* Legacy joystick encoding U|D = FIRE */
    if ((r & 3) == 3) {
        r &= ~3;
        r |= 16;
    }
    if (r & 1)
        k = STICK_DIGITAL_U;
    if (r & 2)
        k |= STICK_DIGITAL_D;
    if (r & 4)
        k |= STICK_DIGITAL_L;
    if (r & 8)
        k |= STICK_DIGITAL_R;
    if (r & 16)
        k |= BUTTON(0);
    *slot++ = STICK_DIGITAL;
    *slot = k;
    return 2;
}

void plt_input_wait(void)
{
    psleep(&kqueue);	/* We wake this on timers so it works for sticks */
}

int plt_input_write(uint_fast8_t flag)
{
    flag;
    udata.u_error = EINVAL;
    return -1;
}

void poll_input(void)
{
    if ((!has_hrg1 && ~in(STICK) != old_stick) ||
	(has_chroma && (old_cj[0] != ~in(CHROMA0) || old_cj[1] != ~in(CHROMA1))))
	    wakeup(&kqueue);
}
