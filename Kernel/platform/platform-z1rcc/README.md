# Fuzix for Z1RCC

## Supported Hardware

- Z1RCC CPU card

## Options

- SD card on CSIO (SC126 and similar)
- Wiznet 5500 on CSIO

## Installation

make diskimage

The resulting disk.img is a raw CF image.

Boot using the built in ROM loader

For emulation

z1rcc -i emu-ide.img

## Configuration Options

- CONFIG_NET_W5500_FDM: set if you have a W5500 but no chip select line

## Boot options

