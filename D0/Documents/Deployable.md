# D0 Deployable (Bare‑Metal Hypervisor)

A concise, implementation‑ready feature set and gap‑closure plan for pivoting D0 into an immutable, bare‑metal, OCI‑compatible system. Each deploy produces a new signed image; updates occur via reboot (no runtime management plane).

## 1) Current State (in tree)
- Kernel and init path: 64‑bit entry (`Live0.s`), CPU feature gating, verification chain.
- Memory/security: W^X model, ASLR scaffolding, stack protection flags, CFI usage, bounds‑checked secure allocators.
- Transport/network primitives: custom TCP/UDP stack (`vm_transport.s`), bridging scaffolding.
- Build: Clang/LLD, hardening flags, Dockerized toolchain; verification (`objdump`, checks).
- Docs: high‑level architecture and security notes.

Limits today
- No UEFI boot artifact; QEMU used for test boot.
- No VMX/EPT hypervisor, no virtio front/back‑ends.
- No human interface (no console/SSH), by design.
- Containers/runtime: scaffolding only; no OCI ingestion.

## 2) Target Architecture (pivot)
- Bare‑metal UEFI boot; D0 is the only OS.
- Type‑1 hypervisor (Intel VT‑x): VMXON, per‑VM VMCS, VM‑exit handler, EPT.
- Virtio devices: virtio‑blk (container rootfs), virtio‑net (vNIC per container).
- Static virtual L2 bridge; deterministic MAC/IP; no DHCP; optional egress NAT/policy.
- OCI compatibility at build‑time: convert OCI image + config.json → micro‑VM disk image; PID1 runs the workload (agentless).
- Immutable deploy: A/B ESP partitions; signed boot manifest + images; reboot to update; auto‑rollback on failure.
- Configuration authored as protobuf on deploy device → packed to TLV for kernel; signature (Ed25519) over TLV; kernel verifies before launch.
- UUIDv7 assigned per successful build and bound into signatures, filenames, manifest, and rollback metadata.

## 3) Feature Set (deliverables)
- UEFI Boot Image
  - PE/COFF `BOOTX64.EFI` for D0; ExitBootServices; paging/ACPI/APIC init.
- Hypervisor Core
  - VMX feature checks, IA32_FEATURE_CONTROL; VMXON; per‑VM VMCS; VM‑entry/exit; EPT (2M/1G when possible).
- Virtio Backend (host) + Frontend (guest contract)
  - virtio‑blk backends: queue handling, IRQ injection.
  - virtio‑net backends: RX/TX queues bridged to host switch.
- Static Virtual Network
  - Host bridge with fixed addressing; route/NAT policy; no L2 learning.
- OCI Build‑time Conversion Tooling (deploy device)
  - Unpack OCI image; apply `config.json`; assemble minimal rootfs; bake raw/ext4 disk image; deterministic fstab/init; embed user args/env/cwd.
- Manifest/Signing
  - Protobuf schema (deploy) → TLV (kernel); Ed25519 signatures; embedded public key in kernel; health/rollback strategy.
- Immutable A/B Layout
  - ESP_A/ESP_B with EFI, manifest, vm images; boot var flip, watchdog health, auto‑rollback.
- Observability (non‑interactive)
  - Structured boot logs to ring buffer; optional serial if enabled; per‑VM boot/result counters.

## 4) Build & Deploy Pipeline (immutable)
- Generate BUILD_UUID (UUIDv7) at start; export to pipeline.
- Build D0 → `BOOTX64-<UUIDv7>.EFI`.
- For each container target: OCI → `VM/<name>-<UUIDv7>.img`.
- Produce protobuf manifest; validate; pack to TLV; sign → `manifest-<UUIDv7>.{tlv,sig}`.
- Assemble A/B ESP images; label slots with UUIDv7; write to disk/USB; set UEFI boot order.
- Reboot target; kernel verifies signature → launches VMs per manifest.

## 5) Manifest (schema contract)
Author on deploy device; verify and pack for kernel.
- Header
  - `manifest_version`, `build_uuid` (16 bytes), `timestamp_ms`.
- Network
  - `bridge_ip4/cidr`, `egress_nat`.
- Containers[]
  - `name`, `vcpu`, `mem_mb`, `disk_path`, `mac(6)`, `ip4/cidr`, `gw4`, `routes[]`, `boot_order`, `health_timeout_s`.
- TLV on target
  - Little‑endian, fixed TIDs; strict bounds checking; unknown non‑critical tags ignored, critical tags cause fail‑closed.

## 6) Security Properties
- Immutable, no runtime management plane; no admin shell on host.
- W^X/ASLR/RELRO/CFI on host; strict input validation on parsers.
- Ed25519 signature over manifest TLV; public key baked in.
- UUIDv7 binds artifacts; last‑good UUID recorded for rollback.
- Per‑VM isolation via EPT; virtio queues validated; rate‑limited RX/TX.

## 7) Acceptance Criteria
- Boots on UEFI bare metal into D0 without QEMU.
- VMX/EPT enabled; at least one micro‑VM launched from manifest and PID1 executes the configured process.
- Static MAC/IP per VM; reachability and egress policy enforced.
- Full image update by swapping slots; auto‑rollback on health failure.
- Signature verification failures block boot (fail‑closed) and trigger rollback.

## 8) Implementation Plan (ordered, with status)
- [ ] UEFI boot path
  - [ ] PE/COFF image; ExitBootServices; paging/ACPI/MP/APIC.
- [ ] VMX/EPT hypervisor core
  - [ ] CPUID/feature MSRs; VMXON; VMCS set/VM‑entry; VM‑exit handler; EPT mapper.
- [ ] Virtio backends (host)
  - [ ] virtio‑blk: queue processing, IRQ; image attach.
  - [ ] virtio‑net: TX/RX queues; integration with host bridge.
- [ ] Static virtual switching
  - [ ] Bridge fabric; deterministic address assignment; NAT policy.
- [ ] Protobuf schema + packer (deploy device)
  - [ ] `manifest.proto`, validation; `pack_manifest` (proto→TLV).
  - [ ] `sign_manifest` (Ed25519); embed pubkey in kernel.
- [ ] OCI→VM image tool (deploy device)
  - [ ] Unpack layers; assemble rootfs; inject minimal init to exec config.json process; produce raw image.
- [ ] A/B ESP image maker
  - [ ] Assemble slots; label with UUIDv7; boot var flip utility; rollback marker.
- [ ] Kernel TLV parser + verifier
  - [ ] Ed25519 verify; strict TLV bounds; reject unknown critical; map to launch spec.
- [ ] VM launcher
  - [ ] Create VMCS/EPT per container; attach virtio‑blk/net; start; health timeout handling.
- [ ] Health & rollback
  - [ ] Boot health heuristic; last‑good UUIDv7; auto‑rollback logic.
- [ ] Validation
  - [ ] Bring‑up on two hardware SKUs; perf smoke; negative tests (bad sig, bad TLV, missing disk).

## 9) Test Strategy
- Unit: TLV parser, Ed25519 verify, EPT mapper, virtio queue handling.
- Integration: end‑to‑end boot from ESP; one VM networking; OCI conversion fidelity.
- Fault injection: corrupt signatures/TLV, queue overflow, EPT violations.
- Soak: reboot loops (update/rollback), per‑VM network churn, large I/O.

## 10) Risks & Mitigations
- VMX bring‑up complexity → stage on known‑good dev boards; add serial diag guard.
- Virtio correctness → start with minimal feature bits; fuzz queue descriptors.
- OCI fidelity → constrain supported config.json fields initially; document.
- Hardware variance → ACPI parsing fallback; limit initial platform matrix.

## 11) Out of Scope (for this pivot)
- Interactive host shell/SSH; in‑guest agent; dynamic runtime orchestration; GUI; dynamic IPAM.

## 12) Artifact Naming (UUIDv7)
- `EFI/BOOT/BOOTX64-<UUIDv7>.EFI`
- `manifest-<UUIDv7>.{tlv,sig}`
- `VM/<name>-<UUIDv7>.img`
- ESP slots labeled with `<UUIDv7>`; last‑good stored for rollback.

---
This document tracks the deployable feature set and remaining work to complete the bare‑metal, immutable, OCI‑compatible pivot for D0. Update the checkboxes as milestones land.
