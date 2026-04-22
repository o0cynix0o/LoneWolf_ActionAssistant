# Repo Gap Audit

Date: `2026-04-22`

## Scope

This pass reviewed:

- current book-module coverage in `modules/rulesets/`
- existing automation audit reports for Books `1-7`
- current validation and milestone docs
- current README/repo-current docs
- current open GitHub issues

This is a repo-state audit, not a fresh full-text reread of every unsupported book.

## What Looks Closed

- Books `1-5` are closed under the current automation audit:
  - `testing/logs/BOOKS1TO5_AUTOMATION_AUDIT_20260415.md`
  - current audit result: `0` missing candidates
- Book `6` is closed under the high-confidence automation audit and the later OG source-language follow-up slice is now built out:
  - `testing/logs/BOOK6_AUTOMATION_AUDIT_20260415.md`
  - `testing/logs/BOOK6_OG_LANGUAGE_SWEEP_20260422.md`
- Book `7` is implemented locally on current `main` with startup, section-entry, random-helper, combat, achievement, route, and difficulty smoke coverage already present:
  - `modules/rulesets/magnakai/book7.psm1`
  - `docs/PROJECT_HANDOFF.md`
- the stale pre-build Book `7` audit has now been replaced by a live post-build refresh:
  - `testing/logs/BOOK7_AUTOMATION_AUDIT_20260422.md`
- README / repo-current wording is now aligned with the recent Book `6` stabilization slice on current `main`
- redirected startup `-Load` cleanup is now fixed on current `main`, and package validation covers it:
  - `testing/logs/PACKAGING_M4_VALIDATION_SUMMARY.md`
- GitHub issue `#31` is already closed, so it is no longer a repo-state gap

## Confirmed Gaps

### 1. Book `8+` gameplay support is still absent

- The local corpus already contains books beyond `7`, but live app support only exists through:
  - Kai Books `1-5`
  - Magnakai Books `6-7`
- Current module inventory shows:
  - `modules/rulesets/kai/` -> `book1.psm1` through `book5.psm1`
  - `modules/rulesets/magnakai/` -> `book6.psm1`, `book7.psm1`
- No `book8.psm1` or later book-module support is present yet.

### 2. Book `7` is implemented but not release-ready yet

- `docs/PROJECT_HANDOFF.md` still states that Book `7` is implemented locally on current `main` but is not yet a tagged public release.
- `README.md` still treats `v0.8.0` as the latest public release.
- Missing release-readiness items for a public Book `7` drop include:
  - version/release bump planning
  - final public changelog/release sweep
  - user-led playtest closeout on the live Book `7` experience before a public build is cut

### 3. Book `7` validation is strong, but it is still short of the full release bar in `docs/VALIDATION_POLICY.md`

- Current `main` has green Book `7` smoke coverage for:
  - startup
  - choice flow
  - combat hooks
  - achievements
  - random helpers
  - automation surface
  - endgame routes
  - targeted difficulty/permadeath behavior
- What still appears missing before a public Book `7` release:
  - a fuller route-family completion matrix
  - a true full-campaign difficulty matrix rather than only targeted difficulty checks
  - explicit full-campaign permadeath completion/failure coverage if that is meant to satisfy the release bar

### 4. The next-book expansion step is only sketched, not planned in detail

- `docs/PROJECT_MILESTONES.md` still describes the next expansion only as:
  - `ruleset/state design notes for the next expansion step`
- There is not yet a repo-tracked Book `8` build plan comparable to the stronger Book `6` and Book `7` planning artifacts.

## Recommended Next Order

1. Finish the user-led Book `7` playtest pass on current `main`.
2. Convert any Book `7` playtest findings into targeted fixes plus rerun the affected validation slices.
3. If Book `7` is moving to release next:
   - finish the broader route-and-mode validation matrix
   - do the final version/tag/changelog/release sweep
4. Only after that, return to Book `8` audit/build planning.
