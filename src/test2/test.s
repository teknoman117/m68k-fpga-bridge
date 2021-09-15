.section .text
.globl _start
_start:
    move.l _ivt, %a0
    movec.l %a0, %VBR
    nop
    bra.s _start

_handler:
    rte

.section .vectortable
.align 4
.globl _ivt
_ivt:
    .long _handler
