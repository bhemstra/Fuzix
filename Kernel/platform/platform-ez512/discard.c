#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <tinydisk.h>
#include <tinyide.h>
#include <tinysd.h>
#include <ds1302.h>

/*
 *	Everything in this file ends up in discard which means the moment
 *	we try and execute init it gets blown away. That includes any
 *	variables declared here so beware!
 */

/*
 *	We get passed each kernel command line argument. if we return 1 then
 *	we claim it, if not it gets passed to init. It's perfectly acceptable
 *	to act on a match and return to also pass it to init if you need to.
 */
uint_fast8_t plt_param(unsigned char *p)
{
	return 0;
}

/*
 *	Set up our memory mappings. This is not needed for simple banked memory
 *	only more complex setups such as 16K paging.
 */
void map_init(void)
{
}

/*
 *	Add all our free pages to the system. They are numbered in pairs as
 *	the system has some h/w logic to fake the 512K RAM/ROM enough for ROMWBW
 *	but not us.
 */
void pagemap_init(void)
{
	uint8_t i;
	/* Bank 3E is kernel low, bank 3F is upper RAM, the rest
	   are in bits 0-2/6 with bit 7 set. 3 and 4 control RTS stuff but
	   we don't use that directly */
	for (i = 0x00; i < 0x08; i ++)
		pagemap_add(0x80 + i);
	for (i = 0x00; i < 0x06; i++)
		pagemap_add(0xC0 + i);
}

/*
 *	Called after interrupts are enabled in order to enumerate and set up
 *	any devices. In our case we set up the SIO and then probe the CF.
 */

void device_init(void)
{
	/* Probe the timers first as IDE needs a timer of some form */
	/* DS1302 can be at 0xC0 only */
	ds1302_init();
	ide_probe();
	pio_setup();
	kputs("sd0: ");
	sd_probe();
}
