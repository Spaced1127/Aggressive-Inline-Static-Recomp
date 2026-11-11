# Widescreen / 16:9 fix - v0.0.2

Date: 2026-11-10

## Symptom

The launcher and RecompLauncher settings were saved correctly:

```
Aspect = wide
WidescreenHack = true
```

and `config.ini` contained:

```
aspect = wide
widescreen_hack = true
```

but the game still rendered 4:3 with no wider FOV.

## Root cause

The shipped `gile.exe` was a stale `moderngekko-run.exe` built on 2026-11-08.
It predates the runtime's aspect/widescreen support. The binary does not
contain the strings `widescreen_hack`, `aspect=%d` or `[video] backend=`, and it
never prints the `[video]` configuration line. The launcher wrote the settings,
but the runner had no code to apply them.

Newer runner binaries in the same workspace (`SpongeBobRecompRunner.exe`,
`rpbb.exe`) do contain the aspect code, but they enforce their own disc ID and
DOL SHA-256, so they reject `GILE51`.

A generic runner was built from the current `moderngekko_run.cpp` source and
the current runtime libraries, with the game-specific defines removed. The
runner must be started with `--core static`; the current source otherwise
selects the JIT path and does not load the module.

## Fix

- `gile.exe` in the release is the new generic runner.
- The launcher now passes `--core static` explicitly.
- The release folder keeps `Sys/GC/dsp_rom.bin` and `dsp_coef.bin` next to the
  runner; without them DSP LLE fails with "Failed to initialize DSP emulation!"
  and the core never boots.

## Verification

With `aspect=wide`, `widescreen_hack=true`, borderless 2560x1440:

```
[video] backend=Vulkan scale=3 msaa=1 ssaa=0 af=0 vsync=0 aspect=1 widescreen=1 fullscreen=0
```

Frame-dump comparison of the same save state:

| Setting | Output size | Aspect |
|---|---:|---:|
| 4:3 (auto, hack off) | 1844x1416 | 1.302 |
| 16:9 (wide, hack on) | 2459x1416 | 1.737 |

The 16:9 capture has a wider horizontal field of view (Hor+), not a stretched
4:3 image. Evidence:
`work/evidence/ws-generic-wide3.png` and `work/evidence/ws-final.png`.

## v0.0.2 artifact

```
dist/AggressiveInline-Recomp-v0.0.2-Windows-x64.zip
Size:    26,067,805 bytes
SHA-256: A0880D10D0C3D08C42B4E503044F695311C522BA7F1C096AA2499B856DF13C38
```

The release contains no game data. The player-facing **Aspect ratio** and
**Widescreen hack** settings now work as described in `PLAYERS.md`.

## Rebuild notes

The generic runner was produced by:

1. Compiling `moderngekko_run.cpp` with
   `MODERNGEKKO_RUNNER_NAME=moderngekko-run`,
   `MODERNGEKKO_USER_DIRECTORY_NAME=moderngekko`,
   `MODERNGEKKO_PORTABLE_DEFAULT_GAME=1`, and no
   `MODERNGEKKO_REQUIRED_DISC_ID` / `MODERNGEKKO_REQUIRED_DOL_SHA256`.
2. Temporarily pointing the `SpongeBobRecompRunner.exe` link line in the SB-RFD
   `build.ninja` at the generic object, running Ninja, and restoring the
   original manifest and SB runner afterwards.
3. Copying the resulting executable to `build/gile.exe`.

`tools/patch_ninja_generic.py` performs step 2; the SB-RFD build itself is not
modified permanently.

## Notes

- `aspect=wide` alone stretches the 4:3 image to the window.
- `aspect=wide` + `widescreen_hack=true` gives Hor+ and is the recommended
  16:9 setting.
- `aspect=auto` + `widescreen_hack=true` does nothing unless the game is
  detected as anamorphic; this game is 4:3.
