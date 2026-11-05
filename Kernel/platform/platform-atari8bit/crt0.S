#include "kernel.def"
#include "../../cpu-6502/kernel02.def"
;
;	We kick off in discard as we know where it is anyway.
;
	.discard
	.export copy16k
;
;	We loaded the low 8K block from cartridge and ran it. NMI is off
;	stack is sane, interrupts are off, not much else is defined.
;
go:
	lda	#0x80
	sta	0x8002

	lda	#0x00
	sta	0xD400
	lda	#<dlist8
	sta	0xD402
	lda	#>dlist8
	sta	0xD403
	lda	#0x22
	sta	0xD400

	ldx	#0xF6
	sta	CARTPORT,x	; select bank 1
	lda	#0x20
	sta	@tmp2+1		; Copy 2000-3FFF out of bank 1

	jsr	romtobank

	lda	#MAIN
	sta	PORTB

	lda	#0x80
	sta	0x8003
	;	Copy from cartridge bank 2 and 3 into 4000-7FFF main RAM
	ldx	#0xF5
	jsr	copy16k


	lda	#0x80
	sta	0x8004

	;	Copy from cartridge bank 4 and 5 into 4000-7FFF ext bank 0
	lda	#EXT0
	sta	PORTB		; bank in at 4000-7FFF


	ldx	#0xF3		; cart bank
	jsr	copy16k


	lda	#0x80
	sta	0x8005

	;	Copy from cartridge bank 6 and 7 into 4000-7FFF ext bank 1
	lda	#EXT1
	sta	PORTB		; bank in at 4000-7FFF
	ldx	#0xF1		; cart bank
	jsr	copy16k

	lda	#0x80
	sta	0x8006

	;	Copy from cartridge bank 8 and 9 into 4000-7FFF ext bank 2
	lda	#EXT2
	sta	PORTB		; bank in at 4000-7FFF
	ldx	#0xE7		; cart bank
	jsr	copy16k


	lda	#0x80
	sta	0x8007

	; 	Ext bank 3 is user space so we don't need to worry
	;	We now have all the 4000-7FFF including the extra banks

	;	Back to main memory mapped
	lda	#MAIN
	sta	PORTB


	.export mark
mark:
	;	Switch to final display
	lda	#0x00
	sta	0xD400
	;	And our fonts
	lda	#0x40		; 0x4000 - 53FF
	sta	0xD409
	lda	#<dlist
	sta	0xD402
	lda	#>dlist
	sta	0xD403
	lda	#0x22
	sta	0xD400


	;	Now we do the upper memory (10 and 11)
	sta	CARTPORT+0xE5
	lda	#0xC0
	sta	@tmp2+1
	ldx	#16		; C000-CFFF (4K)
	jsr	romtosect

	lda	#0x80
	sta	0x4427


	lda	#0xD8		; Skip the I/O (2K)
	sta	@tmp2+1
	lda	#0xB8
	sta	@tmp+1
	ldx	#8		; Places us at E000
	jsr	romblock

	lda	#0x80
	sta	0x4426

	lda	CARTPORT+0xE4	; Final 8K from bank 11
	lda	#0xE0
	sta	@tmp2+1
	jsr	romtobank

	lda	#0x80
	sta	0x4425

	lda	CARTPORT+0xE3
	; Set the cartridge to the live kernel A000-BFFF

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

copy16k:
	txa
	pha
	sta	CARTPORT,x
	jsr	romtoext
	pla
	tax
	dex
	sta	CARTPORT,x
	bne	romtobank
;	set @tmp2 to the address to copy
romtoext:
	lda	#0x40
	sta	@tmp2+1
romtobank:
	ldx	#32
romtosect:
	lda	#0xA0		; ROM start
	sta	@tmp+1
romblock:
	lda	#0
	sta	@tmp
	sta	@tmp2
	tay
copy:
	lda	(@tmp),y
	sta	(@tmp2),y
	iny
	bne	copy
	inc	@tmp+1
	inc	@tmp2+1
	dex
	bne	copy
	rts

vectors:
	; To copy into place TODO
	.word	vector
	.word	_plt_reboot		; does it matter ???
	.word	nmi_handler

	; scratch dlist as we will map out the cart version
	; wasteful but we have tons of discard space so who cares
dlist8:
	.byte	0x70,0x70,0x70,0x70
	.byte	0x42
	.word	0x8000
	; Render 24 lines
	.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
	.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
	.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
	; Wait for vblank and return
	.byte	0x41
	.word	dlist8

	.data

;
;	We can put the stubs anywhere always mapped by the kernel
;	For the moment shove it with the data but it can go with
;	code too or shared depending where there is space
;

	.export stub
	.export stub_end
stub:
	.ds 600
stub_end:
;
;	Overlay specific init. Land a marker byte in each bank for
;	debugging. Maybe evetually for switching - but better it's at
;	7FFF
;
	.overlay1
	.byte	0x92
	.overlay2
	.byte	0x96
	.overlay3
	.byte	0x9A
	.overlay4
	; Overlay 4 is the main bank but the first chunk of it is
	; the buffers area (screen, disk buffers, dlist etc)

	; The font has already been loaded here for 1024 bytes by
	; the linker
	; Now allow for the screen
	.ds	8192
	; Now allow for the disk buffers
	.ds	512 * NBUFS
	; Actual overlay4 code will follow

;
;	Describe the layout of the main chunk of overlay4 in buffers. If
;	we reference it via overlay4 then the linker will generate stubs
;	for the data which we don't want. The two should match exactly
;
	.buffers

	.export _bufdata
	; Font comes first (1K then)
	.ds	1024
	; 0x4400

	.export	screen
screen:
	.ds	8192
_bufdata:
	.ds	512 * NBUFS


	.commondata

	; Ensure always mapped

dlist:	.byte	0x70,0x70,0x70
	; 24 blank lines then set the start
	.byte	0x42
	.word	screen
	; Render 24 lines
	.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
	.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
	.byte	0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02
	; Wait for vblank and return
	.byte	0x41
	.word	dlist
