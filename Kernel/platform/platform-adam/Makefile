ASRCS = crt0.S tricks.S commonmem.S adam.S usermem.S vdp.S ide.S start.S
CSRCS = devices.c main.c devtty.c adamnet.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c
DASRCS =
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

JUNK = *.o *.bin *.tmp

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

clean:
	rm -f $(OBJS) $(JUNK)  core *~
	rm -f boot.tmp boot.bin

image:	boot
	$(CROSS_LD) -b -S 0x0100 -O 0xC000 -C 0xE000 -X 0x4200 -f SsLDBbXC -o fuzix.bin \
	start.o crt0.o commonmem.o adam.o ide.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u-banked.o \
	usermem.o ../../usermem.o tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o ../../vt.o \
	devtty.o tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o \
	vdp.o adamnet.o ../../font/font6x8.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap -R fuzix.relocs
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	# Perform the banking conversion
	bankman fuzix.bin fuzix.tmpmap fuzix.relocs z80
	# Assemble the ROM as a single image

boot:
	fcc -c -mz80 boot.S
	ldz80 -b boot.o -o boot.tmp
	dd if=boot.tmp bs=128 skip=1 of=boot.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
	# And the boot image
	cp boot.bin $(IMAGES)/boot.bin
	dd if=../../fuzix.bin of=$(IMAGES)/boot.bin bs=1024 seek=1 conv=sync
