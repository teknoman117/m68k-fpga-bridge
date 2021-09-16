# HDL

## freerun

Puts the m68k into a "freerun". The data bus is wired to 0x0000, which is the opcode for "ORI.B #0, D0". The processor's address bus should count 0, 2, 4, then 6 for the first 4 cycles. This sets both the program counter and the stack pointer to 0x0000. The processor will then jump to 0 and start counting through all addresses until it wraps back around to 0x0000. At 12.5 MHz, this takes about 2.68 seconds.

This example will validate that the addresses count as expected to validate the correct operation of the address bus, address strobe, reset, and clock signals. If an error is encountered, a single 'E' is output to the UART and the m68k will be reset.

## bus-to-uart

Communicates every bus state over the uart so that a host side program can issue commands directly to it and watch what happens. Should validate all bus signals.

## mojo-base-project

Submodule pointing to the base ISE project for the mojo board from Embedded Micro (now Alchitry). This provides the avr interface module.
