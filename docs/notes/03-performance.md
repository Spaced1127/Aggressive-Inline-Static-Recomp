# Performance investigation - frame drops

Date: 2026-11-10

## Hardware

- Ryzen 7 7800X3D (8 cores / 16 threads, 96 MB L3)
- Radeon RX 7900 XT
- Windows Ultimate Performance power plan
- Release build: Clang `-O3` module, Vulkan, 3x native internal resolution

## Captures

Frame times were captured with PresentMon 2.5.1 (`--process_name gile.exe`,
`--output_file ...`, `--no_console_stats`). Raw CSVs are local, not committed.

### Smooth gameplay window

`pm-test2.csv` (19:02:29, 8.84 s, 530 frames):

- Average **59.84 FPS**
- p50 16.69 ms, p95 17.30 ms, p99 18.06 ms
- 3 frames over 20 ms, 1 frame over 33 ms (33.92 ms)
- GPU busy ~2-3 ms

This is the expected steady state.

### Stall window

`pm-session2.csv` (19:02:52, 8.89 s, 229 frames):

- Average **25.71 FPS**
- 37 frames over 50 ms, 31 over 100 ms
- Worst frames: **1539.7 ms**, **550.9 ms**, then a run of 100-133 ms frames
- CPU busy tracks the frame time almost exactly (1539 ms CPU vs 2.1 ms GPU)
- No presents after the last captured frame until the game exits

The GPU is idle throughout: this is a **CPU-side stall**, not a rendering
bottleneck. The 100 ms frames form a ~3.5 s burst after the 1.5 s stall, which
looks like a synchronous burst of asset/shader work. The game log has no
`Loading scene data` line at that time, so it is not a normal level load.
The capture also stops presenting shortly afterwards; the user may have paused,
minimized, or opened a menu, so this window is not sufficient to attribute the
stall on its own.

### Warm run

After the first session, the shader/pipeline cache contained an 11.4 MB
`Vulkan-Pipeline-*.cache`. A later run (19:05-19:06) showed:

- **53.8 FPS** during `Loading scene data`
- **59.3 FPS** a few seconds later in the level

The warm run did not reproduce the 1.5 s stall in the short window we observed.

## Confirmed bug: shader cache directory

The release user directory had no `Cache\Shaders`. Dolphin creates it with a
single-level `File::CreateDir`, which fails because `Cache` does not exist:

```
Common\FileUtil.cpp:209 E[COMMON]: CreateDir: failed on .../Cache/Shaders/
```

Consequences:

- The shader/pipeline cache is not persisted across launches.
- Every launch rebuilds pipelines, and first-use compilation appears as CPU
  frame-time spikes.

Manually creating `Cache\Shaders` made the runtime write the expected files:

```
Vulkan-Pipeline-<hash>.cache
Vulkan-uber-vs-<hash>.cache
Vulkan-uber-ps-<hash>.cache
Vulkan-specialized-vs-GILE51-<hash>.cache
Vulkan-specialized-ps-GILE51-<hash>.cache
Vulkan-gs-<hash>.cache
```

## Launcher fixes (source)

`tools/gile_launcher.cs` now:

1. Creates `<user-dir>\Cache\Shaders` in `EnsureConfig`.
2. Sets `MODERNGEKKO_CACHE_AFFINITY=1` for the runner.
3. Pins `gile.exe` to `0xFF` (one thread per physical core) when the host has
   at least 16 logical processors. The RPBB project measured ~20% from this.
4. Writes `logs\perf-YYYYMMDD-HHmmss.csv` once per second:
   `timestamp,fps,working_set_mb,cpu_seconds`.

The fixed launcher has been compiled locally but is **not** in the v0.0.1
release asset yet. A v0.0.2 package can be built after the next validation run.

## Remaining work

1. Capture a clean active-gameplay window with the fixed launcher and warm
   shader cache. The capture should cover at least 2-3 minutes of skating.
2. Compare that window against `pm-test2`/`pm-session2`; if 100 ms+ stalls
   remain, build a PGO module from a gameplay profile.
3. The log also shows a missing zgui host function:
   `inlineOverlayGetNumContinues` (`Continues`). This is a UI/overlay path, not
   the frame-time issue, but it should be implemented or stubbed.
4. If stalls correlate with texture uploads, investigate
   `VKTexture.cpp:396` (`Executing command list while waiting for space in
   texture upload buffer`). No such warning was present in the captured
   windows.

## Capture notes

PresentMon 2.5.1 with `--timed`/`--stop_existing_session` can hang and leave a
stale ETW session. The reliable path used here:

1. Start PresentMon detached with a unique `--session_name`, no `--timed`.
2. Start the game.
3. Stop the PresentMon process and terminate the session by name when done.

`tools/capture_session.ps1` and `tools/sample_process.ps1` automate the capture
and process-memory logging. `tools/perf_probe.ps1` measures the dev build with
the runtime's automation channel.
