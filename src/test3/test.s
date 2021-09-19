.section .data
.globl _display
_display: .word 0

.section .text
.globl _start
_start:
    move.w #0xaaaa, %d0
    move.w _display, %a0
_loop:
    move.w %d0, (%a0)+
    not.w %d0
    bra.s _loop

.section .vectortable
.align 4
.globl _ivt
_ivt:
    .long _stack_begin
    .long _start
