;
; Joysticks handling
;

	; exported (code)
	.export _jsread

	.code

;
; Joystick helper
;
; jsread(buffer)
;
; Returns a buffer of words in the format
; right left/right, button
; right up/down, button
; left left/right, button
; left up/down, button
;

_jsread:
	; Buffer is in D on entry
	tfr d,x
	pshs u
	lda #0xFF
	sta 0xFF02	; Keyboard scan lines off
	lda #0x08	; Select right joystick
	sta 0xFF23	; Sound off a moment
	bsr jstwo
	lda #0x09
	bsr jstwo
	puls u,pc
jstwo:
	sta 0xFF03	; P0 CR B - select joystick L or R
	lda #0x04
	sta 0xFF01	; X
	bsr jsfind
	lda #0x0C	; Y
	sta 0xFF01
	; Fall through
jsfind:
	ldu #jstmp
	; Binary search the joystick DAC position
	lda #0x20
	sta ,u	; start in the middle and binary search
jssearch:
	lsr ,u
	beq jsdone
	sta 0xFF20
	tst 0xFF20
	bpl jsover
	adda ,u
	bra jssearch
jsover:
	suba ,u
	bra jssearch
jsdone:
	ldb 0xFF20	; save fire button in bit 0
	std ,x++
	rts

	.data

jstmp:
	.byte 0
