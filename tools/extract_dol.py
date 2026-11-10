#!/usr/bin/env python3
"""Extract the monolithic boot DOL from a GameCube ISO using the disc header."""
from __future__ import annotations

import struct
import sys
from pathlib import Path

DISC_DOL_OFFSET = 0x420


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_dol.py <game.iso> <out.dol>")
        return 1
    iso = Path(sys.argv[1])
    out = Path(sys.argv[2])
    with iso.open("rb") as f:
        f.seek(DISC_DOL_OFFSET)
        dol_offset = struct.unpack(">I", f.read(4))[0]
        f.seek(dol_offset)
        header = f.read(0x100)
        if len(header) != 0x100:
            print("short DOL header")
            return 1
        text_offs = struct.unpack(">7I", header[0x00:0x1C])
        data_offs = struct.unpack(">11I", header[0x1C:0x48])
        text_addrs = struct.unpack(">7I", header[0x48:0x64])
        data_addrs = struct.unpack(">11I", header[0x64:0x90])
        text_sizes = struct.unpack(">7I", header[0x90:0xAC])
        data_sizes = struct.unpack(">11I", header[0xAC:0xD8])
        bss_addr, bss_size, entry = struct.unpack(">III", header[0xD8:0xE4])

        sections = []
        for i in range(7):
            if text_sizes[i]:
                sections.append((text_offs[i], text_sizes[i], text_addrs[i], "text", i))
        for i in range(11):
            if data_sizes[i]:
                sections.append((data_offs[i], data_sizes[i], data_addrs[i], "data", i))
        sections.sort()

        end = max(off + size for off, size, _, _, _ in sections)
        f.seek(dol_offset)
        blob = f.read(end)

    if len(blob) != end:
        print(f"short read: {len(blob)} of {end}")
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(blob)

    print(f"ISO:        {iso}")
    print(f"DOL offset: 0x{dol_offset:08X}")
    print(f"DOL size:   {len(blob)} (0x{len(blob):X})")
    print(f"Entry:      0x{entry:08X}")
    print(f"BSS:        0x{bss_addr:08X} + 0x{bss_size:X}")
    for off, size, addr, kind, idx in sections:
        print(f"  {kind}{idx:<2} file 0x{off:06X}  mem 0x{addr:08X}-0x{addr + size:08X}  size 0x{size:X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
