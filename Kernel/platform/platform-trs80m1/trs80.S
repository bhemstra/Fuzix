;
;	TRS 80  hardware support
;

	; exported symbols
	.export init_early
	.export _program_vectors
	.export plt_interrupt_all

	.export go_fast
	.export go_slow

	.export _int_disabled

	; hard disk helpers
	.export _hd_xfer_in
	.export _hd_xfer_out

	.export _halt

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (0x4000 upwards after the udata etc)
; -----------------------------------------------------------------------------
	.commondata
;
;	This is linked first after udata and boot, and we turn the boot area
;	into the istack. Don't screw around with the link order!
;
istack_top:
istack_switched_sp:
	.word	0

	.common

_plt_monitor:
	push	af
	call	_vtflush		; get any panic onscreen
	pop	af
monitor_spin:
	di
	jr	monitor_spin

plt_interrupt_all:
	ret

_plt_reboot:
	di
	ld	sp,0xffff
	xor	a
	out	(0x43),a
	rst	0

_int_disabled:
	.byte 1

; -----------------------------------------------------------------------------
; BOOT MEMORY BANK (below 0x8000)
; -----------------------------------------------------------------------------

	.common	

init_early:
	call	mapper_init	; A is the mapper type passed from crt0.s
	ld	a,(4)
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
	ld	hl,(0x18F5)
	ld	de,0x4E53	; 'SN' for VG, 'L3' for TRS80 Model 1
	or	a
	sbc	hl,de
	jr	nz, not_vg
	ld	a,3
	ld	(_trs80_model),a	; Video Genie
not_vg:
	jp	_rom_vectors

_halt:
	halt
	ret

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

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
	jr	nz, snot_model_1
	; A = 0
	out	(254),a
	ret
snot_model_1:
	cp	1		; model III ?
	ret	nz
	xor	a
	out	(95),a
	ret
go_fast:
	ld	a,(_trs80_model)
	or	a
	jr	nz,fnot_model_1
	; A = 0
	inc	a
	out	(254),a
	ret
fnot_model_1:
	cp	1
	ret	nz
	; A = 1
	out	(95),a
	ret

_program_vectors:
	ret

_rom_vectors:
	ld	a,0xC3
	ld	(0x4012), a
	ld	hl, interrupt_handler
	ld	(0x4013), hl

	; Model III only but just writing it does no harm
	ld	hl,	fd_nmi_handler
	ld	(0x404A), hl
	jp	map_kernel
	
; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
; FIXME: need to do different things for Video Genie and Model III
outchar:
	; xtrs debug trick only
	ld	(0x37E8), a
	ret

;
;	Swap helpers.
;	We have our buffers mapped in Bank 2. We are in common memory
;	and thge map_buffers will if needed ensure we have the right bank
;	mapped
;

hd_prep_xfer:
	ld	hl, 8
	add	hl,sp
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	bc, 0xC8		; 256 bytes from 0xC8
	ld	a, (_hd_page)
	or	a
	jp	z, map_buffers
	jp	map_proc_a

_hd_xfer_in:
	push	bc
	call	hd_prep_xfer
	inir
	pop	bc
	jp	map_kernel_restore

_hd_xfer_out:
	push	bc
	call	hd_prep_xfer
	otir
	pop	bc
	jp	map_kernel_restore



;
;	Storage for buffers. Is actually banked with overlay2
;
	.buffers

	.export _bufdata
	.export _bufdata_end
_bufdata:
	.ds 512 * 5
_bufdata_end:

