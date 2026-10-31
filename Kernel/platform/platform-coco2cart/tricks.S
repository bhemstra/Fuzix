;
;	TODO: udata needs to be in common space so swap needs to be smarter
;	about split udata
;
        .export _plt_switchout
        .export _switchin
        .export _dofork
	.export _ramtop

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.common

	; ramtop must be in common although not used here
_ramtop:
	.word 0

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
;
; 
; This function can have no arguments or auto variables.
_plt_switchout:
	orcc	#0x10		; irq off

        ; save machine state, including Y and U used by our C code
        clra
	clrb ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
	pshs	d,u
	sts	_udata + U_DATA__U_SP	; this is where the SP is restored in _switchin

        ; find another (or same) process to run, returned in D
        jsr	_getproc
        jsr	_switchin
        ; we should never get here
        jsr	_plt_monitor

badswitchmsg:
	.ascii "_switchin: FAIL"
        .byte 13
	.byte 10
	.byte 0

newpp:   .word 0

; new process pointer is in D
_switchin:
	tfr	d,x
        orcc	#0x10		; irq off

	stx	newpp
	inc	_inswap
	; get process table
	lda	P_TAB__P_PAGE_OFFSET+1,x	; LSB of 16-bit page no
	bne	not_swapped

	lds	#0x0200		;	$1xx is vectors and swap stack

	ldx	_udata + U_DATA__U_PTAB
	ldb	P_TAB__P_PAGE_OFFSET+1, x
	beq	not_swapout		;	it's dead don't swap it out
	ldd	_udata + U_DATA__U_PTAB
	andcc	#0xef
	jsr	_swapout		;	swapout(pptr)
not_swapout:
	ldd	newpp
	andcc	#0xef
	jsr	_swapper		; 	fetch our process
	ldx	newpp
	lda	#1
	sta	P_TAB__P_PAGE_OFFSET+1,x	; marked paged in
not_swapped:
	orcc	#0x10
	dec	_inswap
	; we have now new stacks so get new stack pointer before any jsr
	lds	_udata + U_DATA__U_SP

	; get back kernel page so that we see process table
	jsr	map_kernel

	ldx	newpp
        ; check u_data->u_ptab matches what we wanted
	cmpx	_udata + U_DATA__U_PTAB
        bne	switchinfail

	lda	#P_RUNNING
	sta	P_TAB__P_STATUS_OFFSET,x

	; fix any moved page pointers
	lda	P_TAB__P_PAGE_OFFSET+1,x
	sta	_udata + U_DATA__U_PAGE+1

	ldd	#0
	std	_runticks

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
        lds	_udata + U_DATA__U_SP

        ; enable interrupts, if the ISR isn't already running
	lda	_udata + U_DATA__U_ININTERRUPT
        bne	swtchdone ; in ISR, leave interrupts off
	andcc	#0xef
swtchdone:
        puls	d,u,pc ; return code and saved U

switchinfail:
	jsr	outx
        ldx	#badswitchmsg
        jsr	outstring
	; something went wrong and we didn't switch in what we asked for
        jmp	_plt_monitor

	.data

fork_proc_ptr:
	.word	0 ; (C type is struct p_tab *) -- address of child process p_tab entry

	.common
;
;	Called from _fork. We are in a syscall, the uarea is live as the
;	parent uarea. The kernel is the mapped object.
;
;	With the re-interrupt changes we can now do a lot of this safely
;	with interrupts enabled. 
;
_dofork:
	; new process in D so make sure D is 0 in the child image

	std	fork_proc_ptr
	clra
	clrb	; child returns 0

        ; Save the stack pointer and critical registers (Y and U used by C).
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        pshs	d,u ;  d has p->p_pid from above, the return value in the parent

        ; save kernel stack pointer -- when it comes back in for the childt we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) and with X (ie return code) containing the child PID.
        ; Hurray.
        sts	_udata + U_DATA__U_SP

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	; Re-enable interrupts as the buffer fetch onwards could do I/O and
	; we want it to feel smooth. makeproc will turn ints off/on as
	; needed

	andcc	#0xEF
	; Copy the parent properties into a temporary udata buffer
	jsr	_tmpbuf
	tfr	d,u
	pshs	u
	ldx	#_udata
udsave:
	ldd	,x++
	std	,u++
	cmpx	#_udata+U_DATA__TOTALSIZE
	bne	udsave

	; Buffer we stacked above is still top of stack
	puls	u
	pshs	u
	ldd	fork_proc_ptr
	jsr	_makeproc
	leas	2,s
	;	U was preserved by makeproc
	pshs	u
	ldd	fork_proc_ptr
	jsr	_swapout_new
	leas	2,s
	;	U was preserved by swapout_new
	tfr	 u,d
	jsr	_tmpfree

	; The child is now on disk, the parent is still running. This is
	; good, it reduces thrash
	ldx	fork_proc_ptr
	ldd	P_TAB__P_PID_OFFSET,x
	; Clean up and return child pid
	; TODO - for now return with ints off as we were called. This should
	; eventually go away
	orcc	#$10
	; Toss the spare value into X so we preserve D
	puls	x,u,pc
