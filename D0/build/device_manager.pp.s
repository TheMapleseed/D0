.code64
.global init_device_manager, cleanup_device_manager, register_device, verify_device_state, verify_device_links
# Defaults for table sizing (portable for assembler-time expressions)
.set MAX_DEVICES, 128


# Device Types
.set DEV_BLOCK,      0x01
.set DEV_CHAR,       0x02
.set DEV_NETWORK,    0x03
.set DEV_SPECIAL,    0x04

# Error Types
.set ERR_IRQ_CONFLICT,  0x01
.set ERR_IRQ_INVALID,   0x02
.set ERR_DEV_CONFLICT,  0x03

# Device Structure
DEV_ID:          .quad 0    # Device ID
DEV_TYPE:        .quad 0    # Device type
DEV_OPS:         .quad 0    # Operations table
DEV_STATE:       .quad 0    # Device state
DEV_BUFFER:      .quad 0    # Device buffer
DEV_IRQ:         .quad 0    # IRQ number
DEV_NEURAL:      .quad 0    # Neural feedback data
.set DEV_SIZE, 0

register_device:
    push    %rbx
    push    %r12
    mov     %rdi, %rbx     # Save device structure

    # Check for IRQ conflicts
    mov     DEV_IRQ(%rbx), %rdi
    call    check_irq_conflict
    test    %rax, %rax
    jnz     handle_irq_conflict

    # Normal registration continues
    call    do_device_registration
    pop     %r12
    pop     %rbx
    ret

handle_irq_conflict:
    # Prepare neural feedback
    lea     neural_conflict_data(%rip), %rdi
    mov     %rax, (%rdi)                    # Save error type
    mov     DEV_IRQ(%rbx), %rax
    mov     %rax, 8(%rdi)                   # Save conflicting IRQ
    
    # Feed conflict to neural network
    call    neural_analyze_irq_conflict
    
    # Get neural suggestion for IRQ resolution
    call    neural_get_irq_adaptation
    test    %rax, %rax
    jz      registration_failed
    
    # Try neural-suggested IRQ
    mov     %rax, DEV_IRQ(%rbx)
    mov     %rbx, %rdi
    call    register_device                  # Recursive retry with new IRQ
    
    pop     %r12
    pop     %rbx
    ret

registration_failed:
    # Record failure pattern for learning
    call    record_device_failure
    mov     $-1, %rax
    pop     %r12
    pop     %rbx
    ret

# Initialize device manager
init_device_manager:
    # Setup device table
    lea     device_table(%rip), %rdi
    mov     $MAX_DEVICES, %rsi
    call    init_device_table
    
    # Scan for devices
    call    scan_pci_devices
    call    scan_usb_devices
    call    scan_nvme_devices
    
    # Initialize found devices
    call    init_detected_devices
    ret

# Cleanup device manager and release resources
cleanup_device_manager:
    push    %rbx
    push    %r12
    
    # Unregister all devices
    lea     device_table(%rip), %rbx
    mov     $MAX_DEVICES, %r12d
1:
    mov     DEV_ID(%rbx), %rdi
    test    %rdi, %rdi
    jz      2f
    
    # Shutdown device
    call    shutdown_device
    
    # Free device resources
    mov     %rbx, %rdi
    call    free_device_resources
    
2:  add     $DEV_SIZE, %rbx
    dec     %r12
    jnz     1b
    
    # Clear device table
    lea     device_table(%rip), %rdi
    mov     $(DEV_SIZE * MAX_DEVICES), %ecx
    xor     %rax, %rax
    rep stosb
    
    pop     %r12
    pop     %rbx
    ret

# Free device specific resources
free_device_resources:
    push    %rbx
    mov     %rdi, %rbx    # Device structure
    
    # Free device buffer if allocated
    mov     DEV_BUFFER(%rbx), %rdi
    test    %rdi, %rdi
    jz      1f
    call    free_pages
    
    # Free IRQ if assigned
    mov     DEV_IRQ(%rbx), %rdi
    test    %rdi, %rdi
    jz      1f
    call    free_irq
    
1:  pop     %rbx
    ret

# Data Section
.section .data
.align 8
device_table:
    .skip (DEV_SIZE * MAX_DEVICES)

# Neural learning data
neural_conflict_data:
    .quad 0    # Error type
    .quad 0    # Conflicting IRQ
    .quad 0    # Resolution attempt
    .quad 0    # Success/failure flag

# Verification States
.set DEV_VERIFIED,    0x01
.set DEV_FAILED,      0xFF

verify_device_state:
    push    %rbx
    push    %r12
    
    # Verify device manager state
    call    check_device_integrity
    test    %rax, %rax
    jz      device_verify_failed
    
    # Verify forward link (back to Live0)
    call    verify_boot_link
    test    %rax, %rax
    jz      device_verify_failed
    
    # Verify backward link (sync system)
    call    verify_sync_link
    test    %rax, %rax
    jz      device_verify_failed
    
    movq    $DEV_VERIFIED, device_verify_state(%rip)
    mov     $1, %rax
    jmp     device_verify_done

device_verify_failed:
    movq    $DEV_FAILED, device_verify_state(%rip)
    xor     %rax, %rax

device_verify_done:
    pop     %r12
    pop     %rbx
    ret
