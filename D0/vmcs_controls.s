.code64
.global vmcs_write_basic_controls

# VMX control MSRs
.set IA32_VMX_PINBASED_CTLS,   0x481
.set IA32_VMX_PROCBASED_CTLS,  0x482
.set IA32_VMX_EXIT_CTLS,       0x483
.set IA32_VMX_ENTRY_CTLS,      0x484
.set IA32_VMX_PROCBASED_CTLS2, 0x48B

# VMCS field encodings (subset)
.set VMCS_PINBASED_CTLS,       0x4000
.set VMCS_PROCBASED_CTLS,      0x4002
.set VMCS_PROCBASED_CTLS2,     0x401E
.set VMCS_EXIT_CTLS,           0x400C
.set VMCS_ENTRY_CTLS,          0x4012

.text
# int vmcs_write_basic_controls(void)
# Reads control MSRs and writes minimally required controls to VMCS.
vmcs_write_basic_controls:
    push    %rbx
    push    %rcx
    push    %rdx

    # Helper macro-ish: read MSR, select allowed1, vmwrite value into field
    # PINBASED
    mov     $IA32_VMX_PINBASED_CTLS, %ecx
    rdmsr                      # EDX:EAX
    mov     %edx, %eax         # allowed-1 bits
    mov     $VMCS_PINBASED_CTLS, %rbx
    vmwrite %rax, %rbx

    # PROCBASED primary
    mov     $IA32_VMX_PROCBASED_CTLS, %ecx
    rdmsr
    mov     %edx, %eax
    # Enable secondary controls if available (bit 31)
    bts     $31, %eax
    mov     $VMCS_PROCBASED_CTLS, %rbx
    vmwrite %rax, %rbx

    # PROCBASED secondary
    mov     $IA32_VMX_PROCBASED_CTLS2, %ecx
    rdmsr
    mov     %edx, %eax
    mov     $VMCS_PROCBASED_CTLS2, %rbx
    vmwrite %rax, %rbx

    # EXIT controls
    mov     $IA32_VMX_EXIT_CTLS, %ecx
    rdmsr
    mov     %edx, %eax
    mov     $VMCS_EXIT_CTLS, %rbx
    vmwrite %rax, %rbx

    # ENTRY controls
    mov     $IA32_VMX_ENTRY_CTLS, %ecx
    rdmsr
    mov     %edx, %eax
    mov     $VMCS_ENTRY_CTLS, %rbx
    vmwrite %rax, %rbx

    mov     $1, %rax
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret


