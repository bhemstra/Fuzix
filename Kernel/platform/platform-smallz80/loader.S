;
;	Bootstrap loader for FUZIX from the ROM
;
;	The ROM thinks it is loading CP/M but is pretty flexible
;

	.abs
	.org 0xFA00
	; Sector 0

DATA	.equ 	0x00
ERROR	.equ	0x01
FEATURES .equ	0x01
COUNT	.equ	0x02
LBA_0	.equ	0x03
LBA_1	.equ	0x04
LBA_2	.equ	0x05
LBA_3	.equ	0x06
STATUS	.equ	0x07
CMD	.equ	0x07

ERR	.equ	0
DRQ	.equ	3
READY	.equ	6
BUSY	.equ	7

ATA_READ .equ	0x20

start:
	.word	0x2176		; Magic number
	.word	0xFA00		; Load address
	.byte	0xC9
	.byte	0xC3
	.word	0xFC00		; Run address

	; Sector 1 and 2
	.org	0xFC00

run:
	ld	sp, 0xFC00
	ld	a, 0x80		; ROM off lights off
	out	(0xF8), a

	; Save BIOS info so we can work out if we are on the old or new
	; port mapping.
	ld	hl,0x40
	ld	de,0xFFC0
	ld	bc,0x40
	ldir

	; Now print sign on (relies on copy above)
	ld	hl, signon
	call	print


	; Kernel will now get loaded linearly into memory
	; including bankable bank 0

	; This gets ugly as the disk controller location
	; depends entirely upon the board generation

	ld	a,(0x40)
	cp	0x10
	ld	a,0x38
	jr	z, old_board
	ld	a,0x68
old_board:
	ld	(ideport),a
	call	ide_ready
	ld	a,(ideport)
	add	a,LBA_3
	ld	c,a
	ld	a, 0xE0
	out	(c), a
	call	ide_ready
	xor	a
	dec	c		; LBA 2
	out	(c), a
	dec	c		; LBA1
	out	(c), a

	ld	de, 0x7C03	; sectors 3-127
	ld	hl, 0x0000	; load address

load_loop:
	call	ide_ready
	ld	a, (ideport)
	add	a, LBA_0
	ld	c, a
	ld	a, e
	out	(c), a		; LBA0
	dec	c
	ld 	a, 1
	out	(c), a		; COUNT
	ld	a,c
	or	7		; CMD/STATUS
	ld	c,a
	ld	a, ATA_READ
	out	(c), a
	call	ide_wait_drq
	ld	bc, (ideport)	; C = port B = 0
	inir
	inir
	ld	a, '.'
	call	putchar
	inc	e
	dec	d
	jr	nz, load_loop
	ld	hl, gogogo
	call	print
	jp	0x0100

ide_ready:
	push	bc
	ld	a, (ideport)
	add	a, STATUS
	ld	c,a
ide_readyw:
	in	a, (c)
	bit	BUSY, a
	jr	nz, ide_readyw
	bit	READY, a
	jr	z, ide_readyw
	pop	bc
	ret

ide_wait_drq:
	push	bc
	ld	a, (ideport)
	add	a, STATUS
	ld	c,a
ide_wdrq:
	in	a, (c)
	bit	DRQ, a
	jr	z, ide_wdrq
	pop	bc
	ret

print:
	ld	a, (hl)
	or	a
	ret	z
	call	putchar
	inc	hl
	jr	print

;
;	The ROM console byte is a 16x50 base (0x10, 0x40, 0x48 ...), or on the
;	Z180 board 0x00 = ASCI0, 0x01 = ASCI1, 0xFF = NULL port.
;
putchar:
	push	bc
	push	af
	ld	b,0		; Z180 internal I/O needs A15-A8 = 0
	ld	a,(0xFFC0)	; get console port
	cp	0xFF
	jr	z, putdone	; NULL console
	cp	2
	jr	c, putasci
	add	a,5		; 16x50 LSR
	ld	c,a
waitch:
	in	a, (c)
	bit	5, a		; THRE
	jr	z, waitch
	ld	a,c
	sub	5		; 16x50 THR
	ld	c,a
	jr	putout
putasci:
	add	a,4		; STAT0 (0x04) or STAT1 (0x05)
	ld	c,a
waitasci:
	in	a, (c)
	bit	1, a		; TDRE
	jr	z, waitasci
	inc	c
	inc	c		; TDR0 (0x06) or TDR1 (0x07)
putout:
	pop	af
	out	(c),a
	pop	bc
	ret
putdone:
	pop	af
	pop	bc
	ret

signon:
	.byte	13,10,13,10
	.ascii	'SmallZ80 FUZIX LOADER 0.2'
	.byte	13,10,0
gogogo:
	.byte	13,10
	.ascii 'Executing FUZIX...'
	.byte	13,10,0

ideport:
	.byte	0
	.byte	0
