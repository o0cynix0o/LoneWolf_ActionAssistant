# Changelog

All notable public release changes for the Lone Wolf Action Assistant should be tracked here.

This file is meant to summarize shipped behavior at release time, not every internal commit.

## Unreleased

- added DE Book `6` section `297` support for the Bronin Sleeve-shield:
  - section `297` now offers the DE armor-swap flow and lets you trade one carried `Helmet`, `Shield`, or `Waistcoat`
  - added `Bronin Sleeve-shield` as a supported Special Item
  - `Bronin Sleeve-shield` now grants `+1 CS` and a `+1 END` combat buffer in physical combat when a normal `Shield` is not in use
  - it does not stack with a usable `Shield`, but it still works when shield bonuses are suppressed
  - validated locally with:
    - `testing/logs/SECTION297_DE_SLEEVESHIELD_PS7.txt`
    - `testing/logs/SECTION297_DE_SLEEVESHIELD_PS51.txt`
    - `testing/logs/SECTION297_DE_SLEEVESHIELD_COMBAT_PS7.txt`
- fixed Book `6` section `170` roll handling:
  - the interactive `roll` command now passes the live current state explicitly into the random-helper pipeline instead of relying on module-local default state
  - section `170` now matches the local OG text bonus and applies `+3` for `Weaponmastery with Bow` and `+1` for `Huntmastery`, without an extra `Silver Bow of Duadon` modifier
  - validated in both shells with:
    - `testing/logs/SECTION170_ROLL_FIX_PS7.txt`
    - `testing/logs/SECTION170_ROLL_FIX_PS51.txt`
- closed the remaining Books `1-5` automation audit gaps:
  - refreshed the local `BOOKS1TO5_AUTOMATION_AUDIT_20260415.json` output to `0` missing candidates across all five Kai books
  - Books `1-5` current coverage totals now stand at:
    - Book `1`: `78/78`
    - Book `2`: `153/153`
    - Book `3`: `127/127`
    - Book `4`: `130/130`
    - Book `5`: `152/152`
- expanded the Books `1-5` Kai automation layer in the book modules and shared Kai ruleset modules:
  - added the remaining Book `2-5` choice/payment/inventory flows needed to close the audit
  - added the last six deterministic instant-death hooks that were still open in the Books `1-5` audit
  - validated the updated choice-flow harness at `70` tests with `0` failures in both shells
- added a refreshed Book `6` automation audit script at `testing/tmp/book6_automation_refresh_audit.py`
- refreshed the Book `6` local coverage report and confirmed the high-confidence OG automation candidates are fully covered:
  - `77/77` covered
  - `0` missing
  - remaining notes are now design-review items rather than missing hooks:
    - section `24` OG/DE drift
    - section `112` Herb Pouch DE variant
    - sections `207` / `276` Bronin Warhammer slot-model choice
    - section `298` covered indirectly through the section `26` tournament combat flow
- combined local automation coverage now stands at `717/717` high-confidence candidates covered across Books `1-6`
- current automation validation artifacts:
  - `testing/logs/BOOKS1TO5_AUTOMATION_AUDIT_20260415.md`
  - `testing/logs/BOOK6_AUTOMATION_AUDIT_20260415.md`
  - `testing/logs/BOOKS1_2_CHOICE_FLOW_SMOKE_PS7.txt`
  - `testing/logs/BOOKS1_2_CHOICE_FLOW_SMOKE_PS51.txt`
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS7.txt`
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS51.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS7.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS51.txt`
- added a reusable Kai section-choice automation layer in `modules/core/shell.psm1`:
  - shared section loot/pickup flow
  - shared gold-reward flow
  - shared payment-choice flow
  - exclusive-choice support for sections that allow one option from a group
- moved the first Books `1-2` player-choice/shop/pickup/payment sections onto that shared layer in `modules/rulesets/kai/kai.psm1`, with section definitions kept in the book modules:
  - Book `1`: `12`, `20`, `33`, `46`, `62`, `94`, `164`, `184`, `193`, `197`, `199`, `263`, `269`, `291`, `319`
  - Book `2`: `55`, `76`, `117`, `124`, `181`, `187`, `217`, `220`, `231`, `233`, `274`, `301`
- kept the section-specific choice data in:
  - `modules/rulesets/kai/book1.psm1`
  - `modules/rulesets/kai/book2.psm1`
- validated the new Book `1-2` choice/payment flow in both shells with a targeted smoke pass:
  - `testing/logs/BOOKS1_2_CHOICE_FLOW_SMOKE_PS7.txt`
  - `testing/logs/BOOKS1_2_CHOICE_FLOW_SMOKE_PS51.txt`
- reran the broader automation surface smoke after the new interactive section layer and stayed green in both shells:
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS7_POSTCHOICE.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS51_POSTCHOICE.txt`
- expanded the Kai ruleset automation layer for Books `1-5` using the book-module structure instead of pushing new section logic back into `lonewolf.ps1`
- added generic Kai section-effect execution in `modules/rulesets/kai/kai.psm1` for simple deterministic section hooks:
  - direct `ENDURANCE` loss/recovery
  - instant death
  - meal-or-lose-END checks
- added generic Kai combat-rule dispatch in `modules/rulesets/kai/combat.psm1` for simple per-section combat modifiers and restrictions
- expanded Kai random-number context coverage in the Book `1-5` modules, including the late Book `5` section range through `400`
- widened both automation smoke harnesses so Book `5` now validates sections `1-400` instead of stopping at `350`
- fixed a follow-up Book `5` section `393` refactor bug where a stale `Test-LWStateHasMindshield` call could break section-entry automation after the new sweep widened coverage
- validated the updated Books `1-6` automation surface in both shells:
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS7.txt`
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS51.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS7.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS51.txt`
- recorded the Books `1-5` automation implementation scope and remaining backlog in:
  - `testing/logs/BOOKS1TO5_AUTOMATION_IMPLEMENTATION_20260415.md`
- fixed a strict-mode crash path where `roll` could fail before section handling if the command or ruleset module had not yet materialized a local `GameState` variable
- confirmed the fix against a copied campaign save on Book `6`, section `170`; `roll` now resolves without appending to `data/error.log`
- proactively hardened the rest of the automation surface against the same strict-mode module-state bug by materializing `GameState`, `GameData`, and `LWUi` at module scope across core and book/ruleset modules before context rebinding occurs
- added a reusable random-automation smoke harness at `testing/tmp/random-automation-smoke.ps1`
- validated all currently implemented random-number automations across Books `1-6` in both shells with no failures:
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS7.txt`
  - `testing/logs/RANDOM_AUTOMATION_SMOKE_PS51.txt`
- fixed a follow-up refactor bug where Book `3`, section `18` could fail while resolving forced weapon loss because the ruleset helper was reading module-local state without rebinding context first
- added a broader automation smoke harness at `testing/tmp/automation-surface-smoke.ps1`
- validated startup gear, story/transition triggers, section-entry hooks, and combat-scenario rules across Books `1-6` in both shells with no failures:
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS7.txt`
  - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS51.txt`
- widened the shell notification buffer from `8` to `12` entries so important combat/setup notices are not pushed off-screen by later round or achievement messages
- refreshed the post-fix screen-lag baseline in both shells and added a direct before/after comparison report:
  - `testing/logs/SCREEN_LAG_VALIDATION_POSTFIX_PS7.txt`
  - `testing/logs/SCREEN_LAG_VALIDATION_POSTFIX_PS51.txt`
  - `testing/logs/SCREEN_LAG_BASELINE_COMPARISON_20260414.md`
- reran the Books `1-3` prerelease harness after the lag/context work and finished green in both shells:
  - `testing/logs/BOOKS_1_3_PRERELEASE_NORMAL_PS7_POSTLAG.txt`
  - `testing/logs/BOOKS_1_3_PRERELEASE_NORMAL_PS51_POSTLAG.txt`
- completed the remaining lag-hardening pass from `recommendations.md`, including:
  - generation-based module-context caching across host/core/ruleset modules
  - same-screen refresh gating with lighter clear behavior
  - current-save fast-path normalization during load
  - expanded render batching for shell status lines and combat round/meter output
  - startup cache warming for achievement definitions and mode availability
- added `StateSchemaVersion` metadata so healthy current-format saves can skip the legacy normalize-and-repair path on future loads
- fixed a post-lag-pass regression where shell started calling the shared batched display writer before that helper was exported from `modules/core/display.psm1`
- validated that `combat status` from `inv` no longer writes to `data/error.log`
- new lag-hardening artifacts:
  - `testing/logs/LAG_HARDENING_VALIDATION_PS7.txt`
  - `testing/logs/LAG_HARDENING_VALIDATION_PS51.txt`
  - `testing/logs/LAG_HARDENING_REPORT_20260414.md`
- reworked the achievement sub-screens so `unlocked`, `locked`, `progress`, and `recent` are grouped into `Run-Wide` plus per-book panels instead of rendering as one long flat dump
- converted achievement detail rows to wrapped key/value panels so long names and descriptions stay readable without truncation
- cleaned up the campaign milestones `Recent Achievements` panel to use the same wrapped achievement row style
- fixed a post-extraction performance regression where host-context rebinding could stomp achievement-module caches on every screen call
- fixed `combat status` from the inventory flow so it rebinds combat-module state correctly and no longer writes a strict-mode error to `data/error.log`
- optimized achievement overview rendering by:
  - keeping achievement definition and per-book display caches module-local
  - reusing a single unlocked-ID lookup per render
  - avoiding repeated full-definition scans for book totals
- optimized inventory slot-grid rendering by indexing backpack slot data once per panel instead of re-filtering the slot map for every slot
- new lag-validation artifacts:
  - `testing/logs/SCREEN_LAG_VALIDATION_PS7.txt`
  - `testing/logs/SCREEN_LAG_VALIDATION_PS51.txt`
- reduced `-Load` startup lag on campaign saves by:
  - removing duplicate load-time story-achievement rebuild work
  - adding an achievement-state schema fast path
  - adding derived-metric caching for load-time achievement backfill
  - persisting a load-backfill version marker so later loads of a saved run are faster
- new load-startup validation artifacts:
  - `testing/logs/LOAD_STARTUP_LAGFIX_PS7.txt`
  - `testing/logs/LOAD_STARTUP_LAGFIX_PS51.txt`
  - `testing/logs/LOAD_STARTUP_LAGFIX_POSTSAVE_PS7.txt`
  - `testing/logs/LOAD_STARTUP_LAGFIX_POSTSAVE_PS51.txt`
  - `testing/logs/LOAD_BREAKDOWN_LAGFIX_PS7.txt`
  - `testing/logs/LOAD_STARTUP_LAGFIX_REPORT.md`
- prerelease full-sweep Batches `1-4` are now green in both PowerShell `7` and Windows PowerShell `5.1`, including:
  - package validation
  - command-surface and save-system prerelease passes
  - Books `1-6` prerelease campaign coverage
  - NewRun difficulty sweep, achievement audit, and performance capture
- fixed a post-optimization regression where module host-command caches could permanently remember missing late-bound functions and break later load/performance paths
- fixed a strict-mode regression in backpack layout handling where one-item collections could collapse to scalars and crash Book `2` / Book `3` startup gear screens
- fixed a Book `5` confiscation regression where pocket-carried confiscated items could collapse to scalars under strict mode and break summary/restore flows

- prerelease Batch 1 foundation pass is now green in both shells:
  - package and cold-start validation
  - command-surface prerelease sweep
  - save-system prerelease sweep
- fixed a command-surface inventory defect where `add backpack Arrow` could add arrows to the Backpack instead of the Quiver when a `Quiver` was carried
- fixed a packaged/runtime strict-mode regression where module-local `GameData` could be missing during load/normalize flows
- fixed the no-save `load` screen path so an empty save catalog renders cleanly instead of crashing
- final architecture cleanup pass completed the remaining extraction buckets from `recommendations.md`, including:
  - combat stat / weapon / archive helpers into `modules/core/combat.psm1`
  - a new `modules/core/healing.psm1`
  - section random-number / torch / hunting helpers into `modules/core/ruleset.psm1`
  - remaining UI primitives into `modules/core/shell.psm1`
  - input helpers into `modules/core/common.psm1`
  - missed state constructors into `modules/core/state.psm1`
- `lonewolf.ps1` is now reduced to roughly `1.2k` lines and acts as bootstrap plus top-level orchestration
- post-final-pass command-surface validation is green in both shells:
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT3_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT3_PS51.txt`
- architecture extraction pass now moves the largest remaining engine blocks out of `lonewolf.ps1` into:
  - `modules/core/achievements.psm1`
  - `modules/core/items.psm1`
  - `modules/core/inventory.psm1`
- remaining state, save, screen, combat, common, and ruleset helpers were also extracted into their owning modules:
  - `modules/core/combat.psm1`
  - `modules/core/state.psm1`
  - `modules/core/save.psm1`
  - `modules/core/shell.psm1`
  - `modules/core/common.psm1`
  - `modules/core/ruleset.psm1`
  - `modules/rulesets/kai/kai.psm1`
  - `modules/rulesets/magnakai/magnakai.psm1`
- `lonewolf.ps1` is now reduced to roughly `1.2k` lines and acts primarily as bootstrap, shared-state wiring, and top-level orchestration
- post-extraction runtime validation is green in both shells:
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PLAYTEST_POSTREFACTOR_EXTRACT_PS51.txt`
- runtime now rotates oversized `data/error.log` files at startup, archives them as `error-YYYYMMDD-HHMMSS.log`, and keeps the latest `5`
- new `modules/core/shell.psm1` now owns runtime maintenance, notifications, banners, and additional screen renderers for:
  - stats
  - campaign
  - achievements
  - inventory
  - main sheet
- book-specific combat encounter profiles and scenario rules now dispatch through:
  - `modules/rulesets/kai/combat.psm1`
  - `modules/rulesets/magnakai/combat.psm1`
- `modules/core/combat.psm1` no longer carries the legacy inline per-book scenario branch
- additional strict-mode/null-safety hardening landed in core save/common/shell handling
- stale duplicate wrapper-era functions were removed from `lonewolf.ps1`, including dead legacy copies of:
  - save/load
  - command dispatch
  - combat startup
  - section-entry rules
  - section random-number context dispatch
  - story-section achievement trigger dispatch
- Book `1-5` starting-equipment helper definitions now live with their respective Kai book modules instead of the main script
- Book `1-6` section-context achievement ID lists now live with their respective book modules and dispatch through `modules/core/ruleset.psm1`
- generic loot-choice and book-transition safekeeping prompts now live in `modules/core/shell.psm1` instead of `lonewolf.ps1`
- Book `4` section `12` choice handling now lives in `modules/rulesets/kai/book4.psm1`
- Book `6` riverboat-ticket item names now live in `modules/rulesets/magnakai/book6.psm1`
- `Book of the Magnakai` item-name helpers now live in `modules/rulesets/magnakai/magnakai.psm1`
- Book `6` section `10` now prompts for the riverboat ticket purchase, stores the ticket as a pocket-carried Special Item outside the normal `12`-item cap, and surfaces the ticket route again at section `124`
- Book `6` OG automation catch-up expanded across:
  - fixed ENDURANCE losses and gains
  - Random Number helpers
  - gold, item, and equipment state changes
  - combat-special rules
- Book `6` validation was rerun in both PowerShell `7` and Windows PowerShell `5.1`, including:
  - instant-death matrix reruns
  - full sample-route and difficulty matrix reruns
  - targeted section `155` combat timing validation

## v0.8.0 - 2026-04-09

Second public release.

### Highlights

- Magnakai support is now public for Book `6`
- Book `5` now hands off into Book `6` with:
  - ruleset change
  - Magnakai discipline selection
  - Weaponmastery starter selection
  - lore-circle bonus handling
- Book `6` section, combat, and achievement coverage expanded substantially, including Definitive Edition differences found during live playtesting
- Total achievements increased to `111`

### UX And Command Surface

- M3 retro UI refresh is now part of the shipped build across:
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
- main screens now include compact screen-specific `Helpful Commands` panels
- combat archive/detail rendering is cleaner and more stable
- inventory, campaign, achievement, and combat panels were compacted to reduce redraw clutter

### Packaging And Validation

- portable packaging now includes the Magnakai data files needed for Book `6`
- the portable bundle now ships `CHANGELOG.md`
- `validate-release.ps1` now smoke-tests a disposable extracted package copy in both shells
- Books `1-6` route, command-surface, and package validation cleared in both PowerShell `7` and Windows PowerShell `5.1`

### Release Asset

- `LoneWolf_ActionAssistant_v0.8.0_portable.zip`
- GitHub release:
  `https://github.com/o0cynix0o/LoneWolf_ActionAssistant/releases/tag/v0.8.0`

## v0.7.40 - 2026-04-02

First public release.

### Highlights

- Kai ruleset support through Books `1-5`
- Screen-based PowerShell Action Chart companion with:
  - inventory
  - combat
  - saves
  - notes
  - stats
  - campaign review
  - achievements
- Book-aware automation for:
  - startup packages
  - carry-forward state
  - loot sections
  - special combat hooks
  - forced damage and item loss
  - major route and story rules
- Locked run difficulties:
  - `Story`
  - `Easy`
  - `Normal`
  - `Hard`
  - `Veteran`
  - optional `Permadeath`
- M1 modular engine refactor completed and shipped
- Portable packaging workflow and first portable release zip

### GitHub And Docs

- Wiki strategy guides published for Books `1-5`
- GitHub milestones, labels, issue forms, and project board are now in use
- Repo workflow and handoff docs updated for the modular engine and release process

### Release Asset

- `LoneWolf_ActionAssistant_v0.7.40_portable.zip`
- GitHub release:
  `https://github.com/o0cynix0o/LoneWolf_ActionAssistant/releases/tag/v0.7.40`
