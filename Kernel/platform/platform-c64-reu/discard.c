#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <tinyide.h>

extern uint16_t reu_size;

void map_init(void)
{
	procmem = 48 * (reu_size + 1);
	ramsize = 64 * (reu_size + 1);
}

/* Number our pages 1..n. They are actually indexes into an array
  as the swap operation keeps moving the logical/physical mapping */

void pagemap_init(void)
{
	unsigned pages = reu_size;
	while(pages)
		pagemap_add(pages--);
}

uint_fast8_t plt_param(char *p)
{
    return 0;
}

void device_init(void)
{
	if (reu_size == 0)
		panic("REU required");
	kprintf("REU: %uKib\n", reu_size << 6);
#ifdef CONFIG_TD_IDE
	ide_probe();
#endif
}

