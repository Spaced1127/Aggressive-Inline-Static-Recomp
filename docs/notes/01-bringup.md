# Bring-up log - Aggressive Inline (GILE51)

Date: 2026-11-09

## 1. Disc

Source: `Aggressive Inline (USA).rvz` (user's own dump).

- RVZ v1.00.00, Zstandard level 19, 128 KiB chunks, 11,139 groups.
- ISO: 1,459,978,240 bytes.
- Game ID `GILE51`, title `Aggressive Inline`, country `0x00` (USA).
- Magic `0xC2339F3D` at `0x1C`.
- DOL offset `0x22531FE0`, size `1,574,144`.
- FST offset `0x20440`, size `0x5500`, 949 entries.
- Entry `0x80005308`, BSS `0x801817E0` + `0x52A00`.

```
python tools\rvz_extract.py "Aggressive Inline (USA).rvz" work\disc\game.iso
python tools\extract_dol.py work\disc\game.iso work\disc\main.dol
```

The extracted DOL hash is
`F3D92F4312DAFA5BAA79355A03989873E100B97AE85B97280BC808EDB084C27A`.
The FST `default.dol` entry has the same 1,574,144-byte size.

## 2. Recompile

```
H:\Projects\SB-RFD\build\dolrecomp\dolrecomp.exe --cpu gekko --gamecube work\disc\main.dol build\recomp
```

Result:

```
text[0]: 2,368 decoded, 730 known, 1,638 embedded data, 0 unknown
text[1]: 338,200 decoded, 338,200 known, 0 unknown
84 chunks
100 possible patching ranges (generated_smc.txt)
```

The first SMC entries are `0x8000335C`, `0x80005558`, `0x80116A50`,
`0x80125E38`, `0x80125E74`, `0x80125E84`, `0x80125F7C`,
`0x80127BBC-0x80127BD0`.

## 3. Game root

```
H:\Projects\SB-RFD\build\dolrecomp\dolrecomp.exe extract work\disc\game.iso work\game
```

Produces `sys/{boot.bin,bi2.bin,apploader.img,main.dol,fst.bin}` and `files/`
with the full 949-entry disc tree.

## 4. Module build

The project path contains spaces and a long folder name; `moderngekko-port`
builds its module cache under `<output>\GILE51\<dol-hash>-<toolchain-hash>\`,
which exceeded the MSVC 250-character object path limit. Build from a short
cache root instead:

```
moderngekko-port.exe build work\game --backend c --toolchain msvc --opt-level 2 --output C:\gile\modules
copy C:\gile\modules\GILE51\<cache>\gGILE51_recomp.dll build\gGILE51_recomp.dll
```

MSVC module size: 93,054,464 bytes.

Clang build:

```
set PATH=C:\Program Files\LLVM\bin;%PATH%
set CFLAGS=-march=x86-64-v3 -mtune=generic
set DOLRECOMP_C_LOOP_CYCLE_BUDGET=4096
set DOLRECOMP_C_MAX_CALL_DEPTH=128
moderngekko-port.exe build work\game --backend c --toolchain clang --opt-level 3 --output C:\gile\modules-clang
```

Clang module size: 36,866,560 bytes. Cache key
`f3d...a42d-8f78e41483de3f25`.

## 5. Boot and gameplay

Launch:

```
moderngekko-run.exe --game work\game --module build\gGILE51_recomp.dll --user-dir work\user --audio cubeb --automation-dir work\automation
```

The automation channel accepts command files under `work/automation/commands`
and writes `status.txt`. Screenshots use the frame dumper and work headless.

Observed sequence (MSVC `/O2`, Vulkan, DSP LLE):

| Scene | Evidence |
|---|---|
| Z-Axis logo | `options-0.png` (early capture) |
| Intro FMV / ASi Pro Tour (h4m) | `01-intro-fmv.png` |
| Main menu | `02-main-menu.png`, `11-main-menu-alt.png` |
| Options / Sound | `08-options-sound.png` |
| Player select | `03-player-select.png` |
| Name entry | `04-name-entry.png` |
| Level select | `05-level-select.png` |
| Tutorial gameplay | `06-gameplay-start.png` |
| Movement | `07-gameplay-moved.png` |
| Save-state reload | `09-loadstate-gameplay.png` |

Input was injected with `pad_frames` (`start`, `a`, `dpad_right`,
`main_y`). Save state `work/saves/tutorial-start.state` (29,975,615 bytes)
loads back to the tutorial overlay.

Runtime speed at the tutorial start was `0.99-1.02` (emulation speed) in
headless mode. With the Clang module, the windowed title reports **59.9 FPS**
in gameplay at 3x native (1920x1344) internal resolution; a 20-second sample
held `speed=0.999`. During the intro FMV the MSVC module showed 36.6 FPS.

## 6. Audio control test

GILE51:

- `DumpAudio=True` produces `GILE51_*_dspdump.wav` of 2,092 bytes (one silent
  frame), with zero-length `dspdump1` / `dtkdump` while running.
- Both DSP HLE and DSP LLE are silent.
- JIT/interpreter (`--allow-interpreter`, no static module) is also silent, so
  this is not caused by the recompiled module.
- Ucode CRCs observed: `0x07F88145` (known AX ucode used by F-Zero GX, Ikaruga,
  etc.) at boot; the IRAM CRC becomes `0x3A864594` after state load (the AX
  ucode's data area is part of that hash).
- AI DMA is configured at boot: `20 blocks from 0x001b9740`.
- Guest reads of `0x801b9740` (the 640-byte AI DMA ring) are all zero at the
  main menu and in gameplay. The DSP is not writing PCM into the AI buffer.
- File monitor shows the sound banks being read: `sfxcom.zsd`, `sfxgame.zsd`,
  `music.zsd` (179 MB), `speech00.zsd`.
- The Sound menu sliders render as plain white rectangles and did not change
  visibly under D-pad input; the saved volume cannot be read from the capture.
- `work/saves/sound-menu.state` loads directly to the Sound menu for follow-up.

Control:

- The same runtime, user dir, and `--audio cubeb` produce a 771 KB
  `GBQE78_*_dspdump.wav` for the RPBB recomp (Rocket Power: Beach Bandits).
- Therefore the runtime and Cubeb/DSP installation are functional; the issue is
  specific to GILE51's audio path.

## 7. Open work

1. Audio: confirm AI DMA/sound-engine state and identify `0x3A864594`.
2. Clang `-O3` module is built and holds 59.9 FPS; PGO only if later scenes dip.
3. Full tutorial, level transitions, pause, memory-card save/load.
4. Review the 100 SMC ranges.
5. Packaging/launcher.
