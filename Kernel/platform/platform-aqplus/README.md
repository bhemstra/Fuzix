# Fuzix For The Aquarius Plus

An initial port to the Aquarius+ machine. This is a modern interpretation
of the Aquarius rather fixed up from the original. As it supports 16K
banking we use 16K banking throughout.

## Things To Do
-	RTC driver using the ESP
-	Ink/paper/border setting
-	40/80 col mode switching
-	Look at mouse reporting
-	Graphics API routines
-	Swap
-	Console beep
-	Some way to import/export data (as the C64 also could do with)
-	Media switching

## To Run

At the moment the loader is a cartridge file as it's easier to debug. This
needs sorting out. It loads FUZIX.BIN from the SD card and that then uses
FUZIXHD0.IMG (and 1 2 3) for the disks.

## Notes

The AQ+ does tricks with the RAM and cartridge on boot so that it ends up
as bank 3F and write protected. Thus we use 20-23 for the kernel unlike most
other ports that use the upper banks on 16Kx4.
