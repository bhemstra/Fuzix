.export entry

; This is a simple bootstrap loader which uses the Amstrad's built-in software to
; load files off disk. It first searches for LOAD????.?? files, where the first
; field is a hex address and the second is a bank ID, and loads them all. Then it
; searches for a CALL????.?? file, pages in the bank, and calls that address.
; The paged in bank is always at 0x4000. Typically you'll want something like:
;
;   LOAD4000.80
;   LOAD4000.81
;   CALL4000.80
;
; If there are multiple CALL????.?? files, it will pick one at random and ignore
; the rest.

; Amstrad kernel entrypoints

kmreadchar .equ 0xb9b3
textout .equ 0xb81e
txtclearwindow .equ 0xb824
txtoutput .equ 0xb833

; Ranger FDD entrypoints. I have no idea whether these are consistent between ROM
; versions, if there are different ROM versions, but I've found at least two
; machines with these values. Unfortunately the Ranger software doesn't expose
; things like read_sector via a system call.

r_finish .equ 0xf34b
r_set_dta .equ 0xf391
r_find_first .equ 0xf396
r_find_next .equ 0xf3bf
_d_gp .equ 0xb7e0
_d_dta .equ 0xb7f1
load_sectors_to_4000 .equ 0xe884
print_hex_i8 .equ 0xcb0e
press_any_key .equ 0xcb50
advance_to_next_cluster .equ 0xd8ca
read_sector .equ 0xdffe
calculate_location_of_cluster .equ 0xda57
update_watchdog_timer .equ 0xcc78

    ; On entry, the memory map is as follows:
    ;
    ; 0x0000-0x3fff: Kernel workspace
    ; 0x4000-0x7ccc: Dedicated 16kB bank for us
    ; 0x8000-0xbfff: Kernel workspace
    ; 0xc000-0xffff: Ranger floppy disk routines
    ;
    ; The only bank we can change while still keeping the Amstrad kernel running
    ; from is the one at 0x4000. So we need to relocate ourself into the transient
    ; data area at 0xa000 to allow this. This is 4kB wide.

entry:
    ld de, 0xa000
    ld hl, 0x4000
    ld bc, 0x1000
    ldir
    jp start
start:
    ld (_d_entry_stack), sp
    call txtclearwindow
    ld hl, _str_hello
    call textout

    ld hl, _str_load_pattern
    ld a, 0xff
    call r_find_first
filename_loop:
    jp c, failed

    ld hl, (_d_dta)
    call textout
    ld a, ' '
    call txtoutput
    call parse_filename
    call load_file

    call r_find_next
    jr filename_loop

failed:
    cp 0x12 ; ran out of files?
    jr z, finished
    ; Otherwise it's a hard error.
really_failed:
    push af
    ld hl, _str_error
    call textout
    pop af
    call print_hex_i8
press_any_key_and_exit:
    call press_any_key
exit:
    ld sp, (_d_entry_stack)
    ret

finished:
    ld a, (_d_found_a_file)
    or a
    jr z, no_bank_files

    ld hl, _str_call_pattern
    ld a, 0xff
    call r_find_first
    jr c, no_boot_file
    call parse_filename

    push af
    ld hl, _str_booting
    call textout
    pop af
    call print_hex_i8

    call r_finish
    ld sp, (_d_entry_stack)
    ld hl, (_d_destination)
    jp (hl)

no_bank_files:
    ld hl, _str_no_bank_files
textout_and_exit:
    call textout
    jr press_any_key_and_exit
no_boot_file:
    ld hl, _str_no_boot_file
    jr textout_and_exit

nl:
    ld hl, _str_nl
    jp textout

; Assumes that the dta contains a dirent for a file and that _d_destination
; is set correctly; reads it all in.
load_file:
    ld a, 1
    ld (_d_found_a_file), a

    ld iy, (_d_dta)
    ld l, (iy+0x1c) ; start cluster in dirent
    ld h, (iy+0x1d)
cluster_loop:
    push hl
    call calculate_location_of_cluster
    ld (ix+0x18), a ; track
    ld (ix+0x1a), l ; sector

    ld hl, (_d_destination)
    call read_sector
    jr c, really_failed
    call update_watchdog_timer

    ld a, (ix+0x1a)		; just inc (ix+0x1a) ??? TODO
    inc a
    ld (ix+0x1a), a

    ld hl, (_d_destination)
    ld de, 0x200
    add hl, de
    ld (_d_destination), hl
    call read_sector
    jp c, really_failed
    call update_watchdog_timer

    ld hl, (_d_destination)
    ld de, 0x200
    add hl, de
    ld (_d_destination), hl
    
    ld a, '.'
    call txtoutput

    pop hl
    call advance_to_next_cluster
    jr nc, cluster_loop
    jp nl

; Assumes that the dta contains the dirent for the current file.
parse_filename:
    ld iy, (_d_dta)

    ld d, (iy+6)
    ld e, (iy+7)
    call parse_hex
    ld (_d_destination+0), a

    ld d, (iy+4)
    ld e, (iy+5)
    call parse_hex
    ld (_d_destination+1), a

    ld d, (iy+9)
    ld e, (iy+10)
    call parse_hex
    ld (0xb001), a ; tell the OS that we're changing banks
    out (0x11), a  ; actually change banks
    ret

; Takes a hex number in D, E and reads it into A.
parse_hex:
    ld a,d
    call parse_hex_digit
    add a,a
    add a,a
    add a,a
    add a,a
    ld d,a
    ld a,e
    call parse_hex_digit
    or d
    ret

parse_hex_digit:
    sub '0'
    cp 10
    ret c
    sub 'A'-'0'-10
    ret

_d_entry_stack: .word 0
_d_found_a_file:.byte 0
_d_destination: .word 0

_str_hello:	    .ascii "Loading..." ; falls through
_str_nl:            .byte 13,10,0
_str_no_bank_files: .ascii "No files to load!"
		    .byte 0
_str_no_boot_file:  .ascii "No boot configuration!"
		    .byte 0
_str_load_pattern:  .ascii "LOAD????.??"
		    .byte 0
_str_call_pattern:  .ascii "CALL????.??"
		    .byte 0
_str_error:         .byte 13,10
		    .ascii "Error: "
		    .byte 0
_str_booting:       .ascii "Starting bank "
		    .byte 0
