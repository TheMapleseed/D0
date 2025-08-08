# Use a modern base image with latest build tools
FROM ubuntu:24.04 AS builder

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install modern Clang toolchain and security tools
RUN apt-get update && apt-get install -y \
    clang-18 \
    lld-18 \
    llvm-18 \
    make \
    qemu-system-x86 \
    binutils \
    git \
    security-checker \
    && rm -rf /var/lib/apt/lists/*

# Set modern Clang as default
RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100 \
    && update-alternatives --install /usr/bin/lld lld /usr/bin/lld-18 100

# Create working directory
WORKDIR /build

# Copy source files
COPY . .

# Build the system with modern Clang
RUN chmod +x build.sh && \
    ./build.sh

# Create test environment with modern tools
FROM ubuntu:24.04 AS tester

# Install modern QEMU and security tools
RUN apt-get update && apt-get install -y \
    qemu-system-x86 \
    security-checker \
    && rm -rf /var/lib/apt/lists/*

# Copy built system from builder
COPY --from=builder /build/build/live_system.img /test/
COPY --from=builder /build/deploy.sh /test/
COPY --from=builder /build/neural_state.bin /test/

WORKDIR /test

# Make deploy script executable
RUN chmod +x deploy.sh

# Default command for testing with security checks
CMD ["./deploy.sh", "test"] 