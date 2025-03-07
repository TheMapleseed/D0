.code64
.global init_unified_security, verify_security_state

# Combined Security Structure
.struct 0
SEC_PHASE:       .quad 0    # Cycle phase data
SEC_HASH:        .quad 0    # Phase-based hash
SEC_CERT:        .quad 0    # Phase certificate
SEC_PERM:        .quad 0    # Permissions
SEC_STATE:       .quad 0    # Security state
SEC_SIZE:

# Initialize unified security
init_unified_security:
    push    %rbx
    
    # Initialize cycle tracking
    call    init_cycle_tracking
    
    # Setup phase-based certificates
    call    init_phase_certificates
    
    # Initialize permission system
    call    init_phase_permissions
    
    # Start security monitor
    call    start_security_monitor
    
    pop     %rbx
    ret

# Generate security token
generate_security_token:
    push    %rbx
    push    %r12
    
    # Get cycle phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Generate phase-based hash
    mov     %rbx, %rdi
    call    generate_phase_hash
    mov     %rax, %r12
    
    # Create phase certificate
    mov     %rbx, %rdi
    mov     %r12, %rsi
    call    create_phase_certificate
    
    pop     %r12
    pop     %rbx
    ret

# Verify security state
verify_security_state:
    push    %rbx
    
    # Get current phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Verify phase certificate
    mov     %rdi, %rsi    # Security token
    mov     %rbx, %rdi    # Current phase
    call    verify_phase_cert
    
    # Check permissions
    test    %rax, %rax
    jz      security_failed
    
    # Verify hash
    call    verify_phase_hash
    
security_failed:
    pop     %rbx
    ret

# Update security state
update_security_state:
    push    %rbx
    push    %r12
    
    # Get new phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Update certificates
    mov     %rbx, %rdi
    call    update_phase_certificates
    
    # Update permissions
    call    update_phase_permissions
    
    # Verify state
    call    verify_security_state
    
    pop     %r12
    pop     %rbx
    ret

# Data Section
.section .data
.align 8
security_state:
    .skip SEC_SIZE * 1024    # Security state entries

phase_certificates:
    .skip 4096               # Phase certificates

# BSS Section
.section .bss
.align 4096
security_monitor:
    .skip 4096              # Security monitoring data 