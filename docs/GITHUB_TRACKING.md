# GitHub Tracking

This file describes how GitHub should be used for the Lone Wolf Action Assistant beyond normal code pushes.

## Repo Current Means All Of It

When the user says to keep the repo current, that means:

- code
- `README.md`
- wiki
- labels
- issue tracker
- milestones
- handoff and workflow docs

Do not treat GitHub upkeep as code-only.

## Live GitHub Tracking Layers

### Milestones

Top-level roadmap work is tracked both in:

- `docs/PROJECT_MILESTONES.md`
- GitHub milestones

Current top-level milestone set:

- `M1 - Modular Engine Refactor`
- `M2 - Additional Rule Set Support`
- `M3 - UX Polish Pass`
- `M4 - Portable Distribution Packaging`

Sub-milestones stay in the repo docs rather than being mirrored 1:1 into GitHub milestones.

### Labels

The repo now uses a lightweight label taxonomy so issues stay filterable by book and work type.

Book labels:

- `book-1`
- `book-2`
- `book-3`
- `book-4`
- `book-5`
- `cross-book`

Work-type labels:

- `rules`
- `combat`
- `inventory`
- `ui-ux`
- `automation`
- `command-surface`
- `save-system`
- `achievements`
- `testing`
- `performance`
- `packaging`
- `refactor`
- `strategy-guide`
- `docs`
- `wiki`
- `de-diff`

Priority labels:

- `priority:high`
- `priority:medium`
- `priority:low`

### Issue Forms

GitHub issue forms now exist under:

- `.github/ISSUE_TEMPLATE/`

Current forms:

- `Bug Report`
- `DE Difference`
- `Rule Gap`
- `UX / Playtest Note`
- `Book Audit / Build Request`

Use the forms instead of freeform issues whenever practical.

### Wiki

The wiki is part of the repo’s maintained public surface.

When player-facing strategy or feature behavior changes meaningfully, review the wiki as part of the update sweep.

## Project Board

The next GitHub tracking layer should be a GitHub Project board for day-to-day issue flow.

Recommended fields:

- `Status`
- `Book`
- `Area`
- `Type`
- `Priority`
- `DE?`

As of `2026-04-02`, project creation is still blocked by token permissions.

The current token can:

- push code through git
- manage issues
- manage labels
- manage milestones

The current token cannot:

- create or mutate GitHub Projects

If project-board setup is needed, use a token with GitHub Projects write access and then create the board from this document’s field plan.
