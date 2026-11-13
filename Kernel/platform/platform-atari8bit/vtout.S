;
;	We are called from C as vtputchar(char c)
;
;	TODO: proper locking versus interrupt usage
;

	.zp
	.export esc1
	.export escaped
	.export vtputc

cursorhide:
	.byte	0
curpos:
	.word	0
cursormod:
	.byte	0
vidptr:
	.word	0
vtstate:
	.word	0
cursorx:
	.byte	0
cursory:
	.byte	0
vidinv:
	.byte	0

	.data
	.export	_vtattr
newy:
	.byte	0
_vtattr:
	.byte	0
_vtink:
	.byte	0
_vtpaper:
	.byte	0

	.overlay4

#define VTA_INVERSE	0x01
#define VTA_ALTCHAR	0x40

	.export	_vtinit

_vtinit:
	lda	#0
	sta	cursorx
	sta	cursory
	sta	_vtattr
	sta	_vtink
	sta	@cursorhide
	jsr	do_vtinit
	php		; docursor expects stack flags
	jmp	docursor

	.export	_vtputchar

_vtputchar:
	php
	sei
	; Deal with NMI weirdnesses on Atari
	lda	#0
	sta	0xD40E		; NMIen off
	;	Disable the current live cursor
	lda	@cursorhide
	bne	cursor_off
	ldy	#0
	lda	(@curpos),y
	eor	#0x80
	sta	(@curpos),y
cursor_off:
	lda	(@sp),y
	jsr	__incsp
	jsr	dovt
docursor:
	;	Put back a cursor ?
	lda	@cursorhide
	bne	no_writec
	;	Check if the cursor was moved
	lda	@cursormod
	beq	cnext
	;	Recalculate position
	jsr	plot_calc
	;	Cursor position is computed
cnext:
	lda	@vidptr
	sta	@curpos
	lda	@vidptr+1
	sta	@curpos+1
	ldy	#0
	lda	#0x80
	eor	(@curpos),y
	sta	(@curpos),y
no_writec:
	pla
	pha
	and	#4
	bne	noirqrest
	; NMI back on
	lda	#0x40
	sta	0xD40E
noirqrest:
	; Restore interrupt mask
	plp
	rts

dovt:
	jmp	(@vtstate)
	;
	;	Normal state - glyphs and control codes
	;
vtputc:
	cmp	#32
	bcc	control
	;
	;	Glypyh
	;
plotchar:
	; 128-255 are wrapped back to 0-127
	and	#127		; patch to OR 128 maybe ? if in common
	ora	@vidinv		; invert if needed
	
	; Writing a glyph to the screen
	pha
	; Have we moved the cursor or is the screen pointer valid
	lda	@cursormod
	beq	pnext
	jsr	plot_calc
	lda	#0
	sta	@cursormod
pnext:
	pla
	; Draw the glyph
	ldy	#0
	sta	(@vidptr),y
	; Move the working position right one
	inc	@vidptr
	bne	vidnc
	inc	@vidptr+1
vidnc:
	; Adjust the cursor tracking
	inc	@cursorx
	lda	@cursorx
	cmp	#40
	beq	wrap
done:
	rts
	; Cursor has wrapped to new line, adjust and remember we need
	; to recalculate
wrap:	lda	#0
	sta	@cursorx
	lda	#1
	sta	@cursormod
	inc	@cursory
	; Check if we caused scrolling
	lda	@cursory
	cmp	#24
	bne	done
	; Finish with the scroll
	dec	@cursory
	jmp	scroll_up
	
	;
	;	Control codes. Implement the same as vt.c
	;
control:
	cmp	#0x1B
	beq	escaped
	cmp	#7
	beq	beep
	cmp	#8
	beq	cursorl
	cmp	#9
	beq	tab
	cmp	#10
	beq	newl
	cmp	#13
	bne	noop
	lda	#0
	sta	@cursorx
	inc	@cursormod
beep:
noop:
	rts
	;	Backspace (TODO - check if we should backspace up a line)
cursorl:
	lda	@cursorx
	beq	noop
	dec	@cursorx
	inc	@cursormod
	rts
	;	Newline - move down, maybe scroll
newl:	inc	@cursory
	inc	@cursormod
	lda	@cursory
	cmp	#24
	bne	noop
	; We overran
	dec	@cursory
	jmp	scroll_up
	;	Ctrl I aka tab we recursively implement by printing spaces
tab:
	lda	#' '
	jsr	plotchar
	lda	@cursorx
	and	7
	bne	tab
	rts
	;	Next token will be handled by esc1
escaped:
	lda	#<esc1
	sta	@vtstate
	ldx	#>esc1
	stx	@vtstate+1
	rts

;
;	Attribute controls
;
inverse:
	lda	_vtattr
	ora	#VTA_INVERSE
	bne	doalt
normal:
	lda	_vtattr
	and	#~VTA_INVERSE
	jmp	doalt
naltchar:
	lda	_vtattr
	and	#~VTA_ALTCHAR
	jmp	doalt
altchar:
	lda	_vtattr
	ora	#VTA_ALTCHAR
doalt:
	sta	_vtattr
doaltn:
	jsr	_vtattr_notify
	jmp	stdmode
	;
	;	Cursor movement
	;
curmove:
	cmp	#'A'
	beq	up
	cmp	#'B'
	beq	down
	cmp	#'C'
	beq	left
	cmp	#'D'
	beq	right
	cmp	#'E'
	jne	stdmode
do_vtinit:
	; Clear whole screen
	lda	#0
	tax
	jsr	doclrtoend
std1:	jmp	stdmode
up:
	lda	@cursory
	beq	std1
	dec	@cursory
	jmp	stdmode_mv
down:
	lda	@cursory
	cmp	#23
	beq	std1
	inc	@cursory
	jne	stdmode_mv
left:
	lda	@cursorx
	beq	std1
	dec	@cursorx
	jmp	stdmode_mv
right:
	lda	@cursorx
	cmp	#39
	beq	std1
	inc	@cursorx
	jmp	stdmode_mv
esc1:
	cmp	#'F'
	bcc	curmove
	beq	altchar
	cmp	#'G'
	beq	naltchar
	cmp	#'H'
	jeq	home
	cmp	#'I'
	jeq	upscr
	cmp	#'J'
	jeq	clrtoend
	cmp	#'K'
	jeq	clracross
	cmp	#'e'
	beq	cshow
	cmp	#'f'
	beq	chide
	cmp	#'p'
	jeq 	inverse
	cmp	#'q'
	jeq	normal
	cmp	#'Y'
	beq	move
	cmp	#'a'
	beq	op_a
	cmp	#'b'
	beq	op_b
	cmp	#'c'
	beq	op_c
	bne	stdmode
	;
	;	Movement is esc-y sym sym: wait for the final symbol
	;
esc_y1:
	sta	newy
	lda	#<esc_y2
	ldx	#>esc_y2
	bne	setop
	;
	;	Esc Y - wait for first symbol of co-ordinates
	;
move:
	lda	#<esc_y1
	ldx	#>esc_y1
	bne	setop
	;
	;	Esc a b and c have a following smybol
	;
op_a:
	lda	#<esc_a
	ldx	#>esc_a
	bne	setop
op_b:
	lda	#<esc_b
	ldx	#>esc_b
	bne	setop
op_c:
	lda	#<esc_c
	ldx	#>esc_c
	bne	setop
	;
	;	Go back to normal mode but note cursor changed
	;
stdmode_mv:
	inc	@cursormod
	;
	;	Go back to normal mode
	;
stdmode:
	lda	#<vtputc
	ldx	#>vtputc
	;
	;	Set the next operation vector to XA
	;
setop:
	sta	@vtstate
	stx	@vtstate + 1
	rts
	;
	;	Show the curso
	;
cshow:
	lda	#0
	sta	@cursorhide
	beq	stdmode
	;
	;	Hide the cursor
	;
chide:
	lda	#1
	sta	@cursorhide
	bne	stdmode
	;
	;	Move to top left
	;
home:
	lda	#0
	sta	@cursorx
	sta	@cursory
	beq	stdmode_mv
	;
	;	Move up scrolling backwards if needed
	;
upscr:
	lda	@cursory
	beq	backscroll
	dec	@cursory
	jmp	stdmode_mv
backscroll:
	jsr	scroll_down
	jmp	stdmode
	;
	;	Clear to the end of the current line
	;
clrtoend:
	ldx	@cursorx
	lda	@cursory
doclrtoend:
	; Clear from pos XA to end
	jsr	plot_xacalc
	; vidptr is now the right place
	; XY is the count to do
	sty	@tmp			; save low bytes
	lda	#' '

	; Do each full block of 256 bytes
	ldy	#0
	; If there are any .... maybe < 256
	cpx	#0
	beq	clrl
doclr:
	sta	(@vidptr),y
	iny
	bne	doclr
	inc	@vidptr+1	
	dex
	bne	doclr
clrl:	lda	@tmp
	beq	noclr
	lda	#' '
clrlp:	sta	(@vidptr),y
	iny
	cpy	@tmp
	bne	clrlp
noclr:
	; We messed with vidptr
	jmp	stdmode_mv
	;
	;	Clear from current position to end of line
	;
clracross:
	jsr	plot_calc
	lda	#39
	sec
	sbc	@cursorx		; How many to do ?
	beq	atright
	tay
	lda	#' '
nextclr:
	sta	(@vidptr),y
	dey
	bne	nextclr
atright:
	jmp	stdmode_mv
;
;	Final step of esc-Y Y X
;	Invalid Y causes only X to change. This is a documented feature
;	of VT52 and actively used.
;
esc_y2:
	sec
	sbc	#32
	cmp	#40
	bcs	nosetx
	sta	@cursorx
nosetx:	lda	newy
	sec
	sbc	#32
	cmp	#24
	bcs	nosety
	sta	@cursory
nosety:	jmp	stdmode_mv
;
;	Set the various attributes
;
esc_a:
	and	#~VTA_ALTCHAR
	sta	@tmp
	lda	_vtattr
	and	#VTA_ALTCHAR
	ora	@tmp
	jmp	doalt
esc_b:
	and	#31
	sta	_vtink
	jmp	doaltn
esc_c:
	and	#31
	sta	_vtpaper
	jmp	doaltn

;
;	Support routines. TODO hardware scroll
;

; Quick hack for now - we should rewrite the display lists not copy memory
scroll_up:
	lda	#>screen
	sta	@tmp+1
	sta	@tmp2+1
	lda	#0x00
	sta	@tmp
	lda	#0x28
	sta	@tmp2
	ldy	#0
	ldx	#3
cpup:	lda	(@tmp2),y
	sta	(@tmp),y
	iny
	bne	cpup
	inc	@tmp2+1
	inc	@tmp+1
	dex
	bne	cpup
cpup2:	lda	(@tmp2),y
	sta	(@tmp),y
	iny
	cpy	#0xC0
	bne	cpup2
	lda	#' '
wipe:	sta	(@tmp),y
	iny
	cpy	#0xE8
	bne	wipe
	rts
; TODO

scroll_down:
	rts

	.common

	.export plot_xacalc

;	X = X, A = Y
plot_xacalc:
	jsr	doxacalc
	;	Now the question - how many bytes do we need to clear
	;	vidptr is the new pointer
	lda	#<0x3E8+screen
	sec
	sbc	@vidptr
	tay
	lda	#>0x3E8+screen
	sbc	@vidptr+1
	tax
	;	Do XY bytes from @vidptr
	rts

plot_calc:
	ldx	@cursorx
	lda	@cursory
doxacalc:
	ldy	#0
	stx	@tmp		; X co-ord
	; A is 0-39
	asl	a		; x 2
	asl	a		; x 4
	; Can overflow beyond this point
	asl	a
	bcc	noover
	iny
noover:
	sty	@tmp2		; set upper byte
	sty	@tmp3+1		; save whole x 8 value
	sta	@tmp3
	asl	a		; x 16
	rol	@tmp2
	asl	a		; x 32
	rol	@tmp2
	; C will be clear
	adc	@tmp3		; low add
	bcc	nobump
	inc	@tmp3+1		; carry into uppet for add
	clc
nobump:	adc	@tmp		; add X
	sta	@vidptr		; low set
	lda	@tmp2		; high
	adc	@tmp3+1		; fold in upper of tmp3 and any X overflow
	adc	#>screen	; screen base
	sta	@vidptr+1
	rts

	.export _vtattr_notify

_vtattr_notify:
	lda	_vtattr
	ror	a		; Inverse into top bit
	ror	a
	and	#0x80
	sta	@vidinv		; Stash inverse bit
	rts			; for now - no attributes
