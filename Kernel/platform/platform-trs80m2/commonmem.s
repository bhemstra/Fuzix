;
;	The udata, kernel and interrupt stacks live in the fixed low 32K
;
        .module commonmem

        .area _COMMONMEM

	.include "../../cpu-z80/std-commonmem.s"
