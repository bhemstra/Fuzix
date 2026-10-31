	        ; Ordering of segments for the linker.
	        ; WRS: Note we list all our segments here, even though
	        ; we don't use them all, because their ordering is set
	        ; when they are first seen.
		;
		; _CODE is linked at 0x0100 and only holds start up and
		; compiler helper code, all the C code goes in _CODE2. That
		; keeps the common code and all the data in the fixed lower
		; 32K (page 0) where it is visible whichever user page is
		; mapped. _CODE2 follows on and spills into page 1 at 0x8000.
		; The loader brings the entire image in with page 1 mapped.
		;
	        .area _CODE
	        .area _COMMONMEM
	        .area _COMMONDATA
	        .area _CONST
	        .area _INITIALIZED
	        .area _DATA
	        .area _BSEG
	        .area _BSS
	        .area _HEAP
	        ; note that areas below here may be overwritten by the heap at runtime, so
	        ; put initialisation stuff in here
	        .area _GSINIT
	        .area _GSFINAL
	        .area _CODE2
		; SDCC places its C support routines in _HOME
		.area _HOME
		.area _VIDEO
		; Buffers must be directly before discard as they will
		; expand over it
		.area _BUFFERS
		.area _DISCARD
	        ; Doesn't matter if this goes over the video space as it is
		; removed at the end of the build
	        .area _INITIALIZER

        	; imported symbols
        	.globl _fuzix_main
	        .globl init_early
	        .globl init_hardware
	        .globl s__DATA
	        .globl l__DATA
	        .globl s__DISCARD
	        .globl s__BUFFERS
	        .globl l__BUFFERS
	        .globl kstack_top

		; exports
		.globl _discard_size

		.include "kernel.def"

	        ; startup code
	        .area _CODE

;
;	Once the loader completes it jumps here (0x0100). Page 1 is
;	mapped at 0x8000, the boot ROM is disabled and interrupts are
;	off.
;
start:
		jp start2

		.area _DISCARD
start2:
		di
		ld sp, #kstack_top
		; Kernel mapping, video on, RTC interrupt off for now
		ld a, #M2_VIDEO + M2_KPAGE
		out (0xFF), a
		ld a, #'K'		; first sign of life, top right
		ld (0xF84F), a
		; zero the data area
		ld hl, #s__DATA
		ld de, #s__DATA + 1
		ld bc, #l__DATA - 1
		ld (hl), #0
		ldir
;		Zero buffers area
		ld hl, #s__BUFFERS
		ld de, #s__BUFFERS + 1
		ld bc, #l__BUFFERS - 1
		ld (hl), #0
		ldir
		; The discard area runs up to the video memory, the loader
		; that sat between them is no longer needed
		ld hl, #0xF800
		ld de, #s__DISCARD
		or a
		sbc hl, de
		ld (_discard_size), hl
		call init_early
		call init_hardware
		call _fuzix_main
		di
stop:		halt
		jr stop

_discard_size:
		.dw 0
