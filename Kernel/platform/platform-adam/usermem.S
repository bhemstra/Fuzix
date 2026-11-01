;
;	The lack of a common single stack makes life a bit interesting
;
#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

        ; exported symbols
        .export __uget
        .export __ugetc
        .export __ugetw

        .export __uput
        .export __uputc
        .export __uputw
        .export __uzero

	.common

uputget:
	ld	ix,10
	add	ix, sp
        ; load DE with the byte count
        ld	c, (ix + 4) ; byte count
        ld	b, (ix + 5)
	ld	a, b
	or	c
	ret	z		; no work
        ; load HL with the source address
        ld	l, (ix + 0) ; src address
        ld	h, (ix + 1)
        ; load DE with destination address
        ld	e, (ix + 2)
        ld	d, (ix + 3)
	ret

__uget:
	push	bc
	push	ix
	call	uputget
	jr	z, uget_out
	bit	7, d		; User below 0x8000 so may need to switch
	jr	z, gcopy_slow
do_ldir:
	ldir
uget_out:
	pop	ix
	pop	bc
	ld	hl,0
	ret
gcopy_slow:
	;	Copy BC bytes from HL to DE switching banks as we go
	ld	a,(_udata + U_DATA__U_PAGE)
	exx
	ld	d,a
	ld	bc, 0x0D7F
	jr	pcgo

__uput:
	push	bc
	push	ix
	call	uputget
	jr	z, uget_out
	bit	7, h		; User below 0x8000 same issue
	jr	z, pcopy_slow
	jr	do_ldir
pcopy_slow:
	;	Copy BC bytes from HL to DE switching banks as we go
	ld	a,(_udata + U_DATA__U_PAGE)
	exx
	ld	b,a
	ld	d,0x0D
	ld	c,0x7F
pcgo:
	exx

	; Optimize with djnz and split loop TODO
pcloop:
	ld	a, (hl)
	exx
	out	(c), b
	exx
	ld	(de), a
	inc	hl
	inc	de
	exx
	out	(c),d
	exx
	dec	bc
	ld	a,b
	or	c
	jr	nz, pcloop
	jr	uget_out
	
__uzero:
	ld	hl,7
	add	hl,sp
	push	bc
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	ld	a,b
	or	c
	jr	z,uzout
	ld	a, (_udata + U_DATA__U_PAGE)
	out	(0x7F),a
	ld	(hl),0
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	z, uzout
	ldir
uzout:
	ld	a,0x0D
	out	(0x7F),a
	pop	bc
	ret

__ugetc:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a, _udata + U_DATA__U_PAGE
	out	(0x7F),a
	ld	l,(hl)
	ld	a,0x0D
	out	(0x7F),a
	ld	h, 0
	ret

__ugetw:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a, _udata + U_DATA__U_PAGE
	out	(0x7F),a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,0x0D
	out	(0x7F),a
	ret
	
__uputc:
	ld	hl, 4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a, _udata + U_DATA__U_PAGE
	out	(0x7F),a
	ld	(hl),e
	ld	a,0x0D
	out	(0x7F),a
	ld	hl,0
	ret

__uputw:
	ld	hl, 4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a, _udata + U_DATA__U_PAGE
	out	(0x7F),a
	ld	(hl),e
	inc	hl
	ld	d,(hl)
	ld	a,0x0D
	out	(0x7F),a
	ld	hl,0
	ret
