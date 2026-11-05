	;
	; MOOH platform
	;

	; exported
	.export _mpi_present
	.export _mpi_set_slot
	.export _cart_hash
	.export _cart_analyze_hdb
	.export _hdb_id
	.export _hdb_port
	.export _hdb_timeout
	.export _bufpool
	.export _framedet

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar
	.export ___hard_di
	.export ___hard_ei
	.export ___hard_irqrestore

#include "kernel.def"
#include "../../cpu-6809/kernel09.def"

	.abs
	.org 0xFEF0
	;
	;	Will be at FFF0 once CRM is enabled
	;
	.word badswi_handler		; 6809 Reserved / 6309 Trap
	.word badswi_handler		; SWI3
	.word badswi_handler		; SWI2
	.word firq_handler		; FIRQ
	.word interrupt_handler		; IRQ
	.word unix_syscall_entry 		; SWI
	.word fd_nmi_handler		; NMI
	.word badswi_handler		; Restart

	.buffers
	;
	;	We use the linker to place these just below
	;	the discard area
	;
_bufpool:
	.ds	BUFSIZE*NBUFS

	;	And expose the discard buffer count to C - but in discard
	;	so we can blow it away and precomputed at link time
	.discard

init_early:
	ldx	#null_handler
	stx	1
	lda	#0x7E
	sta	0
	sta	0x0071		; BASIC cold boot flag
	ldx	#ramstub	; copy to internal RAM
cp2ram:	ldu	,x
	stu	,x++
	cmpx	#stubend
	blo	cp2ram
	rts

init_hardware:
	jsr	size_ram
	; Turn on PIA  CB1 (50Hz interrupt)
	lda	0xFF03
	ora	#1
	sta	0xFF03
	jsr	_vid256x192
	jsr	_vtinit
	; NTSC or PAL/SECAM ?
	ldx	#0
	lda	$ff02
waitvb0:
	lda	$ff03
	bpl	waitvb0		; wait for vsync
	lda	$ff02
waitvb2:
	leax	1,x		; time until vsync starts
	lda	$ff03
	bpl	waitvb2
	stx	_framedet
	rts

_framedet:
	.word	0

; old p6809.s stuff below

	; exported symbols
	.export init_early
	.export init_hardware
	.export _program_vectors
	.export _need_resched

	.commondata

; in a place where internal memory is kept alone

_plt_reboot:
	ldd	#0x3F3F
	orcc	#0x10
	sta	0x0071		; cold boot flag for ROM reset handler
	std	0xFFA2		; unmap at 0x4000 and 0x6000
	std	0xFFA4		; unmap at 0x8000 and 0xA000
	std	0xFFA6		; unmap at 0xC000 and 0xE000
	clr	0xFF90		; disable MMU
ramstub:    			; runs from internal RAM
	std	0xFFA0		; reset MMU config for 0x0000 and 0x2000
	jmp	[0xFFFE]	; BASIC ROM & vectors are back
stubend:

	.common

_plt_monitor:
	orcc #0x10
	bra _plt_monitor

___hard_di:
	tfr cc,b		; return the old irq state
	orcc #0x10
	rts
___hard_ei:
	andcc #0xef
	rts

___hard_irqrestore:		; B holds the data
	tfr b,cc
	rts

;
;------------------------------------------------------------------------------
; COMMON MEMORY PROCEDURES FOLLOW


	.common

;
;	In the MOOH case our vectors live in a fixed block
; 	and is not banked out.
; 	However, hook in the MMU refresh here
; 	(called by pagemap_realloc and makeproc)
;
_program_vectors:
	tfr	d,x
	ldx	,x		; dereference pointer to udata.u_page
	pshs	cc
	orcc	#0x10
	jsr	mmu_remap_x
	puls	cc,pc


;
;	Helpers for the MPI and Cartridge Detect
;

	.code
;
;	oldslot = mpi_set_slot(uint8_t newslot)
;
_mpi_set_slot:
	tfr	b,a
	ldb	0xff7f
	sta	0xff7f
	rts
;
;	int8_t mpi_present(void)
;
_mpi_present:
	lda	0xff7f	; Save bits
	tfr	a,b
	lsrb
	lsrb
	lsrb
	lsrb
	eorb	0xff7f
	andb	#0x03	; We expect to see the bits 5-4 and 1-0 matching
	bne	nompi	; not guaranteed but a good rule of thumb for us
	ldb	#0xff	; Will get back 33 from an MPI cartridge
	stb	0xff7f	; if the emulator is right on this
	ldb	0xff7f
	andb	#0x33
	cmpb	#0x33
	bne	nompi
	clr	0xff7f	; Switch to slot 0
	ldb	0xff7f
	andb	#0x33	; We can't trust the high bits
	bne	nompi
	incb
	sta	0xff7f	; Our becker port for debug will be on the default
			; slot so put it back for now
	rts		; B = 1
nompi:	ldb	#0
	sta	0xff7f	; Restore bits just in case
	rts


; this can be anywhere below 0xC000
	; FIXME
;	.area .ncart
	.code
;
;	uint16_t cart_hash(void)
;
_cart_hash:
	pshs	cc
	orcc	#0x10
	ldx	#0xC000
	lda	#$3F
	sta	$FFA6	; unmap kernel in cartridge area C000-DFFF
	clra
	clrb
hashl:
	addd	,x++
	cmpx	#0xC200
	bne	hashl
	tfr	d,x
	lda	#2
	sta	$FFA6	; map kernel back
	puls	cc,pc

_cart_analyze_hdb:
	pshs	cc
	orcc	#0x10
	lda	#$3F
	sta	$FFA6		; unmap kernel in cartridge area C000-DFFF
	ldd	0xD93B		; I/O port
	std	_hdb_port
	ldd	0xD93D		; Timeout and ID if SCSI
	std	_hdb_timeout
	; Shortly after that fixed block we will find the sign on and
	; copyright, which tell us what interface we are for.
	ldx	#0xD940
hdb_s_next:
	cmpx	#0xE000
	beq	no_sign		; No sign of the sign on !
	lda	,x+
	cmpa	#'H'
	bne	hdb_s_next
	lda	,x+
	cmpa	#'D'		; This is safe as we know the bytes before
	bne	hdb_s_next	; our match are AUTOEXEC.BAS so won't partially
	lda	,x+		; match !
	cmpa	#'B'
	bne	hdb_s_next
	lda	,x+
	cmpa	#'-'
	bne	hdb_s_next
	;
	; We have found the HDB-. X now points at the D of DOS
	;
	leax	6,x		; Skip version
	;
	; We now have to find a space
	;
hdb_s_spc:
	cmpx	#0xE000
	beq	no_sign
	lda	,x+
	cmpa	#0x20
	bne	hdb_s_spc
	;
	; This is followed by a string. For those we care about the first
	; letters are sufficient to tell them apart
	;
	; LB : IDE LBA
	; ID : IDE CHS
	; TC : TC^3 SCSI
	; KE : Kenton
	; LR : LR Tech 
	; HD : HD-II
	; 4- : 4-N-1
	; DW : Drivewire stuff	} Need more identification but are not 
	; BE : Becker ports 	} interesting to us anyway
	; J& : J&M CP
	ldx	,x
ret1:
	lda	#2
	sta	$FFA6	; map kernel back
	puls	cc,pc
no_sign:
	ldx	#-1
	bra	ret1

; Need to be here so they can be written with cart paged in
	; FIXME where ?
	.data

_hdb_port:
	.word 0
_hdb_timeout:
	.byte 0
_hdb_id:
	.byte 0
_hdb_type:
	.byte 0	

	.code
;
;	Joystick helper
;
;	jsread(buffer)
;
;	Returns a buffer of words in the format
;	right left/right, button
;	right up/down, button
;	left left/right, button
;	left up/down, button
;
	.export _jsread

_jsread:
	tfr	d,x
	; Buffer is in D on entry
	pshs	u
	lda	#$FF
	sta	$FF02		; Keyboard scan lines off
	lda	#$08		; Select right joystick
	sta	$FF23		; Sound off a moment
	bsr	jstwo
	lda	#$09
	bsr	jstwo
	puls	u,pc
jstwo:
	sta	$FF03		; P0 CR B - select joystick L or R
	lda	#$04
	sta	$FF01		; X
	bsr	jsfind
	lda	#$0C		; Y
	sta	$FF01
	; Fall through
jsfind:
	ldu	#jstmp
	; Binary search the joystick DAC position
	lda	#$20
	sta	,u		; start in the middle and binary search
jssearch:
	lsr	,u
	beq	jsdone
	sta	$FF20
	tst	$FF20
	bpl	jsover
	adda	,u
	bra	jssearch
jsover:
	suba	,u
	bra	jssearch
jsdone:
	ldb	$FF20	; save fire button in bit 0
	std	,x++
	rts

	.data

jstmp:
	.byte 0

	.common
;
;	FIXME:
;
firq_handler:
badswi_handler:
	rti

;
;	debug via printer port
;
outchar:
	sta	0xFF02
	lda	0xFF20
	ora	#0x02
	sta	0xFF20
	anda	#0xFD
	sta	0xFF20
	rts

	.commondata

_need_resched:
	.byte 0
