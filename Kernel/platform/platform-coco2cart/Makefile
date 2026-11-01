
CSRCS = devices.c main.c devinput.c devtty.c

# Code that must be present for the bootstrap
CISRCS = devsdc.c

CDSRCS = discard.c 

DSRCS = ../../dev/devdw.c ../../dev/tinydisk.c ../../dev/tinyide.c
DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyide_discard.c

ASRCS = crt0.S coco2.S ide.S usermem.S sdc.S
ASRCS += bootstrap.S bootstrap_sdc.S #bootstrap_dw.S
ASRCS += tricks.S commonmem.S video.S

ADSRCS = ../../dev/drivewire/drivewire.S

COBJS = $(CSRCS:.c=.o)
CIOBJS = $(CISRCS:.c=.o)
C3OBJS = $(C3SRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
ADOBJS = $(patsubst ../../dev/drivewire/%.S,%.o, $(ADSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
OBJS  = $(COBJS) $(C3OBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(CIOBJS) $(ADOBJS)

CROSS_CCOPTS += -I../../dev/

all: $(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG1) -c $< -o $@

$(CIOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG1) -c $< -o $@

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGD) -c $< -o $@

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

$(ADOBJS): %.o: ../../dev/drivewire/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f *.o *~ *.rom *.bin fuzix.ide fuzix.sdc fuzix.img fuzix.tmpmap

image:
	$(CROSS_LD) -b -C 0xC000 -X 0x0400 -S 0x1000 -f CXSsLDBb -o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o bootstrap.o commonmem.o coco2.o discard.o ../../mm/simple.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	drivewire.o devdw.o tinyide.o \
	tinyide_discard.o ide.o tinydisk.o \
	tinydisk_discard.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_exec.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o usermem.o ../../syscall_fs2.o \
	../../syscall_exec16.o devtty.o ../../vt.o video.o  ../../syscall_fs3.o \
	../../blk512.o ../../font/font8x8.o devsdc.o sdc.o ../../devinput.o devinput.o \
	/opt/fcc/lib/6809/lib6809.a
	# This has changed with the discard change
	# We now have C000-FFFF ROM
	# 0400-7FFF single RAM block
	# This is much simpler and storage size simply isn't an issue
	dd if=../../fuzix.bin of=fuzixide.rom bs=16384 skip=3 count=1 conv=sync
	dd if=../../fuzix.bin of=fuzix.ide bs=1024 skip=1 count=31
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

	$(CROSS_LD) -b  -C 0xC000 -S 0x1A00 -f CSsLDBbX -o ../../fuzix-sdc.bin -m fuzix.tmpmap \
	crt0.o bootstrap_sdc.o commonmem.o coco2.o discard.o ../../mm/simple.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	drivewire.o devdw.o tinyide.o tinyide_discard.o ide.o \
	tinydisk.o tinydisk_discard.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_exec.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o usermem.o ../../syscall_fs2.o \
	../../syscall_exec16.o devtty.o ../../vt.o video.o  ../../syscall_fs3.o \
	../../blk512.o ../../font/font8x8.o devsdc.o sdc.o ../../devinput.o devinput.o \
	/opt/fcc/lib/6809/lib6809.a
	dd if=../../fuzix-sdc.bin of=fuzixsdc.rom bs=16384 skip=3 count=1 conv=sync
	dd if=../../fuzix-sdc.bin of=fuzix.sdc bs=1024 skip=1 count=31
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix-sdc.map


IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# We have 2048 blocks at the start which are the partition table then our
	# image blocks
	cp $(IMAGES)/disk.img $(IMAGES)/sd.img
	# Write the rest of the images to the disks
	dd if=fuzix.ide of=$(IMAGES)/disk.img bs=512 seek=1 conv=notrunc
	dd if=fuzix.sdc of=$(IMAGES)/sd.img bs=512 seek=1 conv=notrunc
	# Cartridge ROM
	cp fuzixide.rom $(IMAGES)/fuzixide.rom
	cp fuzixsdc.rom $(IMAGES)/fuzixsdc.rom
