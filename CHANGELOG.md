# Changelog

All notable public release changes for the Lone Wolf Action Assistant should be tracked here.

This file is meant to summarize shipped behavior at release time, not every internal commit.

## Unreleased

- prerelease full-sweep Batches `1-4` are now green in both PowerShell `7` and Windows PowerShell `5.1`, including:
  - package validation
  - command-surface and save-system prerelease passes
  - Books `1-6` prerelease campaign coverage
  - NewRun difficulty sweep, achievement audit, and performance capture
- fixed a post-optimization regression where module host-command caches could permanently remember missing late-bound functions and break later load/performance paths
- fixed a strict-mode regression in backpack layout handling where one-item collections could collapse to scalars and crash Book `2` / Book `3` startup gear screens
- fixed a Book `5` confiscation regression where pocket-carried confiscated items could collapse to scalars under strict mode and break summary/restore flows

- prerelease Batch 1 foundation pass is now green in both shells:
  - package and cold-start validation
  - command-surface prerelease sweep
  - save-system prerelease sweep
- fixed a command-surface inventory defect where `add backpack Arrow` could add arrows to the Backpack instead of the Quiver when a `Quiver` was carried
- fixed a packaged/runtime strict-mode regression where module-local `GameData` could be missing during load/normalize flows
- fixed the no-save `load` screen path so an empty save catalog renders cleanly instead of crashing
- final architecture cleanup pass completed the remaining extraction buckets from `recommendations.md`, including:
  - combat stat / weapon / archive helpers into `modules/core/combat.psm1`
  - a new `modules/core/healing.psm1`
  - section random-number / torch / hunting helpers into `modules/core/ruleset.psm1`
  - remaining UI primitives into `modules/core/shell.psm1`
  - input helpers into `modules/core/common.psm1`
  - missed state constructors into `modules/core/state.psm1`
- `lonewolf.ps1` is now reduced to roughly `1.2k` lines and acts as bootstrap plus top-level orchestration
- post-final-pass command-surface validation is green in both shells:
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT3_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT3_PS51.txt`
- architecture extraction pass now moves the largest remaining engine blocks out of `lonewolf.ps1` into:
  - `modules/core/achievements.psm1`
  - `modules/core/items.psm1`
  - `modules/core/inventory.psm1`
- remaining state, save, screen, combat, common, and ruleset helpers were also extracted into their owning modules:
  - `modules/core/combat.psm1`
  - `modules/core/state.psm1`
  - `modules/core/save.psm1`
  - `modules/core/shell.psm1`
  - `modules/core/common.psm1`
  - `modules/core/ruleset.psm1`
  - `modules/rulesets/kai/kai.psm1`
  - `modules/rulesets/magnakai/magnakai.psm1`
- `lonewolf.ps1` is now reduced to roughly `1.2k` lines and acts primarily as bootstrap, shared-state wiring, and top-level orchestration
- post-extraction runtime validation is green in both shells:
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS51.txt`
- runtime now rotates oversized `data/error.log` files at startup, archives them as `error-YYYYMMDD-HHMMSS.log`, and keeps the latest `5`
- new `modules/core/shell.psm1` now owns runtime maintenance, notifications, banners, and additional screen renderers for:
  - stats
  - campaign
  - achievements
  - inventory
  - main sheet
- book-specific combat encounter profiles and scenario rules now dispatch through:
  - `modules/rulesets/kai/combat.psm1`
  - `modules/rulesets/magnakai/combat.psm1`
- `modules/core/combat.psm1` no longer carries the legacy inline per-book scenario branch
- additional strict-mode/null-safety hardening landed in core save/common/shell handling
- stale duplicate wrapper-era functions were removed from `lonewolf.ps1`, including dead legacy copies of:
  - save/load
  - command dispatch
  - combat startup
  - section-entry rules
  - section random-number context dispatch
  - story-section achievement trigger dispatch
- Book `1-5` starting-equipment helper definitions now live with their respective Kai book modules instead of the main script
- Book `1-6` section-context achievement ID lists now live with their respective book modules and dispatch through `modules/core/ruleset.psm1`
- generic loot-choice and book-transition safekeeping prompts now live in `modules/core/shell.psm1` instead of `lonewolf.ps1`
- Book `4` section `12` choice handling now lives in `modules/rulesets/kai/book4.psm1`
- Book `6` riverboat-ticket item names now live in `modules/rulesets/magnakai/book6.psm1`
- `Book of the Magnakai` item-name helpers now live in `modules/rulesets/magnakai/magnakai.psm1`
- Book `6` section `10` now prompts for the riverboat ticket purchase, stores the ticket as a pocket-carried Special Item outside the normal `12`-item cap, and surfaces the ticket route again at section `124`
- Book `6` OG automation catch-up expanded across:
  - fixed ENDURANCE losses and gains
  - Random Number helpers
  - gold, item, and equipment state changes
  - combat-special rules
- Book `6` validation was rerun in both PowerShell `7` and Windows PowerShell `5.1`, including:
  - instant-death matrix reruns
  - full sample-route and difficulty matrix reruns
  - targeted section `155` combat timing validation

## v0.8.0 - 2026-04-09

Second public release.

### Highlights

- Magnakai support is now public for Book `6`
- Book `5` now hands off into Book `6` with:
  - ruleset change
  - Magnakai discipline selection
  - Weaponmastery starter selection
  - lore-circle bonus handling
- Book `6` section, combat, and achievement coverage expanded substantially, including Definitive Edition differences found during live playtesting
- Total achievements increased to `111`

### UX And Command Surface

- M3 retro UI refresh is now part of the shipped build across:
  - welcome
  - load
  - help
  - modes
  - main character sheet
  - inventory
  - disciplines
  - stats
  - campaign
  - achievements
  - notes
  - history
  - combat
  - combat log
  - death
  - book complete
- main screens now include compact screen-specific `Helpful Commands` panels
- combat archive/detail rendering is cleaner and more stable
- inventory, campaign, achievement, and combat panels were compacted to reduce redraw clutter

### Packaging And Validation

- portable packaging now includes the Magnakai data files needed for Book `6`
- the portable bundle now ships `CHANGELOG.md`
- `validate-release.ps1` now smoke-tests a disposable extracted package copy in both shells
- Books `1-6` route, command-surface, and package validation cleared in both PowerShell `7` and Windows PowerShell `5.1`

### Release Asset

- `LoneWolf_ActionAssistant_v0.8.0_portable.zip`
- GitHub release:
  `https://github.com/o0cynix0o/LoneWolf_ActionAssistant/releases/tag/v0.8.0`

## v0.7.40 - 2026-04-02

First public release.

### Highlights

- Kai ruleset support through Books `1-5`
- Screen-based PowerShell Action Chart companion with:
  - inventory
  - combat
  - saves
  - notes
  - stats
  - campaign review
  - achievements
- Book-aware automation for:
  - startup packages
  - carry-forward state
  - loot sections
  - special combat hooks
  - forced damage and item loss
  - major route and story rules
- Locked run difficulties:
  - `Story`
  - `Easy`
  - `Normal`
  - `Hard`
  - `Veteran`
  - optional `Permadeath`
- M1 modular engine refactor completed and shipped
- Portable packaging workflow and first portable release zip

### GitHub And Docs

- Wiki strategy guides published for Books `1-5`
- GitHub milestones, labels, issue forms, and project board are now in use
- Repo workflow and handoff docs updated for the modular engine and release process

### Release Asset

- `LoneWolf_ActionAssistant_v0.7.40_portable.zip`
- GitHub release:
  `https://github.com/o0cynix0o/LoneWolf_ActionAssistant/releases/tag/v0.7.40`
