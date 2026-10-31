#include <kernel.h>
#include <blkdev.h>
#include <devsd.h>
#include <z80softspi.h>

#ifdef CONFIG_SD

__sfr __banked __at 0xDF10	sd_data;
__sfr __banked __at 0xDF11	sd_ctrl;
__sfr __banked __at 0xDF12	sd_status;

static uint_fast8_t fast;

/*
 *	SD card bit bang. For now just a single card to get us going. We
 *	should fix the cs asm to allow for multiple cards
 *
 *	Bits
 *	7: MISO
 *	6: CLK
 *	5: \CS card 0
 *	4: MOSI
 */

void sd_spi_raise_cs(void)
{
    sd_ctrl |= 0x02;
}

void sd_spi_lower_cs(void)
{
    sd_ctrl &= ~0x02;
}

void sd_spi_clock(bool go_fast) __z88dk_fastcall
{
  fast = go_fast;
  if (go_fast)
      sd_ctrl |= 0x04;
  else
      sd_ctrl &= 0xF7;
}

void sd_spi_tx_byte(uint8_t byte) __z88dk_fastcall
{
  if (!fast)
    while(!(sd_status & 0x80));
  sd_data = byte;
}

uint8_t sd_spi_rx_byte(void)
{
  if (fast) {
    sd_data = 0xFF;
    return sd_data;
  }
  while(!(sd_status & 0x80));
  sd_data = 0xFF;
  while(!(sd_status & 0x80));
  return sd_data;
}

COMMON_MEMORY

bool sd_spi_rx_sector(void) __naked
{
  __asm
    ld a, (_blk_op+BLKPARAM_IS_USER_OFFSET)
    ld hl, (_blk_op+BLKPARAM_ADDR_OFFSET)
    or a
    jr nz, rx_user
    call map_buffers
    jr rx_go
rx_user:
    call map_proc_always
rx_go:
    ld bc,#0xDF10
    ld de,#0x80FF	; D = 128 groups of 4, E = dummy byte out
rx_next:
    out (c),e
    in a,(c)
    ld (hl),a
    inc hl
    out (c),e
    in a,(c)
    ld (hl),a
    inc hl
    out (c),e
    in a,(c)
    ld (hl),a
    inc hl
    out (c),e
    in a,(c)
    ld (hl),a
    inc hl
    dec d
    jr nz, rx_next
    jp map_kernel_restore
  __endasm;
}

bool sd_spi_tx_sector(void) __naked
{
  __asm
    ld a, (_blk_op+BLKPARAM_IS_USER_OFFSET)
    ld hl, (_blk_op+BLKPARAM_ADDR_OFFSET)
    or a
    jr nz, tx_user
    call map_buffers
    jr tx_go
tx_user:
    call map_proc_always
tx_go:
    ld bc,#0xDF10
    ld d,#0x80
tx_next:
    ld a,(hl)
    out (c),a
    inc hl
    ld a,(hl)
    out (c),a
    inc hl
    ld a,(hl)
    out (c),a
    inc hl
    ld a,(hl)
    out (c),a
    inc hl
    dec d
    jr nz, tx_next
    jp map_kernel_restore
  __endasm;
}

#endif
