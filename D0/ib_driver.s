.code64
.global register_ib_driver, init_ib_subsystem, ib_probe_devices
.global ib_init_device, ib_cleanup_device, ib_open, ib_close
.global ib_post_send, ib_post_recv, ib_poll_cq, ib_create_qp

# External dependencies
.extern init_network_subsystem, register_network_driver
.extern alloc_netbuf, free_netbuf, process_incoming_packet

# InfiniBand constants
.set IB_GID_SIZE,          16      # GID size in bytes
.set IB_GUID_SIZE,         8       # GUID size in bytes
.set IB_LID_UNICAST_START, 0x001   # Starting unicast LID
.set IB_LID_MULTICAST,     0xC000  # Starting multicast LID
.set IB_QP_MIN_SIZE,       64      # Minimum QP size
.set IB_QP_MAX_SIZE,       8192    # Maximum QP size
.set IB_MAX_SGE,           32      # Maximum scatter-gather entries
.set IB_MAX_WR,            4096    # Maximum outstanding work requests
.set IB_MAX_CQ_ENTRIES,    16384   # Maximum CQ entries
.set IB_MTU_256,           1       # 256 bytes MTU
.set IB_MTU_512,           2       # 512 bytes MTU
.set IB_MTU_1024,          3       # 1024 bytes MTU
.set IB_MTU_2048,          4       # 2048 bytes MTU
.set IB_MTU_4096,          5       # 4096 bytes MTU

# InfiniBand speeds
.set IB_SPEED_SDR,         0x01    # 10 Gbps (4X)
.set IB_SPEED_DDR,         0x02    # 20 Gbps (4X)
.set IB_SPEED_QDR,         0x04    # 40 Gbps (4X)
.set IB_SPEED_FDR10,       0x08    # 40 Gbps (4X)
.set IB_SPEED_FDR,         0x10    # 56 Gbps (4X)
.set IB_SPEED_EDR,         0x20    # 100 Gbps (4X)
.set IB_SPEED_HDR,         0x40    # 200 Gbps (4X)
.set IB_SPEED_NDR,         0x80    # 400 Gbps (4X)
.set IB_SPEED_XDR,         0x100   # 800 Gbps (4X)
.set IB_SPEED_GDR,         0x200   # 1600 Gbps (4X)

# QP types
.set IB_QPT_RC,            0       # Reliable Connection
.set IB_QPT_UC,            1       # Unreliable Connection
.set IB_QPT_UD,            2       # Unreliable Datagram
.set IB_QPT_RAW_IPV6,      3       # Raw IPv6
.set IB_QPT_RAW_ETHERTYPE, 4       # Raw Ethertype
.set IB_QPT_XRC_INI,       5       # XRC Initiator
.set IB_QPT_XRC_TGT,       6       # XRC Target

# QP states
.set IB_QPS_RESET,         0       # Reset
.set IB_QPS_INIT,          1       # Init
.set IB_QPS_RTR,           2       # Ready to Receive
.set IB_QPS_RTS,           3       # Ready to Send
.set IB_QPS_SQD,           4       # Send Queue Drain
.set IB_QPS_SQE,           5       # Send Queue Error
.set IB_QPS_ERR,           6       # Error

# Work request opcodes
.set IB_WR_RDMA_WRITE,     0       # RDMA Write
.set IB_WR_RDMA_WRITE_IMM, 1       # RDMA Write with immediate data
.set IB_WR_SEND,           2       # Send
.set IB_WR_SEND_IMM,       3       # Send with immediate data
.set IB_WR_RDMA_READ,      4       # RDMA Read
.set IB_WR_ATOMIC_CMP_AND_SWP, 5   # Atomic compare and swap
.set IB_WR_ATOMIC_FETCH_AND_ADD, 6 # Atomic fetch and add
.set IB_WR_LOCAL_INV,      7       # Local invalidate
.set IB_WR_BIND_MW,        8       # Bind memory window
.set IB_WR_REG_MR,         9       # Register memory region
.set IB_WR_SEND_WITH_INV,  10      # Send with invalidate

# InfiniBand device structure
.struct 0
IB_DEV_ID:               .quad 0    # Device ID
IB_DEV_PCI_INFO:         .quad 0    # PCI device information
IB_DEV_NODE_TYPE:        .quad 0    # Node type
IB_DEV_NODE_GUID:        .skip 8    # Node GUID
IB_DEV_PORT_GUID:        .skip 8    # Port GUID
IB_DEV_SYS_GUID:         .skip 8    # System image GUID
IB_DEV_GID:              .skip 16   # GID
IB_DEV_LID:              .quad 0    # LID
IB_DEV_NUM_PORTS:        .quad 0    # Number of ports
IB_DEV_PORT_STATE:       .quad 0    # Port state
IB_DEV_PORT_SPEED:       .quad 0    # Port speed
IB_DEV_PORT_WIDTH:       .quad 0    # Port width
IB_DEV_VENDOR_ID:        .quad 0    # Vendor ID
IB_DEV_VENDOR_PART_ID:   .quad 0    # Vendor part ID
IB_DEV_HW_VERSION:       .quad 0    # Hardware version
IB_DEV_FW_VERSION:       .quad 0    # Firmware version
IB_DEV_MAX_QP:           .quad 0    # Maximum QPs
IB_DEV_MAX_CQ:           .quad 0    # Maximum CQs
IB_DEV_MAX_MR:           .quad 0    # Maximum MRs
IB_DEV_MAX_PD:           .quad 0    # Maximum PDs
IB_DEV_MAX_QP_WR:        .quad 0    # Maximum work requests per QP
IB_DEV_MAX_SGE:          .quad 0    # Maximum SGEs per WR
IB_DEV_MAX_CQE:          .quad 0    # Maximum CQ entries
IB_DEV_MMIO_BASE:        .quad 0    # MMIO base address
IB_DEV_MMIO_SIZE:        .quad 0    # MMIO size
IB_DEV_PRIV:             .quad 0    # Private data pointer
IB_DEV_SIZE:

# Queue Pair structure
.struct 0
IB_QP_ID:                .quad 0    # QP ID
IB_QP_TYPE:              .quad 0    # QP type
IB_QP_STATE:             .quad 0    # QP state
IB_QP_SEND_CQ:           .quad 0    # Send CQ
IB_QP_RECV_CQ:           .quad 0    # Receive CQ
IB_QP_PD:                .quad 0    # Protection domain
IB_QP_MAX_SEND_WR:       .quad 0    # Maximum send WRs
IB_QP_MAX_RECV_WR:       .quad 0    # Maximum receive WRs
IB_QP_MAX_SEND_SGE:      .quad 0    # Maximum send SGEs
IB_QP_MAX_RECV_SGE:      .quad 0    # Maximum receive SGEs
IB_QP_DEST_QP_NUM:       .quad 0    # Destination QP number
IB_QP_DEST_LID:          .quad 0    # Destination LID
IB_QP_DEST_GID:          .skip 16   # Destination GID
IB_QP_SL:                .quad 0    # Service level
IB_QP_PRIV:              .quad 0    # Private data pointer
IB_QP_SIZE:

# Completion Queue structure
.struct 0
IB_CQ_ID:                .quad 0    # CQ ID
IB_CQ_SIZE:              .quad 0    # CQ size
IB_CQ_ENTRIES:           .quad 0    # CQ entries
IB_CQ_NOTIFY:            .quad 0    # CQ notification
IB_CQ_PRIV:              .quad 0    # Private data pointer
IB_CQ_SIZE:

# Work Request structure
.struct 0
IB_WR_ID:                .quad 0    # Work request ID
IB_WR_OPCODE:            .quad 0    # Work request opcode
IB_WR_FLAGS:             .quad 0    # Work request flags
IB_WR_NUM_SGE:           .quad 0    # Number of scatter-gather entries
IB_WR_SGE_LIST:          .quad 0    # Pointer to scatter-gather list
IB_WR_NEXT:              .quad 0    # Next work request
IB_WR_SIZE:

# Memory Region structure
.struct 0
IB_MR_ID:                .quad 0    # Memory region ID
IB_MR_ADDR:              .quad 0    # Start address
IB_MR_LENGTH:            .quad 0    # Length
IB_MR_PD:                .quad 0    # Protection domain
IB_MR_ACCESS:            .quad 0    # Access flags
IB_MR_LKEY:              .quad 0    # Local key
IB_MR_RKEY:              .quad 0    # Remote key
IB_MR_SIZE:

#
# Initialize InfiniBand subsystem
#
init_ib_subsystem:
    # Save registers
    push    %rbx
    push    %r12
    
    # Initialize network subsystem if not done already
    call    check_net_initialized
    test    %rax, %rax
    jnz     .net_already_init
    
    call    init_network_subsystem
    test    %rax, %rax
    jz      .ib_init_failed
    
.net_already_init:
    # Register base InfiniBand driver
    call    register_ib_driver
    test    %rax, %rax
    jz      .ib_init_failed
    
    # Probe for InfiniBand devices
    call    ib_probe_devices
    
    # Always return success, even if no devices are found
    # The absence of devices is not a critical error
    mov     $1, %rax
    jmp     .ib_init_done
    
.ib_init_failed:
    xor     %rax, %rax
    
.ib_init_done:
    pop     %r12
    pop     %rbx
    ret

#
# Register InfiniBand driver
#
register_ib_driver:
    # Save registers
    push    %rbx
    
    # Allocate driver descriptor
    mov     $NDRV_SIZE, %rdi
    call    allocate_memory
    test    %rax, %rax
    jz      .reg_ib_failed
    
    # Save descriptor pointer
    mov     %rax, %rbx
    
    # Initialize driver descriptor
    movq    $0, NDRV_ID(%rbx)                     # Will be assigned on registration
    movq    $NET_DEV_INFINIBAND, NDRV_TYPE(%rbx)  # InfiniBand type
    
    # Set driver name
    lea     ib_driver_name(%rip), %rsi
    lea     NDRV_NAME(%rbx), %rdi
    call    copy_string
    
    # Set driver version
    movq    $0x00010000, NDRV_VERSION(%rbx)       # Version 1.0.0.0
    
    # Set function pointers
    lea     ib_init_device(%rip), %rax
    movq    %rax, NDRV_INIT(%rbx)
    
    lea     ib_cleanup_device(%rip), %rax
    movq    %rax, NDRV_CLEANUP(%rbx)
    
    lea     ib_probe_devices(%rip), %rax
    movq    %rax, NDRV_PROBE(%rbx)
    
    lea     ib_open(%rip), %rax
    movq    %rax, NDRV_OPEN(%rbx)
    
    lea     ib_close(%rip), %rax
    movq    %rax, NDRV_CLOSE(%rbx)
    
    # Register driver
    mov     %rbx, %rdi
    call    register_network_driver
    test    %rax, %rax
    jz      .reg_ib_failed
    
    # Store driver ID
    movq    %rax, ib_driver_id(%rip)
    
    # Return success
    mov     $1, %rax
    jmp     .reg_ib_done
    
.reg_ib_failed:
    # Free driver descriptor if allocated
    test    %rbx, %rbx
    jz      1f
    mov     %rbx, %rdi
    call    free_memory
1:
    xor     %rax, %rax
    
.reg_ib_done:
    pop     %rbx
    ret

#
# Probe for InfiniBand devices
#
ib_probe_devices:
    # Save registers
    push    %rbx
    push    %r12
    push    %r13
    
    # Count of found devices
    xor     %r12, %r12
    
    # Scan PCI bus for InfiniBand devices - starting with Mellanox
    mov     $PCI_VENDOR_MELLANOX, %rdi
    call    scan_pci_for_vendor
    add     %rax, %r12
    
    # Return number of devices found
    mov     %r12, %rax
    
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

#
# Initialize an InfiniBand device
#
ib_init_device:
    # Device descriptor in %rdi
    push    %rbx
    push    %r12
    push    %r13
    
    # Save parameter
    mov     %rdi, %rbx
    
    # Map device memory
    mov     %rbx, %rdi
    call    ib_map_device_memory
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Reset device
    mov     %rbx, %rdi
    call    ib_reset_device
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Initialize device registers
    mov     %rbx, %rdi
    call    ib_init_registers
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Read device capabilities
    mov     %rbx, %rdi
    call    ib_read_capabilities
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Create management objects
    mov     %rbx, %rdi
    call    ib_create_mgmt_objects
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Initialize ports
    mov     %rbx, %rdi
    call    ib_init_ports
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Create protection domain
    mov     %rbx, %rdi
    call    ib_create_pd
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Setup event handling
    mov     %rbx, %rdi
    call    ib_setup_events
    test    %rax, %rax
    jz      .init_ib_failed
    
    # Device is ready
    mov     $1, %rax
    jmp     .init_ib_done
    
.init_ib_failed:
    xor     %rax, %rax
    
.init_ib_done:
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

#
# Create a Queue Pair
#
ib_create_qp:
    # QP parameters in %rdi
    push    %rbx
    push    %r12
    
    # Save QP parameters
    mov     %rdi, %rbx
    
    # Allocate QP structure
    mov     $IB_QP_SIZE, %rdi
    call    allocate_memory
    test    %rax, %rax
    jz      .create_qp_failed
    
    # Save QP pointer
    mov     %rax, %r12
    
    # Copy QP parameters
    mov     %rbx, %rsi
    mov     %r12, %rdi
    mov     $IB_QP_SIZE, %rdx
    call    secure_memcpy
    
    # Create completion queues if needed
    movq    IB_QP_SEND_CQ(%r12), %rax
    test    %rax, %rax
    jnz     .send_cq_exists
    
    # Create send completion queue
    mov     %r12, %rdi
    call    ib_create_send_cq
    test    %rax, %rax
    jz      .create_qp_failed
    
    # Store send CQ
    movq    %rax, IB_QP_SEND_CQ(%r12)
    
.send_cq_exists:
    movq    IB_QP_RECV_CQ(%r12), %rax
    test    %rax, %rax
    jnz     .recv_cq_exists
    
    # Create receive completion queue
    mov     %r12, %rdi
    call    ib_create_recv_cq
    test    %rax, %rax
    jz      .create_qp_failed
    
    # Store receive CQ
    movq    %rax, IB_QP_RECV_CQ(%r12)
    
.recv_cq_exists:
    # Allocate QP hardware resources
    mov     %r12, %rdi
    call    ib_alloc_qp_resources
    test    %rax, %rax
    jz      .create_qp_failed
    
    # Initialize QP to INIT state
    mov     %r12, %rdi
    call    ib_qp_init
    test    %rax, %rax
    jz      .create_qp_failed
    
    # Return QP pointer
    mov     %r12, %rax
    jmp     .create_qp_done
    
.create_qp_failed:
    # Cleanup resources if QP creation failed
    test    %r12, %r12
    jz      1f
    
    # Free QP resources
    mov     %r12, %rdi
    call    ib_free_qp_resources
    
    # Free QP structure
    mov     %r12, %rdi
    call    free_memory
    
1:
    xor     %rax, %rax
    
.create_qp_done:
    pop     %r12
    pop     %rbx
    ret

#
# Post a work request to the send queue
#
ib_post_send:
    # QP in %rdi, work request in %rsi
    push    %rbx
    push    %r12
    
    # Save parameters
    mov     %rdi, %rbx    # QP
    mov     %rsi, %r12    # Work request
    
    # Check if QP is in valid state for sending
    movq    IB_QP_STATE(%rbx), %rax
    cmp     $IB_QPS_RTS, %rax
    jne     .post_send_failed
    
    # Post the work request to the hardware queue
    mov     %rbx, %rdi
    mov     %r12, %rsi
    call    ib_post_send_hw
    test    %rax, %rax
    jz      .post_send_failed
    
    # Return success
    mov     $1, %rax
    jmp     .post_send_done
    
.post_send_failed:
    xor     %rax, %rax
    
.post_send_done:
    pop     %r12
    pop     %rbx
    ret

#
# Poll a completion queue
#
ib_poll_cq:
    # CQ in %rdi, work completions array in %rsi, max entries in %rdx
    push    %rbx
    push    %r12
    push    %r13
    
    # Save parameters
    mov     %rdi, %rbx    # CQ
    mov     %rsi, %r12    # Work completions array
    mov     %rdx, %r13    # Max entries
    
    # Poll the completion queue
    mov     %rbx, %rdi
    mov     %r12, %rsi
    mov     %r13, %rdx
    call    ib_poll_cq_hw
    
    # Return number of completions (or error)
    
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

# Helper function stubs (to be implemented)
check_net_initialized:
    ret
allocate_memory:
    ret
free_memory:
    ret
copy_string:
    ret
scan_pci_for_vendor:
    ret
ib_map_device_memory:
    ret
ib_reset_device:
    ret
ib_init_registers:
    ret
ib_read_capabilities:
    ret
ib_create_mgmt_objects:
    ret
ib_init_ports:
    ret
ib_create_pd:
    ret
ib_setup_events:
    ret
secure_memcpy:
    ret
ib_create_send_cq:
    ret
ib_create_recv_cq:
    ret
ib_alloc_qp_resources:
    ret
ib_qp_init:
    ret
ib_free_qp_resources:
    ret
ib_post_send_hw:
    ret
ib_poll_cq_hw:
    ret

# Data section
.section .data
.align 8
ib_driver_id:
    .quad 0               # InfiniBand driver ID

# Strings
ib_driver_name:
    .asciz "D0-InfiniBand"   # Driver name 