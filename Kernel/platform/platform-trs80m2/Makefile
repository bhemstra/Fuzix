CSRCS = devlpr.c devtty.c devfd.c devhd.c
CSRCS += devices.c main.c
DISCARD_CSRCS = discard.c devhd_discard.c

ASRCS = crt0.S trs80m2.S
ASRCS += tricks.S commonmem.S

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
OBJS  = $(COBJS) $(AOBJS) $(DISCARD_COBJS)

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) *~ *.tmp fuzix.tmpmap boot.o loader.o hdboot.o
	rm -f boot.bin loader.bin boot.raw boot.imd bootds.raw hdboot.bin hdzone.bin
	rm -f ../../tools/makeimd

#
#	The image runs from 0x0100. The common memory, literals, data and
#	bss come first so they are in the fixed lower 32K (page 0), where
#	they can be seen whichever user page is mapped at 0x8000. The code
#	follows and runs on into page 1, then the buffers and the discard
#	area, which may grow up to the video memory at 0xF800. crt0.o is
#	linked first: its common part (the jump to the start) is at 0x0100.
#	fuzix.bin starts at 0x0000; the loaders bring in 0x0100-0xEEFF.
#
image: boot.bin loader.bin ../../tools/makeimd
	$(CROSS_LD) -b -S 0x0100 -f SsLDBCbX -o ../../fuzix.bin \
	crt0.o commonmem.o trs80m2.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../cpu-z80u/usermem_std-z80u.o \
	../../usermem.o tricks.o main.o discard.o \
	devfd.o devhd.o devhd_discard.o devices.o \
	../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o \
	../../tty.o ../../vt.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bankfixed.o ../../devsys.o \
	devtty.o devlpr.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap | sort -n | cut -d" " -f 2- >../../fuzix.map
	@S=`stat -c %s ../../fuzix.bin`; \
	if [ $$S -gt $$((0xEF00)) ]; then \
		echo "Kernel image is $$S bytes: it must end below 0xEF00 to fit the loaders"; exit 1; fi
	$(MAKE) hdzone.bin
	rm -f boot.raw
	dd if=/dev/zero of=boot.raw bs=1 count=0 seek=$(RAW_SIZE)
	dd if=boot.bin of=boot.raw conv=notrunc
	dd if=loader.bin of=boot.raw bs=1 seek=1552 count=2032 conv=notrunc
	dd if=../../fuzix.bin of=boot.raw bs=256 skip=1 seek=$$(($(KERNEL_OFFSET) / 256)) count=239 conv=notrunc
	../../tools/makeimd boot.raw boot.imd

#
#	The boot ROM reads all 26 single density sectors of cylinder 0 into
#	0x0E00-0x1BFF. boot.S is the part it runs, loader.S is copied up to
#	0xF000 by it and loads the kernel.
#
boot.bin: boot.S
	fcc -mz80 -c boot.S
	ldz80 -b boot.o -o boot.tmp
	dd if=boot.tmp of=boot.bin bs=256 skip=14 count=13
	rm -f boot.tmp

loader.bin: loader.S
	fcc -mz80 -c loader.S
	ldz80 -b loader.o -o loader.tmp
	dd if=loader.tmp of=loader.bin bs=256 skip=240 count=8
	rm -f loader.tmp

#
#	Hard disk loader: one 512 byte sector, assembled to run at 0xF000
#
hdboot.bin: hdboot.S
	fcc -mz80 -c hdboot.S
	ldz80 -b hdboot.o -o hdboot.tmp
	dd if=hdboot.tmp of=hdboot.bin bs=512 skip=120 count=1
	rm -f hdboot.tmp

#
#	Hard disk boot zone (cylinder 0, 128K with trs80gp's 32 sectors of
#	512 bytes per track and 8 heads): sectors 0-8 filler (the label goes
#	in the first one), sector 9 the loader, then the kernel 0x0100-0xEEFF
#	in sector order, the rest of the cylinder unused. The boot ROM loads
#	from sector 1 (or 0) to 0x0000, so the loader lands at 0x1000 (or
#	0x1200): above a 4K boot ROM, which hides what is below 0x1000
#
hdzone.bin: hdboot.bin ../../fuzix.bin
	dd if=/dev/zero of=hdzone.bin bs=512 count=256 2>/dev/null
	dd if=hdboot.bin of=hdzone.bin bs=512 seek=9 conv=notrunc 2>/dev/null
	dd if=../../fuzix.bin of=hdzone.bin bs=256 skip=1 seek=20 count=238 conv=notrunc 2>/dev/null

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
		dd if=../../fuzix.bin of=bootds.raw bs=256 skip=$$((1 + t * 26)) \
		   seek=$$(($(DS_KERNEL_OFFSET) / 256 + t * 52)) count=26 \
		   conv=notrunc 2>/dev/null; \
	done
	../../tools/makeimd -d bootds.raw $(IMAGES)/bootds.imd
	rm -f bootds.raw $(IMAGES)/fsmini.img
