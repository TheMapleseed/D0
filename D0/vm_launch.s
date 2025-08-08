.code64
.global vm_launch_vcpu, vm_resume_vcpu, vm_exit_handler

# VM exit reasons
.set VM_EXIT_CPUID,          0x0000000A
.set VM_EXIT_HLT,            0x0000000C
.set VM_EXIT_VMCALL,         0x00000012
.set VM_EXIT_CR_ACCESS,      0x0000001A
.set VM_EXIT_IO_INSTRUCTION, 0x0000001B
.set VM_EXIT_MSR_READ,       0x0000001C
.set VM_EXIT_MSR_WRITE,      0x0000001D
.set VM_EXIT_EPT_VIOLATION,  0x00000033

.text
# int vm_launch_vcpu(struct VM *vm, uint64_t vcpu_index)
vm_launch_vcpu:
    push    %rbx
    push    %rcx
    push    %rdx
    push    %rsi
    push    %rdi

    # Save VM pointer
    mov     %rdi, %rbx

    # Launch VM
    vmlaunch
    jc      1f
    jz      1f

    # VM exit occurred - handle it
    call    vm_exit_handler
    mov     $1, %rax
    jmp     2f

1:  xor     %rax, %rax
2:  pop     %rdi
    pop     %rsi
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# int vm_resume_vcpu(struct VM *vm, uint64_t vcpu_index)
vm_resume_vcpu:
    push    %rbx
    push    %rcx
    push    %rdx
    push    %rsi
    push    %rdi

    # Save VM pointer
    mov     %rdi, %rbx

    # Resume VM
    vmresume
    jc      1f
    jz      1f

    # VM exit occurred - handle it
    call    vm_exit_handler
    mov     $1, %rax
    jmp     2f

1:  xor     %rax, %rax
2:  pop     %rdi
    pop     %rsi
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# void vm_exit_handler(void)
vm_exit_handler:
    push    %rax
    push    %rbx
    push    %rcx
    push    %rdx

    # Read exit reason from VMCS
    mov     $0x4402, %rax    # VM_EXIT_REASON
    vmread  %rax, %rax
    and     $0xFFFF, %rax

    # Handle different exit reasons
    cmp     $VM_EXIT_CPUID, %rax
    je      handle_cpuid_exit
    cmp     $VM_EXIT_HLT, %rax
    je      handle_hlt_exit
    cmp     $VM_EXIT_VMCALL, %rax
    je      handle_vmcall_exit
    cmp     $VM_EXIT_IO_INSTRUCTION, %rax
    je      handle_io_exit
    cmp     $VM_EXIT_MSR_READ, %rax
    je      handle_msr_read_exit
    cmp     $VM_EXIT_MSR_WRITE, %rax
    je      handle_msr_write_exit
    cmp     $VM_EXIT_EPT_VIOLATION, %rax
    je      handle_ept_violation

    # Unknown exit reason - just resume
    jmp     vm_exit_done

handle_cpuid_exit:
    # Handle CPUID instruction
    # For now, just resume
    jmp     vm_exit_done

handle_hlt_exit:
    # Handle HLT instruction
    # For now, just resume
    jmp     vm_exit_done

handle_vmcall_exit:
    # Handle VMCALL instruction
    # For now, just resume
    jmp     vm_exit_done

handle_io_exit:
    # Handle I/O instruction
    # For now, just resume
    jmp     vm_exit_done

handle_msr_read_exit:
    # Handle MSR read
    # For now, just resume
    jmp     vm_exit_done

handle_msr_write_exit:
    # Handle MSR write
    # For now, just resume
    jmp     vm_exit_done

handle_ept_violation:
    # Handle EPT violation
    # For now, just resume
    jmp     vm_exit_done

vm_exit_done:
    pop     %rdx
    pop     %rcx
    pop     %rbx
    pop     %rax
    ret
