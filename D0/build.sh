#!/bin/bash

# Build configuration
ARCH="x86_64"
FORMAT="elf64"
OUTDIR="build"
BOOTIMG="live_system.img"

# Assembler and linker
AS="nasm"
LD="ld"

# Flags
ASFLAGS="-f ${FORMAT} -g -F dwarf"
LDFLAGS="-nostdlib -n"

# Source files in order of dependency
SOURCES=(
    "Live0.s"
    "neural_mutate.s"
    "memory_regions.s"
    "binary_healing.s"
    "sync.s"
    "device_manager.s"
    "kernel.s"
    "io_manager.s"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Create build directory
mkdir -p ${OUTDIR}

# Function to check last command status
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: $1 failed${NC}"
        exit 1
    fi
}

# Clean previous build
clean() {
    rm -rf ${OUTDIR}/*
    echo "Cleaned build directory"
}

# Compile individual files
compile() {
    local source=$1
    local object="${OUTDIR}/${source%.s}.o"
    echo "Compiling ${source}..."
    ${AS} ${ASFLAGS} ${source} -o ${object}
    check_status "Compilation of ${source}"
}

# Link objects
link() {
    local objects=""
    for source in "${SOURCES[@]}"; do
        objects="${objects} ${OUTDIR}/${source%.s}.o"
    done
    
    echo "Linking..."
    ${LD} ${LDFLAGS} -T linker.ld -o ${OUTDIR}/kernel.elf ${objects}
    check_status "Linking"
}

# Create bootable image
create_image() {
    echo "Creating bootable image..."
    dd if=/dev/zero of=${OUTDIR}/${BOOTIMG} bs=1M count=64
    check_status "Image creation"
    
    dd if=${OUTDIR}/kernel.elf of=${OUTDIR}/${BOOTIMG} conv=notrunc
    check_status "Kernel copying"
}

# Verify build
verify() {
    echo "Verifying build..."
    # Add verification steps here
    objdump -d ${OUTDIR}/kernel.elf > ${OUTDIR}/kernel.dump
    check_status "Verification"
}

# Main build process
main() {
    echo -e "${GREEN}Starting build process...${NC}"
    
    # Clean previous build
    clean
    
    # Compile each source file
    for source in "${SOURCES[@]}"; do
        compile ${source}
    done
    
    # Link objects
    link
    
    # Create bootable image
    create_image
    
    # Verify build
    verify
    
    echo -e "${GREEN}Build completed successfully${NC}"
}

# Run build
main