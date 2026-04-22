# GitHub Workflow

This repo is set up so the public project stays clean while local play data stays on the machine.

## What Stays Out Of Git

- `saves/`
- `data/last-save.txt`
- `data/crt.json`
- `data/rh-crtneg.png`
- `data/rh-crtpos.png`
- local `tmp-*` test folders

## Normal Update Flow

From the repo root:

```powershell
git status
```

Review what changed. Then run lightweight validation:

```powershell
powershell -NoProfile -Command "$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path '.\\lonewolf.ps1'),[ref]$tokens,[ref]$errors); if($errors){ $errors | ForEach-Object Message }"
pwsh -NoProfile -Command "$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path '.\\lonewolf.ps1'),[ref]$tokens,[ref]$errors); if($errors){ $errors | ForEach-Object Message }"
```

Stage and commit:

```powershell
git add .
git commit -m "Short summary of the change"
```

Push to GitHub:

```powershell
git push origin main
```

## First-Time Setup Still Needed

Before the first commit/push, this machine needs:

1. A git author name
2. A git author email
3. GitHub authentication for push access

## Recommended Rules

- Keep player save files local unless you intentionally want to publish a sample save.
- Keep `data/crt.json` local unless you have confirmed redistribution rights for that data.
- Prefer one focused commit per feature or fix.
- Update `README.md` when command surface or major features change.
- Update `CHANGELOG.md` when a new public release is cut.
- Keep GitHub labels, issue state, milestones, and wiki pages current when user-facing project state changes.
- For book work, treat strategy-guide creation or update as part of done when route, achievement, or support coverage changes meaningfully.
- If a new book becomes playable on current `main`, update the related wiki guide/index/support pages in the same completion sweep instead of leaving them for later.
- Use `docs/STRATEGY_GUIDE_STYLE_GUIDE.md` as the house style for book strategy guides so new pages keep the same article-first `BradyGames` voice.
- Prefer the repo issue forms under `.github/ISSUE_TEMPLATE/` instead of blank freeform issues.
- Use GitHub milestones only for top-level roadmap items; keep sub-milestones in `docs/PROJECT_MILESTONES.md`.
- If GitHub Projects are used later, mirror the board structure documented in `docs/GITHUB_TRACKING.md`.

## Book Workflow Closeout

For book implementation, book hardening, or book-audit build work, close out the pass with:

- code or rules updates
- validation in Windows PowerShell `5.1` and PowerShell `7`
- repo doc updates when project state changed
- wiki strategy-guide and scope-page updates when player-facing book state changed
- strategy-guide updates that follow `docs/STRATEGY_GUIDE_STYLE_GUIDE.md` instead of reverting to list-heavy audit-note formatting
- if the wiki repo changed locally, a separate wiki commit/push so the public pages actually update
- GitHub issue / milestone / board hygiene where applicable

## README Sanitization Before Push

Before pushing changes that touch `README.md`, do a quick public-facing cleanup pass:

- Remove local machine paths, personal environment details, and temporary test references.
- Do not mention live save names, current character progress, or private playthrough state.
- Keep the README focused on shipped features, setup, commands, and public workflow.
- Avoid internal-only notes, handoff references, agent notes, and debugging details.
- Do not include copyrighted book text or copied reference tables.
- Prefer generic examples over anything pulled from a personal save.

Treat the README as public project documentation, not a development log.
