.code64
.global init_memory_layout, setup_instance_space

# Memory Region Types
.set MEM_SHARED,      0x01    # Shared between instances
.set MEM_PRIVATE,     0x02    # Instance-specific
.set MEM_ENCRYPTED,   0x04    # Encrypted space
.set MEM_PROTECTED,   0x08    # Write-protected

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

# Memory layout initialization
init_memory_layout:
    # Set up shared memory region
    mov     $SHARED_BASE, %rdi
    mov     $SHARED_SIZE, %rsi
    call    init_shared_space
    
    # Initialize instance spaces
    mov     $MAX_INSTANCES, %rcx
1:
    push    %rcx
    call    setup_instance_space
    pop     %rcx
    loop    1b
    ret

# Setup individual instance space
setup_instance_space:
    push    %rbx
    push    %r12
    
    # Allocate encrypted space
    mov     $INSTANCE_SIZE, %rdi
    call    allocate_encrypted_pages
    mov     %rax, %rbx
    
    # Generate instance key
    lea     INST_KEY(%rbx), %rdi
    call    generate_instance_key
    
    # Setup memory mapping
    mov     %rbx, %rdi
    call    setup_instance_mapping
    
    pop     %r12
    pop     %rbx
    ret

# Memory Map
.section .data
.align 4096
memory_layout:
    # Shared memory region (unencrypted)
    .quad SHARED_BASE          # Base address
    .quad SHARED_SIZE          # Size
    .byte MEM_SHARED          # Flags

    # Instance spaces (encrypted)
    .quad INSTANCE_BASE       # First instance
    .quad INSTANCE_SIZE       # Size per instance
    .byte MEM_PRIVATE | MEM_ENCRYPTED

    # Protected regions
    .quad PROTECTED_BASE      # Protected memory
    .quad PROTECTED_SIZE      # Size
    .byte MEM_PROTECTED 