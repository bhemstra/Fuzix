/*
 *	TRS-80 Model II (also Model 12, 16, 16B and 6000 running in Z80 mode)
 *
 *	Memory model
 *	0000-7FFF	Fixed RAM (page 0): vectors, common, data, some code
 *	8000-FFFF	One of pages 1-15 (port 0xFF bits 0-3)
 *			Page 1 holds the rest of the kernel, pages 2+ are
 *			used for 32K user processes
 *	F800-FFFF	Video RAM when port 0xFF bit 7 is set (kernel map)
 */

/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Multiple processes in memory at once */
#define CONFIG_MULTI
/* Video terminal, not a serial tty */
#define CONFIG_VT
/* Banked memory set up */
#define CONFIG_BANK_FIXED
/* Reclaim the discard space for buffers */
#define CONFIG_DYNAMIC_BUFPOOL
/* Use large I/O */
#define CONFIG_LARGE_IO_DIRECT(x)	1

#define MAX_MAPS	14	/* Pages 2-15 */

#define MAP_SIZE	0x8000

#define CONFIG_BANKS	2	/* 2 x 32K */

/* Vt definitions */
#define VT_WIDTH	80
#define VT_HEIGHT	24
#define VT_RIGHT	79
#define VT_BOTTOM	23

/*
 *	The real time clock is the vertical sync divided by two, so 30Hz on
 *	a 60Hz machine. Overseas 50Hz machines give 25Hz.
 */
#define TICKSPERSEC 30	    /* Ticks per second */
#define PROGBASE    0x8000  /* Base of user  */
#define PROGLOAD    0x8000  /* Load and run here */
#define PROGTOP     0xFE00  /* Top of program, base of U_DATA stash */
#define PROC_SIZE   32 	    /* Memory needed per process */

#define SWAP_SIZE   0x40 	/* 32K in blocks */
#define SWAPBASE    0x8000	/* We swap the lot in one, include the */
#define SWAPTOP	    0x10000UL	/* udata stash at the top */

#define MAX_SWAPS	64	/* Should be plenty (2MB!) */

#define swap_map(x)	((uint8_t *)(x))

#define BOOT_TTY (512 + 1)      /* Set this to default device for stdio, stderr */
                          /* In this case, the default is the first TTY device */

/* The loaders leave a command line here ("hda2" from the hard disk
   loader, empty from the floppy one). It is in the discard area which is
   only reclaimed after the root is mounted */
#define CMDLINE	((char *)0xF7E0)

/* Device parameters */
#define NUM_DEV_TTY 3		/* Console, serial A, serial B */
#define TTYDEV   BOOT_TTY /* Device used by kernel for messages, panics */
#define SWAPDEV  (swap_dev)  /* Device for swapping (dynamic). */
#define NBUFS    5        /* Number of block buffers - keep in sync with asm! */
#define NMOUNTS	 4	  /* Number of mounts at a time */

extern void plt_discard(void);
#define plt_copyright()

#define BOOTDEVICENAMES "hd#,fd#"

#define CONFIG_SMALL
