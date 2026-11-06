# Fuzix for Bill Shen's EasyZ80-512K

512K RAM and a KIO with 32K fixed upper memory and the lower banked. ROMWBW is
unpacked into RAM so our loader has to be a bit more careful not to blow
things up too early.

## Supported Hardware

- EasyZ80 SBC
- Onboard KIO (SIO, CTC and PIO ports) including SD bitbang

## TODO

- Doesn't successfully reboot into ROMWBW
- TMS9918A at 0x98/99 ?

## Optional Devices

- DS1302 at 0xC0 (0x0C is in KIO space)
- IDE CF at 0x90 (0x10 ditto)
