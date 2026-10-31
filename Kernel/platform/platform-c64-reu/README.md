# Commodore 64 + IDE64 + REU

C64 with an REU. We keep the processes in REU space except the running
one. We also use the REU for some copies and clears as well as screen
scrolling.

## TODO

### Check versus other ports to see if this is a compiler/general issue
- Signal handling bugs possibly related to memory base (shutdown fail,
  crash ^C on zork)
- Zork isn't happy (vocab broken) - need to cross check with rcbus-6502
  looks like a general compiler bug

### To Add
- Check VICE CF emulation (seems broken)
- Debug and test IDE64 with CF mode and REU to existing buffers
- Switch to keeping all but tmpbuf buffers in the REU all the time
- Use freed space to allow for full console and 2K character table
- Set UDG and font symbols
DONE - Ink/paper/border
- How to expose colour map for apps ?
- Use REU space to allow for a second console and console switching
- Better cursor - sprite maybe ?
- Add back swap once REU disk I/O is working

## Performance
- Need to sort REU to get disk speed up
- Possibly we need a 6502 native asm implementation of the console I/O driver


## Memory Map

0000-00FF	Zero Page
0100-01FF	Stack
0200-03FF	C64 Kernal owns
0400-07FF	Screen
0800-0BFF	Font (would be nice to get a full 2K font in but no room
		until we move the buffers into the REU)
0C00-3FFF	Kernel data/buffers etc
4000-7FFF	Always user (discard during boot)
8000-AFFF	Cartridge (banked 5 ways - kernel), RAM user
B000-BFFF	Cartridge (same code in each 4K bank)
C000-FEFF	User, D000-DFFF becoems I/O when cartridge is paged in
E000-FFFF	Becomes kernal when cartridge paged in so icky mess
		with vectors
FF00-FFFF	REU trigger, vectors

## REU Memory Map
000000		A zero byte used for fills
000004-		Scratch buffer (used for copies, scrolling etc)
XX3C00-XXFDFF	Saved copy of a user process including ZP/S and uarea

We don't currently pack the process buffers for simplicity


## Kernal

We get the system ROM shoved in our face whether we like it or not. It's
not a problem for user (all RAM mode it goes away) but does mean we take
interrupts in kernel mode via the kernal layer so might have to be polite 8(

Kernal requires most of 0200-03FF which isn't too bad and hogs E000-FFFF
in cartridge mapped mode which is actually fine (except for the high vectors
it's all user anyway)

We try and be polite and co-exist with KERNAL. Our keyboard handling has
to duplicate some KERNAL code because it assumes it won't be called from
an interrupt.

I've not tried playing with the various IEC helpers and stuff but with
error reporting off they ought to be usable with luck so some tools to move
files to and from the Commodore floppies etc might be doable.

## VICE

-cartide  -IDE64Image1 foo.cfa

Need a 4.x cartridge to get 128K ROM

4.1	Write to 0x60-7 with bank 0-7
4.2+	Write to 0x68+ with bank 0-31
4.x	Write to 0xFF with IO and GAME bits

Raw 128K  8 x 16K or 512K image

(the VICE cartridge conversion tool seems broken for IDE64, raw images work
but crt ones do not)
