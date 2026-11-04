;
;	6809 version
;
        .export _plt_switchout
        .export _switchin
        .export _dofork
	.export _ramtop

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.commondata

	; ramtop must be in common although not used here
_ramtop:
	.word	0

newpp:
	.word	0

	common

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
;
_plt_switchout:
	orcc #0x10		; irq off

        ; save machine state, including Y and U used by our C code
	clra
	clrb
        ; return code set here is ignored, but _switchin can 
        ; return from either _switchout OR _dofork, so they must both write 
        ; U_DATA__U_SP with the following on the stack:
	pshs	d,u
	sts	U_DATA__U_SP	; this is where the SP is restored in _switchin

	; Stash the uarea into process memory bank
	; FIXME could map in only the bank that holds the stash
	jsr	map_proc_always

	ldx	#_udata
	ldu	#U_DATA_STASH
stash:	ldd	,x++
	std	,u++
	cmpx	#_udata+U_DATA__TOTALSIZE
	bne	stash

	; get process table in
	jsr	map_kernel

        ; find another (or same) process to run, returned in D
        jsr	_getproc
        jsr	_switchin
        ; we should never get here
        jsr _plt_monitor

badswitchmsg:
	.ascii "_switchin: FAIL"
	.byte 13, 10, 0


; new process pointer is in D
_switchin:
        orcc #0x10		; irq off

	tfr	d,x
	stx	newpp
	; get process table
	ldx	P_TAB__P_PAGE_OFFSET,x	; process map pointer

	; check if we are switching to the same process
	cmpx	U_DATA__U_PAGE
	beq	nostash

	; process was swapped out?
	cmpx	#0
	bne	not_swapped
	jsr	_swapper		; void swapper(ptptr p)
	ldx	newpp
	ldx	P_TAB__P_PAGE_OFFSET,x

not_swapped:
	jsr	map_proc_a
	
	; fetch uarea from process memory
	ldx	#U_DATA_STASH
	ldu	#_udata
stashb:	ldd	,x++
	std	,u++
	cmpx	#U_DATA_STASH+U_DATA__TOTALSIZE
	bne	stashb

	; we have now new stacks so get new stack pointer before any jsr
	lds	 U_DATA__U_SP

	; get back kernel page so that we see process table
	jsr	map_kernel

nostash:
	ldx	 newpp
        ; check u_data->u_ptab matches what we wanted
	cmpx	_udata + U_DATA__U_PTAB
        bne	switchinfail

	lda	#P_RUNNING
	sta	P_TAB__P_STATUS_OFFSET,x

	; fix any moved page pointers
	ldx	P_TAB__P_PAGE_OFFSET,x
	stx	_udata + U_DATA__U_PAGE

	clra	
	clrb
	std	_runticks

        ; restore machine state -- note we may be returning from either
        ; _switchout or _dofork
        lds	U_DATA__U_SP

        ; enable interrupts, if the ISR isn't already running
	lda	U_DATA__U_ININTERRUPT
        bne	swtchdone ; in ISR, leave interrupts off
	andcc	#0xef
swtchdone:
        puls	d,u,pc ; return code and saved U and Y

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
_dofork:
	tfr	d,x
        ; always disconnect the vehicle battery before performing maintenance
        orcc	#0x10	 ; should already be the case ... belt and braces.

	; new process in X, get parent pid into D

	stx	fork_proc_ptr
	ldd	P_TAB__P_PID_OFFSET,x

        ; Save the stack pointer and critical registers (Y and U used by C).
        ; When this process (the parent) is switched back in, it will be as if
        ; it returns with the value of the child's pid.
        pshs	d,u ;  x has p->p_pid from above, the return value in the parent

        ; save kernel stack pointer -- when it comes back in the parent we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) and with X (ie return code) containing the child PID.
        ; Hurray.
        sts	U_DATA__U_SP

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	jsr	fork_copy	; copy process memory to new bank
				; and save parents uarea

	; We are now in the kernel child context

        ; now the copy operation is complete we can get rid of the stuff
        ; _switchin will be expecting from our copy of the stack.
	leas	2,s

	ldx	#_udata
	pshs	x
        ldd	fork_proc_ptr
        jsr	_makeproc
	leas	2,s

	; any calls to map process will now map the childs memory

        ; in the child process, fork() returns zero.
	clra
	clrb
        ; runticks = 0;
	std	_runticks
	;
	; And we exit, with the kernel mapped, the child now being deemed
	; to be the live uarea. The parent is frozen in time and space as
	; if it had done a switchout().
	; Return is 0, discard stashed D into X
	puls	x,u,pc

fork_copy:
; copy the process memory to the new banks and stash parent uarea to old banks
	lda	#6			; counter, decremented until negative
	pshs	a
	ldx	fork_proc_ptr
	ldx	P_TAB__P_PAGE_OFFSET,x	; new bank map
	ldy	_udata + U_DATA__U_PAGE	; old bank map
cpbank:	lda	,y+			; src
	cmpa 	,y			; repeated bank = last
	bne	notlst
	clr	,s
notlst:	ldb	,x+			; dst
	jsr	 copybank			; clobbers only A,B
	dec	,s
	bpl	cpbank
	leas	1,s			; drop counter

; stash parent uarea (including kernel stack)
	ldx	_udata + U_DATA__U_PAGE		; old bank
	jsr	map_proc_a
	ldx	#_udata
	ldu	#U_DATA_STASH
stashf:	ldd	,x++
	std	,u++
	cmpx	#_udata+U_DATA__TOTALSIZE
	bne	stashf
	jsr	map_kernel
	ldx	fork_proc_ptr
	ldx	P_TAB__P_PAGE_OFFSET,x	; child's map
	jmp	mmu_remap_x		; leave with child mapped in MMU user task
	; --- we are now on the stack copy, parent stack is locked away ---
	; this stack is copied so safe to return on

