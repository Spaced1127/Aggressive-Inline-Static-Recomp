# Controller matrix check, v0.1.2 (2026-11-16)

Build: published v0.1.2 runner (`gile.exe`, SHA of release below).
Scope: re-check the controller fixes after the v0.0.2/v0.0.3 player reports
("no controller input with Xbox One", "issues still remain with controller
support"). Both reports predate v0.1.1/v0.1.2.

## Connected hardware

Only one pad is physically present:

```
controller: "Xbox One Controller" guid=0300fa675e040000ff02000000007801
  bus=usb vid=045e pid=02ff layout=xbox source=guid
  dpad_swap=no face_swap=no family="Xbox One"
controller configuration: 1 GameCube controller mapped (xbox layout)
  device="SDL/0/Xbox One Controller"
  profile=...\Config\GCPadNew.ini
```

PnP parent is `USB\VID_045E&PID_0B12` ("Xbox Controller", Xbox Series/One
wireless controller over USB); the XInput interface reports `045E:02FF`.
The current runner detects it, selects the Xbox layout, names the exact
SDL device in the profile, and maps it. No device-binding failure.

## Offline layout matrix

`moderngekko_controller_layout_test.exe` on this build:

```
130 PASS, 0 FAIL - "All controller-layout checks passed"
```

Covered: Xbox 360 USB/BT/version-word, Xbox One (02D1/02DD), Xbox One S
(02E0/02EA), Xbox One BT (02FD), Xbox Series X|S (0B12), Xbox Elite
Series 1 and Series 2 (0B00/0B05, including 0B22), standard DualSense,
DualSense Edge USB/BT (including a STANDARD-type pad), Switch Pro USB/BT,
8BitDo Pro 2 USB/BT (Nintendo and Switch modes), 8BitDo Ultimate, 8BitDo
64, Steam virtual Xbox 360, D-pad reversal cases, and profile bindings.

Startup diagnostic samples for each family are printed by the test and
match the live line.

## Actual-button check

Not completed. A visible game window ran at 59.94 FPS while an XInput
monitor logged the connected pad for 113 s. The only event was a resting
stick axis (`LY=19214`); no buttons, triggers or stick moves were pressed.
The interactive prompt asking for presses was interrupted by the server
restart. The game's `dolphin.log` has no `Ctrl #0 Pressed` lines.

So: detection + profile + mapping are verified; physical button presses
on real hardware are **not** verified in this pass.

## Remaining cases to test when a human/pad is available

1. Physical buttons on the Xbox pad (A/B/X/Y, Start, D-pad, LB/RB,
   triggers, both sticks) with the game focused.
2. DualSense, DualSense Edge, Elite Series 1/2, 8BitDo Pro 2, Switch Pro
   on hardware. Only offline mappings exist here; no such pads are
   connected.
3. Bluetooth vs USB for the Xbox and 8BitDo pads.
4. Connect-after-launch: the runner enumerates and writes the profile at
   startup. A pad connected after launch is not covered by this test.
5. Profile migration from a v0.0.x install. The layout test covers the
   migration logic; a real v0.0.3 install was not upgraded here.

## What to ask the reporter for

If the report persists on v0.1.2, ask for the two lines from
`logs\run.log`:

```
controller: "<name>" guid=<32-hex> bus=<usb|bluetooth> vid=<vvvv> pid=<pppp> layout=<...> source=<...> ...
controller configuration: ... device="SDL/<n>/<name>" profile=<path>
```

Those identify whether the pad was seen, whether the fallback fired, and
which device the profile names. No source change is justified until a
current-build line shows a failure.