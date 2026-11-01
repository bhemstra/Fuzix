	.abs
	.org 0x6100

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

;
;	This is our precious block of fixed RAM we need to be under
;	256 bytes

	.export kbank
	.export hbank

kbank:	.byte	0		; current kernel bank
hbank:	.byte	0		; upper bank
ksave:	.byte	0		; saved kernel bank
hsave:	.byte	0		; upper bank save
syscarg:.ds	8		; 4 x 2 byte argments
syscnum:.byte	0		; syscall number
sigret:	.byte	0		; signal return code
sigvec:	.word	0		; signal vector for return


	.export interrupt_handler

interrupt_handler:	; with an IRQ frame in place
	ldd	kbank		; save old bank info
	std	ksave
	lda	#KHIGH		; no valid stack from here
	sta	hipage		; switch in kernel upper
	sta	lopage		; switch to ROM0 (overlay1 )
	jmp	do_irq
irqout:
	ldx	#0		; low memory writes switch cartridge bank
	abx
	sta	,x		; switch the ROM page back
	rti			; and return from the interrupt

	.overlay1

null_handler:		; ROM0 alwyas mapped for user space
	orcc	#0x10
	lda	#KHIGH	
	sta	hipage	; Kernel mapped (no stack)
	tst	_udata + U_DATA__U_INSYS
	bne	trap_illegal
	lda	_udata + U_DATA__U_PAGE
	ldx	_udata + U_DATA__U_PTAB
	sta	hipage	; map back
	ldd	#9
	pshs	d
	tfr	x,d
	ldx	#39	; kill
	; We are back as if we are a user app
	jsr	syscall_fa ;	kill(self, SIGKILL)
	; We will get here only if the SIGKILL didn't work
	lda	#KHIGH
	sta	hipage
trap_illegal:
	lds	#kstack_top
	ldx	#illegalmsg
	jsr	outstring
	jsr	_plt_monitor
illegalmsg:
	.ascii	"[trap_zero]"
	.byte	13,10,0

reintr:
	pshs	d
	jsr	_plt_reinterrupt
	puls	d
	rti
do_irq:
	; ROM handlers were tricked into returing into our handler
	; Now we can do our own handling
	tst	_udata + U_DATA__U_ININTERRUPT
	bne	reintr
	; Stack and map magic time. We have the kernel mapped correctly
	; but we have no valid stack so get one
	tfr	s,x
	lds	#istack_top
	pshs	x		; save old stack on new
	lda	#1
	sta	_udata + U_DATA__U_ININTERRUPT
	; Kernel is mapped flags are set up
	pshs	d
	jsr	_plt_interrupt
	puls	d
	; Returning from the kernel IRQ path
	clr	_udata + U_DATA__U_ININTERRUPT
	lda	_udata + U_DATA__U_INSYS
	bne	intret_x		; Returning from within kernel
	; Returning to user space, check if we need to pre-empt
	lda	_need_resched
	bne	no_switch
	; The basic idea here is to do the same as if we did a null
	; syscall. This is a bit tricky with all this bank and stack
	; flipping
	ldx	,s		; get the user stack pointer
	clr	_need_resched
	stx	_udata + U_DATA__U_SYSCALL_SP
	lds	#kstack_top
	jsr	_chksigs
	ldx	_udata + U_DATA__U_PTAB
	lda	P_TAB__P_STATUS_OFFSET,x
	cmpa	#P_RUNNING
	bne	not_running
	lda	#P_READY
	sta	P_TAB__P_STATUS_OFFSET,x
not_running:
	jsr	_plt_switchout
	;	We will resume here after the task is rescheduled
	;	and on the kernel stack as if coming out of a syscall
	;	now on the user stack but not valid
	lds	_udata + U_DATA__U_SYSCALL_SP	
	;	TODO - handle signals on this exit path too
	ldd	ksave		; A = low B = hi
	stb	hipage		; set the upper memory valid
	jmp	irqout		; via stub page as switching low
	
no_switch:
	jsr	_chksigs
	ldb	_udata + U_DATA__U_CURSIG
	beq	intret_x
	clr	_udata + U_DATA__U_CURSIG
	; Ok we have a signal to dispatch from user
	ldx	#_udata + U_DATA__U_SIGVEC
	abx
	abx
	ldu	,x
	beq	intret_x
	clr	,x+
	clr	,x
	; Ok ready to do the signal exit path
	; U is our vector B is our signal
	puls	x
	tfr	x,s
	;	Now have a valid user stack but not a map
	lda	_udata + U_DATA__U_PAGE
	sta	hipage
	;	Now user stack, kernel data unmapped
	clra
	pshs	d		; signal
	andcc	#0xef
	jsr	,u		; call the handler
	orcc	#0x10
	puls	d		; clean up
	jmp	irqout		; switch the low page and reti
	
intret_x:
	; Returning back to the same user task
	puls	x
	tfr	x,s
	; Valid stack
	ldd	ksave		; A = low B = hi
	stb	hipage		; set the upper memory valid
	jmp	irqout		; via stub page as switching low


;
;	Entering user space
;

	.overlay1
	.export _doexec

_doexec:
	tfr	d,x		; jump address
	orcc	#0x10		; interrupts off
	ldb	_udata + U_DATA__U_PAGE
	ldy	_udata + U_DATA__U_CODEBASE
	clr	_udata + U_DATA__U_INSYS
	lds	_udata + U_DATA__U_ISP
	stb	hipage		; user process mapped high
				; fixed low is already valid
	andcc	#0xef		; interrupts back on
	jmp	,x

;
;	Syscall is one of the easier paths. We know that we are in ROM0
;
	.overlay1

syscall_va:
	pshs	cc,u		; onto user stack
        orcc	#0x10
	stb	syscnum
	leax	7,s
	ldu	#syscarg	; copy arguments
	ldd	,x++
	std	,u++
	bra	syscall
syscall_fa:
	pshs	cc,u
        orcc	#0x10
	ldu	#syscarg
	std	,u++
	tfr	x,d
	stb	syscnum	
	leax	7,s
syscall:
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x
	std	,u
	; Ok arguments are save, stuff is stack on user
	; all as we need. Now off we go
	tfr	s,x		; save old stack pointer
	ldb	#KHIGH
	stb	hipage		; switch the upper bank to kernel
				; stack is no longer safe
	lds	#kstack_top	; onto kernel stack
	stx	_udata + U_DATA__U_SYSCALL_SP
	; Now propogate the arguments into the udata
	ldx	#syscarg
	ldu	#_udata + U_DATA__U_ARGN
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x++
	std	,u++
	ldd	,x
	std	,u
	ldb	syscnum
	stb	_udata + U_DATA__U_CALLNO
	; We now look like the kernel expects
	andcc	#0xEF
	; May be inter-bank
	pshs	d
	jsr	_unix_syscall
	puls	d
	orcc	#0x10
	clr	_udata + U_DATA__U_INSYS
	ldb	_udata + U_DATA__U_CURSIG
	stb	sigret
	beq	nosig
	clr	_udata + U_DATA__U_CURSIG
	ldx	#_udata + U_DATA__U_SIGVEC
	abx
	abx
	ldu	,x
	clr	,x+
	clr	,x
	stu	sigvec
	ldy	_udata + U_DATA__U_RETVAL
	ldx	_udata + U_DATA__U_ERROR
	; Ok we now have the state sorted
	; U and X hold the return states
	; sigret and sigvec hold the info for a signal based return
	; back to user stack (invalid at this point)
	lds	_udata + U_DATA__U_SYSCALL_SP
	; Get the process mapping (may have changed if pre-empted and
	; swapped
	lda	_udata + U_DATA__U_PAGE
	sta	hipage
	; Stack is now valid again
	ldb	sigret
	bne	via_signal
nosig:
	tfr	y,d
	; and back to user space
	puls	cc,u,pc
via_signal:
	; invoke signal handler
	pshs	x,y		; save syscall return
	clra			; b is signal code
	pshs	d		; stack signal number
	ldx	sigvec		; vector
	andcc	#0xEF		; IRQ on
	jsr	,x		; call handler
	puls	d,x,y		; clean up and recover return info
	tfr	y,d		; in the right place
	puls	cc,u,pc		; and out

	.export _sys_stubs

_sys_stubs:
	jmp	syscall_fa
	jmp	syscall_va

; Copies of stuff we generally need from the normal lowlevel but tweaked
; for our ROM0 setup
;
;	Check for a 6309 (as per The 6309 Book)
;
	.export	_set_cpu_type
_set_cpu_type:
	pshs	d
	.word	0x1043
	cmpb	1,s
	puls	d
	beq	is8
	lda	#1
	sta	_sys_cpu_feat
is8:
	rts

	.data
	.export _sys_cpu
	.export _sys_cpu_feat

_sys_cpu:
	.byte 4
_sys_cpu_feat:
	.byte 0

	.overlay1

	.export outstring

; outstring: Print the string at X until 0 byte is found
; destroys: A, X
outstring:
	lda	,x+
	beq	outstrdone
        jsr	outchar
        bra	outstring
outstrdone:
	rts

	.export outstringhex

; print the string at (X) in hex (continues until 0 byte seen)
outstringhex:
	lda	,x+
	beq	outstrdone
        jsr	outcharhex
	lda	#32
	jsr	outchar
        bra	outstringhex

	.export outnewline

; output a newline
outnewline:
        lda	#0x0d  ; output newline
        jsr	outchar
        lda	#0x0a
        jsr	outchar
        rts

	.export outx

outx:  ; prints X
	pshs	d
	tfr	x,d
	bsr	outd
	puls	d,pc

	.export outy

outy:  ; prints Y
	pshs	d
	tfr	y,d
	bsr	outd
	puls	d,pc

	.export outd

outd:  ; prints D in hex.
	pshs	b
	bsr	outcharhex
	puls	a
	; FALL THROUGH

	.export outcharhex
; print the byte in A as a two-character hex value
outcharhex:
	pshs	a
        lsra
        lsra
        lsra
        lsra
        bsr	outnibble
	puls	a
	; FALL THROUGH

; print the nibble in the low four bits of A
outnibble:
        anda	#0x0f ; mask off low four bits
        cmpa	#9
        ble	num    ; less than 10?
        adda	#0x07 ; start at 'A' (10+7+0x30=0x41='A')
num:    adda	#0x30 ; start at '0' (0x30='0')
        jsr	outchar
        rts

	.overlay1

; Compiler helpers

	.export _swab

_swab:	exg	a,b
	rts

	.export _memset

_memset:
	pshs	u,d		; d is the address
	tfr	d,u
	ldx	8,s		; count
	beq	nowork
	ldb	7,s		; byte
msl:	stb	,u+
	leax	-1,x
	bne	msl
nowork:
	puls	d,u,pc

	.export _memcpy

_memcpy:
	pshs	u,d
	tfr	d,u		; dest
	ldx	6,s		; src
	ldy	8,s		; count
	beq	nowork
mcl:	lda	,x+
	sta	,u+
	leay	-1,y
	bne	mcl
	puls	d,u,pc

	.export _strlen

_strlen:
	tfr	d,x
	ldd	#0xFFFF
next:
	addd	#1
	tst	,x+
	bne	next
	rts
