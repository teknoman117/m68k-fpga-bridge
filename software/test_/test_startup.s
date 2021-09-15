    .section .startup
_start:
    jsr .init
    jsr main
    jsr .fini
