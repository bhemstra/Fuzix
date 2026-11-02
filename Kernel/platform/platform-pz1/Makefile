
CSRCS = devtty.c devhd.c
CSRCS += main.c devices.c

CDSRCS = ../../dev/tinydisk_discard.c

DSRCS = ../../dev/tinydisk.c

ASRCS = pz1.S crt0.S
ASRCS += tricks.S commonmem.S

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
CDOBJS = $(patsubst ../../dev/%.c,%.o, $(CDSRCS))

OBJS  = $(COBJS) $(AOBJS) $(DOBJS) $(CDOBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -Tcommon $< -o $@

$(CDOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $< -o $@

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -Tcommon -c $< -o $@

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $< -o $@

clean:
	rm -f *.o core *~ fuzix.img fuzix.bin fuzix.tmpmap

image:
	$(CROSS_LD) -b -X 0x2200 -S 0x0200 -C 0x4000 -f SsDLXCBb -o ../../fuzix.bin -m fuzix.tmpmap \
	crt0.o commonmem.o pz1.o ../../start.o ../../version.o \
	../../cpu-6502/lowlevel-6502.o 	tricks.o main.o ../../timer.o \
	../../kdata.o devices.o devhd.o ../../mm/memalloc_none.o \
	tinydisk.o tinydisk_discard.o ../../devio.o ../../filesys.o \
	../../process.o ../../inode.o ../../syscall_fs.o \
	../../syscall_proc.o ../../syscall_other.o ../../mm.o ../../mm/bankfixed.o \
	../../tty.o ../../devsys.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_exec16.o ../../syscall_exec.o ../../blk512.o \
	../../usermem.o ../../cpu-6502/usermem_std-6502.o devtty.o \
	 /opt/fcc/lib/6502/lib6502.a
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)

diskimage: image
	cp ../../fuzix.bin $(IMAGES)/fuzix.rom
	# Make a blank disk image with partition
	dd if=$(FUZIX_ROOT)/Standalone/filesystem-src/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync
	# Add the file system
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc
