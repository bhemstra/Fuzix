# 1 "trs80-bank.S"
;
;	    Banking logic for the EG64 board
;

        ; exported symbols
        .export init_early
        .export init_hardware
	.export _plt_reboot
	.export map_kernel
	.export map_kernel_di
	.export map_kernel_restore
	.export map_buffers
	.export map_proc
	.export map_proc_di
	.export map_proc_always
	.export map_proc_always_di
	.export map_proc_noio
	.export map_for_swap
	.export map_save_kernel
	.export map_restore
	.export map_io
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
 
# 26 "trs80-bank.S"
	.code
;
;	Needs to be outside of the ROM range
;
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

;
;	These live below 0x8000 so they are not switched out
;
	.common

init_hardware:
	; write zeroes across all vectors
        ld	hl, 0
        ld	de, 1
        ld	bc, 0x007f ; program first 0x80 bytes only
        ld	(hl), 0x00
        ldir

        ; now install the interrupt vector at 0x0038
        ld	a, 0xC3 ; JP instruction
        ld	(0x0038), a
        ld	hl, interrupt_handler
        ld	(0x0039), hl

        ; Set vector for jump to NULL
        ld	(0x0000), a
        ld	hl, null_handler  ;   to Our Trap Handler
        ld	(0x0001), hl

        ld	(0x0066), a  ; Set vector for NMI
        ld	hl, nmi_handler
        ld	(0x0067), hl

	ld	hl,96
	ld	(_ramsize),hl
	ld	hl,40
	ld	(_procmem),hl
        im	1 ; set CPU interrupt mode

	jp	_vt_check_lower
;
;	Mapping for us is fairly simple but it's not blank because we do
;	some mapping.
;
map_buffers:
map_kernel:
map_kernel_di:
map_kernel_restore:
	push	af
	ld	a,0xE0		; Internal memory, ROM unmapped, IO unmapped
	ld	(map_state),a
	out	(0xC0),a
	pop	af
	ret
map_proc:
map_proc_di:
map_for_swap:
map_proc_always:
map_proc_always_di:
	push af
	ld	a,0xD0		; External memory, ROM unmapped, IO mapped
	ld	(map_state),a	; (so we can do screen mapping)
	out	(0xC0),a
	pop	af
	ret
; Used for user-kernel copies only (see tricks.S)
map_proc_noio:
	push	af
	ld	a,0xF0		; External memory, ROM unmapped, IO unmapped
	ld	(map_state),a
	out	(0xC0),a
	pop	af
	ret
map_save_kernel:
	push	af
	ld	a,(map_state)
	ld	(map_save_val),a
	ld	a,0xE0		; Internal memory, ROM unmapped, IO unmapped
	ld	(map_state),a
	out	(0xC0),a
	pop	af
	ret
map_restore:
	push	af
	ld	a,(map_save_val)
	ld	(map_state),a
	out	(0xC0),a
	pop	af
	ret

map_io:
	ld	a,0xC0		; Internal memory, ROM unmapped, IO mapped
	ld	(map_state),a
	out	(0xC0),a
	ret

map_state:
	.byte 0
map_save_val:
	.byte 0
