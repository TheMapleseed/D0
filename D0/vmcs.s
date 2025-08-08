.code64
.global vmcs_alloc_for_vm, vmcs_init_for_vcpu
.extern vmcs_write_basic_controls

# MSRs
.set IA32_FEATURE_CONTROL,   0x3A
.set IA32_VMX_BASIC,         0x480

# VMCS field encodings
.set VMCS_FIELD_EPTP,        0x201A

# CR4 bits
.set CR4_VMXE,               (1 << 13)

# CPUID leafs/bits
.set CPUID_LEAF1,            0x1
.set CPUID_VMX_BIT,          (1 << 5)   # ECX bit 5

# VMCS region (aligned 4K)
.section .bss
.align 4096
vmcs_region:
    .skip 4096

.section .data
.align 8
vmxon_pa:
    .quad 0

.text
# uint64_t vmcs_alloc_for_vm(struct VM *vm)
# Returns pointer to VMCS region (identity PA assumption) or 0
vmcs_alloc_for_vm:
    # Return static VMCS region base (identity mapping assumption)
    lea     vmcs_region(%rip), %rax
    ret

# int vmcs_init_for_vcpu(struct VM *vm, uint64_t vcpu_index, uint64_t eptp)
vmcs_init_for_vcpu:
    # Write VMX revision ID into VMCS region header
    push    %rbx
    push    %rcx
    push    %rdx
    mov     $IA32_VMX_BASIC, %ecx
    rdmsr                           # EAX = revision ID
    lea     vmcs_region(%rip), %rbx
    mov     %eax, (%rbx)
    # Assume identity mapping; program physical address for VMCS ops
    mov     %rbx, %rax
    mov     %rax, vmxon_pa(%rip)
    # VMX operations: VMCLEAR then VMPTRLD
    vmclear vmxon_pa(%rip)
    jc      1f
    vmptrld vmxon_pa(%rip)
    jc      1f
    # Write controls (pin/proc/exit/entry including secondary)
    call    vmcs_write_basic_controls
    jc      1f
    # Write host state
    call    vmcs_write_host_state
    jc      1f
    # Write guest state
    call    vmcs_write_guest_state
    jc      1f
    # Write EPTP into VMCS
    mov     $VMCS_FIELD_EPTP, %rax
    vmwrite %rdx, %rax               # %rdx contains eptp from caller
    jc      1f
    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rdx
    pop     %rcx
    pop     %rbx
    ret
