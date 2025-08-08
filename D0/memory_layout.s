.code64
.global init_memory_layout, setup_instance_space

# Memory Region Types
.set MEM_SHARED,      0x01    # Shared between instances
.set MEM_PRIVATE,     0x02    # Instance-specific
.set MEM_ENCRYPTED,   0x04    # Encrypted space
.set MEM_PROTECTED,   0x08    # Write-protected

# Security constants
.set MEM_MIN_SIZE,     4096    # Minimum allocation size
.set MEM_MAX_SIZE,     0x100000000  # Maximum allocation size (4GB)
.set MEM_ALIGNMENT,    4096    # Page alignment requirement
.set MEM_CANARY_SIZE,  16      # Stack canary size

# Memory Layout Structure
.struct 0
LAYOUT_SHARED:    .quad 0    # Shared memory base
LAYOUT_SIZE:      .quad 0    # Shared region size
LAYOUT_INSTANCES: .quad 0    # Instance memory array
LAYOUT_KEYS:      .quad 0    # Encryption keys
LAYOUT_MAP:       .quad 0    # Memory mapping table
LAYOUT_SIZE:

# Instance Memory Structure
.struct 0
INST_BASE:        .quad 0    # Instance base address
INST_KEY:         .quad 0    # Instance encryption key
INST_IV:          .quad 0    # Encryption IV
INST_STATE:       .quad 0    # Instance state
INST_SIZE:

# Secure memory allocation with bounds checking
allocate_secure_memory:
    .cfi_startproc
    .cfi_def_cfa rsp, 8
    push    %rbx
    .cfi_offset rbx, -16
    push    %r12
    .cfi_offset r12, -24
    push    %r13
    .cfi_offset r13, -32
    
    # %rdi = requested size
    mov     %rdi, %r12
    
    # Validate size bounds
    call    validate_allocation_size
    test    %rax, %rax
    jz      allocation_failed
    
    # Check for integer overflow
    mov     %r12, %rax
    add     $MEM_CANARY_SIZE, %rax
    jc      allocation_failed
    
    # Allocate memory with canary protection
    mov     %r12, %rdi
    call    allocate_memory_with_canary
    test    %rax, %rax
    jz      allocation_failed
    
    mov     %rax, %rbx
    
    # Initialize memory with secure pattern
    mov     %rbx, %rdi
    mov     %r12, %rsi
    call    initialize_secure_memory
    
    # Set up memory protection
    mov     %rbx, %rdi
    mov     %r12, %rsi
    call    setup_memory_protection
    
    mov     %rbx, %rax
    
allocation_exit:
    pop     %r13
    .cfi_restore r13
    pop     %r12
    .cfi_restore r12
    pop     %rbx
    .cfi_restore rbx
    ret
    .cfi_endproc

allocation_failed:
    xor     %rax, %rax
    jmp     allocation_exit

# Validate allocation size against security bounds
validate_allocation_size:
    .cfi_startproc
    # %rdi = requested size
    
    # Check minimum size
    cmp     $MEM_MIN_SIZE, %rdi
    jb      size_invalid
    
    # Check maximum size
    cmp     $MEM_MAX_SIZE, %rdi
    ja      size_invalid
    
    # Check alignment requirement
    test    $(MEM_ALIGNMENT-1), %rdi
    jnz     size_invalid
    
    mov     $1, %rax
    ret
    
size_invalid:
    xor     %rax, %rax
    ret
    .cfi_endproc

# Allocate memory with stack canary protection
allocate_memory_with_canary:
    .cfi_startproc
    # %rdi = size
    push    %rbx
    push    %r12
    
    # Add canary space
    add     $MEM_CANARY_SIZE, %rdi
    mov     %rdi, %r12
    
    # Allocate memory
    call    allocate_pages
    test    %rax, %rax
    jz      canary_allocation_failed
    
    mov     %rax, %rbx
    
    # Generate and place canary
    call    generate_memory_canary
    mov     %rax, (%rbx)
    mov     %rax, (%rbx,%r12)
    
    # Return address after canary
    lea     MEM_CANARY_SIZE(%rbx), %rax
    
canary_allocation_exit:
    pop     %r12
    pop     %rbx
    ret
    
canary_allocation_failed:
    xor     %rax, %rax
    jmp     canary_allocation_exit
    .cfi_endproc

# Generate cryptographically secure canary
generate_memory_canary:
    .cfi_startproc
    push    %rbx
    
    # Use hardware entropy for canary
    rdrand  %rax
    rdtsc
    shl     $32, %rdx
    or      %rax, %rdx
    mov     %rdx, %rbx
    
    # Mix with additional entropy
    rdrand  %rax
    xor     %rbx, %rax
    
    # Ensure canary is non-zero
    test    %rax, %rax
    jz      generate_memory_canary
    
    pop     %rbx
    ret
    .cfi_endproc

# Initialize memory with secure pattern
initialize_secure_memory:
    .cfi_startproc
    # %rdi = memory address, %rsi = size
    push    %rbx
    push    %r12
    push    %r13
    
    mov     %rdi, %rbx    # Memory address
    mov     %rsi, %r12    # Size
    mov     $0, %r13      # Counter
    
    # Fill with secure random pattern
init_loop:
    rdrand  %rax
    mov     %rax, (%rbx,%r13,8)
    
    add     $8, %r13
    cmp     %r12, %r13
    jb      init_loop
    
    pop     %r13
    pop     %r12
    pop     %rbx
    ret
    .cfi_endproc

# Setup memory protection with W^X
setup_memory_protection:
    .cfi_startproc
    # %rdi = memory address, %rsi = size
    push    %rbx
    push    %r12
    
    mov     %rdi, %rbx
    mov     %rsi, %r12
    
    # Align to page boundary
    call    align_to_page_boundary
    
    # Set up page protection
    mov     %rbx, %rdi
    mov     %r12, %rsi
    mov     $0x1, %rdx    # Read-only initially
    call    set_page_protection
    
    pop     %r12
    pop     %rbx
    ret
    .cfi_endproc

# Memory layout initialization with security
init_memory_layout:
    .cfi_startproc
    .cfi_def_cfa rsp, 8
    push    %rbx
    .cfi_offset rbx, -16
    push    %r12
    .cfi_offset r12, -24
    
    # Validate memory layout parameters
    call    validate_memory_layout
    test    %rax, %rax
    jz      layout_init_failed
    
    # Set up shared memory region with security
    mov     $SHARED_BASE, %rdi
    mov     $SHARED_SIZE, %rsi
    call    init_secure_shared_space
    test    %rax, %rax
    jz      layout_init_failed
    
    # Initialize instance spaces with encryption
    mov     $MAX_INSTANCES, %rcx
1:
    push    %rcx
    call    setup_secure_instance_space
    pop     %rcx
    test    %rax, %rax
    jz      layout_init_failed
    loop    1b
    
    mov     $1, %rax
    
layout_init_exit:
    pop     %r12
    .cfi_restore r12
    pop     %rbx
    .cfi_restore rbx
    ret
    .cfi_endproc

layout_init_failed:
    xor     %rax, %rax
    jmp     layout_init_exit

# Setup individual instance space with security
setup_secure_instance_space:
    .cfi_startproc
    .cfi_def_cfa rsp, 8
    push    %rbx
    .cfi_offset rbx, -16
    push    %r12
    .cfi_offset r12, -24
    
    # Allocate encrypted space with bounds checking
    mov     $INSTANCE_SIZE, %rdi
    call    allocate_secure_memory
    test    %rax, %rax
    jz      instance_setup_failed
    
    mov     %rax, %rbx
    
    # Generate cryptographically secure instance key
    lea     INST_KEY(%rbx), %rdi
    call    generate_secure_instance_key
    test    %rax, %rax
    jz      instance_setup_failed
    
    # Setup secure memory mapping
    mov     %rbx, %rdi
    call    setup_secure_instance_mapping
    test    %rax, %rax
    jz      instance_setup_failed
    
    # Initialize secure instance
    mov     %rbx, %rdi
    call    init_secure_instance
    test    %rax, %rax
    jz      instance_setup_failed
    
    mov     $1, %rax
    
instance_setup_exit:
    pop     %r12
    .cfi_restore r12
    pop     %rbx
    .cfi_restore rbx
    ret
    .cfi_endproc

instance_setup_failed:
    xor     %rax, %rax
    jmp     instance_setup_exit

# Generate cryptographically secure instance key
generate_secure_instance_key:
    .cfi_startproc
    # %rdi = key storage location
    push    %rbx
    push    %r12
    
    mov     %rdi, %rbx
    
    # Collect hardware entropy
    call    collect_hardware_entropy
    
    # Derive key using cryptographic mixing
    mov     %rax, %rdi
    mov     %rbx, %rsi
    call    derive_cryptographic_key
    
    # Verify key quality
    mov     %rbx, %rdi
    call    verify_key_quality
    test    %rax, %rax
    jz      key_generation_failed
    
    mov     $1, %rax
    
key_generation_exit:
    pop     %r12
    pop     %rbx
    ret
    .cfi_endproc

key_generation_failed:
    xor     %rax, %rax
    jmp     key_generation_exit

# Memory Map with security features
.section .data
.align 4096
secure_memory_map:
    .quad SHARED_BASE          # Base address
    .quad SHARED_SIZE          # Size
    .byte MEM_SHARED | MEM_PROTECTED  # Flags with protection

    .quad INSTANCE_BASE       # First instance
    .quad INSTANCE_SIZE       # Size per instance
    .byte MEM_PRIVATE | MEM_ENCRYPTED

    .quad PROTECTED_BASE      # Protected memory
    .quad PROTECTED_SIZE      # Size
    .byte MEM_PROTECTED

# Security canary storage
.section .bss
.align 16
memory_canaries:
    .skip MEM_CANARY_SIZE * 1024  # Canary storage for 1024 allocations 