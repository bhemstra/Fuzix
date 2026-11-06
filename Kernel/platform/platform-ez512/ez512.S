;
;	 EZ512 support
;
;	This first chunk is mostly boilerplate to adjust for each
;	system.
;

	.export init_early
	.export init_hardware
	.export _program_vectors
	.export map_buffers
	.export map_kernel
	.export map_kernel_di
	.export map_kernel_restore
	.export map_proc
	.export map_proc_a
	.export map_proc_always
	.export map_proc_always_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap
	.export plt_interrupt_all
	.export _kernel_flag
	.export _int_disabled

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

;
;	KIO has the SIO part at 0x08
;
SIOA_D	.equ	0x08
SIOA_C	.equ	0x09
SIOB_D	.equ	0x0A
SIOB_C	.equ	0x0B

CTC_CH0	.equ	0x04	; CTC channel 0 and interrupt vector
CTC_CH1	.equ	0x05	; CTC channel 1 (serial B)
CTC_CH2	.equ	0x06	; CTC channel 2 (timer)
CTC_CH3	.equ	0x07	; CTC channel 3 (timer count)

KIO_C	.equ	0x0C	; KIO additional PIO port C

;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.buffers

	.export _bufpool

_bufpool:
	.ds BUFSIZE * NBUFS

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (kept even when we task switch)
; -----------------------------------------------------------------------------
	.common
;
;	Interrupt flag. This needs to be in common memory for most memory
;	models. It starts as 1 as interrupts start off.
;
_int_disabled:
	.byte	1
;
;	This method is invoked early in interrupt handling before any
;	complex handling is done. It's useful on a few platforms but
;	generally a ret is all that is needed
;
plt_interrupt_all:
	ret

;
;	If you have a ROM monitor you can get back to then do so, if not
;	fall into reboot.
;
_plt_monitor:
;
;	Reboot the system if possible, halt if not. On a system where the
;	ROM promptly wipes the display you may want to delay or wait for
;	a keypress here (just remember you may be interrupts off, no kernel
;	mapped so hit the hardware).
;
_plt_reboot:
	di
	ld	a, 0x43
	out	(CTC_CH0), a
	out	(CTC_CH1), a
	out	(CTC_CH2), a
	out	(CTC_CH3), a
	ld	hl, 0x0CD3
	ld	a, 0x00
	di
	ld	sp,0xFFFF
	;	Will execute out (0x0C), a and fall into address 0
	ld	(0xFFFE), hl
	jp	0xFFFE

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (may be below 0x8000, only accessible when the kernel is
; mapped)
; -----------------------------------------------------------------------------
	.code
;
;	This routine is called very early, before the boot code shuffles
;	things into place.
;
init_early:
	ret

	.export	_plt_idle

_plt_idle:
	halt
	ret

; -----------------------------------------------------------------------------
; DISCARD is memory that will be recycled when we exec init
; -----------------------------------------------------------------------------
	.discard
;
;	After the kernel has shuffled things into place this code is run.
;	It's the best place to breakpoint or trace if you are not sure your
;	kernel is loading and putting itself into place properly.
;
;	It's required jobs are to set up the vectors, ramsize (total RAM),
;	and procmem (total memory free to processs), as well as setting the
;	interrupt mode but *not* enabling interrupts. Many platforms also
;	program up support hardware like PIO and CTC devices here.
;
init_hardware:
	ld	hl, 512			; 512K total
	ld	(_ramsize), hl
	ld	de, 64			; 64K for the kernel bank
	or	a
	sbc	hl,de
	ld	(_procmem), hl

	; set up interrupt vectors for the kernel
	ld	hl, 0
	push	hl
	call	_program_vectors
	pop	hl

	;
	; Defense in depth - shut everything up first
	;

	ld	a, 0x43
	out	(CTC_CH0), a		; set CH0 mode
	out	(CTC_CH1), a		; set CH1 mode
	out	(CTC_CH2), a		; set CH2 mode
	out	(CTC_CH3), a		; set CH3 mode

	ld	a, 0x80
	out	(CTC_CH0), a		; IRQ vector 0x80
	;
	;	CTC 1 is driven by the 1.8432MHz clock but that's not
	;	actually useful. The CPU clock is 22MHz so it's better
	;	to scale that down

	ld a, 0xB5
	out (CTC_CH2),a			; counter mode no interrupt
					; time constant control word
	ld a, 214			; divide by 14
	out (CTC_CH2),a			; 400Hz

	ld hl, sio_setup
	ld bc, 0xA00 + SIOA_C		; 10 bytes to SIOA_C
	otir
	ld hl, sio_setup
	ld bc, 0x0C00 + SIOB_C		; and 12 to SIOB_C (vector included)
	otir

	ld	hl, vectortab
	ld	de, vectors
	ld	a, d
	ld	bc, 32
	ldir
	ld	i, a

	im	2

	ret

vectortab:
	.word	unexpected		; CTC 0 @ 0x80
	.word	unexpected		; CTC 1
	.word	interrupt_hook		; CTC 2
	.word	unexpected		; CTC 3
	.word	unexpected
	.word	unexpected
	.word	unexpected
	.word	unexpected
	.word	siob_txd		; SIO @ 0x90
	.word	siob_status
	.word	siob_rx_ring
	.word	siob_special
	.word	sioa_txd
	.word	sioa_status
	.word	sioa_rx_ring
	.word	sioa_special


sio_setup:
	.byte	0x00
	.byte	0x18		; Reset
	.byte	0x04
	.byte	0x44		; 115200 baud at / 16
	.byte	0x01
	.byte	0x1F
	.byte	0x03
	.byte	0xC1
	.byte	0x05
	.byte	0xEA		; RTS low
	.byte	0x02
	.byte	0x90		; vector 0x90

;
;	Bank switching unsurprisingly must be in common memory space so it's
;	always available.
;
	.commondata

mapsave:
	.byte	0	; Saved copy of the previous map (see map_save)
icount:
	.byte	4

_kernel_flag:
	.byte	1	; We start in kernel mode

	.common

unexpected:
	reti		; and hope

interrupt_hook:
	push	af
	push	hl
	ld	hl, icount
	dec	(hl)
	jr	z, ivec
	pop	hl
	pop	af
	reti
ivec:	ld	a, 4		; Scale 400Hz down to 100Hz
	ld	(hl), a
	pop	hl
	pop	af
	jp	interrupt_handler
;
;	This is invoked with a NULL argument at boot to set the kernel
;	vectors and then elsewhere in the kernel when the kernel knows
;	a bank may need vectors writing to it.
;
_program_vectors:
	; we are called, with interrupts disabled, by both newproc() and crt0
	; will exit with interrupts off
	di		; just to be sure
	pop	de	; temporarily store return address
	pop	hl	; function argument -- base page number
	push	hl	; put stack back as it was
	push	de

	call	map_proc

	; now install the interrupt vector at 0x0038
	ld	a, 0xC3 ; JP instruction
	ld	(0x0038), a
	ld	hl, interrupt_handler
	ld	(0x0039), hl

	ld	(0x0000), a
	ld	hl, null_handler   ;   to Our Trap Handler
	ld	(0x0001), hl

	; and fall into map_kernel

;
;	The top 32K bank holds kernel code and pieces of common memory
;	The lower 32K is switched between the kernel and various user banks.
;
;	The _di versions of the functions are called when we know interrupts
;	are definitely off. In our case it's not useful information so both
;	symbols end up at the same code.
;
map_buffers:
	   ; for us no difference. We could potentially use a low 32K bank
	   ; for buffers but it's not clear it would gain us much value
map_kernel_di:
map_kernel:
map_kernel_restore:		; On banked kernels this is different
				; on unbanked it is just a map_kernel
	push af
	ld a, 0xC6		; kernel ends up in bank 0, RAM
	out (0x0C), a
	pop af
	ret
	; map_proc is called with HL either NULL or pointing to the
	; page mapping. Unlike the other calls it's allowed to trash AF
map_proc:
	ld a, h
	or l
	jr z, map_kernel
map_proc_hl:
	ld a, (hl)			; and fall through
	;
	; With a simple bank switching system you need to provide a
	; method to switch to the bank in A without corrupting any
	; other registers. The stack is safe in common memory.
	; For swap you need to provide what for simple banking is an
	; identical routine.
map_for_swap:
map_proc_a:			; used by bankfork
	out (0x0C), a
	ret

	;
	; Map the current process into memory. We do this by extracting
	; the bank value from u_page.
	;
map_proc_always_di:
map_proc_always:
	push af
	ld a, (_udata + U_DATA__U_PAGE)
	out (0x0C),a
	pop af
	ret

	;
	; Save the existing mapping and switch to the kernel.
	; The place you save it to needs to be in common memory as you
	; have no idea what bank is live. Alternatively defer the save
	; until you switch to the kernel mapping
	;
map_save_kernel:   
	push af
	in a,(0x0C)
	ld (mapsave), a
	ld a, 0xC6		; Kernel map (see map_kernel)
	out (0x0C),a
	pop af
	ret
	;
	; Restore the saved bank. Note that you don't need to deal with
	; stacking of banks (we never recursively use save/restore), and
	; that we may well call save and decide not to call restore.
	;
map_restore:
	push af
	ld a, (mapsave)
	out (0x0C), a
	pop af
	ret
