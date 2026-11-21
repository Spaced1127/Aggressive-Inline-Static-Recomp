# Project state

Updated: 2026-11-21

## Working mode

**Hub pause active (2026-11-16): no GUI or test launches.** Until the hub
lifts it: no launchers, game executables, emulators, windows or audio. Host-side
work only (code, analysis, builds without a GUI, docs). Do not hide anything
and do not launch anything. Test cycles are suspended; blocked test actions are
recorded under Next actions.

Quiet mode was **lifted by user directive on 2026-11-16**. When the hub pause
is lifted, test apps launch normally with visible windows. Do not use
`H:\Orchestration\tools\run-hidden.ps1`, and do not hide, minimize, move or
kill the windows of test apps. This supersedes every earlier hidden-desktop
instruction. See [`notes/13-visible-windows.md`](notes/13-visible-windows.md).

**Shared guide (standing user directive, 2026-11-21):** any finding, fix or
tool from this port that would help other GameCube recomps goes into
<https://github.com/Spaced1127/GameCube-Static-Recomp-Guide> (local checkout
`H:\Projects\GameCube-Static-Recomp-Guide`). Keep game data and personal
details out of it.

**Fixes must not depend on the user's controller:** a controller change must
work for any connected pad without editing a config. Dev launches use
`build\gile.exe` (the shipped runner, with the first-SDL-pad fallback) through
`tools\run_dev.bat`, not the older shared `moderngekko-run.exe`, which lacks the
fallback. `build\Sys` is a local junction to
`H:\Projects\SB-RFD\build\moderngekko\Sys`.

On 2026-11-21 the user directed level-start stutter testing. The windowed runs
in [`notes/14-movielot-stutter.md`](notes/14-movielot-stutter.md) were made
under that direction. The hub pause text above remains for other work.

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
- Audio output confirmed working through DSP LLE + Cubeb; the earlier silence
  was a muted output, not a DSP fault.
- Player release v0.0.2 staged and tested from `dist/`: launcher, direct
  ISO/RVZ import, generic runner, Clang module, no game data. Zip SHA-256
  `3ED12524FC4636D0DEE745257AF16D6FEA740ED9F92CB57BDC965E25813F1A4E`.
- Player release v0.0.3 staged and tested from `dist/`: the same runner and
  module with the expanded controller layouts. Zip size 26,077,924 bytes,
  SHA-256
  `7CD1C5D6CC80DE17BBE9B80E37695DFDD8E06CDF825DFDF775DB0A08AE012D04`.
  No game data.
- Player release v0.0.4 staged and tested from `dist/`: automatic SDL
  controller fallback, Aggressive Inline branding and 16:9 window sizing. Zip
  size 26,080,740 bytes, SHA-256
  `9AA57FE8DD09845B3FF5822340D38B839346AA2E676050A66E1B20B0092F7789`.
  No game data.
- Player release v0.1.0 staged and verified from `dist/`: native RVZ import,
  DualSense Edge / Xbox Elite Series 1-2 GUID support, and the 8BitDo
  Nintendo-layout fix. Zip size 26,123,520 bytes, SHA-256
  `2C2515867A50F1D453D91D1B396B17017A6CCFE86A91EA2F965293EB53443C01`.
  Stage contains 2,662 files and no game data. RVZ extraction matches the
  ISO-derived tree (861 files, 883,595,233 bytes, manifest
  `1A74BCC722A087D7A0F12AF2859C8BB5C1D9CEA81026D968D351CC746A6F781B`).
  Boot smoke on the hidden desktop reached `app booted from bootrom` and
  `StartZAxisMovie`.
- Native RVZ import (shipping in v0.1.0): the launcher detects
  `RVZ\x01` and calls `rvz_extract.exe --extract` to write the same `sys/` +
  `files/` tree as the ISO path, with no temporary ISO. `make_game_dir.py`,
  `gcdisc.py` and `extract_dol.py` also accept RVZ. Acceptance hashes are in
  [`notes/07-rvz-native.md`](notes/07-rvz-native.md).
- Controller batch (shipping in v0.1.0): GUID-level DualSense Edge
  (054C:0DF2) and Xbox Elite Series 1/2 (045E:02E3/0B00/0B05/0B22) detection;
  standard DualSense/Xbox layouts; Edge paddles/Fn and Elite paddles unbound;
  offline layout test passes. See
  [`notes/08-edge-elite-controllers.md`](notes/08-edge-elite-controllers.md).
- 8BitDo Nintendo-layout fix (shipping in v0.1.0): the runner reads the live SDL
  mapping per device and selects the Switch layout when `a > b`, so a Pro 2 in
  Nintendo or Switch mode gets swapped A/B/X/Y while the Ultimate and 64 stay
  standard. Reversed D-pad bindings are corrected. Default profiles migrate;
  a custom profile is preserved for the connected pad; the manual Nintendo
  override remains. Layout test 62/62 and launcher self-test 132/132. See
  [`notes/09-8bitdo-nintendo-mapping.md`](notes/09-8bitdo-nintendo-mapping.md).
- **Controller hotfix (v0.1.1, staged and pending approval)**: players reported
  Xbox pads with no input at all in v0.1.0. The layout heuristics are not the
  cause - every Xbox row in SDL's database resolves to `layout=xbox`, and
  Xbox/PlayStation/Generic generate byte-identical profiles. The release broke
  **device binding**: the v0.1.0 runner lost the runtime's
  "configured device not found; using the first SDL pad" fallback (present in
  the v0.0.4 binary, and it fired for the Xbox pad in
  `work/v004_upgrade_user` and `work/v004_final_upgrade`), and it now rewrites
  `GCPadNew.ini` on every launch from its own SDL probe, which ran with
  different SDL hints than Dolphin's backend. Fixed by re-applying
  `docs/patches/dolphin-sdl-controller-fallback.patch` (now matches the same
  device name with a shifted id first), mirroring the runtime's SDL hints in
  the probe, dropping the raw-button-index D-pad comparison (35 legitimate DB
  rows and SDL's WGI Xbox mapping were inverted by it), and configuring
  `tools/rebuild_runner.bat` for this port (no baked-in `GSQE78`/DOL gate).
  Layout test 130/130, session matrix 80/80, hidden-desktop boot smoke reaches
  `module loaded`. Staged as v0.1.1 (26,124,775 bytes, SHA-256
  `DA657D3076B2D2FC1A985A227A7180F92D8F49E6E0E94EE8CA3BCFB580AC5E35`,
  notes in `work/release_notes_v0.1.1.md`); **never published**. It is
  superseded by v0.1.2, which contains this fix plus the memory-card fix.
  See [`notes/10-controller-hotfix.md`](notes/10-controller-hotfix.md).
- **Memory card / slot A (v0.1.2 candidate, save + load verified)**:
  the save hang was two config defects plus a runtime gap. Slot A was never
  configured (Dolphin defaults to the GCI folder), the runtime never called
  `UICommon::CreateDirectories`, and `SlotB = 0` is Dolphin's **Dummy**
  device, which the game rejects with "THE DEVICE IN SLOT B IS NOT
  SUPPORTED". Fixed by creating the user-path tree before
  `UICommon::Init`, writing `SlotA = 1` / `SlotB = 255` in the launcher and
  `recomplauncher.json`, and forcing both keys on existing installs.
  Verified on a clean user dir: `GC/{USA,EUR,JAP}` and
  `GC/MemoryCardA.USA.raw` (16,777,216 bytes) are created, slot A is EXI
  type 1 (raw), and a Movie Lot career save changed the raw card from
  SHA-256 `75273788B863F156D8DF1157B4D4D3A19A305C7DC0E70F34F71CC864B7513BD1`
  to `B13262F7EFAA636368AF80CA283675C98CB367E3BA6F6C80F5C4D38725E7A1F8`
  (one `AGGR_INLINE` / `GILE` directory entry, 57 blocks). A fresh process
  then loaded it via Options -> Save & Load -> Load -> Slot A
  (`LOADING 'SKATER CAREER'...`) and resumed directly in Movie Lot, the
  saved park, with no character creation; the card SHA was unchanged.
  See [`notes/11-memory-card.md`](notes/11-memory-card.md) and the shared
  pattern in [`notes/12-memcard-shared-pattern.md`](notes/12-memcard-shared-pattern.md).
- **Player release v0.1.2 PUBLISHED (2026-11-16)**: contains the v0.1.1
  controller fix plus the memory-card fix. Zip size 26,125,343 bytes,
  SHA-256
  `6CAE9F3DA3DA7FA6954F74B6B176BC4D9488D3466D93B34089A24321A5B41C23`,
  2,662 files, no game data. Commit `a749ad6`, tag `v0.1.2`; release assets
  are the zip and `SHA256SUMS`. URL
  <https://github.com/Spaced1127/Aggressive-Inline-Static-Recomp/releases/tag/v0.1.2>.
  Notes in `work/release_notes_v0.1.2.md`. The published asset was downloaded
  and re-hashed; it matches. v0.1.1 was never published and is superseded.
- **Controller matrix check (v0.1.2)**: offline layout test **130/130** on the
  current build (Xbox 360/One/S/Series, Elite 1/2 incl. 0B22, DualSense,
  DualSense Edge USB/BT, Switch Pro USB/BT, 8BitDo Pro 2 USB/BT, Ultimate,
  64, D-pad reversal, migration/profile bindings). The live pad is an Xbox
  Series/One controller over USB (`045E:0B12`, XInput `045E:02FF`): detected
  as `SDL/0/Xbox One Controller`, `layout=xbox`, `source=guid`, profile names
  the exact device. Physical button presses were **not** verified - a 113 s
  XInput monitor captured no presses after the interactive prompt was
  interrupted. See [`notes/15-controller-matrix-v0.1.2.md`](notes/15-controller-matrix-v0.1.2.md).
  16:9 widescreen and the Hor+ widescreen hack are fixed in v0.0.2. The v0.0.1
  runner was a stale binary that ignored `aspect`/`widescreen_hack`; the new
  runner is built from the current ModernGekko source. See
  [`notes/04-widescreen.md`](notes/04-widescreen.md).
- Controller support expanded in v0.0.3: ready-made DualSense, DualShock 4/3,
  Xbox Wireless/Series/One/360, Switch Pro, Steam Controller and 8BitDo
  layouts, plus a launcher that reads the exact `SDL/<id>/<name>` from
  `dolphin.log`. See [`notes/05-controllers.md`](notes/05-controllers.md).
- Controller support is automatic in v0.0.4: the runner detects the first SDL
  pad and existing profiles fall back to the first SDL pad, so RecompLauncher
  installs need no controller page. The window is branded **Aggressive Inline**
  and sized from the selected 16:9 output resolution, with 2560x1440 as the
  default on 1440p+ desktops. See
  [`notes/06-controller-runtime-and-resolution.md`](notes/06-controller-runtime-and-resolution.md).
- Frame-time investigation: GPU is idle (~2-3 ms) and the game is CPU-bound.
  One captured window held 59.84 FPS; a later window in the same session hit
  1.54 s and 550 ms CPU stalls. That session began with a missing shader cache
  directory (now fixed); the stall window may include a transition/pause, so it
  is not yet attributed to a single cause. The launcher now creates the cache,
  enables cache affinity and pins to physical cores on 16-thread CPUs. See
  [`notes/03-performance.md`](notes/03-performance.md).
- **Level-start stutter reproduced and attributed (2026-11-21)**: Movie Lot,
  started from `work/memtest/levelselect.state` + one right press + A, shows a
  ~1.6 s freeze, a run of 100.1 ms frames for several seconds, further
  1.3-1.6 s freezes, and is still at 56.8 FPS / speed 0.948 after 30 s.
  PresentMon shows the GPU idle (~0.7 ms) and the emulated CPU thread running
  at ~100 % through the hitches. The Tutorial level has the same pattern but
  recovers to 60 FPS. Running the Tutorial through the Dolphin JIT core
  produces the same stalls, so it is not static-recomp dispatch overhead; warm
  shader caches and GPU texture decoding do not change it. Setting
  `[Core] FastDiscSpeed = True` shrinks Movie Lot's worst freeze from 1602 ms
  to 467 ms, removes the sustained 100 ms staircase, and restores
  59.95 FPS / speed 0.9997. Full data and reproduction in
  [`notes/14-movielot-stutter.md`](notes/14-movielot-stutter.md).
- **Level-start stutter fixed in source (2026-11-21, later)**: there were two
  causes. (1) No idle skipping. The static core idle-skips only at
  `[Core] StaticRecompIdlePC`, which GILE51 lacked, so the SDK `SelectThread`
  idle loop at `0x80143348` (the hottest dispatch site, ~30 % of samples) spun
  on the host. That left Movie Lot at 54 FPS / speed 0.92. (2) Emulated disc
  timing. The long freezes are whole numbers of vblanks in emulated time
  (100.1 ms = 6 VI, 1601.7 ms = 96 VI), so only `FastDiscSpeed` removes them.
  `assets/GameSettings/GILE51.ini` sets both and the release script ships it in
  `Sys/GameSettings/`. Measured via the game-settings path: worst frame
  1602 -> 479 ms, >50 ms frames 47 -> 14, all within ~3.5 s of pressing A, then
  59.94 FPS / speed 0.9998. A 2x CPU overclock does not help the remaining
  hitches. Not yet in a release. User play-test: Movie Lot and the other
  levels (unlocked with the in-game cheat `wwssadadBABA`, i.e. arrows plus the
  letters B A B A on the cheat keyboard) feel smooth.
- **Player release v0.1.3 PUBLISHED (2026-11-21)**: commit `04eea99`, tag
  `v0.1.3`, release assets the zip and `SHA256SUMS`, marked Latest. URL
  <https://github.com/Spaced1127/Aggressive-Inline-Static-Recomp/releases/tag/v0.1.3>.
  The published zip was downloaded and re-hashed; it matches. Contents: the
  level-start stutter fix
  (`Sys/GameSettings/GILE51.ini`) plus the generic controller system
  ([`notes/16-controller-generic.md`](notes/16-controller-generic.md)). Zip
  26,112,756 bytes, SHA-256
  `611D8586778C1B310C8E4A40938FA00F9833FEEA25BEE1CFC4ADB915443E6EA4`,
  2,646 files, no game data. Verified from the staged `gile.exe` with a user
  dir that has no settings of its own: Movie Lot worst frame 480 ms, 14 frames
  >50 ms, 59.94 FPS / 0.9995x after 30 s; idle-loop samples 425; Xbox One pad
  bound automatically. Launcher self-test 8/8; layout test passes. Notes:
  [`release-notes/v0.1.3.md`](release-notes/v0.1.3.md).
- **Dev controller binding (2026-11-21)**: an Xbox One pad did nothing in dev
  runs because the shared `moderngekko-run.exe` (built Nov 8) has no
  first-SDL-pad fallback and the dev profile names a DualSense. Dev launches now
  use `build\gile.exe`. With the profile unchanged (DualSense), it logged
  `configured device missing; bound "SDL/0/Xbox One Controller"`, the pad
  worked, and the game ran at 59.9 FPS. Release players were never affected.

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

## Audio (working)

Audio output works through DSP LLE + Cubeb. The user confirmed it; the earlier
"silence" was a muted output.

The older investigation in [`notes/01-bringup.md`](notes/01-bringup.md) recorded
zero DSP dumps and a zero AI DMA buffer. Those runs were made while the output
was muted, so they are **not** evidence of a DSP bug; the AX ucode upload and
AI DMA configuration seen there are normal. If a future run is silent, check:

1. Windows volume mixer, per-app volume for `gile.exe`.
2. The launcher's Audio page (mute checkbox / "No sound" backend).
3. The in-game Sound menu (SFX / Music / Speech volumes).

`work/saves/sound-menu.state` (24,428,124 bytes) boots straight to the Sound
menu if those values need checking.

## Next actions

1. **Visible test windows allowed for release verification (hub lifted the
   GUI pause)**: launch normally with visible windows; the hidden desktop is
   retired. If the hub pauses GUI/test launches again, stop all launches and
   do host-side work only. Remaining test actions: physical button
   confirmation on the connected Xbox pad, Edge / Elite / 8BitDo hardware,
   Bluetooth vs USB, connect-after-launch, and the coverage runs below.
2. **v0.1.3 published** (latest): commit `04eea99`, tag `v0.1.3`, zip SHA-256
   `611D8586778C1B310C8E4A40938FA00F9833FEEA25BEE1CFC4ADB915443E6EA4`.
   Post-release: ask players for the `controller:` lines, Edge / Elite /
   8BitDo confirmation, and whether any level still hitches outside the
   LOADING screen. Only an Xbox Series/One USB pad is present on this machine.
3. **Audio**: working. No action; if a report says silent, check the Windows
   per-app mixer, the launcher Audio page and the in-game Sound menu first.
4. **Performance / level-start stutter**: shipped in v0.1.3. Fixed by
   `assets/GameSettings/GILE51.ini` (`StaticRecompIdlePC = 0x80143348`,
   `FastDiscSpeed = True`), shipped into `Sys/GameSettings/` by
   `tools/make_release_gile.ps1`. No launcher or `recomplauncher.json` change
   is needed. Next: validate the intro FMV, audio by ear, a level transition
   and a long Movie Lot session, then cut a release. The remaining ~0.5 s
   hitches during the LOADING splash are transfer waits, not CPU work. See
   [`notes/14-movielot-stutter.md`](notes/14-movielot-stutter.md).
5. **Coverage**: memory-card save/load is done. Remaining: complete the
   tutorial, level transitions, pause, and at least one full level (blocked by
   the launch pause).
6. **SMC review**: inspect the 100 `generated_smc.txt` ranges; only patch sites
   that actually write executable memory at runtime.
7. **Packaging**: done for v0.1.0. The launcher accepts ISO, RVZ or an extracted
   folder, verifies `GILE51`/DOL hash, extracts to
   `%LOCALAPPDATA%\AggressiveInlineRecomp`, and starts the bundled module.
   The release ships the full `defaults/GCPadNew*.ini` preset set, branded
   `gile.exe`/`gile-launcher.exe` version info and 16:9 window sizing. See
   [`notes/06-controller-runtime-and-resolution.md`](notes/06-controller-runtime-and-resolution.md).
8. **Frame-time validation**: with `GILE51.ini`, capture a 60 s Movie Lot
   gameplay window and a level transition. Other levels may wait in different
   loops; check `STATICRECOMP_DISPATCH_SAMPLES=1` output for a new hot spin
   site before considering PGO. See
   [`notes/03-performance.md`](notes/03-performance.md) and
   [`notes/14-movielot-stutter.md`](notes/14-movielot-stutter.md).
9. **zgui host function**: implement or stub `inlineOverlayGetNumContinues`
   (`Continues`), which logs "Host function not Found" in the UI overlay.

## Known risks

- **Controller hotfix unverified on hardware**: no Xbox, DualSense Edge, Elite or
  8BitDo pad is connected on this machine, so v0.1.1 rests on SDL's DB rows plus
  the restored device fallback. The first player report after release must be
  checked against the two `controller` log lines.
- **8BitDo mode ambiguity**: a Pro 2 reports B below A in both Nintendo and
  standard HID mode, so the automatic Nintendo swap cannot distinguish them. The
  manual presets (`8bitdo`, `8bitdo-nintendo`) are the override.
- **Concurrent controller work**: another session in this window edited
  `tools/controller_layout.hpp` (vendor-family fallback, `source=guid-family`)
  and `tests/controller_layout_test.cpp` while this fix was in progress. Both
  sets of changes are kept and the combined tree passes 130/130 + 80/80.

- **Audio**: working through DSP LLE + Cubeb. Silence is a mute/config issue,
  not a port bug.
- **Self-modifying code**: 100 flagged ranges; boot/gameplay currently OK, but a
  real text patch later could need an explicit DolRecomp patch.
- **h4m/PSS video**: the intro movies render and use the working audio path.
- **Memory card**: slot A raw card save + load verified. See
  [`notes/11-memory-card.md`](notes/11-memory-card.md). Old savestates made
  under the GCI-folder setup restore that device type and should not be
  used for memcard testing.
- **Performance**: the Clang module is at the 60 FPS cap in steady gameplay at
  3x internal. The Movie Lot stutter fix (`GILE51.ini`: idle PC + fast disc)
  ships in v0.1.3. The user play-tested it, but the intro FMV and audio have
  not been specifically re-checked with it. ~0.5 s hitches remain during the LOADING splash (transfer waits). The v0.0.1 release asset predates
  the `Cache\Shaders`, affinity and generic runner fixes; v0.0.2+ contain them.
  See [`notes/14-movielot-stutter.md`](notes/14-movielot-stutter.md).
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

# Dev run windowed (build\gile.exe; any SDL pad; extra args pass through,
# e.g. --load-state work\memtest\levelselect.state)
tools\run_dev.bat

# Build the player release (stage + zip)
powershell -ExecutionPolicy Bypass -File tools\make_release_gile.ps1 -Version 0.1.0

# Headless automation screenshots
powershell -ExecutionPolicy Bypass -File tools\auto_probe.ps1 -Seconds 50 -Shots 10,25,45

# Frame-time capture (start PresentMon before the game, stop manually)
powershell -ExecutionPolicy Bypass -File tools\capture_session.ps1 -Seconds 600 -ProcessName gile

# Dev-build FPS probe with save-state load and scripted movement
powershell -ExecutionPolicy Bypass -File tools\perf_probe.ps1 -Seconds 30

# Movie Lot level-start frame trace (normal and fast disc)
powershell -ExecutionPolicy Bypass -File tools\perf\capture_level_start.ps1 `
  -UserDir work\perf_stutter\movielot_user -StartLevel -RightPresses 1 `
  -Tag movielot-cold -CaptureSeconds 30
```
