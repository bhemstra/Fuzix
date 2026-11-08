;
;	Mapping implementation for the Atari 130XE and systems with PORTB
;	banking. We don't use any extra space provided by the third party
;	bankers and we require that either ANTIC memory is tied to main
;	memory or ANTIC memory is switchable by PORTB.
;
#include "kernel.def"
#include "../../cpu-6502/kernel02.def"

	.export _plt_monitor
	.export _plt_reboot
	.export init_early
	.export init_hardware
	.export _program_vectors

	.export map_kernel
	.export map_buffers
	.export map_proc
	.export map_proc_always
	.export map_save_kernel
	.export map_restore

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

	.common

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

