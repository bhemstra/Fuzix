; startup code
;

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.abs
	.org	0

	jp	null_handler		; 0x00
	.ds	5
	jp	null_handler		; 0x08
	.ds	5
	jp	null_handler		; 0x10
	.ds	5
	jp	null_handler		; 0x18
	.ds	5
	jp	null_handler		; 0x20
	.ds	5
	jp	null_handler		; 0x28
	.ds	5
	jp	null_handler		; 0x30
	.ds	5
	jp	interrupt_handler	; 0x38
	.ds	5

	.org	0x66
	jp	nmi_handler

	;
        ; startup code. Called with most stuff indeterminate but overlay 1
        ; mapped. On entry A is the machine type.
	; A = 0		DivIDE plus
	; A = 1		ZXCF 512K+ (we need to do sizing later)
	;

	.overlay1

	.export _go	; should be at 0xC000

_go:

        di

	;  We need to wipe the BSS but the rest of the job is done.

	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, __bss_size - 1
	ld	(hl), 0
	ldir

	; Debug trace on
	ld	bc,0x50FD
	out	(c),b

        ld	sp, kstack_top

        ; Configure memory map
	push	af
        call	init_early
	pop	af

        ; Hardware setup
	push	af
        call	init_hardware
	pop	af

        ; Call the C main routine
	push	af
        call	_fuzix_main
	pop	af
    
        ; main shouldn't return, but if it does...
        di
stop:   halt
        jr	stop

	.common

	.export stub
	.export stub_end
stub:
	.ds	560
stub_end:

	; Boot marker at 0x2200

	.commondata
	.export _marker
_marker:
	.byte 'Z'		; marker
	.byte 'B'
	.word _go		; boot addresss

stubs:
	.ds 640

	.buffers

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.export _bufpool

_bufpool:
	.ds BUFSIZE * NBUFS
