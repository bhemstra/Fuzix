/*
 *	SPI glue for the SocZ80. Based on Will Sowerbutts's UZI180 for SocZ80
 *	and his implementation for the N8VEM Mark 4
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <stdbool.h>
#include "config.h"
#include <blkdev.h>

/* We should revisit this if we are willing to rely on the later VHDL
   being used. At that point we've got mode setting but more importantly
   the tx port is r/w as rx/tx so the port can sit in (c) */

#define SD_SPI_CHIPSEL	0x30
#define SD_SPI_STATUS	0x31
#define SD_SPI_TX	0x32
#define SD_SPI_RX	0x33
#define SD_SPI_DIVISOR	0x34
#define SD_SPI_GPIO	0x35	/* only on later VHDL */
#define SD_SPI_MODE	0x36	/* only on later VHDL */

void sd_spi_mode0(void)
{
  sd_spi_mode = 0;
}

void sd_spi_clock(bool go_fast)
{
//  sd_spi_mode0();
  /* Currently the sd driver just uses 'slow' and 'fast'. That's ok for
     sd but mmc really needs to be 16MHz */
  if (go_fast)
    out(SD_SPI_DIVISOR, 3);
  else
    out(SD_SPI_DIVISOR, 255);
}

void sd_spi_raise_cs(void)
{
  out(SD_SPI_CHIPSEL, 0xFF);
}

void sd_spi_lower_cs(void)
{
  out(SD_SPI_CHIPSEL, 0xFE);
}

void sd_spi_transmit_byte(unsigned char byte)
{
  out(SD_SPI_TX, byte);
}

uint8_t sd_spi_receive_byte(void)
{
  uint8_t r;
  out(SD_SPI_TX, 0xFF);
  r = in(SD_SPI_RX);
  return r;
}

#if 0	// TODO

COMMON_MEMORY

bool sd_spi_receive_sector(void) __naked
{
  __asm
    ld a, (_blk_op+BLKPARAM_IS_USER_OFFSET);
    ld hl, (_blk_op+BLKPARAM_ADDR_OFFSET);
    or a	; Set the Z flag up and save it, dont do it twice
    push af
    call nz,map_proc_always
    call rx256
    call rx256
xferout:
    pop af
    call nz,map_kernel
    ret
rx256:
    ld a,#0xFF
    ld bc, #SD_SPI_RX	 ; b = 0, c = port
rx256_1:
    out (SD_SPI_TX),a   ; we could use (c),a on newer VHDL
    ini
    jr nz, rx256_1
    ret
  __endasm;
}

bool sd_spi_transmit_sector(void) __naked
{
  __asm
    ld a, (_blk_op+BLKPARAM_IS_USER_OFFSET)
    ld hl, (_blk_op+BLKPARAM_ADDR_OFFSET)
    or a	; Set the Z flag up and save it, dont do it twice
    push af
    call nz,map_proc_always
    ld a,#0xFF
    ld bc, #SD_SPI_TX
    otir
    otir
    jr xferout
  __endasm;
}
#endif
