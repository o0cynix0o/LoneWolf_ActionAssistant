Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$sessionScript = Join-Path $repoRoot 'web\lw_api_session.ps1'
$testSaveRoot = Join-Path $repoRoot 'testing\saves'
$sourceSavePath = Join-Path $testSaveRoot ("web-command-parity-source-{0}.json" -f $PID)
$lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
$hadLastSave = Test-Path -LiteralPath $lastSaveFile
$previousLastSave = if ($hadLastSave) { Get-Content -LiteralPath $lastSaveFile -Raw } else { $null }

Set-Location -LiteralPath $repoRoot
. (Join-Path $repoRoot 'lonewolf.ps1')
Initialize-LWData

function Assert-WebCommandParitySmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-WebCommandParitySourceSave {
    New-Item -ItemType Directory -Path $testSaveRoot -Force | Out-Null

    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.CurrentSection = 73
    $state.Character.Name = 'Web Command Parity'
    $state.Character.BookNumber = 7
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 27
    $state.Character.EnduranceMax = 30
    $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Animal Control')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.Inventory.Weapons = @('Sword', 'Bow')
    $state.Inventory.BackpackItems = @('Meal', 'Rope')
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Inventory.GoldCrowns = 17
    $state.Run = New-LWRunState -Difficulty 'Normal' -Permadeath:$false
    $state.Settings.SavePath = [string]$sourceSavePath
    $state.Settings.AutoSave = $false
    $state.CurrentBookStats = New-LWBookStats -BookNumber 7 -StartSection 1

    Set-LWHostGameState -State $state | Out-Null
    Add-LWBookSectionVisit -Section 73
    Rebuild-LWStoryAchievementFlagsFromState
    Sync-LWAchievements -Silent | Out-Null
    [void](Sync-LWRunIntegrityState -State $state -Reseal)

    $json = $state | ConvertTo-Json -Depth 40
    Set-Content -LiteralPath $sourceSavePath -Value $json -Encoding UTF8

    $lastSaveDir = Split-Path -Parent $lastSaveFile
    if (-not (Test-Path -LiteralPath $lastSaveDir)) {
        New-Item -ItemType Directory -Path $lastSaveDir -Force | Out-Null
    }
    Set-Content -LiteralPath $lastSaveFile -Value ([string]$sourceSavePath) -Encoding UTF8
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

function Get-WebCommandTexts {
    param([object]$Help)

    $commands = New-Object System.Collections.Generic.List[string]
    foreach ($group in @($Help.SafeCommandGroups)) {
        foreach ($entry in @($group.Commands)) {
            [void]$commands.Add([string]$entry.Command)
        }
    }
    return @($commands.ToArray())
}

New-WebCommandParitySourceSave
$session = Start-WebApiSession
try {
    $state = Invoke-WebApiAction -Process $session -Request @{ action = 'state' }
    $safeCommands = @($state.payload.help.SafeCommands | ForEach-Object { [string]$_ })
    $buttonCommands = @(Get-WebCommandTexts -Help $state.payload.help)
    $cliOnly = @($state.payload.help.CliOnlyCommands | ForEach-Object { [string]$_.Label })

    foreach ($command in @('roll', 'stats combat', 'campaign milestones', 'achievements progress', 'combat log')) {
        Assert-WebCommandParitySmoke -Condition ($safeCommands -contains $command) -Message "Safe command list is missing $command."
        Assert-WebCommandParitySmoke -Condition ($buttonCommands -contains $command) -Message "Command button groups are missing $command."
    }
    Assert-WebCommandParitySmoke -Condition ($cliOnly -contains 'setcs / setend / setmaxend') -Message 'CLI-only command notes are missing manual stat overrides.'

    $loaded = Invoke-WebApiAction -Process $session -Request @{ action = 'loadLastSave' }
    Assert-WebCommandParitySmoke -Condition ([string]$loaded.payload.character.Name -eq 'Web Command Parity') -Message 'Smoke source save did not load.'

    $stats = Invoke-WebApiAction -Process $session -Request @{ action = 'safeCommand'; command = 'stats combat' }
    Assert-WebCommandParitySmoke -Condition ([string]$stats.payload.session.CurrentScreen -eq 'stats') -Message 'stats combat did not open stats screen.'
    Assert-WebCommandParitySmoke -Condition ([string]$stats.payload.session.ScreenData.View -eq 'combat') -Message 'stats combat did not preserve combat view metadata.'

    $campaign = Invoke-WebApiAction -Process $session -Request @{ action = 'safeCommand'; command = 'campaign milestones' }
    Assert-WebCommandParitySmoke -Condition ([string]$campaign.payload.session.CurrentScreen -eq 'campaign') -Message 'campaign milestones did not open campaign screen.'
    Assert-WebCommandParitySmoke -Condition ([string]$campaign.payload.session.ScreenData.View -eq 'milestones') -Message 'campaign milestones did not preserve milestone view metadata.'

    $achievements = Invoke-WebApiAction -Process $session -Request @{ action = 'safeCommand'; command = 'achievements progress' }
    Assert-WebCommandParitySmoke -Condition ([string]$achievements.payload.session.CurrentScreen -eq 'achievements') -Message 'achievements progress did not open achievements screen.'
    Assert-WebCommandParitySmoke -Condition ([string]$achievements.payload.session.ScreenData.View -eq 'progress') -Message 'achievements progress did not preserve progress view metadata.'

    $roll = Invoke-WebApiAction -Process $session -Request @{ action = 'safeCommand'; command = 'roll' }
    $rollNotifications = @($roll.payload.session.Notifications | ForEach-Object { [string]$_.Message })
    Assert-WebCommandParitySmoke -Condition (($rollNotifications -join "`n").Contains('Random Number Table roll')) -Message 'roll did not return a visible random-number notification.'

    '[PASS] Web command parity smoke'
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
    if (Test-Path -LiteralPath $sourceSavePath) {
        Remove-Item -LiteralPath $sourceSavePath -Force
    }
}
