;
;	Display
;
;	Put this code high so we are clear of the video window
;
;	We assume _data and _bss are > 0x7FFF which should be pretty safe
;
	.common

videopos80:
	; E = Y D = X, output HL = addr, C preserved
	ld	a, e
	add	a, a	;	x 2 (max 48)
	add	a, a	;	x 4 (max 96)
	add	a, a	;	x 8 (max 192)
	ld	l, a
	ld	h, 0
	push	hl
	add	hl, hl	;	x 16
	add	hl, hl	;	x 32
	ld	a, d
	pop	de
	add	hl, de	;	x 40
	add	hl, hl	;	drop this one for 40 col version
	ld	e, a
	ld	d, 0x30
	add	hl, de	;	and screen mapped address
	ld	d, h
	ld	e, l
;	inc	d	Only needed for 40 cols - in 80 tram will do it
;	inc	d
;	inc	d
;	inc	d	;	HL = symbol DE = attribute
	ld	a, 0xE1
	jp	map_video	; map screen

videopos40:
	; E = Y D = X, output HL = addr, C preserved
	ld	a, e
	add	a, a	;	x 2 (max 48)
	add	a, a	;	x 4 (max 96)
	add	a, a	;	x 8 (max 192)
	ld	l, a
	ld	h, 0
	push	hl
	add	hl, hl	;	x 16
	add	hl, hl	;	x 32
	ld	a, d
	pop	de
	add	hl, de	;	x 40
	ld	e, a
	ld	d, 0x30
	add	hl, de	;	and screen mapped address
	ld	d, h
	ld	e, l
	inc	d	;	Single mapping in 40 column
	inc	d
	inc	d
	inc	d	;	HL = symbol DE = attribute
	jp	map_video	; map screen

	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_lines
	.export _clear_across
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _set_border
	.export	_set_mode
	.export _load_character

_plot_char:
	push	bc
	ld	hl, 4
	add	hl, sp
	ld	e, (hl)
	inc	hl
	inc	hl
	ld	d, (hl)
	inc	hl
	inc	hl
	ld	c, (hl)
	ld	a,(_vtmode)
	or	a
	jr	z, plot80
	call	videopos40
	ld	(hl),c
popvidout40:
	pop	bc
vidout40:
	ld	a, 0x21
	out	(0xE0),a
	jp	map_kernel

plot80:
	call	videopos80
	ld	(hl), c
	ld	a, 0xE1
	out	(0xE0), a
	ld	a,(_vtcol)
	ld	(de),a
popvidout80:
	pop	bc
vidout80:
	ld	a, 0x61
	out	(0xE0), a
	jp	map_kernel

_scroll_down:
	push	bc
	ld	a,(_vtmode)
	or	a
	jr	z, sd80
	call	map_video
	ld	hl, 0x33E7	; last line right char
	ld	de, 0x33BF	; line above
	ld	bc, 0x03C0	; all but one line
	ld	hl, 0x37E7	; last line right char
	ld	de, 0x37BF	; line above
	ld	bc, 0x03C0	; all but one line
	lddr
	jr	popvidout40
sd80:
	call	map_video
	ld	hl, 0x37CF	; last line right char
	ld	de, 0x377F	; line above
	ld	bc, 0x0780	; all but one line
	lddr
	ld	a, 0xE1		; Fixme store somewhere
	out	(0xE0), a	; TRAM on
	ld	hl, 0x37CF	; last line right char
	ld	de, 0x377F	; line above
	ld	bc, 0x0780	; all but one line
	lddr
	jr	popvidout80

_scroll_up:
	push	bc
	ld	a,(_vtmode)
	or	a
	jr	z, su80
su40:
	ld	hl, 0x3028
	ld	de, 0x3000
	ld	bc, 0x03C0
	call	map_video
	ldir
	ld	hl, 0x3428
	ld	de, 0x3400
	ld	bc, 0x03C0
	ldir
	jr	popvidout40
su80:
	ld	hl, 0x3050
	ld	de, 0x3000
	ld	bc, 0x0780
	call	map_video
	ldir
	ld	a, 0xE1
	out	(0xE0), a	; TRAM on
	ld	hl, 0x3050
	ld	de, 0x3000
	ld	bc, 0x0780
	ldir
	jr	popvidout80

_clear_lines:
	ld	hl, 2
	add	hl, sp
	ld	e, (hl)
	inc	hl
	inc	hl
	ld	d, (hl)		; Clear D lines from line E
	xor	a
	cp	d		; no work ?
	ret	z
	push	bc
	ld	c, d		; save
	ld	d, a		; clear d
	ld	a, (_vtmode)
	or	a
	jr	z, cl80
	call	videopos40
	ld	a, (_vtcol)
wipeo4:
	ld	b, 40
wipe14:
	ld	(hl), ' '
	ld	(de), a
	inc	hl
	inc	de
	djnz	wipe14
	dec	c
	jr	nz, wipeo4
	jr	popvidout40
cl80:
	call	videopos80
	ld	de, (_vtcol)	; ends up in E
wipeo:
	ld	b, 80
wipe1:
	ld	(hl), ' '
	ld	a, 0xE1
	out	(0xE0), a
	ld	(hl), e
	ld	a, 0x61
	out	(0xE0), a
	inc	hl
	djnz	wipe1
	dec	c
	jr	nz, wipeo
	jr	popvidout80

_clear_across:
	ld	hl, 2
	add	hl, sp
	ld	e, (hl)
	inc	hl
	inc	hl
	ld	d, (hl)
	inc	hl
	inc	hl
	ld	a, (hl)
	; DE = coords, A = count
	or	a
	ret	z		; No work
	push	bc
	ld	b, a
	ld	a, (_vtmode)
	or	a
	jr	z, ca80
ca40:
	call	videopos40
	ld	a, (_vtcol)
	ld	c, ' '
wipea40:
	ld	(hl), c
	ld	(de), a
	inc	hl
	inc	de
	djnz	wipea40
	jr	popvidout40
ca80:
	call	videopos80
	ld	de, (_vtcol)
wipea:
	ld	(hl), ' '
	ld	a, 0xE1
	out	(0xE0), a
	ld	(hl), e
	ld	a, 0x61
	out	(0xE0),a
	inc	hl
	djnz	wipea
	jr	popvidout80

_cursor_on:
	ld	hl, 2
	add	hl, sp
	ld	e, (hl)
	inc	hl
	inc	hl
	ld	d, (hl)
	ld	a, (_vtmode)
	or	a
	jr	z, co80
	call	videopos40
	ex	de,hl
	ld	(cursorpos),hl
cfix40:
	ld	a,(hl)
	rrca
	rrca
	rrca
	rrca
	ld 	(hl),a
	jr	vidout40
co80:
	call	videopos80
	ld	(cursorpos), hl
cfix80:
	ld	a, 0xE1
	out	(0xE0), a
	ld	a, (hl)
	rrca
	rrca
	rrca
	rrca
	ld	(hl), a
	jr	vidout80

_cursor_off:
	call	map_video
	ld	hl, (cursorpos)
	ld	a,(_vtmode)
	or	a
	jr	z, cfix80
	jr	cfix40

_cursor_disable:
	ret

_set_border:
	pop	hl
	pop	de
	push	de
	push	hl
set_border:
	ld	hl, 0x37FF
	ld	a, (_vtmode)
	or	a
	jr	z, setb80
	ld	a, (_vtcol)
	call	map_video
	ld	(hl), a
	ld	hl, 0x33FF
	ld	(hl), ' '
	jr	vidout40
setb80:
	ld	de, (_vtcol)
	call	map_video
	ld	(hl), ' '
	ld	a, 0xE1
	out	(0xE0), a
	ld	(hl), e
	jr	vidout80

;
;	Set video mode. For now it's just a case of 0 = 80 1 = 40 col
;
_set_mode:
	ld	a, (_vtmode)
	or	a
	ld	a, 0x61
	jr	z, mode80
	ld	a, 0x21
mode80:
	out	(0xE0), a
	ret

_load_character:
	push	bc
	ld	hl, 4
	add	hl, sp
	ld	a, (hl)
	inc	hl
	inc	hl
	ld	e, (hl)
	inc	hl
	ld	d, (hl)

	ld	l, a
	ld	h, 0
	add	hl, hl
	add	hl, hl
	add	hl, hl		; 0x0000-0x07FF
	set	6, h		; 0x4000-0x7FFF
	ex	de, hl
	ld	bc, 8
	call	map_font	; font RAM to 0x4000
	ldir			; copy symbol into font
	pop	bc
	jp	map_kernel	; restore mapping

	; commondata is per task so must be in real data
	; data will be above video window
	.data

	.export	_vtcol

cursorpos:
	.word	0
cursorpeek:
	.byte	0
_vtcol:
	.byte	0x70
