;
;	REU related operations
;
	.discard
	.export _size_reu

#include "kernel.def"

no_reu:
	lda	#0
	tax
	rts

_size_reu:
	lda	#<reuct
	sta	0xDF02
	lda	0xDF02
	cmp	#<reuct
	bne	no_reu

	lda	#>reuct
	sta	0xDF03
	lda	0xDF03
	cmp	#>reuct
	bne	no_reu

	; Ok so now size it

	lda	#0
	sta	0xDF04		; Address 0 within bank
	sta	0xDF05
	sta	0xDF08		; Upper length 0
	sta	0xDF0A		; Incrementing addresses
	lda	#1
	sta	0xDF07		; Lowr length 1

	; We are set up to DMA between reuct and byte 0 of the REU for 1
	; byte

	ldx	#0

next:
	stx	0xDF06		; Bank X
	stx	reuct

	;	Write the bank number into the bank
	;	and read it back

	lda	#0xB0		; transfer to REU with reload
	sta	0xDF01
	lda	#0xB1		; and back with reload
	sta	0xDF01
	cpx	reuct		; Did we get the same value back ?
	bne	xfer_fail	; we failed to read/write back
				; so not a valid bank

	;
	;	Most REU devices don't stop but wrap at their
	;	limit so check if we scribbled on bank 0
	;
	lda	#0x00		; Bank 0
	sta	0xDF06		; transfer
	lda	#0xB1
	sta	0xDF01		; copy into reuct
	lda	reuct		; Should be 0 still
	bne	xfer_wrap	; We scribbled onto bank 0 

	inx
	bne	next

	; 16MB REU ????	report 256 banks
	lda	#0
	ldx	#1
	rts

xfer_fail:
xfer_wrap:
	lda	#0
	sta	reuct
	sta	0xDF06		; Bank 0
	lda	#0xB0
	sta	0xDF01		; Write the 0 into 000000 REU space
	; X is the first bank that is absent
	; Thus X is the number of banks
	txa
	ldx	#0
	rts


reuct:	.byte	0

	.code

#if 0
	.export _scroll_down
	.export _scroll_up

;
;	REU display routines
;
;	TODO: colour RAM
;
_scroll_down:
	lda	#0
	beq	scroll
_scroll_up:
	; Screen bounce buffer lives at 000004 in REU space
	lda	#0x28
scroll:
	php
	sei
	sta	0xDF02
	ldx	#0
	stx	0xDF05
	stx	0xDF06
	stx	0xDF0A
	ldx	#0x04
	stx	0xDF03		; from 0428
	stx	0xDF04		; to 000004
	ldx	#0xC0
	stx	0xDF07
	ldx	#0x03
	stx	0xDF08		; 3C0 bytes
	ldx	#0xB0
	stx	0xDF01		; copy to REU, restore pointers
	eor	#0x28		; switch line so we can do up or down
	sta	0xDF02
	ldx	#0xB1		; copy back offset
	stx	0xDF01
	ldx	#0xD8
	stx	0xDF03		; from D800
	eor	#0x28
	sta	0xDF02		; set screen to D800 or D828
	ldx	#0xB0
	stx	0xDF01		; copy into scratch
	eor	#0x28
	sta	0xDF02
	ldx	#0xB1
	stx	0xDF01		; copy back
	plp
	rts

#endif

; 	uzero(addr, len)

setupz:
	jsr	__pop
	sta	0xDF02		; Target address on C64
	stx	0xDF03
	lda	#0
	sta	0xDF04		; A zero byte on the REU
	sta	0xDF05
	sta	0XDF06
	jsr	__pop
	sta	0xDF07		; Length (beware 0 is nothing!)
	stx	0xDF08
	ora	0xDF08
	beq	notask
	lda	#0x40		; Don't increment REU address
	sta	0xDF0A
	lda	#0x81		; Fetch , wait for FF00
	sta	0xDF01
notask:
	; EQ - no work, NE - do op
	rts

	.common

	.export __uzero

__uzero:
	php
	sei
	jsr	setupz
	beq	nocopy
	jsr	map_proc_always
	sta	0xFF00		; Fire
nocopy:
	plp
	jmp	map_kernel

; Not yet used but basically free with uzero

	.export __bzero

__bzero:
	php
	sei
	jsr	setupz
	beq	nocopy
	sta	0xFF00	; Fire
	plp
	rts

uputgetin:
	jsr	__pop
	sta	0xDF02		; Source
	stx	0xDF03
	jsr	__pop
	sta	@tmp		; Destination
	stx	@tmp+1
	jsr	__pop
	sta	0xDF07		; Length
	stx	0xDF08
	ora	0xDF08
	beq	noputget
	lda	#0		; Will always be under 1K
	sta	0xDF05
	sta	0xDF06
	sta	0xDF0A		; copy with increment
	lda	#0x04		; REU address for work buffer is 4
	sta	0xDF04
	lda	#0xA0
	sta	0xDF01
noputget:
	rts

uputgetout:
	;	Most values were restored by the REU itself
	lda	@tmp
	sta	0xDF02
	lda	@tmp+1
	sta	0xDF03
	lda	#0xA1		; state is ready for copy anyway
	sta	0xDF01
	lda	#0		; return value is 0
	tax
	rts

	.export __uget
__uget:
	php
	sei
	jsr	uputgetin
	beq	noopg
	; REU is waiting for FF00 trigger
	jsr	map_proc_always
	sta	0xFF00
	; Copied
	jsr	map_kernel
	jsr	uputgetout
	sta	0xFF00
noopg:
	plp
	rts

	.export __uput
__uput:
	php
	sei
	jsr	uputgetin
	beq	noopg
	sta	0xFF00
	jsr	uputgetout
	jsr	map_proc_always
	sta	0xFF00
	plp
	jmp	map_kernel

#if 0
;
;	Need to fix VICE first
;
;	We will want buffers in the REU eventually but start simnple
;

;
;	Set up the controller basics for our Disk I/O
;	Length 512, REU address 000004
;
disk_prep:
	lda	#2
	sta	0xDF08		; 512 byte blocks
	lda	#4
	sta	0xDF04		; Work buffer is at REU 000004
	; Clear the other bits as needed
	lda	#0
	sta	0xDF05
	sta	0xDF06
	sta	0xDF07
	rts

;
;	Set the C64 side to the IDE data port, constant C64 address
;
disk_setup:
	lda	#0x20	
	sta	0xDF02
	lda	#0xDE
	sta	0xDF03		; IDE is at DE20
	lda	#0x80		; C64 side constant
	sta	0xDF0A
	sty	0xDF01		; command to use
	rts

;
;	Perform a copy to our from user space mapping as needed
;	The command to use is passed in Y, the rest is the same
;	either direction
;
data_io:
	jsr	__pop
	sta	0xDF02		; get address
	stx	0xDF03
	lda	#0
	sta	0xDF0A		; addresses incrementing
	sty	0xDF01		; operation code
	lda	_td_raw		; op type
	beq	rdkernel
	; Once we do multiple banking this needs to check for swap
	; as well but that will be after our buffers are on REU anyway
	jsr	map_proc_always
rdkernel:
	sta	0xFF00		; transfer to user/buffer happens here
	jmp	map_kernel

_devide_read_data:
	php
	sei
	;	Pull the block off disk before we even worry
	;	about where it goes
	jsr	disk_prep
	ldy	#0xB0		; from C64 to REU, preserve regs, now
	jsr	disk_setup
	;
	;	Now put it in the right place
	;
	ldy	#0xA1		; from REU to C64, trigger on FF00
	jsr	data_io		; copies to the user
ide_out:
	plp			; interrupt state restore
nbusyr:
	lda	0xDE20		; wait for it to stop being busy
	bmi	nbusyr
	lda	0xDE20		; error info
	and	#1
	eor	#1
	ldx	#0
	rts

devide_write_data:
	php
	sei
	;	Get into the REU before writing
	jsr	disk_prep
	ldy	#0xA0		; from C64 to REU, trigger on FF00
	jsr	data_io
	ldy	#0xB1		; from REU to C64, preserve regs, now
	jsr	disk_setup
	lda	#0xB1		; from REU to C64
	sta	0xDF01		; out to the disk controller
	bne	ide_out

#endif

;
;	Task switching. Exchange current task with bank Y. We
;	don't trigger the final transfer as we want that to happen in the
;	caller so our overwriting of the live stack underneath us works
;	out nicely
;
;	Our task banks are numbered 1-n and we use 0 to n-1 as actual. The
;	actual REU banks keep changing as we swap tasks around so we keep
;	an array bank2reu as a lookup table betwen the p_page values and
;	where it currently maps
;
;	On a task swap
;		bank2reu[old] = bank2reu[new]
;		bank2reu[new] = 0xFF	; as old was always "in memory"
;
;	On a fork
;		new proc gets allocated a slot and this will map to
;		an unused REU bank which we stick in _livebank in the
;		caller
;
;		basnk2reu[old] = allocated slot
;		bank2reu[new] = 0xFF	; we run child first
;
;	Called with interrupts off
;
;	_livebank is the bank number of the current task
;	_bank2reu translates between bank numbers and current REU bank
;
;

	.export taskcopy

taskcopy:
	lda	#0xA0			;	Copy to REU
	bne	docopy
	.export taskswap

taskswap:
	lda	#0xA2			;	Swap
docopy:
	pha
	sei
	lda	_bank2reu-1,y		; 	Where is our bank on the REU ?
	ldx	_livebank		;	Current live task
	sta	0xDF06			;	REU bank
	sta	_bank2reu-1,x		;	Our swap slot will become
					;	our predecessors
	sty	_livebank		;	We are now the live bank code
	lda	#0xFF
	sta	_bank2reu-1,y		;	We are 0xFF (main memory)

	; Swap or copy 3E00-FE00 (3E00-3FFF is udata, 4000-FEFF process)
	lda	#>REUSWITCH		;	User base
	sta	0xDF03
	sta	0xDF05
	lda	#>REUSWITCHSIZE
	sta	0xDF08			;	Size
	lda	#0x00
	sta	0xDF02
	sta	0xDF04
	sta	0xDF07
	sta	0xDF0A
	pla
	tay
	; Set up the transfer
	sty	0xDF01
	jsr	map_proc_always
	; FF00 reference will trigger swap
	sta	0xFF00
	jsr	map_kernel		;	map I/O back in
	; Now set up for Z and S
	; We save Z 0x0A-0x4F and the whole of S
	lda	#0
	sta	0xDF03			;	clear high bytes
	sta	0xDF08
	lda	#@sp			;	from 0002
	sta	0xDF02
	; *** ADJUST THIS IF YOU TWEAK SHARED ZP BITS ***
	lda	#58			;	save kernel/user switched only
	sta	0xDF07
	lda	#>REUZP			;	store below the main copy
	sta	0xDF05
	sty	0xDF01			;	transfer
	sta	0xFF00			;	and trigger
	lda	#0x00
	sta	0xDF02			;	clear low
	sta	0xDF07
	lda	#0x01
	sta	0xDF03			;	from 0100
	sta	0xDF08			;	for 0100
	lda	#>REUZP+256		;	store below the main copy
	sta	0xDF05
	sty	0xDF01			;	caller will trigger
	rts

	.data

	.export _livebank
	.export _bank2reu
;
;	Allow for up to 32 banks (2MB) 1 in memory
;
_livebank:
	.byte	1
;
;	Start with a linear mapping. This will change as we exchange tasks
;
_bank2reu:
	.byte	0xFF,0,1,2,3,4,5,6,7
	.byte	8,9,10,11,12,13,14,15
	.byte	16,17,18,19,20,21,22,23
	.byte	24,25,26,27,28,29,30,31
