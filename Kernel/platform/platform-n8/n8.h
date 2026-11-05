#ifndef __N8_H

int n8tty_ioctl(uint_fast8_t minor, uarg_t arg, char *ptr);
int n8tty_close(uint_fast8_t minor);

#define TMS9918A_DATA	0x98
#define TMS9918A_CTRL	0x99

/* For console */
extern uint8_t vt_twidth, vt_tright;
extern uint8_t tms9918a_type;

#endif
