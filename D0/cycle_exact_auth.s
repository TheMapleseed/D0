.code64
.global init_cycle_auth, generate_phase_cert

# Clock Phase Constants
.set PHASE_UP,        0    # Clock rising edge
.set PHASE_DOWN,      1    # Clock falling edge
.set CYCLE_MASK,      0xFFFFFFFFFFFFFFFF
.set PHASE_BITS,      2    # Bits for phase tracking

# Cycle Structure
.struct 0
CYCLE_TIMESTAMP: .quad 0    # Base timestamp
CYCLE_PHASE:     .quad 0    # Current phase
CYCLE_COUNT:     .quad 0    # Cycles from edge
CYCLE_VARIANCE:  .quad 0    # Measured variance
CYCLE_SIZE:

# Get exact cycle position
get_cycle_phase:
    push    %rbx
    push    %r12
    
    # Get precise cycle count with phase
    rdtsc
    shl     $32, %rdx
    or      %rax, %rdx
    mov     %rdx, %rbx
    
    mfence              # Memory barrier for precise timing
    rdtsc              # Second reading for edge detection
    shl     $32, %rdx
    or      %rax, %rdx
    
    # Calculate phase
    sub     %rbx, %rdx
    test    $1, %rdx
    setz    %al        # AL = 1 if rising edge
    
    # Get cycles from edge
    mov     %rbx, %rdi
    call    calculate_edge_distance
    mov     %rax, %r12
    
    # Package result
    shl     $63, %rax  # Phase in high bit
    or      %r12, %rax # Cycles in lower bits
    
    pop     %r12
    pop     %rbx
    ret

# Calculate distance from clock edge
calculate_edge_distance:
    push    %rbx
    mov     %rdi, %rbx
    
    # Get base clock frequency
    call    get_base_frequency
    
    # Calculate cycle position
    xor     %rdx, %rdx
    div     %rbx
    
    # Account for variance
    call    apply_variance_correction
    
    pop     %rbx
    ret

# Generate phase-aware certificate
generate_phase_cert:
    push    %rbx
    
    # Get exact cycle position
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Create certificate with phase info
    mov     %rbx, %rdi
    call    create_phase_certificate
    
    pop     %rbx
    ret

# Verify phase-based certificate
verify_phase_cert:
    push    %rbx
    push    %r12
    
    # Get current phase
    call    get_cycle_phase
    mov     %rax, %rbx
    
    # Compare with certificate
    mov     %rdi, %r12    # Certificate
    call    compare_phase_timing
    
    pop     %r12
    pop     %rbx
    ret

# Data Section
.section .data
.align 8
cycle_data:
    .skip CYCLE_SIZE * 256    # Cycle tracking data

variance_table:
    .quad 0    # Variance measurements
    .quad 0    # Correction factors
    .quad 0    # Phase history

# BSS Section
.section .bss
.align 4096
phase_history:
    .skip 4096    # Phase tracking history 