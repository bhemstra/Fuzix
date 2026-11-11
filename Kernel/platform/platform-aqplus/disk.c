#include <kernel.h>
#include <kdata.h>
#include <printf.h>
#include <timer.h>
#include <tinydisk.h>
#include <aqplus.h>

uint8_t disk_unit;
uint32_t disk_lba;
uint8_t disk_op;
uint8_t *disk_addr;

static uint8_t disk_fd[TD_DISK_NUM];

static int disk_xfer(uint_fast8_t dev, bool is_read, uint32_t lba, uint8_t *dptr)
{
	uint8_t r;
	disk_unit = disk_fd[dev];
	disk_lba = lba * 512;
	disk_op = is_read;
	disk_addr = dptr;
	if ((r = iop_diskop()) & 0x80) {
		kprintf("hd%u: err %2x\n", dev, r);
		return 0;
	}
	return 1;
}

static int disk_ioctl(uint_fast8_t dev, uarg_t request, char *unused)
{
    return -1;
}

void disk_probe(void)
{
	unsigned n;
	int fd;
	for (n = 0 ; n < TD_DISK_NUM; n++) {
	        disk_unit = n;
	        if ((fd = iop_diskopen()) >= 0) {
	        	disk_fd[n] = fd;
			td_register(n, disk_xfer, disk_ioctl, 1);
		}
	}
}
