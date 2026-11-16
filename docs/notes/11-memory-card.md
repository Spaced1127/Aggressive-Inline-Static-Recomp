# Memory card (slot A) fix

Updated: 2026-11-16

## Symptom

Saving hung at "Checking Memory Card Slot A" / the save screen stayed empty.
Installs got only `GC/USA/Card A` (empty GCI folder) and never a
`MemoryCardA.USA.raw`.

## Causes

1. **Slot A was never configured.** Dolphin's default
   `MainSettings.cpp` value for `Core/SlotA` is
   `EXIDeviceType::MemoryCardFolder`. Neither the launcher nor
   `recomplauncher.json` wrote `SlotA`, so every install used the folder
   device with an empty `GC/<region>/Card A`.
2. **The runtime never created the user-path tree.** `Runtime::Create`
   called `UICommon::SetUserDirectory` + `UICommon::Init` but not
   `UICommon::CreateDirectories` (DolphinQt calls all three). With the
   default folder device this was masked because `GCMemcardDirectory`
   creates its own folder; with a raw card the `GC/` tree did not exist.
3. **Slot B was `Dummy`, not empty.** `SlotB = 0` is
   `EXIDeviceType::Dummy`. The game reports it as
   "THE DEVICE IN SLOT B IS NOT SUPPORTED. PLEASE INSERT A MEMORY CARD."
   and stops in the new-file save flow. The empty slot is `None` = 255.

## Fix

- `lib/ModernGekko/src/runtime/dolphin_runtime.cpp` (`Runtime::Create`):
  `UICommon::CreateDirectories()` after `SetUserDirectory` and before
  `UICommon::Init`.
- `tools/gile_launcher.cs`: new installs write `SlotA = 1`,
  `SlotB = 255`; existing installs get both keys forced with `SetIniKey`
  (repairs a previous `SlotB = 0`).
- `recomplauncher.json`: `Core/SlotA = 1`, `Core/SlotB = 255` in
  `ensure`, `always` and `new`.

## Runtime evidence

Clean user dir with `Config/Dolphin.ini` (`SlotA = 1`, `SlotB = 255`) and
no `GC/`, 14 s headless boot, then force-stop:

```
before GC exists: False
after GC exists:  True
GC/EUR
GC/JAP
GC/USA

04:07:141 GCMemcardRaw.cpp:75 I[EXI]: No memory card found. A new one was created instead.
04:07:143 EXI_Channel.cpp:187 I[EXI]: Changing EXI channel 0, device 0 to type 1
```

`type 1` is `EXIDeviceType::MemoryCard` (raw). There is no
`Changing ... to type 8 (MemoryCardFolder)` and no `Card A` directory.
The formatted card lives in memory at EXI init and is written to
`GC/MemoryCardA.USA.raw` on the first dirty flush or on exit. Log:
`work/evidence/16-memcard-create.log`.

## Save evidence (raw card)

Movie Lot career, pause -> SAVE -> Memory Card Slot A:

| Point | Size | SHA-256 |
|---|---:|---|
| before first save (empty formatted card) | 16,777,216 | `75273788B863F156D8DF1157B4D4D3A19A305C7DC0E70F34F71CC864B7513BD1` |
| after save and flush | 16,777,216 | `B13262F7EFAA636368AF80CA283675C98CB367E3BA6F6C80F5C4D38725E7A1F8` |

Directory entry 0 of the raw card after the save:

```
GameCode GILE   Company 51   FileName AGGR_INLINE   Blocks 57
```

EXI wrote the save to raw blocks 4, 2, 5, 1, 6, 7, ... (`writing to
block: 4`, `writing to block: 2`, ...), with no `GCMemcardDirectory`
lines and no `.gci` file. The pause menu after the save:
`work/evidence/14-memcard-save-done.png`.

## Reload evidence

A fresh process reads the card at boot (`Reading memory card
.../GC/MemoryCardA.USA.raw`) and the Save screen reports:

```
OVERWRITE OLD 'SKATER CAREER' IN MEMORY CARD IN SLOT A
```

so the save directory is parsed back from disk. Screenshot:
`work/evidence/15-memcard-save-readback.png`.

## Load path and round-trip evidence

The load is on the frontend Options page, not the CAREER icon:

```
main menu -> OPTIONS (wrench icon)
          -> SAVE & LOAD page (disc icon)
          -> A: dialog with SAVE / LOAD
          -> LOAD -> Memory Card Slot A
```

Selecting Slot A reads the card and auto-loads the only file:

```
LOADING 'SKATER CAREER'...
DO NOT REMOVE THE MEMORY CARD IN SLOT A. DO NOT TOUCH THE POWER BUTTON
```

Screenshot: `work/evidence/17-memcard-loading.png`. The game then returns
to the frontend with the career active. Selecting CAREER goes straight to
level select with no player select / name entry, and the loaded career
resumes in **Movie Lot** - the park where the save was made - rather than
the Tutorial. Screenshot: `work/evidence/18-memcard-load-movielot.png`
(full gameplay, Movie Lot street, timer visible).

This was run in a fresh process with no savestates, so the card was read
from disk. The card SHA-256 was unchanged by the load:
`B13262F7EFAA636368AF80CA283675C98CB367E3BA6F6C80F5C4D38725E7A1F8`
before and after. The round trip is verified.

Note: the load does not show a file list when the card holds a single
save; it checks the slot and loads the file directly. A file list appears
only when there is a choice.

Launcher migration was verified on an existing install: `Dolphin.ini`
with `SlotA = 1`, `SlotB = 0` became `SlotA = 1`, `SlotB = 255` on the
next launch (staged v0.1.2 launcher, hidden desktop).

The staged v0.1.2 binary was also run against a fresh user dir: it created
`GC/{USA,EUR,JAP}` and `GC/MemoryCardA.USA.raw` (16,777,216 bytes,
SHA-256 `1B86C29070BC5DCFFB1CCC01C602834D3D361B02F2BCE41AE2D26FF651D1DC43`)
with an empty directory, then a graceful `stop` wrote the card to disk.

## Test notes

- Savestates capture the raw card contents and the EXI device type
  (`CEXIMemoryCard::DoState` -> `MemoryCard::DoState`). Any state made
  while Slot A was the GCI folder restores `MemoryCardFolder` on load, so
  old states save to `GC/USA/Card A` again. Use states made after a raw
  boot for memcard tests.
- The automation screenshot channel keeps only the latest pending
  screenshot name; take one screenshot per run.
- Force-killing (`taskkill /F`) skips the card flush. Use the automation
  `stop` command for a graceful shutdown when testing persistence.
- Free-roam and tutorial pause menus have no SAVE item. A non-tutorial
  career park (e.g. Movie Lot) does.