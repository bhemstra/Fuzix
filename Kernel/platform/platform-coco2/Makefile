
CSRCS = devices.c main.c devtty.c

CDSRCS = discard.c

DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c

DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyide_discard.c

ASRCS = crt0.S coco2.S video.S
ASRCS += tricks.S commonmem.S

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
OBJS  = $(COBJS) $(C3OBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS)

CROSS_CCOPTS += -I../../dev/

all: $(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $< -o $@

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

tinyide.o: ../../dev/tinyide.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGD) -c $< -o $@

tinydisk.o: ../../dev/tinydisk.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGD) -c $< -o $@

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

clean:
	rm -f *.o *~ fuzix.tmp fuzix.img bootfuz.bin fuzix.tmpmap

image: bootfuz.bin
	$(CROSS_LD) -b -C 0x0400 -f CLDBbsSX -o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o commonmem.o \
	coco2.o discard.o ../../mm/simple.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o ../../mm/memalloc_none.o \
	tricks.o main.o ../../timer.o ../../kdata.o devices.o \
	tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_exec16.o \
	devtty.o ../../vt.o ../../syscall_fs3.o ../../syscall_exec.o ../../blk512.o \
	video.o /opt/fcc/lib/6809/lib6809.a
	# Repack the high spot F0-FF where it wants it
	dd if=../../fuzix.bin of=fuzix.tmp bs=256 skip=240
	dd if=fuzix.tmp of=../../fuzix.bin bs=1024 seek=32 conv=notrunc
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

bootfuz.bin: bootloader.s
	lwasm -r -b -obootfuz.bin bootloader.s

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# We have 2048 blocks at the start which are the partition table then our
	# image blocks
	# Write the rest of the images to the disks
	dd if=../../fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=1 conv=notrunc
	# Loader
	cp bootfuz.bin $(IMAGES)
