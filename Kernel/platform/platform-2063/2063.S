;
;	2063 specific hardware implementation/ Mostly
;	memory banking
;
        ; exported symbols
        .export init_hardware
	.export _program_vectors
	.export map_kernel
	.export map_proc
	.export map_proc_always
	.export map_proc_a
	.export map_kernel_di
	.export map_kernel_restore
	.export map_proc_di
	.export map_proc_always_di
	.export map_save_kernel
	.export map_restore
	.export map_for_swap
	.export map_buffers
	.export plt_interrupt_all
	.export _plt_reboot
	.export _plt_monitor
	.export _plt_idle
	.export _lp_strobe
	.export _bufpool
	.export _int_disabled
	.export _gpio
	.export _sd_busy
	.export _sd_count

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

;=========================================================================
; Buffers
;=========================================================================
	.buffers

	.export	kernel_endmark

_bufpool:
        .ds	BUFSIZE * 4 ; adjust NBUFS in config.h in line with this
;
;	So we can check for overflow
;
kernel_endmark:

;=========================================================================
; Initialization code
;=========================================================================

	.discard

init_hardware:
	ld	hl,512
	ld	(_ramsize), hl
	ld	hl,512-64
	ld	(_procmem), hl

	call	program_kvectors

	call	sio_install

	call	_vdp_type
	ld	a,l
	ld	(_vdptype),a
	call	_vdp_init
	call	_vdp_load_font
	call	_vdp_wipe_consoles
	call	_vdp_restore_font

        ; ---------------------------------------------------------------------
	; Initialize CTC
	;
	; We must initialize all channels of the CTC. The documentation
	; states that the initial CTC state is undefined and we don't want
	; random interrupt surprises
	;
	; ---------------------------------------------------------------------

	;
	; Defense in depth - shut everything up first
	;

	ld	a,0x43
	out	(CTC_CH0),a	; set CH0 mode
	out	(CTC_CH1),a	; set CH1 mode
	out	(CTC_CH2),a	; set CH2 mode
	out	(CTC_CH3),a	; set CH3 mode

	xor a
	out	(CTC_CH0),a	; set the CTC vector to 0

	; CTC 1 and 2 drive the SIO are are on a fixed 1.8Mhz clock. The
	; timer though is off the CPU clock so we just have to hope
	; everyone stays with 10MHz
	;
	; This is btw a lousy choice because with rhe /256 divider we get
	; 39062 clocks and 19531 is prime...
	;

	ld	a,0xB5
	out	(CTC_CH3),a
	ld	a,217			; 180Hz ish (we'll drift slghly... )
	; TOOD add a subtle fudge factor to the clock to fix the drift
	out	(CTC_CH3),a

	ld	hl,interrupt_hook
	ld	(_vectors + 6),hl

	ld	hl,_vectors
	ld	a,h
	ld	i,a
	im	2			; set Z80 CPU interrupt mode 1 for now

	call _vtinit			; init the console video
	ret

	.common

; No way to page the ROM back in
_plt_monitor:
_plt_reboot:
	di
	halt

_int_disabled:
	.byte	1
pagereg:
	.byte	0
pagesave:
	.byte	0

_gpio:
	.byte	0x05			; CS high clock low MOSI high

plt_interrupt_all:
	ret

; install interrupt vectors
_program_vectors:
	di
	pop	de			; temporarily store return address
	pop	hl			; function argument -- base page number
	push	hl			; put stack back as it was
	push	de
	push	bc

	call	map_proc

	; write zeroes across all vectors
	ld	hl,0
	ld	de,1
	ld	bc,0x007f		; program first 0x80 bytes only
	ld	(hl),0x00
	ldir
	pop	bc

program_kvectors:
	ld	a,0xC3			; JP instruction
	ld	(0x0000),a		; Must be present for NULL checker
	ld	hl,null_handler		; to Our Trap Handler
	ld	(0x0001),hl

	; now install the interrupt vector at 0x0038 (shouldn't be use)
	ld	(0x0038),a
	ld	hl,interrupt_hook
	ld	(0x0039),hl

	ld	(0x0066),a		; Set vector for NMI
	ld	hl,nmi_handler
	ld	(0x0067),hl

	jr	map_kernel

;
;	Wrap the system interrupt code to deal with the brain-dead
;	SPI/banking conflict
;
interrupt_hook:
	push	af
	ld	a,(_sd_busy)
	or	a
	jr	nz, contended
	pop	af
	jp	interrupt_handler
contended:
	ld	a,(_sd_count)
	inc	a
	ld	(_sd_count),a
	pop	af
	ei
	reti

_sd_busy:
	.byte	0		; SD is bitbanging the GPIO
_sd_count:
	.byte	0		; Number of timer interrupts lost
				; to SD bitbanging

;=========================================================================
; Memory management
;=========================================================================

map_proc:
map_proc_di:
	ld	a,h
	or	l			; HL == 0?
	jr	z,map_kernel		; HL == 0 - map the kernel
	ld	a,(hl)
map_for_swap:
map_proc_a:
	push	bc
	ld	(pagereg),a
	ld	c,a
	ld	a,(_gpio)
	and	0x0F
	or	c
	ld	(_gpio),a
	out	(0x10),a
	pop	bc
	ret

map_proc_always:
map_proc_always_di:
	push	af
	ld	a,(_udata + U_DATA__U_PAGE)
	call	map_proc_a
	pop	af
	ret

map_buffers:
map_kernel:
map_kernel_di:
map_kernel_restore:
	push	af
map_kernel_a:
	xor	a
	call	map_proc_a
	pop	af
	ret

map_restore:
	push	af
	ld	a,(pagesave)
	call	map_proc_a
	pop	af
	ret

map_save_kernel:
	push	af
	ld	a,(pagereg)
	ld	(pagesave),a
	jr	map_kernel_a

	.code

_plt_idle:
	halt
	ret

_lp_strobe:
	ld a,(_gpio)
	ld l,a
	and 0xF7
	out (0x10),a
	ld a,l
	nop
	out(0x10),a
	ret
