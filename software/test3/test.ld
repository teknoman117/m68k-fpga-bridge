SECTIONS
{
    . = 0x000000;
    .vectortable :
    {
    	*(.vectortable)
    }
    . = 0x000040;
    .text :
    {
        *(.text)
    }
    . = 0x000080;
    .data :
    {
        *(.data)
    }
    . = 0x100000;
    _stack_end = .;
    . = 0x200000;
    _stack_begin = .;
}
