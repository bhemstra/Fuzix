;
;	TRS 80  hardware support
;
	; exported symbols
	.export init_early
	.export _program_vectors
	.export plt_interrupt_all
	.export _int_disabled

	; hard disk helpers
	.export _hd_xfer_in
	.export _hd_xfer_out

	; exported debugging tools
	.export _plt_monitor
	.export _plt_reboot
	.export outchar

	.export _bufpool

#include "../../build/kernelu.def"
#include "../../cpu-z80u/kernel-z80.def"

	.buffers
_bufpool:
	.ds BUFSIZE * NBUFS

	.common

_int_disabled:
	.byte	1

_plt_monitor:
	di
	halt

plt_interrupt_all:
	ret

;
;	We write the following into low memory
;	out (0x84),a
;	inc a
;	out (0x9c),a
;	.. then resets into ROM (see the technical reference manual)
;
_plt_reboot:
	di
	ld	hl,0x84D3		; out (0x84),a
	ld	(0),hl
	ld	hl,0xD33C		; inc a, out (
	ld	(2),hl
	ld	a,0x9C			; 9c),a
	ld	(4),a
	xor a
	rst 0

	.code

	.export _plt_idle
_plt_idle:
	halt
	ret

_ctc6845:			; registers in order
	.byte 99, 80, 85, 10, 25, 4, 24, 24, 0, 9, 101, 9, 0, 0, 0, 0
init_early:
	ld	a, 0x24		; uart rx, timer
	out	(0xE0), a
	ld	a, (_opreg)
	out	(0x84), a
	ld	a, (_modout)
	out	(0xEC), a

	; load the 6845 parameters
	ld	hl, _ctc6845
	ld	bc, 0x88
crtcloop:
	out	(c), b		; register
	ld	a, (hl)
	out	(0x89), a	; data
	inc	hl
	inc	b
	bit	4,b
	jr	z, crtcloop

   	; clear screen
	ld	hl, 0xF800
	ld	(hl), '*'		; debugging aid in top left
	inc	hl
	ld	de, 0xF802
	ld	bc, 1998
	ld	(hl), ' '
	ldir
	ret

	.common

_program_vectors:
	; we are called, with interrupts disabled, by both newproc() and crt0
	; will exit with interrupts off
	di ; just to be sure
	pop	de ; temporarily store return address
	pop	hl ; function argument -- base page number
	push	hl ; put stack back as it was
	push	de
	push	bc

	call	map_proc

	; write zeroes across all vectors
	ld	hl, 0
	ld	de, 1
	ld	bc, 0x007f	; program first 0x80 bytes only
	ld	(hl), 0x00
	ldir

	; now install the interrupt vector at 0x0038
	ld	a, 0xC3 ; JP instruction
	ld	(0x0038), a
	ld	hl, interrupt_handler
	ld	(0x0039), hl

	ld	(0x0000), a   
	ld	hl, null_handler   ;   to Our Trap Handler
	ld	(0x0001), hl

	ld	(0x0066), a  ; Set vector for NMI
	ld	hl, fd_nmi_handler
	ld	(0x0067), hl
	pop	bc
	jp	map_kernel
	
; outchar: Wait for UART TX idle, then print the char in A
; destroys: AF
outchar:
	; FIXME: wait idle (works fine on emu as is of course)
	out	(0xEB), a
	ret

;
;	Read I/O memory'
;
	.export _ioread

_ioread:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_io
	ld	l,(hl)
	jp	map_kernel


;
;	Swap helpers
;
_hd_xfer_in:
	pop	de
	pop	hl
	push	hl
	push	de
	ld	a, (_hd_page)
	or	a
	call 	nz, map_proc_a
	push	bc
	ld	bc, #0xC8		; 256 bytes from 0xC8
	inir
	pop	bc
	jp	map_kernel

_hd_xfer_out:
	pop	de
	pop	hl
	push	hl
	push	de
	ld	a, (_hd_page)
	or	a
	call	nz, map_proc_a
	push	bc
	ld	bc, #0xC8		; 256 bytes to 0xC8
	otir
	pop	bc
xfer_out_wait:				; busy wait after OTIR
	ex	(sp), hl
	ex	(sp), hl
	in	a,(0xCF)
	rlca
	jr	c, xfer_out_wait
	jp	map_kernel

;
;	Keyboard
;
	.code		; Need these below the I/O range

	.export _keyscan
	.export _anykey

_keyscan:
	push	bc
	call	map_io_slow
	ld	b,8
	ld	hl,0xF401
	ld	de,_keyin
scank:
	ld	a,(hl)
	ld	(de),a
	inc	de
	sla	l
	djnz	scank
	pop	bc
	jp	map_kernel_fast

_anykey:
	call	map_io_slow
	ld	a,(0xF4FF)
	ld	l,a
	jp	map_kernel_fast


;
;	Display
;
videopos:
	; E = Y D = X, output HL = addr, C preserved
	ld	a,e
	add	a,a	;	x 2 (max 50)
	ld	l,a	;
	add	a,a	;	x 4 (max 100)
	add	a,a	;	x 8 (max 200)
	add	a,l	;	x 10 (max 250)
	ld	l,a
	ld	h,0
	add	hl,hl  ;	x 20
	add	hl,hl  ;	x 40
	add	hl,hl  ;	x 80
	ld	e,d
	ld	d,0
	add	hl,de		; Now holds the offset
	ld	de,0xF800
	add	hl,de		; and screen mapped address
	ld	a, (_curtty)
	ld	e,a
	ld	a,(_inputtty)
	cp	e
	ret	nz		; map kernel buffer
	jp	 map_io		; map screen

	.export _plot_char
	.export _scroll_up
	.export _scroll_down
	.export _clear_lines
	.export _clear_across
	.export _cursor_on
	.export _cursor_off
	.export _cursor_disable
	.export _vtattr_notify

_plot_char:
	push	bc
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	c,(hl)
	call	videopos
	ld	(hl),c
	pop	bc
	jp	map_kernel

_scroll_down:
	push	bc
	ld	hl,0xFF2F	; last byte of last-but-one line
	ld	de,0xFF7F	; last byte of last line
	ld	bc,0x0730	; all but one line
	call	map_io
	lddr		; copy down one line (to a higher address)
	pop	bc
	jp	map_kernel

_scroll_up:
	push	bc
	ld	hl,0xF850
	ld	de,0xF800
	ld	bc,0x0730
	call	map_io
	ldir
	pop	bc
	jp	map_kernel

_clear_lines:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)		; Clear D lines from line E
	xor	a
	cp	d		; no work ?
	ret	z
	push	bc
	ld	c,d		; save
	ld	d,a		; clear d
	call	videopos
	ld	a,0x20
wipeo:
	ld	b,0x50
wipe1:
	ld	(hl),a
	inc	hl
	djnz	wipe1
	dec	c
	jr	nz,wipeo
	pop	bc
	jp	map_kernel

_clear_across:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	inc	hl
	inc	hl
	ld	a,(hl)
	; DE = coords, A = count
	or	a
	ret	z		; No work
	push	bc
	ld	b,a
	call	videopos
	ld	a,0x20
wipea:
	ld	(hl),a
	inc	hl
	djnz	wipea
	pop	bc
	jp	map_kernel

_cursor_on:
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	inc	hl
	ld	d,(hl)
	call	videopos
	ld	a,(hl)
	ld	(cursorpos),hl
	ld	(cursorpeek),a
	ld	(hl),0x8F
	jp	map_kernel

_cursor_off:
	call	map_io
	ld	hl,(cursorpos)
	ld	a,(cursorpeek)
	ld	(hl),a
	jp	map_kernel

_vtattr_notify:
_cursor_disable:
	ret

	.commondata

cursorpos:
	.word	0
cursorpeek:
	.byte	0
_video_lower:
	.byte	0

;
;	Video screen flip
;
;	This is a bit funky. Our screen is always at 0xF800 but we
;	also have main memory we can expose at the same address so that
;	means we can keep everything simple and the alt buffer is in
;	that RAM at the same location. The one downer is we can't hardware
;	switch so when the user changes the displayed console we have to
;	to flip the two banks
;

	.export	_vt_swap
_vt_swap:
	push	bc
	ld	a,(_opreg)	; Get the kernel mapping
	ld	e,a		; Kernel
	and	0xFE		; clear I/O bit
	ld	d,a		; I/O
	ld	c,0x84		; control port
	ld	hl, 0xF800	; base
	di			; playing fast and loose with I/O map
vtcopy:
	ld	a,(hl)
	out	(c),d		; map I/O space
	ld	b,(hl)
	ld	(hl),a
	out	(c),e		; kernel map
	ld	(hl),b		; byte done
	inc	hl
	bit	7,h
	jr	nz,vtcopy	; we copy a few bytes extra but its cheaper
	pop	bc
	ld	a,(_int_disabled)
	or	a
	ret	nz
	ei
	ret

;
;	Graphics
;
	.export _gfx_write
	.export _gfx_read
	.export _gfx_draw
	.export _gfx_exg
	.export _gfx_blit

_gfx_write:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always
	push	ix
	push	bc
	push	hl
	pop	ix
	ld	de,8
	add	hl,de

	ld	e,(ix + 6)	; Lines to do
	ld	d,(ix + 4)	; Y

	ld	a,(_ctrl_cache)
	or	0x40		; clock X on write
	out	(0x83),a
	ld	c,0x82			; data

wnextline:
	ld	a,d
	out	(0x81),a	; set Y
	ld	b,(ix + 4)	; width
	ld	a,(ix+ 0)	; X left
	out	(0x80),a
	otir			; write bytes
	inc	d		; move down
	dec	e		; count one off
	jr	nz, wnextline
	pop	bc
	pop	ix
	ld	hl,0
	jp	map_kernel


_gfx_read:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always
	push	ix
	push	bc
	push	hl
	pop	ix
	ld	de,8
	add	hl,de

	ld	e,(ix + 4)	; Lines to do
	ld	d,(ix + 0)	; Y

	ld a,(_ctrl_cache)
	or	0x10		; clock X on read
	out	(0x83),a
	ld	c,0x82		; data

rnextline:
	ld	a,d
	out	(0x81),a	; set Y
	ld	b,(ix + 6)	; width
	ld	a,(ix + 2)	; X left
	out	(0x80),a
	inir			; write bytes
	inc	d		; move down
	dec	e		; count one off
	jr	nz, rnextline
	pop	bc
	pop	ix
	ld	hl,0
	jp	map_kernel

_gfx_exg:
	pop	hl
	pop	de
	call	map_proc_always
	push	ix
	push	bc
	push	hl
	pop	ix
	ld	de,8
	add	hl,de

	ld	e,(ix + 4)	; Lines to do
	ld	d,(ix + 0)	; Y

	ld	a,(_ctrl_cache)
	or	0x20		; clock X on write
	out	(0x83),a
	ld	c,0x82		; data

enextline:
	ld	a,d
	out	(0x81),a	; set Y
	ld	b,(ix + 6)	; width
	ld	a,(ix + 2)	; X left
	out	(0x80),a
ebyte:
	ld	a,(hl)		; get new
	ini			; read byte to memory
	out	(0x82),a	; write new and inc
	djnz	ebyte
	inc	d		; move down
	dec	e		; count one off
	jr	nz, enextline
	pop	bc
	pop	ix
	ld	hl,0
	jp	map_kernel

_gfx_draw:
	pop	de
	pop	hl
	push	hl
	push	de
	call	map_proc_always	; Length, Y, X
	ld	de,	6			
	add	hl,de
	push	ix
	push	bc
	push	hl
	pop	ix
	ld	a,(_ctrl_cache)
	or	0x40		; clock X on write
	out	(0x83),a
	ld	d,(ix + 4)	; X
	ld	e,(ix + 2)	; Y
nextopline:
	; Set position
	ld	a,d
	out	(0x80),a
	ld	a,e
	out	(0x81),a
nextop:
	xor	a
	ld	b,(hl)
	cp	b
	jr	z,line_done
	inc	hl
	ld	c,(hl)
	inc	hl
oploop:
	in	a,(0x82)	; read no inc
	and	c
	xor	(hl)
	out	(0x82),a	; write, inc
	djnz	oploop
	inc	hl
	jr	nextop
line_done:
	inc	e		; down a line
	xor	a
	cp	(hl)
	jr	nz, nextopline
	pop	bc
	pop	ix
	ld	hl,0
	jp	map_kernel

; We can use bouncebuffer as we will never fork mid blit

_gfx_blit:
	pop	de
	pop	hl
	push	hl
	push	de
	push	ix
	push	bc
	push	hl
	pop	ix

	ld	d,(ix + 10)	; width
	res	7,d

	exx
	ld	a,(_ctrl_cache)
	or	0x10		; alt bc are the config sets
	ld	b,a
	xor	0x30
	ld	c,a
	exx

	ld	a,(ix + 0)	; Compare Y
	cp	(ix + 4)
	jr	c, blitrd
	jr	nz, blitlu
	ld	a,(ix + 2)	; and X
	cp	(ix + 6)
	jr	c, blitrd

blitlu:
	ld	e,(ix + 8)	; start on bottom line and work up
	dec	e
blitlu_n:
	exx
	ld	a,b
	out	(0x83),a
	exx
	ld	a,(ix + 2)	; source X
	out	(0x80),a
	ld	a,e
	add	a, (ix + 0)	; add Y source
	out	(0x81),a
	ld	b,d		; width of line
	ld	hl,bouncebuffer
	inir
	exx
	ld	a,(ix + 6)
	out	(0x80),a
	ld	a,e
	add	a, (ix + 4)	; add Y dest
	out	(0x81),a
	ld	a,c
	out	(0x83),a
	exx	
	ld	b,d
	ld	hl,bouncebuffer
	otir
	dec	e
	jr	nz, blitlu_n
	pop	ix
	ld	hl,0
	ret
	
blitrd:
	ld	e,0		; line counter
blitrd_n:
	exx
	ld	a,b
	out	(0x83),a
	exx
	ld	a,d		; source X
	out	(0x80),a
	ld	a,e
	add 	a, (ix + 0)	; add Y source
	out	(0x81),a
	ld	b,(ix + 8)	; width of line
	ld	hl,bouncebuffer
	inir
	exx
	ld	a,d
	out	(0x80),a
	ld	a,e
	add	a, (ix + 4)	; add Y dest
	out	(0x81),a
	ld	a,c
	out	(0x83),a
	exx	
	ld	b,(ix + 8)
	ld	hl,bouncebuffer
	otir
	inc	e
	ld	a, (ix + 8)	; height match ?
	cp	e
	jr	nz, blitrd_n
	pop	ix
	ld	hl,0
	ret


;
;	Should this be in the common base code ?
;
	.code
	.export	_memmove

_memmove:
	push	hl
	push	bc
	ld	hl,11
	add	hl,sp
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	; To HL from DE for BC length
	ld	a,b
	or	c
	jr	z, nowork
	; Which way do we do it ?
	push	hl
	or	a
	sbc	hl,de
	pop	hl
	jr	z, nowork
	jr	nc,lowhi
	ex	de,hl
	; HL < DE so we are copying downwards
	ldir
nowork:	pop	bc
	pop	hl
	ret
lowhi:
	dec	bc
	add	hl,bc
	ex	de,hl
	add	hl,bc
	inc	bc
	lddr
	pop	bc
	pop	hl
	ret

;
;	MegaMEM RAM disc
;
;	User is at 0x0000-7FFF and were are above 0xC000 so use 8000-BFFF
;	for the transfer

	.common
	.export _megamem_io

_megamem_io:
	push	bc
	ld	bc,(_mega_io)
	ld	hl,(_mega_src)
	ld	de,(_mega_dest)
	ld	a,(_mega_page)
	or	a
	call	nz, map_proc_a
	di
	out	(c),b		; turn on
	ld	bc,512
	ldir
	ld	bc,0x0060	; and off
	out	(c),b
	pop	bc
	ld	a,(_int_disabled)
	or	a
	jp	nz,map_kernel
	ei
	jp	map_kernel

	.discard

	.export _megamem_probe

_megamem_probe:
	push	bc
	ld	bc, 0x0060	; ensure it's off
	out	(c),b
	ld	hl, 0x8000	; good as anywhere
	ld	e,(hl)
	push	de		; save original value in base mmory
	ld	a,e
	out	(c),h		; megamem on
	inc	(hl)
	out	(c),b		; now off
	cp 	(hl)		; we didn't modify the base copy
	jr	z, is_megamem	; ok it didn't change
	; Base copy changed so isn't a megamem
	pop	de
	ld	(hl),e		; ensure memory is back right
	ld	hl,0
	pop	bc
	ret
is_megamem:
	; Next game how many megabytes
	ld	b,h		; 0x80 for memory region
count_mega:
	out	(c),b		; select bank
	ld	a,(hl)
	inc	(hl)		; see if it changes
	cp	(hl)
	jr	z, mega_done	; assume populated in order
	inc	c		; now try the next bank
	ld 	a,c
	and	0x0F
	jr	nz, count_mega	; we've done all 16 possible banks ?
mega_done:
	ld	a,c
	sub	0x60		; base of the megaram
	; Number of banks is now in A (each 1MB)
	; We get 2048 sectors per bank
	add	a,a
	add	a,a
	add	a,a		; number of 512 byte sectors (high bye)
	pop	de
	ld	(hl),e		; restore memory
	ld	h,a
	xor	a
	out	(0x60),a	; megaram off
	ld	l,a
	pop	bc
	ret			; sectors

