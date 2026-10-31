;
;	TRS-80 Model II Fuzix loader
;
;	Runs at 0xF000 in page 1 (copied there by boot.s). Loads 239 double
;	density sectors from cylinder 67 onwards on drive 0 side 0 into
;	0x0100-0xEFFF and jumps to the kernel at 0x0100.
;
;	The FD1791 is driven by the Z80 DMA as polled I/O is too slow for
;	8" double density.
;
		.module loader
		.area LOADER (ABS)

		.org 0xF000

KCYL		.equ	67
VIDEO		.equ	0xF800

start:
		di
		ld sp, #0xF800
		xor a
		out (0xF9), a		; boot ROM off
		ld a, #0x81		; page 1, video RAM on, no clock NMI
		out (0xFF), a
		ld hl, #msg_load
		ld de, #VIDEO + 80 * 12 + 32
		call print

		ld a, #0xC3		; DMA reset
		out (0xF8), a
		ld a, #0xCE		; drive 0, side 0, MFM
		out (0xEF), a

		ld a, #0x0A		; restore, load head, 10ms steps
		call fdcmd

		ld a, #KCYL
		ld (cyl), a
		ld hl, #0x0100
nextcyl:
		ld a, (cyl)
		out (0xE7), a
		ld a, #0x1E		; seek, load head, verify, 10ms
		call fdcmd
		and #0x98		; not ready, seek error, CRC
		jr nz, error
		ld a, #1
		ld (sec), a
nextsec:
		ld a, #10
		ld (tries), a
retry:
		ld a, (sec)
		out (0xE6), a
		call dmaread
		and #0x9D		; not ready, RNF, CRC, lost, busy
		jr z, secok
		ld a, (tries)
		dec a
		ld (tries), a
		jr nz, retry
		jr error
secok:
		inc h			; next 256 bytes
		ld a, h
		cp #0xF0
		jr z, done
		ld a, (sec)
		inc a
		ld (sec), a
		cp #27
		jr nz, nextsec
		ld a, (cyl)
		inc a
		ld (cyl), a
		jr nextcyl

done:
		xor a			; no kernel command line, so the kernel
		ld (0xF7E0), a		; asks for the root device
		ld a, #0x01		; page 1, the kernel sets up the rest
		out (0xFF), a
		jp 0x0100

error:
		ld hl, #msg_err
		ld de, #VIDEO + 80 * 12 + 32
		call print
stop:
		jr stop

;
;	Issue a type 1 command and wait for it
;
fdcmd:
		out (0xE4), a
		ld b, #20
fdcmd_d:
		djnz fdcmd_d
fdcmd_w:
		in a, (0xE4)
		bit 0, a
		jr nz, fdcmd_w
		ret

;
;	Read the sector set up in the FDC into (HL) using the DMA. Returns
;	the FDC status in A, HL preserved.
;
dmaread:
		ld c, #0xF8
		ld a, #0xC3		; reset
		out (c), a
		ld a, #0x79		; B->A, address and length follow
		out (c), a
		out (c), l
		out (c), h
		xor a			; 256 bytes
		out (c), a
		inc a
		out (c), a
		ld a, #0x14		; port A memory, increment
		out (c), a
		ld a, #0x28		; port B I/O, fixed
		out (c), a
		ld a, #0xC5		; burst, port B low address follows
		out (c), a
		ld a, #0xE7
		out (c), a
		ld a, #0x8A		; RDY active high
		out (c), a
		ld a, #0xCF		; load
		out (c), a
		ld a, #0x87		; enable
		out (c), a
		ld a, #0x80		; read sector
		call fdcmd
		ld a, #0x83		; DMA off
		out (0xF8), a
		in a, (0xE4)
		ret

print:
		ld a, (hl)
		or a
		ret z
		ld (de), a
		inc hl
		inc de
		jr print

msg_load:
		.asciz "Loading Fuzix..."
msg_err:
		.asciz "Fuzix boot error"

cyl:		.db 0
sec:		.db 0
tries:		.db 0

		; Must fit in the space boot.s copies
		.ifgt (. - start - 2032)
		.error 1
		.endif
