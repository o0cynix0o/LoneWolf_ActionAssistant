# Lone Wolf Terminal - Agent Handoff

Last updated: 2026-04-13

## What This File Is For

This file is the short agent-facing summary for the repo.

It should stay lightweight and current.
For deeper project state, workflow details, and local report locations, use:

- `docs/PROJECT_HANDOFF.md`
- `docs/PLAYTEST_AND_BUG_WORKFLOW.md`
- `docs/BOOK_AUDIT_WORKFLOW.md`
- `docs/PROJECT_MILESTONES.md`

## Current Reality

- App version: `0.8.0`
- Main script: `lonewolf.ps1`
- `main` is the public release branch
- `dev` is the active integration branch for current architecture-hardening work
- Runtime target:
  - Windows PowerShell 5.1
  - PowerShell 7
- GitHub bug hygiene is part of normal work:
  - one confirmed defect should become one issue
  - use book + area labels
  - close issues when the fix lands
- Kai ruleset support is complete through Books `1-5`
- Magnakai support is live through Book `6`
- M1 modular refactor is complete and pushed
- Core modules live under:
  - `modules/core/`
- largest extracted core slices now include:
  - `modules/core/achievements.psm1`
  - `modules/core/items.psm1`
  - `modules/core/inventory.psm1`
- final late-stage extraction now also includes:
  - `modules/core/healing.psm1`
- Runtime shell extraction now lives in:
  - `modules/core/shell.psm1`
- Kai ruleset modules live under:
  - `modules/rulesets/kai/`
- Magnakai ruleset modules live under:
  - `modules/rulesets/magnakai/`
- `lonewolf.ps1` is now down to roughly `1.2k` lines after the latest extraction slice
- Book-specific combat dispatch now lives in:
  - `modules/rulesets/kai/combat.psm1`
  - `modules/rulesets/magnakai/combat.psm1`

This project is no longer a “single-script starter kit with combat overhaul next.”
That old framing is stale.

## Current Priorities

The highest-value work now is:

1. post-release stabilization across Books `1-6`
2. fixing any remaining DE-specific rule differences found during live play
3. keeping repo docs/workflow current
4. preparing Book `7+` expansion cleanly

Combat is already a shipped system.
It still gets polish and bug fixes, but it is not the defining unfinished milestone anymore.

## Repo Up-To-Date Means All Of It

When the user says to keep the repo current, that means:

- code
- `README.md`
- wiki
- project board
- issue tracker
- labels
- issue forms
- milestone docs
- handoff docs

Do not treat “repo” as code-only.

## Working Rules

- Never use the player's live save for sandbox experimentation.
- Keep testing artifacts under `testing/`.
- Keep public docs free of private save names and private playthrough details.
- Use Project Aon as the baseline source unless the user reports a DE-specific difference.
- When DE text and Project Aon differ in a meaningful rule, treat the user's DE playtest as authoritative and patch the app accordingly.

## Live Terminal Debugging

When terminal output scrolls too fast, prefer transcript capture:

```powershell
Start-Transcript -Path 'C:\Scripts\Lone Wolf\testing\logs\live-terminal.txt' -Force
```

Reproduce the issue, then stop:

```powershell
Stop-Transcript
```

Then inspect:

- `testing/logs/live-terminal.txt`

## Standard Named Workflows

### Full Book Audit

Meaning:

- read the book + errata
- map endings and major route families
- audit items, rules, and one-off automation opportunities
- write local reports in `testing/logs/`
- summarize findings in chat

### Full Book Audit + Build

Meaning:

- do the full audit
- implement approved rules/items/achievements
- validate in PowerShell 5.1 and PowerShell 7
- update repo docs as needed
- commit and push

### Playtest Pass

Meaning:

- use sandbox saves or throwaway runs
- test the app, not just the source text
- write local validation/playtest notes under `testing/logs/`
- open/fix/close issues for real defects

## Current Architecture

- `lonewolf.ps1`
  thin main entry script plus still-shared logic
- `modules/core/`
  state, save, commands, combat, bootstrap, display, ruleset helpers
- `modules/rulesets/kai/`
  Kai ruleset shell and Book `1-5` slices
- `data/`
  discipline maps, weaponskill maps, CRT data, local app state files

## Good Next Steps

- continue Books `1-6` live playtesting
- patch DE differences as they appear
- keep `PROJECT_HANDOFF.md` and milestone docs current
- expand to Book `7+` once Book `6` feels stable

## Bottom Line

This is now a real Books `1-6` assistant on `main`, with the Kai run complete and the first Magnakai ruleset handoff working.

The main job is no longer “invent the app.”
The main job is:

- maintain it cleanly
- keep the repo current
- respond quickly to playtest findings
- preserve a clean path for future ruleset expansion
