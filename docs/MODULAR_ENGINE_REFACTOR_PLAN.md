# Modular Engine Refactor Plan

## Purpose

This document defines the planned refactor from the current monolithic `lonewolf.ps1` application into a modular engine architecture.

The immediate driver is maintainability:

- the current main script is large and still growing
- adding more books directly into one file will become increasingly error-prone
- future rule sets should not require duplicating the whole app

This plan is intentionally written **before** any refactor code changes begin.

## Current State

Today the app has:

- a working Kai campaign flow through Books `1-5`
- achievements, modes, saves, combat, stats, and inventory in one main script
- Project Aon baseline rule coverage through Book `5`
- local testing/reporting workflows already established

This is a good functional baseline, but the code organization is now the main scaling risk.

## Refactor Goals

1. Keep the app behaviorally stable while changing its structure.
2. Split the monolith into clear modules with narrow responsibilities.
3. Move book-specific logic out of the engine and into book modules.
4. Make the ruleset itself pluggable, so future rule sets can reuse the engine.
5. Preserve existing save compatibility through a controlled migration layer.
6. Keep the current command surface intact unless a later UX change is explicitly approved.

## Non-Goals

This refactor is **not** primarily for:

- redesigning the UI
- changing the command vocabulary
- rewriting all saves from scratch
- changing achievement philosophy
- switching away from PowerShell

Those can happen later, but they are not required for this milestone.

## Proposed End State

The target structure is:

```text
lonewolf.ps1
modules/
  core/
    bootstrap.psm1
    ui.psm1
    commands.psm1
    saves.psm1
    inventory.psm1
    combat.psm1
    achievements.psm1
    modes.psm1
    stats.psm1
    validation.psm1
    migrations.psm1
  rulesets/
    kai/
      kai.psm1
      book1.psm1
      book2.psm1
      book3.psm1
      book4.psm1
      book5.psm1
data/
  rulesets/
    kai/
      ...
```

## Core Design

### Thin Entry Script

`lonewolf.ps1` should become a thin launcher that:

- resolves paths
- imports the core engine
- imports the selected ruleset
- starts the terminal session

It should stop being the place where the full application logic lives.

### Core Engine

The engine should own:

- screen rendering
- command routing
- save/load/autosave
- inventory primitives
- combat primitives
- achievement evaluation
- mode enforcement
- stats/history storage
- integrity/tamper logic
- migration/version logic

The engine should **not** know section text or book-specific one-offs directly.

### Ruleset Layer

A ruleset module should register:

- rule set name
- supported books
- startup flows
- carry-forward behavior
- section-entry rules
- section-transition rules
- special combat hooks
- random-number context logic
- item intelligence specific to that ruleset
- ruleset/book achievement definitions

### Book Modules

Each book module should provide:

- section-entry handlers
- combat special cases
- route/endgame metadata
- book-specific random-number support
- book-specific item and achievement hooks

Book modules should be the place where future rule differences are localized.

## Save Model Direction

Saves should remain movable and version-aware.

The save model should explicitly carry:

- `Ruleset`
- `BookNumber`
- `EngineVersion`
- `RulesetVersion`
- migration markers if needed

This supports the longer-term goal of:

- one app architecture
- multiple rulesets
- saves that can survive refactors and loader changes

## Refactor Strategy

The refactor should be incremental, not a big-bang rewrite.

Rules:

1. The app must stay runnable at each milestone.
2. Existing saves must continue to load unless a migration path has been added first.
3. No milestone should mix architectural extraction with broad gameplay redesign.
4. Every extraction step must be followed by validation in:
   - PowerShell 7
   - Windows PowerShell 5.1
5. Book behavior should be moved, not reinterpreted.

## Recommended Extraction Order

1. Bootstrap and module loader
2. shared utilities/helpers
3. UI and command routing
4. save/integrity/migration layer
5. inventory/combat/stats engines
6. achievement/mode engines
7. Kai ruleset shell
8. Books `1-2`
9. Books `3-5`
10. final regression and command-surface sweep

## Testing Requirements

The refactor is not done unless these still pass:

- parser checks in both shells
- command-surface smoke
- save/load flow
- mode and permadeath flow
- combat smoke
- Books `1-5` campaign progression smoke

Existing local validation harnesses should be preserved and extended where useful rather than thrown away.

## Risk Areas

Highest refactor risk:

- save compatibility
- hidden coupling in the current global state
- achievement triggers that currently depend on script-local side effects
- command routing assumptions
- book startup/carry-forward transitions

## Acceptance Criteria

This refactor milestone is complete when:

- the main script is a thin bootstrap
- engine logic is separated from book logic
- Kai Books `1-5` are loaded through ruleset/book modules
- current saves still load or migrate cleanly
- command surface still works
- the validation baseline still passes

## Relationship To Future Work

This refactor is the foundation for:

- future Kai books
- additional Lone Wolf rule sets as separate packages
- cleaner DE-difference handling
- less risky future maintenance

## Tracking

Milestones for this refactor are tracked in:

- [PROJECT_MILESTONES.md](/C:/Scripts/Lone%20Wolf/docs/PROJECT_MILESTONES.md)
