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

CROSS_CCOPTS += -I../../dev/ -I../../dev/net/

CROSS_CC_HIGH = -Tcommon

JUNK = *.o *.map *.bin fuzix.tmpmap cpmboot

all:	$(OBJS)

dart.S: dartgen
	./dartgen >dart.S

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_HIGH) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_HIGH) -c $< -o $@

$(DHOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_HIGH) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $< -o $@

clean:
	rm -f $(OBJS) $(JUNK)  core *~ diskstrap fuzix.rom *.s
	rm -f cpmboot.tmp cpmboot.com diskstrap

cpmboot.com: cpmboot.S
	fcc -mz80 -c cpmboot.S
	ldz80 -b -C 0x100 cpmboot.o -o cpmboot.tmp
	dd if=cpmboot.tmp of=cpmboot.com bs=256 skip=1

image: cpmboot.com
	$(CROSS_LD) -b -C 0x500 -S 0xB000 -X0xA000 -f CXSsLDBb -o ../../fuzix.bin \
	crt0.o commonmem.o lb.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o devlpr.o devfd.o floppy.o \
	devtty.o dart.o  tinydisk.o tinydisk_discard.o \
	tinyscsi.o tinyscsi_discard.o devscsi.o ncr5380.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	dd if=../../fuzix.bin of=fuzix.rom bs=32768 count=1
	# We have a 512 byte hole we leave for the loader
	dd if=../../fuzix.bin of=diskstrap bs=33280 count=1 skip=1
	cat diskstrap >>cpmboot.com

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel extra blocks
	dd if=diskstrap of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc
	cp cpmboot.com $(IMAGES)
	cp fuzix.rom $(IMAGES)
