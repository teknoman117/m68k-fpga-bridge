.section .text
.globl _start
_start:
    move.l #0x00900000, %a0
    movec.l %a0, %VBR
    nop
    bra.s _start
