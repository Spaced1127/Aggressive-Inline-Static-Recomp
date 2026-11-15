# 8BitDo Nintendo-layout mapping fix

Date: 2026-11-15

Status: implemented and tested offline; shipping in v0.1.0. Physical 8BitDo
confirmation still requested.

## Root cause

SDL normalizes face buttons by **physical position**: `a` is south, `b` is east.
That is correct for Xbox and PlayStation pads. An 8BitDo pad in Nintendo mode
reports its printed **B** as SDL `a` and its printed **A** as SDL `b`:

```
03000000c82d00000660000011010000  8BitDo Pro 2 (Nintendo mode)
  a:b1,b:b0,x:b4,y:b3,...

05000000ac05000004000000fd216d04  8BitDo Pro 2 (Switch mode)
  a:b3,b:b2,x:b8,y:b7,...
```

The old runner chose the layout from the product name and SDL gamepad type. A
Pro 2 reports type `SDL_GAMEPAD_TYPE_STANDARD`, so it fell through to Generic
and generated `Buttons/A = Button A`. On the pad, SDL `Button A` is the physical
**B** button, so A/B and X/Y were reversed for the player.

This was reproduced in the offline test:

```
PASS Pro 2 without live mapping reproduces the old Generic path
PASS old path binds A to Button A (the reported swap)
```

It is not a blanket 8BitDo rule. The Ultimate and 64 report a standard
`a:b0,b:b1` mapping and must keep the standard layout:

```
03000000c82d00001330000011010000  8BitDo Ultimate   a:b0,b:b1,...
03000000c82d00001930000000000000  8BitDo 64         a:b0,b:b1,...
```

## Fix

`tools/controller_layout.hpp` now resolves a pad in this order:

1. **GUID table** for known families (DualSense Edge, Xbox Elite, Switch Pro,
   standard PlayStation/Xbox pads). A GUID match is `source=guid`.
2. **Live SDL mapping** from `SDL_GetGamepadMappingForID` for the connected
   device. The parser reads the actual `a`, `b`, `dpleft` and `dpright`
   bindings:
   - `a > b` is Nintendo order -> `ControllerLayout::Switch`, which generates
     `Buttons/A = Button B`, `Buttons/B = Button A`, `Buttons/X = Button Y`,
     `Buttons/Y = Button X`.
   - `a < b` (or no usable mapping) leaves the existing layout/Generic, so
     standard-mode 8BitDo pads and unknown pads are unchanged.
   - `dpleft:h0.2,dpright:h0.8` (or a left button index greater than the right)
     sets `dpad_swap=yes`; the generated profile writes
     `D-Pad/Left = Pad E` and `D-Pad/Right = Pad W`.
3. **SDL gamepad type** as a fallback when no GUID or mapping rule applies.
4. Otherwise Generic.

The runner obtains the mapping per device, not per product name, so the same
model can resolve differently in Nintendo mode and standard mode. The runtime
passes the resolved layout and D-pad swap to `GenerateControllerConfig`.

`tools/frontend_config.cpp` already supported both flags; the missing piece was
the live-mapping parser and passing its result through.

## Profiles

- A generated/default profile (standard or Nintendo bindings, including a stale
  D-pad order) migrates to the detected layout in `auto` mode.
- A hand-edited profile is preserved while the **same** device is connected.
  Connecting a different pad regenerates the profile for that pad.
- An explicit launcher layout (`controller_profile=<preset>`) overrides
  migration, and **Apply layout** writes `controller_profile=manual` so a later
  auto launch cannot overwrite the player's choice.
- The manual Nintendo override still works and produces the same swapped
  A/B/X/Y bindings.

Presets:

| Preset | Layout | Notes |
|---|---|---|
| `GCPadNew.8bitdo.ini` | standard | Xbox-style, positional A/B/X/Y |
| `GCPadNew.8bitdo-nintendo.ini` | Switch | swapped A/B/X/Y for Nintendo mode |
| `GCPadNew.switch-pro.ini` | Switch | corrected to swapped A/B/X/Y |

## Offline test evidence

`moderngekko_controller_layout_test.exe` built from the current shared sources
passes **62/62** checks, including:

- Pro 2 Nintendo mapping -> `Switch`, `source=mapping`, `face_swap=yes`.
- Pro 2 GUIDs `03000000c82d00000660000011010000`,
  `...00020000`, `...00000000` and `05000000c82d00000660000000010000`
  all resolve to `Switch`.
- Pro 2 Switch-mode GUID `05000000ac05000004000000fd216d04` -> `Switch`.
- Ultimate and 64 stay `Generic` with `source=default`, `face_swap=no`.
- Synthetic reversed D-pad sets `dpad_swap=yes` and writes the corrected
  Left/Right bindings.
- Standard default profile migrates; Nintendo default profile migrates;
  custom profile for the connected pad is preserved; custom profile for a
  different pad is regenerated; explicit layout overrides a custom profile.
- Standard DualSense, Xbox 360, Xbox One, Edge, Elite and Switch Pro
  regressions pass.
- Startup diagnostic lines are generated for each sample, for example:

```
controller: "8BitDo Pro 2" guid=03000000c82d00000660000011010000 bus=usb vid=2dc8 pid=6006 layout=switch source=mapping dpad_swap=no face_swap=yes family="8BitDo (Nintendo mapping)"
```

Launcher self-test: **132/132** checks pass, including the
`8bitdo-nintendo` preset, its default device name, and the swapped
`switch-pro` bindings.

## Player confirmation

No physical 8BitDo pad is available on this machine; the evidence is the SDL
mapping strings, GUID table and offline profile generation. Players should
check:

1. On a Pro 2 in Nintendo mode, the south button (printed **B**) jumps and
   confirms, and the east button (printed **A**) cancels. X/Y should follow the
   printed labels.
2. The D-pad moves in the direction pressed. If it is reversed, report it; the
   generated profile has a D-pad correction path.
3. An Ultimate or 64 keeps the normal Xbox-style positions.
4. A Pro 2 in Switch mode uses the same Nintendo swap.

Send the `controller:` line from `logs\run.log` and say which mode the pad was
in (Nintendo/Switch or standard/XInput) and whether it was USB or Bluetooth.
