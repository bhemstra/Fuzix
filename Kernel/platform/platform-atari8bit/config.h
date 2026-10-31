/* Enable to make ^Z dump the inode table for debug */
#undef CONFIG_IDUMP
/* Enable to make ^A drop back into the monitor */
#undef CONFIG_MONITOR
/* Profil syscall support (not yet complete) */
#undef CONFIG_PROFIL
/* Acct syscall support */
#undef CONFIG_ACCT
/* Multiple processes in memory at once */
#define CONFIG_MULTI
/* Use fixed banks for now. It's simplest and we've got so much memory ! */
#define CONFIG_BANKS	1
/* Permit large I/O requests to bypass cache and go direct to userspace */
#define CONFIG_LARGE_IO_DIRECT(x)	1

/*
 *	One process in memory only
 */
#define CONFIG_SWAP_ONLY
#define CONFIG_DYNAMIC_SWAP
#define SWAPBASE 0x0200
#define SWAPTOP  0xC000
#define SWAP_SIZE 0x61		/* including the udata and ZP/S */
#define CONFIG_SWAP_6502	/* need to handle S and ZP specially */
#define CONFIG_PARENT_FIRST	/* We write the child to media */

#define swap_map(x)	((uint8_t *)(x))

#define MAX_SWAPS	14
#define SWAPDEV (swap_dev)
/* We have one mapping from our working of memory */
#define MAX_MAPS	1
#define MAP_SIZE	0xC000U

#define TICKSPERSEC 60	    /* Ticks per second */

/* We've not yet made the rest of the code - eg tricks match this ! */
#define MAPBASE	    0x0200  /* We map from 0200 */
#define PROGBASE    0x0200  /* also data base */
#define PROGLOAD    0x0200
#define PROGTOP     0xC000

/* Settings for swap only mode */
#define CONFIG_SPLIT_UDATA
#define UDATA_SIZE 0x200
#define UDATA_BLKS 1

#define CONFIG_TD_NUM	2
#define CONFIG_TD_IDE
#define CONFIG_TINYIDE_8BIT
#define IDE_IS_8BIT(x)	1

/* FIXME: swap */

#define BOOT_TTY 513        /* Set this to default device for stdio, stderr */

#define CONFIG_VT
#define CONFIG_FONT8X8
#define CONFIG_FONT8X8_7BIT	/* Only 128 symbols */

/* Vt definitions */
#define VT_WIDTH	40
#define VT_HEIGHT	25
#define VT_RIGHT	39
#define VT_BOTTOM	24

/* We need a tidier way to do this from the loader */
#define CMDLINE	NULL	  /* Location of root dev name */

/* Device parameters */
#define NUM_DEV_TTY 1
#define TTYDEV   BOOT_TTY /* Device used by kernel for messages, panics */
/* External buffers (so we can balance things better) */
#define CONFIG_BLKBUF_EXTERNAL
#define NBUFS    5        /* Number of block buffers */
#define NMOUNTS	 2	  /* Number of mounts at a time */

#define plt_discard()
#define plt_copyright()

#define BOOTDEVICENAMES "hd#"

#undef CONFIG_SMALL
