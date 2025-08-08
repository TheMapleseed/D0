.code64
.global init_hypervisor, create_transport_vm, destroy_transport_vm
.global vm_alloc_memory, vm_free_memory, vm_map_device, vm_unmap_device
.global start_transport_vm, stop_transport_vm, pause_transport_vm
.global vm_send_interrupt, vm_poll_event
# External VMX helper
.extern vmx_init_safe
.extern ept_init_global
.extern ept_setup_for_vm
.extern virtio_init_net_backend
.extern virtio_mmio_init_net, virtio_mmio_init_blk
.extern vmcs_alloc_for_vm
.extern vmcs_init_for_vcpu
.extern apic_init_guest, bridge_init


# Hypervisor constants
.set VM_PAGE_SIZE,         4096          # Basic page size
.set VM_LARGE_PAGE_SIZE,   2097152       # 2MB large page
.set VM_HUGE_PAGE_SIZE,    1073741824    # 1GB huge page
.set VM_MAX_VCPUS,         32            # Maximum vCPUs per VM
.set VM_DEFAULT_VCPUS,     2             # Default vCPUs for transport VMs
.set VM_MAX_TRANSPORT_VMS, 64            # Maximum number of transport VMs
.set VM_MEMORY_MIN,        16777216      # Minimum VM memory (16MB)
.set VM_MEMORY_DEFAULT,    67108864      # Default VM memory (64MB)
.set VM_MAX_DEVICES,       16            # Maximum devices per VM

# Hardware virtualization features
.set VM_FEATURE_EPT,       0x00000001    # Extended Page Tables
.set VM_FEATURE_VPID,      0x00000002    # Virtual Processor IDs
.set VM_FEATURE_VMCS,      0x00000004    # VM Control Structure shadowing
.set VM_FEATURE_VMFUNC,    0x00000008    # VM Functions
.set VM_FEATURE_VE,        0x00000010    # Virtualization Exceptions
.set VM_FEATURE_PML,       0x00000020    # Page Modification Logging
.set VM_FEATURE_SPP,       0x00000040    # Sub-Page Protection
.set VM_FEATURE_APIC,      0x00000080    # Virtual APIC
.set VM_FEATURE_POSTED_INT,0x00000100    # Posted Interrupts

# VM exit reasons relevant to transport layer
.set VM_EXIT_EXTERNAL_INT, 1             # External interrupt
.set VM_EXIT_IO_INSTR,     16            # I/O instruction
.set VM_EXIT_RDMSR,        31            # RDMSR instruction
.set VM_EXIT_WRMSR,        32            # WRMSR instruction
.set VM_EXIT_EPT_VIOLATION,48            # EPT violation
.set VM_EXIT_CPUID,          0x0000000A
.set VM_EXIT_HLT,            0x0000000C
.set VM_EXIT_VMCALL,         0x00000012
.set VM_EXIT_CR_ACCESS,      0x0000001A
.set VM_EXIT_IO_INSTRUCTION, 0x0000001B
.set VM_EXIT_MSR_READ,       0x0000001C
.set VM_EXIT_MSR_WRITE,      0x0000001D
.set VM_EXIT_EPT_VIOLATION,  0x00000033

# VM states
.set VM_STATE_CREATED,     0             # VM created but not running
.set VM_STATE_RUNNING,     1             # VM running
.set VM_STATE_PAUSED,      2             # VM paused
.set VM_STATE_ERROR,       3             # VM error state

# Transport VM structure
.struct 0
VM_ID:                  .quad 0          # VM ID
VM_STATE:               .quad 0          # VM state
VM_VCPU_COUNT:          .quad 0          # Number of vCPUs
VM_MEMORY_SIZE:         .quad 0          # Memory size in bytes
VM_EPT_ROOT:            .quad 0          # EPT root address
VM_VMCS_ADDR:           .skip VM_MAX_VCPUS * 8  # VMCS addresses
VM_VCPU_STATE:          .skip VM_MAX_VCPUS * 8  # vCPU state addresses
VM_FEATURES:            .quad 0          # Enabled features
VM_NETWORK_INTERFACE:   .quad 0          # Network interface for this VM
VM_SHARED_PAGES:        .quad 0          # Shared memory pages for packet exchange
VM_SHARED_SIZE:         .quad 0          # Size of shared memory
VM_EXIT_HANDLER:        .quad 0          # Exit handler function
VM_DEVICE_COUNT:        .quad 0          # Number of devices
VM_DEVICE_LIST:         .skip VM_MAX_DEVICES * 8  # Device list
VM_PRIVATE_DATA:        .quad 0          # Private data pointer
VM_SIZE:

# Shared memory region for packet exchange between VM and host
.struct 0
SHM_MAGIC:              .quad 0          # Magic number for verification
SHM_VERSION:            .quad 0          # Version of the shared memory format
SHM_TX_RING_ADDR:       .quad 0          # TX ring address
SHM_RX_RING_ADDR:       .quad 0          # RX ring address
SHM_TX_RING_SIZE:       .quad 0          # TX ring size
SHM_RX_RING_SIZE:       .quad 0          # RX ring size
SHM_TX_PROD_IDX:        .quad 0          # TX producer index
SHM_TX_CONS_IDX:        .quad 0          # TX consumer index
SHM_RX_PROD_IDX:        .quad 0          # RX producer index
SHM_RX_CONS_IDX:        .quad 0          # RX consumer index
SHM_FLAGS:              .quad 0          # Flags
SHM_NOTIFY_METHOD:      .quad 0          # Notification method
SHM_HOST_FEATURES:      .quad 0          # Host supported features
SHM_VM_FEATURES:        .quad 0          # VM supported features
SHM_SIZE:

#
# Initialize hypervisor
#
init_hypervisor:
    # Save registers
    push    %rbx
    push    %r12
    push    %r13
    
    # Check CPU virtualization support
    call    check_vmx_support
    test    %rax, %rax
    jz      .no_vmx_support
    
    # Enable VMX operation
    call    enable_vmx
    test    %rax, %rax
    jz      .vmx_enable_failed
    
    # Initialize EPT
    call    ept_init_global
    test    %rax, %rax
    jz      .ept_setup_failed

    # Initialize APIC virtualization
    call    apic_init_guest
    test    %rax, %rax
    jz      .apic_init_failed

    # Initialize network bridge
    call    bridge_init
    test    %rax, %rax
    jz      .bridge_init_failed
    
    # Allocate memory for VM tracking array
    mov     $VM_MAX_TRANSPORT_VMS, %rdi
    imul    $VM_SIZE, %rdi
    mov     $0, %rsi                       # Use secure isolated memory
    call    allocate_secure_memory
    test    %rax, %rax
    jz      .vm_alloc_failed
    
    # Save VM array base
    movq    %rax, vm_array_base(%rip)
    
    # Initialize the array
    mov     %rax, %rdi
    mov     $VM_MAX_TRANSPORT_VMS, %rsi
    imul    $VM_SIZE, %rsi
    xor     %rdx, %rdx                     # Fill with zeros
    call    secure_memset
    
    # Setup globally shared EPT structures
    call    setup_global_ept
    test    %rax, %rax
    jz      .ept_setup_failed
    
    # Setup VM exit handlers
    call    setup_vm_exit_handlers
    test    %rax, %rax
    jz      .exit_handler_failed
    
    # Mark hypervisor as initialized
    movq    $1, hypervisor_initialized(%rip)
    
    # Success
    mov     $1, %rax
    jmp     .init_done
    
.no_vmx_support:
.vmx_enable_failed:
.vm_alloc_failed:
.ept_setup_failed:
.apic_init_failed:
.bridge_init_failed:
.exit_handler_failed:
    # Initialization failed
    xor     %rax, %rax
    
.init_done:
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

#
# Create a transport VM
#
create_transport_vm:
    # Network interface ID in %rdi, VM config in %rsi
    push    %rbx
    push    %r12
    push    %r13
    
    # Save parameters
    mov     %rdi, %r12          # Network interface ID
    mov     %rsi, %r13          # VM config
    
    # Check if hypervisor is initialized
    movq    hypervisor_initialized(%rip), %rax
    test    %rax, %rax
    jz      .create_vm_failed
    
    # Find free VM slot
    mov     vm_array_base(%rip), %rbx
    xor     %rcx, %rcx
    
.find_vm_slot:
    cmp     $VM_MAX_TRANSPORT_VMS, %rcx
    jge     .no_free_slots
    
    # Check if slot is free
    movq    VM_ID(%rbx), %rax
    test    %rax, %rax
    jz      .slot_found
    
    # Move to next slot
    add     $VM_SIZE, %rbx
    inc     %rcx
    jmp     .find_vm_slot
    
.slot_found:
    # Generate VM ID
    mov     %rcx, %rdi
    call    generate_vm_id
    
    # Store VM ID
    movq    %rax, VM_ID(%rbx)
    
    # Set up VM initial state
    movq    $VM_STATE_CREATED, VM_STATE(%rbx)
    
    # Store network interface ID
    movq    %r12, VM_NETWORK_INTERFACE(%rbx)
    
    # Configure VM memory and vCPUs
    test    %r13, %r13
    jz      .use_default_config
    
    # Use provided config
    # TODO: Implement custom configuration parsing
    jmp     .vm_configured
    
.use_default_config:
    # Set default values
    movq    $VM_DEFAULT_VCPUS, VM_VCPU_COUNT(%rbx)
    movq    $VM_MEMORY_DEFAULT, VM_MEMORY_SIZE(%rbx)
    
.vm_configured:
    # Allocate VM memory
    movq    VM_MEMORY_SIZE(%rbx), %rdi
    call    allocate_vm_memory
    test    %rax, %rax
    jz      .vm_memory_failed
    
    # Save VM memory base
    movq    %rax, vm_memory_base(%rip)
    
    # Set up Extended Page Tables (EPT)
    mov     %rbx, %rdi          # VM descriptor
    call    setup_vm_ept
    test    %rax, %rax
    jz      .ept_failed
    
    # Set up shared memory region for packet exchange
    mov     %rbx, %rdi          # VM descriptor
    call    setup_shared_memory
    test    %rax, %rax
    jz      .shared_mem_failed
    
    # Initialize virtual CPUs
    mov     %rbx, %rdi          # VM descriptor
    call    init_vm_vcpus
    test    %rax, %rax
    jz      .vcpu_init_failed
    
    # Setup virtual network device for the transport layer
    mov     %rbx, %rdi          # VM descriptor
    mov     %r12, %rsi          # Network interface ID
    call    setup_virtual_network
    test    %rax, %rax
    jz      .vnet_setup_failed
    
    # Return VM ID
    movq    VM_ID(%rbx), %rax
    jmp     .create_vm_done
    
.no_free_slots:
.vm_memory_failed:
.ept_failed:
.shared_mem_failed:
.vcpu_init_failed:
.vnet_setup_failed:
.create_vm_failed:
    # Creation failed, clean up any partial initialization
    test    %rbx, %rbx
    jz      .no_cleanup
    
    movq    VM_ID(%rbx), %rax
    test    %rax, %rax
    jz      .no_cleanup
    
    # Clean up VM resources
    mov     %rbx, %rdi
    call    cleanup_vm_resources
    
    # Clear VM ID to mark slot as free
    movq    $0, VM_ID(%rbx)
    
.no_cleanup:
    xor     %rax, %rax
    
.create_vm_done:
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

#
# Start a transport VM
#
start_transport_vm:
    # VM ID in %rdi
    push    %rbx
    
    # Find VM descriptor
    call    find_vm_by_id
    test    %rax, %rax
    jz      .start_vm_failed
    
    # Save VM descriptor
    mov     %rax, %rbx
    
    # Check VM state
    movq    VM_STATE(%rbx), %rax
    cmp     $VM_STATE_CREATED, %rax
    je      .can_start
    cmp     $VM_STATE_PAUSED, %rax
    je      .can_start
    jmp     .invalid_state
    
.can_start:
    # Load transport layer code into VM memory
    mov     %rbx, %rdi
    call    load_transport_code
    test    %rax, %rax
    jz      .start_vm_failed
    
    # Start all virtual CPUs
    mov     %rbx, %rdi
    call    start_vm_vcpus
    test    %rax, %rax
    jz      .start_vm_failed
    
    # Set VM state to running
    movq    $VM_STATE_RUNNING, VM_STATE(%rbx)
    
    # Return success
    mov     $1, %rax
    jmp     .start_vm_done
    
.invalid_state:
.start_vm_failed:
    xor     %rax, %rax
    
.start_vm_done:
    pop     %rbx
    ret

#
# Set up shared memory for packet exchange
#
setup_shared_memory:
    # VM descriptor in %rdi
    push    %rbx
    
    # Save VM descriptor
    mov     %rdi, %rbx
    
    # Allocate shared memory for packet rings
    # Note: This memory will be shared between host and VM
    mov     $SHM_SIZE, %rdi
    add     $65536, %rdi        # Add space for packet buffers
    call    allocate_shared_memory
    test    %rax, %rax
    jz      .shared_alloc_failed
    
    # Save shared memory address
    movq    %rax, VM_SHARED_PAGES(%rbx)
    
    # Save shared memory size
    movq    %rdi, VM_SHARED_SIZE(%rbx)
    
    # Initialize shared memory header
    movq    $0x5452414E535648, SHM_MAGIC(%rax)    # "TRANSVH"
    movq    $0x00010000, SHM_VERSION(%rax)         # Version 1.0
    
    # Set up rings
    lea     4096(%rax), %rcx                       # TX ring starts at offset 4096
    movq    %rcx, SHM_TX_RING_ADDR(%rax)
    
    lea     16384(%rax), %rcx                      # RX ring starts at offset 16384
    movq    %rcx, SHM_RX_RING_ADDR(%rax)
    
    # Set ring sizes
    movq    $4096, SHM_TX_RING_SIZE(%rax)
    movq    $4096, SHM_RX_RING_SIZE(%rax)
    
    # Initialize indices
    movq    $0, SHM_TX_PROD_IDX(%rax)
    movq    $0, SHM_TX_CONS_IDX(%rax)
    movq    $0, SHM_RX_PROD_IDX(%rax)
    movq    $0, SHM_RX_CONS_IDX(%rax)
    
    # Set notification method (hypercall by default)
    movq    $1, SHM_NOTIFY_METHOD(%rax)
    
    # Map the shared memory into VM address space
    mov     %rbx, %rdi          # VM descriptor
    mov     VM_SHARED_PAGES(%rbx), %rsi    # Shared memory address
    mov     VM_SHARED_SIZE(%rbx), %rdx     # Shared memory size
    call    map_shared_memory_to_vm
    test    %rax, %rax
    jz      .shared_map_failed
    
    # Success
    mov     $1, %rax
    jmp     .setup_shared_done
    
.shared_alloc_failed:
.shared_map_failed:
    xor     %rax, %rax
    
.setup_shared_done:
    pop     %rbx
    ret

#
# VM exit handler for transport layer VM
# This is called when VM exits (e.g., for I/O operations or hypercalls)
#
transport_vm_exit_handler:
    # VMCS pointer in %rdi, exit reason in %rsi, exit qualification in %rdx
    push    %rbx
    push    %r12
    push    %r13
    
    # Save parameters
    mov     %rdi, %rbx          # VMCS pointer
    mov     %rsi, %r12          # Exit reason
    mov     %rdx, %r13          # Exit qualification
    
    # Handle based on exit reason
    cmp     $VM_EXIT_IO_INSTR, %r12
    je      .handle_io_exit
    
    cmp     $VM_EXIT_EXTERNAL_INT, %r12
    je      .handle_ext_interrupt
    
    cmp     $VM_EXIT_EPT_VIOLATION, %r12
    je      .handle_ept_violation
    
    # Default handling for other exit reasons
    jmp     .default_exit_handling
    
.handle_io_exit:
    # Handle emulated I/O instruction (e.g., for virtual NIC)
    mov     %rbx, %rdi          # VMCS pointer
    mov     %r13, %rsi          # Exit qualification
    call    handle_virtual_io
    jmp     .exit_handled
    
.handle_ext_interrupt:
    # Handle external interrupt
    mov     %rbx, %rdi
    call    handle_external_interrupt
    jmp     .exit_handled
    
.handle_ept_violation:
    # Handle EPT violation (e.g., for memory-mapped I/O)
    mov     %rbx, %rdi
    mov     %r13, %rsi
    call    handle_ept_violation
    jmp     .exit_handled
    
.default_exit_handling:
    # Default handling
    call    handle_default_exit
    
.exit_handled:
    # If return value in %rax is 1, we'll resume the VM
    # Otherwise we'll handle it differently
    
    pop     %r13
    pop     %r12
    pop     %rbx
    ret

# Helper function implementations (minimal skeleton)
check_vmx_support:
    # Return 1 if CPUID.1:ECX.VMX is set and IA32_FEATURE_CONTROL allows VMXON
    push    %rbx
    mov     $0x1, %eax
    cpuid
    test    $(1 << 5), %ecx          # VMX bit
    jz      1f
    mov     $0x3A, %ecx              # IA32_FEATURE_CONTROL
    rdmsr
    test    $0x1, %eax               # lock bit
    jz      1f
    test    $0x4, %eax               # VMXON outside SMX
    jz      1f
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rbx
    ret

enable_vmx:
    # Enable VMX in CR4
    mov     %cr4, %rax
    or      $0x2000, %rax  # CR4.VMXE
    mov     %rax, %cr4
    
    # Enable VMX in MSR
    mov     $0x3A, %ecx  # IA32_FEATURE_CONTROL
    rdmsr
    or      $0x05, %eax  # Lock bit + VMX enable
    wrmsr
    
    mov     $1, %rax
    ret

allocate_secure_memory:
    # %rdi = size (bytes)
    # Minimal non-destructive placeholder: return a non-zero dummy pointer
    mov     $0x100000, %rax
    ret
secure_memset:
    # %rdi = dst, %rsi = len, %rdx = value (low 8 bits)
    push    %rbx
    mov     %rdi, %rbx
    test    %rsi, %rsi
    jz      1f
0:  mov     %dl, (%rbx)
    inc     %rbx
    dec     %rsi
    jnz     0b
1:  pop     %rbx
    mov     %rdi, %rax
    ret
setup_global_ept:
    # Initialize global EPT structures
    call    ept_init_global
    ret
setup_vm_exit_handlers:
    # No VM descriptor in %rdi here; this installs a default handler address
    lea     transport_vm_exit_handler(%rip), %rax
    mov     %rax, default_vm_exit_handler(%rip)
    mov     $1, %rax
    ret
generate_vm_id:
    ret
allocate_vm_memory:
    # %rdi = size
    mov     $0x200000, %rax
    ret
setup_vm_ept:
    # %rdi = VM descriptor
    push    %rbx
    mov     %rdi, %rbx
    # Ask EPT module to prepare mappings and return EPT root pointer
    mov     %rbx, %rdi
    call    ept_setup_for_vm
    test    %rax, %rax
    jz      1f
    # Save EPT root into VM descriptor
    mov     %rax, VM_EPT_ROOT(%rbx)
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rbx
    ret
init_vm_vcpus:
    # %rdi = VM descriptor
    push    %rbx
    mov     %rdi, %rbx
    # For now, bring up a single vCPU minimal VMCS
    mov     $1, %rax
    mov     %rax, VM_VCPU_COUNT(%rbx)
    mov     %rbx, %rdi
    call    vmcs_alloc_for_vm
    test    %rax, %rax
    jz      1f
    # Initialize VMCS for vCPU 0 with current EPTP
    mov     %rbx, %rdi
    xor     %rsi, %rsi                # vcpu index 0
    mov     VM_EPT_ROOT(%rbx), %rdx   # EPTP
    call    vmcs_init_for_vcpu
    test    %rax, %rax
    jz      1f
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rbx
    ret
setup_virtual_network:
    # %rdi = VM descriptor, %rsi = netif id
    push    %rbx
    mov     %rdi, %rbx
    # Initialize virtio-net backend for this VM
    mov     %rbx, %rdi
    mov     %rsi, %rsi
    call    virtio_init_net_backend
    # Propagate return value
    test    %rax, %rax
    jz      1f
    # Initialize virtio block backend
    call    virtio_init_blk_backend
    test    %rax, %rax
    jz      1f
    # Map MMIO window for virtio-net
    mov     %rbx, %rdi
    call    virtio_mmio_init_net
1:
    pop     %rbx
    ret
cleanup_vm_resources:
    ret
find_vm_by_id:
    ret
load_transport_code:
    ret
start_vm_vcpus:
    ret
allocate_shared_memory:
    # %rdi = size
    mov     $0x300000, %rax
    ret
map_shared_memory_to_vm:
    # Minimal skeleton: assume mapping succeeds
    mov     $1, %rax
    ret
handle_virtual_io:
    # Minimal skeleton: handle I/O exit as completed
    mov     $1, %rax
    ret
handle_external_interrupt:
    ret
handle_ept_violation:
    ret
handle_default_exit:
    ret

# Data section
.section .data
.align 8
hypervisor_initialized:
    .quad 0                      # Whether hypervisor is initialized
vm_array_base:
    .quad 0                      # Base address of VM tracking array
vm_memory_base:
    .quad 0                      # Base address of VM memory
vm_count:
    .quad 0                      # Number of created VMs 
default_vm_exit_handler:
    .quad 0