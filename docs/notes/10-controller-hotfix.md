# Controller regression hotfix (Xbox dead, Edge/Elite/8BitDo audit)

Date: 2026-11-16

Status: source fixed and offline-tested; **hotfix v0.1.1 staged, not committed and
not published - awaiting hub approval.** Physical Xbox / DualSense Edge /
Xbox Elite / 8BitDo confirmation still outstanding (no such pad is connected on
this machine: the runner logs `0 SDL joystick(s) detected`).

## What players reported

- "Xbox controllers not working at all" after v0.1.0.
- Doubts about DualSense Edge and 8BitDo correctness.

## Xbox: the layout code is not the cause

Every Xbox row in SDL's own database was walked through the real detection and
profile generation. Layout selection is correct and cannot kill a pad:

- `layout=xbox` for all 22 Xbox GUIDs tested: 360 USB (`0300...8e02...`), 360
  v0110, 360 Bluetooth, One 02D1/02E3/02EA/02E0/02FD, Series 0B12/0B13, Elite
  S1 02E3, Elite S2 0B00/0B05/0B22, plus unlisted PIDs 0B20/0B21/0B2A.
- Xbox, PlayStation and Generic generate **byte-identical** `GCPadNew.ini`
  bodies (verified against the shipped `defaults/GCPadNew.xbox.ini`), so even a
  mis-detected Xbox pad cannot lose its inputs.
- `a > b` cannot fire on an Xbox pad: all 32 Microsoft (045E) rows in the SDL
  DB bind `a:b0,b:b1`. Same for the XInput mapping (`xinput,*,a:b0,b:b1`).
- The D-pad heuristic cannot fire on a stock Xbox row either (hat D-pads, or
  `dpleft:b13,dpright:b14`).

## Xbox: what the release actually changed

Two things, both about **binding the device**, not about buttons:

1. **The runtime's SDL device fallback was missing from the v0.1.0 runner.**
   v0.0.4's `gile.exe` contains
   `controller: configured device '%s' not found; using '%s'`; v0.1.0's does
   not, and `vendor/dolphin/.../CoreDevice.cpp` was unmodified. The tree was
   re-pinned for v0.1.0 and
   `docs/patches/dolphin-sdl-controller-fallback.patch` was not re-applied.
   Without it `DeviceContainer::FindDevice` must match source **and** name
   **and** id exactly, otherwise the GameCube pad gets no device at all.
   The fallback was not theoretical on this machine: two v0.0.4 run logs show
   it firing for the Xbox pad -
   `work/v004_upgrade_user/logs/run.log` and
   `work/v004_final_upgrade/logs/run.log`:
   `configured device 'SDL/0/DualSense Wireless Controller' not found; using
   'Xbox One Controller'`.
2. **The runner now rewrites `GCPadNew.ini` on every launch from its own SDL
   probe** (new in v0.1.0). The probe ran with default SDL hints while Dolphin's
   backend sets its own (`SDL_JOYSTICK_WGI=0`, `DIRECTINPUT=1`,
   `HIDAPI_ENHANCED_REPORTS=1`, ...). A name or index that differs between the
   probe and the runtime is now written *into* the profile, and with the
   fallback gone that mismatch is fatal. This machine's logs show the same pad
   logged as `Xbox One Controller` (v0.0.4 logs) and `Xbox Wireless Controller`
   (`work/controller_cli_user`, `work/stage_cli_user`), and once as
   **`SDL/1/Xbox Wireless Controller`** - the probe's per-name index and the
   runtime's per-(source,name) id can disagree.

Root cause: **profile device binding + the removed fallback**, not the
heuristics.

## Fixes (one at a time)

1. `tools/controller_layout.hpp` - `MappingDpadSwapped` no longer compares raw
   button indices. 35 rows in SDL's DB bind `dpleft` above `dpright` and are
   perfectly normal (PS2/PS3 pads, the GameCube adapter, Razer Atrox,
   SteelSeries Nimbus, and SDL's own WGI Xbox mapping
   `dpup:b10,dpdown:b12,dpleft:b13,dpright:b11`). Only hat values (`h0.2` vs
   `h0.8`) and axis signs can mean "reversed".
2. `vendor/dolphin/.../CoreDevice.cpp` - re-applied the SDL fallback, and it now
   first matches the **same name** with a different id (the real
   probe/runtime case) before falling back to the first SDL pad. Both paths log
   once, with the reason.
3. `tools/moderngekko_run.cpp` - the probe sets the same SDL hints as the
   runtime before `SDL_Init`, so the name it writes is the name Dolphin will
   enumerate.
4. `tools/rebuild_runner.bat` - configures the shared build tree for this port
   (`gile` output, "Aggressive Inline" title, `moderngekko` user dir, and
   **no** pinned disc/DOL id). Without the last two the shared tree baked in the
   other port's `GSQE78` / DOL hash and refused the Aggressive Inline disc.
   The script sets those values itself, so the shared tree can be (and was)
   restored to the other port afterwards; run the script again to rebuild.

Concurrent work in the same session also added a vendor-family fallback
(`kVendorFamilies`, `source=guid-family`), so unlisted Microsoft PIDs
(0B20/0B21/...) resolve to Xbox instead of the mapping heuristics. That is kept.

## Verification

- Project test `moderngekko_controller_layout_test.exe`: **130/130** checks
  pass (Xbox 360/One/Series/Elite S1/S2, Edge, DualSense, 8BitDo
  Nintendo/standard, Switch Pro, unlisted PIDs, PS3/PS2 D-pads).
- Session matrix harness (same headers, `frontend_config.cpp`): **80/80**
  checks pass, including:
  - the generated Xbox profile equals the shipped `GCPadNew.xbox.ini` body;
  - `dpad_swap=no` for the WGI Xbox mapping and the PS2/Razer/GameCube rows;
  - an Xbox pad with a reversed raw A/B order stays Xbox (no Nintendo swap);
  - migration: a default Xbox profile migrates, a profile seeded under another
    pad's name is regenerated, a hand-edited profile for the same pad is kept.
- Runner rebuilt from the fixed tree (`build\gile.exe`, 15,806,464 bytes):
  contains the fallback strings, `Aggressive Inline`, no `SpongeBob`, no
  `GSQE78`, no DOL gate.
- Hidden-desktop boot smoke (`run-hidden.ps1`, 55 s): `[staticrecomp] core init`
  and `module loaded ... entry=0x80005308`, no crash or abort. No pad was
  connected, so the binding path could not be exercised live.

## What still needs a physical pad

1. Xbox (360/One/Series/Elite): all face buttons, both sticks, both triggers,
   D-pad (especially left/right), Start. Send the `controller:` and
   `controller configuration:` lines from `logs\run.log`.
2. DualSense Edge: as a standard DualSense; paddles/Fn unbound.
3. 8BitDo: the Pro 2 cannot be told apart by SDL mapping alone - its HID report
   numbers B below A in **both** Nintendo and standard modes, so `a > b` selects
   the Nintendo layout either way. The manual **8BitDo (Nintendo mode)** preset
   and `controller_profile=nintendo` remain the override for a player who wants
   positional A/B.