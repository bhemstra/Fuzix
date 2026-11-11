# TRS80 Model 4/4D/4P

## Base Systems

- Tandy TRS80 Model 4 (including 4D and gate array models) 128K
- Tandy TRS80 Model 4P 128K

## Supported Hardware

- Floppy Disk
- Hard Disk (Tandy or compatible including things like FreHD)
- Alpha Technology Style Joystick
- Tandy Hi-res card (graphics use only)
- Huffman style memory banking on port 0x94

## To Do

- Microlabs Grafyx reporting for graphics use only
- Alpha technology supermem
- Anitek MegaMem as a ramdisk/swap
- Anitek Hypermem
- FreHD specific features other than the clock
- Split base 128K kernel from a thunked kernel for the memory bank cards

## Unsupported

- XLR8R/4ccelerator - really deserves its own Z180 mode port
- M3SE except as far as compatibility goes

## Booting From Hard Disk (FreHD)

`hard4p-0.hdv` boots by itself on a Model 4P (its boot ROM can start a
hard disk) and on a Model 4 with the FreHD auto boot ROM:

| Where            | Contents                                            |
|------------------|-----------------------------------------------------|
| cylinder 0, sector 1 | boot sector (`hdload.s`), partition label at bytes 128-191 |
| cylinder 0, sector 2 onwards | the kernel                              |
| cylinders 1-169  | hda2: root file system                              |
| cylinders 170-201 | hda3: swap                                         |

The ROM (or the FreHD menu) loads sector 1 to 0x4300. The boot sector
loads the kernel from the rest of cylinder 0 and leaves `hda2` in the
kernel's command line slot at 0x0102, so the system comes up without
asking for the root device. Header byte 8 = 0x01 and byte 11 = 0x02 tell
FreHD the image boots natively, so it does not try to patch a DOS.

Copy `hard4p-0.hdv` to the FreHD SD card as hard disk 0. For a Model 4
with the FreHD auto boot ROM, `frehd.rom` must be on the card as well.
A machine that cannot boot from hard disk can use `hdboot.jv3`: a floppy
with the same boot sector, which loads the kernel from the hard disk.
`boot.jv3` loads the kernel from floppy and asks for the root device
(answer `hda2`).

`Tools/m2web/m4boot.mjs` runs the boot sector against the image the way
the ROM does and checks the kernel arrives intact.

## Clock

`/dev/rtc` (read by `setdate` from `/etc/rc` at boot) takes the time from
the clock chip on ports 0xB0-0xBC when there is one, and else from the
FreHD clock, so a Model 4 with a FreHD comes up with the right date
without asking. `setdate -w` sets the FreHD clock from the system time
(`setdate -u` first to type it in). The clock chip cannot be set.

The FreHD is asked through its own ports: a command to 0xC4 (1 GET_TIME,
2 SET_TIME), wait until the status at 0xCF is no longer busy, then six
binary bytes through 0xC2: seconds, minutes, hours, year from 2000, day,
month. It is never read from an interrupt, as it shares the controller
with the hard disk; without a clock chip the seconds come from the 30 Hz
timer.

## Floppy Disks

`/dev/fd0` to `/dev/fd3` are drives 0-3. The default mode is the TRS-80
double density layout: 40 tracks, one side, 18 sectors of 256 bytes
numbered from 0, as LS-DOS and TRSDOS 6 format them. Fuzix cannot format
a floppy, so format it with LS-DOS (`FORMAT :1 (DDEN,SIDES=1,CYL=40)`)
and make a file system on it:

    mkfs /dev/fd0 32 360
    mount /dev/fd0 /mnt

Other modes (`FDIO_SETMODE`): 1 double sided TRS-80, 2 single density
TRS-80 (10 sectors), 3 PC 360K, 4 PC 180K (the PC ones number from 1).

## Installation

`make TARGET=trs80 diskimage` puts `hard4p-0.hdv`, `boot.jv3` and
`hdboot.jv3` in `Images/trs80`.
