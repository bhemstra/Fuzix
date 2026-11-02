ASRCS = crt0.S z180.S commonmem.S dyno.S monitor.S
CSRCS += devices.c main.c devtty.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c ../../dev/bq4845.c
DSRCS += ../../dev/devfd.c
DASRCS = ../../dev/devfd_rbc.S ../../dev/tinyide_ppide_rbc.S

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

clean:
	rm -f $(OBJS) core *~ fuzix.com makecpmloader
	rm -f loader.bin loader.tmp boot-romwbw.bin boot-romwbw.tmp
	rm -f fuzix.romwbw fuzix.tmpmap

z180.o: z180.S kernelu.def ../../cpu-z180/z180.S

boot-romwbw.bin: boot-romwbw.S
	fcc -mz80 -c boot-romwbw.S
	# This makes us a binary from physical 0
	ldz80 -b boot-romwbw.o -o boot-romwbw.tmp
	# Chop off the leading 61440 bytes we don't want
	dd if=boot-romwbw.tmp of=boot-romwbw.bin bs=512 conv=sync count=2 skip=120

image: boot-romwbw.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xF600 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o z180.o dyno.o main.o devices.o discard.o \
	devtty.o tinyide.o tinyide_discard.o tinydisk.o tinydisk_discard.o \
	tinyide_ppide_rbc.o monitor.o bq4845.o devfd.o devfd_rbc.o \
	../../libfuzix.a /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.bin <../../fuzix.map
	cat boot-romwbw.bin >fuzix.romwbw
	dd if=/dev/zero bs=256 count=1 >>fuzix.romwbw
	dd if=fuzix.bin bs=256 skip=1  >>fuzix.romwbw

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img conv=notrunc
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.romwbw of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
