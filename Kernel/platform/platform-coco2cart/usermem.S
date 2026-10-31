;
;	6809 + Cartridge copy to and from userspace
;	Assumes the irq handler saves/restores cartridge/ram correctly
;	Assumes we never copy to/from ROM space
;

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	; exported
	.export __ugetc
	.export __ugetw
	.export __uget
	.export __uputc
	.export __uputw
	.export __uput
	.export __uzero

	.common

__ugetc:
	tfr	d,x
	jsr	map_proc_always
	ldb	,x
	clra
	jmp	map_kernel

__ugetw:
	tfr	d,x
	jsr	map_proc_always
	ldd	,x
	jmp	map_kernel

__uget:
	pshs	u
	tfr	d,x		; user
	ldu	4,s		; kernel
	ldy	6,s		; count
	jsr	map_proc_always
ugetl:
	lda	,x+
	sta	,u+
	leay	-1,y
	bne	ugetl
	jsr	map_kernel
	clra
	clrb
	puls	u,pc

__uputc:
	ldx	2,s
	jsr	map_proc_always
	stb	,x
	clra
	clrb
	jmp	map_kernel

__uputw:
	ldx	2,s
	jsr	map_proc_always
	std	,x
	clra
	clrb
	jmp	map_kernel

;	X = source, user, size on stack
__uput:
	pshs	u
	tfr	d,x	; kernel
	ldu	4,s	; user address
	ldy	6,s	; count
	jsr	map_proc_always
uputl:
	lda	,x+
	sta	,u+
	leay	-1,y
	bne	uputl
	clra
	clrb
	jsr	map_kernel
	puls	u,pc

; TODO: steal optimization from COCO2
__uzero:
	tfr	d,x
	ldy	2,s
	jsr	map_proc_always
uzloop:
	clr	,x+
	leay	-1,y
	bne	uzloop
	jsr	map_kernel
	clra
	clrb
	rts
