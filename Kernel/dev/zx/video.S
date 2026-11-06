;
;        zx128 vt primitives
;
        ; exported symbols
        .export zx_plot_char
        .export zx_scroll_down
        .export zx_scroll_up
        .export zx_cursor_on
        .export zx_cursor_off
	.export zx_cursor_disable
        .export zx_clear_lines
        .export zx_clear_across
        .export zx_do_beep
	.export _curattr

videopos:
        ld	a,e
        and	7
        rrca
        rrca
        rrca 
        add	a,d
        ld	d,e
        ld	e,a
        ld	a,d
        and	0x18
        or	SCREENBASE	    ; Standard screen
        ld	d,a
	VIDEO_MAP
	ret

videoattr:
	;			32 x E + D into HL
	ld	a,e
	rrca
	rrca
	rrca			; A is now 32xE with the top bits overflowed
				; into the low 2 bits
	ld	l,a
	and	3		; Extract the low 2 bits for the high
	add	a, SCREENBASE+0x18	; Attributes start 0x5800
	ld	h,a
	ld	a,l
	and	0xE0		; mask the bits that are valid
	add	a,d		; add the low 5 bits from D
	ld	l,a		; and done (the add can't overflow)
	ret

#ifdef ZXVID_ONLY
_plot_char:
#endif
zx_plot_char:
	push	bc
#ifdef BANKED_Z80
	ld	hl,6
#else
	ld	hl,4
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)

	push de
        call videopos

        ld	b, 0		; calculating offset in font table
        ld	a, c

	.export _altmod
_altmod:	; patched for altchars between and 127 and or 128
	and	0x7F		; also clear carry
        rla
        rl	b
        rla
        rl	b
        rla
        rl	b
        ld	c, a

        ld	hl, _fontdata_8x8-32*8	; font
        add	hl, bc		; hl points to first byte of char data

	; We do underline for now - not clear italic or bold are useful
	; with the font we have.
	ld	bc, (_vtattr)	; c is vt attributes

        ; printing
plot_char_loop:
        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
        ld	(de), a
        inc	hl	; next byte of char data
        inc	d	; next screen line

        ld	a, (hl)
	bit	1,c		    ; underline ?
	jr	nz, last_ul
plot_attr:
        ld	(de), a

	pop	de
	call	videoattr
	ld	a,(_curattr)
	ld	(hl),a
	VIDEO_UNMAP
	pop	bc
        ret

last_ul:
	ld	a,0xff
	jr	plot_attr

#ifdef ZXVID_ONLY
_clear_lines:
#endif
zx_clear_lines:
	push	bc
#ifdef BANKED_Z80
	ld	hl,6
#else
	ld	hl,4
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	
	; This way we handle 0 correctly
	inc d
	jr nextline

clear_next_line:
        push	de
        ld	d, 0	; from the column 0
        ld	b, d	; b = 0
        ld	c, 32	; clear 32 cols
        call	do_clear_line
        pop	de
        inc	e
nextline:
        dec	d
        jr	nz, clear_next_line
	pop	de
        ret


#ifdef ZXVID_ONLY
_clear_across:
#endif
zx_clear_across:
	push	bc
#ifdef BANKED_Z80
	ld	hl,6
#else
	ld	hl,4
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)
	ld	a,c
	or	a
	call	nz, do_clear_line
	pop	bc
	ret

do_clear_line:
	push	de
	push	bc
        call	videopos	; first pixel line of first character in DE
	ld	h,d
	ld	l,e
        xor	a

        ; no boundary checks. Assuming that D + C < SCREEN_WIDTH

clear_line:
        ld	b, 8		; 8 pixel lines to clear for this char
clear_char:
        ld	(de), a
        inc	d
        djnz	clear_char

        inc	hl
	ld	d,h
	ld	e,l
        dec	c
        jr	nz, clear_line

	pop	bc
	pop	de
	call	videoattr
	ld	a,(_curattr)
	ld	b,c
setattr:
	ld	(hl),a
	inc	hl
	djnz	setattr
	VIDEO_UNMAP
        ret

copy_line:
        ; HL - source, DE - destination

        ; convert line coordinates to screen coordinates both for DE and HL
        push	de
        ex	de, hl
        call	videopos
        ex	de, hl
        pop	de
        call	videopos

        ld	c, 8

copy_line_nextchar:
        push	hl
        push	de

        ld	b, 32

copy_pixel_line:
        ld	a, (hl)
        ld	(de), a
        inc	e
        inc	l
        djnz	copy_pixel_line

        pop	de
        pop	hl
        inc	d
        inc	h
        dec	c
        jr	nz, copy_line_nextchar
	VIDEO_UNMAP
        ret

        ; TODO: the LDIR way should be much faster

#ifdef ZXVID_ONLY
_scroll_down:
#endif
zx_scroll_down:
        ; set HL = (0,22), DE = (0, 23)
        xor	a
        ld	d, a
        ld	h, a
        ld	l, 22
        ld	e, 23
        ld	c, 23           ; 23 lines to move

loop_scroll_down:
        push	hl
        push	de
        push	bc

        call	copy_line

        pop	bc
        pop	de
        pop	hl

        dec	l
        dec	e
        dec	c
        jr	nz, loop_scroll_down

	VIDEO_MAP
	; Attributes
	ld	hl,0x5ADF
	ld	de,0x5AFF
	ld	bc,0x02E0
	lddr

	VIDEO_UNMAP
        ret


#ifdef ZXVID_ONLY
_scroll_up:
#endif
zx_scroll_up:
	push	bc
        ; set HL = (0,1), DE = (0, 0)
        xor	a
        ld	d, a
        ld	e, a
        ld	h, a
        ld	l, 1
        ld	c, 23           ; 23 lines to move

loop_scroll_up:
        push	hl
        push	de
        push	bc

        call	copy_line

        pop	bc
        pop	de
        pop	hl

        inc	l
        inc	e
        dec	c
        jr	nz, loop_scroll_up

	VIDEO_MAP
	ld	hl,0x5820
	ld	de,0x5800
	ld	bc,0x02E0
	ldir
	VIDEO_UNMAP
	pop	bc
        ret

#ifdef ZXVID_ONLY
_cursor_on:
#endif
zx_cursor_on:
#ifdef BANKED_Z80
	ld	hl,4
#else
	ld	hl,2
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
        ld	(cursorpos), de

        call	videopos
        ld	a, 7
        add	a, d
        ld	d, a
        ld	a, (de)
	cpl
        ld	(de), a
	VIDEO_UNMAP
        ret
#ifdef ZXVID_ONLY
_cursor_disable:
_cursor_off:
#endif
zx_cursor_disable:
zx_cursor_off:
        ld	de, (cursorpos)
        call	videopos
        ld	a, 7
        add	a, d
        ld	d, a
	ld	a,(de)
	cpl
        ld	(de), a
	VIDEO_UNMAP
#ifdef	ZXVID_ONLY
_do_beep:
#endif
zx_do_beep:
        ret

	.data
cursorpos:
        .word 0

	.commondata
_curattr:
	.byte 7
