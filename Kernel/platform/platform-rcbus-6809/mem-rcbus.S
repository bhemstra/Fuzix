;
; memory banking for RC2104
;

	; exported
	.export size_ram
	.export map_kernel
	.export map_proc
	.export map_proc_always
	.export map_save
	.export map_restore
	.export map_for_swap

	.export cur_map

	.export __ugetc
	.export __ugetw
	.export __uget
	.export __uputc
	.export __uputw
	.export __uput
	.export __uzero

	.export _copy_common

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.discard

; Sets ramsize, procmem, membanks
size_ram:
	ldd  #512
	std _ramsize
	subd #48	; whatever the kernel occupies (changes when we move
	std _procmem
	rts

	.common

map_proc:
	cmpx	#0
	bne	map_procu
map_kernel:
	pshs	d
	ldd	#0x2021
	std	cur_map
	std	0xFE78
	incb
	stb	cur_map+2
	stb	0xFE7A
	puls	d,pc

map_procu:
	pshs	d
	ldd	,x++
	std	cur_map
	std	$FE78
	ldb	,x
	stb	cur_map+2
	stb	$FE7A
	puls	d,pc

map_proc_always:
	pshs	d
	ldd	_udata + U_DATA__U_PAGE
	std	cur_map
	std	0xFE78
	ldb	_udata + U_DATA__U_PAGE+2
	stb	cur_map+2
	stb	0xFE7A
	puls	d,pc

map_save:
	pshs	d
	ldd	cur_map
	std	saved_map
	ldb	cur_map+2
	stb	saved_map+2
	puls	d,pc

map_restore:
	pshs	d
	ldd	saved_map
	std	cur_map
	std	0xFE78
	ldb	saved_map+2
	stb	cur_map+2
	stb	0xFE7A
	puls	d,pc

map_for_swap:
	sta	cur_map+1
	sta	0xFE79
	rts

_copy_common:
	;	B holds the page to stuff it in, ints are off, and we will
	;	clean up all the maps in the caller later. Will need
	;	review if we allow interrupts during fork copy
	stb	$FE79
	ldx	#__common	; Start of common space to copy
	ldy	-0x8000,x	; we are mapping a Cxxx page at 4xxx
commoncp:
	ldd	,x++
	std	,y++
	cmpx	#$FE00		; I/O window
	beq	skipio
	cmpx	#0		; copy until we did all the vectors
	bne	commoncp
	jmp	map_kernel
skipio:
	leax	0x100,x
	leay	0x100,y
	bra	commoncp

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
	ldu	4,s		; dst
	ldy	6,s		; size
ugetl:
	jsr	map_proc_always
	lda	,x+
	jsr	map_kernel
	sta	,u+
	leay	-1,y
	bne	ugetl
	ldd	#0
	puls	u,pc

__uputc:
	ldx	2,s
	jsr	map_proc_always
	stb	,x
	jsr	map_kernel
	ldd	#0
	rts
__uputw:
	ldx	2,s
	jsr	map_proc_always
	std	,x
	jsr	map_kernel
	ldd	#0
	rts
;
;	Might be worth doing word sized loops for uput/uget ?
;
__uput:
	pshs u
	tfr d,x		; src
	ldu 4,s		; dst
	ldy 6,s		; size
uputl:
	lda ,x+
	jsr map_proc_always
	sta ,u+
	jsr map_kernel
	leay -1,y
	bne uputl
	ldd #0
	puls u,pc

__uzero:
	tfr	d,x
	ldy	2,s
	ldb	3,s		; so we can check if odd byte count
	jsr	map_proc_always
	clra
	lsrb
	bcc	evenc
	sta	,x+
	leay	-1,y
	beq	zdone
evenc:
	clrb
uzloop:
	std	,x++
	leay	-2,y
	bne	uzloop
zdone:
	jsr	map_kernel
	ldd	#0
	rts

	.commondata

cur_map:
	.word	0
	.byte	0
saved_map:
	.word	0
	.byte	0
