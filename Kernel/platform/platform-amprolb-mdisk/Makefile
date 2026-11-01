vpath %.c ../platform-amprolb
vpath %.S ../platform-amprolb

ASRCS = crt0.S tricks.S commonmem.S lb.S ncr5380.S dart.S floppy.S
CSRCS = devices.c main.c devtty.c devfd.c devscsi.c devlpr.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinydisk_discard.c ../../dev/tinyscsi_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyscsi.c
DHSRCS = 
DSRCS +=  
DASRCS = 
NSRCS = 

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DHOBJS = $(patsubst ../../dev/%.c,%.o, $(DHSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DHOBJS) $(DAOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(NOBJS)

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/ -I../platform-amprolb

CROSS_CC_HIGH = --codeseg COMMONMEM

JUNK = *.o *.map *.bin

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DHOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $@ $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

dart.S: dartgen
	./dartgen >dart.S

clean:
	rm -f $(OBJS) $(JUNK)  core *~ *.tmp *.o fuzix.com boot.com boot.rom

boot.com: boot.S
	fcc -mz80 -c boot.S
	ldz80 -b boot.o -o boot.tmp
	dd if=boot.tmp of=boot.com bs=256 skip=254

boot.rom: bootrom.S
	fcc -mz80 -c bootrom.S
	ldz80 -b bootrom.o -o boot.tmp
	dd if=boot.tmp bs=256 skip=254 | dd bs=8192 count=1 conv=sync of=boot.rom

# This assumes that code is always big enough to push the other segments
# higher
image: boot.com boot.rom
	$(CROSS_LD) -b -C 0x100 -f CSsLDBbX -o ../../fuzix.bin \
	crt0.o commonmem.o lb.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bankfixed.o ../../devsys.o devlpr.o devfd.o floppy.o \
	devtty.o dart.o  tinydisk.o tinydisk_discard.o \
	tinyscsi.o tinyscsi_discard.o devscsi.o ncr5380.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/packdiscard ../../fuzix.bin fuzix.tmp <fuzix.tmpmap
	dd if=fuzix.tmp of=fuzix.com bs=256 skip=1

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=fuzix.com of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	cp boot.com $(IMAGES)/boot.com
	cp boot.rom $(IMAGES)/boot.rom
	cp fuzix.com $(IMAGES)/fuzix.com
