#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

	.code		; CHECK

	.byte 0x02
	.byte 0x65

entry:
;
;	We are entered at 0xC002 just after the required magic number
;
	sei			; interrupts off
	cld			; decimal off
	ldx	#0xFF
	txs			; Stack (6502 not C)

	lda	#<kstack_top	; C stack
	sta	@sp
	lda	#>kstack_top
	sta	@sp+1 

	lda	#<_udata
	sta	@tmp
	lda	#>_udata
	sta	@tmp+1

	lda	#0
	tay
	ldx	#2
wipeud:
	sta	(@tmp),y
	iny
	bne	wipeud
	inc	@tmp+1
	dex
	bne	wipeud

	lda	#<__bss
	sta	@tmp
	lda	#>__bss
	sta	@tmp+1

	lda	#0
	tay
	ldx	#>__bss_size
	beq	bss_wipe_tail
bss_wiper_1:
	sta	(@tmp),y
	iny
	bne	bss_wiper_1
	inc	@tmp+1
	dex
	bne	bss_wiper_1
bss_wipe_tail:
	cpy	#<__bss_size
	beq	gogogo
	sta	(@tmp),y
	iny
	bne	bss_wipe_tail

gogogo:
	jsr	init_early
	jsr	init_hardware
	jsr	_fuzix_main	; Should never return
	sei			; Spin
stop:	jmp stop

	.abs
	.org	0xFFFA

	.word	vector
	.word	entry		; does it matter ???
	.word	nmi_handler
