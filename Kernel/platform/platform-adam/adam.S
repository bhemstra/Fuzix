;
;	ADAM support
;
;	This is a bit hairy as we've got 32K banks but no single common
;	RAM space.
;
;	The fancier expansion boards used port 0x42 to select between
;	multiple 64K banks of "expansion". We don't deal with this yet.
;	These went up to 2MB
;

        ; exported symbols
        .export init_hardware
        .export _program_vectors
	.export _kernel_flag
	.export _plt_reboot
	.export _int_disabled
	.export _plt_idle

        ; exported debugging tools
        .export _plt_monitor
        .export outchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"


;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.export _bufpool
	.buffers
_bufpool:
	.ds BUFSIZE * NBUFS

; -----------------------------------------------------------------------------
;
;	Because of the weird memory model this is a bit different to the
;	usual Z80 setup.
;
; -----------------------------------------------------------------------------
	.common
_plt_monitor:
	; Reboot ends up back in the monitor
_plt_reboot:
	;; TODO: firmware call
	di
	halt

	.code

_plt_idle:
	halt
	ret

	; Be careful due to bank switching!
	.data

_int_disabled:
	.byte 1

	; At 0x4200 blown away by user

	.discard

init_hardware:
	ld	hl,	128
        ld	(_ramsize), hl
	ld	hl,	96
        ld	(_procmem), hl

	push	af
	call	_vdp_init
	pop	af
	push	af
	call	_vdp_load_font	
	pop	af
	push	af
	call	_vdp_wipe_consoles
	pop	af
	push	af
	call	_vdp_restore_font
	pop	af

	push	af
	call	_vtinit		; init the console video
	pop	af

	im	1	; set Z80 CPU interrupt mode 1
	ret

;
;	This gets a bit weird as we have no true common space
;
	.commondata

_kernel_flag:
	.byte	1	; We start in kernel mode

	.common

_program_vectors:
	; TODO
	ret

;
; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
;
outchar:
	ret

;
;	Adam firmware interface F400-FFFF is the minimal OS segment
;	we keep alive.
;
	.export _getpcb
	.export _getdcb
	.export _lptout
	.export _lptcheck
	.export _keypoll
	.export _keycheck
	.export _readbegin
	.export _readdone
	.export _writebegin
	.export _writedone

_getpcb:
	push	bc
	push	ix
	push	iy
	call	0xFC5A
	push	iy
	pop	hl
	pop	iy
	pop	ix
	pop	bc
	ret

_getdcb:	; z88dk fastcall
	push	bc
	push	ix
	push	iy
	ld	a,l
	call	0xFC5A
	push	iy
	pop	hl
	pop	iy
	pop	ix
	pop	bc
	ret

_lptout:
	pop	de
	pop	hl
	push	hl
	push	de
	ld	a,l	; char
	push	bc
	push	ix
	push	iy
	call	0xFC69F
	pop	iy
	pop	ix
	pop	bc
	ld 	l,a
	ret
_lptcheck:
	push	bc
	push	ix
	push	iy
	call	0xFC42
	pop	iy
	pop	ix
	pop	bc
	ld	l, 0
	jr	nz,lpterr
	ret	c
	inc	l		; 1 not completed
	ret
lpterr:
	dec	l		; -1 error
	ret	

_keypoll:
	push	bc
	push	ix
	push	iy
	call	0xFCA8
	pop	iy
	pop	ix
	pop	bc
	ld 	l,a
	ld	h,0
	ret
_keycheck:
	push	bc
	push	ix
	push	iy
	call	0xFC4B
	pop	iy
	pop	ix
	pop	bc
	ld	hl, -1
	ret	nz
	ld	h,0
	ld	l,a
	ret	c
	ld	l, 0
	ret
_readbegin:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	a,(_andev)
	ld	bc,(_lbahi)
	ld	de,(_lbalo)
	call	0xFCA2
	pop	iy
	pop	ix
	pop	bc
	ld	l,a
	ret	nz
	ld	l, 0
	ret
_readdone:
	ld	a,(_andev)
	push	bc
	push	ix
	push	iy
	call	0xFC45
	pop	iy
	pop	ix
	pop	bc
	ld	hl, 0
	ret	nc
	ld	l, 1
	ret	z
	ld	l,a
	ret	

_writebegin:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	ld	a,(_andev)
	ld	bc,(_lbahi)
	ld	de,(_lbalo)
	call	0xFCAB
	pop	iy
	pop	ix
	pop	bc
	ld	l,a
	ret	nz
	ld	l, 0
	ret
_writedone:
	ld	a,(_andev)
	push	bc
	push	ix
	push	iy
	call	0xFC4E
	pop	iy
	pop	ix
	pop	bc
	ld	hl, 0
	ret	nc
	ld	l, 1
	ret	z
	ld	l,a
	ret	
_reboot:
	; need to reload EOS from ROM first (or just map OS7 and rst 0 ?)
	jp	0xFC30
