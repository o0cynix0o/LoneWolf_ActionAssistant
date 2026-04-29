# Web GUI And Cross-Platform Migration Plan

## Purpose

This document defines the planned migration of the Lone Wolf Action Assistant
from a terminal-first PowerShell application into a web-GUI-first local app
with cross-platform support.

The immediate driver is product direction:

- the current app has grown into a feature-rich engine with substantial
  book-specific rule support
- the terminal UI remains effective for power users, but it now constrains
  presentation, discoverability, and portability
- a browser-based UI can make the app easier to use without giving up the
  rule, automation, and campaign depth that already exists
- compatibility now matters more than a Windows-only launch model

This plan is intentionally written before any large migration work begins.

## Decision Summary

Current recommendation:

1. keep the existing Lone Wolf game engine during the migration
2. move the project to a web-GUI-first architecture
3. use a local HTTP/JSON service instead of terminal streaming
4. keep the CLI available until parity is proven
5. target PowerShell `7` as the engine runtime for Windows, Linux, and macOS
6. use a small local web-server layer rather than a big-bang language rewrite

This is a migration plan, not a rewrite-from-scratch plan.

## Goals

1. Preserve `100%` of current gameplay and assistant behavior for the supported
   books.
2. Preserve existing core surfaces:
   - new game and carried campaign starts
   - character setup and discipline selection
   - inventory, gold, meals, healing, potions, and notes
   - combat setup, round handling, summaries, and special combat rules
   - section tracking and section-entry automation
   - saves, autosave, load, history, stats, and campaign review
   - achievements, difficulty rules, and optional permadeath
   - book transitions, carry-over logic, and book-complete summaries
3. Replace the terminal-first UX with a browser-based primary experience.
4. Support Windows, Linux, and macOS through a cross-platform local runtime.
5. Preserve save compatibility and validation discipline through the migration.
6. Keep a fallback CLI until the web UI has demonstrated behavioral parity.

## Non-Goals

This migration is not primarily for:

- changing book rules or reinterpreting source text
- dropping the CLI immediately
- rewriting the rules engine into Python before parity work begins
- changing save philosophy
- redesigning the command surface during the early migration phases
- shipping a network-hosted multi-user service

Those may be revisited later, but they are not required for this plan.

## Current State

Today the app has:

- a modular PowerShell engine with released support through Book `6`
- current `main` support through Book `7`
- established validation harnesses in PowerShell `7` and Windows PowerShell
  `5.1`
- a terminal UI that already exposes the full supported feature set
- difficulty, permadeath, integrity, stats, achievements, and campaign review
- substantial ruleset and book-specific automation already proven in live play

This is a strong rules-and-state baseline. The main migration risk is not rule
coverage; it is UI and runtime coupling.

## Current Blockers To The Target Direction

The main blockers are architectural, not gameplay-related:

- the app is still driven primarily by interactive terminal prompts
- screen rendering and interaction flow are still closely tied together in many
  places
- current startup, packaging, and launch workflows still assume Windows-first
  behavior
- terminal streaming is not the right permanent basis for a real browser UI
- compatibility is limited by Windows-specific launch glue, not by Lone Wolf's
  rules engine alone

## Recommended End State

The target architecture is:

```text
Browser UI
  -> Local HTTP/JSON server
    -> Lone Wolf engine session host
      -> Existing ruleset/book modules
        -> Data files / saves / logs

CLI fallback
  -> Same engine session host
```

The browser should become the primary interface, but the engine should remain
the single source of truth for rules, state transitions, and save logic.

## Technology Recommendation

### Engine

Keep the current engine in PowerShell during the migration and standardize on
PowerShell `7`.

Why:

- the current rules and state logic already exist and already work
- the project has an established validation culture around this engine
- the cost of proving parity is lower if the rules engine remains stable while
  the UI and runtime boundaries change

### Local Server Layer

The current recommendation is a small local server layer in Python.

Why:

- Python is already in use elsewhere in the local project ecosystem
- Python is a good fit for a local HTTP service, static-file hosting, and
  browser launch flow
- the server layer can act as a portability shell without forcing an immediate
  port of the game engine itself

This is a recommendation, not a requirement. The important decision is the
introduction of a real HTTP/JSON boundary. The server implementation language
is secondary to that boundary.

### Frontend

The frontend should be a real browser GUI, not a streamed terminal window.

It should eventually cover:

- sheet / stats
- inventory
- combat
- sections and navigation
- notes
- saves
- achievements
- campaign review and history
- book-complete recap

## Parity Contract

`100% parity` in this project means the web mode must preserve all supported
player-facing behavior for the shipped ruleset/book surface.

The parity bar includes:

- same rule outcomes
- same save semantics
- same inventory and carry-over outcomes
- same combat outcomes and combat hook behavior
- same achievement behavior
- same difficulty and permadeath behavior
- same book-transition behavior
- same book-complete and campaign summaries
- same automation coverage across the supported books

Parity does not require the browser UI to look like the terminal UI. It does
require the browser UI to preserve the same game behavior and decision space.

## Design Principles

1. One engine truth.
   UI layers must not fork gameplay logic.
2. Structured interaction over prompt scraping.
   The browser UI should consume explicit state and choice payloads, not parse
   terminal text.
3. Incremental migration.
   The app must stay runnable throughout the transition.
4. Compatibility as an architectural goal.
   Remove Windows-only assumptions wherever the user-facing behavior does not
   depend on them.
5. Validation-first changes.
   Every architectural step must be backed by repeatable local validation.

## Engine Boundary Direction

The engine should be treated as a session host with structured operations
instead of a script that assumes a human at a prompt.

At minimum, the boundary should support operations like:

- `new_game`
- `load_game`
- `save_game`
- `set_section`
- `apply_choice`
- `start_combat`
- `resolve_combat_round`
- `stop_combat`
- `add_note`
- `remove_note`
- `add_item`
- `drop_item`
- `adjust_gold`
- `render_book_complete`

Each operation should return:

- updated state snapshot
- any pending choice or prompt requirement
- any user-facing messages or warnings
- any screen-specific metadata the frontend needs to render cleanly

## Pending-Choice Model

The current prompt-heavy flows must move to a structured pending-choice model.

Examples:

- difficulty selection
- discipline selection
- Weaponmastery weapon choice
- startup gear choice
- make-room prompts
- loot selection
- safekeeping choices
- section menu choices
- combat action selection
- load/save target selection

Instead of reading directly from the console, these flows should expose:

- prompt type
- title / instruction text
- current context
- valid choices
- validation rules
- optional default or recommended choice

This is the key technical pivot that makes a real web GUI possible.

## Proposed Phases

### Phase 0 - Parity Inventory

Goal:

- define exactly what must survive the migration

Deliverables:

- formal feature inventory of the current app
- list of player-facing surfaces and flows
- list of supported automation hooks that must remain behaviorally stable
- list of Windows-specific runtime assumptions to remove
- parity checklist with pass/fail criteria

Exit criteria:

- no major feature or rule surface remains undefined
- parity checklist is agreed before adapter/server work begins

### Phase 1 - Engine Boundary Extraction

Goal:

- make the engine callable without depending on terminal rendering

Deliverables:

- structured engine session abstraction
- normalized state snapshot format
- structured action entry points
- message/result contract for state-changing operations
- clear separation between mutation logic and screen rendering

Exit criteria:

- major state changes can be driven without scraping terminal output

### Phase 2 - Prompt And Workflow Conversion

Goal:

- replace direct console prompts with structured pending-choice flows

Deliverables:

- pending-choice contracts for setup, inventory, combat, saves, and
  transitions
- adapter-safe validation rules for each prompt class
- fallback CLI path that can still render and answer the same structured flows

Exit criteria:

- no critical gameplay path still requires direct console-only input handling

### Phase 3 - Local Web Backend

Goal:

- introduce a real local HTTP/JSON API in front of the engine

Deliverables:

- local API server
- session lifecycle management
- endpoints for state reads and actions
- static hosting for the frontend
- browser launch flow that no longer depends on PTY terminal bridging

Recommended baseline endpoints:

- `GET /api/state`
- `POST /api/action`
- `GET /api/saves`
- `POST /api/save`
- `POST /api/load`
- `POST /api/new-game`

Exit criteria:

- browser clients can drive the app through the API without terminal streaming

### Phase 4 - Browser GUI

Goal:

- make the browser UI a complete play surface

Deliverables:

- split-pane or equivalent reader-plus-assistant layout
- views for sheet, inventory, combat, notes, saves, achievements, campaign,
  and book-complete recap
- rendering for pending choices and validation feedback
- stable browser-side navigation between views

Exit criteria:

- a player can complete supported books in web mode without falling back to the
  terminal

### Phase 5 - Parity Harness

Goal:

- prove that the new architecture did not lose behavior

Deliverables:

- API-level parity tests
- UI workflow tests for major play surfaces
- comparison passes between CLI and API outcomes where useful
- explicit coverage for books, combat, saves, transitions, and achievements

Exit criteria:

- the supported books and gameplay surfaces match the parity checklist

### Phase 6 - Cross-Platform Hardening

Goal:

- make the web-first app runnable on Windows, Linux, and macOS

Deliverables:

- PowerShell `7` runtime standardization
- removal or replacement of Windows-only launcher assumptions
- cross-platform launch scripts
- cross-platform packaging and startup validation

Exit criteria:

- the local web app starts and runs on all target platforms

### Phase 7 - Web-First Release Transition

Goal:

- make the browser UI the project's primary user path

Deliverables:

- updated docs and launch instructions
- CLI retained as fallback until a stable parity release has shipped
- release-validation workflow updated for the web-first app

Exit criteria:

- the documented primary experience is the web UI
- parity validation has passed for the supported surface

## Validation Requirements

This migration is not complete unless these categories remain green:

- parser/load checks
- save/load/autosave
- character setup
- book transitions
- inventory and carry-over flows
- combat flows and combat hook behavior
- section automation flows
- achievements and hidden/story triggers
- difficulty and permadeath behavior
- campaign review and book-complete recap flows

Existing PowerShell validation harnesses should be preserved and extended rather
than discarded.

## Compatibility Strategy

The portability target is:

- Windows
- Linux
- macOS

The compatibility baseline should become:

- PowerShell `7`
- local browser
- local HTTP/JSON server

The migration should explicitly replace or retire:

- Windows-only launcher assumptions
- terminal-PTY browser hosting as the main UI path
- Windows PowerShell `5.1` as a long-term requirement for the web-first app

Windows PowerShell `5.1` may remain temporarily relevant during the transition,
but it should not define the end-state runtime.

## Risk Areas

Highest migration risk:

- prompt-heavy flows that are still tightly bound to console assumptions
- save compatibility during engine-boundary changes
- silent drift between CLI behavior and web behavior
- cross-platform path/process differences
- mixing UI redesign work with deep gameplay logic changes

## Recommended Order Of Work

1. Phase `0` parity inventory
2. Phase `1` engine boundary extraction
3. Phase `2` prompt/workflow conversion
4. Phase `3` local web backend
5. Phase `4` browser GUI
6. Phase `5` parity validation
7. Phase `6` cross-platform hardening
8. Phase `7` web-first release transition

This order is important. Building the frontend too early would leave the project
trapped behind terminal-centric workflows.

## Approval Decisions To Lock Before Implementation

Before migration work begins in earnest, these decisions should be treated as
explicitly approved:

1. keep the rules engine in PowerShell during the first migration stages
2. make a real HTTP/JSON boundary the official architecture target
3. keep the CLI during the parity period
4. target PowerShell `7` as the long-term engine runtime
5. treat cross-platform compatibility as a first-class goal, not a later extra

## Acceptance Criteria

This migration plan is complete when:

- the browser UI is the documented primary interface
- the engine remains the single source of truth for game behavior
- supported Lone Wolf features behave the same in web mode as they did in CLI
  mode
- the parity checklist passes
- the app runs through the supported surface on Windows, Linux, and macOS
- the CLI remains available until the parity release is stable

## Relationship To Future Work

This plan does not rule out a later full engine port to Python or another
runtime.

What it does say is:

- parity should be won first
- the UI/runtime boundary should be cleaned up first
- the project should only revisit a deeper language port after the engine is
  already decoupled from the terminal

That sequence lowers risk and gives the project a cleaner future decision point.
