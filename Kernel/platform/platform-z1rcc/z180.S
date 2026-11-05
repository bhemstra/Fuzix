#include "../../cpu-z180/z180.S"

	.code
	.export _nap20

	; 18.432MHz so 360 cycles (25 in call/ret sequence)
_nap20:
	ld	b,28
snooze:
	djnz	snooze
	ret

	.common

	.export _ch375_rblock
	.export _ch375_wblock

map:
	ld	bc,0x40BE		; 64 bytes port BE
	ld	a,(_td_raw)
	ret	z
	dec	a
	jp	z,map_proc_always
	ld	a,(_td_page)
	jp	map_for_swap

_ch375_rblock:
	call	map
	inir
	jp	map_kernel
_ch375_wblock:
	call	map
	otir
	jp	map_kernel
