#include <kernel.h>
#include <timer.h>
#include <kdata.h>
#include <printf.h>
#include <devtty.h>
#include <blkdev.h>
#include <zxuno.h>

extern uint8_t fuller, kempston, kmouse, kempston_mbmask;


void pagemap_init(void)
{
	if (probe_zxuno())
		configure_zxuno();
}

uint_fast8_t plt_param(char *p)
{
	if (strcmp(p, "kempston") == 0) {
		kempston = 1;
		return 1;
	}
	if (strcmp(p, "kmouse") == 0) {
		kmouse = 1;
		return 1;
	}
	if (strcmp(p, "fuller") == 0) {
		fuller = 1;
		return 1;
	}
	if (strcmp(p, "kmouse3") == 0) {
		kmouse = 1;
		kempston_mbmask = 7;
		return 1;
	}
	if (strcmp(p, "kmturbo") == 0) {
		/* For now rely on the turbo detect - may want to change this */
		kmouse = 1;
		return 1;
	}
	return 0;
}

/* Nothing to do for the map of init */
void map_init(void)
{
}

void plt_copyright(void)
{
}
