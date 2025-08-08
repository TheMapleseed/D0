.code64
.global vmx_init_safe

# MSRs
.set IA32_FEATURE_CONTROL,   0x3A
.set IA32_VMX_BASIC,         0x480

# CR4 bits
.set CR4_VMXE,               (1 << 13)

# CPUID leafs/bits
.set CPUID_LEAF1,            0x1
.set CPUID_VMX_BIT,          (1 << 5)   # ECX bit 5

# VMXON region (aligned 4K)
.section .bss
.align 4096
vmxon_region:
    .skip 4096

.section .data
.align 8
vmxon_pa:
    .quad 0

.text
# int vmx_init_safe(void)
vmx_init_safe:
    push    %rbx
    push    %r12

    # Check CPUID.1:ECX.VMX
    mov     $CPUID_LEAF1, %eax
    cpuid
    test    $CPUID_VMX_BIT, %ecx
    jz      .fail

    # Check IA32_FEATURE_CONTROL MSR: VMXON enabled outside SMX and lock bit
    mov     $IA32_FEATURE_CONTROL, %ecx
    rdmsr
    # EAX bits: 0=lock, 2=VMXON outside SMX
    test    $0x1, %eax
    jz      .fail
    test    $0x4, %eax
    jz      .fail

    # Enable CR4.VMXE
    mov     %cr4, %rax
    or      $CR4_VMXE, %rax
    mov     %rax, %cr4

    # Write VMX revision ID into VMXON region (first 4 bytes)
    mov     $IA32_VMX_BASIC, %ecx
    rdmsr
    # EAX contains revision ID (low 31 bits)
    lea     vmxon_region(%rip), %rbx
    mov     %eax, (%rbx)

    # Execute VMXON with physical address of vmxon_region
    # NOTE: assumes identity mapping during bring-up
    lea     vmxon_region(%rip), %rax
    # Store assumed physical address (identity) into vmxon_pa
    mov     %rax, vmxon_pa(%rip)
    # VMXON operand is memory containing the physical address
    vmxon   vmxon_pa(%rip)
    jc      .fail

    mov     $1, %rax
    jmp     .out

.fail:
    xor     %rax, %rax

.out:
    pop     %r12
    pop     %rbx
    ret
