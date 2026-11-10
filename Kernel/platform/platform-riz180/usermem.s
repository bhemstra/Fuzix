# 1 "usermem.S"
;
;	For now use the generic Z80 setup. The Z180 ones assuee a
;	specific memory mapping we don't use due to our limited
;	RAM.
;
# 1 "kernelu.def"
;
U_DATA__TOTALSIZE           .equ 0x200        ; 256+256
Z80_TYPE                    .equ 2

OS_BANK                     .equ 0x00         ; value from include/kernel.h

; Memory layout
FIRST_RAM_BANK              .equ 0x40         ; 128K of RAM
Z180_IO_BASE                .equ 0xC0

CPU_CLOCK_KHZ               .equ 6144         ; 6.144MHz * 1
TICKSPERSEC                 .equ 40           ; timer interrupt rate (Hz)
TCR_CLOCK		    .equ 7680

PROGBASE		    .equ 0x0000
PROGLOAD		    .equ 0x0100

; disabling this saves around approx 0.5KB
# 1 "../../cpu-z80u/kernel-z80.def"
 
# 26
 
# 44
 
# 9 "usermem.S"
        ; exported symbols
        .export __uget
        .export __ugetc
        .export __ugetw

        .export __uput
        .export __uputc
        .export __uputw
        .export __uzero

;	We need these in common as they bank switch
;
	.common

__uputc:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_always
	ld 	(hl), e
	ld	hl,0
	jp	map_kernel_restore	; map the kernel back below common

__uputw:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	map_proc_always
	ld	(hl), e
	inc	hl
	ld	(hl), d
	ld	hl,0
	jp	map_kernel_restore

__ugetc:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always
        ld	l, (hl)
	ld	h, 0
	jp	map_kernel_restore

__ugetw:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always
        ld	a, (hl)
	inc	hl
	ld	h, (hl)
	ld	l,a
	jp	map_kernel_restore

uputget:
        ; load DE with the byte count
	ld	ix,8
	add	ix,sp
        ld	e, (ix + 4) ; byte count
        ld	d, (ix + 5)
	ld	a, d
	or	e
	ret	z	; no work
	dec	de	; we return BC as a count for two 8bit loops
	ld	b, e	; not a 16bit value
	inc	b	; See http:
	inc	d
	ld	c, d
        ; load HL with the source address
        ld	l, (ix + 0) ; src address
        ld	h, (ix + 1)
        ; load DE with destination address (in userspace)
        ld	e, (ix + 2)
        ld	d, (ix + 3)
	ld	a, b
	or	c
	ret


__uput:
	push	ix
	push	bc
	call	uputget		; source in HL dest in DE, count in BC
	jr	z, uput_out	; but count is at this point magic
	
uput_l:	ld	a, (hl)
	inc	hl
	call	map_proc_always
	ld 	(de), a
	call	map_kernel_restore
	inc	de
	djnz	uput_l
	dec	c
	jr	nz, uput_l
uput_out:
	pop	bc
	pop	ix
	ld	hl, 0
	ret


__uget:
	push	ix
	push	bc
	call	uputget			; source in HL dest in DE, count in BC
	jr	z, uput_out			; but count is at this point magic
	
uget_l:
	call	map_proc_always
	ld	a, (hl)
	inc	hl
	call	map_kernel_restore
	ld	(de), a
	inc	de
	djnz	uget_l
	dec	c
	jr	nz, uget_l
	jr	uput_out
;
__uzero:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a, b	; check for 0 copy
	or	c
	jr	z, uz_out
	ex	de,hl
	call	map_proc_always
	ld	(hl), 0
	dec	bc
	ld	a, b
	or	c
	jp	z, uz_out
	ld	e, l
	ld	d, h
	inc	de
	ldir
uz_out:
	pop	bc
	ld	hl,0
	jp	map_kernel_restore
