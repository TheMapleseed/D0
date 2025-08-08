#!/usr/bin/env python3
import sys, struct, time

# Minimal proto decoder avoidance: expect a JSON-like manifest via stdin is out of scope.
# This packer expects a binary protobuf for d0.Manifest (see manifest.proto) and a small
# sidecar json for bridge_ip/prefix/egress to avoid pulling in full protobuf runtime.
# For now, accept a small textpb with key fields; future: replace with proper protobuf tooling.

# TLV constants
MAGIC = 0x444f4d46  # 'D0MF' little endian when packed as LE dword

T_BRIDGE_IP4  = 0x0001  # u32 ip + u8 prefix
T_EGRESS_NAT  = 0x0002  # u8
T_BUILD_UUID  = 0x0003  # 16 bytes

# Header: magic (4), ver(u16), sig_alg(u16), hdr_len(u16), reserved(u16)
# Then TLVs starting at hdr_len

def le16(x):
    return struct.pack('<H', x)

def le32(x):
    return struct.pack('<I', x)

def pack_tlv(tag, val_bytes):
    return le16(tag) + le16(len(val_bytes)) + val_bytes


def parse_textpb(fp):
    # Extremely small parser for a constrained input subset:
    # build_uuid: 16-byte hex (no dashes)
    # bridge_ip4: dotted quad
    # prefix: int
    # egress_nat: true/false
    data = {"build_uuid": None, "bridge_ip4": None, "prefix": None, "egress_nat": False}
    for line in fp:
        s = line.strip()
        if s.startswith('build_uuid:'):
            v = s.split(':',1)[1].strip().strip('"').replace('-', '')
            if len(v) == 32:
                data['build_uuid'] = bytes.fromhex(v)
        elif s.startswith('bridge_ip4:'):
            v = s.split(':',1)[1].strip().strip('"')
            parts = v.split('.')
            if len(parts)==4:
                data['bridge_ip4'] = bytes([int(parts[0]),int(parts[1]),int(parts[2]),int(parts[3])])
        elif s.startswith('prefix:'):
            v = int(s.split(':',1)[1].strip())
            data['prefix'] = v & 0xff
        elif s.startswith('egress_nat:'):
            v = s.split(':',1)[1].strip().lower()
            data['egress_nat'] = (v in ('1','true','yes','on'))
    return data


def main():
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <textpb_manifest> <out.tlv>")
        sys.exit(1)
    textpb, out_tlv = sys.argv[1], sys.argv[2]
    with open(textpb, 'r', encoding='utf-8') as f:
        m = parse_textpb(f)
    # Validate
    if m['build_uuid'] is None or len(m['build_uuid']) != 16:
        print('error: build_uuid missing or invalid')
        sys.exit(2)
    if m['bridge_ip4'] is None or m['prefix'] is None:
        print('error: bridge_ip4/prefix missing')
        sys.exit(2)
    # Build header
    ver = 1
    sig_alg = 1  # placeholder
    # Placeholder header length = 16 bytes after magic: ver,u16 sig_alg,u16 hdr_len,u16 reserved,u16
    hdr_len = 16
    reserved = 0
    buf = bytearray()
    buf += le32(MAGIC)
    buf += le16(ver)
    buf += le16(sig_alg)
    buf += le16(hdr_len)
    buf += le16(reserved)
    # TLVs
    tlvs = bytearray()
    tlvs += pack_tlv(T_BUILD_UUID, m['build_uuid'])
    tlvs += pack_tlv(T_BRIDGE_IP4, m['bridge_ip4'] + bytes([m['prefix']]))
    tlvs += pack_tlv(T_EGRESS_NAT, bytes([1 if m['egress_nat'] else 0]))
    buf += tlvs
    with open(out_tlv, 'wb') as f:
        f.write(buf)

if __name__ == '__main__':
    main()
