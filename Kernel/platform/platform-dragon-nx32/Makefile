ifneq ($(MOOH),)
ASOPTS += -DMOOH=1
CROSS_CCOPTS += -DMOOH=1
MEMSRC = mem-nx32-mooh.S
else
MEMSRC = mem-nx32.S
endif
MEMOBJ = $(MEMSRC:.S=.o)

CSRCS = devlpr.c devtty.c devfd.c ttydw.c devinput.c
CSRCS += vc.c devices.c main.c libc.c

CDSRCS = discard.c

DSRCS = ../../dev/devdw.c ../../dev/tinydisk.c ../../dev/tinyide.c \
        ../../dev/crt9128.c \
        ../../dev/tinysd.c ../../dev/tinyscsi.c

DDSRCS = ../../dev/tinyide_discard.c ../../dev/tinyscsi_discard.c \
	 ../../dev/tinydisk_discard.c ../../dev/tinysd_discard.c

ASRCS = crt0.S dragon.S $(MEMSRC) video.S ide.S spi.S scsi_tc3.S
ASRCS += tricks.S commonmem.S usermem_sam.S floppy.S ../../dev/drivewire/drivewire.S
ASRCS += multihead.S vc_asm.S

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
OBJS  = $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS)

CROSS_CCOPTS += -I../../dev/

../../dev/drivewire/drivewire.o: ASOPTS += -DBECKER=$(BECKER)

all: $(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $< -o $@

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*.o

clean:
	rm -f *.o wrap fuzix.decb fuzix.tmpmap

wrap: wrap.c
	$(CC) -Wall -pedantic $< -o $@

image: wrap
	$(CROSS_LD) -b -o ../../fuzix.bin -m fuzix.tmpmap \
	-S 0x2000 -f SsbXCLDB \
	crt0.o commonmem.o usermem_sam.o \
	dragon.o $(MEMOBJ) ../../mm/bankfixed.o \
	../../start.o ../../version.o ../../cpu-6809/lowlevel-6809.o \
	tricks.o main.o ../../timer.o ../../kdata.o devfd.o floppy.o devices.o \
	multihead.o crt9128.o vc.o vc_asm.o \
	../../dev/drivewire/drivewire.o devdw.o ttydw.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o \
	../../tty.o ../../devsys.o ../../usermem.o ../../syscall_fs2.o ../../syscall_exec16.o \
	../../syscall_fs3.o ../../syscall_exec.o ../../blk512.o ../../devinput.o \
	devinput.o devlpr.o devtty.o libc.o ../../vt.o video.o ../../font/font8x8.o \
	tinyide.o tinydisk.o ide.o tinyide_discard.o tinydisk_discard.o \
	tinysd.o tinysd_discard.o spi.o tinyscsi.o tinyscsi_discard.o \
	discard.o /opt/fcc/lib/6809/lib6809.a
# scsi_tc3.o
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	./wrap < ../../fuzix.bin >fuzix.decb

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Write the rest of the images to the disks
	dd if=fuzix.decb of=$(IMAGES)/disk.img bs=512 seek=64 conv=notrunc
