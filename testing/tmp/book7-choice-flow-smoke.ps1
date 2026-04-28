$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()

function Set-LWBookSevenChoiceSmokeQueues {
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

function New-LWBookSevenChoiceSmokeState {
    param(
        [int]$Gold = 20
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Book7 Choice Smoke'
    $state.Character.BookNumber = 7
    $state.Character.CombatSkillBase = 24
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Psi-surge', 'Huntmastery', 'Pathsmanship')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.CurrentSection = 1
    $state.RuleSet = 'Magnakai'
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)
    $state.Inventory.Weapons = @()
    $state.Inventory.BackpackItems = @()
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Inventory.PocketSpecialItems = @()
    $state.Inventory.GoldCrowns = [int]$Gold

    Set-LWHostGameState -State $state | Out-Null
    Sync-LWStateEquipmentBonuses -State $state
    Set-LWBackpackState -HasBackpack $true
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Assert-LWBookSevenChoiceSmoke {
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
        Name = 'Section 15 reward choice'
        Section = 15
        Texts = @('2', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $state -Names @('Kazan-Oud Platinum Amulet', 'Platinum Amulet') -Type 'special'))) -Message 'Section 15 did not add the Platinum Amulet.'
        }
    }
    @{
        Name = 'Section 73 Diamond pocketing'
        Section = 73
        YesNo = @($true)
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStateHasPocketSpecialItem -State $state -Names @('Diamond')) -Message 'Section 73 did not pocket the Diamond.'
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7Snake123ClueSeen') -Message 'Section 73 did not set the snake clue flag.'
        }
    }
    @{
        Name = 'Section 80 body loot'
        Section = 80
        Texts = @('8', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 26) -Message 'Section 80 did not add 6 Gold Crowns.'
        }
    }
    @{
        Name = 'Section 148 nest loot'
        Section = 148
        Texts = @('1', '4', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Mace' }).Count -eq 1) -Message 'Section 148 did not add the Mace.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Blanket' }).Count -eq 1) -Message 'Section 148 did not add the Blanket.'
        }
    }
    @{
        Name = 'Section 158 backpack loss'
        Section = 158
        Ints = @(1, 1)
        Arrange = {
            param($state)
            foreach ($item in @('Meal', 'Meal', 'Rope', 'Lantern', 'Potion of Laumspur')) {
                [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name $item)
            }
        }
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 0) -Message 'Section 158 did not remove food.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.BackpackItems).Count -eq 1) -Message 'Section 158 did not remove exactly two extra Backpack Items after the food loss.'
        }
    }
    @{
        Name = 'Section 186 whistle reward'
        Section = 186
        Texts = @('2', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $state -Names @('Silver Whistle') -Type 'special'))) -Message 'Section 186 did not add the Silver Whistle.'
        }
    }
    @{
        Name = 'Section 190 psychic escape cost'
        Section = 190
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq ([int]$state.ChoiceSmokePreEnduranceCurrent - 2)) -Message 'Section 190 did not apply the 2 END psychic cost.'
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7Section190PsychicCostApplied') -Message 'Section 190 did not set its one-shot story flag.'
            Invoke-LWRuleSetSectionEntryRules -State $state
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq ([int]$state.ChoiceSmokePreEnduranceCurrent - 2)) -Message 'Section 190 applied its psychic cost more than once.'
        }
    }
    @{
        Name = 'Section 199 corpse loot'
        Section = 199
        Texts = @('1', '2', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 26) -Message 'Section 199 did not add 6 Gold Crowns.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Lantern' }).Count -eq 1) -Message 'Section 199 did not add the Lantern.'
        }
    }
    @{
        Name = 'Section 220 guard loot'
        Section = 220
        Texts = @('1', '1', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Axe' }).Count -eq 1) -Message 'Section 220 did not add the Axe.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 220 did not add the Dagger.'
        }
    }
    @{
        Name = 'Section 227 body search and Power-key recovery'
        Section = 227
        Texts = @('2', '3', '0')
        YesNo = @($true)
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Rope' }).Count -eq 1) -Message 'Section 227 did not add the Rope.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 227 did not add the Dagger.'
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStateHasPocketSpecialItem -State $state -Names @('Power-key', 'Power Key')) -Message 'Section 227 did not recover the Power-key.'
        }
    }
    @{
        Name = 'Section 238 fallen guard loot'
        Section = 238
        Texts = @('1', '3', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Axe' }).Count -eq 1) -Message 'Section 238 did not add the Axe.'
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 22) -Message 'Section 238 did not add 2 Gold Crowns.'
        }
    }
    @{
        Name = 'Section 262 weapon rack'
        Section = 262
        Texts = @('2', '0')
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $state -Names @('Shield') -Type 'special'))) -Message 'Section 262 did not add the Shield.'
        }
    }
    @{
        Name = 'Section 264 confiscation stash'
        Section = 264
        Arrange = {
            param($state)
            [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Sword')
            [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Bow')
            [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Jewelled Mace')
        }
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons).Count -eq 0) -Message 'Section 264 did not clear carried weapons.'
            Assert-LWBookSevenChoiceSmoke -Condition ([string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $state -Names @('Jewelled Mace') -Type 'special'))) -Message 'Section 264 did not confiscate the Jewelled Mace.'
            Assert-LWBookSevenChoiceSmoke -Condition (@(Get-LWInventoryRecoveryItems -Type 'weapon').Count -eq 2) -Message 'Section 264 did not save both weapons to recovery.'
            Assert-LWBookSevenChoiceSmoke -Condition (@(Get-LWInventoryRecoveryItems -Type 'special').Count -eq 1) -Message 'Section 264 did not save the weapon-like Special Item to recovery.'
        }
    }
    @{
        Name = 'Section 271 Gold Key'
        Section = 271
        YesNo = @($true)
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStateHasPocketSpecialItem -State $state -Names @('Gold Key')) -Message 'Section 271 did not add the Gold Key.'
        }
    }
    @{
        Name = 'Section 301 arrow spill'
        Section = 301
        Arrange = {
            param($state)
            [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Quiver')
            $state.Inventory.QuiverArrows = 6
        }
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Inventory.QuiverArrows -eq 0) -Message 'Section 301 did not remove the remaining arrows.'
        }
    }
    @{
        Name = 'Section 305 Diamond pickup'
        Section = 305
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStateHasPocketSpecialItem -State $state -Names @('Diamond')) -Message 'Section 305 did not add the Diamond.'
        }
    }
    @{
        Name = 'Section 324 Platinum Amulet protection'
        Section = 324
        Arrange = {
            param($state)
            $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Nexus' })
            [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Kazan-Oud Platinum Amulet')
        }
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7HotTunnelSurvived') -Message 'Section 324 did not flag the protected hot-tunnel route.'
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq [int]$state.ChoiceSmokePreEnduranceCurrent) -Message 'Section 324 should not deal damage when the Platinum Amulet protects you.'
        }
    }
    @{
        Name = 'Section 333 Gold Key route'
        Section = 333
        Texts = @('1', '0')
        Arrange = {
            param($state)
            [void](TryAdd-LWPocketSpecialItemSilently -Name 'Gold Key')
        }
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition (-not (Test-LWStateHasPocketSpecialItem -State $state -Names @('Gold Key'))) -Message 'Section 333 did not consume the Gold Key.'
            Assert-LWBookSevenChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book7GoldKeyUsed') -Message 'Section 333 did not set the Gold Key route flag.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Spear' }).Count -eq 1) -Message 'Section 333 did not add the chosen Spear.'
        }
    }
    @{
        Name = 'Section 335 confiscation and damage'
        Section = 335
        Arrange = {
            param($state)
            [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Sword')
            [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Jewelled Mace')
        }
        Assert = {
            param($state)
            Assert-LWBookSevenChoiceSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq ([int]$state.ChoiceSmokePreEnduranceCurrent - 1)) -Message 'Section 335 did not apply the 1 END loss.'
            Assert-LWBookSevenChoiceSmoke -Condition (@($state.Inventory.Weapons).Count -eq 0) -Message 'Section 335 did not confiscate carried weapons.'
            Assert-LWBookSevenChoiceSmoke -Condition (@(Get-LWInventoryRecoveryItems -Type 'special').Count -eq 1) -Message 'Section 335 did not stash weapon-like Special Items for recovery.'
        }
    }
)

$results = @()

foreach ($test in $tests) {
    $state = New-LWBookSevenChoiceSmokeState
    Set-LWHostGameState -State $state | Out-Null
    $ints = if ($test.ContainsKey('Ints')) { @($test.Ints) } else { @() }
    $texts = if ($test.ContainsKey('Texts')) { @($test.Texts) } else { @() }
    $yesNo = if ($test.ContainsKey('YesNo')) { @($test.YesNo) } else { @() }
    Set-LWBookSevenChoiceSmokeQueues -Ints $ints -Texts $texts -YesNo $yesNo
    $state.CurrentSection = [int]$test.Section

    if ($test.ContainsKey('Arrange') -and $null -ne $test.Arrange) {
        & $test.Arrange $state
    }

    $state | Add-Member -Force -NotePropertyName ChoiceSmokePreEnduranceCurrent -NotePropertyValue ([int]$state.Character.EnduranceCurrent)

    try {
        Invoke-LWRuleSetSectionEntryRules -State $state
        & $test.Assert $state
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'ok'; Error = '' }
    }
    catch {
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'fail'; Error = $_.Exception.Message }
    }
}

$failures = @($results | Where-Object { $_.Status -ne 'ok' })
Write-Host ("Book 7 choice/state tests: {0}" -f $results.Count)
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
