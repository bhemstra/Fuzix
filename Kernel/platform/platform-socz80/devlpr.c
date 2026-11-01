#include <kernel.h>
#include <version.h>
#include <kdata.h>
#include <devlpr.h>

int lpr_open(uint_fast8_t minor, uint16_t flag)
{
    udata.u_error = ENODEV;
    return (-1);
}

int lpr_close(uint_fast8_t minor)
{
    udata.u_error = ENODEV;
    return (-1);
}

int lpr_read(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
    udata.u_error = EINVAL;
    return (-1);
}

int lpr_write(uint_fast8_t minor, uint_fast8_t rawflag, uint_fast8_t flag)
{
    udata.u_error = ENODEV;
    return (-1);
}
