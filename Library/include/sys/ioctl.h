#ifndef _SYS_IOCTL_H
#define _SYS_IOCTL_H

#define __IOCTL_SUPER	0x4000

/* Some things expect sys/ioctl.h to define this */

extern int ioctl(int fd, int request,...);

#endif

