;****************************************************************
;* Filename: HDBOOT2/ASM					*
;****************************************************************
;* TRS-80 Model II hard disk loader for LS-DOS			*
;****************************************************************
;
;	The hard disk boot ROM reads 512 byte sectors from cylinder 0
;	head 0 into memory from 0000H until one starts with the text
;	below, then jumps past it (HL holds that address too). Drives
;	number their sectors from 0 (trs80gp) or 1, so the ROM starts
;	at our sector 1 or 0 and this sector ends up at 0E00H or 1000H.
;
;	Sectors of cylinder 0 head 0, counted from 0:
;	0-7	filler (sector 1 byte 2 holds the directory cylinder,
;		where LS-DOS looks for it when it gets lost)
;	8	this loader
;	9-26	memory 0000H-23FFH: BOOT/SYS (lowcore) with SYS0 on top
;	27-30	video memory F800H-FFFFH (the LS-DOS logo)
;
;	The loader moves to 7E00H, turns the ROM off, loads the lot,
;	tells the hard disk driver how the sectors are numbered and
;	starts SYS0.
;
*GET	LOWCORE.EQU
;
	ORG	7E00H
BSIG	DB	'/* END BOOT */'
	DI
	LD	A,81H		;Page 1 at 8000H, video on
	OUT	(0FFH),A
	LD	DE,-14		;Back to the start of the sector
	ADD	HL,DE
	LD	DE,BSIG
	LD	BC,512
	LDIR
	JP	BGO
;
BGO	LD	SP,BSIG
	LD	HL,45EDH	;RETN at the NMI vector, in case
	LD	(0066H),HL	;  a clock tick comes
	IN	A,(0FEH)	;Clear a pending tick
	XOR	A
	OUT	(0F9H),A	;Boot ROM off
	LD	(0066H),HL	;  and in the RAM that now shows
	LD	A,0CH		;Controller enable, wait states
	OUT	(0C1H),A
;
;	Are the sectors numbered from 0 or 1? Try sector 0.
;
	LD	A,20H		;512 byte sectors, drive 0, head 0
	OUT	(0CEH),A
	XOR	A
	OUT	(0CCH),A
	OUT	(0CDH),A
	OUT	(0CBH),A
	INC	A
	OUT	(0CAH),A
	CALL	BWAIT
	LD	A,20H		;Read sector
	OUT	(0CFH),A
	CALL	BWAIT
	AND	1		;Error: no sector 0, numbered from 1
	LD	(BBASE),A
	JR	NZ,BPROBED
	LD	HL,BBUF	;Drain the data
	CALL	BRDDAT
BPROBED
	LD	HL,0000H
	LD	D,9		;First sector
	LD	B,18		;0000H-23FFH
	CALL	BLOAD
	LD	HL,0F800H
	LD	B,4		;F800H-FFFFH
	CALL	BLOAD
	LD	A,(BBASE)
	LD	(HDBASE),A	;Tell the driver
	LD	SP,380H		;STACK$
	JP	1E00H		;SYS0 (SYSINIT)
;
;	Load B sectors from sector D on, to HL
;
BLOAD	LD	A,(BBASE)
	ADD	A,D
	OUT	(0CBH),A
	LD	A,20H
	OUT	(0CEH),A
	XOR	A
	OUT	(0CCH),A
	OUT	(0CDH),A
	INC	A
	OUT	(0CAH),A
	LD	C,10		;Retries
BRETRY	CALL	BWAIT
	LD	A,20H		;Read sector
	OUT	(0CFH),A
	CALL	BWAIT
	AND	09H		;DRQ, no error?
	CP	08H
	JR	NZ,BFAIL
	PUSH	HL
	CALL	BRDDAT
	CALL	BWAIT
	AND	1
	JR	Z,BSECOK
	POP	HL		;Again into the same place
BFAIL	DEC	C
	JR	NZ,BRETRY
	LD	HL,BERRM
	LD	DE,0FBE0H
	LD	BC,BERRE-BERRM
	LDIR
	JR	$
BSECOK	POP	AF		;Drop the old HL
	INC	D
	DJNZ	BLOAD
	RET
;
BRDDAT	PUSH	BC
	LD	BC,0C8H		;512 bytes
	INIR
	INIR
	POP	BC
	RET
;
BWAIT	IN	A,(0CFH)
	RLCA
	JR	C,BWAIT
	RRCA
	RET
;
BERRM	DB	'LS-DOS boot error'
BERRE
BBASE	DB	0
	IFGT	$,BSIG+512
	ERR	'Loader too big'
	ENDIF
BBUF	EQU	BSIG+512
	END
