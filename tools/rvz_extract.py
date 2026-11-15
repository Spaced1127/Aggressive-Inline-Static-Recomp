#!/usr/bin/env python3
"""Native RVZ (Dolphin compressed disc image) reader and extractor.

Implements the WIA-derived RVZ container documented in Dolphin's
docs/WiaAndRvz.md and the GameCube raw-data path used by WIABlob.cpp.
Only the compression modes needed for this project are implemented:
Zstandard, None, and RVZ padding packing. Wii partition data is not
supported (this is a GameCube disc).

Usage:
    python tools/rvz_extract.py input.rvz output.iso
    python tools/rvz_extract.py --extract input.rvz output-game-dir

The second form reads the RVZ with random access and writes the same
sys/ + files/ layout the ISO extractor produces. No temporary ISO is made.
"""
from __future__ import annotations

import bisect
import hashlib
import struct
import sys
from collections import OrderedDict
from pathlib import Path

import zstandard

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

from gcdisc import parse_fst, read_dol, walk  # noqa: E402

RVZ_MAGIC = b"RVZ\x01"
WIA_DISC_OFFSET = 0x48
DISC_HEADER_SIZE = 0x80
COMPRESSION_NONE = 0
COMPRESSION_ZSTD = 5

MASK32 = 0xFFFFFFFF
LFG_K = 521
LFG_J = 32
LFG_SEED_WORDS = 17
LFG_BYTES = LFG_K * 4
BLOCK_SIZE = 0x8000


class LaggedFibonacciGenerator:
    """Dolphin's GC/Wii disc padding PRNG (LaggedFibonacciGenerator.cpp)."""

    def __init__(self, seed: bytes):
        if len(seed) != LFG_SEED_WORDS * 4:
            raise ValueError(f"bad LFG seed size: {len(seed)}")
        self.buffer = [0] * LFG_K
        for i in range(LFG_SEED_WORDS):
            self.buffer[i] = struct.unpack_from(">I", seed, i * 4)[0]

        for i in range(LFG_SEED_WORDS, LFG_K):
            self.buffer[i] = (
                (self.buffer[i - 17] << 23)
                ^ (self.buffer[i - 16] >> 9)
                ^ self.buffer[i - 1]
            ) & MASK32

        # Dolphin folds the "shift by 18 instead of 16" output quirk into the
        # words and byte-swaps them so GetBytes can just memcpy native order.
        for i in range(LFG_K):
            x = self.buffer[i]
            x = (x & 0xFF00FFFF) | ((x >> 2) & 0x00FF0000)
            self.buffer[i] = x
        self.pos = 0
        for _ in range(4):
            self._forward()

    def _forward(self):
        b = self.buffer
        for i in range(LFG_J):
            b[i] ^= b[i + LFG_K - LFG_J]
        for i in range(LFG_J, LFG_K):
            b[i] ^= b[i - LFG_J]

    def skip(self, count: int):
        self.pos += count
        while self.pos >= LFG_BYTES:
            self._forward()
            self.pos -= LFG_BYTES

    def get(self, count: int) -> bytes:
        out = bytearray()
        while count:
            word = self.buffer[self.pos // 4]
            byte_in_word = self.pos % 4
            # Native little-endian memory after the Initialize byte swap is
            # the big-endian representation of the transformed word.
            raw = word.to_bytes(4, "big")
            take = min(count, 4 - byte_in_word)
            out += raw[byte_in_word:byte_in_word + take]
            self.pos += take
            count -= take
            if self.pos == LFG_BYTES:
                self._forward()
                self.pos = 0
        return bytes(out)


def unpack_rvz(stream: bytes, output_size: int, data_offset: int) -> bytes:
    """Decode Dolphin's RVZ packing (plain runs + PRNG runs)."""
    out = bytearray()
    p = 0
    while len(out) < output_size:
        if p + 4 > len(stream):
            raise ValueError("RVZ pack stream truncated while reading run size")
        size = struct.unpack_from(">I", stream, p)[0]
        p += 4
        junk = bool(size & 0x80000000)
        size &= 0x7FFFFFFF

        if junk:
            if p + LFG_SEED_WORDS * 4 > len(stream):
                raise ValueError("RVZ pack stream truncated while reading seed")
            lfg = LaggedFibonacciGenerator(stream[p:p + LFG_SEED_WORDS * 4])
            p += LFG_SEED_WORDS * 4
            lfg.skip(data_offset % BLOCK_SIZE)
            out += lfg.get(size)
        else:
            if p + size > len(stream):
                raise ValueError("RVZ pack stream truncated while reading plain run")
            out += stream[p:p + size]
            p += size
        data_offset += size

    if len(out) != output_size:
        raise ValueError(f"RVZ pack produced {len(out)} bytes, expected {output_size}")
    return bytes(out)


def read_compressed_table(f, offset: int, size: int, compression: int, expect: int) -> bytes:
    f.seek(offset)
    data = f.read(size)
    if len(data) != size:
        raise ValueError("compressed table truncated")
    if compression == COMPRESSION_ZSTD:
        data = zstandard.ZstdDecompressor().decompress(data, max_output_size=expect)
    elif compression != COMPRESSION_NONE:
        raise NotImplementedError(f"compression type {compression} is not supported")
    if len(data) < expect:
        raise ValueError(f"table decompressed to {len(data)}, expected at least {expect}")
    return data


class RvzReader:
    """Random-access reader over a GameCube RVZ disc.

    Groups are decompressed on demand and a small LRU cache keeps sequential
    file extraction from re-decompressing the same chunk.
    """

    def __init__(self, path: Path):
        self.path = Path(path)
        self.file = self.path.open("rb")
        try:
            head = self.file.read(0x48)
            if len(head) != 0x48 or head[:4] != RVZ_MAGIC:
                raise ValueError("not an RVZ file")
            self.version, self.compat, header2_size = struct.unpack_from(">III", head, 4)
            self.iso_size, file_size = struct.unpack_from(">QQ", head, 0x24)
            if self.path.stat().st_size != file_size:
                raise ValueError("RVZ file size does not match header")

            h2 = self.file.read(header2_size)
            if len(h2) != header2_size:
                raise ValueError("RVZ header 2 truncated")
            (disc_type, self.compression, self.compr_level,
             self.chunk_size) = struct.unpack_from(">IIII", h2, 0)
            if disc_type != 1:
                raise NotImplementedError(f"disc_type {disc_type} is not GameCube")
            if self.compression not in (COMPRESSION_NONE, COMPRESSION_ZSTD):
                raise NotImplementedError(
                    f"compression type {self.compression} is not supported")
            if self.chunk_size % BLOCK_SIZE != 0:
                raise ValueError("invalid chunk size")

            self.disc_header = h2[0x10:0x10 + DISC_HEADER_SIZE]
            p = 0x10 + DISC_HEADER_SIZE
            n_part, part_t_size = struct.unpack_from(">II", h2, p)
            p += 8
            part_off, = struct.unpack_from(">Q", h2, p)
            p += 8 + 20
            n_raw, = struct.unpack_from(">I", h2, p)
            p += 4
            raw_off, = struct.unpack_from(">Q", h2, p)
            p += 8
            raw_size, = struct.unpack_from(">I", h2, p)
            p += 4
            n_groups, = struct.unpack_from(">I", h2, p)
            p += 4
            group_off, = struct.unpack_from(">Q", h2, p)
            p += 8
            group_size, = struct.unpack_from(">I", h2, p)

            if n_part != 0:
                raise NotImplementedError("Wii partition entries are not supported")

            self.raw_table = read_compressed_table(
                self.file, raw_off, raw_size, self.compression, n_raw * 24)
            self.group_table = read_compressed_table(
                self.file, group_off, group_size, self.compression, n_groups * 12)
            self.n_groups = n_groups

            self.entries = []
            for i in range(n_raw):
                data_off, data_size, group_index, groups = struct.unpack_from(
                    ">QQII", self.raw_table, i * 24)
                skipped = data_off % BLOCK_SIZE
                aligned_off = data_off - skipped
                aligned_size = data_size + skipped
                self.entries.append({
                    "data_off": data_off,
                    "data_size": data_size,
                    "group_index": group_index,
                    "groups": groups,
                    "aligned_off": aligned_off,
                    "aligned_size": aligned_size,
                })
            self.entries.sort(key=lambda e: e["aligned_off"])
            self.entry_starts = [e["aligned_off"] for e in self.entries]
            self.cache: OrderedDict[tuple[int, int, int], bytes] = OrderedDict()
            self.cache_limit = 8
        except Exception:
            self.file.close()
            raise

    def close(self):
        self.file.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()

    def _entry_for(self, offset: int):
        idx = bisect.bisect_right(self.entry_starts, offset) - 1
        if idx < 0:
            return None
        entry = self.entries[idx]
        if offset < entry["aligned_off"] + entry["aligned_size"]:
            return entry
        return None

    def _load_group(self, total_group: int, this_chunk: int,
                    chunk_offset: int) -> bytes:
        key = (total_group, this_chunk, chunk_offset)
        cached = self.cache.get(key)
        if cached is not None:
            self.cache.move_to_end(key)
            return cached
        if total_group >= self.n_groups:
            raise ValueError("group index out of range")

        file_off4, group_data_size, packed_size = struct.unpack_from(
            ">III", self.group_table, total_group * 12)
        compressed = bool(group_data_size & 0x80000000)
        group_data_size &= 0x7FFFFFFF

        if group_data_size == 0:
            chunk = bytes(this_chunk)
        else:
            self.file.seek(file_off4 * 4)
            raw = self.file.read(group_data_size)
            if len(raw) != group_data_size:
                raise ValueError("group data truncated")
            if compressed:
                dec = zstandard.ZstdDecompressor()
                if packed_size:
                    packed = dec.decompress(raw, max_output_size=packed_size)
                    if len(packed) != packed_size:
                        raise ValueError("packed group size mismatch")
                    chunk = unpack_rvz(packed, this_chunk, chunk_offset)
                else:
                    chunk = dec.decompress(raw, max_output_size=this_chunk)
                    if len(chunk) != this_chunk:
                        raise ValueError(
                            f"group {total_group}: got {len(chunk)} bytes, "
                            f"expected {this_chunk}")
            else:
                chunk = raw
                if packed_size:
                    chunk = unpack_rvz(chunk, this_chunk, chunk_offset)
                if len(chunk) != this_chunk:
                    raise ValueError("uncompressed group size mismatch")

        if len(chunk) < this_chunk:
            chunk += bytes(this_chunk - len(chunk))
        self.cache[key] = chunk
        if len(self.cache) > self.cache_limit:
            self.cache.popitem(last=False)
        return chunk

    def read_at(self, offset: int, size: int) -> bytes:
        if offset < 0 or size < 0 or offset + size > self.iso_size:
            raise ValueError("read outside the disc")
        out = bytearray()

        if offset < DISC_HEADER_SIZE:
            take = min(size, DISC_HEADER_SIZE - offset)
            out += self.disc_header[offset:offset + take]
            offset += take
            size -= take
            if size == 0:
                return bytes(out)

        while size:
            entry = self._entry_for(offset)
            if entry is None:
                next_start = self.iso_size
                idx = bisect.bisect_right(self.entry_starts, offset)
                if idx < len(self.entry_starts):
                    next_start = self.entry_starts[idx]
                take = next_start - offset if next_start > offset else size
                take = min(size, take)
                out += bytes(take)
                offset += take
                size -= take
                continue

            relative = offset - entry["aligned_off"]
            chunk_index = relative // self.chunk_size
            chunk_offset = relative % self.chunk_size
            this_chunk = min(
                self.chunk_size,
                entry["aligned_size"] - chunk_index * self.chunk_size)
            if this_chunk <= 0 or chunk_index >= entry["groups"]:
                take = min(
                    size,
                    entry["aligned_off"] + entry["aligned_size"] - offset)
                if take <= 0:
                    take = size
                out += bytes(take)
                offset += take
                size -= take
                continue

            total_group = entry["group_index"] + chunk_index
            chunk = self._load_group(
                total_group, this_chunk, chunk_index * self.chunk_size)
            take = min(size, this_chunk - chunk_offset)
            out += chunk[chunk_offset:chunk_offset + take]
            offset += take
            size -= take

        return bytes(out)


def extract(rvz_path: Path, iso_path: Path):
    """Legacy whole-disc mode: write a byte-identical ISO."""
    with rvz_path.open("rb") as f:
        head = f.read(0x48)
        if len(head) != 0x48 or head[:4] != RVZ_MAGIC:
            raise ValueError("not an RVZ file")
        version, compat, header2_size = struct.unpack_from(">III", head, 4)
        iso_size, file_size = struct.unpack_from(">QQ", head, 0x24)
        if rvz_path.stat().st_size != file_size:
            raise ValueError("RVZ file size does not match header")

        h2 = f.read(header2_size)
        disc_type, compression, compr_level, chunk_size = struct.unpack_from(">IIII", h2, 0)
        if disc_type != 1:
            raise NotImplementedError(f"disc_type {disc_type} is not GameCube")
        if compression not in (COMPRESSION_NONE, COMPRESSION_ZSTD):
            raise NotImplementedError(f"compression type {compression} is not supported")
        if chunk_size % BLOCK_SIZE != 0:
            raise ValueError("invalid chunk size")

        disc_header = h2[0x10:0x10 + DISC_HEADER_SIZE]
        p = 0x10 + DISC_HEADER_SIZE
        n_part, part_t_size = struct.unpack_from(">II", h2, p)
        p += 8
        part_off, = struct.unpack_from(">Q", h2, p)
        p += 8 + 20
        n_raw, = struct.unpack_from(">I", h2, p)
        p += 4
        raw_off, = struct.unpack_from(">Q", h2, p)
        p += 8
        raw_size, = struct.unpack_from(">I", h2, p)
        p += 4
        n_groups, = struct.unpack_from(">I", h2, p)
        p += 4
        group_off, = struct.unpack_from(">Q", h2, p)
        p += 8
        group_size, = struct.unpack_from(">I", h2, p)

        if n_part != 0:
            raise NotImplementedError("Wii partition entries are not supported")

        raw_table = read_compressed_table(f, raw_off, raw_size, compression, n_raw * 24)
        entries = []
        for i in range(n_raw):
            data_off, data_size, group_index, groups = struct.unpack_from(">QQII", raw_table, i * 24)
            entries.append((data_off, data_size, group_index, groups))

        group_table = read_compressed_table(f, group_off, group_size, compression, n_groups * 12)

        print(f"RVZ v{version >> 24}.{version >> 16 & 0xff:02x}.{version >> 8 & 0xff:02x}")
        print(f"ISO size: {iso_size:,} bytes, chunk: {chunk_size:,}, groups: {n_groups:,}")

        with iso_path.open("wb") as out:
            out.truncate(iso_size)
            out.seek(0)
            out.write(disc_header)

            for entry_index, (data_off, data_size, group_index, groups) in enumerate(entries):
                # Mirrors ReadFromGroups: the entry is aligned down to a 32 KiB
                # sector and the skipped bytes are included in the data size.
                skipped = data_off % BLOCK_SIZE
                aligned_off = data_off - skipped
                aligned_size = data_size + skipped

                for i in range(groups):
                    total_group = group_index + i
                    file_off4, group_data_size, packed_size = struct.unpack_from(
                        ">III", group_table, total_group * 12
                    )
                    compressed = bool(group_data_size & 0x80000000)
                    group_data_size &= 0x7FFFFFFF

                    this_chunk = min(chunk_size, aligned_size - i * chunk_size)
                    if this_chunk <= 0:
                        break

                    if group_data_size == 0:
                        chunk = bytes(this_chunk)
                    else:
                        f.seek(file_off4 * 4)
                        raw = f.read(group_data_size)
                        if len(raw) != group_data_size:
                            raise ValueError("group data truncated")
                        if compressed:
                            dec = zstandard.ZstdDecompressor()
                            if packed_size:
                                packed = dec.decompress(raw, max_output_size=packed_size)
                                if len(packed) != packed_size:
                                    raise ValueError("packed group size mismatch")
                                chunk = unpack_rvz(packed, this_chunk, i * chunk_size)
                            else:
                                chunk = dec.decompress(raw, max_output_size=this_chunk)
                                if len(chunk) != this_chunk:
                                    raise ValueError(
                                        f"group {total_group}: got {len(chunk)} bytes, expected {this_chunk}"
                                    )
                        else:
                            chunk = raw
                            if packed_size:
                                chunk = unpack_rvz(chunk, this_chunk, i * chunk_size)
                            if len(chunk) != this_chunk:
                                raise ValueError("uncompressed group size mismatch")

                    # Group 0 covers disc offset 0 even though the raw entry
                    # starts at 0x80; the header was written above.
                    out.seek(aligned_off + i * chunk_size)
                    out.write(chunk)

                    if (i + 1) % 256 == 0 or i + 1 == groups:
                        done = aligned_off + (i + 1) * chunk_size
                        pct = min(100, done * 100 // iso_size)
                        print(f"\r  groups {i + 1:,}/{groups:,}  {pct:3d}%", end="", flush=True)
                print()

    print(f"Wrote {iso_path} ({iso_path.stat().st_size:,} bytes)")


def extract_game_dir(rvz_path: Path, out_dir: Path):
    """Read the RVZ natively and write the ISO-equivalent sys/ + files/ tree."""
    with RvzReader(rvz_path) as reader:
        head = reader.read_at(0, 0x2440)
        if len(head) != 0x2440:
            raise ValueError("disc header truncated")
        magic = struct.unpack_from(">I", head, 0x1C)[0]
        if magic != 0xC2339F3D:
            raise ValueError("not a GameCube disc")

        sys_dir = out_dir / "sys"
        files_dir = out_dir / "files"
        sys_dir.mkdir(parents=True, exist_ok=True)
        files_dir.mkdir(parents=True, exist_ok=True)

        (sys_dir / "boot.bin").write_bytes(head[0:0x440])
        (sys_dir / "bi2.bin").write_bytes(head[0x440:0x2440])

        app = reader.read_at(0x2440, 0x20)
        app_total = 0x20 + struct.unpack_from(">I", app, 0x14)[0] + struct.unpack_from(">I", app, 0x18)[0]
        (sys_dir / "apploader.img").write_bytes(reader.read_at(0x2440, app_total))

        dol, dol_blob = read_dol(reader)
        (sys_dir / "main.dol").write_bytes(dol_blob)

        fst_root, fst_off, fst_size = parse_fst(reader)
        (sys_dir / "fst.bin").write_bytes(reader.read_at(fst_off, fst_size))

        files = []
        for path, entry in walk(fst_root):
            if entry.is_dir:
                continue
            files.append((entry.offset, entry.size, path))
        files.sort(key=lambda item: (item[0], item[2]))

        total = sum(size for _, size, _ in files)
        done = 0
        last_percent = -1
        for offset, size, path in files:
            dest = files_dir / path
            dest.parent.mkdir(parents=True, exist_ok=True)
            if not dest.resolve().is_relative_to(files_dir.resolve()):
                raise ValueError(f"FST path escapes the output folder: {path}")
            with dest.open("wb") as out:
                pos = offset
                remaining = size
                while remaining > 0:
                    chunk = reader.read_at(pos, min(4 * 1024 * 1024, remaining))
                    if not chunk:
                        raise ValueError(f"truncated file {path}")
                    out.write(chunk)
                    pos += len(chunk)
                    remaining -= len(chunk)
            done += size
            percent = done * 100 // max(1, total)
            if percent // 10 != last_percent // 10:
                last_percent = percent
                print(f"\r  files {percent:3d}%", end="", flush=True)

        print()
        dol_hash = hashlib.sha256((sys_dir / "main.dol").read_bytes()).hexdigest()
        print(f"Game root:   {out_dir}")
        print(f"boot.bin     {0x440} bytes")
        print(f"bi2.bin      {0x2000} bytes")
        print(f"apploader.img {app_total} bytes")
        print(f"main.dol     {len(dol_blob)} bytes, entry {dol.entry_point:#010x}")
        print(f"main.dol SHA-256: {dol_hash}")
        print(f"fst.bin      {fst_size} bytes at {fst_off:#x}")
        print(f"files/       {len(files)} files, {total:,} bytes")


def main(argv: list[str]) -> int:
    if len(argv) == 4 and argv[1] == "--extract":
        extract_game_dir(Path(argv[2]), Path(argv[3]))
        return 0
    if len(argv) == 3:
        extract(Path(argv[1]), Path(argv[2]))
        return 0
    print(__doc__.strip())
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
