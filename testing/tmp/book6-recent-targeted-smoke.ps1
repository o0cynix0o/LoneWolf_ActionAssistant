$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()
$script:BookSixRecentResults = [System.Collections.Generic.List[object]]::new()

function Set-LWBookSixRecentSmokeQueues {
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

function New-LWBookSixRecentState {
    param(
        [int]$Section = 1,
        [int]$Gold = 0,
        [string[]]$MagnakaiDisciplines = @('Weaponmastery', 'Huntmastery', 'Psi-screen'),
        [string[]]$WeaponmasteryWeapons = @('Bow', 'Sword', 'Quarterstaff'),
        [string[]]$Weapons = @(),
        [string[]]$BackpackItems = @(),
        [string[]]$SpecialItems = @('Book of the Magnakai'),
        [string[]]$PocketSpecialItems = @(),
        [int]$Endurance = 24
    )

    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.Character.Name = 'Book 6 Recent Smoke'
    $state.Character.BookNumber = 6
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiDisciplines = @($MagnakaiDisciplines)
    $state.Character.MagnakaiRank = [Math]::Max(3, @($MagnakaiDisciplines).Count)
    $state.Character.WeaponmasteryWeapons = @($WeaponmasteryWeapons)
    $state.Character.CombatSkillBase = 24
    $state.Character.EnduranceCurrent = $Endurance
    $state.Character.EnduranceMax = $Endurance
    $state.CurrentSection = $Section
    $state.Inventory.Weapons = @($Weapons)
    $state.Inventory.BackpackItems = @($BackpackItems)
    $state.Inventory.SpecialItems = @($SpecialItems)
    $state.Inventory.PocketSpecialItems = @($PocketSpecialItems)
    $state.Inventory.GoldCrowns = $Gold
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)

    Set-LWHostGameState -State $state | Out-Null
    Set-LWBackpackState -HasBackpack $true
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Add-LWBookSixRecentResult {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Pass,
        [string]$Message = ''
    )

    $script:BookSixRecentResults.Add([pscustomobject]@{
            Name    = $Name
            Pass    = $Pass
            Message = $Message
        })

    if ($Pass) {
        Write-Host ("PASS {0}" -f $Name)
    }
    else {
        Write-Host ("FAIL {0}: {1}" -f $Name, $Message)
    }
}

function Assert-LWBookSixRecent {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Add-LWBookSixRecentResult -Name $Name -Pass $Condition -Message $Message
}

function Invoke-LWBookSixRecentScenario {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Host ("SCENARIO {0}" -f $Name)
    try {
        & $Action
    }
    catch {
        Add-LWBookSixRecentResult -Name ("{0}_exception" -f $Name.ToLowerInvariant()) -Pass $false -Message $_.Exception.Message
    }
}

function Get-LWBookSixRecentShellSuffix {
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        return 'ps51'
    }

    return 'ps7'
}

function Get-LWBookSixRecentSavePath {
    param([Parameter(Mandatory = $true)][string]$Stem)

    $suffix = Get-LWBookSixRecentShellSuffix
    return (Join-Path $repoRoot ("testing\saves\{0}-{1}-rerun.json" -f $Stem, $suffix))
}

function Get-LWFileSnapshot {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Exists            = $false
            Length            = -1
            LastWriteTimeUtc  = $null
        }
    }

    $item = Get-Item -LiteralPath $Path
    return [pscustomobject]@{
        Exists            = $true
        Length            = [int64]$item.Length
        LastWriteTimeUtc  = $item.LastWriteTimeUtc
    }
}

function Test-LWMatchingSnapshot {
    param(
        [Parameter(Mandatory = $true)][object]$Left,
        [Parameter(Mandatory = $true)][object]$Right
    )

    return (
        [bool]$Left.Exists -eq [bool]$Right.Exists -and
        [int64]$Left.Length -eq [int64]$Right.Length -and
        [string]$Left.LastWriteTimeUtc -eq [string]$Right.LastWriteTimeUtc
    )
}

Invoke-LWBookSixRecentScenario -Name 'Section002Apothecary' -Action {
    $state = New-LWBookSixRecentState -Section 2 -Gold 25 -Weapons @('Sword', 'Quarterstaff')
    Set-LWBookSixRecentSmokeQueues -Texts @('1', '1', '1', '1', '1', '0')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section002_has_Potion_of_Laumspur' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWHealingPotionItemNames) -Type 'backpack'
    ) -Message 'Section 2 did not add a healing-potion-group item.'

    Assert-LWBookSixRecent -Name 'section002_has_Potion_of_Gallowbrush' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWGallowbrushItemNames) -Type 'backpack'
    ) -Message 'Section 2 did not add Potion of Gallowbrush.'

    Assert-LWBookSixRecent -Name 'section002_has_Rendalims_Elixir' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWRendalimsElixirItemNames) -Type 'backpack'
    ) -Message 'Section 2 did not add Rendalim''s Elixir.'

    Assert-LWBookSixRecent -Name 'section002_has_Potion_of_Alether' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWAletherPotionItemNames) -Type 'backpack'
    ) -Message 'Section 2 did not add an Alether potion-group item.'

    Assert-LWBookSixRecent -Name 'section002_has_Graveweed_Concentrate' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWGraveweedItemNames) -Type 'backpack'
    ) -Message 'Section 2 did not add a Graveweed item.'

    Assert-LWBookSixRecent -Name 'section002_gold' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 3
    ) -Message ("Section 2 should leave 3 Gold Crowns after buying all five potions; actual {0}." -f [int]$state.Inventory.GoldCrowns)

    Assert-LWBookSixRecent -Name 'section002_backpackcount' -Condition (
        @($state.Inventory.BackpackItems).Count -eq 5
    ) -Message ("Section 2 should leave 5 Backpack Items; actual {0}." -f @($state.Inventory.BackpackItems).Count)
}

Invoke-LWBookSixRecentScenario -Name 'Section017RoomRoutes' -Action {
    $goldState = New-LWBookSixRecentState -Section 17 -Gold 5 -BackpackItems @('Meal')
    Set-LWBookSixRecentSmokeQueues -Ints @(3)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $goldState

    Assert-LWBookSixRecent -Name 'section017_gold_paid' -Condition (
        [int]$goldState.Inventory.GoldCrowns -eq 0
    ) -Message ("Section 17 hot-bath route should spend all 5 Gold Crowns; actual {0}." -f [int]$goldState.Inventory.GoldCrowns)

    Assert-LWBookSixRecent -Name 'section017_gold_target' -Condition (
        [int](Get-LWMagnakaiBookSixConditionValue -Name 'BookSixSection017RoomTarget' -Default 0) -eq 251
    ) -Message 'Section 17 hot-bath route should point to section 251.'

    Assert-LWBookSixRecent -Name 'section017_gold_flag' -Condition (
        Test-LWStoryAchievementFlag -Name 'Book6Section017Handled'
    ) -Message 'Section 17 gold route should mark the lodging flag.'

    $barterState = New-LWBookSixRecentState -Section 17 -Gold 0 -BackpackItems @('Meal')
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $barterState

    Assert-LWBookSixRecent -Name 'section017_barter_removed_item' -Condition (
        -not (Test-LWStateHasInventoryItem -State $barterState -Names @('Meal') -Type 'backpack')
    ) -Message 'Section 17 barter route should remove the traded Backpack Item.'

    Assert-LWBookSixRecent -Name 'section017_barter_target' -Condition (
        [int](Get-LWMagnakaiBookSixConditionValue -Name 'BookSixSection017RoomTarget' -Default 0) -eq 144
    ) -Message 'Section 17 barter route should point to section 144.'
}

Invoke-LWBookSixRecentScenario -Name 'Section098WeaponShop' -Action {
    $state = New-LWBookSixRecentState -Section 98 -Gold 20 -Weapons @('Sword')
    Set-LWBookSixRecentSmokeQueues -Ints @(1, 13, 11, 11, 1, 0, 0)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section098_large_quiver' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWLargeQuiverItemNames) -Type 'special'
    ) -Message 'Section 98 should add a Large Quiver.'

    Assert-LWBookSixRecent -Name 'section098_broadsword' -Condition (
        @($state.Inventory.Weapons) -contains 'Broadsword'
    ) -Message 'Section 98 should add the purchased Broadsword.'

    Assert-LWBookSixRecent -Name 'section098_arrows' -Condition (
        (Get-LWQuiverArrowCount -State $state) -eq 4
    ) -Message ("Section 98 should leave 4 arrows in the new quiver; actual {0}." -f (Get-LWQuiverArrowCount -State $state))

    Assert-LWBookSixRecent -Name 'section098_gold' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 6
    ) -Message ("Section 98 should leave 6 Gold Crowns; actual {0}." -f [int]$state.Inventory.GoldCrowns)
}

Invoke-LWBookSixRecentScenario -Name 'Section098SellQuiver' -Action {
    $state = New-LWBookSixRecentState -Section 98 -Gold 8 -SpecialItems @('Book of the Magnakai', 'Quiver')
    $state.Inventory.QuiverArrows = 2
    Set-LWBookSixRecentSmokeQueues -Ints @(2, 1, 0, 0)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section098_quiver_removed' -Condition (
        -not (Test-LWStateHasInventoryItem -State $state -Names (Get-LWQuiverItemNames) -Type 'special')
    ) -Message 'Section 98 should allow selling the Quiver.'

    Assert-LWBookSixRecent -Name 'section098_quiver_sale_gold' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 10
    ) -Message ("Section 98 should pay 2 Gold Crowns for a Quiver; actual {0}." -f [int]$state.Inventory.GoldCrowns)

    Assert-LWBookSixRecent -Name 'section098_quiver_sale_arrows' -Condition (
        (Get-LWQuiverArrowCount -State $state) -eq 0
    ) -Message ("Section 98 should clear the tracked quiver arrows when the Quiver is sold; actual {0}." -f (Get-LWQuiverArrowCount -State $state))
}

Invoke-LWBookSixRecentScenario -Name 'Section158And293SilverKey' -Action {
    $section158State = New-LWBookSixRecentState -Section 158 -Gold 26 -BackpackItems @('Meal')
    Set-LWBookSixRecentSmokeQueues -Texts @('0')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section158State

    Assert-LWBookSixRecent -Name 'section158_key_name' -Condition (
        Test-LWStateHasInventoryItem -State $section158State -Names (Get-LWSmallSilverKeyItemNames) -Type 'special'
    ) -Message 'Section 158 should add Sinede''s Silver Key using the DE-facing item-name group.'

    $section293State = New-LWBookSixRecentState -Section 293 -SpecialItems @('Book of the Magnakai', 'Sinede''s Silver Key')
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section293State

    Assert-LWBookSixRecent -Name 'section293_key_removed' -Condition (
        -not (Test-LWStateHasInventoryItem -State $section293State -Names (Get-LWSmallSilverKeyItemNames) -Type 'special')
    ) -Message 'Section 293 should erase Sinede''s Silver Key.'

    Assert-LWBookSixRecent -Name 'section293_flag' -Condition (
        Test-LWStoryAchievementFlag -Name 'Book6Section293SilverKeyUsed'
    ) -Message 'Section 293 should mark the key-used flag.'
}

Invoke-LWBookSixRecentScenario -Name 'Section170RollFix' -Action {
    $errorLogPath = Join-Path $repoRoot 'data\error.log'
    $savePath = Get-LWBookSixRecentSavePath -Stem 'campaign-save-roll-crash-copy'
    $beforeSnapshot = Get-LWFileSnapshot -Path $errorLogPath

    Load-LWGame -Path $savePath
    Write-LWCurrentSectionRandomNumberRoll -Roll 2 -State $script:GameState

    $afterSnapshot = Get-LWFileSnapshot -Path $errorLogPath
    Assert-LWBookSixRecent -Name 'section170_roll_no_crash' -Condition $true -Message 'Section 170 roll completed without throwing.'
    Assert-LWBookSixRecent -Name 'section170_errorlog' -Condition (
        Test-LWMatchingSnapshot -Left $beforeSnapshot -Right $afterSnapshot
    ) -Message 'Section 170 roll regression should not append to data/error.log.'

    $explicitState = New-LWBookSixRecentState -Section 170
    $context = Get-LWSectionRandomNumberContext -State $explicitState
    $hasExpectedNotes = (
        @($context.ModifierNotes) -contains 'Weaponmastery with Bow' -and
        @($context.ModifierNotes) -contains 'Huntmastery'
    )
    Assert-LWBookSixRecent -Name 'section170_modifier' -Condition (
        $null -ne $context -and [int]$context.Modifier -eq 4 -and $hasExpectedNotes
    ) -Message 'Section 170 should resolve to a +4 modifier for Bow Weaponmastery plus Huntmastery.'
}

Invoke-LWBookSixRecentScenario -Name 'Section297BroninSleeveShield' -Action {
    $usableState = New-LWBookSixRecentState -Section 297 -SpecialItems @('Book of the Magnakai', 'Chainmail Waistcoat')
    Set-LWBookSixRecentSmokeQueues -Ints @(1)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $usableState

    Assert-LWBookSixRecent -Name 'section297_sleeveshield_added' -Condition (
        Test-LWStateHasInventoryItem -State $usableState -Names (Get-LWBroninSleeveShieldItemNames) -Type 'special'
    ) -Message 'Section 297 should add the Bronin Sleeve-shield.'

    Assert-LWBookSixRecent -Name 'section297_waistcoat_removed' -Condition (
        -not (Test-LWStateHasInventoryItem -State $usableState -Names (Get-LWChainmailItemNames) -Type 'special')
    ) -Message 'Section 297 should remove the traded Chainmail Waistcoat.'

    Assert-LWBookSixRecent -Name 'section297_usable_bonus' -Condition (
        (Get-LWStateBroninSleeveShieldCombatSkillBonus -State $usableState) -eq 1 -and
        (Get-LWStateBroninSleeveShieldCombatEnduranceBonus -State $usableState) -eq 1
    ) -Message 'Section 297 should leave the Bronin Sleeve-shield bonuses active when no normal Shield remains.'

    $suppressedState = New-LWBookSixRecentState -Section 297 -SpecialItems @('Book of the Magnakai', 'Kai Shield', 'Chainmail Waistcoat')
    Set-LWBookSixRecentSmokeQueues -Ints @(2)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $suppressedState

    Assert-LWBookSixRecent -Name 'section297_suppressed_pool' -Condition (
        (Test-LWStateHasInventoryItem -State $suppressedState -Names (Get-LWBroninSleeveShieldItemNames) -Type 'special') -and
        (Get-LWStateShieldCombatSkillBonus -State $suppressedState) -eq 2 -and
        (Get-LWStateBroninSleeveShieldCombatSkillBonus -State $suppressedState) -eq 0 -and
        (Get-LWStateBroninSleeveShieldCombatEnduranceBonus -State $suppressedState) -eq 0
    ) -Message 'Section 297 should suppress Bronin Sleeve-shield bonuses while a normal Shield remains equipped.'
}

$failures = @($script:BookSixRecentResults | Where-Object { -not $_.Pass })
Write-Host ("Book 6 recent targeted checks: {0}" -f $script:BookSixRecentResults.Count)
Write-Host ("Failures: {0}" -f $failures.Count)

if ($failures.Count -gt 0) {
    exit 1
}
