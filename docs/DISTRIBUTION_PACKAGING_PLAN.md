# Distribution Packaging Plan

This document defines how the Lone Wolf Action Assistant should be packaged for
distribution while the project is still a PowerShell-based app with local data
files and modules.

## Current Recommendation

The current distribution target is a **portable zip release**.

Why:

- the app depends on `lonewolf.ps1`
- it depends on local `data/` JSON files
- it now depends on local `modules/`
- a portable bundle is easier to validate and easier to debug than a packaged
  executable at this stage

## Portable Release Contents

Ship:

- `lonewolf.ps1`
- `modules/`
- `data/kai-disciplines.json`
- `data/magnakai-disciplines.json`
- `data/magnakai-ranks.json`
- `data/magnakai-lore-circles.json`
- `data/weaponskill-map.json`
- `data/crt.template.json`
- `data/crt.json` when available
- `README.md`
- `CHANGELOG.md`
- generated launchers:
  - `Start-LoneWolf.cmd`
  - `Start-LoneWolf.ps1`
  - `Start-LoneWolfWeb.cmd`
- tracked web launchers:
  - `Start-LoneWolfWeb.ps1`
  - `Start-LoneWolfWeb.sh`
- `web/`

Do not ship:

- `.git/`
- `.vscode/`
- `testing/`
- `logs/`
- live `saves/`
- `data/last-save.txt`
- `data/error.log`

## Release Builder

The repo-tracked release builder is:

- `build-release.ps1`

The repo-tracked package validator is:

- `validate-release.ps1`

Default output:

- `testing/releases/`

Default artifact names:

- staging folder:
  - `LoneWolf_ActionAssistant_v<version>_portable`
- zip archive:
  - `LoneWolf_ActionAssistant_v<version>_portable.zip`

## Build Workflow

From the repo root:

```powershell
.\build-release.ps1
```

That should:

1. detect the current app version
2. create a clean staging folder under `testing/releases/`
3. copy the required app files
4. generate end-user launcher files
5. generate a simple `release-manifest.json`
6. create a zip archive

## Validation Workflow

Before any public release/package:

1. rebuild the portable package locally
2. validate the zip on a disposable extracted copy so the real staging folder stays clean
3. confirm that the real staging folder still does not contain:
   - `data/last-save.txt`
   - `data/error.log`
4. validate that the extracted copy can:
   - initialize data
   - load modules
   - load a save
   - render `help`
   - render the main Book `6` screens
   - serve the local web scaffold at `/api/state`
   - start cleanly through:
     - `Start-LoneWolf.ps1`
     - `Start-LoneWolf.cmd`
     - `Start-LoneWolfWeb.ps1`
     - `Start-LoneWolfWeb.cmd`
5. keep validation notes in `testing/logs/`

Preferred command:

```powershell
.\validate-release.ps1 -Rebuild
```

Web scaffold packaging smoke:

```powershell
pwsh -NoLogo -NoProfile -File .\testing\tmp\web-packaging-smoke.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\testing\tmp\web-packaging-smoke.ps1
```

## Packaging Milestone

M4 portable packaging is complete and remains the current release workflow.

The portable zip remains the correct packaging format for local hardening builds
and future public releases. Current `v0.9.0` packages include the M6 web
scaffold and launchers, but they are pre-release hardening artifacts; the app is
not release-ready until `v1.0.0`.

## Future Packaging Options

After the current portable flow stops meeting project needs:

- optional installer package
- optional ruleset-specific packages
- optional single-file distribution investigation

Those are later-phase tasks. The portable zip remains the correct first release
format.
