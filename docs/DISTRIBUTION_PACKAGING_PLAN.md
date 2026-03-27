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
- the modular refactor is still in progress
- a portable bundle is easier to validate and easier to debug than a packaged
  executable at this stage

## Portable Release Contents

Ship:

- `lonewolf.ps1`
- `modules/`
- `data/kai-disciplines.json`
- `data/weaponskill-map.json`
- `data/crt.template.json`
- `data/crt.json` when available
- `README.md`
- generated launchers:
  - `Start-LoneWolf.cmd`
  - `Start-LoneWolf.ps1`

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

Before any push/release:

1. build the portable package locally
2. validate that the staged copy can:
   - initialize data
   - load modules
   - render `help`
   - start the app cleanly
3. keep validation notes in `testing/logs/`

## Packaging Milestone

This packaging work is intentionally separate from the gameplay rules work.

Recommended milestone framing:

- prepare portable release tooling while M1 is still in progress
- do not treat installer/exe packaging as required for the first public release

## Future Packaging Options

After the modular refactor stabilizes:

- optional installer package
- optional ruleset-specific packages
- optional single-file distribution investigation

Those are later-phase tasks. The portable zip remains the correct first release
format.
