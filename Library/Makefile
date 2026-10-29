
# Top level makefile for library (Z80 only: TRS-80 Model 4 and Model II)

CFLAGS += -I../Kernel/include

all: tools/syscall_z80 tools/liberror

clean:
	rm -f tools/syscall_z80 tools/liberror

tools/syscall_z80: tools/syscall_z80.c ../Kernel/include/syscall_name.h
	$(CC) $(CFLAGS) -o $@ $<

tools/liberror: tools/liberror.c
	$(CC) $(CFLAGS) -o $@ $<

install:
	mkdir -p /opt/fcc/lib/z80/include/arpa
	mkdir -p /opt/fcc/lib/z80/include/net /opt/fcc/lib/z80/include/netinet
	mkdir -p /opt/fcc/lib/z80/include/readline
	mkdir -p /opt/fcc/lib/z80/include/sys
	install -m 0644 include/*.h /opt/fcc/lib/z80/include
	install -m 0644 include/arpa/*.h /opt/fcc/lib/z80/include/arpa
	install -m 0644 include/net/*.h /opt/fcc/lib/z80/include/net
	install -m 0644 include/netinet/*.h /opt/fcc/lib/z80/include/netinet
	install -m 0644 include/readline/*.h /opt/fcc/lib/z80/include/readline
	install -m 0644 ../Kernel/include/drivewire.h /opt/fcc/lib/z80/include/sys/
	install -m 0644 ../Kernel/include/userstructs.h /opt/fcc/lib/z80/include/sys/
	install -m 0644 ../Kernel/include/drivewire.h include/sys/
	install -m 0644 ../Kernel/include/userstructs.h include/sys/
	install -m 0644 include/sys/*.h /opt/fcc/lib/z80/include/sys
