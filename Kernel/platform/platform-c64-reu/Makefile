
CSRCS = devtty.c
CSRCS += devices.c main.c discard.c devinput.c

ASRCS = c64.S crt0.S reu.S usermem.S vtout.S mouse.S
ASRCS += tricks.S commonmem.S

DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c

COBJS = $(CSRCS:.c=$(BINEXT))
AOBJS = $(ASRCS:.S=$(BINEXT))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))

OBJS  = font8x8.o $(COBJS) $(AOBJS) $(DOBJS) $(DISCARD_DOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS)

font8x8.o: ../../font/font8x8.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c ../../font/font8x8.c -o $@ -p force_common.peep

$(COBJS): %$(BINEXT): %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $< -Toverlay5

$(AOBJS): %$(BINEXT): %.S
	$(CROSS_AS) $(ASOPTS) $< -o $*$(BINEXT)

$(DOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c -Toverlay5 $<
	mv ../../dev/$*.o .

$(DISCARD_DOBJS): %$(BINEXT): ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<
	mv ../../dev/$*.o .

clean:
	rm -f *.o core *~ fuzix.img fuzix.bin *.tmp fuzix.tmpmap
	rm -f fuzix.relocs fuzix.shared

image:
	$(CROSS_LD) -b -f CLSsDBbX -S 0x0800 -Z 0x00 -O 0x8000 -C 0xAC00 -X 0x4200 \
	-o ../../fuzix.bin -m fuzix.tmpmap -R fuzix.relocs \
	font8x8.o crt0.o commonmem.o c64.o discard.o vtout.o mouse.o \
	../../start.o ../../version.o ../../cpu-6502/lowlevel-6502.o \
	tricks.o main.o reu.o ../../timer.o ../../kdata.o devices.o \
	tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o ../../mm/memalloc_none.o \
	../../devio.o ../../filesys.o ../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../swap.o \
	 ../../mm/bankfixed.o ../../tty.o ../../devsys.o ../../syscall_fs2.o \
	 ../../syscall_fs3.o ../../syscall_exec16.o ../../syscall_exec.o \
	 ../../blk512.o ../../usermem.o usermem.o \
	 devtty.o devinput.o ../../devinput.o \
	 /opt/fcc/lib/6502/lib6502.a
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	bankman ../../fuzix.bin fuzix.tmpmap fuzix.relocs 6502
	# Now assemble an image in cartridge layout
	# Copy common from AC00 into a temporary
	dd if=../../fuzix.bin of=fuzix.shared bs=1024 skip=43 count=5
	# Pack ROM bank 1
	# Insert first 8K block (0000-1FFF)
	dd if=../../fuzix.bin bs=8192 seek=0 skip=0 count=1 of=fuzix.rom
	# Insert leading boot area (0x8000 in our image to 0x0000)
	dd if=../../fuzix.bin bs=256 seek=0 skip=128 count=1 of=fuzix.rom conv=notrunc
	# Insert high block 4000-5FFF
	dd if=../../fuzix.bin bs=8192 seek=1 skip=2 count=1 of=fuzix.rom
	# 8000-BFFF from overlay0 into cartridge bank 1
	dd if=../../fuzix.bin bs=8192 skip=12 seek=2 count=2 of=fuzix.rom
	# 8000-BFFF from overlay1 into cartridge bank 2
	dd if=../../fuzix.bin bs=8192 skip=20 seek=4 count=2 of=fuzix.rom
	# 8000-BFFF from overlay2 into cartridge bank 3
	dd if=../../fuzix.bin bs=8192 skip=28 seek=6 count=2 of=fuzix.rom
	# 8000-BFFF from overlay3 into cartridge bank 4
	dd if=../../fuzix.bin bs=8192 skip=36 seek=8 count=2 of=fuzix.rom
	# 8000-BFFF from overlay3 into cartridge bank 5
	dd if=../../fuzix.bin bs=8192 skip=44 seek=10 count=2 of=fuzix.rom
	# Insert the shared code into each bank
	dd if=fuzix.shared of=fuzix.rom bs=1024 seek=27 conv=notrunc
	dd if=fuzix.shared of=fuzix.rom bs=1024 seek=43 conv=notrunc
	dd if=fuzix.shared of=fuzix.rom bs=1024 seek=59 conv=notrunc
	dd if=fuzix.shared of=fuzix.rom bs=1024 seek=75 conv=notrunc
	dd if=fuzix.shared of=fuzix.rom bs=1024 seek=91 conv=notrunc
	# And size out. We've filled 6 banks of 8
	dd if=/dev/zero of=fuzix.rom bs=16384 seek=6 count=2
	
IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the bootstrap loader
	# dd if=loader.bin of=$(IMAGES)/disk.img conv=notrunc
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
	# And the cartridge (use the .rom file or VICE seems to break ?)
	#cartconv -t ide64 -i fuzix.rom -o $(IMAGES)/fuzix.crt
	cp fuzix.rom $(IMAGES)


