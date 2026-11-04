# lsdos2: LS-DOS 6.3.1 on a Model II hard disk

Builds `Images/trs80m2/lsdos2-0.hdv`, a TRS-80 Model II hard disk image
that boots LS-DOS 6.3.1 (level N) straight from the hard disk boot ROM,
with drive :0 the hard disk and the floppies as :1 and :2.

LS-DOS for the Model II only boots from floppy and has no hard disk
driver. This adds one, a loader for the boot ROM and a disk layout, to
Michel Bernard's (GmEsoft) Model II sources,
https://github.com/GmEsoft/TRS80_M2_LSDOS631N, assembled with George
Phillips' zmac, https://github.com/gp48k/zmac.

**Status: works in the browser emulator (`Tools/m2web`, `test.mjs`);
not yet tried in trs80gp or on real hardware.**

| File          | Contents                                                |
|---------------|---------------------------------------------------------|
| `build.py`    | fetches the sources and zmac into `work/`, changes and assembles them, builds the image |
| `hddvr2.asm`  | the WD1010 hard disk driver, part of lowcore (BOOT/SYS) |
| `hdboot2.asm` | the loader the hard disk boot ROM starts                |
| `mklib.py`    | builds SYS6/SYS7/SYS8 from the library commands, as BLDLIBS/CMD does |
| `mklsdos.py`  | writes the image: boot area, GAT, HIT, directory and files |
| `test.mjs`    | boots the image under Node and tries the disk           |

## Use

```
python3 Tools/lsdos2/build.py      # needs git, make, a C compiler
node Tools/lsdos2/test.mjs
```

The first run clones both repositories into `Tools/lsdos2/work` (tested
with GmEsoft b1e7f71 and zmac 050bbb1); `--lsdos DIR` and `--zmac FILE`
use existing ones. The image has the same geometry and header as the
Fuzix `hard2-0.hdv`, so it goes wherever that one goes. In the browser:

```
Tools/m2web/mkdisk.sh Images/trs80m2/lsdos2-0.hdv lsdos2-0
```

`Tools/m2web/disks.json` already lists it as "LS-DOS 6.3.1".

LS-DOS asks for the date and time at every boot (the Model II has no
clock that keeps time).

## On the disk

SYS0-SYS13 (SYS6-8 with all library commands: DIR, COPY, FREE, LIST,
DEVICE, ...), BACKUP, FORMAT, DISKCOPY, PATCH, REPAIR, LOG, COMM, DATECONV
and HELP, the MEMDISK/DCT and COM/DVR drivers, the CLICK, FORMS and KSM
filters, and NOTICE/TXT with the LS-DOS copyright and permission notice,
which has to go along with copies. No HELP files and no BASIC (LS-DOS
does not come with one for the Model II).

## Disk layout

The drive: 101 cylinders, 8 heads, 32 sectors of 512 bytes per track
(13 MB). LS-DOS works with 256 byte sectors, so each LS-DOS sector is the
first half of a 512 byte one and the second half is unused (written as
zeros). That keeps the driver small, without a sector buffer, at the cost
of half the space: LS-DOS sees 6464K.

LS-DOS sees 202 cylinders of 4 heads: physical cylinder n is LS-DOS
cylinder 2n (heads 0-3) and 2n+1 (heads 4-7). 128 sectors per cylinder,
8 granules of 16 sectors (4K).

| LS-DOS cylinder | Contents                                          |
|-----------------|---------------------------------------------------|
| 0               | boot area, BOOT/SYS                               |
| 1               | directory: GAT, HIT, 32 directory sectors (256 files) |
| 2-201           | files                                             |

The boot area, as 512 byte sectors of cylinder 0 head 0, counted from 0:

| Sector | Contents                                                      |
|--------|---------------------------------------------------------------|
| 0-7    | filler (sector 1 byte 2 is the directory cylinder, where LS-DOS looks when it loses track of it) |
| 8      | `hdboot2.asm`, starting with `/* END BOOT */`                 |
| 9-26   | memory 0000H-23FFH: lowcore (BOOT/SYS) with SYS0 loaded on top |
| 27-30  | video memory F800H-FFFFH (the sign-on logo SYS0 brings)       |

As for Fuzix (see `Kernel/platform/platform-trs80m2/README.md`) the boot
ROM reads sectors from 1 into memory from 0000H until one starts with
`/* END BOOT */`. The loader moves to 7E00H, turns the ROM off, works out
whether the drive numbers its sectors from 0 (trs80gp) or 1, loads
memory, tells the driver the numbering and jumps to SYSINIT at 1E00H.
`test.mjs` passes with both numberings.

## Changes to the LS-DOS sources

`build.py` lists them (`EDITS`). In short:

- `lowcore.asm`: DCT 0 is the hard disk driver (cylinders 0-201, fixed,
  directory on cylinder 1), physical floppies 0 and 1 are :1 and :2,
  `hddvr2.asm` goes after the floppy driver, in the space for drivers
  below 1200H.
- `sysinit4.asm`: SYSINIT no longer sets up DCT 0 from what the floppy
  boot sector left.
- `buildver.asm`: the `@HD` and `HDDIR` switches.
- For zmac: `COM` records and the `NUL` symbol left out, a `:` typo in
  `sys3.asm`, the `LIST` label in `lblist.asm` renamed, `LORG` written as
  `PHASE`/`DEPHASE` in FORMAT and BACKUP, a negative `DC` value and
  `(IX+0FFH)` spelled differently.

MRAS makes the `.EQU` files (symbols of lowcore, SYS0 and SYS5 for the
other modules) with XREF; `build.py` makes them from zmac's symbol tables
and drops the symbols a module defines itself.

## The driver

`hddvr2.asm` handles read (9), verify (10), write (13) and write system
sector (14) and does nothing for the rest; reads from the directory
cylinder return error 6, as LS-DOS expects of a protected directory.
FORMAT cannot format the hard disk (it is for floppies); the disk comes
formatted from `mklsdos.py`.

## Not done / to check

- trs80gp and real hardware (a Model II, 12, 16 or 6000 with a hard disk
  boot ROM, or FreHD): only the browser emulator has run it so far.
- `Tools/m2web/m2.js` had to learn the keyboard interrupt (CTC channel 3,
  IM 2) that LS-DOS uses; Fuzix polls the keyboard.
- The floppy drives are untested: the emulator has no floppy controller.
- CONFIG/SYS (SYSGEN) and the utilities beyond starting BACKUP are
  untested.
