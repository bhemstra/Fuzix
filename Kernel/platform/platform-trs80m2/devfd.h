#ifndef __DEVFD_DOT_H__
#define __DEVFD_DOT_H__

/* public interface */
int fd_read(uint8_t minor, uint8_t rawflag, uint8_t flag);
int fd_write(uint8_t minor, uint8_t rawflag, uint8_t flag);
int fd_open(uint8_t minor, uint16_t flag);

/* DMA transfer helper in trs80m2.s */
extern uint8_t fd_dma(uint8_t cmd);

/* Shared with the helper */
extern uint8_t fd_page;
extern uint8_t fd_wr;
extern uint8_t *fd_addr;
extern uint16_t fd_len;

#endif /* __DEVFD_DOT_H__ */
