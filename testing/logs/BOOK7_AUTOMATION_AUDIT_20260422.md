# Book 7 Automation Audit Refresh

Date: `2026-04-22`

Book: `7 - Castle Death`

## Purpose

Refresh the stale pre-implementation Book `7` audit with the actual live automation surface now present on current `main`.

This report supersedes the old repo-state assumption in `testing/logs/BOOK7_AUTOMATION_AUDIT_20260416.md` that still showed `0` live Book `7` hooks.

## Summary

- sections in book: `350`
- live Book `7` module now exists at:
  - `modules/rulesets/magnakai/book7.psm1`
- direct Book `7` section-entry hooks on current `main`: `55`
- random-number context coverage on current `main`: `22` sections
- automated random-result side effects currently resolved in code: `4` sections
  - `26`, `85`, `129`, `241`
- instant-death dispatcher coverage on current `main`: `20` sections from the original audit surface
- story / route achievement tracking now includes:
  - `15` section-based trigger points
  - `12` transition-based route edges
- validation on current `main` is green in both shells across:
  - startup
  - choice flow
  - combat hooks
  - achievements
  - random automation
  - automation surface
  - endgame routes
  - difficulty / permadeath behavior

## Current Live Automation Surface

### Startup And Carry-Forward

- Book `6` -> `7` carry-forward is implemented.
- Book `7` opening equipment selection is implemented.
- Book `7` weapon confiscation / recovery handling is implemented.

### Section-Entry Bookkeeping

Current `main` now has direct Book `7` section-entry handling for:

- forced meals, ENDURANCE deltas, and environmental penalties
- inventory gains and losses
- guided loot / recovery choice tables
- confiscation, backpack-loss, and pocket-item tracking
- story flags that support route logic and achievement sync

The current direct section-entry hook surface is:

`1, 5, 7, 10, 15, 18, 31, 32, 42, 43, 44, 58, 59, 60, 73, 80, 88, 103, 104, 105, 107, 108, 112, 120, 122, 134, 148, 154, 155, 158, 170, 186, 198, 199, 219, 220, 222, 227, 238, 262, 264, 265, 271, 284, 297, 301, 304, 305, 311, 313, 324, 333, 335, 340, 344`

### Random-Number Support

The random-context resolver now covers the same `22` sections identified by the original source-text sweep:

`26, 35, 39, 55, 85, 86, 116, 128, 129, 148, 166, 169, 175, 185, 225, 241, 255, 266, 327, 328, 337, 343`

Current automated result-side effects are implemented for:

- `26` transparent-prison oxygen loss
- `85` cliff-climb ENDURANCE loss
- `129` Adgana addiction resolution
- `241` red-fire bolt ENDURANCE loss

The remaining random-context sections are still surfaced as guided play support rather than direct auto-resolution, which is acceptable for current `main` stabilization so long as the playtest remains green.

### Instant Death

The instant-death dispatcher now covers the original Book `7` death surface:

`28, 51, 64, 77, 84, 105, 106, 121, 159, 163, 189, 237, 263, 273, 275, 292, 300, 331, 340, 349`

Notes:

- most of these are direct automatic death triggers
- sections `105` and `340` are currently represented as route / story surfaces rather than unconditional kill hooks

### Story And Route Tracking

Section-based trigger points currently include:

`1, 12, 43, 73, 105, 133, 186, 271, 291, 305, 317, 333, 340, 347, 349`

Transition-based route tracking currently includes:

`1->135, 100->34, 119->280, 138->118, 174->149, 202->149, 138->250, 149->250, 149->267, 267->200, 315->122, 338->122`

## Validation Artifacts

- `testing/logs/BOOK7_STARTUP_SMOKE_PS7.txt`
- `testing/logs/BOOK7_STARTUP_SMOKE_PS51.txt`
- `testing/logs/BOOK7_CHOICE_FLOW_SMOKE_PS7.txt`
- `testing/logs/BOOK7_CHOICE_FLOW_SMOKE_PS51.txt`
- `testing/logs/BOOK7_COMBAT_HOOK_SMOKE_PS7.txt`
- `testing/logs/BOOK7_COMBAT_HOOK_SMOKE_PS51.txt`
- `testing/logs/BOOK7_ACHIEVEMENT_SMOKE_PS7.txt`
- `testing/logs/BOOK7_ACHIEVEMENT_SMOKE_PS51.txt`
- `testing/logs/BOOK7_RANDOM_AUTOMATION_SMOKE_PS7.txt`
- `testing/logs/BOOK7_RANDOM_AUTOMATION_SMOKE_PS51.txt`
- `testing/logs/BOOK7_AUTOMATION_SURFACE_SMOKE_PS7.txt`
- `testing/logs/BOOK7_AUTOMATION_SURFACE_SMOKE_PS51.txt`
- `testing/logs/BOOK7_ENDGAME_ROUTE_SMOKE_PS7.txt`
- `testing/logs/BOOK7_ENDGAME_ROUTE_SMOKE_PS51.txt`
- `testing/logs/BOOK7_DIFFICULTY_SMOKE_PS7.txt`
- `testing/logs/BOOK7_DIFFICULTY_SMOKE_PS51.txt`

## Current Conclusion

The missing Book `7` work on current `main` is no longer core implementation. The remaining gap is release-readiness hardening:

- user-led Book `7` playtest
- any follow-up route fixes found during that playtest
- broader release-bar validation before a public version/tag bump
