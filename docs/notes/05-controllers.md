# Controller layouts and exact SDL device matching - v0.0.3

Date: 2026-11-11

## Symptom

A player reported that an Xbox controller did not work. The game still booted,
but the pad produced no input.

## Root cause

The release shipped one profile, `defaults/GCPadNew.ini`, with:

```
[GCPad1]
Device = SDL/0/DualSense Wireless Controller
```

ModernGekko/Dolphin resolves a configured pad with
`DeviceQualifier::operator==`, which compares all three fields:

- source (`SDL`)
- device id (`0`)
- device name (`DualSense Wireless Controller`)

There is no wildcard and no family match. An Xbox pad is exposed under a
different SDL name (and sometimes a different id when another pad is already
connected), so the DualSense profile never binds. The game receives no input.

## Fix

### Presets

`defaults/` now contains a layout for each major family. Every preset has the
full GameCube mapping and only the default `Device` line differs:

| Preset | Default SDL device |
|---|---|
| `GCPadNew.ini` | `SDL/0/DualSense Wireless Controller` |
| `GCPadNew.dualsense.ini` | `SDL/0/DualSense Wireless Controller` |
| `GCPadNew.dualshock4.ini` | `SDL/0/PS4 Controller` |
| `GCPadNew.dualshock3.ini` | `SDL/0/PS3 Controller` |
| `GCPadNew.xbox.ini` | `SDL/0/Xbox Wireless Controller` |
| `GCPadNew.xbox-series.ini` | `SDL/0/Xbox Series X Controller` |
| `GCPadNew.xbox-one.ini` | `SDL/0/Xbox One Controller` |
| `GCPadNew.xbox360.ini` | `SDL/0/Xbox 360 Controller` |
| `GCPadNew.xbox-generic.ini` | `SDL/0/Xbox Controller` |
| `GCPadNew.switch-pro.ini` | `SDL/0/Nintendo Switch Pro Controller` |
| `GCPadNew.steam.ini` | `SDL/0/Steam Controller` |
| `GCPadNew.8bitdo.ini` | `SDL/0/8BitDo Pro 2` |
| `GCPadNew.generic.ini` | `SDL/0/Gamepad` |

Unknown pads fall back to the generic Xbox-style layout.

### Launcher CONTROLLER page

- A layout selector with the presets above.
- An editable device field with the exact SDL name.
- **Read from log** parses `logs/dolphin.log` for
  `Added device: SDL/<id>/<name>`, skips keyboard and mouse devices, and fills
  the exact name. It also lists every pad found, so a second controller can be
  selected instead of always taking the last one.
- **Apply layout** copies the chosen preset, rewrites only the `Device` line,
  and backs up the previous `GCPadNew.ini` as
  `GCPadNew.backup-YYYYMMDD-HHmmss.ini`.
- The status line shows the configured device and, when the last logged pad
  differs, prompts the player to use **Read from log**.
- If no profile exists yet and the log contains a pad, the launcher creates the
  matching layout with the exact detected name instead of assuming a DualSense.

`tools/make_release_gile.ps1` now copies every `defaults/GCPadNew*.ini` into
the release stage.

## Button mapping

Dolphin's SDL backend matches positionally. `IsMatchingName` maps:

- `Button A` to `SDL_GAMEPAD_BUTTON_SOUTH`
- `Button B` to `SDL_GAMEPAD_BUTTON_EAST`
- `Button X` to `SDL_GAMEPAD_BUTTON_WEST`
- `Button Y` to `SDL_GAMEPAD_BUTTON_NORTH`

So one mapping works on every pad family:

| GameCube | Xbox | PlayStation | Switch Pro |
|---|---|---|---|
| A | A (south) | Cross (south) | B (south) |
| B | B (east) | Circle (east) | A (east) |
| X | X (west) | Square (west) | Y (west) |
| Y | Y (north) | Triangle (north) | X (north) |
| Z | RB | R1 | R |
| Start | Menu | Options | Plus |
| L / R | LT / RT | L2 / R2 | ZL / ZR |
| C stick | Right stick | Right stick | Right stick |

On a Switch Pro the printed labels are swapped relative to Xbox, but the
physical positions are identical. The profile intentionally follows positions.

## Verification

`tools/controller_selftest.cs` loads `gile-launcher.exe` and exercises the
private helpers through reflection. All checks pass:

- Two pads are read from a realistic log; keyboard entries are skipped.
- Xbox Wireless, Series, One, 360, DualSense, DualShock 4/3, Switch Pro,
  8BitDo and unknown devices map to the right preset.
- `EnsureConfig` creates an Xbox profile when the log has an Xbox and no
  profile exists.
- Applying a preset with `SDL/1/...` preserves the custom device id and the
  full mapping.

UI test on the real launcher:

1. Opened **CONTROLLER**.
2. Selected **Xbox Wireless**; the device field changed to
   `SDL/0/Xbox Wireless Controller`.
3. Pressed **Apply layout**.
4. Confirmed `Config/GCPadNew.ini` contained
   `Device = SDL/0/Xbox Wireless Controller` and a backup was written.
5. Restored the original profile afterwards.

CLI test with a temporary user folder and a fake `dolphin.log` containing
`Added device: SDL/0/Xbox Wireless Controller`: the launcher created
`Config/GCPadNew.ini` with that exact device and booted the game.

## v0.0.3 artifact

```
dist/AggressiveInline-Recomp-v0.0.3-Windows-x64.zip
Size:    26,077,924 bytes
SHA-256: 7CD1C5D6CC80DE17BBE9B80E37695DFDD8E06CDF825DFDF775DB0A08AE012D04
```

The release contains no game data.

## Limitations

- No physical Xbox controller was available on the build machine, so the
  end-to-end button test is pending. The profile format, exact device name,
  Dolphin positional aliases and launcher write path are verified.
- Device names come from SDL and vary with the driver and connection mode
  (USB, Bluetooth, Steam Input). **Read from log** is the reliable way to get
  the exact string; the preset names are sensible defaults.
- The official Wii U GameCube adapter is handled by Dolphin's native adapter
  path, not by these SDL presets. Third-party adapters that expose a normal SDL
  pad work through the generic layout.
