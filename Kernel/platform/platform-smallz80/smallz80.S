;
;	SmallZ80 support
;
;	This first chunk is mostly boilerplate to adjust for each
;	system.
;

	; exported symbols
	.export init_early
	.export init_hardware
	.export _program_vectors
	.export plt_interrupt_all
	.export _kernel_flag
	.export _int_disabled

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar

#include "../../build/kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"
#include "../../cpu-z180/z180.def"


;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.export _bufpool
	.buffers

_bufpool:
	.ds BUFSIZE * NBUFS

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK (kept even when we task switch)
; -----------------------------------------------------------------------------
	.commondata

;
;	Interrupt flag. This needs to be in common memory for most memory
;	models. It starts as 1 as interrupts start off.
;
_int_disabled:
	.byte	1

	.common
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
;	Wait for a key as the monitor does a screen clear
;
_plt_monitor:
	ld	a,(_uart_base + 1)
	add	a,5
	ld	c,a
pmwait:
	in	a,(c)
	rrca
	jr	nc, pmwait
	; Fall through
;
;	Reboot the system if possible, halt if not. On a system where the
;	ROM promptly wipes the display you may want to delay or wait for
;	a keypress here (just remember you may be interrupts off, no kernel
;	mapped so hit the hardware).
;
_plt_reboot:
	di
	ld	a,(_sys_cpu)
	cp	6			; Z180 ?
	jr	nz, gpio_reboot
	ld	a,(_uart_base + 1)
	add	a,4
	ld	c,a
	xor	a
	; Ensure the ROM is off in all forms, and hit the switch
	out	(c),a
	.z180
	out0	(MMU_BBR),a
	.z80
	rst	0
gpio_reboot:
	out	(0xF8),a
	rst	0

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (may be below 0x8000, only accessible when the kernel is
; mapped)
; -----------------------------------------------------------------------------
	.code
;
;	This routine is called very early, before the boot code shuffles
;	things into place. We do the ttymap here mostly as an example but
;	even that really ought to be in init_hardware.
;
init_early:
	in a,(0xF8)
	or 0x70		; All lights on
	out (0xF8),a
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

	ld	a,(0xFFC2)	; Where is the primary serial ?
	cp	0x10
	ld	a, 0x20		; For RTC refs
	jr	z, old_board
	ld	a, 0x50
old_board:
	ld	(_rtc_base),a	; Set RTC infop
	add	a,0x0D		; set up pointer for RTC config
	ld	c,a

	xor	a
	out	(c),a		; hold off, weirdness off
	ld	a,0x02
	inc	c
	out	(c),a		; 64ms, clear any irq
				; irq mode, unmasked
	ld	a,0x04
	inc	c
	out	(c),a		; test off, 24hr mode, stop/reset off

	ld	a,(0xFFC0)	; ROM CP/M CON: port (16x50 base, or on
	ld	(_uart_base),a	; the Z180 0=ASCI0 1=ASCI1 FF=none)
	ld	hl, 0xFFC2	; set up the uart map early
	ld	de, _uart_base + 1

	ldi
	inc	hl
	ldi
	inc	hl
	ldi
	inc	hl
	ldi
	inc	hl
	ld	a,(hl)
	ld	(_num_banks),a
	;	Ignore the expansion board info for now (floppy etc)

	;	Test the CPU for Z180 (same DAA check as
	;	set_cpu_type: a Z80 sets carry here, a Z180 does not).
	xor	a
	dec	a
	daa
	jr	c, is_z80
	.z180
	ld	a,0xE0
	out0	(MMU_CBAR),a
	.z80
	ld	hl,1024
	ld	(_ramsize), hl
	ld	hl,960
	ld	(_procmem), hl
	jr	setup
is_z80:
	ld	hl,544			; 512 + 32
	ld	(_ramsize), hl
	ld	hl,480
	ld	(_procmem), hl
setup:
	; set up interrupt vectors for the kernel (also sets up common memory in page 0x000F which is unused)
	ld	hl, 0
	push	hl
	call	_program_vectors
	pop	hl

	im 1 ; set CPU interrupt mode

	ret

;
;	Bank switching unsurprisingly must be in common memory space so it's
;	always available.
;
	.commondata

_kernel_flag:
	.byte	1	; We start in kernel mode

	.common
;
;	This is invoked with a NULL argument at boot to set the kernel
;	vectors and then elsewhere in the kernel when the kernel knows
;	a bank may need vectors writing to it.
;
;	FIXME: do this once early as we don't switch the low 16K
;
_program_vectors:
	; we are called, with interrupts disabled, by both newproc() and crt0
	; will exit with interrupts off
	di ; just to be sure
	pop	de ; temporarily store return address
	pop	hl ; function argument -- base page number
	push	hl ; put stack back as it was
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

	jp	map_kernel

	;
	; Used for low level debug. Output the character in A without
	; corrupting other registers. May block. Interrupts and memory
	; state are undefined
	;
outchar:
	push	af
	push	bc
	ld	a, (_uart_base + 1)
	add	a,5
	ld	c,a
twait:	in	a, (c)
	bit	5, a
	jr	z, twait
	ld	a,c
	sub	5
	ld	c,a
	pop	af
	out	(c), a
	pop	bc
	ret
