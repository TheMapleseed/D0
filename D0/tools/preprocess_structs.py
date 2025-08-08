#!/usr/bin/env python3
import re
import sys

def preprocess_structs(src: str) -> str:
    out_lines = []
    in_struct = False
    cur_off = 0
    # Patterns
    re_struct = re.compile(r"^\s*\.struct\s+(\d+)\s*$")
    re_field_quad = re.compile(r"^\s*([A-Za-z_][\w]*)\s*:\s*\.quad\s+0\s*$")
    re_size_label = re.compile(r"^\s*([A-Za-z_][\w]*)\s*:\s*$")

    for line in src.splitlines():
        m = re_struct.match(line)
        if m:
            in_struct = True
            cur_off = int(m.group(1))
            continue

        if in_struct:
            mf = re_field_quad.match(line)
            if mf:
                name = mf.group(1)
                out_lines.append(f".set {name}, {cur_off}")
                cur_off += 8
                continue
            ms = re_size_label.match(line)
            if ms:
                name = ms.group(1)
                out_lines.append(f".set {name}, {cur_off}")
                in_struct = False
                continue
        # default
        out_lines.append(line)

    return "\n".join(out_lines) + "\n"

def main():
    if len(sys.argv) != 3:
        print("usage: preprocess_structs.py <infile> <outfile>")
        sys.exit(2)
    with open(sys.argv[1], 'r') as f:
        src = f.read()
    out = preprocess_structs(src)
    with open(sys.argv[2], 'w') as f:
        f.write(out)

if __name__ == '__main__':
    main()


