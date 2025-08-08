.code64
.global apic_init_guest, apic_inject_interrupt, apic_handle_guest_read, apic_handle_guest_write

# APIC register offsets
.set APIC_ID,                   0x020
.set APIC_VERSION,              0x030
.set APIC_TASK_PRIORITY,       0x080
.set APIC_ARBITRATION_PRIORITY,0x090
.set APIC_PROCESSOR_PRIORITY,  0x0A0
.set APIC_EOI,                 0x0B0
.set APIC_REMOTE_READ,         0x0C0
.set APIC_LOGICAL_DESTINATION, 0x0D0
.set APIC_DESTINATION_FORMAT,  0x0E0
.set APIC_SPURIOUS_VECTOR,     0x0F0
.set APIC_ISR_BASE,            0x100
.set APIC_TMR_BASE,            0x180
.set APIC_IRR_BASE,            0x200
.set APIC_ERROR_STATUS,        0x280
.set APIC_ICR_LOW,             0x300
.set APIC_ICR_HIGH,            0x310
.set APIC_LVT_TIMER,           0x320
.set APIC_LVT_THERMAL,         0x330
.set APIC_LVT_PERFORMANCE,     0x340
.set APIC_LVT_LINT0,           0x350
.set APIC_LVT_LINT1,           0x360
.set APIC_LVT_ERROR,           0x370
.set APIC_TIMER_INITIAL_COUNT, 0x380
.set APIC_TIMER_CURRENT_COUNT, 0x390
.set APIC_TIMER_DIVIDE,        0x3E0

# I/O APIC registers
.set IOAPIC_ID,                0x00
.set IOAPIC_VER,               0x01
.set IOAPIC_ARB,               0x02
.set IOAPIC_REDIR_TBL_BASE,   0x10

# APIC virtualization state
.section .bss
.align 4096
guest_apic_state:
    .skip 4096  # 4KB for APIC registers

ioapic_state:
    .skip 4096  # 4KB for I/O APIC

.section .data
.align 8
apic_base_addr:
    .quad 0xFEE00000  # Standard APIC base address

ioapic_base_addr:
    .quad 0xFEC00000  # Standard I/O APIC base address

.text
# void apic_init_guest(struct VM *vm)
apic_init_guest:
    push    %rbx
    push    %rcx
    push    %rdx

    # Initialize Local APIC registers
    lea     guest_apic_state(%rip), %rax
    
    # Set APIC ID
    mov     $APIC_ID, %rbx
    mov     $0x01000000, %ecx  # APIC ID = 1
    mov     %ecx, (%rax, %rbx)
    
    # Set APIC Version
    mov     $APIC_VERSION, %rbx
    mov     $0x00050014, %ecx  # Version 5.14
    mov     %ecx, (%rax, %rbx)
    
    # Set Spurious Vector
    mov     $APIC_SPURIOUS_VECTOR, %rbx
    mov     $0x000001FF, %ecx  # Enable APIC, vector 0xFF
    mov     %ecx, (%rax, %rbx)
    
    # Initialize I/O APIC
    lea     ioapic_state(%rip), %rax
    
    # Set I/O APIC ID
    mov     $IOAPIC_ID, %rbx
    mov     $0x01000000, %ecx  # I/O APIC ID = 1
    mov     %ecx, (%rax, %rbx)
    
    # Set I/O APIC Version
    mov     $IOAPIC_VER, %rbx
    mov     $0x00030020, %ecx  # Version 3.32
    mov     %ecx, (%rax, %rbx)

    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# void apic_inject_interrupt(uint8_t vector)
apic_inject_interrupt:
    push    %rbx
    push    %rcx
    push    %rdx

    # %dil contains vector
    mov     %dil, %al
    
    # Set ICR low register
    lea     guest_apic_state(%rip), %rbx
    mov     $APIC_ICR_LOW, %rcx
    mov     %eax, (%rbx, %rcx)
    
    # Set ICR high register (destination)
    mov     $APIC_ICR_HIGH, %rcx
    mov     $0x01000000, %eax  # Destination APIC ID = 1
    mov     %eax, (%rbx, %rcx)

    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# uint32_t apic_handle_guest_read(uint64_t addr)
apic_handle_guest_read:
    # %rdi contains guest address
    push    %rbx
    push    %rcx
    push    %rdx

    # Check if it's Local APIC access
    mov     %rdi, %rax
    and     $0xFFFFF000, %rax
    cmp     apic_base_addr(%rip), %rax
    je      handle_local_apic_read
    
    # Check if it's I/O APIC access
    cmp     ioapic_base_addr(%rip), %rax
    je      handle_ioapic_read
    
    # Unknown address
    xor     %rax, %rax
    jmp     apic_read_done

handle_local_apic_read:
    # Calculate register offset
    mov     %rdi, %rax
    and     $0xFFF, %rax
    
    # Read from guest APIC state
    lea     guest_apic_state(%rip), %rbx
    mov     (%rbx, %rax), %eax
    jmp     apic_read_done

handle_ioapic_read:
    # Calculate register offset
    mov     %rdi, %rax
    and     $0xFFF, %rax
    
    # Read from I/O APIC state
    lea     ioapic_state(%rip), %rbx
    mov     (%rbx, %rax), %eax

apic_read_done:
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# void apic_handle_guest_write(uint64_t addr, uint32_t value)
apic_handle_guest_write:
    # %rdi = addr, %rsi = value
    push    %rbx
    push    %rcx
    push    %rdx

    # Check if it's Local APIC access
    mov     %rdi, %rax
    and     $0xFFFFF000, %rax
    cmp     apic_base_addr(%rip), %rax
    je      handle_local_apic_write
    
    # Check if it's I/O APIC access
    cmp     ioapic_base_addr(%rip), %rax
    je      handle_ioapic_write
    
    # Unknown address - ignore
    jmp     apic_write_done

handle_local_apic_write:
    # Calculate register offset
    mov     %rdi, %rax
    and     $0xFFF, %rax
    
    # Write to guest APIC state
    lea     guest_apic_state(%rip), %rbx
    mov     %esi, (%rbx, %rax)
    
    # Handle special registers
    cmp     $APIC_EOI, %rax
    je      handle_eoi_write
    cmp     $APIC_ICR_LOW, %rax
    je      handle_icr_write
    jmp     apic_write_done

handle_ioapic_write:
    # Calculate register offset
    mov     %rdi, %rax
    and     $0xFFF, %rax
    
    # Write to I/O APIC state
    lea     ioapic_state(%rip), %rbx
    mov     %esi, (%rbx, %rax)

handle_eoi_write:
    # Handle End of Interrupt
    # For now, just acknowledge
    jmp     apic_write_done

handle_icr_write:
    # Handle Interrupt Command Register
    # For now, just store the value
    jmp     apic_write_done

apic_write_done:
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret
