# Magnakai Book 6 Transition Plan

This doc captures the planned transition from the Kai ruleset to the Magnakai ruleset beginning with Book `6` (`The Kingdoms of Terror`).

It is a planning document only. It does not mean Book `6` is already implemented.

## Why Book 6 Is A Real Ruleset Shift

Book `6` is not just "the next book."

It changes the player model in ways that the current Kai-only app does not yet represent cleanly:

- the active ruleset changes from `Kai` to `Magnakai`
- Lone Wolf is assumed to have mastered all ten basic Kai Disciplines
- the player now chooses `3` starting Magnakai Disciplines
- the Magnakai rank ladder starts at `Kai Master Superior`
- `Weaponmastery` replaces `Weaponskill` and tracks multiple mastered weapons
- `Lore-circles` grant permanent `CS` / `ENDURANCE` bonuses when completed
- `Psi-surge` and `Mindblast` have a new relationship
- `Psi-screen` replaces `Mindshield` as the relevant anti-Mindforce rule
- future Magnakai books introduce `Improved Disciplines`

This means Book `6` should be treated as the first implementation pass for a second live ruleset, not as a normal Book `N+1` feature drop.

## What Book 6 Requires

## 1. New Ruleset Registration

Add a real Magnakai ruleset alongside Kai:

- `modules/rulesets/magnakai/magnakai.psm1`
- `modules/rulesets/magnakai/book6.psm1`

Update the ruleset dispatcher so it can route:

- section-entry rules
- startup equipment
- random-number context
- story triggers
- transition logic

The current ruleset engine already dispatches by `RuleSet`, so this is an extension of shipped architecture, not a redesign.

## 2. Character State Expansion

The current state shape is still strongly Kai-flavoured:

- `Character.Disciplines`
- `Character.WeaponskillWeapon`
- Kai-rank formatting

Book `6` needs the state model to become ruleset-neutral.

Planned additions:

- `Character.MagnakaiDisciplines`
- `Character.MagnakaiRank`
- `Character.WeaponmasteryWeapons`
- `Character.LoreCirclesCompleted`
- `Character.ImprovedDisciplines`
- `Character.LegacyKaiComplete`

Planned compatibility rule:

- keep old Kai saves loading cleanly
- normalize missing Magnakai fields only when the ruleset is `Magnakai`

## 3. Book 5 To Book 6 Transition Logic

The Book `5` -> Book `6` bridge is the most important part of the whole effort.

Required behavior:

- offer the player a true `continue into Magnakai` path after Book `5`
- switch `RuleSet` from `Kai` to `Magnakai`
- preserve current `COMBAT SKILL` and `ENDURANCE`
- preserve Weapons and Special Items from the previous adventure
- apply Book `6` startup gold roll: `random + 10`
- auto-add `Map of the Stornlands`
- let the player choose `5` Book `6` starting items
- let the player choose `3` starting Magnakai Disciplines
- if `Weaponmastery` is chosen, let the player pick `3` mastered weapons

Important carry-over note from the Book `6` rules text:

- the baseline rules explicitly mention carrying over Weapons and Special Items
- they do **not** explicitly grant blanket carry-over for Backpack Items

That means the transition likely needs a deliberate Book `6` carry-over rule instead of blindly preserving the Book `5` Backpack.

This is one of the biggest design-sensitive points to confirm during the full Book `6` audit/build pass.

## 4. Magnakai Discipline Engine

Book `6` introduces ten Magnakai Disciplines:

- `Weaponmastery`
- `Animal Control`
- `Curing`
- `Invisibility`
- `Huntmastery`
- `Pathsmanship`
- `Psi-surge`
- `Psi-screen`
- `Nexus`
- `Divination`

Planned handling:

- store Magnakai disciplines separately from legacy Kai state
- make discipline checks ruleset-aware
- make help/sheet/command text ruleset-aware

Key rule differences that need engine support:

- `Weaponmastery`
  - `+3 CS` with mastered melee weapon
  - `+3` to random-number picks when using `Bow`
  - starts with `3` mastered weapons at Kai Master Superior
- `Curing`
  - same healing cadence as Kai `Healing`
  - also identifies herbs / potions and cures specific conditions in text
- `Huntmastery`
  - expands survival coverage into wasteland and desert
  - ignores surprise / ambush CS penalties
- `Psi-surge`
  - `+4 CS`
  - `-2 END` each round
  - cannot be used at `6 END` or lower
  - weaker `Mindblast` still exists as `+2`
  - cannot stack `Psi-surge` and `Mindblast`
- `Psi-screen`
  - blocks Mindforce loss
- `Nexus`
  - prevents climate/extreme-temperature losses
- `Lore-circles`
  - apply permanent base bonuses, not temporary combat notes

## 5. Lore-circle Tracking

Book `6` makes Lore-circles a real progression system:

- `Circle of Fire`
  - `Weaponmastery` + `Huntmastery`
  - `+1 CS`, `+2 END`
- `Circle of Light`
  - `Animal Control` + `Curing`
  - `+0 CS`, `+3 END`
- `Circle of Solaris`
  - `Invisibility` + `Huntmastery` + `Pathsmanship`
  - `+1 CS`, `+3 END`
- `Circle of the Spirit`
  - `Psi-surge` + `Psi-screen` + `Nexus` + `Divination`
  - `+3 CS`, `+3 END`

Planned app behavior:

- detect completed circles automatically
- permanently apply the correct bonus to base stats
- show circle completion on the character sheet
- prepare this data to carry through Books `6-12`

## 6. Weaponmastery And Archery Tracking

Book `6` raises the importance of ranged checks and weapon specialization.

Planned support:

- `WeaponmasteryWeapons` checklist on the sheet
- `Quiver` as a Special Item with `Arrow` count tracking
- ruleset-aware Bow-shot random-number modifiers
- special handling for Book `6` archery tournament text
- future-safe support for weapon-mastery additions after each completed Magnakai book

This is an area where Book `6` should push the item model further than the current Kai-era implementation.

## 7. Sheet And Command-Surface Changes

The current sheet is Kai-shaped:

- `Kai Rank`
- `Kai Disciplines`
- `Weaponskill`

Book `6` needs a Magnakai-shaped view.

Planned visible changes:

- `Rule Set : Magnakai`
- `Rank : Kai Master Superior`
- `Magnakai Disciplines`
- `Weaponmastery`
- `Lore-circles`
- `Improved Disciplines`
- `Legacy Kai : mastered`

Commands/help text that should become ruleset-aware:

- `new`
- `newrun`
- `disciplines`
- `discipline add`
- startup prompts
- rule explanations during combat and random-number checks

## 8. Data Files

Expected new data assets:

- `data/magnakai-disciplines.json`
- `data/magnakai-ranks.json`
- `data/magnakai-lore-circles.json`
- optional:
  - `data/magnakai-weaponmastery-weapons.json`

These should keep rule text out of the main code where practical.

## 9. Book 6 Audit Scope

Once the ruleset transition layer exists, Book `6` still needs the normal content pass:

- route families
- endings
- startup package
- items
- special combat rules
- random-number modifiers
- one-off section automation
- achievements
- strategy guide

So Book `6` work naturally splits into:

1. ruleset transition
2. Book `6` full audit
3. Book `6` build

## 10. Validation Bar

Book `6` should not ship until all of these are true:

- standalone Book `6` new-game flow works
- Book `5` -> `6` carry-over flow works
- existing Kai saves still load without drift
- commands and sheet are ruleset-aware
- validation passes in PowerShell `5.1` and PowerShell `7`
- `100+` sandbox tests of the command surface and actual app pass across the full Books `1-6` campaign

## Planned Sheet Mockup

This is the intended direction for the first Magnakai-shaped sheet.

```text
+----------------------------------------------------+
| Character Sheet                                    |
+----------------------------------------------------+
  Name            : Lone Wolf
  Rule Set        : Magnakai
  Book            : 6 - The Kingdoms of Terror
  Rank            : Kai Master Superior
  Legacy Kai      : mastered
  Combat Skill    : 29
  Endurance       : 31 / 31
  Gold Crowns     : 37/50
  Completed Books : 1-5

+----------------------------------------------------+
| Magnakai Disciplines                               |
+----------------------------------------------------+
  - Weaponmastery
  - Huntmastery
  - Psi-screen

+----------------------------------------------------+
| Weaponmastery                                      |
+----------------------------------------------------+
  - Sword
  - Bow
  - Quarterstaff

+----------------------------------------------------+
| Lore-circles                                       |
+----------------------------------------------------+
  Circle of Fire    : partial   (Weaponmastery, Huntmastery)
  Circle of Light   : empty     (Animal Control, Curing)
  Circle of Solaris : partial   (Invisibility, Huntmastery, Pathsmanship)
  Circle of Spirit  : partial   (Psi-surge, Psi-screen, Nexus, Divination)

+----------------------------------------------------+
| Improved Disciplines                               |
+----------------------------------------------------+
  - none yet

+----------------------------------------------------+
| Inventory                                          |
+----------------------------------------------------+
  Weapons         : 2/2  Sommerswerd, Sword
  Backpack        : 5/8  Potion of Laumspur, Rope, Special Rations x3
  Special Items   : 7/12  Book of the Magnakai, Map of the Stornlands, ...
```

Sheet design goals:

- keep the current compact screen style
- make the active ruleset obvious at a glance
- separate legacy Kai status from live Magnakai mechanics
- give Lore-circles and Weaponmastery a permanent home instead of burying them in notes
- leave room for later Books `7-12` improved-discipline growth

## Recommended M2 Slice Order

### M2.1 - Magnakai Ruleset Shell

- add `modules/rulesets/magnakai/`
- register Magnakai in ruleset dispatch

### M2.2 - Ruleset-Neutral Character State

- add Magnakai fields
- make save normalization ruleset-aware
- keep Kai compatibility intact

### M2.3 - Book 5 -> Book 6 Transition

- preserve valid carry-over state
- add Book `6` startup flow
- choose `3` disciplines
- choose `3` Weaponmastery weapons when needed

### M2.4 - Magnakai Sheet And Command Surface

- ruleset-aware sheet
- ruleset-aware discipline screens and command help

### M2.5 - Magnakai Combat And Discipline Rules

- Weaponmastery
- Psi-surge / Mindblast
- Psi-screen
- Huntmastery
- Nexus
- Lore-circle bonus engine

### M2.6 - Book 6 Full Audit + Build

- normal book audit and implementation pass
- Book `6` achievements and strategy guide

### M2.7 - Full Validation

- PowerShell `5.1`
- PowerShell `7`
- Books `1-6` campaign testing
- `100+` sandbox runs across command surface and actual app flow
