# Generic controller system (Aggressive Inline port)

Ported from WWE WrestleMania X8 v0.1.4 (`docs/notes/controller-generic-design.md`).
One canonical controller system for every ModernGekko GameCube port.

## Design

- **One static `GCPadNew.ini`**: canonical SDL positional bindings, written only
  when missing, never rewritten at launch.
- **Two classes**: `positional` (default) and `nintendo` (A<->B and X<->Y so
  printed labels match). D-pad, sticks and triggers are never swapped.
- **Class per pad at input init**: `SDL_GetGamepadType` (Switch Pro/Joy-Con/
  Joy-Con pair), then an 8BitDo Switch-mode vendor/product fallback, then the
  `controller_class = auto|positional|nintendo` override. `--controller-layout`
  maps onto the same override (`keyboard` is a device choice, not a class).
- **Device binding in memory**: `EnsurePadBound()` checks
  `IsDefaultDeviceConnected()`; if absent it calls
  `SetDefaultDevice(g_controller_interface.GetDefaultDeviceString())` and
  `UpdateReferences()`. A 2 s watcher repeats it for hot-plug. The ini is never
  edited for this.
- **No migration**: stale `Device = SDL/0/<name>` lines are harmless because
  binding falls back to the first pad and the class is per connection. Deleting
  an old `GCPadNew.ini` is optional.

## Aggressive Inline files

Changed/deleted:

- `tools/gile_launcher.cs`: removed `DetectControllerDevices/Device`,
  `ControllerPresetDevice/ForDevice`, `WriteControllerProfile`, the
  `defaults/GCPadNew.<preset>.ini` pre-seed, the preset combo and the
  `controller_profile` key. The CONTROLLER page is now a single class picker
  (`auto|positional|nintendo`) plus profile/config buttons; it writes only
  `[Input] controller_class` in `config.ini`.
- `defaults/`: all per-device presets deleted; no profile is shipped. The
  runner writes the one canonical profile on first launch.
- `tools/controller_selftest.cs`: rewritten to prove no pre-seed, no rewrite of
  an existing profile, no preset tables and `controller_class=auto`.
- `tools/make_release_gile.ps1`: no longer ships `defaults/` or requires a
  development profile.
- `recomplauncher.json`: adds the `Input/controller_class` setting and `new`
  key; no controller profile setting.
- Shared runtime (via `lib/ModernGekko`): `EnsurePadBound()` now uses
  `GetDefaultDeviceString()`; the canonical classes/profile, per-pad class and
  runtime override were already present in the shared tree.

Kept (deviation from the reference): `tests/controller_layout_test.cpp`
remains the offline family matrix. The reference design names it but the
reference tree no longer contains it.

## Startup diagnostic

```
controller: name="<pad>" guid=<32-hex|none> type=<sdl type|none>
  class=<positional|nintendo> override=<auto|positional|nintendo>
  device="<SDL/0/<pad>|DInput/0/Keyboard Mouse>" source=<sdl|keyboard>
  profile=<written|static>
```

The reference line omits SDL type/source; they are kept here because the hub's
triage requirement asks for guid, SDL type, class, chosen device and source.

## 8BitDo fallback (reference deviation)

The reference ships only `05ac:0004`. This port keeps the known Switch-mode
pairs already in the shared tree:

- `2dc8:6006` - 8BitDo Pro 2 in Nintendo/Switch mode (USB and Bluetooth)
- `05ac:0004` - Switch-mode clone over Bluetooth

The Pro 2 in XInput mode reports Microsoft vendor `045e` and stays positional.
Other 2dc8 PIDs are not guessed; the startup line prints the full GUID, so a
player report can extend the list with a real pair.

## Verification

- Offline: `moderngekko_controller_layout_test.exe` 130/130 (Xbox 360/One/
  Series/Elite, DualSense/Edge, DS4/DS3, 8BitDo USB/BT/Switch/XInput, Switch
  Pro/Joy-Con, generic DInput; override precedence; D-pad untouched; canonical
  profile text; write-once; configured-device read-back; legacy keys).
- GameCube `frontend_config_gamecube_test.exe`: pass.
- Launcher self-test: pass (no pre-seed, existing profile untouched, no preset
  tables, `controller_class=auto`).
- Live (no pad connected): first launch writes a 573-byte keyboard profile,
  second launch `profile=static` with the same SHA; `--controller-layout
  nintendo` reports `override=nintendo`; memory card lines unchanged.
- Physical pad matrix: **not run** - the Xbox pad was disconnected
  (`XInputGetState` 1167) during this pass. The no-pad path is verified; the
  per-pad live class/press matrix is parked.

## Known limits

- First launch without a pad writes the keyboard profile; a pad connected later
  binds but the profile bindings are keyboard. Delete `GCPadNew.ini` once a pad
  is present to get the canonical pad profile (optional, never required).
- The profile binds port 1 only. Two pads with different classes work per pad,
  but only port 1 has a profile.