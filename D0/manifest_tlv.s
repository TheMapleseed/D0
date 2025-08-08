.code64
.global parse_manifest_tlv, verify_manifest_signature
.global get_manifest_build_uuid, get_manifest_bridge_ipv4
.global manifest_container_count

# TLV constants (little-endian)
.set TLV_HDR_SIZE,        4       # T:u16, L:u16
.set TLV_MAGIC,           0x464D3044  # 'D0MF'

# Top-level tags
.set T_BUILD_UUID,        0x0003   # 16 bytes
.set T_BRIDGE_IP4,        0x0001   # u32 ip + u8 prefix (5 bytes)
.set T_EGRESS_NAT,        0x0002   # u8

# Limits
.set MANIFEST_MAX_SIZE,   1024*64
.set MAX_CONTAINERS,      64

# Parsed state (BSS)
.section .bss
.align 8
manifest_build_uuid:
    .skip 16
manifest_bridge_ip4:
    .quad 0               # lower 5 bytes used: ip(u32)|prefix(u8) in low bits
manifest_container_count:
    .quad 0

# Public key placeholder (rodata, 32 bytes for Ed25519)
.section .rodata
.align 16
manifest_pubkey:
    .byte 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
    .byte 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0

# Verify manifest signature (glue)
# rdi = ptr to tlv buffer, rsi = length, rdx = ptr to signature, rcx = sig length
# returns rax = 1 on success, 0 on failure
.extern ed25519_verify_wrapper
verify_manifest_signature:
    push    %rbx
    push    %r12
    # Sanity checks
    test    %rdi, %rdi
    jz      .fail
    test    %rsi, %rsi
    jz      .fail
    test    %rdx, %rdx
    jz      .fail
    cmp     $64, %rcx
    jne     .fail
    # Call C wrapper: int ed25519_verify_wrapper(const void* msg, size_t msglen, const void* sig, const void* pubkey)
    mov     %rdi, %rdi      # msg
    mov     %rsi, %rsi      # msglen
    mov     %rdx, %rdx      # sig
    lea     manifest_pubkey(%rip), %rcx   # pubkey
    call    ed25519_verify_wrapper
    test    %rax, %rax
    jz      .fail
    mov     $1, %rax
    jmp     .out
.fail:
    xor     %rax, %rax
.out:
    pop     %r12
    pop     %rbx
    ret

# Getters
# rax -> pointer to 16-byte UUID buffer
get_manifest_build_uuid:
    lea     manifest_build_uuid(%rip), %rax
    ret

# rax -> 64-bit value: low 32 bits ipv4 (LE), next 8 bits prefix
get_manifest_bridge_ipv4:
    mov     manifest_bridge_ip4(%rip), %rax
    ret

# Parse manifest TLV (strict bounds)
# rdi = ptr, rsi = len
# returns rax = 1 ok, 0 fail
parse_manifest_tlv:
    push    %rbx
    push    %r12
    push    %r13
    push    %r14

    # Basic length check
    test    %rsi, %rsi
    jz      .fail
    cmp     $MANIFEST_MAX_SIZE, %rsi
    ja      .fail

    mov     %rdi, %rbx          # buf
    mov     %rsi, %r12          # len

    # Check magic (first 4 bytes)
    cmp     $4, %r12
    jb      .fail
    mov     (%rbx), %eax        # load dword
    cmp     $TLV_MAGIC, %eax
    jne     .fail

    # Header after magic: ver(u16), sig_alg(u16), hdr_len(u16), reserved(u16)
    cmp     $12, %r12
    jb      .fail
    # Load header length (offset 8..9)
    movzwl  8(%rbx), %r13d      # hdr_len
    mov     %r13, %r14          # hdr_len in r14
    # Bounds check header
    cmp     %r12, %r14
    ja      .fail
    cmp     $16, %r14           # minimum header length
    jb      .fail

    # Initialize outputs
    xor     %rax, %rax
    movq    %rax, manifest_container_count(%rip)

    # TLV scan starts at hdr_len
    mov     %rbx, %rdi
    add     %r14, %rdi          # rdi = p

    mov     %r12, %rcx
    sub     %r14, %rcx          # rcx = remaining

.scan:
    # End if no remaining
    test    %rcx, %rcx
    jz      .ok
    # Need at least TLV header
    cmp     $TLV_HDR_SIZE, %rcx
    jb      .fail

    # Read T and L
    movzwl  (%rdi), %eax        # T
    movzwl  2(%rdi), %edx       # L

    # Move to value start, update remaining
    lea     4(%rdi), %r8        # val ptr

    # Bounds check value
    mov     %rcx, %r9
    sub     $TLV_HDR_SIZE, %r9
    cmp     %r9, %rdx
    ja      .fail

    # Switch on T
    cmp     $T_BUILD_UUID, %eax
    je      .t_build_uuid
    cmp     $T_BRIDGE_IP4, %eax
    je      .t_bridge
    cmp     $T_EGRESS_NAT, %eax
    je      .t_egress
    jmp     .t_skip

.t_build_uuid:
    cmp     $16, %edx
    jne     .fail
    lea     manifest_build_uuid(%rip), %r10
    # copy 16 bytes
    mov     0(%r8), %rax
    mov     %rax, 0(%r10)
    mov     8(%r8), %rax
    mov     %rax, 8(%r10)
    jmp     .t_advance

.t_bridge:
    cmp     $5, %edx
    jne     .fail
    # Pack u32 ip (LE) in low bits and prefix in next byte of manifest_bridge_ip4
    mov     0(%r8), %eax        # ip
    movzbq  4(%r8), %r9         # prefix
    mov     %rax, %r10          # zero extend
    or      %r9, %r10
    shl     $32, %r10
    shr     $32, %r10           # keep lower 40 bits in reg (stored in quad)
    mov     %r10, manifest_bridge_ip4(%rip)
    jmp     .t_advance

.t_egress:
    # Currently ignored; keep for policy
    jmp     .t_advance

.t_skip:
    # Unknown tag: skip safely
    jmp     .t_advance

.t_advance:
    # Advance p by TLV_HDR_SIZE + L; decrease remaining
    lea     4(%rdi,%rdx), %rdi
    lea     -4(%rcx), %rcx
    sub     %rdx, %rcx
    jmp     .scan

.ok:
    mov     $1, %rax
    jmp     .out

.fail:
    xor     %rax, %rax

.out:
    pop     %r14
    pop     %r13
    pop     %r12
    pop     %rbx
    ret
