;
;	External buffer support logic
;

	.common

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.export _do_blkzero
	.export _do_blkcopyk
	.export _do_blkcopyul
	.export _do_blkcopyuh

	.export _bsrc
	.export _bdest
	.export _blen

	.export _workbuf

;
;	Ugly - but we need to rework memory management and stuff to fix it
;
_workbuf:
	.ds 1024

_bsrc:
	.word 0
_bdest:
	.word 0
_blen:
	.word 0

_do_blkzero:
	call map_buffers
	push bc
	ld hl,(_bsrc)
	ld d,h
	ld e,l
	inc de
	ld (hl),#0
	ld bc,#511
	ldir
	pop bc
	jp map_kernel

_do_blkcopyk:
	call map_buffers
	push bc
	ld hl,(_bsrc)
	ld de,(_bdest)
	ld bc,(_blen)
	ldir
	pop bc
	jp map_kernel

_do_blkcopyul:
	call map_buf_user
	push bc
	ld hl,(_bsrc)
	ld de,(_bdest)
	ld bc,(_blen)
	ldir
	pop bc
	jp map_kernel

_do_blkcopyuh:
	call map_buf_user_h
	push bc
	ld hl,(_bsrc)
	ld de,(_bdest)
	ld bc,(_blen)
	ldir
	pop bc
	jp map_kernel
