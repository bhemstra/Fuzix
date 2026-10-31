;
;	6502 version
;
        .export _plt_switchout
        .export _switchin
        .export _dofork
	.export _ramtop

#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

	.common

; ramtop must be in common for single process swapping cases
; and its a constant for the others from before init forks so it'll be fine
; here
_ramtop:
	.word $FE00

; Switchout switches out the current process, finds another that is READY,
; possibly the same process, and switches it in.  When a process is
; restarted after calling switchout, it thinks it has just returned
; from switchout().
_plt_switchout:
	sei

;
;	Put the C stack on the CPU stack, and store that in U_SP
;
	lda	#0		; return code
	pha
	pha
	lda	@sp		; C stack
	pha
	lda	@sp+1
	pha
	tsx
	stx	_udata + U_DATA__U_SP	; Save it

        ; find another process to run (may select this one again) returns it
        ; in x,a
        jsr	_getproc
	jmp	x1		; will be patched for banking
	nop
x1:
	jsr	__push
        jsr	_switchin
        ; we should never get here
        jsr	_plt_monitor

badswitchmsg:
	.ascii	"_switchin: FAIL"
	.byte	13, 10, 0

;
;	Any switch to another task is a swap. We should never be asked
;	to switch to the task in memory (ie current).
;
_switchin:
	sei
	jsr	__pop
	; XA holds the process to switch in
	sta	@tmp2
	stx	@tmp2+1
	; Take a second saved set as we are going to swap stacks and ZP
	; with a CPU that hasn't got sufficient registers to keep it on
	; CPU
	sta	switch_proc_ptr
	stx	switch_proc_ptr+1

;	jsr	outxa

	;
	;	We are going to read in memory over the C stack so we
	;	need a private stack. The actual stack to use when loaded
	;	is in the ZP we will restore in a bit. For now use the
	;	scratch C stack
	;
	lda	#<swapstack
	ldx	#>swapstack
	sta	@sp
	stx	@sp+1

	; Check if we are the task in memory anyway
	ldy	#P_TAB__P_PAGE_OFFSET
	lda	(@tmp2),y
	jne	not_swapped

	lda	switch_proc_ptr
	ldx	switch_proc_ptr+1
	jsr	__push
	jsr	_swapinout
	jmp	x2
	nop
x2:
	.export XXX
XXX:

	;	We can swap ourself out on our own stack just
	;	fine. What ends up on disk has the correct S area
	;	and mostly correct ZP. We can wory about ZP on the return

	; Now the hairy bit. We have a last sector to read in that
	; holds ZP and S for the new task. We have to do this one inline.
	;
	; _swapper ends with the IDE done the block before the one we need
	; so we need to do this last one in asm with no stack!

	; Point at LBA holding S and ZP

waitbusy:
	lda	0xDE27		; wait not busy
	bmi	waitbusy

	; Move LBA on one
	inc	0xDE23
	bne	lbaset
	inc	0xDE24
	bne	lbaset
	inc	0xDE25
lbaset:
	; One sector to read
	lda	#1
	sta	0xDE22		; 1 sector

waitbusy2:
	lda	0xDE27		; wait not busy
	bmi	waitbusy2

	lda	#0x20
	sta	0xDE27		; READ
waitdrq:
	lda	0xDE27
	and	#0x08
	beq	waitdrq

	;
	; We need to avoid using the stack or ZP at this point

	; Discard the memory mapping register bits
	lda	0xDE20
	lda	0xDE31
	; Copy ZP
	ldx	#2
load_zp:
	lda	0xDE20
	sta	0x0000,x
	inx
	lda	0xDE31
	sta	0x0000,x
	inx
	bne	load_zp
load_s:
	lda	0xDE20
	sta	0x0100,x
	inx
	lda	0xDE31
	sta	0x0100,x
	inx
	bne	load_s

waitbusy3:
	lda	0xDE27
	bmi	waitbusy3

	lda	0xDE27		; Status (TODO check & 1)

	; We are now in the old tasks ZP and S but our S register
	; points to the wrong place. Fix this so we have a usable stack

	; We now have a valid ZP and S again

not_swapped:
	ldx	_udata + U_DATA__U_SP
	txs

	lda	switch_proc_ptr
	sta	@tmp2
	cmp	_udata + U_DATA__U_PTAB
	bne	switchinfail
	lda	switch_proc_ptr+1
	sta	@tmp2+1
	cmp	_udata + U_DATA__U_PTAB+1
	bne	switchinfail

	lda	#P_RUNNING
	ldy	#P_TAB__P_STATUS_OFFSET
	sta	(@tmp2),y

	lda	#0
	sta	_runticks
	sta	_runticks+1

	;	Recover the saved stack state
	pla
	sta	@sp+1
	pla
	sta	@sp
	lda	_udata + U_DATA__U_ININTERRUPT
        beq	swtchdone		; in ISR, leave interrupts off
	cli
swtchdone:
	pla		; Return code
	tax
	pla
        rts

switchinfail:
	lda	@tmp2+1
	jsr	outcharhex
	lda	@tmp2
	jsr	outcharhex
        lda	#<badswitchmsg
	ldx	#>badswitchmsg
        jsr	outstring
	; something went wrong and we didn't switch in what we asked for
        jmp	_plt_monitor

;
;	Called from _fork. We are in a syscall, the uarea is live as the
;	parent uarea. The kernel is the mapped object.
;
_dofork:
;        ; always disconnect the vehicle battery before performing maintenance
        sei	 ; should already be the case ... belt and braces.

	; new process in X, get parent pid into y
	jsr	__pop

	sta	fork_proc_ptr
	stx	fork_proc_ptr+1

        ; Save the stack pointer and critical registers.
	; 6502 at least doesn't have too many of those 8)

        ; When this process (the child) is switched back in, it will be as if
        ; it returns with the fork return of 0
	; FIXME can we just drop these and ret 0 given doing parent first ?
	lda	#0
	pha
	pha
        ; save kernel stack pointer -- when it comes back in the child we'll be in
        ; _switchin which will immediately return (appearing to be _dofork()
	; returning) the child PID.
	lda	@sp
	pha
	lda	@sp+1
	pha
	.export YYY
YYY:
	tsx
	stx	_udata + U_DATA__U_SP

	; Get a workspace for the childs udata and kstack

	jsr	_tmpbuf
	jmp	x4
	nop
x4:
	sta	tmpbuf_ptr
	stx	tmpbuf_ptr+1

	; XA now points at a 512 byte workspace
	sta	@tmp
	stx	@tmp+1

	lda	#<_udata
	sta	@tmp1
	lda	#>_udata
	sta	@tmp1+1
	ldy	#0
	ldx	#2
	; Copy the parent udata and kstack into the child
udcopy:
	lda	(@tmp1),y
	sta	(@tmp),y
	iny
	bne	udcopy
	inc	@tmp+1
	inc	@tmp1+1
	dex
	bne	udcopy

	; Ok we have the udata stashed in the tmpbuf

	;  makeproc(proc, &newudata);
	lda	tmpbuf_ptr
	ldx	tmpbuf_ptr+1
	jsr	__push
	lda	fork_proc_ptr
	ldx	fork_proc_ptr+1
	jsr	__push

	; Back into C to turn the tmpbuf into the child udata
	jsr	_makeproc
	jmp	x5
	nop
x5:

        ; now we're in a safe state for _switchin to return in the parent
	; process.

	lda	tmpbuf_ptr
	ldx	tmpbuf_ptr+1
	jsr	__push

	lda	fork_proc_ptr
	ldx	fork_proc_ptr+1
	jsr	__push

	; swapout_new(ptptr, &newudata)
	jsr	_swapout_new
	jmp	x6
	nop
x6:
	lda	tmpbuf_ptr
	ldx	tmpbuf_ptr+1
	jsr	__push
	jsr	_tmpfree
	jmp	x7
	nop
x7:
	; Now swap is done clean up the stack
	pla
	pla
	pla
	pla

	; Child is now on disk (yay)
	lda	fork_proc_ptr
	ldx	fork_proc_ptr+1
	sta	@tmp
	stx	@tmp+1
	ldy	#P_TAB__P_PID_OFFSET+1
	lda	(@tmp),y
	tax
	dey
	lda	(@tmp),y

	; XA is now the PID

        rts

	.commondata

switch_proc_ptr:
	.word	0
fork_proc_ptr:
	.word	0 ; (C type is struct p_tab *) -- address of child process p_tab entry
tmpbuf_ptr:
	.word	0

	.ds	256
swapstack:
