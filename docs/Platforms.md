# Supported Platforms

This tree builds Fuzix for two Tandy machines, both Z80 based.

## TRS-80 Model 4, 4D and 4P (`TARGET=trs80`)

128K of RAM (or a larger banked memory board), floppy drives, the Tandy
hard disk, the serial port, the printer port and optionally the hi-res
graphics board. See `Kernel/platform/platform-trs80/README.md`.

## TRS-80 Model II, 12, 16 and 6000 (`TARGET=trs80m2`)

The Z80 side of the machine with 96K or more of RAM, 8" floppy drives, the
Tandy 8MB hard disk, both serial ports and the printer port. See
`Kernel/platform/platform-trs80m2/README.md`.
