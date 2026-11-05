# steal what we can from nx32 port
vpath %.S ../platform-dragon-nx32
vpath %.c ../platform-dragon-nx32

CSRCS = devlpr.c devtty.c devfd.c ttydw.c devinput.c
CSRCS += devices.c main.c libc.c

VSRCS = vc.c

CDSRCS = discard.c

DSRCS = ../../dev/devdw.c ../../dev/tinydisk.c ../../dev/tinyide.c \
        ../../dev/crt9128.c \
        ../../dev/tinysd.c

DDSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c \
         ../../dev/tinysd_discard.c

ASRCS = crt0.S dragon.S mem-mooh.S video.S ide.S spi.S
ASRCS += tricks.S commonmem.S usermem_sam.S floppy.S ../../dev/drivewire/drivewire.S
ASRCS += multihead.S vc_asm.S

COBJS = $(CSRCS:.c=$(BINEXT))
VOBJS = $(VSRCS:.c=$(BINEXT))
CDOBJS = $(CDSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:.S=$(BINEXT))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
OBJS  = $(COBJS) $(VOBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS)

CROSS_CCOPTS += -I../../dev/ -I../platform-dragon-nx32/

../../dev/drivewire/drivewire.o: ASOPTS += -DBECKER=$(BECKER)

JUNK = $(CSRCS:.c=.o) $(ASRCS:.S=.o) *~ 

all: $(OBJS)

$(COBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $< -o $@

$(VOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_VIDEO) -c $< -o $@

$(CDOBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $< -o $@

$(DDOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AOBJS): %$(BINEXT): %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f $(OBJS) $(JUNK)

image: ../../tools/decb-mooh
	$(CROSS_LD) -b -8 0x0008 -S 0x0400 -C 0x2000 -f sSLCbXDB \
	-o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o commonmem.o usermem_sam.o dragon.o mem-mooh.o ../../mm/bank8k.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devfd.o floppy.o devices.o \
	multihead.o crt9128.o vc.o vc_asm.o \
	../../dev/drivewire/drivewire.o devdw.o ttydw.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_exec16.o \
	../../syscall_fs3.o ../../syscall_exec.o ../../blk512.o ../../devinput.o devinput.o \
	devlpr.o devtty.o libc.o ../../vt.o video.o ../../font/font8x8.o \
	tinydisk.o tinyide.o ide.o tinyide_discard.o tinydisk_discard.o \
	tinysd.o tinysd_discard.o spi.o discard.o  /opt/fcc/lib/6809/lib6809.a
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

#	../../tools/pad256 ../../fuzix.bin
#	../../tools/lw-checkmap ../../fuzix.map
#	../../tools/decb-mooh < ../../fuzix.bin > ../../fuzix-mooh.bin
#	mv ../../fuzix-mooh.bin ../../fuzix.bin


IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Write the rest of the images to the disks
	dd if=../../fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=64 conv=notrunc
