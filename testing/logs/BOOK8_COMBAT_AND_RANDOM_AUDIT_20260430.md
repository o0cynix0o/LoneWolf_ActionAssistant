# Book 8 Combat And Random Audit - 2026-04-30

Book: `8 - The Jungle of Horrors`

## Combat Sections

Combat sections found by sweep:

`8`, `13`, `30`, `38`, `40`, `41`, `47`, `52`, `74`, `88`, `101`, `106`, `110`, `155`, `159`, `162`, `164`, `169`, `183`, `199`, `205`, `231`, `233`, `241`, `251`, `252`, `257`, `265`, `287`, `298`, `305`, `308`, `313`, `323`, `333`, `339`, `346`

## Combat Exception Support

| Section | Enemy / rule family | Special handling | Support |
| --- | --- | --- | --- |
| `8`, `13`, `101`, `169`, `287` | Vordaks | undead, Mindblast immune unless Psi-surge, Psi-screen penalties where relevant | built |
| `30`, `47`, `183`, `308`, `346` | Helghasts | Mindforce, Psi-screen block, Spirit lore +2, Sommerswerd double where applicable | built |
| `52` | Taan-spider | Lone Wolf ENDURANCE losses doubled; Mindblast/Psi-surge bonuses tripled | built |
| `74` | Korkuna | psychic combat approximates fixed current CS 15 and suppresses gear | built |
| `155` | Silver Swamp Python | Curing at Primate protection, otherwise double Lone Wolf losses | built |
| `159`, `199` | Kezoor | immune to Mindblast/Psi-surge; Paido absorbs half losses after victory | built |
| `251` | Bourn | ignore first-round Lone Wolf ENDURANCE loss | built |
| `252`, `323` | Xlorg / monks routes | unarmed first two rounds where required, route notes | built |
| `257` | Boran | two-round outcome threshold | built |
| `298` | Ghagrim | Huntmastery first-two-round modifier | built |
| `313` | Xlorg | Huntmastery penalty support | built |
| `333` | Vordak | Psi-screen penalty support | built |
| `339` | swamp gas fight | Nexus at Primate protection, evade route | built |

Sections `13` and `287` are watch items. They represent two sequential Vordak combats. Current support starts the first fight, records the route thresholds, and warns the player to start the second fight manually.

## Random Number Contexts

Random-number sections found by sweep:

`17`, `18`, `28`, `45`, `54`, `77`, `86`, `102`, `117`, `122`, `176`, `209`, `246`, `284`, `296`, `310`

| Section | Context | Modifiers / special behavior | Support |
| --- | --- | --- | --- |
| `17` | infection resistance | Fire or Light lore circle +3 | built |
| `18` | Levitron boarding escape | Animal Control/Huntmastery +3, Primate +2 | built |
| `28` | street pursuit | plain check | built |
| `45` | hide from Helghast | Invisibility +3 | built |
| `54` | Danarg tracking | Huntmastery or Divination +3 | built |
| `77` | cabin disease | Huntmastery +2 | built |
| `86` | Grey Crystal Ring backlash | 0 counts as 10, damage applies after roll | built |
| `102` | swamp route | plain check | built |
| `117` | bowyer ambush | Huntmastery +3, Divination at Primate +1 | built |
| `122` | crossbow ambush | Huntmastery +2 | built |
| `176` | crossbow ambush | Huntmastery +3 | built |
| `209` | horse control | Animal Control +3 | built |
| `246` | bow shot | Weaponmastery with Bow +3 | built |
| `284` | Bor Brew collapse | Primate +3 | built |
| `296` | poison path | Huntmastery at Primate +3 | built |
| `310` | bow shot | Weaponmastery with Bow +3 | built |

## Validation

- `testing/tmp/book8-rules-smoke.ps1`
- PowerShell 7: passed
- Windows PowerShell 5.1: passed
