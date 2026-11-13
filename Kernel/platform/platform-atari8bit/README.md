# Atari 8bit

An initial port to Atari 8bit machines with 128K or more of RAMBO style
memory (so 130XE etc). This kind of works but because the Atari uses NMI
and IRQ as a pair of interrupts with external masks it doesn't quite fit
our model so there's some work needed to wrangle in a timer interrupt.

Performance is not great at startup as we end up doing a lot of disk
switching of tasks but it's not quite so bad once we are running. As with
the C64 our big problem is the slow disk I/O, but unlike the C64 we've got
no REU style DMA options.

## Compatibility

We build two versions of the kernel
-	Standard kernel requires a 130XE or a machine with 130XE style
	banking and either the proper ANTIC bank control or a board
	where ANTIC only sees main memory
-	Rambo kernel. 130XE or similar style machine where the 130XE style
	banking follows the CPU. Video options are more limited

In all cases you need RAM at 0xC000 and you need PORTB to be able to page
out the system ROM at D800-FFFF

No AXLON style kernel is built as the original 400/800 cannot map out the
ROM at D800-FFFF.

## TODO
-	ink/paper/border/video modes (very limited options)
-	For 130XE style systems we have 8K set up for the screen
	so do we support hardware scrolled 320x192 ?
-	When we do graphic modes restore font from cartridge with RAMBO
	systems. Then we've got a bit more video space.
-	Add support for machines with enough memory to bank processes in
	RAM (neeeds 8 banks + base including kernel)
-	Only call into C irq handler when there is a char on the kbd or
	a timer tick, so we can cut IRQ load a lot (ditto C64)

Runs from a 128K SpartaDOS style cartridge

Memory Map:
0000-00FF	Zero Page (shared between kernel and user)
0100-01FF	Stack Page (shared between kernel and user)
0200-03FF	Space for initial boot
0400-3FFF	Code and data discarded after initial booting
4000-7FFF	Banked (4 overlays and user)
8000-9FFF	User
A000-BFFF	User or Kernel code from cartridge directly
C000-CFFF	Bits of shared space (screen and font also for RAMBO style)
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

Overlay4 is carefully laid out on 130XE style machines

4000		Font
4400		Video space (8K)
5400		Disk buffers (2.5K)
~5800		Code for overlay 4

This gives us enough space for the full video mode range in future and keeps
everything out of the user map. We keep the video in the main bank so we can
handle less functional RAMBO banking. For AXLON style machines the video
and font are moved to C000

## Memory Banking

Currently we only support 130XE style banking.

Supporting AXLON style banking isn't particularly tricky. The 16K pages are
the same with page 0 as the base memory. The paging mechanism however means
we have to be very careful about 0FC0-0FFF and CFC0-CFFF. CFC0-CFFF is easy
to deal with. As we need D800-FFFF as RAM it's not however useful.

## Constraints

### C000-CFFF

Early machines had no RAM here, but they also can't map out the ROM so not
a problem.

### CFC0-CFFF / 0FC0-0FFF

Writes to these blocks do AXLON style bank switching. For the 0Fxx alias this
could be problematic. One option would be to move discard up and keep the
common at 0200-1000 or so and put non writeable common space there. User
would then extend up to CFBF or BFFF depending upon the machine and presence
of the 4K at C000. Again right now it's not clear we can ever support such
a machine.

### Video

Our current setup uses the main bank at 4000 for video but some cards will feed
ANTIC whatever bank the CPU is using. The RAMBO kernel build covers such
cards but you lose nice video modes.

### Problems To Solve

Fix the signal handling bug (same as C64)


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


