$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()

function Set-LWBookSevenAchievementSmokeQueues {
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

function New-LWBookSevenAchievementSmokeState {
    $state = New-LWDefaultState
    $state.Character.Name = 'Book7 Achievement Smoke'
    $state.Character.BookNumber = 7
    $state.RuleSet = 'Magnakai'
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Psi-surge', 'Huntmastery', 'Animal Control', 'Pathsmanship')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.CurrentSection = 1
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Inventory.BackpackItems = @()
    $state.Inventory.PocketSpecialItems = @()
    $state.Inventory.Weapons = @('Sword')
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)
    Set-LWHostGameState -State $state | Out-Null
    Set-LWBackpackState -HasBackpack $true
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Add-LWBookSevenAchievementVisitedSections {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int[]]$Sections
    )

    Set-LWHostGameState -State $State | Out-Null
    foreach ($section in @($Sections)) {
        Add-LWBookSectionVisit -Section ([int]$section)
    }
}

function Assert-LWBookSevenAchievementSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$tests = @(
    @{ Name = 'Book Seven Complete'; AchievementId = 'book_seven_complete'; Arrange = { param($state) $state.Character.CompletedBooks = @(7) } }
    @{ Name = 'Lorestone Bearer'; AchievementId = 'lorestone_bearer'; Arrange = { param($state) $state.Character.CompletedBooks = @(1,2,3,4,5,6,7) } }
    @{ Name = 'Riddle of the Zakhan'; AchievementId = 'riddle_of_the_zakhan'; Arrange = { param($state) Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(34); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Heat of the Moment'; AchievementId = 'heat_of_the_moment'; Arrange = { param($state) [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Kazan-Oud Platinum Amulet'); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Blue Breath'; AchievementId = 'blue_breath'; Arrange = { param($state) [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Sabito'); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Snake Eyes'; AchievementId = 'snake_eyes'; Arrange = { param($state) [void](TryAdd-LWPocketSpecialItemSilently -Name 'Diamond'); Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(73); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Kasin''s Last Words'; AchievementId = 'kasin_last_words'; Arrange = { param($state) Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(105); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Green Is Death'; AchievementId = 'green_is_death'; Arrange = { param($state) Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(133); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Silent No More'; AchievementId = 'silent_no_more'; Arrange = { param($state) Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(347); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'One Eye Open'; AchievementId = 'one_eye_open'; Ints = @(0); Arrange = { param($state) [void](TryAdd-LWPocketSpecialItemSilently -Name 'Gold Key'); $state.CurrentSection = 333; Invoke-LWRuleSetSectionEntryRules -State $state } }
    @{ Name = 'Cool Head, Hot Tunnel'; AchievementId = 'cool_head_hot_tunnel'; Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Nexus' }); [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Kazan-Oud Platinum Amulet'); $state.CurrentSection = 324; Invoke-LWRuleSetSectionEntryRules -State $state } }
    @{ Name = 'Sever the Tendril'; AchievementId = 'sever_the_tendril'; Arrange = { param($state) Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(317); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Up the Blue Beam'; AchievementId = 'up_the_blue_beam'; Arrange = { param($state) $state.Character.CompletedBooks = @(7); Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(118); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Throne of Fire'; AchievementId = 'throne_of_fire'; Arrange = { param($state) $state.Character.CompletedBooks = @(7); Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(174); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Out Through the Ash'; AchievementId = 'out_through_the_ash'; Arrange = { param($state) $state.Character.CompletedBooks = @(7); Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(250); Rebuild-LWStoryAchievementFlagsFromState } }
    @{ Name = 'Castle Death'; AchievementId = 'castle_death'; Arrange = { param($state) Add-LWBookSevenAchievementVisitedSections -State $state -Sections @(349); Rebuild-LWStoryAchievementFlagsFromState } }
)

$results = @()

foreach ($test in $tests) {
    $state = New-LWBookSevenAchievementSmokeState
    Set-LWHostGameState -State $state | Out-Null
    $ints = if ($test.ContainsKey('Ints')) { @($test.Ints) } else { @() }
    $texts = if ($test.ContainsKey('Texts')) { @($test.Texts) } else { @() }
    $yesNo = if ($test.ContainsKey('YesNo')) { @($test.YesNo) } else { @() }
    Set-LWBookSevenAchievementSmokeQueues -Ints $ints -Texts $texts -YesNo $yesNo

    try {
        & $test.Arrange $state
        Sync-LWAchievements -Silent | Out-Null
        $definition = Get-LWAchievementDefinitionById -Id ([string]$test.AchievementId)
        Assert-LWBookSevenAchievementSmoke -Condition ($null -ne $definition) -Message ("Achievement definition '{0}' was not found." -f [string]$test.AchievementId)
        Assert-LWBookSevenAchievementSmoke -Condition (Test-LWAchievementUnlocked -Id ([string]$test.AchievementId)) -Message ("Achievement '{0}' did not unlock." -f [string]$test.AchievementId)
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'ok'; Error = '' }
    }
    catch {
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'fail'; Error = $_.Exception.Message }
    }
}

$failures = @($results | Where-Object { $_.Status -ne 'ok' })
Write-Host ("Book 7 achievement tests: {0}" -f $results.Count)
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
