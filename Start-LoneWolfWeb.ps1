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
$controlHost = if ($ListenHost -in @('0.0.0.0', '::', '[::]')) { 'localhost' } else { $ListenHost }
$shutdownUrl = "http://$controlHost`:$Port/api/shutdown"

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
Write-Host "Press Enter in this window to stop the web server." -ForegroundColor DarkGray
Write-Host ""

Set-Location $root
$serverProcess = $null
try {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = [string]$pythonCommand.Source
    $startInfo.Arguments = ('"{0}" --host "{1}" --port {2} --quiet' -f $serverScript, $ListenHost, $Port)
    $startInfo.WorkingDirectory = [string]$root
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $false

    $serverProcess = [System.Diagnostics.Process]::Start($startInfo)
    [void](Read-Host 'Press Enter to stop all Lone Wolf web processes')
}
finally {
    if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
        try {
            Invoke-RestMethod -Method Post -Uri $shutdownUrl -ContentType 'application/json' -Body '{}' -TimeoutSec 5 | Out-Null
        }
        catch {
        }

        if (-not $serverProcess.WaitForExit(10000)) {
            try {
                Stop-Process -Id ([int]$serverProcess.Id) -Force -ErrorAction Stop
            }
            catch {
            }
        }
    }
}
