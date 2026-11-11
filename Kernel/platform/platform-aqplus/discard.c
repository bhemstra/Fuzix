#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <vt.h>
#include <aqplus.h>

/* Everything in here is discarded after init starts */

void init_hardware_c(void)
{
	ramsize = 512;
	procmem = 512 - 64;
	vtinit();
}

/* Kernel is at 0x20-23, boot common is at 0x23 */
void pagemap_init(void)
{
	int i;

	/* Add the pages not in use by the kernel */
	for (i = 0x24; i <= 0x3F; i++)
		pagemap_add(i);
	/* finally add the common area */
	pagemap_add(0x23);
}

void map_init(void)
{
}

void device_init(void)
{
	disk_probe();
}
