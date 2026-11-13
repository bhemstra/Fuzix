#ifndef __DEVTTY_DOT_H__
#define __DEVTTY_DOT_H__

extern void tty_poll(void);
extern uint8_t keyscan(void);
extern uint8_t vidpaper;
extern uint8_t vtborder;

extern int c64tty_ioctl(uint_fast8_t minor, uarg_t request, register char *data);

extern void vtputchar(uint8_t c);
#endif
