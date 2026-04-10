# Changelog

All notable public release changes for the Lone Wolf Action Assistant should be tracked here.

This file is meant to summarize shipped behavior at release time, not every internal commit.

## Unreleased

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
