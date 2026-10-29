tools/analysemap: tools/analysemap.c

tools/visualize: tools/visualize.c

tools/bihx: tools/bihx.c

tools/binmunge: tools/binmunge.c

tools/memhogs: tools/analysemap
	cp tools/analysemap tools/memhogs

tools/binman: tools/binman.c

tools/modlib-z80: tools/modlib-z80.c

tools/bankld/sdldz80:
	+(cd tools/bankld; $(MAKE))

tools/makejv3: tools/makejv3.c

tools/trslabel: tools/trslabel.c

cpu-z80/sdccrt/sdccrt.lib:
	+$(MAKE) -C cpu-z80/sdccrt

fuzix.ihx: target $(OBJS) platform/platform-$(TARGET)/fuzix.lnk tools/bankld/sdldz80 cpu-z80/sdccrt/sdccrt.lib
	$(CROSS_LD) -n -k $(LIBZ80) -f platform/platform-$(TARGET)/fuzix.lnk

modlib.s: tools/modlib-z80 fuzix.export platform/platform-$(TARGET)/fuzix.export fuzix.map
	tools/modlib-z80 >modlib.s

modlib.rel: modlib.s kmod-z80.rel
	$(CROSS_AS) $(ASOPTS) modlib.s

kmod-z80.rel: cpu-z80/kmod-z80.s
	$(CROSS_AS) $(ASOPTS) cpu-z80/kmod-z80.s

fuzix.bin: fuzix.ihx tools/bihx tools/analysemap tools/memhogs tools/binman tools/binmunge tools/makejv3 tools/trslabel tools/visualize modlib.rel kmod-z80.rel
	-cp hogs.txt hogs.txt.old
	tools/memhogs <fuzix.map |sort -nr >hogs.txt
	head -5 hogs.txt
	tools/visualize < fuzix.map
	tools/bihx fuzix.ihx
	tools/binprep
	+$(MAKE) -C platform/platform-$(TARGET) image

fuzix.map: fuzix.ihx
