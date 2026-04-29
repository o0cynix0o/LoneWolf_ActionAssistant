Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$sessionScript = Join-Path $repoRoot 'web\lw_api_session.ps1'
$saveDir = Join-Path $repoRoot 'testing\saves'
$savePath = Join-Path $saveDir ("web-parity-death-smoke-{0}.json" -f $PID)
$lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
$hadLastSave = Test-Path -LiteralPath $lastSaveFile
$previousLastSave = if ($hadLastSave) { Get-Content -LiteralPath $lastSaveFile -Raw } else { $null }

function Assert-WebDeathSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Start-WebApiSession {
    $pwsh = Get-Command pwsh -ErrorAction Stop
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh.Source
    $startInfo.Arguments = ('-NoLogo -NoProfile -File "{0}"' -f $sessionScript)
    $startInfo.WorkingDirectory = [string]$repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) {
        throw 'Failed to start web API session.'
    }

    return $process
}

function Invoke-WebApiAction {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][hashtable]$Request
    )

    $json = $Request | ConvertTo-Json -Compress -Depth 20
    $Process.StandardInput.WriteLine($json)
    $Process.StandardInput.Flush()

    $line = $Process.StandardOutput.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) {
        $errorText = $Process.StandardError.ReadToEnd()
        throw "No response from web API session. $errorText"
    }

    $response = $line | ConvertFrom-Json
    if (-not [bool]$response.ok) {
        throw ("API action failed: {0}" -f [string]$response.message)
    }

    return $response
}

function Get-PendingFlow {
    param([object]$Response)

    if ($null -eq $Response -or $null -eq $Response.payload -or $null -eq $Response.payload.pendingFlow) {
        return $null
    }

    return $Response.payload.pendingFlow
}

function Restore-LastSavePointer {
    if ($hadLastSave) {
        $directory = Split-Path -Parent $lastSaveFile
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Set-Content -LiteralPath $lastSaveFile -Value $previousLastSave -Encoding UTF8
    }
    elseif (Test-Path -LiteralPath $lastSaveFile) {
        Remove-Item -LiteralPath $lastSaveFile -Force
    }
}

New-Item -ItemType Directory -Path $saveDir -Force | Out-Null

$session = Start-WebApiSession
try {
    $initial = Invoke-WebApiAction -Process $session -Request @{ action = 'state' }
    Assert-WebDeathSmoke -Condition (-not [bool]$initial.payload.session.HasState) -Message 'Initial state should not have an active run.'

    $wizard = Invoke-WebApiAction -Process $session -Request @{ action = 'startNewGameWizard' }
    $pending = Get-PendingFlow -Response $wizard
    if ($null -ne $pending -and [string]$pending.Step -eq 'replaceConfirm') {
        $wizard = Invoke-WebApiAction -Process $session -Request @{
            action = 'submitFlow'
            data   = @{ confirm = $true }
        }
        $pending = Get-PendingFlow -Response $wizard
    }
    Assert-WebDeathSmoke -Condition ($null -ne $pending -and [string]$pending.Step -eq 'runConfig') -Message 'New-game wizard did not reach runConfig.'

    $config = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{
            difficulty = 'Normal'
            permadeath = $false
        }
    }
    Assert-WebDeathSmoke -Condition ([string](Get-PendingFlow -Response $config).Step -eq 'identity') -Message 'Run config did not advance to identity.'

    $identity = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{
            name         = 'Web Death Smoke'
            bookNumber   = 1
            startSection = 1
        }
    }
    Assert-WebDeathSmoke -Condition ([string](Get-PendingFlow -Response $identity).Step -eq 'kaiDisciplines') -Message 'Identity did not advance to Kai discipline selection.'

    $kai = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ selected = @(1, 2, 3, 4, 5) }
    }
    Assert-WebDeathSmoke -Condition ([string](Get-PendingFlow -Response $kai).Step -eq 'startupEquipment') -Message 'Kai selection did not advance to startup equipment.'

    $created = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ response = '1' }
    }
    Assert-WebDeathSmoke -Condition ([bool]$created.payload.session.HasState) -Message 'Startup equipment did not create an active run.'
    Assert-WebDeathSmoke -Condition (-not [bool]$created.payload.session.DeathActive) -Message 'Fresh run should not start dead.'
    Assert-WebDeathSmoke -Condition ([int]$created.payload.reader.Section -eq 1) -Message 'Fresh run should start at section 1.'

    $sectionTwo = Invoke-WebApiAction -Process $session -Request @{
        action  = 'setSection'
        section = 2
    }
    Assert-WebDeathSmoke -Condition ($null -eq (Get-PendingFlow -Response $sectionTwo)) -Message 'Section 2 should not require a pending prompt in this smoke.'
    Assert-WebDeathSmoke -Condition ([int]$sectionTwo.payload.reader.Section -eq 2) -Message 'setSection did not move to section 2.'

    $saved = Invoke-WebApiAction -Process $session -Request @{
        action = 'saveGame'
        path   = [string]$savePath
    }
    Assert-WebDeathSmoke -Condition (Test-Path -LiteralPath $savePath) -Message 'Sandbox save file was not created.'
    Assert-WebDeathSmoke -Condition ([string]$saved.payload.session.SavePath -eq [string]$savePath) -Message 'Saved payload did not report the sandbox save path.'

    $death = Invoke-WebApiAction -Process $session -Request @{
        action = 'adjustEndurance'
        delta  = -999
    }
    Assert-WebDeathSmoke -Condition ([bool]$death.payload.session.DeathActive) -Message 'ENDURANCE loss did not activate death state.'
    Assert-WebDeathSmoke -Condition ([string]$death.payload.session.CurrentScreen -eq 'death') -Message 'Death did not switch to death screen.'
    Assert-WebDeathSmoke -Condition ($null -ne $death.payload.death -and [bool]$death.payload.death.Active) -Message 'Death snapshot is missing or inactive.'
    Assert-WebDeathSmoke -Condition ([string]$death.payload.death.Type -eq 'Endurance') -Message 'Death type should be Endurance.'
    Assert-WebDeathSmoke -Condition (-not [string]::IsNullOrWhiteSpace([string]$death.payload.death.Cause)) -Message 'Death cause is missing.'
    Assert-WebDeathSmoke -Condition ([int]$death.payload.death.Section -eq 2) -Message 'Death snapshot should preserve section 2.'
    Assert-WebDeathSmoke -Condition ([int]$death.payload.death.EnduranceCurrent -eq 0) -Message 'Death snapshot should show 0 current ENDURANCE.'
    Assert-WebDeathSmoke -Condition ([int]$death.payload.death.AvailableRewinds -ge 1) -Message 'Death snapshot should expose at least one rewind.'
    Assert-WebDeathSmoke -Condition ([string]$death.payload.death.SavePath -eq [string]$savePath) -Message 'Death snapshot should preserve save-path context.'

    foreach ($screen in @('stats', 'campaign', 'achievements', 'saves')) {
        $review = Invoke-WebApiAction -Process $session -Request @{
            action = 'showScreen'
            name   = $screen
        }
        Assert-WebDeathSmoke -Condition ([string]$review.payload.session.CurrentScreen -eq $screen) -Message "Death review screen '$screen' did not stick."
        Assert-WebDeathSmoke -Condition ([bool]$review.payload.session.DeathActive) -Message "Death state was lost while reviewing '$screen'."
        Assert-WebDeathSmoke -Condition ($null -ne $review.payload.death -and [bool]$review.payload.death.Active) -Message "Death snapshot disappeared while reviewing '$screen'."
    }

    $rewound = Invoke-WebApiAction -Process $session -Request @{
        action = 'rewindDeath'
        steps  = 1
    }
    Assert-WebDeathSmoke -Condition (-not [bool]$rewound.payload.session.DeathActive) -Message 'rewindDeath did not clear death state.'
    Assert-WebDeathSmoke -Condition ($null -eq $rewound.payload.death) -Message 'Death snapshot should be absent after rewind.'
    Assert-WebDeathSmoke -Condition ([string]$rewound.payload.session.CurrentScreen -eq 'sheet') -Message 'rewindDeath should return to the sheet screen.'
    Assert-WebDeathSmoke -Condition ([int]$rewound.payload.reader.Section -eq 1) -Message 'rewindDeath should return to section 1.'
    Assert-WebDeathSmoke -Condition ([int]$rewound.payload.character.EnduranceCurrent -gt 0) -Message 'rewindDeath should restore a living ENDURANCE value.'
    if ($null -ne $rewound.payload.currentBookStats -and $null -ne $rewound.payload.currentBookStats.RewindsUsed) {
        Assert-WebDeathSmoke -Condition ([int]$rewound.payload.currentBookStats.RewindsUsed -ge 1) -Message 'Rewind use was not reflected in current-book stats.'
    }

    '[PASS] Web parity death smoke'
}
finally {
    if ($null -ne $session -and -not $session.HasExited) {
        try {
            $session.StandardInput.Close()
        }
        catch {
        }

        if (-not $session.WaitForExit(3000)) {
            $session.Kill()
            $session.WaitForExit()
        }
    }

    Restore-LastSavePointer
}
