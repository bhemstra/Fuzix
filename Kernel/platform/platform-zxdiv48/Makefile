CSRCS = devtty.c devices.c main.c buffers.c devrd.c
CDSRCS = discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c
DDSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyide_discard.c
DZSRCS = ../../dev/zx/zxkeyboard.c
DZSRCS += ../../dev/zx/devinput.c
DDZSRCS =
ASRCS = crt0.S zx48.S zxvideo.S rd_divideplus.S
ASRCS += tricks.S commonmem.S
AZSRCS = ../../dev/zx/divide.S ../../dev/zx/keyscan.S

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
AZOBJS = $(patsubst ../../dev/zx/%.S,%.o, $(AZSRCS))
DZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DZSRCS))
DDZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DDZSRCS))
OBJS = font8x8.o $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(DZOBJS) $(DDZOBJS) $(AZOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/zx/

CROSS_CC_SEG3 = -Toverlay3
CROSS_CC_SEG4 = -Toverlay4

all:	$(OBJS)

font8x8.o: ../../font/font8x8.c force_over1.peep
	$(CROSS_CC) $(CROSS_CCOPTS) -c ../../font/font8x8.c -o $@ -p force_over1.peep

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG4) -c $< -o $@

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG4) -c $< -o $@

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AZOBJS): %.o: ../../dev/zx/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(DZOBJS): %.o: ../../dev/zx/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $< -o $@

$(DDZOBJS): %.o: ../../dev/zx/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

clean:
	rm -f *.o core *~ fuzix.tmpmap
	rm -f *.tmp loader loader-zxcf
	rm -f FUZIX.BIN FUZIX comcode

# Re-order the image and turn it into the raw image to load from disk
loader:
	# Build a generic DivIDE plus loader
	fcc -mz80 -c loader.S
	ldz80 -b loader.o -o loader.tmp
	dd bs=1 skip=57344 if=loader.tmp of=loader

loader-zxcf:
	# Build a generic ZXCF+ style loader
	fcc -mz80 -c loader-zxcf.S
	ldz80 -b loader-zxcf.o -o loader-zxcf

image: loader loader-zxcf
	# We repeat some stuff into each bank to make it fit
	$(CROSS_LD) -b -O 0x0080 -S 0x3000 -C 0x5B00 -X 0x8200 \
	-f SLCDBsbX -o ../../fuzix.bin \
	crt0.o commonmem.o zx48.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u-banked.o \
	../../usermem.o tricks.o main.o discard.o devrd.o rd_divideplus.o \
	zxkeyboard.o divide.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o ../../vt.o \
	../../devinput.o devinput.o keyscan.o font8x8.o devtty.o zxvideo.o \
	buffers.o tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap -R fuzix.relocs
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	bankman ../../fuzix.bin fuzix.tmpmap fuzix.relocs z80
	# Now build a FUZIX.BIN to load
	# in the order we need it
	# Extract the common code for each bank
	# Extract 3000-3FFF from the image into a work file
	dd if=../../fuzix.bin bs=4096 skip=3 count=1 of=comcode
	# Drop it into the overlay1 at the end (13000-13FFF in the file)
	dd if=comcode of=../../fuzix.bin bs=4096 seek=19 conv=notrunc
	# Drop it into the overlay2 at the end (23000-23FFF in the file)
	dd if=comcode of=../../fuzix.bin bs=4096 seek=35 conv=notrunc
	# Drop it into the overlay3 at the end (33000-33FFF in the file)
	dd if=comcode of=../../fuzix.bin bs=4096 seek=51 conv=notrunc
	# Drop it into the overlay4 at the end (43000-43FFF in the file)
	dd if=comcode of=../../fuzix.bin bs=4096 seek=67 conv=notrunc
	# Start with the four banks of 16K (including common copies)
	dd if=../../fuzix.bin bs=16384 skip=4 count=1 >FUZIX.BIN conv=sync
	dd if=../../fuzix.bin bs=16384 skip=8 count=1 >>FUZIX.BIN conv=sync
	dd if=../../fuzix.bin bs=16384 skip=12 count=1 >>FUZIX.BIN conv=sync
	dd if=../../fuzix.bin bs=16384 skip=16 count=1 >>FUZIX.BIN conv=sync
	# Now append the 16-32K page
	dd if=../../fuzix.bin bs=16384 skip=1 count=1 >>FUZIX.BIN conv=sync
	# And the 32K-48K page
	dd if=../../fuzix.bin bs=16384 skip=2 count=1 >>FUZIX.BIN conv=sync
	# We now have an image for the loader


IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)
# Adjust to wherever you have ESXDOS unpacked
ESXDOS = $(FUZIX_ROOT)/../ESXDOS

diskimage:
	dd if=hdfstart.bin of=$(IMAGES)/disk.hdf
	# Write a byte at the end to force the size
	dd if=/dev/zero of=$(IMAGES)/disk.hdf bs=1 seek=134218261 count=1
	# Sector 67584 (second partition on the hdfstart we used)
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.hdf bs=34603542 seek=1 conv=notrunc
	dd if=/dev/zero bs=512 count=65536 of=tmp.fat
	mkfs.fat -F16 tmp.fat
	# Sector 2048
	dd if=tmp.fat of=$(IMAGES)/disk.hdf bs=1049110 seek=1 conv=notrunc
	hdfmonkey put $(IMAGES)/disk.hdf $(ESXDOS)/* /
	hdfmonkey put $(IMAGES)/disk.hdf FUZIX.BIN FUZIX.BIN
	hdfmonkey put $(IMAGES)/disk.hdf loader BIN/FUZIX
	dd if=$(IMAGES)/disk.hdf of=$(IMAGES)/disk.raw bs=534 skip=1
	dd if=FUZIX.BIN of=$(IMAGES)/disk.raw bs=512 seek=1 conv=notrunc
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.raw >$(IMAGES)/emu-ide.img
