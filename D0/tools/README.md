# D0 Deploy Tools

This directory holds deploy-side tools (run on the deployment device), not in-kernel code.

- `manifest.proto`: protobuf schema for the deploy manifest. Build a protobuf binary, then convert to the kernel TLV format and sign.
- `pack_manifest` (to be implemented): converts protobuf `Manifest` to a strict TLV with magic `D0MF`, a header, and typed values. All lengths are validated; little-endian fields.
- `sign_manifest` (to be implemented): Ed25519 signs the TLV; the kernel holds the public key and verifies at boot.

Output artifacts should be copied to the ESP:
- `EFI/BOOT/BOOTX64.EFI`
- `manifest-<UUID>.tlv`, `manifest-<UUID>.sig`
- `VM/<name>-<UUID>.img`

Vendored crypto:
- If `third_party/ed25519` contains `ed25519.c` and `ed25519.h` from `orlp/ed25519`, the build enables in-kernel Ed25519 verification by compiling these sources and defining `HAVE_ORLP_ED25519`.
