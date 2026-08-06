OUTPUT_ARCH(riscv)
OUTPUT_FORMAT("elf32-littleriscv")
ENTRY(_start)

MEMORY
{
    INSTRUCTION_MEMORY (rx) : ORIGIN = 0x00000100, LENGTH = 0x00000400
}

SECTIONS
{
    .text ORIGIN(INSTRUCTION_MEMORY) :
    {
        . = ALIGN(4);
        KEEP(*(.text))
        *(.text.*)
        . = ALIGN(4);
    } > INSTRUCTION_MEMORY

    /DISCARD/ :
    {
        *(.data*)
        *(.bss*)
        *(.rodata*)
        *(.sdata*)
        *(.sbss*)
        *(.eh_frame*)
        *(.comment*)
        *(.note*)
        *(.riscv.attributes)
    }
}

ASSERT(ADDR(.text) == ORIGIN(INSTRUCTION_MEMORY),
       "Program does not begin at the ForgeRV reset vector")

ASSERT(SIZEOF(.text) <= LENGTH(INSTRUCTION_MEMORY),
       "Program exceeds the 256-instruction memory")
