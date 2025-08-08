# Modern Clang toolchain with latest standards
CC := clang
AS := clang
LD := clang

# Modern flags for Intel processors with security features
CFLAGS := -target x86_64-unknown-linux-gnu -march=native -mtune=native -O3 -fPIC -fstack-protector-strong -D_FORTIFY_SOURCE=2
ASFLAGS := -target x86_64-unknown-linux-gnu -march=native -mtune=native -fPIC -fstack-protector-strong
LDFLAGS := -nostdlib -n -static -Wl,-z,relro,-z,now -Wl,--as-needed

# Directories
BUILDDIR := build
SRCDIR := .

# Sources with modern dependency order
SOURCES := $(wildcard *.s)
OBJECTS := $(SOURCES:%.s=$(BUILDDIR)/%.o)

# Output
KERNEL := $(BUILDDIR)/kernel.elf
IMAGE := $(BUILDDIR)/live_system.img
BUILD_UUID := $(shell [ -f $(BUILDDIR)/BUILD_UUID ] && cat $(BUILDDIR)/BUILD_UUID || echo unknown)

# Default target
all: $(IMAGE)

# Create build directory
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Modern compilation with Clang
$(BUILDDIR)/%.o: %.s | $(BUILDDIR)
	$(CC) $(ASFLAGS) -c $< -o $@

# Modern linking with Clang
$(KERNEL): $(OBJECTS)
	$(LD) $(LDFLAGS) -T linker.ld -o $@ $^
	@# Emit UUID-suffixed immutable artifact if BUILD_UUID is present
	@[ "$(BUILD_UUID)" != "unknown" ] && cp -f $@ $(BUILDDIR)/kernel-$(BUILD_UUID).elf || true

# Create bootable image
$(IMAGE): $(KERNEL)
	dd if=/dev/zero of=$@ bs=1M count=64
	dd if=$< of=$@ conv=notrunc

# Clean
clean:
	rm -rf $(BUILDDIR)

# Modern verification with security checks
verify: $(KERNEL)
	objdump -d $< > $(BUILDDIR)/kernel.dump
	@echo "Checking for modern SIMD instructions..."
	@grep -q "vmovups\|vaddps\|vmulps" $(BUILDDIR)/kernel.dump && echo "✓ Modern SIMD detected" || echo "⚠ No modern SIMD found"
	@echo "Checking for modern alignment..."
	@grep -q "\.align 64\|\.p2align 6" $(BUILDDIR)/kernel.dump && echo "✓ Modern alignment detected" || echo "⚠ Legacy alignment found"

# Debug info
debug: $(KERNEL)
	objdump -x $<

# Security analysis
security: $(KERNEL)
	@echo "Performing security analysis..."
	@objdump -d $< | grep -E "(ret|call|jmp)" | head -20
	@echo "Checking for stack protection..."
	@objdump -d $< | grep -q "stack_chk" && echo "✓ Stack protection enabled" || echo "⚠ No stack protection"

.PHONY: all clean verify debug security 