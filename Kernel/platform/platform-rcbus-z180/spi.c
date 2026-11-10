/*-----------------------------------------------------------------------*/
/* CSI/O SPI driver                                                      */
/* 2014-12-27 Will Sowerbutts                                            */
/* 2014-12-29 Optimised for size/speed                                   */
/*                                                                       */
/* Updated for SC126 to use GPIO interface at port 0x0C			 */
/*-----------------------------------------------------------------------*/

#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <stdbool.h>
#include "config.h"
#include <z180.h>
#include <tinysd.h>
#include <rcbus-z180.h>

#define CSIO_CNTR_TE           (1<<4)   /* tx enable */
#define CSIO_CNTR_RE           (1<<5)   /* rx enable */
#define CSIO_CNTR_END_FLAG     (1<<7)   /* operation completed flag */

static uint8_t spi_slow[4];

extern uint8_t reverse_byte(uint8_t a);

void sd_spi_fast(void)
{
    spi_slow[1] = 0;
}

void sd_spi_slow(void)
{
    spi_slow[1] = 1;
}

void sd_spi_raise_cs(void)
{
    /* wait for idle */
    while(in(CSIO_CNTR) & (CSIO_CNTR_TE | CSIO_CNTR_RE));
    /* Set both CS bits back */
    gpio_set(0x0C, 0x0C);
}

void spi_select_port(uint8_t port)
{
    uint8_t c;

    while(in(CSIO_CNTR) & (CSIO_CNTR_TE | CSIO_CNTR_RE));
    gpio_set(0x0C, (~port & 3) << 2);

    if (spi_slow[port]) {
        c = in(CSIO_CNTR) & 0xf8; /* clear low three bits, gives fastest rate (clk/20) */
        c = c | 0x03;     /* set low two bits, clk/160 (can go down to clk/1280, see data sheet) */
        out(CSIO_CNTR, c);
    } else {
        c = in(CSIO_CNTR) & 0xf8; /* clear low three bits, gives fastest rate (clk/20) */
        out(CSIO_CNTR, c);
    }
}

/* SD is on SPI 1 */
void sd_spi_lower_cs(void)
{
    spi_select_port(1);
}

void sd_spi_tx_byte(uint_fast8_t byte)
{
    unsigned char c;
//    kprintf("[W%d]", byte);

    /* reverse the bits before we busywait */
    byte = reverse_byte(byte);

    /* wait for any current tx operation to complete */
    do{
        c = in(CSIO_CNTR);
    }while(c & CSIO_CNTR_TE);

    /* write the byte and enable txter */
    out(CSIO_TRDR, byte);
    out(CSIO_CNTR, c | CSIO_CNTR_TE);
}

uint_fast8_t sd_spi_rx_byte(void)
{
    unsigned char c;

    /* wait for any current tx or rx operation to complete */
    do {
        c = in(CSIO_CNTR);
    } while(c & (CSIO_CNTR_TE | CSIO_CNTR_RE));

    /* enable rx operation */
    out(CSIO_CNTR,  c | CSIO_CNTR_RE);

    /* wait for rx to complete */
    while(in(CSIO_CNTR) & CSIO_CNTR_RE);

    /* read byte */
    c = reverse_byte(in(CSIO_TRDR));
//    kprintf("[R%x]", c);
    return c;
}

