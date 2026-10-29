;
;	TRS-80 Model II boot track
;
;	The boot ROM reads the 26 single density sectors of cylinder 0 into
;	0x0E00-0x1BFF, checks for "BOOT" at 0x1000 and "DIAG" at 0x1400,
;	calls 0x1404 and then jumps to 0x1004.
;
;	The kernel loads over all of this, so we just copy the real loader
;	(placed at 0x1410 in this track by the build) up to 0xF000 in page 1
;	and run it there.
;
		.module boot
		.area BOOT (ABS)

		.org 0x1000
		.ascii "BOOT"
		jp boot

boot:
		di
		ld a, #0x01		; page 1 at 0x8000, video off
		out (0xFF), a
		ld hl, #0x1410
		ld de, #0xF000
		ld bc, #2032
		ldir
		jp 0xF000

		.org 0x1400
		.ascii "DIAG"
		ret			; no diagnostics

		.org 0x1BFF
		.db 0
