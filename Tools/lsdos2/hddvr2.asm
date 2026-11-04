;****************************************************************
;* Filename: HDDVR2/ASM						*
;****************************************************************
;* TRS-80 Model II WD1010 hard disk driver (drive 0)		*
;****************************************************************
;
;	HL -> Buffer Address
;	D  -> Cylinder desired
;	E  -> Sector desired (within the cylinder)
;	C  -> Drive desired
;	B  -> Disk primitive command
;	IY -> DCT
;
;	The drive has 512 byte sectors, 32 per track and 8 heads. LS-DOS
;	sees 256 byte sectors: each is the first half of a physical sector.
;	An LS-DOS cylinder is 4 heads (128 sectors), so physical cylinder
;	n holds LS-DOS cylinders 2n (heads 0-3) and 2n+1 (heads 4-7).
;
;	Sector numbers on the drive start at HDBASE (0 or 1); the boot
;	loader finds out which and stores it there.
;
HDDVR	JR	HDBGN
	DW	HDEND
	DB	3,'$HD'
HDBASE	DB	0
;
HDBGN	LD	A,B
	SUB	9
	JR	Z,HDRD		;9: read sector
	DEC	A
	JR	Z,HDVER		;10: verify sector
	SUB	3
	JR	Z,HDWR		;13: write sector
	DEC	A
	JR	Z,HDWR		;14: write system sector
	XOR	A		;Everything else: done
	RET
;
;	Read: the first 256 bytes to the buffer, the rest away
;
HDRD	PUSH	BC
	PUSH	HL
	LD	A,20H		;Read sector
	CALL	HDCMD
	JR	NZ,HDRERR
	LD	BC,0C8H		;B=0: 256 bytes
	INIR
HDRD1	IN	A,(0C8H)	;Drop the second half
	DJNZ	HDRD1
	POP	HL
	POP	BC
;
;	Verify: nothing to do but report the directory cylinder
;
HDVER	LD	A,D
	CP	(IY+9)		;Directory cylinder?
	LD	A,6		;"Attempted to read system data"
	JR	Z,HDNZ
	XOR	A
	RET
;
HDRERR	LD	A,4		;Parity error during read
HDERR	POP	HL
	POP	BC
HDNZ	OR	A
	RET
;
;	Write: the buffer, then 256 zero bytes
;
HDWR	BIT	7,(IY+3)	;Software write protect?
	LD	A,15
	RET	NZ
	PUSH	BC
	PUSH	HL
	LD	A,30H		;Write sector
	CALL	HDCMD
	JR	NZ,HDWERR
	LD	BC,0C8H
	OTIR
	XOR	A
HDWR1	OUT	(0C8H),A
	DJNZ	HDWR1
	CALL	HDWAIT
	AND	1		;Error?
	JR	NZ,HDWERR
	POP	HL
	POP	BC
	RET			;A=0, Z
HDWERR	LD	A,12		;Parity error during write
	JR	HDERR
;
;	Set up the task file for D/E, issue command A and wait
;	until the data can be transferred. Z if so.
;
HDCMD	PUSH	AF
	CALL	HDWAIT
	PUSH	HL
	LD	A,E		;Sector within the track
	AND	1FH
	LD	HL,HDBASE
	ADD	A,(HL)
	POP	HL
	OUT	(0CBH),A
	LD	A,D		;Head: bit 0 of the cylinder,
	RRCA			;  then bits 6-5 of the sector
	AND	80H
	OR	E
	RLCA
	RLCA
	RLCA
	AND	7
	OR	20H		;512 byte sectors, drive 0
	OUT	(0CEH),A
	LD	A,D		;Physical cylinder
	SRL	A
	OUT	(0CCH),A
	XOR	A
	OUT	(0CDH),A
	INC	A
	OUT	(0CAH),A	;One sector
	POP	AF
	OUT	(0CFH),A
	CALL	HDWAIT
	AND	09H		;DRQ and no error?
	CP	08H
	RET
;
HDWAIT	IN	A,(0CFH)
	RLCA			;Busy?
	JR	C,HDWAIT
	RRCA
	RET
HDEND	EQU	$-1
;
	END
