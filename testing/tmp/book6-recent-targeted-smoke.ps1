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
        ([bool]$Left.Exists -eq [bool]$Right.Exists) -and
        ([int64]$Left.Length -eq [int64]$Right.Length) -and
        ([string]$Left.LastWriteTimeUtc -eq [string]$Right.LastWriteTimeUtc)
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

Invoke-LWBookSixRecentScenario -Name 'Section098PartialArrowPurchase' -Action {
    $state = New-LWBookSixRecentState -Section 98 -Gold 3 -SpecialItems @('Book of the Magnakai', 'Quiver')
    $state.Inventory.QuiverArrows = 5
    Set-LWBookSixRecentSmokeQueues -Ints @(1, 11, 0, 0)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section098_partial_arrow_count' -Condition (
        (Get-LWQuiverArrowCount -State $state) -eq 6
    ) -Message ("Section 98 should fill the last quiver slot and leave the extra Arrow behind; actual {0}." -f (Get-LWQuiverArrowCount -State $state))

    Assert-LWBookSixRecent -Name 'section098_partial_arrow_gold' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 2
    ) -Message ("Section 98 should still charge 1 Gold Crown for the 2-Arrow purchase; actual {0}." -f [int]$state.Inventory.GoldCrowns)

    Assert-LWBookSixRecent -Name 'section098_partial_arrow_no_backpack' -Condition (
        @($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Arrow' }).Count -eq 0
    ) -Message 'Section 98 should leave the overflow Arrow behind instead of adding it to Backpack Items when a quiver is present.'
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
        (@($context.ModifierNotes) -contains 'Weaponmastery with Bow') -and
        (@($context.ModifierNotes) -contains 'Huntmastery')
    )
    Assert-LWBookSixRecent -Name 'section170_modifier' -Condition (
        $null -ne $context -and [int]$context.Modifier -eq 4 -and $hasExpectedNotes
    ) -Message 'Section 170 should resolve to a +4 modifier for Bow Weaponmastery plus Huntmastery.'
}

Invoke-LWBookSixRecentScenario -Name 'Section016And165MapOfVaretta' -Action {
    $state = New-LWBookSixRecentState -Section 165 -Gold 8
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section165_map_paid' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 3 -and (Test-LWStoryAchievementFlag -Name 'Book6Section165MapPaid')
    ) -Message ("Section 165 should deduct 5 Gold Crowns and mark the payment flag; actual gold {0}." -f [int]$state.Inventory.GoldCrowns)

    $state.CurrentSection = 16
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section016_map_claimed' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWMapOfVarettaItemNames) -Type 'special'
    ) -Message 'Section 16 should add the Map of Varetta as a Special Item.'

    Assert-LWBookSixRecent -Name 'section016_map_flag' -Condition (
        Test-LWStoryAchievementFlag -Name 'Book6Section016MapClaimed'
    ) -Message 'Section 16 should mark the map-claimed flag.'
}

Invoke-LWBookSixRecentScenario -Name 'Section027And304CessPurchase' -Action {
    $state = New-LWBookSixRecentState -Section 27 -Gold 6
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section027_cess_paid' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 3 -and (Test-LWStoryAchievementFlag -Name 'Book6CessPurchasePaid')
    ) -Message ("Section 27 should deduct 3 Gold Crowns for the Cess route; actual gold {0}." -f [int]$state.Inventory.GoldCrowns)

    $state.CurrentSection = 304
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section304_cess_claimed_from_027' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWCessItemNames) -Type 'special'
    ) -Message 'Section 304 should add the Cess after the section 27 payment route.'
}

Invoke-LWBookSixRecentScenario -Name 'Section273And304CessPurchase' -Action {
    $state = New-LWBookSixRecentState -Section 273 -Gold 5
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section273_cess_paid' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 2 -and (Test-LWStoryAchievementFlag -Name 'Book6CessPurchasePaid')
    ) -Message ("Section 273 should deduct 3 Gold Crowns for the Cess route; actual gold {0}." -f [int]$state.Inventory.GoldCrowns)

    $state.CurrentSection = 304
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section304_cess_claimed_from_273' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWCessItemNames) -Type 'special'
    ) -Message 'Section 304 should add the Cess after the section 273 payment route.'
}

Invoke-LWBookSixRecentScenario -Name 'Section137LevyAnd328Meal' -Action {
    $levyState = New-LWBookSixRecentState -Section 137 -Gold 4
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $levyState

    Assert-LWBookSixRecent -Name 'section137_levy_paid' -Condition (
        [int]$levyState.Inventory.GoldCrowns -eq 1 -and (Test-LWStoryAchievementFlag -Name 'Book6Section137LevyPaid')
    ) -Message ("Section 137 should deduct the 3 Gold Crown levy; actual gold {0}." -f [int]$levyState.Inventory.GoldCrowns)

    $mealState = New-LWBookSixRecentState -Section 328 -Gold 3
    Set-LWBookSixRecentSmokeQueues
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $mealState

    Assert-LWBookSixRecent -Name 'section328_meal_paid' -Condition (
        [int]$mealState.Inventory.GoldCrowns -eq 1 -and (Test-LWStoryAchievementFlag -Name 'Book6Section328MealPaid')
    ) -Message ("Section 328 should deduct 2 Gold Crowns for the roast beef; actual gold {0}." -f [int]$mealState.Inventory.GoldCrowns)
}

Invoke-LWBookSixRecentScenario -Name 'SectionOgRouteGuidance' -Action {
    $section096State = New-LWBookSixRecentState -Section 96 -Gold 7 -SpecialItems @('Book of the Magnakai', 'Cess')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section096State
    Assert-LWBookSixRecent -Name 'section096_guidance_no_side_effect' -Condition (
        ([int]$section096State.Inventory.GoldCrowns -eq 7) -and
        (Test-LWStateHasInventoryItem -State $section096State -Names (Get-LWCessItemNames) -Type 'special')
    ) -Message 'Section 96 guidance should not alter state.'

    $section169State = New-LWBookSixRecentState -Section 169 -Gold 6 -MagnakaiDisciplines @('Weaponmastery', 'Huntmastery', 'Psi-screen')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section169State
    Assert-LWBookSixRecent -Name 'section169_guidance_no_side_effect' -Condition (
        [int]$section169State.Inventory.GoldCrowns -eq 6
    ) -Message 'Section 169 guidance should not alter state.'

    $section205State = New-LWBookSixRecentState -Section 205 -Gold 6 -MagnakaiDisciplines @('Huntmastery', 'Psi-screen', 'Divination')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section205State
    Assert-LWBookSixRecent -Name 'section205_guidance_no_side_effect' -Condition (
        [int]$section205State.Inventory.GoldCrowns -eq 6
    ) -Message 'Section 205 guidance should not alter state.'

    $section211State = New-LWBookSixRecentState -Section 211 -Gold 6 -SpecialItems @('Book of the Magnakai', 'Map of Varetta')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section211State
    Assert-LWBookSixRecent -Name 'section211_guidance_no_side_effect' -Condition (
        Test-LWStateHasInventoryItem -State $section211State -Names (Get-LWMapOfVarettaItemNames) -Type 'special'
    ) -Message 'Section 211 guidance should not alter the Map of Varetta state.'

    $section248State = New-LWBookSixRecentState -Section 248 -Gold 6 -MagnakaiDisciplines @('Invisibility', 'Psi-screen', 'Divination')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section248State
    Assert-LWBookSixRecent -Name 'section248_guidance_no_side_effect' -Condition (
        [int]$section248State.Inventory.GoldCrowns -eq 6
    ) -Message 'Section 248 guidance should not alter state.'

    $section295State = New-LWBookSixRecentState -Section 295 -Gold 6 -SpecialItems @('Book of the Magnakai', 'Sommerswerd')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section295State
    Assert-LWBookSixRecent -Name 'section295_guidance_no_side_effect' -Condition (
        Test-LWStateHasInventoryItem -State $section295State -Names (Get-LWSommerswerdItemNames) -Type 'special'
    ) -Message 'Section 295 guidance should not alter the Sommerswerd state.'

    $section316State = New-LWBookSixRecentState -Section 316 -Gold 5 -MagnakaiDisciplines @('Weaponmastery', 'Psi-screen', 'Divination')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section316State
    Assert-LWBookSixRecent -Name 'section316_guidance_no_side_effect' -Condition (
        [int]$section316State.Inventory.GoldCrowns -eq 5
    ) -Message 'Section 316 guidance should not alter state.'

    $section318State = New-LWBookSixRecentState -Section 318 -Gold 6 -MagnakaiDisciplines @('Animal Control', 'Psi-screen', 'Divination')
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $section318State
    Assert-LWBookSixRecent -Name 'section318_guidance_no_side_effect' -Condition (
        [int]$section318State.Inventory.GoldCrowns -eq 6
    ) -Message 'Section 318 guidance should not alter state.'
}

Invoke-LWBookSixRecentScenario -Name 'Section275Cartographer' -Action {
    $state = New-LWBookSixRecentState -Section 275 -Gold 12 -BackpackItems @('Map of Tekaro')
    Set-LWBookSixRecentSmokeQueues -Ints @(2, 1, 1, 3, 0)
    Invoke-LWMagnakaiBookSixSectionEntryRules -State $state

    Assert-LWBookSixRecent -Name 'section275_map_removed' -Condition (
        @($state.Inventory.BackpackItems | Where-Object { [string]$_ -eq 'Map of Tekaro' }).Count -eq 0
    ) -Message 'Section 275 should let you sell a carried Map of Tekaro.'

    Assert-LWBookSixRecent -Name 'section275_map_of_luyen_added' -Condition (
        Test-LWStateHasInventoryItem -State $state -Names (Get-LWMapOfLuyenItemNames) -Type 'backpack'
    ) -Message 'Section 275 should let you buy the Map of Luyen.'

    Assert-LWBookSixRecent -Name 'section275_gold' -Condition (
        [int]$state.Inventory.GoldCrowns -eq 12
    ) -Message ("Section 275 should return to the starting 12 Gold Crowns after selling Map of Tekaro for 3 and buying Map of Luyen for 3; actual {0}." -f [int]$state.Inventory.GoldCrowns)
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
