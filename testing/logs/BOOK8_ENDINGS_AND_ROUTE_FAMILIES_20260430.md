# Book 8 Endings And Route Families - 2026-04-30

Book: `8 - The Jungle of Horrors`

Local source: `books/lw/08tjoh`

Mechanical sweep artifact: `testing/tmp/book8_source_sweep.json`

## Route Shape

Book 8 is a travel-and-survival Magnakai book. The successful arc moves from the opening mission into the Hellswamp and the Danarg, then through the Ohrido Lorestone and the Levitron escape route.

The main route pressure points are:

- the `Pass` at section `1`
- Count Conundrum's riddle chain through `126 -> 16`, `141 -> 59`, and `338 -> 7`
- the Lodestone and Grey Crystal Ring branch around `202`, `242`, and `139`
- the Lorestone of Ohrido at `100`
- the Levitron escape route through `267 -> 350`

## Success Ending

| Section | Meaning | Notes |
| --- | --- | --- |
| `350` | Book complete | Entered only from `267` in the route graph. Marks Book 8 complete and closes the current Magnakai campaign span supported by the app. |

## Failure Endings

Terminal non-success sections found by route sweep:

`21`, `51`, `57`, `69`, `75`, `121`, `134`, `154`, `158`, `165`, `200`, `222`, `223`, `237`, `263`, `281`, `295`, `322`

Section `281` is achievement-worthy because it is the distinctive poison/jungle horror failure path.

## Direct-Answer / Riddle Sections

The route graph has five direct-link-unreachable sections:

`3`, `7`, `16`, `59`, `181`

These are not broken links. They are riddle/direct-answer or special access destinations.

## Route Families

| Route family | Core sections | App support |
| --- | --- | --- |
| Ohrido Lorestone | `100` | Story flag and achievement support added. ENDURANCE restores to max on entry. |
| Count Conundrum | `126 -> 16`, `141 -> 59`, `338 -> 7` | Transition flags, section rewards, and Silver Box choice support added. |
| Grey Crystal Ring | `202`, `242`, `139` | Lodestone pickup, prompted exchange, direct ring pickup, and achievement support added. |
| Levitron escape | `18`, `267`, `350` | Random context for `18`, route flags, and completion support added. |
| Poison failure | `281` | Instant failure and achievement flag support added. |

## Build Notes

- `Get-LWBookNumberFromTitle` now recognizes titles beyond Book 5.
- New-game and book-complete flows accept Book 8.
- Book 7 completion can now transition into Book 8.
- Book 8 startup selects five Magnakai disciplines/rank support, Weaponmastery weapon count, starting gold, starting item choices, and the mandatory `Pass`.
