;
;	scc run time helpers
;
;	Binary operations take the left operand in DE and the right one in
;	HL and return the result in HL. BC is preserved.
;
		.code

		.export __sccmul
		.export __sccdiv
		.export __sccudiv
		.export __sccmod
		.export __sccumod
		.export __sccshl
		.export __sccshr
		.export __sccushr
		.export __sccjphl
		.export __sccswitch
		.export __sccrev

;	HL = DE * HL
__sccmul:
		push bc
		ld b,h
		ld c,l
		ld hl,0
		ld a,16
mul1:
		add hl,hl
		ex de,hl
		add hl,hl
		ex de,hl
		jr nc,mul2
		add hl,bc
mul2:
		dec a
		jr nz,mul1
		pop bc
		ret

;	Unsigned DE / HL: quotient in DE, remainder in HL
divmod:
		push bc
		ld b,h
		ld c,l
		ld hl,0
		ld a,16
div1:
		ex de,hl
		add hl,hl
		ex de,hl
		adc hl,hl
		jr c,div3
		or a
		sbc hl,bc
		jr nc,div2
		add hl,bc
		jr div4
div3:
		or a
		sbc hl,bc
div2:
		inc e
div4:
		dec a
		jr nz,div1
		pop bc
		ret

__sccudiv:
		call divmod
		ex de,hl
		ret

__sccumod:
		jr divmod

absde:
		bit 7,d
		ret z
		xor a
		sub e
		ld e,a
		sbc a,a
		sub d
		ld d,a
		ret

abshl:
		bit 7,h
		ret z
neghl:
		xor a
		sub l
		ld l,a
		sbc a,a
		sub h
		ld h,a
		ret

;	Signed: the quotient is negative if the signs differ
__sccdiv:
		ld a,d
		xor h
		push af
		call absde
		call abshl
		call divmod
		ex de,hl
		pop af
		or a
		jp m,neghl
		ret

;	Signed: the remainder takes the sign of the dividend
__sccmod:
		ld a,d
		push af
		call absde
		call abshl
		call divmod
		pop af
		or a
		jp m,neghl
		ret

;	HL = DE << HL
__sccshl:
		ld a,l
		ex de,hl
shl1:
		or a
		ret z
		add hl,hl
		dec a
		jr shl1

;	HL = DE >> HL (signed)
__sccshr:
		ld a,l
		ex de,hl
shr1:
		or a
		ret z
		sra h
		rr l
		dec a
		jr shr1

;	HL = DE >> HL (unsigned)
__sccushr:
		ld a,l
		ex de,hl
ushr1:
		or a
		ret z
		srl h
		rr l
		dec a
		jr ushr1

__sccjphl:
		jp (hl)

;
;	switch: HL is the value, the table follows the call:
;	count, count x (value, address), default address
;
__sccswitch:
		pop de
		ex de,hl
		push bc
		ld c,(hl)
		inc hl
		ld b,(hl)
		inc hl
sw1:
		ld a,b
		or c
		jr z,sw3
		ld a,(hl)
		inc hl
		cp e
		jr nz,sw2
		ld a,(hl)
		cp d
		jr nz,sw2
		inc hl
sw3:
		ld a,(hl)
		inc hl
		ld h,(hl)
		ld l,a
		pop bc
		jp (hl)
sw2:
		inc hl
		inc hl
		inc hl
		dec bc
		jr sw1

;
;	Reverse the order of the A words pushed before the call, so the
;	arguments evaluated left to right end up in C order. A >= 2.
;
__sccrev:
		push bc
		ld hl,4
		add hl,sp
		ld e,a
		ld d,0
		dec de
		ex de,hl
		add hl,hl
		add hl,de
		ex de,hl
		ld b,a
		srl b
rev1:
		ld a,(de)
		ld c,(hl)
		ld (hl),a
		ld a,c
		ld (de),a
		inc hl
		inc de
		ld a,(de)
		ld c,(hl)
		ld (hl),a
		ld a,c
		ld (de),a
		inc hl
		dec de
		dec de
		dec de
		djnz rev1
		pop bc
		ret
