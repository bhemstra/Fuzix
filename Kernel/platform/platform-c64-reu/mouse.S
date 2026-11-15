;
;	C64 1351 Mouse
;
;	The SID is basically bamboozled by the mouse into doing the POT
;	as co-ordinate shifts.
;
;	See the mouse manual for most of this.
;

	.common
	.export mousexy
	.export mouseclamp
	.export mouseshow

mousexy:		; I'm too sexy for my mouse
	lda	0xD419	; POTX
	ldy	old_potx
	jsr	movchk
	sty	old_potx

	clc
	adc	xpos
	sta	xpos
	txa
	adc	xposmsb
	sta	xposmsb

	lda	0xD41A
	ldy	old_poty
	jsr	movchk
	sty	old_poty

	clc
	adc	ypos
	sta	ypos
	txa
	adc	yposmsb
	sta	yposmsb
	rts

movchk:
	sty	oldv
	sta	newv		; tay
	ldx	#0

	sec
	sbc	oldv
	and	#0x7F
	cmp	#0x40		; Sign bit
	bcs	nega
	lsr	a		; scale
	beq	wrap0
	ldy	newv
	rts
nega:
	ora	#0xC0		; Sign extend
	cmp	#0xff
	beq	wrap0		; Avoid jitter around 0
	sec
	ror	a		; Scale keeping sign
	dex
	ldy	newv
	rts
wrap0:
	lda	#0		; txa ?
	rts

mouseclamp:
	lda	yposmsb
	bmi	yclampl		; -ve Y is clamped to 0
	bne	yclamph		; >  0xFF is clamped to 200
	lda	ypos		; check if in range ?
	cmp	#200		; Bottom of screen with bit of mouse
	bcs	yclamph
xclamp:
	lda	xposmsb
	bmi	xclampl
	beq	xok
	cmp	#1
	bne	xclamph
	lda	xpos
	cmp	#0x40
	bcs	xclamph
xok:	rts
yclamph:
	lda	#199
	sta	ypos
	lda	#0
	sta	yposmsb
	beq	xclamp
yclampl:
	lda	#0
	sta	yposmsb
	sta	ypos
	beq	xclamp
xclamph:
	lda	#0x3F
	sta	xpos
	lda	#1
	sta	xposmsb
	rts
xclampl:
	lda	#0
	sta	xpos
	sta	xposmsb
	rts

mouseshow:
	lda	xpos	
	clc
	adc	#23
	sta	0xD002
	sta	0xD004
	lda	xposmsb
	adc	#0
	and	#1
	beq	hiclr
	lda	#6
	ora	0xD010		; Set upper bits on X
wdoy:
	sta	0xD010
	lda	#199	
	sec
	sbc	ypos		; Invert the Y co-ordinate
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

oldv:	.byte	0
newv:	.byte	0
xpos:
	.byte	0
xposmsb:
	.byte	0
ypos:
	.byte	0
yposmsb:
	.byte	0
old_potx:
	.byte	0
old_poty:
	.byte	0
