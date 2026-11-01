# Status

This tree has been reduced to the TRS-80 Model 4 and Model II targets. The
status of all other platforms is in the upstream FUZIX repository.

## TRS80 (Model 4, 4D, 4P)

Upstream status: builds, passes basic tests.

Kernel builds with stock SDCC 4.2 now that the kernel is compiled with
`--sdcccall 0` and its own helper library (`Kernel/cpu-z80/sdccrt`). Before
that change a kernel built with SDCC 4.2 linked but did not match the
calling convention of the hand written assembly code.

## TRS80m2 (Model II, 12, 16, 16B, 6000 as a Z80 machine)

New port. Boots from floppy and from hard disk, runs multi user and shuts
down cleanly in the trs80gp emulator. Not yet run on real hardware, see
`Kernel/platform/platform-trs80m2/README.md` for the things to check
first.

## User space

Built with the Fuzix C Compiler and Bintools. Z80 binaries are
relocatable, so the same binaries serve the Model 4 (programs at 0x0100)
and the Model II (programs at 0x8000).
