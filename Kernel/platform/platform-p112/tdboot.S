;
;	P112 CF/IDE sector-0 bootstrap loader for FUZIX (modern 0x2176 path).
;
;	The P112 boot ROM (v5.8) G-IDE boot (gide.S:BtGIDE) reads sector 0 of
;	the boot device to 0x8000 and checks that the first word == 0x2176
;	(little-endian bytes 76 21). On match it IGNORES any load address in
;	the header and hardcodes `ld hl,8100h` / `ld b,32`, loading 32 sectors
;	(16 KB) to 0x8100, then transfers through BootV0 -> MovRout:
;	  DE=(8002h); BC=0x10000-DE; HL=0x80FF+BC; LDDR (dest 0xFFFF); jp (8006h)
;	With (8002h)=0x8100 the LDDR is a verified byte-onto-itself no-op
;	(BC=0x7F00, src=dst=0xFFFF descending in lockstep), so the 16 KB block
;	the ROM loaded at 0x8100 is left in place, and MovRout jumps to
;	(8006h)=0x8108 -> our loader entry.
;
;	This loader therefore carries the 0x2176 header in its first 8 bytes:
;	  76 21 00 81 C9 C3 08 81
;	  word@0x00 = 0x2176   BtGIDE magic
;	  word@0x02 = 0x8100   MovRout relocation target (makes LDDR a no-op)
;	  byte@0x04 = 0xC9     RET (convention, inert on modern path)
;	  byte@0x05 = 0xC3 + word@0x06 = 0x8108  JP 0x8108 (MovRout jump target)
;
;	RELOCATION STRUCTURE (the FIX):
;	  The loader is split into a STUB assembled at .org 0x8100 and a BODY
;	  assembled at a second .org 0xFC00. The ROM delivers the whole image
;	  at 0x8100; the stub's entry (at 0x8108) LDIRs the BODY up to its run
;	  address 0xFC00 (the CBAR-toggle-invariant common window) and then
;	  jumps into the 0xFC00 copy. Because the body is org'd at 0xFC00, ALL
;	  its internal jp/jr/call targets and ld hl,#string pointers resolve to
;	  0xFC00-range natively -- so execution after the LDIR runs entirely in
;	  the relocated copy, never in the original 0x81xx image that the kernel
;	  load (flat 0x0000..~0xB5A8) is about to overwrite.
;
;	  On disk the body bytes are NOT at file offset 0xFC00: the Makefile
;	  concatenates two slices -- the stub [start,stub_end) and the body
;	  [body_start,body_end) -- so the body lands contiguously right after
;	  the stub, which is exactly the load address (body_load == stub_end)
;	  the stub's LDIR source points at.
;
;	The body reads the packed FUZIX kernel off the same G-IDE card over
;	LBA28 polled PIO (CS1 task-file 0x58..0x5F), starting at LBA 32,
;	deposits it at physical 0x0000, and jumps to the kernel entry at 0x0088.
;
;	The IDE read handshake matches gide.S exactly: BSY-clear poll of 0x5F
;	after the command, then DRQ-set poll of 0x5F, two 256-byte INIR bursts
;	from the data register 0x58, a final BSY-clear poll, and a
;	(status & 0x89)==0 success test (no BSY, DRQ, or ERR).
;
;	PROGRESS OUTPUT uses the P112 ROM console services exactly as the
;	historical flopboot.s did: rst 0x20 prints a NUL-terminated string
;	(pointer in HL), rst 0x18 prints a char (in A). These work ONLY while
;	the ROM is mapped low (CBAR=0xF8 + SYSCONFIG bit3). Every rst in this
;	loader executes with CBAR=0xF8; the "Booting" print is the LAST rst and
;	sits immediately before the terminal CBAR=0xF0 ROM-shadow-off switch.
;
;	The 0x2176 modern path does NOT checksum sector 0 and does NOT require
;	a 55AA signature; neither a checksum pad nor an SP-word slot is present.
;	The MBR partition table + 55AA at sector offset 0x1BE..0x1FF is written
;	by the diskimage recipe purely as tinydisk filesystem metadata.
;
;	Build-filled bytes:
;	  ksectors : number of kernel sectors to read (Makefile fills it)
;

	.z180
	.abs
	.org 0x8100

	; Boundary labels exported so the Makefile can (a) emit the two-slice
	; concatenation (stub [start,stub_end) + body [body_start,body_end)),
	; (b) run the slot/overlap/run-fit map gates, and (c) find the
	; in-image offset of the build-filled ksectors byte.
	.export start
	.export stub_end
	.export body_start
	.export body_end
	.export ksectors

; ----------------------------------------------------------------------------
; Equates
; ----------------------------------------------------------------------------
romload		.equ	0x8100		; ROM loads the 32-sector OS block here
runbase		.equ	0xFC00		; loader body self-relocates to CA1 here
kernel_load	.equ	0x0000		; kernel is deposited flat from 0x0000
fuzix_entry	.equ	0x0088		; kernel code base (-C 0x0088)
himem_sp	.equ	0xFE00		; loader stack (P112 ROM uses FE00 up)
bfr		.equ	0xFA00		; per-sector read buffer (CA1, stable)
kernel_lba	.equ	32		; kernel starts at LBA 32 (loader slot
					; = LBA 0..31, 32 sectors to 0x8100)

; G-IDE task-file registers (CS1 base 0x58, = plt_ide.h)
IDE_DATA	.equ	0x58
IDE_ERR		.equ	0x59
IDE_COUNT	.equ	0x5A
IDE_SEC		.equ	0x5B
IDE_CYLL	.equ	0x5C
IDE_CYLH	.equ	0x5D
IDE_DEVH	.equ	0x5E
IDE_CMD		.equ	0x5F
IDE_STATUS	.equ	0x5F
ATA_READ	.equ	0x20

; Z180 MMU / Z182 system-config ports (= cpu-z180/z180.def)
MMU_CBR		.equ	0x38
MMU_BBR		.equ	0x39
MMU_CBAR	.equ	0x3A
Z182_SYSCONFIG	.equ	0xEF

; ----------------------------------------------------------------------------
; STUB (.org 0x8100). Sector-0 0x2176 boot header (first 8 image bytes) plus
; the relocation entry. The stub stays at 0x8100; it copies the BODY up to
; 0xFC00 and jumps into the relocated copy.
; ----------------------------------------------------------------------------
start:
	.word	0x2176			; byte@0x00: BtGIDE magic (76 21)
	.word	romload			; byte@0x02: MovRout reloc target 0x8100
	.byte	0xC9			; byte@0x04: RET (convention, inert)
	.byte	0xC3			; byte@0x05: JP opcode ...
	.word	entry			; byte@0x06: ... 0x8108 (MovRout jumps here)

; entry: the ROM (via MovRout) jumps here at 0x8108, with the 16 KB block
; still resident at 0x8100. Copy the BODY span up to CA1 at 0xFC00 and jump
; into the relocated copy. The LDIR uses only link-time constants:
;   source = body_load (= stub_end, the body's load address in the image)
;   dest   = runbase (0xFC00)
;   length = body_end - body_start (true body byte count, org-independent)
; After the LDIR the stub makes no reference to any body label by its load
; address; `jp run` targets a 0xFC00-range label (the live copy).
entry:
	di
	ld	sp, #himem_sp		; safe stack high in RAM
	ld	hl, #body_load		; SOURCE = body load addr (= stub_end)
	ld	de, #runbase		; DEST   = 0xFC00 (constant)
	ld	bc, #body_end-body_start ; LEN  = true body byte count
	ldir
	jp	run			; -> 0xFC00-range entry (live copy)

stub_end:
body_load:				; body load address == end of stub

; ----------------------------------------------------------------------------
; BODY (.org 0xFC00). Everything here runs from the relocated 0xFC00 copy, so
; every jp/jr/call target and every ld hl,#string resolves to 0xFC00-range.
; ----------------------------------------------------------------------------
	.org	runbase			; 0xFC00 -- body LABELS resolve here
body_start:

; run: executes from the 0xFC00 copy. CA1 (high nibble F) is stable across the
; CBAR 0xF8<->0xF0 toggle used per sector, so loader code/buffer/stack at
; 0xFC00/0xFA00/0xFE00 stay mapped while low RAM is swapped in to receive the
; kernel. MMU dance mirrors flopboot-reference.s.
run:
	ld	a, #0xF8		; ROM in low 32K, loader + buffer mapped high
	out0	(MMU_CBAR), a
	in0	a, (MMU_CBR)
	out0	(MMU_BBR), a
	in0	a, (Z182_SYSCONFIG)
	set	3, a			; keep BIOS ROM selectable during the load
	out0	(Z182_SYSCONFIG), a

	ld	hl, #msg_signon		; ROM live (CBAR=0xF8): sign-on
	rst	#0x20

	; Read ksectors sectors starting at LBA 32 into kernel_load (0x0000).
	ld	de, #kernel_load	; DE = kernel load pointer
	ld	hl, #kernel_lba		; HL = LBA (kernel starts at sector 32)
	ld	a, (ksectors)
	ld	b, a			; B = sector count for djnz

rdloop:
	push	bc
	push	hl
	push	de
	call	ide_read_sector		; read LBA (HL) -> bfr (0xFA00), CBAR=0xF8
	pop	de
	ld	a, #0x2E		; '.' per-sector dot while ROM live (CBAR=0xF8)
	rst	#0x18
	ld	hl, #bfr
	ld	bc, #512
	ld	a, #0xF0		; RAM into low 32K (expose kernel_load)
	out0	(MMU_CBAR), a
	ldir				; copy sector buffer -> (DE) in low RAM
	ld	a, #0xF8		; ROM back into low 32K
	out0	(MMU_CBAR), a
	pop	hl
	pop	bc
	inc	hl			; next LBA
	djnz	rdloop

	; Load complete, ROM STILL live (CBAR=0xF8). This "Booting" print is
	; the LAST rst; it precedes the terminal CBAR=0xF0 ROM-shadow-off.
	ld	hl, #msg_boot
	rst	#0x20

	; Terminal MMU state: byte-for-byte p112.S init_early (set 3 = ROM
	; shadow OFF / full RAM low), then CBAR=0xF0, then enter the kernel.
	; NO rst may execute after this point -- the ROM is gone.
	in0	a, (Z182_SYSCONFIG)
	set	3, a
	out0	(Z182_SYSCONFIG), a
	ld	a, #0xF0
	out0	(MMU_CBAR), a
	jp	fuzix_entry		; jp 0x0088 (no rst after this)

; ----------------------------------------------------------------------------
; ide_read_sector: read one 512-byte sector (LBA in HL, LBA28 with high bits 0)
; into bfr via 16-bit PIO (INIR/INIR over the data port 0x58). The handshake
; matches gide.S (GoGIDE/HRead/Wt_Rdy): plain IN/OUT task-file access, BSY-clear
; pre-command poll, then BSY-clear + DRQ-set after the command, then the
; (status & 0x89)==0 success test. Clobbers A, BC, HL (caller saved HL).
; Called only inside rdloop while CBAR=0xF8 (ROM mapped).
; ----------------------------------------------------------------------------
ide_read_sector:
	call	ide_wait_bsy		; pre-command: BSY clear (gide.S GoGID1)
	ld	a, #0xE0		; LBA mode, master, LBA bits 27..24 = 0
	out	(IDE_DEVH), a
	xor	a
	out	(IDE_CYLH), a		; LBA bits 23..16 = 0
	ld	a, h
	out	(IDE_CYLL), a		; LBA bits 15..8
	ld	a, l
	out	(IDE_SEC), a		; LBA bits 7..0
	ld	a, #1
	out	(IDE_COUNT), a		; one sector
	ld	a, #ATA_READ
	out	(IDE_CMD), a		; start the read (Cmd_Wt)
	call	ide_wait_bsy		; Wt_Rdy: BSY clear
	call	ide_wait_drq		; HRead0: DRQ set
	ld	bc, #IDE_DATA		; B=0, C=0x58 -> inir does 256 bytes
	ld	hl, #bfr
	inir				; first 256 bytes
	inir				; second 256 bytes
	call	ide_wait_bsy		; HdFini: BSY clear
	in	a, (IDE_STATUS)		; HdFnQ: success test
	and	#0x89			; BSY(0x80)|DRQ(0x08)|ERR(0x01)
	jr	nz, ide_error		; any set -> read failed
	ret

; ide_error: a sector read reported BSY/DRQ/ERR after completion. There is no
; recovery path in the loader; print the error (ROM is live here, CBAR=0xF8,
; reached only from inside rdloop) and spin so the failure is visible rather
; than depositing a corrupt kernel.
ide_error:
	ld	hl, #msg_err
	rst	#0x20
ide_error_spin:
	jr	ide_error_spin

; ide_wait_bsy: spin until BSY (bit7) clear (gide.S Wt_Rdy: IN/RLA/JR C). Does
; NOT test RDY (bit6) -- the ROM never gates on RDY.
ide_wait_bsy:
	in	a, (IDE_STATUS)
	rla				; BSY (bit7) -> carry
	jr	c, ide_wait_bsy
	ret

; ide_wait_drq: spin until DRQ (bit3) set (gide.S HRead0: IN/BIT 3/JR Z).
ide_wait_drq:
	in	a, (IDE_STATUS)
	bit	3, a			; DRQ
	jr	z, ide_wait_drq
	ret

; ----------------------------------------------------------------------------
; Console strings. These live in the body (0xFC00 range), so every ld hl,#msg_*
; resolves to the relocated copy that is actually mapped and executing.
; ----------------------------------------------------------------------------
msg_signon:
	.ascii	"FUZIX loader"
	.byte	13, 10, 0
msg_boot:
	.ascii	"Booting"
	.byte	13, 10, 0
msg_err:
	.ascii	"IDE error"
	.byte	13, 10, 0

; ----------------------------------------------------------------------------
; Build-filled bytes (Makefile writes these into the sector image).
; ----------------------------------------------------------------------------
ksectors:
	.byte	0			; kernel sector count (filled by diskimage)
body_end:				; end-of-body marker for the map checks
