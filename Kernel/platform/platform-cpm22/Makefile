
CSRCS += devices.c main.c devfd.c devinput.c devlpr.c devtty.c

ASRCS = crt0.S cpm.S lowlevel.S
ASRCS += tricks.S commonmem.S

AOBJS = $(ASRCS:.S=.o)
COBJS = $(CSRCS:.c=.o)

OBJS  = $(AOBJS) $(COBJS) $(DOBJS) $(NOBJS)

all:	$(OBJS)

sysmod_E000.o: sysmod_example.S
	$(CROSS_AS) -c -DBASE=0xE000 sysmod_example.S -o sysmod_E000.o
	
sysmod_D000.o: sysmod_example.S
	$(CROSS_AS) -c -DBASE=0xD000 sysmod_example.S -o sysmod_D000.o
	
$(AOBJS): %.o: %.S
	$(CROSS_AS) $(ASOPTS) $<

$(COBJS): %.o: %.c
	$(CROSS_CC) $(CROSS_CCOPTS) -c $<

clean:
	rm -f $(OBJS) core *~ sysmod_E000.o sysmod_D000.o

image: sysmod_E000.o sysmod_D000.o
	$(CROSS_LD) -b -C 0x100 -S 0xF000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o cpm.o lowlevel.o main.o ../../start.o ../../version.o \
	../../cpu-z80u/lowlevel-z80u.o ../../cpu-z80u/usermem_std-z80u.o tricks.o \
	../../timer.o ../../kdata.o ../../usermem.o devfd.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o ../../inode.o ../../syscall_exec.o \
	../../syscall_exec16.o ../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../tty.o ../../mm.o \
	../../mm/memalloc_none.o ../../mm/bankfixed.o ../../swap.o ../../devsys.o ../../devinput.o \
	devlpr.o devtty.o devinput.o sysmod_E000.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	cp ../../fuzix.bin fuzix56.com
	$(CROSS_LD) -b -C 0x100 -S 0xE000 -f CLDBbXSs -o ../../fuzix.bin \
	crt0.o commonmem.o cpm.o lowlevel.o main.o ../../start.o ../../version.o \
	../../cpu-z80u/lowlevel-z80u.o ../../cpu-z80u/usermem_std-z80u.o tricks.o \
	../../timer.o ../../kdata.o ../../usermem.o devfd.o devices.o ../../devio.o \
	../../filesys.o ../../blk512.o ../../process.o ../../inode.o ../../syscall_exec.o \
	../../syscall_exec16.o ../../syscall_fs.o ../../syscall_fs2.o ../../syscall_fs3.o \
	../../syscall_proc.o ../../syscall_other.o ../../tty.o ../../mm.o \
	../../mm/memalloc_none.o ../../mm/bankfixed.o ../../swap.o ../../devsys.o ../../devinput.o \
	devlpr.o devtty.o devinput.o sysmod_D000.o \
	/opt/fcc/lib/z80/libz80.a -m fuzix.tmpmap
	perl -lpe '$$_=hex' fuzix.tmpmap | paste -d" " - fuzix.tmpmap  |  sort -n |  cut -d" " -f 2- >../../fuzix.map
	cp ../../fuzix.bin fuzix48.com
