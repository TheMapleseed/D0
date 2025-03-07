.code64
.global _vm_start, vm_init_transport, vm_shutdown_transport
.global vm_tcp_connect, vm_tcp_listen, vm_tcp_accept, vm_tcp_close
.global vm_udp_bind, vm_udp_sendto, vm_udp_recvfrom
.global vm_ip_config, vm_get_stats, vm_route_add

# Transport layer constants
.set VM_TRANSPORT_VERSION,   0x00010000    # Version 1.0.0
.set VM_MAX_CONNECTIONS,     4096          # Maximum TCP connections
.set VM_MAX_SOCKETS,         8192          # Maximum sockets
.set VM_DEFAULT_TTL,         64            # Default TTL for IP packets
.set VM_TCP_WINDOW_SIZE,     65536         # Default TCP window size
.set VM_MAX_BACKLOG,         128           # Default listen backlog
.set VM_SHARED_MEM_BASE,     0x40000000    # Base address for shared memory in VM
.set VM_MTU,                 16384         # Maximum transmission unit for VM

# Protocol numbers
.set IPPROTO_IP,             0
.set IPPROTO_ICMP,           1
.set IPPROTO_TCP,            6
.set IPPROTO_UDP,            17
.set IPPROTO_IPV6,           41
.set IPPROTO_ROUTING,        43
.set IPPROTO_FRAGMENT,       44
.set IPPROTO_ICMPV6,         58
.set IPPROTO_NONE,           59
.set IPPROTO_DSTOPTS,        60
.set IPPROTO_SCTP,           132
.set IPPROTO_RAW,            255

# Socket types
.set SOCK_STREAM,            1             # TCP socket
.set SOCK_DGRAM,             2             # UDP socket
.set SOCK_RAW,               3             # Raw socket
.set SOCK_SEQPACKET,         5             # SCTP socket

# Socket states
.set TCP_CLOSED,             0
.set TCP_LISTEN,             1
.set TCP_SYN_SENT,           2
.set TCP_SYN_RECEIVED,       3
.set TCP_ESTABLISHED,        4
.set TCP_FIN_WAIT_1,         5
.set TCP_FIN_WAIT_2,         6
.set TCP_CLOSE_WAIT,         7
.set TCP_CLOSING,            8
.set TCP_LAST_ACK,           9
.set TCP_TIME_WAIT,          10

# Socket options
.set SO_REUSEADDR,           0x0004
.set SO_KEEPALIVE,           0x0008
.set SO_BROADCAST,           0x0020
.set SO_LINGER,              0x0080
.set SO_OOBINLINE,           0x0100
.set SO_SNDBUF,              0x1001
.set SO_RCVBUF,              0x1002
.set SO_SNDTIMEO,            0x1005
.set SO_RCVTIMEO,            0x1006
.set TCP_NODELAY,            0x2001

# Shared memory layout
.struct VM_SHARED_MEM_BASE
SHM_MAGIC:                .quad 0          # Magic number for verification
SHM_VERSION:              .quad 0          # Version of shared memory format
SHM_TX_RING_ADDR:         .quad 0          # TX ring address
SHM_RX_RING_ADDR:         .quad 0          # RX ring address
SHM_TX_RING_SIZE:         .quad 0          # TX ring size
SHM_RX_RING_SIZE:         .quad 0          # RX ring size
SHM_TX_PROD_IDX:          .quad 0          # TX producer index
SHM_TX_CONS_IDX:          .quad 0          # TX consumer index
SHM_RX_PROD_IDX:          .quad 0          # RX producer index
SHM_RX_CONS_IDX:          .quad 0          # RX consumer index
SHM_FLAGS:                .quad 0          # Flags
SHM_NOTIFY_METHOD:        .quad 0          # Notification method
SHM_HOST_FEATURES:        .quad 0          # Host supported features
SHM_VM_FEATURES:          .quad 0          # VM supported features
SHM_HEADER_SIZE:

# Socket structure
.struct 0
SOCK_ID:                  .quad 0          # Socket ID
SOCK_TYPE:                .quad 0          # Socket type
SOCK_PROTOCOL:            .quad 0          # Protocol
SOCK_STATE:               .quad 0          # Socket state
SOCK_LOCAL_ADDR:          .quad 0          # Local address
SOCK_LOCAL_PORT:          .quad 0          # Local port
SOCK_REMOTE_ADDR:         .quad 0          # Remote address
SOCK_REMOTE_PORT:         .quad 0          # Remote port
SOCK_OPTIONS:             .quad 0          # Socket options
SOCK_RCVBUF:              .quad 0          # Receive buffer size
SOCK_SNDBUF:              .quad 0          # Send buffer size
SOCK_BACKLOG:             .quad 0          # Listen backlog
SOCK_ACCEPT_QUEUE:        .quad 0          # Accept queue
SOCK_ACCEPT_COUNT:        .quad 0          # Number of connections in accept queue
SOCK_OWNER:               .quad 0          # Owner process ID
SOCK_ERROR:               .quad 0          # Last error
SOCK_FLAGS:               .quad 0          # Flags
SOCK_TIMEOUT:             .quad 0          # Timeout
SOCK_NEXT:                .quad 0          # Next socket in list
SOCK_PRIV:                .quad 0          # Private data
SOCK_SIZE:

# TCP control block structure
.struct 0
TCB_SOCK_ID:              .quad 0          # Associated socket ID
TCB_STATE:                .quad 0          # TCP state
TCB_SEQ_NUM:              .quad 0          # Sequence number
TCB_ACK_NUM:              .quad 0          # Acknowledge number
TCB_WINDOW:               .quad 0          # Window size
TCB_CWND:                 .quad 0          # Congestion window
TCB_SSTHRESH:             .quad 0          # Slow start threshold
TCB_RTT:                  .quad 0          # Round trip time
TCB_RTO:                  .quad 0          # Retransmission timeout
TCB_MSS:                  .quad 0          # Maximum segment size
TCB_SEND_BUFFER:          .quad 0          # Send buffer
TCB_RECV_BUFFER:          .quad 0          # Receive buffer
TCB_SEND_BUF_SIZE:        .quad 0          # Send buffer size
TCB_RECV_BUF_SIZE:        .quad 0          # Receive buffer size
TCB_SEND_NEXT:            .quad 0          # Next byte to send
TCB_SEND_UNACK:           .quad 0          # First unacknowledged byte
TCB_RECV_NEXT:            .quad 0          # Next byte expected
TCB_RECV_WINDOW:          .quad 0          # Receive window
TCB_TIMER:                .quad 0          # Retransmission timer
TCB_SIZE:

#
# VM entry point
#
_vm_start:
    # Save registers
    push    %rbx
    push    %r12
    
    # Initialize transport layer
    call    vm_init_transport
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Set up shared memory mapping
    call    setup_shared_memory
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Initialize packet handling
    call    init_packet_handling
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Initialize socket subsystem
    call    init_socket_subsystem
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Initialize TCP subsystem
    call    init_tcp_subsystem
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Initialize UDP subsystem
    call    init_udp_subsystem
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Initialize routing and ARP tables
    call    init_routing_and_arp
    test    %rax, %rax
    jz      .vm_start_failed
    
    # Set up main packet loop
    call    vm_main_loop
    
    # Shouldn't return normally
    call    vm_shutdown_transport
    
.vm_start_failed:
    # Error handling
    call    vm_transport_error
    
    # Return to VM exit
    pop     %r12
    pop     %rbx
    ret

#
# Initialize transport layer
#
vm_init_transport:
    # Save registers
    push    %rbx
    
    # Check for shared memory interface
    mov     $VM_SHARED_MEM_BASE, %rdi
    call    validate_shared_memory
    test    %rax, %rax
    jz      .transport_init_failed
    
    # Allocate transport control structures
    call    allocate_transport_structures
    test    %rax, %rax
    jz      .transport_init_failed
    
    # Initialize memory allocator for transport layer
    call    init_transport_allocator
    test    %rax, %rax
    jz      .transport_init_failed
    
    # Initialize protocol handlers
    call    init_protocol_handlers
    test    %rax, %rax
    jz      .transport_init_failed
    
    # Register with shared memory
    mov     $VM_SHARED_MEM_BASE, %rdi
    call    register_with_shared_memory
    test    %rax, %rax
    jz      .transport_init_failed
    
    # Success
    mov     $1, %rax
    jmp     .transport_init_done
    
.transport_init_failed:
    xor     %rax, %rax
    
.transport_init_done:
    pop     %rbx
    ret

#
# Main processing loop
#
vm_main_loop:
    # Save registers
    push    %rbx
    push    %r12
    push    %r13
    
    # Set up loop
.process_loop:
    # Poll for incoming packets
    call    poll_rx_ring
    mov     %rax, %rbx    # Save number of packets
    
    # Process any received packets
    test    %rbx, %rbx
    jz      .process_tx
    
    # Process all received packets
    mov     %rbx, %rdi
    call    process_rx_packets
    
.process_tx:
    # Check if there are outgoing packets
    call    check_tx_queues
    test    %rax, %rax
    jz      .process_timers
    
    # Process outgoing packets
    call    process_tx_queues
    
.process_timers:
    # Process TCP timers
    call    process_tcp_timers
    
    # Check if we need to exit
    call    check_exit_condition
    test    %rax, %rax
    jnz     .exit_loop
    
    # Brief pause to avoid 100% CPU
    mov     $1000, %rdi    # 1000 microseconds = 1ms
    call    vm_usleep
    
    # Continue loop
    jmp     .process_loop
    
.exit_loop:
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

#
# TCP connection establishment
#
vm_tcp_connect:
    # Socket ID in %rdi, address in %rsi, port in %rdx
    push    %rbx
    push    %r12
    push    %r13
    
    # Save parameters
    mov     %rdi, %rbx    # Socket ID
    mov     %rsi, %r12    # Address
    mov     %rdx, %r13    # Port
    
    # Find socket
    mov     %rbx, %rdi
    call    find_socket_by_id
    test    %rax, %rax
    jz      .connect_failed
    
    # Save socket pointer
    mov     %rax, %rbx
    
    # Check if socket is valid for connection
    movq    SOCK_TYPE(%rbx), %rax
    cmp     $SOCK_STREAM, %rax
    jne     .connect_failed
    
    movq    SOCK_STATE(%rbx), %rax
    cmp     $TCP_CLOSED, %rax
    jne     .connect_failed
    
    # Set remote address and port
    movq    %r12, SOCK_REMOTE_ADDR(%rbx)
    movq    %r13, SOCK_REMOTE_PORT(%rbx)
    
    # Allocate TCP control block
    mov     %rbx, %rdi
    call    allocate_tcb
    test    %rax, %rax
    jz      .connect_failed
    
    # Save TCB pointer
    mov     %rax, %r12
    
    # Set socket state to SYN_SENT
    movq    $TCP_SYN_SENT, SOCK_STATE(%rbx)
    
    # Set TCB state
    movq    $TCP_SYN_SENT, TCB_STATE(%r12)
    
    # Send SYN packet
    mov     %rbx, %rdi
    call    tcp_send_syn
    test    %rax, %rax
    jz      .connect_failed
    
    # Success - connection initiated
    mov     $1, %rax
    jmp     .connect_done
    
.connect_failed:
    xor     %rax, %rax
    
.connect_done:
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

#
# UDP send
#
vm_udp_sendto:
    # Socket ID in %rdi, buffer in %rsi, length in %rdx, address in %rcx, port in %r8
    push    %rbx
    push    %r12
    push    %r13
    push    %r14
    push    %r15
    
    # Save parameters
    mov     %rdi, %rbx    # Socket ID
    mov     %rsi, %r12    # Buffer
    mov     %rdx, %r13    # Length
    mov     %rcx, %r14    # Address
    mov     %r8, %r15     # Port
    
    # Find socket
    mov     %rbx, %rdi
    call    find_socket_by_id
    test    %rax, %rax
    jz      .udp_send_failed
    
    # Save socket pointer
    mov     %rax, %rbx
    
    # Check if socket is valid for UDP
    movq    SOCK_TYPE(%rbx), %rax
    cmp     $SOCK_DGRAM, %rax
    jne     .udp_send_failed
    
    # Allocate packet buffer
    mov     %r13, %rdi
    add     $28, %rdi     # UDP header (8) + IP header min (20)
    call    allocate_packet_buffer
    test    %rax, %rax
    jz      .udp_send_failed
    
    # Save buffer pointer
    mov     %rax, %rdi
    
    # Set up UDP header
    add     $20, %rdi     # Skip IP header
    movq    SOCK_LOCAL_PORT(%rbx), %rax
    movw    %ax, (%rdi)   # Source port
    movw    %r15w, 2(%rdi)  # Destination port
    movw    %r13w, 4(%rdi)  # Data length
    addw    $8, 4(%rdi)   # Add UDP header length
    movw    $0, 6(%rdi)   # Checksum (will compute later)
    
    # Copy data
    add     $8, %rdi      # Skip UDP header
    mov     %r12, %rsi    # Source
    mov     %r13, %rdx    # Length
    call    memcpy
    
    # Set up IP header
    sub     $28, %rdi     # Go back to start of buffer
    mov     %rdi, %r12    # Save buffer start
    
    call    setup_ip_header
    
    # Calculate checksums
    mov     %r12, %rdi
    call    calculate_ip_checksum
    
    mov     %r12, %rdi
    call    calculate_udp_checksum
    
    # Add to outgoing queue
    mov     %r12, %rdi    # Buffer
    add     $20, %r13     # Length + IP header
    add     $8, %r13      # Length + UDP header
    mov     %r13, %rsi    # Total length
    call    queue_outgoing_packet
    test    %rax, %rax
    jz      .udp_send_failed
    
    # Return bytes sent
    mov     %r13, %rax
    jmp     .udp_send_done
    
.udp_send_failed:
    xor     %rax, %rax
    
.udp_send_done:
    pop     %r15
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

# Helper functions
validate_shared_memory:
    ret
allocate_transport_structures:
    ret
init_transport_allocator:
    ret
init_protocol_handlers:
    ret
register_with_shared_memory:
    ret
setup_shared_memory:
    ret
init_packet_handling:
    ret
init_socket_subsystem:
    ret
init_tcp_subsystem:
    ret
init_udp_subsystem:
    ret
init_routing_and_arp:
    ret
vm_transport_error:
    ret
poll_rx_ring:
    ret
process_rx_packets:
    ret
check_tx_queues:
    ret
process_tx_queues:
    ret
process_tcp_timers:
    ret
check_exit_condition:
    ret
vm_usleep:
    ret
find_socket_by_id:
    ret
allocate_tcb:
    ret
tcp_send_syn:
    ret
allocate_packet_buffer:
    ret
memcpy:
    ret
setup_ip_header:
    ret
calculate_ip_checksum:
    ret
calculate_udp_checksum:
    ret
queue_outgoing_packet:
    ret

# Data section
.section .data
.align 8
transport_initialized:
    .quad 0                      # Whether transport layer is initialized
socket_list_head:
    .quad 0                      # Head of socket list
tcb_list_head:
    .quad 0                      # Head of TCB list
sockets_allocated:
    .quad 0                      # Number of allocated sockets
connections_active:
    .quad 0                      # Number of active connections 