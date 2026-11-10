	.export _devide_read_data
	.export _devide_write_data

#define IDE_REG_DATA	0x58

	.common

idesetup:
	ld	hl, 8
	add	hl, sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ld	a, (_td_raw)
	ld	bc, IDE_REG_DATA	; setup port number
					; and count
	or	a
	jp	z, map_buffers
	dec	a
	jp	z, map_proc_always
	ld	a, (_td_page)
	jp	map_for_swap

_devide_read_data:
	push	bc
	inir
	inir
	jp	map_kernel_restore	; map kernel then return

_devide_write_data:
	push	bc
	inir
	inir
	jp	map_kernel_restore	; map kernel then return
