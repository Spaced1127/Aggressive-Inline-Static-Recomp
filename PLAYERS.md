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

The RVZ path needs about 1.5 GB of temporary disk space while it decompresses,
then about 1.5 GB for the extracted game. The temporary ISO is deleted after
extraction.

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

The bundled profile is for a DualSense. The GameCube pad buttons map as
follows:

| GameCube | Action | DualSense |
|---|---|---|
| A | Jump / confirm | Cross |
| B | Cancel / attack | Circle |
| X | Action 1 | Square |
| Y | Action 2 | Triangle |
| Start | Pause | Options |
| Left stick | Move | Left stick |
| D-pad | Move | D-pad |
| C stick | Camera | Right stick |
| L / R | Triggers | L2 / R2 |

For an Xbox or Switch Pro controller, edit:

```
%LOCALAPPDATA%\AggressiveInlineRecomp\Config\GCPadNew.ini
```

Set the `Device` line to the SDL name of your controller, or delete the file to
use SDL's default mapping. There is no keyboard gameplay mapping in this build.

## Settings

The launcher exposes:

- **Graphics API**: Vulkan (default), D3D12 or OpenGL.
- **Internal resolution**: 1x to 12x. 3x native is 1920x1344 for this game.
- **Aspect ratio**: Auto keeps the original 4:3 framing; 16:9 fills a
  widescreen display; Stretch fills the window.
- **Widescreen hack**: widens the 3D projection. The 2D HUD may stretch.
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

- **Audio is silent in this build.** The game loads its sound banks and boots
  the DSP ucode, but no PCM reaches the AI DMA buffer. The runtime produces
  audio for the RPBB recomp, so this is specific to Aggressive Inline's audio
  path. Video, input, menus, levels and save states are unaffected.
- **First launch extracts the disc.** This takes about a minute on an SSD for
  an RVZ, plus the decompression step.
- The game is playable through the tutorial. A full story playthrough has not
  been completed; report any scene that crashes or renders incorrectly.
- 100 possible self-modifying-code ranges are under review. None blocked boot
  or the first level.

## Credits

DolRecomp and ModernGekko are distributed under their upstream licenses. The
ModernGekko runtime is Dolphin-derived (GPL-2.0). See `LICENSES/`.
