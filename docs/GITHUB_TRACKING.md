# GitHub Tracking

This file describes how GitHub should be used for the Lone Wolf Action Assistant beyond normal code pushes.

## Repo Current Means All Of It

When the user says to keep the repo current, that means:

- code
- `README.md`
- wiki
- strategy guides and other player-facing wiki surface
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
- `M5 - Post-Release Stabilization And Book 7+ Planning`

Sub-milestones stay in the repo docs rather than being mirrored 1:1 into GitHub milestones.

### Labels

The repo now uses a lightweight label taxonomy so issues stay filterable by book and work type.

Book labels:

- `book-1`
- `book-2`
- `book-3`
- `book-4`
- `book-5`
- `book-6`
- `book-7`
- `cross-book`
- `magnakai`

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

### Issue Tracking Baseline

Confirmed defects should be tracked consistently across all books and cross-book work.

Baseline rule:

- one confirmed defect = one GitHub issue

Expected labels:

- one specific book label such as `book-1` through `book-7`, or `cross-book`
- `magnakai` when ruleset-specific
- one or two area labels such as `rules`, `combat`, `inventory`, `automation`, `ui-ux`, or `command-surface`
- `de-diff` when the report came from a Definitive Edition difference

Expected closeout:

- fix committed
- validation noted
- issue closed after the fix lands

Current umbrella tracker:

- GitHub issue `#19` `Book 6 playtest stabilization tracker`

Use that tracker for the active Book `6` stream, but keep the same one-defect-per-issue standard everywhere else too.

### Wiki

The wiki is part of the repo’s maintained public surface.

When player-facing strategy or feature behavior changes meaningfully, review the wiki as part of the update sweep.

For book work, the wiki sweep should explicitly include strategy-guide state.

Do not treat a book as fully current if:

- the code and validation are updated
- but the strategy guide, guide index, or related public scope pages still describe the old state

At minimum, review:

- the book-specific strategy guide page
- `Strategy-Guide`
- any scope/support/achievement pages whose public claims changed

If the cloned wiki repo changed locally, commit and push that repo too so the public guide state actually lands.

## Project Board

The repo now has a GitHub Project board for day-to-day issue flow:

- `Lone Wolf Tracker`
- `https://github.com/users/o0cynix0o/projects/1`

Current custom fields:

- `Status`
- `Book`
- `Area`
- `Type`
- `Priority`
- `DE Diff`

The default GitHub project fields remain useful too:

- `Title`
- `Assignees`
- `Labels`
- `Milestone`
- `Repository`

Recommended usage:

- use milestones for top-level roadmap
- use the project board for day-to-day triage and routing
- keep book/area/type/priority consistent with the GitHub labels
