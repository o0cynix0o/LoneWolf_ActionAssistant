# Playtest And Bug Workflow

This file describes how to test the app safely and how bugs should be handled when found.

## Core Rule

Never use the player's live save for destructive or exploratory testing.

Use:

- a cloned sandbox save
- or a brand-new throwaway save

Keep the player's real run untouched unless the user explicitly asks for a save repair.

## Common Sandbox Patterns

- clone the live save to a sandbox such as `readtest`
- create throwaway mode-specific saves
- keep all playtest artifacts local in `testing/logs/`

For live terminal debugging, prefer transcript capture when output scrolls too fast to read:

```powershell
Start-Transcript -Path '.\testing\logs\live-terminal.txt' -Force
```

Reproduce the issue, then stop capture:

```powershell
Stop-Transcript
```

Then inspect:

- `testing/logs/live-terminal.txt`

## Standard Playtest Passes

### Command-Surface Playtest

Purpose:

- exercise the broad command set on a fresh or sandbox save

Typical outputs:

- `COMMAND_SURFACE_PLAYTEST_REPORT.md`
- `COMMAND_SURFACE_PLAYTEST_RESULTS.json`
- transcript file

### Mode Rules Playtest

Purpose:

- verify Story, Easy, Hard, Veteran, and achievement gating behavior

Typical outputs:

- `MODE_RULES_PLAYTEST_REPORT.md`
- `MODE_RULES_PLAYTEST_RESULTS.json`

### Permadeath Playtest

Purpose:

- verify save deletion, rewind blocking, and post-death behavior

Typical outputs:

- `PERMADEATH_PLAYTEST_REPORT.md`
- `PERMADEATH_PLAYTEST_RESULTS.json`
- transcript file

### Book Sandbox Run

Purpose:

- run one book through the app using a sandbox save
- look for missing rules, item handling gaps, and achievement triggers

Typical outputs:

- book-specific run log
- route matrix JSON when multiple routes are tested
- transcript file

## Bug Handling Workflow

### 1. Reproduce

Try to reproduce the bug on a sandbox save or isolated harness.

Capture:

- the command used
- the state leading into the bug
- the expected behavior
- the actual behavior

### 2. Decide Whether It Is A Real Defect

Good candidates for GitHub issues:

- crash
- false achievement behavior
- wrong item/rule handling
- wrong save/integrity behavior
- broken command flow

Do not open issues for every design idea or content request. Reserve issues for real defects unless the user wants feature tracking.

### 3. Open A GitHub Issue

When a real bug is confirmed:

- open an issue
- prefer the matching GitHub issue form
- fix the bug
- validate it
- close the issue with the fix reference

This repo already uses the issue tracker as the historical bug ledger.

Recommended labels after confirmation:

- one book label such as `book-2` or `cross-book`
- one or two area labels such as `inventory`, `combat`, `rules`, `ui-ux`
- an optional priority label when it helps triage

### All-Book Tracking Baseline

From this point forward, confirmed defects should be tracked consistently across all books and cross-book work.

When a real defect is confirmed:

- open one GitHub issue per confirmed defect before closing the work
- use the matching issue form instead of a blank issue whenever possible
- add the most specific book label possible such as `book-3`, `book-6`, or `cross-book`
- add `magnakai` when the finding is ruleset-specific
- add one or two area labels such as `rules`, `combat`, `inventory`, `automation`, `ui-ux`, or `command-surface`
- add `de-diff` when the trigger came from a Definitive Edition difference
- validate the fix in both shells when practical
- close the issue with the fixing commit or validation reference

Do not batch multiple unrelated defects into one catch-all bug just to save tracker space.

## Validation Expectations

Unless blocked, validate changes in:

- Windows PowerShell 5.1
- PowerShell 7

For high-risk behavior, prefer a small focused harness over a vague manual spot-check.

## Crash Logging

Unexpected exceptions should end up in:

- `data/error.log`

That log is local-only and should not be committed.

Crash logging is useful, but it is not a substitute for reproducing the exact path that failed.

## Save Integrity Notes

The app uses tamper-evident run integrity. When testing:

- avoid mutating the player's live save
- prefer disposable saves for experiments
- if a live save ever needs repair, back it up first and then re-sign it cleanly

## Report Writing Pattern

A useful playtest report usually includes:

- scope of the pass
- save used
- what was tested
- what worked
- what failed
- what remains manual
- concrete next fixes

Keep the report local in `logs/` unless there is a specific reason to publish it.

## When To Stop And Ask

Pause and ask before making silent fixes when:

- the rule text is ambiguous
- the change has non-obvious gameplay consequences
- the fix would rewrite live save state instead of code
- the user asked for reports first and fixes second

## Good Standard Requests

- `Run a command-surface playtest`
- `Run a mode rules playtest`
- `Run a permadeath playtest`
- `Do a Book 3 sandbox run`
- `Do a multi-route Book 3 sweep`

These are good because they define the type of testing clearly and keep the work repeatable.
