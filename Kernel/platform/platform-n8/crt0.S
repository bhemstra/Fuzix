; 2013-12-18 William R Sowerbutts
#if 0
	.module crt0

	; Ordering of segments for the linker.
	; WRS: Note we list all our segments here, even though
	; we don't use them all, because their ordering is set
	; when they are first seen.
	.area _CODE
	.area _HOME     ; compiler stores __mullong etc in here if you use them
	.area _CODE2
	.area _VIDEO
	.area _CONST
	.area _INITIALIZED
	.area _DATA
	.area _BSEG
	.area _BSS
	.area _HEAP
	; note that areas below here may be overwritten by the heap at runtime, so
	; put initialisation stuff in here
	.area _BUFFERS     ; _BUFFERS grows to consume all before it (up to KERNTOP)
	.area _GSINIT
	.area _GSFINAL
	.area _DISCARD
	.area _FONT
	.area _INITIALIZER
	.area _COMMONMEM

	; imported symbols
	.globl _fuzix_main
	.globl init_early
	.globl init_hardware
	.globl s__INITIALIZER
	.globl s__COMMONMEM
	.globl l__COMMONMEM
	.globl s__DISCARD
	.globl l__DISCARD
	.globl s__DATA
	.globl l__DATA
	.globl s__FONT
	.globl l__FONT
	.globl kstack_top

#endif
	; startup code
	.code
init:
	di
	ld	sp, kstack_top

	; move the common memory where it belongs    
	ld	hl, __bss
	ld	de, __common
	ld	bc, __common_size
	ldir

	ld	de, __commondata
	ld	bc, __commondata_size
	ld	a,b
	or	c
	jr 	z, nocdata
	ldir
nocdata:
#if 0
	; and then the font
	ld de, s__FONT
	ld bc, l__FONT
	ld a,b
	or c
	jr 	z, nofont
	ldir
#endif
nofont:
	; and the discard
	ld	de, __discard
	ld	bc, __discard_size
	ldir

	; then zero the data area
	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, _bss_size - 1
	ld	(hl), 0
	ldir

	; Configure memory map
	call	init_early

	; Hardware setup
	call	init_hardware

	; Call the C main routine
	call	_fuzix_main
    
	; fuzix_main() shouldn't return, but if it does...
	di
stop:   halt
	jr	stop
