# Lone Wolf Action Assistant

A PowerShell terminal companion for the **Lone Wolf** gamebooks. Current `main` is stamped as app/package version `v0.9.0` for the completed web-GUI milestone and final hardening before `v1.0.0`. The latest tagged public release remains `v0.8.0`.

This project is built to act like a digital Action Chart and play aid, not a replacement for the books. It handles the bookkeeping that tends to slow play down: character state, inventory, combat math, saves, notes, healing, book progression, stats, and achievements.

Current `main` includes the local browser GUI backed by a Python HTTP server and
a PowerShell engine session adapter, with the CLI still preserved as the
source-accurate fallback.

## What It Does

- Screen-based terminal UI with ASCII banners and color-coded panels
- New Kai character creation with random starting Combat Skill and Endurance
- Book 1 through Book 6 start-package automation, including carry-in gear support where needed
- Kai discipline selection, including Weaponskill weapon assignment
- Magnakai discipline selection, including Weaponmastery starter weapon choice
- Derived Kai rank titles from discipline count, shown on the sheet and campaign overview
- Derived Magnakai rank titles and lore-circle progress when the ruleset changes
- Inventory slot tracking for weapons (`2`), backpack items (`8`), special items (`12`), and gold
- Section tracking with Healing support for non-combat sections
- Meal handling with Hunting support, including Book 2 Wildlands, Book 3 / Kalte, Book 4 mines / wasteland restrictions, and Book 5 restricted meal sections
- Potion handling for:
  - Healing Potion / Laumspur Potion
  - Potent Laumspur Potion
  - Concentrated Laumspur
  - Book 1 Laumspur Herb
  - Book 2 Meal of Laumspur
- Combat assistant with:
  - combat ratio calculation
  - random number rolls
  - manual or data-driven CRT resolution
  - auto-resolve support
  - round logs and combat summaries
- Item intelligence for:
  - Shield
  - Silver Helm
  - Helmet
  - Broadsword +1
  - Captain D'Val's Sword
  - Drodarin War Hammer
  - Chainmail Waistcoat / Wastecoat
  - Padded Leather Waistcoat / Wastecoat
  - Long Rope
  - Magic Spear
  - Sommerswerd
- Book 1 section-rule support for:
  - Vordak Gem handling
  - Burrowcrawler torch/darkness combat setup
  - Crystal Star Pendant carry-forward tracking
- Book 2 section-rule support for:
  - Seal of Hammerdal startup and audience-route handling
  - Coach Ticket, White Pass, and Red Pass tracking
  - forged access papers state
  - Potent Laumspur Potion and Meal of Laumspur pickups
  - section `106` Magic Spear / Helghast setup
  - section `313` spear loss and damage
  - section `337` storm gear-loss handling
- Book 4 section-rule support for:
  - startup gear, `Map of the Southlands`, `Badge of Rank`, and gold package
  - real Backpack loss / recovery handling
  - mine Torch / Tinderbox supply sections and lighting-aware routes
  - Book 4 forced-loss sections like `22`, `272`, and `327`
  - Holy Water, Scroll, Onyx Medallion, and Captain D'Val's Sword hooks
  - section loot tables, damage/recovery hooks, and contextual random-number support
  - special combat rules like delayed evade, variable Mindforce loss, underwater oxygen loss, and Barraka setup
- Book 5 section-rule support for:
  - startup package, transition safekeeping, and `Map of Vassagonia`
  - confiscation / recovery state in the dungeons
  - blood poisoning and Limbdeath condition handling
  - Book 5 shops, loot tables, and carry-forward item hooks
  - Book 5 special combat rules, endgame routing, and `Book of the Magnakai` recovery
- Book 6 / Magnakai support for:
  - Book `5` -> `6` ruleset handoff
  - Magnakai discipline and Weaponmastery selection
  - lore-circle bonus handling
  - Book 6 startup package and item selection
  - Book 6 section automation, combat hooks, and achievement support
- JSON save/load with autosave support
- Numbered save picker and remembered last-used save
- Book completion summaries with live campaign stats
- Whole-run campaign review screens
- Achievement system with current unlocks, progress, and Book 1-6 story/path coverage
- Death tracking with death-only rewind checkpoints
- Locked run difficulties with Story, Easy, Normal, Hard, and Veteran rules
- Optional Permadeath runs with tamper-evident challenge tracking
- Transition-only Special Item safekeeping starting with the Book `4` -> `5` handoff and continuing on later book-to-book transitions
- Initial tracked web scaffold with:
  - local HTTP/JSON app server
  - browser-based reader + assistant shell
  - long-lived PowerShell engine adapter instead of PTY terminal streaming

## Release Status

- Current app/package version on `main`: `v0.9.0`
- Latest tagged public release: `v0.8.0`
- Current `main` coverage: Kai Books `1-5` plus Magnakai Books `6-7`
- M6 web-GUI / cross-platform migration is complete on `main` and in final hardening before `v1.0.0`
- Current `main` Book `6` stabilization work includes sections `2`, `17`, `98`, `158/293`, `170`, `275`, and `297`, plus the OG source-language follow-up slice at sections `16`, `27`, `96`, `137`, `165`, `169`, `205`, `211`, `248`, `273`, `295`, `316`, `318`, and `328`
- [CHANGELOG.md](./CHANGELOG.md) tracks both public release history and current `Unreleased` main-branch work

## Scope

- Focused on the Kai sequence plus current **Magnakai** support
- Current `main` coverage reaches Book `7` / `Castle Death`
- The latest tagged public release covers through Book `6`
- Intended for use alongside the books
- Does **not** include book text
- Designed to stay flexible when book-specific exceptions come up

## Tracking And Support

- The GitHub wiki contains route and strategy-guide material for the released Books `1-6`, and current `main` now also carries Book `7` / `Castle Death` guide coverage
- GitHub issues now use issue forms for bugs, DE differences, rule gaps, UX notes, and audit/build requests
- GitHub milestones track the top-level roadmap
- The GitHub Project board `Lone Wolf Tracker` is used for day-to-day issue triage
- Latest tagged public release: `v0.8.0`
- Current `main` status: `v0.9.0` web-GUI milestone hardening with Book `7` / `Castle Death` support plus recent Book `6` DE and OG-source stabilization work
- [CHANGELOG.md](./CHANGELOG.md) tracks public release history and current unreleased `main` work

## Requirements

- Windows PowerShell `5.1` or PowerShell `7+`
- Windows terminal with color support recommended
- Python `3` and PowerShell `7` for the tracked web scaffold on current `main`

## Web Scaffold

The tracked migration scaffold can be launched locally with:

```powershell
.\Start-LoneWolfWeb.ps1
```

On POSIX shells, the packaged launcher is:

```sh
./Start-LoneWolfWeb.sh
```

This is the repo-tracked local browser shell for the project. The M6 migration
parity bar is complete on current `main`: the web path uses the real
PowerShell engine over HTTP/JSON while the CLI remains available as a fallback
and validation anchor.

The launcher can be started from Windows PowerShell or PowerShell `7`, but the
web engine host itself requires PowerShell `7`. On non-Windows systems, the
launcher will use `python3` if `python` is not available.

Current web-scaffold coverage includes:

- split reader + assistant browser shell
- live state and screen refresh over the local HTTP/JSON backend
- same-book section-page navigation inside the reader now pushes section changes back into the app state
- browser-native review surfaces for:
  - `Stats`
  - `Campaign`
  - `Achievements`
  - `Disciplines`
  - `Modes`
  - `Combat Log`
  - `Help`
- browser-native death and recovery surface:
  - the Overview now renders a dedicated death panel whenever the engine enters the `death` screen
  - rewind can now be triggered directly from the browser without falling back to command text
  - `Load Last Save` and `Start New Run` are exposed as explicit recovery buttons on that panel
  - while dead, the browser still lets you inspect `Stats`, `Campaign`, `Achievements`, and `Saves` before deciding what to do next
- browser-tab sync for backend review screens:
  - `stats`
  - `campaign`
  - `achievements`
- safe screen / section commands
- save catalog browsing and load actions
- browser-side save controls:
  - `Save Run` from the action strip
  - `Save To Path` and prompt-backed path selection from the Saves tab
- browser-side note controls:
  - add note directly from the Notes tab
  - remove existing notes without dropping back to command text
- browser-side run-review surfaces:
  - current-book stats now render from the live engine summary instead of the raw `CurrentBookStats` object
  - campaign review now has a browser-native screen for run status, totals, milestones, weapon trends, and tracked-book history
  - achievements now have a browser-native screen for current-book targets, recent unlocks, and per-book totals
  - disciplines now render from structured Kai/Magnakai catalogs, selected discipline state, Weaponmastery picks, and lore-circle progress
  - modes now render current difficulty, permadeath, integrity, achievement pools, and difficulty rule definitions
  - combat logs now render active and archived fight records with round details
- browser-side inventory and resource controls:
  - slot-aware inventory panels for Weapons, Backpack, Special Items, Pocket Items, and Herb Pouch
  - direct add, drop, and recover actions for supported inventory sections
  - live recovery-stash summaries for recoverable gear
  - direct Gold and END adjustments from the Inventory tab
  - `Use Meal` and `Use Healing Potion` actions, including prompt-backed follow-up answers when the engine needs more input
- first live-play combat controls:
  - tracked combat start from the Combat tab
  - structured pending prompts for combat setup follow-up questions
  - resolve round, auto-resolve, evade, and stop controls for active fights
- browser-side book-complete continuation:
  - the Book Complete screen now exposes a `Continue To Next Book` action
  - prompt-backed book transitions can now advance into the next book over the same HTTP/JSON path
  - current continuation prompt context includes readable option lists for Magnakai discipline picks, Weaponmastery top-ups, and transition safekeeping choices
  - prompt-backed flows now render clickable quick-pick buttons from the visible option list when context is available
- web-native prompt handling for prompt-heavy gameplay friction points:
  - pending prompts now carry lightweight prompt-kind metadata such as make-room, safekeeping, and starting-gear choice states
  - inventory-pressure prompts now render a compact inventory snapshot plus direct `Open Inventory Tab` shortcuts instead of only dropping to a yes/no box
  - safekeeping prompts now render carried-versus-stored Special Item summaries alongside the live quick-pick actions
  - structured choice tables now render as stacked quick-pick actions, while the raw prompt transcript stays available through a collapsed details block when needed
  - shop, loot, payment, section-choice, make-room, safekeeping, starting-gear, and transition prompts are covered by the M6 parity smokes
- safer recovery-save handling:
  - loading a `.bak-...` recovery save no longer replaces the default `last save` launch target automatically
  - the web bootstrap now skips stale backup pointers and falls back to the newest normal `.json` save instead
- structured `New Game` flow for:
  - difficulty and permadeath
  - character name, book, and starting section
  - Kai / Magnakai discipline picks
  - Weaponmastery picks
  - startup-equipment continuation

## Project Files

- `lonewolf.ps1`
  Main terminal application
- `data/kai-disciplines.json`
  Kai discipline list and selection data
- `data/magnakai-disciplines.json`
  Magnakai discipline list and selection data
- `data/magnakai-ranks.json`
  Magnakai rank ladder data
- `data/magnakai-lore-circles.json`
  Lore-circle groupings and bonus metadata
- `data/weaponskill-map.json`
  Weaponskill roll mapping
- `data/crt.json`
  Data-driven Combat Results Table used by `DataFile` mode
- `data/crt.template.json`
  Template CRT schema
- `data/last-save.txt`
  Last-used save path cache created by the app
- `build-release.ps1`
  Portable release builder
- `validate-release.ps1`
  Portable package validator that rebuilds, extracts, and smoke-tests a disposable copy, including redirected startup `-Load`
- `saves/`
  JSON save files created during play

## Quick Start

Run the app from PowerShell:

```powershell
.\lonewolf.ps1
```

Launch and load a save immediately:

```powershell
.\lonewolf.ps1 -Load .\saves\your-save.json
```

If you run `load` inside the app, it scans the save folder, lists saves by number, and remembers the last one you used as the default.

## Portable Packaging

The project currently packages best as a **portable zip release** rather than a
single executable.

Build a local portable package from the repo root with:

```powershell
.\build-release.ps1
```

Validate the portable package with a disposable extracted-copy smoke pass:

```powershell
.\validate-release.ps1 -Rebuild
```

Default output:

- `testing/releases/LoneWolf_ActionAssistant_v<version>_portable`
- `testing/releases/LoneWolf_ActionAssistant_v<version>_portable.zip`

See [docs/DISTRIBUTION_PACKAGING_PLAN.md](./docs/DISTRIBUTION_PACKAGING_PLAN.md)
for the full packaging workflow.

## Core Commands

### Campaign

```text
new
newrun
sheet
modes
difficulty [name]
permadeath [on|off]
disciplines
discipline add [name]
section [n]
complete
history
stats [combat|survival]
campaign [books|combat|survival|milestones]
achievements [view]
help
quit
```

### Notes and Inventory

```text
inv
add [type name [qty]]
drop [type slot|all]
recover [type|all]
gold [delta]
notes
note [text]
note remove [n]
```

Examples:

```text
add backpack Potion of Laumspur
add special Sommerswerd
drop backpack 2
drop backpack all
recover backpack
note White Pass
note remove 1
```

### Survival and Manual Adjustments

```text
meal
potion
healcheck
end [delta]
setend [current]
setmaxend [max]
setcs
die [cause]
fail [cause]
rewind [n]
```

Use `end -1` for section damage and `end +1` for simple recovery without changing max END.

If you miss a book-completion discipline reward, you can recover it in-app with:

```text
discipline add
discipline add Mindblast
discipline add Mind Over Matter
```

### Combat

```text
combat start
combat round
combat next
combat auto
combat status
combat log [n|all|book n]
combat evade
combat stop
fight [enemy cs end]
mode [manual|data]
```

Quick examples:

```text
combat start Giak 12 10
combat auto
combat log all
combat log book 2
fight Giak 12 10
```

While combat is active, pressing `Enter` advances one round.

During combat setup, the app can also track enemy-specific effects like:

- `Mindforce`
  Applies its extra END loss automatically each round
  Checks `Mindshield` automatically and blocks the effect when owned
- `Knockout attempts`
  Available from Book 3 onward
  Edged weapons take `-2 Combat Skill`
  Unarmed combat, `Warhammer`, `Quarterstaff`, and `Mace` take no extra knockout penalty
  When the foe reaches zero END, the fight ends as a knockout instead of a kill

## Run Modes

Every run now has a locked difficulty profile. You choose it when the run begins, and it stays locked until you retire that run and start a fresh one with `newrun`.

Use these commands any time:

```text
modes
difficulty
permadeath
newrun
```

### Difficulties

- `Story`
  Prevents normal END loss from gameplay damage.
  Restores END to full between books.
  Uses universal and Story-only achievements.
  Cannot be combined with Permadeath.
- `Easy`
  Halves incoming END loss.
  Restores END to full between books.
  Uses universal achievements only.
- `Normal`
  Standard rules, including current END carryover between books.
  Uses the standard universal, combat, and exploration pool.
- `Hard`
  Halves the Sommerswerd combat bonus.
  Caps Healing at `10 END` restored per book.
  Keeps current END carryover between books.
  Enables challenge achievements.
- `Veteran`
  Uses Hard rules.
  Also requires the text to explicitly allow Sommerswerd power in each combat.
  Keeps current END carryover between books.
  Enables challenge achievements.

### Permadeath

- Can only be enabled when starting a run
- Cannot be turned off once chosen
- Deletes the save file when the character dies
- Disables rewind for that run
- Keeps the classic current-END carryover between books
- Unlocks Permadeath challenge achievements when the run stays clean

### Run Integrity

Locked run settings are signed inside the save. If a save is edited outside the app in a way that breaks that signature, the run is marked as tampered and challenge achievements are disabled for that run.

This is meant to keep challenge clears honest. It is tamper-evident, not copy protection.

## Combat Modes

### `DataFile`

Reads CRT results from `data/crt.json` and applies them automatically.

This is the smoother mode and supports full fight automation when the data file covers the needed ratios and rolls.

### `ManualCRT`

Still calculates the combat ratio and random number for you, but asks you to enter the losses from your own Combat Results Table.

This is useful if you want to rely on the printed book or a separately sourced table.

## Item Intelligence

Some items are now handled automatically instead of needing manual stat edits.

- `Shield`
  Adds `+2 Combat Skill`
- `Silver Helm`
  Counts as a Special Item that is treated as worn automatically
  Adds `+2 Combat Skill`
- `Helmet`
  Counts as a Special Item that is treated as worn automatically
  Adds `+2 Endurance`
  Does not stack with `Silver Helm`
- `Bone Sword`
  Counts as a normal weapon
  Gives `+1 Combat Skill` in Book 3 / Kalte only
- `Broadsword +1`
  Counts as a normal weapon
  Adds `+1 Combat Skill` in combat
  Still counts as a `Broadsword` for Weaponskill
- `Drodarin War Hammer`
  Counts as a normal weapon
  Adds `+1 Combat Skill` in combat
  Counts as a `Warhammer` for Weaponskill and knockout rules
- `Captain D'Val's Sword`
  Counts as a normal weapon
  Adds `+1 Combat Skill` in combat
  Counts as a `Sword` for Weaponskill
- `Chainmail Waistcoat` / `Chainmail Wastecoat`
  Adds `+4 Endurance`
- `Padded Leather Waistcoat` / `Padded Leather Wastecoat`
  Counts as a Special Item that is treated as worn automatically
  Adds `+2 Endurance`
- `Long Rope`
  Counts as a backpack item
  Uses `2` backpack slots instead of `1`
- `Shovel`, `Pick`, `Pickaxe`
  Count as backpack items
  Use `2` backpack slots each
- `Magic Spear`
  Counts as a weapon-like Special Item
  Counts as a `Spear` for Weaponskill
  Used automatically in the Book 2 Helghast fight at section `106`
- `Sommerswerd`
  Available from Book 2 onward
  Counts as a weapon-like Special Item
  Gives `+8 Combat Skill` in combat
  Gives `+10 total` if Weaponskill is `Short Sword`, `Sword`, or `Broadsword`
  Doubles enemy END loss against undead when active
- `Potion of Laumspur` / `Healing Potion`
  Restores `4 END`
- `Potent Laumspur Potion`
  Restores `5 END`
- `Concentrated Laumspur`
  Restores `8 END`
  The `potion` command prefers it first when available
- `Meal of Laumspur`
  Satisfies a Meal and restores `3 END`
  Can also be used with `potion` to restore `3 END`
- `Alether`
  Available from Book 3 onward
  Must be used before combat starts
  `combat start` can consume it from the backpack and grant `+4 Combat Skill` for that fight only
- `Special Rations`
  Count as Meal substitutes in Book 4
- `Potion of Red Liquid`
  Restores `4 END`
- `Map of the Southlands`, `Badge of Rank`, `Onyx Medallion`, `Flask of Holy Water`, `Scroll`, `Iron Key`, `Brass Key`, and `Dagger of Vashna`
  Are all recognized by name for Book 4 automation and achievement checks
- `Hourglass`
  Is recognized as a normal Backpack item for Book 4 loot handling
- `Captain D'Val's Sword`
  Is a recognized weapon for Book 4 story handling
  Also adds `+1 Combat Skill`
- `Whip`
  Is recognized as a Backpack item for Book 4 story handling

## Stats and Achievements

The app tracks live book stats and run history, including:

- sections visited
- winning-path section count
- END lost and regained
- gold gained and spent
- meals, Hunting meals, starvation hits
- potions used and potion END restored
- fights, wins, defeats, evades, and rounds fought
- highest enemy CS and END faced / defeated

It also supports hidden story achievements. The current batch now includes Book 1 routes, Book 2 route/story milestones, Book 3 section/discovery achievements, and the first full Book 4 route/story batch.
- fastest, easiest, and longest fights
- weapon usage and weapon victories
- Mindblast usage and wins
- deaths, rewinds, and manual recovery shortcuts

Commands:

```text
stats
stats combat
stats survival
achievements
achievements unlocked
achievements locked
achievements recent
achievements progress
achievements planned
```

Achievement availability depends on the active run mode:

- `Story`
  Universal + Story achievements
- `Easy`
  Universal achievements
- `Normal`
  Universal + Combat + Exploration achievements
- `Hard` / `Veteran`
  Universal + Combat + Exploration + Challenge achievements
- `Permadeath`
  Adds Permadeath challenge achievements when active on a clean run

## Campaign Review

Use the campaign screens when you want the whole-run picture instead of only the current book:

```text
campaign
campaign books
campaign combat
campaign survival
campaign milestones
```

This rolls up completed-book history together with the current in-progress book so you can review the entire run so far in one place.

## Replay Flow

If you want to replay the series on a new difficulty while keeping your profile achievements, use:

```text
newrun
```

This archives the current run, keeps your achievement profile, and starts a fresh run with a new locked difficulty and Permadeath choice.

## Death and Rewind Flow

Instant-death sections are handled with:

```text
die [cause]
```

Dead-end story failures are handled with:

```text
fail [cause]
```

After death or failure, the app can rewind to earlier safe section checkpoints:

```text
rewind
rewind 2
```

Rewind is only available while a death or failed mission state is active. This keeps normal play honest while still supporting the way Lone Wolf books often ask you to go back and choose another path after a fatal section or failed route.

## Book Progression

When you finish a book, use:

```text
complete
```

The app will:

- archive the completed book
- advance to the next book
- restore END to full
- reset section tracking for the new book
- offer the next Kai discipline if one is due
- show a completion summary with stats and an in-universe sendoff

## Save Compatibility

Save files are JSON-based and normalized on load so the project can evolve without constantly breaking older saves.

The app creates and updates runtime files during normal use:

- save JSON files in `saves/`
- backup saves when a manual patch is needed
- `data/last-save.txt`

## Recommended Play Flow

1. Run `new` or `load`.
2. If starting fresh, review `modes` and choose your run settings carefully.
3. Read the book normally.
4. Use `section`, `note`, `add`, `drop`, `gold`, `meal`, and `potion` as needed.
5. Use `combat start` or `fight` when combat begins.
6. Use `save` or autosave for checkpoints.
7. Use `complete` when you finish a book.
8. Use `newrun` when you want to start over on a new difficulty without losing your profile achievements.

## Notes

- The project is focused on being useful and fast in play, not academically complete.
- Book-specific exceptions still happen. Manual controls like `setcs`, `setend`, `setmaxend`, notes, and inventory edits are intentionally kept available.
- Item intelligence is still expanding as new items are encountered during playthroughs.
