CSRCS = devlpr.c devtty.c devfd.c devhd.c
CSRCS += devices.c main.c
DISCARD_CSRCS = discard.c devhd_discard.c

ASRCS = trs80m2.s crt0.s
ASRCS += tricks.s commonmem.s

COBJS = $(CSRCS:.c=.rel)
AOBJS = $(ASRCS:.s=.rel)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.rel)
OBJS  = $(COBJS) $(AOBJS) $(DISCARD_COBJS)

all:	$(OBJS)

$(COBJS): %.rel: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(AOBJS): %.rel: %.s
	$(CROSS_AS) $(ASOPTS) $<

$(DISCARD_COBJS): %.rel: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) *.lst *.asm *.sym *.rst *.lk *.ihx *.map *.noi core *~
	rm -f boot.bin loader.bin boot.raw boot.imd
	rm -f ../../tools/makeimd

#
#	The boot ROM reads all 26 single density sectors of cylinder 0 into
#	0x0E00-0x1BFF. boot.s is the part it runs, loader.s is copied up to
#	0xF000 by it and loads the kernel.
#
boot.bin: boot.s
	sdasz80 -o boot.s
	sdldz80 -i boot.rel
	makebin -s 7168 boot.ihx boot.tmp
	dd if=boot.tmp of=boot.bin bs=256 skip=14 count=13
	rm -f boot.tmp

loader.bin: loader.s
	sdasz80 -o loader.s
	sdldz80 -i loader.rel
	makebin -s 63488 loader.ihx loader.tmp
	dd if=loader.tmp of=loader.bin bs=256 skip=240 count=8
	rm -f loader.tmp

../../tools/makeimd: ../../tools/makeimd.c
	cc -O2 -Wall -o $@ $<

#
#	Raw image layout (single sided)
#	0	cylinder 0, 26 x 128 bytes FM (boot code)
#	3328	cylinders 1-76, 26 x 256 bytes MFM each
#
#	Fuzix /dev/fd0 block 0 starts at cylinder 1. The kernel image
#	(0x0100 up to at most 0xEFFF) lives on cylinders 67-76, leaving
#	cylinders 1-66 (858 blocks) for a file system.
#
KERNEL_OFFSET = 442624
RAW_SIZE = 509184

image: boot.bin loader.bin ../../tools/makeimd
	@E=`awk '$$2 == "s__INITIALIZER" { print $$1 }' ../../fuzix.map`; \
	if [ $$((0x$$E)) -gt $$((0xF000)) ]; then \
		echo "Kernel image ends at 0x$$E and runs into the loader at 0xF000"; exit 1; fi
	rm -f boot.raw
	dd if=/dev/zero of=boot.raw bs=1 count=0 seek=$(RAW_SIZE)
	dd if=boot.bin of=boot.raw conv=notrunc
	dd if=loader.bin of=boot.raw bs=1 seek=1552 count=2032 conv=notrunc
	dd if=../../fuzix.bin of=boot.raw bs=1 seek=$(KERNEL_OFFSET) count=61184 conv=notrunc
	../../tools/makeimd boot.raw boot.imd

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	cp boot.imd $(IMAGES)/boot.imd
	cp boot.raw $(IMAGES)/boot.raw
	# Build a file system for the hard disk
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAGH) $(IMAGES)/filesys.img 256 21760)
	cat xtrsheader $(IMAGES)/filesys.img >$(IMAGES)/hard2-0
	../../tools/trslabel $(IMAGES)/hard2-0
