"""Print raw words and branch targets around DOL addresses.

Usage: python tools/perf/dol_context.py work/disc/main.dol 0x80129220 [...] [--before 16 --after 8]
"""
import argparse
import struct
import sys

sys.path.insert(0, __import__("os").path.dirname(__file__))
from find_spin_loops import disasm_hint, sections  # noqa: E402


def read_word(dol: bytes, va: int):
    for _, off, addr, size in sections(dol):
        if addr <= va < addr + size:
            return struct.unpack(">I", dol[off + va - addr:off + va - addr + 4])[0]
    return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dol")
    ap.add_argument("addrs", nargs="+")
    ap.add_argument("--before", type=int, default=16)
    ap.add_argument("--after", type=int, default=8)
    args = ap.parse_args()
    dol = open(args.dol, "rb").read()
    for a in args.addrs:
        va = int(a, 16)
        print(f"== {va:08x}")
        for k in range(-args.before, args.after + 1):
            p = va + 4 * k
            w = read_word(dol, p)
            if w is None:
                continue
            extra = ""
            if (w >> 26) == 18:
                li = w & 0x03FFFFFC
                if li & 0x02000000:
                    li -= 0x04000000
                extra = f"  -> {p + li:08x}"
            elif w == 0x4E800020:
                extra = "  (blr)"
            elif (w >> 26) == 31 and ((w >> 1) & 0x3FF) == 339:
                extra = "  (mfspr)"
            print(f"  {'>' if k == 0 else ' '} {p:08x}: {w:08x}  {disasm_hint(w)}{extra}")


if __name__ == "__main__":
    main()
