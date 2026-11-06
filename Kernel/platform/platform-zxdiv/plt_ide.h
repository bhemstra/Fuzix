#define data	0xA3
#define error	0xA7
#define count	0xAB
#define sec	0xAF
#define cyll	0xB3
#define cylh	0xB7
#define devh	0xBB
#define cmd	0xBF
#define status	0xBF

#define IDE_REG_DATA	0x00A3

#define IDE_NONSTANDARD_XFER

#define ide_read(x)	in(x)
#define ide_write(x,y)	out(x,y)
