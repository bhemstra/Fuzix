# Beoordeling en wijzigingen (TRS-80-versie)

## Wat er is gedaan

- Alle CPU's behalve Z80 en alle platforms behalve `trs80` (Model 4/4D/4P)
  verwijderd: kernel (`cpu-*`, `platform-*`, `lib`, `dev`, tools),
  Library (Makefiles, crt0/setjmp/syscall-varianten, include-mappen,
  linkerscripts), Applications (Makefiles per CPU, 6809-tools, emulators,
  flashrom, cross-backends van assembler en compiler), Target, Tools,
  Build, Standalone (`mkftl`) en documentatie.
- Nieuwe port `Kernel/platform/platform-trs80m2` voor de TRS-80 Model II
  (ook 12/16/16B/6000 als Z80-machine). Zie de README daar.
- Top-level `Makefile`, `README.md`, `INSTALL`, `STATUS.md` en
  `BUILD_REQUIREMENTS.md` aangepast.

Bouwen:

```
make TARGET=trs80 kernel
make TARGET=trs80m2 kernel
```

Beide kernels bouwen met de standaard SDCC 4.2. Gebruikersprogramma's
vragen de Fuzix Compiler Kit (`fcc`) en Fuzix-Bintools; die zijn hier niet
getest.

## Bevindingen in de bestaande code

1. **Aanroepconventie SDCC (ernstig).** De handgeschreven Z80-assembly
   (o.a. `usermem_std-z80.s`, `lowlevel-z80.s`, de drivers) haalt
   argumenten van de stack. SDCC 4.2 en nieuwer geven argumenten
   standaard door in registers (`__sdcccall(1)`) en de meegeleverde
   `z80.lib` is alleen daarvoor gebouwd. De Model 4-kernel compileerde en
   linkte daardoor zonder foutmelding, maar zou bij de eerste
   `uget`/`uput` vastlopen. Opgelost met `--sdcccall 0` in
   `Kernel/cpu-z80/rules.mk` en een eigen hulpbibliotheek
   `Kernel/cpu-z80/sdccrt`, gebouwd met dezelfde opties. De kernel linkt
   niets meer uit `z80.lib`, zodat een ontbrekende routine een linkfout
   geeft in plaats van een stil defect.
2. **`_HOME`-segment.** De C-hulproutines van SDCC komen in het segment
   `_HOME`. Dat stond niet in de segmentvolgorde van `crt0.s` en zou dan
   buiten het kernelimage vallen. Toegevoegd aan beide `crt0.s`.
3. **Printerdriver Model 4 (`devlpr.c`).** `lpr_write` verlaagde de
   teller nooit (oneindige lus), gaf altijd -1 terug en gebruikte poort
   0x02/0x03 met een onjuiste klaar-test. Nu poort 0xF8 met de test
   `(status & 0xF0) == 0x30` van de ROM, telt de bytes en respecteert
   `O_NDELAY`.
4. **`.gitignore` sloot `fuzix.lnk` uit.** Daardoor raakt een kloon in
   git zijn linkerscripts kwijt. Uitzondering toegevoegd.
5. **`trs80m1` (Model I/III) bouwde niet** (tegenstrijdige declaraties
   van `fd3_operation`/`fd3_motor_on`). Die port is volgens de opdracht
   verwijderd.
6. **Kleinere punten (niet gewijzigd):** de Model 4 harde-schijfdriver
   wacht zonder time-out op "ready" (`hd_waitready`), het schrijven naar
   diskettes is volgens `Notes.md` nog niet af, en de gedeelde
   kernelcode bevat nog `#ifdef`-takken voor andere CPU's. Die laatste
   zijn onschadelijk en zijn bewust niet aangeraakt.

## Model II-port: status

De port is geschreven op basis van de Technical Reference Manual, de
TRSDOS-II-handleiding, de MAME-driver en een reconstructie van de
boot-ROM. Hij is **niet getest** op hardware of in een emulator. Het
meeste risico zit in de DMA-programmering voor de diskette, de
toetsenbordcodes en de omzetting van de klok-NMI naar een timerinterrupt.
Details en een controlelijst staan in
`Kernel/platform/platform-trs80m2/README.md`.
