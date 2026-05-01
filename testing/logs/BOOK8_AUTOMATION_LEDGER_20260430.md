# Book 8 Automation Ledger - 2026-04-30

Book: `8 - The Jungle of Horrors`

Source sweep: `testing/tmp/book8_source_sweep.json`

Status legend:

- `built` means implemented in current workspace
- `manual` means intentionally left as player-managed
- `watch` means supported enough for now but worth checking during playtest

## Entry And Transition Automation

| Section / transition | Timing | Rule type | Preconditions | State change | Prompt | Web-safe context | Support | Acceptance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Book 7 complete -> Book 8 | after book transition | campaign transition | current book is 7 | advances to Book 8, section 1 | yes, startup choices | existing prompt-backed transition | built | parse smoke, rules smoke |
| Book 8 startup | after book transition / new run | setup | Book 8 selected | Magnakai rank/discipline floor, lore bonuses, starting gold, starting gear, Pass | yes | existing prompt-backed setup | built | parse smoke |
| `1` | on entry after text | item gain | Book 8 section 1 | add `Pass` to pocket items | no | no prompt | built | `book8-rules-smoke.ps1` |
| `244 -> 20` | after transition | gold spend | enough Gold Crowns | spend 20 Gold | no | no prompt | built | targeted by transition hook |
| `89 -> 266` | after transition | gold spend | enough Gold Crowns | spend 10 Gold | no | no prompt | built | targeted by transition hook |
| `299 -> 266` | after transition | gold spend | enough Gold Crowns | spend 10 Gold | no | no prompt | built | targeted by transition hook |
| `316 -> 139` | after transition | gold spend | enough Gold Crowns | spend 30 Gold | no | no prompt | built | targeted by transition hook |

## Inventory, Gold, Meals, And Recovery

| Section | Timing | Rule type | Preconditions | State change | Prompt | Web-safe context | Support | Acceptance |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `7` | on entry after text | optional pickup | reached Conundrum prize | optional `Silver Box` backpack item | yes | choice list | built | choice-table pattern |
| `16` | on entry after text | gold reward | not already claimed | add 5 Gold Crowns for 20 Lune | no | no prompt | built | `book8-rules-smoke.ps1` |
| `34` | on entry after text | meal spend | has Meal | remove 1 Meal | no | no prompt | built | ledger-only |
| `59` | on entry after text | gold reward | not already claimed | add 10 Gold Crowns for 40 Lune | no | no prompt | built | ledger-only |
| `87` | on entry after text | forced loss | has Silver Bow of Duadon | remove Silver Bow | no | no prompt | built | ledger-only |
| `105` | on entry after text | meal requirement | no Huntmastery/Hunting cover | consume Meal or lose 3 END | no | no prompt | built | `book8-rules-smoke.ps1` |
| `129` | on entry after text | meal requirement | no Huntmastery/Hunting cover | consume Meal or lose 3 END | no | no prompt | built | ledger-only |
| `139` | on entry after text | item gain | not already claimed | add `Grey Crystal Ring` special item | no | no prompt | built | ledger-only |
| `150` | on entry after text | meal requirement | no Huntmastery/Hunting cover | consume Meal or lose 3 END | no | no prompt | built | ledger-only |
| `152` | on entry after text | meal requirement | no Huntmastery/Hunting cover | consume Meal or lose 3 END | no | no prompt | built | ledger-only |
| `170` | on entry after text | meal requirement | no Huntmastery/Hunting cover | consume Meal or lose 3 END | no | no prompt | built | ledger-only |
| `175` | on entry after text | meal requirement | no Huntmastery/Hunting cover | consume Meal or lose 3 END | no | no prompt | built | ledger-only |
| `201` | on entry after text | optional loot | reached chamber | Sword, Bow, 3 Arrows, 2 Meals | yes | choice list | built | choice-table pattern |
| `202` | on entry after text | item gain | not already claimed | add `Lodestone` special item | no | no prompt | built | ledger-only |
| `226` | on entry after text | damage plus meal | reached section | lose 3 END, then meal/no-meal handling | no | no prompt | built | ledger-only |
| `228` | on entry after text | optional pickup | reached section | optional `Flask of Larnuma` backpack item | yes | choice list | built | choice-table pattern |
| `242` | on entry after text | item exchange | has Lodestone, Jewelled Mace, or Silver Helm | exchange one for Grey Crystal Ring | yes | numbered eligible item list | built | prompt-backed |
| `258` | on entry after text | damage plus weapon loss | reached section | lose 8 END, remove current/selected weapon | sometimes | weapon slot prompt if needed | built | ledger-only |
| `269` | on entry after text | riddle penalty | failed riddle route | remove 4th Special Item, else last Special, else first Backpack | no | no prompt | built | `book8-rules-smoke.ps1` |
| `294` | on entry after text | meal spend | has Meal | remove 1 Meal for Paido | no | no prompt | built | ledger-only |
| `306` | on entry after text | optional loot | reached mill chest | Map of Tharro, 1 Meal, Axe | yes | choice list | built | choice-table pattern |
| `312` | on entry after text | item gain | not already claimed | add `Giak Scroll` pocket item | no | no prompt | built | ledger-only |

## Endurance Changes

| Section | Timing | Rule type | State change | Support |
| --- | --- | --- | --- | --- |
| `15` | on entry after text | damage | lose 2 END | built |
| `39` | on entry after text | damage | lose 8 END | built |
| `40` | on entry after text | damage | lose 2 END | built |
| `86` | after random roll | damage | lose adjusted roll, 0 counts as 10 | built |
| `100` | on entry after text | recovery | restore ENDURANCE to max | built |
| `104` | on entry after text | damage | lose 2 END | built |
| `115` | on entry after text | damage | lose 8 END | built |
| `146` | on entry after text | damage | lose 5 END | built |
| `156` | on entry after text | damage | lose 6 END, cure note remains player action | built |
| `159` | on entry after text | damage | lose 5 END before Kezoor | built |
| `226` | on entry after text | damage | lose 3 END before meal handling | built |
| `230` | on entry after text | damage | lose 8 END | built |
| `258` | on entry after text | damage | lose 8 END | built |
| `274` | on entry after text | recovery | gain 3 END | built |
| `325` | on entry after text | damage | lose 3 END | built |
| `337` | on entry after text | damage | lose 3 END | built |

## Manual / Watch Items

| Section | Reason | Status |
| --- | --- | --- |
| `139` optional sale of other Special Items | broad player choice and price bookkeeping; easy manual command | manual |
| `168` Bowyery shop | Lune subcurrency and multiple item classes make full automation higher risk | manual |
| `228` Flask of Larnuma later use | stored as item; two later draught uses are player-managed for now | watch |
| two-Vordak combats at `13` and `287` | engine starts first fight and warns user to start second manually | watch |
