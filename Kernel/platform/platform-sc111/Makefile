ASRCS = crt0.S z180.S commonmem.S sc111.S monitor.S ide.S
CSRCS += devices.c main.c devtty.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyide_discard.c ../../dev/ds1302_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c ../../dev/ds1302.c
DASRCS = ../../dev/ds1302_rcbusu_z180.S

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(DAOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

clean:
	rm -f *.o core *~ fuzix.com makecpmloader
	rm -f loader.bin loader.tmp boot-romwbw.bin
	rm -f fuzix.tmpmap *.tmp fuzix.bin

z180.o: z180.S kernelu.def ../../cpu-z180/z180.S

boot-romwbw.bin: boot-romwbw.S
	fcc -mz80 -c boot-romwbw.S
	# This makes us a binary from physical 0
	ldz80 -b boot-romwbw.o -o boot-romwbw.tmp
	# Chop off the leading 61440 bytes we don't want
	dd if=boot-romwbw.tmp of=boot-romwbw.bin bs=512 conv=sync count=2 skip=120

loader.bin: loader.S
	fcc -mz80 -c loader.S
	ldz80 -b loader.o -o loader.tmp
	dd if=loader.tmp bs=256 skip=208 of=loader.bin

image: loader.bin boot-romwbw.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xF600 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o z180.o sc111.o main.o devices.o discard.o \
	devtty.o tinyide.o tinyide_discard.o tinydisk.o tinydisk_discard.o \
	monitor.o ds1302.o ds1302_discard.o ds1302_rcbusu_z180.o ide.o \
	../../libfuzix.a ../../libfuzix.a /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.bin <../../fuzix.map
#	cat boot-romwbw.bin >fuzix.romwbw
#	dd if=/dev/zero bs=256 count=1 >>fuzix.romwbw
#	dd if=fuzix.bin bs=256 skip=1  >>fuzix.romwbw

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

#
# The diskimage contains both the ROMWBW loader from 0x0400 to 0x0800
# and the SCM loader from 0x2800 to 0x3000. Kernel at 0x3000 and
# filesystem at 1M is shared between both loaders
#
# |-----------------|0x0000:0000
# | partition table |
# | 0x17C: bootdev  |
# |-----------------|0x0000:0200
# |                 |
# |-----------------|0x0000:0400
# | ROMWBW header   |
# | ROMWBW loader   |
# |-----------------|0x0000:0800
# |                 |
# |-----------------|0x0000:2800
# | SCM loader      |
# |-----------------|0x0000:3000
# | FUZIX kernel    |
# |                 |
# |-----------------|0x0010:0000
# | filesystem      |
# |                 |
#
diskimage: image boot-romwbw.bin loader.bin
	rm -f $(IMAGES)/disk.img
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img conv=notrunc
	# Kernel boot string at 0x17C with signature: 0xB5 0x5E hda1
	printf "\265\136%s\000" "hda1" | dd of=$(IMAGES)/disk.img seek=380 bs=1 conv=notrunc
	# ROMWBW loader at 0x400
	dd if=boot-romwbw.bin of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# SCM loader at 0x2800
	dd if=loader.bin of=$(IMAGES)/disk.img bs=512 skip=20 seek=20 count=4 conv=notrunc
	# Kernel starting 0x3000
	dd if=fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=24 conv=notrunc
	# Filesystem starting at 1M/0x0010:0000
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
