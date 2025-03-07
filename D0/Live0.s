.code16
.global _start

# System States
.set SYS_INIT,         0x01
.set SYS_VERIFY,       0x02
.set SYS_READY,        0x03
.set SYS_ERROR,        0xFF

# Verification Chain
.set VERIFY_NEURAL,    0x01
.set VERIFY_MEMORY,    0x02
.set VERIFY_HEALING,   0x03
.set VERIFY_SYNC,      0x04
.set VERIFY_DEVICE,    0x05
.set VERIFY_BOOT,      0x06
.set VERIFY_FS,        0x07    # Added filesystem verification step

_start:
    # Initial CPU checks
    call    check_cpu_features
    test    %ax, %ax
    jz      cpu_error

    # Start circular verification
    call    init_verification_chain
    test    %ax, %ax
    jz      verify_error

    # Begin component verification loop
    mov     $VERIFY_NEURAL, %al
verify_loop:
    push    %ax
    call    verify_component
    test    %ax, %ax
    jz      chain_error
    
    pop     %ax
    inc     %al
    cmp     $VERIFY_FS+1, %al    # Updated to include FS verification
    jne     verify_loop

    # All components verified, start system
    call    start_system
    ret

verify_component:
    # Save registers
    push    %rbx
    push    %r12
    
    # Get component to verify
    movzx   %al, %ebx
    
    # Get verification function
    lea     verify_table(%rip), %r12
    mov     (%r12,%rbx,8), %rax
    
    # Call verification
    call    *%rax
    
    # Check next component
    test    %rax, %rax
    jz      1f
    
    # Verify backwards link
    call    verify_backward_link
    
1:  pop     %r12
    pop     %rbx
    ret

# Start the system with all components initialized
start_system:
    # Save registers
    push    %rbx
    
    # Initialize neural components
    call    init_neural_components
    test    %rax, %rax
    jz      .system_failed
    
    # Initialize memory systems
    call    init_memory_systems
    test    %rax, %rax
    jz      .system_failed
    
    # Initialize device systems
    call    init_device_systems
    test    %rax, %rax
    jz      .system_failed
    
    # Initialize healing systems
    call    init_healing_systems
    test    %rax, %rax
    jz      .system_failed
    
    # Conditionally initialize filesystem
    # This will only create the filesystem if configured to do so
    call    init_filesystem
    
    # Note: We continue even if filesystem initialization fails
    # as it may be intentionally disabled
    
    # Complete system startup
    call    complete_system_startup
    
    # Return success
    mov     $1, %rax
    pop     %rbx
    ret
    
.system_failed:
    xor     %rax, %rax
    pop     %rbx
    ret

# Initialize the filesystem if configured
init_filesystem:
    # Save registers
    push    %rbx
    
    # Check for filesystem configuration
    call    check_fs_config
    test    %rax, %rax
    jz      .no_filesystem
    
    # Initialize H2 filesystem
    call    init_h2_fs
    
    # Store result (but we continue regardless)
    mov     %rax, fs_enabled(%rip)
    
.no_filesystem:
    # Return success regardless (filesystem is optional)
    mov     $1, %rax
    pop     %rbx
    ret

# Check for filesystem configuration
check_fs_config:
    # First check for boot parameter
    call    check_fs_boot_param
    test    %rax, %rax
    jnz     .fs_config_found
    
    # Then check for configuration file
    call    check_fs_config_file
    test    %rax, %rax
    jnz     .fs_config_found
    
    # No filesystem configuration found
    xor     %rax, %rax
    ret
    
.fs_config_found:
    mov     $1, %rax
    ret

# Verification function table
verify_table:
    .quad verify_neural_state
    .quad verify_memory_patterns
    .quad verify_healing_system
    .quad verify_sync_state
    .quad verify_device_state
    .quad verify_boot_state
    .quad verify_fs_state         # Added filesystem verification function

# Data section
.section .data
.align 8
verify_state:
    .quad 0    # Current verification state
fs_enabled:
    .quad 0    # Filesystem enabled flag

# Messages
verify_error_msg:
    .ascii "Verification chain failed\r\n\0"

# External functions
.extern init_h2_fs, h2_check_enabled

# Function stubs (to be implemented)
.text
check_fs_boot_param:
    ret
check_fs_config_file:
    ret
verify_fs_state:
    ret
