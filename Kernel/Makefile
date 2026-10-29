# Define V=1 for more verbose compilation.

TARGET_LIST = $(wildcard platform/platform-*)

export ROOT_DIR

UNAME_S := $(shell uname -s)

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

all:	fuzix.bin

# Platform properties
include platform/platform-$(TARGET)/target.mk
# CPU properties
include cpu-$(CPU)/rules.mk
# Overrides (optional)
-include platform/platform-$(TARGET)/rules.mk


#
#	We put these into two code segments so that the caller can plan to
#	bank them with a ROM banking tool. We pull out const data because on
#	such a system you want to the constants unbanked otherwise badness
#	happens on stuff like printf("Hello world\n"); when you bank switch
#	the code.
#
#	This is also useful if you've got an annoying box where the kernel can't
#	be a linear chunk eg if you need to put the kernel in two non adjacent 16K
#	chunks or compile it around a hole for videomemory or similar
#
#	VT and FONT are handled specially because they can be mapped more
#	freely and also because you often want to overlay part of the kernel
#	with the framebuffer when doing video output
#

CDSRCS = start.c
C1SRCS =  devio.c kdata.c
C1SRCS += inode.c tty.c
C2SRCS =  syscall_proc.c process.c mm/malloc.c
C2SRCS += mm/simple.c mm/bank8k.c mm/bank16k.c mm/bank16k_low.c mm/bank32k.c
C3SRCS = mm/bankfixed.c mm/flat.c mm/flat_mem.c mm/buddy.c kmod.c
C2SRCS += mm/bank16kfc.c mm/banksplit.c mm/flat_small.c
C4SRCS = filesys.c version.c blk400.c blk512.c
#
#	Usually we map sysalls into CODE2 but they can be overlaid
#	Assume we'll never be doing overlays with level2 or networking
#
CS1SRCS = syscall_fs.c syscall_level2.c select.c
CS2SRCS = syscall_fs2.c
CS3SRCS = syscall_fs3.c	syscall_net.c
CS4SRCS = syscall_other.c

#
#	Set EXECFORMAT to use one of the standard loaders
#
CS5SRCS = syscall_exec.c mm/memalloc_none.c
ifneq ($(EXECFORMAT),)
CS5SRCS += syscall_exec$(EXECFORMAT).c
endif
#
#
#	Drop some bits into CODE3 so the banks fit nicely
#
C3SRCS += devsys.c mm.c swap.c page.c usermem.c timer.c audio.c level2.c
C3SRCS += devinput.c
CVIDEOSRCS = vt.c
CFONTSRCS = font/font4x6.c font/font6x8.c font/font8x8.c font/font8x8_exp2.c font/font4x8.c

CNETSRCS = network.c

ASRCS =  cpu-$(CPU)/lowlevel-$(CPU)$(BANKED)$(ASMEXT) cpu-$(CPU)/usermem_std-$(CPU)$(BANKED)$(ASMEXT)


CDOBJS = $(CDSRCS:.c=$(BINEXT))
C1OBJS = $(C1SRCS:.c=$(BINEXT))
C2OBJS = $(C2SRCS:.c=$(BINEXT))
C3OBJS = $(C3SRCS:.c=$(BINEXT))
C4OBJS = $(C4SRCS:.c=$(BINEXT))

CS1OBJS = $(CS1SRCS:.c=$(BINEXT))
CS2OBJS = $(CS2SRCS:.c=$(BINEXT))
CS3OBJS = $(CS3SRCS:.c=$(BINEXT))
CS4OBJS = $(CS4SRCS:.c=$(BINEXT))
CS5OBJS = $(CS5SRCS:.c=$(BINEXT))

CFONTOBJS = $(CFONTSRCS:.c=$(BINEXT))
CNETOBJS = $(CNETSRCS:.c=$(BINEXT))
CVIDEOOBJS = $(CVIDEOSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:$(ASMEXT)=$(BINEXT))

CSSRCS = $(CS1SRCS) $(CS2SRCS) $(CS3SRCS) $(CS4SRCS) $(CS5SRCS)
CSOBJS = $(CS1OBJS) $(CS2OBJS) $(CS3OBJS) $(CS4OBJS) $(CS5OBJS)

CSRCS = $(CDSRCS) $(C1SRCS) $(C2SRCS) $(C3SRCS) $(C4SRCS) $(CFONTSRCS) $(CVIDEOSRCS) $(CSSRCS) $(CNETSRCS)
COBJS = $(CDOBJS) $(C1OBJS) $(C2OBJS) $(C3OBJS) $(C4OBJS) $(CFONTOBJS) $(CVIDEOOBJS) $(CSOBJS) $(CNETOBJS)

OBJS  = $(COBJS) $(AOBJS)

JUNK = $(CSRCS:.c=.lst) $(CSRCS:.c=.s) $(CSRCS:.c=.asm) $(CSRCS:.c=.sym) $(ASRCS:$(ASMEXT)=.lst) $(ASRCS:$(ASMEXT)=.sym) $(CSRCS:.c=.rst) $(CSRCS:.c=.o)  $(CSRCS:.c=.adb)  $(ASRCS:$(ASMEXT)=.rst)

.SUFFIXES:		# delete the default suffixes
.SUFFIXES: .c .s .rel .S


build:
	ln -sf platform/platform-$(TARGET) build

target: include/kernel.h $(OBJS) | build
	+$(MAKE) -C platform/platform-$(TARGET)

$(OBJS): | build

$(CSRCS): include/kernel.h

include/kernel.h: include/sysinfoblk.h

include/sysinfoblk.h: tools/makeversion
	$(QUIET_GEN)tools/makeversion $(VERSION) $(SUBVERSION) $(TARGET)

$(C1OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG1) $<

$(CDOBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) $<

$(C2OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) $<

$(C3OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) $<

$(C4OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG4) $<

$(CFONTOBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_FONT) $<

$(CVIDEOOBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_VIDEO) $<

$(CS1OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SYS1) $<

$(CS2OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SYS2) $<

$(CS3OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SYS3) $<

$(CS4OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SYS4) $<

$(CS5OBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SYS5) $<

$(CNETOBJS): %$(BINEXT): %.c
	$(QUIET_CC)$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_NETWORK) $<

$(AOBJS): %$(BINEXT): %$(ASMEXT)
	$(QUIET_AS)$(CROSS_AS) $(ASOPTS) -o $*$(BINEXT) $<

version.c: tools/makeversion
	$(QUIET_GEN)tools/makeversion $(VERSION) $(SUBVERSION) $(TARGET)

font/font8x8_exp2.c: font/font8x8.c tools/fontexpand
	$(QUIET_GEN)tools/fontexpand <font/font8x8.c >font/font8x8_exp2.c

tools/makeversion: tools/makeversion.c

tools/filesizes: tools/filesizes.c

tools/map_syscall: tools/map_syscall.c

tools/make4x6: tools/make4x6.c

tools/makejv3: tools/makejv3.c

tools/trslabel: tools/trslabel.c

tools/fontexpand: tools/fontexpand.c

mm/font4x6.c: tools/make4x6
	tools/make4x6 >font4x6.c

clean:
	rm -f build
	rm -f $(OBJS) $(JUNK) fuzix.cdb fuzix.com fuzix.tmp fuzix.bin fuzix.map fuzix.noi
	rm -f fuzix.ihx common.ihx common.bin relocs.dat core *~ include/*~ version.c tools/make4x6
	rm -f tools/analysemap tools/memhogs tools/binman tools/bihx tools/binmunge
	rm -f tools/makejv3 tools/modlib-z80 tools/visualize hogs.txt
	rm -f hogs.txt.old tools/*~ version.c include/sysinfoblk.h tools/makeversion tools/trslabel
	rm -f tools/fontexpand font/font8x8_exp2.c
	rm -f *.rel *.lst *.sym *.o *.bin
	+$(MAKE) -C platform/platform-$(TARGET) clean
	+$(MAKE) -C tools/bankld clean
	+$(MAKE) -C cpu-z80/sdccrt clean

clean-all: clean
	(cd tools/bankld; $(MAKE) clean)
	$(foreach target,$(TARGET_LIST), $(MAKE) -C $(target) clean;)
	-rm -f build

include quiet.mk

include cpu-$(CPU)/image.mk
-include platform/platform-$(TARGET)/image.mk

diskimage:
	+$(MAKE) -C platform/platform-$(TARGET) diskimage
