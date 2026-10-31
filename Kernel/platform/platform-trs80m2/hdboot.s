;
;	TRS-80 Model II Fuzix hard disk loader
;
;	The boot ROM reads 512 byte sectors from cylinder 0 head 0 of hard
;	disk 0, starting at sector 1, into memory from 0x0000. After each
;	sector it checks whether the sector starts with "/* END BOOT */" and
;	if so jumps to the byte after it. The ROM covers 0x0000-0x0FFF while
;	it runs, so the signature has to be in sector 9 (loaded at 0x1000) or
;	later. This file is that sector: sectors 1-8 are filler.
;
;	Cylinder 0 is a 64K boot zone (partition 1, type 0xAA):
;	head 0 sectors 1-8	filler, the first one holds the partition label
;	head 0 sector 9		this loader
;	the rest		the kernel, 0x0100-0xEEFF, in order through
;				sectors 10-16 of head 0 and then heads 1-7
;
;	The file system follows from cylinder 1 (partition 2).
;
;	The loader copies itself to 0xF000 in page 1, turns the boot ROM off,
;	loads the kernel and leaves "hda2" as the kernel command line at
;	0xF7E0 so the kernel mounts the root file system without asking.
;
		.module hdboot
		.area HDBOOT (ABS)

		.org 0xF000

HD_SPT		.equ	16
KSECTORS	.equ	119		; 0x0100-0xEEFF
CMDLINE		.equ	0xF7E0

sig:
		.ascii "/* END BOOT */"
;
;	The ROM jumps here with this sector at 0x1000. Only use absolute
;	constants until we run from 0xF000.
;
		di
		ld a, #0x81		; page 1 at 0x8000, video on
		out (0xFF), a
		ld hl, #0x1000
		ld de, #0xF000
		ld bc, #512
		ldir
		jp go

go:
		ld sp, #0xF800
		xor a
		out (0xF9), a		; boot ROM off
		ld a, #0x0C		; controller enable, wait states on
		out (0xC1), a		; (the ROM turned it off)

		ld hl, #msg_load
		call print

		ld hl, #0x0100		; load address
		ld de, #(9 * 256) + 0	; D = sector within the track (0 based)
					; E = head
		ld b, #KSECTORS
nextsec:
		push bc
		ld a, d
		inc a			; sectors are numbered from 1
		out (0xCB), a
		ld a, e
		or #0x20		; 512 byte sectors, drive 0
		out (0xCE), a
		xor a
		out (0xCC), a		; cylinder 0
		out (0xCD), a
		inc a
		out (0xCA), a		; one sector
		ld c, #10		; retries
retry:
		call hdwait
		ld a, #0x20		; read sector
		out (0xCF), a
		call hdwait
		bit 0, a
		jr nz, failed
drq:
		in a, (0xCF)
		bit 3, a
		jr z, drq
		push bc
		ld bc, #0x00C8		; 512 bytes
		inir
		inir
		pop bc
		call hdwait
		bit 0, a
		jr z, secok
failed:
		dec c
		jr nz, retry
		jr error
secok:
		pop bc
		inc d			; next sector
		ld a, d
		cp #HD_SPT
		jr nz, samehead
		ld d, #0
		inc e			; next head
samehead:
		djnz nextsec

		; Tell the kernel where its root is
		ld hl, #root
		ld de, #CMDLINE
		ld bc, #root_end - root
		ldir

		ld a, #0x01		; page 1, the kernel sets up the rest
		out (0xFF), a
		jp 0x0100

error:
		ld hl, #msg_err
		call print
stop:
		jr stop

;
;	Wait for the controller to finish, return the status in A
;
hdwait:
		in a, (0xCF)
		rlca
		jr c, hdwait
		rrca
		ret

print:
		ld de, #0xF800 + 80 * 12 + 32
printl:
		ld a, (hl)
		or a
		ret z
		ld (de), a
		inc hl
		inc de
		jr printl

msg_load:
		.asciz "Loading Fuzix..."
msg_err:
		.asciz "Fuzix boot error"
root:
		.asciz "hda2"
root_end:

		; The whole loader has to fit in the one sector the ROM loads
		.ifgt (. - sig - 512)
		.error 1
		.endif

		.org 0xF1FF
		.db 0
