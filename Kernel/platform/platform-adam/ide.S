#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.common
	.export _devide_read_data
	.export _devide_write_data

idesetup:
	ld	bc,0x0058	; 256 count port 0x58
	ld	a,(_td_raw)
	or	a
	ld	a,0x0D	; Kernel I/O (no separate buffer bank for now)
	ret	z
	dec	a
	ld	a,_udata + U_DATA__U_PAGE	; Current user map register
	ret	z
	ld	a,(_td_page)
	ret

;
;	User memory accesses switch our stack copy. We have stack space in
;	both but need to be careful to enter/leave on the right bank
;
_devide_read_data:
	push	bc
	call	idesetup
	out	(0x7F),a
rdloop:
	;	16bit wide transfers on port 0x58/9
	ini
	in	a,(0x59)
	ld	(hl),a
	inc	hl
	djnz	rdloop
ideout:
	ld	a,0x0D
	out	(0x7F),a
	pop	bc
	ret
	
_devide_write_data:
	push	bc
	call	idesetup
	out	(0x7F),a
	inc	c
wrloop:
	;	16bit wide transfers on port 0x58/9
	outi
	ld	a,(hl)
	out	(0x58),a
	inc	hl
	djnz	wrloop
	jr	ideout
