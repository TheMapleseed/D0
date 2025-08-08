#!/bin/bash

# Modern D0 Build Script with Enhanced Security
# Updated for Clang 18+ and modern Intel security features

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build configuration
FORMAT="elf64"
OUTDIR="build"
KERNEL="kernel.elf"
SOURCES=(
    "Live0.s"
    "neural_mutate.s"
    "memory_regions.s"
    "binary_healing.s"
    "sync.s"
    "device_manager.s"
    "kernel.s"
    "io_manager.s"
    "perf_opt.s"
    "net_common.s"
    "eth_driver.s"
    "vm_hypervisor.s"
    "security_model.s"
    "memory_layout.s"
    "time_based_auth.s"
    "h2_config.s"
    "net_integration.s"
    "manifest_tlv.s"
    "vmx_init.s"
    "ept.s"
    "virtio_backend.s"
    "virtio_mmio.s"
    "vmcs.s"
    "vmcs_controls.s"
    "vmcs_state.s"
    "vm_launch.s"
    "apic_virtualization.s"
    "virtio_queue.s"
    "network_bridge.s"
    "uefi_loader_stub.s"
)
C_SOURCES=(
    "ed25519_verify.c"
)

# Optionally compile vendored Ed25519 (orlp/ed25519) if present
if [ -f "third_party/ed25519/ed25519.c" ] && [ -f "third_party/ed25519/ed25519.h" ]; then
    C_SOURCES+=("third_party/ed25519/ed25519.c")
    CFLAGS+=" -DHAVE_ORLP_ED25519"
fi

# Modern Clang toolchain
CC="clang"
AS="clang"
LD="clang"

# Modern flags for Intel processors with enhanced security
CFLAGS="-target x86_64-unknown-linux-gnu -march=native -mtune=native -O3 -fPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fcf-protection=full -fstack-clash-protection -ffreestanding -fno-builtin"
ASFLAGS="-target x86_64-unknown-linux-gnu -march=native -mtune=native -fPIC -fstack-protector-strong -fcf-protection=full"
LDFLAGS="-nostdlib -n -static -Wl,-z,relro,-z,now -Wl,--as-needed -Wl,-z,stack-size=8388608 -Wl,-z,noexecstack -Wl,-z,separate-code"

# Security verification tools
SECURITY_TOOLS=(
    "objdump"
    "readelf"
    "nm"
    "strings"
)

# Function to check if command exists
check_command() {
    case "$1" in
        readelf)
            if command -v readelf >/dev/null 2>&1 || command -v llvm-readelf >/dev/null 2>&1 || command -v eu-readelf >/dev/null 2>&1; then
                return 0
            fi
            ;;
        objdump)
            if command -v objdump >/dev/null 2>&1 || command -v llvm-objdump >/dev/null 2>&1; then
                return 0
            fi
            ;;
        *)
            if command -v "$1" >/dev/null 2>&1; then
                return 0
            fi
            ;;
    esac
    echo -e "${RED}Error: $1 (or compatible) is not installed${NC}"
    exit 1
}

# Tool shims to prefer LLVM equivalents when GNU tools are missing
objdump() {
    if command -v /usr/bin/objdump >/dev/null 2>&1 || command -v objdump >/dev/null 2>&1; then
        command objdump "$@"
    elif command -v llvm-objdump >/dev/null 2>&1; then
        llvm-objdump "$@"
    else
        return 127
    fi
}

readelf() {
    if command -v /usr/bin/readelf >/dev/null 2>&1 || command -v readelf >/dev/null 2>&1; then
        command readelf "$@"
    elif command -v llvm-readelf >/dev/null 2>&1; then
        llvm-readelf "$@"
    elif command -v eu-readelf >/dev/null 2>&1; then
        eu-readelf "$@"
    else
        return 127
    fi
}

# UUIDv7 (with fallbacks) for build identity
generate_build_uuid() {
    # Try Python uuid6 (uuid7 support)
    if command -v python3 >/dev/null 2>&1; then
        UUID7=$(python3 - "$@" << 'PY'
import os, sys
try:
    import uuid6  # pip install uuid6
    print(str(uuid6.uuid7()))
    sys.exit(0)
except Exception:
    pass
import uuid
print(str(uuid.uuid4()))  # fallback v4
PY
)
        if [ -n "$UUID7" ]; then
            echo "$UUID7"
            return 0
        fi
    fi
    # Fallback to uuidgen (v4)
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
        return 0
    fi
    # Last resort: timestamp + random (not RFC9562)
    echo "$(date +%s)-$RANDOM$RANDOM$RANDOM"
}

# Function to check status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1 completed successfully${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# Function to perform security analysis
security_analysis() {
    local binary=$1
    echo -e "${BLUE}Performing security analysis on $binary...${NC}"
    
    # Check for stack protection
    if objdump -d $binary | grep -q "stack_chk"; then
        echo -e "${GREEN}✓ Stack protection enabled${NC}"
    else
        echo -e "${YELLOW}⚠ Stack protection not detected${NC}"
    fi
    
    # Check for executable stack
    if readelf -l $binary | grep -q "GNU_STACK.*RWE"; then
        echo -e "${RED}✗ Executable stack detected${NC}"
    else
        echo -e "${GREEN}✓ Non-executable stack${NC}"
    fi
    
    # Check for RELRO
    if readelf -d $binary | grep -q "BIND_NOW"; then
        echo -e "${GREEN}✓ Full RELRO enabled${NC}"
    else
        echo -e "${YELLOW}⚠ Partial or no RELRO${NC}"
    fi
    
    # Check for PIE
    if readelf -h $binary | grep -q "Type.*DYN"; then
        echo -e "${GREEN}✓ Position Independent Executable${NC}"
    else
        echo -e "${YELLOW}⚠ Not a PIE${NC}"
    fi
    
    # Check for hard-coded strings
    if strings $binary | grep -q "password\|secret\|key\|token"; then
        echo -e "${RED}✗ Potential hard-coded secrets detected${NC}"
    else
        echo -e "${GREEN}✓ No obvious hard-coded secrets${NC}"
    fi
    
    # Check for modern instructions
    if objdump -d $binary | grep -q "vmovups\|vaddps\|vmulps"; then
        echo -e "${GREEN}✓ Modern SIMD instructions detected${NC}"
    else
        echo -e "${YELLOW}⚠ No modern SIMD instructions found${NC}"
    fi
    
    # Check for proper alignment
    if objdump -d $binary | grep -q "\.align 64\|\.p2align 6"; then
        echo -e "${GREEN}✓ Modern memory alignment detected${NC}"
    else
        echo -e "${YELLOW}⚠ Legacy alignment patterns found${NC}"
    fi
}

# Function to verify cryptographic implementations
verify_crypto() {
    local binary=$1
    echo -e "${BLUE}Verifying cryptographic implementations...${NC}"
    
    # Check for hardware entropy usage
    if objdump -d $binary | grep -q "rdrand\|rdtsc"; then
        echo -e "${GREEN}✓ Hardware entropy sources detected${NC}"
    else
        echo -e "${YELLOW}⚠ No hardware entropy sources found${NC}"
    fi
    
    # Check for secure memory operations
    if objdump -d $binary | grep -q "clflush\|mfence\|sfence"; then
        echo -e "${GREEN}✓ Secure memory operations detected${NC}"
    else
        echo -e "${YELLOW}⚠ No secure memory operations found${NC}"
    fi
    
    # Check for bounds checking
    if objdump -d $binary | grep -q "cmp.*jae\|cmp.*jbe"; then
        echo -e "${GREEN}✓ Bounds checking detected${NC}"
    else
        echo -e "${YELLOW}⚠ Limited bounds checking found${NC}"
    fi
}

# Function to check for common vulnerabilities
vulnerability_scan() {
    local binary=$1
    echo -e "${BLUE}Scanning for common vulnerabilities...${NC}"
    
    # Check for buffer overflow patterns
    if objdump -d $binary | grep -q "mov.*\[.*\].*\[.*\]"; then
        echo -e "${RED}✗ Potential double indirection detected${NC}"
    else
        echo -e "${GREEN}✓ No obvious double indirection patterns${NC}"
    fi
    
    # Check for format string vulnerabilities
    if objdump -d $binary | grep -q "printf\|sprintf\|fprintf"; then
        echo -e "${YELLOW}⚠ Format string functions detected - review needed${NC}"
    else
        echo -e "${GREEN}✓ No format string functions detected${NC}"
    fi
    
    # Check for integer overflow patterns
    if objdump -d $binary | grep -q "add.*jo\|add.*jc"; then
        echo -e "${GREEN}✓ Integer overflow checks detected${NC}"
    else
        echo -e "${YELLOW}⚠ Limited integer overflow protection${NC}"
    fi
}

# Main build process
main() {
    echo -e "${BLUE}Building D0 with enhanced security features...${NC}"
    
    # Generate/record build UUID (v7 preferred)
    BUILD_UUID=$(generate_build_uuid)
    mkdir -p "$OUTDIR"
    echo "$BUILD_UUID" > "$OUTDIR/BUILD_UUID"
    echo -e "${YELLOW}Build UUID: ${BUILD_UUID}${NC}"

    # Check prerequisites
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    for tool in "${SECURITY_TOOLS[@]}"; do
        check_command $tool
    done
    check_command $CC
    check_status "Prerequisites check"
    
    # Create output directory
    mkdir -p $OUTDIR
    check_status "Create output directory"
    
    # Compile assembly sources
    echo -e "${YELLOW}Compiling assembly sources...${NC}"
    for source in "${SOURCES[@]}"; do
        if [ -f "$source" ]; then
            object="${OUTDIR}/$(basename $source .s).o"
            preprocessed="${OUTDIR}/$(basename $source .s).pp.s"
            # Preprocess .struct into portable .set offsets
            if grep -q "^\\.struct" "$source"; then
                python3 tools/preprocess_structs.py "$source" "$preprocessed"
                check_status "Preprocess $source"
                echo "AS $source (preprocessed)"
                ${CC} ${ASFLAGS} -c "$preprocessed" -o "$object"
            else
                echo "AS $source"
                ${CC} ${ASFLAGS} -c $source -o $object
            fi
            check_status "Compile $source"
        else
            echo -e "${YELLOW}Warning: $source not found${NC}"
        fi
    done

    # Compile C sources (freestanding)
    echo -e "${YELLOW}Compiling C sources...${NC}"
    for csrc in "${C_SOURCES[@]}"; do
        if [ -f "$csrc" ]; then
            obj="${OUTDIR}/$(basename $csrc .c).o"
            echo "CC $csrc"
            ${CC} ${CFLAGS} -c "$csrc" -o "$obj"
            check_status "Compile $csrc"
        fi
    done
    
    # Link kernel
    echo -e "${YELLOW}Linking kernel...${NC}"
    objects=()
    for source in "${SOURCES[@]}"; do
        if [ -f "$source" ]; then
            object="${OUTDIR}/$(basename $source .s).o"
            if [ -f "$object" ]; then
                objects+=("$object")
            fi
        fi
    done
    for csrc in "${C_SOURCES[@]}"; do
        obj="${OUTDIR}/$(basename $csrc .c).o"
        if [ -f "$obj" ]; then
            objects+=("$obj")
        fi
    done
    
    ${LD} ${LDFLAGS} -T linker.ld -o ${OUTDIR}/${KERNEL} "${objects[@]}"
    check_status "Link kernel"

    # Also emit UUID-suffixed kernel for immutable deployments
    cp -f "${OUTDIR}/${KERNEL}" "${OUTDIR}/kernel-${BUILD_UUID}.elf"

    # Modern verification with enhanced security checks
    echo -e "${YELLOW}Verifying build with enhanced security checks...${NC}"
    
    # Basic verification
    objdump -d ${OUTDIR}/${KERNEL} > ${OUTDIR}/kernel.dump
    check_status "Disassembly"
    
    # Security analysis
    security_analysis ${OUTDIR}/${KERNEL}
    
    # Cryptographic verification
    verify_crypto ${OUTDIR}/${KERNEL}
    
    # Vulnerability scan
    vulnerability_scan ${OUTDIR}/${KERNEL}
    
    # Check for modern instruction usage
    if grep -q "vmovups\|vaddps\|vmulps" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Modern SIMD instructions detected${NC}"
    else
        echo -e "${YELLOW}⚠ No modern SIMD instructions found${NC}"
    fi
    
    # Check for proper alignment
    if grep -q "\.align 64\|\.p2align 6" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Modern memory alignment detected${NC}"
    else
        echo -e "${YELLOW}⚠ Legacy alignment patterns found${NC}"
    fi
    
    # Check for CFI directives
    if grep -q "\.cfi_" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ CFI directives detected${NC}"
    else
        echo -e "${YELLOW}⚠ No CFI directives found${NC}"
    fi
    
    # Check for secure memory operations
    if grep -q "clflush\|mfence\|sfence" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Secure memory operations detected${NC}"
    else
        echo -e "${YELLOW}⚠ No secure memory operations found${NC}"
    fi
    
    # Check for bounds checking
    if grep -q "cmp.*jae\|cmp.*jbe" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Bounds checking detected${NC}"
    else
        echo -e "${YELLOW}⚠ Limited bounds checking found${NC}"
    fi
    
    # Check for hardware entropy
    if grep -q "rdrand\|rdtsc" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Hardware entropy sources detected${NC}"
    else
        echo -e "${YELLOW}⚠ No hardware entropy sources found${NC}"
    fi
    
    # Check for input validation
    if grep -q "validate_input\|check_bounds" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Input validation detected${NC}"
    else
        echo -e "${YELLOW}⚠ Limited input validation found${NC}"
    fi
    
    # Check for secure networking
    if grep -q "setup_bridge_networking\|setup_macvlan_networking" ${OUTDIR}/kernel.dump; then
        echo -e "${GREEN}✓ Secure networking implementations detected${NC}"
    else
        echo -e "${YELLOW}⚠ Limited secure networking found${NC}"
    fi
    
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo -e "${BLUE}Build UUID: ${BUILD_UUID}${NC}"
    echo -e "${BLUE}Kernel binary: ${OUTDIR}/${KERNEL}${NC}"
    echo -e "${BLUE}Immutable kernel: ${OUTDIR}/kernel-${BUILD_UUID}.elf${NC}"
    echo -e "${BLUE}Disassembly: ${OUTDIR}/kernel.dump${NC}"
}

# Run main function
main "$@"