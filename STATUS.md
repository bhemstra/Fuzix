# Status of 0.6 Work

## Move 6502 to Fuzix C Compiler

Done for all but pz1

## Move 6303/6803 to Fuzix C Compiler

Done

## Move 6809 to Fuzix C Compiler

Started but only a couple of conversions finished yet

## Move 68HC11 to Fuzix C Compiler

Not started

## Move 8080 and 8085 to Fuzix C Compiler

All targets completed. Userspace also moved. No relocatable binaries (as
before). Can build applications natively.

## Move Z80/Z180 To Fuzix C Compiler

Userspace entirely moved. Binaries relocatable as before. Need to move to
a better relocation solution for doing dynamic object modules.

Switched to the latest updates to the compiler and bintools kits. These put
everything in a sensibly laid out location.

### Completed

- 2063
- Ampro Litleboard (base and with MDISK)
- Challenger III
- CP/M 2.2 (experimental only but converted)
- Dyno
- EasyZ80
- EZ512
- Genie EG64
- Linc80
- Lobo Max
- Micro80
- Nano-Z80
- Nascom
- NC100 (Amstrad)
- NC200 (Amstrad)
- RBC Mark 4
- RC2014-Tiny
- Rcbus-TP128
- Rcbus-SBC64
- Rcbus-z180
- Rhyophyre
- RIZ180
- SBC2g
- SBCv2
- SC108
- SC111
- SC720
- Searle
- Simple80
- SmallZ80
- Sorceror (Exidy), WIP only
- TC2068 (Sinclair)
- Tom's SBC (ROM based and banked form)
- TRS80 (Model 4/4D/4P)
- TRS80 (XLR8R)
- VZ200
- Z1013
- Z180ITX
- Z1RCC
- Z80All
- Z80-MBC2
- Z80 Membership Card
- Z80Pack
- Z80Retro
- Zeta V2
- ZRC
- ZX+3 (Sinclair)
- ZXDiv (Sinclair)
- ZXDiv48 (Sinclair)
- ZXUno (Sinclair)

### In Progress

- TRS80 Model 1 (weird crash to debug)

### To Complete

- CPC128 / CMCSME (Amstrad)
- Cromemco
- KC87
- MSX1
- MSX2
- MTX (Memotech)
- N8
- Pentagon (base and 1024)
- P112
- PCW8256 (Amstrad)
- RC2014
- Sam Coupe
- Scorpion
- SocZ80


# Target Status

Last updated 2026/09/25

## 2063

Builds, passes basic tests

## 68KNano

Passes basic tests.

## Adam

Work in progress, not targeted for 0.6

## Agon (Agon Light, Olimex AgonLight2)

Passes basic tests.

## AmproLb (Ampro Littleboard) (both with and without mdisk)

Passes basic tests.

## Amstrad NC100

Passes basic tests

## Amstrad NC200

Passes basic tests

## AppleIIe

Long term project - probably needs a better compiler. Not for 0.6. Still not
got enough code density.

## Atari 8bit

Mostly working, 6502 PoC port. Needs some video work, disk optimizatiosn and
further interrupt handling improvements for performance. Probably needs a
6502 video driver for speed.

Signal handling to debug.

## Atari ST

Early 68K work. Now core 68K is stable can be resurrected. Probably not for
0.6

## C64

Similar state to Atari 8bit but ever slower and more in need of performance
tweaks

## C64-REU

Basics done but the bit work is to use the REU for disk I/O. Right now that
breaks on VICE so is tricky to work on.

## C128-Z80

Early experiments, broke VICE so on hold. VICE now fixed so many take
another look.

## Centurion

Early work in progress

## Challenger III

Builds, needs a 0.6 test run

## COCO2 (64K, no cartridge)

Converted, very limited user space size but runs

## COCO2Cart (64K with cartridge ROM)

Passes basic tests

## COCO3

Brett is working on this.

## CPC6128 / CPCSME

Neeeds conversion, should be working

## CPM22

Experimental only. Needs conversion finishing

## CROMEMCO

Needs conversion

## Dragon (MOOH)

Mostly converted, needs a new boot loader

## Dragon (NX32)

Passes basic tests

## Dragon SamX8

Passes basic tests

## Dyno

Passes basic tests

## Easy-Z80

Passes basic tests

## ESP8266

Builds, testing pending

## EZ512

Builds, passes basic tests

## Gemini

Removed for now (early WIP best restarted differently)

## Geneve

Early WIP for TMS99xx. Needs compiler fixes and more yet

## Genie-EG64

Builds, passes basic tests

## IBMPC

Early sketches only

## JackRabbit

Early sketches only

## KC87

Needs conversion

## LINC80

Builds, passes basic tests

## LOBO-MAX 80

Builds, passes basic tests

## MB020 (Plasmo)

Builds, passes basic tests 

## Micro80 (Plasmo)

Builds, passes basic tests

## MicroZ (Plasmo)

Builds, passes basic tests

## Mini11 (Etched Pixels)

Builds, passes basic tests

## MiniM8

Builds, passes basic tests

## MO6 (Thomson)

Work in progress only (need info on cartridge headers to progress)

## MSX1

Needs conversion, look at doing switchable RAM 4000-BFFF version

## MSX2

Needs conversion

## MTX (Memotech)

Needs conversion

## Multicomp09

Not converted, will probably drop

## N8 (Retrobrew)

Conversion in progress

## NASCOM

Builds, passes basic tests

## OSI50x

Builds but too big to be useful. Would need a banked port somehow.

## P112

Builds, not tested

## P90MB (Plasmo)

Builds, some debug needed

## PCW8256 (Amstrad)

Builds, passes basic tests, needs conversion

## PDP11

Work in progress - need a compiler that actually works (gcc still fails on
basic stuff alas)

## Pentagon

Conversion pending

## Pentagon 1024

Conversion pending

## Pico68K

Builds, passes basic tests

## PX4 plus (Epson)

Early WIP, probably never feasible

## PZ1

Conversion in progress

## Rabbit 2000

To merge with jackrabbit

## RBC-Mark4 (Retrobrew)

Builds, passes basic tests

## RBC-Minim68k (Retrobrew)

Builds, passes basic tests

## RC2014

Conversion needed

## RC2014-Tiny

Builds, passes basic tests

## rcbus-1802

Compiler experimentation only

## rcbus-6303

Builds, passes basic tests.

## rcbus-6502

Builds, passes basic tests

## rcbus-65C816

WIP compiler bring up

## rcbus-6800

Builds, passes basic tests

## rcbus-68008

Builds, passes basic tests

## rcbus-6809

Builds, passes basic tests

## rcbus-68hc11

Builds, passes basic tests

## rcbus-8080

Builds, passes basic tests

## rcbus-8085

Builds, passes basic tests

## rcbus-80C188

Early WIP only

## rcbus-ns32k

Builds, passes basic tests

## rcbus-sbc64

Builds, passes basic tests

## rcbus-super8

Compiler bring up work

## rcbus-tms9995

Compiler bring up work

## rcbus-tp128

Builds, passes basic tests

## rcbus-z180

Builds, passes basic tests

## rcbus-z8

Early work, dev board needs changes

## rhyophyre

Builds, passes basic tests

## riz180 (Plasmo)

Builds, passes basic tests

## rosco-r2

Builds

## rpipico (Rapsberry Pi Pico0

Builds

## sam (Sam Coupe)

Needs conversion to fcc

## sbc08k

Builds, passes basic tests

## sbc2g

Builds, passes basic tests

## sbcv2

Builds, passes basic tests

## sc108 (Small Computer Central)

Builds, passes basic tests

## sc111 (Small Computer Central)

Builds, passes basic tests

## sc720 (Small Computer Central)

Builds, passes basic tests

## scorpion

Builds, passes basic tests

## scrumpel

Builds

## searle (Grant Searle Z80)

Builds, passes basic tests

## simple80 (Plasmo)

Builds, passes basic tests

## smallz180

Builds, works on emulator only, fails no hardware

## smallz80

Builds, passes basic tests

## socz80

Needs a plan

## sorceror (Exidy)

Work in progress only

## T100

Early sizing and experimental work in progress only, probably not viable

## TC2068 (Timex)

Builds, passes basic tests, requires Fuzix bintools 2024/6/18 or later.

## Tiny68K (Plasmo)

Builds, passes basic tests

## TM4C129X

Builds, test pending

## TO7/70 (Thomson)

WIP testbed for 6809 banked compiler

## TO8 (Thomson) 

Needs conversion

## TO9 (Thomson)

needs conversion

## Toms SBC

Builds, passes basic tests

## Toms SBC (ROM)

Builds, passes basic tests

## TRS80 (Model 4, 4D, 4P)

Builds, passes basic tests

## TRS80m1 (Model 1/3)

Builds, failing tests

## ubee (Microbee)

Needs conversion

## v65c816(-big)

Work in progress only

## v8080

Builds, passes basic tests

## vrisc32

RISCV toolchain still breaks on us

## vz200

Builds, passes basic tests

## vz700

Experiment only, may well not be possible

## z1013 (Robotron)

Builds, needs testing

## Z1RCC

Builds, passes basic tests

## z180itx (Etched Pixels)

Builds, passes basic tests

## z280rc

Work in progress, post 0.5

## z80all (Plasmo)

Builds, passes basic tests

## z80-bios

Experiment only

## z80-mbc2

Builds, usually passes basic tests, debugging a possible interrupt problem

## z80membership

Builds,passes basic tests

## z80pack

Builds, passes basic tests

## z80retro

Builds, test pending

## zeta-v2

Currently converting to new compiler

## zrc (Plasmo)

Builds, passes basic tests

## zx128

Obsolete experiment (128K spectrum and microdrive)

## ZX+3 (ZX Spectrum +3)

Builds, passes basic tests

## ZXDiv (ZX Spectrum 128K with DIVIDE/DIVMMC)

Builds, passes basic tests

## ZXDiv48 (ZX Spectrum 48K with DIVIDE Plus)

Builds, passes basic tests

## ZXEvo (Evolution)

Early WIP only

## ZX Spectra

Work in progress. 0.5 stretch goal

## ZX Uno

Builds, passes basic tests
