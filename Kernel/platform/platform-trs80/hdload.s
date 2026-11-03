;
;	TRS-80 Model 4 / 4P hard disk boot sector
;
;	The Model 4P boot ROM, and the FreHD auto boot ROM on a Model 4,
;	read the second sector of the hard disk (cylinder 0, head 0, sector
;	1) into 0x4300 and jump to it. This sector:
;
;	- moves itself to 0x0000
;	- loads the kernel from the rest of cylinder 0 (sectors 2 onwards,
;	  head by head) into 0x0100-0xEDFF
;	- leaves "hda2" in the kernel's command line slot at 0x0102 so the
;	  kernel mounts the root file system without asking
;	- jumps to the kernel at 0x0100
;
;	Bytes 0x80-0xBF of this sector hold the partition label (written by
;	trslabel), so the code is in two parts around it. The same sector
;	also boots from a floppy (hdboot.jv3), as the floppy boot ROM loads
;	the first floppy sector to 0x4300 too.
;
;	There are no CALLs: on a 4P a call in page 0 can bring the boot ROM
;	back in.
;
;	Disk layout (256 byte sectors, 32 per track, 8 heads):
;	cylinder 0	sector 0: unused, sector 1: this, then the kernel
;	cylinder 1-	hda2: the root file system, then hda3: swap
;

		.z80

SDH		.equ	0x80		; CRC, 256 byte sectors, drive 0
SPT		.equ	32		; sectors per track
CMDLINE		.equ	0x0102		; see crt0.s
VIDEO		.equ	0xF800

		.area BOOT (ABS)
		.org 0x0000

start:
		di			; needed on a Model 4 with FreHD
		ld a, #0x18
		out (0xC1), a		; reset the hard disk controller
		ld a, #0x86		; 80x24, memory map 2 (all RAM low)
		out (0x84), a
		ld a, #0x50		; fast, external I/O on
		out (0xEC), a
		ld hl, #0x4300
		ld de, #0x0000
		ld bc, #256
		ldir
		jp part2

;	Read the kernel: D = SDH and head, E = sector, HL = where
load:
		ld hl, #0x0100
		ld de, #(SDH << 8) + 2
		xor a
		out (0xCC), a		; cylinder 0
		out (0xCD), a
next:
		ld a, h
		cp #0xEE		; 0x0100-0xEDFF loaded ?
		jp z, done
		ld a, d
		out (0xCE), a
		ld a, e
		out (0xCB), a
		ld a, #1
		out (0xCA), a
		ld a, #0x20		; read sector
		out (0xCF), a
wait:
		in a, (0xCF)
		rlca			; busy ?
		jr c, wait
		in a, (0xCF)
		and #0x09		; DRQ and ERR
		cp #0x08
		jp nz, fail
		ld bc, #0x00C8		; 256 bytes from the data port
		inir
		inc e
		ld a, e
		cp #SPT
		jr nz, next
		ld e, #0
		inc d			; next head
		jr next

		.org 0x0080
;	The partition label goes here (64 bytes, see trslabel)
		.ds 64

		.org 0x00C0
done:
		ld hl, #root
		ld de, #CMDLINE
		ld bc, #5
		ldir
		jp 0x0100

fail:
		ld a, #'E'
		ld (VIDEO + 79), a
stop:
		jr stop

part2:
		ld sp, #0xEE00
		ld a, #'F'		; sign of life, top left (the kernel
		ld (VIDEO), a		; sets up the 6845 and the screen)
		ld a, #0x0C
		out (0xC1), a		; enable the controller, wait states
hdready:
		in a, (0xCF)
		and #0xC0		; not busy and ready
		cp #0x40
		jr nz, hdready
		jp load

root:
		.asciz "hda2"
