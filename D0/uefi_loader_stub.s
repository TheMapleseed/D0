.code64
.global uefi_loader_populate_manifest

# Kernel globals to populate
.extern manifest_addr
.extern manifest_len
.extern manifest_sig_addr
.extern manifest_sig_len

# D0 handoff block (placed by UEFI loader)
# Layout (all little-endian):
#   u32 magic = 'D0HD' (0x44484F30)
#   u32 version = 0x00010000
#   u64 manifest_addr
#   u64 manifest_len
#   u64 manifest_sig_addr
#   u64 manifest_sig_len

.set D0_HANDOFF_ADDR, 0x0000000000070000
.set D0_HANDOFF_MAGIC, 0x44484F30

.text
uefi_loader_populate_manifest:
    push    %rbx
    push    %rcx
    push    %rdx

    mov     $D0_HANDOFF_ADDR, %rbx
    # Verify magic
    mov     (%rbx), %eax
    cmp     $D0_HANDOFF_MAGIC, %eax
    jne     1f

    # Skip magic (4) + version (4)
    lea     8(%rbx), %rbx

    # Load manifest_addr
    mov     (%rbx), %rax
    mov     %rax, manifest_addr(%rip)
    add     $8, %rbx

    # Load manifest_len
    mov     (%rbx), %rax
    mov     %rax, manifest_len(%rip)
    add     $8, %rbx

    # Load manifest_sig_addr
    mov     (%rbx), %rax
    mov     %rax, manifest_sig_addr(%rip)
    add     $8, %rbx

    # Load manifest_sig_len
    mov     (%rbx), %rax
    mov     %rax, manifest_sig_len(%rip)

1:  xor     %rax, %rax
    pop     %rdx
    pop     %rcx
    pop     %rbx
    ret
