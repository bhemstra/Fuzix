;
;	We are loaded at 0xA000 and we are 256 bytes long. The CPLD ROM
;	is still decorating all the low address space
;
;	We also want to squash the partition table into the end of this
;	block!
;
	.abs
	.org 0xFF00

start:	; entered as 0xA000
	ld	hl,0xA000
	ld	de,0xFF00
	ld	bc,0x0100
	ldir
	jp	go
go:	; now in the right addressing, remove CPLD ROM
	ld	a,0x80
	out	(0x1F),a
	; time to get loading
	ld	sp,0xFF00
	call	waitrdy
	ld	a,0xE0
	out	(0x16),a
	call	waitrdy
	; 8bit mode
	ld	a,0x01
	out	(0x11),a	; feature 8bit
	ld	a,0xEF
	out	(0x17),a	; set 8bit mode
	ld	hl,0		; load address
	ld	e,1		; Skip the boot block
loop:	
	call	waitrdy
	ld	a,e
	out	(0x13),a	; LBA low
	xor	a
	out	(0x14),a	; LBA med
	out	(0x15),a	; LBA high
	inc	a
	out	(0x12),a	; 1 sector
	ld	a,0x20
	out	(0x17),a	; READ
	nop
wdrq:
	in	a,(0x17)
	and	0x08
	jr	z,wdrq

	ld	bc,0x0010
	inir
	inir
	inc	e
	ld	a, 0xFE		; Load 0000-FDFF
	cp	h
	jr	nz, loop
	jp	0x0100
waitrdy:
	in	a,(0x17)
	add	a,a
	jr	c, waitrdy
	ret
