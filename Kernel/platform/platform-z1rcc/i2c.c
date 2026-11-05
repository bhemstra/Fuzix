/*
 *	I2C interface support
 */

#include <kernel.h>
#include <kdata.h>
#include <z1rcc.h>
#include <i2c.h>
#include <i2c_bitbang.h>

#define I2C	0x9E

/* There isn't a huge point optimizing this, we are not supposed to go over
   100 or 400KHz anyway. The expectations of the caller are that
   - any delays needed are made before the signal is changed
   - on a read a delay is made before the signal is read

   But basically it only matters that both are the same side. */

static uint8_t i2c_bits;

void i2c_set(uint_fast8_t bus, uint_fast8_t val)
{
	i2c_bits |= val;
	out(0x9E, i2c_bits);
}

void i2c_clear(uint_fast8_t bus, uint_fast8_t val)
{
	i2c_bits &= ~val;
	out(0x9E, i2c_bits);
}

uint_fast8_t i2c_sda(uint_fast8_t bus)
{
	return in(0x9E) & I2C_RX_SDA;
}

/* No clock stretch support */
uint_fast8_t i2c_scl(uint_fast8_t bus)
{
	return in(0x9E) & I2C_RX_SCL;
}

int i2c_claim_bus(uint_fast8_t bus)
{
	if (bus) {
		udata.u_error = ENODEV;
		return -1;
	}
	return 0;
}

void i2c_release_bus(uint_fast8_t bus)
{
}

int plt_i2c_msg(struct i2c_msg *m, uint8_t *kbuf)
{
	if (m->bus)
		return -ENODEV;
	if (m->addr & 1)
		return i2c_bb_receive(m->bus, m->addr, kbuf, m->len);
	else
		return i2c_bb_send(m->bus, m->addr, kbuf, m->len);
}
