;
;	SC126 support code. Based closely upon the N8VEM mark IV code by
;	Will Sowerbutts
;
        .z180

        ; exported symbols
        .export init_early
        .export init_hardware
        .export _detect_1mb
        .export inchar
        .export outchar
        .export plt_interrupt_all
        .export _bufpool
	.export _plt_idle
	.export _reverse_byte
	.export _sd_spi_rx_sector
	.export _sd_spi_tx_sector

#include "kernelu.def"
#include "../../cpu-z180/z180.def"
#include "../../cpu-z80u/kernel-z80.def"

	.buffers

_bufpool:
        .ds	BUFSIZE * 4 ; adjust NBUFS in config.h in line with this

	.discard

init_early:
	jp z180_init_early

init_hardware:
        ; enable ASCI interrupts
        in0	a, (ASCI_STAT0)
        or	0x08                ; enable ASCI0 receive interrupts
        out0	(ASCI_STAT0), a
        in0	a, (ASCI_ASEXT0)
        and	0x7f               ; disable RDRF interrupt inhibit
        out0	(ASCI_ASEXT0), a
        in0	a, (ASCI_STAT1)
        or	0x08                ; enable ASCI1 receive interrupts
        out0	(ASCI_STAT1), a
        in0	a, (ASCI_ASEXT1)
        and	0x7f               ; disable RDRF interrupt inhibit
        out0	(ASCI_ASEXT1), a
        jp z180_init_hardware


_detect_1mb:
        ; Try to enable and probe additional RAM chip
        ; Select U2 for low half of physical memory
        ld	hl, _rtc_shadow
        ld	a, (hl)
        or	0x02
        out	(0x0C), a
        ld	(hl), a

        ; Will need to examine a byte in the top 4K logical region (controlled
        ; by CBR) and this also gives us a convenient 0.
        ld	hl, 0xFF00

        in0	c, (MMU_CBR)
        out0	(MMU_CBR), l

        ld	a, (hl)
        xor	0x55
        ld	(hl), a
        ld	b, a
        ld	a, (hl)

        out0	(MMU_CBR), c

        xor	b
        ret	nz	; return 0 in L
        inc	l	; return 1
        ret

	.common

; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
outchar:
        push	bc
        ld	b, a
        ; wait for transmitter to be idle
ocloop: in0	a, (ASCI_STAT0)
        bit	1, a		; and 0x02
        jr	z, ocloop	; loop while busy
        ; now output the char to serial port
        ld	a, b
        out0	(ASCI_TDR0), a
        pop	bc
        ret

; inchar: Wait for character on UART, return in A
; destroys: AF
inchar:
        in0	a, (ASCI_STAT0)
        rlca
        jr	nc, inchar
        in0	a, (ASCI_RDR0)
        ret

plt_interrupt_all:
        ret

	.code

_plt_idle:
	ld	a,0xFF
	out	(0x0D),a
	halt
	ret

_reverse_byte:
        ld	hl, 2
        add	hl, sp
        ld	a, (hl)
reverse_byte_a:
        ; reverse bits in A
        ld	l,a    ; a = 76543210
        rlca
        rlca      ; a = 54321076
        xor	l
        and	0xAA
        xor	l     ; a = 56341270
        ld	l,a
        rlca
        rlca
        rlca      ; a = 41270563
        rrc	l     ; l = 05634127
        xor	l
        and	0x66
        xor	l     ; a = 01234567
        ld	l, a   ; return value in L
        ret

;****************************************************************************
;* The innermost part of the transfer routines has to live in common memory *
;* since it must be able to bank switch to the user memory bank.            *
;****************************************************************************

	.common
/* WRS: measured byte transfer time as approx 5.66us with Z180 @ 36.864MHz,
   three times faster. Main change is to start the next rx operation 
   as soon as possible and overlap the loop housekeeping with the rx. */

_sd_spi_rx_sector:
        pop	hl
        pop	de
        push	de
        push	hl
	push	bc
waitrx: 
        in0	a, (CSIO_CNTR)	; wait for any current tx or rx operation to complete
        tst	0x30
        jr	nz, waitrx
        set	5, a		; set CSIO_CNTR_RE, enable rx operation for first byte
        out0	(CSIO_CNTR), a
        ld	h, a		; stash value for reuse later

        ; load parameters
        ld	a, (_td_raw) 	; blkparam.is_user
        ld	bc, 512		; sector size
#ifdef CONFIG_SWAP
        cp	2
        jr	nz, not_swapin
        ld	a,(_td_page)
        call	map_for_swap
        jr	rxnextbyte
not_swapin:
#endif
        or	a
        jr	z, rd_kernel
        call	map_proc_always	; map user process
        jr	rxnextbyte
rd_kernel:
        call	map_buffers
rxnextbyte:
        dec	bc		; length--
        ld	a, b
        or	c
        jr	nz, waitrx2
        res	5, h		; final byte: clear CSIO_CNTR_RE bit in H
waitrx2:
        ld	l, c		; store C temporarily
        ld	c, CSIO_CNTR	; load IO port address
waitrx3:
        tstio	0x20		; test bits in IO port (C)
        jr	nz, waitrx3	; wait for rx to complete
        in0	a, (CSIO_TRDR)	; load rxd byte
        out0	(CSIO_CNTR), h	; start next rx (or NOP, if this is the final byte)
        ld	c, l		; restore C
        ; reverse bits in A
        ld	l,a		; a = 76543210
        rlca
        rlca			; a = 54321076
        xor	l
        and	0xAA
        xor	l		; a = 56341270
        ld	l,a
        rlca
        rlca
        rlca			; a = 41270563
        rrc	l		; l = 05634127
        xor	l
        and	0x66
        xor	l		; a = 01234567
        ld	(de), a		; store reversed byte value
        inc	de		; ptr++
        bit	5, h
        jr	nz, rxnextbyte	; go again if not yet done
        jr	transferdone	; we are done

_sd_spi_tx_sector:
        ; load parameters
        pop	hl
        pop	de
        push	de
        push	hl
	push	bc
        ld	a, (_td_raw)	; blkparam.is_user
        ld	hl, 512		; sector size
#ifdef CONFIG_SWAP
        cp	2
        jr	nz, not_swapout
        ld	a, (_td_page)
        call	map_for_swap
        jr	gotx
not_swapout:
#endif
        or	a
        jr	z, wr_kernel
        call	map_proc_always	; map user process
        jr	gotx
wr_kernel:
        call	map_buffers
gotx:
        in0	a, (CSIO_CNTR)
        and	0xDF		; mask off RE bit
        or	0x10		; set TE bit
        ld	b, a		; B now contains CNTR register value to start transmission
txnextbyte:
        ld	a, (de)
        ; reverse bits in A
        ld	c,a
        rlca
        rlca
        xor	c
        and	0xAA
        xor	c
        ld	c,a
        rlca
        rlca
        rlca
        rrc	c
        xor	c
        and	0x66
        xor	c
        ld	c, CSIO_CNTR	; load IO port address
waittx: 
        tstio	0x10		; test bits in IO port (C)
        jr	nz, waittx	; wait for tx to complete
        out0	(CSIO_TRDR), a	; write byte to tx
        out0	(CSIO_CNTR), b	; start tx
        inc	de		; ptr++
        dec	hl		; length--
        ld	a, h
        or	l
        jr	nz, txnextbyte	; length != 0, go again
transferdone:			; note this code is shared with sd_spi_rx_block
        ld	l, 1		; return true
	pop	bc
        jp	map_kernel_restore	; map kernel and return
