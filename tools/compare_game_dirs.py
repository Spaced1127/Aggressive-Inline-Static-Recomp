#!/usr/bin/env python3
"""Compare two extracted GameCube game roots byte-for-byte.

Usage:
    python tools/compare_game_dirs.py <a> <b>

Prints SHA-256 for each sys/ file and a manifest hash for files/.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def tree_manifest(root: Path) -> tuple[str, int, int]:
    rows = []
    total = 0
    count = 0
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(root).as_posix()
        size = path.stat().st_size
        digest = sha256(path)
        rows.append(f"{rel}\t{size}\t{digest}")
        total += size
        count += 1
    manifest = "\n".join(rows) + ("\n" if rows else "")
    return hashlib.sha256(manifest.encode("utf-8")).hexdigest(), count, total


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__.strip())
        return 2
    a = Path(argv[1])
    b = Path(argv[2])
    ok = True

    sys_names = sorted({
        p.name for root in (a / "sys", b / "sys")
        for p in root.glob("*") if p.is_file()
    })
    print("sys/")
    for name in sys_names:
        left = a / "sys" / name
        right = b / "sys" / name
        lh = sha256(left) if left.is_file() else "<missing>"
        rh = sha256(right) if right.is_file() else "<missing>"
        same = lh == rh
        ok = ok and same
        print(f"  {name:16} {lh}  {'OK' if same else 'DIFF'}")
        if not same:
            print(f"  {'':16} {rh}")

    for label, root in (("files/ A", a / "files"), ("files/ B", b / "files")):
        digest, count, total = tree_manifest(root)
        print(f"{label}: {count:,} files, {total:,} bytes, manifest {digest}")

    ah, ac, at = tree_manifest(a / "files")
    bh, bc, bt = tree_manifest(b / "files")
    files_same = ah == bh and ac == bc and at == bt
    ok = ok and files_same
    print(f"files/ match: {files_same}")
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
