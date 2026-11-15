        ; exported symbols
        .export init_hardware
	.export _program_vectors
	.export map_kernel
	.export map_kernel_restore
	.export map_proc
	.export map_buffers
	.export map_video
	.export map_font
	.export map_kernel_di
	.export map_proc_di
	.export map_proc_always
	.export map_proc_always_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap
	.export plt_interrupt_all
	.export _copy_common
	.export mpgsel_cache
	.export top_bank
	.export _kernel_pages
	.export _plt_reboot
	.export _plt_monitor
	.export _int_disabled
	.export _plt_idle

	; exported debugging tools
	.export outchar

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

        .discard

init_hardware:
        ld	hl, 0
        push	hl
        call	_program_vectors
        pop	hl

	im	1

	ld	a, 1
	out	(0xEE), a		; Vblank on

	ld	a, 0xE1	; 80 column for the moment, text on, remap border, colour
	out	(0xE0),a

	ld	hl, 0x37FF
	ld	(hl), 0

	ld	a, 0x61
	out	(0xE0), a ; Switch to the text mapping

	; Get the internal DI state right
	call	___hard_di
        jp	_init_hardware_c	; pass control to C, which returns for us

;=========================================================================
; Kernel code
;=========================================================================
	.code

_plt_monitor:
_plt_reboot:
	call	_iop_closeall
        di
	halt
	jr	_plt_reboot
_plt_idle:
	halt
	ret

;=========================================================================
; Common Memory (0xF000 upwards)
;=========================================================================
	.common

;=========================================================================

_int_disabled:
	.byte 1

plt_interrupt_all:
	ret

; install interrupt vectors
_program_vectors:
	di
	pop de				; temporarily store return address
	pop hl				; function argument -- base page number
	push hl				; put stack back as it was
	push de

	; At this point the common block has already been copied
	call map_proc

	ld a,0xC3			; JP instruction
	ld (0x0038),a
	ld hl,interrupt_handler
	ld (0x0039),hl

	ld (0x0000),a
	ld hl,null_handler		; to Our Trap Handler
	ld (0x0001),hl

	ld (0x0066),a			; Set vector for NMI
	ld hl,nmi_handler
	ld (0x0067),hl

	jr map_kernel

;=========================================================================
; Memory management
; - kernel pages:     20 - 23
; - common page:      23 (also init top page)
; - user space pages: 24 - 3F
;=========================================================================

;=========================================================================
; map_proc_always - map process pages
; Inputs: page table address in U_DATA__U_PAGE
; Outputs: none; all registers preserved
;=========================================================================
map_proc_always:
map_proc_always_di:
	push hl
	ld hl,_udata + U_DATA__U_PAGE
        jr map_proc_2_pophl_ret

;=========================================================================
; map_proc - map process or kernel pages
; Inputs: page table address in HL, map kernel if HL == 0
; Outputs: none; A and HL destroyed
;=========================================================================
map_proc:
map_proc_di:
	ld a,h
	or l				; HL == 0?
	jr nz,map_proc_2		; HL == 0 - map the kernel

;=========================================================================
; map_kernel - map kernel pages
; Inputs: none
; Outputs: none; all registers preserved
;=========================================================================
map_kernel:
map_kernel_di:
map_kernel_restore:
map_buffers:
	push hl
	ld hl,_kernel_pages
        jr map_proc_2_pophl_ret


;=========================================================================
; map_video - map kernel pages with video hole
; Inputs: none
; Outputs: none; all registers preserved
;=========================================================================
map_video:
	push hl
	ld hl,_video_pages
        jr map_proc_2_pophl_ret

;=========================================================================
; map_font - map kernel pages with font at 4000-7FFF
; Inputs: none
; Outputs: none; all registers preserved
;=========================================================================
map_font:
	push hl
	ld hl,_font_pages
        jr map_proc_2_pophl_ret

;=========================================================================
; map_proc_2 - map process or kernel pages
; Inputs: page table address in HL
; Outputs: none, HL destroyed
;=========================================================================
map_proc_2:
	push de
	push af

	ld de,mpgsel_cache		; paging registers are write only
					; so cache their content in RAM
	ld a,(hl)			; memory page number for bank 0
	ld (de),a
	out (MPGSEL_0),a		; set bank 0
	inc hl
	inc de
	ld a,(hl)			; memory page number for bank 1
	ld (de),a
	out (MPGSEL_1),a		; set bank 1
	inc hl
	inc de
	ld a,(hl)			; memory page number for bank 2
	ld (de),a
	out (MPGSEL_2),a		; set bank 2

	pop af
	pop de
	ret

;=========================================================================
; map_restore - restore a saved page mapping
; Inputs: none
; Outputs: none, all registers preserved
;=========================================================================
map_restore:
	push hl
	push af
	; As well as banking we flip the video page between two
	; segments so need to put it back properly. Do this before
	; we lose data mappings and can't access it
	ld a, (vidpage)
	out (0xE0), a
	pop af
	ld hl,map_savearea
map_proc_2_pophl_ret:
	call map_proc_2
	pop hl
	ret

;=========================================================================
; map_save_kernel - save the current page mapping to map_savearea and
; switch to kernel maps
; Inputs: none
; Outputs: none
;=========================================================================
map_save_kernel:
	push hl
	push af
	in a, (0xE0)
	ld (vidpage), a
	pop af
	ld hl,(mpgsel_cache)
	ld (map_savearea),hl
	ld hl,(mpgsel_cache+2)
	ld (map_savearea+2),hl
	ld hl,_kernel_pages
	call map_proc_2
	; Now the kernel is mapped in save the video bits
	push af
	in a, (0xE0)
	ld (vidpage), a
	pop af
	pop hl
	ret
;=========================================================================
; map_for_swap - map a page into a bank for swap I/O
; Inputs: none
; Outputs: none
;
; The caller will later map_kernel to restore normality
;
; We use 0x4000-0x7FFF so that all the interrupt stuff is mapped.
;
;=========================================================================
map_for_swap:
	ld (mpgsel_cache + 1),a
	out (MPGSEL_1),a
	ret

_copy_common:
	pop hl
	pop de
	push de
	push hl
	push bc
	ld a,e
	call map_for_swap
	ld hl,0xEA00
	ld de,0x2A00
	ld bc,0x1600
	ldir
	pop bc
	jr map_kernel


	.commondata

; MPGSEL registers are write only, so their content is cached here
mpgsel_cache:
	.byte	0x20,0x21,0x22
top_bank:	; the shared tricks code needs this name for cache+3
	.byte	0x23

; kernel page mapping
_kernel_pages:
	.byte	0x20,0x21,0x22,0x23
_video_pages:
	.byte	0x60,0x14,0x22,0x23	/* Text video passthrough, graphics
					   RAM at 0x4000-7FFF */
_font_pages:
	.byte	0x20,0x15,0x22,0x23	/* Font page at 4000-7FFF */

; memory page mapping save area for map_save/map_restore
map_savearea:
	.byte	0,0,0,0

	.data
	; Need to be shared in both kernel and user cases
vidpage:
	.byte	0

	.common
;=========================================================================
; Basic console I/O
;=========================================================================

;=========================================================================
; outchar - Wait for UART TX idle, then print the char in A
; Inputs: A - character to print
; Outputs: none
;=========================================================================
outchar:
	push	af
	push	de
	push	hl
	ld	hl,1
	push	hl
	ld	hl, scratch
	ld	(hl),a
	push	hl
	call	_vtoutput
	pop	af
	pop	af
	pop	hl
	pop	de
	pop	af
	ret

	.data
scratch:
	.byte	0

	.code

	.export	_anykey
	.export	_keyscan
;
;	Test if a key is pressed
;
_anykey:
	push	bc
	ld	bc, 0x00FF
	in	a, (c)
	pop	bc
	cpl
	and	#0x3F
	ld	l,a
	ret

;
;	Scan the key matrix and report if it has changed
;
;	TODO: Debounce
;
_keyscan:
	push	bc
	push	ix
	; Grab the key matrix
	ld	hl, _keyin
	ld	ix, _keymap
	ld	d, 0		; no changes
	ld	bc, 0x7FFF
nextrow:
	in	a, (c)
	cpl
	cp	(ix + 0)
	jr	z, nochange
	inc	d		; can't overflow
nochange:
	ld	(hl), a
	inc	hl
	inc	ix
	rrc	b
	jr	c, nextrow
	pop	ix
	pop	bc
	ld	l,d
	ret

	.export _keyboard
	.export _shiftkeyboard

	.data

_keyboard:
	.ascii 	"2w1q  "
	.ascii	"3esz a"
	.ascii	"5t4rdx"
	.ascii	"6ygvcf"
	.ascii	"8i7uhb"
	.ascii	"9okmnj"
	.ascii 	"-/0pl,"
	.byte	'=', 8, ':', 13, ';', '.'
	; And shifted
_shiftkeyboard:
	.ascii	'"W!Q  '
	.ascii	"#ESZ A"
	.ascii	"%T$RDX"
	.ascii	"&YGVCF"
	.ascii	"(I'UHB"
	.ascii	")OKMNJ"
	.ascii	"_^?PL<"
	.byte	'+', '\', '*', 13, '@', '>'
