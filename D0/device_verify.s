.code64
.global verify_device_map, check_device_integrity

# Verification Constants
.set VERIFY_OK,       0
.set VERIFY_CHANGED,  1
.set VERIFY_FAILED,   2
.set VERIFY_NEW,      3

# Device Signature Structure
.struct 0
SIG_HASH:       .quad 0    # Device hash
SIG_VENDOR:     .quad 0    # Vendor ID
SIG_DEVICE:     .quad 0    # Device ID
SIG_SERIAL:     .quad 0    # Serial number
SIG_FIRMWARE:   .quad 0    # Firmware version
SIG_CHECKSUM:   .quad 0    # Signature checksum
SIG_SIZE:

# Verify device mapping
verify_device_map:
    push    %rbx
    push    %r12
    push    %r13
    
    # Load stored hash table
    lea     device_hash_table(%rip), %rbx
    
    # For each device
1:
    # Get current device signature
    mov     (%rbx), %rdi
    call    generate_device_signature
    mov     %rax, %r12
    
    # Compare with stored
    mov     HASH_SIGNATURE(%rbx), %rdi
    mov     %r12, %rsi
    call    compare_signatures
    
    # Handle result
    cmp     $VERIFY_OK, %rax
    je      2f
    
    # Handle verification failure
    call    handle_verify_mismatch
    
2:
    add     $HASH_SIZE, %rbx
    dec     %rcx
    jnz     1b
    
    # Add phase-based verification
    call    verify_device_phase
    
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

# Generate device signature
generate_device_signature:
    push    %rbx
    mov     %rdi, %rbx    # Device pointer
    
    # Allocate signature structure
    mov     $SIG_SIZE, %rdi
    call    allocate_temp_buffer
    mov     %rax, %rdi
    
    # Get device info
    mov     %rbx, %rsi
    call    get_device_info
    
    # Generate hash
    call    hash_device_info
    
    # Store in signature
    mov     %rax, SIG_HASH(%rdi)
    
    pop     %rbx
    ret

# Handle verification mismatch
handle_verify_mismatch:
    push    %rbx
    mov     %rdi, %rbx    # Device pointer
    
    # Check mismatch type
    cmp     $VERIFY_CHANGED, %rax
    je      handle_device_changed
    cmp     $VERIFY_NEW, %rax
    je      handle_new_device
    
    # Handle failure
    call    report_verification_failure
    
    pop     %rbx
    ret

# Update device mapping
update_device_map:
    # Generate new signature
    call    generate_device_signature
    
    # Update hash table
    lea     device_hash_table(%rip), %rdi
    call    update_hash_entry
    
    # Verify update
    call    verify_update
    ret

# Data Section
.section .data
.align 8
verify_status:
    .quad 0    # Current verification status

# Read-only signature database
.section .rodata
known_signatures:
    .skip SIG_SIZE * 1024    # Known good signatures

# BSS Section
.section .bss
.align 4096
verify_buffer:
    .skip 4096    # Temporary verification buffer 