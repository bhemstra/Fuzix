#include "kernelu.def"

;
;	We need slightly custom transfer routines for the IDE controller
;	as we have no common stack to use.
;
	.common

	.export _devide_read_data
	.export _devide_write_data

#define IDE_REG_DATA	0x10


_devide_read_data:
            pop de
            pop hl
            push hl
            push de
            push bc
            ld a, (_td_raw)
            ld bc, IDE_REG_DATA                    ; setup port number
                                                    ; and count
	    cp 2
            jr nz, not_swapin
            ld a, (_td_page)
not_swapin:
            ; At this point A = 0 kernel, A = 1, user
            rrca
            or 1				    ; 0x81 or 0x01
            out (0x38),a
            rlca
            out (0x30),a
            inir                                    ; transfer first 256 bytes
            inir                                    ; transfer second 256 bytes
            ld a,0x01
            out (0x38),a
            rlca
            out (0x30),a
            pop bc
            ret

_devide_write_data:
            pop de
            pop hl
            push hl
            push de
            push bc
            ld a, (_td_raw)
            ld bc, IDE_REG_DATA                    ; setup port number
                                                    ; and count
	    cp 2
            jr nz, not_swapout
            ld a, (_td_page)
not_swapout:
            ; At this point A = 0 kernel, A = 1, kernel
            rrca
            or 1			; 0x81 or 0x01
            out (0x38),a
            rlca
            out (0x30),a
            otir                                    ; transfer first 256 bytes
            otir                                    ; transfer second 256 bytes
            ld a,0x01
            out (0x38),a
            rlca
            out (0x30),a
            pop bc
            ret

