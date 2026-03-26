# Project Handoff

This file is the durable handoff for the Lone Wolf Action Assistant. It is meant to let a new chat recover the project's current state, understand how work is done here, and continue without relying on prior conversation history.

## Current Project State

- App version: `0.7.19`
- Main script: `lonewolf.ps1`
- Latest shipped commit at time of writing: `3ce78bc` `Add Book 1 rule automation and route achievements`
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
- Book-aware rule support across Books 1-3
- GitHub repo, wiki, and issue tracker workflow already in use

## Main Repo Files

- `lonewolf.ps1`
  Main application
- `README.md`
  Public-facing project overview and command surface
- `docs/GITHUB_WORKFLOW.md`
  Git/GitHub workflow and README sanitization rules
- `data/kai-disciplines.json`
  Discipline definitions
- `data/weaponskill-map.json`
  Weaponskill roll mapping
- `data/crt.json`
  Data CRT used by `DataFile` mode

## Local-Only Working Material

These are intentionally local and should normally stay out of git:

- `saves/`
- `logs/`
- `data/last-save.txt`
- `data/error.log`
- `tmp-*.html`
- other `tmp-*` test folders

The working pattern has been:

- keep reports and playtest artifacts in `logs/`
- keep sandbox saves in `saves/`
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

Local reports:

- `logs/BOOK1_ENDINGS_AND_ROUTE_FAMILIES.md`
- `logs/BOOK1_RULES_AND_ITEMS_AUDIT.md`
- `logs/BOOK1_ACHIEVEMENT_CANDIDATES.md`

### Book 2

- Partial story-achievement support is implemented
- Sommerswerd is implemented and gated to Book 2+
- Broadsword +1 is implemented
- Book 2 has not yet had the same full audit pass as Book 1 and Book 3

### Book 3

- Heavily playtested
- Route families and endings analyzed
- Multiple readtest/full-run reports exist
- Many Book 3-specific rules and achievements are implemented
- Item/rule support includes Bone Sword, knockout fights, Mindforce, Book 3 Hunting restriction, ornate key logic, and endgame/path achievements

Local reports:

- `logs/BOOK3_READTEST_REPORT.md`
- `logs/BOOK3_FULL_RUN_LOG.md`
- `logs/BOOK3_ENDINGS_AND_ROUTE_FAMILIES.md`
- `logs/BOOK3_RUN_MATRIX.json`

### Book 4

- Not audited yet
- Not expanded yet
- Natural next major content target after current Book 3 playtesting stabilizes

## Existing Playtest Coverage

Local reports already exist for:

- command surface playtest
- run-mode rules playtest
- permadeath playtest
- Book 3 sandbox and route sweeps

Key files:

- `logs/COMMAND_SURFACE_PLAYTEST_REPORT.md`
- `logs/MODE_RULES_PLAYTEST_REPORT.md`
- `logs/PERMADEATH_PLAYTEST_REPORT.md`

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
- write local reports in `logs/`
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
5. Check the newest local reports in `logs/`
6. Confirm whether the next task is:
   - content audit
   - implementation
   - playtesting
   - bug fix
7. If a public doc changed, remember the README sanitization rules before push

## Good Next Steps

- Run the Full Book Audit for Book 2
- Continue Book 3 live playtesting and patch book-specific gaps
- Start Book 4 support after Book 3 feels stable
- Expand story-aware achievements book by book

## Important Cautions

- Never use the player's live save for sandbox testing
- Prefer cloned sandbox saves such as `readtest` for experimentation
- Do not publish live saves, personal notes, or private playthrough state
- Keep copyrighted book text out of committed docs
- When in doubt, log findings locally first and only ship the confirmed code/docs changes
