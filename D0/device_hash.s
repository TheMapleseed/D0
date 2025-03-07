.code64
.global init_device_hash

# Device Hash Structure
.struct 0
HASH_DEVICE:     .quad 0    # Device identifier
HASH_SIGNATURE:  .quad 0    # Unique device signature
HASH_MAPPING:    .quad 0    # Kernel mapping
HASH_VERIFY:     .quad 0    # Verification data
HASH_SIZE:

# This persists across reboots
.section .device_store
.align 4096
device_hash_table:
    .skip HASH_SIZE * MAX_DEVICES 