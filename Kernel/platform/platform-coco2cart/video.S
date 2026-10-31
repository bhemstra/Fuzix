#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	; Methods provided
	.export _vid256x192
	.export _vidtxt
	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_across
	.export _clear_lines
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _vtattr_notify

	.export _video_read
	.export _video_write
	.export _video_cmd

	.export _lower
	.export _spaces


; No room currently for text mode so just disable it and point it at C000

_fontdata_8x8	.equ	0xC000

;
;	TODO: could hide the text video functions and init in discard ?
;
	.code

_vidtxt:
	; COCO2 defaults to text at 0400-05FF move it to 0200
	rts
;
;	Dragon video drivers
;
;	SAM V2=1 V1=1 V0=-
;	6847 A/G=1 GM2=1 GM1=1 GM0=1
;
_vid256x192:
	sta $ffc0
	sta $ffc3
	sta $ffc5
	lda $ff22
	anda #$07
	ora #$f0
	sta $ff22
	sta vidmode	; any non zero value will do
	ldb #24
	stb _vid_h
	decb
	stb _vid_b
	rts

;
;	Video base for text
;
txtaddr:
	ldx #VIDEO_BASE
	leax a,x		; X value
	lslb
	lslb
	lslb			; x 8 so keep unsigned
	leax b,x		; and add four times
	leax b,x
	leax b,x
	leax b,x
	rts
;
;	Compute the video base address
;	A = X, B = Y
;
vidaddr:
	ldx #VIDEO_BASE
	exg a,b
	leax d,x		; 256 x Y + X
	rts
;
;	plot_char(int8_t y, int8_t x, uint16_t c)
;
_plot_char:
	lda 2,s		; B = Y, A = X
	ldy 3,s		; Y = char
	tst vidmode
	bne plot_cg3
	bsr txtaddr
	tfr y,d
	tst _lower
	beq map_cases
	; We want to map
;	; 20-3F	to 60-7F		40-5F	^20	60-7F
	; 40-5F to 40-5F		60-7F	^20	40-5F
	; 60-7F to 00-1F		80-9F	^20	A0-BF
	addb #$20
	bmi low
	eorb #$20
	bra plotit
low:	andb #$1f
	bra plotit
map_cases:
	cmpb #0x60
	bcs upper
	subb #0x20
upper:
	andb #0x3F
plotit:
	stb ,x
	rts
plot_cg3:
	bsr vidaddr		; preserves X (holding the char)
	tfr y,d
	andb #$7F		; no high font bits
	subb #$20		; skip control symbols
	rolb			; multiply by 8
	rola
	rolb
	rola
	rolb
	rola
	tfr d,y
	leay _fontdata_8x8,y		; relative to font
	ldb _vtattr
	andb #0x3F		; drop the bits that don't affect our video
	beq plot_fast

	;
	;	General purpose plot with attributes, we only fastpath
	;	the simple case
	;
	clra
plot_loop:
	sta _vtrow
	ldb _vtattr
	cmpa #7		; Underline only applies on the bottom row
	beq ul_this
	andb #0xFD
ul_this:
	cmpa #3		; italic shift right for < 3
	blt ital_1
	andb #0xFB
	bra maskdone
ital_1:
	cmpa #5		; italic shift right for >= 5
	blt maskdone
	bitb #0x04
	bne maskdone
	orb #0x40		; spare bit borrow for bottom of italic
	andb #0xFB
maskdone:
	lda ,y+			; now throw the row away for a bit
	bitb #0x10
	bne notbold
	lsra
	ora -1,x		; shift and or to make it bold
notbold:
	bitb #0x04		; italic by shifting top and bottom
	beq notital1
	lsra
notital1:
	bitb #0x40
	beq notital2
	lsla
notital2:
	bitb #0x02
	beq notuline
	lda #0xff		; underline by setting bottom row
notuline:
	bitb #0x01		; inverse or not: we are really in inverse
	bne plot_inv		; by default so we complement except if
	coma			; inverted
plot_inv:
	bitb #0x20		; overstrike or plot ?
	bne overstrike
	sta ,x
	bra plotnext
overstrike:
	anda ,x
	sta ,x
plotnext:
	leax 32,x
	lda _vtrow
	inca
	cmpa #8
	bne plot_loop
	rts
;
;	Fast path for normal attributes
;
plot_fast:
	lda ,x+			; simple 8x8 renderer for now
	coma
	sta 0,x
	lda ,y+
	coma
	sta 32,x
	lda ,y+
	coma
	sta 64,x
	lda ,y+
	coma
	sta 96,x
	lda ,y+
	coma
	sta 128,x
	lda ,y+
	coma
	sta 160,x
	lda ,y+
	coma
	sta 192,x
	lda ,y+
	coma
	sta 224,x
	rts

;
;	void scroll_up(void)
;
_scroll_up:
	pshs u
	ldu #VIDEO_BASE
	tst vidmode
	bne scroll_up_cg3
scrup_t:
	ldx #VIDEO_BASE+0x20
scrup_tl:
	ldd ,x++
	std ,u++
	cmpx #VIDEO_BASE+512
	bne scrup_tl
	puls u,pc

scroll_up_cg3:
	leax 256,u
vscrolln:
	; Unrolled line by line copy
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	cmpx video_endptr
	bne vscrolln
	puls u,pc

;
;	void scroll_down(void)
;
;	Never used in text mode
;
_scroll_down:
	rts
	pshs u
	ldu #VIDEO_END
	leax -256,u
vscrolld:
	; Unrolled line by line loop
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	ldd ,--x
	std ,--u
	cmpx video_startptr
	bne vscrolld
	puls u,pc

video_startptr:
	.word	VIDEO_BASE
video_endptr:
	.word	VIDEO_END

;
;	clear_across(int8_t y, int8_t x, uint16_t l)
;
_clear_across:
	lda	2,s	; Y = B A = X
	ldy	3,s	; count
	tst	vidmode
	beq	clat
	jsr	vidaddr	; X now holds the address
	tfr	y,d	; Shuffle so we are writng to X and the counter
	lda	#0xff
clearnext:
	sta	,x
	sta	32,x
	sta	64,x
	sta	96,x
	sta	128,x
	sta	160,x
	sta	192,x
	sta	224,x
	leax	1,x
	decb
	bne	clearnext
	rts
clat:
	jsr	txtaddr	; X now holds address
	tfr	y,d		; count into B
	lda	_spaces
clatl:
	sta	,x+
	decb
	bne	clatl
	rts
;
;	clear_lines(int8_t y, int8_t ct)
;
_clear_lines:
	lda	2,s		; B is Y A is CT
	beq	cldone
	tst	vidmode
	bne	clines_cg3
	clra
	jsr	txtaddr		; Start of line into X
	lsl	2,s		; max of 15 lines
	lsl	2,s
	lsl	2,s
	lsl	2,s		; x 16 as dword
	ldd	_spaces
clt:
	std	,x++
	dec	2,s		; 32 bytes per line max 16 lines in text
	bne	clt
cldone:
	rts

clines_cg3:
	clrb			; A is Y B is now 0 (X)
	jsr vidaddr		; X now holds ptr to line start
	ldd #$ffff
	lsl 2,s
	lsl 2,s
	lsl 2,s
wipel:
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	std ,x++
	dec 2,s			; count of lines
	bne wipel
	rts

_cursor_on:
	lda	2,s
	tst	vidmode
	bne	con_cg3
	jsr	txtaddr
	stx	cursor_save
coff_txt:
	lda	#0x40
	eora	,x
	sta	,x
	rts

con_cg3:
	jsr	vidaddr
	stx	cursor_save
	; Fall through
_cursor_off:
	ldx	cursor_save
	tst	vidmode
	beq	coff_txt
	ldb	_vtattr
	bitb	#0x80
	bne	nocursor
	com	,x
	com	32,x
	com	64,x
	com	96,x
	com	128,x
	com	160,x
	com	192,x
	com	224,x
nocursor:
_vtattr_notify:
_cursor_disable:
	rts
;
;	These routines wortk in both 256x192x2 and 128x192x4 modes
;	because everything in the X plane is bytewide.
;
_video_write:
	clra			; clr C
	bra	tfr_cmd
_video_read:
	coma			; set C
	bra	tfr_cmd		; go

;;; This does the job of READ & WRITE
;;;   takes: C = direction 0=write, 1=read
;;;   takes: X = transfer buffer ptr + 2
tfr_cmd:
	ldx	2,s		; get argument
	pshs	u,y		; save regs
	orcc	#$10		; turn off interrupt - int might remap kernel
	ldd	#$80c0		; this is writing
	bcc	t_c		; if carry clear then keep D write
	exg	a,b		; else flip D: now is reading
t_c:	sta	t_b+1		; !!! self modify inner loop
	stb	t_b+3		; !!!  
	bsr	vidptr		; U = screen addr
	tfr	x,y		; Y = ptr to Height, width
	leax	4,x		; X = pixel data
	;; outter loop: iterate over pixel rows
t_a:	lda	3,y		; count = width
	pshs	u		; save screen ptr
	;; inner loop: iterate over columns
	;; modify mod+1 and mod+3 to switch directions
t_b:	ldb	,x+		; get a byte from src
	stb	,u+		; save byte to dest
	deca			; bump counter
	bne	t_b		; loop
	;; increment outer loop
	puls	u		; restore original screen ptr
	leau	32,u		; add byte span of screen (goto next line)
	dec	1,y		; bump row counter
	bne	t_a		; loop
	puls	u,y,pc		; restore regs, return
	

;
;	Find the address we need on a pixel row basis
;
vidptr:
	ldu	#VIDEO_BASE
	ldd	,x++		; Y into B
	lda	#32
	mul
	leau	d,u
	ldd	,x++		; X
	leau	d,u
	rts

_video_cmd:
	tfr	d,x
	pshs	u
	bsr	vidptr		; u now points to the screen
nextline:
	pshs	u			; save it for the next line
nextop:
	ldb	,x+			; op code, 0 = end of line
	beq	endline
oploop:
	lda	,u			; do one screen byte
	anda	,x
	eora	1,x
	sta	,u+
	decb
	bne	oploop		; keep going for run
	leax	2,x
	bra	nextop		; next triplet
endline:
	puls	u		; get position back
	leau	32,u		; down one scan line
	ldb	,x+		; get next op - 0,0 means end and done
	bne	oploop
	puls	u,pc

	.data
cursor_save:
	.word	0
_vtrow:
	.byte	0
vidmode:
	.byte	0
_lower:
	.byte	0
_spaces:
	.word	0x2020
