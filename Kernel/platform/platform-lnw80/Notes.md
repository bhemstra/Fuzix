# Notes for the LNW-80/80-II CP/M setup

## The Hardware

Port 0x1F

| Bit   | Val | Meaning          |
|:------|:----|:-----------------|
| Bit 7 | Set | Write protect low 12K (ROM emulation) |
| Bit 6 | Set | Use the extra 32K bank high |
| Bit 5 | Set | Disable the additional 32K |
| Bit 4 | Set | Replace MMIO with RAM |
| Bit 3 | Set | Reserved |
| Bit 2 | Set | Disable Interrupts |
| Bit 1 | Set | 0-16K are RAM except for the MMIO areas |
| Bit 0 | Set | Swap bottom and top 16K for CP/M use |

## Bugs

## To Add

80 column support - maybe. Memory is very tight so this would probably need
to use the additional 32K bank somehow. Might be a better model anyway.

Maybe the Apple style joystick

## Memory Map

0000-5FFF	Small parts of the kernel, video driver and data, common, constants initialized data and buffers
6000-7FFF	Always user space (used for discardable code at boot)
8000-FFFF	Banked kernel or user

We don't load 3800-3FFF or 4000-41FF. The latter is easy to fix the former
is quite tricky, so we need to load BSS space there if we use it.

## Notes

Floppy boot requires a single density disk. The Level II ROM reads
disk 0 side 0 track 0 sector 0 (TRS80 disks are 0 offset sector count)
into 4200-42FF and then does a JP 4200	(stack is around 407D)

The LNW80 has a rather complicated extended video space, and the LNW80-II is
slightly different

LNW80-II

Modes
0:	Text (as TRS80 64/32 column)
1:	128x48 + 480x192  (weird split mode with right side added)
2:	160x192 in 8 colours
3:	480x192 with 128x16 colour pair blocks

0x37E4(R) - Apple style joystick on bits 2-7 ( 2-7 in order F1 F2 X1 X2 Y2 Y1)

37DE/F serial
37E8 printer

Video RAM on LNW80

bitmap mode (when mapped in low)	0xFE bit D3 = 1 graphics
	00 RRRR LLLL CCCC	row line char (so top of each char first
				and interleaved like spectrum) 6bit wide
	00111RRLLLLrrCCCC	right side bit for 80 col
				RR=low 2 bits of rom, rr = high 2 bits of row
text
	3C00-3FFF		as TRS80m1

Colour mode options for ntsc output

Modes
0		Lores 128x48 mixed with text (TRS80)
1		Hires 480x192 mixed with lores
2		Lores 128x192 in 8 colours
3		Hires 38x192 with 128x16 colour mapping blocks (RGB monitor only)


UART at 0xE8-EB (modem status, config jumpers, status, rx R)
                (reset, -, control, tx W) TR1602B


0xE9 BRG  4bit codes 50/75/110/134.5/150/300/600/1200/1800/2000/2400/3600/
		     4800 7200 9600 19200
		TX << 4 | RX

0x95	Graphcis page display D7/D6  accessed D5/D4 - optional

0xFE	0: inverse video 1-2 display mode (0-2) 3 graphics enable low 16K
        4-6: background colour 7: set inverse char mode D5 bit 2 turns
	on/off char inverse video

0x95:	0-1 must be zero, 2 inverse char on/off 3 mbz 4-78 pages
