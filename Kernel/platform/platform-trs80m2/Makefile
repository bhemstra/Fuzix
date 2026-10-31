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
	rm -f boot.bin loader.bin boot.raw boot.imd bootds.raw hdboot.bin hdzone.bin
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

#
#	Hard disk loader: one 512 byte sector, assembled to run at 0xF000
#
hdboot.bin: hdboot.s
	sdasz80 -o hdboot.s
	sdldz80 -i hdboot.rel
	makebin -s 61952 hdboot.ihx hdboot.tmp
	dd if=hdboot.tmp of=hdboot.bin bs=512 skip=120 count=1
	rm -f hdboot.tmp

#
#	Hard disk boot zone (cylinder 0, 128K with trs80gp's 32 sectors of
#	512 bytes per track and 8 heads): sectors 0-7 filler (the label goes
#	in the first one), sector 8 the loader, then the kernel 0x0100-0xEEFF
#	in sector order, the rest of the cylinder unused
#
hdzone.bin: hdboot.bin ../../fuzix.bin
	dd if=/dev/zero of=hdzone.bin bs=512 count=256 2>/dev/null
	dd if=hdboot.bin of=hdzone.bin bs=512 seek=8 conv=notrunc 2>/dev/null
	dd if=../../fuzix.bin of=hdzone.bin bs=512 seek=9 count=119 conv=notrunc 2>/dev/null

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
	if [ $$((0x$$E)) -gt $$((0xEF00)) ]; then \
		echo "Kernel image ends at 0x$$E: it must end below 0xEF00 to fit the loaders"; exit 1; fi
	$(MAKE) hdzone.bin
	rm -f boot.raw
	dd if=/dev/zero of=boot.raw bs=1 count=0 seek=$(RAW_SIZE)
	dd if=boot.bin of=boot.raw conv=notrunc
	dd if=loader.bin of=boot.raw bs=1 seek=1552 count=2032 conv=notrunc
	dd if=../../fuzix.bin of=boot.raw bs=1 seek=$(KERNEL_OFFSET) count=61184 conv=notrunc
	../../tools/makeimd boot.raw boot.imd

#
#	Double sided boot disk with a small root file system. The raw layout
#	(as makeimd -d expects) is cylinder 0 side 0 FM, cylinder 0 side 1,
#	then cylinders 1-76 with side 0 followed by side 1. /dev/fd0 starts
#	at cylinder 1 side 0 so the file system is cylinders 1-66, both
#	sides (1716 blocks), and the kernel sits on side 0 of cylinders
#	67-76 where the loader expects it.
#
DS_FS_OFFSET = 9984
DS_KERNEL_OFFSET = 888576
DS_RAW_SIZE = 1021696

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	cp boot.imd $(IMAGES)/boot.imd
	cp boot.raw $(IMAGES)/boot.raw
	# Hard disk: 101 cylinders of 8 heads x 32 x 512 bytes. Header,
	# boot zone (cylinder 0), file system on cylinders 1-68 (hda2) and
	# swap on 69-100 (hda3). The header (xtrsheader) has byte 8 = 0x0A:
	# Model II drive (0x02) with 512 byte sectors (0x08), and byte 29 = 0
	# (256 sectors per cylinder), which is how trs80gp lays out a Model
	# II hard disk.
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAGH) $(IMAGES)/filesys.img 256 17408)
	cat xtrsheader hdzone.bin $(IMAGES)/filesys.img >$(IMAGES)/hard2-0.hdv
	../../tools/trslabel $(IMAGES)/hard2-0.hdv
	# Pad to the full 101 x 8 x 16K so the swap area exists in the file
	truncate -s 13238528 $(IMAGES)/hard2-0.hdv
	rm -f $(IMAGES)/filesys.img
	# Double sided boot floppy with a minimal root file system
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-mini-filesystem $(ENDIANFLAGH) $(IMAGES)/fsmini.img 64 1716)
	rm -f bootds.raw
	dd if=/dev/zero of=bootds.raw bs=1 count=0 seek=$(DS_RAW_SIZE)
	dd if=boot.bin of=bootds.raw conv=notrunc
	dd if=loader.bin of=bootds.raw bs=1 seek=1552 count=2032 conv=notrunc
	dd if=$(IMAGES)/fsmini.img of=bootds.raw bs=1 seek=$(DS_FS_OFFSET) conv=notrunc
	# The loader reads side 0 only, so the kernel goes one track at a
	# time onto side 0 of cylinders 67-76 (26 sectors each, the side 1
	# track in between belongs to nothing)
	for t in 0 1 2 3 4 5 6 7 8 9; do \
		dd if=../../fuzix.bin of=bootds.raw bs=256 skip=$$((t * 26)) \
		   seek=$$(($(DS_KERNEL_OFFSET) / 256 + t * 52)) count=26 \
		   conv=notrunc 2>/dev/null; \
	done
	../../tools/makeimd -d bootds.raw $(IMAGES)/bootds.imd
	rm -f bootds.raw $(IMAGES)/fsmini.img
