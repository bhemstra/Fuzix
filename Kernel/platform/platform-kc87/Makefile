ASRCS = crt0.S tricks.S commonmem.S kc87.S ide.S vt.S
CSRCS = devices.c main.c devtty.c devrtc.c devrd.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinyide.c ../../dev/tinydisk.c
DASRCS = 
NSRCS = 

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DHOBJS) $(DAOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS) $(NOBJS)

CROSS_CCOPTS += -I. -I../../dev/ -I../../dev/net/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG2) -c $< -o $@

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $@ $< -o $@

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@ 

$(NOBJS): %.o: ../../dev/net/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEG3) -c $< -o $@

clean:
	rm -f $(OBJS) core *~ fuzix.rom *.tmp
	rm -f mega.rom megarom_shuffle

bootstrap: bootstrap.S megarom_shuffle
	fcc -mz80 -c bootstrap.S
	ldz80 -b bootstrap.o -o bootstrap.tmp
	>bootstrap.bin
	dd if=bootstrap.tmp of=bootstrap.bin bs=512 skip=96 count=1

megarom_shuffle: ../../tools/megarom_shuffle.c
	gcc -Wall -pedantic -Werror ../../tools/megarom_shuffle.c -o megarom_shuffle
	
image:	bootstrap
	$(CROSS_LD) -b -O 0xC000 -S 0x400 -X 0x8000 -f SsCLDBbX -o fuzix.bin \
	crt0.o commonmem.o kc87.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u-banked.o \
	../../cpu-z80u/usermem_std-z80u-banked.o \
	../../usermem.o tricks.o main.o discard.o \
	../../timer.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o  ../../vt.o \
	devtty.o tinydisk.o tinydisk_discard.o tinyide.o tinyide_discard.o \
	devrtc.o ide.o devrd.o vt.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap -R fuzix.relocs
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	# Perform the banking conversion
	bankman fuzix.bin fuzix.tmpmap fuzix.relocs z80
	# Bank 0
	# First 10K bank is the bootstrap plus the relevant common bits
	#dd if=../../fuix.bin of=bootstrap.bin bs=512 skip=2 seek=1 count=19
	# Now pack the kernel banks
	# Bank 1
	#dd if=../../bank1.bin bs=512 skip=96 count=20 >block.tmp
	#dd if=block.tmp bs=10240 conv=sync count=1 >>bootstrap.bin
	# Bank 2
	#dd if=../../bank2.bin bs=512 skip=96 count=20 >block.tmp
	#dd if=block.tmp bs=10240 conv=sync count=1 >>bootstrap.bin
	# Bank 3
	#dd if=../../bank3.bin bs=512 skip=96 count=20 >block.tmp
	#dd if=block.tmp bs=10240 conv=sync count=1 >>bootstrap.bin
	# Bank 4
	#dd if=../../bank4.bin bs=512 skip=96 count=20 >block.tmp
	#dd if=block.tmp bs=10240 conv=sync count=1 >>bootstrap.bin
	## Bank 5: Code for 4000
	#dd if=../../common.bin bs=512 skip=32 count=16 >>bootstrap.bin
	#dd if=/dev/zero bs=2048 count=1 >>bootstrap.bin
	## Bank 6: Code for 6000
	#dd if=../../common.bin bs=512 skip=48 count=16 >>bootstrap.bin
	#dd if=/dev/zero bs=2048 count=1 >>bootstrap.bin
	# Bank 7: Discard for 8200
	#dd if=../../common.bin bs=512 skip=65 count=20 >>bootstrap.bin
	#./megarom_shuffle <bootstrap.bin >mega.rom

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.20M of=$(IMAGES)/disk.img bs=20152320 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys8.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Make an emulator image of it
	cat $(FUZIX_ROOT)/Standalone/filesystem-src/idehdr.20M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
	# ROM
	cp mega.rom $(IMAGES)/mega.rom
