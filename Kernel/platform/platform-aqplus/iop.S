;
;	Communication routines for the IOP
;

	.export	_iop_diskopen
	.export _iop_diskop
	.export _iop_closeall


#define ESPCTRL	0xF4
#define ESPDATA	0xF5

#define ESPCMD_VERSION		0x02
#define ESPCMD_GETDATETIME	0x03
#define EPSCMD_GETMOUSE		0x0C
#define ESPCMD_OPEN		0x10
#define ESPCMD_CLOSE		0x11
#define ESPCMD_READ		0x12
#define ESPCMD_WRITE		0x13
#define ESPCMD_SEEK		0x14
#define ESPCMD_CLOSEALL		0x1F

	.common

espcmd:
	push	af
	ld	a, 0x83
	out	(ESPCTRL), a
	pop	af
esptx:
	push	af
esptxw:
	in	a,(ESPCTRL)
	and	2
	jr	nz, esptxw
	pop	af
	out	(ESPDATA), a
	ret
esprx:
	in	a,(ESPCTRL)
	rra
	jr	nc, esprx
	in	a, (ESPDATA)
	ret

esptxpath:
	ld	a,(hl)
	inc	hl
	or	a
	jr	z, esptx
	call	esptx
	jr	esptxpath


_iop_diskopen:
	di
	ld	a,(_disk_unit)
	add	a, '0'
	ld	(diskpathmod), a
	ld	a,ESPCMD_OPEN
	call	espcmd
	ld	a,2
	call	esptx
	ld	hl,diskpath
	call	esptxpath
	call	esprx
iop_exit:
	ld	l,a
	ld	a,(_int_disabled)
	or	a
	ret	nz
	ei
	ret

iosetup:
	ld	a, ESPCMD_SEEK
	call	espcmd
	ld	a, (_disk_unit)
	call	esptx
	ld	hl, _disk_lba
	ld	a,(hl)
	call	esptx
	inc	hl
	ld	a,(hl)
	call	esptx
	inc	hl
	ld	a,(hl)
	call	esptx
	inc	hl
	ld	a,(hl)
	call	esptx
	call	esprx
	or	a
	ret

iomap:
	ld	b, 0		; for counting
	ld	hl,(_disk_addr)	; address
	ld	a,(_td_raw)
	or	a
	ret	z		; no buffer maps
	dec	a
	jp	z, map_proc_always
	ld	a,(_td_page)
	jp	map_for_swap

_iop_diskop:
	call	iosetup
	jp	m, shortr
	ld	a, (_disk_op)
	or	a
	jr	z, do_write
	di
	; and now read
	ld	a, ESPCMD_READ
	call	espcmd
	ld	a, (_disk_unit)
	call	esptx
	ld	a, 0
	call	esptx
	ld	a, 2
	call	esptx
	call	esprx
	ld	h,0
	ld	l,a
	or	a
	ret	m
	call	esprx
	or	a
	jr	nz, shortr1
	call	esprx
	cp	2
	jr	nz, shortr
	; Load 512 bytes
	push	bc
	call	iomap
iord:
	call	esprx
	ld	(hl),a
	inc	hl
	call	esprx
	ld	(hl),a
	inc	hl
	djnz	iord
	pop	bc
	call	map_kernel
iop_rwout:
	xor	a
	jr	iop_exit
shortr1:
	call	esprx
shortr:
	ld	a, 255
	jr	iop_exit

do_write:
	di
	ld	a, ESPCMD_WRITE
	call	espcmd
	ld	a, (_disk_unit)
	call	esptx
	xor	a
	call	esptx
	ld	a, 2
	call	esptx
	push	bc
	call	iomap
iowr:
	ld	a,(hl)
	call	esptx
	inc	hl
	ld	a,(hl)
	call	esptx
	inc	hl
	djnz	iowr
	call	map_kernel
	pop	bc
	call	esprx
	bit	7,a
	jr	nz, iop_exit
	call	esprx
	or	a
	jr	nz, werr2
	call	esprx
	cp	2
	jr	nz, werr3
	jr	iop_rwout
werr2:	call	esprx		; Length wrong
werr3:	ld	a, 0xFF
	jr	iop_exit

_iop_closeall:
	ld	a, ESPCMD_CLOSEALL
	di
	call	espcmd
	call	esprx
	jr	iop_exit

	.data

diskpath:
	.ascii "FUZIXHD"
diskpathmod:
	.byte	0
	.ascii ".IMG"
	.byte	0
