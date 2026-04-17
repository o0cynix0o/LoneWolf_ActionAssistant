$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()

function Set-LWBookSevenDifficultySmokeQueues {
    param(
        [int[]]$Ints = @(),
        [string[]]$Texts = @(),
        [bool[]]$YesNo = @()
    )

    $script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
    foreach ($value in @($Ints)) { $script:IntQueue.Enqueue([int]$value) }

    $script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($value in @($Texts)) { $script:TextQueue.Enqueue([string]$value) }

    $script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()
    foreach ($value in @($YesNo)) { $script:YesNoQueue.Enqueue([bool]$value) }
}

function global:Read-LWInt {
    param(
        [string]$Prompt,
        [int]$Default = 0,
        [int]$Min = [int]::MinValue,
        [int]$Max = [int]::MaxValue,
        [switch]$NoRefresh
    )

    if ($script:IntQueue.Count -gt 0) { return [int]$script:IntQueue.Dequeue() }
    if ($PSBoundParameters.ContainsKey('Default')) { return [int]$Default }
    if ($Min -ne [int]::MinValue) { return [int]$Min }
    return 0
}

function global:Read-LWText {
    param(
        [string]$Prompt,
        [string]$Default = '',
        [switch]$NoRefresh
    )

    if ($script:TextQueue.Count -gt 0) { return [string]$script:TextQueue.Dequeue() }
    if ($PSBoundParameters.ContainsKey('Default')) { return [string]$Default }
    return ''
}

function global:Read-LWYesNo {
    param([string]$Prompt, [bool]$Default = $false, [switch]$NoRefresh)
    if ($script:YesNoQueue.Count -gt 0) { return [bool]$script:YesNoQueue.Dequeue() }
    return [bool]$Default
}

function global:Read-LWInlineYesNo {
    param([string]$Prompt, [bool]$Default = $false)
    if ($script:YesNoQueue.Count -gt 0) { return [bool]$script:YesNoQueue.Dequeue() }
    return [bool]$Default
}

function global:Read-Host {
    param([string]$Prompt)
    if ($script:TextQueue.Count -gt 0) { return [string]$script:TextQueue.Dequeue() }
    return ''
}

function global:Write-LWInfo { param([string]$Message) }
function global:Write-LWWarn { param([string]$Message) }
function global:Write-LWError { param([string]$Message) }
function global:Add-LWNotification { param([string]$Message, [string]$Level) }
function global:Request-LWRender { param() }
function global:Refresh-LWScreen { param() }
function global:Clear-LWScreenHost { param([switch]$PreserveNotifications) }

function New-LWBookSevenDifficultySmokeState {
    param(
        [string]$Difficulty = 'Normal',
        [bool]$Permadeath = $false,
        [switch]$IncludeCompletedBooks
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Book7 Difficulty Smoke'
    $state.Character.BookNumber = 7
    $state.Character.CombatSkillBase = 24
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Psi-surge', 'Huntmastery', 'Animal Control', 'Pathsmanship')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.CurrentSection = 1
    $state.RuleSet = 'Magnakai'
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty $Difficulty -Permadeath:$Permadeath)
    $state.Inventory.Weapons = @('Sword')
    $state.Inventory.BackpackItems = @('Potion of Laumspur')
    $state.Inventory.SpecialItems = @('Book of the Magnakai', 'Sommerswerd')
    $state.Inventory.PocketSpecialItems = @()
    $state.Inventory.GoldCrowns = 15
    if ($IncludeCompletedBooks) {
        $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    }

    Set-LWHostGameState -State $state | Out-Null
    Set-LWBackpackState -HasBackpack $true
    Sync-LWStateEquipmentBonuses -State $state
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Assert-LWBookSevenDifficultySmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$repoSaveRoot = Join-Path $repoRoot 'testing\saves'
if (-not (Test-Path -LiteralPath $repoSaveRoot)) {
    New-Item -ItemType Directory -Path $repoSaveRoot | Out-Null
}

$tests = @(
    @{
        Name = 'Story mode prevents normal Book 7 END loss'
        Difficulty = 'Story'
        Arrange = {
            param($state)
            $state | Add-Member -Force -NotePropertyName StoryEnduranceBefore -NotePropertyValue ([int]$state.Character.EnduranceCurrent)
            $state.CurrentSection = 18
            Invoke-LWRuleSetSectionEntryRules -State $state
        }
        Assert = {
            param($state)
            Assert-LWBookSevenDifficultySmoke -Condition ([int]$state.Character.EnduranceCurrent -eq [int]$state.StoryEnduranceBefore) -Message 'Story mode did not prevent Book 7 section 18 END loss.'
        }
    }
    @{
        Name = 'Easy mode halves Book 7 END loss'
        Difficulty = 'Easy'
        Arrange = {
            param($state)
            $state | Add-Member -Force -NotePropertyName EasyEnduranceBefore -NotePropertyValue ([int]$state.Character.EnduranceCurrent)
            $state.CurrentSection = 18
            Invoke-LWRuleSetSectionEntryRules -State $state
        }
        Assert = {
            param($state)
            Assert-LWBookSevenDifficultySmoke -Condition ([int]$state.Character.EnduranceCurrent -eq ([int]$state.EasyEnduranceBefore - 1)) -Message 'Easy mode did not halve Book 7 section 18 END loss.'
        }
    }
    @{
        Name = 'Story completion only unlocks Story mode milestone'
        Difficulty = 'Story'
        IncludeCompletedBooks = $true
        Arrange = {
            param($state)
            $state.CurrentSection = 350
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'gentle_path') -Message 'Story completion did not unlock A Gentle Path.'
            Assert-LWBookSevenDifficultySmoke -Condition (-not (Test-LWAchievementUnlocked -Id 'hard_road')) -Message 'Story completion incorrectly unlocked Hard Road.'
        }
    }
    @{
        Name = 'Hard mode halves Sommerswerd power'
        Difficulty = 'Hard'
        Arrange = { param($state) }
        Assert = {
            param($state)
            Assert-LWBookSevenDifficultySmoke -Condition ((Get-LWModeAdjustedSommerswerdBonus -BaseBonus 8 -State $state) -eq 4) -Message 'Hard mode did not halve the Sommerswerd bonus.'
        }
    }
    @{
        Name = 'Hard mode healing cap allows only the final point'
        Difficulty = 'Hard'
        Arrange = {
            param($state)
            $stats = Ensure-LWCurrentBookStats -State $state
            $stats.HealingEnduranceRestored = 9
        }
        Assert = {
            param($state)
            $resolution = Resolve-LWHealingRestoreAmount -RequestedAmount 3 -State $state
            Assert-LWBookSevenDifficultySmoke -Condition ([int]$resolution.AppliedAmount -eq 1) -Message 'Hard mode did not cap Healing to the final remaining point.'
        }
    }
    @{
        Name = 'Hard completion unlocks challenge milestones'
        Difficulty = 'Hard'
        IncludeCompletedBooks = $true
        Arrange = {
            param($state)
            $stats = Ensure-LWCurrentBookStats -State $state
            $stats.HealingEnduranceRestored = 10
            $state.CurrentSection = 350
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'hard_road') -Message 'Hard completion did not unlock Hard Road.'
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'lean_healing') -Message 'Hard completion with capped healing did not unlock Lean Healing.'
        }
    }
    @{
        Name = 'Veteran suppresses unauthorized Sommerswerd power'
        Difficulty = 'Veteran'
        Ints = @(1)
        YesNo = @($true, $false)
        Arrange = {
            param($state)
            $state.Inventory.Weapons = @()
            $state.Inventory.SpecialItems = @('Book of the Magnakai', 'Sommerswerd')
            Start-LWCombat -Arguments @('Test Foe', '20', '20') | Out-Null
        }
        Assert = {
            param($state)
            Assert-LWBookSevenDifficultySmoke -Condition ([bool]$state.Combat.Active) -Message 'Veteran combat setup did not start.'
            Assert-LWBookSevenDifficultySmoke -Condition ([bool]$state.Combat.SommerswerdSuppressed) -Message 'Veteran mode did not suppress unauthorized Sommerswerd power.'
        }
    }
    @{
        Name = 'Veteran completion unlocks Veteran milestones'
        Difficulty = 'Veteran'
        IncludeCompletedBooks = $true
        Arrange = {
            param($state)
            $state.CurrentSection = 350
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'veteran_of_sommerlund') -Message 'Veteran completion did not unlock Veteran of Sommerlund.'
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'by_the_text') -Message 'Veteran completion did not unlock By the Text.'
        }
    }
    @{
        Name = 'Permadeath blocks rewind after death'
        Difficulty = 'Hard'
        Permadeath = $true
        Arrange = {
            param($state)
            Register-LWDeath -Cause 'Permadeath smoke death' | Out-Null
            Invoke-LWRewind -Steps 1
        }
        Assert = {
            param($state)
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWDeathActive) -Message 'Permadeath rewind check unexpectedly cleared the death state.'
            Assert-LWBookSevenDifficultySmoke -Condition ([int]$state.CurrentSection -eq 1) -Message 'Permadeath rewind check unexpectedly changed the current section.'
        }
    }
    @{
        Name = 'Permadeath death deletes the save file'
        Difficulty = 'Hard'
        Permadeath = $true
        Arrange = {
            param($state)
            $tempSavePath = Join-Path $repoSaveRoot 'book7-permadeath-smoke.json'
            Set-Content -LiteralPath $tempSavePath -Value '{}' -Encoding UTF8
            $state.Settings.SavePath = $tempSavePath
            Register-LWDeath -Cause 'Permadeath delete smoke' | Out-Null
        }
        Assert = {
            param($state)
            $tempSavePath = Join-Path $repoSaveRoot 'book7-permadeath-smoke.json'
            Assert-LWBookSevenDifficultySmoke -Condition (-not (Test-Path -LiteralPath $tempSavePath)) -Message 'Permadeath death did not delete the save file.'
            Assert-LWBookSevenDifficultySmoke -Condition ([string]::IsNullOrWhiteSpace([string]$state.Settings.SavePath)) -Message 'Permadeath death did not clear the save path.'
        }
    }
    @{
        Name = 'Permadeath completion unlocks permadeath milestones'
        Difficulty = 'Hard'
        Permadeath = $true
        IncludeCompletedBooks = $true
        Arrange = {
            param($state)
            $state.CurrentSection = 350
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'only_one_life') -Message 'Permadeath completion did not unlock Only One Life.'
            Assert-LWBookSevenDifficultySmoke -Condition (Test-LWAchievementUnlocked -Id 'mortal_wolf') -Message 'Hard Permadeath completion did not unlock Mortal Wolf.'
        }
    }
)

$results = @()

foreach ($test in $tests) {
    $state = New-LWBookSevenDifficultySmokeState -Difficulty $(if ($test.ContainsKey('Difficulty')) { [string]$test.Difficulty } else { 'Normal' }) -Permadeath:([bool]($test.ContainsKey('Permadeath') -and $test.Permadeath)) -IncludeCompletedBooks:([bool]($test.ContainsKey('IncludeCompletedBooks') -and $test.IncludeCompletedBooks))
    Set-LWHostGameState -State $state | Out-Null
    $ints = if ($test.ContainsKey('Ints')) { @($test.Ints) } else { @() }
    $texts = if ($test.ContainsKey('Texts')) { @($test.Texts) } else { @() }
    $yesNo = if ($test.ContainsKey('YesNo')) { @($test.YesNo) } else { @() }
    Set-LWBookSevenDifficultySmokeQueues -Ints $ints -Texts $texts -YesNo $yesNo

    try {
        & $test.Arrange $state
        & $test.Assert $state
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'ok'; Error = '' }
    }
    catch {
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'fail'; Error = $_.Exception.Message }
    }
}

$failures = @($results | Where-Object { $_.Status -ne 'ok' })
Write-Host ("Book 7 difficulty tests: {0}" -f $results.Count)
Write-Host ("Failures: {0}" -f $failures.Count)

foreach ($result in $results) {
    if ($result.Status -eq 'ok') {
        Write-Host ("[PASS] {0}" -f $result.Name)
    }
    else {
        Write-Host ("[FAIL] {0} -- {1}" -f $result.Name, $result.Error)
    }
}

if ($failures.Count -gt 0) {
    exit 1
}
