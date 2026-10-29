#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <devlpr.h>

/* Model III/4 parallel printer: status bits 7 busy, 6 paper out,
   5 selected, 4 not fault. The ROM tests (status & 0xF0) == 0x30 */
__sfr __at 0xF8 lpstat;
__sfr __at 0xF8 lpdata;

int lpr_open(uint8_t minor, uint16_t flag)
{
    minor; flag; // shut up compiler
    return 0;
}

int lpr_close(uint8_t minor)
{
    minor; // shut up compiler
    return 0;
}

int lpr_write(uint8_t minor, uint8_t rawflag, uint8_t flag)
{
    uint16_t ct = 0;
    char *p = udata.u_base;
    minor; rawflag; // shut up compiler

    while(ct < udata.u_count) {
        /* Note; on real hardware it might well be necessary to
           busy wait a bit just to get acceptable performance */
        while ((lpstat & 0xF0) != 0x30) {
            if (flag & O_NDELAY) {
                if (ct)
                    return ct;
                udata.u_error = EAGAIN;
                return -1;
            }
        }
        /* FIXME: tidy up ugetc and sysio checks globally */
        lpdata = ugetc(p++);
        ct++;
    }
    return ct;
}
