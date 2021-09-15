    .section .text
start:
    move.w #0xaaaa, %d0
    move.w #0xbbbb, %d1
    movem.l %d0-%d3/%d6/%a3-%a6, -(%sp)
