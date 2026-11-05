;
; low-level routines for VC handling
;

	.export _set_vid_mode
	.export _set_vc_mode
	.export _vc_clear
	.export _vc_write_char
	.export _vc_read_char
	.export _vc_memset
	.export _vc_scroll_up
	.export _vc_scroll_down

#include "kernel.def"

	.code

_set_vc_mode:
	ldx #$ffc6
	sta -4,x	; reset V1 0xffc2 ; set resolution
	sta -2,x	; reset V2 0xffc4

	; video base 0x0400 = 0x200 * 0b0010
	sta   b,x	; set/reset bit F0 for b = 0 or 1
	sta 2+1,x	; set F1
	sta 4+0,x 	; reset F2

	lda $ff22
	anda #$07
	sta $ff22	; set PIA for VDG
	rts

_set_vid_mode:
	; video base 0x0800 = 0x200 * 0b0100
	sta	$ffc6+0 	; reset F0
	sta	$ffc8+0 	; reset F1
	sta	$ffca+1 	; set F2
	jmp	_vid256x192	; set resolution

_vc_clear:
	tfr b,a
	asla
	clrb
	ldx #VC_BASE+512
	leax d,x
	pshs x
	leax -512,x
	jsr _map_video
	ldd #$2020
cllp:	std ,x++
	cmpx ,s
	blo cllp
	leas 2,s
	jmp _unmap_video

_vc_write_char:
	tfr	d,x
	ldb	2,s
	jsr	_map_video
	stb	,x
	jmp	_unmap_video

_vc_read_char:
	tfr	d,x
	jsr	_map_video
	ldb	,x
	jmp	_unmap_video

vtbase:
	lda	_curtty
	deca
	deca
	asla
	clrb
	ldx	#VC_BASE
	leax	d,x
	leay	512,x
	rts

_vc_scroll_up:
	pshs	x	; x: make space for end address
	jsr	vtbase
	sty	,s
	leay	32,x
	jsr	_map_video
scup:	ldd	,y++
	std	,x++
	cmpx	,s
	blo	scup
	jsr	_unmap_video
	puls	x,pc

_vc_scroll_down:
	pshs	x
	jsr	vtbase
	stx	,s
	leax	-32,y
	jsr	_map_video
scdn:	ldd	,--x
	std	,--y
	cmpx	,s
	bhi	scdn
	jsr	_unmap_video
	puls	x,pc

_vc_memset:
	tfr	d,x
	ldb	2,s
	ldy	3,s
	jsr	_map_video
vcms:	stb	,x+
	leay	-1,y
	bne	vcms
	jsr	_unmap_video
	rts

