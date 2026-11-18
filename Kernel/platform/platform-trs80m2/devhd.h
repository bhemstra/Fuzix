#ifndef __DEVHD_DOT_H__
#define __DEVHD_DOT_H__

/* public interface */
extern int hd_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int hd_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int hd_open(uint_fast8_t minor, uint16_t flag);

extern void hd_probe(void);

#ifdef _HD_PRIVATE

#define HD_WPBITS	0xC0	/* Write protect and IRQ (not used) */
#define HD_CTRL	0xC1	/* Reset and enable bits */
#define HD_DATA	0xC8
#define HD_PRECOMP	0xC9	/* W/O */
#define HD_ERR	0xC9		/* R/O */
#define HD_SECCNT	0xCA
#define HD_SECNUM	0xCB
#define HD_CYLLO	0xCC
#define HD_CYLHI	0xCD
#define HD_SDH	0xCE
#define HD_STATUS	0xCF	/* R/O */
#define HD_CMD	0xCF

#define HDCMD_RESTORE	0x10
#define HDCMD_READ	0x20
#define HDCMD_WRITE	0x30
#define HDCMD_VERIFY	0x40	/* Not on the 1010 later only */
#define HDCMD_FORMAT	0x50
#define HDCMD_INIT	0x60	/* Ditto */
#define HDCMD_SEEK	0x70

#define RATE_4MS	0x08	/* 4ms step rate for hd (conservative) */

#define HDCTRL_SOFTRESET	0x10
#define HDCTRL_ENABLE		0x08
#define HDCTRL_WAITENABLE	0x04

/* SDH register: the Model II boot ROM uses plain CRC mode with the
   sector size in bits 5-6 */
#define HDSDH_ECC		0x00
#define HDSDH_512		0x20

/* Seek and restore low 4 bits are the step rate, read/write support
   multi-sector mode but not all emulators do .. */

#define MAX_HD	4

extern struct minipart parts[MAX_HD];

extern uint8_t hd_waitready(void);
extern uint8_t hd_waitdrq(void);
extern uint8_t hd_xfer(bool is_read, uint8_t *dptr);
extern uint8_t hd_secbase;

/* helpers in common memory for the block transfers */
extern int hd_xfer_in(uint8_t *addr);
extern int hd_xfer_out(uint8_t *addr);

#endif
#endif /* __DEVHD_DOT_H__ */
