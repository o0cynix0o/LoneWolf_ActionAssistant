# Project Handoff

This file is the durable handoff for the Lone Wolf Action Assistant. It is meant to let a new chat recover the project's current state, understand how work is done here, and continue without relying on prior conversation history.

## Current Project State

- App version: `0.8.0`
- Main script: `lonewolf.ps1`
- Latest public release on `main`: `v0.8.0`
- `main` remains the public release branch
- `dev` is active again as the integration branch for post-release architecture hardening
- M5 post-release stabilization and architecture hardening are now in progress on `dev`
- Repo workflow: commit and push completed Lone Wolf changes by default unless explicitly told not to
- Confirmed defects should be tracked in GitHub as they are found, not cleaned up later in a batch
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
- Book-aware rule support across Books 1-6
- Transition-only Special Item safekeeping beginning at the Book `4` -> `5` handoff and continuing on later book-to-book transitions
- Project Aon baseline catch-up complete across Books 1-5, plus released Book 6 / Magnakai support
- The Kai ruleset campaign is complete through Book 5, and the first Magnakai transition book is now part of the public build
- GitHub repo, wiki, and issue tracker workflow already in use
- GitHub labels, issue forms, and milestones are now live
- GitHub Project board is now live
- Formal architecture planning docs now exist for the modular-engine refactor milestone
- M1 modular refactor is complete and pushed
- M2 Magnakai / Book `6` support is complete and released
- M2.7 validation closeout is complete under the route-and-mode validation bar
- M3 UX polish is complete and released
- M4 portable packaging workflow is complete and released
- M5 Book `6` automation catch-up is complete on `main`
- current `dev` work is architecture hardening and dead-code cleanup after the `0.8.0` release
- latest `dev` lag pass fixed two post-extraction regressions:
  - achievement-screen caching was being reset by host-context rebinding
  - `combat status` from `inv` could throw a module-context error and write to `data/error.log`
- the follow-up lag-hardening pass from `recommendations.md` is now in on `dev`:
  - generation-based context caching now short-circuits repeated rebinding across host/core/ruleset modules
  - current-format saves can fast-path load normalization instead of always paying the full repair path
  - shell render output now batches more status and combat lines through the shared display writer
  - same-screen refreshes now use a lighter clear path
- prerelease Batch `1-4` full-sweep validation is now green on `dev` in both shells
- load-path performance work on `dev` now targets campaign-save startup directly instead of screen rendering
- current `main` hotfix: `roll` no longer crashes under strict mode when command/ruleset modules are invoked before a local `GameState` variable has been materialized
- current `main` follow-up hardening: core and ruleset/book modules now pre-materialize `GameState`, `GameData`, and `LWUi` at script scope so strict-mode evaluation cannot trip over unbound host-state variables before context rebinding
- current `main` automation smoke harness:
  - `testing/tmp/random-automation-smoke.ps1`
- current `main` random-automation validation artifacts:
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS7.txt`
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS51.txt`
- current `main` broader automation smoke harness:
  - `testing/tmp/automation-surface-smoke.ps1`
- current `main` broader automation validation artifacts:
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS7.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS51.txt`
- current `main` Books `1-5` automation catch-up pass:
  - added new Kai book-module automation definitions for deterministic section-entry effects, simple combat rules, and missing random-number context coverage
  - widened both automation smoke harnesses so Book `5` coverage now extends through section `400`
  - fixed a widened-smoke follow-up bug at Book `5`, section `393` where a stale `Test-LWStateHasMindshield` reference remained after the refactor
  - recorded scope and remaining backlog in:
    - `testing/logs/BOOKS1TO5_AUTOMATION_IMPLEMENTATION_20260415.md`
- current `main` follow-up hotfix after the broader smoke pass:
  - Book `3`, section `18` no longer fails forced weapon-loss automation because `Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem` now rebinds ruleset module context before reading state
- current measured load behavior on a copied current-format campaign save:
  - cold `pwsh` `-Load`: about `316ms` load / `1.50s` total
  - cold Windows PowerShell `5.1` `-Load`: about `412ms` load / `1.68s` total
- current measured first-open hot screens on the same copied save:
  - `sheet`: about `30ms` in `pwsh`, `27ms` in Windows PowerShell `5.1`
  - `combat status`: about `9ms` in `pwsh`, `15ms` in Windows PowerShell `5.1`
  - `achievements` command timing is now sub-`1ms` in the screen-sweep harness, but the full overview block still costs more real render time than lighter screens
- latest lag validation artifacts:
  - `testing/logs/LAG_HARDENING_VALIDATION_PS7.txt`
  - `testing/logs/LAG_HARDENING_VALIDATION_PS51.txt`
  - `testing/logs/LAG_HARDENING_REPORT_20260414.md`
- refreshed post-fix screen baselines after the generation-cache/render-path work:
  - `testing/logs/SCREEN_LAG_VALIDATION_POSTFIX_PS7.txt`
  - `testing/logs/SCREEN_LAG_VALIDATION_POSTFIX_PS51.txt`
  - `testing/logs/SCREEN_LAG_BASELINE_COMPARISON_20260414.md`
- the Books `1-3` prerelease harness was rerun after the lag/context changes and now passes `29/29` in both shells
- shell notifications now retain the last `12` entries instead of `8` so critical combat/setup notices are not displaced by later unlock/result messages
- approved M3 visual direction:
  - `Arcade / GameFAQs Retro`
- shared M3 style rules are now tracked in:
  - `docs/M3_UI_STYLE_GUIDE.md`
- M3 retro screen refresh is now live across the app on `main`:
  - welcome
  - load
  - help
  - modes
  - main character sheet
  - inventory
  - disciplines
  - stats
  - campaign
  - achievements
  - notes
  - history
  - combat
  - combat log
  - death
  - book complete
- screen-specific `Helpful Commands` panels now appear across the main screen families on `main`
- `modules/core/shell.psm1` now owns runtime maintenance, notifications, banners, and several screen renderers
- ruleset combat hook modules now exist in:
  - `modules/rulesets/kai/combat.psm1`
  - `modules/rulesets/magnakai/combat.psm1`
- startup now rotates oversized `data/error.log` files and keeps only the latest archive set
- stale duplicate legacy wrappers and book-specific copies were removed from `lonewolf.ps1` after their module-backed replacements went live
- Book `1-5` starting-equipment helper definitions now live in their respective Kai book modules
- Book `1-6` section-context achievement ID lists now live in their respective book modules and dispatch through `modules/core/ruleset.psm1`
- generic loot-choice and book-transition safekeeping prompts now live in `modules/core/shell.psm1`
- Book `4` section `12` choice handling now lives in `modules/rulesets/kai/book4.psm1`
- Book `6` riverboat-ticket item names now live in `modules/rulesets/magnakai/book6.psm1`
- `Book of the Magnakai` item-name helper now lives in `modules/rulesets/magnakai/magnakai.psm1`
- latest architecture extraction slice on `dev` moved the largest remaining monolith blocks into:
  - `modules/core/achievements.psm1`
  - `modules/core/items.psm1`
  - `modules/core/inventory.psm1`
- the final cleanup pass from `recommendations.md` also moved the remaining late-stage helpers into:
  - `modules/core/combat.psm1`
  - `modules/core/healing.psm1`
  - `modules/core/ruleset.psm1`
  - `modules/core/shell.psm1`
  - `modules/core/common.psm1`
  - `modules/core/state.psm1`
- the remaining shared extraction pass also pushed more ownership into:
  - `modules/core/combat.psm1`
  - `modules/core/state.psm1`
  - `modules/core/save.psm1`
  - `modules/core/shell.psm1`
  - `modules/core/common.psm1`
  - `modules/core/ruleset.psm1`
  - `modules/rulesets/kai/kai.psm1`
  - `modules/rulesets/magnakai/magnakai.psm1`
- current approximate file sizes after the extraction pass:
  - `lonewolf.ps1`: `1226`
  - `modules/core/achievements.psm1`: `1800`
  - `modules/core/items.psm1`: `994`
  - `modules/core/inventory.psm1`: `1671`
  - `modules/core/combat.psm1`: `3104`
  - `modules/core/healing.psm1`: `361`
  - `modules/core/shell.psm1`: `3554`
  - `modules/core/state.psm1`: `1967`
  - `modules/core/save.psm1`: `295`
- latest `dev` architecture-hardening smoke passed in both shells:
  - `testing/logs/DEV_MODULE_CLEANUP_SMOKE_PS7.txt`
  - `testing/logs/DEV_MODULE_CLEANUP_SMOKE_PS51.txt`
- latest post-extraction command-surface smoke passed in both shells:
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS51.txt`
- prerelease full-sweep artifacts now include:
  - `testing/logs/BOOKS_1_3_PRERELEASE_NORMAL_PS7.txt`
  - `testing/logs/BOOKS_1_3_PRERELEASE_NORMAL_PS51.txt`
  - `testing/logs/BATCH4_NEWRUN_SWEEP_PS7.txt`
  - `testing/logs/BATCH4_NEWRUN_SWEEP_PS51.txt`
- latest lag-hardening regressions fixed on `dev`:
  - `#41` late-bound host command caches could permanently remember missing functions and break later load/performance paths
  - `#42` backpack layout rendering could crash on one-item collections under strict mode
- latest final-pass command-surface smoke also passed in both shells:
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT3_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT3_PS51.txt`
- latest prerelease Batch `1` foundation checks also passed in both shells:
  - `testing/logs/PRERELEASE_PACKAGE_VALIDATION.txt`
  - `testing/logs/COMMAND_SURFACE_PRERELEASE_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PRERELEASE_PS51.txt`
  - `testing/logs/SAVE_SYSTEM_PRERELEASE_PS7.txt`
  - `testing/logs/SAVE_SYSTEM_PRERELEASE_PS51.txt`
- Batch `1` prerelease defects fixed on `dev` include:
  - quiver-aware `Arrow` add routing from the command surface
  - packaged/runtime module-context recovery for `GameData` under strict mode
  - empty save-catalog rendering on the `load` screen
- M3 validation passed in both shells:
  - `testing/logs/M3_SCREEN_RENDER_PW7.txt`
  - `testing/logs/M3_SCREEN_RENDER_PS51.txt`
- latest Book `6` stabilization validation passed in both shells:
  - `testing/logs/BOOK6_INSTANT_DEATH_MATRIX_PS7_AUTOFIX_RERUN.md`
  - `testing/logs/BOOK6_INSTANT_DEATH_MATRIX_PS51_AUTOFIX_RERUN.md`
  - `testing/logs/BOOK6_SAMPLE_ROUTE_MATRIX_PS7_AUTOFIX_RERUN2.md`
  - `testing/logs/BOOK6_SAMPLE_ROUTE_MATRIX_PS51_AUTOFIX_RERUN2.md`
  - `testing/logs/BOOK6_SECTION155_COMBAT_PS7.txt`
  - `testing/logs/BOOK6_SECTION155_COMBAT_PS51.txt`
  - `testing/logs/BOOK6_TARGETED_REGRESSION_PS7.txt`
  - `testing/logs/BOOK6_TARGETED_REGRESSION_PS51.txt`

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
- `docs/DISTRIBUTION_PACKAGING_PLAN.md`
  Portable-release packaging plan and workflow
- `build-release.ps1`
  Local portable release builder that assembles a clean distributable package under `testing/releases/`
- `validate-release.ps1`
  Local portable package validator that rebuilds, extracts, and smoke-tests a disposable package copy in both shells
- `modules/core/`
  Core-engine modules, including state/save/command/combat/ruleset slices
- `modules/core/shell.psm1`
  Runtime maintenance, notifications, banner helpers, and extracted screen renderers
- `modules/rulesets/kai/`
  Kai ruleset shell plus Book `1-5` modules
- `modules/rulesets/magnakai/`
  Magnakai ruleset shell plus Book `6`
- `data/kai-disciplines.json`
  Discipline definitions
- `data/magnakai-disciplines.json`
  Magnakai discipline definitions
- `data/magnakai-ranks.json`
  Magnakai rank titles
- `data/magnakai-lore-circles.json`
  Lore-circle groupings and bonus metadata
- `data/weaponskill-map.json`
  Weaponskill roll mapping
- `data/crt.json`
  Data CRT used by `DataFile` mode
- `docs/BOOK_SOURCE_MAP.md`
  Local source-corpus map for audits and future book work
- `docs/GITHUB_TRACKING.md`
  GitHub labels, milestones, issue forms, and project-board notes
- `docs/MAGNAKAI_BOOK6_PLAN.md`
  Magnakai ruleset transition design and implementation notes for Book `6`
- `docs/M3_UI_STYLE_GUIDE.md`
  Shared UI rules for the M3 screen refresh

## Local-Only Working Material

These are intentionally local and should normally stay out of git:

- `saves/`
- `testing/`
- `books/`
- `data/last-save.txt`
- `data/error.log`
  Local runtime error log; oversized logs are rotated automatically at startup
- ad-hoc temp files under `testing/tmp/`

The working pattern has been:

- keep reports and playtest artifacts in `testing/logs/`
- keep sandbox saves in `testing/saves/`
- keep local release bundles in `testing/releases/`
- keep local book corpus files in `books/`
- commit code/docs changes, not live player state

## Local Book Corpus

The preferred audit source is now the local book corpus:

- `books/lw/`

This local corpus includes Lone Wolf book folders from:

- `01fftd`
- through
- `29tsoc`

and also:

- `dotd`

The audit workflow should now use:

1. local corpus first
2. Project Aon plus errata as fallback or cross-check
3. Definitive Edition playtesting as the correction layer when differences are confirmed

See:

- `docs/BOOK_SOURCE_MAP.md`

## Live Terminal Capture

When a user sees a fast-scrolling VS Code or terminal error that is hard to paste cleanly, prefer transcript capture first.

Recommended pattern:

```powershell
Start-Transcript -Path '.\testing\logs\live-terminal.txt' -Force
```

Reproduce the issue, then stop capture:

```powershell
Stop-Transcript
```

Then inspect:

- `testing/logs/live-terminal.txt`

For one-shot non-interactive startup capture, redirect all output instead:

```powershell
.\lonewolf.ps1 -Load '.\saves\sample-save.json' *> '.\testing\logs\live-run.txt'
```

## GitHub Tracking

GitHub tracking now includes:

- labels
- issue forms
- milestones
- project board
- wiki updates alongside repo updates

Project board:

- `Lone Wolf Tracker`
- `https://github.com/users/o0cynix0o/projects/1`

Field design and tracking notes are documented in:

- `docs/GITHUB_TRACKING.md`

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

### Book 6

- Implemented on `main`
- Book `6` is the first Magnakai book and is now treated as a real ruleset transition, not just the next Kai book
- implemented support includes:
  - Magnakai ruleset shell
  - Book `5` -> `6` transition
  - ruleset-aware sheet/state changes
  - Magnakai discipline, Weaponmastery, and lore-circle support
  - Book `6` startup package and carry-forward handling
  - Book `6` section-entry rules, item hooks, combat hooks, and achievements

Current achievement additions:

- `Book Six Complete`
- `Magnakai Rising`
- `Jump the Wagons`
- `Water Bearer`
- `Tekaro Cartographer`
- `Key to Varetta`
- `Silver Oak Prize`
- `Cess to Enter`
- `Cold Comfort`
- `Mind Over Malice`

Reference:

- `docs/MAGNAKAI_BOOK6_PLAN.md`
- GitHub issue `#18` `Plan Book 6 Magnakai ruleset transition`
- GitHub issue `#19` `Book 6 playtest stabilization tracker`

Local reports:

- `testing/logs/BOOK6_BUILD_VALIDATION.md`
- `testing/logs/BOOK6_ROUTE_STRATEGY_REPORT.md`
- `testing/logs/M2_7_COMPLETION_SUMMARY_20260403.md`
- `testing/logs/M2_7_COMPLETION_SUMMARY_20260407.md`

## Existing Playtest Coverage

Local reports already exist for:

- command surface playtest
- run-mode rules playtest
- permadeath playtest
- Book 3 sandbox and route sweeps
- Book 5 targeted validation and Books 1-5 campaign smoke
- Book 6 targeted validation and Magnakai transition smoke on `main`
- fresh-character Books `1-6` full-campaign mode coverage
- synthetic sample Book `5` -> `6` route-matrix coverage
- current sample save/load/failure/permadeath smoke

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
- Book 6 targeted validation passed in both shells on `main`
- fresh-character Books `1-6` campaigns now pass in both shells on:
  - `Story`
  - `Easy`
  - `Normal`
  - `Hard`
  - `Veteran`
  - `Hard + Permadeath`
- synthetic sample Book `5` -> `6` route matrix now passes in both shells:
  - `20/20` in PowerShell `7`
  - `20/20` in Windows PowerShell `5.1`
- current live-style sample save smoke now passes in both shells:
  - manual load
  - startup `-Load`
  - command-surface smoke
  - non-permadeath failure
  - permadeath failure
- startup `-Load` under the redirected harness still does not exit cleanly on its own, but load/render succeeds, no stderr is emitted, and the harness forces cleanup after verification
- the earlier interrupted long-run PowerShell `7` validator that completed `44` full campaigns remains a useful historical note, but is no longer the main M2.7 closeout evidence

## Validation Standard

The older `100+ sandbox runs` rule is now considered historical, not the preferred future bar.

Use:

- `docs/VALIDATION_POLICY.md`

for future milestone validation planning.

Current preferred validation philosophy:

- route coverage
- difficulty coverage
- failure coverage
- permadeath coverage
- transition/save/load coverage
- command-surface smoke in both shells

This scales better than a flat raw run-count target as the app grows.

M1 refactor status:

- modular wrappers are active in the shipped build
- extracted modules include:
  - `modules/core/state.psm1`
  - `modules/core/save.psm1`
  - `modules/core/commands.psm1`
  - `modules/core/combat.psm1`
  - `modules/core/ruleset.psm1`
  - `modules/rulesets/kai/kai.psm1`
  - `modules/rulesets/kai/book1.psm1` through `book5.psm1`
- saves normalize:
  - `RuleSet`
  - `EngineVersion`
  - `RuleSetVersion`
- validation cleared the documented M1 exit bar:
  - `100` full Books `1-5` sandbox campaigns passed
  - `0` campaign failures
  - command-surface smoke passed in both shells
- reports:
  - `testing/logs/M1_7_COMPLETION_SUMMARY_20260327.md`
  - `testing/logs/FULL_VALIDATION_REPORT_M1_PWSH_40.md`
  - `testing/logs/FULL_VALIDATION_REPORT_M1_PS51_20.md`
  - `testing/logs/FULL_VALIDATION_REPORT_M1_PWSH_EXTRA20.md`
  - `testing/logs/FULL_VALIDATION_REPORT_M1_PS51_EXTRA20.md`

Local packaging prep:

- portable packaging workflow is now tracked in `docs/DISTRIBUTION_PACKAGING_PLAN.md`
- local release builder lives at `build-release.ps1`
- local release validator lives at `validate-release.ps1`
- release artifacts should stay local under `testing/releases/` until intentionally published
- local packaging validation is recorded in:
  - `testing/logs/PACKAGING_PREP_VALIDATION_20260327.md`
  - `testing/logs/PACKAGING_M4_VALIDATION_SUMMARY.md`

## Standard Named Workflows

### Full Book Audit

Use this when the goal is to read a book, map its routes, find missing rules/items, and plan achievements.

Standard user phrasing:

- `Run the Full Book Audit for Book 2`

Meaning:

- read the local book corpus first
- use Project Aon and errata only as fallback or cross-check
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

- Continue live playtesting across Books 1-6 and patch DE-specific rule differences
- Deepen Book `6` route reporting and strategy support as more play data comes in
- Plan Book `7` / the next Magnakai audit once Book `6` feels stable
- Keep the handoff docs in sync as new books become implemented

## Important Cautions

- Never use the player's live save for sandbox testing
- Prefer cloned sandbox saves such as `readtest` for experimentation
- Do not publish live saves, personal notes, or private playthrough state
- Keep copyrighted book text out of committed docs
- When in doubt, log findings locally first and only ship the confirmed code/docs changes
