#
APPS = util cmd sh games cave cpm v7games games cursesgames \
       netd MWC ue cpmfs plato \
       cpnet dw assembler CC cpp ar \
       2048

.PHONY: $(APPS)

all:	$(APPS)

util:
	+(cd util; $(MAKE) -f Makefile.$(USERCPU))

cmd:
	+(cd V7/cmd; $(MAKE) -f Makefile.$(USERCPU))

sh:
	+(cd V7/cmd/sh; $(MAKE) -f Makefile.$(USERCPU))

v7games:
	+(cd V7/games; $(MAKE) -f Makefile.$(USERCPU))

cave:
	+(cd cave; $(MAKE) -f Makefile.$(USERCPU))

cpm:
	+(cd cpm; $(MAKE) -f Makefile.$(USERCPU))

games:
	+(cd games; $(MAKE) -f Makefile.$(USERCPU))

2048:
	+(cd games/2048; $(MAKE) -f Makefile.$(USERCPU))

cursesgames:
	+(cd cursesgames; $(MAKE) -f Makefile.$(USERCPU))



netd:
	+(cd netd; $(MAKE) -f Makefile.$(USERCPU))

MWC:
	+(cd MWC/cmd; $(MAKE) -f Makefile.$(USERCPU))


levee:
	+(cd levee; $(MAKE) -f Makefile.$(USERCPU))

ue:
	+(cd ue; $(MAKE) -f Makefile.$(USERCPU))

cpmfs:
	+(cd cpmfs/src; $(MAKE) -f Makefile.$(USERCPU))

plato:
	+(cd plato; $(MAKE) -f Makefile.$(USERCPU))


cpnet:
	+(cd cpnet; $(MAKE) -f Makefile.$(USERCPU))

dw:
	+(cd dw; $(MAKE) -f Makefile.$(USERCPU))

assembler:
	+(cd assembler; $(MAKE) -f Makefile.$(USERCPU))

CC:
	+(cd CC; $(MAKE) -f Makefile.$(USERCPU))

cpp:
	+(cd cpp; $(MAKE) -f Makefile.$(USERCPU))

ar:
	+(cd ar; $(MAKE) -f Makefile.$(USERCPU))

clean:
	(cd util; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd V7/cmd; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd V7/cmd/sh; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd V7/games; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd cave; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd cpm; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd games; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd games/2048; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd cursesgames; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd netd; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd MWC/cmd; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd levee; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd ue; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd cpmfs/src; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd plato; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd cpnet; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd assembler; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd CC; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd cpp; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd dw; $(MAKE) -f Makefile.$(USERCPU) clean)
	(cd ar; $(MAKE) -f Makefile.$(USERCPU) clean)
