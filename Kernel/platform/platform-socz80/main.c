#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <tty.h>
#include <printf.h>
#include <deveth.h>

uint16_t ramtop = PROGTOP;

void plt_idle(void)
{
    __asm
    halt
    __endasm;
}

uint8_t plt_param(char *p)
{
    used(p);
    return 0;
}

#define UART0_STATUS	0x00
#define UART0_DATA	0x01
#define UART1_STATUS	0x28
#define UART1_DATA	0x29

extern uint8_t irqwork;

void plt_interrupt(void)
{
    uint8_t st0 = in(UART0_STATUS);
    uint8_t st1 = in(UART1_STATUS);
    uint8_t ts = irqwork;
    uint8_t d;

    irqwork = 0;
    if (ts & 0xC0) {
        if (ts & 0x80) 	/* RX data */
            tty_inproc(1, in(UART0_DATA));
        if (ts & 0x40)		/* TX idle */
            tty_outproc(1);
    }
    if (st1 & 0xC0) {
        uart1_status = st1 & 0xFC;
        if (st1 & 0x80) 	/* RX data */
            tty_inproc(2, in(UART1_DATA);
        if (st1 & 0x40)		/* TX idle */
            tty_outproc(2);
    }
    if (ts & 1) {
        eth_poll();
        timer_interrupt();
    }
}

void pagemap_init(void)
{
    int i;
    /* 0/1/2 kernel, 3 initial common, 4+ to use */
    for (i = 4; i < 128 ; i++)
        pagemap_add(i);
    /*
     * The kernel boots with 3 as the common, list it last here so it also
     * gets given to init as the kernel kicks off the init stub. init will then
     * exec preserving this common and all forks will be copies from it.
     */
    pagemap_add(3);
}

void map_init(void)
{
}
