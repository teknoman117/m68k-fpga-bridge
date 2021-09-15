SECTIONS
{
    . = 0M;
    . = 16320K;
    .text :
    {
        *(.*)
    }
    .vectortable :
    {
        *(.*)
    }
}
