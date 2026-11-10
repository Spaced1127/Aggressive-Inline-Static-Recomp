# Release packaging - v0.0.1

Date: 2026-11-09

## Artifact

```
dist/AggressiveInline-Recomp-v0.0.1-Windows-x64.zip
Size:    25,845,915 bytes
SHA-256: 2E358D4B5453E89D6C8E9CC70D52E4DF4EF333E3CEBFDC85CF31CD7DEAA8253E
```

Stage:

```
dist/AggressiveInline-Recomp-v0.0.1-Windows-x64/
  gile-launcher.exe              92,160
  gile.exe                       15,590,912  (moderngekko-run.exe, icon replaced)
  gGILE51_recomp_clang.dll       36,866,560
  rvz_extract.exe                 9,661,176
  Sys/                           DSP ROM/coef + fonts
  defaults/GCPadNew.ini          DualSense profile
  LICENSES/                      DolRecomp, ModernGekko, Dolphin notice
  recomplauncher.json
  README.md
  PLAYERS.md
  run.bat
  VERSION
  game/README.txt                empty game folder
```

No game data is present. The packaging script refuses `.iso`, `.rvz`, `.gcm`,
`.dol`, `.thp`, `.pak`, `.zsd`, `.zal` files and `sys/main.dol`.

## Launcher

`gile-launcher.exe` is a WinForms launcher adapted from the RPBB launcher:

- Accepts an ISO, an RVZ, or an extracted folder.
- Verifies the GameCube ID `GILE51` and the DOL SHA-256 before extraction.
- RVZ input is decompressed by the bundled `rvz_extract.exe` (PyInstaller build
  of `tools/rvz_extract.py`) into a temporary ISO, then extracted through the
  normal ISO path. The temporary ISO is deleted afterwards.
- Writes the extracted game to `%LOCALAPPDATA%\AggressiveInlineRecomp\game`.
- Starts `gile.exe` with `--game`, `--module`, `--audio cubeb` and
  `--user-dir`.
- Exposes graphics API, internal resolution, aspect ratio, widescreen hack,
  window mode and FPS title settings.
- Prefers `gGILE51_recomp_clang.dll`; falls back to `gGILE51_recomp.dll`.

## Tests

1. Stage built with:

   ```
   powershell -ExecutionPolicy Bypass -File tools\make_release_gile.ps1 -Version 0.0.1
   ```

2. RVZ prepare from the staged folder:

   ```
   dist\...\gile-launcher.exe --prepare --game "Aggressive Inline (USA).rvz" --user-dir work\release_test_rvz
   ```

   Result: exit 0, 55.6 s, `sys/main.dol` SHA-256
   `F3D92F4312DAFA5BAA79355A03989873E100B97AE85B97280BC808EDB084C27A`,
   no `gile-*.iso` left in `%TEMP%`.

3. Start from the staged folder with the RVZ path:

   ```
   dist\...\gile-launcher.exe --game "Aggressive Inline (USA).rvz" --user-dir work\release_test_rvz --window-mode windowed
   ```

   Result: `gile.exe` launched; window title
   `ModernGekko - Aggressive Inline [GILE51]`; run log shows the module loaded
   from the stage.

4. Earlier dev-stage tests confirmed the same launcher code launches the
   Clang module from `build\launcher` and creates the user config with
   `mute=false`, `volume=100`, `DSPHLE=False`, `Backend=Cubeb`.

5. Extracted the final zip to `work\zip_test` and launched from that extracted
   stage:

   ```
   gile-launcher.exe --game "work\game" --user-dir work\zip_test_user --window-mode windowed
   ```

   Result: `gile.exe` launched, window title
   `ModernGekko - Aggressive Inline [GILE51]`, module loaded from the extracted
   stage.

6. Invalid-file check: `--game C:\Windows\notepad.exe` reaches the disc-ID
   validation and exits with code 2 ("That doesn't look like Aggressive
   Inline"), not the "game files aren't ready" path. This confirms the
   auto-prepare branch is wired in.

## Rebuild

Inputs are the shared toolchain build and the project module:

- `H:\Projects\SB-RFD\build\moderngekko\moderngekko-run.exe`
- `H:\Projects\SB-RFD\build\moderngekko\Sys`
- `build\gGILE51_recomp_clang.dll`
- `build\pyinstaller\dist\rvz_extract.exe`
- `H:\Projects\SB-RFD\dist\SpongeBobRecomp-Release-v0.1.2\LICENSES`

If the module is rebuilt, copy the new DLL into `build\gGILE51_recomp_clang.dll`
before packaging.

## Open items

- Audio is silent; the launcher and PLAYERS.md state this.
- A full story playthrough and real memory-card save/read are still pending.
- RecompLauncher manifest uses the local launcher CLI; a public `repo` field is
  intentionally omitted until the project repository exists.
