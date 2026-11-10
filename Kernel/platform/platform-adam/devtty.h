#ifndef __DEVTTY_DOT_H__
#define __DEVTTY_DOT_H__

extern int vdptty_ioctl(uint_fast8_t minor, uarg_t arg, char *ptr);
extern int vdptty_close(uint_fast8_t minor);

extern int8_t vt_twidth;
extern int8_t vt_tright;

extern void tty_pollirq(void);

#endif
