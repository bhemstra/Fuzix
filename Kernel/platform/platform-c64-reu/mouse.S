
	.common
	.export mousexy
	.export mouseclamp
	.export mouseshow

	.export _vtmouse
	.export _mousex
	.export _mousexh
	.export _mousey
	.export _mouseyh
	.export _mousemoved
	.export _mousetrack

;
;	C64 1351 Mouse
;
;	The SID is basically bamboozled by the mouse into doing the POT
;	as co-ordinate shifts.
;
;	See the mouse manual for most of this.
;

mousexy:		; I'm too sexy for my mouse
	ldy	#0
	jsr	movchk
	iny
movchk:
	lda	0xD419,y	; get position
	pha
	ldx	#0

	sec
	sbc	old_pot,y
	and	#0x7F
	cmp	#0x40		; Sign bit
	bcs	nega
	lsr	a		; scale
	beq	wrap0
modify:
	clc
	adc	pos,y
	sta	pos,y
	txa
	adc	posh,y
	sta	posh,y
	pla
	sta	old_pot,y
	inc	_mousemoved
	rts
wrap0:
	pla
	rts
nega:
	ora	#0xC0		; Sign extend
	cmp	#0xff
	beq	wrap0		; Avoid jitter around 0
	sec
	ror	a		; Scale keeping sign
	dex
	bne	modify

;
;	Do mouse with joystick. Needs acceleration to be usable TODO
;
joyxy:
	lda	0xDC00		; Joystick in port 2
	ldy	#1
	jsr	joybits		; Do up/down
	dey
;
;	Turn a pair of bits into a movement
;
joybits:
	lsr	a
	bcc	notsub
	lda	pos,y
	sec
	sbc	#1
	sta	pos,y
	lda	pos+1,y
	sbc	#0
	sta	pos+1,y
notsub:
	lsr	a
	bcc	notadd
	lda	pos,y
	clc
	adc	#1
	sta	pos,y
	lda	pos+1,y
	adc	#0
	sta	pos+1,y
notadd:
	rts


;
;	Clamp mouse pointer to screen
;
mouseclamp:
	lda	_mouseyh
	bmi	yclampl		; -ve Y is clamped to 0
	bne	yclamph		; >  0xFF is clamped to 200
	lda	_mousey		; check if in range ?
	cmp	#200		; Bottom of screen with bit of mouse
	bcs	yclamph
xclamp:
	lda	_mousexh
	bmi	xclampl
	beq	xok
	cmp	#1
	bne	xclamph
	lda	_mousex
	cmp	#0x40
	bcs	xclamph
xok:	rts
yclamph:
	lda	#199
	sta	_mousey
	lda	#0
	sta	_mouseyh
	beq	xclamp
yclampl:
	lda	#0
	sta	_mouseyh
	sta	_mousey
	beq	xclamp
xclamph:
	lda	#0x3F
	sta	_mousex
	lda	#1
	sta	_mousexh
	rts
xclampl:
	lda	#0
	sta	_mousex
	sta	_mousexh
	rts

mouseshow:
	lda	_mousex
	clc
	adc	#23
	sta	0xD002
	sta	0xD004
	lda	_mousexh
	adc	#0
	and	#1
	beq	hiclr
	lda	#6
	ora	0xD010		; Set upper bits on X
wdoy:
	sta	0xD010
	lda	#199
	sec
	sbc	_mousey		; Invert the Y co-ordinate
	clc
	adc	#49		; Bias as hardware needs
	sta	0xD003
	sta	0xD005
	rts
hiclr:
	lda	0xD010
	and	#0xF9
	jmp	wdoy

	.commondata

pos:
_mousex:
	.byte	160
_mousey:
	.byte	100
posh:
_mousexh:
	.byte	0
_mouseyh:
	.byte	0
_mousemoved:
	.byte	0	; Mouse has moved

old_pot:
old_potx:
	.byte	0
old_poty:
	.byte	0
_vtmouse:
	.byte	0
_mousetrack:
	.byte	0	; Set to enable tracking
