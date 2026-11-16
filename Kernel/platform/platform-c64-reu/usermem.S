#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

		.export __ugetc
		.export __ugetw
		.export __uputc
		.export __uputw

;
;		Helpers in common space
;

		.common

#ifdef NO_REU
	.export __uget
	.export __uput

ugparg:	; uget/put argument fetch
	; leave Y as 0
	ldy	#0
	lda	(@sp),y		; User low
	iny
	sta	@tmp4
	lda	(@sp),y		; User high
	iny
	sta	@tmp4+1
	lda	(@sp),y		; Kernel low
	iny
	sta	@tmp3
	lda	(@sp),y		; Kernel high
	iny
	sta	@tmp3+1
	lda	(@sp),y		; Length low
	iny
	sta	@tmp2
	lda	(@sp),y		; Length high
	sta	@tmp2+1

	ldy	#0
	rts

; user, dst, count
;
;	Decidedly unoptimised (even the 6502 could manage a word a switch)
;
__uget:
	jsr	ugparg
	; Y is now 0 for counter

	ldx	@tmp2+1		; how many 256 byte blocks
	beq	__uget_tail	; if none skip to the tail

__uget_blk:
	jsr	map_proc_always	; map the user process in
	lda	(@tmp4), y	; get a byte of user data
	jsr	map_kernel	; map the kernel back in
	sta	(@tmp3), y	; save it to the kernel buffer
	iny			; move on one
	bne	__uget_blk	; not finished a block ?
	inc	@tmp3+1		; move src ptr 256 bytes on
	inc	@tmp4+1		; move dst ptr the same
	dex			; one less block to do
	bne	__uget_blk	; out of blocks ?

__uget_tail:
	cpy	@tmp2		; finished ?
	beq	__uget_done

	jsr	map_proc_always	; map the user process
	lda	(@tmp4),y	; get a byte of user data
	jsr	map_kernel	; map the kernel back in
	sta	(@tmp3),y	; save it to the kernel buffer
	iny			; move on
	bne	__uget_tail	; always taken (y will be non zero)

__uget_done:
	lda	#0
	tax
	ldy	#6
	jmp	__addysp	; And clean up stack

__uput:
	jsr	ugparg

	; Y is 0 for counter

	ldx	@tmp2+1
	beq	__uput_tail
__uput_blk:
	lda	(@tmp4), y
	jsr	map_proc_always
	sta	(@tmp3), y
	jsr	map_kernel
	iny
	bne	__uput_blk
	inc	@tmp3+1
	inc	@tmp4+1
	dex
	bne	__uput_blk

__uput_tail:
	cpy	@tmp2
	beq	__uget_done
	lda	(@tmp4),y
	jsr	map_proc_always
	sta	(@tmp3),y
	jsr	map_kernel
	iny
	bne	__uput_tail
	beq	__uget_done

#endif

__ugetc:
	jsr	__pop
	sta	@tmp3
	stx	@tmp3+1
	jsr	map_proc_always
	ldy	#0
	lda	(@tmp3),y
	ldx	#0
	jsr	map_kernel
	rts

__ugetw:
	jsr	__pop
	sta	@tmp3
	stx	@tmp3+1
	jsr	map_proc_always
	ldy	#1
	lda	(@tmp3),y
	tax
	dey
	lda	(@tmp3),y
	jmp	map_kernel

__uputc:
	ldy	#3
	lda	(@sp),y
	sta	@tmp3+1
	dey
	lda	(@sp),y
	sta	@tmp3
	dey
	lda	(@sp),y
	tax
	dey
	lda	(@sp),y
	jsr	map_proc_always
	ldy	#0		; Needed ??? Y is 0 before MPA
	sta	(@tmp3),y
	jsr	map_kernel
	tya
	tax
	jmp	__add4sp

__uputw:
	ldy	#3
	lda	(@sp),y
	sta	@tmp3+1
	dey
	lda	(@sp),y
	sta	@tmp3
	dey
	lda	(@sp),y
	tax
	dey
	lda	(@sp),y
	jsr	map_proc_always
	ldy	#0		; Needed ??? Y is 0 before MPA
	sta	(@tmp3),y
	iny
	txa
	sta	(@tmp3),y
	jsr	map_kernel
	lda	#0
	tax
	jmp	__add4sp

#ifdef NO_REU
	.export __uzero

__uzero:
	ldy	#3
	lda	(@sp),y
	dey
	sta	@tmp2+1
	lda	(@sp),y
	dey
	sta	@tmp2
	lda	(@sp),y
	dey
	sta	@tmp3+1
	lda	(@sp),y
	sta	@tmp3

	jsr	map_proc_always

	ldy	#0
	tya

	ldx	@tmp2+1		; more than 256 bytes
	beq	__uzero_tail	; no - just do dribbles
__uzero_blk:
	sta	(@tmp3),y
	iny
	bne	__uzero_blk
	inc	@tmp3+1		; next 256 bytes
	dex			; are we done with whole blocks ?
	bne	__uzero_blk

__uzero_tail:
	cpy	@tmp2
	beq	__uzero_done
	sta	(@tmp3),y
	iny
	bne	__uzero_tail
__uzero_done:
	jsr	map_kernel
	jmp	__add4sp

#endif
