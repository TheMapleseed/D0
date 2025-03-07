.code64
.global init_boot_devices, map_uefi_devices

# UEFI Device Map Structure
.struct 0
UEFI_HANDLE:    .quad 0    # UEFI device handle
UEFI_PATH:      .quad 0    # Device path
UEFI_PROTOCOL:  .quad 0    # Protocol GUID
UEFI_INFO:      .quad 0    # Device info
UEFI_MAP_SIZE:

# Boot Services Table
.struct 0
BOOT_LOCATE:    .quad 0    # LocateHandle
BOOT_PROTOCOL:  .quad 0    # ProtocolInterface
BOOT_EXIT:      .quad 0    # ExitBootServices
BOOT_SIZE:

# Map UEFI devices to kernel
map_uefi_devices:
    push    %rbx
    push    %r12
    
    # Get UEFI boot services
    mov     boot_services_table, %rbx
    
    # Enumerate devices
    mov     BOOT_LOCATE(%rbx), %rax
    call    *%rax
    
    # For each device
1:
    # Get device info
    call    get_uefi_device_info
    
    # Create kernel mapping
    call    create_kernel_device
    
    # Store in device table
    call    store_device_mapping
    
    # Next device
    dec     %rcx
    jnz     1b
    
    pop     %r12
    pop     %rbx
    ret

# Store UEFI info before ExitBootServices
preserve_uefi_info:
    # Save critical device info before ExitBootServices
    lea     uefi_preserved(%rip), %rdi
    mov     uefi_system_table, %rsi
    mov     $UEFI_INFO_SIZE, %rcx
    rep movsb
    
    # Save device paths
    call    save_device_paths
    ret

# Data Section
.section .data
.align 8
uefi_device_map:
    .skip UEFI_MAP_SIZE * 256    # Support up to 256 devices

boot_services_table:
    .quad 0

# Read-only preserved UEFI data
.section .rodata
uefi_preserved:
    .skip 4096    # Preserved UEFI information 