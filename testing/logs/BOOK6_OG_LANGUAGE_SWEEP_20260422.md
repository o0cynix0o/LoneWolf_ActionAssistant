# Book 6 OG Section Language Sweep

Date: 2026-04-22

Source corpus:
- `C:\Scripts\Lone Wolf\books\lw\06tkot\sect1.htm` through `sect350.htm`

Comparison target:
- `C:\Scripts\Lone Wolf\modules\rulesets\magnakai\book6.psm1`
- `C:\Scripts\Lone Wolf\modules\rulesets\magnakai\combat.psm1`
- prior focused audit:
  - `testing/logs/BOOK6_AUTOMATION_AUDIT_20260415.md`

## Purpose

This pass widens the Book `6` review beyond the earlier high-confidence audit.

The `2026-04-15` audit correctly covered the strongest objective rules work:
- instant death
- direct ENDURANCE changes
- random-number helpers
- inventory/currency changes that were already treated as high-value
- combat exceptions

This `2026-04-22` sweep re-read all `350` original sections specifically for broader automation language:
- pay / buy / sell text
- item claim / mark-it-on-the-Action-Chart text
- source-side payment prompts that lead to a later reward section
- route gates based on items or disciplines
- other medium-value guided-choice surfaces

## Summary

- All `350` original Book `6` sections were re-checked in the local `06tkot` corpus.
- The earlier high-confidence audit still looks sound for combat, ENDURANCE, random, and hard-rule coverage.
- The broader OG wording sweep found a small set of source-side payment sections that are still good automation candidates even though they were outside the earlier `77`-candidate table.
- The clearest current OG follow-up candidates are:
  - section `27`
  - section `137`
  - section `165`
  - section `273`
  - section `328`
- Sections `27` and `273` are really the same missing Cess-purchase flow viewed from two entry points.

## Clear OG Follow-Up Candidates

### 1. Section 27 -> Section 304 Cess purchase

OG text:
- section `27` offers a direct `3` Gold Crown payment for a `Cess`
- the player then turns to section `304`

Current `main` state:
- section `304` is already automated to add the `Cess`
- section `27` itself is not currently referenced in `book6.psm1`

Why it matters:
- current `main` can add the `Cess` at section `304`
- but it does not help with the source-side `3` Gold Crown deduction at section `27`

Recommended treatment:
- add a small section `27` payment prompt
- if paid, deduct `3` Gold Crowns and direct the player onward to `304`
- if declined, leave the route manual as written

### 2. Section 273 -> Section 304 Cess purchase

OG text:
- section `273` explains what a `Cess` is
- it then offers the same `3` Gold Crown purchase that leads to section `304`

Current `main` state:
- section `304` adds the `Cess`
- section `273` itself is not currently referenced in `book6.psm1`

Why it matters:
- this is the second source-side entry to the same missing payment flow
- it should probably be implemented together with section `27`

Recommended treatment:
- share one helper for the `27` / `273` Cess-purchase source flow
- keep section `304` as the item-claim destination

### 3. Section 165 -> Section 16 Map of Varetta purchase

OG text:
- section `165` offers a `Map of Varetta` for `5` Gold Crowns
- the player pays there and then turns to section `16`
- section `16` is where the map is marked as a Special Item

Current `main` state:
- `Map of Varetta` is already modeled
- current `main` adds it from section `8`
- section `165` is not currently referenced in `book6.psm1`
- section `16` is also not currently referenced for this purchase flow

Why it matters:
- this is a clean OG item-purchase flow with both:
  - a source-side payment
  - a destination-side item claim

Recommended treatment:
- add a section `165` purchase prompt for the `5` Gold Crown payment
- optionally add a section `16` safety hook so the map claim is not missed if the player arrives there from this route

### 4. Section 137 Quarlen levy

OG text:
- section `137` requires `3` Gold Crowns to enter town
- paying sends the player to section `332`

Current `main` state:
- section `137` is not currently referenced in `book6.psm1`
- section `332` is just the arrival/setup section that routes into later tavern choices

Why it matters:
- this is a simple but objective source-side Gold deduction
- there is no downstream hook currently offsetting the payment

Recommended treatment:
- add a lightweight section `137` levy prompt
- deduct `3` Gold Crowns when the player takes the paid route

### 5. Section 328 roast-beef meal purchase

OG text:
- section `328` charges `2` Gold Crowns for food
- the player is told to deduct the gold before turning to section `219`

Current `main` state:
- section `328` is not currently referenced in `book6.psm1`
- section `219` is a route gate based on whether you have a Bow

Why it matters:
- this is another clean source-side cost with no current hook
- lower impact than the Cess or map flows, but still a real accounting gap

Recommended treatment:
- add a small section `328` gold-deduction hook

## Already Covered But Outside The Old High-Confidence Table

These are worth noting because the older audit intentionally under-counted medium-value automation:

- section `10`
  - riverboat ticket purchase prompt is already implemented on `main`
- section `212`
  - horse-trade payment resolution is already implemented on `main`
- section `275`
  - the OG map-buy flow is now implemented on `main`
  - note: current `main` also carries later DE-facing cartographer resale support beyond the OG wording
- section `304`
  - Cess item claim is already implemented on `main`

## Lower-Priority Route / Guidance Candidates

These sections do contain automation-related language, but they look more like guided routing or conditional prompts than urgent missing rules:

- section `96`
  - Cess possession gate at Amory
- section `169`
  - Lore-circle of Fire route gate
- section `205`
  - Huntmastery effectively auto-picks the safer bow route
- section `211`
  - Map of Varetta route gate
- section `248`
  - attack / Invisibility route gate
- section `295`
  - Sommerswerd route gate
- section `316`
  - surrender-all-gold versus fight choice before the section `161` death route
- section `318`
  - Animal Control route gate

These feel like:
- useful future command-surface guidance targets
- but lower priority than the missing source-side payment/item flows above

## Notable Non-Issues From This Sweep

Some sections mention money or items but do not look like missing automation after comparison:

- section `102`
  - setup/signboard text for the section `10` riverboat-ticket purchase flow already implemented on `main`
- sections `132` and `148`
  - both feed the already-implemented section `212` horse trade
- section `134`
  - mentions the Denka Gate toll in narrative setup, but the real route handling happens later
- sections `331`, `332`, and `333`
  - setup / routing / interrupted-gift text rather than missing accounting hooks by themselves

## Practical Takeaway

If we want to act on this sweep, the cleanest OG follow-up bundle would be:

1. section `27` / `273` Cess purchase source handling
2. section `165` / `16` Map of Varetta purchase handling
3. section `137` levy deduction
4. section `328` meal deduction

That would close the strongest remaining original-text accounting gaps without reopening the entire Book `6` ruleset.
