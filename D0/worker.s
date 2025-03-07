.code64
.global init_worker_pool, create_worker_thread, worker_main

# Worker Thread States
.set WORKER_IDLE,       0
.set WORKER_RUNNING,    1
.set WORKER_BLOCKED,    2
.set WORKER_TERMINATED, 3
.set WORKER_TIMEOUT,    1000    # Cycles before timeout
.set WORKER_RECOVERY,   4       # Recovery state

# Worker Thread Structure
.struct 0
WORKER_ID:      .quad 0    # Unique worker ID
WORKER_STATE:   .quad 0    # Current state
WORKER_TASK:    .quad 0    # Current task pointer
WORKER_STACK:   .quad 0    # Thread stack pointer
WORKER_CPU:     .quad 0    # Preferred CPU core
WORKER_STATS:   .quad 0    # Performance statistics
WORKER_NEXT:    .quad 0    # Next worker in pool
WORKER_SIZE:

# Initialize worker pool
init_worker_pool:
    # Allocate worker pool
    mov     $WORKER_SIZE * MAX_WORKERS, %rdi
    call    allocate_pages
    mov     %rax, worker_pool
    
    # Initialize each worker
    mov     $0, %rbx        # Worker ID counter
1:
    cmp     $MAX_WORKERS, %rbx
    jae     2f
    
    # Initialize worker structure
    mov     worker_pool, %rdi
    mov     %rbx, %rsi
    call    init_worker
    
    inc     %rbx
    jmp     1b
2:
    ret

# Initialize single worker
# rdi = worker structure, rsi = worker ID
init_worker:
    push    %rbx
    mov     %rdi, %rbx
    
    # Set worker ID
    mov     %rsi, WORKER_ID(%rbx)
    
    # Allocate worker stack
    mov     $WORKER_STACK_SIZE, %rdi
    call    allocate_pages
    mov     %rax, WORKER_STACK(%rbx)
    
    # Initialize state
    movq    $WORKER_IDLE, WORKER_STATE(%rbx)
    
    # Set preferred CPU (round-robin)
    mov     WORKER_ID(%rbx), %rax
    xor     %rdx, %rdx
    mov     $CPU_COUNT, %rcx
    div     %rcx
    mov     %rdx, WORKER_CPU(%rbx)
    
    pop     %rbx
    ret

# Worker main loop
worker_main:
    # Get worker structure
    mov     %rdi, %rbx
    
    # Set initial state
    movq    $WORKER_IDLE, WORKER_STATE(%rbx)
    
    # Bind to preferred CPU
    mov     WORKER_CPU(%rbx), %rdi
    call    set_cpu_affinity

worker_loop:
    # Try to get task
    call    get_next_task
    test    %rax, %rax
    jz      worker_wait     # No task available
    
    # Execute task
    mov     %rax, WORKER_TASK(%rbx)
    movq    $WORKER_RUNNING, WORKER_STATE(%rbx)
    
    # Update statistics
    lea     WORKER_STATS(%rbx), %rdi
    call    update_worker_stats
    
    # Execute task
    mov     WORKER_TASK(%rbx), %rdi
    call    execute_task
    
    # Clear task and go idle
    movq    $0, WORKER_TASK(%rbx)
    movq    $WORKER_IDLE, WORKER_STATE(%rbx)
    jmp     worker_loop

worker_wait:
    # Enter idle state
    movq    $WORKER_IDLE, WORKER_STATE(%rbx)
    
    # Wait for work notification
    call    wait_for_work
    jmp     worker_loop

# Worker performance monitoring
update_worker_stats:
    push    %rbx
    mov     %rdi, %rbx
    
    # Update task count
    incq    (%rbx)
    
    # Update CPU time
    rdtsc
    shl     $32, %rdx
    or      %rax, %rdx
    mov     %rdx, 8(%rbx)
    
    pop     %rbx
    ret

# Data section
.section .data
worker_pool:    .quad 0
active_workers: .quad 0

# Statistics
.section .data
.align 8
worker_stats:
    .skip 64 * MAX_WORKERS  # 64 bytes of stats per worker 

monitor_worker_pool:
    push    %rbx
    push    %r12
    
    # Check for blocked workers
    mov     active_workers(%rip), %r12
    test    %r12, %r12
    jz      pool_empty
    
    # Scan workers
    lea     worker_pool(%rip), %rbx
1:
    # Check if worker is blocked too long
    mov     WORKER_STATE(%rbx), %rax
    cmp     $WORKER_BLOCKED, %rax
    jne     2f
    
    # Check timeout
    call    check_worker_timeout
    test    %rax, %rax
    jz      2f
    
    # Recover blocked worker
    mov     %rbx, %rdi
    call    recover_worker
    
2:  # Next worker
    add     $WORKER_SIZE, %rbx
    dec     %r12
    jnz     1b
    
    pop     %r12
    pop     %rbx
    ret

recover_worker:
    # Force worker back to IDLE state
    pushfq
    cli
    movq    $WORKER_IDLE, WORKER_STATE(%rdi)
    movq    $0, WORKER_TASK(%rdi)
    popfq
    ret