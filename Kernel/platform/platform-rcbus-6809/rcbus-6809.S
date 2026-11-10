	;
	; common RC2014 6809 code
	;

        ; exported symbols
        .export init_early
        .export init_hardware
        .export _program_vectors
	.export _need_resched

	; exported
	.export _bufpool

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.common

vectors:
	.word 0				; reserved
	.word badswi_handler		; SWI3
	.word badswi_handler		; SWI2
	.word firq_handler		; FIR
	.word interrupt_handler		; IRQ
	.word badswi_handler		; SWI
	.word nmi_handler		; NMI
	.word 0				; RESET (never used)

	.buffers
	;
	;	We use the linker to place these just below
	;	the discard area
	;
_bufpool:
	.ds	BUFSIZE*NBUFS

	;	And expose the discard buffer count to C - but in discard
	;	so we can blow it away and precomputed at link time
	;
	;	TODO: this wants to change to blow away anything below
	;	common.
	;
	.discard

init_early:
	rts

init_hardware:
	jsr size_ram
	ldx #$FE60		; 6840 PTM at I/O 0x60
	lda #0x01		; CR1 visible
	sta 1,x			; Enable CR1, set CR2 to be
				; square wave no IRQ, refclk, 16bit
	lda #0x01
	sta ,x			; Reset the chip, CR1 config doesn't matter
				; providing output is disabled
	ldd #CLKVAL
	std 4,x			; Timer 2
	ldd #0x08
	std 6,x			; And divide down further
	clr 1,x			; CR2 square, no IRQ, no out, no input,
				; CR3 accessible, drive output
	lda #0x40		; counter mode, count external clocks off T2
				; IRQ on
	sta ,x

	lda #0x81
	sta 1,x			; Back to CR1
	clr ,x			; out of reset

	ldx #vectors
	ldu #0xFFF0
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x++
	std ,u++
	ldd ,x
	std ,u

	jmp set_vector

        .common

_plt_reboot:
	; TODO
_plt_monitor:
	orcc #0x10
	bra _plt_monitor
___hard_di:
	tfr cc,b		; return the old irq state
	orcc #0x10
	rts
___hard_ei:
	andcc #0xef
	rts
___hard_irqrestore:		; B holds the data
	tfr b,cc
	rts

        .common

;
;	Our vectors are in a single fixed bank so no work is needed. Will
;	change if we move to properly using the paging.
;
_program_vectors:
	tfr	d,x
	lda	,x
	sta	0xFE78		; map low page
	jsr	set_vector
	lda	#0x20
	sta	0xFE78
	rts

set_vector:
	lda	#0x7E
	sta	0
	ldd	#null_handler
	std	1
	rts

;
;	Nothing to do here - we don't use SWI or FIRQ
;
firq_handler:
badswi_handler:
	rti

;
;	debug via serial console port 1
;
outchar:
	ldb $FEC5
	andb #0x20
	beq outchar
	sta $FEC0
	rts

	.commondata

_need_resched:
	.byte 0

