
CSRCS = devlpr.c devtty.c
DISCARD_CSRCS = discard.c devhd_discard.c
NSRCS = ../../dev/net/net_native.c

ASRCS = trs80.S trs80-bank.S crt0.S vtsupport.S
ASRCS += tricks.S commonmem.S floppy.S floppy3.S stringy.S ide.S

# buffers.c must be in CODE2, direct users are more convenient there as
# the asm helpers then can avoid another switch
C2SRCS = buffers.c devfd.c devhd.c
# And these so CODE1 is under 32K
C2SRCS += devices.c main.c devstringy.c devinput.c devgfx.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c


COBJS = $(CSRCS:.c=.o)
C2OBJS = $(C2SRCS:.c=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
AOBJS = $(ASRCS:.S=.o)
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
OBJS  = $(COBJS) $(C2OBJS) $(AOBJS) $(DISCARD_COBJS) $(DOBJS) $(DISCARD_DOBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS) trs80load.bin

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG1) -c $<

$(C2OBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $<

clean:
	rm -f *.o *.lst *.asm *.lst *.sym *.adb *.rst *.ihx core *~

image: trs80load.bin trs80load-m3.bin
	$(CROSS_LD) -b -D 0x4300 -O 0x8C00 -9 0xF400 -f DLSsBCXb -o fuzix.bin \
	crt0.o commonmem.o trs80.o trs80-bank.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u-banked.o \
	../../usermem.o tricks.o main.o discard.o \
	devfd.o floppy.o floppy3.o devhd.o devhd_discard.o devgfx.o \
	devstringy.o stringy.o devices.o buffers.o \
	../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../vt.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bankfixed.o ../../devsys.o \
	devtty.o ../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../dev/tinyide.o ../../dev/tinyide_discard.o \
	devlpr.o vtsupport.o ../../devinput.o devinput.o ide.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap -R fuzix.relocs
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	# Move the 8000-8BFF block into both banks
	dd if=fuzix.bin of=fuzix.bin bs=256 skip=128 count=12 seek=384 conv=notrunc
	dd if=fuzix.bin of=fuzix.bin bs=256 skip=128 count=12 seek=640 conv=notrunc
	# Perform the banking conversion
	bankman fuzix.bin fuzix.tmpmap fuzix.relocs z80

	dd if=/dev/zero of=boot.raw bs=256 count=400
	# Boot block at 0,0
	dd if=trs80load.bin of=boot.raw bs=256 count=1 conv=notrunc
	# 16K of common at 1,0 0x4300-
	dd if=fuzix.bin of=boot.raw bs=256 count=61 seek=10 conv=notrunc skip=67
	# Followed directly by bank1 (32K)
	dd if=fuzix.bin of=boot.raw bs=256 count=128 seek=71 conv=notrunc skip=384
	# And then bank2 (32K)
	dd if=fuzix.bin of=boot.raw bs=256 count=128 seek=199 conv=notrunc skip=640
	# And turn it into a single sided 40 track fm image
	../../tools/makejv3 -s -t sd40s -d boot.raw boot.jv3

	dd if=/dev/zero of=boot.raw bs=256 count=720
	# Boot block at 0,0
	dd if=trs80load-m3.bin of=boot.raw bs=256 count=1 conv=notrunc
	# 16K of common at 1,0 0x4300-
	dd if=fuzix.bin of=boot.raw bs=256 count=61 seek=18 conv=notrunc skip=67
	# Followed directly by bank1 (32K)
	dd if=fuzix.bin of=boot.raw bs=256 count=128 seek=79 conv=notrunc skip=384
	# And then bank2 (32K)
	dd if=fuzix.bin of=boot.raw bs=256 count=128 seek=207 conv=notrunc skip=640
	# And turn it into a single sided 40 track fm image
	../../tools/makejv3 -s -t dd40s -d boot.raw boot3.jv3

trs80load.bin: trs80load.S
	fcc -mz80 -c trs80load.S
	ldz80 -b trs80load.o -o trs80load.tmp
	dd if=trs80load.tmp of=trs80load.bin bs=256 skip=66 count=1

trs80load-m3.bin: trs80load-m3.S
	fcc -mz80 -c trs80load-m3.S
	ldz80 -b trs80load-m3.o -o trs80load-m3.tmp
	dd if=trs80load-m3.tmp of=trs80load-m3.bin bs=256 skip=66 count=1

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	cp boot.jv3 $(IMAGES)
	cp boot3.jv3 $(IMAGES)
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAGH) $(IMAGES)/filesys.img 256 21760)
	cat xtrsheader $(IMAGES)/filesys.img >$(IMAGES)/hard1-0
	../../tools/trslabel $(IMAGES)/hard1-0
