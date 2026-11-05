ASRCS = crt0.S z180.S commonmem.S n8.S ds1302-n8.S monitor.S vdp.S
ASRCS += keyboard.S mouse.S
CSRCS += devices.c main.c devtty.c devsdspi.c devinput.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/ds1302_discard.c ../../dev/tinydisk_discard.c
DISCARD_DSRCS += ../../dev/tinysd_discard.c ../../dev/tinyide_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/devfd.c
DSRCS += ../../dev/tinysd.c ../../dev/tinyide.c ../../dev/ds1302.c
DSRCS += ../../dev/ps2kbd.c ../../dev/ps2mouse.c ../../dev/tinyide_ppide_rbc.c
DASRCS = ../../dev/devfd_hw.S

AOBJS = $(ASRCS:.S=.rel)
COBJS = $(CSRCS:.c=.rel)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.rel)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.rel, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.rel, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.rel, $(DASRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(DAOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS)

$(AOBJS): %.rel: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.rel: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.rel: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DAOBJS): %.rel: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $@ $<

$(DISCARD_COBJS): %.rel: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.rel: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f *.o *.tmp *.bin core *~
	rm -f fuzix.romwbw fuzix fuzix.tmpmap

z180.o: z180.S kernelu.def ../../cpu-z180/z180.S

#
#	Compile up the boot block
#
image: bootblock vdp.font
	cat boot-romwbw.bin >fuzix.romwbw
	cat vdp.font >>fuzix.romwbw
	dd if=/dev/zero bs=256 count=1 >>fuzix.romwbw
	cat ../../fuzix.bin >>fuzix.romwbw

bootblock:
	fcc -mz180 -c boot-romwbw.S
	# This makes us a binary from physical 0
	ldz80 -b  boot-romwbw.o -o boot-romwbw.tmp
	# Chop off the leading 61440 bytes we don't want
	dd if=boot-romwbw.tmp of=boot-romwbw.bin bs=512 count=2 skip=120

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

vdpfont: vdpfont.c

vdp.font: vdpfont
	./vdpfont > vdp.font

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.romwbw of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
