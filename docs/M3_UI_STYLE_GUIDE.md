# M3 UI Style Guide

This document is the shared visual spec for `M3 - UX Polish Pass`.

It exists to keep the screen refresh consistent as the app is restyled one screen family at a time.

## Approved Direction

Approved style direction:

- `Arcade / GameFAQs Retro`

Approved on:

- `2026-04-07`

This direction was chosen because it best fits:

- terminal readability
- dense information display
- low visual clutter
- the project's gamebook / helper-tool feel

It is intentionally more practical than ornate.

## Core Principles

The UI should feel:

- compact
- readable
- game-like
- structured
- fast to scan

The UI should avoid:

- excessive decorative framing
- overly wide empty padding
- too many stacked panel breaks
- “fantasy novel” flourish that hurts legibility

## Shared Layout Rules

### 1. Banner Style

Use:

- one strong top banner for the current screen family
- simple block borders
- all-caps title text where it helps

Preferred model:

```text
+==============================================================+
| LONE WOLF ACTION ASSISTANT                                   |
| MAGNAKAI MODE :: BOOK 6 :: v0.8.0-dev                        |
+==============================================================+
```

Rules:

- banner should be compact
- avoid tall multi-line art unless the screen is ceremonial
- keep the app name readable before decorative

### 2. Panel Style

Use:

- rectangular `+-----+` panels
- centered or near-centered panel headers when practical
- compact single-line field rows

Preferred model:

```text
+---------------------- CHARACTER SHEET -----------------------+
| Name            : Lone Wolf                                  |
+--------------------------------------------------------------+
```

Rules:

- one visual border system across normal screens
- no mixing multiple border styles on the same screen
- keep panel widths consistent

### 3. Field Layout

Use:

- left-aligned labels
- single-space padding after `:`
- compact values

Preferred model:

```text
| Combat Skill    : 29                                         |
| Endurance       : 31 / 31                                    |
```

Rules:

- keep labels stable in width
- prefer short labels over wrapping labels
- prefer one row per fact unless a dense paired row is clearly better

### 4. Two-Column Rows

Use two-column rows only when the content is naturally paired and remains readable.

Approved uses:

- discipline lists
- lore-circle grids
- some campaign/stat summaries

Preferred model:

```text
| Fire    : partial       | Light   : empty                    |
| Solaris : partial       | Spirit  : partial                  |
```

Rules:

- do not force two columns when one side becomes much longer than the other
- if a row becomes awkward, fall back to wrapped single-column text

### 5. Main Sheet Density

The main sheet is a current-state dashboard, not a campaign archive.

Keep on the main sheet:

- name
- ruleset
- current book
- rank
- core stats
- current disciplines
- current containers/inventory summary
- active Book `6+` systems like Lore Circles or Herb Pouch when relevant

Move off the main sheet:

- completed books
- long achievement progress
- detailed history
- route recap

`Completed Books` belongs on the `Campaign` screen, not the main sheet.

### 6. Information Priority

Order information by immediate play value:

1. current identity and state
2. current ruleset-specific mechanics
3. current carry/load state
4. broader campaign context

This means:

- `Combat Skill`, `Endurance`, and `Gold` beat campaign recap
- active disciplines beat deep notes
- inventory summary beats decorative spacing

## Screen-Specific Direction

### Main Sheet

Use separate panels for:

- `Character Sheet`
- `Disciplines`
- `Lore Circles` when relevant
- `Inventory`

Do not overload the main sheet with:

- completed-book history
- achievement counts
- long rules explanations

### Inventory

Use:

- one banner
- one summary panel
- sectioned inventory lists below

Keep repeated items compact, for example:

- `Special Rations x5`

### Combat

Combat should be the densest screen in the app.

Prioritize:

- player/enemy state
- active weapon
- ratio
- rule notes
- round result visibility

Combat art should stay minimal and strong, not tall.

### Achievements

Achievements can be a little more decorative than utility screens, but still within the same border system.

The trophy/art element should remain short.

### Death And Book Complete

These ceremonial screens are the one place where slightly taller ASCII treatment is acceptable.

Even there:

- keep the border system consistent
- do not switch to an entirely different UI language

## Shared Color Intent

The style guide does not lock exact code changes yet, but color usage should broadly follow:

- `Cyan` / `White` for primary app identity
- `Yellow` / `DarkYellow` for inventory, highlights, and achievements
- `Red` for death/combat danger
- `Green` for healthy or successful state
- `DarkGray` for borders and subtle separators

Color should support scanning, not become the design itself.

## M3 Rollout Order

Apply the style in this order:

1. main banner + character sheet
2. inventory
3. combat + combat log
4. disciplines
5. stats + campaign
6. achievements
7. notes + history
8. welcome + load + help + modes
9. death + book complete

Each slice should be:

1. mocked up in chat
2. approved
3. implemented
4. tested in PowerShell `7` and Windows PowerShell `5.1`

## Exit Condition For M3

M3 should only be marked complete when:

- all screen families use the same visual language
- main sheet readability is improved
- no major wrapping regressions appear in PowerShell `7` or Windows PowerShell `5.1`
- performance is not meaningfully worse
