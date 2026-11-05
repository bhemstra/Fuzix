ASRCS = crt0.S tricks.S commonmem.S sc108.S usermem.S ide.S
CSRCS = devices.c main.c devtty.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinydisk_discard.c
DISCARD_DSRCS += ../../dev/tinyide_discard.c ../../dev/ds1302_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c
DSRCS +=  ../../dev/ds1302.c
DASRCS = ../../dev/ds1302_rcbusu.S
NSRCS = 

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DAOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $@ $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

clean:
	rm -f $(OBJS) *.o *.bin  core *~ *.tmp
	rm -f fuzix.com fuzix.tmpmap fuzix.img

image:	loader.bin loader-acia.bin

loader.bin: loader.S
	fcc -mz80 -c loader.S
	ldz80 -b loader.o -o loader.tmp
	dd if=loader.tmp bs=256 skip=208 of=loader.bin

loader-acia.bin: loader-acia.S
	fcc -mz80 -c loader-acia.S
	ldz80 -b loader-acia.o -o loader-acia.tmp
	dd if=loader-acia.tmp bs=256 skip=208 of=loader-acia.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

image: loader.bin loader-acia.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xF000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o sc108.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u-thunked.o \
	../../usermem.o usermem.o tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o \
	devtty.o tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o \
	ide.o ds1302_rcbusu.o ds1302.o ds1302_discard.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.tmp <../../fuzix.map
	dd if=fuzix.tmp of=fuzix.img bs=256 skip=1

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.img of=$(IMAGES)/disk.img bs=512 seek=24 conv=notrunc
	# And loader (avoiding the partition table)
	dd if=loader.bin of=$(IMAGES)/disk.img bs=256 count=1 conv=notrunc
	dd if=loader.bin of=$(IMAGES)/disk.img bs=512 seek=1 skip=1 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img

	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk-acia.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk-acia.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.img of=$(IMAGES)/disk-acia.img bs=512 seek=24 conv=notrunc
	# And loader (avoiding the partition table)
	dd if=loader-acia.bin of=$(IMAGES)/disk-acia.img bs=256 count=1 conv=notrunc
	dd if=loader-acia.bin of=$(IMAGES)/disk-acia.img bs=512 seek=1 skip=1 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk-acia.img > $(IMAGES)/emu-ide-acia.img
