# v0.0.4 - automatic controllers, branding and 16:9 resolution

Date: 2026-11-14

## 1. Controllers without the launcher page

### Symptom

RecompLauncher starts `gile-launcher.exe --game ...` directly. It never opens
the WinForms controller page, so an Xbox/PlayStation/Switch pad produced no
input.

### Root cause

Two defaults combined badly:

- The v0.0.3 launcher's `EnsureConfig` copied `defaults/GCPadNew.ini` whenever
  `Config/GCPadNew.ini` was missing. That file names
  `SDL/0/DualSense Wireless Controller`.
- The runner only auto-detects a pad in `EnsureDefaultControllerConfig`, and
  that function returns early when `GCPadNew.ini` already exists.

So the launcher pre-seeded a DualSense-only profile and blocked the runner's
auto-detection. Dolphin then compared `SDL/0/DualSense Wireless Controller`
against the connected pad with `DeviceQualifier::operator==`, which requires an
exact id, name and source match. The pad was never bound.

### Fix

1. **No pre-seeded profile.** `EnsureConfig` now creates a controller profile
   only when `logs/dolphin.log` already names a pad, and writes that exact SDL
   name. Otherwise it leaves `GCPadNew.ini` absent, so the runner's
   `EnsureDefaultControllerConfig` detects the first connected SDL gamepad and
   generates the standard mapping.
2. **Runtime fallback.** `DeviceContainer::FindDevice` in Dolphin's
   `CoreDevice.cpp` now falls back to the first SDL device when the configured
   SDL device is not present. Existing profiles from v0.0.3 therefore still
   work after an upgrade.
3. **No launcher dependency.** Both paths run inside the game/launcher pair
   that RecompLauncher starts, so no controller selection UI is required.

The fallback logs once:

```
controller: configured device 'SDL/0/DualSense Wireless Controller' not found; using 'Xbox One Controller'
```

A fresh install logs:

```
controller: 1 SDL joystick(s) detected
controller configuration: 1 GameCube controller mapped
```

and writes:

```
[GCPad1]
Device = SDL/0/Xbox One Controller
Buttons/A = `Button A`
...
```

### Runtime patch

The fallback is a small patch to:

```
vendor/dolphin/Source/Core/InputCommon/ControllerInterface/CoreDevice.cpp
```

The patch is stored in
[`patches/dolphin-sdl-controller-fallback.patch`](../patches/dolphin-sdl-controller-fallback.patch).
The SB-RFD Dolphin source is restored after building; the release runner
contains the compiled fallback.

## 2. Aggressive Inline branding

### Symptom

The game window and Task Manager showed `ModernGekko`, not `Aggressive Inline`.

### Root cause

`dolphin_runtime.cpp` builds the title as:

```
ModernGekko - <game name> [<disc id>]
```

and the generic runner was compiled with
`MODERNGEKKO_DEFAULT_WINDOW_TITLE="ModernGekko - "`. The launcher did not pass
`--title`. The executables also had no product identity beyond the C# compiler's
minimal version resource.

### Fix

- The generic runner was rebuilt with
  `MODERNGEKKO_DEFAULT_WINDOW_TITLE="Aggressive Inline"`.
- The launcher passes `--title "Aggressive Inline"` on every run, including the
  RecompLauncher CLI path.
- `tools/set_version_info.cs` stamps both `gile.exe` and `gile-launcher.exe`:

| Field | Value |
|---|---|
| FileDescription | `Aggressive Inline` / `Aggressive Inline Launcher` |
| ProductName | `Aggressive Inline Static Recomp` |
| CompanyName | `Aggressive Inline Recomp` |
| FileVersion | `0.0.4.0` |
| OriginalFilename | `gile.exe` / `gile-launcher.exe` |

Verified window title:

```
Aggressive Inline | 0.0 FPS
```

## 3. 16:9 resolutions and full-screen sizing

### Symptom

The resolution choices were not full-screen 16:9 sizes. `2560x1440` was listed
but did not produce a 2560x1440 window, and new installs were pillarboxed at
4:3.

### Root causes

- The launcher's 1x label was `640x528` (a 4:3 EFB size) and the RecompLauncher
  JSON labels were 4:3 visible sizes (`640x448`, `1280x896`, `1920x1344`,
  `2560x1792`, ...).
- `config.ini resolution` only selected Dolphin's integer EFB scale. It did not
  set the window size.
- `PlatformWin32` creates the window from
  `[Display] RenderWindowWidth/Height` in `Dolphin.ini`, whose defaults are
  1556x934. The launcher only resized the window for borderless/fullscreen;
  Windowed mode stayed small.
- New `config.ini` files defaulted to `aspect=auto` and
  `widescreen_hack=false`, which is 4:3 pillarboxed on a 16:9 display.

### Fix

- All resolution labels are 16:9: `640x360`, `1280x720`, `1920x1080`,
  `2560x1440`, `3840x2160`, `5120x2880`, `7680x4320`.
- The default resolution follows the primary display, capped at 2560x1440:
  a 1440p or 4K desktop starts at **4x (2560x1440)**.
- The selected resolution writes `Dolphin.ini [Display] RenderWindowWidth` and
  `RenderWindowHeight`, so Windowed mode is the real selected size and
  Fullscreen windowed fills the monitor.
- New configs default to `aspect=wide` and `widescreen_hack=true`.
- A one-time migration moves a v0.0.3 config still on `1920x1080` + Auto/off to
  `2560x1440` + 16:9 + widescreen hack on a 1440p display. A later explicit
  4:3 choice is preserved (marker `Launcher/AspectMigratedV004`).
- `recomplauncher.json` uses the same 16:9 labels and defaults.

Note: 4x is 4x the 640x528 EFB (`2560x2112` internal) presented at the selected
16:9 output size (`2560x1440`). The label is the output/window size.

### Verification

- UI: selecting 3x wrote `resolution=1920x1080` and
  `RenderWindowWidth=1920`, `RenderWindowHeight=1080`; selecting 4x wrote
  `2560x1440`.
- Runner: a 2560x1440 config produced a 2560x1440 window and the log line
  `[video] backend=Vulkan scale=4 ... aspect=1 widescreen=1 fullscreen=0`.
- Fresh install: `config.ini resolution=2560x1440`, `Dolphin.ini` window
  2560x1440, controller profile auto-created for the connected Xbox One pad,
  window title `Aggressive Inline | 0.0 FPS`.
- Upgrade: a v0.0.3 DualSense profile with an Xbox pad connected logged the
  fallback to `Xbox One Controller` and started at 2560x1440.

## v0.0.4 artifact

```
dist/AggressiveInline-Recomp-v0.0.4-Windows-x64.zip
Size:    26,080,740 bytes
SHA-256: 9AA57FE8DD09845B3FF5822340D38B839346AA2E676050A66E1B20B0092F7789
```

No game data is included.

## Limitations

- The controller is detected and bound, but a physical button walk-through on
  every pad family is still recommended.
- The internal EFB remains 4:3 at integer scales. The 16:9 output is produced by
  Dolphin's presentation path, not by a 16:9 EFB.
- The official Wii U GameCube adapter uses Dolphin's native adapter path, not
  these SDL profiles.
