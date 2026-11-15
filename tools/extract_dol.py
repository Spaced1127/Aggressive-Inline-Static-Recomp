#!/usr/bin/env python3
"""Extract the monolithic boot DOL from a GameCube ISO or RVZ."""
from __future__ import annotations

import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

from gcdisc import open_source, read_dol  # noqa: E402


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_dol.py <game.iso|game.rvz> <out.dol>")
        return 1
    source_path, out = Path(sys.argv[1]), Path(sys.argv[2])
    source = open_source(source_path)
    try:
        dol, blob = read_dol(source)
    finally:
        close = getattr(source, "close", None)
        if close:
            close()

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(blob)

    print(f"Source:     {source_path}")
    print(f"DOL size:   {len(blob)} (0x{len(blob):X})")
    print(f"Entry:      0x{dol.entry_point:08X}")
    print(f"BSS:        0x{dol.bss_address:08X} + 0x{dol.bss_size:X}")
    for s in dol.sections:
        print(f"  {s.kind}{s.index:<2} file 0x{s.file_offset:06X}  "
              f"mem 0x{s.address:08X}-0x{s.end_address:08X}  size 0x{s.size:X}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
