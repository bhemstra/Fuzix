extern int gfx_ioctl(uint_fast8_t minor, uarg_t request, register char *data);
extern void set_border(uint8_t col);
extern void set_mode(void);
extern void load_character(uint8_t c, uint8_t *bits);
extern uint8_t vtcol;

#define KEY_ROWS	8
#define KEY_COLS	6

extern uint8_t keymap[8];
extern uint8_t keyboard[8][6];
extern uint8_t shiftkeyboard[8][6];

extern uint8_t vtright;
extern uint8_t vtwidth;
