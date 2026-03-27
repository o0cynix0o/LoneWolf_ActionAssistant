# Project Milestones

This file is the repo-tracked milestone list for the Lone Wolf Action Assistant.

Status values:

- `planned`
- `in_progress`
- `completed`
- `on_hold`

## Current Milestone Focus

Current top architectural milestone:

- `completed` `M1` Modular Engine Refactor

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
- `100+` sandbox tests of the command surface and actual app pass across the full Kai campaign

Local completion note:

- completed locally on 2026-03-27 and intentionally held unpushed for playtesting
- current local validation:
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

Local checkpoint:

- thin launcher/module import path is active in the local unpushed M1 build
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

Local checkpoint:

- first extracted modules:
  - `modules/core/bootstrap.psm1`
  - `modules/core/display.psm1`
  - `modules/core/common.psm1`
- additional extracted engine modules in the local unpushed M1 build:
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

Local checkpoint:

- Kai ruleset shell and dispatch are active in the local unpushed M1 build
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

Local checkpoint:

- Books `1-2` now load through `modules/rulesets/kai/` in the local unpushed M1 build

### M1.5 - Kai Books 3-5 Extraction

Status:

- `completed`

Goal:

- move the remaining Kai books into book modules

Deliverables:

- `book3.psm1`
- `book4.psm1`
- `book5.psm1`

Local checkpoint:

- Books `3-5` now load through `modules/rulesets/kai/` in the local unpushed M1 build

### M1.6 - Save Migration And Ruleset-Aware Saves

Status:

- `completed`

Goal:

- keep old saves usable while formalizing a multi-ruleset save model

Deliverables:

- ruleset-aware save metadata
- migration logic
- migration validation against existing live formats

Local checkpoint:

- saves now normalize `RuleSet`, `EngineVersion`, and `RuleSetVersion` in the local unpushed M1 build

### M1.7 - Full Regression Pass

Status:

- `completed`

Goal:

- prove the refactor did not break behavior

Deliverables:

- command-surface smoke
- Books `1-5` campaign smoke
- cross-shell validation
- `100+` sandbox tests of the command surface and actual app across the full Kai campaign
- updated handoff and validation notes

Local checkpoint:

- current local M1 validation:
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

- `planned`

Goal:

- use the modular architecture to support a second ruleset app/package cleanly

Notes:

- this starts only after `M1` is complete
- saves should be movable through explicit ruleset metadata

### M4 - Portable Distribution Packaging

Status:

- `in_progress`

Goal:

- prepare a repeatable portable release workflow for the current PowerShell app

Deliverables:

- repo-tracked release builder
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

- repo-tracked builder planned at `build-release.ps1`
- packaging workflow tracked in `docs/DISTRIBUTION_PACKAGING_PLAN.md`
- keep generated packages local in `testing/releases/`
- local package build + package smoke validation passed on 2026-03-27
- see `testing/logs/PACKAGING_PREP_VALIDATION_20260327.md`

### M3 - UX Polish Pass

Status:

- `planned`

Goal:

- clean up terminal flow once the architecture is stable

Notes:

- this stays behind the refactor because UI cleanup is safer after module boundaries exist

## Tracking Rules

When milestone work begins:

1. change the milestone status here
2. mention it in `docs/PROJECT_HANDOFF.md`
3. keep validation artifacts in `testing/`
4. only mark a milestone complete after the matching validation pass succeeds
