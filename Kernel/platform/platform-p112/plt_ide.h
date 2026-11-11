/*
 *	P112 G-IDE (IDE/ATA) register map.
 *
 *	G-IDE presents the ATA task-file in Z180 I/O space on CS1 at
 *	0x58..0x5F (CS0 control/altstatus/DOR = 0x56), per the Tillmann Reh
 *	GIDE (base 0x50): IDEDat=0x58 .. IDECmd=0x5F (ROM Equ.S). Registers are
 *	read and written via in()/out() (CONFIG_TINYIDE_INDIRECT). The 16-bit
 *	bulk data transfer is handled in ide.S (IDE_NONSTANDARD_XFER).
 */
#define data	0x58
#define error	0x59
#define count	0x5A
#define sec	0x5B
#define cyll	0x5C
#define cylh	0x5D
#define devh	0x5E
#define cmd	0x5F
#define status	0x5F

#define IDE_REG_DATA	0x58
#define IDE_NONSTANDARD_XFER
#define ide_read(x)	in(x)
#define ide_write(x,y)	out(x,y)
