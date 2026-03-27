# Project Handoff

This file is the durable handoff for the Lone Wolf Action Assistant. It is meant to let a new chat recover the project's current state, understand how work is done here, and continue without relying on prior conversation history.

## Current Project State

- App version: `0.7.37`
- Main script: `lonewolf.ps1`
- Latest shipped commit at time of writing: keep this synced with the newest pushed release; if unsure, check `git log -1`
- Repo workflow: commit and push completed Lone Wolf changes by default unless explicitly told not to
- Public docs hygiene:
  - sanitize `README.md` before push
  - avoid personal save names, local machine notes, and private playthrough details in public docs

## What Exists Today

- Screen-based PowerShell UI with ASCII banners
- New game and new run support
- Save/load/autosave
- Notes, inventory, gold, meals, potions, healing
- Combat helper with manual/data CRT modes
- Stats, campaign review, history, combat log
- Achievement system with hidden/story/challenge coverage
- Locked run modes:
  - `Story`
  - `Easy`
  - `Normal`
  - `Hard`
  - `Veteran`
  - optional `Permadeath`
- Tamper-evident run integrity
- Book-aware rule support across Books 1-5
- Project Aon baseline catch-up complete across Books 1-5 as of 2026-03-27
- The Kai ruleset campaign is now complete through Book 5
- GitHub repo, wiki, and issue tracker workflow already in use
- Formal architecture planning docs now exist for the modular-engine refactor milestone
- Local-only M1 modular refactor work is currently in progress and intentionally unpushed as of 2026-03-27

## Main Repo Files

- `lonewolf.ps1`
  Main application
- `README.md`
  Public-facing project overview and command surface
- `docs/GITHUB_WORKFLOW.md`
  Git/GitHub workflow and README sanitization rules
- `docs/MODULAR_ENGINE_REFACTOR_PLAN.md`
  Formal architecture plan for splitting the monolith into an engine plus book/ruleset modules
- `docs/PROJECT_MILESTONES.md`
  Repo-tracked milestone list, including the modular-engine refactor
- `data/kai-disciplines.json`
  Discipline definitions
- `data/weaponskill-map.json`
  Weaponskill roll mapping
- `data/crt.json`
  Data CRT used by `DataFile` mode

## Local-Only Working Material

These are intentionally local and should normally stay out of git:

- `saves/`
- `testing/`
- `data/last-save.txt`
- `data/error.log`
- ad-hoc temp files under `testing/tmp/`

The working pattern has been:

- keep reports and playtest artifacts in `testing/logs/`
- keep sandbox saves in `testing/saves/`
- commit code/docs changes, not live player state

## Current Book Status

### Book 1

- Route families audited
- Endings counted
- Missing rules/items reviewed
- First Book 1 route/discovery achievement batch implemented
- New automation added for:
  - start package
  - Laumspur Herb
  - Vordak Gem handling
  - Burrowcrawler torch/darkness setup
  - Crystal Star Pendant tracking
- Remaining Project Aon baseline rule gaps from the earlier audit were closed on 2026-03-27

Local reports:

- `testing/logs/BOOK1_ENDINGS_AND_ROUTE_FAMILIES.md`
- `testing/logs/BOOK1_RULES_AND_ITEMS_AUDIT.md`
- `testing/logs/BOOK1_ACHIEVEMENT_CANDIDATES.md`

### Book 2

- Full audit completed
- Route/story achievement batch implemented
- Sommerswerd is implemented and gated to Book 2+
- Broadsword +1 is implemented
- Book 2 startup, pass items, forged papers, Magic Spear hooks, storm loss, and Wildlands Hunting restriction are implemented
- Remaining Project Aon baseline rule gaps from the earlier audit were closed on 2026-03-27

### Book 3

- Heavily playtested
- Route families and endings analyzed
- Multiple readtest/full-run reports exist
- Many Book 3-specific rules and achievements are implemented
- Item/rule support includes Bone Sword, knockout fights, Mindforce, Book 3 Hunting restriction, ornate key logic, and endgame/path achievements
- Remaining Project Aon baseline rule gaps from the earlier audit were closed on 2026-03-27

Local reports:

- `testing/logs/BOOK3_READTEST_REPORT.md`
- `testing/logs/BOOK3_FULL_RUN_LOG.md`
- `testing/logs/BOOK3_ENDINGS_AND_ROUTE_FAMILIES.md`
- `testing/logs/BOOK3_RUN_MATRIX.json`

### Book 4

- Full audit completed
- First full Book 4 build implemented
- High-priority section-by-section rules pass implemented
- Startup package, Backpack-loss state, mine lighting hooks, Book 4 Hunting restrictions, Barraka combat hooks, and the first Book 4 route/story achievement batch are implemented
- Additional Book 4 support now includes:
  - corrected Holy Water and Whip item typing
  - section loot tables for common one-off pickups
  - section damage/recovery hooks
  - special combat rules like delayed evade, variable Mindforce loss, and underwater oxygen loss
  - contextual `roll` output for Book 4 random-number sections
- Remaining Project Aon baseline rule gaps from the earlier audit were closed on 2026-03-27

Local reports:

- `testing/logs/BOOK4_ENDINGS_AND_ROUTE_FAMILIES.md`
- `testing/logs/BOOK4_RULES_AND_ITEMS_AUDIT.md`
- `testing/logs/BOOK4_ACHIEVEMENT_CANDIDATES.md`
- `testing/logs/BOOK4_BUILD_VALIDATION.md`
- `testing/logs/BOOK4_FULL_RULE_GAP_REPORT.md`

### Book 5

- Full audit completed
- Book 5 startup/carry-forward logic implemented
- confiscation/recovery, blood poisoning, Limbdeath, and Book 5 endgame handling are implemented
- Book 5 route/story achievement batch implemented
- Remaining Project Aon baseline rule gaps from the Book 5 audit were closed on 2026-03-27

Local reports:

- `testing/logs/BOOK5_ENDINGS_AND_ROUTE_FAMILIES.md`
- `testing/logs/BOOK5_RULES_AND_ITEMS_AUDIT.md`
- `testing/logs/BOOK5_ACHIEVEMENT_CANDIDATES.md`
- `testing/logs/BOOK5_FULL_RULE_GAP_REPORT.md`
- `testing/logs/BOOK5_BUILD_VALIDATION.md`

## Existing Playtest Coverage

Local reports already exist for:

- command surface playtest
- run-mode rules playtest
- permadeath playtest
- Book 3 sandbox and route sweeps
- Book 5 targeted validation and Books 1-5 campaign smoke

Key files:

- `testing/logs/COMMAND_SURFACE_PLAYTEST_REPORT.md`
- `testing/logs/MODE_RULES_PLAYTEST_REPORT.md`
- `testing/logs/PERMADEATH_PLAYTEST_REPORT.md`
- `testing/logs/FULL_VALIDATION_SUMMARY_20260327.md`
- `testing/logs/BOOK5_BUILD_VALIDATION.md`
- `testing/logs/M1_LOCAL_CAMPAIGN_VALIDATION_20260327.md`

Latest large-scale validation:

- `100` full synthetic campaign runs spanning Books 1-4 in order
- `80` runs in PowerShell 7
- `20` runs in Windows PowerShell 5.1
- command-surface smoke passed in both shells
- no campaign failures in the March 27 full validation sweep
- additional targeted Books 1-5 campaign smoke and Book 5 validation passed in both shells

Local unpushed M1 checkpoint:

- first core-module extraction completed locally
- `60` full Books `1-5` sandbox campaigns passed on the local M1 build
- `0` campaign failures
- see `testing/logs/M1_LOCAL_CAMPAIGN_VALIDATION_20260327.md`

## Standard Named Workflows

### Full Book Audit

Use this when the goal is to read a book, map its routes, find missing rules/items, and plan achievements.

Standard user phrasing:

- `Run the Full Book Audit for Book 2`

Meaning:

- read Project Aon book text and errata
- map endings and major winning route families
- audit missing item/rule support
- draft achievement candidates
- write local reports in `testing/logs/`
- summarize findings in chat

### Full Book Audit + Build

Use this when the audit should be followed by implementation of the approved findings.

Standard user phrasing:

- `Run the Full Book Audit + Build for Book 2`

Meaning:

- do the full audit
- propose the top rules/items/achievements
- implement approved findings
- validate in Windows PowerShell and PowerShell 7
- update public docs if needed
- commit and push

### Playtest Pass

Use this when the goal is to exercise the app itself rather than audit book text.

Examples:

- `Run a command-surface playtest`
- `Run a mode rules playtest`
- `Run a permadeath playtest`
- `Do a Book 3 sandbox run`

## Bug Workflow

For real defects:

1. Reproduce on a sandbox save when possible
2. If it is a real bug, open a GitHub issue
3. Fix the bug
4. Validate in both:
   - Windows PowerShell 5.1
   - PowerShell 7
5. Commit and push
6. Close the issue with the fix reference

Crash logging exists via `data/error.log`, but the preferred workflow is still to reproduce and validate the exact command path.

## Resume Checklist For A New Chat

1. Read this file
2. Read `docs/BOOK_AUDIT_WORKFLOW.md`
3. Read `docs/PLAYTEST_AND_BUG_WORKFLOW.md`
4. Check `git status`
5. Check the newest local reports in `testing/logs/`
6. Confirm whether the next task is:
   - content audit
   - implementation
   - playtesting
   - bug fix
7. If a public doc changed, remember the README sanitization rules before push

## Good Next Steps

- Continue live playtesting across Books 1-5 and patch DE-specific rule differences
- Continue `M1` Modular Engine Refactor and validate each extraction step locally before push
- Expand story-aware achievements in later books
- Run the Full Book Audit for the next unsupported book after the refactor plan is in motion
- Keep the handoff docs in sync as new books become implemented

## Important Cautions

- Never use the player's live save for sandbox testing
- Prefer cloned sandbox saves such as `readtest` for experimentation
- Do not publish live saves, personal notes, or private playthrough state
- Keep copyrighted book text out of committed docs
- When in doubt, log findings locally first and only ship the confirmed code/docs changes
