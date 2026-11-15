# Native RVZ support - acceptance

Date: 2026-11-15

Status: implemented, verified, and shipping in v0.1.0.

## What changed

### Direct RVZ reader

`tools/rvz_extract.py` now has a random-access `RvzReader` over the RVZ
container (Dolphin's WIA-derived format: zstd groups + RVZ packing + FST).
`--extract` reads only the groups needed by the disc header, DOL, FST and file
tree and writes the same layout as the ISO path:

```
<root>/sys/boot.bin
<root>/sys/bi2.bin
<root>/sys/apploader.img
<root>/sys/main.dol
<root>/sys/fst.bin
<root>/files/...
```

No temporary ISO is created. The old `rvz_extract.py input.rvz output.iso`
mode remains for compatibility but is no longer used by the launcher.

### Disc tooling

- `tools/gcdisc.py` gained `_read_at()` and `open_source()`. `read_dol()`,
  `parse_fst()`, `open_section()` and the CLI (`info`, `list`, `extract`,
  `dol`) accept an ISO path or an RVZ reader. RVZ is detected by the
  `RVZ\x01` magic.
- `tools/make_game_dir.py` builds the game root from `.iso` or `.rvz`.
- `tools/extract_dol.py` extracts the DOL from `.iso` or `.rvz`.
- `tools/compare_game_dirs.py` compares `sys/` and `files/` hashes.

### Launcher

`tools/gile_launcher.cs`:

- Detects RVZ by magic (`RVZ\x01`), not just the extension.
- `PrepareRvz` calls `rvz_extract.exe --extract <input> <game-dir>` and then
  verifies `main.dol` SHA-256. There is no temp ISO.
- The file picker filter is
  `GameCube disc image (*.iso;*.rvz;*.gcm)`.
- `UpdateReadyState` accepts `.iso`, `.gcm`, `.rvz`, or any file with RVZ
  magic.
- UI and error text says ISO / RVZ.
- A bundled `game.rvz` is detected next to the launcher, as well as
  `game.iso`.

`build/pyinstaller/dist/rvz_extract.exe` was rebuilt with PyInstaller from the
updated script and includes `gcdisc.py`.

## Acceptance

Input:

```
Aggressive Inline (USA).rvz   700,699,800 bytes
work/disc/game.iso          1,459,978,240 bytes
ISO SHA-256                 EAD97F1722E79B2CBD96823EFE637EB3630183BE1889B3C487AB4A3277E3327E
```

The existing decoder produced an ISO byte-identical to the source ISO:

```
RVZ-decoded ISO SHA-256     EAD97F1722E79B2CBD96823EFE637EB3630183BE1889B3C487AB4A3277E3327E
```

Direct RVZ extraction vs ISO extraction (`work/rvz_acceptance/rvz-direct` vs
`work/rvz_acceptance/iso-baseline`):

| File | SHA-256 |
|---|---|
| `sys/boot.bin` | `2aa72129f729feac8ea732d24b95f7c0f5d0444d7a889f009d7ac3e8aa1c7ca0` |
| `sys/bi2.bin` | `4678bd3bcd787c167e13c114ee9f775a29f47d310df2bbc90b01ac56e1efff52` |
| `sys/apploader.img` | `1a864e15684124c72e55abb3dc283acccc97ce3fa5dd0f60dee17317b17819ec` |
| `sys/main.dol` | `f3d92f4312dafa5baa79355a03989873e100b97ae85b97280bc808edb084c27a` |
| `sys/fst.bin` | `f252b914417d64252d811cea809ac550e0ed099dd0574a6c56f0395578534e0b` |
| `files/` manifest | `1a74bcc722a087d7a0f12af2859c8bb5c1d9cea81026d968d351cc746a6f781b` |

`files/`: 861 files, 883,595,233 bytes. Every file matched by relative path,
size and SHA-256.

The launcher's hidden `--prepare` path was run through
`H:\Orchestration\tools\run-hidden.ps1`:

| Path | Result |
|---|---|
| `--prepare --game Aggressive Inline (USA).rvz` | identical to `work/game` |
| `--prepare --game work\disc\game.iso` | identical to `work/game` |
| RVZ output vs ISO output | identical |

`gcdisc.py info` on the RVZ reported the real disc size (1,459,978,240 bytes),
GILE51, DOL entry `0x80005308`, and the same FST/DOL sections. `make_game_dir.py`
and `extract_dol.py` produced the same hashes from RVZ and ISO.

## What still uses ISO

- The recompiler's upstream helper `dolrecomp.exe extract` is ISO-only. The
  project quick start no longer uses it; `make_game_dir.py` writes the same
  `sys/` + `files/` tree that `moderngekko-port build` consumes.
- The legacy `rvz_extract.py input.rvz output.iso` mode still exists for
  compatibility, but no player or documented build step requires it.
- Players can import `.iso`, `.rvz` or an extracted folder. No ISO conversion
  is required.
