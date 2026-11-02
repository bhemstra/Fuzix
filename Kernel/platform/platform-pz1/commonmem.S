;
;	We keep our common area right down low, with the ZP and stack
;
;
        ; exported symbols
        .export _ub
        .export _udata
        .export kstack_top
        .export istack_top
        .export istack_switched_sp
	.export CTemp

#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

	.commondata
;
;	In 6502 land these are the C stacks, we will need to handle the
;	hardware stack separately, and also to save sp,sp+1 etc on irqs
;
;	Declared as BSS so no non zero bytes here please
;
;	Commondata exists per process in the switched space
;
_ub:    ; first 512 bytes: starts with struct u_block, with the kernel stack working down from above
_udata:
kstack_base:
	.ds	512 - STASHSIZE
kstack_top:

;
;	Finally we tack the ZP save area for interrupts on the end
;
; Swap space for the the C temporaries (FIXME - we stash sp twice right now)
;
CTemp:
	.ds	STASHSIZE

        ; next 256 bytes: 254 byte interrupt stack, then 2 byte saved stack pointer
istack_base:
	.ds	254
istack_top:
istack_switched_sp:
	.word 0
