;
; MPI handling
;

	; exported (code)
	.export _mpi_present
	.export _mpi_set_slot

	.code

; Returns old slot.
; uint8_t mpi_set_slot(uint8_t slot);
_mpi_set_slot:
	lda 0xFF7F
	stb 0xFF7F
	tfr a,b
	rts

; uint8_t mpi_present(void);
_mpi_present:
	lda 0xFF7F	; Save bits
	tfr a,b
	lsrb
	lsrb
	lsrb
	lsrb
	eorb 0xFF7F
	andb #0x03	; We expect to see the bits 5-4 and 1-0 matching
	bne nompi	; not guaranteed but a good rule of thumb for us
	ldb #0xFF	; Will get back 33 from an MPI cartridge
	stb 0xFF7F	; if the emulator is right on this
	ldb 0xFF7F
	andb #0x33
	cmpb #0x33
	bne nompi
	clr 0xFF7F	; Switch to slot 0
	ldb 0xFF7F
	andb #0x33	; We can't trust the high bits
	bne nompi
	incb
	sta 0xFF7F	; Our becker port for debug will be on the default
			; slot so put it back for now
	rts	; B = 0
nompi:	ldb #0
	sta 0xFF7F	; Restore bits just in case
	rts
