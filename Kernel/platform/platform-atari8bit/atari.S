;
;	Atari 8bit Experiments
;

	.export init_early
	.export init_hardware
	.export _program_vectors
	.export map_kernel
	.export map_buffers
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
stop:
	sei
	jmp	stop
	; Won't work and we want to drop into monitor on monitor case!
	; We need this code somewhere not Cxxx or to be smarter with maps

	lda	#0x01
	sta	0xD301		; ROM back in
	jmp	($FFFC)		; reboot

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
	and	#4		; IRQ flag
	bne	irq_off
	cli
	jmp	__add1sp

irq_off:
	sei
	jmp	__add1sp

;
;	The Atari essentially uses NMI as a second vector with a
;	mask register in the hardware not the CPU. We deal with that
;	in our IRQ mask routines.
;
;	TODO: figure out how to use this usefully so we can get our VBI
;	etc folded into the normal paths.
;
nmivec:
	lda	0xD40F
	; Should only see 0x40
	sta	_nmival
	rti

	.code			; TODO can we get this into discard ?

init_early:
	rts

init_hardware:
	lda	#128
	sta	_ramsize
	lda	#48
	sta	_procmem
	lda	#0
	sta	_procmem+1
	sta	_ramsize+1
	jsr	program_vectors_k
	jsr	_vtinit
	jmp	x0
	nop
x0:	lda	#0xC0		; Enable key and break interrupts
	sta	0xD20E
	lda	#0x03
	sta	0xD20F
	rts

	.commondata

	.export _nmival

_nmival:
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
	lda	#<nmivec
	sta	$FFFA
	lda	#>nmivec
	sta	$FFFB
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
map_proc_always:
	pha
	; RAM select, antic on main, cpu on extended
	; Bank 3 (user page) basic off, OS ROM off
	lda	0xD301
	sta	old_kmap
	sta	0xD5FF		; Cartridge off
	lda	#EXT3
	; Set PORTB correctly
	sta	0xD301		; Select banks
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
map_kernel:
	pha
	lda	old_kmap	; Back to the kernel bank we mapped from
	sta	0xD301
	sta	0xD5E3		; Cartridge on
	pla
	rts

map_buffers:
	pha
	lda	0xD301
	sta	old_kmap	; Current map save
	lda	#MAIN		; Switch to buffers
	sta	0xD301	
	sta	0xD5E3		; Cartridge on
	pla
	rts

;
;	Restore the user or previous kernel mapping post IRQ
;
map_restore:
	pha
	lda	old_kbank	; Restore any temporary saved bank
	sta	old_kmap	; if we IRQ during a kernel user access
	lda	saved_map
	sta	0xD301
	sta	0xD5FF		; Cartridge off
	cmp	#EXT3
	beq	nocart
	sta	0xD5E3
nocart:
	pla
	rts

;
;	How do we want to force a given kernel map or do we ?
;
map_save_kernel:
	pha
	lda	0xD301
	sta	saved_map
	lda	old_kmap
	sta	old_kbank
	; Main memory (overlay 4) shouldn't matter which we use
	lda	#MAIN
	sta	0xD301
	sta	0xD5E3		; Cartridge on
	pla
	rts

old_kbank:
	.byte	0
old_kmap:
	.byte	0
saved_map:
	.byte	0

;
;	Bank switchers
;

	.export	__bank_0_1
	.export	__bank_0_2
	.export	__bank_0_3
	.export	__bank_0_4
	.export	__bank_1_2
	.export	__bank_1_3
	.export	__bank_1_4
	.export	__bank_2_1
	.export	__bank_2_3
	.export	__bank_2_4
	.export	__bank_3_1
	.export	__bank_3_2
	.export	__bank_3_4
	.export	__bank_4_1
	.export	__bank_4_2
	.export	__bank_4_3
	.export __stub_1
	.export __stub_2
	.export __stub_3
	.export __stub_4


jsrxy:
	txa
	pha
	tya
	pha
	rts


__bank_1_2:
	lda	#EXT1	; RAM select, antic on main, cpu on ext page 1
b1call:
	sta	0xD301
	jsr	jsrxy
	pha
	lda	#EXT0	; cpu on ext page 1
	sta	0xD301
	pla
	rts
__bank_1_3:
	lda	#EXT2	; cpu on ext page 2
	bne	b1call
__bank_1_4:
	lda	#MAIN	; cpu on main page (overlay 4)
	bne	b1call

__bank_2_1:
	lda	#EXT0	; RAM select, antic on main, cpu on ext page 0
b2call:
	sta	0xD301
	jsr	jsrxy
	pha
	lda	#EXT1	; cpu on ext page 1
	sta	0xD301
	pla
	rts
__bank_2_3:
	lda	#EXT2	; cpu on ext page 2
	bne	b2call
__bank_2_4:
	lda	#MAIN	; cpu on main page (overlay 4)
	bne	b2call

__bank_3_1:
	lda	#EXT0	; RAM select, antic on main, cpu on ext page 0
b3call:
	sta	0xD301
	jsr	jsrxy
	pha
	lda	#EXT2	; cpu on ext page 2
	sta	0xD301
	pla
	rts
__bank_3_2:
	lda	#EXT1	; cpu on ext page 1
	bne	b3call
__bank_3_4:
	lda	#MAIN	; cpu on main page (overlay 4)
	bne	b3call

__bank_4_1:
	lda	#EXT0	; RAM select, antic on main, cpu on ext page 0
b4call:
	sta	0xD301
	jsr	jsrxy
	pha
	lda	#MAIN	; cpu on main page
	sta	0xD301
	pla
	rts
__bank_4_2:
	lda	#EXT1	; cpu on ext page 1
	bne	b4call
__bank_4_3:
	lda	#EXT2	; cpu on ext page 3
	bne	b4call

__stub_1:
__bank_0_1:
	lda	0xD301
	pha		; not ideal we need to see if this is too much stack
	lda	#EXT0
bnk0h:
	sta	0xD301
	jsr	jsrxy
	tay
	pla
	sta	0xD301
	tya
	rts
__stub_2:
__bank_0_2:
	lda	0xD301
	pha		; not ideal we need to see if this is too much stack
	lda	#EXT1
	bne	bnk0h
__stub_3:
__bank_0_3:
	lda	0xD301
	pha		; not ideal we need to see if this is too much stack
	lda	#EXT2
	bne	bnk0h
__stub_4:
__bank_0_4:
	lda	0xD301
	pha		; not ideal we need to see if this is too much stack
	lda	#MAIN
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
vector:
	pha
	txa
	pha
	tya
	pha
	cld

	jsr	map_save_kernel

;	Save our zero page bits (and thus the C stack etc). The save
;	area is task specific so if we task switch all is good
;
	jsr 	stash_zp
;
;	Q: do we want to spot BRK instructions and signal them ?
;
;
;
;	Configure the C stack to the i stack
;
	lda	#<istack_top
	sta	@sp
	lda	#>istack_top
	sta	@sp+1
;
;	This will map in the upper kernel pages via map_save_kernel, invoke
;	the handler and then return restoring the mapped pages of either
;	the kernel or calling user process to the high space.
;
	jsr	_plt_interrupt_i
	; Bankman will fix this up into a banked jump
	jmp	x1
	nop
x1:

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
	ldx	_udata+U_DATA__U_PTAB
	lda	#P_READY
	sta	P_TAB__P_STATUS_OFFSET,x
	; Switch out .. we will re-appear at some point
	lda	_udata+U_DATA__U_PTAB
	ldx	_udata+U_DATA__U_PTAB+1
	; When we enter this code we will switch the low 16K underneath
	; us. Other stuff will run on a different low bank, and at some
	; point we will return with S correct and on our 6502 and C
	; stacks (we effectively have private IRQ stacks)
	jsr	_plt_switchout
	; Bankman will fix this up into a banked jump
	jmp	x3
	nop

x3:
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
;
;	Get back on the user stack, but do not use the user C stack
;	between here and returning to user space
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
	pha					; dummy flags, with irq enable
	rti					; return on the fake frame
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

	; 	@sp points to the user argments

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
;	TODO; special handler for read into pages 0 and 1 (has to throw
;	part of the page away)	
;

	.common

	.export _devide_read_data
	.export _devide_write_data

_devide_read_data:
	jsr	__pop
	sta	@tmp3
	stx	@tmp3+1		; Save the target

	;
	;	We must flip banks before we play mmu pokery, or it will
	; undo all our work. This means our variables must be commondata
	;
devide_do_read:
	lda	_td_raw
	beq	hd_kmap
	jsr	map_proc_always
	jmp	hd_do_read
hd_kmap:
	jsr	map_buffers
hd_do_read:
	ldy	#0
	jsr	hd_read256
	inc	@tmp3+1
	jsr	hd_read256
	jmp	map_kernel

hd_read256:
	lda	0xD500
	sta	(@tmp3),y
	iny
	bne	hd_read256
no_remap:
	rts

_devide_write_data:
	jsr	__pop
	sta	@tmp3
	stx	@tmp3+1		; Save the target
	;
	; We must flip banks before we play mmu pokery, or it will
	; undo all our work. This means our variables must be commondata
	;
	lda	_td_raw
	beq	hd_kmapw
	jsr	map_proc_always
	jmp	hd_do_write
hd_kmapw:
	jsr	map_buffers
hd_do_write:
	ldy	#0
	jsr	hd_write256
	inc	@tmp3+1
	jsr	hd_write256
	jmp	map_kernel

; This one is a shade more complicated. Write the bytes swapped in order
; TODO: would it be better to have a tmp4 thats tmp3 + 1 and avoid the
; inc/dec stuff ?

hd_write256:
	lda	(@tmp3),y
	sta	0xD500
	iny
	bne	hd_write256
	rts

;
;	Screen handling
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
_vtattr_notify:
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
	inc	@tmp3+1		; carry into uppet for add
	clc
nobump:	adc	@tmp		; add X
	sta	@tmp		; low set
	lda	@tmp2		; high
	adc	@tmp3+1		; fold in upper of tmp3 and any X overflow
	adc	#0x44		; screen base
	sta	@tmp+1
	ldy	#2
	rts

_plot_char:
	jsr	addr
	; @tmp is now address
	lda	(@sp),y
	ldy	#0
	sta	(@tmp),y
	jmp	__add4sp

_cursor_on:
	jsr	addr
	ldy	#0
	lda	(@tmp),y
	eor	#0x80
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
	lda	(@tmp),y
	eor	#0x80
	sta	(@tmp),y
	rts

_clear_across:
	jsr	addr
	lda	(@sp),y
	tax
	lda	#' '
	ldy	#0
clac:
	sta	(@tmp),y
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
	lda	#' '
line:
	ldy	#40
doline:
	sta	(@tmp),y
	dey
	bne	doline
	lda	@tmp
	clc
	adc	#40
	sta	@tmp
	lda	#' '
	bcc	nline
	inc	@tmp+1
nline:	dec	@tmp2
	bne	doline
nowork:
	jmp	__add2sp

; Quick hack for now - we should rewrite the display lists not copy memory
_scroll_up:
	lda	#0x44
	sta	@tmp+1
	sta	@tmp2+1
	lda	#0x00
	sta	@tmp
	lda	#0x28
	sta	@tmp2
	ldy	#0
	ldx	#3
cpup:	lda	(@tmp2),y
	sta	(@tmp),y
	iny
	bne	cpup
	inc	@tmp2+1
	inc	@tmp+1
	dex
	bne	cpup
cpup2:	lda	(@tmp2),y
	sta	(@tmp),y
	iny
	cpy	#0xC0
	bne	cpup2
	rts
; TODO

_scroll_down:
	rts

	; Can live in banked space

cursorl:
	.byte	0
cursorh:
	.byte	0

	; Keyboard table

#define KEY_F1	0x80 + '1'
#define KEY_F2	0x80 + '2'
#define KEY_F3	0x80 + '3'
#define KEY_F4	0x80 + '4'
#define KEY_F5	0x80 + '5'
#define KEY_F6	0x80 + '6'
#define KEY_F7	0x80 + '7'
#define KEY_F8	0x80 + '8'
#define KEY_HOME 0x80 + 'H'
#define KEY_HELP 0x80 + 'h'

	.literal
	.export _keydecode
_keydecode:
	.byte 'l', 'j', ';', KEY_F1, KEY_F2, 'k', '+', '*'
	.byte 'o', 0, 'p', 'u', 13, 'i', '-', '='
	.byte 'v', KEY_HELP, 'c', KEY_F3, KEY_F4, 'b', 'x', 'z'
	.byte '4', '0', '3', '6', 27, '5', '2', '1'
	.byte ',', ' ', ',' ,'n' , 0, 'm', '/', KEY_HOME
	.byte 'r', 0, 'e', 'y', 8, 't', 'w', 'q'
	.byte '9', 0, '0', '7', 127, '8', '<', '>'
	.byte 'f', 'h', 'd', 0, 0 /* CAPS */, 'g', 's', 'a'

	.byte 'L', 'J', ':', KEY_F5, KEY_F6, 'K', '\', '^'
	.byte 'O', 0, 'P', 'U', 13, 'I', '_', '|'
	.byte 'V', KEY_HELP, 'C', KEY_F7, KEY_F8, 'B', 'X', 'Z'
	.byte '$', ')', '#', '&', 27, '%', '"', '!'
	.byte '[', ' ', ']', 'N', 0, 'M', '?', KEY_HOME
	.byte 'R', 0, 'E', 'Y', 8, 'T', 'W', 'Q'
	.byte '(', 0, ')', 39, 127, '8', '{', '}'
	.byte 'F', 'H', 'D', 0, 0 /* CAPS */, 'G', 'S', 'A'
