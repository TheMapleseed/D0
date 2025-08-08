.code64
.global bridge_init, bridge_add_port, bridge_forward_packet, bridge_get_mac_table

# Bridge configuration
.set BRIDGE_MAX_PORTS,     16
.set BRIDGE_MAX_MAC_ENTRIES, 1024
.set ETH_ALEN,             6
.set ETH_HLEN,             14

# Ethernet frame types
.set ETH_P_IP,             0x0800
.set ETH_P_ARP,            0x0806
.set ETH_P_IPV6,           0x86DD

# Bridge port state
.section .bss
.align 4096
bridge_ports:
    .skip 4096  # Array of bridge ports

bridge_mac_table:
    .skip 4096  # MAC address table

bridge_state:
    .skip 256   # Bridge state

.section .data
.align 8
bridge_port_count:
    .quad 0

bridge_mac_count:
    .quad 0

# Bridge port structure (32 bytes)
.set PORT_MAC_OFFSET,      0
.set PORT_VM_ID_OFFSET,    6
.set PORT_QUEUE_ID_OFFSET, 8
.set PORT_STATE_OFFSET,    16
.set PORT_SIZE,            32

.text
# int bridge_init(void)
bridge_init:
    push    %rbx
    push    %rcx
    push    %rdx

    # Initialize bridge state
    lea     bridge_state(%rip), %rax
    mov     $0, (%rax)      # bridge state
    mov     $0, 8(%rax)     # bridge flags
    
    # Initialize port count
    lea     bridge_port_count(%rip), %rax
    mov     $0, (%rax)
    
    # Initialize MAC table count
    lea     bridge_mac_count(%rip), %rax
    mov     $0, (%rax)
    
    # Clear MAC table
    lea     bridge_mac_table(%rip), %rdi
    mov     $0, %rax
    mov     $BRIDGE_MAX_MAC_ENTRIES, %rcx
    rep stosb

    mov     $1, %rax
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# int bridge_add_port(uint8_t *mac, uint64_t vm_id, uint64_t queue_id)
bridge_add_port:
    # %rdi = mac, %rsi = vm_id, %rdx = queue_id
    push    %rbx
    push    %rcx
    push    %r8
    push    %r9

    # Check if we have room for another port
    mov     bridge_port_count(%rip), %rax
    cmp     $BRIDGE_MAX_PORTS, %rax
    jge     1f
    
    # Calculate port address
    lea     bridge_ports(%rip), %r8
    imul    $PORT_SIZE, %rax, %r9
    add     %r9, %r8
    
    # Copy MAC address
    mov     %rdi, %r9
    mov     (%r9), %ecx
    mov     %ecx, PORT_MAC_OFFSET(%r8)
    mov     2(%r9), %ecx
    mov     %ecx, PORT_MAC_OFFSET+2(%r8)
    
    # Store VM ID and queue ID
    mov     %rsi, PORT_VM_ID_OFFSET(%r8)
    mov     %rdx, PORT_QUEUE_ID_OFFSET(%r8)
    
    # Set port state (active)
    mov     $1, PORT_STATE_OFFSET(%r8)
    
    # Increment port count
    inc     %rax
    mov     %rax, bridge_port_count(%rip)
    
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %r9
    pop     %r8
    pop     %rcx
    pop     %rbx
    ret

# int bridge_forward_packet(uint8_t *packet, uint64_t len, uint64_t src_vm_id)
bridge_forward_packet:
    # %rdi = packet, %rsi = len, %rdx = src_vm_id
    push    %rbx
    push    %rcx
    push    %r8
    push    %r9
    push    %r10
    push    %r11

    # Validate packet length
    cmp     $ETH_HLEN, %rsi
    jl      1f
    
    # Extract destination MAC
    lea     ETH_HLEN(%rdi), %r8  # Skip source MAC
    mov     (%r8), %r9           # Destination MAC
    
    # Check if it's a broadcast packet
    cmp     $0xFFFFFFFFFFFF, %r9
    je      forward_broadcast
    
    # Look up destination in MAC table
    call    bridge_lookup_mac
    test    %rax, %rax
    jz      forward_broadcast
    
    # Forward to specific port
    mov     %rax, %r10
    call    bridge_send_to_port
    jmp     2f

forward_broadcast:
    # Forward to all ports except source
    mov     bridge_port_count(%rip), %rcx
    lea     bridge_ports(%rip), %r8
    
    xor     %r9, %r9  # port index
3:  cmp     %rcx, %r9
    jge     2f
    
    # Check if this is the source port
    mov     PORT_VM_ID_OFFSET(%r8), %r10
    cmp     %rdx, %r10
    je      4f
    
    # Send to this port
    push    %rcx
    push    %r8
    push    %r9
    mov     %r8, %rdi
    call    bridge_send_to_port
    pop     %r9
    pop     %r8
    pop     %rcx
    
4:  add     $PORT_SIZE, %r8
    inc     %r9
    jmp     3b

2:  mov     $1, %rax
    jmp     5f
1:  xor     %rax, %rax
5:  pop     %r11
    pop     %r10
    pop     %r9
    pop     %r8
    pop     %rcx
    pop     %rbx
    ret

# uint64_t bridge_lookup_mac(uint8_t *mac)
bridge_lookup_mac:
    # %rdi = mac address
    push    %rbx
    push    %rcx
    push    %r8
    push    %r9

    mov     bridge_mac_count(%rip), %rcx
    lea     bridge_mac_table(%rip), %r8
    
    xor     %r9, %r9  # index
6:  cmp     %rcx, %r9
    jge     7f
    
    # Compare MAC addresses
    mov     (%rdi), %eax
    cmp     (%r8), %eax
    jne     8f
    mov     2(%rdi), %eax
    cmp     2(%r8), %eax
    je      9f
    
8:  add     $16, %r8  # MAC entry size
    inc     %r9
    jmp     6b

7:  xor     %rax, %rax
    jmp     10f
9:  mov     %r9, %rax
10: pop     %r9
    pop     %r8
    pop     %rcx
    pop     %rbx
    ret

# void bridge_send_to_port(void *port, void *packet, uint64_t len)
bridge_send_to_port:
    # %rdi = port, %rsi = packet, %rdx = len
    push    %rbx
    push    %rcx
    push    %rdx

    # Get queue ID from port
    mov     PORT_QUEUE_ID_OFFSET(%rdi), %rax
    
    # Add packet to virtio queue
    mov     %rsi, %rdi  # packet
    mov     %rdx, %rsi  # len
    mov     $0, %rdx    # write = 0
    call    virtio_queue_add_buf
    
    # Kick the queue
    mov     %rax, %rdi
    call    virtio_queue_kick

    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret
