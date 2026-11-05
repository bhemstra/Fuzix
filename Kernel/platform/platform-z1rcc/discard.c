#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <tinyide.h>
#include <tinysd.h>
#include "config.h"
#include <z180.h>
#include <ds1302.h>
#include <tty.h>
#include "z1rcc.h"

void init_hardware_c(void)
{
	ramsize = 512;
	procmem = 512 - 64;
	/* zero out the initial bufpool */
	memset(bufpool, 0, (char *) bufpool_end - (char *) bufpool);
}

void pagemap_init(void)
{
	int i;

	/* Low 512K only, bank 0 is the kernel */
	for (i = 0x11; i < (512 >> 2); i += 0x10)
		pagemap_add(i);
#ifdef CONFIG_RTC_DS1302
	ds1302_init();
	if (ds1302_present)
		kputs("DS1302 detected at 0x0C.\n");
#endif
}

void map_init(void)
{
	/* clone udata and stack into a regular process bank, return with common memory
	   for the new process loaded */
	copy_and_map_proc(&init_process->p_page);
	/* kernel bank udata (0x300 bytes) is never used again -- could be reused? */
}

uint_fast8_t plt_param(char *p)
{
	return 0;
}

void device_init(void)
{
	ide_probe();
}
