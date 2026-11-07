CROSS_CCOPTS += -I../../dev/ 

CSRCS = sdxfer.c devtty.c
CSRCS += devices.c main.c

DISCSRCS = discard.c

ASRCS = nano-z80.S vt.S crt0.S
ASRCS += tricks.S commonmem.S

DISCARD_DSRCS = ../../dev/tinydisk_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/mbr.c
NSRCS = ../../dev/net/net_native.c

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
NOBJS = $(patsubst ../../dev/net/%.c,%.o, $(NSRCS))
DISCOBJS = $(DISCSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))

OBJS  = $(COBJS) $(AOBJS) $(NOBJS) $(DISCOBJS) $(DOBJS) $(DISCARD_DOBJS)

JUNK =  *.lst *.asm *.Sym *.rst *.lnk *.s *.\^ *.\# *.\% *.\@

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCOBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(NOBJS): %.o: ../../dev/net/%.c                                                
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<   

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $<

clean:
	rm -f $(OBJS) $(JUNK)  core *~ fuzix.com fuzix.bin fuzix.tmpmap
#
# Create kernel binary to put in the disk image
#
image:
	$(CROSS_LD) -b -C 0x0088 -X 0xD400 -S 0xF000 -f CLDBbXSs -o fuzix.bin \
	crt0.o commonmem.o nano-z80.o vt.o tricks.o devtty.o sdxfer.o main.o \
	discard.o \
	../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o \
	../../timer.o ../../devsys.o ../../kdata.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../mm/bankfixed.o ../../vt.o ../../dev/net/net_native.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 <../../fuzix.map fuzix.bin ../../fuzix.bin
	#../../cpm-loader-fcc/makecpmloader ../../cpm-loader-fcc/cpmload.bin ../../fuzix.bin 0x88 fuzix.com

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage:
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
	# Add the kernel
	dd if=../../fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=2 conv=notrunc

	# Copy the kernel / cpm loader to Images
	#cp fuzix.com $(IMAGES)
	
