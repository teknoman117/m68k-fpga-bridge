SECTIONS
STARTUP(test_startup.o)
{
    . = 0x1000;
    .startup ;
    {
        *(.startup);
    }
    .text :
    {
        *(.text);
    }
    .data :
    {
        *(.data);
        *(.bss);
        *(.rodata);
    }
}
