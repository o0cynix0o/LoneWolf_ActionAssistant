# Lone Wolf Action Assistant

A PowerShell terminal companion for the Kai-era **Lone Wolf** gamebooks.

This project is built to act like a digital Action Chart and play aid, not a replacement for the books. It handles the bookkeeping that tends to slow play down: character state, inventory, combat math, saves, notes, healing, book progression, stats, and achievements.

## What It Does

- Screen-based terminal UI with ASCII banners and color-coded panels
- New Kai character creation with random starting Combat Skill and Endurance
- Book 1 start-package automation for Axe, Meal, Map of Sommerlund, random Gold, and the random monastery find
- Kai discipline selection, including Weaponskill weapon assignment
- Derived Kai rank titles from discipline count, shown on the sheet and campaign overview
- Inventory slot tracking for weapons (`2`), backpack items (`8`), special items (`12`), and gold
- Section tracking with Healing support for non-combat sections
- Meal handling with Hunting support, including Book 3 / Kalte restrictions
- Potion handling for:
  - Healing Potion / Laumspur Potion
  - Concentrated Laumspur
  - Book 1 Laumspur Herb
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
  - Drodarin War Hammer
  - Chainmail Waistcoat / Wastecoat
  - Padded Leather Waistcoat / Wastecoat
  - Long Rope
  - Sommerswerd
- Book 1 section-rule support for:
  - Vordak Gem handling
  - Burrowcrawler torch/darkness combat setup
  - Crystal Star Pendant carry-forward tracking
- JSON save/load with autosave support
- Numbered save picker and remembered last-used save
- Book completion summaries with live campaign stats
- Whole-run campaign review screens
- Achievement system with current unlocks, progress, and planned phase-two ideas
- Death tracking with death-only rewind checkpoints
- Locked run difficulties with Story, Easy, Normal, Hard, and Veteran rules
- Optional Permadeath runs with tamper-evident challenge tracking

## Scope

- Focused on the **Kai** ruleset
- Intended for use alongside the books
- Does **not** include book text
- Designed to stay flexible when book-specific exceptions come up

## Requirements

- Windows PowerShell `5.1` or PowerShell `7+`
- Windows terminal with color support recommended

## Project Files

- `lonewolf.ps1`
  Main terminal application
- `data/kai-disciplines.json`
  Kai discipline list and selection data
- `data/weaponskill-map.json`
  Weaponskill roll mapping
- `data/crt.json`
  Data-driven Combat Results Table used by `DataFile` mode
- `data/crt.template.json`
  Template CRT schema
- `data/last-save.txt`
  Last-used save path cache created by the app
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
  Uses universal and Story-only achievements.
  Cannot be combined with Permadeath.
- `Easy`
  Halves incoming END loss.
  Uses universal achievements only.
- `Normal`
  Standard rules.
  Uses the standard universal, combat, and exploration pool.
- `Hard`
  Halves the Sommerswerd combat bonus.
  Caps Healing at `10 END` restored per book.
  Enables challenge achievements.
- `Veteran`
  Uses Hard rules.
  Also requires the text to explicitly allow Sommerswerd power in each combat.
  Enables challenge achievements.

### Permadeath

- Can only be enabled when starting a run
- Cannot be turned off once chosen
- Deletes the save file when the character dies
- Disables rewind for that run
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
- `Chainmail Waistcoat` / `Chainmail Wastecoat`
  Adds `+4 Endurance`
- `Padded Leather Waistcoat` / `Padded Leather Wastecoat`
  Counts as a Special Item that is treated as worn automatically
  Adds `+2 Endurance`
- `Long Rope`
  Counts as a backpack item
  Uses `2` backpack slots instead of `1`
- `Sommerswerd`
  Available from Book 2 onward
  Counts as a weapon-like Special Item
  Gives `+8 Combat Skill` in combat
  Gives `+10 total` if Weaponskill is `Short Sword`, `Sword`, or `Broadsword`
  Doubles enemy END loss against undead when active
- `Potion of Laumspur` / `Healing Potion`
  Restores `4 END`
- `Concentrated Laumspur`
  Restores `8 END`
  The `potion` command prefers it first when available
- `Alether`
  Available from Book 3 onward
  Must be used before combat starts
  `combat start` can consume it from the backpack and grant `+4 Combat Skill` for that fight only

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

It also supports hidden story achievements. The current batch includes Book 1 route/discovery achievements and Book 3 section/discovery achievements, including the Diamond from section `218`.
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

After death, the app can rewind to earlier safe section checkpoints:

```text
rewind
rewind 2
```

Rewind is only available while dead. This keeps normal play honest while still supporting the way Lone Wolf books often ask you to go back and choose another path after a fatal section.

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
