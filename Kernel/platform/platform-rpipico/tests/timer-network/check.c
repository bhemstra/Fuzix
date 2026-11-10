#include <kernel.h>
#include <blkdev.h>
#include <net_w5x00.h>
#include <hardware/spi.h>
#include <hardware/gpio.h>
#include <pico/stdlib.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include "../../wiznet_spi.h"
extern volatile bool sd_spi_busy, sd_spi_active;
void device_init(void);
void sd_rawinit(void);
void sd_spi_raise_cs(void);
void sd_spi_lower_cs(void);
uint_fast8_t sd_spi_rx_byte(void);
struct u_data udata;
struct test_blk_op blk_op;
spi_inst_t fixture_spi[2];
static uint64_t clock_us=1000000, target;
static unsigned ticks, tty_ticks, polls, retries, byte_index, reply_index;
static bool release_sd;
static bool levels[30], raise_during_poll, try_poll_during_spi;
static uint8_t replies[16];
static void (*tick_cb)(unsigned);
static gpio_irq_callback_t gpio_cb;
int fixture_noop(void) { return 0; }
irqflags_t di(void) { return 123; }
void irqrestore(irqflags_t irq) { assert(irq==123); }
void timer_interrupt(void) { assert(udata.u_ininterrupt); ticks++; clock_us+=137; }
void tty_interrupt(void) { assert(udata.u_ininterrupt); tty_ticks++; }
void devsd_init(void) {}
uint_fast8_t sd_spi_try_release(void) { assert(!sd_spi_active); if (!release_sd) return 1; sd_spi_raise_cs(); return 0; }
void netdev_init(void) { wiz_spi_init(); }
void w5x00_poll(void) { polls++; if(raise_during_poll) gpio_cb(21,GPIO_IRQ_EDGE_FALL); }
void update_us_since_boot(absolute_time_t *t,uint64_t us) { *t=us; }
uint64_t to_us_since_boot(absolute_time_t t) { return t; }
uint64_t time_us_64(void) { return clock_us; }
void hardware_alarm_claim(unsigned n) { assert(n==0); }
void hardware_alarm_set_callback(unsigned n,void (*cb)(unsigned)) { assert(n==0); tick_cb=cb; }
void hardware_alarm_force_irq(unsigned n) { assert(n==0); }
bool hardware_alarm_set_target(unsigned n,absolute_time_t t) {
    assert(n==0);
    if(retries) { clock_us=t+10001; retries--; }
    if(t<=clock_us) return true;
    target=t; return false;
}
void irq_set_enabled(unsigned n,bool enabled) { (void)n; assert(enabled); }
void gpio_init(unsigned pin) { assert(pin<30); }
void gpio_set_dir(unsigned pin,bool out) { assert(pin<30); (void)out; }
void gpio_pull_up(unsigned pin) { assert(pin<30); levels[pin]=true; }
void gpio_set_function(unsigned pin,unsigned fn) { assert(pin<30); (void)fn; }
void gpio_put(unsigned pin,bool value) { assert(pin<30); levels[pin]=value; if(pin==17 && !value) byte_index=0; }
bool gpio_get(unsigned pin) { assert(pin<30); return levels[pin]; }
void gpio_set_irq_callback(gpio_irq_callback_t cb) { gpio_cb=cb; }
void gpio_set_irq_enabled(unsigned pin,unsigned mask,bool enabled) { assert(pin==21 && mask==GPIO_IRQ_EDGE_FALL && enabled); }
unsigned spi_init(spi_inst_t *spi,unsigned baud) { (void)spi; return baud; }
unsigned spi_set_baudrate(spi_inst_t *spi,unsigned baud) { (void)spi; return baud; }
void spi_set_format(spi_inst_t *spi,unsigned bits,unsigned a,unsigned b,unsigned c) { (void)spi; (void)a; (void)b; (void)c; assert(bits==8); }
int spi_write_read_blocking(spi_inst_t *spi,const uint8_t *tx,uint8_t *rx,unsigned n) {
    assert(spi==spi0 && !levels[17] && n==1);
    (void)tx;
    unsigned before=polls;
    if(try_poll_during_spi) { wiz_poll(); assert(polls==before); }
    *rx=byte_index++==3 ? replies[reply_index++] : 0;
    assert(reply_index<=sizeof(replies)); return n;
}
int spi_write_blocking(spi_inst_t *spi,const uint8_t *p,unsigned n) { (void)spi; (void)p; return n; }
int spi_read_blocking(spi_inst_t *spi,uint8_t filler,uint8_t *p,unsigned n) { (void)spi; unsigned before=polls;
    if(try_poll_during_spi) { wiz_poll(); assert(polls==before); }
    memset(p,filler,n); return n; }
int main(int argc,char **argv)
{
    assert(argc==2);
    if(!strcmp(argv[1],"phase") || !strcmp(argv[1],"missed") || !strcmp(argv[1],"race")) {
        device_init();
        tick_cb(0);
        assert(target==1010000 && ticks==1 && tty_ticks==1 && !udata.u_ininterrupt);
        if(!strcmp(argv[1],"phase")) {
            for(unsigned i=2;i<=1000;i++) { clock_us=target; tick_cb(0); assert(target==1000000+(uint64_t)i*10000); }
        } else if(!strcmp(argv[1],"missed")) {
            clock_us=1050071; tick_cb(0); assert(target==1060000);
        } else {
            clock_us=target; retries=2; tick_cb(0); assert(target==1060000 && !retries);
        }
        /* The actual timer path must consume pending network work. */
        gpio_cb(21,GPIO_IRQ_EDGE_FALL); unsigned before=polls;
        clock_us=target; tick_cb(0); assert(polls==before+1 && !wiz_irq_pending);
    } else if(!strcmp(argv[1],"pending")) {
        wiz_poll(); assert(!polls);
        wiz_spi_init(); wiz_poll(); assert(!polls);
        gpio_cb(21,GPIO_IRQ_EDGE_FALL); assert(wiz_irq_pending && !polls);
        wiz_poll(); assert(polls==1 && !wiz_irq_pending);
        wiz_poll(); assert(polls==1);
        levels[21]=false; wiz_poll(); wiz_poll(); assert(polls==3);
        levels[21]=true; raise_during_poll=true;
        gpio_cb(21,GPIO_IRQ_EDGE_FALL); wiz_poll(); assert(polls==4 && wiz_irq_pending);
        raise_during_poll=false; wiz_poll(); assert(polls==5 && !wiz_irq_pending);
    } else if(!strcmp(argv[1],"spi")) {
        wiz_spi_init(); sd_rawinit(); assert(!sd_spi_busy);
        gpio_cb(21,GPIO_IRQ_EDGE_FALL); sd_spi_lower_cs();
        assert(sd_spi_busy); wiz_poll(); assert(!polls && wiz_irq_pending);
        sd_spi_raise_cs(); wiz_poll(); assert(polls==1 && !wiz_irq_pending);
        gpio_cb(21,GPIO_IRQ_EDGE_FALL); try_poll_during_spi=true;
        w5x00_readsb(0,0); assert(polls==1 && wiz_irq_pending);
        wiz_poll(); assert(polls==2 && !wiz_irq_pending);
        gpio_cb(21,GPIO_IRQ_EDGE_FALL); release_sd=true; sd_spi_rx_byte();
        assert(polls==2 && wiz_irq_pending); /* Includes clocks with CS high. */
        wiz_poll(); assert(polls==3 && !wiz_irq_pending);
        sd_spi_lower_cs(); gpio_cb(21,GPIO_IRQ_EDGE_FALL); release_sd=true;
        wiz_poll(); assert(polls==4 && !wiz_irq_pending && !sd_spi_busy);
    } else if(!strcmp(argv[1],"normal")) {
        wiz_spi_init(); replies[0]=0x12; replies[1]=0x34;
        assert(w5x00_readsw(0,0x24)==0x1234 && reply_index==2);
    } else abort();
    puts(argv[1]);
}
