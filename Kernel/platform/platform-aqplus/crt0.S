#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

        ; startup code

	.abs

	.org	0x100

init:                       ; must be at 0x0100 as we are loaded at that
	di

	; Drop the final block into place
	ld	a,0x23
	out	(0xF3),a

	ld	sp, kstack_top

	; Clear the BSS

	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, __bss_size - 1
	ld	(hl), 0
	ldir
	; Zero buffers area
;	ld	hl, __buffers
;	ld	de, __buffers + 1
;	ld	bc, __buffers_size - 1
;	ld	(hl), 0
;	ldir

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr stop

	.buffers
;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.export _bufpool

_bufpool:
	.ds BUFSIZE * NBUFS
