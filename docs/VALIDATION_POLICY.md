# Validation Policy

This document defines the current validation bar for the Lone Wolf Action Assistant.

The older `100+ sandbox runs` rule was useful when the app was smaller, but it does not scale well as more books, routes, DE options, and rulesets are added.

The current standard is a **route-and-mode coverage matrix**, backed by command-surface and state-integrity checks.

## Core Principle

Validation should prove:

- the app can complete the supported campaign
- the major route families still work
- the supported difficulty modes still behave correctly
- failure and death states still behave correctly
- save/load, transitions, and recovery systems still behave correctly

It is better to cover the real route surface deliberately than to rely on an arbitrary raw run count.

## Route-And-Mode Validation Bar

For a milestone that changes game logic, a good pass bar is:

- all known **winning route families** covered at least once
- each supported difficulty covered at least once:
  - `Story`
  - `Easy`
  - `Normal`
  - `Hard`
  - `Veteran`
- `Permadeath` covered explicitly
- known **failure routes / failure endings** covered explicitly

Preferred interpretation:

- run each known winning route family through the campaign on each supported difficulty when practical
- if a route matrix is too large for one pass, split it into:
  - representative route coverage per difficulty
  - then explicit route-family completion coverage on at least `Normal` or the project’s current baseline difficulty

## Minimum Pass Categories

Every major milestone or book/ruleset drop should cover these categories.

### 1. Command Surface Smoke

Run the main command surface in both:

- PowerShell `7`
- Windows PowerShell `5.1`

Minimum commands:

- `help`
- `load`
- `save`
- `sheet`
- `inv`
- `disciplines`
- `stats`
- `campaign`
- `achievements`
- `history`
- `section`
- `combat` flow if the build touched combat

### 2. Route Matrix

Cover:

- all known main winning routes for the supported books
- all known route achievements
- all major item-dependent and discipline-dependent route families

### 3. Difficulty Matrix

Cover:

- `Story`
- `Easy`
- `Normal`
- `Hard`
- `Veteran`

Check that:

- difficulty-specific rules still apply
- mode-gated achievements still unlock or stay locked correctly
- carry-forward and startup flows still work at each difficulty

### 4. Permadeath Matrix

At minimum:

- one successful campaign pass with `Permadeath`
- one death/failure pass with `Permadeath`

Check that:

- rewind is disabled correctly
- death handling stays correct
- permadeath challenge achievements stay honest

### 5. Failure Coverage

Cover at least one pass through:

- major failure endings
- representative death states
- failed mission states where the app distinguishes them from direct death

Check that:

- death/failure screens are correct
- rewind/recovery behavior is correct
- integrity and mode behavior stays correct

### 6. Transition Coverage

Cover every supported book-to-book transition in the active campaign.

Check:

- carry-forward state
- startup gear and startup prompts
- safekeeping or stash systems
- ruleset handoffs where applicable

### 7. Save / Load / Autosave Coverage

Check:

- manual save
- manual load
- startup `-Load`
- autosave after section move / transition / combat where relevant
- loading older existing saves after migration changes

### 8. DE Option Coverage

If a book supports Definitive Edition options or DE-only rules:

- cover each supported option at least once
- check that option-specific inventory, combat, and route behavior works

### 9. Performance Smoke

If a build touched performance-sensitive paths, verify at least:

- section movement
- sheet refresh
- load/startup

Use practical thresholds rather than “feels fast” alone.

## Good Pass Bar For Future Milestones

For future book or ruleset work, a strong practical bar is:

1. command-surface smoke in both shells
2. one full pass of each supported difficulty
3. explicit coverage of all known winning route families
4. explicit coverage of known failure routes
5. at least one successful `Permadeath` run and one failed `Permadeath` run
6. transition/save/load validation
7. DE-option coverage where applicable

That is a better standard than a flat `100+` run target.

## Historical Note

Earlier milestones were sometimes validated against a `100+ sandbox runs` bar.

Those historical notes should remain accurate in the repo, but future milestone planning should use this document as the preferred validation standard.
