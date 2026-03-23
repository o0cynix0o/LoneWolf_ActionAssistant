# GitHub Workflow

This repo is set up so the public project stays clean while local play data stays on the machine.

## What Stays Out Of Git

- `saves/`
- `data/last-save.txt`
- `data/crt.json`
- `data/rh-crtneg.png`
- `data/rh-crtpos.png`
- local `tmp-*` test folders
- `agent.md`

## Normal Update Flow

From `C:\Scripts\Lone Wolf`:

```powershell
git status
```

Review what changed. Then run lightweight validation:

```powershell
powershell -NoProfile -Command "$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('C:\Scripts\Lone Wolf\lonewolf.ps1',[ref]$tokens,[ref]$errors); if($errors){ $errors | ForEach-Object Message }"
pwsh -NoProfile -Command "$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('C:\Scripts\Lone Wolf\lonewolf.ps1',[ref]$tokens,[ref]$errors); if($errors){ $errors | ForEach-Object Message }"
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

## README Sanitization Before Push

Before pushing changes that touch `README.md`, do a quick public-facing cleanup pass:

- Remove local machine paths, personal environment details, and temporary test references.
- Do not mention live save names, current character progress, or private playthrough state.
- Keep the README focused on shipped features, setup, commands, and public workflow.
- Avoid internal-only notes, handoff references, agent notes, and debugging details.
- Do not include copyrighted book text or copied reference tables.
- Prefer generic examples over anything pulled from a personal save.

Treat the README as public project documentation, not a development log.
