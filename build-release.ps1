#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputRoot,
    [switch]$SkipZip
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

function Write-LWBuildInfo {
    param([string]$Message)
    Write-Host '[BUILD] ' -NoNewline -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Gray
}

function Join-LWPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$ChildPath
    )

    $resolved = $Path
    foreach ($child in @($ChildPath)) {
        $resolved = Join-Path $resolved $child
    }

    return $resolved
}

function Copy-LWRequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Required file not found: $Source"
    }

    $destinationDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Get-LWGitHead {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    try {
        $head = git -C $RepoRoot rev-parse --short HEAD 2>$null
        if ([string]::IsNullOrWhiteSpace($head)) {
            return $null
        }

        return [string]$head.Trim()
    }
    catch {
        return $null
    }
}

$repoRoot = Get-LWRepoRoot
$bootstrapModulePath = Join-LWPath $repoRoot 'modules' 'core' 'bootstrap.psm1'
$appVersion = Get-LWAppVersion -BootstrapModulePath $bootstrapModulePath
$releaseRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $repoRoot 'testing\releases'
}
else {
    $OutputRoot
}
$packageName = "LoneWolf_ActionAssistant_v{0}_portable" -f $appVersion
$stagingRoot = Join-Path $releaseRoot $packageName
$zipPath = Join-Path $releaseRoot ("{0}.zip" -f $packageName)
$gitHead = Get-LWGitHead -RepoRoot $repoRoot

if (-not (Test-Path -LiteralPath $releaseRoot)) {
    New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
}

if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

if ((-not $SkipZip) -and (Test-Path -LiteralPath $zipPath)) {
    Remove-Item -LiteralPath $zipPath -Force
}

Write-LWBuildInfo ("Preparing staging folder at {0}" -f $stagingRoot)

$directories = @(
    $stagingRoot,
    (Join-Path $stagingRoot 'data'),
    (Join-Path $stagingRoot 'modules'),
    (Join-Path $stagingRoot 'saves')
)
foreach ($dir in $directories) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Copy-LWRequiredFile -Source (Join-Path $repoRoot 'lonewolf.ps1') -Destination (Join-Path $stagingRoot 'lonewolf.ps1')
Copy-LWRequiredFile -Source (Join-Path $repoRoot 'README.md') -Destination (Join-Path $stagingRoot 'README.md')
Copy-LWRequiredFile -Source (Join-Path $repoRoot 'CHANGELOG.md') -Destination (Join-Path $stagingRoot 'CHANGELOG.md')
Copy-LWRequiredFile -Source (Join-Path $repoRoot 'Start-LoneWolfWeb.ps1') -Destination (Join-Path $stagingRoot 'Start-LoneWolfWeb.ps1')
Copy-LWRequiredFile -Source (Join-Path $repoRoot 'Start-LoneWolfWeb.sh') -Destination (Join-Path $stagingRoot 'Start-LoneWolfWeb.sh')

foreach ($relativePath in @(
        (Join-LWPath 'data' 'kai-disciplines.json'),
        (Join-LWPath 'data' 'magnakai-disciplines.json'),
        (Join-LWPath 'data' 'magnakai-ranks.json'),
        (Join-LWPath 'data' 'magnakai-lore-circles.json'),
        (Join-LWPath 'data' 'weaponskill-map.json'),
        (Join-LWPath 'data' 'crt.template.json')
    )) {
    Copy-LWRequiredFile -Source (Join-Path $repoRoot $relativePath) -Destination (Join-Path $stagingRoot $relativePath)
}

$optionalCrtPath = Join-LWPath $repoRoot 'data' 'crt.json'
$includedCrt = $false
if (Test-Path -LiteralPath $optionalCrtPath) {
    Copy-LWRequiredFile -Source $optionalCrtPath -Destination (Join-Path $stagingRoot 'data\crt.json')
    $includedCrt = $true
}

$modulesSourceRoot = Join-Path $repoRoot 'modules'
foreach ($moduleChild in @(Get-ChildItem -LiteralPath $modulesSourceRoot -Force)) {
    Copy-Item -LiteralPath $moduleChild.FullName -Destination (Join-Path $stagingRoot 'modules') -Recurse -Force
}

$webSourceRoot = Join-Path $repoRoot 'web'
if (-not (Test-Path -LiteralPath $webSourceRoot)) {
    throw "Web scaffold folder not found: $webSourceRoot"
}
Copy-Item -LiteralPath $webSourceRoot -Destination $stagingRoot -Recurse -Force

$cmdLauncher = @'
@echo off
setlocal
set "APPDIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPDIR%lonewolf.ps1" %*
endlocal
'@
Set-Content -LiteralPath (Join-Path $stagingRoot 'Start-LoneWolf.cmd') -Value $cmdLauncher -Encoding ASCII

$psLauncher = @'
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$scriptPath = Join-Path $PSScriptRoot 'lonewolf.ps1'
& $scriptPath @Args
'@
Set-Content -LiteralPath (Join-Path $stagingRoot 'Start-LoneWolf.ps1') -Value $psLauncher -Encoding UTF8

$webCmdLauncher = @'
@echo off
setlocal
set "APPDIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%APPDIR%Start-LoneWolfWeb.ps1" %*
endlocal
'@
Set-Content -LiteralPath (Join-Path $stagingRoot 'Start-LoneWolfWeb.cmd') -Value $webCmdLauncher -Encoding ASCII

$packageReadme = @"
Lone Wolf Action Assistant
Portable package: $packageName
App version: $appVersion
Git head: $(if ($gitHead) { $gitHead } else { 'unknown' })

Quick start:
1. Double-click Start-LoneWolf.cmd
2. Or run .\lonewolf.ps1 from PowerShell
3. For the local browser scaffold, run .\Start-LoneWolfWeb.ps1 or Start-LoneWolfWeb.cmd

Notes:
- This package includes the CLI plus the current local web scaffold.
- The web scaffold requires Python 3 and PowerShell 7.
- Book text is not bundled; the browser reader shell can point at local book files when present.
- This portable package keeps saves in the local saves folder beside the app.
- DataFile combat mode requires data\crt.json. Included: $includedCrt
"@
Set-Content -LiteralPath (Join-Path $stagingRoot 'PACKAGE_README.txt') -Value $packageReadme -Encoding UTF8

$manifest = [pscustomobject]@{
    PackageName        = $packageName
    AppVersion         = $appVersion
    BuiltOn            = (Get-Date).ToString('o')
    GitHead            = $gitHead
    IncludedCrtData    = $includedCrt
    RequiredRootFiles  = @('lonewolf.ps1', 'README.md', 'CHANGELOG.md', 'Start-LoneWolf.cmd', 'Start-LoneWolf.ps1', 'Start-LoneWolfWeb.cmd', 'Start-LoneWolfWeb.ps1', 'Start-LoneWolfWeb.sh', 'PACKAGE_README.txt')
    RequiredDataFiles  = @('kai-disciplines.json', 'magnakai-disciplines.json', 'magnakai-ranks.json', 'magnakai-lore-circles.json', 'weaponskill-map.json', 'crt.template.json') + $(if ($includedCrt) { @('crt.json') } else { @() })
    RequiredDirs       = @('data', 'modules', 'saves', 'web')
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $stagingRoot 'release-manifest.json') -Encoding UTF8

if (-not $SkipZip) {
    Write-LWBuildInfo ("Creating zip archive at {0}" -f $zipPath)
    Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
}

Write-LWBuildInfo ("Portable release ready: {0}" -f $stagingRoot)
if (-not $SkipZip) {
    Write-LWBuildInfo ("Zip archive ready: {0}" -f $zipPath)
}
