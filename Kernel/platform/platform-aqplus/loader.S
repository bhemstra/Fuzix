#define ESPCTRL	0xF4
#define ESPDATA	0xF5

#define ESPCMD_VERSION		0x02
#define ESPCMD_GETDATETIME	0x03
#define EPSCMD_GETMOUSE		0x0C
#define ESPCMD_OPEN		0x10
#define ESPCMD_CLOSE		0x11
#define ESPCMD_READ		0x12
#define ESPCMD_WRITE		0x13
#define ESPCMD_SEEK		0x14
#define ESPCMD_CLOSEALL		0x1F

	.abs

	.org	0xE000

	.byte  70, 85, 90, 73
	.byte  88, 156, 48, 176
	.byte  214, 108, 170, 100
	.byte  48, 168, 221, 112

start:
	ld	hl, 0x3000
	ld	de, 0x3001
	ld	bc, 0x03FF
	ld	(hl), ' '
	ldir
	ld	bc, 0x03FF
	ld	(hl), 0x70
	ldir

	ld	a, 4
	out	(0xFB),a

	ld	hl, 0x3028
	ld	de, str
loop:	ld	a,(de)
	or	a
	jr	z, done
	ld	(hl),a
	inc	hl
	inc	de
	jr	loop
done:
	ld	ix, 0x30A0
;
;	Set up AQPlus stuff
;
	ld	(ix + 0), 0x7F
	inc	ix

	ld	a,ESPCMD_OPEN
	call	espcmd
	ld	hl, kernel
	xor	a
	call	esptx		; open for read only
esppath:
	ld	a,(hl)
	inc	hl
	call	esptx
	or	a
	jr	nz, esppath
	call	esprx
	ld	e,a		; handle
	bit	7,a
	jr	nz, open_error

	ld	a, 0x20
	call	fill16k

	ld	a, 0x21
	call	fill16k

	ld	a, 0x22
	call	fill16k

	ld	a, 0x23
	call	fill16k

	ld	a, ESPCMD_CLOSEALL
	call	esptx
	call	esprx

	;	Now map things

	ld	a,0x20
	out	(0xF0),a
	inc	a
	out	(0xF1),a
	inc	a
	out	(0xF2),a

	;	Can't swap the upper 16K as we are in it - crt0.S will do
	;	the necessary

	jp	0x0100

	.export	fill16k

fill16k:
	out	(0xF1), a	; Map at 4000-7000
	ld	a, ESPCMD_READ
	call	espcmd
	ld	a,e
	call	esptx		; Handle
	xor	a
	call	esptx
	ld	a,64
	call	esptx		; 16K
	call	esprx		; get result code
	bit	7,a
	jr	nz, read_error
	call	esprx		; get result length
	or	a
	jr	nz, read_error2
	call	esprx
	cp	64
	jr	nz, read_error3

	ld	hl, 0x4000
	ld	bc, 0x0040
nextb:
	call	esprx
	ld	(hl),a
	inc	hl
	djnz	nextb
	ld	(ix+0), 0x7F
	inc	ix
	dec	c
	jr	nz, nextb
	ret	

espcmd:
	push	af
	ld	a, 0x83
	out	(ESPCTRL), a
	pop	af
esptx:
	push	af
esptxw:
	in	a,(ESPCTRL)
	and	2
	jr	nz, esptxw
	pop	af
	out	(ESPDATA), a
	ret
esprx:
	in	a,(ESPCTRL)
	rra	
	jr	nc, esprx
	in	a, (ESPDATA)
	ret

open_error:
	ld	hl, eopen
	jr	error
read_error:
read_error2:
read_error3:
	ld	hl, eread
error:	ld	de, 0x3050
errl:	ld	a,(hl)
	or	a
	jr	z, errend
	ld	(de),a
	inc	hl
	inc	de
	jr	errl
errend:
	di
	halt

kernel:
	.ascii	"FUZIX.BIN"
	.byte	0
eread:
	.ascii	"READ ERROR"
	.byte	0
eopen:
	.ascii	"FILE NOT FOUND"
	.byte	0

str:
	.ascii	"FUZIX Cartridge Loader"
	.byte	0

