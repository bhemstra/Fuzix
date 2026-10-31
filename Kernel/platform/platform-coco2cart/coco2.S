#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	;
	; COCO2 platform
	;

	; exported
	.export map_kernel
	.export map_proc
	.export map_proc_a
	.export map_proc_always
	.export map_save
	.export map_restore
        .export init_early
        .export init_hardware
        .export _program_vectors
	.export _need_resched
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore

	.export _bufpool

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar

	.discard

vectors:
	;
	;	At 0x100 as required by the COCO ROM
	;
	jmp badswi_handler			; 0x100
	jmp badswi_handler			; 0x103
	jmp unix_syscall_entry 			; 0x106
	; FIXME: 109 needs to handle bad NMI!
	jmp badswi_handler			; 0x109
	jmp interrupt_handler			; 0x10C
	jmp firq_handler			; 0x10F
vectors_end:

init_early:
	ldx	#null_handler
	stx	1
	lda	#0x7E
	sta	0
	sta	0x0071		; BASIC cold boot flag (will get trashed by
				; irq stack but hopefully still look bad)
	;
	;	Move the display
	;
	ldx	#0xFFC7
	clr	,x+			; Set F0
	clr	,x++		; Clear F1-F6
	clr	,x++
	clr	,x++
	clr	,x++
	clr	,x++
	clr	,x++
	ldy	#0x0100
	ldx	#vectors
cpvec:
	ldd	,x++
	std	,y++
	cmpx	#vectors_end
	bne	cpvec
	rts

init_hardware:
	ldd	#64
	std	_ramsize
	ldb	#32
	std	_procmem

	; Turn on PIA  CB1 (50Hz or 60Hz interrupt)
	lda	0xFF03
	ora	#1
	sta	0xFF03
	jsr	_vidtxt
	jsr	_vtinit

	; NTSC or PAL/SECAM ?
	ldx	#0
	lda	$ff02
waitvb0:
	lda	$ff03
	bpl	waitvb0		; wait for vsync
	lda	$ff02
waitvb2:
	leax	1,x		; time until vsync starts
	lda	$ff03
	bpl	waitvb2
	stx	_framedet
	rts

	.export _framedet

_framedet:
	.word	0

        .common

_plt_reboot:
	orcc	#0x10
	clr	0xFFBE
	lda	#0x7e
	sta	0x0071		; in case IRQ left it looking valid
	jmp	[0xFFFE]

_plt_monitor:
	orcc	#0x10
	bra	_plt_monitor

___hard_di:
	tfr	cc,b		; return the old irq state
	orcc	#0x10
	rts
___hard_ei:
	andcc	#0xef
	rts

___hard_irqrestore:		; B holds the data
	tfr	b,cc
	rts

;
; COMMON MEMORY PROCEDURES FOLLOW
;

	.common
;
;	Our vectors live in a fixed block and are not banked out. Likewise
;	No memory management for now
;
_program_vectors:
	rts

map_kernel:
	pshs a
	lda #1
	sta romin
map_kr:
	clr $ffde	;	ROM in
	puls a,pc
	
map_proc:
map_proc_always:
map_proc_a:
	clr romin
	clr $ffdf	;	ROM out
	rts

map_restore:
	pshs a
	lda romsave
	sta romin
	bne map_kr
	clr $ffdf
	puls a,pc
	
map_save:
	pshs a
	lda romin
	sta romsave
	puls a,pc

	.code
;
;	Joystick helper
;
;	jsread(buffer)
;
;	Returns a buffer of words in the format
;	right left/right, button
;	right up/down, button
;	left left/right, button
;	left up/down, button
;
	.export _jsread

_jsread:
	; Buffer is in D on entry
	tfr	d,x
	pshs u
	lda #$FF
	sta $FF02		; Keyboard scan lines off
	lda #$08		; Select right joystick
	sta $FF23		; Sound off a moment
	bsr jstwo
	lda #$09
	bsr jstwo
	puls u
	rts
jstwo:
	sta $FF03		; P0 CR B - select joystick L or R
	lda #$04
	sta $FF01		; X
	bsr jsfind
	lda #$0C		; Y
	sta $FF01
	; Fall through
jsfind:
	ldu #jstmp
	; Binary search the joystick DAC position
	lda #$20
	sta ,u		; start in the middle and binary search
jssearch:
	lsr ,u
	beq jsdone
	sta $FF20
	tst $FF20
	bpl jsover
	adda ,u
	bra jssearch
jsover:
	suba ,u
	bra jssearch
jsdone:
	ldb $FF20	; save fire button in bit 0
	std ,x++
	rts

	.data
jstmp:
	.byte 0

	.common
;
;	FIXME:
;
firq_handler:
badswi_handler:
	rti

;
;	debug via printer port
;
outchar:
	sta	0xFF02
	lda	0xFF20
	ora	#0x02
	sta	0xFF20
	anda	#0xFD
	sta	0xFF20
	rts

	.common

_need_resched:
	.byte	0
romin:
	.byte	0
romsave:
	.byte	0

	.buffers
_bufpool:
	.ds	520*5		; initial buffers

