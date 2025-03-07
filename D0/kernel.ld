ENTRY(_start)

SECTIONS {
    /* Kernel starts at 1MB */
    . = 1M;

    .text BLOCK(4K) : ALIGN(4K) {
        *(.text)           /* All text sections */
    }

    .rodata BLOCK(4K) : ALIGN(4K) {
        *(.rodata)        /* Read-only data */
        syscall_table = .; /* System call table */
    }

    .data BLOCK(4K) : ALIGN(4K) {
        *(.data)          /* All data sections */
    }

    .bss BLOCK(4K) : ALIGN(4K) {
        *(COMMON)         /* Common symbols */
        *(.bss)           /* All BSS sections */
    }
}
