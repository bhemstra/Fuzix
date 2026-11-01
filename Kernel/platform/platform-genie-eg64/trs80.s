# 1 "trs80.S"
;
;	    Genie EG64  hardware support
;

        ; exported symbols
        .export init_early
        .export _program_vectors
	.export plt_interrupt_all

	.export go_fast
	.export go_slow

	.export _int_disabled
	.export _need_resched

	; hard disk helpers
	.export _hd_xfer_in
	.export _hd_xfer_out

        ; exported debugging tools
        .export _plt_monitor
        .export _plt_reboot
        .export outchar
# 1 "kernelu.def"
; UZI mnemonics for memory addresses etc

U_DATA__TOTALSIZE           .equ 0x200        ; 256+256

PROGBASE		    .equ 0x6000
PROGLOAD		    .equ 0x6000

Z80_TYPE		    .equ 1

NBUFS			    .equ 4

Z80_MMU_HOOKS		    .equ 0

CONFIG_SWAP		    .equ 1
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 28 "trs80.S"
; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (0x0000 upwards after the udata etc)
; -----------------------------------------------------------------------------
	.commondata

_int_disabled:
	.byte 1

_need_resched:
	.byte 0

	.common

_plt_monitor:
monitor_spin:
	di
	jr monitor_spin

plt_interrupt_all:
	ret


; -----------------------------------------------------------------------------
; Needs to be higher than the ROM space
; -----------------------------------------------------------------------------

	.code

_plt_reboot:
	di
	ld	sp,0
	xor	a
	out	(0x43),a
	out	(0xC0),a
	rst	0

	.discard

init_early:
	ld	bc,0xC0	; map in the ROM at 0000-3FFF
	out	(c),b
	ld	a,(4)	; identify machine
	out	(c),c	; ROM back out
	cp	0x30
	jr	nz, not_m3
	ld	a,1
	ld	(_trs80_model),a
	ld	a,0x74
	out	(0xE0),a	; Mask iobus, cassette
	xor	a
	out	(0xE4),a	; and NMI sources
	jr	not_vg
not_m3:
	; Detect machine type (Model 1 or LNW80 or VideoGenie ?)
	ld	a,8
	out	(0xFE),a	; turn off ROM on the LNW80
	ld	hl,0
	ld	a,(hl)
	inc	(hl)
	cp	(hl)
	jr	z, not_lnw	; if it's RAM it's an LNW80
	dec	(hl)
	xor	a
	out	(0xFE),a	; ROM back on, normal video mode for now
	ld	a,2		; LNW80
	ld	(_trs80_model), a
	jr	not_vg
not_lnw:
	out	(c),b		; ROM back in
	ld	hl,(0x18F5)
	out	(c),c
	ld	de,0x4E53	; 'SN' for VG, 'L3' for TRS80 Model 1
	or	a
	sbc	hl,de
	jr	nz, not_vg
	ld	a,3
	ld	(_trs80_model),a; Video Genie
not_vg:
	ld bc,	0xC0C0
	out	(c),b		; Back to RAM mapping
        ret


	.common
;
;	TRS80 speed control. Save anything used except AF
;	The LNW80 does automatic slowing on floppy disk access
;	The Model 3 sprinter type card uses port 95 the same way but
;	also does automatic slow down when needed.
;
;	Only allowed to mess with AF
;
go_slow:
	ld	a,(_trs80_model)
	or	a
	ret	z
	xor	a
	out	(254),a
	ret
go_fast:
	ld	a,(_trs80_model)
	or	a
	ret	z
	; A = 0
	inc	a
	out	(254),a
	ret

_program_vectors:
	ret

; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
outchar:
	push	bc
	push	de
	push	hl
	call	map_kernel
	ld	(outtmp),a
	ld	hl,1
	push	hl
	ld	hl,outtmp
	push	hl
	call	_vtoutput
	pop	hl
	pop	hl
	pop	hl
	pop	de
	pop	bc
	ret

outtmp:	.byte 0

;
;	Read I/O memory'
;
	.export _ioread

_ioread:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_io
	ld	l,(hl)
	jp	map_kernel

;
;	Disk transfer helpers.
;
_hd_xfer_in:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	ld	a, (_hd_page)
	or	a
	push	af
	call	nz, map_proc_always
	ld	bc, 0xC8			; 256 bytes from 0xC8
	inir
	pop	af
	pop	bc
	ret	z
	jp	map_kernel

_hd_xfer_out:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	ld	a, (_hd_page)
	or	a
	push	af
	call	nz, map_proc_always
	ld	bc, 0xC8		; 256 bytes to 0xC8
	otir
	pop	af
	pop	bc
	ret	z
	jp	map_kernel

;
;	Keyboard
;
	.export _keyscan
	.export _anykey

_keyscan:
	push	bc
	call	map_io
	ld	b,8
	ld	hl,0x3801
	ld	de,_keyin
scank:
	ld	a,(hl)
	ld	(de),a
	inc	de
	sla	l
	djnz	scank
	pop	bc
	jp	map_kernel

_anykey:
	call	map_io
	ld	a,(0x38FF)
	ld	l,a
	jp	map_kernel

;
;	Display
;
videopos:
	; E = Y D = X, output HL = addr, C preserved
	ld	a,e
	add	a,a	;	x 2 (max 30)
	add	a,a	;	x 4 (max 60)
	add	a,a	;	x 8 (max 120)
	add	a,a	;	x 16 (max 240)
	ld	l,a
	ld	h,0
	add	hl,hl  ;	x 32
	add	hl,hl  ;	x 64
	ld	e,d
	ld	d,0
	add	hl,de	; Now holds the offset
	ld	de,0x3C00
	add	hl,de	; and screen mapped address
	jp	map_io	; map screen

	.export _vt_check_lower
	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_lines
	.export _clear_across
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _vtattr_notify

	.export _video_lower

_vt_check_lower:
	call	map_io
	ld	hl,0x3C00
	ld	a,'a';
	ld	(hl),a
	ld	l,(hl)
	call	map_kernel
	cp	l
	ret	nz		; No lower
	ld	a,1
	ld	(_video_lower),a
	ret

_plot_char:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)
	call	videopos
	ld	a,(_video_lower)
	or	a
	ld	a,c
	jr	nz, has_lower
	cp	96
	jr	c, no_modify
	bit	7,a
	jr	nz, no_modify
	sub	32
no_modify:
has_lower:
	ld	(hl),a
	pop	bc
	jp	map_kernel

_scroll_down:
	push	bc
	ld	hl,0x3FBF	; last line
	ld	de,0x3FFF	; line above
	ld	bc,0x03C0	; all but one line
	call	map_io
	lddr
	pop	bc
	jp	map_kernel

_scroll_up:
	push	bc
	ld	hl,0x3C40
	ld	de,0x3C00
	ld	bc,0x03C0
	call	map_io
	ldir
	pop	bc
	jp	map_kernel

_clear_lines:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)		; Clear D lines from line E
	xor	a
	cp	d		; no work ?
	ret	z
	push	bc
	ld	c,d		; save
	ld	d,a		; clear d
	call	videopos
	ld	a,0x20
wipeo:
	ld	b,0x40
wipe1:
	ld	(hl),a
	inc	hl
	djnz	wipe1
	dec	c
	jr	nz,wipeo
	pop	bc
	jp	map_kernel

_clear_across:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	; DE = coords, A = count
	or	a
	ret	z		; No work
	push	bc
	ld	b,a
	call	videopos
	ld	a,0x20
wipea:
	ld	(hl),a
	inc	hl
	djnz	wipea
	pop	bc
	jp	map_kernel

_cursor_on:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	call	videopos
	ld	a,(hl)
	ld	(cursorpos),hl
	ld	(cursorpeek),a
	ld	(hl),0x8F
	jp	map_kernel

_cursor_off:
	call	map_io
	ld	hl,(cursorpos)
	ld	a,(cursorpeek)
	ld	(hl),a
	jp	map_kernel

_vtattr_notify:
_cursor_disable:
	ret

	.commondata

cursorpos:
	.word	0
cursorpeek:
	.byte	0
_video_lower:
	.byte	0
