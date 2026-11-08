;
;	C64 8bit Experiments
;

	.export init_early
	.export init_hardware
	.export _program_vectors
	.export map_kernel
	.export map_proc
	.export map_proc_always
	.export map_save_kernel
	.export map_restore

	.export _unix_syscall_i
	.export _plt_interrupt_i
	.export plt_doexec

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore
	.export vector
	.export _sys_stubs

#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

;
;	Standard compiler zero page then anything private to the port
;	then @usp needs to match the start of the userspace ZP range
;
	.zp

	.export sp
	.export hireg
	.export tmp
	.export tmp1
	.export tmp2
	.export tmp3
	.export tmp4
	.export	tmp5
	.export reg1
	.export reg2
	.export reg3
	.export reg4

	.zp


	.export usp

sp:	.word	0
hireg:	.word	0
tmp:	.word	0
tmp1:	.word	0
tmp2:	.word	0
tmp3:	.word	0
tmp4:	.word	0
tmp5:	.word	0
reg1:	.word	0
reg2:	.word	0
reg3:	.word	0
reg4:	.word	0

usp:	.word	0

	.common

_plt_monitor:
_plt_reboot:
	sei			; TODO
	jmp _plt_reboot

___hard_di:
	php
	sei			; Save old state in return to C
	pla			; Old status
	rts
___hard_ei:
	cli			; on 6502 cli enables IRQs!!!
	rts

___hard_irqrestore:
	ldy	#0
	lda	(@sp),y
	pha
	plp
	jmp	__add1sp

	.code			; TODO can we get this into discard ?

init_early:
	rts

init_hardware:
	lda	#0x0E
	sta	0xD020
	lda	#0x06
	sta	0xD021
	lda	#64
	sta	_ramsize
	lda	#48
	sta	_procmem
	lda	#0
	sta	_procmem+1
	sta	_ramsize+1
	lda	0x0314		; old IRQ vector
	sta	oldvec
	lda	0x0315
	sta	oldvec+1
	jsr	program_vectors_k
	lda	#0xEA
	sta	0xD012		; ???
	sta	@0xCC		; Turn off ROM cursor flasher
	jsr	_vtinit
	jmp	x0
	nop
x0:	rts

	.commondata

oldvec:	.word	0

old_kbank:
	.byte	0
old_kmap:
	.byte	0
old_mmu:
	.byte	0

	.literal

	; copied into the stubs of each binary
_sys_stubs:
	jmp	syscall_entry
	.byte	0
	.word	0
	.word	0
	.word	0
	.word	0
	.word	0
	.word	0

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.common

_program_vectors:
	; we are called, with interrupts disabled, by both newproc() and crt0
	; will exit with interrupts off
	sei
	;
	jsr	__pop
	; C argument into XA - just pass it on_
	jsr	map_proc
	jsr	program_vectors_k
	jmp	map_kernel

program_vectors_k:
	lda	#<vector
	sta	$FFFE
	lda	#>vector
	sta	$FFFF
	lda	#<nmi_handler
	sta	$FFFA
	lda	#>nmi_handler
	sta	$FFFB
	lda	#<vector2
	; Set the vector via the ROM services
	sta	$0314
	lda	#>vector2
	sta	$0315
	rts

;
;	On a fully switching system with far copies like the 6509 this is
;	all basically a no-op
;
;	On a banked setup the semantics are:
;
;	map_proc_always()
;	Map the current process (ie the one with the live uarea)
;
;	map_kernel()
;	Map the kernel
;
;	map_proc(pageptr [in X,A])
;	if pageptr = 0 then map_kernel
;	else map_proc using the pageptr
;
;	map_save
;	save the current mapping
;
;	map_restore
;	restore the saved mapping
;
;	save/restore are used so that the kernel can play with its internal
;	banking/mappings without having to leave interrupts off all the time
;
;	ptr1 and tmp1 may be destroyed by these methods, but no other
;	temporaries.
;
;
map_proc_always:
	pha
	; HIRAM, LORAM off and CHAREN on
	; Gives us a full RAM map with no I/O (except 0/1)
	lda	@0x01
	and	#0xFC
	sta	@0x01
	pla
	rts
;
;	X,A points to the map table of this process
;	We don't care though - we only have one map
;
map_proc:
	cmp	#0
	bne	map_proc_always
	cpx	#0
	bne	map_proc_always
;
;	Need to adjust this to the map_kernel and save semantic ?
;
;	HIRAM, LORAM and CHAREN high
;	Cartridge at 8000-BFFF
;	RAM at C000-CFFF
;	I/O at D000-DFFF
;	KERNAL at E000-FFFF	(we have no choice on that one)
;
map_kernel:
	pha
	lda	@mmu		; Switch the banked cart into the map
	ora	#7
	sta	@mmu
	pla
	rts

;
;	Restore the user or previous kernel mapping post IRQ
;
map_restore:
	pha
	txa
	pha
	; We might be interrupted in kernel space with a user mapping
	; in which case the I/O space isn't present. Put it back to
	; flip the cartridge bank, then restore it as it was when
	; we interrupted
	lda	@mmu
	ora	#7
	sta	@mmu
	ldx	old_kbank	; Restore any temporary saved bank
	stx	old_kmap	; if we IRQ during a kernel user access
	sta	CARTPORT,x
	lda	old_mmu
	; Our I/O mappings might disappear at this point
	sta	@mmu
	pla
	tax
	pla
	rts

;
;	How do we want to force a given kernel map or do we ?
;
map_save_kernel:
	pha
	lda	@mmu
	sta	old_mmu
	lda	old_kmap
	sta	old_kbank
	lda	@mmu
	ora	#7		; Map in kernel
	sta	@mmu		; which kernel bank doesn't matter
	pla
	rts


	.common
;
;	Bank switchers
;

	.export	__bank_0_1
	.export	__bank_0_2
	.export	__bank_0_3
	.export	__bank_0_4
	.export	__bank_0_5
	.export	__bank_1_2
	.export	__bank_1_3
	.export	__bank_1_4
	.export	__bank_1_5
	.export	__bank_2_1
	.export	__bank_2_3
	.export	__bank_2_4
	.export	__bank_2_5
	.export	__bank_3_1
	.export	__bank_3_2
	.export	__bank_3_4
	.export	__bank_3_5
	.export	__bank_4_1
	.export	__bank_4_2
	.export	__bank_4_3
	.export	__bank_4_5
	.export	__bank_5_1
	.export	__bank_5_2
	.export	__bank_5_3
	.export	__bank_5_4
	.export __stub_1
	.export __stub_2
	.export __stub_3
	.export __stub_4
	.export __stub_5


jsrtmpy:
	lda	@tmp
	pha
	tya
	pha
	rts

__bank_1_2:
	lda	#ROM1
b1call:
	stx	@tmp
	tax
	sta	old_kmap
	sta	CARTPORT,x
	jsr	jsrtmpy
	pha
	lda	#ROM0
	sta	old_kmap
	sta	CARTPORT+ROM0
	pla
	rts
__bank_1_3:
	lda	#ROM2
	bne	b1call
__bank_1_4:
	lda	#ROM3
	bne	b1call
__bank_1_5:
	lda	#ROM4
	bne	b1call

__bank_2_1:
	lda	#ROM0
b2call:
	stx	@tmp
	tax
	sta	old_kmap
	sta	CARTPORT,x
	jsr	jsrtmpy
	pha
	lda	#ROM1
	sta	old_kmap
	sta	CARTPORT+ROM1
	pla
	rts
__bank_2_3:
	lda	#ROM2
	bne	b2call
__bank_2_4:
	lda	#ROM3
	bne	b2call
__bank_2_5:
	lda	#ROM4
	bne	b2call

__bank_3_1:
	lda	#ROM0
b3call:
	stx	@tmp
	tax
	sta	old_kmap
	sta	CARTPORT,x
	jsr	jsrtmpy
	pha
	lda	#ROM2
	sta	old_kmap
	sta	CARTPORT+ROM2
	pla
	rts
__bank_3_2:
	lda	#ROM1
	bne	b3call
__bank_3_4:
	lda	#ROM3
	bne	b3call
__bank_3_5:
	lda	#ROM4	; cpu on main page (overlay 4)
	bne	b3call

__bank_4_1:
	lda	#ROM0
b4call:
	stx	@tmp
	tax
	sta	old_kmap
	sta	CARTPORT,x
	jsr	jsrtmpy
	pha
	lda	#ROM3
	sta	old_kmap
	sta	CARTPORT+ROM3
	pla
	rts
__bank_4_2:
	lda	#ROM1
	bne	b4call
__bank_4_3:
	lda	#ROM2
	bne	b4call
__bank_4_5:
	lda	#ROM4
	bne	b4call

__bank_5_1:
	lda	#ROM0
b5call:
	stx	@tmp
	tax
	sta	old_kmap
	sta	CARTPORT,x
	jsr	jsrtmpy
	pha
	lda	#ROM4
	sta	old_kmap
	sta	CARTPORT+ROM4
	pla
	rts
__bank_5_2:
	lda	#ROM1
	bne	b5call
__bank_5_3:
	lda	#ROM2
	bne	b5call
__bank_5_4:
	lda	#ROM3
	bne	b5call

__stub_1:
__bank_0_1:
	lda	old_kmap
	pha		; not ideal we need to see if this is too much stack
	lda	#ROM0
bnk0h:
	stx	@tmp
	tax
	sta	old_kmap
	sta	CARTPORT,x
	jsr	jsrtmpy
	tay
	stx	@tmp
	pla
	tax
	sta	old_kmap
	sta	CARTPORT,x
	ldx	@tmp
	tya
	rts
__stub_2:
__bank_0_2:
	lda	old_kmap
	pha		; not ideal we need to see if this is too much stack
	lda	#ROM1
	bne	bnk0h
__stub_3:
__bank_0_3:
	lda	old_kmap
	pha		; not ideal we need to see if this is too much stack
	lda	#ROM2
	bne	bnk0h
__stub_4:
__bank_0_4:
	lda	old_kmap
	pha		; not ideal we need to see if this is too much stack
	lda	#ROM3
	bne	bnk0h
__stub_5:
__bank_0_5:
	lda	old_kmap
	pha		; not ideal we need to see if this is too much stack
	lda	#ROM4
	bne	bnk0h




; outchar: Wait for UART TX idle, then print the char in a without
; corrupting other registers

outchar:
outcharw:
	; TODO
	rts

;
;	Code that will live in each bank at the same address and is copied
;	there on 6509 type setups. On 6502 it may well be linked once in
;	common space
;
	.common
;
;	Interrupt vector logic. Keep this in platform for the 6502 so that
;	we can use the shorter one for the CMOS chip
;
;	This matches the routine in kernal for the cases where the kernal is
;	mapped. Both end up at vector2 with stuff stacked the same way.
;
vector:
	pha
	txa
	pha
	tya
	pha
	tsx
	lda	0x0104,x
	and	#0x10
	beq	vector_map
	jmp	(0x0316)

	.export vector2		; For debugging

vector_map:
	lda	@mmu
	sta	old_mmu
	ora	#7
	sta	@mmu		; Remember old MMU state, map in KERNAL
	bne	vector_do

vector2:
	lda	@mmu
	sta	old_mmu	; Remember existing MMU
vector_do:
#if 1
	cld
	lda	#>vector3
	pha
	lda	#<vector3
	pha
	php	; fake stack for the ROM routine RTI
	pha
	pha
	pha
	;	can't JSR this as RTI and RTS work differently (sigh)
	jmp	(oldvec)
#endif

vector3:
;
;	Kick EXEC back out if not expected. We'll sort out our mappings
;	again in the IRQ handler core
;
	lda	old_mmu
	sta	@mmu
;
;	Map the kernel in, remmember our old state
;
	jsr	map_save_kernel

;	Save our zero page bits (and thus the C stack etc). The save
;	area is task specific so if we task switch all is good
;
	jsr	stash_zp

;
;	Configure the C stack to the i stack
;	stask_zp saved the old stack
;
	lda	#<istack_top
	sta	@sp
	lda	#>istack_top
	sta	@sp+1
	jsr	_plt_interrupt_i	; call via C int wrapper

;	Check for kernel return path

	lda	_udata + U_DATA__U_INSYS
	bne	kirqout
;
;	Pre-emption ?
;
	lda	_need_resched
	beq	no_preempt

	;
	; Put this task to sleep and continue with the next one. As we
	; have per task IRQ stacks out of necessity (the 6502 stack is
	; a fixed page) this isn't as scary as on some ports.
	;

	lda	#0
	sta	_need_resched

	; Switch to the kernel stack (which is currently free as we are
	; in user space. This stack unlike the istack is per process and
	; will be saved to swap
	;
	lda	#<kstack_top
	sta	@sp
	lda	#>kstack_top
	sta	@sp+1

	lda	#1
	sta	_udata+U_DATA__U_INSYS
	jsr	_chksigs
	; Bankman will fix this up into a banked jump
	jmp	x2
	nop
x2:
	; Mark ourselves Ready not Running
	lda	_udata+U_DATA__U_PTAB
	ldx	_udata+U_DATA__U_PTAB+1
	sta	@tmp
	stx	@tmp+1
	ldy	#P_TAB__P_STATUS_OFFSET
	lda	#P_READY
	sta	(@tmp),y
	; Switch out .. we will re-appear at some point
	; When we enter this code we will switch the low 16K underneath
	; us. Other stuff will run on a different low bank, and at some
	; point we will return with S correct and on our 6502 and C
	; stacks (we effectively have private IRQ stacks)
	jsr	_plt_switchout
	; Bankman will fix this up into a banked jump
	jmp	x3
	nop
x3:
	; The switch back in has restored our 6502 stack. We don't
	; care about the kstack at this point
	;
	; Now return to the old state having woken back up
	; Clear insys, move back onto the interrupt stack
	;
	lda	#0
	sta	_udata+U_DATA__U_INSYS

	;
	; Check what signals are now waiting for us
	;
no_preempt:
;
;	Signal handling on 6502 is foul as the C stack may be inconsistent
;	during an IRQ. We push a new complete rti frame below the official
;	one, along with a vector and the signal number. The glue in the
;	app is expected to switch to a signal stack or similar, pop the
;	values, invoke the signal handler and then return.
;
;	stash zp will restore our C stack not that it matters
;
	jsr	stash_zp			; recover 6502 zp bits

	;	Put the user process back into visible memory
	jsr	map_proc_always

	lda	_udata+U_DATA__U_CURSIG
	beq	irqout
	tay

	; Right now the stack holds Y X A P rti addr
	; Push a helper to clean up and restore the register state
	lda	#>irqout-1
	pha
	lda	#<irqout-1
	pha					; stack a return vector
	tya
	pha					; stack signal number
	ldx	#0
	stx	_udata+U_DATA__U_CURSIG
	asl	a
	tay
	lda	_udata+U_DATA__U_SIGVEC+1,y	; Our vector (low)
	pha					; stack half of vector
	lda	_udata+U_DATA__U_SIGVEC,y	; High half
	pha					; stack rest of vector
	txa
	sta	_udata+U_DATA__U_SIGVEC,y	; Wipe the vector
	sta	_udata+U_DATA__U_SIGVEC+1,y
	lda	#>PROGLOAD + 16
	pha
	lda	#<PROGLOAD + 16
	pha
	lda	#0
	pha		; dummy flags, with irq enable
	rti		; return on the fake frame
			; if the handler returns
			; rather than doing a longjmp
			; we'll end up at irqout and pop the
			; real frame
kirqout:
;
;	Get back on the user stack, but do not use the user C stack
;	until we leave
;
	jsr	stash_zp	; recover 6502 zp bits
	jsr	map_restore
irqout:
	pla
	tay
	pla
	tax
	pla
	rti
;
;	@usp/usp+1 are the C stack of the userspace
;	with the syscall number in X
;	Y indicates the number of bytes of argument
;
syscall_entry:
	php
	sei
	cld

	stx	_udata+U_DATA__U_CALLNO

	;	@sp points to the user argments

	;
	;	We copy the arguments but need to deal with the compiler
	;   stacking in the reverse order. At this point @tmp points
	;	to the last byte of the arguments (first argument). We go
	;	down the stack copying words up the argument list.
	;
	ldy	#0
	ldx	#0
copy_args:
	lda	(@usp),y
	sta	_udata+U_DATA__U_ARGN,x
	inx
	iny
	cpy	#8
	bne	copy_args

	; Now we need to stack switch. Save the adjusted stack we want
	; for return
	;
	lda	@usp
	pha
	lda	@usp+1
	pha
	tsx
	stx	_udata+U_DATA__U_SYSCALL_SP
;
;	We save a copy of the high byte of sp here as we may need it to get
;	the brk() syscall right.
;
	sta	_udata+U_DATA__U_SYSCALL_SP+1
;
;	FIXME: we should check here if there is enough 6502 stack left
;	and if so either copy and switch stacks or kill the process
;
;	Set up the C stack
;
	lda	#<kstack_top
	sta	@sp
	lda	#>kstack_top
	sta	@sp+1

;
;	Caution: We may enter here and context switch and another task
;	exit via its own syscall returning in its own memory context.
;
;	Don't assume anything we stored statically *except* the uarea
;	will be different. The uarea is banked in and out (or copied in
;	more awkward systems).
;
	jsr	unix_syscall_entry
	; Bankman will fix this up into a banked jump
	jmp	x4
	nop
x4:

;
;	Correct the system stack
;
	ldx	_udata+U_DATA__U_SYSCALL_SP
	txs

;
;	From that recover the C stack and the syscall buf ptr
;
	pla
	sta	@usp+1
	pla
	sta	@usp
	lda	_udata+U_DATA__U_CURSIG
	beq	syscout
	tay

	;
	;	The signal handler might make syscalls so we need to get
	;	our return saved and return the right value!
	;
	lda	_udata+U_DATA__U_ERROR
	pha
	lda	_udata+U_DATA__U_RETVAL
	pha
	lda	_udata+U_DATA__U_RETVAL+1
	pha
	lda	#>sigret-1			; Return address
	pha
	lda	#<sigret-1
	pha

	tya
	pha					; signal
	ldx	#0
	stx	_udata+U_DATA__U_CURSIG
	asl	a
	tay
	lda	_udata+U_DATA__U_SIGVEC+1,y	; Our vector
	pha
	lda	_udata+U_DATA__U_SIGVEC,y
	pha
	txa
	sta	_udata+U_DATA__U_SIGVEC,y	; Wipe the vector
	sta	_udata+U_DATA__U_SIGVEC+1,y

	; Invoke the helper with signal and vector stacked
	; it will then return to syscout and recover the original
	; frame. If the handler made syscalls then we set the registers
	; up in sigret
	cli
	jmp	(PROGLOAD + 16)

sigret:
	pla		; Unstack the syscall return pieces
	tax
	pla
	tay
	pla
	plp		; from original stack frame
	rts

syscout:
;	We may be in decimal mode beyond this line.. take care
;
	plp

;	Copy the return data over
;
	ldy	_udata+U_DATA__U_RETVAL
	ldx	_udata+U_DATA__U_RETVAL+1
;	Also sets Z for us
	lda	_udata+U_DATA__U_ERROR

	rts

plt_doexec:
	;	Can't use pop directly and we don't actually care
	;	about the kstack anwyay
	ldy	#1
	lda	(@sp),y
	dey
	tax
	lda	(@sp),y
	;	Set up for the loader
	stx	@tmp3+1
	sta	@tmp3		; Save execution address in @tmp3
	stx	@tmp2+1		; Point tmp2 at base page + 16
	lda	#16
	sta	@tmp2
	ldy	#0
	lda	(@tmp2),y	; Get the signal vector pointer
	sta	PROGLOAD+16	; if we loaded high put the vector in
	iny
	lda	(tmp2),y
	sta	PROGLOAD+17	; the low space where it is expected

;
;	Set up the C stack
;
	lda	_udata+U_DATA__U_ISP
	sta	@usp
	ldx	_udata+U_DATA__U_ISP+1
	stx	@usp+1

;
;	Set up the 6502 stack
;
	ldx	#$ff
	txs
;
;	Relocation is done in kernel because the 6502 isn't quite smart
;	enough to do its own ZP relocations as far as I can tell (prove me
;	wrong....)
;
	jsr	_relocator

	jmp	(@tmp3)		; Enter user application

;
;	Have to deal with banking
;
_unix_syscall_i:
	jsr	_unix_syscall
	jmp	x10
	nop
x10:
	rts
_plt_interrupt_i:
	jsr	_plt_interrupt
	jmp	x11
	nop
x11:
	rts


;
;	Disk copier (needs to be in common), call with ints off
;	for now
;
;	TOS = ptr, length always 512, src and page in globals
;
;	Uses @tmp3/4 as 1/2 are reserved for the mappers
;
;	TODO: swap support
;
;	Swap requires we are smart about block 0 as we'll overwrite the
;	live CPU stack and this may make it very tricky if at all possible
;	to do 6502 swap and make the atari8bit work. Research needed
;
;	part of the page away)
;
;	Some mapping tricks are needed unfortunately
;
;	If the address is outside of the range D000-DFFF then we can
;	map HIRAM/LORAM as 01 and directly copy. If the Address is
;	between D000-DFFF then we just have to deal with it. A read
;	can also cross the boundary so we really care about CE01-DFFF
;
	.common

	.export _devide_read_data
	.export _devide_write_data

_devide_read_data:
	jsr	__pop
	sta	@tmp3
	stx	@tmp3+1		; Save the target
	sta	@tmp3
	stx	@tmp3+1		; Save the target
	txa
	and	#0xF0		; Check the 4K range is not I/O
	cmp	#0xD0
	beq	read_slow	; In the I/O window
	lda	@tmp3+1
	cmp	#0xCF
	bne	read_fast
	; Trying cases CE01-CFFF will spill into I/O
	lda	@tmp3
	beq	read_fast

	;	Slow path
	;	CE01-DFFF are never kernel reads
	;	REU would avoid so much pain!
read_slow:
	ldy	#0
	lda	@mmu
	and	#0xFC
	tax
	inx			; MMU with I/O mapped
	jsr	hd_rslow256
	inc	@tmp3+1
	jsr	hd_rslow256
	jmp	map_kernel

hd_rslow256:
	stx	@mmu		; I/O in but user
	lda	0xDE20
	dex
	stx	@mmu		; I/O out but user
	sta	(@tmp3),y	; Save behind I/O window
	iny
	inx
	stx	@mmu
	lda	0xDE31
	dex
	stx	@mmu
	sta	(@tmp3),y
	inx
	iny
	bne	hd_rslow256
	rts

read_fast:
	;
	;	We must flip banks before we play mmu pokery, or it will
	; undo all our work. This means our variables must be commondata
	;
	lda	_td_raw
	beq	hd_kmap
	; Map user except for the I/O window
	lda	@mmu
	and	#0xFC
	ora	#1
	sta	@mmu
hd_kmap:
	inc	0xD020
	ldy	#0
	jsr	hd_read256
	inc	@tmp3+1
	jsr	hd_read256
	dec	0xD020
	jmp	map_kernel

hd_read256:
	lda	0xDE20
	sta	(@tmp3),y
	iny
	lda	0xDE31
	sta	(@tmp3),y
	iny
	bne	hd_read256
	rts

_devide_write_data:
	jsr	__pop
	sta	@tmp3
	stx	@tmp3+1		; Save the target
	txa
	and	#0xF0		; Check the 4K range is not I/O
	cmp	#0xD0
	beq	write_slow	; In the I/O window
	lda	@tmp3+1
	cmp	#0xCF
	bne	write_fast
	; Trying cases CE01-CFFF will spill into I/O
	lda	@tmp3
	beq	write_fast

	;	Slow path
	;	CE01-DFFF are never kernel reads
	;	REU would avoid so much pain!
write_slow:
	ldy	#0
	;	HIRAM and LORAM off, CHAREN on - all RAM
	lda	@mmu
	and	#0xFC
	tax
	; 	Save MMU bits to use in X
	jsr	hd_wslow256
	inc	@tmp3+1
	jsr	hd_wslow256
	jmp	map_kernel

hd_wslow256:
	;	100	RAM at D000
	stx	@mmu
	iny
	lda	(@tmp3),y	; Load behind I/O window
	inx
	;	101	I/O at D000
	stx	@mmu		; I/O in but user
	sta	0xDE31
	dey
	dex
	;	100	RAM at D000
	stx	@mmu
	lda	(@tmp3),y	; Load behind I/O window
	inx
	;	101	I/O at D000
	stx	@mmu		; I/O in but user
	sta	0xDE20
	;	Back to 100 for next loop
	dex
	iny
	iny
	bne	hd_wslow256
	rts

write_fast:
	;
	; We must flip banks before we play mmu pokery, or it will
	; undo all our work. This means our variables must be commondata
	;
	lda	_td_raw
	beq	hd_kmapw
	; Map user except for the I/O window
	lda	@mmu
	and	#0xFC
	ora	#1
	sta	@mmu
hd_kmapw:
	inc	0xD020
	inc	0xD020
	ldy	#0
	jsr	hd_write256
	inc	@tmp3+1
	jsr	hd_write256
	dec	0xD020
	dec	0xD020
	jmp	map_kernel

; This one is a shade more complicated. Write the bytes swapped in order
; TODO: would it be better to have a tmp4 thats tmp3 + 1 and avoid the
; inc/dec stuff ?

hd_write256:
	lda	(@tmp3),y
	tax
	iny
	lda	(@tmp3),y
	sta	0xDE31
	stx	0xDE20
	iny
	bne	hd_write256
	rts

;
;	Screen handling. Much like an Atari but we have to do the scrolling
;
;	We pull a trick here. When we have the kernel mapped we need the
;	cartridge mapped so we have I/O mapped in Dxxx. When we are in user
;	space we have RAM mapped so the I/O space also vanishes
;
	.overlay4

	.export	_plot_char
	.export _scroll_up
	.export _scroll_down
	.export _vtattr_notify
	.export _clear_across
	.export _clear_lines
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable

gaddr:
	ldy	#1
	lda	(@sp),y
	tax
	dey
	lda	(@sp),y
_cursor_disable:
	rts

addr:
	jsr	gaddr
	; A = Y X = X Y = 0
set_addr:
	ldy	#0
	stx	@tmp		; X co-ord
	; A is 0-39
	asl	a		; x 2
	asl	a		; x 4
	; Can overflow beyond this point
	asl	a
	bcc	noover
	iny
noover:
	sty	@tmp2		; set upper byte
	sty	@tmp3+1		; save whole x 8 value
	sta	@tmp3
	asl	a		; x 16
	rol	@tmp2
	asl	a		; x 32
	rol	@tmp2
	; C will be clear
	adc	@tmp3		; low add
	bcc	nobump
	inc	@tmp3+1		; carry into upper for add
	clc
nobump:	adc	@tmp		; add X
	sta	@tmp		; low set
	sta	@tmp3		; save for colour
	lda	@tmp2		; high
	adc	@tmp3+1		; fold in upper of tmp3 and any X overflow
	adc	#0x04		; screen base
	sta	@tmp+1
	adc	#0xD4		; D800 is the colour RAM
	sta	@tmp3+1
	ldy	#2
	rts

_plot_char:
	jsr	addr
	; @tmp is now address
	lda	(@sp),y
	ldy	#0
	and	#0x7F
	sta	(@tmp),y
	lda	_c64ink
	sta	(@tmp3),y
	jmp	__add4sp

_cursor_on:
	jsr	addr
	ldy	#0
	lda	(@tmp),y
	sta	cursorc
	lda	#0x00
	sta	(@tmp),y
	lda	@tmp
	sta	cursorl
	lda	@tmp+1
	sta	cursorh
	jmp	__add2sp

_cursor_off:
	lda	cursorl
	sta	@tmp
	lda	cursorh
	sta	@tmp+1
	ldy	#0
	lda	cursorc
	sta	(@tmp),y
	rts

_clear_across:
	jsr	addr
	lda	(@sp),y
	tax
	ldy	#0
clac:
	lda	#' '
	sta	(@tmp),y
	lda	_c64ink
	sta	(@tmp3),y
	iny
	dex
	bne	clac
	jmp	__add4sp

_clear_lines:
	jsr	gaddr
	stx	@tmp2+1		; not touched by set_addr
	cpx	#0
	beq	nowork
	ldx	#0
	jsr	set_addr	; start of line
	ldx	@tmp2+1
line:
	ldy	#39
doline:
	lda	#' '
	sta	(@tmp),y
	lda	_c64ink
	sta	(@tmp3),y
	dey
	cpy	#0xFF
	bne	doline
	lda	@tmp
	clc
	adc	#40
	sta	@tmp
	sta	@tmp3
	bcc	nline
	inc	@tmp+1
	inc	@tmp3+1
nline:	dex
	bne	line
nowork:
	jmp	__add2sp

_scroll_up:
	lda	#0x04
	sta	@tmp+1
	sta	@tmp2+1
	lda	#0xD8
	sta	@tmp3+1
	sta	@tmp4+1
	lda	#0x00
	sta	@tmp
	sta	@tmp3
	lda	#0x28
	sta	@tmp2
	sta	@tmp4
	ldy	#0
	ldx	#3
cpup:	lda	(@tmp2),y
	sta	(@tmp),y
	lda	(@tmp4),y
	sta	(@tmp3),y
	iny
	bne	cpup
	inc	@tmp+1
	inc	@tmp2+1
	inc	@tmp3+1
	inc	@tmp4+1
	dex
	bne	cpup
cpup2:	lda	(@tmp2),y
	sta	(@tmp),y
	lda	(@tmp4),y
	sta	(@tmp3),y
	iny
	cpy	#0xC0
	bne	cpup2
	rts

; Back scrolling is the same idea but we have to work backwards
; Screen is 400-7E8
_scroll_down:
	; 255 bytes from end of frame buffer
	lda	#0xE7
	ldx	#0x07
	ldy	#0xDB
	sta	@tmp
	sta	@tmp3
	stx	@tmp+1
	sty	@tmp3+1
	lda	#0xBF
	sta	@tmp2
	stx	@tmp2+1
	sta	@tmp4
	sty	@tmp4+1
	ldy	#255
	ldx	#3
cpdown:
	lda	(@tmp2),y
	sta	(@tmp),y
	lda	(@tmp4),y
	sta	(@tmp3),y
	dey
	bne	cpdown
	lda	(@tmp2),y
	sta	(@tmp),y
	lda	(@tmp4),y
	sta	(@tmp3),y
	dey
	;	256 bytes moved
	dex
	dec	@tmp+1
	dec	@tmp2+1
	dec	@tmp3+1
	dec	@tmp4+1
	bne	cpdown
	;	We have done 768 bytes, We need to do
	;	192 more
cplast:
	lda	(@tmp2),y
	sta	(@tmp),y
	lda	(@tmp4),y
	sta	(@tmp3),y
	dey
	cpy	#0x3F
	bne	cplast
	rts

_vtattr_notify:
	; Map colours
	lda	_vtink
	and	#0x1F
	tax
	lda	coltab,x
	sta	_c64ink
	lda	_vidpaper
	and	#0x1F
	tax
	lda	coltab,x
	sta	0xD021
	lda	_vtborder
	and	#0x1F
	tax
	lda	coltab,x
	sta	0xD020
	rts

coltab:
	.byte	0		; black
	.byte	6		; blue
	.byte	2		; red
	.byte	4		; magenta
	.byte	5		; green
	.byte	3		; cyan
	.byte	7		; yellow
	.byte	1		; white
	.byte	0		; black
	.byte	6		; blue
	.byte	2		; red
	.byte	4		; magenta
	.byte	5		; green
	.byte	3		; cyan
	.byte	7		; yellow
	.byte	1		; white
	; And native
	.byte	0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15


	.data

	.export	_vidpaper
	.export	_vtborder

cursorl:
	.byte	0
cursorh:
	.byte	0
cursorc:
	.byte	0
_c64ink:
	.byte	14		; native colour 14
_vidpaper:
	.byte	1		; blue
_vtborder:
	.byte	30		; native colour 14

	.export _keydown
	.export _keytab
	.export _kdown
	.export _lshift
	.export _rshift
	.export _ctrl

_keydown:
	.byte	0
_keytab:
	.byte	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
_kdown:
	.byte	0	; count of dow keys
_lshift:
	.byte	0
_rshift:
	.byte	0
_ctrl:
	.byte	0

	.code
#if 0
	.export	_keyscan

;
;	Scan the keyboard. We return a key
;

_keyscan:
	lda	#0xFF
	sta	_keydown	; Assume no key down

	lda	#0
	tax
	sta	0xDC00		; Check if any key is pressed
	ldy	0xDC01
	iny
	bne	keys		; was 0xFF ? no - then keys down
	lda	_kdown		; keys down have gone up ?
	beq	keydone		; no keys down, none now fast path
keys:
	; X is 0 here
	lda	#0xFE		; enable right column
col:
	sta	0xDC00		; select column
	pha
	; Get and debounce a column of keys
debounce:
	lda	0xDC00
	cmp	0xDC00
	bne	debounce
	cmp	_keytab,x	; check versus keybits
	beq	nomod
	pha
	jsr	kchange		; Line Y changed
	pla
	sta	_keytab,x	; update state
nomod:	inx
	pla
	sec
	rol	a		; next line
	bcs	col		; if we rotate the 0 into the carry it's
				; done
	bcc	keydone

kchange:	; Line Y changed between (@tmp),y and A
	sta	@tmp1		; save lines
	eor	_keytab,x	; A is now the changed lines
	ldy	#7
next:
	clc
	rol	a		; roll a 0 into the right check left
	bcs	do_delta
	beq	next
knext:
	pla
	clc
	rol	@tmp1		; rotate the up/down bits accordingly
	dey
	jmp	next

do_delta:
	; Key changed
	; Key matrix entry is Y,@tmp1+1
	pha
	lda	@tmp1
	bpl	key_down
	; For now key up isn't interesting
	dec	_kdown		; one less key down
nextk:
key_down:
	; Key X, Y  is down
	; Key table entry is Y << 3 + X
	txa
	asl	a
	asl	a
	asl	a
	sty	@tmp
	clc
	adc	@tmp
	;	TODO shift checks need to go here and not touch keydown
		sta	_keydown
	inc	_kdown		; one more key down
	rts
keydone:
	lda	_keydown
	rts
#endif
	.export	_keyread

keyd	.equ	0x0277

_keyread:
;
;	The ROM version helpfully enables interrupts which doesn't really
;	work for us!
;
	lda	@0xC6
	beq	nochar
	ldy	keyd
	ldx	#0
lp1:	lda	keyd+1,x
	sta	keyd,x
	inx
	cpx	@0xC6
	bne	lp1
	dec	@0xC6
	tya
nochar:
	rts
