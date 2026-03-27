# Project Milestones

This file is the repo-tracked milestone list for the Lone Wolf Action Assistant.

Status values:

- `planned`
- `in_progress`
- `completed`
- `on_hold`

## Current Milestone Focus

Current top architectural milestone:

- `in_progress` `M1` Modular Engine Refactor

## Milestone List

### M1 - Modular Engine Refactor

Status:

- `in_progress`

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

Reference:

- [MODULAR_ENGINE_REFACTOR_PLAN.md](./MODULAR_ENGINE_REFACTOR_PLAN.md)

### M1.1 - Bootstrap And Loader

Status:

- `in_progress`

Goal:

- make `lonewolf.ps1` a thin entrypoint

Deliverables:

- bootstrap file/module loading pattern
- centralized import order
- no behavioral changes intended

### M1.2 - Core Engine Extraction

Status:

- `in_progress`

Goal:

- move shared non-book logic into engine modules

Deliverables:

- UI module
- command-routing module
- save/integrity module
- inventory/combat/stats modules
- achievement/mode modules

### M1.3 - Kai Ruleset Shell

Status:

- `planned`

Goal:

- establish a first-class ruleset registration layer

Deliverables:

- `modules/rulesets/kai/kai.psm1`
- ruleset metadata and registration hooks
- book-dispatch mechanism

### M1.4 - Kai Books 1-2 Extraction

Status:

- `planned`

Goal:

- move the first two books into book modules

Deliverables:

- `book1.psm1`
- `book2.psm1`
- startup, section, combat, and achievement hooks moved out of the monolith

### M1.5 - Kai Books 3-5 Extraction

Status:

- `planned`

Goal:

- move the remaining Kai books into book modules

Deliverables:

- `book3.psm1`
- `book4.psm1`
- `book5.psm1`

### M1.6 - Save Migration And Ruleset-Aware Saves

Status:

- `planned`

Goal:

- keep old saves usable while formalizing a multi-ruleset save model

Deliverables:

- ruleset-aware save metadata
- migration logic
- migration validation against existing live formats

### M1.7 - Full Regression Pass

Status:

- `planned`

Goal:

- prove the refactor did not break behavior

Deliverables:

- command-surface smoke
- Books `1-5` campaign smoke
- cross-shell validation
- `100+` sandbox tests of the command surface and actual app across the full Kai campaign
- updated handoff and validation notes

### M2 - Additional Rule Set Support

Status:

- `planned`

Goal:

- use the modular architecture to support a second ruleset app/package cleanly

Notes:

- this starts only after `M1` is complete
- saves should be movable through explicit ruleset metadata

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
