.code64
.global ept_init_global, ept_setup_for_vm

# EPT constants
.set EPT_MEM_TYPE_WB,      6
.set EPT_PAGE_WALK_LEN,    3           # 4 levels -> value 3
.set EPTP_AD_FLAG,         (1 << 6)
.set EPT_READ,             (1 << 0)
.set EPT_WRITE,            (1 << 1)
.set EPT_EXEC,             (1 << 2)
.set EPT_LARGE,            (1 << 7)
.set SIZE_2MB,             (1 << 21)

.section .bss
.align 4096
# Global EPT structures for a 1GiB identity map using 2MiB pages
ept_global_pml4:
    .skip 4096
.align 4096
ept_global_pdpt:
    .skip 4096
.align 4096
ept_global_pd0:
    .skip 4096

.text
# int ept_init_global(void)
ept_init_global:
    push    %rbx
    push    %rcx
    push    %rdx
    # Clear PML4/PDPT/PD and build minimal identity map
    # Set PML4E[0] -> PDPT | R/W/X
    lea     ept_global_pdpt(%rip), %rbx
    lea     ept_global_pml4(%rip), %rax
    mov     %rbx, %rdx
    and     $~0xFFF, %rdx
    or      $(EPT_READ|EPT_WRITE|EPT_EXEC), %rdx
    mov     %rdx, (%rax)

    # Set PDPTE[0] -> PD0 | R/W/X
    lea     ept_global_pd0(%rip), %rbx
    lea     ept_global_pdpt(%rip), %rax
    mov     %rbx, %rdx
    and     $~0xFFF, %rdx
    or      $(EPT_READ|EPT_WRITE|EPT_EXEC), %rdx
    mov     %rdx, (%rax)

    # Fill PD entries with 2MiB identity mappings up to 1GiB
    lea     ept_global_pd0(%rip), %rax
    xor     %rcx, %rcx                  # index
    xor     %rdx, %rdx                  # phys base accumulator
1:
    mov     %rdx, %rbx
    and     $~0xFFF, %rbx
    or      $(EPT_READ|EPT_WRITE|EPT_EXEC|EPT_LARGE), %rbx
    mov     %rbx, (%rax,%rcx,8)
    add     $SIZE_2MB, %rdx
    inc     %rcx
    cmp     $512, %rcx
    jb      1b

    mov     $1, %rax
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret

# uint64_t ept_setup_for_vm(struct VM *vm)
# Returns EPTP in rax on success, 0 on failure
ept_setup_for_vm:
    push    %rbx
    # Build EPTP pointing to ept_global_pml4
    lea     ept_global_pml4(%rip), %rbx
    mov     %rbx, %rax
    and     $~0xFFF, %rax             # physical align assumption (identity)
    # Compose EPTP: [ bits 5:3 = page-walk length, bits 2:0 = memory type ]
    or      $(EPT_MEM_TYPE_WB | (EPT_PAGE_WALK_LEN << 3)), %rax
    # Optionally enable accessed/dirty
    # or      $EPTP_AD_FLAG, %rax
    pop     %rbx
    ret
