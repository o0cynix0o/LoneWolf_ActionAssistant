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

## Confirmed Gaps

### 1. Book `8+` gameplay support is still absent

- The local corpus already contains books beyond `7`, but live app support only exists through:
  - Kai Books `1-5`
  - Magnakai Books `6-7`
- Current module inventory shows:
  - `modules/rulesets/kai/` -> `book1.psm1` through `book5.psm1`
  - `modules/rulesets/magnakai/` -> `book6.psm1`, `book7.psm1`
- No `book8.psm1` or later book-module support is present yet.

### 2. The repo still lacks a post-build Book `7` automation audit

- `testing/logs/BOOK7_AUTOMATION_AUDIT_20260416.md` is now stale.
- That report still says:
  - current Book `7` section-entry hooks in app: `0`
  - current Book `7` book-specific coverage in app: `0`
- Those statements predate the actual Book `7` implementation now living in `modules/rulesets/magnakai/book7.psm1`.
- Missing follow-through:
  - a fresh post-build Book `7` automation audit
  - ideally a reusable Book `7` audit script similar to the Books `1-5` and Book `6` audit tooling

### 3. Book `7` is implemented but not release-ready yet

- `docs/PROJECT_HANDOFF.md` still states that Book `7` is implemented locally on current `main` but is not yet a tagged public release.
- `README.md` still treats `v0.8.0` as the latest public release.
- Missing release-readiness items for a public Book `7` drop include:
  - version/release bump planning
  - final public changelog/release sweep
  - release-package validation for the intended Book `7` public build

### 4. Book `7` validation is strong, but it is still short of the full release bar in `docs/VALIDATION_POLICY.md`

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

### 5. `README.md` is no longer fully repo-current

- The release-status section still says current `main` Book `6` stabilization work includes only:
  - `2`, `17`, `98`, `158/293`, `170`, `297`
- That list is now stale.
- It is missing at least:
  - section `275`
  - the OG source-language follow-up slice built on `2026-04-22`
- Repo-current docs in `docs/PROJECT_HANDOFF.md` and `docs/PROJECT_MILESTONES.md` are ahead of the README here.

### 6. There is still a known app/harness rough edge around redirected startup `-Load`

- `docs/PROJECT_HANDOFF.md` still documents that startup `-Load` under the redirected harness does not exit cleanly on its own.
- Current wording says load/render succeeds and the harness forces cleanup after verification.
- That means one of these is still missing:
  - a proper runtime fix
  - or a dedicated tracked issue if this is an accepted known limitation for now

### 7. GitHub closeout is not fully caught up with repo state

- Live open issues checked on `2026-04-22`:
  - `#31` `Combat tactical summary can crash on blank note rows after command-surface actions`
  - `#19` `Book 6 playtest stabilization tracker`
- `#19` still makes sense as the open umbrella tracker.
- `#31` is still open, so issue closeout is incomplete unless that defect is still reproducible on current `main`.

### 8. The next-book expansion step is only sketched, not planned in detail

- `docs/PROJECT_MILESTONES.md` still describes the next expansion only as:
  - `ruleset/state design notes for the next expansion step`
- There is not yet a repo-tracked Book `8` build plan comparable to the stronger Book `6` and Book `7` planning artifacts.

## Recommended Next Order

1. Replace the stale Book `7` automation audit with a current post-build report.
2. Decide whether the next priority is:
   - Book `7` release-readiness
   - or Book `8` audit/build planning
3. If Book `7` release-readiness is next:
   - finish the route-and-mode validation matrix
   - rerun `validate-release.ps1` for the intended release state
   - sync `README.md`
   - close any resolved GitHub issues
4. If Book `8` is next:
   - create a proper Book `8` audit/build artifact
   - map route/state/item/combat surfaces before implementation starts
