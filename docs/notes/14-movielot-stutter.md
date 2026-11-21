# Movie Lot level-start stutter

Date: 2026-11-21

Player report: the first few seconds of a level are very stuttery. The first
Movie Lot level is the worst case; the Tutorial level also hitches but recovers
to 60 FPS.

This investigation reproduced the report, measured it per frame, and isolated
the dominant cause to **emulated GameCube disc speed**. It is not the static
recompiler, the Vulkan backend, or the shader cache.

## Reproduction

1. Start the static runner with the level-select save state:

   ```powershell
   moderngekko-run.exe --game work\game `
     --module build\gGILE51_recomp_clang.dll `
     --user-dir work\perf_stutter\movielot_user `
     --audio cubeb --automation-dir work\perf_stutter\automation `
     --load-state work\memtest\levelselect.state
   ```

2. Wait until the emulator is idle at Level Select.
3. Send one right press (`main_x=1`, 20 frames) to select **Movie Lot**, then
   `A` (20 frames) to start it.
4. Capture frame times with PresentMon 2.6.0 attached to the running process:

   ```powershell
   PresentMon.exe --process_id <pid> --output_file <csv> --no_console_stats `
     --session_name GilePerf --timed 40 --terminate_after_timed
   ```

The scripts used here are committed in
[`tools/perf/`](../../tools/perf/) (`capture_level_start.ps1`,
`sample_threads.ps1`, `record_level_start.ps1`), with working copies and raw
captures under `work/perf_stutter/` (ignored by git).

## Measurements

Frame times from PresentMon (`MsBetweenPresents`). "post" is the runtime's own
status after the capture window.

| Scenario | Frames | avg ms | p50 | p95 | p99 | max | >50 ms | >100 ms | post FPS / speed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Tutorial, normal disc | 1380 | 22.42 | 16.68 | 17.23 | 116.81 | 1718.37 | 21 | 21 | 59.95 / 0.9999 |
| Tutorial, fast disc | 1778 | 17.41 | 16.69 | 17.14 | 17.70 | 466.89 | 8 | 7 | 59.94 / 0.9997 |
| **Movie Lot, normal disc** | 1357 | **26.48** | 17.23 | 22.11 | 133.22 | **1601.87** | **55** | **48** | **56.78 / 0.9483** |
| **Movie Lot, fast disc** | 2238 | **18.30** | 16.91 | 19.59 | 26.20 | **466.78** | **14** | **12** | **59.95 / 0.9997** |

Movie Lot, normal disc, is a staircase: 466 ms, then 1602 ms, then a run of
**100.1 ms frames** for several seconds, then further 1.30-1.60 s freezes. The
level is still at 52-57 FPS (speed 0.89-0.95) 20-30 s after it starts. The
Tutorial level recovers to 60 FPS but still has the same shape in the first few
seconds.

With `FastDiscSpeed = True` (Dolphin `[Core]` setting, i.e. treat all disc reads
as buffered), the stutter window shrinks to roughly 2.3 s of load (3.8-6.1 s
after pressing A) and the run returns to 59.95 FPS / speed 0.9997. The worst
remaining frame is 467 ms.

## What it is not

- **Not the static recompiler.** Running the same Tutorial level through the
  Dolphin JIT core (`MODERNGEKKO_STATICRECOMP=0`, `cpu_core=jit`) produced the
  same 50/104/100/100/350/517 ms pattern. Movie Lot was not re-run under JIT.
- **Not the shader cache or pipeline compilation.** A warm `Cache\Shaders`
  (including the 10 MB Vulkan pipeline cache) did not change the Movie Lot
  frame trace. The runtime already uses `AsynchronousUberShaders` with
  `WaitForShadersBeforeStarting`.
- **Not GPU texture decoding.** Enabling `EnableGPUTextureDecoding` produced the
  same Tutorial frame trace.
- **Not the GPU.** `MsGPUTime` stays around 0.7-1.8 ms through every stall;
  PresentMon's CPU time tracks the frame time exactly.
- **Not a sleep or a fixed timeout.** A thread sampler (`sample_threads.ps1`)
  showed the emulated CPU thread running at ~100 % through the 100 ms frames,
  with only short 15.6 ms `Wait UserRequest` slices. The CPU is executing guest
  code (the game's loading loop) while the frame interval grows.

## Likely mechanism

The game's loader waits on emulated disc reads. With normal disc timing the
guest spends entire host frames in that loop, and the runtime presents the next
frame only when the loop yields. `FastDiscSpeed` removes the emulated
seek/rotational/raw-read latency, so the loader advances after far less guest
work. This is consistent with the 100 ms staircase disappearing and the
sustained speed returning to 1.0.

The remaining 100-467 ms hitches under fast disc are a second, smaller source
(first-use level asset work / uploads) and are not yet attributed. They occur
during the load transition, before gameplay is stable.

## Recommended next steps

1. **Ship `FastDiscSpeed = True` for this port.** Add it to:
   - `tools/gile_launcher.cs` (`EnsureConfig` / the forced config keys)
   - `recomplauncher.json` (`config` -> `ensure`, `always`, and `new`)
   - `work/user/Config/Dolphin.ini` for dev runs (or the runner default for
     this port only).

   Then validate: Movie Lot 60 s of gameplay at 60 FPS, a level transition
   (Movie Lot -> another level), the intro FMV, and audio (music/SFX/speech).

2. **Attribute the remaining fast-disc hitches.** Re-run the Movie Lot capture
   with a null audio backend, with GPU texture decoding, and with a warm vs
   cold pipeline cache. If they are texture uploads, the next place to look is
   `VKTexture`/`TextureCacheBase`; if they are asset parsing, profile the
   remaining load loop.

3. **Do not chase the static module first.** The JIT comparison rules out
   dispatch overhead as the dominant cause. PGO is a possible later refinement
   for the remaining load work, not the fix for the 1.6 s freezes.

## Follow-up: idle loop and the fix (2026-11-21, later)

### Corrections to the sections above

- The JIT and GPU-texture-decoding comparisons were run with
  `FastDiscSpeed = True` in `jit_user` / `gputex_user`. They rule things out
  only for the remaining fast-disc hitches, not for the normal-disc staircase.
- The 100 ms staircase and the 1.3-1.6 s freezes are **emulated-time** stalls,
  not host slowness. Every long frame is a whole number of vblanks
  (100.1 ms = 6 VI, 116.8 = 7, 133.3 = 8, 1601.7 = 96). They reproduce
  frame-for-frame with and without the idle fix below. The game simply does not
  present while it waits on emulated disc reads.

### Root cause of the sustained slowdown: no idle skipping

ModernGekko's static core idle-skips only at one configured PC
(`[Core] StaticRecompIdlePC`, `StaticRecompCore_Run.cpp`). GILE51 had none.
Dispatch sampling (`STATICRECOMP_DISPATCH_SAMPLES=1`) during the Movie Lot run
showed the hottest guest site at `0x80143348`: 6,720 samples, ~30 % of all
samples. That is the SDK `SelectThread` idle loop:

```
80143344  bl    OSEnableInterrupts      (0x80140944)
80143348  lwz   r0, -28232(r13)         RunQueueBits
8014334c  cmplwi r0, 0
80143350  beq   0x80143348
80143354  bl    OSDisableInterrupts     (0x80140930)
```

Dolphin's JIT detects this loop and skips it. The static core spun on it once per
dispatch, and that cost more host time than the cycles it charged. The more
time the game spent waiting on the disc, the further emulation fell behind:
Movie Lot gameplay at 54 FPS / speed 0.92. `FastDiscSpeed` hid most of it by
shortening the waits.

`tools/perf/find_spin_loops.py` lists short polling loops in the DOL and
`tools/perf/dol_context.py` prints the code around one. The other matches
(`0x80129220`, `0x801419d8`, `0x80141a08`) are one-off init waits.

### Measurements (Movie Lot, warm caches, 30 s after pressing A)

| Config | frames | avg ms | p95 | max | >50 ms | sum >50 ms | post FPS / speed |
|---|---:|---:|---:|---:|---:|---:|---|
| Normal disc (baseline) | 1340 | 26.82 | 29.87 | 1601.7 | 47 | 12547 | 54.10 / 0.918 |
| Normal disc + idle PC | 1447 | 24.84 | 18.61 | 1601.7 | 47 | 12563 | 59.94 / 1.001 |
| Fast disc only (earlier run) | 2238 | 18.30 | 19.57 | 466.8 | 14 | 2553 | 59.95 / 0.9997 |
| **Fast disc + idle PC** | 2015 | 17.83 | 17.51 | 485.1 | 14 | 2520 | **59.94 / 0.9994** |
| Fast disc + idle PC, 2x CPU overclock | 1998 | 17.99 | 18.13 | 465.7 | 12 | 2668 | 59.93 / 1.001 |
| **Shipped `GILE51.ini` (game-settings path)** | 2015 | 17.84 | 17.39 | 478.8 | 14 | 2536 | **59.94 / 0.9998** |

- The idle PC fixes the sustained slowdown. Fast disc removes the long freezes.
  Together, every hitch is confined to ~3.5 s right after pressing A (the
  LOADING splash and first frames), worst frame ~480 ms. Afterwards the game
  holds 60 FPS.
- Doubling the emulated CPU clock does not shrink the remaining hitches, and it
  costs host time at Level Select (speed 0.92 there). So they are waits on
  transfers (DVD buffer at 32 MiB/s, DMA or ARAM), not guest CPU work.
  Overclock is not used.

### Shipped fix

`assets/GameSettings/GILE51.ini` sets `StaticRecompIdlePC = 0x80143348` and
`FastDiscSpeed = True`. `tools/make_release_gile.ps1` copies it into the staged
`Sys/GameSettings/`, so it applies by game ID regardless of launcher, and the
launcher/`recomplauncher.json` need no change. For dev runs with the shared
runner, copy it to `<user-dir>\GameSettings\GILE51.ini`. The `gameini` run above
used exactly that path.

Still to validate: intro FMV, audio (music/SFX/speech) by ear, a level
transition, and a long Movie Lot session.

## Raw data

PresentMon CSVs and screenshots are local under
`work/perf_stutter/captures/` (ignored by git). They can be regenerated with
`tools/perf/capture_level_start.ps1`, for example:

- `movielot-cold-20261121-084501.csv` - normal disc, 35 s
- `movielot-fastdisc-20261121-084619.csv` - fast disc, 35 s
- `levelstart-jit2-20261121-084003.csv` - Tutorial JIT comparison
- `movielot-cold-20261121-084501-after.png` - Movie Lot gameplay
- `movielot-fastdisc-20261121-084619-after.png` - game-over screen (idle run)
- `idle-base-20261121-094311.csv` - normal disc, dispatch samples
- `idle-pc-20261121-094418.csv` - normal disc + idle PC
- `idle-fast-20261121-094556.csv` - fast disc + idle PC
- `idle-fast-oc2-20261121-094710.csv` - fast disc + idle PC + 2x overclock
- `gameini-20261121-094913.csv` - `GILE51.ini` via `<user>\GameSettings`

Summaries: `python tools\perf\summarize_presentmon.py <csv>... --timeline`.