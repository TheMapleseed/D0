.code64
.global virtio_queue_init, virtio_queue_add_buf, virtio_queue_get_buf, virtio_queue_kick

# Virtio descriptor flags
.set VRING_DESC_F_NEXT,       1
.set VRING_DESC_F_WRITE,      2
.set VRING_DESC_F_INDIRECT,   4

# Virtio available flags
.set VRING_AVAIL_F_NO_INTERRUPT, 1

# Virtio used flags
.set VRING_USED_F_NO_NOTIFY,     1

# Virtio queue state
.section .bss
.align 4096
virtio_net_queue:
    .skip 4096  # Descriptor table + available ring + used ring

virtio_blk_queue:
    .skip 4096  # Descriptor table + available ring + used ring

.section .data
.align 8
virtio_net_queue_state:
    .quad 0  # queue size
    .quad 0  # next free descriptor
    .quad 0  # last used index

virtio_blk_queue_state:
    .quad 0  # queue size
    .quad 0  # next free descriptor
    .quad 0  # last used index

.text
# int virtio_queue_init(uint64_t queue_id, uint64_t size)
virtio_queue_init:
    # %rdi = queue_id, %rsi = size
    push    %rbx
    push    %rcx
    push    %rdx

    # Validate queue size (must be power of 2)
    mov     %rsi, %rax
    dec     %rax
    test    %rax, %rsi
    jnz     1f

    # Store queue size
    cmp     $0, %rdi  # net queue
    je      init_net_queue
    cmp     $1, %rdi  # blk queue
    je      init_blk_queue
    jmp     1f

init_net_queue:
    lea     virtio_net_queue_state(%rip), %rax
    mov     %rsi, (%rax)  # queue size
    mov     $0, 8(%rax)   # next free descriptor
    mov     $0, 16(%rax)  # last used index
    jmp     2f

init_blk_queue:
    lea     virtio_blk_queue_state(%rip), %rax
    mov     %rsi, (%rax)  # queue size
    mov     $0, 8(%rax)   # next free descriptor
    mov     $0, 16(%rax)  # last used index

2:  mov     $1, %rax
    jmp     3f
1:  xor     %rax, %rax
3:  pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# int virtio_queue_add_buf(uint64_t queue_id, void *buf, uint64_t len, int write)
virtio_queue_add_buf:
    # %rdi = queue_id, %rsi = buf, %rdx = len, %rcx = write
    push    %rbx
    push    %r8
    push    %r9

    # Get queue state
    cmp     $0, %rdi  # net queue
    je      add_net_buf
    cmp     $1, %rdi  # blk queue
    je      add_blk_buf
    jmp     1f

add_net_buf:
    lea     virtio_net_queue_state(%rip), %r8
    lea     virtio_net_queue(%rip), %r9
    jmp     add_buf_common

add_blk_buf:
    lea     virtio_blk_queue_state(%rip), %r8
    lea     virtio_blk_queue(%rip), %r9

add_buf_common:
    # Get next free descriptor
    mov     8(%r8), %rax  # next free descriptor
    mov     (%r8), %rbx   # queue size
    
    # Check if queue is full
    cmp     %rbx, %rax
    jge     1f
    
    # Calculate descriptor address
    imul    $16, %rax, %r10  # descriptor size = 16 bytes
    add     %r10, %r9        # add to queue base
    
    # Fill descriptor
    mov     %rsi, (%r9)      # addr
    mov     %rdx, 8(%r9)     # len
    
    # Set flags
    mov     $0, %r11
    cmp     $0, %rcx
    je      4f
    or      $VRING_DESC_F_WRITE, %r11
4:  mov     %r11, 12(%r9)   # flags
    
    # Update next free descriptor
    inc     %rax
    mov     %rax, 8(%r8)
    
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %r9
    pop     %r8
    pop     %rbx
    ret

# int virtio_queue_get_buf(uint64_t queue_id, void **buf, uint64_t *len)
virtio_queue_get_buf:
    # %rdi = queue_id, %rsi = buf ptr, %rdx = len ptr
    push    %rbx
    push    %r8
    push    %r9

    # Get queue state
    cmp     $0, %rdi  # net queue
    je      get_net_buf
    cmp     $1, %rdi  # blk queue
    je      get_blk_buf
    jmp     1f

get_net_buf:
    lea     virtio_net_queue_state(%rip), %r8
    lea     virtio_net_queue(%rip), %r9
    jmp     get_buf_common

get_blk_buf:
    lea     virtio_blk_queue_state(%rip), %r8
    lea     virtio_blk_queue(%rip), %r9

get_buf_common:
    # Get last used index
    mov     16(%r8), %rax  # last used index
    mov     (%r8), %rbx    # queue size
    
    # Check if queue is empty
    cmp     %rbx, %rax
    jge     1f
    
    # Calculate descriptor address
    imul    $16, %rax, %r10  # descriptor size = 16 bytes
    add     %r10, %r9        # add to queue base
    
    # Get descriptor data
    mov     (%r9), %r11      # addr
    mov     8(%r9), %r12     # len
    
    # Store in output parameters
    mov     %r11, (%rsi)     # *buf = addr
    mov     %r12, (%rdx)     # *len = len
    
    # Update last used index
    inc     %rax
    mov     %rax, 16(%r8)
    
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %r9
    pop     %r8
    pop     %rbx
    ret

# void virtio_queue_kick(uint64_t queue_id)
virtio_queue_kick:
    # %rdi = queue_id
    push    %rbx
    push    %rcx
    push    %rdx

    # For now, just acknowledge the kick
    # In a full implementation, this would trigger processing
    # of the queue and potentially inject an interrupt

    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret
