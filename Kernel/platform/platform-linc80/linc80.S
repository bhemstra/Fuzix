;
;	Linc80 Initial Support
;

        ; exported symbols
        .export init_hardware
        .export _program_vectors
	.export _kernel_flag
        .export map_kernel
        .export map_buffers
        .export map_proc_always
        .export map_proc
        .export map_kernel_di
        .export map_kernel_restore
        .export map_proc_always_di
        .export map_save_kernel
        .export map_restore
	.export map_for_swap
	.export _plt_reboot
	.export _int_disabled
	.export plt_interrupt_all
	.export _need_resched

        ; exported debugging tools
        .export _plt_monitor

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"


;
; Buffers (we use asm to set this up as we need them in a special segment
; so we can recover the discard memory into the buffer pool
;

	.buffers
	.export _bufpool
_bufpool:
	.ds BUFSIZE * NBUFS

;
;	We need this above 16K so the ROM doesn't map over it
;
	.code

_plt_monitor:
	    ; Reboot ends up back in the monitor
_plt_reboot:
	xor a
	ld hl,0x38D3		; out (38),a
	ld (0xFFFE),hl
	jp 0xFFFE		; does the out, wraps to 0 and the ROM
				; appeared

	.data

_int_disabled:
	.byte 1

	.common
map_buffers:
map_kernel:
map_kernel_di:
map_kernel_restore:
	push af
	ld a,#1
map_a:
	ld (mapreg),a
	out (0x38),a
	pop af
	ret
map_proc:
	ld a,h
	or l
	jr z, map_kernel
map_proc_always:
map_proc_always_di:
map_for_swap:
	push af
	ld a,#3
	jr map_a
map_save_kernel:
	push af
	ld a,(mapreg)
	ld (mapsave),a
	ld a,#1
	jr map_a
map_restore:
	push af
	ld a,(mapsave)
	jr map_a

_program_early_vectors:
	push	bc
        ; write zeroes across all vectors
        ld hl, vectormap
	ld de, #0
	ld bc, #0x80
	ldir
	pop	bc

_program_vectors:
plt_interrupt_all:
	ret

	.export spurious		; so we can debug trap on it

spurious:
	ei
	reti

mapreg:
	.byte 0
mapsave:
	.byte 0

_need_resched:
	.byte 0



; -----------------------------------------------------------------------------
;	All of discard gets reclaimed when init is run
;
;	Discard must be above 0x8000 as we need some of it when the ROM
;	is paged in during init_hardware
; -----------------------------------------------------------------------------
	.discard

init_hardware:
	call _program_early_vectors
	; IM2 vector for the CTC
	ld hl, #spurious
	ld (0x80),hl			; CTC vectors
	ld (0x82),hl
	ld (0x84),hl
	ld hl, #interrupt_handler	; Standard tick handler
	ld (0x86),hl

	ld hl,#spurious			; For now
	ld (0x88),hl			; PIO A
	ld (0x8A),hl			; PIO B

	ld hl, #80
        ld (_ramsize), hl
	ld hl,#32
        ld (_procmem), hl

	call sio_install

	;
	;	Now program up the CTC
	;	CTC 0 and CTC 1 are set up for the serial and we should
	;	not touch them. We configure up 2 and 3
	;
	ld a,#0x80
	out (CTC_CH0),a	; set the CTC vector

	ld a,#0x25	; timer, 256 prescale, irq off
	out (CTC_CH2),a
	ld a,#90	; counter base (320 per second)
	out (CTC_CH2),a
	ld a,#0xF5	; counter, irq on
	out (CTC_CH3),a
	ld a,#8
	out (CTC_CH3),a	; 320 per sec down to 40 per sec

	xor a
	ld i,a	; Use upper half of rst vector page
        im 2	; set CPU interrupt

        ret

	.data

_kernel_flag:
	    .byte 1	; We start in kernel mode


	.code

;
;	Idle
;
	.export _plt_idle

_plt_idle:
	halt
	ret

;
;	Disk I/O transfer in common
;
	.common
	.export _devide_read_data
	.export _devide_write_data

initide:
	ld hl,6
	add hl,sp
	ld e,(hl)
	inc hl
	ld d,(hl)
	ex de,hl
	ld bc,0x10		; 256 ops port 0x10
	ld a,(_td_raw)
	or a
	ret z
	dec a
	jp z, map_proc_always
	dec a
	ld a,(_td_page)
	jp map_for_swap

_devide_read_data:
	push bc
	call initide
	inir
	inir
	pop bc
	jp map_kernel
_devide_write_data:
	push bc
	call initide
	otir
	otir
	pop bc
	jp map_kernel

	.discard

vectormap:
	jp	null_handler
	.ds	5
	jp	__ldword4
	.ds	5
	jp	__ldword6
	.ds	5
	jp	__ldword8
	.ds	5
	jp	__ldword10
	.ds	5
	jp	__ldword12
	.ds	5
	jp	__stword4
	.ds	5
	jp	interrupt_handler
	.ds	43
nmi:	jp	nmi_handler
	.ds	0x17
