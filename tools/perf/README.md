# Level-start performance probes

These scripts reproduce the Movie Lot / Tutorial stutter described in
[`docs/notes/14-movielot-stutter.md`](../../docs/notes/14-movielot-stutter.md).

They are development helpers. They launch the game in a visible window, so run
them only when a test launch is allowed. All captures and user directories are
written under `work/perf_stutter/` (ignored by git).

## capture_level_start.ps1

Starts the runner with `work/memtest/levelselect.state`, optionally selects a
level with right presses, presses A, captures a PresentMon CSV, and takes a
before/after screenshot.

```powershell
# Movie Lot (one step right on Level Select)
powershell -ExecutionPolicy Bypass -File tools\perf\capture_level_start.ps1 `
  -StartLevel -RightPresses 1 -Tag movielot-cold -CaptureSeconds 30

# Tutorial (no right press)
powershell -ExecutionPolicy Bypass -File tools\perf\capture_level_start.ps1 `
  -StartLevel -Tag tutorial-cold -CaptureSeconds 30
```

PresentMon 2.6.0 is expected at
`H:\Projects\RPBB-GCN-Recomp\work\PresentMon.exe`. The script attaches by
process ID after the game is running; starting PresentMon by process name
before the game exists does not capture reliably.

To compare against the JIT core, add `-Core jit`. That writes `cpu_core=jit`
to the probe's `config.ini` and runs with `MODERNGEKKO_STATICRECOMP=0`.

To compare disc timing, add `FastDiscSpeed = True` under `[Core]` in the
probe's `Config/Dolphin.ini`.

To test the shipped fix, copy `assets/GameSettings/GILE51.ini` to
`<UserDir>\GameSettings\GILE51.ini`. Set `STATICRECOMP_DISPATCH_SAMPLES=1`
before running to get the 16 hottest guest dispatch sites in the stderr log at
shutdown.

## summarize_presentmon.py

Prints frames, avg, p50/p95/p99, max, and counts of >50 ms / >100 ms frames
for one or more captures. `--timeline` lists each >50 ms frame with its offset.

```powershell
python tools\perf\summarize_presentmon.py work\perf_stutter\captures\a.csv b.csv --timeline
```

## find_spin_loops.py / dol_context.py

Static helpers for choosing `StaticRecompIdlePC`. `find_spin_loops.py` lists
short backward-branch loops with loads and no calls or stores.
`dol_context.py` prints the words and branch targets around an address.

```powershell
python tools\perf\find_spin_loops.py work\disc\main.dol --max-len 5
python tools\perf\dol_context.py work\disc\main.dol 0x80143348
```

## sample_threads.ps1

Samples per-thread CPU time and wait states while the level starts. Use it to
distinguish a sleeping/waiting CPU thread from one that is executing guest
code.

```powershell
powershell -ExecutionPolicy Bypass -File tools\perf\sample_threads.ps1 `
  -RightPresses 1 -Seconds 16 -Tag movielot-threads
```

The emulated CPU thread is the one at ~100 %; the GPU thread is usually
20-40 % and shows ~0.7 ms GPU time in PresentMon. During the Movie Lot hitches
the CPU thread was running, not waiting.

## record_level_start.ps1

Records the desktop with ffmpeg (15 FPS) and writes a contact sheet, for visual
context around the transition. ffmpeg is expected at
`H:\Tools\ffmpeg\bin\ffmpeg.exe`.

```powershell
powershell -ExecutionPolicy Bypass -File tools\perf\record_level_start.ps1 `
  -RightPresses 1 -Seconds 18 -Tag visual-movielot
```

The Movie Lot transition shows the "LOADING..." splash, then the first
gameplay frame. The frame-time spikes happen while that splash is on screen and
in the first seconds after it.