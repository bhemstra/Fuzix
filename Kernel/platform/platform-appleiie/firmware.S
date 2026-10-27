;
;	Driver routines for firmware interfaces
;
#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

	.export _pascal_op
	.export _pascal_cmd
	.export _dos_op
;
;	Issue pascal command X to slot A. Note that we don't check for valid
;	firmware here. That was done earlier. If it's not valid we jump to
;	fishkill.
;
;	On entry the C argument (opcode << 8 | slot) is on the C stack, as
;	for every other 6502 asm function called from C.
;
_pascal_op:
	jsr __pop		; C argument into XA
	stx cmdbyte		; patch the operation data following the jsr
	clc
	adc #$C0		; Turn slot into slot address high
	sta @tmp+1		; xxFF holds the index to the DOS entry
	lda #255
	sta @tmp
	ldy #0
	lda (@tmp),y		; index
	clc
	adc #3			; and 3 beyond that (next JMP) is the pascal
	sta @tmp		; one.
	jsr gotmp		; Fake a jsr (@tmp)
cmdbyte:
	.byte $00
	.word _pascal_cmd+1
	rts

gotmp:	jmp (tmp)

;
;	Issue a generic ProDOS command block. Again the C argument (the slot)
;	is on the C stack; it is a char so it occupies one byte and has to be
;	dropped before the tail call into the firmware.
;
_dos_op:
	ldy #0
	lda (@sp),y		; slot argument
	clc
	adc #$C0
	sta @tmp+1
	lda #255
	sta @tmp
	ldy #0
	lda (@tmp),y
	sta @tmp
	inc @sp			; drop the argument
	bne dosop
	inc @sp+1
dosop:	jmp (@tmp)

;
;	The caller loads up to 9 bytes of data into this buffer
;
	.bss
_pascal_cmd:	.ds 9


