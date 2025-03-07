/* Linker Script */
ENTRY(_start)

SECTIONS
{
    /* Code section */
    .text 0x100000 : {
        *(.text.boot)    /* Boot code first */
        *(.text)         /* Regular code */
        *(.text.*)       /* Other text sections */
    }

    /* Read-only data */
    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Read-write data */
    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    }

    /* BSS section */
    .bss ALIGN(4K) : {
        *(COMMON)
        *(.bss)
        *(.bss.*)
    }

    /* Special sections */
    .device_store ALIGN(4K) : {
        *(.device_store)
    }

    .security ALIGN(4K) : {
        *(.security)
        *(.security.*)
    }

    /* Neural network data */
    .neural ALIGN(4K) : {
        *(.neural)
        *(.neural.*)
    }

    /* Add new obfuscation sections here */
    .obfuscated ALIGN(4K) : {
        *(.obfuscated)
        *(.obfuscated.*)
    }

    .decoy ALIGN(4K) : {
        *(.decoy)
        *(.decoy.*)
    }

    .trap ALIGN(4K) : {
        *(.trap)
        *(.trap.*)
    }

    /* Debugging sections */
    .debug_info    0 : { *(.debug_info) }
    .debug_abbrev  0 : { *(.debug_abbrev) }
    .debug_line    0 : { *(.debug_line) }
    .debug_str     0 : { *(.debug_str) }

    /DISCARD/ : {
        *(.comment)
        *(.eh_frame)
        *(.note.*)
    }
} 