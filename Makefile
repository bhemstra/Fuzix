#
# Set this to the desired platform to build
#
# This tree has been reduced to the Tandy TRS-80 machines only:
#
# trs80:	TRS80 Model 4/4D/4P with 128K RAM (or some other mappers)
# trs80m2:	TRS80 Model II/12/16/6000 (Z80 side) with 96K or more RAM
#
# Both are Z80 systems. The kernel is built with SDCC, the user space
# with the Fuzix Compiler Kit (fcc) and Fuzix-Bintools.

TARGET ?= trs80

include version.mk

# Get the CPU type
include Kernel/platform/platform-$(TARGET)/target.mk

ifeq ($(USERCPU),)
	USERCPU = $(CPU)
endif

# Base of the build directory
FUZIX_ROOT = $(shell pwd)

# FIXME: we should make it possible to do things entirely without /opt/fcc
PATH := /opt/fcc/bin:$(PATH)

# Use Berkeley yacc always (Bison output is too large)
YACC = byacc

# TARGET is what we are building
# CPU is the CPU type for the kernel
# USERCPU is the CPU type for userspace and may be different
export TARGET CPU USERCPU PATH FUZIX_ROOT YACC

# FUZIX_CCOPTS is the global CC optimization level
ifeq ($(FUZIX_CCOPTS),)
	FUZIX_CCOPTS = -O2
endif
export FUZIX_CCOPTS

all: tools stand ltools libs apps kernel

stand:
	+(cd Standalone; $(MAKE))

ltools:
	+(cd Library; $(MAKE) && $(MAKE) install)

libs: ltools
	+(cd Library/libs; $(MAKE) -f Makefile.$(USERCPU) && \
		$(MAKE) -f Makefile.$(USERCPU) install)

apps: libs
	+(cd Applications; $(MAKE))

tools:
	(cd Tools; ./build-$(CPU))

.PHONY: gtags
gtags:
	gtags

kernel: ltools
	mkdir -p Images/$(TARGET)
	+(cd Kernel; $(MAKE))

diskimage: stand ltools libs apps kernel
	mkdir -p Images/$(TARGET)
	+(cd Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAG) $(FUZIX_ROOT)/Images/$(TARGET)/filesys.img 256 65535)
	+(cd Standalone/filesystem-src; ./build-filesystem $(ENDIANFLAG) $(FUZIX_ROOT)/Images/$(TARGET)/filesys8.img 256 16384)
	+(cd Kernel; $(MAKE) diskimage)

kclean:
	+(cd Kernel; $(MAKE) clean)

clean:
	rm -f GPATH GRTAGS GTAGS
	rm -f Images/$(TARGET)/*.img
	rm -f Images/$(TARGET)/*.DSK
	+(cd Standalone; $(MAKE) clean)
	+(cd Library/libs; $(MAKE) -f Makefile.$(USERCPU) clean)
	+(cd Library; $(MAKE) clean)
	+(cd Kernel; $(MAKE) clean)
	+(cd Applications; $(MAKE) clean)
