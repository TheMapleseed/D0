.code64
.global virtio_mmio_read_reg, virtio_mmio_write_reg, virtio_mmio_init_net, virtio_mmio_init_blk

# Virtio MMIO register offsets
.set VIRTIO_MMIO_MAGIC_VALUE,     0x000
.set VIRTIO_MMIO_VERSION,          0x004
.set VIRTIO_MMIO_DEVICE_ID,        0x008
.set VIRTIO_MMIO_VENDOR_ID,        0x00C
.set VIRTIO_MMIO_DEVICE_FEATURES,  0x010
.set VIRTIO_MMIO_DEVICE_FEATURES_SEL, 0x014
.set VIRTIO_MMIO_DRIVER_FEATURES,  0x020
.set VIRTIO_MMIO_DRIVER_FEATURES_SEL, 0x024
.set VIRTIO_MMIO_GUEST_PAGE_SIZE,  0x028
.set VIRTIO_MMIO_QUEUE_SEL,        0x030
.set VIRTIO_MMIO_QUEUE_NUM_MAX,    0x034
.set VIRTIO_MMIO_QUEUE_NUM,        0x038
.set VIRTIO_MMIO_QUEUE_ALIGN,      0x03C
.set VIRTIO_MMIO_QUEUE_PFN,        0x040
.set VIRTIO_MMIO_QUEUE_NOTIFY,     0x050
.set VIRTIO_MMIO_INTERRUPT_STATUS, 0x060
.set VIRTIO_MMIO_INTERRUPT_ACK,    0x064
.set VIRTIO_MMIO_STATUS,           0x070
.set VIRTIO_MMIO_CONFIG,           0x100

# Virtio device IDs
.set VIRTIO_ID_NET,                0x1000
.set VIRTIO_ID_BLOCK,              0x1001

# Virtio feature bits
.set VIRTIO_F_NOTIFY_ON_EMPTY,     (1 << 24)
.set VIRTIO_F_ANY_LAYOUT,          (1 << 27)
.set VIRTIO_F_RING_INDIRECT_DESC,  (1 << 28)
.set VIRTIO_F_RING_EVENT_IDX,      (1 << 29)
.set VIRTIO_F_VERSION_1,           (1 << 32)

# MMIO base addresses
.section .data
.align 8
virtio_net_mmio_base:
    .quad 0x40000000  # 1GB
virtio_blk_mmio_base:
    .quad 0x40001000  # 1GB + 4KB

.text
# uint32_t virtio_mmio_read_reg(uint64_t base, uint32_t offset)
virtio_mmio_read_reg:
    # %rdi = base, %rsi = offset
    add     %rdi, %rsi
    mov     (%rsi), %eax
    ret

# void virtio_mmio_write_reg(uint64_t base, uint32_t offset, uint32_t value)
virtio_mmio_write_reg:
    # %rdi = base, %rsi = offset, %rdx = value
    add     %rdi, %rsi
    mov     %edx, (%rsi)
    ret

# int virtio_mmio_init_net(void)
virtio_mmio_init_net:
    push    %rbx
    push    %rcx
    push    %rdx

    # Read magic value
    mov     $VIRTIO_MMIO_MAGIC_VALUE, %rsi
    mov     virtio_net_mmio_base(%rip), %rdi
    call    virtio_mmio_read_reg
    cmp     $0x74726976, %eax  # "virt"
    jne     1f

    # Read device ID
    mov     $VIRTIO_MMIO_DEVICE_ID, %rsi
    mov     virtio_net_mmio_base(%rip), %rdi
    call    virtio_mmio_read_reg
    cmp     $VIRTIO_ID_NET, %eax
    jne     1f

    # Write driver features
    mov     $VIRTIO_MMIO_DRIVER_FEATURES_SEL, %rsi
    mov     virtio_net_mmio_base(%rip), %rdi
    xor     %rdx, %rdx
    call    virtio_mmio_write_reg

    mov     $VIRTIO_MMIO_DRIVER_FEATURES, %rsi
    mov     virtio_net_mmio_base(%rip), %rdi
    mov     $VIRTIO_F_VERSION_1, %edx
    call    virtio_mmio_write_reg

    # Set status to ACKNOWLEDGE | DRIVER
    mov     $VIRTIO_MMIO_STATUS, %rsi
    mov     virtio_net_mmio_base(%rip), %rdi
    mov     $0x03, %edx  # ACKNOWLEDGE | DRIVER
    call    virtio_mmio_write_reg

    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# int virtio_mmio_init_blk(void)
virtio_mmio_init_blk:
    push    %rbx
    push    %rcx
    push    %rdx

    # Read magic value
    mov     $VIRTIO_MMIO_MAGIC_VALUE, %rsi
    mov     virtio_blk_mmio_base(%rip), %rdi
    call    virtio_mmio_read_reg
    cmp     $0x74726976, %eax  # "virt"
    jne     1f

    # Read device ID
    mov     $VIRTIO_MMIO_DEVICE_ID, %rsi
    mov     virtio_blk_mmio_base(%rip), %rdi
    call    virtio_mmio_read_reg
    cmp     $VIRTIO_ID_BLOCK, %eax
    jne     1f

    # Write driver features
    mov     $VIRTIO_MMIO_DRIVER_FEATURES_SEL, %rsi
    mov     virtio_blk_mmio_base(%rip), %rdi
    xor     %rdx, %rdx
    call    virtio_mmio_write_reg

    mov     $VIRTIO_MMIO_DRIVER_FEATURES, %rsi
    mov     virtio_blk_mmio_base(%rip), %rdi
    mov     $VIRTIO_F_VERSION_1, %edx
    call    virtio_mmio_write_reg

    # Set status to ACKNOWLEDGE | DRIVER
    mov     $VIRTIO_MMIO_STATUS, %rsi
    mov     virtio_blk_mmio_base(%rip), %rdi
    mov     $0x03, %edx  # ACKNOWLEDGE | DRIVER
    call    virtio_mmio_write_reg

    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rdx
    pop     %rcx
    pop     %rbx
    ret


