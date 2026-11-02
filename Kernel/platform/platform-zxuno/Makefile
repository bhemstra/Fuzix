CSRCS = devtty.c devices.c main.c
CDSRCS = discard.c
DSRCS = ../../dev/tinysd.c ../../dev/tinydisk.c
DDSRCS = ../../dev/tinysd_discard.c ../../dev/tinydisk_discard.c
DZSRCS = ../../dev/zx/divmmc.c ../../dev/zx/zxkeyboard.c
DZSRCS += ../../dev/zx/devinput.c
AZSRCS = ../../dev/zx/divmmc-spi.S ../../dev/zx/keyscan.S
DDZSRCS = ../../dev/zx/zxuno.c
ASRCS = crt0.S zx128.S zxvideo.S
ASRCS += tricks.S commonmem.S

COBJS = $(CSRCS:.c=.o)
CDOBJS = $(CDSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DDOBJS = $(patsubst ../../dev/%.c,%.o, $(DDSRCS))
AZOBJS = $(patsubst ../../dev/zx/%.S,%.o, $(AZSRCS))
DZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DZSRCS))
DDZOBJS = $(patsubst ../../dev/zx/%.c,%.o, $(DDZSRCS))
OBJS  = font8x8.o $(COBJS) $(CDOBJS) $(AOBJS) $(DOBJS) $(DDOBJS) $(DZOBJS) $(DDZOBJS) $(AZOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/zx/

all:	$(OBJS)

font8x8.o: ../../font/font8x8.c force_literal.peep
	$(CROSS_CC) $(CROSS_CCOPTS) -c ../../font/font8x8.c -o $@ -p force_literal.peep

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(CDOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(AZOBJS): %.o: ../../dev/zx/%.S
	$(CROSS_AS) $(ASOPTS) -c $< -o $@

$(DZOBJS): %.o: ../../dev/zx/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DDZOBJS): %.o: ../../dev/zx/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

clean:
	rm -f *.o core *~ 
	rm -f BOOT.BIN strap.bin load-esx.ihx load-esx.tmp
	rm -f FUZIX.BIN FUZIX fuzix.tmpmap

# Re-order the image and snapshop it
# See the README crt0.S and NOTES. This platform is tricky to layout due to
# design flaws
image:
	$(CROSS_LD) -b -S 0x0100 -D 0x2000 -C 0x4200 -f SLDsBCbX -o ../../fuzix.bin \
	crt0.o commonmem.o zx128.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o \
	tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o ../../vt.o \
	../../devinput.o devinput.o keyscan.o \
	devtty.o font8x8.o tinydisk.o tinydisk_discard.o tinysd.o \
	tinysd_discard.o divmmc.o divmmc-spi.o zxvideo.o zxuno.o \
	zxkeyboard.o ../../mm/bankfixed.o /opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	dd if=../../fuzix.bin of=fuzix.load bs=32768 count=1
	# Build an esxdos friendly setup
	fcc -mz80 -c load-esx.S
	ldz80 -b load-esx.o -o load-esx.tmp
	# Generate the image file we need
	dd if=load-esx.tmp of=FUZIX bs=8192 skip=1

	# Now build a FUZIX.BIN to load
	# in the order we need it
	cp ../../fuzix.bin FUZIX.BIN

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
	dd if=$(IMAGES)/disk.hdf of=$(IMAGES)/disk.mmc bs=534 skip=1
