#include <kernel.h>
#include <tinydisk.h>
#include <tinysd.h>
#include <z80softspi.h>

#ifdef CONFIG_TD_SD

/*
 *	SD card bit bang. For now just a single card to get us going. We
 *	should fix the cs asm to allow for multiple cards
 *
 *	Bits
 *	7: MISO
 *	4: CLK
 *	3: \CS card 0
 *	0: MOSI
 */

uint16_t pio_c;

/* TODO: check pin and if change also do direction */
void pio_setup(void)
{
    spi_piostate = 0xE6;

    pio_c = 0x03;
    spi_port = 0x02;

    /* Pin names in brackets are mapping onto Gluino */
    /* Data on PIOB bit 0 (D11 / CIPO */
    /* Clock on PIOB bit 4 (D13 / SCL) */
    /* CS on PIOB bit 3 (D10 / SS) */
    /* Data on PIOB bit 7 (D12 /COPI) */
    spi_data = 0x01;
    spi_clock = 0x10;

    out16(pio_c, 0xCF);		/* Mode 3 */
    out16(pio_c, 0xE6);		/* MISO input, unused as input (so high Z) */
    out16(pio_c, 0x07);		/* No interrupt, no mask */
}

void sd_spi_raise_cs(void)
{
    out16(spi_port, spi_piostate |= 0x08);
}

void sd_spi_lower_cs(void)
{
    spi_piostate &= ~0x08;
    out16(spi_port, spi_piostate);
}

void sd_spi_fast(void)
{
}

void sd_spi_slow(void)
{
}

#endif
