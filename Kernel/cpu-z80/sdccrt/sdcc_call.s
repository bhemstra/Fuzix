;
;	Indirect call helpers used by SDCC generated code
;
	.module sdcc_call
	.area	_CODE

	.globl	___sdcc_call_hl
	.globl	___sdcc_call_iy

___sdcc_call_hl:
	jp	(hl)

___sdcc_call_iy:
	jp	(iy)
