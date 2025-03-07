.code64
.global init_ipc, send_message, receive_message

# Message structure
.struct 0
MSG_FROM:    .quad 0
MSG_TO:      .quad 0
MSG_TYPE:    .quad 0
MSG_DATA:    .skip 1024
MSG_SIZE:

# Initialize IPC
init_ipc:
    lea     msg_queue(%rip), %rax
    movq    $0, (%rax)           # Empty queue
    ret

# Send message
# rdi = to_pid, rsi = msg_type, rdx = data, rcx = size
send_message:
    push    %rbx
    push    %rcx

    # Allocate message buffer
    mov     $MSG_SIZE, %rdi
    call    allocate_pages
    test    %rax, %rax
    jz      send_fail

    # Fill message structure
    mov     %rax, %rbx
    lea     current_process(%rip), %rax
    mov     (%rax), %rax
    mov     PCB_PID(%rax), %rax
    mov     %rax, MSG_FROM(%rbx)
    
    # Add to queue
    call    add_to_msg_queue

    pop     %rcx
    pop     %rbx
    ret

send_fail:
    mov     $-1, %rax
    pop     %rcx
    pop     %rbx
    ret

# Message queue
.section .data
msg_queue:   .quad 0 