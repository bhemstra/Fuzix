# 1 "piosd.S"
# 1 "../../dev/z80usoftsd.S"
;
;	Software SPI. Implements the minimal bits needed to support the
;	SD card interface. Does not implement simultaneous send/rx
;	currently. The hardware can obviously do it but nobody needs it
;	so far.
;
;	Alan Cox 2019 with some further optimizations by herrw@pluspora
;

	.export _sd_spi_tx_byte
	.export _sd_spi_rx_byte
	.export _sd_spi_tx_sector
	.export _sd_spi_rx_sector

	.common

_sd_spi_tx_byte:
	jp	_spi_tx_byte
_sd_spi_rx_byte:
	jp	_spi_rx_byte

sd_map:
	exx
	call	spi0_set_regs
	exx
	ld	b,0
	ld	a,(_td_raw)
	or	a
	ret	z
	dec	a
	jp	z,map_proc_always
	ld	a,(_td_page)
	jp	map_for_swap

_sd_spi_rx_sector:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	call	sd_map
spi_rx_loop:
	exx
	call	spi0_bitbang_rx
	ld	a,d
	exx
	ld	(hl),a
	inc	hl
	exx
	call	spi0_bitbang_rx
	ld	a,d
	exx
	ld	(hl),a
	inc	hl
	djnz	spi_rx_loop
	exx
	out	(c),e
	exx
	pop	bc
	jp	map_kernel

_sd_spi_tx_sector:
	pop	de
	pop	hl
	push	hl
	push	de
	push	bc
	call	sd_map
spi_tx_loop:
	ld	a,(hl)
	inc	hl
	exx
	call	spi0_bitbang_tx
	exx
	ld	a,(hl)
	inc	hl
	exx
	call	spi0_bitbang_tx
	exx
	djnz	spi_tx_loop
	exx
	out	(c),e
	exx
	pop	bc
	jp	map_kernel
