CSRCS = devtty.c devices.c main.c
CDSRCS = discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinysd.c ../../dev/tinydisk.c
DDSRCS = ../../dev/tinyide_discard.c ../../dev/tinysd_discard.c
DDSRCS += ../../dev/tinydisk_discard.c
DZSRCS = ../../dev/zx/divmmc.c ../../dev/zx/zxkeyboard.c
DZSRCS += ../../dev/zx/devinput.c ../../dev/zx/bank128.c
DDZSRCS = ../../dev/zx/zxuno.c
ASRCS = crt0.S zx128.S zxvideo.S
ASRCS += tricks.S commonmem.S loader-divide.S
AZSRCS = ../../dev/zx/divide.S ../../dev/zx/keyscan.S ../../dev/zx/divmmc-spi.S

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
AZOBJS = $(patsubst ../../dev/zx/%.S,%.o, $(AZSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
DZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DZSRCS))
DDZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DDZSRCS))
OBJS  = $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(DZOBJS) $(DDZOBJS) $(AZOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/zx/

CROSS_CC_SEG3 = -Toverlay3

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $< -o $@

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $< -o $@

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
	rm -f BOOT.BIN FUZIX FUZIX.BIN
	rm -f fuzix.relocs tmp.fat

FUZIX: load-esx.o
	ldz80 -b load-esx.o -o load-esx.tmp
	# Generate the image file we need
	dd if=load-esx.tmp of=FUZIX bs=8192 skip=1

load-esx.o: load-esx.S
	# Build an esxdos friendly setup
	fcc -c -mz80 load-esx.S

#	0000-1FFF	: ends up locked for write
#		04C6 / 05C2	: Magic if M1 set (avoid code here)
#		1FF8-1FFF	: DivIDE page out - avoid
#	2000-3FFF	: from DivIDE, can write
#		3D00-3DFF	: DivIDE page in - should be harmless
#	4000-BFFF	: Sinclair unbanked memory
#	C000-FFFF	: Sinclair banked memory
#
image: FUZIX
	$(CROSS_LD) -b -L 0x0400 -O 0xC000 -D 0x5B00 -X 0x8200 -8 0x2200 \
	-f LCSsbDBX -o ../../fuzix.bin \
	crt0.o commonmem.o zx128.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u-banked.o \
	../../cpu-z80u/usermem_std-z80u-banked.o \
	../../usermem.o tricks.o main.o discard.o \
	zxkeyboard.o divide.o zxuno.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o bank128.o ../../devsys.o ../../vt.o \
	../../devinput.o devinput.o keyscan.o ../../font/font8x8.o \
	devtty.o zxvideo.o tinydisk.o tinydisk_discard.o tinyide.o \
	tinyide_discard.o tinysd.o tinysd_discard.o divmmc.o divmmc-spi.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap -R fuzix.relocs
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	bankman ../../fuzix.bin fuzix.tmpmap fuzix.relocs z80

	# build a FUZIX.BIN to load in the order we need it
	# Copy the low 48k
	dd if=../../fuzix.bin bs=16384 count=3 conv=sync of=FUZIX.BIN
	# Overlay 1 C000-FFFF
	dd if=../../fuzix.bin bs=16384 count=1 seek=3 skip=7 of=FUZIX.BIN
	# Overlay 2 C000-FFFF
	dd if=../../fuzix.bin bs=16384 count=1 seek=4 skip=11 of=FUZIX.BIN
	# Overlay 3 C000-FFFF
	dd if=../../fuzix.bin bs=16384 count=1 seek=5 skip=15 of=FUZIX.BIN

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
	hdfmonkey put $(IMAGES)/disk.hdf FUZIX BIN/FUZIX
	dd if=$(IMAGES)/disk.hdf of=$(IMAGES)/disk.raw bs=534 skip=1
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.40M $(IMAGES)/disk.raw >$(IMAGES)/emu-ide.img
