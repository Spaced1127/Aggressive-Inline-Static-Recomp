# Shared pattern: GameCube raw memory card (slot A) + empty slot B

Applies to the ModernGekko / Dolphin runtime family (all GameCube projects).
Aggressive Inline is the reference implementation; evidence in
[`11-memory-card.md`](11-memory-card.md).

## Three required pieces

1. **Slot A = raw card, slot B = None.**
   `Config/Dolphin.ini`:

   ```ini
   [Core]
   SlotA = 1     ; EXIDeviceType::MemoryCard (raw .raw card)
   SlotB = 255   ; EXIDeviceType::None (empty slot)
   ```

   Do **not** use `SlotB = 0`. `0` is `Dummy` (an EXI device that is not a
   memory card) and the game stops with
   "THE DEVICE IN SLOT B IS NOT SUPPORTED".
   Do **not** leave `SlotA` unset: Dolphin's default is `8`
   (`MemoryCardFolder`), which needs `GC/<region>/Card A` and behaves
   differently for saves.

2. **Create the user-path tree before `UICommon::Init`.**
   In `Runtime::Create` (dolphin_runtime.cpp), mirror DolphinQt:

   ```cpp
   UICommon::SetUserDirectory(config.user_directory.string());
   UICommon::CreateDirectories();   // GC/USA, GC/EUR, GC/JAP, Logs, Cache...
   UICommon::Init();
   ```

   `ExpansionInterface::Init` resolves the raw card path
   (`GC/MemoryCardA.<region>.raw`) during boot. Without this, only the
   folder device works because it creates its own directory.

3. **Force both keys on existing installs.**
   Launcher migration must overwrite, not only insert:
   `SetIniKey(..., "SlotA", "1")`, `SetIniKey(..., "SlotB", "255")`.
   RecompLauncher manifests: put both keys in `ensure`, `always` and
   `new`, with SlotB = 255.

## Verification recipe

- Fresh user dir, no `GC/`, boot 10-15 s: `GC/USA`, `GC/EUR`, `GC/JAP`
  appear; log says `No memory card found. A new one was created instead.`
  and `Changing EXI channel 0, device 0 to type 1` (raw). No type 8, no
  `Card A`.
- Save once: `GC/MemoryCardA.<region>.raw` exists, 16,777,216 bytes
  (128 Mbit), directory entry has the game code/company and a file.
- Load once: frontend Options -> Save & Load -> Load -> slot A shows
  `LOADING '<file>'...` and resumes the saved park.
- Use the automation `stop` command, not `taskkill /F`; a force-kill
  skips the card flush.

## Savestate caveat (test only)

Dolphin savestates store the raw card bytes and the EXI device type.
Loading a state made while Slot A was the GCI folder restores
`MemoryCardFolder` and saves go to `GC/<region>/Card A`. Use states made
after a raw-card boot when testing memcards. This does not affect players
who never load an old state.