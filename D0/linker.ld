/* Modern linker script for Intel processors with security features */

ENTRY(_start)

/* Modern memory layout with proper alignment */
SECTIONS
{
    /* Modern boot code first with proper alignment */
    .text 0x100000 : {
        *(.text.boot)    /* Boot code first */
        *(.text)         /* Regular code */
        *(.text.*)       /* Other text sections */
    }

    /* Modern read-only data with proper alignment */
    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Modern data section with proper alignment */
    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    }

    /* Modern BSS section with proper alignment */
    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }

    /* Modern stack with proper alignment */
    .stack ALIGN(4K) : {
        . = . + 64K;     /* 64KB stack */
        stack_top = .;
    }

    /* Modern heap with proper alignment */
    .heap ALIGN(4K) : {
        heap_start = .;
        . = . + 1M;      /* 1MB heap */
        heap_end = .;
    }

    /* Modern syscall table with proper alignment */
    .syscall ALIGN(8) : {
        syscall_table = .;
        *(.syscall)
    }

    /* Modern security features */
    .security ALIGN(4K) : {
        *(.security)
        *(.security.*)
    }
} 