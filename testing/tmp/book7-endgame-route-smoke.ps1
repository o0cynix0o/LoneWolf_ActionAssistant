$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()

function Set-LWBookSevenEndgameSmokeQueues {
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

function New-LWBookSevenEndgameSmokeState {
    param(
        [string]$Difficulty = 'Normal',
        [bool]$Permadeath = $false,
        [switch]$IncludeCompletedBooks
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Book7 Endgame Smoke'
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
    $state.Inventory.Weapons = @()
    $state.Inventory.BackpackItems = @()
    $state.Inventory.SpecialItems = @('Book of the Magnakai', 'Sommerswerd')
    $state.Inventory.PocketSpecialItems = @()
    $state.Inventory.GoldCrowns = 12
    if ($IncludeCompletedBooks) {
        $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    }

    Set-LWHostGameState -State $state | Out-Null
    Set-LWBackpackState -HasBackpack $true
    Sync-LWStateEquipmentBonuses -State $state
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Invoke-LWBookSevenRoutePath {
    param([int[]]$Sections)

    foreach ($section in @($Sections)) {
        Set-LWSection -Section ([int]$section)
        if (Test-LWDeathActive) {
            break
        }
    }
}

function Assert-LWBookSevenEndgameSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$tests = @(
    @{
        Name = 'Full Normal completion through the ash route'
        Ints = @(1, 1, 1, 1, 1)
        Texts = @('2', '0', '2', '0', '0')
        YesNo = @($true, $true)
        Arrange = {
            param($state)
            Apply-LWBookSevenStartingEquipment
            Invoke-LWBookSevenRoutePath -Sections @(15, 43, 73, 105, 133, 186, 271, 333, 138, 250, 315, 122, 350)
            Assert-LWBookSevenEndgameSmoke -Condition (-not (Test-LWDeathActive)) -Message 'The Normal ash-route smoke died before completion.'
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenEndgameSmoke -Condition (@($state.Character.CompletedBooks) -contains 7) -Message 'Book 7 did not complete on the Normal ash-route smoke.'
            Assert-LWBookSevenEndgameSmoke -Condition ([string]$state.Run.Status -eq 'Completed') -Message 'The run did not end in Completed status on the Normal ash-route smoke.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWAchievementUnlocked -Id 'book_seven_complete') -Message 'Book Seven Complete did not unlock on the Normal ash-route smoke.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWAchievementUnlocked -Id 'lorestone_bearer') -Message 'Lorestone Bearer did not unlock on the Normal ash-route smoke.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWAchievementUnlocked -Id 'out_through_the_ash') -Message 'Out Through the Ash did not unlock on the Normal ash-route smoke.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7OutThroughTheAshRoute') -Message 'The ash-route story flag was not set.'
        }
    }
    @{
        Name = 'Blue beam endgame route'
        Arrange = {
            param($state)
            $state.CurrentSection = 138
            Invoke-LWBookSevenRoutePath -Sections @(118, 200, 122, 350)
            Assert-LWBookSevenEndgameSmoke -Condition (-not (Test-LWDeathActive)) -Message 'The blue-beam route died before completion.'
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7BlueBeamRoute') -Message 'The blue-beam route flag was not set.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWAchievementUnlocked -Id 'up_the_blue_beam') -Message 'Up the Blue Beam did not unlock.'
        }
    }
    @{
        Name = 'Direct throne duel endgame route'
        Arrange = {
            param($state)
            $state.CurrentSection = 174
            Invoke-LWBookSevenRoutePath -Sections @(149, 267, 200, 122, 350)
            Assert-LWBookSevenEndgameSmoke -Condition (-not (Test-LWDeathActive)) -Message 'The throne-duel route died before completion.'
            Complete-LWBook
        }
        Assert = {
            param($state)
            Sync-LWAchievements -Silent | Out-Null
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7ThroneOfFireRoute') -Message 'The throne-of-fire route flag was not set.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWAchievementUnlocked -Id 'throne_of_fire') -Message 'Throne of Fire did not unlock.'
        }
    }
    @{
        Name = 'Castle Death signature failure route'
        Arrange = {
            param($state)
            $state.CurrentSection = 46
            Invoke-LWBookSevenRoutePath -Sections @(349)
            Sync-LWAchievements -Context 'section' -Silent | Out-Null
        }
        Assert = {
            param($state)
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWDeathActive) -Message 'Section 349 did not record the Castle Death failure.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7CastleDeathFailureSeen') -Message 'The Castle Death story flag was not set.'
            Assert-LWBookSevenEndgameSmoke -Condition (Test-LWAchievementUnlocked -Id 'castle_death') -Message 'Castle Death did not unlock.'
        }
    }
)

$results = @()

foreach ($test in $tests) {
    $state = New-LWBookSevenEndgameSmokeState -IncludeCompletedBooks
    Set-LWHostGameState -State $state | Out-Null
    $ints = if ($test.ContainsKey('Ints')) { @($test.Ints) } else { @() }
    $texts = if ($test.ContainsKey('Texts')) { @($test.Texts) } else { @() }
    $yesNo = if ($test.ContainsKey('YesNo')) { @($test.YesNo) } else { @() }
    Set-LWBookSevenEndgameSmokeQueues -Ints $ints -Texts $texts -YesNo $yesNo

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
Write-Host ("Book 7 endgame route tests: {0}" -f $results.Count)
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
