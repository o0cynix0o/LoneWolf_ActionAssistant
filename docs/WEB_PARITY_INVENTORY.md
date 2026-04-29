# Web Parity Inventory

## Purpose

This document is the Phase `0` parity inventory for the web-GUI and
cross-platform migration.

It defines the currently supported Lone Wolf feature surface that must remain
behaviorally stable as the app moves from a terminal-first experience to a
browser-first local app.

This is not a full code map. It is the functional inventory that the migration
must preserve.

## Current Parity Baseline

The current parity baseline is:

- released gameplay support through Books `1-6`
- current `main` gameplay support through Book `7`
- CLI-driven campaign play with saves, combat, achievements, stats, notes, and
  history
- current validation harnesses in PowerShell `7` and Windows PowerShell `5.1`

The web migration should preserve the current `main` supported surface, not
only the latest public release surface.

## Player-Facing Runtime Surfaces

The app currently exposes these major runtime surfaces:

- welcome / startup
- new run setup
- difficulty and permadeath selection
- load / save / autosave
- sheet
- inventory
- disciplines
- notes
- history
- stats
- campaign review
- achievements
- combat status / combat log / combat summary
- death / rewind
- book-complete recap

These surfaces are currently presented through terminal screens, but their
underlying behavior must survive the migration even if the rendered layout
changes.

## Gameplay And State Surfaces

The current game/state model includes:

- character identity and current book progress
- Kai and Magnakai discipline state
- Weaponmastery / Weaponskill carry-forward state
- inventory sections:
  - weapons
  - backpack items
  - herb pouch items
  - special items
  - pocket special items
  - safekeeping special items
- gold, ENDURANCE, combat skill, and equipment bonuses
- current section and section-visit history
- current book stats and whole-run campaign history
- combat state, combat log, and archived combat results
- achievements, progress flags, and story flags
- run difficulty, permadeath, and integrity tracking
- death state and death-only rewind checkpoints

## Book And Ruleset Surfaces

The migration must preserve:

- ruleset-aware campaign flow
- book-specific startup packages
- book-specific section-entry automation
- book-specific combat hooks
- book-specific carry-over rules
- source-text and DE-specific rule handling already implemented on `main`

Current supported surface on `main`:

- Kai Books `1-5`
- Magnakai Books `6-7`

## Command And Workflow Surfaces

The current app supports a broad command surface and many multi-step flows.

Important command/workflow categories:

- section navigation
- inventory add / drop / recover flows
- meals, potions, healing, and gold adjustments
- combat start / round / evade / stop
- notes add / remove
- stats, campaign, and achievement views
- save / load flows
- death rewind flow
- book-transition flow

Some of these are simple commands. Others are interactive workflows that
currently depend on terminal prompts and must move to a structured pending-
choice model for the web UI.

## Prompt Classes That Need Structured Migration

The main prompt classes that need explicit web-safe modeling are:

- difficulty selection
- permadeath confirmation
- Kai discipline selection
- Magnakai discipline selection
- Weaponmastery / Weaponskill choice
- book startup package choices
- loot / shop / payment choice tables
- make-room prompts
- safekeeping prompts
- save-path and load-selection prompts
- combat setup prompts
- transition prompts between books

These are the highest-value candidates for Phase `2` prompt/workflow
conversion.

## Screen Inventory

Current screen names already in use include:

- `welcome`
- `load`
- `sheet`
- `inventory`
- `disciplines`
- `notes`
- `history`
- `stats`
- `campaign`
- `achievements`
- `modes`
- `combat`
- `combatlog`
- `death`
- `bookcomplete`
- `disciplineselect`

The web UI does not need to copy these layouts exactly, but it should still
respect the same functional transitions between them.

## Save And Transition Surfaces

Save compatibility is a migration-critical surface.

The web migration must preserve:

- current save schema support
- load normalization and repair paths
- autosave behavior
- last-used save behavior
- book-transition carry-over rules
- difficulty/permadeath state
- integrity state and tamper-evident tracking

The migration should treat save compatibility as a blocker-level concern, not a
polish task.

## Combat Surfaces

Combat parity includes:

- manual and data-driven combat modes
- combat start/setup behavior
- weapon selection rules
- Mindblast / Psi-surge / special psychic behavior
- evade timing rules
- special enemy requirements and resolutions
- combat logs, summaries, and campaign rollups
- book-specific combat exceptions and instant-death interactions

## Stats, History, And Achievement Surfaces

The migration must preserve:

- current book stats
- whole-run campaign review
- combat archive/history
- per-book and campaign-level survival/combat summaries
- achievement availability rules
- achievement unlock behavior
- recent unlock display state
- story and challenge tracking

## Validation Inventory

Existing validation categories that matter to the migration include:

- command-surface smokes
- book startup smokes
- choice/state smokes
- combat-hook smokes
- achievement smokes
- random automation smokes
- automation-surface smokes
- endgame route smokes
- difficulty/permadeath smokes
- packaging/startup/load smokes

These should be preserved and extended, not replaced by ad hoc browser testing.

## Initial M6 Gap List

The web migration still needs explicit implementation work for:

- structured pending-choice modeling
- browser-safe inventory workflows
- browser-safe startup/setup workflows
- real API contract coverage for combat and save flows
- cross-platform launcher and packaging hardening
- UI parity for campaign/achievement-heavy views

## Current M6 Kickoff Deliverables

The first tracked migration slice should establish:

- this parity inventory
- the formal migration plan
- a repo-tracked local web scaffold
- a real PowerShell-session-to-HTTP adapter path
- a browser shell that reads state from JSON instead of terminal streaming

That does not complete parity, but it does establish the correct direction for
the rest of the work.
