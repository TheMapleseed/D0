.code64
.global init_permission_system, verify_permission, update_permissions

# External references
.extern get_cycle_phase
.extern verify_phase_cert
.extern generate_phase_hash

# Permission Structure (aligned with cycle security)
.struct 0
PERM_PHASE:      .quad 0    # Phase timing
PERM_HASH:       .quad 0    # Phase-based hash
PERM_FLAGS:      .quad 0    # Permission flags
PERM_STATE:      .quad 0    # Current state
PERM_SIZE:

# Initialize permission system
init_permission_system:
    push    %rbx
    
    # Get initial phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Setup initial permissions
    mov     %rbx, %rdi
    call    setup_phase_permissions
    
    # Initialize state
    call    init_permission_state
    
    pop     %rbx
    ret

# Verify permission with phase
verify_permission:
    push    %rbx
    push    %r12
    
    # Get current phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Verify phase timing
    mov     %rdi, %r12    # Save permission request
    mov     %rbx, %rdi    # Current phase
    mov     PERM_PHASE(%r12), %rsi    # Stored phase
    call    verify_phase_cert
    test    %rax, %rax
    jz      perm_denied
    
    # Verify permission hash
    mov     %rbx, %rdi
    mov     PERM_HASH(%r12), %rsi
    call    verify_phase_hash
    test    %rax, %rax
    jz      perm_denied
    
    # Check permission flags
    mov     PERM_FLAGS(%r12), %rax
    and     required_permissions, %rax
    cmp     required_permissions, %rax
    jne     perm_denied
    
    mov     $1, %rax
    jmp     verify_exit

perm_denied:
    xor     %rax, %rax

verify_exit:
    pop     %r12
    pop     %rbx
    ret

# Update permissions
update_permissions:
    push    %rbx
    
    # Get new phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Update phase timing
    mov     %rbx, %rdi
    call    update_permission_phase
    
    # Generate new hash
    mov     %rbx, %rdi
    call    generate_phase_hash
    
    # Update state
    call    update_permission_state
    
    pop     %rbx
    ret

# Data Section
.section .data
.align 8
permission_state:
    .skip PERM_SIZE * 1024    # Permission entries

required_permissions:
    .quad 0                   # Required permission mask

# BSS Section
.section .bss
.align 4096
permission_cache:
    .skip 4096               # Permission cache