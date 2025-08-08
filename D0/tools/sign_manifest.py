#!/usr/bin/env python3
import sys
try:
    from nacl.signing import SigningKey
    from nacl.encoding import HexEncoder
except Exception as e:
    print('error: PyNaCl is required (pip install pynacl)')
    sys.exit(1)

def main():
    if len(sys.argv) != 4:
        print(f"usage: {sys.argv[0]} <privkey-hex> <in.tlv> <out.sig>")
        sys.exit(1)
    priv_hex, in_tlv, out_sig = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        sk = SigningKey(priv_hex, encoder=HexEncoder)
    except Exception:
        print('error: invalid private key hex')
        sys.exit(2)
    with open(in_tlv, 'rb') as f:
        data = f.read()
    sig = sk.sign(data).signature
    with open(out_sig, 'wb') as f:
        f.write(sig)

if __name__ == '__main__':
    main()
