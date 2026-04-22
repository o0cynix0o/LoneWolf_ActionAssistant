# Project Milestones

This file is the repo-tracked milestone list for the Lone Wolf Action Assistant.

Status values:

- `planned`
- `in_progress`
- `completed`
- `on_hold`

## Current Milestone Focus

Current top milestone focus:

- `in_progress` `M5` Post-Release Stabilization And Book `7+` Planning
- operational source-of-truth branch for this work: `main`
- `dev` currently trails `main` and should not be treated as the active integration branch until branch strategy is reconciled

## Milestone List

### M1 - Modular Engine Refactor

Status:

- `completed`

Goal:

- split the monolithic app into a core engine plus ruleset/book modules

Deliverables:

- thin `lonewolf.ps1` bootstrap
- `modules/core/` engine modules
- `modules/rulesets/kai/` ruleset shell
- Kai Books `1-5` moved into book modules
- save-version and migration support for the refactor

Exit criteria:

- Books `1-5` still work
- existing saves load cleanly
- command surface remains stable
- validation passes in PowerShell 7 and Windows PowerShell 5.1
- validation meets the route-and-mode coverage standard in `docs/VALIDATION_POLICY.md`

Completion note:

- completed on 2026-03-27 and later pushed after playtesting
- validation:
  - `100` full Books `1-5` sandbox campaigns passed
  - `60` initial campaigns
  - `40` additional campaigns to clear the `100+` exit bar
  - command-surface smoke passed in both shells

Reference:

- [MODULAR_ENGINE_REFACTOR_PLAN.md](./MODULAR_ENGINE_REFACTOR_PLAN.md)

### M1.1 - Bootstrap And Loader

Status:

- `completed`

Goal:

- make `lonewolf.ps1` a thin entrypoint

Deliverables:

- bootstrap file/module loading pattern
- centralized import order
- no behavioral changes intended

Checkpoint:

- thin launcher/module import path is active in the shipped build
- latest validation notes:
  - `testing/logs/M1_1_BOOTSTRAP_VALIDATION.md`
  - `testing/logs/M1_7_COMPLETION_SUMMARY_20260327.md`

### M1.2 - Core Engine Extraction

Status:

- `completed`

Goal:

- move shared non-book logic into engine modules

Deliverables:

- UI module
- command-routing module
- save/integrity module
- inventory/combat/stats modules
- achievement/mode modules

Checkpoint:

- first extracted modules:
  - `modules/core/bootstrap.psm1`
  - `modules/core/display.psm1`
  - `modules/core/common.psm1`
- additional extracted engine modules in the shipped build:
  - `modules/core/state.psm1`
  - `modules/core/save.psm1`
  - `modules/core/commands.psm1`
  - `modules/core/combat.psm1`
  - `modules/core/ruleset.psm1`
- validated locally before push
- see `testing/logs/M1_7_COMPLETION_SUMMARY_20260327.md`

### M1.3 - Kai Ruleset Shell

Status:

- `completed`

Goal:

- establish a first-class ruleset registration layer

Deliverables:

- `modules/rulesets/kai/kai.psm1`
- ruleset metadata and registration hooks
- book-dispatch mechanism

Checkpoint:

- Kai ruleset shell and dispatch are active in the shipped build
- book modules currently present for Kai Books `1-5`

### M1.4 - Kai Books 1-2 Extraction

Status:

- `completed`

Goal:

- move the first two books into book modules

Deliverables:

- `book1.psm1`
- `book2.psm1`
- startup, section, combat, and achievement hooks moved out of the monolith

Checkpoint:

- Books `1-2` now load through `modules/rulesets/kai/` in the shipped build

### M1.5 - Kai Books 3-5 Extraction

Status:

- `completed`

Goal:

- move the remaining Kai books into book modules

Deliverables:

- `book3.psm1`
- `book4.psm1`
- `book5.psm1`

Checkpoint:

- Books `3-5` now load through `modules/rulesets/kai/` in the shipped build

### M1.6 - Save Migration And Ruleset-Aware Saves

Status:

- `completed`

Goal:

- keep old saves usable while formalizing a multi-ruleset save model

Deliverables:

- ruleset-aware save metadata
- migration logic
- migration validation against existing live formats

Checkpoint:

- saves now normalize `RuleSet`, `EngineVersion`, and `RuleSetVersion` in the shipped build

### M1.7 - Full Regression Pass

Status:

- `completed`

Goal:

- prove the refactor did not break behavior

Deliverables:

- command-surface smoke
- Books `1-5` campaign smoke
- cross-shell validation
- route-and-mode validation coverage as defined in `docs/VALIDATION_POLICY.md`
- updated handoff and validation notes

Checkpoint:

- current M1 validation:
  - `100` full Books `1-5` campaigns
  - command-surface smoke in both shells
  - local reports:
    - `testing/logs/FULL_VALIDATION_REPORT_M1_PWSH_40.md`
    - `testing/logs/FULL_VALIDATION_REPORT_M1_PS51_20.md`
    - `testing/logs/FULL_VALIDATION_REPORT_M1_PWSH_EXTRA20.md`
    - `testing/logs/FULL_VALIDATION_REPORT_M1_PS51_EXTRA20.md`
    - `testing/logs/FULL_VALIDATION_REPORT_M1_PWSH_40.md`
    - `testing/logs/M1_7_COMPLETION_SUMMARY_20260327.md`

### M2 - Additional Rule Set Support

Status:

- `completed`

Goal:

- use the modular architecture to support a second ruleset app/package cleanly

Notes:

- this starts only after `M1` is complete
- saves should be movable through explicit ruleset metadata
- Book `6` / Magnakai is the planned entry point for `M2`

Deliverables:

- `modules/rulesets/magnakai/` ruleset shell
- Book `5` -> `6` transition flow
- ruleset-neutral state and sheet handling
- Magnakai discipline engine
- Book `6` audit/build support

Exit criteria:

- standalone Book `6` new-game flow works
- Book `5` -> `6` carry-over flow works
- existing Kai saves still load cleanly
- validation passes in PowerShell 7 and Windows PowerShell 5.1
- validation meets the route-and-mode coverage standard in `docs/VALIDATION_POLICY.md`

Completion note:

- Magnakai / Book `6` implementation completed on `main`
- M2.7 closeout completed on `2026-04-07`
- final closeout validation included:
  - fresh-character full Books `1-6` campaigns in both shells on:
    - `Story`
    - `Easy`
    - `Normal`
    - `Hard`
    - `Veteran`
    - `Hard + Permadeath`
  - synthetic sample Book `5` -> `6` route matrix:
    - `20/20` pass in PowerShell `7`
    - `20/20` pass in Windows PowerShell `5.1`
  - current sample save/load/`-Load`/command-surface smoke in both shells
  - explicit non-permadeath and permadeath failure coverage in both shells

Reference:

- [MAGNAKAI_BOOK6_PLAN.md](./MAGNAKAI_BOOK6_PLAN.md)

Tracking issue:

- GitHub issue `#18` `Plan Book 6 Magnakai ruleset transition`

### M2.1 - Magnakai Ruleset Shell

Status:

- `completed`

Goal:

- add a real second ruleset shell beside Kai

Deliverables:

- `modules/rulesets/magnakai/magnakai.psm1`
- ruleset dispatch entries for Magnakai

### M2.2 - Ruleset-Neutral Character State

Status:

- `completed`

Goal:

- evolve the save/state model so Magnakai data is first-class instead of bolted onto Kai fields

Deliverables:

- Magnakai discipline state
- Magnakai rank state
- Weaponmastery checklist state
- Lore-circle completion state
- Improved Discipline placeholder state

### M2.3 - Book 5 To Book 6 Transition

Status:

- `completed`

Goal:

- implement the actual ruleset handoff from Kai to Magnakai

Deliverables:

- carry-over CS / END handling
- carry-over Weapons / Special Items handling
- Book `6` starting gold and item package
- Magnakai discipline selection
- Weaponmastery starter selection

### M2.4 - Magnakai Sheet And Command Surface

Status:

- `completed`

Goal:

- make the UI and commands ruleset-aware instead of Kai-only

Deliverables:

- Magnakai sheet layout
- ruleset-aware discipline panels
- updated command help text

### M2.5 - Magnakai Combat And Discipline Engine

Status:

- `completed`

Goal:

- support the Book `6` mechanical differences in the core engine

Deliverables:

- Weaponmastery handling
- Psi-surge / Mindblast handling
- Psi-screen handling
- Huntmastery and Nexus handling
- Lore-circle bonus engine

### M2.6 - Book 6 Full Audit + Build

Status:

- `completed`

Goal:

- do the standard full audit/build pass for Book `6`

Deliverables:

- route audit
- rules and items audit
- Book `6` implementation
- Book `6` achievements
- Book `6` strategy guide

### M2.7 - Full Regression Pass Through Book 6

Status:

- `completed`

Goal:

- prove the new ruleset and transition did not break the existing campaign

Deliverables:

- command-surface smoke
- cross-shell validation
- standalone Book `6` validation
- full fresh-character campaign coverage through Books `1-6`
- synthetic sample transition route matrix coverage
- save/load/`-Load` and failure/permadeath smoke in both shells

Checkpoint:

- completed on `2026-04-07`
- summary report:
  - `testing/logs/M2_7_COMPLETION_SUMMARY_20260407.md`
- supporting reports:
  - `testing/logs/MODE_CAMPAIGN_VALIDATION_PS7.md`
  - `testing/logs/MODE_CAMPAIGN_VALIDATION_PS51.md`
  - `testing/logs/BOOK6_CYNIX_ROUTE_MATRIX_PS7.md`
  - `testing/logs/BOOK6_CYNIX_ROUTE_MATRIX_PS51.md`
  - `testing/logs/M2_7_FAILURE_AND_SMOKE_PS7.md`
  - `testing/logs/M2_7_FAILURE_AND_SMOKE_PS51.md`

### M4 - Portable Distribution Packaging

Status:

- `completed`

Goal:

- prepare a repeatable portable release workflow for the current PowerShell app

Deliverables:

- repo-tracked release builder
- repo-tracked package validator
- generated launcher files in the portable package
- package manifest
- packaging workflow doc
- local packaging validation notes

Exit criteria:

- portable staging folder builds cleanly
- portable zip builds cleanly
- staged copy initializes and loads modules correctly
- staged copy passes a basic command-surface smoke check

Local checkpoint:

- repo-tracked builder active at `build-release.ps1`
- repo-tracked validator active at `validate-release.ps1`
- packaging workflow tracked in `docs/DISTRIBUTION_PACKAGING_PLAN.md`
- keep generated packages local in `testing/releases/`
- initial package build + smoke validation passed on `2026-03-27`
- final M4 closeout validation passed on `2026-04-07`
- closeout reports:
  - `testing/logs/PACKAGING_PREP_VALIDATION_20260327.md`
  - `testing/logs/PACKAGING_M4_VALIDATION_SUMMARY.md`

### M3 - UX Polish Pass

Status:

- `completed`

Goal:

- clean up terminal flow once the architecture is stable

Notes:

- this stays behind the refactor because UI cleanup is safer after module boundaries exist
- approved visual direction for M3:
  - `Arcade / GameFAQs Retro`
- shared UI rules now tracked in:
  - `docs/M3_UI_STYLE_GUIDE.md`

Deliverables:

- shared UI style spec
- refreshed main banner
- refreshed character sheet
- refreshed inventory/combat/campaign/achievement screens
- consistent panel and border language across the app

Completion checkpoint:

- completed on `2026-04-07`
- approved visual standards locked into:
  - `docs/M3_UI_STYLE_GUIDE.md`
- shared retro screen refresh now covers:
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
- validation passed in PowerShell `7` and Windows PowerShell `5.1`:
  - `testing/logs/M3_SCREEN_RENDER_PW7.txt`
  - `testing/logs/M3_SCREEN_RENDER_PS51.txt`

### M5 - Post-Release Stabilization And Book 7+ Planning

Status:

- `in_progress`

Goal:

- keep the released Books `1-6` experience stable while preparing the current `main` Book `7` expansion cleanly

Deliverables:

- post-release bug triage for the shipped Books `1-6` command surface
- continued DE-difference cleanup found during real play
- current `main` Book `6` stabilization hardening across sections `2`, `17`, `98`, `158/293`, `170`, and `297`
- Book `7` validation and hardening across startup, choice, combat, achievements, route coverage, and difficulty behavior
- branch/docs cleanup so public release state and current `main` state stay explicit
- ruleset/state design notes for the next expansion step

Current checkpoint:

- `main` is the current operational source of truth and is `13` commits ahead of `dev` as of `2026-04-22`
- Book `6` stabilization validation is green in both shells:
  - `testing/logs/BOOK6_INSTANT_DEATH_MATRIX_PS7_AUTOFIX_RERUN.md`
  - `testing/logs/BOOK6_INSTANT_DEATH_MATRIX_PS51_AUTOFIX_RERUN.md`
  - `testing/logs/BOOK6_SAMPLE_ROUTE_MATRIX_PS7_AUTOFIX_RERUN2.md`
  - `testing/logs/BOOK6_SAMPLE_ROUTE_MATRIX_PS51_AUTOFIX_RERUN2.md`
- current `main` Book `7` validation is green in both shells:
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
- architecture-hardening and lag-hardening work previously tracked on `dev` is already present on `main`:
  - runtime `error.log` rotation
  - `modules/core/shell.psm1` extraction
  - ruleset combat-hook dispatch modules
  - strict-mode/null-safety hardening in core modules
  - large-scale monolith extraction now landed for:
    - `modules/core/achievements.psm1`
    - `modules/core/items.psm1`
    - `modules/core/inventory.psm1`
  - remaining ownership cleanup also landed in:
    - `modules/core/combat.psm1`
    - `modules/core/state.psm1`
    - `modules/core/save.psm1`
    - `modules/core/common.psm1`
    - `modules/core/ruleset.psm1`
    - `modules/rulesets/kai/kai.psm1`
    - `modules/rulesets/magnakai/magnakai.psm1`
  - post-extraction command-surface validation is green in both shells:
    - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS7.txt`
    - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS51.txt`

## Tracking Rules

When milestone work begins:

1. change the milestone status here
2. mention it in `docs/PROJECT_HANDOFF.md`
3. keep validation artifacts in `testing/`
4. only mark a milestone complete after the matching validation pass succeeds

## Validation Standard

Future milestone planning should use:

- `docs/VALIDATION_POLICY.md`

instead of the older flat `100+ sandbox runs` rule.

Historical milestone notes that mention `100+` runs are still accurate as records of what happened at the time.
