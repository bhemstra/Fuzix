;
;	Interface to a CP/M 2.2 BIOS
;
;	We assume the BIOS is in the common space.
;
	.export _cpm_const
	.export _cpm_conin
	.export _cpm_conout
	.export _cpm_list
	.export _cpm_punch
	.export _cpm_reader
	.export _cpm_home
	.export _cpm_seldsk
	.export _cpm_settrk
	.export _cpm_setsec
	.export _cpm_setdma
	.export _cpm_read
	.export _cpm_write
	.export _cpm_listst
	.export _cpm_sectran

	.export _cpm_diskread
	.export _cpm_diskwrite

	.export _cpm_map

	.export biosbase


;
;	Call the bios function whose entry offset is in A, return to the
;	layer above.
;
; These calls also copy A into L on return but it doesn't matter

	.common

;
;	Call passed argument in BC or C argument is currently on C stack
;	Result usually ends up in A so is switched into L by helper. Must
;	preserve BC. CP/M doesn't use (or preserves) IX and IY unless your
;	BIOS is broken.
;
bioscall_bc:
bioscall_c:
	pop de
	pop hl		; argument is in HL
	push hl
	push de
	push bc
	ld c,l
	ld b,h
	call bioscall
	pop bc
	ret
;
;	No argument result in A
;
bioscall_a:
	push bc
	call bioscall
	pop bc
	ld l,a
	ret
;
;	No argument result in HL
;
bioscall_hl:
	push bc
	call bioscall
	pop bc
	ret
;
;	Perform a bios call. The entry offset is in A, so the called BIOS
;	routine returns straight to our caller.
;
bioscall:
	ld hl,(biosbase)
	ld l,a
callhl:	jp (hl)

;
;	Standard CP/M entry points
;
_cpm_const:
	ld a,6		; call 2
	jr bioscall_a
_cpm_conin:
	ld a,9		; call 3
	jr bioscall_a
	.byte 9		; call 3
_cpm_conout:
	ld a,12		; call 4
	jr bioscall_c
_cpm_list:
	ld a,15		; call 5
	jr bioscall_c
_cpm_punch:
	ld a,18
	jr bioscall_c
_cpm_reader:
	ld a,21
	jr bioscall_a
_cpm_home:
	ld a,24
	jr bioscall_a
_cpm_settrk:
	ld a,30
	jr bioscall_bc
_cpm_setsec:
	ld a,33
	jr bioscall_bc
_cpm_setdma:
	ld a,36
	jr bioscall_bc
_cpm_read:
	ld a,39
	jr bioscall_a
_cpm_write:
	ld a,42
	jr bioscall_c
_cpm_listst:
	ld a,45
	jr bioscall_a
;
;	CP/M 3 extensions (not something we can use yet due to the SCB)
;
_cpm_conost:
	ld a,48
	jr bioscall_a
_cpm_auxist:
	ld a,51
	jr bioscall_a
_cpm_auxost:
	ld a,54
	jr bioscall_a
_cpm_devtbl:
	ld a,57
	jr bioscall_hl
_cpm_devini:
	ld a,60
	jr bioscall_c
_cpm_drvtbl:
	ld a,63
	jr bioscall_hl
_cpm_multio:
	ld a,66
	jr bioscall_hl
_cpm_flush:
	ld a,69
	jr bioscall_hl
; MOVE is useless to us
_cpm_time:
	ld a,75
	jr bioscall_c
;
; SELMEM and SETBNK won't be present in an unbanked BIOS nor XMOVE
;
;	Seldsk wants a bit argument in E and a drive in C
;
_cpm_seldsk:
	; Our input is drive and control bit in C and E. Result in HL
	pop de
	pop hl
	push hl		; get argument
	push de
	push bc		; save BC
	ld c,l
	ld e,h		; 0000 or FFFF
	ld d,h
	ld a,27		; Call 9
	call bioscall_hl
	pop bc
	ret
;
;	sectran wants
;	BC = sector
;	DE = table
;
;	returns HL = sector number
;
_cpm_sectran:
	push bc
	ld hl,4
	add hl,sp
	ld c,(hl)
	inc hl
	ld b,(hl)
	inc hl
	ld e,(hl)
	inc hl
	ld d,(hl)
	ld a,48
	call bioscall_hl
	pop bc
	ret

;
;	Common space helpers of our own
;
_cpm_diskread:
	ld a,(_cpm_map)
	or a
	push af
	call nz, map_proc_a
	call _cpm_read
	; Return is in L
	pop af
	ret z
	jp map_kernel
_cpm_diskwrite:
	; This needs to preserve H into the cpm_write call
	ld a,(_cpm_map)
	or a
	push af
	call nz, map_proc_a
	call _cpm_write
	; Return is in L
	pop af
	ret z
	jp map_kernel

	.commondata

biosbase:
	.word 0			; updated at boot
_cpm_map:
	.byte 0
