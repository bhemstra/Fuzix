
	.export _memset
	.code

;
;	memset has an int sized pattern that is byte written.
;
;
_memset:
	stx	(-s)
	ldx	4(s)
	ldb	6(s)
	lda	8(s)
	jz	nowork

setl:
	stbb	(x+)
	dca
	jnz	setl
nowork:
	ldb	4(s)
	ldx	(s+)
	rsr
