# Full Book Audit Workflow

This is the standard workflow for auditing a Lone Wolf book the same way across the series.

Use this when the task is:

- read the book
- map the routes
- find missing items
- find missing rules and one-off exceptions
- propose route/exploration/story achievements
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
- validation
- commit and push

## Source Material

Use official Project Aon sources as the primary book reference:

- the book text
- the relevant errata page, if it exists

Do not copy large passages into committed docs.

## Expected Local Report Outputs

For each book, the audit should usually produce:

- `BOOKX_ENDINGS_AND_ROUTE_FAMILIES.md`
- `BOOKX_RULES_AND_ITEMS_AUDIT.md`
- `BOOKX_ACHIEVEMENT_CANDIDATES.md`

These are local working reports and normally stay in `logs/`.

## Audit Steps

### 1. Read The Book Text

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

### 3. Audit Missing Rules And Items

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

## 4. Compare Against The App

Check the current script and docs so the audit distinguishes:

- what the book contains
- what the app already knows
- what still needs implementation

This avoids duplicate work and keeps the report honest.

## 5. Draft Achievement Candidates

Propose a first batch of:

- route achievements
- exploration achievements
- story achievements
- item/discovery achievements

Good achievement candidates are:

- memorable
- triggerable from reliable state
- not dependent on large copied book text

## 6. Write The Reports

Summarize:

- endings and route families
- missing rules/items
- top implementation candidates
- achievement candidates

These reports should be enough for a later chat to continue without re-reading the entire conversation.

## 7. Propose The Top Build Candidates

Before implementation, summarize:

- the best missing rules to automate
- the best achievement batch to add
- any assumptions or ambiguities

If a rule is unclear or too one-off, prefer calling that out instead of forcing premature automation.

## 8. Implement Approved Findings

If the user approves build-out:

- add rule/item support
- add achievement definitions and triggers
- update public docs if behavior changed

Prefer integrating with existing helpers instead of inventing one-off branches when possible.

## 9. Validate In Both Shells

Always run parse or targeted validation in:

- Windows PowerShell 5.1
- PowerShell 7

Where useful, add small harness checks for the new rules.

## 10. Commit And Push

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

## Success Condition

The audit is successful when another chat can pick up the book with:

- the route picture
- the missing rule list
- the item list
- the achievement plan
- the local report files

without needing the original conversation.
