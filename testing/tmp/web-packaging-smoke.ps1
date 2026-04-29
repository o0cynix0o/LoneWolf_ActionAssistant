Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$runtimeRoot = Join-Path $repoRoot ("testing\runtime\web-package-smoke-{0}" -f $PID)
$outputRoot = Join-Path $runtimeRoot 'release'
$port = 0
$server = $null

function Assert-WebPackagingSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), 0)
    $listener.Start()
    try {
        return [int]$listener.LocalEndpoint.Port
    }
    finally {
        $listener.Stop()
    }
}

function Stop-WebPackageServer {
    param([System.Diagnostics.Process]$Process)

    if ($null -eq $Process) {
        return
    }

    $processIds = @()
    try {
        $processIds += @(Get-WebPackageChildProcessIds -ProcessId ([int]$Process.Id))
    }
    catch {
    }

    try {
        if (-not $Process.HasExited) {
            $processIds += [int]$Process.Id
        }
    }
    catch {
    }

    foreach ($processId in ($processIds | Select-Object -Unique)) {
        try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
        }
        catch {
        }
    }
}

function Get-WebPackageChildProcessIds {
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Get-WebPackageChildProcessIds -ProcessId ([int]$child.ProcessId)
        [int]$child.ProcessId
    }
}

function ConvertTo-WebPackageArgumentString {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    return (($Arguments | ForEach-Object {
                if ($null -eq $_) {
                    '""'
                }
                else {
                    '"{0}"' -f (($_ -replace '\\(?=")', '\\') -replace '"', '\"')
                }
            }) -join ' ')
}

function Remove-WebPackageRuntime {
    if (-not (Test-Path -LiteralPath $runtimeRoot)) {
        return
    }

    $runtimeResolved = (Resolve-Path -LiteralPath $runtimeRoot).Path
    $allowedRoot = (Resolve-Path (Join-Path $repoRoot 'testing\runtime')).Path
    if (-not $runtimeResolved.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove runtime folder outside testing runtime: $runtimeResolved"
    }

    Remove-Item -LiteralPath $runtimeResolved -Recurse -Force
}

try {
    if (Test-Path -LiteralPath $runtimeRoot) {
        Remove-WebPackageRuntime
    }
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null

    & (Join-Path $repoRoot 'build-release.ps1') -OutputRoot $outputRoot -SkipZip | Out-Null

    $manifestPath = Get-ChildItem -LiteralPath $outputRoot -Filter 'release-manifest.json' -Recurse -File | Select-Object -First 1
    Assert-WebPackagingSmoke -Condition ($null -ne $manifestPath) -Message 'Packaged release manifest was not found.'
    $stageRoot = Split-Path -Parent $manifestPath.FullName

    foreach ($relativePath in @(
            'Start-LoneWolfWeb.ps1',
            'Start-LoneWolfWeb.cmd',
            'Start-LoneWolfWeb.sh',
            'web\app_server.py',
            'web\frontend\index.html',
            'web\frontend\app.js',
            'web\frontend\styles.css',
            'web\frontend\library.html'
        )) {
        Assert-WebPackagingSmoke -Condition (Test-Path -LiteralPath (Join-Path $stageRoot $relativePath)) -Message "Packaged web file missing: $relativePath"
    }

    $manifest = Get-Content -LiteralPath $manifestPath.FullName -Raw | ConvertFrom-Json
    Assert-WebPackagingSmoke -Condition (@($manifest.RequiredRootFiles) -contains 'Start-LoneWolfWeb.ps1') -Message 'Manifest is missing Start-LoneWolfWeb.ps1.'
    Assert-WebPackagingSmoke -Condition (@($manifest.RequiredRootFiles) -contains 'Start-LoneWolfWeb.sh') -Message 'Manifest is missing Start-LoneWolfWeb.sh.'
    Assert-WebPackagingSmoke -Condition (@($manifest.RequiredDirs) -contains 'web') -Message 'Manifest is missing web directory.'

    $port = Get-FreeTcpPort
    $launcher = Join-Path $stageRoot 'Start-LoneWolfWeb.ps1'
    $pwsh = Get-Command pwsh -ErrorAction Stop
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh.Source
    $startInfo.Arguments = ConvertTo-WebPackageArgumentString -Arguments @('-NoLogo', '-NoProfile', '-File', $launcher, '-ListenHost', '127.0.0.1', '-Port', [string]$port, '-NoBrowser')
    $startInfo.WorkingDirectory = $stageRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $server = [System.Diagnostics.Process]::Start($startInfo)

    $ready = $false
    for ($i = 0; $i -lt 80; $i++) {
        Start-Sleep -Milliseconds 250
        try {
            $stateResponse = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$port/api/state" -TimeoutSec 2
            if ([bool]$stateResponse.ok) {
                $ready = $true
                break
            }
        }
        catch {
        }
    }
    Assert-WebPackagingSmoke -Condition $ready -Message 'Packaged web launcher did not serve /api/state.'

    $rootHtml = [string](Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:$port/" -TimeoutSec 5)
    Assert-WebPackagingSmoke -Condition ($rootHtml.Contains('Lone Wolf Web Assistant')) -Message 'Packaged web launcher did not serve the frontend shell.'

    '[PASS] Web packaging smoke'
}
catch {
    Write-Error ("Web packaging smoke failed: {0}" -f $_.Exception.Message)
    throw
}
finally {
    Stop-WebPackageServer -Process $server
    Remove-WebPackageRuntime
}
