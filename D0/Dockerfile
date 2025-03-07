# Use a base image with necessary build tools
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    nasm \
    make \
    gcc \
    qemu-system-x86 \
    binutils \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /build

# Copy source files
COPY . .

# Build the system
RUN chmod +x build.sh && \
    ./build.sh

# Create test environment
FROM ubuntu:22.04 AS tester

# Install QEMU for testing
RUN apt-get update && apt-get install -y \
    qemu-system-x86 \
    && rm -rf /var/lib/apt/lists/*

# Copy built system from builder
COPY --from=builder /build/build/live_system.img /test/
COPY --from=builder /build/deploy.sh /test/
COPY --from=builder /build/neural_state.bin /test/

WORKDIR /test

# Make deploy script executable
RUN chmod +x deploy.sh

# Default command for testing
CMD ["./deploy.sh", "test"] 