;
;	Frame set up helper used by SDCC generated code
;
	.module crtenter
	.area	_CODE

	.globl	___sdcc_enter_ix

___sdcc_enter_ix:
	pop	hl		; return address
	push	ix		; save frame pointer
	ld	ix, #0
	add	ix, sp		; set ix to the stack frame
	jp	(hl)		; and return
