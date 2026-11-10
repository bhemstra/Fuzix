# 1 "crt0.S"
# 1 "kernelu.def"
; FUZIX mnemonics for memory addresses etc

U_DATA__TOTALSIZE	.equ	0x200	; 256+256 bytes @ 0x0100



PROGBASE		.equ	0x4000
PROGLOAD		.equ	0x4000

; Force any reti to go via higher memory where it is seen by the CPU
# 59 "crt0.S"
	; Starts at 0x4000

	.code
init:  
        di
	xor	a
	ld	sp, kstack_top

	out	(6), a		; C000-E7FF RAM off for now TODO
	out	(0xFF), a	; Get into a known state

	; Clear the screen
	ld	a, 0x10
	out	(0x88), a
	ld	hl, 0xE800
	ld	de, 0xE801
	ld	bc, 0x03BF
	ld	(hl), 0x02
	ldir
	ld	hl, 0xEC00
	ld	de, 0xEC01
	ld	bc, 0x03BF
	ld	(hl), ' '
	ldir

	ld	a, 0xC7
	out	(0x83), a
	ld	a, 0x08		;	8 / second
	out	(0x83), a
	ld	a, 0xFB
	ld	(0xEFF8), a
	ld	hl, 0x4DED	;	jp 0xEFF9 
	ld	(0xEFF9), hl

        ; Hardware setup
        call	init_hardware

        ; Call the C main routine
        call	_fuzix_main
    
        ; fuzix_main() shouldn't return, but if it does...
        di
stop:   halt
        jr stop

	.literal

	.export	stub
	.export	stub_end
stub:
	.ds	600
stub_end:
