#include "kernelu.def"

	; Will be at 0x4000
	.discard

init:
	; page in the cartridge with main ram low
	ld	a, 0x1D
	out	(0x7F),a
        di
        ; switch to stack in high memory
        ld	sp, kstack_top

        ld	hl, __bss
        ld	de, __bss + 1
        ld	bc, __bss_size - 1
        ld	(hl), 0
        ldir

        ; Hardware setup
        call	init_hardware
	jp	main

	.code
main:
        ; Call the C main routine
	push	af
        call	_fuzix_main
	pop	af

        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr	stop
