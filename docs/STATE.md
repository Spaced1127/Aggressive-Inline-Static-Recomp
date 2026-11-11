# Project state

Updated: 2026-11-09

## Latest verified result

The recompiled game boots to playable gameplay on Windows:

- Intro FMV (PSS) renders: `work/evidence/01-intro-fmv.png`.
- Main menu: `02-main-menu.png`, `11-main-menu-alt.png`.
- Options menu with SFX / Music / Speech volume: `08-options-sound.png`.
- Player select: `03-player-select.png`.
- Name entry: `04-name-entry.png`.
- Level select with live 3D background: `05-level-select.png`.
- Tutorial level loads and renders: `06-gameplay-start.png`.
- Player movement with the main stick: `07-gameplay-moved.png`.
- Save state reload into gameplay: `09-loadstate-gameplay.png`.
- Player release staged and tested from `dist/`: launcher, direct ISO/RVZ
  import, Clang module, no game data. Zip SHA-256
  `2E358D4B5453E89D6C8E9CC70D52E4DF4EF333E3CEBFDC85CF31CD7DEAA8253E`.
- Frame-time investigation: GPU is idle (~2-3 ms) and the game is CPU-bound.
  A cold-cache window hit 1.54 s and 550 ms CPU stalls; the shader cache
  directory was missing. The launcher now creates it, enables cache affinity
  and pins to physical cores on 16-thread CPUs. See
  [`notes/03-performance.md`](notes/03-performance.md).

No crash, hang, or unimplemented-stub abort was observed through these scenes.
With the Clang `-O3` module the window title reports **59.9 FPS** in gameplay at
3x native (1920x1344) internal resolution, and the automation status reports
`speed~0.999`. The MSVC `/O2` module also runs at `speed~0.99-1.02` in headless
probing. A Clang gameplay capture is `13-clang-gameplay.png`.

## Disc facts

- File: `Aggressive Inline (USA).rvz` (RVZ v1.00.00, Zstandard).
- ISO: 1,459,978,240 bytes, CRC32 `5D9F46F1`,
  SHA-256 `EAD97F1722E79B2CBD96823EFE637EB3630183BE1889B3C487AB4A3277E3327E`.
- Game ID: `GILE51`; title `Aggressive Inline`; country `0x00` (USA).
- Magic at `0x1C`: `0xC2339F3D` (GameCube).
- DOL offset: `0x22531FE0`; DOL size: `1,574,144` bytes.
- DOL SHA-256: `F3D92F4312DAFA5BAA79355A03989873E100B97AE85B97280BC808EDB084C27A`.
- Entry point: `0x80005308`.
- BSS: `0x801817E0` + `0x52A00`.
- FST offset: `0x20440`, size `0x5500`; 949 entries.
- `work/game/files/default.dol` is the same size as the boot DOL.

### DOL sections

| Kind | Index | File offset | Virtual range | Size |
|---|---|---:|---|---:|
| text | 0 | `0x000100` | `0x80003100`-`0x80005600` | `0x2500` |
| text | 1 | `0x002600` | `0x80005600`-`0x8014FA60` | `0x14A460` |
| data | 0 | `0x14CA60` | `0x8014FA60`-`0x8014FA80` | `0x20` |
| data | 1 | `0x14CA80` | `0x8014FA80`-`0x8014FAA0` | `0x20` |
| data | 2 | `0x14CAA0` | `0x8014FAA0`-`0x801564A0` | `0x6A00` |
| data | 3 | `0x1534A0` | `0x801564A0`-`0x801817E0` | `0x2B340` |
| data | 4 | `0x17E7E0` | `0x801D1600`-`0x801D19E0` | `0x3E0` |
| data | 5 | `0x17EBC0` | `0x801D2860`-`0x801D41A0` | `0x1940` |

### Engine and data

- Z-Axis / Acclaim engine (`Z-Axis Gaming Environment`, copyright Z-Axis 2000).
- Movies are CRI **h4m** (`assets/Movies/z-axis.h4m` is opened by the movie
  player); a `ASSETS\Movies\Z-AXIS.PSS` string is also present in the DOL.
- Audio banks are `.zsd` (`assets/audio/music.zsd` 179 MB,
  `speech*.zsd`, `sfx*.zsd`).
- Assets use `.zal`, `.zit`, `.geo`, `.ins`, `.txr`, `.map`, `.zif`, `.zsc`.
- The root `inline.fld` says `GameShort=GBIN`, `CountryCode=0x2`; the disc header
  and FST say `GILE51` / USA. Treat the `.fld` as a stale build file.

## Recompilation

DolRecomp (`H:\Projects\SB-RFD\build\dolrecomp\dolrecomp.exe`) produced:

- text0: 2,368 instructions (730 known, 1,638 embedded data, 0 unknown).
- text1: 338,200 instructions (338,200 known, 0 unknown).
- 84 C chunks, portable C backend.
- 100 possible self-modifying/patching ranges in `generated_smc.txt`.
  Most are cache-management and SDK relocation writes; they did not block boot.

Build command:

```
dolrecomp.exe --cpu gekko --gamecube work\disc\main.dol build\recomp
```

## Runtime

- ModernGekko at `H:\Projects\SB-RFD\build\moderngekko`.
- Module (default): `build\gGILE51_recomp_clang.dll`, 36,866,560 bytes,
  Clang `-O3` + `-march=x86-64-v3` + ThinLTO, loop budget 4096 / call depth 128.
  Cache: `C:\gile\modules-clang\GILE51\f3d...-8f78e41483de3f25\gGILE51_recomp.dll`.
- Module (fallback): `build\gGILE51_recomp.dll`, 93,054,464 bytes, MSVC 14.51
  `/O2`. Cache: `C:\gile\modules\GILE51\f3d...-a71f4a5f346fbe4a\gGILE51_recomp.dll`.
- `run.bat` and the probe scripts prefer the Clang module when it exists.
- User dir: `work\user` with `DSPHLE=False`, `Backend=Cubeb`, DualSense profile.
- `--audio cubeb` is passed on the command line; `--automation-dir` enables
  screenshots/input/save-state/memory commands.
- Headless probing uses `tools\start_auto.bat`; windowed play uses `run.bat`.

## Audio investigation (open)

The game's sound engine runs but produces no audible samples:

- DSP LLE log shows the boot AX ucode `0x07f88145`, then after the sound engine
  initializes (e.g. state load) a second ucode `0x3a864594`.
- `DumpAudio=True` writes `*_dspdump.wav` (2,092 bytes = one silent frame) and
  zero-length `*_dspdump1.wav` / `*_dtkdump.wav` while running.
- DSP HLE and DSP LLE both produce silence for GILE51.
- The AI DMA is configured at boot: `20 blocks from 0x001b9740`.
- A guest-memory read of the AI DMA buffer (`0x801b9740`, 640 bytes) is all zero
  at the main menu and in gameplay, so the DSP is not writing PCM into the
  buffer the AI is playing.
- File monitor shows the game opening/reading the sound banks
  (`assets/audio/sfxcom.zsd`, `sfxgame.zsd`, `music.zsd` 179 MB,
  `speech00.zsd`), so the engine is trying to load audio.
- Control: the same runtime, user dir and `--audio cubeb` produce a 771 KB
  non-zero `GBQE78_*_dspdump.wav` for the RPBB recomp, so the runtime and audio
  backend are working.
- The Sound menu exposes SFX / Music / Speech volume bars. The slider fill
  renders as a plain white rectangle, so the saved values cannot be read from
  the screenshot; the volume controls did not change the bar visually when
  driven with D-pad input.
- Save state `work/saves/sound-menu.state` (24,428,124 bytes) boots straight to
  the Sound menu for follow-up tests.

Next step: determine whether the AI/DSP task is being fed. Likely candidates are
the custom `0x3a864594` ucode path, an AI DMA/interrupt issue, or the game's
sound settings. This is independent of the static module: a JIT/interpreter run
(`--allow-interpreter`, no module) is also silent.

## Next actions

1. **Audio**: instrument AI/DSP state and confirm whether the sound engine issues
   AI DMA. Identify the `0x3a864594` ucode (find its upload site and compare with
   Dolphin's known AX ucodes). Check the game's `EnableSound` global and the
   Sound menu values in guest memory.
2. **Performance**: done for the first pass - Clang `-O3` + x86-64-v3 + ThinLTO
   holds 59.9 FPS at 3x native internal in gameplay. PGO is optional from here.
3. **Coverage**: complete the tutorial, level transitions, pause, memory-card
   save/load, and at least one full level.
4. **SMC review**: inspect the 100 `generated_smc.txt` ranges; only patch sites
   that actually write executable memory at runtime.
5. **Packaging**: done for v0.0.1. The launcher accepts ISO, RVZ or an extracted
   folder, verifies `GILE51`/DOL hash, extracts to
   `%LOCALAPPDATA%\AggressiveInlineRecomp`, and starts the bundled module.
   See [`notes/02-release.md`](notes/02-release.md).
6. **Frame-time validation**: capture a clean active-gameplay window with the
   fixed launcher and warm shader cache. If 100 ms+ CPU stalls remain, build a
   PGO module from a gameplay profile. See
   [`notes/03-performance.md`](notes/03-performance.md).
7. **zgui host function**: implement or stub `inlineOverlayGetNumContinues`
   (`Continues`), which logs "Host function not Found" in the UI overlay.

## Known risks

- **Audio**: see above. The custom sound-driver ucode may need DSP LLE work.
- **Self-modifying code**: 100 flagged ranges; boot/gameplay currently OK, but a
  real text patch later could need an explicit DolRecomp patch.
- **h4m/PSS video**: the intro movies render, but movie audio is part of the
  same open audio issue.
- **Memory card**: the save/load menu is reachable; actual .gci write/read has
  not been verified.
- **Performance**: the Clang module is at the 60 FPS cap in the tested scene at
  3x internal resolution, but a cold shader cache produced CPU-bound 1.5 s
  stalls. The v0.0.1 release asset predates the `Cache\Shaders` and affinity
  fixes in `tools/gile_launcher.cs`; rebuild or use the fixed launcher for a
  validation run.
- **Missing host function**: `inlineOverlayGetNumContinues` is called by the
  zgui overlay and is not implemented. It is separate from the frame-time issue
  but should be stubbed.

## Commands

```powershell
# Extract the RVZ and DOL
python tools\rvz_extract.py "Aggressive Inline (USA).rvz" work\disc\game.iso
python tools\extract_dol.py work\disc\game.iso work\disc\main.dol

# Extract the Dolphin layout (sys/ + files/)
H:\Projects\SB-RFD\build\dolrecomp\dolrecomp.exe extract work\disc\game.iso work\game

# Build the Clang module (writes to C:\gile\modules-clang)
tools\build_clang.bat

# Build the MSVC module (writes to C:\gile\modules)
tools\build_msvc.bat

# Dev run windowed
tools\run_dev.bat

# Build the player release (stage + zip)
powershell -ExecutionPolicy Bypass -File tools\make_release_gile.ps1 -Version 0.0.1

# Headless automation screenshots
powershell -ExecutionPolicy Bypass -File tools\auto_probe.ps1 -Seconds 50 -Shots 10,25,45

# Frame-time capture (start PresentMon before the game, stop manually)
powershell -ExecutionPolicy Bypass -File tools\capture_session.ps1 -Seconds 600 -ProcessName gile

# Dev-build FPS probe with save-state load and scripted movement
powershell -ExecutionPolicy Bypass -File tools\perf_probe.ps1 -Seconds 30
```
