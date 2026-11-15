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
/* Needs work to do this alas */
#define CONFIG_LARGE_IO_DIRECT(x)	1

/*
 *	REU behaves like multiple banks
 */
#define CONFIG_BANK_FIXED
#define MAX_MAPS	32	/* Should be plenty */
#define MAP_SIZE	0xC000

/* Custom buffer clearing routine */
extern void reu_blkzero(uint8_t *p);
#define blkzero(x)	reu_blkzero((x)->__bf_data)

/* Disable swap whilst we work on bank switching */
#if 0
#define CONFIG_DYNAMIC_SWAP
#define SWAPBASE 0x4000		/* Special handling needed on the in part ! */
#define SWAPTOP  0xFE00
#define SWAP_SIZE 0x61		/* including the udata and S/ZP */
#define CONFIG_SWAP_6502	/* need to handle S and ZP specially */

#define swap_map(x)	((uint8_t *)(x))

#define MAX_SWAPS	14
#define SWAPDEV		(swap_dev)
#endif

#define TICKSPERSEC	10	    /* Ticks per second */

/* We've not yet made the rest of the code - eg tricks match this ! */
#define MAPBASE	    0x4000  /* We map from 4000 */
#define PROGBASE    0x4000  /* also data base */
#define PROGLOAD    0x4000
#define PROGTOP     0xFE00  /* UDATA at 3E00-3FFF and asm changes needed
                               to adjust this */
#define DP_BASE	    0x1A
#define DP_SIZE	    32

#if 0
/* Settings for swap only mode */
#define CONFIG_SPLIT_UDATA
#define UDATA_SIZE 0x200
#define UDATA_BLKS 1
#endif

#define CONFIG_TD_NUM	2
#define CONFIG_TD_IDE
#define CONFIG_TINYIDE_8BIT
#define IDE_IS_8BIT(x)	1

#define BOOT_TTY 513        /* Set this to default device for stdio, stderr */

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
#define NBUFS    5        /* Number of block buffers */
#define NMOUNTS	 2	  /* Number of mounts at a time */

#define plt_discard()
#define plt_copyright()

#define BOOTDEVICENAMES "hd#"

#undef CONFIG_SMALL
