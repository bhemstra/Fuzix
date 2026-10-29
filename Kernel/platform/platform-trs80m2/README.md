# TRS-80 Model II / 12 / 16 / 6000 (Z80)

**Status: new port, compiles but has not yet been run on real hardware or
an emulator.** Treat it as a starting point for bring-up.

## Base Systems

- Tandy TRS-80 Model II with 96K or more RAM (64K main board plus a memory
  expansion board)
- Model 12, 16, 16B and Tandy 6000 used as a Z80 machine (the 68000 side
  is not used)

A plain 64K Model II is not enough: the kernel uses the fixed low 32K and
page 1, user processes need at least one more 32K page.

## Memory Map

| Address       | Contents                                                |
|---------------|---------------------------------------------------------|
| 0000-00FF     | Vectors (RST, IM1 interrupt, NMI), shared by everything  |
| 0100-7FFF     | Page 0: start up, common code, data, start of kernel code |
| 8000-FFFF     | Page 1: rest of the kernel, buffers, discard            |
| 8000-FDFF     | Pages 2-15: one 32K user process each                    |
| FE00-FFFF     | udata stash in each user page                            |
| F800-FFFF     | Video RAM, mapped while the kernel is mapped             |

Port 0xFF selects the page at 0x8000 (bits 0-3), video RAM (bit 7) and the
real time clock interrupt (bit 5). Processes that do not fit are swapped
to a hard disk partition of type 0x56.

## Supported Hardware

- 80x24 video with the 6845 hardware cursor, reverse video
- Keyboard (polled on the clock tick; HOLD acts as ^S/^Q, BREAK is ^C,
  F1/F2 and the arrow keys give the usual Fuzix key codes)
- Real time clock interrupt (30Hz, on NMI)
- Two serial ports on the Z80 SIO (tty2 = A, tty3 = B), 150-9600 baud,
  clocks from the CTC
- 8" floppy drives on the FD1791 using the Z80 DMA, double density
  26 x 256 byte sectors, single or double sided
- Tandy 8MB (WD1010 style) hard disk at 0xC0-0xCF, using the same driver
  and partition label as the Model 4 port
- Parallel printer on the FDC board PIO

## Not Supported / To Do

- Booting directly from hard disk (boot from floppy, root on hard disk or
  floppy)
- Floppy formatting, single density data tracks
- Hardware flow control and carrier detect on the serial ports
- Graphics boards
- Using the 68000 of the Model 16/6000

## Floppy Layout

Cylinder 0 side 0 is the single density boot track the boot ROM reads
(26 x 128 bytes into 0x0E00-0x1BFF, "BOOT" at 0x1000, "DIAG" at 0x1400).
`boot.s` copies `loader.s` to 0xF000 and the loader reads the kernel from
cylinders 67-76 into 0x0100-0xEFFF.

`/dev/fd0` starts at cylinder 1, so cylinders 1-66 (858 blocks on a single
sided disk) of the boot disk can hold a file system.

## Building

```
make TARGET=trs80m2 kernel
make TARGET=trs80m2 diskimage
```

`Images/trs80m2/boot.imd` is an ImageDisk file (for MAME, trs80gp or for
writing a real disk), `boot.raw` the same data as a plain sector dump.
`hard2-0` is a hard disk image with a Fuzix file system.

## Things To Check During Bring-Up

These come from documentation only and want verifying first:

- Z80 DMA programming in `trs80m2.s` (`fd_dma`) and `loader.s`
- That the keyboard really delivers the TRSDOS codes listed in `devtty.c`
- The RTC NMI handling: the NMI is turned into a normal timer interrupt
  only when interrupts were enabled when it arrived
- Hard disk host adapter enable bits (0xC1)
