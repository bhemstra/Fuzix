extern int fd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int fd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int fd_close(uint_fast8_t minor);
extern int fd_open(uint_fast8_t minor, uint16_t flag);

extern uint8_t fd_reset(void);
extern uint8_t fd_operation(void);
extern uint8_t fd_seek(void);
