
CSRCS = devlpr.c devtty.c devfd.c devhd.c devgfx.c
CSRCS += devices.c main.c devinput.c
DISCARD_CSRCS = discard.c devhd_discard.c

ASRCS = trs80.s trs80-bank.s crt0.s
ASRCS += tricks.s commonmem.s floppy.s drivewire.s

DSRCS = ../../dev/devdw.c

COBJS = $(CSRCS:.c=.rel)
AOBJS = $(ASRCS:.s=.rel)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.rel)
DOBJS = $(patsubst ../../dev/%.c,%.rel, $(DSRCS))
OBJS  = $(COBJS) $(AOBJS) $(DISCARD_COBJS) $(DOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS) trs80load.bin

$(COBJS): %.rel: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(AOBJS): %.rel: %.s
	$(CROSS_AS) $(ASOPTS) $<

$(DOBJS): %.rel: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_COBJS): %.rel: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) *.lst *.asm *.sym *.rst *.lk  core *~

image: trs80load.bin hdload.bin
	dd if=/dev/zero of=boot.raw bs=256 count=720
	# Boot block at 0,0
	dd if=trs80load.bin of=boot.raw bs=256 count=1 conv=notrunc
	# Kernel lives on the end of the disk (so we can add an fs)
	dd if=../../fuzix.bin of=boot.raw bs=1 seek=129024 conv=notrunc
	../../tools/makejv3 -s -t dd40s -d boot.raw boot4p.jv3
	dd if=/dev/zero of=hdboot.raw bs=256 count=720
	dd if=hdload.bin of=hdboot.raw bs=256 count=1 conv=notrunc
	../../tools/makejv3 -s -t dd40s -d hdboot.raw hdboot4p.jv3
	# Hard disk boot zone (cylinder 0, 8 heads x 32 x 256 bytes): sector 1
	# holds the boot sector, the kernel follows from sector 2
	dd if=/dev/zero of=hdzone.bin bs=256 count=256
	dd if=hdload.bin of=hdzone.bin bs=256 seek=1 conv=notrunc
	dd if=../../fuzix.bin of=hdzone.bin bs=256 seek=2 conv=notrunc
	test $$(stat -c %s hdzone.bin) -eq 65536

trs80load.bin: trs80load.s
	sdasz80 -o trs80load.s
	sdldz80 -i trs80load.rel
	makebin -s 256 trs80load.ihx trs80load.bin

hdload.bin: hdload.s
	sdasz80 -o hdload.s
	sdldz80 -i hdload.rel
	makebin -s 256 hdload.ihx hdload.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Boot floppy
	cp boot4p.jv3 $(IMAGES)/boot.jv3
	cp hdboot4p.jv3 $(IMAGES)/hdboot.jv3
	# Hard disk: 202 cylinders of 8 heads x 32 x 256 bytes. Header, boot
	# zone (cylinder 0), the file system on cylinders 1-169 (hda2, 21632
	# blocks) and swap on 170-201 (hda3). Header byte 8 = 0x01 and byte
	# 11 = 0x02 mark it for FreHD as an image that boots natively.
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAGH) $(IMAGES)/filesys.img 256 21632)
	cat xtrsheader hdzone.bin $(IMAGES)/filesys.img >$(IMAGES)/hard4p-0.hdv
	printf '\001' | dd of=$(IMAGES)/hard4p-0.hdv bs=1 seek=8 conv=notrunc
	printf '\002' | dd of=$(IMAGES)/hard4p-0.hdv bs=1 seek=11 conv=notrunc
	../../tools/trslabel $(IMAGES)/hard4p-0.hdv
	truncate -s $$((256 + 202 * 8 * 32 * 256)) $(IMAGES)/hard4p-0.hdv
	rm -f $(IMAGES)/filesys.img
