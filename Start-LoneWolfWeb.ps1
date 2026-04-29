param(
    [string]$ListenHost = 'localhost',
    [int]$Port = 8797,
    [switch]$NoBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSCommandPath
$serverScript = Join-Path $root 'web\app_server.py'
$url = "http://$ListenHost`:$Port/"

$isWindowsValue = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
$isMacOSValue = Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue
$isWindowsPlatform = if ($null -ne $isWindowsValue) { [bool]$isWindowsValue } else { [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT }
$isMacOSPlatform = if ($null -ne $isMacOSValue) { [bool]$isMacOSValue } else { $false }
$platformName = if ($isWindowsPlatform) { 'windows' } elseif ($isMacOSPlatform) { 'macos' } else { 'linux' }

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    $pythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
}
if ($null -eq $pythonCommand) {
    throw 'Python 3 is required to launch the Lone Wolf web scaffold.'
}

if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    throw 'PowerShell 7 (pwsh) is required to launch the Lone Wolf web scaffold.'
}

if (-not (Test-Path -LiteralPath $serverScript)) {
    throw "Server script not found: $serverScript"
}

if (-not $NoBrowser) {
    Start-Job -ScriptBlock {
        param($LaunchUrl, $PlatformName)
        Start-Sleep -Seconds 2
        try {
            if ($PlatformName -eq 'windows') {
                Start-Process $LaunchUrl | Out-Null
            }
            elseif ($PlatformName -eq 'macos') {
                & open $LaunchUrl | Out-Null
            }
            else {
                & xdg-open $LaunchUrl | Out-Null
            }
        }
        catch {
        }
    } -ArgumentList $url, $platformName | Out-Null
}

Write-Host ""
Write-Host "Lone Wolf web scaffold" -ForegroundColor Yellow
Write-Host "URL: $url" -ForegroundColor Green
Write-Host ""

Set-Location $root
& $pythonCommand.Source $serverScript --host $ListenHost --port $Port
