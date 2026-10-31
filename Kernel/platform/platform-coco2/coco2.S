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

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore


	.abs
	.org 0x0100
	; This block occupies just under 0x0100 bytes. If you change it you'll
	; need to adjust something to make space!
vectors:
	;
	;	Will end up at 0x100 as required by the COCO ROM
	;
	jmp badswi_handler			; 0x100
	jmp badswi_handler			; 0x103
	jmp unix_syscall_entry 			; 0x106
	; FIXME: 109 needs to handle bad NMI!
	jmp badswi_handler			; 0x109
	jmp interrupt_handler			; 0x10C
	jmp firq_handler			; 0x10F

_plt_reboot:
	orcc #0x10
	clr 0xFFBE
	lda #0x7e
	sta 0x0071		; in case IRQ left it looking valid
	jmp [0xFFFE]

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

;
;	Our vectors live in a fixed block and are not banked out. Likewise
;	No memory management for now
;
_program_vectors:
map_kernel:
map_restore:
map_proc:
map_proc_always:
map_proc_a:
map_save:
	rts
firq_handler:
badswi_handler:
	rti

;
;	debug via printer port
;
outchar:
	sta 0xFF02
	lda 0xFF20
	ora #0x02
	sta 0xFF20
	anda #0xFD
	sta 0xFF20
	rts

;
;	Glenside style IDE block transfer logic
;	Single unified map so trivial
;

	.export _devide_read_data
	.export _devide_write_data

ideprep:
	tfr d,x
	lda #0xFF
	tfr a,dp
	leay 512,x
	sty endp
	rts

_devide_read_data:
	pshs dp
	bsr ideprep
readword:
	; word 1
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 2
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 3
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 4
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 5
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 6
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 7
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 8
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 8
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 9
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 10
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 11
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 12
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 13
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 14
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	; word 15
	lda @IDEDATA
	ldb @IDEDATA_L		; latched
	std ,x++
	cmpx endp
	bne readword
	puls dp,pc

_devide_write_data:
	pshs dp
	bsr ideprep
writeword:
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	ldd ,x++
	stb @IDEDATA_L
	sta @IDEDATA
	cmpx endp
	bne writeword
	puls dp,pc

endp:	.word 0

_need_resched:
	.byte 0

	.export _framedet

	; As the code stands this should be at 0x01FC/0x01FD
_framedet:
	.word	0		; Check this below 0x0200


	.discard

init_early:
	ldx #null_handler
	stx 1
	lda #0x7E
	sta 0
	sta 0x0071		; BASIC cold boot flag (will get trashed by
				; irq stack but hopefully still look bad)
	;
	;	Move the display
	;
	ldx #0xFFC7
	clr ,x+			; Set F0
	clr ,x++		; Clear F1-F6
	clr ,x++
	clr ,x++
	clr ,x++
	clr ,x++
	clr ,x++
	rts

init_hardware:
	ldd #64
	std _ramsize
	ldd #25
	std _procmem

	; Turn on PIA  CB1 (50Hz interrupt)
	lda 0xFF03
	ora #1
	sta 0xFF03
	jsr _vtinit

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
