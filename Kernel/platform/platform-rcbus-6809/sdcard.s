# 0 "sdcard.S"
# 0 "<built-in>"
# 0 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3
# 0 "<command-line>" 2
# 1 "sdcard.S"
 .export _sd_spi_raise_cs
 .export _sd_spi_lower_cs
 .export _sd_spi_rx_byte
 .export _sd_spi_tx_byte
 .export _sd_spi_rx_sector
 .export _sd_spi_tx_sector
 .export _sd_spi_fast
 .export _sd_spi_slow

PRA equ 0xFE68

;
; We can rx fastest on bit 7 or 0, but we want
; bit 0 to be the clock so we can inc/dec the clock
;
DATAIN equ 0x80
CS0 equ 0x04
DATA equ 0x02
CLOCK equ 0x01
;
; This assumes that port A was properly configured
; with the right bits set for R/W
;
; TODO: routine variants to avoid the extra dp setup and call
; overhhead etc on block read/writes
;

 .data
spibits:
 .byte 0

 .code

_sd_spi_raise_cs:
 lda spibits
 ora #CS0
 sta spibits
 sta PRA
 rts
_sd_spi_lower_cs:
 lda spibits
 anda #~CS0
 sta spibits
 sta PRA
; We don't do anything fast enough
; to need a speed setting
_sd_spi_fast:
_sd_spi_slow:
 rts
_sd_spi_tx_sector:
 pshs dp
 jsr iomap
 ldy #512
writebyte:
 ldb ,x+
 bsr _sd_spi_tx_byte
 leay -1,y
 bne writebyte
 jsr map_kernel
 puls dp,pc
_sd_spi_rx_sector:
 pshs dp
 jsr iomap
 ldy #512
readbyte:
 bsr _sd_spi_rx_byte
 stb ,x+
 leay -1,y
 bne readbyte
 jsr map_kernel
 puls dp,pc

;
; We pay a small cost here to use bit 0 for the clock
; but it speeds up rx
;
_sd_spi_tx_byte:
 pshs dp
 lda #$FE
 tfr a,dp
 lda #8
 pshs a
 lda spibits
writebit:
 rora ; Shift the configured bits right
 rora
 rolb ; Get the next bit to send into C
 rola ; Insert data bit into A
 lsla ; Clock clear (low bit now 0)
 sta @PRA ; Clock low
 inca
 sta @PRA ; Clock high
 dec ,s
 bne writebit
 puls a,dp,pc

_sd_spi_rx_byte:
 pshs dp
 lda #$FE
 tfr a,dp
 lda spibits
 ora #DATA

 ; Bang out FF as fast as we can and collect the
 ; bits back
 sta @PRA ; Low
 inc @PRA ; High
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 dec @PRA
 inc @PRA
 lda @PRA ; Sample
 rola
 rolb
 clra
 dec @PRA
 puls dp,pc

 .data
endp: .word 0
