# Players

A native Windows port of **Aggressive Inline** (GameCube, USA, `GILE51`).
The recompiled game runs on ModernGekko, the Dolphin-derived runtime used by
the other recomp projects in this workspace.

This download contains no game data. You must supply your own legally dumped
USA copy of the disc.

## Start

1. Run `gile-launcher.exe`.
2. Pick your copy of the game:
   - the `.iso` disc image,
   - the `.rvz` compressed image (supported directly), or
   - an extracted folder containing `sys\main.dol` and `files\`.
3. Press **PLAY**.

The first run verifies the disc and extracts it to:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\game
```

The RVZ path reads the compressed groups directly and writes the same `sys/` +
`files/` layout as the ISO path. No temporary ISO is created. The extracted game
is about 883 MB.

You can also start from the command line:

```
run.bat "D:\Aggressive Inline (USA).rvz"
run.bat "D:\Aggressive Inline (USA).iso"
run.bat "D:\path\to\extracted\game"
```

## Verified dump

| | |
|---|---|
| Name | Aggressive Inline (USA) |
| Disc ID | `GILE51` |
| Size | 1,459,978,240 bytes |
| CRC32 | `5D9F46F1` |
| DOL SHA-256 | `F3D92F4312DAFA5BAA79355A03989873E100B97AE85B97280BC808EDB084C27A` |

The launcher refuses a different revision.

## Controls

The game supports the major controller families:

- DualSense (PS5) and DualSense Edge
- DualShock 4 (PS4) and DualShock 3 (PS3)
- Xbox Wireless, Xbox Series X/S, Xbox One and Xbox 360
- Xbox Elite Series 1 and Series 2
- Switch Pro
- Steam Controller
- 8BitDo Pro 2 and other 8BitDo pads (standard or Nintendo mode, detected
  automatically)
- Other SDL pads (generic Xbox-style layout)

DualSense Edge and Xbox Elite are identified by the SDL GUID (VID/PID), not by
the product name. They use the standard DualSense or Xbox layout. The Edge's
back paddles and Fn buttons and the Elite's four paddles are intentionally
unbound; they do not duplicate or override the face buttons. If the
controller's own software maps a paddle to a standard button, that assignment
happens before SDL.

The game auto-detects the first connected SDL gamepad on first play and writes
the matching profile. You do not need the launcher page for a single pad, and
this also works when RecompLauncher starts the game directly.

8BitDo pads are detected from their live SDL button mapping, not their name. A
Pro 2 in Nintendo or Switch mode reports the printed **B** as SDL `A`, so the
runner switches to the Nintendo layout and keeps the labelled buttons in the
right positions. An 8BitDo Ultimate or 64 reports a standard mapping and keeps
the normal Xbox-style layout. The runner also corrects a reversed D-pad if the
pad's mapping reports one.

If a profile already exists for a different pad, the game falls back to the
first connected SDL pad, so an Xbox, PlayStation, Switch or 8BitDo pad still
works without editing the file. A hand-edited profile is preserved while that
same pad is connected.

To choose a specific pad, for example when two controllers are connected:

1. Connect the controller and start the game once so ModernGekko logs its SDL
   name.
2. Open **CONTROLLER** in the launcher.
3. Pick your layout.
4. Press **Read from log** to fill the exact SDL device name.
5. Press **Apply layout**, then restart the game.

Dolphin matches the device name exactly, including `SDL/0/` or `SDL/1/`. The
launcher backs up the old `GCPadNew.ini` before writing a new one.

The runner writes one diagnostic line per pad to `logs\run.log`:

```
controller: "<name>" guid=<32-hex> bus=<usb|bluetooth> vid=<vvvv> pid=<pppp> layout=<xbox|playstation|switch|generic> source=<guid|mapping|type|default> dpad_swap=<yes|no> face_swap=<yes|no> paddles=unbound extras=unbound family="<family>"
```

If a pad is mapped wrongly, send that line. For an Edge or Elite, also say
whether it was connected by USB or Bluetooth. For 8BitDo, say whether the pad
was in Nintendo/Switch mode or standard/XInput mode.

### Button layout

Dolphin matches physical button positions, not the printed labels. That keeps
the same layout on every pad:

| GameCube | Action | Xbox | DualSense / DualShock | Switch Pro |
|---|---|---|---|---|
| A | Jump / confirm | A (south) | Cross (south) | B (south) |
| B | Cancel / attack | B (east) | Circle (east) | A (east) |
| X | Action 1 | X (west) | Square (west) | Y (west) |
| Y | Action 2 | Y (north) | Triangle (north) | X (north) |
| Z | Action 3 | RB | R1 | R |
| Start | Pause | Menu | Options | Plus |
| Left stick | Move | Left stick | Left stick | Left stick |
| D-pad | Move | D-pad | D-pad | D-pad |
| C stick | Camera | Right stick | Right stick | Right stick |
| L / R | Triggers | LT / RT | L2 / R2 | ZL / ZR |

On a Switch Pro this means GameCube **A** is the south button printed **B**,
and GameCube **B** is the east button printed **A**. That is intentional: the
buttons stay in the same physical positions as an Xbox or PlayStation pad. A
Pro 2 in Nintendo or Switch mode behaves the same way. An 8BitDo Ultimate or 64
in standard mode uses the Xbox-style positions.

The profile is stored at:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\Config\GCPadNew.ini
```

You can edit it by hand from **Open profile**. There is no keyboard gameplay
mapping in this build.

## Resolution and full screen

- The resolution list is 16:9: 640x360, 1280x720, 1920x1080, 2560x1440,
  3840x2160, 5120x2880 and 7680x4320.
- **4x (2560x1440)** matches a 1440p display and is the default on a 1440p or
  larger desktop.
- The selected resolution sizes the game window. **Fullscreen windowed** fills
  the monitor.
- New installs default to 16:9 widescreen with the widescreen hack. A v0.0.3
  config still on Auto/off is moved to 16:9 once; change it in **GRAPHICS** if
  you prefer 4:3.
- The 3D scene is rendered at the integer EFB scale (4x is 2560x2112 from the
  640x528 EFB) and presented at the selected 16:9 output size (2560x1440).

## Settings

The launcher exposes:

- **Graphics API**: Vulkan (default), D3D12 or OpenGL.
- **Resolution**: 16:9 output sizes from 640x360 to 7680x4320. 4x (2560x1440)
  is the 1440p default; the selected size also sets the window size.
- **Aspect ratio**: 16:9 widescreen is the default for new installs; Auto keeps
  the original 4:3 framing; Stretch fills the window.
- **Widescreen hack**: widens the 3D projection. On by default for new installs.
  The 2D HUD may stretch.
- **Window mode**: fullscreen windowed (default), fullscreen, or windowed.
- **Show FPS** in the window title.

Settings live in:

```
%LOCALAPPDATA%\AggressiveInlineRecomp
```

## Save data

The game uses a folder-based memory card:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\GC\USA\Card A\
```

The Save & Load menu is reachable. A full write/read test with a real `.gci`
has not been completed yet; back up the folder before relying on it.

## Performance logs

The launcher writes a one-line-per-second FPS and memory record to:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\logs\perf-YYYYMMDD-HHmmss.csv
```

It also creates the shader cache folder and pins the game to physical CPU
cores. The first launch after a fresh install may compile shaders; later
launches should be smoother. If you see frame drops, keep the latest
`perf-*.csv` and send it with a note about what was on screen.

## Known issues

- **If the game is silent**, check the Windows volume mixer for `gile.exe`,
  the launcher's Audio page, and the in-game Sound menu (SFX / Music / Speech).
  Audio output through DSP LLE + Cubeb is working.
- **First launch extracts the disc.** This takes about a minute on an SSD for
  an RVZ, plus the decompression step.
- The game is playable through the tutorial. A full story playthrough has not
  been completed; report any scene that crashes or renders incorrectly.
- 100 possible self-modifying-code ranges are under review. None blocked boot
  or the first level.

## Credits

DolRecomp and ModernGekko are distributed under their upstream licenses. The
ModernGekko runtime is Dolphin-derived (GPL-2.0). See `LICENSES/`.
