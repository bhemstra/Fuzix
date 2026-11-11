
CSRCS = devlpr.c devtty.c devfd.c devhd.c devgfx.c
CSRCS += devices.c main.c devinput.c devmega.c
DISCARD_CSRCS = discard.c devhd_discard.c

ASRCS = trs80.S trs80-bank.S crt0.S
ASRCS += tricks.S commonmem.S floppy.S

DSRCS = 

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
OBJS  = $(COBJS) $(AOBJS) $(DISCARD_COBJS) $(DOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS) trs80load.bin

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) *~ *.tmp *.raw fuzix.bin fuzix.tmpmap *.jv3

image: trs80load.bin hdboot.bin
	$(CROSS_LD) -b -C 0x0100 -S 0xE400 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o trs80.o trs80-bank.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../cpu-z80u/usermem_std-z80u.o \
	../../usermem.o tricks.o main.o discard.o \
	devfd.o floppy.o devhd.o devhd_discard.o devgfx.o \
	devices.o ../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../vt.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bankfixed.o ../../devsys.o \
	devtty.o devlpr.o ../../devinput.o devinput.o devmega.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.bin <../../fuzix.map
	dd if=/dev/zero of=boot.raw bs=256 count=720
	# Boot block at 0,0
	dd if=trs80load.bin of=boot.raw bs=256 count=1 conv=notrunc
	# Kernel lives on the end of the disk (so we can add an fs)
	dd if=fuzix.bin of=boot.raw skip=256 bs=1 seek=129024 conv=notrunc
	../../tools/makejv3 -s -t dd40s -d boot.raw boot4p.jv3
	dd if=hdboot.bin of=hdboot.raw bs=256 count=1 conv=notrunc
	../../tools/makejv3 -s -t dd40s -d hdboot.raw hdboot4p.jv3

trs80load.bin: trs80load.S
	fcc -mz80 -c trs80load.S
	ldz80 -b trs80load.o -o trs80load.bin

hdboot.bin: hdboot.S
	fcc -mz80 -c hdboot.S
	ldz80 -b hdboot.o -o hdboot.bin

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Boot floppy
	cp boot4p.jv3 $(IMAGES)/boot.jv3
	cp hdboot4p.jv3 $(IMAGES)/hdboot.jv3
	# Build a file system to fit
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAGH) $(IMAGES)/filesys.img 256 21760)
	# Grow the disk out to 202 cylinders to keep FreHD happy
	dd if=/dev/zero of=disk.tmp bs=1 seek=13238271 count=1
	dd if=$(IMAGES)/filesys.img of=disk.tmp bs=32768 seek=2 conv=notrunc
	dd if=hdboot.bin of=disk.tmp seek=2 bs=128 count=1 conv=notrunc
	dd if=fuzix.bin bs=256 of=disk.tmp seek=4 skip=1 conv=notrunc
	cat xtrsheader disk.tmp >$(IMAGES)/hard4p-0
	../../tools/trslabel $(IMAGES)/hard4p-0
	rm disk.tmp

