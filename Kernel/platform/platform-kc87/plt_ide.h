#define	data	0x58
#define error	0x59
#define	count	0x5A
#define	sec	0x5B
#define	cyll	0x5C
#define cylh	0x5D
#define devh	0x5E
#define cmd	0x5F
#define status	0x5f

#define IDE_REG_DATA	0x0058

/* Banked xfer routines needed */
#define IDE_NONSTANDARD_XFER

#define ide_read(x)	in(x)
#define ide_write(x,y)	out(x,y)
