#include "kernel.def"
#include "../../cpu-z8/kernel-z8.def"

; FIXME: helpers can't use __cleanupnn if they didn't move ret from cpu
; stack!

	.common

	.export _plt_reboot
	.export _plt_monitor

_plt_reboot:
_plt_monitor:
	idle
	jmp _plt_monitor

	.export plt_interrupt_all

plt_interrupt_all:
	rets

; Hack until we get ZP working properly as register maps

	.abs

	.export _int_disabled
	.export _mem_bank
	.export istack_switched_sp

	.org 0x10
_int_disabled:
	.byte 0
_mem_bank:
	.byte 0
_mem_saved_bank:
	.byte 0
istack_switched_sp:
	.word 0

	.code

	.export init_early
	.export init_hardware

init_early:
	rets

init_hardware:
	movd	%_ramsize+1,r13
	clr	a
	sta	*r13
	decd	r13
	mov	%2,a		; 512K
	sta	*r13
	movd	%_procmem+1,r13
	mov	%136,a
	sta	*r13
	decd	r13
	mov	%1,a
	sta	*r13
	; TODO timers etc
	rets

	.common

	.export _program_vectors

_program_vectors:
	; TODO need to fill in the high memory table ?
	rets

	.export map_proc
	.export map_proc_always
	.export map_proc_always_di
	.export map_proc_a
	.export map_kernel
	.export map_kernel_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap

map_restore:
;TODO	movp	_mem_saved_bank,0x06		; set the port B bits for the bank select
	rets
map_save_kernel:
;TODO	movp	0x06,_mem_saved_bank		; save the old B bits
map_kernel:
map_kernel_di:
;TODO	clrp	0x06				; switch to bank 0
	rets

map_proc:
map_proc_di:
	mov	r12,a
	or	r13,a
	jz	map_kernel
	; r12/r13 points to the memory to map
	lda	*r13
;TODO	movp	a,0x06				; set port B
	rets

map_for_swap:
map_proc_a:
;TODO	movp	a,_0x06				; set port B
	rets

map_proc_always:
map_proc_always_di:
	push	a
	push	r12
	push	r13
	movd	%U_DATA__U_PAGE+1,r13		; big endian
	lda	*r13
	movp	a,p6				; load port B
	pop	r13
	pop	r12
	pop	a
	rets

	.export outchar

	; Should use bit tests but to work properly we want to go IRQ
	; anyway
outchar:
	btjzp	%0x1,p17,outchar	; P17 uart status wait for ready to write
	movp  a,p23
	rets

;
;	Console - hack with polling for now
;
	.export _tmstty_get
_tmstty_get:
	btjop	%0x1,p0xC5,has_ch
	movd	%0xFFFF,r5
	rets
has_ch:
	movp	p0xC0,b
	mov	b,r5
	clr	r4
	rets

	.export _tmstty_put
_tmstty_put:
	pop	a
	pop	b
	clr	r11
	trap	10
	mov	%2,r1
	call	@__gargr2
	mov	r5,b
	movp	b,p0xC0
	br	@__cleanup_1

	.export _tmstty_status
_tmstty_status:
	movp	p0xC5,b
	and	%0x20,b
	mov	b,r5
	clr	r4
	rets

	.export _devide_read_data
	.export _devide_write_data

map_io:
	movd	%_td_raw,r11
	lda	*r11
	jz	iskern
	dec	a
	jz	map_proc_always
	; swap
	movd	%_td_page,r11
	lda	*r11
	movp	a,p6		; set bank register to the swap page
iskern:
	rets

_devide_read_data:
	pop	a
	pop	b
	clr	r11
	trap	10
	clr	r13
	call	@__gargr2	; r4/r5 is the pointer
	call	@map_io
	clr	b
	movd	%0xFE10,r13	; IDE data
rsec:
	lda	*r13
	sta	*r5
	add	%1,r5
	adc	%0,r4
	lda	*r13
	sta	*r5
	add	%1,r5
	adc	%0,r4
	djnz	b,rsec
	call	@map_kernel
	br	@__cleanup_2

_devide_write_data:
	pop	a
	pop	b
	clr	r11
	trap	10
	clr	r13
	call	@__gargr2
	call	@map_io
wsec:
	lda	*r5
	sta	*r13
	add	%1,r5
	adc	%0,r4
	lda	*r5
	sta	*r13
	add	%1,r5
	adc	%0,r4
	djnz	b,wsec
	call	@map_kernel
	br	@__cleanup_2	; FIXME (also fix in lowlevel-)
