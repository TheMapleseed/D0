.code64
.global init_async_scheduler, schedule_async_task, yield_cpu

# Scheduler States
.set SCHED_IDLE,        0
.set SCHED_RUNNING,     1
.set SCHED_BLOCKED,     2

# Task Queue structure
.struct 0
QUEUE_HEAD:     .quad 0
QUEUE_TAIL:     .quad 0
QUEUE_COUNT:    .quad 0
QUEUE_LOCK:     .quad 0
QUEUE_SIZE:

# Initialize async scheduler
init_async_scheduler:
    # Initialize task queues
    lea     ready_queue(%rip), %rdi
    call    init_queue
    
    lea     waiting_queue(%rip), %rdi
    call    init_queue
    
    # Set up scheduler state
    lea     sched_state(%rip), %rax
    movq    $SCHED_IDLE, (%rax)
    
    # Initialize worker threads
    mov     $MAX_WORKERS, %ecx
1:
    push    %rcx
    call    create_worker_thread
    pop     %rcx
    loop    1b
    
    ret

# Schedule async task
# rdi = task pointer
schedule_async_task:
    push    %rbx
    mov     %rdi, %rbx
    
    # Add to ready queue
    lea     ready_queue(%rip), %rdi
    mov     %rbx, %rsi
    call    queue_push
    
    # Wake scheduler if idle
    lea     sched_state(%rip), %rax
    cmpq    $SCHED_IDLE, (%rax)
    jne     1f
    call    wake_scheduler
1:
    pop     %rbx
    ret

# Main scheduler loop
scheduler_loop:
    # Check ready queue
    lea     ready_queue(%rip), %rdi
    call    queue_pop
    test    %rax, %rax
    jz      check_waiting
    
    # Execute task
    mov     %rax, %rdi
    call    execute_task
    jmp     scheduler_loop

check_waiting:
    # Check waiting tasks
    lea     waiting_queue(%rip), %rdi
    call    process_waiting_tasks
    
    # If no tasks, go idle
    lea     sched_state(%rip), %rax
    movq    $SCHED_IDLE, (%rax)
    call    wait_for_tasks
    jmp     scheduler_loop

# Execute single task
# rdi = task pointer
execute_task:
    push    %rbx
    push    %r12
    
    # Disable interrupts during state change
    pushfq
    cli
    
    # Set task state with error checking
    movq    $TASK_RUNNING, TASK_STATE(%rbx)
    
    # Save task info for cleanup
    mov     %rbx, %r12
    
    # Enable interrupts before task execution
    popfq
    
    # Execute task with error handling
    mov     TASK_FUNC(%rbx), %rax
    mov     TASK_ARGS(%rbx), %rdi
    
    # Try to execute task
    call    *%rax
    test    %rax, %rax
    js      task_failed
    
    # Success path
    pushfq
    cli
    movq    $TASK_COMPLETED, TASK_STATE(%r12)
    popfq
    jmp     task_cleanup
    
task_failed:
    # Error handling path
    pushfq
    cli
    movq    $TASK_ERROR, TASK_STATE(%r12)
    call    release_task_resources
    popfq
    
task_cleanup:
    pop     %r12
    pop     %rbx
    ret

# Yield CPU to scheduler
yield_cpu:
    push    %rbx
    
    # Disable interrupts during task switch
    pushfq
    cli
    
    # Save current state
    mov     current_task, %rbx
    test    %rbx, %rbx
    jz      1f                 # No current task
    
    # Add to ready queue
    lea     ready_queue(%rip), %rdi
    mov     %rbx, %rsi
    call    enqueue_task
    
1:  # Restore interrupt state
    popfq
    
    pop     %rbx
    ret

# Data section
.section .data
sched_state:    .quad SCHED_IDLE
current_task:   .quad 0

# Queue structures
.align 8
ready_queue:    .skip QUEUE_SIZE
waiting_queue:  .skip QUEUE_SIZE

# BSS section
.section .bss
.align 4096
worker_threads:
    .skip 8 * MAX_WORKERS    # Array of worker thread pointers 

.set CPUID_FEAT_EDX_PAE,      1 << 6
.set CPUID_FEAT_AMD64,        1 << 29    # Long Mode bit in EDX
.set CPUID_FEAT_ECX_AVX,      1 << 28
.set CPUID_FEAT_ECX_AVX512F,  1 << 16