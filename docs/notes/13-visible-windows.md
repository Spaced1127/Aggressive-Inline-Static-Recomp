# Working mode: visible windows (quiet mode lifted)

Persisted 2026-11-16 by direct user order.

**Current status (2026-11-21): the hub lifted the GUI pause for release
verification; visible test windows are allowed.** Launch normally. If the hub
pauses GUI/test launches again, stop all launches and do host-side work only
until it lifts the pause.

- Do **not** use `H:\Orchestration\tools\run-hidden.ps1` or any hidden
  desktop. Launch apps normally so their windows are visible on the user's
  desktop.
- Do not minimize, move, hide or kill the windows of test apps.
- No window-suppression scripts or daemons.
- Test runs are ordinary visible windows. If that is disruptive, the user
  will say so; it is their call.

This supersedes the earlier "hidden desktop only" instruction for this
project. Headless runs may still be used when a test does not need a window
(e.g. automation with `--headless`), but the default is visible.