# Book 8 Rules And Items Audit - 2026-04-30

Book: `8 - The Jungle of Horrors`

## Startup

- Book 8 requires the Magnakai ruleset and a five-discipline / Tutelary-rank floor.
- Weaponmastery should have five weapon selections by Book 8 if owned.
- Starting gold is random digit plus 10, capped at 50 Gold Crowns.
- Starting item choices match Book 7's pool: Sword, Bow, Quiver with 6 Arrows, Rope, Potion of Laumspur, Lantern, Mace, 3 Meals, Dagger, 3 Fireseeds.
- The section `1` `Pass` is mandatory and pocket-carried. The startup/entry safeguard now checks actual inventory, not just the story flag.

## Item Gains

| Section | Item | Slot | Support |
| --- | --- | --- | --- |
| `1` | Pass | Pocket Items | built |
| `7` | Silver Box | Backpack | built, optional choice |
| `139` | Grey Crystal Ring | Special Items | built |
| `202` | Lodestone | Special Items | built |
| `228` | Flask of Larnuma | Backpack | built, optional choice |
| `306` | Map of Tharro | Backpack | built, optional choice |
| `306` | 1 Meal | Backpack | built, optional choice |
| `306` | Axe | Weapons | built, optional choice |
| `312` | Giak Scroll | Pocket Items | built |

## Item Losses And Exchanges

| Section | Rule | Support |
| --- | --- | --- |
| `34` | spend a Meal as bait | built |
| `87` | Silver Bow of Duadon is destroyed | built |
| `242` | exchange Lodestone, Jewelled Mace, or Silver Helm for Grey Crystal Ring | built, prompted |
| `258` | current weapon destroyed by fireball | built, prompts if no current weapon is known |
| `269` | lose fourth Special Item, else fallback loss | built |
| `294` | give Paido one Meal if present | built |

## Gold And Currency

| Section / transition | Rule | Support |
| --- | --- | --- |
| `16` | 20 Lune converted to 5 Gold Crowns | built |
| `59` | 40 Lune converted to 10 Gold Crowns | built |
| `244 -> 20` | pay 20 Gold Crowns | built |
| `89 -> 266` | pay 10 Gold Crowns | built |
| `299 -> 266` | pay 10 Gold Crowns | built |
| `316 -> 139` | pay 30 Gold Crowns | built |
| `168` | Bowyery prices in Lune | manual |

## Discipline And Route Notes

- Huntmastery/Hunting covers normal Meal requirements.
- Section `39` notes the Divination plus Tutelary route.
- Section `156` applies wound damage and prompts the player to use Tincture of Oxydine or Oede herb if available.
- Section `242` is web-safe because it writes a numbered context payload before asking for the exchange choice.

## Known Manual Items

The audit intentionally leaves some broad market or optional-sale behavior manual. These cases are documented in the automation ledger so they are not mistaken for missed work.
