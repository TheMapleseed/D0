# Compiler and linker
AS := nasm
LD := ld

# Flags
ASFLAGS := -f elf64 -g -F dwarf
LDFLAGS := -nostdlib -n

# Directories
BUILDDIR := build
SRCDIR := .

# Sources
SOURCES := $(wildcard *.s)
OBJECTS := $(SOURCES:%.s=$(BUILDDIR)/%.o)

# Output
KERNEL := $(BUILDDIR)/kernel.elf
IMAGE := $(BUILDDIR)/live_system.img

# Default target
all: $(IMAGE)

# Create build directory
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

# Compile
$(BUILDDIR)/%.o: %.s | $(BUILDDIR)
	$(AS) $(ASFLAGS) $< -o $@

# Link
$(KERNEL): $(OBJECTS)
	$(LD) $(LDFLAGS) -T linker.ld -o $@ $^

# Create bootable image
$(IMAGE): $(KERNEL)
	dd if=/dev/zero of=$@ bs=1M count=64
	dd if=$< of=$@ conv=notrunc

# Clean
clean:
	rm -rf $(BUILDDIR)

# Verify
verify: $(KERNEL)
	objdump -d $< > $(BUILDDIR)/kernel.dump

# Debug info
debug: $(KERNEL)
	objdump -x $<

.PHONY: all clean verify debug 