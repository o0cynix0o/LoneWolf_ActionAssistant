# Full Book Audit Workflow

This is the standard workflow for auditing a Lone Wolf book the same way across the series.

Use this when the task is:

- read the book
- map the routes
- find missing items
- find missing rules and one-off exceptions
- create structured automation ledgers
- propose route/exploration/story achievements
- draft or update player-facing strategy-guide material
- write repeatable local reports

## Standard Request Phrases

- `Run the Full Book Audit for Book X`
- `Run the Full Book Audit + Build for Book X`

The first means analysis and reports only.

The second means:

- analysis
- reports
- proposal
- implementation of approved findings
- strategy-guide draft/update
- wiki/public tracking sync
- validation
- commit and push

## Source Material

Use the local book corpus first:

- `books/lw/`

For Lone Wolf book audits, the preferred source order is:

1. local corpus under `books/lw/<book-code>/`
2. local supporting pages in the same folder such as:
   - `gamerulz.htm`
   - `footnotz.htm`
   - `equipmnt.htm`
   - `action.htm`
   - `random.htm`
3. Project Aon text and errata as fallback, cross-check, or gap filler when the local corpus is missing something

The local corpus is the primary offline audit baseline because it gives:

- section files directly
- footnotes and rules pages locally
- faster section-to-section tracing
- a stable source base without web dependency

Do not copy large passages into committed docs.

See also:

- `docs/BOOK_SOURCE_MAP.md`

## Expected Local Report Outputs

For each book, the audit should usually produce:

- `BOOKX_AUTOMATION_LEDGER.md`
- `BOOKX_ENDINGS_AND_ROUTE_FAMILIES.md`
- `BOOKX_RULES_AND_ITEMS_AUDIT.md`
- `BOOKX_COMBAT_AND_RANDOM_AUDIT.md`
- `BOOKX_ACHIEVEMENT_CANDIDATES.md`

These are local working reports and normally stay in `testing/logs/`.

`BOOKX_AUTOMATION_LEDGER.md` is the build handoff. It should be structured enough that implementation can work from it without re-reading the whole book.

## Expected Public Tracking Outputs

When the user approves a real book build or significant book hardening, the public-tracking sweep should usually produce:

- a new or updated book-specific strategy guide in the wiki
- updates to the wiki guide index or support pages if project scope changed
- matching repo-tracked workflow/handoff updates when the book status materially changed

Use:

- `docs/STRATEGY_GUIDE_STYLE_GUIDE.md`

as the house style for the wiki guide itself.

## Audit Steps

### 1. Read The Book Text

Start in the local corpus:

- find the book folder under `books/lw/`
- use `title.htm` to confirm the book
- use `sect*.htm` for section text
- use `footnotz.htm`, `gamerulz.htm`, and `equipmnt.htm` for supporting rules and item context

Only fall back to Project Aon if:

- the local corpus file is missing
- the local copy appears incomplete or malformed
- you need to cross-check a suspected difference

When a Definitive Edition difference is reported in live play, treat that as the correction layer over the Project Aon/local baseline.

Review the book and errata with an eye toward:

- branch points
- special item pickups
- discipline checks
- special combat rules
- permanent penalties or bonuses
- gear loss or forced inventory changes
- unique endings

### 2. Map Endings And Route Families

Identify:

- the success ending
- hard failure endings
- major winning route families
- any especially important companion/rescue dependencies

The goal is not to enumerate every tiny branch first. The goal is to understand the meaningful route families and the terminal outcomes.

### 3. Run A Mechanical Text Sweep

Before relying on memory from the read-through, run a machine-assisted sweep over every `sect*.htm` for automation language.

Useful search terms include:

- `lose`
- `gain`
- `erase`
- `add`
- `restore`
- `deduct`
- `discard`
- `eat a Meal`
- `Random Number Table`
- `if you possess`
- `if you have`
- `unless you have`
- `Combat Skill`
- `ENDURANCE`
- `turn to`

Treat the sweep as a candidate generator, not as truth. The human audit must still confirm context, timing, and whether the text describes an actual state change.

Record candidate sections in the automation ledger with:

- section
- source cue
- suspected rule type
- whether the cue was confirmed, rejected, or needs follow-up

### 4. Build The Section Automation Ledger

Create one row per candidate automation section.

Recommended columns:

- section
- trigger timing
- rule type
- preconditions
- state change
- prompt needed
- legal prompt values or choices
- web-safe payload needed
- current app support
- acceptance test needed
- status

Use consistent trigger timing labels:

- on entry before text
- on entry after text
- after combat
- after random roll
- after prompt choice
- after inventory choice
- after book transition
- manual only

This ledger is the main guardrail against missed build work. It should capture not just what the rule does, but when the player should see it happen.

### 5. Audit Missing Rules And Items

Scan for high-value automation candidates:

- items with bonuses or slot quirks
- section entry damage or healing
- forced gains/losses
- combat exceptions
- permanent stat changes
- book-specific restrictions

Mark each candidate as one of:

- already supported
- partly supported
- missing
- better left manual for now

Create a dedicated inventory delta table for:

- pickups
- losses
- forced drops
- confiscation and recovery
- safekeeping
- gold gains or losses
- backpack, quiver, and herb pouch changes
- container gain/loss
- weapon-like Special Items
- items with slot or capacity exceptions

### 6. Audit Combat Exceptions

Create a combat exception table for every combat found in the book.

Recommended columns:

- section
- enemy name
- enemy Combat Skill
- enemy ENDURANCE
- psychic rules
- weapon restrictions
- endurance multipliers
- evade rules
- auto-win or auto-loss conditions
- post-combat state changes
- current app support
- acceptance test needed

### 7. Audit Random Number And Prompt Flows

Create a random-number and prompt table for every roll or structured choice that should be supported by automation or the web UI.

Recommended columns:

- section
- prompt label
- visible option text
- legal values
- random number modifier
- zero-counts-as-ten behavior
- result mapping
- state changes
- web context text needed
- current app support
- acceptance test needed

This table should make unclear browser prompts visible before build work starts.

### 8. Compare Against The App

Check the current script and docs so the audit distinguishes:

- what the book contains
- what the app already knows
- what still needs implementation

This avoids duplicate work and keeps the report honest.

### 9. Draft Achievement Candidates

Propose a first batch of:

- route achievements
- exploration achievements
- story achievements
- item/discovery achievements

Good achievement candidates are:

- memorable
- triggerable from reliable state
- not dependent on large copied book text

### 10. Write The Reports

Summarize:

- endings and route families
- the automation ledger
- missing rules/items
- combat and random-number exceptions
- top implementation candidates
- achievement candidates

These reports should be enough for a later chat to continue without re-reading the entire conversation.

They should also leave enough route understanding behind to support a later strategy-guide draft without having to re-audit the whole book from scratch.

### 11. Propose The Top Build Candidates

Before implementation, summarize:

- the best missing rules to automate
- the best achievement batch to add
- any assumptions or ambiguities
- the build-ready acceptance checks for each proposed automation

If a rule is unclear or too one-off, prefer calling that out instead of forcing premature automation.

### 12. Implement Approved Findings

If the user approves build-out:

- add rule/item support
- add achievement definitions and triggers
- update public docs if behavior changed
- update the book strategy guide and related wiki scope pages when player-facing route/support state changed

Prefer integrating with existing helpers instead of inventing one-off branches when possible.

### 13. Draft Or Update The Strategy Guide

If the book is implemented, materially expanded, or route coverage changed enough to affect players:

- create or update the book-specific strategy guide in the wiki
- update the wiki guide index and any scope/support pages that now changed
- keep latest public release state separate from current `main` state when they differ
- follow `docs/STRATEGY_GUIDE_STYLE_GUIDE.md` so new guides read like article-style printed strategy guides rather than audit notes

Strategy-guide creation is part of book closeout, not a nice-to-have follow-up.

### 14. Validate In Both Shells

Always run parse or targeted validation in:

- Windows PowerShell 5.1
- PowerShell 7

Where useful, add small harness checks for the new rules.

For build work, each automated ledger row should either have:

- a passing targeted harness
- coverage in a broader route/combat/transition smoke
- a written reason it remains manual

### 15. Commit And Push

For Lone Wolf, completed work should normally be:

- committed
- pushed

Use a clear message describing the book and change set.

## What Usually Stays Manual

Leave rules manual when they are:

- too ambiguous from the text
- too isolated to justify code yet
- easy for the player to perform once without bookkeeping pain

Document them in the audit so they are not lost.

## What Usually Gets Automated First

Highest-value automation candidates are usually:

- item bonuses
- slot/capacity quirks
- section entry damage or gains
- permanent stat changes
- unique combat setup rules
- reliable story achievement triggers

## Naming Conventions

Reports:

- `BOOK1_*`
- `BOOK2_*`
- `BOOK3_*`

Keep names consistent so later chats can find them quickly.

## Source Hygiene

- treat `books/` as local reference material, not repo content
- do not commit the local book corpus
- keep committed docs focused on app behavior, route structure, and audit results rather than copied source text

## Success Condition

The audit is successful when another chat can pick up the book with:

- the route picture
- the missing rule list
- the item list
- the achievement plan
- the local report files
- the strategy-guide status
- the strategy-guide style standard

without needing the original conversation.
