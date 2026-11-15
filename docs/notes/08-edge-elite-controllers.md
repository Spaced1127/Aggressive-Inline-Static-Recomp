# DualSense Edge and Xbox Elite controller support

Date: 2026-11-15

Status: implemented and tested offline; shipping in v0.1.0. Physical controller
confirmation still requested.

## Detection model

The shared runner detects pads from SDL's standard-form GUID, not from the
product name:

- `tools/controller_guid.hpp` decodes the 32-character GUID into bus, vendor,
  product, version, driver and driver type. A name-hash GUID does not invent a
  VID/PID.
- `tools/controller_layout.hpp` maps VID/PID to a layout and a family. A GUID
  match is `source=guid`; an SDL gamepad type match is `source=type`; anything
  else stays `source=default` and Generic. The product name is not an input.

### GUID table

| Family | VID:PID | GUID prefixes | Layout | Paddles |
|---|---|---|---|---|
| DualSense Edge | 054C:0DF2 | `050000004c050000f20d...` (BT), `030000004c050000f20d...` (USB) | PlayStation | unbound (4 + Fn) |
| Xbox Elite Series 1 | 045E:02E3 | `030000005e040000e302...` (USB), `050000005e040000e302...` (BT) | Xbox | unbound (4) |
| Xbox Elite Series 2 | 045E:0B00 | `050000005e040000000b...` (BT) | Xbox | unbound (4) |
| Xbox Elite Series 2 | 045E:0B05 | `030000005e040000050b...` (USB), `050000005e040000050b...` (BT) | Xbox | unbound (4) |
| Xbox Elite Series 2 | 045E:0B22 | `050000005e040000220b...` (BLE) | Xbox | unbound (4) |
| DualSense | 054C:0CE6 | `030000004c050000e60c...`, `050000004c050000e60c...` | PlayStation | none |
| DualShock 4 | 054C:09CC / 05C4 | `...4c050000cc09...`, `...4c050000c405...` | PlayStation | none |
| DualShock 3 | 054C:0268 | `...4c0500006802...` | PlayStation | none |
| Xbox 360 | 045E:028E | `030000005e0400008e02...` | Xbox | none |
| Xbox One | 045E:02D1 / 02DD / 02E0 / 02EA / 02FD / 02FF | `03/050000005e040000...` | Xbox | none |
| Xbox Series X|S | 045E:0B12 / 0B13 | `...5e040000120b/130b...` | Xbox | none |
| Switch Pro | 057E:2009 | `030000007e0500000920...` | Switch | none |

The table lives in `kKnownControllers` in `controller_layout.hpp`. Paddles and
Fn/extra buttons are recorded but deliberately not written to `GCPadNew.ini`.

## SDL gamecontrollerdb evidence

Relevant `SDL_gamepad_db.h` entries:

```
050000004c050000f20d000000010000,DualSense Edge Wireless Controller,
  a:b1,b:b2,back:b8,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,
  guide:b12,leftshoulder:b4,leftstick:b10,lefttrigger:a3,leftx:a0,lefty:a1,
  rightshoulder:b5,rightstick:b11,righttrigger:a4,rightx:a2,righty:a5,
  start:b9,x:b0,y:b3,

030000005e040000e302000000000000,Xbox One Wired Controller,
  a:b0,b:b1,back:b9,dpdown:b12,dpleft:b13,dpright:b14,dpup:b11,
  guide:b10,leftshoulder:b4,leftstick:b6,lefttrigger:a2,leftx:a0,lefty:a1,
  rightshoulder:b5,rightstick:b7,righttrigger:a5,rightx:a3,righty:a4,
  start:b8,x:b2,y:b3,

030000005e040000050b000003090000,Xbox Elite Wireless Controller,
  a:b0,b:b1,back:b38,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,
  guide:b12,leftshoulder:b6,leftstick:b13,lefttrigger:a5,leftx:a0,lefty:a1,
  rightshoulder:b7,rightstick:b14,righttrigger:a4,rightx:a2,righty:a3,
  start:b11,x:b3,y:b4,

050000005e040000000b000000783f80,Xbox One Elite 2 Controller,
  a:b0,b:b1,back:b4,dpdown:b12,dpleft:b13,dpright:b14,dpup:b11,
  guide:b5,leftshoulder:b9,leftstick:b7,lefttrigger:a4,leftx:a0,lefty:a1,
  rightshoulder:b10,rightstick:b8,righttrigger:a5,rightx:a2,righty:a3,
  start:b6,x:b2,y:b3,

050000005e040000050b0000ffff3f00,Xbox One Elite 2 Controller,
  a:b0,b:b1,back:b4,dpdown:b12,dpleft:b13,dpright:b14,dpup:b11,
  leftshoulder:b9,leftstick:b7,lefttrigger:a5,leftx:a0,lefty:a1,
  rightshoulder:b10,rightstick:b8,righttrigger:a6,rightx:a2,righty:a3,
  start:b6,x:b2,y:b3,
```

The Edge entry has the same logical face buttons, shoulders, triggers, sticks,
D-pad and Start/Back as the standard DualSense entry; the Edge's extra
`misc1`/paddles are not in the game profile. The Elite entries use the same
logical Xbox layout; some also expose `paddle1..4`, which are not bound.

The DB has the explicit Bluetooth Edge row above. USB Edge is a HIDAPI device;
SDL generates the mapping for its USB GUID in
`SDL_CreateMappingForHIDAPIGamepad` using the PS5 type and adds
`touchpad`, `misc1` and `paddle1..4`. The face/stick/trigger/D-pad bindings are
the standard PS5 layout, and the runtime identifies the USB Edge from
054C:0DF2 in the GUID.

## Offline layout test

`build/moderngekko/moderngekko_controller_layout_test.exe` passes all checks:

- Edge Bluetooth and USB GUIDs -> PlayStation, family "DualSense Edge",
  `source=guid`, `dpad_swap=no`, `face_swap=no`, paddles/extras unbound.
- Elite Series 1 USB -> Xbox, family "Xbox Elite Series 1", paddles unbound.
- Elite Series 2 Bluetooth 0B00/0B05 -> Xbox, family "Xbox Elite Series 2",
  paddles unbound.
- Standard DualSense, Xbox 360, Xbox One and Switch Pro regression checks pass.
- Unknown GUID + unknown type stays Generic; there is no name-only rule.
- Generated GameCube profiles:
  - Edge profile is byte-identical to the standard DualSense profile.
  - Elite Series 1/2 profiles are byte-identical to the standard Xbox profile.
  - Standard Xbox One profile is byte-identical to the Xbox 360 profile.
  - Edge has no paddle entries and leaves the D-pad unswapped.
  - Switch Pro keeps its printed-label A/B/X/Y swap.

Diagnostic samples from the test:

```
controller: "DualSense Edge Wireless Controller" guid=050000004c050000f20d000000010000 bus=bluetooth vid=054c pid=0df2 layout=playstation source=guid dpad_swap=no face_swap=no paddles=unbound extras=unbound family="DualSense Edge"
controller: "DualSense Edge Controller" guid=030000004c050000f20d000000006800 bus=usb vid=054c pid=0df2 layout=playstation source=guid dpad_swap=no face_swap=no paddles=unbound extras=unbound family="DualSense Edge"
controller: "Xbox Elite Wireless Controller" guid=030000005e040000e302000000000000 bus=usb vid=045e pid=02e3 layout=xbox source=guid dpad_swap=no face_swap=no paddles=unbound family="Xbox Elite Series 1"
controller: "Xbox One Elite 2 Controller" guid=050000005e040000050b0000ffff3f00 bus=bluetooth vid=045e pid=0b05 layout=xbox source=guid dpad_swap=no face_swap=no paddles=unbound family="Xbox Elite Series 2"
controller: "DualSense Wireless Controller" guid=030000004c050000e60c000000007700 bus=usb vid=054c pid=0ce6 layout=playstation source=guid dpad_swap=no face_swap=no family="DualSense"
controller: "Xbox 360 Controller" guid=030000005e0400008e02000000000000 bus=usb vid=045e pid=028e layout=xbox source=guid dpad_swap=no face_swap=no family="Xbox 360"
controller: "Switch Pro Controller" guid=030000007e0500000920000000000000 bus=usb vid=057e pid=2009 layout=switch source=guid dpad_swap=no face_swap=yes family="Switch Pro"
```

## Player confirmation

Hardware confirmation is unavailable on this machine; SDL currently reports no
physical gamepad. Players should check:

1. A/B/X/Y, left and right sticks, both analog triggers, D-pad, Start and Back
   match the standard DualSense or Xbox behavior.
2. Edge paddles/Fn and Elite paddles do nothing and do not duplicate or
   override face buttons. If the controller's own software maps a paddle to a
   standard button, that happens before SDL and is expected.
3. USB and Bluetooth each work if the pad supports both.

Send the `controller:` line from `logs\run.log` and say whether the pad was
connected by USB or Bluetooth.
