;
;	We can't quite use the generic code because we are in ROM and we
;	don't run 64K banks due to the memory available.
;
        .z180

#include "kernelu.def"
#include "../../cpu-z180/z180.def"
#include "../../cpu-z80u/kernel-z80.def"

        ; exported symbols
        .export z180_init_hardware
        .export z180_init_early
        .export _program_vectors
        .export _copy_and_map_proc
        .export interrupt_table ; not used elsewhere but useful to check correct alignment
        .export hw_irqvector
        .export _irqvector
        .export _need_resched
	.export _int_disabled

	.export map_buffers
	.export map_kernel
	.export map_kernel_di
	.export map_kernel_restore
	.export map_proc_always
	.export map_proc_always_di
	.export map_for_swap
	.export map_save_kernel
	.export map_restore
	.export z80_irq

	.export _plt_switchout
	.export _switchin
	.export _dofork
	.export _plt_idle

#ifdef CONFIG_SWAP
	.export _swapout
#endif

	.discard

z180_init_early:
        ; program MMU for 60KB/4KB bank/common1 split.
        ld	a, 0xFD
        out0	(MMU_CBAR), a
        ret

z180_init_hardware:
        ; program Z180 interrupt table registers
        ld	hl, interrupt_table ; note table MUST be 32-byte aligned!
        out0	(INT_IL), l
        ld	a, h
        ld	i, a
        im	1	; set CPU interrupt mode for INT0

        ; set up system tick timer
        xor	a
        out0	(TIME_TCR), a
        ld	hl, #TCR_CLOCK
        out0	(TIME_RLDR0L), l
        out0	(TIME_RLDR0H), h
        ld a,	#0x11         ; enable downcounting and interrupts for timer 0 only
        out0	(TIME_TCR), a

        ; Enable illegal instruction trap (vector at 0x0000)
        ; Enable external interrupts (INT0/INT1/INT2) 
        ld a,	0x87
        out0	(INT_ITC), a

        jp	_init_hardware_c

	.code

_plt_idle:
	halt
	ret

;
;	More complicared than the usual set up as our banks are smaller.
;
_copy_and_map_proc:
        di		; just to be sure
        pop	hl	; temporarily store return address
        pop	de	; function argument -- pointer to base page number
        push	de	; put stack back as it was
        push	hl
	push	bc

        ld	b, 0x02
        out0	(DMA_DMODE), b     ; 0x02 - memory to memory, burst mode

        ; load destination page number
        ld	a, (de)
	cp	0x44
	; to process 1: 52:000 to 5F:FFF */
	ld	bc, 0x0405	; From 05:2000 to  04:400
	ld	de, 0x2000	; Souce
	ld	hl, 0x4000	; Dest
	jr	z, camp
	; to process 2: 44:000 to 51:FFF
	ld	bc, 0x0504	; 04:400 to 05:200
	ex	de,hl		; Copying the other direction
camp:
	ld	e,a		; Save the MMU value
	dec	e		;  E000 to F000 shift
	dec	e

	; Copy from CDL to BHL

        out0	(DMA_DAR0L), l	; 0
        out0	(DMA_DAR0H), h
	out0	(DMA_DAR0B), b
        out0	(DMA_SAR0L), l	; 0
        out0	(DMA_SAR0H), d
        out0	(DMA_SAR0B), c

	; Copy 56K (base and common)
	ld	hl, 0xE000
        out0	(DMA_BCR0H), h     ; set byte count
        out0	(DMA_BCR0L), l
        ; call dump_dma_state
	ld	c,0x40
        out0	(DMA_DSTAT), c     ; 0x40 - enable DMA channel 0
        ; CPU stalled until DMA completes

        ; finally reprogram the MMU to bring the new process common memory into context
        ; note this replaces the stack, but we just copied it over.

        out0	(MMU_CBR), e
	pop	bc
        ret ; was jp map_kernel but we never change MMU_BBR

	.data
fork_proc_ptr:
	.word	0 ; (C type is struct p_tab *) -- address of child process p_tab entry

	.code
;
;   Called from _fork. We are in a syscall, the uarea is live as the
;   parent uarea. The kernel is the mapped object.
;
_dofork:
        ; always disconnect the vehicle battery before performing maintenance
        di ; should already be the case ... belt and braces.

        pop	de  ; return address
        pop	hl  ; new process p_tab*
        push	hl
        push	de

        ld	(fork_proc_ptr), hl

        ; prepare return value in parent process -- HL = p->p_pid;
        ld	de, P_TAB__P_PID_OFFSET
        add	hl, de
        ld	a, (hl)
        inc	hl
        ld	h, (hl)
        ld	l, a

        ; Save the stack pointer and critical registers.
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        push	hl ; HL still has p->p_pid from above, the return value in the parent
	push	bc ; register variables
        push	ix
        push	iy
	; Compiler temporaries
	ld	hl,(__tmp)
	push	hl
	ld	hl,(__hireg)
	push	hl
	ld	hl,(__tmp2)
	push	hl
	ld	hl,(__tmp2+2)
	push	hl
	ld	hl,(__tmp3)
	push	hl
	ld	hl,(__tmp3+2)
	push	hl
	ld	hl,(__retaddr)
	push	hl
        ; save kernel stack pointer -- when it comes back in the parent we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
        ; returning) and with HL (ie return code) containing the child PID.
        ; Hooray.
        ld	(_udata + U_DATA__U_SP), sp

        ; now we're in a safe state for _switchin to return in the parent
        ; process.

        ; --------- copy process ---------
        ld	hl, (fork_proc_ptr)
        ld	de, P_TAB__P_PAGE_OFFSET
        add	hl, de
        push	hl
        call	_copy_and_map_proc
        pop	hl

        ; now the copy operation is complete we can get rid of the stuff
        ; _switchin will be expecting from our copy of the stack.
	; ix/iy are untouched so don't need a restore BC is not so does
	ld	hl, 18
	add	hl, sp
	ld	sp, hl
        pop	bc
	pop	af	; and the pid

        ; Make a new process table entry, etc.
	ld	 hl, _udata
	push	hl
        ld	hl, (fork_proc_ptr)
        push	hl
        call	_makeproc
        pop	af 
	pop	af

        ; runticks = 0;
        ld	hl, 0
        ld	(_runticks), hl
        ; in the child process, fork() returns zero.
        ;
        ; And we exit, with the kernel mapped, the child now being deemed
        ; to be the live uarea. The parent is frozen in time and space as
        ; if it had done a switchout().
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DEBUGGING
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; mmu_cbar_msg:  .ascii "MMU: CBAR="
;;                .byte	0
;; mmu_cbr_msg:   .ascii ", CBR="
;;                .byte	0
;; mmu_bbr_msg:   .ascii ", BBR="
;;                .byte	0
;; 
;; mmu_state_dump:
;;             ld hl, #mmu_cbar_msg
;;             call outstring
;;             in0 a, (MMU_CBAR)
;;             call outcharhex
;;             ld hl, #mmu_cbr_msg
;;             call outstring
;;             in0 a, (MMU_CBR)
;;             call outcharhex
;;             ld hl, #mmu_bbr_msg
;;             call outstring
;;             in0 a, (MMU_BBR)
;;             call outcharhex
;;             call outnewline
;;             ret
;; ;------------------------------------------------------------------------------
;; dmamsg1:    .ascii "[DMA source="
;;             .byte	0
;; dmamsg2:    .ascii ", dest="
;;             .byte	0
;; dmamsg3:    .ascii ", count="
;;             .byte	0
;; dmamsg4:    .ascii "]"
;;             .byte	13, 10, 0
;; 
;; dump_dma_state:
;;         push af
;;         push hl
;;         push de
;;         push bc
;; 
;;         ld hl, #dmamsg1
;;         call outstring
;; 
;;         in0 a, (DMA_SAR0B)
;;         call outcharhex
;;         in0 a, (DMA_SAR0H)
;;         call outcharhex
;;         in0 a, (DMA_SAR0L)
;;         call outcharhex
;;         
;;         ld hl, #dmamsg2
;;         call outstring
;; 
;;         in0 a, (DMA_DAR0B)
;;         call outcharhex
;;         in0 a, (DMA_DAR0H)
;;         call outcharhex
;;         in0 a, (DMA_DAR0L)
;;         call outcharhex
;; 
;;         ld hl, #dmamsg3
;;         call outstring
;; 
;;         in0 a, (DMA_BCR0H)
;;         call outcharhex
;;         in0 a, (DMA_BCR0L)
;;         call outcharhex
;; 
;;         ld hl, #dmamsg4
;;         call outstring
;; 
;;         pop bc
;;         pop de
;;         pop hl
;;         pop af
;;         ret
;; 
;; 
;; dumpbuf: .ds 16
;; 
;; dump_process_memory:
;;         ; enter with the 64K bank to dump in A (low 4 bits only)
;;         out0 (DMA_SAR0B), a
;; 
;;         ld hl, #0
;;         ld a, #0x02
;;         out0 (DMA_DMODE), a     ; 0x02 - memory to memory, burst mode
;;         xor a
;;         out0 (DMA_SAR0H), a
;;         out0 (DMA_SAR0L), a
;;         ld a, #((OS_BANK + FIRST_RAM_BANK) >> 4)
;;         out0 (DMA_DAR0B), a
;; 
;; nextblock:
;;         ; set dest to our target buffer
;;         ld a, #<dumpbuf
;;         out0 (DMA_DAR0L), a
;;         ld a, #>dumpbuf
;;         out0 (DMA_DAR0H), a
;;         ; 16 bytes
;;         xor a
;;         out0 (DMA_BCR0H), a
;;         ld a, #0x10
;;         out0 (DMA_BCR0L), a
;;         ld a, #0x40
;;         out0 (DMA_DSTAT), a     ; 0x40 - enable DMA channel 0
;;         ; DMA does the copy
;; 
;;         ; print address
;;         call outhl
;;         ld a, #':'
;;         call outchar
;;         ld a, #' '
;;         call outchar
;; 
;;         ; print data
;;         ex de, hl
;;         ld hl, #dumpbuf
;;         ld b, #0x10
;; nextbyte:
;;         ld a, (hl)
;;         call outcharhex
;;         ld a, #' '
;;         call outchar
;;         inc hl
;;         djnz nextbyte
;;         ex de, hl
;; 
;;         call outnewline
;; 
;;         ld de, #0x10
;;         add hl, de
;;         ld a, h
;;         or l
;;         jr nz, nextblock
;;         ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; -----------------------------------------------------------------------------
; COMMON MEMORY BANK
; -----------------------------------------------------------------------------
	.common

        ; MUST arrange for this table to be 32-byte aligned
        ; linked immediately after commonmem.s
interrupt_table:
        .word	z180_irq1               ;     1    INT1 external interrupt - ? disconnected
        .word	z180_irq2               ;     2    INT2 external interrupt - SD card socket event
        .word	z180_irq3               ;     3    Timer 0
        .word	z180_irq_unused         ;     4    Timer 1
        .word	z180_irq_unused         ;     5    DMA 0
        .word	z180_irq_unused         ;     6    DMA 1
        .word	z180_irq_unused         ;     7    CSI/O
        .word	z180_irq8               ;     8    ASCI 0
        .word	z180_irq9               ;     9    ASCI 1
        .word	z180_irq_unused         ;     10
        .word	z180_irq_unused         ;     11
        .word	z180_irq_unused         ;     12
        .word	z180_irq_unused         ;     13
        .word	z180_irq_unused         ;     14
        .word	z180_irq_unused         ;     15
        .word	z180_irq_unused         ;     16

hw_irqvector:	.byte	0
_irqvector:	.byte	0
_need_resched:	.byte	0
_int_disabled:	.byte	0

z80_irq:
        push	af
        xor	a
        jr	z180_irqgo

z180_irq1:
        push	af
        ld	a, 1
        jr	z180_irqgo

z180_irq2:
        push	af
        ld	a, 2
        jr	z180_irqgo

z180_irq3:
        push	af
        ld	a, 3
        ; fall through -- timer is likely to be the most common, we'll save it the jr
z180_irqgo:
        ld	(hw_irqvector), a
        ; quick and dirty way to debug which interrupt is jamming us up ...
        ;    add #0x30
        ;    .export outchar
        ;    call outchar
        pop	af
        jp	interrupt_handler

; z180_irq4:
;         push af
;         ld a, #4
;         jr z180_irqgo
; 
; z180_irq5:
;         push af
;         ld a, #5 
;         jr z180_irqgo
; 
; z180_irq6:
;         push af
;         ld a, #6
;         jr z180_irqgo
; 
; z180_irq7:
;         push af
;         ld a, #7
;         jr z180_irqgo

z180_irq8:
        push	af
        ld	a, 8
        jr	z180_irqgo

z180_irq9:
        push	af
        ld	a, 9
        jr	z180_irqgo

; z180_irq10:
;         push af
;         ld a, #10
;         jr z180_irqgo
; 
; z180_irq11:
;         push af
;         ld a, #11
;         jr z180_irqgo
; 
; z180_irq12:
;         push af
;         ld a, #12
;         jr z180_irqgo
; 
; z180_irq13:
;         push af
;         ld a, #13
;         jr z180_irqgo
; 
; z180_irq14:
;         push af
;         ld a, #14
;         jr z180_irqgo
; 
; z180_irq15:
;         push af
;         ld a, #15
;         jr z180_irqgo
; 
; z180_irq16:
;         push af
;         ld a, #16
;         jr z180_irqgo
z180_irq_unused:
        push	af
        ld	a, 0xFF
        jr 	z180_irqgo

#ifdef CONFIG_SWAP
;
;	Swapping requires the swap out is done on a different stack so we
;	can flip the common of the victim for the write out
;
_swapout:
	pop	de
	pop	hl
	push	hl
	push	de		; HL is now the process to swap
	push	bc
	ld	b,h		; Save the process pointer
	ld	c,l
	ld	de, P_TAB__P_PAGE_OFFSET
	add	hl,de
	ld	a,(hl)		; Get the page info for this process
	ld	hl,0
	add	hl,sp		; get the current SP into a register pair
	ld	sp,swapinstack
	in0	e,(MMU_CBR)	; save the old mapping
	dec	a		; allow for the 56K
	dec	a
	out0	(MMU_CBR),a	; Swap the common to the victim
	push	hl		; Save old stack frame
	push	de		; Save old mapping
	push	bc		; Argument for do_swapout
	call	_do_swapout	; Swap the victim out in its own context
	pop	bc		; discard
	pop	bc		; Recover old mapping
	pop	de		; Recover old stack
	ex	de,hl		; DE is now return value, HL the stack
	di
	out0	(MMU_CBR), c	; Restore map first in case we takn an IRQ
	ld	sp,hl		; Switch stack
	pop	bc		; Recover BC
	ex	de,hl		; Return value back into HL
	jp map_kernel		; Ensure the lower mapping is fixed up if needed
#endif
;
; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
_plt_switchout:
	di
        ; save machine state
        ld	hl,	0 ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
        push	hl	; return code
	push	bc	; register variables
        push	ix
        push	iy
	ld	hl,(__tmp)	; working values for the compiler
	push	hl
	ld	hl,(__hireg)
	push	hl
	ld	hl,(__tmp2)
	push	hl
	ld	hl,(__tmp2+2)
	push	hl
	ld	hl,(__tmp3)
	push	hl
	ld	hl,(__tmp3+2)
	push	hl
	ld	hl,(__retaddr)
	push	hl
        ld	(_udata + U_DATA__U_SP), sp ; this is where the SP is restored in _switchin

        ; no need to stash udata on this platform since common memory is dedicated
        ; to each process.

        ; find another process to run (may select this one again)
        call	_getproc

        push	hl
        call	_switchin

        ; we should never get here
        jp	_plt_monitor

badswitchmsg: .ascii "_switchin: FAIL"
            .byte	13, 10, 0
swapped: .ascii "_switchin: SWAPPED"
            .byte	13, 10, 0

_switchin:
        di
        pop	hl	; return address
        pop	de	; new process pointer (struct p_tab *)
        push	de	; restore stack (WRS: AC thinks this may not be required -- he's probably right!)
        push	hl	; restore stack

        ; probably not reqired since we're only called from kernel code ...
        ; call map_kernel

        ld	hl, P_TAB__P_PAGE_OFFSET
        add	hl, de	; now HL points at the p_page value for the next process

        ; map in the common memory for the new process -- this swaps common
        ; memory and the stack under our feet so let's hope that common memory
        ; contains a copy of this code, eh?

#ifdef CONFIG_SWAP

        ld	a, (hl)
	or	a
	jr	nz, is_resident
	; Swap in the new process (and maybe out an old one)
	ld	sp, swapstack
	ei
	xor	a
	ld	(_int_disabled),a
	push	hl
	push	de
	call	_swapper
	pop	de
	pop	hl
	ld	a,1
	ld	(_int_disabled),a
	di
#endif
is_resident:
	;
	; We have no valid stack at this point
	;
	ld	a, (hl)
        ; out0 (MMU_BBR), a -- WRS: leave the kernel mapped in
	dec	a		; Allow for the fact it's not a full 64K
	dec	a
        out0	(MMU_CBR), a

        ; sanity check: u_data->u_ptab matches what we wanted?
        ld	hl, (_udata + U_DATA__U_PTAB) ; u_data->u_ptab
        or	a		; clear carry flag
        sbc	hl, de		; subtract, result will be zero if DE==IX
        jr	nz, switchinfail

        ; wants optimising up a bit
        ld	ix, (_udata + U_DATA__U_PTAB)
        ; next_process->p_status = P_RUNNING
        ld	(ix + P_TAB__P_STATUS_OFFSET), P_RUNNING

        ;; ; Fix the moved page pointers
        ;; ; Just do one byte as that is all we use on this platform
        ld	a, (ix + P_TAB__P_PAGE_OFFSET)
        ld	(_udata + U_DATA__U_PAGE), a

        ; runticks = 0
        ld	 hl, 0
        ld	(_runticks), hl

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
	;
	; Only from here is the stack valid again
	;
        ld	sp, (_udata + U_DATA__U_SP)

	pop	hl
        ld	(__retaddr),hl
	pop	hl
	ld	(__tmp3+2),hl
	pop	hl
	ld	(__tmp3),hl
	pop	hl
	ld	(__tmp2+2),hl
	pop	hl
	ld	(__tmp2),hl
	pop	hl
	ld	(__hireg),hl
	pop	hl
	ld	(__tmp),hl
        pop	iy
        pop	ix
	pop	bc
        pop	hl ; return code

        ; enable interrupts, if the ISR isn't already running
        ld	a, (_udata + U_DATA__U_ININTERRUPT)
	ld	(_int_disabled),a
        or	a
        ret	nz ; in ISR, leave interrupts off
        ei
        ret ; return with interrupts on

switchinfail:
        ; something went wrong and we didn't switch in what we asked for
        call	outhl
        ld hl,	badswitchmsg
        call	outstring
        jp	_plt_monitor

map_kernel_restore:
map_buffers:
map_kernel_di:
map_kernel: ; map the kernel into the low 60K, leaves common memory unchanged
        push	af
#ifdef DEBUGBANK
        ld a,	'K'
        call	outchar
#endif
	ld a,	0xFD		; Split at D000 and F000
	out0	(MMU_CBAR),a
	ld	a, 0x33		; Low 8K of RAM appears at D000
	out0	(MMU_BBR),a
        pop	af
        ret

map_proc_always_di:
map_proc_always: ; map the process into the low 60K based on current common mem (which is unchanged)
        push	af
#ifdef DEBUGBANK
        ld a,	'='
        call	outchar
#endif
	; Switch to a flat user mapping with common
	ld	a, 0xF0
	out0	(MMU_CBAR),a
	; Map the right user page. We don't flip the common here */
        ld	a, (_udata + U_DATA__U_PAGE)
        out0	(MMU_BBR), a
#ifdef DEBUGBANK
        call	outcharhex
#endif
        ; MMU_CBR is left unchanged
        pop	af
        ret

map_for_swap:
#ifdef DEBUGBANK
	push	af
        ld	a, 's'
        call	outchar
	pop	af
	push	af
#endif
	out0	(MMU_BBR),a	; the page is passed in A, so we just do an out0
	ld	a, 0xF0
	out0	(MMU_CBAR),a
#ifdef DEBUGBANK
        call	outcharhex
	pop	af
#endif
	ret

map_save_kernel:   ; save the current process/kernel mapping
        push	af
        in0	a, (MMU_BBR)
        ld	(map_store), a
        in0	a, (MMU_CBAR)
        ld	(map_store + 1), a
#ifdef DEBUGBANK
        ld	a, 'S'
        call	outchar
#endif
	ld	a,0xFD
	out0	(MMU_CBAR),a
        ld	a, 0x33
        out0	(MMU_BBR), a
        pop	af
        ret

map_restore: ; restore the saved process/kernel mapping
        push	af
#ifdef DEBUGBANK
        ld	a, #'-'
        call	outchar
#endif
        ld	a, (map_store + 1)
	out0	(MMU_CBAR),a
	ld	a, (map_store)
        out0	(MMU_BBR), a
#ifdef DEBUGBANK
        call	outcharhex
#endif
        pop	af
        ret

map_store:  ; storage for map_save/map_restore
        .byte	0	; BBR
	.byte	0	; CBAR

#ifdef CONFIG_SWAP
	.common
	; Combining these is tricky so for the sake of 128 bytes or so we
	; don't try at this point.
	.ds 128
swapstack:
	.ds 128
swapinstack:
#endif

_program_vectors:
	call	map_proc_always
	ld	a,#0xC3
	ld	(0),a
	ld	(0x38),a
	ld	(0x66),a
	ld	hl,#null_handler
	ld 	(0x01),hl
	ld	hl,#nmi_handler
	ld	(0x67),hl
	ld	hl,#interrupt_handler
	ld	(0x39),hl
	jp	map_kernel

