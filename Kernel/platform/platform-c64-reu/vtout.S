;
;	We are called from C as vtputchar(char c)
;
;	Really we want a sprite for the cursor
;

	.zp
	.export esc1
	.export escaped
	.export vtputc

; Where is our screen base
; Attributes are fixed at D800
screen	.equ	0x0400
; plot_calc knows screen/attribute diff is D4 so will also need changing
; if these are changed

cursorhide:
	.byte	0
curpos:
	.word	0
cursormod:
	.byte	0
cursave:
	.byte	0
vidptr:
	.word	0
vidatr:
	.word	0
vtstate:
	.word	0
cursorx:
	.byte	0
cursory:
	.byte	0
c64ink:
	.byte	0

	.data
	.export	_vtattr
newy:
	.byte	0
_vtattr:
	.byte	0
_vtpaper:
	.byte	0
_vtink:
	.byte	0

	.overlay4

#define VTA_INVERSE	0x01
#define VTA_ALTCHAR	0x40
#define VTHEIGHT	25
#define VTBOTTOM	24
#define VTWIDTH		40
#define VTRIGHT		39

	.export	_vtinit

_vtinit:
	lda	#0
	sta	cursorx
	sta	cursory
	sta	_vtattr
	lda	#1
	sta	@cursorhide
	sta	@cursormod
	lda	#14
	sta	@c64ink
	jsr	do_vtinit
	php		; docursor expects stack flags
	jmp	docursor

	.export	_vtputchar

_vtputchar:
	php
	sei
	;	Disable the current live cursor
	lda	@cursorhide
	bne	cursor_off
	ldy	#0
	lda	@cursave
	sta	(@curpos),y
cursor_off:
	ldy	#0
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
	lda	(@curpos),y
	sta	@cursave
	lda	#127
	sta	(@curpos),y
no_writec:
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
	; need 2K font to do ALTCHAR
	and	#127		; patch to OR 128 maybe ? if in common
	; ora	@vidinv		; invert if needed
	
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
	lda	@c64ink
	sta	(@vidatr),y
	; Move the working position right one
	inc	@vidptr
	bne	vidnc
	inc	@vidptr+1
vidnc:
	inc	@vidatr
	bne	vidnca
	inc	@vidatr+1
vidnca:
	; Adjust the cursor tracking
	inc	@cursorx
	lda	@cursorx
	cmp	#VTWIDTH
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
	cmp	#VTHEIGHT
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
	cmp	#VTHEIGHT
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
	cmp	#VTBOTTOM
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
	cmp	#VTRIGHT
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

	;	Is this worth doing with the REU instead - keep a space
	;	stashed at a fixed low addr (1 ?) and the c64ink in 2 when
	;	we do a vtattr_notify ? TODO
doclrtoend:
	; Clear from pos XA to end
	jsr	plot_xacalc
	; vidptr is now the right place
	; XY is the count to do
	sty	@tmp			; save low bytes

	; Do each full block of 256 bytes
	ldy	#0
	; If there are any .... maybe < 256
	cpx	#0
	beq	clrl
doclr:
	lda	#' '
	sta	(@vidptr),y
	lda	@c64ink
	sta	(@vidatr),y
	iny
	bne	doclr
	inc	@vidptr+1	
	inc	@vidatr+1	
	dex
	bne	doclr
clrl:	lda	@tmp
	beq	noclr
clrlp:	lda	#' '
	sta	(@vidptr),y
	lda	@c64ink
	sta	(@vidatr),y
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
	lda	#VTRIGHT
	sec
	sbc	@cursorx		; How many to do ?
	beq	atright
	tay
nextclr:
	lda	#' '
	sta	(@vidptr),y
	lda	@c64ink
	sta	(@vidatr), y
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
	cmp	#VTWIDTH
	bcs	nosetx
	sta	@cursorx
nosetx:	lda	newy
	sec
	sbc	#32
	cmp	#VTHEIGHT
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
;	REU display routines
;
scroll_down:
	lda	#0
	jsr	scroll
	; Clear the top line - worth doing via REU ?
	lda	#>screen
	sta	@tmp+1
	lda	#0xD8		; Colour memory
	sta	@tmp2+1
	lda	#0x00
wipes:
	sta	@tmp2
	sta	@tmp
	ldy	#0
wiper:
	lda	#' '
	sta	(@tmp),y
	lda	@c64ink
	sta	(@tmp2),y
	iny	
	cpy	#40
	bne	wiper
	rts
scroll_up:
	; Screen bounce buffer lives at 000004 in REU space
	lda	#0x28
	jsr	scroll
	lda	#>screen+0x3C0
	sta	@tmp+1
	lda	#0xDB
	sta	@tmp2+1
	lda	#0xC0
	bne	wipes
scroll:
	php
	sei
	sta	0xDF02
	ldx	#0
	stx	0xDF05
	stx	0xDF06
	stx	0xDF0A
	ldx	#0x04
	stx	0xDF03		; from 0428
	stx	0xDF04		; to 000004
	ldx	#0xC0
	stx	0xDF07
	ldx	#0x03
	stx	0xDF08		; 3C0 bytes
	ldx	#0xB0
	stx	0xDF01		; copy to REU, restore pointers
	eor	#0x28		; switch line so we can do up or down
	sta	0xDF02
	ldx	#0xB1		; copy back offset
	stx	0xDF01
	ldx	#0xD8
	stx	0xDF03		; from D800
	eor	#0x28
	sta	0xDF02		; set screen to D800 or D828
	ldx	#0xB0
	stx	0xDF01		; copy into scratch
	eor	#0x28
	sta	0xDF02
	ldx	#0xB1
	stx	0xDF01		; copy back
	plp
	rts

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
	inc	@tmp3+1		; carry into upper for add
	clc
nobump:	adc	@tmp		; add X
	sta	@vidptr		; low set
	sta	@vidatr
	sta	@tmp3		; save for colour
	lda	@tmp2		; high
	adc	@tmp3+1		; fold in upper of tmp3 and any X overflow
	adc	#>screen
	sta	@vidptr+1
	adc	#0xD4		; D800 is the colour RAM
	sta	@vidatr+1
	rts

	.export _vtattr_notify

_vtattr_notify:
	; Map colours
	lda	_vtink
	and	#0x1F
	tax
	lda	coltab,x
	sta	@c64ink
	lda	_vidpaper
	and	#0x1F
	tax
	lda	coltab,x
	sta	0xD021
	lda	_vtborder
	and	#0x1F
	tax
	lda	coltab,x
	sta	0xD020
	rts

coltab:
	.byte	0		; black
	.byte	6		; blue
	.byte	2		; red
	.byte	4		; magenta
	.byte	5		; green
	.byte	3		; cyan
	.byte	7		; yellow
	.byte	1		; white
	.byte	0		; black
	.byte	6		; blue
	.byte	2		; red
	.byte	4		; magenta
	.byte	5		; green
	.byte	3		; cyan
	.byte	7		; yellow
	.byte	1		; white
	; And native
	.byte	0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15

	.data

	.export	_vidpaper
	.export	_vtborder

_vidpaper:
	.byte	1		; blue
_vtborder:
	.byte	30		; native colour 14
