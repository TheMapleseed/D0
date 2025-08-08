.code64
.global vmcs_write_host_state, vmcs_write_guest_state

# VMCS field encodings for state areas
.set VMCS_HOST_CR0,       0x6C00
.set VMCS_HOST_CR3,       0x6C02
.set VMCS_HOST_CR4,       0x6C04
.set VMCS_HOST_CS_SEL,    0x0C00
.set VMCS_HOST_SS_SEL,    0x0C02
.set VMCS_HOST_DS_SEL,    0x0C04
.set VMCS_HOST_ES_SEL,    0x0C06
.set VMCS_HOST_FS_SEL,    0x0C08
.set VMCS_HOST_GS_SEL,    0x0C0A
.set VMCS_HOST_TR_SEL,    0x0C0C
.set VMCS_HOST_GDTR_BASE, 0x6C06
.set VMCS_HOST_IDTR_BASE, 0x6C08
.set VMCS_HOST_GDTR_LIMIT,0x6C0A
.set VMCS_HOST_IDTR_LIMIT,0x6C0C
.set VMCS_HOST_RSP,       0x6C14
.set VMCS_HOST_RIP,       0x6C16

.set VMCS_GUEST_CR0,      0x6800
.set VMCS_GUEST_CR3,      0x6802
.set VMCS_GUEST_CR4,      0x6804
.set VMCS_GUEST_CS_SEL,   0x0800
.set VMCS_GUEST_SS_SEL,   0x0802
.set VMCS_GUEST_DS_SEL,   0x0804
.set VMCS_GUEST_ES_SEL,   0x0806
.set VMCS_GUEST_FS_SEL,   0x0808
.set VMCS_GUEST_GS_SEL,   0x080A
.set VMCS_GUEST_LDTR_SEL, 0x080C
.set VMCS_GUEST_TR_SEL,   0x080E
.set VMCS_GUEST_GDTR_BASE,0x6806
.set VMCS_GUEST_IDTR_BASE,0x6808
.set VMCS_GUEST_GDTR_LIMIT,0x680A
.set VMCS_GUEST_IDTR_LIMIT,0x680C
.set VMCS_GUEST_RSP,      0x681C
.set VMCS_GUEST_RIP,      0x681E

.text
# int vmcs_write_host_state(void)
vmcs_write_host_state:
    push    %rbx
    push    %rcx
    push    %rdx

    # Host CR0/CR3/CR4
    mov     %cr0, %rax
    mov     $VMCS_HOST_CR0, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     %cr3, %rax
    mov     $VMCS_HOST_CR3, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     %cr4, %rax
    mov     $VMCS_HOST_CR4, %rbx
    vmwrite %rax, %rbx
    jc      1f

    # Host segment selectors (minimal)
    mov     $0x10, %rax    # data segment
    mov     $VMCS_HOST_CS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_HOST_SS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_HOST_DS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_HOST_ES_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_HOST_FS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_HOST_GS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_HOST_TR_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f

    # Host RSP/RIP (entry point)
    lea     host_entry_point(%rip), %rax
    mov     $VMCS_HOST_RIP, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     $0x1000, %rax  # host stack
    mov     $VMCS_HOST_RSP, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# int vmcs_write_guest_state(void)
vmcs_write_guest_state:
    push    %rbx
    push    %rcx
    push    %rdx

    # Guest CR0/CR3/CR4 (identity for now)
    mov     %cr0, %rax
    mov     $VMCS_GUEST_CR0, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     %cr3, %rax
    mov     $VMCS_GUEST_CR3, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     %cr4, %rax
    mov     $VMCS_GUEST_CR4, %rbx
    vmwrite %rax, %rbx
    jc      1f

    # Guest segment selectors (minimal)
    mov     $0x10, %rax    # data segment
    mov     $VMCS_GUEST_CS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_GUEST_SS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_GUEST_DS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_GUEST_ES_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_GUEST_FS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f
    mov     $VMCS_GUEST_GS_SEL, %rbx
    vmwrite %rax, %rbx
    jc      1f

    # Guest RSP/RIP (entry point)
    lea     guest_entry_point(%rip), %rax
    mov     $VMCS_GUEST_RIP, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     $0x2000, %rax  # guest stack
    mov     $VMCS_GUEST_RSP, %rbx
    vmwrite %rax, %rbx
    jc      1f

    mov     $1, %rax
    jmp     2f
1:  xor     %rax, %rax
2:  pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# Host entry point (called on VM exit)
host_entry_point:
    # TODO: handle VM exit
    vmresume
    ret

# Guest entry point (called on VM entry)
guest_entry_point:
    # TODO: guest code
    vmcall
    ret
