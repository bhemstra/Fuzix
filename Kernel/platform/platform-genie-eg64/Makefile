
CSRCS =
DISCARD_CSRCS = discard.c devhd_discard.c
NSRCS = 

ASRCS = trs80.S trs80-bank.S crt0.S
ASRCS += tricks.S commonmem.S floppy.S

CSRCS = devfd.c devhd.c
CSRCS += devices.c main.c devinput.c
CSRCS += devlpr.c devtty.c
DSRCS =
DISCARD_DSRCS =

COBJS = $(CSRCS:.c=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
AOBJS = $(ASRCS:.S=.o)
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
OBJS  = $(COBJS) $(AOBJS) $(DISCARD_COBJS) $(DOBJS) $(DISCARD_DOBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS) trs80load.bin

$(COBJS): %.o: %.c
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
	rm -f *.o core *~ boot.raw

image: trs80load.bin
	$(CROSS_LD) -b -S 0x0100 -C 0x8000 -f SsLDBbXC -o ../../fuzix.bin \
	crt0.o commonmem.o trs80.o trs80-bank.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o tricks.o main.o discard.o \
	devfd.o floppy.o devhd.o devhd_discard.o \
	devices.o ../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../vt.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o \
	devtty.o devlpr.o ../../devinput.o devinput.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	dd if=/dev/zero of=boot.raw bs=256 count=400
	# Boot block at 0,0
	dd if=trs80load.bin of=boot.raw bs=256 count=1 conv=notrunc
	# With the image straight afterwards
	# Copy 0100-36FF
	dd if=../../fuzix.bin of=boot.raw bs=256 seek=10 skip=1 count=54 conv=notrunc
	# Copy 4000-FFFF
	dd if=../../fuzix.bin of=boot.raw bs=256 skip=64 count=192 seek=64 conv=notrunc
	../../tools/makejv3 -s -t sd40s -d boot.raw boot.jv3

trs80load.bin: trs80load.S
	fcc -mz80 -c trs80load.S
	ldz80 -b trs80load.o -o trs80load.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	cp boot.jv3 $(IMAGES)/boot.jv3
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAGH) $(IMAGES)/filesys.img 256 21760)
	cat xtrsheader $(IMAGES)/filesys.img >$(IMAGES)/hard1-0
	../../tools/trslabel $(IMAGES)/hard1-0
