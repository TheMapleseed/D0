.code64
.global init_work_stealing, set_cpu_affinity, scale_worker_pool

# Work Stealing Constants
.set STEAL_ATTEMPTS,    3
.set STEAL_THRESHOLD,   5
.set MAX_POOL_SIZE,     1024

# CPU Topology Structure
.struct 0
CPU_ID:         .quad 0
CPU_SOCKET:     .quad 0
CPU_CORE:       .quad 0
CPU_THREAD:     .quad 0
CPU_CACHE:      .quad 0
CPU_LOAD:       .quad 0
CPU_SIZE:

# Work stealing implementation
attempt_steal:
    push    %rbx
    push    %r12
    
    # Get current worker
    mov     %rdi, %rbx
    
    # Try stealing from other workers
    mov     $STEAL_ATTEMPTS, %r12d
1:
    # Find busy worker
    call    find_busy_worker
    test    %rax, %rax
    jz      steal_failed
    
    # Try to steal task
    mov     %rax, %rdi
    call    steal_task
    test    %rax, %rax
    jnz     steal_success
    
    dec     %r12d
    jnz     1b

steal_failed:
    xor     %rax, %rax
    jmp     steal_exit

steal_success:
    # Update stealing statistics
    lea     steal_stats(%rip), %rdi
    lock incq (%rdi)

steal_exit:
    pop     %r12
    pop     %rbx
    ret

# CPU Affinity Management
set_cpu_affinity:
    push    %rbx
    mov     %rdi, %rbx
    
    # Get CPU topology
    call    get_cpu_topology
    
    # Calculate optimal CPU
    mov     %rax, %rdi
    call    calculate_optimal_cpu
    
    # Set affinity mask
    mov     %rax, %rdi
    call    set_thread_affinity
    
    pop     %rbx
    ret

# Dynamic Pool Scaling
scale_worker_pool:
    push    %rbx
    push    %r12
    push    %r13
    
    # Get current load metrics
    call    get_system_load
    mov     %rax, %r12
    
    # Calculate optimal pool size
    mov     %r12, %rdi
    call    calculate_pool_size
    mov     %rax, %r13
    
    # Adjust pool
    cmp     active_workers, %r13
    je      scale_exit
    ja      grow_pool
    jmp     shrink_pool

grow_pool:
    # Add workers
    mov     %r13, %rdi
    sub     active_workers, %rdi
    call    add_workers
    jmp     scale_exit

shrink_pool:
    # Remove workers
    mov     active_workers, %rdi
    sub     %r13, %rdi
    call    remove_workers

scale_exit:
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

# Performance Metrics
.struct 0
PERF_TASKS_COMPLETE:    .quad 0
PERF_TASKS_STOLEN:      .quad 0
PERF_CPU_TIME:         .quad 0
PERF_CACHE_MISSES:     .quad 0
PERF_CONTEXT_SWITCHES: .quad 0
PERF_SIZE:

# Update performance metrics
update_metrics:
    push    %rbx
    mov     %rdi, %rbx    # Worker pointer
    
    # Read hardware counters
    mov     $0x412E, %ecx    # CPU cycles
    rdpmc
    shl     $32, %rdx
    or      %rax, %rdx
    mov     %rdx, PERF_CPU_TIME(%rbx)
    
    # Cache misses
    mov     $0x412E, %ecx
    rdpmc
    shl     $32, %rdx
    or      %rax, %rdx
    mov     %rdx, PERF_CACHE_MISSES(%rbx)
    
    pop     %rbx
    ret

# Work Queue Management
.struct 0
QUEUE_HEAD:     .quad 0
QUEUE_TAIL:     .quad 0
QUEUE_SIZE:     .quad 0
QUEUE_LOCK:     .quad 0
QUEUE_STRUCT_SIZE:

# Initialize work queue
init_work_queue:
    push    %rbx
    mov     %rdi, %rbx
    
    # Clear queue structure
    mov     $QUEUE_STRUCT_SIZE, %rcx
    xor     %rax, %rax
    rep stosb
    
    # Initialize lock
    lea     QUEUE_LOCK(%rbx), %rdi
    call    init_spinlock
    
    pop     %rbx
    ret

# Data Section
.section .data
.align 8
cpu_topology:   .skip CPU_SIZE * 256    # Support up to 256 CPUs
steal_stats:    .quad 0
worker_metrics: .skip PERF_SIZE * MAX_POOL_SIZE

# BSS Section
.section .bss
.align 4096
work_queues:    .skip QUEUE_STRUCT_SIZE * MAX_POOL_SIZE 