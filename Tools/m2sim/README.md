# m2sim: minimal TRS-80 Model II simulator

A small simulator used to bring up the Fuzix `trs80m2` port without real
hardware. It is a debugging aid, not an emulator to use the machine with.
For that use trs80gp or MAME.

It models what the Fuzix kernel touches:

- Z80 CPU (via the `z80` Python package)
- 32K fixed page 0, pages 1-15 at 0x8000 and video RAM at 0xF800 behind
  port 0xFF
- 80x24 video (printed as text when the run ends)
- keyboard (port 0xFC, ready bit in port 0xFF)
- real time clock NMI, cleared by reading port 0xFE
- FD1791 floppy controller with the Z80 DMA, reading ImageDisk files
- WD1010 hard disk, drive 0, 512 byte sectors, 16 per track, 8 heads
  (the `hard2-0.hdv` layout)
- serial port A output (kernel debug output)

Without `--kernel` or `--hd-boot` it starts the way the boot ROM does: it loads the 26
single density sectors of cylinder 0 into 0x0E00, checks the `BOOT` and
`DIAG` signatures and runs the boot track, so `boot.s` and `loader.s`
are exercised too.

The device behaviour follows the Model II Technical Reference Manual and
the MAME driver, so it cannot catch places where real hardware or other
emulators differ.

## Setup

```
python3 -m venv venv
venv/bin/pip install z80
```

## Usage

Boot from the double sided floppy and use the hard disk as root (or use
`--hd-boot --hd-secbase 1` without `--floppy` to boot from the hard disk):

```
venv/bin/python Tools/m2sim/m2sim.py \
	--floppy Images/trs80m2/bootds.imd \
	--hdv Images/trs80m2/hard2-0.hdv \
	--map Kernel/fuzix.map --mem 512 --seconds 400 \
	--keys 'bootdev=hda2' --keys 'new date:=' --keys 'new time:=' \
	--keys 'login:=root' --keys 'Welcome to FUZIX=ls /bin | wc -l'
```

Each `--keys 'text=input'` waits until `text` is on the screen, then types
`input` and Return. The steps run in order.

Other options:

- `--kernel Kernel/fuzix.bin`: load the kernel directly at 0x0100
  instead of going through the boot track
- `--hd-boot`: boot from the hard disk the way the boot ROM does (reads
  from sector 1, so use it with `--hd-secbase 1`)
- `--hd-secbase 1`: number the hard disk sectors from 1 instead of 0
- `--hd-write`: write hard disk changes back to the image
- `--mem N`: RAM in KiB, 96 to 512
- `--map Kernel/fuzix.map`: name addresses and stop when the kernel
  reaches `null_handler`, `nmi_handler`, `trap_illegal` or `panic`,
  printing the stack
- `--trace-disk`: log every sector transferred

At the end it prints the screen, the emulated time, the log and anything
sent to serial port A. The exit status is 1 if it stopped on a kernel trap.
