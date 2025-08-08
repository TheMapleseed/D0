# UEFI Loader Build and Deployment

## Overview

The UEFI loader (`uefi_loader.c`) reads manifest files from the ESP and prepares a D0 handoff block for the kernel.

## Build Requirements

### EDK2 (recommended)
```bash
# Install EDK2
git clone https://github.com/tianocore/edk2.git
cd edk2
make -C BaseTools
source edksetup.sh

# Build the UEFI app
build -p D0/D0/D0Uefi.dsc -a X64
```

### GNU-EFI (alternative)
```bash
# Install gnu-efi
sudo apt install gnu-efi  # Ubuntu/Debian
brew install gnu-efi      # macOS

# Build
make -f Makefile.uefi
```

## Expected ESP Layout

```
/EFI/BOOT/
├── BOOTX64.EFI          # UEFI bootloader
├── manifest.tlv          # TLV manifest (from tools/pack_manifest.py)
├── manifest.sig          # Ed25519 signature (from tools/sign_manifest.py)
└── VM/                   # Container disk images
    ├── container1.img
    └── container2.img
```

## D0 Handoff Block

The UEFI loader writes a handoff structure at physical address `0x70000`:

```c
typedef struct {
    uint32_t magic;        // 'D0HD' (0x44484F30)
    uint32_t version;      // 0x00010000
    uint64_t manifest_addr;
    uint64_t manifest_len;
    uint64_t manifest_sig_addr;
    uint64_t manifest_sig_len;
} d0_handoff_t;
```

## Kernel Integration

The kernel's `uefi_loader_populate_manifest()` reads this handoff block and populates the `manifest_*` global variables for verification and parsing.

## Security Notes

- Manifest and signature files must be present on ESP
- Ed25519 verification happens in-kernel
- Handoff block is cleared after reading
- All memory allocations use EfiLoaderData type
