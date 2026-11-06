
	.export _devide_read_data
	.export _devide_write_data

	.common

#include "../../build/kernelu.def"

#define IDE_REG_DATA	0xA3

ide_setup:
#ifdef BANKED_Z80
	ld	hl,8
#else
	ld	hl,6
#endif
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	bc, IDE_REG_DATA		; port and count
	;	Touching the DivIDE control register during a transfer
	;	messes up the odd/even latching
	di
	ld 	a, 0x05
	out	(0xfe), a
	ld	a, (_td_raw)
	or	a
	jp	z, map_buffers
	dec	a
	jp	z, map_proc_always
	ld	a, (_td_page)
	jp	map_for_swap

_devide_read_data:
	push	bc
	call	ide_setup
	inir                                    ; transfer first 256 bytes
	ld 	a,0x02
	out	(0xfe),a
	inir                                    ; transfer second 256 bytes
out:
	ld 	a, (_vtborder)
	out	(0xfe), a
	ld	a,(_int_disabled)
	or	a
	jr	nz, no_ei
	ei
no_ei:
	pop	bc
	jp	map_kernel_restore

_devide_write_data:
	push	bc
	call	ide_setup
	otir                                    ; transfer first 256 bytes
	ld 	a,0x02
	out	(0xfe),a
	otir                                    ; transfer second 256 bytes
	jr	out
