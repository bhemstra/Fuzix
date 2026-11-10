CSRCS = \
	devfd.c \
	devlpr.c \
	devtty.c \
	devrd.c \
	devaudio.c \
	devgfx.c \
	devices.c \
	main.c \
	m146818.c \
	bank.c

ASRCS = \
	nc200.S \
	crt0.S \
	tricks.S \
	commonmem.S \
	fdc765.S

COBJS = $(CSRCS:.c=.o)
AOBJS = $(ASRCS:.S=.o)
OBJS  = $(COBJS) $(AOBJS)

all: $(OBJS)

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -o $@ -c $<

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) -o $@ $<

clean:
	rm -f $(OBJS) core *~
	rm -f *.o *.map
	rm -f bootblock bootblock.img floppyskeleton.img autoprg.bin bootfloppy.img

bootblock: bootblock.S
	fcc -mz80 -c bootblock.S
	ldz80 -b bootblock.o -o bootblock

image: bootblock
	$(CROSS_LD) -b -C 0x0 -S 0xF000 -X 0xE000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o nc200.o ../../start.o \
	../../version.o ../../cpu-z80u/lowlevel-z80u.o \
	../../usermem.o ../../cpu-z80u/usermem_std-z80u.o \
	tricks.o main.o devrd.o devices.o bank.o \
	devlpr.o devtty.o devaudio.o devgfx.o m146818.o \
	devfd.o fdc765.o ../../timer.o ../../kdata.o ../../devio.o ../../audio.o \
	../../filesys.o ../../blk512.o ../../process.o ../../vt.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/simple.o ../../devsys.o ../../font/font6x8.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.img <../../fuzix.map
	dd if=bootblock of=fuzix.img bs=1 conv=notrunc

cardimage: $(ROOT_DIR)/fuzix.bin bootblock
	dd if=bootblock of=$(ROOT_DIR)/fuzix.bin bs=1 conv=notrunc

floppyimage: cardimage floppyskeleton.img autoprg.bin $(ROOT_DIR)/fuzix.bin
	cp floppyskeleton.img $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img
	truncate $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img --size 7680
	mcopy -i $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img autoprg.bin ::auto.prg
	dd if=$(ROOT_DIR)/fuzix.bin bs=16k skip=0 count=1 | mcopy -i $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img - ::load4000.80
	dd if=$(ROOT_DIR)/fuzix.bin bs=16k skip=1 count=1 | mcopy -i $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img - ::load4000.81
	dd if=$(ROOT_DIR)/fuzix.bin bs=16k skip=2 count=1 | mcopy -i $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img - ::load4000.82
	echo -n | mcopy -i $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img - ::call4100.80

floppyskeleton.img: floppyskeleton.s
	sdasz80 -fflopzws floppyskeleton.o floppyskeleton.s
	sdldz80 -nwmx -i floppyskeleton.ihx floppyskeleton.o
	srec_cat -disable-sequence-warning \
 		floppyskeleton.ihx -intel \
 		-output floppyskeleton.img -binary

autoprg.bin: autoprg.S
	fcc -mz80 -c autoprg.S
	ldz80 -b -C 0xA000 autoprg.o -o autoprg.tmp
	dd if=autoprg.tmp of=autoprg.bin bs=40960 skip=1

diskimage: cardimage floppyimage
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-mini-filesystem $(ENDIANFLAGH) $(FUZIX_ROOT)/Images/$(TARGET)/filesys.img 64 1440)
	(cd $(FUZIX_ROOT)/Standalone/filesystem-src; ./build-mini-filesystem $(ENDIANFLAGH) $(FUZIX_ROOT)/Images/$(TARGET)/pcmcia.tmp 64 1408)
	dd if=fuzix.img bs=327680 conv=sync >pcmcia.tmp2
	cat pcmcia.tmp2 $(FUZIX_ROOT)/Images/$(TARGET)/pcmcia.tmp >$(FUZIX_ROOT)/Images/$(TARGET)/pcmcia.img
	rm -f $(FUZIX_ROOT)/Images/$(TARGET)/pcmcia.tmp pcmcia.tmp2
	dd if=$(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.img of=$(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.full bs=737280 conv=sync
	dsktrans -itype raw -format ibm720 $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.full $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.DSK
	rm -f $(FUZIX_ROOT)/Images/$(TARGET)/fuzixboot.full
	dsktrans -itype raw -format ibm720 $(FUZIX_ROOT)/Images/$(TARGET)/filesys.img $(FUZIX_ROOT)/Images/$(TARGET)/fuzixroot.DSK

