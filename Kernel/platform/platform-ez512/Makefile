CROSS_CCOPTS += -I../../dev/

CSRCS = devtty.c
CSRCS += devices.c main.c sd.c

DISCSRCS = discard.c

ASRCS = ez512.S crt0.S ide.S tricks.S commonmem.S serial.S

DISCARD_DSRCS = ../../dev/tinydisk_discard.c ../../dev/ds1302_discard.c
DISCARD_DSRCS += ../../dev/tinyide_discard.c ../../dev/tinysd_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c ../../dev/tinysd.c
DSRCS += ../../dev/ds1302.c
NSRCS =

DASRCS = ../../dev/ds1302_rcbusu.S ../../dev/z80usoftsd.S ../../dev/z80usoftspi.S

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))
DISCOBJS = $(DISCSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))

OBJS  = $(COBJS) $(AOBJS) $(NOBJS) $(DISCOBJS) $(DOBJS) $(DISCARD_DOBJS) $(DAOBJS)

all:	$(OBJS)

serial.S: serialgen serial.hdr
	./serialgen >serial.S

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DISCOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

clean:
	rm -f core *~ *.bin *.o *.tmp fuzix.romwbw fuzix.tmpmap serial.S

#
#	Attach the kernel to the boot block
#
image:	bootblock
	$(CROSS_LD) -b -C 0x0100 -S 0xF000 -f CLDBbXSs -o fuzix.bin \
	crt0.o commonmem.o ez512.o ../../start.o ../../version.o \
	../../cpu-z80u/lowlevel-z80u.o ../../usermem.o tricks.o main.o discard.o sd.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o ../../filesys.o \
	../../blk512.o ../../process.o ../../inode.o ../../syscall_exec.o \
	../../syscall_exec16.o ../../syscall_fs.o ../../syscall_fs2.o \
	../../syscall_fs3.o ../../syscall_proc.o ../../syscall_other.o \
	../../syscall_net.o ../../network.o ../../tty.o ../../mm.o ../../mm/bankfixed.o \
	../../mm/memalloc_none.o ../../swap.o ../../devsys.o devtty.o \
	tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o ide.o \
	tinysd.o tinysd_discard.o ds1302.o ds1302_discard.o ds1302_rcbusu.o \
	z80usoftsd.o z80usoftspi.o serial.o \
	 /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 <../../fuzix.map fuzix.bin ../../fuzix.bin
	cp boot-romwbw.bin fuzix.romwbw
	dd if=../../fuzix.bin bs=256 skip=1 seek=4 of=fuzix.romwbw
#
#	Compile up the boot block
#
bootblock:
	asz80 boot-romwbw.S
	ldz80 -b boot-romwbw.o -o boot-romwbw.tmp
	# Chop off the leading 61440 bytes we don't want
	dd if=boot-romwbw.tmp of=boot-romwbw.bin bs=512 count=2 skip=120

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.romwbw of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.20M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
