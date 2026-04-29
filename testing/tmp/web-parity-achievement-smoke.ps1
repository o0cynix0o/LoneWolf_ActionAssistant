Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$sessionScript = Join-Path $repoRoot 'web\lw_api_session.ps1'
$testSaveRoot = Join-Path $repoRoot 'testing\saves'
$sourceSavePath = Join-Path $testSaveRoot ("web-parity-achievement-source-{0}.json" -f $PID)
$lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
$hadLastSave = Test-Path -LiteralPath $lastSaveFile
$previousLastSave = if ($hadLastSave) { Get-Content -LiteralPath $lastSaveFile -Raw } else { $null }

Set-Location -LiteralPath $repoRoot
. (Join-Path $repoRoot 'lonewolf.ps1')
Initialize-LWData

function Assert-WebAchievementSmoke {
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

function New-WebAchievementSourceSave {
    New-Item -ItemType Directory -Path $testSaveRoot -Force | Out-Null

    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.CurrentSection = 73
    $state.Character.Name = 'Web Achievement Smoke'
    $state.Character.BookNumber = 7
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 28
    $state.Character.EnduranceMax = 30
    $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Animal Control')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.Inventory.Weapons = @('Sword', 'Bow')
    $state.Inventory.BackpackItems = @('Meal', 'Rope')
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Inventory.PocketSpecialItems = @('Diamond')
    $state.Inventory.GoldCrowns = 21
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

New-WebAchievementSourceSave

$session = Start-WebApiSession
try {
    $loaded = Invoke-WebApiAction -Process $session -Request @{
        action = 'loadGame'
        path   = [string]$sourceSavePath
    }

    Assert-WebAchievementSmoke -Condition ([bool]$loaded.payload.session.HasState) -Message 'Achievement source save did not load.'
    Assert-WebAchievementSmoke -Condition ([int]$loaded.payload.character.BookNumber -eq 7) -Message 'Achievement source should be Book 7.'
    Assert-WebAchievementSmoke -Condition ($null -ne $loaded.payload.achievements) -Message 'Achievement snapshot is missing.'

    $achievements = $loaded.payload.achievements
    Assert-WebAchievementSmoke -Condition ([int]$achievements.CurrentBookNumber -eq 7) -Message 'Achievement snapshot should be scoped to Book 7.'
    Assert-WebAchievementSmoke -Condition ([string]$achievements.CurrentBookTitle -eq 'Castle Death') -Message 'Achievement snapshot should carry the Book 7 title.'
    Assert-WebAchievementSmoke -Condition (@($achievements.CurrentBookEntries).Count -gt 0) -Message 'Current-book achievement entries are missing.'
    Assert-WebAchievementSmoke -Condition (@($achievements.BookTotals).Count -ge 7) -Message 'Per-book achievement totals did not include Books 1-7.'

    $snakeEyes = @($achievements.CurrentBookEntries | Where-Object { [string]$_.Id -eq 'snake_eyes' } | Select-Object -First 1)
    Assert-WebAchievementSmoke -Condition ($snakeEyes.Count -eq 1) -Message 'Book 7 Snake Eyes achievement entry is missing.'
    Assert-WebAchievementSmoke -Condition ([bool]$snakeEyes[0].Unlocked) -Message 'Snake Eyes should be unlocked from the synthetic source state.'
    Assert-WebAchievementSmoke -Condition ([string]$snakeEyes[0].Name -eq 'Snake Eyes') -Message 'Unlocked hidden achievement should expose its real display name.'
    Assert-WebAchievementSmoke -Condition (-not [string]::IsNullOrWhiteSpace([string]$snakeEyes[0].Description)) -Message 'Unlocked achievement description should be populated.'

    $hiddenLocked = @($achievements.CurrentBookEntries | Where-Object { [bool]$_.Hidden -and -not [bool]$_.Unlocked } | Select-Object -First 1)
    Assert-WebAchievementSmoke -Condition ($hiddenLocked.Count -eq 1) -Message 'Expected at least one locked hidden Book 7 achievement.'
    Assert-WebAchievementSmoke -Condition ([string]$hiddenLocked[0].Name -eq '???') -Message 'Locked hidden achievement name should stay masked in the web payload.'
    Assert-WebAchievementSmoke -Condition ([string]$hiddenLocked[0].Description -eq 'Hidden story achievement.') -Message 'Locked hidden achievement description should stay masked in the web payload.'

    $recentSnakeEyes = @($achievements.RecentUnlocks | Where-Object { [string]$_.Id -eq 'snake_eyes' } | Select-Object -First 1)
    Assert-WebAchievementSmoke -Condition ($recentSnakeEyes.Count -eq 1) -Message 'Recent unlock payload should include Snake Eyes.'
    Assert-WebAchievementSmoke -Condition ([int]$recentSnakeEyes[0].BookNumber -eq 7) -Message 'Recent unlock should preserve Book 7 context.'
    Assert-WebAchievementSmoke -Condition ([int]$recentSnakeEyes[0].Section -eq 73) -Message 'Recent unlock should preserve the section context.'

    $bookSevenTotal = @($achievements.BookTotals | Where-Object { [int]$_.BookNumber -eq 7 } | Select-Object -First 1)
    Assert-WebAchievementSmoke -Condition ($bookSevenTotal.Count -eq 1) -Message 'Book 7 total row is missing.'
    Assert-WebAchievementSmoke -Condition ([bool]$bookSevenTotal[0].Current) -Message 'Book 7 should be flagged as the current achievement book.'
    Assert-WebAchievementSmoke -Condition (-not [bool]$bookSevenTotal[0].Completed) -Message 'Book 7 should not be marked completed in this source state.'

    $command = Invoke-WebApiAction -Process $session -Request @{
        action  = 'safeCommand'
        command = 'achievements recent'
    }
    Assert-WebAchievementSmoke -Condition ([string]$command.payload.session.CurrentScreen -eq 'achievements') -Message 'achievements recent safe command should land on the achievements screen.'
    Assert-WebAchievementSmoke -Condition (@($command.payload.achievements.RecentUnlocks | Where-Object { [string]$_.Id -eq 'snake_eyes' }).Count -eq 1) -Message 'Achievement payload regressed after safe command screen switch.'

    '[PASS] Web parity achievement smoke'
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
