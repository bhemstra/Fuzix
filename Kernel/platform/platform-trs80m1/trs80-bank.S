;
;	TRS 80 banking logic for the selector and alpha supermem
;

	; exported symbols
	.export init_hardware
	.export map_kernel
	.export map_proc
	.export map_proc_a
	.export map_proc_hl
	.export map_proc_always
	.export map_kernel_di
	.export map_proc_di
	.export map_proc_always_di
	.export map_proc_save
	.export map_kernel_restore
	.export map_save_kernel
	.export map_restore
	.export map_save_kmap
	.export map_restore_kmap
	.export map_buffers
	.export fork_mapsave
	.export mapper_init
	.export _trs80_mapper

	.export __uget
	.export __ugetc
	.export __ugetw
	.export __uput
	.export __uputc
	.export __uputw
	.export __uzero

#include "kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

; -----------------------------------------------------------------------------
; KERNEL MEMORY BANK (above 08000, only accessible when the kernel is mapped)
; -----------------------------------------------------------------------------
	.common
init_hardware:
	push	af
	call	vtbufinit
	pop	af
	ld	a,(_trs80_mapper)
	or	a
	ld	hl,0xFFFF	; FFFF is free in all our pages
	jr	nz, memsize_selector
	; set system RAM size
	ld	bc,0xFF43	; kernel included
	xor	a
mark_pages:
	out	(c),b
	ld 	(hl),a
	djnz	mark_pages
scan_pages:
	out	(c),a		; bank 0
	ld	(hl),0xff	; so we catch any wrapping
	ld	b,2
scan_pages_l:
	out	(c),b
	cp	(hl)		; still 0 ?
	jr	nz, mismatch
	ld	(hl),b
	inc	b
	jr	nz, scan_pages_l
mismatch:			; B holds the first page above
				; the limit (4 for 128K etc)
	ld	e,b
	dec	e
	jr	scan_done

memsize_selector:
	; set system RAM size	- HL already points to FFFF
	ld	bc,0x381f
	ld	e,4		; only 4 pages to test
mark_up:
	out	(c),b
	ld	(hl),e
	ld	a,0xF0		; subtract 0x10
	add	a,b
	ld	b,a
	dec	e
	jr	nz, mark_up
	ld	bc,0x081f
	ld	e,1
scan:
	out	(c),b
	ld	a,(hl)
	cp	e
	jr	nz,scan_done
	ld	a,0x10
	add	a,b
	ld	b,a
	inc	e
	ld	a,5
	cp	e
	jr	nz,scan
	dec	e
scan_done:
;
;	At this point E is the number of external banks we have
;
	dec	e		; one holds kernel code
	ld	h,e
	ld	l,0		; effectively * 256
	srl	h
	rr 	l		; * 128
	srl	h
	rr	l		; * 64
	srl	h
	rr	l		; * 32 so now in Kbytes
	ld	(_procmem), hl
	ld	de,80		; Kernel costs us 80K due to bank
	add	hl,de		; annoyances
	ld	(_ramsize), hl

	; set up interrupt vectors for the kernel (also sets up common memory in page 0x000F which is unused)
	ld	hl, 0
	push 	hl
	call	_program_vectors
	pop	hl

	im	1 ; set CPU interrupt mode
	ret

;
;	Must live here as we need the mapper set up before we make any
;	banked calls.
;
mapper_init:
	ld	(_trs80_mapper),a
	or	a
	jr	nz, mapper_selector
	ld	hl,0x0043
	ld	(ksave_map),hl
	ld	(map_reg),hl
	ld	(map_bank1),hl
	inc	h
	ld	(map_bank2),hl
	ret
mapper_selector:
	; Patch the fast copier for our port numbering
	ld	a,0x1f
	ld	(bankpatch1 + 1),a
	ld	(bankpatch2 + 1),a
	ld	(bankpatch3 + 1),a
	ld	(bankpatch4 + 1),a
	ret

;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW

	.common

_trs80_mapper:
	.byte 0x01	; Tell kernel mapper is Selector
ksave_map:
	.byte 0x1f
	.byte 0x00	; saved kernel map version
map_reg:
	.byte 0x1f	; so we can write a reg pair into map_reg
	.byte 0x00	; current value written to map register
map_bank1:
	.byte 0x1f	; port
	.byte 0x00	; kernel map using system RAM, assuming no low 16K
			; and high banking with I/O mapped
map_bank2:
	.byte 0x1f	; port
	.byte 0x08	; kernel map using first 32K of expansion memory
			; and high banking with I/O mapper
map_store:
	.byte 0x1f
	.byte 0x00	; save value from map_save

;
;	Map in the kernel. We are in common and all kernel entry points are
;	in common. Thus someone will always have banked in the right page
;	before jumping out of common. Thus we don't need to do anything but
;	restore the last saved kernel map!
;
map_kernel_di:
map_kernel:
map_kernel_restore:
	push	bc
	ld	bc, (ksave_map)
	ld	(map_reg), bc
	out	(c), b
	pop	bc
	ret

fork_mapsave:
	push	bc
	ld	bc,(map_reg)
	ld	(ksave_map),bc
	pop	bc
	ret
;
;	Select the bank for the relevant process. Update the ksave_map so we
;	can restore the correct kernel mapping when banked.
;
map_proc_di:
map_proc:
	ld	a, h
	or	l
	jr	z, map_kernel
map_proc_hl:
	ld	bc, (map_reg)
	ld	(ksave_map),bc	; for map_kernel_restore
	ld	b,(hl)		; udata page
	ld	(map_reg),bc
	out	(c), b
	ret

map_proc_a:			; used by bankfork
	push	bc
	ld	bc, (map_reg)
	ld	(ksave_map), bc
	ld	b, a
	ld	(map_reg), bc
	out	(c), b
	pop	bc
	ret

map_proc_save:
map_proc_always:
map_proc_always_di:
	push	af
	push	bc
	ld	bc, (map_reg)
	ld	(ksave_map), bc
	ld	a,(_udata + U_DATA__U_PAGE)
	ld	b,a
	ld	(map_reg),bc
	out	(c),b
	pop	bc
	pop	af
	ret

map_buffers:
	push	af
	push	bc
	ld	bc, (map_reg)
	ld	(ksave_map), bc
	ld	bc, (map_bank2)
	ld	(map_reg), bc
	out	(c),b
	pop	bc
	pop	af
	ret

map_save_kernel:
	push bc
	ld bc, (map_reg)
	ld (map_store), bc
	ld bc, (ksave_map)
	ld (map_reg), bc
	out (c), b
	pop bc
	ret

map_restore:
	push	bc
	ld	bc, (map_store)
	ld	(map_reg), bc
	out	(c), b
	pop	bc
	ret

map_save_kmap:
	ld	a,(map_reg + 1)
	ret

map_restore_kmap:
	ld	(map_reg + 1),a
	push	bc
	ld	bc, (map_reg)
	out	(c),b
	pop	bc
	ret

;
;	This lot is tricky.
;
	.export __bank_0_1
	.export __bank_0_2
	.export __bank_1_2
	.export __bank_2_1
	.export __stub_1
	.export __stub_2

;
;	The only hard case to understand logically here is calls and stubs
;	from common to a bank. In those cases we must save the previous bank
;	and restore it. We do this because we optimise the performance by
;	making calls into COMMON or CODE free of bank work so we can put
;	performance sensitive widely used routines (like compiler helpers)
;	there. The cost of that is that if we do call back out of common
;	space we have to do the restore as we return.
;
;	Available registers are HL,DE. We must save BC if used
;	Or we can use the alt regs if nothing in the target is doing so
;
;	If we nest calls then we get alternating use of BC and BC' via the
;	exx calls. As each BC user expects the callee to save their BC
;	this is fine.
;
__bank_0_2:			; Call from common to bank 2
	ld	a, (map_bank2 + 1)
	jr	bankina
__bank_0_1:			; Call from common to bank 1
	ld	a, (map_bank1 + 1)
bankina:
	; A holds the bank number we target
	pop	hl		; Get the return address
	ld	e,(hl)		; The two bytes following it are the true
	inc	hl		; function to call
	ld	d,(hl)
	inc	hl
	push	hl
	ex	de,hl
	push	bc
	ld	bc, (map_reg)	; bc is the old value/reg
	ld	(map_reg +1),a	; set new value
	out	(c), a		; write new value
	ld	a,b		; Save old into A
	pop	bc
	or	a		; bank 1 is zero with both mappers
	jr	z, retbank1	; Arrange that we put the banks back as they

	call	callhl		; were before the call. Needed because calls
; Return to bank 2
	push	bc
	ld	bc,(map_bank2)	; to common routines don't do banking so
	ld	(map_reg),bc	; the return won't either.
	out	(c),b
	pop	bc
	ret
retbank1:
	call	callhl
	push	bc
	ld	bc,(map_bank1)
	ld	(map_reg),bc
	out	(c),b
	pop	bc
	ret

__bank_1_2:
	pop	hl		; Get the return address
	ld	e,(hl)		; The two bytes following it are the true
	inc	hl		; function to call
	ld	d,(hl)
	inc	hl
	push	hl
	push	bc
	ld	bc, (map_bank2)
	ld	(map_reg), bc
	out	(c),b
	pop	bc
	ex	de,hl
	call	callhl
	push	bc
	ld	bc, (map_bank1)
	ld	(map_reg), bc
	out	(c), b
	pop	bc
	ret

__bank_2_1:
	pop	hl		; Get the return address
	ld	e,(hl)		; The two bytes following it are the true
	inc	hl		; function to call
	ld	d,(hl)
	inc	hl
	push	hl
	push	bc
	ld	bc, (map_bank1)
	ld	(map_reg), bc
	out	(c), b
	pop	bc
	ex	de,hl
	call	callhl
	push	bc
	ld	bc, (map_bank2)
	ld	(map_reg), bc
	out	(c),b
	pop	bc
	ret

;
;	Stubs are similar. Where there is a function pointer the linker adds
;	a call in common and resolves the function pointer to the code in
;	common. The function stub it adds is simply
;
;		ld de,realaddr
;		call __stub_0_%d   where %d is the target bank
;
;	For the same reason as bank calls we need to restore the previous
;	banking setup.
;
__stub_1:
	ld	a, (map_bank1 + 1)
	jr	stub_call
__stub_2:
	ld	a, (map_bank2 + 1)
stub_call:
	;	A is the target bank code
	pop	hl		; return address
	ex	(sp),hl		; swap the junk word for the return
	push	bc
	ld	bc, (map_reg)	; Get the current bank reg/code
	ld	(map_reg + 1), a ; update the code
	out	(c), a		; write the new
	ld	a,b		; Save old
	or	a		; bank 1 is 0 in both mappers 
	pop	bc		; clean up
	ex	de,hl
	jr	z, stub_ret_1
	call	callhl
	push	bc
	ld	bc, (map_bank2)
	jr	stub_ret
stub_ret_1:
	call	callhl		; invoke code in other bank
	push	bc
	ld	bc,(map_bank1)	; and back to bank 1
stub_ret:
	ld	(map_reg),bc
	out	(c),b
	pop	bc
	pop	de
	push	de
	push	de
	ret			; and ret - can't use jp (ix) or jp (hl) here
callhl:	jp	(hl)

;
;	Fast inter-bank copier. Copies from kernel common, data or banked
;	data (logical bank2) to/from userspace
;
;	We could use sp and make this faster still but it gets ugly and
;	complicated. Might be worth doing pairs of bytes though.
;
	.export b2bcopy		; for debug
b2bcopy:
	ld	a, b
	ld	(patch0 + 1), a	; source bank
	ld	a, c
	ld	(patch1 + 1), a	; destination bank
	exx
	; This is a hard copy case
	; For the loop trickery see
	; https://map.grauw.nl/articles/fast_loops.php
	;
	ld	a,c		; save lower loop count
	dec	bc		; number of full cycles + 1
	inc	b		; b is now the outer loop count
	ld	c,b		; upper count
	ld	b,a		; lower count
b2b_loop:
patch0:
	ld	a,0
	ld	(map_reg + 1),a
bankpatch3:
	out	(0x43),a
	ld	a,(hl)
	inc	hl
	ex	af,af'
patch1:
	ld	a,0
	ld	(map_reg + 1),a
bankpatch4:
	out	(0x43),a
	ex	af,af'
	ld	(de),a
	inc	de
	djnz	b2b_loop
	dec	c
	jr	nz, b2b_loop
	ret

; IX + 0	src
; IX + 2	dest
; IX + 4	count
uputget:
	ld	ix,10
	add	ix,sp
        ; load DE with the byte count
        ld	c, (ix + 4) ; byte count
        ld	b, (ix + 5)
	ld	a, c
	or	b
	ret	z		; no work
        ; load HL with the source address
        ld	l, (ix + 0) ; src address
        ld	h, (ix + 1)
        ; load DE with destination address (in userspace)
        ld	e, (ix + 2)
        ld	d, (ix + 3)
	; will return NZ
	ret

;
;	Our memory map has all the kernel data and literals within
;	bank however we might be copying from a kernel space disk buffer
;	in overlay 2. What we won't be doing though is copying across the
;	boundary
;
__uget:
	push	ix
	push	bc
	call	uputget
	jr	z, uput_out
	bit	7,e		; to buffer directly ?
;	jr	z,do_copy
	exx
	; Use alt regs for bank numbers
	ld	a, (_udata + U_DATA__U_PAGE)
	ld	b, a
	ld	a, (map_bank2 + 1)	; kernel is destination
	ld	c, a
	; copy BC (adjusted) from HL to DE between banks
	call	map_proc_save
	call	b2bcopy
	jr	map_out
__uput:
	push	ix
	push	bc
	call	uputget
	jr	z, uput_out
	bit	7,h
;	jr	z, do_copy
	exx
	; Use alt regs for bank numbers
	ld	a, (_udata + U_DATA__U_PAGE)
	ld	c, a
	ld	a, (map_bank2 + 1)	; kernel is source
	ld	b, a
	call	map_proc_save
	call	b2bcopy
	jr	map_out
do_copy:
	call	map_proc_save
	ldir
map_out:
	call	map_kernel_restore
uput_out:
	pop	bc
	pop	ix
	ld	hl,0
	ret

__uputc:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_save
	ld	(hl), e
uputc_out:
	jp	map_kernel_restore			; map the kernel back below common

__uputw:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a

	call	map_proc_save
	ld	(hl), e
	inc	hl
	ld	(hl), d
	jp	map_kernel_restore

__ugetc:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	map_proc_save
        ld	l, (hl)
	ld	h, 0
	jp	map_kernel_restore

__ugetw:
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	map_proc_save
        ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l, a
	jp	map_kernel_restore

__uzero:
	push	bc
	ld	hl,9
	add	hl,sp
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	ex	de,hl
	ld	a, b	; check for 0 copy
	or	c
	jr	z, bcout
	call	map_proc_save
	ld	(hl), 0
	dec	bc
	ld	a, b
	or	c
	jr	z, uzero_done
	ld	e, l
	ld	d, h
	inc	de
	ldir
uzero_done:
	pop	bc
	jp	map_kernel_restore
bcout:	pop	bc
	ret
