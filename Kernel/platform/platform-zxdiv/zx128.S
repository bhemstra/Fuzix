;
;    ZX Spectrum 128 hardware support
;

        ; exported symbols
        .export init_early
        .export init_hardware
        .export _program_vectors
        .export plt_interrupt_all
	.export _plt_idle

        .export map_kernel
        .export map_buffers
        .export map_proc_always
        .export map_proc
        .export map_kernel_di
        .export map_proc_always_di
        .export map_save_kernel
        .export map_restore
	.export map_proc_save
	.export map_kernel_restore
	.export map_for_swap
	.export current_map
	.export switch_bank

        .export _need_resched
	.export _int_disabled

        ; exported debugging tools
        .export _plt_monitor
	.export _plt_reboot
        .export outchar

	; banking support
	.export __bank_0_1
	.export __bank_0_2
	.export __bank_0_3
	.export __bank_1_2
	.export __bank_1_3
	.export __bank_2_1
	.export __bank_2_3
	.export __bank_3_1
	.export __bank_3_2

	.export __stub_1
	.export __stub_2
	.export __stub_3

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (below 0xC000)
; -----------------------------------------------------------------------------
	.common

_plt_monitor:
	;
	;	Not so much a monitor as wait for space
	;
	ld	a, #0x7F
	in	a, (0xFE)
	rra
	jr	c, _plt_monitor

_plt_reboot:
	di
	im	1
	ld	bc, #0x7ffd
	xor	a		; 128K ROM, initial banks, low screen
	out	(c), a
        rst	0		; Into the ROM

plt_interrupt_all:
        ret

	.commondata

_int_disabled:
	.byte	1

	.code

_plt_idle:
	halt
	ret


; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (above 0xC000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
	.overlay1

;
;	The memory banker will deal with the map setting
;
init_early:
        ret

init_hardware:
        ; set system RAM size
        ld	hl, 128
        ld	(_ramsize), hl
        ld	hl, 128 - 64        ; 64K for kernel/screen/etc
        ld	(_procmem), hl

        ; screen initialization
	push	af
	call	_vtinit
	pop	af

        ret

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.common

_program_vectors:
	ret

	; Swap helper. Map the page in A into the address space such
	; that swap_map() gave the correct pointer to use. Undone by
	; a map_kernel_{restore}
map_for_swap:
        ; bank switching procedure. On entrance:
        ;  A - bank number to set
	push	af
	ld	a, (current_map)
	ld	(ksave_map), a
	pop	af
	; Then fall through to set the bank up

switch_bank:
	; Write the store first, that way any interrupt will restore
	; the new bank and our out will just be a no-op
        ld	(current_map), a
	push	bc
        ld	bc, 0x7ffd
	or	BANK_BITS	   ; Spectrum 48K ROM, Screen in Bank 7
        out	(c), a
	pop	bc
        ret


map_proc:
        ld	a, h
        or	l
        jr	z, map_kernel_nosavea
	push	af
        ld	a, (hl)
	call	switch_bank
	pop	af
	ret

;
;	We always save here so that existing code works until we have a
;	clear usage of save/restore forms across the kernel
;
map_proc_save:
map_proc_always:
map_proc_always_di:
	push	af
	ld	a, (current_map)
	ld	(ksave_map), a
        ld	a, (_udata + U_DATA__U_PAGE)
	call	switch_bank
	pop	af
	ret

;
;	Buffers are always mapped but save the bank to restore
;	when we map the kernel back
;
map_buffers:
	push	af
	ld	a,(current_map)
	ld	(ksave_map), a
	pop	af
	ret

;
;	Save and switch to kernel
;
map_save_kernel:
	push	af
        ld	a, (current_map)
        ld	(map_store), a
	pop af
;
;	This may look odd. However the kernel is banked so any
;	invocation of kernel code in fact runs common code and the
;	common code will bank in the right kernel bits for us when it calls
;	out of common into banked code. We do a restore to handle all the
;	callers who do map_proc_always/map_kernel pairs. Probably we
;	should have some global change to map_proc_save/map_kernel_restore
;
map_kernel_di:
map_kernel:
map_kernel_nosavea:          ; to avoid double reg A saving
map_kernel_restore:
	push	af
	ld	a, (ksave_map)
	call	switch_bank
	pop	af
	ret


map_restore:
	push	af
        ld	a, (map_store)
        call	switch_bank
	pop	af
	ret

;
;	We have no easy serial debug output instead just breakpoint this
;	address when debugging.
;
outchar:
	ld	(_tmpout), a
	push	bc
	push	de
	push	hl
	push	ix
	ld	hl, #1
	push	hl
	ld	hl, _tmpout
	push	hl
	push	af
	call	_vtoutput
	pop 	af
	pop	af
	pop	af
	pop	ix
	pop	hl
	pop	de
	pop	bc
        ret

	.commondata
_tmpout:
	.byte	1

current_map:		; place to store current page number. Is needed
        .byte	0	; because we have no ability to read 7ffd port
			; to detect what page is mapped currently 
map_store:
        .byte	0

ksave_map:
        .byte	0

_need_resched:
        .byte	0

	.common
;
;	Banking helpers
;
;	Logical		Physical
;	0		COMMON (0x4000)
;	1		0
;	2		1
;	3		7
;
;
__bank_0_1:
	xor	a	   ; switch to physical bank 0 (logical 1)
bankina0:
	;
	;	Get the target address first, otherwise we will change
	;	bank and read it from the wrong spot!
	;
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	push	bc
	ld	bc, (current_map)	; get current bank into C
	call	switch_bank	; Move to new bank
	; figure out which bank to map on the return path
	ld	a, c
	pop	bc
	or	a
	jr	z, __retmap1
	dec	a
	jr	z, __retmap2
	jr	__retmap3

callhl:	jp (hl)

__bank_0_2:
	ld	a, 1		; logical 2 -> physical 1
	jr	bankina0
__bank_0_3:
	ld	a, 7		; logical 3 -> physical 7
	jr	bankina0

__bank_1_2:
	ld	a, 1
bankina1:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap1:
	ex	de, hl
	call	callhl		; call the function
	xor	a		; return to bank 1 (physical 0)
	jp	switch_bank
__bank_1_3:
	ld	a, 7
	jr	bankina1

__bank_2_1:
	xor	a
bankina2:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap2:
	ex	de, hl
	call	callhl		; call the function
	ld	a, 1		; return to bank 2
	jp	switch_bank
__bank_2_3:
	ld	a, 7
	jr	bankina2
__bank_3_1:
	xor	a
bankina3:
	pop	hl		; Return address (points to true function address)
	ld	e, (hl)		; DE = function to call
	inc	hl
	ld	d, (hl)
	inc	hl
	push	hl		; Restore corrected return pointer
	call	switch_bank	; Move to new bank
__retmap3:
	ex	de, hl
	call	callhl		; call the function
	ld	a, 7		; return to bank 0
	jp	switch_bank

__bank_3_2:
	ld	a, 1
	jr	bankina3

;
;	Stubs need some stack munging and use DE
;

__stub_1:
	xor	a
__stub_a:
	pop	hl		; the return
	ex	(sp), hl	; write it over the discard
	push	bc
	ld	bc, (current_map)
	call	switch_bank
	ld	a, c
	pop	bc
	or	a
	jr	z, __stub_1_ret
	dec	a
	jr	z, __stub_2_ret
	jr	__stub_3_ret
__stub_2:
	ld	a, 1
	jr	__stub_a
__stub_3:
	ld	a,  7
	jr	__stub_a

__stub_1_ret:
	ex	de, hl
	call	callhl
	xor	a
	call	switch_bank
	pop	de
	push	de		; dummy the caller will discard
	push	de		
	ret
__stub_2_ret:
	ex	de, hl
	call	callhl
	ld	a, 1
	call	switch_bank
	pop	de
	push	de		; dummy the caller will discard
	push	de		
	ret
__stub_3_ret:
	ex	de, hl
	call	callhl
	ld	a, 7
	call	switch_bank
	pop	de
	push	de		; dummy the caller will discard
	push	de		
	ret
