ASRCS = crt0.S z180.S commonmem.S riz180.S monitor.S usermem.S ide.S
CSRCS += devices.c main.c devtty.c spi.c wiznet.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/ds1302_discard.c ../../dev/tinysd_discard.c
DISCARD_DSRCS += ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c ../../dev/ds1302.c
DSRCS += ../../dev/tinysd.c
DASRCS = ../../dev/ds1302_rcbusu_z180.S
NSRCS = ../../dev/net/net_w5x00.c

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
	$(CROSS_AS) $(ASOPTS) $@ $<

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) core *~ fuzix.rom

z180.o: z180.S kernelu.def

image:
	$(CROSS_LD) -b -C 0x0000 -D 0xD000 -S 0xF000 -f CLXDBbSs -o ../../fuzix.bin \
	crt0.o commonmem.o z180.o riz180.o main.o devices.o discard.o \
	devtty.o spi.o usermem.o ../../dev/tinyide.o ../../dev/tinyide_discard.o \
	ide.o ../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../dev/tinysd.o ../../dev/tinysd_discard.o \
	monitor.o ../../dev/ds1302.o ../../dev/ds1302_discard.o \
	../../dev/ds1302_rcbusu_z180.o ../../dev/net/net_w5x00.o wiznet.o \
	../../libfuzix.a ../../libfuzix.a /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	dd if=../../fuzix.bin of=fuzix.rom bs=262488 conv=sync

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
	# And the ROM
	cp fuzix.rom $(IMAGES)
