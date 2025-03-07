.code64
.global init_fs_scanner, verify_system_hash

# Constants
.set HASH_SIZE,         64
.set KEY_SIZE,          4096
.set SECTOR_SIZE,       512

# System verification structure
.struct 0
SYS_SERIAL:    .quad 0
SYS_HASH:      .skip HASH_SIZE
SYS_KEY:       .skip KEY_SIZE
SYS_SIZE:

# Initialize filesystem scanner
init_fs_scanner:
    # Get system serial
    call    get_system_serial
    
    # Load private key
    lea     system_key(%rip), %rdi
    call    load_private_key
    
    # Initialize hash verification
    call    init_hash_verify
    ret

# Verify system hash
verify_system_hash:
    push    %rbx
    push    %rcx

    # Read system drives
    call    enumerate_drives
    
    # For each drive
    lea     drive_list(%rip), %rbx
1:
    test    %rbx, %rbx
    jz      2f
    
    # Verify drive hash
    mov     %rbx, %rdi
    call    verify_drive_hash
    
    mov     DRIVE_NEXT(%rbx), %rbx
    jmp     1b

2:
    pop     %rcx
    pop     %rbx
    ret

# Private key and hash storage
.section .rodata
system_key:
    .skip KEY_SIZE

# Data section
.section .data
drive_list:    .quad 0
system_serial: .quad 0 