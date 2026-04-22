#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$StageRoot,
    [string]$ZipPath,
    [string]$OutputRoot,
    [switch]$Rebuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LWRepoRoot {
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return $PSScriptRoot
    }

    if ($MyInvocation.MyCommand.Path) {
        return (Split-Path -Parent $MyInvocation.MyCommand.Path)
    }

    return (Get-Location).Path
}

function Get-LWAppVersion {
    param([Parameter(Mandatory = $true)][string]$BootstrapModulePath)

    $content = Get-Content -LiteralPath $BootstrapModulePath -Raw
    $match = [regex]::Match($content, "AppVersion\s*=\s*'([^']+)'")
    if (-not $match.Success) {
        throw "Could not determine app version from $BootstrapModulePath"
    }

    return [string]$match.Groups[1].Value
}

function Write-LWValidationInfo {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host '[VALIDATE] ' -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Gray
}

function ConvertTo-LWArgumentString {
    param([string[]]$Arguments)

    if (-not $Arguments -or $Arguments.Count -eq 0) {
        return ''
    }

    $encoded = foreach ($argument in $Arguments) {
        if ($null -eq $argument) {
            '""'
        }
        elseif ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        }
        else {
            $argument
        }
    }

    return [string]::Join(' ', $encoded)
}

function Invoke-LWProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory,
        [string]$InputText,
        [string]$StdOutPath,
        [string]$StdErrPath,
        [int]$TimeoutMs = 90000
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = ConvertTo-LWArgumentString -Arguments $ArgumentList
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
        $startInfo.WorkingDirectory = $WorkingDirectory
    }

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()

    if ($null -ne $InputText) {
        $process.StandardInput.Write($InputText)
    }
    $process.StandardInput.Close()

    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()

    if (-not $process.WaitForExit($TimeoutMs)) {
        try {
            $process.Kill()
        }
        catch {
        }

        throw "Process timed out: $FilePath $($startInfo.Arguments)"
    }

    if ($StdOutPath) {
        Set-Content -LiteralPath $StdOutPath -Value $standardOutput -Encoding UTF8
    }

    if ($StdErrPath) {
        Set-Content -LiteralPath $StdErrPath -Value $standardError -Encoding UTF8
    }

    return [pscustomobject]@{
        FilePath     = $FilePath
        Arguments    = $startInfo.Arguments
        ExitCode     = [int]$process.ExitCode
        StandardOut  = $standardOutput
        StandardErr  = $standardError
        TimedOut     = $false
    }
}

function Get-LWSampleSaveSource {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $preferredPath = Join-Path $RepoRoot 'saves\campaign-save.json'
    if (Test-Path -LiteralPath $preferredPath) {
        return $preferredPath
    }

    $bestPath = $null
    $bestBook = -1
    foreach ($candidate in @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'saves') -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        try {
            $rawState = Get-Content -LiteralPath $candidate.FullName -Raw | ConvertFrom-Json
            $bookNumber = 0
            if ($rawState.PSObject.Properties.Name -contains 'Character' -and
                $rawState.Character -and
                $rawState.Character.PSObject.Properties.Name -contains 'BookNumber') {
                $bookNumber = [int]$rawState.Character.BookNumber
            }

            if ($bookNumber -gt $bestBook) {
                $bestBook = $bookNumber
                $bestPath = $candidate.FullName
            }
        }
        catch {
        }
    }

    if ($bestPath) {
        return $bestPath
    }

    throw 'No sample save was found under saves/.'
}

function Test-LWForbiddenPathsAbsent {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string[]]$RelativePaths
    )

    $results = [ordered]@{}
    foreach ($relativePath in $RelativePaths) {
        $results[$relativePath] = -not (Test-Path -LiteralPath (Join-Path $RootPath $relativePath))
    }

    return [pscustomobject]$results
}

$repoRoot = Get-LWRepoRoot
$bootstrapModulePath = Join-Path $repoRoot 'modules\core\bootstrap.psm1'
$appVersion = Get-LWAppVersion -BootstrapModulePath $bootstrapModulePath
$releaseRoot = Join-Path $repoRoot 'testing\releases'
$packageName = "LoneWolf_ActionAssistant_v{0}_portable" -f $appVersion

if (-not $StageRoot) {
    $StageRoot = Join-Path $releaseRoot $packageName
}

if (-not $ZipPath) {
    $ZipPath = Join-Path $releaseRoot ("{0}.zip" -f $packageName)
}

if (-not $OutputRoot) {
    $OutputRoot = Join-Path $repoRoot 'testing\logs'
}

if (-not (Test-Path -LiteralPath $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

if ($Rebuild) {
    Write-LWValidationInfo 'Rebuilding portable package before validation.'
    & (Join-Path $repoRoot 'build-release.ps1')
}

if (-not (Test-Path -LiteralPath $StageRoot)) {
    throw "Stage root not found: $StageRoot"
}

if (-not (Test-Path -LiteralPath $ZipPath)) {
    throw "Zip archive not found: $ZipPath"
}

$forbiddenPackagePaths = @(
    'data\last-save.txt',
    'data\error.log'
)

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runtimeRoot = Join-Path $repoRoot ("testing\runtime\release-validate-{0}" -f $timestamp)
$runtimePackageRoot = Join-Path $runtimeRoot 'portable'
$runtimeSavePath = Join-Path $runtimePackageRoot 'saves\sample-save.json'
$tempScriptPath = Join-Path $runtimeRoot 'direct-smoke.ps1'

if (Test-Path -LiteralPath $runtimeRoot) {
    Remove-Item -LiteralPath $runtimeRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
New-Item -ItemType Directory -Path $runtimePackageRoot -Force | Out-Null

$sampleSaveSource = Get-LWSampleSaveSource -RepoRoot $repoRoot
$preSmokeStageClean = Test-LWForbiddenPathsAbsent -RootPath $StageRoot -RelativePaths $forbiddenPackagePaths

Write-LWValidationInfo ("Expanding portable zip into disposable runtime folder: {0}" -f $runtimePackageRoot)
Expand-Archive -LiteralPath $ZipPath -DestinationPath $runtimePackageRoot -Force
New-Item -ItemType Directory -Path (Split-Path -Parent $runtimeSavePath) -Force | Out-Null
Copy-Item -LiteralPath $sampleSaveSource -Destination $runtimeSavePath -Force

$directSmokeScript = @'
param(
    [string]$StageRoot,
    [string]$SampleSave,
    [string]$OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location $StageRoot
. .\lonewolf.ps1
Initialize-LWData
$script:LWUi.Enabled = $true
$script:LWUi.NeedsRender = $true

$summary = [ordered]@{}
$summary.StageRoot = $StageRoot
$summary.MagnakaiDisciplines = @($script:GameData.MagnakaiDisciplines).Count
$summary.MagnakaiRanks = @($script:GameData.MagnakaiRanks).Count
$summary.MagnakaiLoreCircles = @($script:GameData.MagnakaiLoreCircles).Count

Load-LWGame -Path $SampleSave
$script:GameState.Settings.SavePath = $SampleSave

foreach ($command in @('help', 'sheet', 'inv', 'campaign', 'modes', 'disciplines', 'achievements')) {
    Invoke-LWCommand -InputLine $command | Out-Null
    $script:LWUi.NeedsRender = $true
    Refresh-LWScreen
}

$summary.LoadedBook = [int]$script:GameState.Character.BookNumber
$summary.LoadedRuleSet = [string]$script:GameState.RuleSet
$summary.RunIntegrity = [string]$script:GameState.Run.IntegrityState
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutPath -Encoding UTF8
'@
Set-Content -LiteralPath $tempScriptPath -Value $directSmokeScript -Encoding UTF8

$pwshJsonPath = Join-Path $OutputRoot 'PACKAGING_M4_SMOKE_PS7.json'
$pwshStdOutPath = Join-Path $OutputRoot 'PACKAGING_M4_SMOKE_PS7.txt'
$pwshStdErrPath = Join-Path $OutputRoot 'PACKAGING_M4_SMOKE_PS7.err.txt'
$ps51JsonPath = Join-Path $OutputRoot 'PACKAGING_M4_SMOKE_PS51.json'
$ps51StdOutPath = Join-Path $OutputRoot 'PACKAGING_M4_SMOKE_PS51.txt'
$ps51StdErrPath = Join-Path $OutputRoot 'PACKAGING_M4_SMOKE_PS51.err.txt'

$launcherPs7OutPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_PS7.txt'
$launcherPs7ErrPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_PS7.err.txt'
$launcherCmdOutPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_CMD.txt'
$launcherCmdErrPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_CMD.err.txt'
$startupLoadPs7OutPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_LOAD_PS7.txt'
$startupLoadPs7ErrPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_LOAD_PS7.err.txt'
$startupLoadPs51OutPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_LOAD_PS51.txt'
$startupLoadPs51ErrPath = Join-Path $OutputRoot 'PACKAGING_M4_STARTUP_LOAD_PS51.err.txt'

Write-LWValidationInfo 'Running direct smoke in PowerShell 7.'
$pwshSmoke = Invoke-LWProcess -FilePath 'pwsh.exe' -ArgumentList @(
    '-NoProfile',
    '-File',
    $tempScriptPath,
    '-StageRoot',
    $runtimePackageRoot,
    '-SampleSave',
    $runtimeSavePath,
    '-OutPath',
    $pwshJsonPath
) -WorkingDirectory $runtimePackageRoot -StdOutPath $pwshStdOutPath -StdErrPath $pwshStdErrPath

Write-LWValidationInfo 'Running direct smoke in Windows PowerShell 5.1.'
$ps51Smoke = Invoke-LWProcess -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $tempScriptPath,
    '-StageRoot',
    $runtimePackageRoot,
    '-SampleSave',
    $runtimeSavePath,
    '-OutPath',
    $ps51JsonPath
) -WorkingDirectory $runtimePackageRoot -StdOutPath $ps51StdOutPath -StdErrPath $ps51StdErrPath

Write-LWValidationInfo 'Running packaged PowerShell launcher smoke.'
$launcherPs7 = Invoke-LWProcess -FilePath 'pwsh.exe' -ArgumentList @(
    '-NoProfile',
    '-File',
    (Join-Path $runtimePackageRoot 'Start-LoneWolf.ps1')
) -WorkingDirectory $runtimePackageRoot -InputText "quit`r`n" -StdOutPath $launcherPs7OutPath -StdErrPath $launcherPs7ErrPath

Write-LWValidationInfo 'Running packaged CMD launcher smoke.'
$launcherCmd = Invoke-LWProcess -FilePath 'cmd.exe' -ArgumentList @(
    '/c',
    (Join-Path $runtimePackageRoot 'Start-LoneWolf.cmd')
) -WorkingDirectory $runtimePackageRoot -InputText "quit`r`n" -StdOutPath $launcherCmdOutPath -StdErrPath $launcherCmdErrPath

Write-LWValidationInfo 'Running redirected startup -Load smoke in PowerShell 7.'
$startupLoadPs7 = Invoke-LWProcess -FilePath 'pwsh.exe' -ArgumentList @(
    '-NoProfile',
    '-File',
    (Join-Path $runtimePackageRoot 'lonewolf.ps1'),
    '-Load',
    $runtimeSavePath
) -WorkingDirectory $runtimePackageRoot -InputText "sheet`r`nquit`r`n" -StdOutPath $startupLoadPs7OutPath -StdErrPath $startupLoadPs7ErrPath

Write-LWValidationInfo 'Running redirected startup -Load smoke in Windows PowerShell 5.1.'
$startupLoadPs51 = Invoke-LWProcess -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    (Join-Path $runtimePackageRoot 'lonewolf.ps1'),
    '-Load',
    $runtimeSavePath
) -WorkingDirectory $runtimePackageRoot -InputText "sheet`r`nquit`r`n" -StdOutPath $startupLoadPs51OutPath -StdErrPath $startupLoadPs51ErrPath

$pwshSummary = Get-Content -LiteralPath $pwshJsonPath -Raw | ConvertFrom-Json
$ps51Summary = Get-Content -LiteralPath $ps51JsonPath -Raw | ConvertFrom-Json
$startupLoadPs7Loaded = ($startupLoadPs7.StandardOut -match 'Loaded game from ')
$startupLoadPs51Loaded = ($startupLoadPs51.StandardOut -match 'Loaded game from ')

$expectedDataFiles = @(
    'kai-disciplines.json',
    'magnakai-disciplines.json',
    'magnakai-ranks.json',
    'magnakai-lore-circles.json',
    'weaponskill-map.json',
    'crt.template.json'
)

$missingStageDataFiles = @()
foreach ($dataFile in $expectedDataFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $StageRoot ("data\{0}" -f $dataFile)))) {
        $missingStageDataFiles += $dataFile
    }
}

$postSmokeStageClean = Test-LWForbiddenPathsAbsent -RootPath $StageRoot -RelativePaths $forbiddenPackagePaths
$runtimeGeneratedLastSave = Test-Path -LiteralPath (Join-Path $runtimePackageRoot 'data\last-save.txt')

$result = [ordered]@{
    PackageName              = $packageName
    AppVersion               = $appVersion
    StageRoot                = $StageRoot
    ZipPath                  = $ZipPath
    RuntimePackageRoot       = $runtimePackageRoot
    StageCleanBeforeSmoke    = $preSmokeStageClean
    StageCleanAfterSmoke     = $postSmokeStageClean
    MissingStageDataFiles    = @($missingStageDataFiles)
    DirectSmokePwshExitCode  = [int]$pwshSmoke.ExitCode
    DirectSmokePs51ExitCode  = [int]$ps51Smoke.ExitCode
    LauncherPs7ExitCode      = [int]$launcherPs7.ExitCode
    LauncherCmdExitCode      = [int]$launcherCmd.ExitCode
    StartupLoadPs7ExitCode   = [int]$startupLoadPs7.ExitCode
    StartupLoadPs51ExitCode  = [int]$startupLoadPs51.ExitCode
    StartupLoadPs7Loaded     = [bool]$startupLoadPs7Loaded
    StartupLoadPs51Loaded    = [bool]$startupLoadPs51Loaded
    PwshSmokeSummary         = $pwshSummary
    Ps51SmokeSummary         = $ps51Summary
    RuntimeGeneratedLastSave = [bool]$runtimeGeneratedLastSave
}

$resultJsonPath = Join-Path $OutputRoot 'PACKAGING_M4_VALIDATION_SUMMARY.json'
$resultMdPath = Join-Path $OutputRoot 'PACKAGING_M4_VALIDATION_SUMMARY.md'

$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultJsonPath -Encoding UTF8

$allClean = (
    $missingStageDataFiles.Count -eq 0 -and
    $preSmokeStageClean.'data\last-save.txt' -and
    $preSmokeStageClean.'data\error.log' -and
    $postSmokeStageClean.'data\last-save.txt' -and
    $postSmokeStageClean.'data\error.log' -and
    $pwshSmoke.ExitCode -eq 0 -and
    $ps51Smoke.ExitCode -eq 0 -and
    $launcherPs7.ExitCode -eq 0 -and
    $launcherCmd.ExitCode -eq 0 -and
    $startupLoadPs7.ExitCode -eq 0 -and
    $startupLoadPs51.ExitCode -eq 0 -and
    $startupLoadPs7Loaded -and
    $startupLoadPs51Loaded -and
    [int]$pwshSummary.LoadedBook -ge 6 -and
    [int]$ps51Summary.LoadedBook -ge 6 -and
    [string]$pwshSummary.LoadedRuleSet -eq 'Magnakai' -and
    [string]$ps51Summary.LoadedRuleSet -eq 'Magnakai'
)

$summaryLines = @(
    '# Packaging Validation Summary',
    '',
    ('- Package: {0}' -f $packageName),
    ('- App version: {0}' -f $appVersion),
    ('- Stage root: {0}' -f $StageRoot),
    ('- Zip path: {0}' -f $ZipPath),
    ('- Runtime validation root: {0}' -f $runtimePackageRoot),
    ('- Overall result: {0}' -f $(if ($allClean) { 'PASS' } else { 'FAIL' })),
    '',
    '## Stage Cleanliness',
    '',
    ('- Before smoke: last-save absent = {0}; error.log absent = {1}' -f $preSmokeStageClean.'data\last-save.txt', $preSmokeStageClean.'data\error.log'),
    ('- After smoke: last-save absent = {0}; error.log absent = {1}' -f $postSmokeStageClean.'data\last-save.txt', $postSmokeStageClean.'data\error.log'),
    ('- Runtime copy generated last-save.txt during use: {0}' -f $runtimeGeneratedLastSave),
    '',
    '## Data Files',
    '',
    ('- Missing stage data files: {0}' -f $(if ($missingStageDataFiles.Count -eq 0) { '(none)' } else { ($missingStageDataFiles -join ', ') })),
    '',
    '## Direct Smoke',
    '',
    ('- PowerShell 7 exit code: {0}' -f $pwshSmoke.ExitCode),
    ('- Windows PowerShell 5.1 exit code: {0}' -f $ps51Smoke.ExitCode),
    ('- PowerShell 7 loaded rule set/book: {0} / {1}' -f $pwshSummary.LoadedRuleSet, $pwshSummary.LoadedBook),
    ('- Windows PowerShell 5.1 loaded rule set/book: {0} / {1}' -f $ps51Summary.LoadedRuleSet, $ps51Summary.LoadedBook),
    '',
    '## Launcher Smoke',
    '',
    ('- Start-LoneWolf.ps1 via PowerShell 7 exit code: {0}' -f $launcherPs7.ExitCode),
    ('- Start-LoneWolf.cmd via cmd.exe exit code: {0}' -f $launcherCmd.ExitCode),
    ('- Redirected startup -Load via PowerShell 7 exit code: {0}; loaded save = {1}' -f $startupLoadPs7.ExitCode, [bool]$startupLoadPs7Loaded),
    ('- Redirected startup -Load via Windows PowerShell 5.1 exit code: {0}; loaded save = {1}' -f $startupLoadPs51.ExitCode, [bool]$startupLoadPs51Loaded),
    '',
    '## Artifacts',
    '',
    '- `testing/logs/PACKAGING_M4_SMOKE_PS7.txt`',
    '- `testing/logs/PACKAGING_M4_SMOKE_PS7.err.txt`',
    '- `testing/logs/PACKAGING_M4_SMOKE_PS51.txt`',
    '- `testing/logs/PACKAGING_M4_SMOKE_PS51.err.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_PS7.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_PS7.err.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_CMD.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_CMD.err.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_LOAD_PS7.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_LOAD_PS7.err.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_LOAD_PS51.txt`',
    '- `testing/logs/PACKAGING_M4_STARTUP_LOAD_PS51.err.txt`',
    '- `testing/logs/PACKAGING_M4_VALIDATION_SUMMARY.json`'
)

Set-Content -LiteralPath $resultMdPath -Value ($summaryLines -join [Environment]::NewLine) -Encoding UTF8

Write-LWValidationInfo ("Validation summary written to {0}" -f $resultMdPath)

if (-not $allClean) {
    throw "Portable package validation failed. See $resultMdPath"
}
