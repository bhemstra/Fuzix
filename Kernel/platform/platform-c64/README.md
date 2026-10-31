# Commodore 64 + IDE64

This is just any early development test of a simple C64 + IDE64 setup with the
OS in the IDE64 cartridge memory. A more serious setup would be to build
a C64 + IDE64 + REU configuration as we can use the REU fast memory swap
for process switching and we can also use the REU as a fast memory zero,
copy and even in theory disk to REU direct transfer. That would allow us to
keep the buffers in REU space and also read/write the disk really fast in
CF mode.

## To Look At

- Switch to a proper keyboard scan routine maybe
- Colour attributes + ink/paper/border
- Graphics mode setting (but really need more memory for a full 2K video)
- Performance is horrible

Our performance is mainly bounded by the speed of the disk sector transfers
on the 1MHz 6502, especially the way they are arranged for writes on the
IDE64. Unfortunately VICE appears to have broken CF emulation and 8bit mode
doesn't seem to work right.

## Memory Map

0000-00FF	Zero Page
0100-01FF	Stack
0200-03FF	C64 Kernal owns
0400-07FF	Screen
0800-0BFF	Font (would be nice to get a full 2K font in but no room)
0C00-3FFF	Kernel data/buffers etc
4000-7FFF	Always user (discard during boot)
8000-AFFF	Cartridge (banked 4 ways - kernel), RAM user
B000-BFFF	Cartridge (same code in each 4K bank)
C000-FEFF	User, D000-DFFF becoems I/O when cartridge is paged in
E000-FFFF	Becomes kernal when cartridge paged in so icky mess
		with vectors
FF00-FFFF	REU trigger, vectors

### Kernal

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
