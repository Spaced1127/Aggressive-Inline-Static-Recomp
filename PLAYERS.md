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

**Any connected controller works with no setup.** The game writes one standard
profile the first time it runs and never rewrites it. Whichever SDL pad is
connected is used. If you swap controllers, for example Xbox to DualSense, the
new one works on the next launch, or within about two seconds if you plug it in
while the game is running. You never need to edit a file or press a button in
the launcher for this, and it also works when RecompLauncher starts the game.

The only choice is the **button class**, on the launcher's **CONTROLLER** page:

- **Auto** (default): Switch Pro, Joy-Con and 8BitDo pads in Switch mode use
  **Nintendo**; everything else uses **Positional**.
- **Positional**: buttons by position (Xbox / PlayStation style).
- **Nintendo**: A/B and X/Y swapped so the printed letters match the GameCube
  letters.

The D-pad, sticks and triggers are never swapped.

The runner writes one diagnostic line to `logs\run.log`:

```
controller: name="<pad>" guid=<32-hex> type=<sdl type> class=<positional|nintendo> override=<auto|positional|nintendo> device="SDL/0/<pad>" source=<sdl|keyboard> profile=<written|static>
controller: configured device missing; bound "SDL/0/<pad>"
```

The second line is normal after you change controllers. If a pad is mapped
wrongly, send these lines and say whether it was connected by USB or Bluetooth.
For 8BitDo, also say whether the pad was in Switch mode or XInput mode.

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

The Switch Pro column is the **Positional** class. With **Auto** or
**Nintendo** a Switch Pro uses the Nintendo class instead, so the button
printed **A** is GameCube A.

The profile is stored at:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\Config\GCPadNew.ini
```

You can edit it by hand from **Open profile**; the game will not overwrite it.
If the first launch happened with no controller connected, the profile holds
keyboard bindings. Delete the file once a pad is connected to get the standard
pad profile.

## Cheats

The **Cheats** screen (Options) compares the text you type, so enter every
code on the on-screen keyboard. Directions are the keyboard's arrow keys, and
letters such as **B A B A** are keyboard letters, not controller buttons.

| Type | Unlocks |
|---|---|
| ↑ ↑ ↓ ↓ ← → ← → B A B A | All levels, park editor items, full stats |
| ↓ → → ↓ ← ↓ ← ↓ → → → | All characters |
| SKELETON | All keys |
| KHUFU | Invulnerability |

Save afterwards (Options -> Save & Load) to keep the unlocks.

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

Slot A is a standard 16 MB memory card file (Slot B is empty):

```
%LOCALAPPDATA%\AggressiveInlineRecomp\GC\MemoryCardA.USA.raw
```

Saving and loading a career through Options -> Save & Load is verified. Back
up that file to keep your progress.

## Performance logs

The launcher writes a one-line-per-second FPS and memory record to:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\logs\perf-YYYYMMDD-HHmmss.csv
```

It also creates the shader cache folder and pins the game to physical CPU
cores. The first launch after a fresh install may compile shaders; later
launches should be smoother. If you see frame drops, keep the latest
`perf-*.csv` and send it with a note about what was on screen.

Level loading: from v0.1.3 the game no longer freezes for 1-2 seconds at a
level start and runs at 60 FPS once the level has loaded. A few short hitches
(up to about half a second) can still happen while the LOADING screen is up.
The settings for this are in `Sys\GameSettings\GILE51.ini`; you do not need to
change anything.

## Known issues

- **If the game is silent**, check the Windows volume mixer for `gile.exe`,
  the launcher's Audio page, and the in-game Sound menu (SFX / Music / Speech).
  Audio output through DSP LLE + Cubeb is working.
- **First launch extracts the disc.** This takes about a minute on an SSD for
  an RVZ, plus the decompression step.
- The tutorial, Movie Lot and the other levels (reached through the cheat
  codes) play. A full story playthrough has not been completed; report any
  scene that crashes or renders incorrectly.
- 100 possible self-modifying-code ranges are under review. None blocked boot
  or the first level.

## Credits

DolRecomp and ModernGekko are distributed under their upstream licenses. The
ModernGekko runtime is Dolphin-derived (GPL-2.0). See `LICENSES/`.
