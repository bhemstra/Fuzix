
	.export _memcpy

	.code

_memcpy:
	stx	(-s)
	xfr	y,a
	sta	(-s)

	ldx	8(s)		; from
	lda	6(s)		; to
	xay
	lda	10(s)		; count
	bz	nowork
memcpyl:
	ldbb	(x+)
	stbb	(y+)
	dca
	bnz	memcpyl
nowork:
	ldb	6(s)		; memcpy returns the destination
	lda	(s+)
	xay
	ldx	(s+)
	rsr
