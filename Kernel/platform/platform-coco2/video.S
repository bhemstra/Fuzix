;
;	Although the COCO2 fits the video simple model the generated code
;	isn't terribly pretty.
;
#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

;
;	TODO: could hide the text video functions and init in discard ?
;
	; FIXME: what segment do we need here
	.code

	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_across
	.export _clear_lines
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _vtattr_notify

;
;	Video base for text
;
;	A = X B = Y
;
txtaddr:
	ldx	#VIDEO_BASE
	leax	a,x		; X value
	lslb
	lslb
	lslb			; x 8 so keep unsigned
	leax	b,x		; and add four times
	leax	b,x
	leax	b,x
	leax	b,x		; result in X
	rts
;
;	Compute the video base address
;	A = X, B = Y
;
;
;	plot_char(int8_t y, int8_t x, uint16_t c)
;
_plot_char:
	; B holds Y at this point
	lda	2,s
	bsr	txtaddr
	ldb	4,s
	tst	_lower
	beq	map_cases
	; We want to map
;	; 20-3F	to 60-7F		40-5F	^20	60-7F
	; 40-5F to 40-5F		60-7F	^20	40-5F
	; 60-7F to 00-1F		80-9F	^20	A0-BF
	addb	#$20
	bmi	low
	eorb	#$20
	bra	plotit
low:
	andb	#$1f
	bra	plotit
map_cases:
	; A to Z we just mask with 0x3F so we get inverse
	cmpb	#'A'
	bcs	notuc
	cmpb	#'Z'+1
	bcs	mask_only
	; a to z we mask with 1f and add 0x40 to get normal
notuc:	cmpb	#'a'
	bcs	notlc
	cmpb	#'z'+1
	bcs	fixlc
	; lower punctuation, numbers etc  we just mask
notlc:	cmpb	#$60
	bcs	maskinv
	; upper punctuation we mask and invert
	andb	#$1f
	bra	plotit
fixlc:
	andb	#$1f
maskinv:
	andb	#$3f
	addb	#$40
	bra	plotit
mask_only:
	andb	#$3F
plotit:
	stb	,x
	rts
;
;	void scroll_up(void)
;
_scroll_up:
	pshs	u
	ldu	#VIDEO_BASE
	ldx	#VIDEO_BASE+0x20
scrup_tl:
	ldd	,x++
	std	,u++
	cmpx	#VIDEO_BASE+512
	bne	scrup_tl
	puls	u,pc
;
;	void scroll_down(void)
;
_scroll_down:
	pshs u
	ldu	#VIDEO_BASE+0x200
	ldx	#VIDEO_BASE+0X1E0
scrdn_tl:
	ldd	,--x
	std	,--u
	cmpx	#VIDEO_BASE
	bne	scrdn_tl
	puls	u,pc
;
;	clear_across(int8_t y, int8_t x, uint16_t l)
;
_clear_across:
	lda	2,s		; Y,X into B,A
	jsr	txtaddr
	ldb	_spaces
clatl:
	stb	,x+
	dec	4,s
	bne	clatl
	rts
;
;	clear_lines(int8_t y, int8_t ct)
;
_clear_lines:
	lda	2,s
	beq	cldone
	clra
	jsr	txtaddr
	lsl	2,s
	lsl	2,s
	lsl	2,s
	lsl	2,s		; x 16 cos dword
	ldd	_spaces
clt:
	std	,x++
	dec	2,s		; 32 bytes per line max 16 lines in text
	bne	clt
cldone:
	rts

_cursor_on:
	lda	2,s
	jsr	txtaddr
	stx	cursor_save
coff_txt:
	lda	#0x40
	eora	,x
	sta	,x
	rts

_cursor_off:
	ldx	cursor_save
	bra	coff_txt
_vtattr_notify:
_cursor_disable:
	rts

	.data
cursor_save:
	.word	0
_spaces:
	.word	0x6060
