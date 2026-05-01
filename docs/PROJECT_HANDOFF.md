# Project Handoff

This file is the durable handoff for the Lone Wolf Action Assistant. It is meant to let a new chat recover the project's current state, understand how work is done here, and continue without relying on prior conversation history.

## Current Project State

- App version: `0.9.0` pre-release hardening
- Main script: `lonewolf.ps1`
- Latest tagged public release on `main`: `v0.8.0`
- `main` remains the public release branch
- current working branch is `main`
- `main` is the operational source of truth for recovery and stabilization work
- as of `2026-04-22`, `main` is `13` commits ahead of `dev`
- `dev` currently trails `main` and should not be treated as the active integration source until branch strategy is reconciled
- Repo workflow: commit and push completed Lone Wolf changes by default unless explicitly told not to
- Confirmed defects should be tracked in GitHub as they are found, not cleaned up later in a batch
- Strategy-guide creation/update is part of the required book-work closeout when a book's route/support surface changes
- Strategy-guide house style now lives in `docs/STRATEGY_GUIDE_STYLE_GUIDE.md` and should be treated as the default for future book guides
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
- released rule support across Books `1-6`
- current `main` also contains local rule support across Books `1-8`
- Transition-only Special Item safekeeping beginning at the Book `4` -> `5` handoff and continuing on later book-to-book transitions
- Project Aon baseline catch-up complete across Books 1-5, plus released Book 6 / Magnakai support
- Book `7` / `Castle Death` and Book `8` / `The Jungle of Horrors` are now implemented locally in the Magnakai ruleset on current `main` and validated to the agreed build bar
- The Kai ruleset campaign is complete through Book `5`, and released Magnakai Book `6` support is part of the public build
- GitHub repo, wiki, and issue tracker workflow already in use
- GitHub labels, issue forms, and milestones are now live
- GitHub Project board is now live
- Formal architecture planning docs now exist for the modular-engine refactor milestone and the planned web-GUI / cross-platform migration
- M1 modular refactor is complete and pushed
- M2 Magnakai / Book `6` support is complete and released
- M2.7 validation closeout is complete under the route-and-mode validation bar
- M3 UX polish is complete and released
- M4 portable packaging workflow is complete and released
- M5 Book `6` automation catch-up is complete on `main`
- M6 web GUI and cross-platform migration is complete on `main` under the
  current validation policy
- current stabilization work on `main` is `0.9.0` pre-release web-GUI milestone hardening, architecture cleanup, recent Book `6` DE support, Book `7` validation, and Book `8` audit/build hardening before the first release-ready `1.0.0` build
- the formal migration plan for a web-GUI-first, cross-platform future now lives in `docs/WEB_GUI_CROSS_PLATFORM_PLAN.md`
- the Phase `0` parity inventory for that migration now lives in `docs/WEB_PARITY_INVENTORY.md`
- the initial tracked web scaffold now lives under `web/` with a PowerShell engine session host, a Python HTTP server, a browser frontend shell, and `Start-LoneWolfWeb.ps1`
- the tracked web scaffold now supports the first structured setup flow end-to-end:
  - browser-side `New Game` and `Load Last Save` controls now exist in the tracked frontend shell
  - the web session host now exposes a structured pending-flow model for fresh-run setup instead of only safe screen/state actions
  - current web-driven setup coverage includes run difficulty, name/book/section, Kai or Magnakai discipline picks, Weaponmastery picks, and startup-equipment handoff
  - this flow has been verified both by talking directly to `web/lw_api_session.ps1` and through the local HTTP server in `web/app_server.py`
  - `Start-LoneWolfWeb.ps1` no longer uses a `Host` parameter name, so the launcher can be invoked or dot-sourced without tripping over PowerShell's built-in read-only `$Host` variable
- latest `main` web migration checkpoint:
  - the tracked browser shell now supports first-pass in-run controls instead of stopping at setup
  - current browser-side live-play coverage now includes:
    - `Save Run` plus save-to-path and prompt-backed path selection in the Saves tab
    - direct note add/remove actions in the Notes tab
    - slot-aware Inventory panels with live recovery-stash summaries
    - direct Inventory tab actions for add, drop, and recover on supported inventory sections
    - direct Gold / END adjustments plus prompt-backed `Use Meal` and `Use Healing Potion` controls
    - tracked combat start from the Combat tab
    - structured follow-up prompts for combat setup and save-path requests
    - active combat actions for round resolution, auto-resolve, evade, and stop
  - the web session host now preserves generated random rolls across prompt-backed combat replay so manual CRT follow-up prompts can resume safely without reroll drift
  - the web session payload now exposes slot-aware inventory snapshots for Weapons, Backpack, Special Items, Pocket Items, and Herb Pouch so the browser surface is no longer guessing from raw arrays
  - this slice has been verified both by talking directly to `web/lw_api_session.ps1` and through the local HTTP server in `web/app_server.py`
  - same-book section-page navigation inside the reader iframe now pushes section changes back into the app state instead of only changing the displayed book page
  - the default desktop split now gives less width to the reader pane and more width to the app pane so the book text is framed more tightly and wastes less side margin
  - browser-side Book Complete continuation now uses the real prompt-backed web flow instead of stopping at the recap screen
  - the `continueBook` flow now survives legacy Book `6` -> `7` saves and can enter the real next-book setup path
  - current web transition prompt context now renders readable option lists for Magnakai discipline picks, Weaponmastery top-ups, and safekeeping prompts during that handoff
  - prompt-backed browser flows now render clickable quick-pick buttons whenever the visible pending context includes numbered or lettered choices
  - current quick-pick context now also covers the Book `6` / `7` starting-gear prompts instead of dropping to a bare `Book X choice #n` text box
  - loading a `.bak-...` recovery save no longer rewrites the default `last save` pointer; backup loads now stay detached until the player saves them manually
  - the local web bootstrap now skips stale backup pointers and falls back to the newest normal `.json` save when needed
  - the main web Overview sheet now groups disciplines by ruleset, with separate Kai and Magnakai sections instead of one flat mixed list
  - the web discipline panel now uses a compact multi-column chip grid so overview sheets stop wasting a full row per discipline
  - the tracked browser shell now includes browser-native `Stats`, `Campaign`, and `Achievements` tabs instead of forcing the run-review surfaces back through command text
  - the web session payload now exposes the live current-book stats summary and a structured achievement snapshot with current-book entries, recent unlocks, and per-book totals
  - backend `stats`, `campaign`, and `achievements` screen changes now sync back into the browser tab state, so safe commands and screen shortcuts land on the matching review tab instead of leaving the browser on stale content
  - the Campaign tab hotfix now sends the full engine campaign summary instead of the older lightweight web stub, so browser-side campaign review once again has tracked-book history and recent achievement data to render
  - the Overview campaign snapshot was adjusted to tolerate the richer campaign payload without losing its quick `Sections / Victories / Deaths / Rewinds` summary rows
  - the web session payload now exposes a dedicated death snapshot with cause, death type, book/section, rewind availability, final-state totals, and save-path context
  - the browser Overview now renders a real death screen with direct rewind, `Load Last Save`, and `Start New Run` controls instead of leaving death recovery behind command text
  - while a run is dead, the browser can still switch into `Stats`, `Campaign`, `Achievements`, and `Saves` for review before the player decides whether to rewind or restart
  - the web action layer now includes a direct `rewindDeath` request for browser-native recovery
  - validating that new path also exposed and fixed a web achievement-snapshot bug where unlocked display names were being resolved without the required fallback name
  - prompt-backed browser flows now also expose lightweight prompt-kind metadata so the frontend can distinguish inventory-pressure, safekeeping, and structured choice-table prompts
  - the browser prompt surface now uses that metadata to render guided companion panels, stacked quick-pick actions, and direct `Open Inventory Tab` shortcuts instead of leaning so heavily on raw pasted prompt text
  - startup-equipment prompt payloads now carry their readable context text through the tracked flow too, so Book `6` / `7` starting-gear prompts keep their live option list in the browser
  - the tracked browser shell now also includes browser-native `Disciplines`, `Modes`, `Combat Log`, and `Help` tabs instead of leaving those surfaces behind safe-command-only fallbacks
  - the web session payload now exposes structured discipline catalogs, selected Kai/Magnakai state, Weaponmastery picks, lore-circle status, run-mode definitions, current achievement pools, safe-command help, and detailed active/archive combat-log snapshots
  - combat-log round payloads now stay array-shaped even for one-round fights, so browser rendering can handle archived fights consistently
  - the new web parity surface smoke is tracked at `testing/tmp/web-parity-surface-smoke.ps1` and has green artifacts:
    - `testing/logs/WEB_PARITY_SURFACE_SMOKE_PS7.txt`
    - `testing/logs/WEB_PARITY_SURFACE_SMOKE_PS51.txt`
    - `testing/logs/WEB_HTTP_SURFACE_SMOKE.txt`
  - `Start-LoneWolfWeb.ps1` now avoids PowerShell `7`-only platform variables under strict mode and falls back from `python` to `python3`, with Windows PowerShell launcher smoke coverage at:
    - `testing/logs/WEB_LAUNCHER_PS51_SMOKE.txt`
  - pending-flow state snapshots now tolerate optional prompt metadata under strict mode, and startup-equipment prompts now carry readable context text while restoring their checkpoint before returning to the browser
  - this closes the web setup failure where a Kai setup including `Weaponskill` could reach startup equipment and then fail snapshot rendering because the flow did not yet have `ContextText`
  - the local web parity flow smoke at `testing/tmp/web-parity-flow-smoke.ps1` now covers fresh setup, sandbox save/load, inventory section recovery, combat start/auto-resolve, and the review tabs, with green artifacts:
    - `testing/logs/WEB_PARITY_FLOW_SMOKE_PS7.txt`
    - `testing/logs/WEB_PARITY_FLOW_SMOKE_PS51.txt`
  - the local web parity death smoke at `testing/tmp/web-parity-death-smoke.ps1` now covers a disposable ENDURANCE death, death snapshot/review payloads, and browser-action rewind back to a living section, with green artifacts:
    - `testing/logs/WEB_PARITY_DEATH_SMOKE_PS7.txt`
    - `testing/logs/WEB_PARITY_DEATH_SMOKE_PS51.txt`
  - the local web parity transition smoke at `testing/tmp/web-parity-transition-smoke.ps1` now covers Book Complete -> `continueBook` -> prompt-backed Book `6` to `7` continuation, including Magnakai discipline, Weaponmastery, safekeeping, starting-gear payloads, and final carried-state assertions, with green artifacts:
    - `testing/logs/WEB_PARITY_TRANSITION_SMOKE_PS7.txt`
    - `testing/logs/WEB_PARITY_TRANSITION_SMOKE_PS51.txt`
  - transition prompt context now keeps singleton Special Item lists array-shaped under strict mode and labels safekeeping with the real target book during `continueBook`
  - M6 closeout is now complete:
    - remaining known shop, loot, payment, section-choice, make-room,
      safekeeping, starting-gear, and transition prompts now carry web-safe
      pending-flow context
    - achievement parity is tracked at `testing/tmp/web-parity-achievement-smoke.ps1`
      with green artifacts:
      - `testing/logs/WEB_PARITY_ACHIEVEMENT_SMOKE_PS7.txt`
      - `testing/logs/WEB_PARITY_ACHIEVEMENT_SMOKE_PS51.txt`
    - prompt-heavy book automation parity is tracked at
      `testing/tmp/web-parity-automation-smoke.ps1` with green artifacts:
      - `testing/logs/WEB_PARITY_AUTOMATION_SMOKE_PS7.txt`
      - `testing/logs/WEB_PARITY_AUTOMATION_SMOKE_PS51.txt`
    - browser-DOM validation is tracked at `testing/tmp/web-browser-dom-smoke.ps1`
      with green artifacts:
      - `testing/logs/WEB_BROWSER_DOM_SMOKE_PS7.txt`
      - `testing/logs/WEB_BROWSER_DOM_SMOKE_PS51.txt`
    - package validation for the bundled web scaffold is tracked at
      `testing/tmp/web-packaging-smoke.ps1` with green artifacts:
      - `testing/logs/WEB_PACKAGING_SMOKE_PS7.txt`
      - `testing/logs/WEB_PACKAGING_SMOKE_PS51.txt`
    - the older portable release validator also passes after adding the web
      scaffold to the package:
      - `testing/logs/RELEASE_VALIDATE_M6_CLOSEOUT_PS7.txt`
  - the portable package now includes `web/`, `Start-LoneWolfWeb.ps1`,
      generated `Start-LoneWolfWeb.cmd`, and POSIX `Start-LoneWolfWeb.sh`
- latest `main` Book `8` audit/build:
  - local source audit now covers `books/lw/08tjoh` / `The Jungle of Horrors`, with sweep artifact `testing/tmp/book8_source_sweep.json`
  - Book `8` rule support now includes startup gear/gold, mandatory `Pass`, Conundrum route rewards, meal requirements, section damage/recovery, Grey Crystal Ring/Lodestone/Giak Scroll/Flask/Map handling, gold payments, riddle penalty, and Book `8` completion
  - Book `8` combat support now covers Vordaks, Helghasts, Korkuna, Kezoor, Taan-spider venom/psychic modifiers, swamp hazard fights, and the major route-result notes
  - Book `8` random-number contexts now cover all audited roll sections, including section `86` where zero counts as ten for the Grey Crystal Ring backlash
  - current known manual/watch areas are documented: the section `168` Bowyery Lune shop, optional Special Item sales at `139`, later Flask of Larnuma draught use, and the two sequential Vordak fights at `13` and `287`
  - local Book `8` validation is tracked at `testing/tmp/book8-rules-smoke.ps1` and currently passes in both PowerShell `7` and Windows PowerShell `5.1`
  - local audit reports now exist at:
    - `testing/logs/BOOK8_ENDINGS_AND_ROUTE_FAMILIES_20260430.md`
    - `testing/logs/BOOK8_AUTOMATION_LEDGER_20260430.md`
    - `testing/logs/BOOK8_RULES_AND_ITEMS_AUDIT_20260430.md`
    - `testing/logs/BOOK8_COMBAT_AND_RANDOM_AUDIT_20260430.md`
    - `testing/logs/BOOK8_ACHIEVEMENT_CANDIDATES_20260430.md`
  - wiki strategy-guide closeout now includes `Book-8-Strategy-Guide`, and the support matrix / strategy index / stats pages now reference current `main` support through Book `8`
- latest `main` Book `7` startup/save hotfix:
  - Book `7` startup now guarantees the section `1` `Power-key` is granted into Pocket Items before the opening setup can leave the player stranded on section `1` without it
  - load normalization now repairs missing `Power-key` state for both older and current-format Book `7` section `1` saves, then marks `Book7PowerKeyClaimed` so the corrected key persists on the next save
  - the Book `7` startup smoke now covers both the older-save reconciliation path and the current-format fast-normalize path for this repair
- latest `main` Book `7` automation catch-up:
  - section `190` now automatically applies the text-required `2 ENDURANCE` psychic cost when you force your discipline through the wounded eye and escape the tentacle
  - the section `190` hook is one-shot, so revisiting the section-entry rules while still on `190` will not charge the cost twice
  - the Book `7` choice/state smoke now includes a dedicated section `190` regression for this escape cost
- latest `main` carry-over hotfix:
  - Book `7` startup now preserves the `3` Weaponmastery weapons already earned in a carried-over Book `6` run and prompts only for the one new mastery slot needed to reach the Book `7` total of `4`
  - this matches the original Magnakai Weaponmastery progression text instead of forcing a full `4`-weapon re-pick during the Book `6` -> `7` handoff
  - the Book `7` startup smoke now explicitly verifies that the original mastered set survives the transition and that exactly one new mastery is appended
- latest `main` future-transfer rules fix:
  - future carried-over starts for Books `2-8` now follow the source-text rule that old `Backpack Items` do not carry between adventures during the Kai and Magnakai series
  - app-level `Pocket Items` are now also cleared on those future transfers instead of lingering indefinitely across books
  - the fix is forward-only for local play: existing saves are left as-is, but future book-to-book transfers now clear old `Backpack Items` and `Pocket Items` before the new book's starting-equipment picks begin
  - Book `6` -> `7` transitions now also clear old `Herb Pouch` contents and the carried `Herb Pouch` state so Book `6` potion storage does not bleed into Book `7`
  - carried `Weapons`, `Special Items`, and `Gold` still survive these pre-Book-13 handoffs as before
- latest `main` inventory command follow-up:
  - the interactive `drop` prompt now accepts `pocket` as a removable inventory type
  - `drop pocket <slot>` and `drop pocket all` now work for current pocket-carried items
  - `add pocket` and `recover pocket` remain intentionally blocked so pocket items stay tied to section automation instead of the general inventory recovery system
- latest `main` transition-healing rules update:
  - between-book `ENDURANCE` restoration is now difficulty-driven instead of being hard-coded to early-book transitions
  - `Story` and `Easy` now restore `ENDURANCE` to full when the next book begins
  - `Normal` now keeps the source-text current-`ENDURANCE` carryover between books
  - `Hard`, `Veteran`, and `Permadeath` also keep classic current-`ENDURANCE` carryover between books
  - no other handoff rules changed; carried weapons, Special Items, gold, and the existing future-transfer cleanup rules still behave the same
  - the book-complete summary smoke now explicitly covers `Book 6` -> `Book 7` transitions for `Story`, `Easy`, `Normal`, `Hard`, `Veteran`, and `Permadeath`
- current `main` UX hotfix:
  - mid-campaign book completions now stop on the book-complete recap screen before the next book's setup prompts begin
  - the book-complete recap now snapshots the just-finished book's final Gold, Endurance, notes count, and run-integrity state so the summary does not drift into the next book's state
  - the recap panel now shows a fuller per-book run summary, including sections seen, END swings, gold gained/spent, deaths, rewinds, potions, meals, and final-state totals
  - the recap screen now stays in the app's slimmer two-column panel layout instead of the brief full-width experiment
  - combat recap rows now include named shortest/longest fights, highest and lowest enemy CS/END callouts, highest win thresholds, average fight length, and weapon-usage summaries, with the longer named highlights rendered on their own lines for readability
  - book achievements now render in a dedicated two-column per-book panel on the recap screen
- latest `main` hotfix:
  - Book `6` section `170` `roll` now uses the live current state correctly in interactive play
  - section `170` bonus logic now matches the local OG text (`Weaponmastery with Bow +3`, `Huntmastery +1`)
- latest DE Book `6` rules add-on:
  - section `2` now automates the herbmaster potion-shop flow
  - section `98` now automates the DE weapons-shop flow, including weapon purchases, arrow purchases that can partially fill the last free Arrow slot while leaving overflow behind, weapon resale, arrow resale, and `Quiver` / `Large Quiver` resale at one Gold Crown below list price
  - section `275` now automates the DE cartographer shop flow, including buy/sell handling for `Map of Sommerlund`, `Map of Tekaro`, and `Map of Luyen`
  - `Map of Luyen` is now modeled as a Backpack Item
  - section `275` map resale now follows the DE text rule of `1` Gold Crown below list price
  - `Large Quiver` is now modeled as a real Special Item quiver with `12` Arrow capacity
  - section `158` / `200` / `293` silver-key handling now uses the DE-facing item name `Sinede's Silver Key`, erases the key at section `200` when you insert it into the tomb lock, and keeps section `293` as a save-compatibility fallback for older `Small Silver Key` runs
  - section `17` now automates the inn lodging choice flow, including the text-supported dormitory barter fallback when you cannot afford a room
  - section `297` now supports the DE-only `Bronin Sleeve-shield` trade flow
  - `Bronin Sleeve-shield` is modeled as a Special Item that grants `+1 CS` and `+1 END` in physical combat when a normal shield is not currently usable
- latest OG-source Book `6` follow-up pass now also present on `main`:
  - section `27` and section `273` now support the source-side `3` Gold Crown `Cess` purchase before the existing section `304` item claim
  - section `165` now supports the source-side `5` Gold Crown `Map of Varetta` purchase, and section `16` now safely marks the map claim when you reach it
  - section `137` now deducts the source-side `3` Gold Crown Quarlen levy
  - section `209` now removes the fired Arrow from your Action Chart and backfills that loss onto older in-progress saves during normalization
  - older Book `6` saves created before the section `209` Arrow-loss story flag now load cleanly again through both startup `-Load` and the in-app `load` command
  - section `328` now deducts the source-side `2` Gold Crown roast-beef meal cost
  - sections `96`, `169`, `205`, `211`, `248`, `295`, `316`, and `318` now surface guidance-only automation notes for the text-supported route checks found in the original book language sweep
- latest lag pass now present on `main` fixed two post-extraction regressions:
  - achievement-screen caching was being reset by host-context rebinding
  - `combat status` from `inv` could throw a module-context error and write to `data/error.log`
- the follow-up lag-hardening pass from `recommendations.md` is now present on `main`:
  - generation-based context caching now short-circuits repeated rebinding across host/core/ruleset modules
  - current-format saves can fast-path load normalization instead of always paying the full repair path
  - shell render output now batches more status and combat lines through the shared display writer
  - same-screen refreshes now use a lighter clear path
- prerelease Batch `1-4` full-sweep validation remains green in both shells
- load-path performance work now targets campaign-save startup directly instead of screen rendering
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
- current `main` follow-up Books `1-2` choice-flow automation pass:
  - added shared section-choice, gold-reward, and payment-choice helpers in `modules/core/shell.psm1`
  - added exclusive-choice support so sections like Book `1`, section `291` can grant one weapon from a set without reopening the other exclusive option later
  - moved the first player-choice/shop/pickup/payment slice onto the book-module path in `modules/rulesets/kai/kai.psm1`
  - Book `1` sections now covered by the shared choice/payment layer:
    - `12`, `20`, `33`, `46`, `62`, `94`, `164`, `184`, `193`, `197`, `199`, `263`, `269`, `291`, `319`
  - Book `2` sections now covered by the shared choice/payment layer:
    - `55`, `76`, `117`, `124`, `181`, `187`, `217`, `220`, `231`, `233`, `274`, `301`
  - local validation artifacts:
    - `testing/logs/BOOKS1_2_CHOICE_FLOW_SMOKE_PS7.txt`
    - `testing/logs/BOOKS1_2_CHOICE_FLOW_SMOKE_PS51.txt`
    - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS7_POSTCHOICE.txt`
    - `testing/logs/AUTOMATION_SURFACE_SMOKE_PS51_POSTCHOICE.txt`
- current `main` Books `1-5` automation coverage is now fully closed under the refreshed local audit:
  - Book `1`: `78/78`
  - Book `2`: `153/153`
  - Book `3`: `127/127`
  - Book `4`: `130/130`
  - Book `5`: `152/152`
  - total Books `1-5` missing candidates: `0`
  - local audit artifact:
    - `testing/logs/BOOKS1TO5_AUTOMATION_AUDIT_20260415.md`
- current `main` Book `6` automation coverage is also fully closed under the refreshed local audit:
  - high-confidence OG automation candidates: `77/77`
  - missing candidates: `0`
  - remaining notes are design-review items, not missing hooks:
    - section `24` OG versus DE drift
    - section `112` Herb Pouch DE variant
    - sections `207` / `276` Bronin Warhammer slot-model choice
    - section `298` covered indirectly through the section `26` tournament combat flow
  - local audit artifacts:
    - `testing/logs/BOOK6_AUTOMATION_AUDIT_20260415.md`
    - `testing/tmp/book6_automation_refresh_audit.py`
- current `main` broader Book `6` original-text language sweep is also recorded and now built out for the concrete follow-ups it found:
  - source-language sweep artifact:
    - `testing/logs/BOOK6_OG_LANGUAGE_SWEEP_20260422.md`
  - implemented OG follow-up sections:
    - `16`, `27`, `96`, `137`, `165`, `169`, `205`, `211`, `248`, `273`, `295`, `316`, `318`, `328`
  - current `main` recent-targeted Book `6` harness covers that OG follow-up slice in both shells:
    - `testing/logs/BOOK6_RECENT_TARGETED_PS7.txt`
    - `testing/logs/BOOK6_RECENT_TARGETED_PS51.txt`
- current combined automation coverage across Books `1-6`:
  - `717/717` high-confidence candidates covered
- current `main` follow-up hotfix after the broader smoke pass:
  - Book `3`, section `18` no longer fails forced weapon-loss automation because `Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem` now rebinds ruleset module context before reading state
- current `main` Book `6` potion-shop fix:
  - section `2` now runs the apothecary purchase flow and supports buying all five listed potions as Backpack Items
  - `Graveweed Concentrate` is now included in the graveweed item-name group so Book `6` route checks still recognize it after purchase
  - local validation artifacts:
    - `testing/logs/SECTION002_APOTHECARY_PS7.txt`
    - `testing/logs/SECTION002_APOTHECARY_PS51.txt`
- current `main` Book `7` implementation state:
  - `modules/rulesets/magnakai/book7.psm1` now owns the Book `7` startup flow, section-entry automation, choice flows, random-number helpers, route flags, combat rules, and achievement triggers
  - Book `7` startup, choice, combat, achievement, random-helper, and broad automation smokes are green in both shells
  - Book `7` endgame route smoke is green in both shells:
    - one full Normal completion-path smoke
    - blue-beam completion route
    - direct throne-duel completion route
    - signature `349` failure route
  - Book `7` targeted difficulty validation is green in both shells:
    - Story damage prevention and Story-only completion gating
    - Easy damage halving
    - Hard Sommerswerd-halving and healing-cap behavior
    - Veteran Sommerswerd suppression and Veteran completion gating
    - Permadeath rewind blocking, save deletion on death, and completion gating
  - local Book `7` validation artifacts:
    - `testing/logs/BOOK7_STARTUP_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_STARTUP_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_CHOICE_FLOW_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_CHOICE_FLOW_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_COMBAT_HOOK_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_COMBAT_HOOK_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_ACHIEVEMENT_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_ACHIEVEMENT_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_RANDOM_AUTOMATION_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_RANDOM_AUTOMATION_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_AUTOMATION_SURFACE_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_AUTOMATION_SURFACE_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_ENDGAME_ROUTE_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_ENDGAME_ROUTE_SMOKE_PS51.txt`
    - `testing/logs/BOOK7_DIFFICULTY_SMOKE_PS7.txt`
    - `testing/logs/BOOK7_DIFFICULTY_SMOKE_PS51.txt`
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
- latest architecture extraction slice now present on `main` moved the largest remaining monolith blocks into:
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
- latest architecture-hardening smoke passed in both shells:
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
- latest lag-hardening regressions fixed on `main`:
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
- latest prerelease command-surface rerun on `2026-04-22` is also green in both shells after refreshing the harness expectations for canonical potion naming:
  - harness: `testing/tmp/prerelease-command-surface.ps1`
  - `testing/logs/COMMAND_SURFACE_PRERELEASE_PS7.txt`
  - `testing/logs/COMMAND_SURFACE_PRERELEASE_PS51.txt`
- Batch `1` prerelease defects fixed on `main` include:
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
  - `testing/logs/BOOK6_RECENT_TARGETED_PS7.txt`
  - `testing/logs/BOOK6_RECENT_TARGETED_PS51.txt`

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
  Magnakai ruleset shell plus Books `6-7`
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
- strategy-guide updates as part of book closeout

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

### Book 7

- Implemented locally on current `main`
- not yet represented as a tagged public release
- support now includes:
  - Book `7` startup and carry-forward handling
  - section-entry automation, choice flows, and random-number helpers
  - route flags, combat rules, and achievement triggers
  - completion and route achievements
- current wiki state now also includes:
  - `Strategy-Guide`
  - `Book-7-Strategy-Guide`
- current local validation on `main` is green in both shells for:
  - startup flow
  - choice flow
  - combat hooks
  - achievements
  - random-helper coverage
  - automation surface
  - endgame routes
  - difficulty and permadeath behavior

Local reports:

- `testing/logs/BOOK7_AUTOMATION_AUDIT_20260422.md`
- `testing/logs/BOOK7_STARTUP_SMOKE_PS7.txt`
- `testing/logs/BOOK7_STARTUP_SMOKE_PS51.txt`
- `testing/logs/BOOK7_CHOICE_FLOW_SMOKE_PS7.txt`
- `testing/logs/BOOK7_CHOICE_FLOW_SMOKE_PS51.txt`
- `testing/logs/BOOK7_COMBAT_HOOK_SMOKE_PS7.txt`
- `testing/logs/BOOK7_COMBAT_HOOK_SMOKE_PS51.txt`
- `testing/logs/BOOK7_ACHIEVEMENT_SMOKE_PS7.txt`
- `testing/logs/BOOK7_ACHIEVEMENT_SMOKE_PS51.txt`
- `testing/logs/BOOK7_RANDOM_AUTOMATION_SMOKE_PS7.txt`
- `testing/logs/BOOK7_RANDOM_AUTOMATION_SMOKE_PS51.txt`
- `testing/logs/BOOK7_AUTOMATION_SURFACE_SMOKE_PS7.txt`
- `testing/logs/BOOK7_AUTOMATION_SURFACE_SMOKE_PS51.txt`
- `testing/logs/BOOK7_ENDGAME_ROUTE_SMOKE_PS7.txt`
- `testing/logs/BOOK7_ENDGAME_ROUTE_SMOKE_PS51.txt`
- `testing/logs/BOOK7_DIFFICULTY_SMOKE_PS7.txt`
- `testing/logs/BOOK7_DIFFICULTY_SMOKE_PS51.txt`

### Book 8

- Implemented locally on current `main`
- not yet represented as a tagged public release
- support now includes:
  - Book `8` startup, carry-forward, starting-gold, and mandatory `Pass` handling
  - section-entry automation for meals, damage, recovery, gold, item gains/losses, and route penalties
  - Conundrum route rewards, Grey Crystal Ring exchange, Lodestone, Silver Box, Giak Scroll, and Map of Tharro support
  - random-number helpers for all audited Book `8` roll sections
  - combat profiles and special-combat hooks for the major Book `8` enemy/rule families
  - completion, route, item, and failure achievements
- current wiki state now also includes:
  - `Strategy-Guide`
  - `Book-8-Strategy-Guide`
- current local validation on `main` is green in both shells for:
  - Book `8` entry rewards
  - meal consumption
  - Grey Crystal Ring backlash
  - riddle penalty loss
  - section `233` combat profile
  - section `52` Taan-spider scenario and psychic modifiers

Local reports:

- `testing/logs/BOOK8_ENDINGS_AND_ROUTE_FAMILIES_20260430.md`
- `testing/logs/BOOK8_AUTOMATION_LEDGER_20260430.md`
- `testing/logs/BOOK8_RULES_AND_ITEMS_AUDIT_20260430.md`
- `testing/logs/BOOK8_COMBAT_AND_RANDOM_AUDIT_20260430.md`
- `testing/logs/BOOK8_ACHIEVEMENT_CANDIDATES_20260430.md`
- `testing/tmp/book8-rules-smoke.ps1`

## Existing Playtest Coverage

Local reports already exist for:

- command surface playtest
- run-mode rules playtest
- permadeath playtest
- Book 3 sandbox and route sweeps
- Book 5 targeted validation and Books 1-5 campaign smoke
- Book 6 targeted validation and Magnakai transition smoke on `main`
- Book 7 startup/choice/combat/achievement/random/endgame/difficulty smoke on current `main`
- Book 8 targeted rules/combat/random smoke on current `main`
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
- current `main` Book `7` smoke coverage passed in both shells across startup, choice, combat, achievements, automation surface, endgame routes, and difficulty rules
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
- startup `-Load` under redirected input now exits cleanly on its own in both shells after the shared console-aware prompt-reader update
- current portable package validation also passes on `main`, including redirected startup `-Load` smoke in both shells:
  - `testing/logs/PACKAGING_M4_VALIDATION_SUMMARY.md`
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
- identify what the eventual strategy guide will need to explain
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
- draft or update the book strategy guide and related wiki scope pages
- follow `docs/STRATEGY_GUIDE_STYLE_GUIDE.md` so the guide reads like a prose-first printed strategy article
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
4. If the task touches strategy guides, read `docs/STRATEGY_GUIDE_STYLE_GUIDE.md`
5. Check `git status`
6. Check the newest local reports in `testing/logs/`
7. Confirm whether the next task is:
   - content audit
   - implementation
   - playtesting
   - bug fix
8. If the task touches a book, confirm whether the strategy guide/wiki state also needs an update
9. If a public doc changed, remember the README sanitization rules before push

## Good Next Steps

- Continue live playtesting across the released Books `1-6` surface and the current `main` Book `7-8` paths, and patch DE-specific rule differences
- Keep the Book `7` and Book `8` strategy guides current as live playtesting sharpens the best routes
- Use the new strategy-guide style guide as the template when Book `1` and later guide rewrites happen
- Deepen Book `6` route reporting and strategy support as more play data comes in
- Plan the next post-Book `8` Magnakai audit once the current `main` Book `8` surface feels stable
- Keep the handoff docs and strategy-guide workflow in sync as new books become implemented
- Treat M6 as complete; next web work is post-M6 live-play hardening, long-run browser polish, and non-Windows launch validation when those environments are available

## Important Cautions

- Never use the player's live save for sandbox testing
- Prefer cloned sandbox saves such as `readtest` for experimentation
- Do not publish live saves, personal notes, or private playthrough state
- Keep copyrighted book text out of committed docs
- When in doubt, log findings locally first and only ship the confirmed code/docs changes
