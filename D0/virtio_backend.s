.code64
.global virtio_init_net_backend, virtio_init_blk_backend

# Virtqueue descriptor layout offsets (portable)
.set VQ_DESC_ADDR,   0
.set VQ_DESC_LEN,    8
.set VQ_DESC_FLAGS,  12
.set VQ_DESC_NEXT,   14
.set VQ_DESC_SIZE,   16

# Feature bits to advertise (subset)
.set VIRTIO_F_VERSION_1, (1 << 32)
.set VIRTIO_F_RING_INDIRECT_DESC, (1 << 28)
.set VIRTIO_F_RING_EVENT_IDX, (1 << 29)

# Minimal virtio backend skeletons
# int virtio_init_net_backend(struct VM *vm, uint64_t netif_id)
virtio_init_net_backend:
    # TODO: set up virtqueues and mmio/ioport ranges
    mov     $1, %rax
    ret

# int virtio_init_blk_backend(struct VM *vm, uint64_t disk_id)
virtio_init_blk_backend:
    # TODO: set up virtqueues and backing storage mapping
    mov     $1, %rax
    ret
