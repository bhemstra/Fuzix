#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

;
;	We are mapped in as a cartridge. ROM0 will be mapped initially
;

	.zp
	.export dirport
	.export mmu

	; 0 and 1 in the ZP are hardware and special so push our main
	; ZP to 2
dirport:
	.byte	0
mmu:
	.byte	0

	.abs
	.org	0x8000

	.word	boot
	.word	boot
	.byte	0xC3, 0xC2, 0xCD, 0x38, 0x30

boot:
	ldx	#255
	txs
	cld
	sei
	sta	0xDEFC		; ensure all 16K mapped, low 16K of cart
	jsr	0xFF87		; set up kernel memory pointers
	jsr	0xFF81		; set up keyboard vector
	jsr	0xFF84		; init devices
	jsr	0xFF8A		; reset vectors
;	lda	0xDE60
;	cmp	#0x49
;	bne	badcart
;	lda	0xDE61
;	cmp	#0x44
;	bne	badcart
;	lda	0xDE62
;	cmp	#0x45
;	bne	badcart

	lda	@mmu
	ora	#7		; CART in both, KERNAL unavoidably at E000
	sta	@mmu
	; Copy bank 0 of the cartridge from A000 to 4000-5FFF (Discard)
	lda	#0x40
	sta	@tmp2+1
	lda	#0xA0
	sta	@tmp1+1
	lda	#0
	sta	@tmp1
	sta	@tmp2
	tay
	ldx	#0x20		; copy 8K
docopy:	lda	(@tmp1),y
	sta	(@tmp2),y
	iny
	bne	docopy
	inc	@tmp1+1
	inc	@tmp2+1
	dex
	bne	docopy
	jmp	bootstrap

badcart:
	; FIXME
	jmp	badcart

	; We copied the stuff into 0x4000-0x5FFF so discard is in place

	.discard
bootstrap:
	lda	0xDD00
	ora	#0x03		; low 16K for VIC
	sta	0xDD00
	lda	#0x13		; Chars 0x0800 video at 0x0400
	sta	0xD018
	lda	#0x1B
	sta	0xD011		; standard character mode
	lda	0xD016
	and	#0xE8
	ora	#0x08
	sta	0xD016
	lda	#0x88		; cart 0x0800+
	sta	@tmp1+1
	lda	#0x08
	sta	@tmp2+1	
	ldx	#0x18		; copy 6K
docopy2:
	lda	(@tmp1),y
	sta	(@tmp2),y
	iny
	bne	docopy2
	inc	@tmp1+1
	inc	@tmp2+1
	dex
	bne	docopy2

	; We now have RAM 0000-1FFF set up and RAM 4000-5FFF
	; Everything is zero fill or on cartridge anyway
	; TODO: zero fill more if needed ?

	; We are currently in discard so we can now page in overlay1
	jsr	bootfinal	; Linker will resolve this as a bank switch
	jmp	x1
	nop
x1:	; Shouldn't get here
	inc	0xD021
	sei
	jmp 	x1


	; Debug helper

	.overlay1
	.byte	0x01
	.overlay2
	.byte	0x02
	.overlay3
	.byte	0x03
	.overlay4
	.byte	0x04
	.overlay5
	.byte	0x05

	.overlay1

bootfinal:

	; Everything should now be in place

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
stop:	jmp	stop

	.common

;
;	Stubs can be shoved anywhere that stays mapped when the
;	kernel is running
;

	.export stub
	.export stub_end
stub:
	.ds 700
stub_end:

