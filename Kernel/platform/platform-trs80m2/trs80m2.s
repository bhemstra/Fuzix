;
;	TRS-80 Model II hardware support
;
;	The machine has 32K of fixed RAM at 0000-7FFF and selects one of up
;	to fifteen 32K pages at 8000-FFFF through port 0xFF. Page 1 holds
;	the upper part of the kernel, pages 2 and up hold user processes.
;	Video memory overlays F800-FFFF when port 0xFF bit 7 is set, which
;	we do whenever the kernel is mapped.
;
;	The only periodic interrupt is the real time clock, which is wired
;	to NMI (vertical sync / 2). We turn it into a normal timer interrupt
;	when the CPU had interrupts enabled at the time it fired, otherwise
;	we just count it and pick it up on the next interrupt.
;
;	The Z80 peripherals (CTC, SIO, DMA, PIO) are used in interrupt mode
;	1 so only the SIO receive interrupts are enabled.
;

            .module trs80m2

            ; exported symbols
            .globl init_early
            .globl init_hardware
            .globl _program_vectors
	    .globl plt_interrupt_all
	    .globl map_kernel
	    .globl map_kernel_di
	    .globl map_kernel_restore
	    .globl map_proc
	    .globl map_proc_di
	    .globl map_proc_a
	    .globl map_proc_always
	    .globl map_proc_always_di
	    .globl map_save_kernel
	    .globl map_restore
	    .globl _int_disabled
	    .globl _nmi_count
	    .globl _m2_rtc_on
	    .globl _m2_pages
	    .globl _bufpool

	    ; hard disk helpers
	    .globl _hd_xfer_in
	    .globl _hd_xfer_out
	    ; floppy helper
	    .globl _fd_dma

            ; exported debugging tools
            .globl _plt_monitor
            .globl _plt_reboot
            .globl outchar

            ; imported symbols
            .globl _ramsize
            .globl _procmem
            .globl unix_syscall_entry
	    .globl interrupt_handler
	    .globl null_handler
	    .globl _hd_page
	    .globl _fd_page
	    .globl _fd_addr
	    .globl _fd_len
	    .globl _fd_wr
	    .globl ___sdcc_enter_ix
	    .globl _udata

            .include "kernel.def"
            .include "../../cpu-z80/kernel-z80.def"

	    .area _BUFFERS

_bufpool:
	    .ds BUFSIZE * NBUFS

; -----------------------------------------------------------------------------
; COMMON MEMORY (fixed lower 32K)
; -----------------------------------------------------------------------------
            .area _COMMONMEM

_int_disabled:
	    .db 1
_nmi_count:
	    .db 0
m2_cur:
	    .db M2_VIDEO + M2_KPAGE	; last value written to port 0xFF
m2_save:
	    .db M2_VIDEO + M2_KPAGE
m2_rtc:
	    .db 0			; M2_RTC once the clock is running

;
;	Stop for good. The real time clock NMI would wake a plain halt, so
;	turn the clock off and keep halting.
;
_plt_monitor:
	    di
	    ld a, #M2_VIDEO + M2_KPAGE	; clock interrupt off
	    out (0xFF), a
monitor_stop:
	    halt
	    jr monitor_stop

plt_interrupt_all:
	    ret

;
;	Put the boot ROM back and jump into it. Page 0 stays as it is and
;	the upper page is deselected the way a reset leaves it.
;
_plt_reboot:
	    di
	    xor a
	    out (0xFF), a
	    inc a
	    out (0xF9), a		; boot ROM back on
	    rst 0

;
;	The vectors live in the fixed low memory so they are shared by
;	every process. We just (re)write them.
;
_program_vectors:
	    ld a, #0xC3			; JP
	    ld (0x0000), a
	    ld hl, #null_handler
	    ld (0x0001), hl
	    ld (0x0030), a		; RST 30 is the system call
	    ld hl, #unix_syscall_entry
	    ld (0x0031), hl
	    ld (0x0038), a		; IM 1 interrupt
	    ld hl, #interrupt_handler
	    ld (0x0039), hl
	    ld (0x0066), a		; NMI (real time clock)
	    ld hl, #nmi_entry
	    ld (0x0067), hl
	    ret

;
;	Real time clock NMI. Reading port 0xFE clears it. If interrupts were
;	enabled when it fired (IFF2 set) then it is safe to run the normal
;	interrupt path, which ends with interrupts enabled again just as a
;	RETN would have done. If not, count it and return; the next
;	interrupt (or this NMI next time round) picks the tick up.
;
nmi_entry:
	    push af
	    in a, (0xFE)
	    ld a, (_nmi_count)
	    inc a
	    ld (_nmi_count), a
	    ld a, i			; P/V = IFF2
	    jp pe, nmi_irq
	    pop af
	    retn
nmi_irq:
	    pop af
	    ; Accepting the NMI cleared IFF1 but left IFF2 set. Clear it as
	    ; well, otherwise a second tick during the handler would think
	    ; interrupts were on and re-enter it, and the RETI at the end of
	    ; the handler would turn interrupts back on too early. The
	    ; handler re-enables interrupts itself on the way out.
	    di
	    jp interrupt_handler

;
;	Debug output on serial port A (polled, with a timeout so a port
;	with no clock or cable does not hang us)
;
outchar:
	    push af
	    push bc
	    ld bc, #0
outcharw:
	    in a, (0xF6)
	    bit 2, a
	    jr nz, outcharok
	    dec bc
	    ld a, b
	    or c
	    jr nz, outcharw
outcharok:
	    pop bc
	    pop af
	    out (0xF4), a
	    ret

;
;	Memory mapping. The kernel map is page 1 plus video, user maps are
;	the user page with video off. The RTC enable bit lives in the same
;	port so it is merged in on every write.
;
map_kernel:
map_kernel_di:
map_kernel_restore:
	    push af
	    ld a, (m2_rtc)
	    or #M2_VIDEO + M2_KPAGE
	    ld (m2_cur), a
	    out (0xFF), a
	    pop af
	    ret

map_proc:
map_proc_di:
	    ld a, h
	    or l
	    jr z, map_kernel
	    ld a, (hl)
map_proc_a:
	    push af
	    push bc
	    and #0x0F
	    ld b, a
	    ld a, (m2_rtc)
	    or b
	    ld (m2_cur), a
	    out (0xFF), a
	    pop bc
	    pop af
	    ret

map_proc_always:
map_proc_always_di:
	    push af
	    ld a, (_udata + U_DATA__U_PAGE)
	    call map_proc_a
	    pop af
	    ret

map_save_kernel:
	    push af
	    ld a, (m2_cur)
	    ld (m2_save), a
	    pop af
	    jr map_kernel

map_restore:
	    push af
	    push bc
	    ld a, (m2_save)
	    and #~M2_RTC
	    ld b, a
	    ld a, (m2_rtc)
	    or b
	    ld (m2_cur), a
	    out (0xFF), a
	    pop bc
	    pop af
	    ret

;
;	Start the real time clock interrupt
;
_m2_rtc_on:
	    ld a, #M2_RTC
	    ld (m2_rtc), a
	    ld a, (m2_cur)
	    or #M2_RTC
	    ld (m2_cur), a
	    in a, (0xFE)		; clear any stale tick first
	    ld a, (m2_cur)
	    out (0xFF), a
	    ret

;
;	Find which of pages 2-15 are fitted. Returns a bit mask in HL (bit
;	n set for page n). This has to run from low memory as it maps the
;	pages in. 0xF7F0 is in the old loader space so scribbling on it in
;	page 1 is harmless.
;
_m2_pages:
	    ld bc, #0x0F00 + 0xFF	; B = page, C = port
markp:
	    out (c), b
	    ld a, b
	    ld (0xF7F0), a
	    cpl
	    ld (0xF7F1), a
	    dec b
	    ld a, b
	    cp #1
	    jr nz, markp
	    ; Page 1 last so pages that alias it can be spotted
	    out (c), b
	    ld (0xF7F0), a
	    cpl
	    ld (0xF7F1), a
	    ld hl, #0
	    ld de, #4			; bit for page 2
	    ld b, #2
scanp:
	    out (c), b
	    ld a, (0xF7F0)
	    cp b
	    jr nz, nopage
	    cpl
	    ld (0xF7F0), a		; and check it is really RAM
	    ld a, (0xF7F0)
	    cpl
	    cp b
	    jr nz, nopage
	    ld a, (0xF7F1)
	    cpl
	    cp b
	    jr nz, nopage
	    add hl, de
nopage:
	    ex de, hl
	    add hl, hl
	    ex de, hl
	    inc b
	    bit 4, b
	    jr z, scanp
	    ld a, (m2_cur)
	    out (0xFF), a
	    ret

;
;	Hard disk transfer helpers. The Model II hard disks use 512 byte
;	sectors. Called with a pointer to the buffer and hd_page set to the
;	page to transfer to (0 for the kernel).
;
_hd_xfer_in:
	   pop de
	   pop hl
	   push hl
	   push de
	   ld a, (_hd_page)
	   or a
	   call nz, map_proc_a
	   ld bc, #0xC8			; 512 bytes from 0xC8
	   inir
	   inir
	   call map_kernel
	   ret

_hd_xfer_out:
	   pop de
	   pop hl
	   push hl
	   push de
	   ld a, (_hd_page)
	   or a
	   call nz, map_proc_a
	   ld bc, #0xC8			; 512 bytes to 0xC8
	   otir
	   otir
	   call map_kernel
	   ret

;
;	Floppy transfer using the Z80 DMA. The FD1791 DRQ line drives the
;	DMA RDY input. Port A of the DMA is memory, port B is the FDC data
;	register.
;
;	uint8_t fd_dma(uint8_t cmd)
;
;	fd_addr/fd_len give the buffer, fd_wr is set for a write and
;	fd_page is the page to map (0 for the kernel). Must be called
;	with interrupts off as the DMA uses whatever page is mapped while
;	it runs. Returns the FDC status, or 0xFF on a timeout.
;
;	The block length is programmed as the real length. Some DMA parts
;	move one byte more than programmed, but the FDC never asks for it
;	and we turn the DMA off once the FDC is done.
;
_fd_dma:
	    pop de
	    pop hl			; L = command
	    push hl
	    push de
	    ld a, (_fd_page)
	    or a
	    call nz, map_proc_a
	    ld c, #0xF8
	    ld a, #0xC3			; reset
	    out (c), a
	    ld a, #0x79			; WR0: B->A, port A address and
	    out (c), a			; length follow
	    ld de, (_fd_addr)
	    out (c), e
	    out (c), d
	    ld de, (_fd_len)
	    out (c), e
	    out (c), d
	    ld a, #0x14			; WR1: port A memory, increment
	    out (c), a
	    ld a, #0x28			; WR2: port B I/O, fixed
	    out (c), a
	    ld a, #0xC5			; WR4: burst, port B low address
	    out (c), a
	    ld a, #0xE7			; FDC data register
	    out (c), a
	    ld a, #0x8A			; WR5: RDY active high
	    out (c), a
	    ld a, #0xCF			; load
	    out (c), a
	    ld a, (_fd_wr)
	    or a
	    jr z, fd_dma_go
	    ; For A->B the fixed port B address only loads correctly if we
	    ; load once B->A then flip the direction and load again
	    ld a, #0x05			; WR0: A->B, nothing follows
	    out (c), a
	    ld a, #0xCF
	    out (c), a
fd_dma_go:
	    ld a, #0x87			; enable
	    out (c), a
	    ld a, l
	    out (0xE4), a		; issue the FDC command
	    ld b, #20			; let the FDC go busy
fd_dma_settle:
	    djnz fd_dma_settle
	    ld bc, #0
	    ld e, #3			; about 2.4 seconds
fd_dma_wait:
	    in a, (0xE4)
	    rra
	    jr nc, fd_dma_done
	    dec bc
	    ld a, b
	    or c
	    jr nz, fd_dma_wait
	    dec e
	    jr nz, fd_dma_wait
	    ld a, #0xD0			; force interrupt
	    out (0xE4), a
	    ld l, #0xFF
	    jr fd_dma_out
fd_dma_done:
	    in a, (0xE4)
	    ld l, a
fd_dma_out:
	    ld a, #0x83			; DMA off
	    out (0xF8), a
	    jp map_kernel

; -----------------------------------------------------------------------------
; KERNEL CODE (only run with the kernel mapped)
; -----------------------------------------------------------------------------
            .area _CODE

_crtc6845:				; 80x24 registers 0-15, as the boot ROM
	    .db 99, 80, 85, 8, 25, 0, 24, 24, 0, 9, 0x65, 9, 0, 0, 0, 0

init_early:
	    ; Load the 6845 parameters
	    ld hl, #_crtc6845
	    ld b, #0
crtcloop:
	    ld a, b
	    out (0xFC), a		; register
	    ld a, (hl)
	    out (0xFD), a		; data
	    inc hl
	    inc b
	    bit 4, b
	    jr z, crtcloop

	    ; Clear the screen
	    ld hl, #0xF800
	    ld (hl), #'*'		; debugging aid in top left
	    inc hl
	    ld de, #0xF802
	    ld bc, #1918
	    ld (hl), #' '
	    ldir
	    ret

init_hardware:
	    ; DMA off
	    ld a, #0xC3
	    out (0xF8), a
	    ; CTC channel 3 is the keyboard strobe, we poll the keyboard so
	    ; leave all four channels reset with interrupts off. Channels
	    ; 0-2 are set up as baud rate generators by the tty code.
	    ld a, #0x03
	    out (0xF0), a
	    out (0xF1), a
	    out (0xF2), a
	    out (0xF3), a
	    ; PIO port A (status) input, port B (printer) output, no IRQs
	    ld a, #0x4F
	    out (0xE2), a
	    ld a, #0x07
	    out (0xE2), a
	    ld a, #0x0F
	    out (0xE3), a
	    ld a, #0x07
	    out (0xE3), a
	    ; SIO channel resets
	    ld a, #0x18
	    out (0xF6), a
	    out (0xF7), a
	    ; Hard disc controller off until probed
	    xor a
	    out (0xC1), a

	    ; Vectors and compiler helper vectors in the shared low page
	    call _program_vectors
	    ld hl, #rstblock
	    ld de, #8
	    ld bc, #32
	    ldir

	    im 1
	    ret

;
;	Stub helpers for code compactness. Note that
;	sdcc_enter_ix is in the standard compiler support already
;
	.area _DISCARD

;
;	The first two use an rst as a jump. In the reload sp case we don't
;	have to care. In the pop ix case for the function end we need to
;	drop the spare frame first, but we know that af contents don't
;	matter
;

rstblock:
	jp	___sdcc_enter_ix
	.ds	5
___spixret:
	ld	sp,ix
	pop	ix
	ret
	.ds	3
___ixret:
	pop	af
	pop	ix
	ret
	.ds	4
___ldhlhl:
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
