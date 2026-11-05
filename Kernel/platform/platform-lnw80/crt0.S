#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.common
;
;	On entry the bootloader has put the banker into the
;	kernel map and loaded us at 0x100 (it's at 0x0)
;
;	We need the loader to have set up CP/M mode and swapped the top
;	and bottom 16K
;
start:
	ld	sp, kstack_top
	ld	a,0x12
	; RAM low, I/O space is RAM
	out	(0x1F),a
	; Zero the BSS
	ld 	hl, __bss
	ld 	de, __bss + 1
	ld 	bc, __bss_size - 1
	ld	(hl), 0
	ldir
	ld	hl, __buffers
	ld	de, __buffers + 1
	ld	bc, __buffers_size - 1
	ld	(hl), 0
	ldir
	call	init_early
	call	init_hardware
	call	_vtinit
	call	_fuzix_main
	di
stop:	halt
	jr	stop

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.buffers

	.export _bufpool
_bufpool:
	.ds	BUFSIZE * NBUFS

