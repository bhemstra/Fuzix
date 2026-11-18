#include <kernel.h>
#include <printf.h>
#include <devhd.h>
#include <devtty.h>
#include <devm2.h>
#include <tty.h>

void device_init(void)
{
	/* Start the 30Hz clock now interrupts are on */
	m2_rtc_on();
	sio_init();
	hd_probe();
}
