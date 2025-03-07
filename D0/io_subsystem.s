.code64
.global init_io_subsystem

# I/O Subsystem Structure
.struct 0
IO_CONTROLLER:   .quad 0    # I/O controller state
IO_INSTANCES:    .quad 0    # Instance mapping table
IO_SHARED:       .quad 0    # Shared buffer space
IO_FLAGS:        .quad 0    # Control flags
IO_SIZE:

init_io_subsystem:
    # Initialize in shared memory space
    mov     shared_memory_base, %rdi
    lea     IO_CONTROLLER(%rdi), %rsi
    
    # Setup instance mappings
    call    setup_io_mappings
    
    # Initialize shared buffers
    call    init_shared_buffers
    ret 