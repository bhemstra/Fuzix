#ifndef _DEVTTY_H
#define _DEVTTY_H

extern void tty_interrupt(void);
extern void kbd_poll(void);
extern void sio_init(void);

#endif
