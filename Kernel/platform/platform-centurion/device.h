#ifndef __DEVICE_DOT_H__
#define __DEVICE_DOT_H__

extern void mod_control(uint8_t set, uint8_t clr);

/* centurion.S */
extern void dma_set_base(uint16_t base);
extern void dma_set_length(uint16_t count);
extern void dma_set_mode0(void);
extern void dma_enable(void);

#endif /* __DEVICE_DOT_H__ */
