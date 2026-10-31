
extern int hawk_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int hawk_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag);
extern int hawk_open(uint_fast8_t minor, uint16_t flags);
extern int hawk_ioctl(uint_fast8_t minor, uarg_t request, char *data);

/* Asm helpers */
extern void dma_set_length(uint16_t len);	/* Counts up to FFFF */
extern void dma_set_base(uint16_t addr);
extern void dma_set_mode0(void);
extern void dma_enable(void);
