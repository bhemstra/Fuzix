ASRCS = crt0.S tricks.S commonmem.S aqplus.S iop.S video.S
CSRCS = devices.c main.c devtty.c disk.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinydisk.c
#NSRCS = ../../dev/net/net_native.c

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DAOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $@ $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

loader.rom: loader.S
	fcc -c -mz80 loader.S
	ldz80 -b loader.o -o loader.tmp -m loader.map
	dd if=loader.tmp of=loader.rom bs=8192 skip=7 count=1 conv=sync
	
image: loader.rom
	$(CROSS_LD) -b -C 0x0400 -X 0xC800 -S 0xF000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o aqplus.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../cpu-z80u/usermem_std-z80u.o \
	../../usermem.o tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bank16k.o ../../devsys.o ../../vt.o \
	devtty.o tinydisk.o tinydisk_discard.o disk.o iop.o video.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

clean:
	rm -f *.o core *~ *.tmp fuzix.tmpmap loader.rom loader.map

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	dd if=../../fuzix.bin of=$(IMAGES)/FUZIX.BIN bs=65536 conv=sync
	cp $(IMAGES)/disk.img $(IMAGES)/FUZIXHD0.IMG
	cp loader.rom $(IMAGES)

	