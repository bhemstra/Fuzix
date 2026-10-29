;
;	String helpers for the stack based (sdcccall 0) convention.
;	string.h declares these as preserving IY, they also preserve IX.
;
	.module string
	.area	_CODE

	.globl	_memmove
	.globl	_strlen
	.globl	_strcpy

;
;	void *memmove(void *dst, const void *src, size_t n)
;
_memmove:
	push	ix
	ld	ix, #0
	add	ix, sp
	ld	e, 4(ix)	; dst
	ld	d, 5(ix)
	ld	l, 6(ix)	; src
	ld	h, 7(ix)
	ld	c, 8(ix)	; n
	ld	b, 9(ix)
	ld	a, b
	or	c
	jr	z, memmove_out
	; If dst > src copy from the top down
	ld	a, e
	sub	l
	ld	a, d
	sbc	a, h
	jr	c, memmove_up
	dec	bc
	add	hl, bc
	ex	de, hl
	add	hl, bc
	ex	de, hl
	inc	bc
	lddr
	jr	memmove_out
memmove_up:
	ldir
memmove_out:
	ld	l, 4(ix)	; return dst
	ld	h, 5(ix)
	pop	ix
	ret

;
;	size_t strlen(const char *s)
;
_strlen:
	pop	de
	pop	hl
	push	hl
	push	de
	xor	a
	ld	b, a
	ld	c, a
	cpir
	ld	hl, #-1
	sbc	hl, bc		; carry is clear after cpir finds the 0
	ret

;
;	char *strcpy(char *dst, const char *src)
;
_strcpy:
	pop	bc
	pop	de		; dst
	pop	hl		; src
	push	hl
	push	de
	push	bc
	push	de
strcpy_l:
	ld	a, (hl)
	ldi
	or	a
	jr	nz, strcpy_l
	pop	hl		; return dst
	ret
