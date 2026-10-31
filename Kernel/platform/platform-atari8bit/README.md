# Atari 8bit

An initial port to Atari 8bit machines with 128K or more of RAMBO style
memory (so 130XE etc). This kind of works but because the Atari uses NMI
and IRQ as a pair of interrupts with external masks it doesn't quite fit
our model so there's some work needed to wrangle in a timer interrupt.

Performance is not great at startup as we end up doing a lot of disk
switching of tasks but it's not quite so bad once we are running. As with
the C64 our big problem is the slow disk I/O, but unlike the C64 we've got
no REU style DMA options.

## TODO
-	ink/paper/border/video modes
-	NMI/IRQ handling for timer tick
-	AXLON style support
-	Fix bug in cursor undraw/redraw or scroll somewhere

Runs from a 128K SpartaDOS style cartridge

Memory Map:
0000-00FF	Zero Page (shared between kernel and user)
0100-01FF	Stack Page (shared between kernel and user)
0200-03FF	Space for initial boot
0400-3FFF	Code and data discarded after initial booting
4000-7FFF	Banked (4 overlays and user)
8000-9FFF	User
A000-BFFF	User or Kernel code from cartridge directly
C000-CFFF	Bits of shared space
D000-D7FF	I/O
D800-FFFF	Kernel data/bss/writable common

When in user space our map ends up
0000-00FF	Zero Page (shared between kernel and user)
0100-01FF	Stack Page (shared between kernel and user)
0200-03FF	User
0400-3FFF	User
4000-7FFF	User
8000-9FFF	User
A000-BFFF	User 
C000-CFFF	Bits of shared space
D000-D7FF	I/O
D800-FFFF	Kernel data/bss/writable common

We hide a lot in an overlay segment overlay4. However we use extended
memory for the user process and main memory for overlay4 as we keep the
video in this 16K block

Overlay4 is carefully laid out as

4000		Font
4400		Video space (8K)
5400		Disk buffers (2.5K)
~5800		Code for overlay 4

This gives us enough space for the full video mode range in future and keeps
everything out of the user map. We keep the video in the main bank so we can
handle less functional RAMBO banking in future, and also AXLON style banks.

## Memory Banking

Currently we only support RAMBO style banking. We don't use the ability to
put ANTIC fetches into the extra banks so this should work with many of the
extended variants people produced).

Supporting AXLON style banking isn't particularly tricky. The 16K pages are
the same with page 0 as the base memory. The paging mechanism however means
we have to be very careful about 0FC0-0FFF and CFC0-CFFF. CFC0-CFFF is easy
to deal with. AXLON banking is demented as the bank codes differ between
boards so there's no trivial mapping to know what values work. AXLON style
banking however would mess up the video as the video tracks the CPU
banking generally. We'd be limited to say a 40x25 text screen.

There is also the better but somewhat obscure Byte design that switches the
low 32K based on PORTB 4-6 (bank 6 being the upper 32K)

RAMBO style banking above the 4 banks gets messy and it's not clear we can
make good use of extra anyway. AXLON banking goes up to 1MB and sometimes
4MB which would be sufficient to use as your swap device not the disk. If
so it would also save 16K of copy in/out for the 4000-7FFF range

## Constraints

### C000-CFFF

This is not present on old machines. Do we care, could we pack stuff to
handle this better

### CFC0-CFFF / 0FC0-0FFF

Writes to these blocks do AXLON style bank switching. For the 0Fxx alias this
could be problematic. One option would be to move discard up and keep the
common at 0200-1000 or so and put non writeable common space there. User
would then extend up to CFBF or BFFF depending upon the machine and presence
of the 4K at C000.

### Video

Our current setup uses the main bank at 4000 for video but some AXLON style
cards will feed ANTIC whatever bank the CPU is using. Not clear we can do
much with such cards.

### Problems To Solve



D20F (W)
bit 7: brk (output)
bit 6/5/4: serial mode
bit 3: serial two tone (FSK - used for cassette)
bit 2: fast pot scan
bit 1: enable kbd scanning
bit 0: enable kbd debounce

D20F(R)
bit 7: serial frame
bit 6: serial overrun
bit 5: KB overrun
bit 4: data ready serial
bit 3: shift key
bit 2: last key still pressed
bit 1: serial input busy


Write D20A to reset error bits 5-7 in SKSTAT

Serial D20D data out (8N1), D20D read data in ditto

D209 (R): keyboard code
	00-3F code
	upper 2 bits special key decode
	unshifted
	shifted
	control
	shift-ctrl (not all keys)

Codes:

https://www.atariarchives.org/c3ba/page004.php

Lock key processing is software

D20E IRQ status

7: break pressed
6: key pressed
5: serial input ready
4: serial output needed
3: serial output done
2: timer4
1; timer2
0: timer1

D01F: bit 0: start 1: select 2 : option (console buttons)

D20E (W) IRQen

Set bit to enable (as IRQ status)


