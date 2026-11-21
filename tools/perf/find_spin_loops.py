"""Find short backward-branch spin loops in a GameCube DOL.

Candidates for ModernGekko's [Core] StaticRecompIdlePC: the static core only
idle-skips at one configured PC, so a guest loop that polls memory while it
waits for an interrupt (the SDK's `while (RunQueueBits == 0) {}` in
SelectThread, a frame limiter, a DVD wait) otherwise runs once per dispatch on
the host.

Usage: python tools/perf/find_spin_loops.py work/disc/main.dol [--max-len 6]
"""
import argparse
import struct


def sections(dol: bytes):
    offs = struct.unpack(">18I", dol[0:0x48])
    addrs = struct.unpack(">18I", dol[0x48:0x90])
    sizes = struct.unpack(">18I", dol[0x90:0xD8])
    for i in range(7):
        if sizes[i]:
            yield i, offs[i], addrs[i], sizes[i]


def disasm_hint(w: int) -> str:
    op = w >> 26
    rd = (w >> 21) & 31
    ra = (w >> 16) & 31
    simm = struct.unpack(">h", struct.pack(">H", w & 0xFFFF))[0]
    if op == 32:
        return f"lwz r{rd},{simm}(r{ra})"
    if op == 34:
        return f"lbz r{rd},{simm}(r{ra})"
    if op == 40:
        return f"lhz r{rd},{simm}(r{ra})"
    if op == 10:
        return f"cmplwi cr{rd >> 2},r{ra},{w & 0xFFFF}"
    if op == 11:
        return f"cmpwi cr{rd >> 2},r{ra},{simm}"
    if op == 16:
        bd = struct.unpack(">h", struct.pack(">H", w & 0xFFFC))[0]
        return f"bc {rd},{ra},{bd:+d}"
    if op == 18:
        li = w & 0x03FFFFFC
        if li & 0x02000000:
            li -= 0x04000000
        return f"b{'l' if w & 1 else ''} {li:+d}"
    if op == 15:
        return f"lis/addis r{rd},r{ra},{w & 0xFFFF:#x}"
    if op == 14:
        return f"addi r{rd},r{ra},{simm}"
    if op == 31:
        xo = (w >> 1) & 0x3FF
        return f"op31 xo={xo}"
    if op == 21:
        return "rlwinm"
    if op == 28:
        return f"andi. r{ra},r{rd},{w & 0xFFFF:#x}"
    return f"op{op} {w:08x}"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dol")
    ap.add_argument("--max-len", type=int, default=6,
                    help="maximum loop body length in instructions")
    args = ap.parse_args()
    dol = open(args.dol, "rb").read()

    for idx, off, addr, size in sections(dol):
        words = struct.unpack(f">{size // 4}I", dol[off:off + size])
        for i, w in enumerate(words):
            op = w >> 26
            target = None
            if op == 16 and not (w & 3):  # bc, relative, no link
                bd = struct.unpack(">h", struct.pack(">H", w & 0xFFFC))[0]
                if bd < 0:
                    target = i + bd // 4
            elif op == 18 and not (w & 3):  # b, relative, no link
                li = w & 0x03FFFFFC
                if li & 0x02000000:
                    li -= 0x04000000
                if li <= 0:
                    target = i + li // 4
            if target is None or target < 0:
                continue
            length = i - target + 1
            if length > args.max_len:
                continue
            body = words[target:i + 1]
            # Spin loops have no calls and no stores in the body.
            has_call = any((x >> 26) == 18 and (x & 1) for x in body)
            has_store = any((x >> 26) in (36, 37, 38, 39, 44, 45) for x in body)
            has_load = any((x >> 26) in (32, 33, 34, 35, 40, 41) for x in body)
            if has_call or has_store:
                continue
            if length > 1 and not has_load:
                continue
            head = addr + target * 4
            print(f"text{idx} loop {head:08x}-{addr + i * 4:08x} len={length}")
            for j, x in enumerate(body):
                print(f"    {head + j * 4:08x}: {x:08x}  {disasm_hint(x)}")


if __name__ == "__main__":
    main()
