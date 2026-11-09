#define data	(MARK4_IO_BASE + 0)
#define error	(MARK4_IO_BASE + 1)
#define count	(MARK4_IO_BASE + 2)
#define sec	(MARK4_IO_BASE + 3)
#define cyll	(MARK4_IO_BASE + 4)
#define cylh	(MARK4_IO_BASE + 5)
#define devh	(MARK4_IO_BASE + 6)
#define cmd	(MARK4_IO_BASE + 7)
#define status	(MARK4_IO_BASE + 7)

#define IDE_REG_DATA	(MARK4_IO_BASE + 0)

#define IDE_NONSTANDARD_XFER

#define ide_read(x)	in(x)
#define ide_write(x,y)	out(x,y)
