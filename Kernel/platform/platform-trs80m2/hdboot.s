;
;	TRS-80 Model II Fuzix hard disk loader
;
;	The boot ROM reads 512 byte sectors from cylinder 0 head 0 of hard
;	disk 0, starting at sector 1, into memory from 0x0000. After each
;	sector it checks whether the sector starts with "/* END BOOT */" and
;	if so jumps to the byte after it (the address is also in HL).
;
;	Drives may number their sectors from 0 (trs80gp does) or from 1, so
;	where this sector ends up depends on the drive: at 0x0E00 when the
;	sectors start at 0, at 0x1000 when they start at 1. The loader works
;	out where it is from HL and probes sector 0 to find the numbering.
;
;	Cylinder 0 is a 64K boot zone (partition 1, type 0xAA), counting
;	512 byte sectors from 0 through head 0 to head 7:
;	0-7		filler, the first one holds the partition label
;	8		this loader
;	9-127		the kernel, 0x0100-0xEEFF
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
;	The ROM jumps here with HL pointing here. Only use absolute
;	constants until we run from 0xF000.
;
		di
		ld a, #0x81		; page 1 at 0x8000, video on
		out (0xFF), a
		ld de, #-14		; back to the start of the sector
		add hl, de
		ld de, #0xF000
		ld bc, #512
		ldir
		jp go

go:
		ld sp, #0xF800
		; Low memory takes over from the ROM when we switch it off:
		; make a stray real time clock NMI harmless and clear any
		; pending tick
		ld hl, #0x45ED		; RETN at the NMI vector
		ld (0x0066), hl
		in a, (0xFE)
		xor a
		out (0xF9), a		; boot ROM off
		ld (0x0066), hl		; and in the RAM that now shows
		ld a, #'L'		; progress on the top line: L = running
		ld (0xF800), a
		ld a, #0x0C		; controller enable, wait states on
		out (0xC1), a		; (the ROM turned it off)

		ld hl, #msg_load
		call print
		ld ix, #0xF801		; progress pointer

		; Find out whether the sectors are numbered from 0 or 1: try
		; to read sector 0 of head 0
		ld a, #0x20		; 512 byte sectors, drive 0, head 0
		out (0xCE), a
		xor a
		out (0xCC), a
		out (0xCD), a
		out (0xCB), a
		inc a
		out (0xCA), a
		call hdwait
		ld a, #0x20		; read sector
		out (0xCF), a
		call hdwait
		and #1			; error: no sector 0, numbered from 1
		ld (secbase), a
		ld (ix), #'P'		; P = numbering probed
		inc ix
		jr nz, probed
		ld hl, #0xF200		; drain the data into scratch space
		ld bc, #0x00C8
		inir
		inir
		call hdwait
probed:
		ld hl, #0x0100		; load address
		ld de, #(9 * 256) + 0	; D = sector within the track (0 based)
					; E = head
		ld b, #KSECTORS
nextsec:
		push bc
		ld a, (secbase)
		add d
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
		ld (ix), #'.'		; one dot per kernel sector
		inc ix
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

		ld (ix), #'J'		; J = jumping to the kernel
		; Show the first bytes at 0x0100 and at the address the kernel
		; jumps to from there, so a screenshot tells us what is there
		ld ix, #0xF800 + 80 * 2
		ld hl, #0x0100
		call hex3
		ld hl, (0x0101)
		call hex3
		ld a, #0x01		; page 1, the kernel sets up the rest
		out (0xFF), a
		jp 0x0100

error:
		ld hl, #msg_err
		call print
stop:
		jr stop

;
;	Show the address in HL and the three bytes there at (IX)
;
hex3:
		ld a, h
		call hex2
		ld a, l
		call hex2
		ld (ix), #':'
		inc ix
		ld b, #3
hex3l:
		ld a, (hl)
		call hex2
		inc hl
		djnz hex3l
		ld (ix), #' '
		inc ix
		ret
hex2:
		push af
		rrca
		rrca
		rrca
		rrca
		call hex1
		pop af
hex1:
		and #0x0F
		add #'0'
		cp #'9' + 1
		jr c, hexd
		add #'A' - '9' - 1
hexd:
		ld (ix), a
		inc ix
		ret

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
secbase:
		.db 0

		; The whole loader has to fit in the one sector the ROM loads
		.ifgt (. - sig - 512)
		.error 1
		.endif

		.org 0xF1FF
		.db 0
