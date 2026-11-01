/*
 *	Implement the usermem services. Can then use either C or asm code for
 *	the block transfers. This code can be banked as part of the kernel if
 *	using the asm helpers but must be in commonmem if not
 */

#include <kernel.h>
#include <kdata.h>
#include <printf.h>

#if !defined(CONFIG_LEVEL_0)

/* Flat mode has to use its own valaddr: tidy this */

/* This checks to see if a user-supplied address is legitimate */
usize_t valaddr(const uint8_t *base, usize_t size, uint_fast8_t is_write)
{
	/* Cast to deal with gcc6809 fun */
	if ((usize_t)base + size < (usize_t)base)
		size = MAXUSIZE - (usize_t)base + 1;
	if (!base || base < (const uint8_t *)PROGBASE ||
		base > (const uint8_t *)(size_t)udata.u_top)
		size = 0;
	else if (base + size > (const uint8_t *)(size_t)udata.u_top)
		size = (uint8_t *)(size_t)udata.u_top - base;
	if (size == 0)
		udata.u_error = EFAULT;
	return size;
}

usize_t valaddr_r(const uint8_t *base, usize_t size)
{
	return valaddr(base, size, 0);
}

usize_t valaddr_w(const uint8_t *base, usize_t size)
{
	return valaddr(base, size, 1);
}


int uget(const void *user, void *dst, usize_t count)
{
	if (!valaddr_r(user,count))
		return -1;
	return _uget(user,dst,count);
}

int16_t ugetc(const void *user)
{
	if (!valaddr_r(user, 1))
		return -1;
	return _ugetc(user);
}

uint16_t ugetw(const void *user)
{
	if (!valaddr_r(user, 2))
		return -1;
	return _ugetw(user);
}

int uput(const void *source,   void *user, usize_t count)
{
	if (!valaddr_w(user, count))
		return -1;
	return _uput(source,user,count);
}

int uputc(uint16_t value,  void *user)
{
	if (!valaddr_w(user, 1))
		return -1;
	/* u16_t so we don't get wacky 8bit stack games on SDCC */
	return _uputc(value,user);
}

int uputw(uint16_t value, void *user)
{
	if (!valaddr_w(user, 2))
		return -1;
	return _uputw(value,user);
}

int uzero(void *user, usize_t count)
{
	if (!valaddr_w(user, count))
		return -1;
	return _uzero(user,count);
}


/*
 *	Optional C language implementation for porting to new processors
 *	or where asm isn't needed
 */

#endif
