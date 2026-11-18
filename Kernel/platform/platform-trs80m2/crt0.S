;
;	The loaders put the whole image at 0x0100 with page 1 mapped at
;	0x8000, the boot ROM off and interrupts off, and jump to 0x0100.
;
;	The link order (see the Makefile) puts the common memory first,
;	so it starts at 0x0100, then the literals, data, bss in the fixed
;	low 32K, then the code, which runs on into page 1, the buffers and
;	the discard area up to the video memory at 0xF800. As this file is
;	linked first its common part comes first: the jump to the start.
;

#include "kernelu.def"

	.export _discard_size

	.common

start:
	jp	start2

	.discard

start2:
	di
	ld	sp, kstack_top
	; Kernel mapping, video on, real time clock interrupt off for now
	ld	a, M2_VIDEO + M2_KPAGE
	out	(0xFF), a
	; zero the data area
	ld	hl, __bss
	ld	de, __bss + 1
	ld	bc, __bss_size - 1
	ld	(hl), 0
	ldir
	; zero the buffers
	ld	hl, __buffers
	ld	de, __buffers + 1
	ld	bc, __buffers_size - 1
	ld	(hl), 0
	ldir
	; The discard area runs up to the video memory, the loader that
	; sat between them is no longer needed
	ld	hl, 0xF800
	ld	de, __discard
	or	a
	sbc	hl, de
	ld	(_discard_size), hl
	call	init_early
	call	init_hardware
	call	_fuzix_main
	di
stop:	halt
	jr	stop

	.data

_discard_size:
	.word	0
