.code64
.global init_go_shared_api, go_shared_syscall

# Shared Memory Constants
.set SHARED_BASE,      0x1000000    # Shared memory base
.set SHARED_SIZE,      0x10000000   # 256MB shared space
.set GO_HEAP_OFFSET,   0x1000000    # Go heap offset
.set GO_STACK_OFFSET,  0x8000000    # Go stack space

# Shared Structure
.struct 0
SHARED_HEAD:     .quad 0    # Shared memory header
SHARED_ALLOC:    .quad 0    # Allocation table
SHARED_USED:     .quad 0    # Usage bitmap
SHARED_LOCK:     .quad 0    # Lock table
SHARED_SIZE:

# Go Shared API Functions
.set GO_SHARED_ALLOC,  0x01    # Shared allocation
.set GO_SHARED_FREE,   0x02    # Free shared memory
.set GO_SHARED_SYNC,   0x03    # Sync primitives
.set GO_SHARED_MAP,    0x04    # Memory mapping

# Initialize shared API
init_go_shared_api:
    push    %rbx
    
    # Setup shared memory region
    mov     $SHARED_BASE, %rdi
    mov     $SHARED_SIZE, %rsi
    call    init_shared_region
    
    # Initialize allocation table
    lea     shared_alloc_table(%rip), %rdi
    call    init_alloc_table
    
    # Setup Go heap in shared space
    mov     $GO_HEAP_OFFSET, %rdi
    call    init_go_heap
    
    pop     %rbx
    ret

# Shared memory allocation
go_shared_alloc:
    push    %rbx
    push    %r12
    
    # Verify in shared range
    call    verify_shared_range
    test    %rax, %rax
    jz      shared_alloc_error
    
    # Allocate from shared pool
    mov     %rdi, %r12    # Save size
    call    allocate_shared
    
    # Update allocation table
    mov     %rax, %rdi
    mov     %r12, %rsi
    call    update_alloc_table
    
    pop     %r12
    pop     %rbx
    ret

# Shared memory mapping
map_shared_memory:
    push    %rbx
    
    # Calculate shared offset
    mov     %rdi, %rbx
    sub     $SHARED_BASE, %rbx
    
    # Verify offset
    cmp     $SHARED_SIZE, %rbx
    jae     map_error
    
    # Map into Go space
    mov     %rbx, %rdi
    call    map_to_go_space
    
    pop     %rbx
    ret

# Data Section
.section .data
.align 8
shared_memory_map:
    .quad SHARED_BASE          # Base address
    .quad SHARED_SIZE          # Total size
    .quad GO_HEAP_OFFSET       # Go heap
    .quad GO_STACK_OFFSET      # Go stacks

# Allocation table
.section .shared_alloc
.align 4096
shared_alloc_table:
    .skip 4096 * 4            # 16KB allocation table

# Shared memory bitmap
.section .shared_bitmap
.align 4096
shared_bitmap:
    .skip 4096                # Usage bitmap

# Lock table
.section .shared_locks
.align 4096
shared_locks:
    .skip 4096                # Lock table 