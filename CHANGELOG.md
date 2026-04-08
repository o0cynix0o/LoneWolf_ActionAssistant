# Changelog

All notable public release changes for the Lone Wolf Action Assistant should be tracked here.

This file is meant to summarize shipped behavior at release time, not every internal commit.

## Unreleased

- Dev branch currently carries the Book `6` / Magnakai implementation work that is not part of the `v0.7.40` public release yet.
- Portable packaging now includes the Magnakai data files needed for Book `6` and ships `CHANGELOG.md` in the portable bundle.
- Portable packaging now has a repo-tracked validator at `validate-release.ps1` that smoke-tests a disposable extracted package copy in both shells.
- Main screens now include compact screen-specific `Helpful Commands` panels so the most relevant commands stay visible in context.

## v0.8.0-dev - 2026-04-03

Current `dev` branch checkpoint.

### Highlights

- Magnakai ruleset support now exists for Book `6`
- Book `5` now hands off into Book `6` with:
  - ruleset change
  - Magnakai discipline selection
  - Weaponmastery starter selection
  - lore-circle bonus handling
- Book `6` section, combat, and achievement support added
- Total achievements increased to `111`

### Validation Notes

- targeted Book `6` validation passed in:
  - PowerShell `7`
  - Windows PowerShell `5.1`
- Books `1-6` full-campaign validation repeatedly cleared the Kai -> Magnakai handoff
- an interrupted long-run validator still completed `44` full PowerShell `7` Books `1-6` campaigns before the user stopped the sweep
- the user explicitly approved moving forward before a fresh full long-run rerun was finished

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
