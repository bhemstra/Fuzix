ASRCS = crt0.S z180.S commonmem.S z1rcc.S monitor.S ide.S
CSRCS += devices.c main.c devtty.c i2c.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/ds1302_discard.c ../../dev/tinysd_discard.c
DISCARD_DSRCS += ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/ds1302.c ../../dev/tinydisk.c
DSRCS += ../../dev/devi2c.c ../../dev/i2c_bitbang.c
DASRCS = ../../dev/ds1302_rcbusu_z180.S
NSRCS =

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(DAOBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $<

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f *.o core *~  *.bin *.tmp fuzix.tmpmap
	

z180.o: z180.S kernelu.def ../../cpu-z180/z180.S

boot.bin: boot.S
	fcc -mz80 -c boot.S
	# This makes us a binary from physical 0
	ldz80 -b boot.o -o boot.tmp
	# Chop off the leading 61440 bytes we don't want
	dd if=boot.tmp bs=256 count=1 skip=255 | \
		../../tools/doubleup >boot.bin

image: boot.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xF400 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o z180.o z1rcc.o main.o devices.o discard.o \
	devtty.o ../../dev/tinyide.o ../../dev/tinyide_discard.o \
	ide.o ../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	monitor.o ../../dev/ds1302.o ../../dev/ds1302_discard.o \
	../../dev/ds1302_rcbusu_z180.o \
	../../dev/i2c_bitbang.o ../../dev/devi2c.o i2c.o \
	../../libfuzix.a ../../libfuzix.a /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.bin <../../fuzix.map

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=1 conv=notrunc
	# Add the loader
	dd if=boot.bin of=$(IMAGES)/disk.img conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
