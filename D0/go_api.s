.code64
.global init_go_api, go_syscall_handler

# Go API Constants
.set GO_SYSCALL_BASE,   0x1000
.set GO_API_VERSION,    1
.set MAX_GO_THREADS,    1024

# Go Thread Structure
.struct 0
GO_TID:         .quad 0    # Thread ID
GO_STACK:       .quad 0    # Stack pointer
GO_STATE:       .quad 0    # Thread state
GO_CONTEXT:     .quad 0    # Context pointer
GO_PHASE:       .quad 0    # Cycle phase
GO_SIZE:

# Go API Functions
.set GO_CREATE,     0x01    # Create goroutine
.set GO_CHANNEL,    0x02    # Channel operations
.set GO_SYNC,       0x03    # Synchronization
.set GO_SCHED,      0x04    # Scheduler interface
.set GO_MEM,        0x05    # Memory operations

# Initialize Go API
init_go_api:
    push    %rbx
    
    # Setup API tables
    lea     go_api_table(%rip), %rdi
    call    init_api_table
    
    # Initialize Go runtime support
    call    init_go_runtime
    
    # Setup thread management
    call    init_go_threads
    
    pop     %rbx
    ret

# Go syscall handler
go_syscall_handler:
    push    %rbx
    push    %r12
    
    # Get cycle phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Verify caller
    mov     %rbx, %rdi
    call    verify_go_caller
    test    %rax, %rax
    jz      go_syscall_error
    
    # Process syscall
    mov     %rdi, %r12    # Save syscall number
    
    # Check API version
    cmp     current_api_version, %rsi
    jne     go_api_version_error
    
    # Dispatch to handler
    lea     go_api_table(%rip), %rax
    mov     (%rax,%r12,8), %rax
    call    *%rax
    
    pop     %r12
    pop     %rbx
    ret

# Create goroutine
create_goroutine:
    push    %rbx
    
    # Get cycle phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Allocate thread structure
    mov     $GO_SIZE, %rdi
    call    allocate_go_thread
    
    # Initialize thread
    mov     %rax, %rdi
    mov     %rbx, GO_PHASE(%rdi)
    call    init_go_thread
    
    pop     %rbx
    ret

# Channel operations
handle_channel_op:
    push    %rbx
    
    # Verify phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Process channel operation
    mov     %rdi, %rsi    # Channel
    mov     %rbx, %rdi    # Phase
    call    process_channel_op
    
    pop     %rbx
    ret

# Data Section
.section .data
.align 8
go_api_table:
    .quad create_goroutine      # 0x01
    .quad handle_channel_op     # 0x02
    .quad handle_sync_op        # 0x03
    .quad handle_sched_op       # 0x04
    .quad handle_mem_op         # 0x05

current_api_version:
    .quad GO_API_VERSION

# BSS Section
.section .bss
.align 4096
go_thread_pool:
    .skip GO_SIZE * MAX_GO_THREADS 