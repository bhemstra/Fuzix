ASRCS = crt0.S tricks.S commonmem.S linc80.S piospi.S piosd.S serial.S
CSRCS = devices.c main.c devtty.c sd.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinysd_discard.c
DISCARD_DSRCS += ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c ../../dev/tinysd.c
NSRCS = 

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/

all:	$(OBJS)

serial.S: serialgen serial.hdr
	./serialgen >serial.S

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

clean:
	rm -f $(OBJS) core *~ fuzix.com loader.tmp loader.bin

image:  loader.bin
	$(CROSS_LD) -b -S 0x300 -f SsCLDBbX -o ../../fuzix.bin \
	crt0.o commonmem.o linc80.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o tricks.o \
	main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../vt.o ../../font/font6x8.o \
	../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o sd.o piospi.o piosd.o \
	devtty.o serial.o tinydisk.o tinydisk_discard.o \
	tinysd.o tinysd_discard.o tinyide.o tinyide_discard.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	dd if=../../fuzix.bin of=fuzix.com bs=256 skip=1 count=248

loader.bin: loader.S
	fcc -mz80 -c loader.S
	ldz80 -b loader.o -o loader.tmp
	dd if=loader.tmp bs=256 skip=208 of=loader.bin

piospi.o: ../../dev/z80usoftspi.S

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the boot block into the partition sector
	dd if=loader.bin bs=446 count=1 of=$(IMAGES)/disk.img conv=notrunc
	# Add the rest of the loader
	dd if=loader.bin bs=512 skip=1 of=$(IMAGES)/disk.img seek=1 conv=notrunc
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.com of=$(IMAGES)/disk.img bs=512 seek=24 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
