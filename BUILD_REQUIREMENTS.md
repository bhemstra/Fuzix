# Build Requirements

This tree only builds for the TRS-80 Model 4 (`TARGET=trs80`) and the
TRS-80 Model II family (`TARGET=trs80m2`). Both are Z80 machines.

## General

Bash shell
GNU Make
Byacc
A host C compiler (gcc or clang) for the build tools

## Kernel

SDCC (sdcc, sdasz80, sdldz80, sdar, makebin). Any 4.x release works.

The kernel assembly code uses the classic stack based SDCC calling
convention. SDCC 4.2 and later default to a register based convention, so
the build passes `--sdcccall 0` when the compiler supports it and links
against the small helper library in `Kernel/cpu-z80/sdccrt` (built with
the same options) instead of the SDCC `z80.lib`. Older compilers that do
not know the option already use the classic convention.

## User space

Fuzix Bintools
https://github.com/EtchedPixels/Fuzix-Bintools

make
make install

Fuzix C Compiler
https://github.com/EtchedPixels/Fuzix-Compiler-Kit

Build the assembler first and ensure it's on your path

make install

Both install into /opt/fcc by default, which the top level Makefile adds
to the path.

## Emulators

- Model 4: xtrs or sdltrs (see Patches/README for an sdltrs fix)
- Model II: MAME (`trs80m2`) or trs80gp, both read the `boot.imd` image
