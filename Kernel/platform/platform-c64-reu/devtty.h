#ifndef __DEVTTY_DOT_H__
#define __DEVTTY_DOT_H__

extern uint8_t vtmouse;
extern uint8_t mousex, mousey;
extern uint8_t mousexh, mouseyh;
extern uint8_t mousemoved;
extern uint8_t mousetrack;

extern void tty_poll(void);
extern uint8_t keyread(void);
extern uint8_t vidpaper;
extern uint8_t vtborder;
extern void vtputchar(uint8_t ch);
extern int c64tty_ioctl(uint_fast8_t minor, uarg_t request, register char *data);
#endif
