ASRCS = crt0.S z180.S commonmem.S p112.S ds1302-p112.S monitor.S ide.S
CSRCS += devices.c main.c devtty.c
DISCARD_CSRCS = discard.c
DISCARD_DSRCS = ../../dev/tinyide_discard.c ../../dev/tinydisk_discard.c
DISCARD_DSRCS += ../../dev/ds1302_discard.c
DSRCS = ../../dev/tinydisk.c ../../dev/tinyide.c ../../dev/devfd.c
DSRCS += ../../dev/ds1302.c
DSRCS += ../../dev/devrd.c
DASRCS = ../../dev/devfd_hw.S ../../dev/devrd_z180_hw.S ../../dev/devrd_hwu.S

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)
DISCARD_COBJS = $(DISCARD_CSRCS:.c=.o)
DISCARD_DOBJS = $(patsubst ../../dev/%.c,%.o, $(DISCARD_DSRCS))
DOBJS = $(patsubst ../../dev/%.c,%.o, $(DSRCS))
DAOBJS = $(patsubst ../../dev/%.S,%.o, $(DASRCS))

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(DAOBJS) $(DISCARD_DOBJS) $(DISCARD_COBJS)

CROSS_CCOPTS += -I../../dev/

all:	$(OBJS)

$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

$(DAOBJS): %.o: ../../dev/%.S
	$(CROSS_AS) $(ASOPTS) $<

$(DISCARD_COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

$(DISCARD_DOBJS): %.o: ../../dev/%.c
	$(CROSS_CC) $(CROSS_CCOPTS) $(CROSS_CC_SEGDISC) -c $<

clean:
	rm -f $(OBJS) core *~ *.o *.tmp *.raw *.bin fuzix.map tdboot.map \
		sector0.tmp s0.tmp fuzix.com fuzix-boot.fdd

z180.o: z180.S kernelu.def ../../cpu-z180/z180.S

# ----------------------------------------------------------------------------
# Legacy CP/M loader and floppy boot sector (NOT TESTED after the fcc port).
#
# flopboot.s, kernel.def and ../../cpm-loader/ are still the original sdas
# sources and tooling. They are not part of "all" or "image"; the targets
# below are kept so the old boot paths can be revived and tested later.
# Needs sdas/sdldz80/makebin and python2 (flopboot-mkimage).
cpmimage:
	$(MAKE) -C ../../cpm-loader
	../../cpm-loader/makecpmloader ../../cpm-loader/cpmload.bin ../../fuzix.bin 0x88 fuzix.com
	../../cpm-loader/makecpmloader ../../cpm-loader/fuzixload.bin ../../fuzix.bin 0x88 fuzix

flopboot.bin: flopboot.s kernel.def
	$(CROSS_AS) $(ASOPTS) flopboot.s
	sdldz80 -nmi flopboot.rel
	makebin -s 65536 flopboot.ihx > flopboot.bin

floppyimage: flopboot.bin
	./flopboot-mkimage flopboot.bin ../../fuzix.bin fuzix-boot.fdd

# ----------------------------------------------------------------------------
# CF/IDE sector-0 bootstrap loader (modern 0x2176 path).
#
# tdboot.S assembles/links standalone (NOT part of the kernel ASRCS or the
# image: link). It is a single .abs file with a STUB at .org 0x8100 and a BODY
# at a second .org 0xFC00 (its run address). ldz80 -b emits each byte at its
# link address, so the stub bytes land at file offset 0x8100 and the body bytes
# at file offset 0xFC00 (a sparse image). The on-disk loader image is a
# TWO-SLICE CONCAT: the stub slice [start,stub_end) followed immediately by the
# body slice [body_start,body_end). In the concatenated image the body bytes
# land at 0x8100+(stub_end-start) -- exactly the load address (body_load ==
# stub_end) the stub's LDIR source points at. The ROM's BtGIDE always loads
# 32 sectors (16 KB) to 0x8100, so the on-disk loader slot is reserved at 32
# sectors (LBA 0..31); the slot is zero-filled then overlaid.
#
# asz80 cannot enforce the code budget (a backward/second .org is silently
# accepted with no overlap diagnostic), so the overrun safety lives here: we
# read the boundary labels out of tdboot.map and fail the build on the
# map-derived gates:
#   anchor  : body_start == 0xFC00 and body_load == stub_end (no .org drift)
#   run-fit : body_end-body_start < 0x200  (body at 0xFC00 stays below SP 0xFE00)
#   slot    : stub_len+body_len <= 0x4000  (fits the 16 KB on-disk slot)
# and assert the ksectors byte lands in sector 0 before the partition table
# (concat-relative offset < 0x1BE). makebin is absent and uncalled.
tdboot.bin: tdboot.S
	fcc -mz80 -c tdboot.S -o tdboot.o
	ldz80 -b -m tdboot.map tdboot.o -o tdboot.tmp
	START=`awk '/ start$$/{print $$1}' tdboot.map`; \
	STUBEND=`awk '/ stub_end$$/{print $$1}' tdboot.map`; \
	BODYSTART=`awk '/ body_start$$/{print $$1}' tdboot.map`; \
	BODYEND=`awk '/ body_end$$/{print $$1}' tdboot.map`; \
	KS=`awk '/ ksectors$$/{print $$1}' tdboot.map`; \
	STUBLEN=$$((0x$$STUBEND - 0x$$START)); \
	BODYLEN=$$((0x$$BODYEND - 0x$$BODYSTART)); \
	test $$((0x$$BODYSTART)) -eq $$((0xFC00)) || \
		{ echo "ERROR: body_start=$$BODYSTART != 0xFC00 (.org drift)"; exit 1; }; \
	test $$((0x$$STUBEND)) -eq $$((0x8100 + $$STUBLEN)) || \
		{ echo "ERROR: stub_end=$$STUBEND not at 0x8100+stub_len"; exit 1; }; \
	test $$BODYLEN -lt $$((0xFE00 - 0xFC00)) || \
		{ echo "ERROR: loader body at 0xFC00 collides with stack 0xFE00 (bodylen=$$BODYLEN)"; exit 1; }; \
	test $$(($$STUBLEN + $$BODYLEN)) -le $$((0x4000)) || \
		{ echo "ERROR: loader overruns 16 KB slot (stub=$$STUBLEN body=$$BODYLEN)"; exit 1; }; \
	KSOFF=$$(($$STUBLEN + 0x$$KS - 0x$$BODYSTART)); \
	test $$KSOFF -lt $$((0x1BE)) || \
		{ echo "ERROR: ksectors byte overruns partition table (offset=$$KSOFF)"; exit 1; }; \
	dd if=tdboot.tmp bs=1 skip=$$((0x$$START)) count=$$STUBLEN of=tdboot.raw; \
	dd if=tdboot.tmp bs=1 skip=$$((0x$$BODYSTART)) count=$$BODYLEN >>tdboot.raw; \
	dd if=/dev/zero of=tdboot.bin bs=512 count=32; \
	dd if=tdboot.raw of=tdboot.bin bs=512 conv=notrunc; \
	echo "tdboot.bin OK: 32 sectors, stub=$$STUBLEN body=$$BODYLEN total=$$(($$STUBLEN+$$BODYLEN)) ksectors@$$KSOFF"

image:
	$(CROSS_LD) -b -C 0x0088 -S 0xF600 -X 0xE000 -f CLDBbXSs \
	-o ../../fuzix.bin \
	crt0.o commonmem.o z180.o p112.o ../../start.o \
	../../version.o \
	../../usermem.o main.o discard.o devices.o \
	../../timer.o ../../kdata.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o \
	../../inode.o ../../syscall_exec.o ../../syscall_exec16.o \
	../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../syscall_net.o \
	../../network.o ../../tty.o ../../mm.o ../../mm/memalloc_none.o \
	../../swap.o ../../mm/bankfixed.o ../../devsys.o \
	../../cpu-z180/lowlevel-z180.o ../../cpu-z180/usermem_std-z180.o \
	devtty.o ds1302-p112.o monitor.o ide.o \
	../../dev/tinydisk.o ../../dev/tinydisk_discard.o \
	../../dev/tinyide.o ../../dev/tinyide_discard.o \
	../../dev/devfd.o ../../dev/devfd_hw.o \
	../../dev/ds1302.o ../../dev/ds1302_discard.o \
	../../dev/devrd.o ../../dev/devrd_z180_hw.o ../../dev/devrd_hwu.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap | sort -n | cut -d" " -f 2- >../../fuzix.map
	../../tools/pack85 ../../fuzix.bin fuzix.bin <../../fuzix.map

IMAGES = $(FUZIX_ROOT)/Images/$(TARGET)
FSRC = $(FUZIX_ROOT)/Standalone/filesystem-src

# ----------------------------------------------------------------------------
# Bootable CF/IDE disk image (modern 0x2176 boot contract).
#
# On-disk layout (G-IDE geometry 4096 cylinders x 16 heads x 16 sectors):
#   LBA 0..31    : 32-sector tdboot loader slot (BtGIDE always loads 32 sectors
#                  to 0x8100). Sector 0 also carries the MBR partition table
#                  (from parttab.40M) + 55AA at 0x1BE..0x1FF for tinydisk ONLY;
#                  the 0x2176 ROM path does not checksum sector 0 or need 55AA.
#   LBA 32..N    : PACKED kernel platform-p112/fuzix.bin (byte 0 == phys 0x0000)
#   LBA 2048..   : root filesystem (MBR partition 0, type 0x7e)
#
# The kernel placed on disk is the PACKED platform-local fuzix.bin (the pack85
# output), NOT the raw Kernel/fuzix.bin: crt0.S relocates common from __bss up
# to __common, which only works on the packed layout.
#
# $(IMAGES)/filesys.img is a required input built separately with
# Standalone/filesystem-src/build-filesystem (not auto-run here).
#
# There is NO checksum step: the ROM's modern 0x2176 path does no sum check.
# The MBR table + 55AA and the ksectors byte are written into sector 0 as
# metadata only.
#	diskimage requires the kernel to have been built already (make all);
#	it does not re-link here because the link vars ($(CROSS_LD) etc.) are
#	only defined in the top-level Kernel/Makefile context, not in the
#	diskimage sub-make. tdboot.bin links with fcc/ldz80 directly so it is
#	safe to build here. This matches platform-smallz180's diskimage.
diskimage: tdboot.bin
	mkdir -p $(IMAGES)
	KSOFF=`awk '/ start$$/{s=strtonum("0x"$$1)} / stub_end$$/{se=strtonum("0x"$$1)} / body_start$$/{bs=strtonum("0x"$$1)} / ksectors$$/{ks=strtonum("0x"$$1)} END{printf "%d", (se-s)+(ks-bs)}' tdboot.map`; \
	NSEC=`expr \( \`stat -c%s fuzix.bin\` + 511 \) / 512`; \
	echo "diskimage: ksectors@$$KSOFF kernel sectors=$$NSEC (kernel @ LBA 32)"; \
	test $$((32 + $$NSEC)) -le 2048 || \
		{ echo "ERROR: kernel ($$NSEC sectors) @ LBA 32 overruns root fs @ LBA 2048"; exit 1; }; \
	test $$NSEC -lt 256 || \
		{ echo "ERROR: kernel sector count $$NSEC does not fit in one byte"; exit 1; }; \
	dd if=$(FSRC)/parttab.40M of=$(IMAGES)/disk.img bs=40017920 conv=sync; \
	dd if=$(IMAGES)/filesys.img of=$(IMAGES)/disk.img bs=512 seek=2048 conv=notrunc; \
	dd if=fuzix.bin of=$(IMAGES)/disk.img bs=512 seek=32 conv=notrunc; \
	cp tdboot.bin sector0.tmp; \
	dd if=$(FSRC)/parttab.40M of=sector0.tmp bs=1 seek=446 skip=446 count=66 conv=notrunc; \
	printf "$$(printf '\\%03o' $$NSEC)" | \
		dd of=sector0.tmp bs=1 seek=$$KSOFF count=1 conv=notrunc; \
	dd if=sector0.tmp of=$(IMAGES)/disk.img bs=512 count=1 seek=0 conv=notrunc; \
	dd if=tdboot.bin of=$(IMAGES)/disk.img bs=512 skip=1 seek=1 count=31 conv=notrunc; \
	rm -f sector0.tmp tdboot.raw tdboot.tmp
	cat $(FSRC)/idehdr.40M $(IMAGES)/disk.img > $(IMAGES)/emu-ide.img
