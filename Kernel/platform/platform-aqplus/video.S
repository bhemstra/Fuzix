;
;	Display
;
;	Put this code high so we are clear of the video window
;
	.common

videopos:
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
	jp	map_video	; map screen

	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_lines
	.export _clear_across
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _vtattr_notify

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
	call	videopos
	ld	(hl), c
	ld	a, 0xE1
	out	(0xE0), a
	ld	a,(vtattr)
	ld	(hl),a
	ld	a, 0x61
	out	(0xE0), a
	pop	bc
	jp	map_kernel

_scroll_down:
	push	bc
	ld	hl, 0x37CF	; last line right char
	ld	de, 0x377F	; line above
	ld	bc, 0x0780	; all but one line
	call	map_video
	lddr
	ld	a, 0xE1		; Fixme store somewhere
	out	(0xE0), a	; TRAM on
	ld	hl, 0x37CF	; last line right char
	ld	de, 0x377F	; line above
	ld	bc, 0x0780	; all but one line
	lddr
	ld	a, 0x61
	out	(0xE0),a
	pop	bc
	jp	map_kernel

_scroll_up:
	push	bc
	ld	hl, 0x3050
	ld	de, 0x3000
	ld	bc, 0x0780
	call	map_video
	ldir
	ld	a, 0xE1		; Fixme store somewhere
	out	(0xE0), a	; TRAM on
	ld	hl, 0x3050
	ld	de, 0x3000
	ld	bc, 0x0780
	ldir
	ld	a, 0x61
	out	(0xE0),a
	pop	bc
	jp	map_kernel

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
	call	videopos
	ld	de, (vtattr)	; ends up in E
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
	pop	bc
	jp	map_kernel

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
	call	videopos
	ld	de, (vtattr)
wipea:
	ld	(hl), ' '
	ld	a, 0xE1
	out	(0xE0), a
	ld	(hl), e
	ld	a, 0x61
	out	(0xE0),a
	inc	hl
	djnz	wipea
	pop	bc
	jp	map_kernel

_cursor_on:
	ld	hl, 2
	add	hl, sp
	ld	e, (hl)
	inc	hl
	inc	hl
	ld	d, (hl)
	call	videopos
	ld	(cursorpos), hl
	ld	a, 0xE1
	out	(0xE0), a
	ld	a, (hl)
	ld	(cursorpeek), a
	rra
	rra
	rra
	rra
	ld	(hl), a
	ld	a, 0x61
	out	(0xE0),a
	jp	map_kernel

_cursor_off:
	call	map_video
	ld	hl, (cursorpos)
	ld	a, 0xE1
	out	(0xE0), a
	ld	a, (cursorpeek)
	ld	(hl), a
	ld	a, 0x61
	out	(0xE0), a
	jp	map_kernel

_vtattr_notify:
_cursor_disable:
	ret

	; commondata is per task so must be in real data
	; data will be above video window
	.data

cursorpos:
	.word	0
cursorpeek:
	.byte	0
vtattr:
	.byte	0x70
