Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

$script:LWModuleContextGeneration = -1

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    $generation = if ($Context.ContainsKey('_Generation')) { [int]$Context['_Generation'] } else { -1 }
    if ($generation -ge 0 -and $generation -eq $script:LWModuleContextGeneration) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
    $script:LWModuleContextGeneration = $generation
}

function Get-LWBookEightPassItemNames { return @('Pass') }
function Get-LWBookEightLodestoneItemNames { return @('Lodestone') }
function Get-LWBookEightGreyCrystalRingItemNames { return @('Grey Crystal Ring', 'Gray Crystal Ring') }
function Get-LWBookEightSilverBoxItemNames { return @('Silver Box') }
function Get-LWBookEightMapOfTharroItemNames { return @('Map of Tharro') }
function Get-LWBookEightGiakScrollItemNames { return @('Giak Scroll', 'Scroll') }
function Get-LWBookEightFlaskOfLarnumaItemNames { return @('Flask of Larnuma', 'Larnuma Liqueur', 'Larnuma Flask') }

function Test-LWBookEightHasPrimateRank {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.MagnakaiRank -ge 4)
}

function Test-LWBookEightHasTutelaryRank {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.MagnakaiRank -ge 5)
}

function Get-LWMagnakaiBookEightStartingChoices {
    Set-LWModuleContext -Context (Get-LWModuleContext)

    return @(
        [pscustomobject]@{ Id = 'sword'; Type = 'weapon'; Name = 'Sword'; DisplayName = 'Sword'; Description = 'Sword' },
        [pscustomobject]@{ Id = 'bow'; Type = 'weapon'; Name = 'Bow'; DisplayName = 'Bow'; Description = 'Bow' },
        [pscustomobject]@{ Id = 'quiver'; Type = 'special'; Name = 'Quiver'; DisplayName = 'Quiver'; Description = 'Quiver with 6 Arrows' },
        [pscustomobject]@{ Id = 'rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; DisplayName = 'Rope'; Description = 'Rope' },
        [pscustomobject]@{ Id = 'laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; DisplayName = 'Potion of Laumspur'; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'lantern'; Type = 'backpack'; Name = 'Lantern'; Quantity = 1; DisplayName = 'Lantern'; Description = 'Lantern' },
        [pscustomobject]@{ Id = 'mace'; Type = 'weapon'; Name = 'Mace'; DisplayName = 'Mace'; Description = 'Mace' },
        [pscustomobject]@{ Id = 'meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; DisplayName = '3 Meals'; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'dagger'; Type = 'weapon'; Name = 'Dagger'; DisplayName = 'Dagger'; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'fireseeds'; Type = 'pocketspecial'; Name = 'Fireseed'; Quantity = 3; DisplayName = '3 Fireseeds'; Description = '3 Fireseeds' }
    )
}

function Grant-LWMagnakaiBookEightStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    $quantity = if ((Test-LWPropertyExists -Object $Choice -Name 'Quantity') -and $null -ne $Choice.Quantity) { [int]$Choice.Quantity } else { 1 }

    if ([string]$Choice.Id -eq 'quiver') {
        if (-not (Test-LWStateHasQuiver -State $script:GameState)) {
            if (-not (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Quiver' -Quantity 1)) {
                Write-LWWarn 'No room to add the Quiver automatically. Make room and try again if you are keeping it.'
                return $false
            }
        }

        $script:GameState.Inventory.QuiverArrows = Get-LWQuiverArrowCapacity
        Write-LWInfo 'Book 8 starting item added: Quiver with 6 Arrows.'
        return $true
    }

    if ([string]$Choice.Type -eq 'pocketspecial') {
        $added = 0
        for ($i = 0; $i -lt $quantity; $i++) {
            if (TryAdd-LWPocketSpecialItemSilently -Name ([string]$Choice.Name)) {
                $added++
            }
        }

        if ($added -eq $quantity) {
            Write-LWInfo ("Book 8 starting item added: {0}." -f [string]$Choice.Description)
            return $true
        }

        Write-LWWarn ("Could not add all of the Book 8 starting item '{0}' automatically." -f [string]$Choice.DisplayName)
        return $false
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity $quantity) {
        Write-LWInfo ("Book 8 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 8 starting item '{0}' automatically. Make room and add it manually if needed." -f [string]$Choice.DisplayName)
    return $false
}

function Add-LWBookEightPocketItem {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$FlagName = '',
        [string]$SuccessMessage = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($FlagName) -and (Test-LWStoryAchievementFlag -Name $FlagName)) {
        return $true
    }

    if (TryAdd-LWPocketSpecialItemSilently -Name $Name) {
        if (-not [string]::IsNullOrWhiteSpace($FlagName)) {
            Set-LWStoryAchievementFlag -Name $FlagName
        }
        if (-not [string]::IsNullOrWhiteSpace($SuccessMessage)) {
            Write-LWInfo $SuccessMessage
        }
        return $true
    }

    Write-LWWarn ("No room to add {0} automatically. Make room and add it manually if you are keeping it." -f $Name)
    return $false
}

function Add-LWBookEightSpecialItem {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$FlagName = '',
        [string]$SuccessMessage = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($FlagName) -and (Test-LWStoryAchievementFlag -Name $FlagName)) {
        return $true
    }

    if (TryAdd-LWInventoryItemSilently -Type 'special' -Name $Name -Quantity 1) {
        if (-not [string]::IsNullOrWhiteSpace($FlagName)) {
            Set-LWStoryAchievementFlag -Name $FlagName
        }
        if (-not [string]::IsNullOrWhiteSpace($SuccessMessage)) {
            Write-LWInfo $SuccessMessage
        }
        return $true
    }

    Write-LWWarn ("No room to add {0} automatically. Make room and add it manually if you are keeping it." -f $Name)
    return $false
}

function Ensure-LWBookEightSectionOnePass {
    param([string]$SuccessMessage = 'Section 1: Pass added to Pocket Items.')

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 8) {
        return $false
    }

    if ([int]$script:GameState.CurrentSection -ne 1) {
        return $false
    }

    if (-not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookEightPassItemNames))) {
        if (TryAdd-LWPocketSpecialItemSilently -Name 'Pass') {
            Set-LWStoryAchievementFlag -Name 'Book8PassClaimed'
            if (-not [string]::IsNullOrWhiteSpace($SuccessMessage)) {
                Write-LWInfo $SuccessMessage
            }
            return $true
        }

        Write-LWWarn 'No room to add the Book 8 Pass automatically. Make room and add it manually if needed.'
        return $false
    }

    if (-not (Test-LWStoryAchievementFlag -Name 'Book8PassClaimed')) {
        Set-LWStoryAchievementFlag -Name 'Book8PassClaimed'
    }

    return $true
}

function Get-LWMagnakaiBookEightSection007ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'silver_box'; FlagName = 'Book8SilverBoxClaimed'; DisplayName = 'Silver Box'; Type = 'backpack'; Name = 'Silver Box'; Quantity = 1; Description = 'Silver Box' }
    )
}

function Get-LWMagnakaiBookEightSection201ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book8Section201SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'bow'; FlagName = 'Book8Section201BowClaimed'; DisplayName = 'Bow'; Type = 'weapon'; Name = 'Bow'; Quantity = 1; Description = 'Bow' },
        [pscustomobject]@{ Id = 'arrows'; FlagName = 'Book8Section201ArrowsClaimed'; DisplayName = '3 Arrows'; Type = 'backpack'; Name = 'Arrows'; Quantity = 3; Description = '3 Arrows' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book8Section201MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWMagnakaiBookEightSection228ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'larnuma'; FlagName = 'Book8FlaskOfLarnumaClaimed'; DisplayName = 'Flask of Larnuma'; Type = 'backpack'; Name = 'Flask of Larnuma'; Quantity = 1; Description = 'Flask of Larnuma' }
    )
}

function Get-LWMagnakaiBookEightSection306ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'map'; FlagName = 'Book8MapOfTharroClaimed'; DisplayName = 'Map of Tharro'; Type = 'backpack'; Name = 'Map of Tharro'; Quantity = 1; Description = 'Map of Tharro' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book8Section306MealClaimed'; DisplayName = '1 Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = '1 Meal' },
        [pscustomobject]@{ Id = 'axe'; FlagName = 'Book8Section306AxeClaimed'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' }
    )
}

function Invoke-LWMagnakaiBookEightMealRequirement {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedFlagName,
        [Parameter(Mandatory = $true)][string]$NoMealFlagName,
        [Parameter(Mandatory = $true)][string]$SectionLabel,
        [Parameter(Mandatory = $true)][string]$NoMealMessagePrefix,
        [Parameter(Mandatory = $true)][string]$FatalCause
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (Test-LWStoryAchievementFlag -Name $ResolvedFlagName) {
        return
    }

    Set-LWStoryAchievementFlag -Name $ResolvedFlagName
    $mealLocation = Find-LWStateInventoryItemLocation -State $script:GameState -Names @('Meal', 'Meals') -Types @('backpack')
    if ($null -ne $mealLocation) {
        [void](Remove-LWInventoryItemSilently -Type ([string]$mealLocation.Type) -Name ([string]$mealLocation.Name) -Quantity 1)
        Write-LWInfo ("{0}: ate 1 Meal." -f $SectionLabel)
        return
    }

    if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery') -or (Test-LWStateHasDiscipline -State $script:GameState -Name 'Hunting')) {
        Add-LWBookMealCoveredByHunting
        Write-LWInfo ("{0}: Huntmastery/Hunting covers the Meal requirement." -f $SectionLabel)
        return
    }

    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName $NoMealFlagName -Delta -3 -MessagePrefix $NoMealMessagePrefix -FatalCause $FatalCause)
}

function Invoke-LWMagnakaiBookEightGoldPayment {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][int]$Amount,
        [Parameter(Mandatory = $true)][string]$ContextLabel
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return $true
    }

    if ([int]$script:GameState.Inventory.GoldCrowns -lt $Amount) {
        Write-LWWarn ("{0}: this route costs {1} Gold Crown{2}, but only {3} are recorded." -f $ContextLabel, $Amount, $(if ($Amount -eq 1) { '' } else { 's' }), [int]$script:GameState.Inventory.GoldCrowns)
        return $false
    }

    Update-LWGold -Delta (-1 * $Amount)
    Set-LWStoryAchievementFlag -Name $FlagName
    Write-LWInfo ("{0}: paid {1} Gold Crown{2}." -f $ContextLabel, $Amount, $(if ($Amount -eq 1) { '' } else { 's' }))
    return $true
}

function Invoke-LWMagnakaiBookEightRemoveMeal {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][string]$ContextLabel
    )

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return
    }

    Set-LWStoryAchievementFlag -Name $FlagName
    $mealLocation = Find-LWStateInventoryItemLocation -State $script:GameState -Names @('Meal', 'Meals') -Types @('backpack')
    if ($null -ne $mealLocation) {
        [void](Remove-LWInventoryItemSilently -Type ([string]$mealLocation.Type) -Name ([string]$mealLocation.Name) -Quantity 1)
        Write-LWInfo ("{0}: gave 1 Meal to Paido." -f $ContextLabel)
    }
}

function Invoke-LWMagnakaiBookEightLoseCurrentWeapon {
    param([Parameter(Mandatory = $true)][string]$FlagName)

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return
    }

    Set-LWStoryAchievementFlag -Name $FlagName
    $weapon = ''
    if ((Test-LWPropertyExists -Object $script:GameState.Character -Name 'LastCombatWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Character.LastCombatWeapon)) {
        $weapon = [string]$script:GameState.Character.LastCombatWeapon
    }
    elseif (@($script:GameState.Inventory.Weapons).Count -eq 1) {
        $weapon = [string]@($script:GameState.Inventory.Weapons)[0]
    }

    if ([string]::IsNullOrWhiteSpace($weapon)) {
        Show-LWInventorySlotsSection -Type 'weapon'
        $weaponList = @($script:GameState.Inventory.Weapons)
        if ($weaponList.Count -le 0) {
            Write-LWWarn 'Section 258: no weapon is recorded to delete.'
            return
        }
        $slot = Read-LWInt -Prompt 'Section 258 destroyed weapon slot' -Min 1 -Max $weaponList.Count -NoRefresh
        $weapon = [string]$weaponList[$slot - 1]
    }

    if ((Remove-LWInventoryItemSilently -Type 'weapon' -Name $weapon -Quantity 1) -gt 0) {
        Write-LWInfo ("Section 258: {0} destroyed and removed from Weapons." -f $weapon)
    }
    else {
        Write-LWWarn ("Section 258: could not find {0} in Weapons to delete." -f $weapon)
    }
}

function Invoke-LWMagnakaiBookEightRiddlePenalty {
    if (Test-LWStoryAchievementFlag -Name 'Book8Section269PenaltyApplied') {
        return
    }

    Set-LWStoryAchievementFlag -Name 'Book8Section269PenaltyApplied'
    $specialItems = @(Get-LWInventoryItems -Type 'special')
    if ($specialItems.Count -ge 4) {
        $lost = [string]$specialItems[3]
        [void](Remove-LWInventoryItemSilently -Type 'special' -Name $lost -Quantity 1)
        Write-LWInfo ("Section 269: surrendered fourth Special Item ({0})." -f $lost)
        return
    }
    if ($specialItems.Count -gt 0) {
        $lost = [string]$specialItems[-1]
        [void](Remove-LWInventoryItemSilently -Type 'special' -Name $lost -Quantity 1)
        Write-LWInfo ("Section 269: surrendered last Special Item ({0})." -f $lost)
        return
    }

    $backpackItems = @(Get-LWInventoryItems -Type 'backpack')
    if ($backpackItems.Count -gt 0) {
        $lost = [string]$backpackItems[0]
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $lost -Quantity 1)
        Write-LWInfo ("Section 269: surrendered first Backpack Item ({0})." -f $lost)
        return
    }

    Write-LWInfo 'Section 269: no Special or Backpack Items are recorded to surrender.'
}

function Invoke-LWMagnakaiBookEightGreyRingExchange {
    if ((Test-LWStoryAchievementFlag -Name 'Book8GreyCrystalRingClaimed') -or (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBookEightGreyCrystalRingItemNames) -Type 'special')) {
        Set-LWStoryAchievementFlag -Name 'Book8GreyCrystalRingClaimed'
        return
    }

    $eligibleNames = @('Lodestone', 'Jewelled Mace', 'Silver Helm')
    $eligibleItems = @(
        foreach ($candidate in $eligibleNames) {
            $match = Get-LWMatchingStateInventoryItem -State $script:GameState -Names @($candidate) -Type 'special'
            if (-not [string]::IsNullOrWhiteSpace($match)) {
                [string]$match
            }
        }
    )

    if ($eligibleItems.Count -le 0) {
        Write-LWInfo 'Section 242: no eligible Special Item is recorded for the Grey Crystal Ring exchange.'
        return
    }

    $webContextCommand = Get-Command -Name 'Set-LWWebPendingContextOverride' -CommandType Function -ErrorAction SilentlyContinue
    if ($null -ne $webContextCommand) {
        $lines = @('Section 242 Grey Crystal Ring exchange', '', 'Choose one Special Item to trade for the Grey Crystal Ring:', '')
        for ($i = 0; $i -lt $eligibleItems.Count; $i++) {
            $lines += ("{0}. {1}" -f ($i + 1), [string]$eligibleItems[$i])
        }
        $lines += '0. Do not exchange'
        & $webContextCommand (($lines -join "`n").Trim())
    }

    while ($true) {
        Write-LWPanelHeader -Title 'Section 242 Ring Exchange' -AccentColor 'DarkYellow'
        for ($i = 0; $i -lt $eligibleItems.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. Exchange {1}" -f ($i + 1), [string]$eligibleItems[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text '0. Do not exchange' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt 'Section 242 exchange' -Default 0 -Min 0 -Max $eligibleItems.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            return
        }

        $lostItem = [string]$eligibleItems[$choiceIndex - 1]
        if ((Remove-LWInventoryItemSilently -Type 'special' -Name $lostItem -Quantity 1) -le 0) {
            Write-LWWarn ("Section 242: could not find {0} to exchange." -f $lostItem)
            continue
        }

        if (Add-LWBookEightSpecialItem -Name 'Grey Crystal Ring' -FlagName 'Book8GreyCrystalRingClaimed' -SuccessMessage ("Section 242: exchanged {0} for the Grey Crystal Ring." -f $lostItem)) {
            Set-LWStoryAchievementFlag -Name 'Book8Section242ExchangeMade'
            return
        }

        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name $lostItem -Quantity 1)
        return
    }
}

function Get-LWMagnakaiBookEightSectionRandomNumberContext {
    param([Parameter(Mandatory = $true)][object]$State)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State -or $null -eq $State.Character -or [int]$State.Character.BookNumber -ne 8) {
        return $null
    }

    $section = [int]$State.CurrentSection
    $modifier = 0
    $modifierNotes = @()

    switch ($section) {
        17 {
            if (@(Get-LWStateCompletedLoreCircles -State $State) -contains 'Fire') {
                $modifier += 3
                $modifierNotes += 'Lore-circle of Fire +3'
            }
            elseif (@(Get-LWStateCompletedLoreCircles -State $State) -contains 'Light') {
                $modifier += 3
                $modifierNotes += 'Lore-circle of Light +3'
            }
            return (New-LWSectionRandomNumberContext -Section 17 -Description 'Cabin infection resistance check: 0-7 -> 6; 8+ -> 77.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        18 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Animal Control') -or (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery')) {
                $modifier += 3
                $modifierNotes += 'Animal Control or Huntmastery +3'
            }
            if (Test-LWBookEightHasPrimateRank -State $State) {
                $modifier += 2
                $modifierNotes += 'Primate rank +2'
            }
            return (New-LWSectionRandomNumberContext -Section 18 -Description 'Levitron boarding escape check: 0-3 -> 57; 4+ -> 234.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        28 { return (New-LWSectionRandomNumberContext -Section 28 -Description 'Street pursuit check: 0-4 -> 38; 5+ -> 125.') }
        45 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Invisibility') {
                $modifier += 3
                $modifierNotes += 'Invisibility +3'
            }
            return (New-LWSectionRandomNumberContext -Section 45 -Description 'Hide from the Helghast check: 0-6 -> 155; 7+ -> 167.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        54 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') -or (Test-LWStateHasDiscipline -State $State -Name 'Divination')) {
                $modifier += 3
                $modifierNotes += 'Huntmastery or Divination +3'
            }
            return (New-LWSectionRandomNumberContext -Section 54 -Description 'Danarg tracking check: 0-2 -> 134; 3+ -> 219.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        77 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 2
                $modifierNotes += 'Huntmastery +2'
            }
            return (New-LWSectionRandomNumberContext -Section 77 -Description 'Cabin disease check: 0-1 -> 51; 2+ -> 43.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        86 { return (New-LWSectionRandomNumberContext -Section 86 -Description 'Grey Crystal Ring backlash: 0 counts as 10 ENDURANCE loss.' -ZeroCountsAsTen:$true) }
        102 { return (New-LWSectionRandomNumberContext -Section 102 -Description 'Swamp route check: 0-5 -> 278; 6-9 -> 150.') }
        117 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 3
                $modifierNotes += 'Huntmastery +3'
            }
            if ((Test-LWStateHasDiscipline -State $State -Name 'Divination') -and (Test-LWBookEightHasPrimateRank -State $State)) {
                $modifier += 1
                $modifierNotes += 'Divination at Primate rank +1'
            }
            return (New-LWSectionRandomNumberContext -Section 117 -Description 'Bowyer ambush check: 0-4 -> 154; 5-8 -> 40; 9+ -> 251.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        122 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 2
                $modifierNotes += 'Huntmastery +2'
            }
            return (New-LWSectionRandomNumberContext -Section 122 -Description 'Crossbow ambush check: 0-5 -> 115; 6+ -> 334.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        176 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 3
                $modifierNotes += 'Huntmastery +3'
            }
            return (New-LWSectionRandomNumberContext -Section 176 -Description 'Crossbow ambush check: 0-5 -> 115; 6+ -> 334.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        209 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Animal Control') {
                $modifier += 3
                $modifierNotes += 'Animal Control +3'
            }
            return (New-LWSectionRandomNumberContext -Section 209 -Description 'Horse control check: 0-6 -> 162; 7+ -> 303.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        246 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Bow') -ne $null)) {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow +3'
            }
            return (New-LWSectionRandomNumberContext -Section 246 -Description 'Bow shot at the Helghast: 0-4 -> 184; 5-7 -> 4; 8+ -> 213.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        284 {
            if (Test-LWBookEightHasPrimateRank -State $State) {
                $modifier += 3
                $modifierNotes += 'Primate rank +3'
            }
            return (New-LWSectionRandomNumberContext -Section 284 -Description 'Bor Brew collapse check: 0-5 -> 302; 6+ -> 119.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        296 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') -and (Test-LWBookEightHasPrimateRank -State $State)) {
                $modifier += 3
                $modifierNotes += 'Huntmastery at Primate rank +3'
            }
            return (New-LWSectionRandomNumberContext -Section 296 -Description 'Danarg poison path check: 0-4 -> 69; 5+ -> 140.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        310 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Bow') -ne $null)) {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow +3'
            }
            return (New-LWSectionRandomNumberContext -Section 310 -Description 'Bow shot at the Helghast: 0-8 -> 184; 9+ -> 213.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        default { return $null }
    }
}

function Invoke-LWMagnakaiBookEightSectionRandomNumberResolution {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object]$Context = $null,
        [int[]]$Rolls = @(),
        [int[]]$EffectiveRolls = @(),
        [int]$Subtotal = 0,
        [int]$AdjustedTotal = 0
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if ($null -eq $Context) {
        return
    }

    switch ([int]$Context.Section) {
        86 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book8Section086RingLossApplied')) {
                Set-LWStoryAchievementFlag -Name 'Book8Section086RingLossApplied'
                $loss = [Math]::Max(0, [int]$AdjustedTotal)
                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section086RingDamageApplied' -Delta (-1 * $loss) -MessagePrefix 'Section 86: the Grey Crystal Ring backlash burns through you.' -FatalCause 'The Grey Crystal Ring backlash at section 86 reduced your Endurance to zero.')
            }
        }
    }
}

function Invoke-LWMagnakaiBookEightStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State

    switch ($Section) {
        1 { Set-LWStoryAchievementFlag -Name 'Book8PassClaimed' }
        7 { Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved'; Set-LWStoryAchievementFlag -Name 'Book8SilverBoxRoute' }
        16 { Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved' }
        59 { Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved' }
        100 { Set-LWStoryAchievementFlag -Name 'Book8OhridoLorestoneClaimed' }
        202 { Set-LWStoryAchievementFlag -Name 'Book8LodestoneClaimed' }
        267 { Set-LWStoryAchievementFlag -Name 'Book8LevitronEscapeRoute' }
        281 { Set-LWStoryAchievementFlag -Name 'Book8JungleHorrorFailureSeen' }
        350 { Set-LWStoryAchievementFlag -Name 'Book8LevitronEscapeRoute' }
    }
}

function Invoke-LWMagnakaiBookEightStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State

    switch ("$FromSection->$ToSection") {
        '126->16' { Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved' }
        '141->59' { Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved' }
        '338->7' { Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved'; Set-LWStoryAchievementFlag -Name 'Book8SilverBoxRoute' }
        '244->20' { [void](Invoke-LWMagnakaiBookEightGoldPayment -FlagName 'Book8Section244FortunePaid' -Amount 20 -ContextLabel 'Section 244 fortune teller') }
        '89->266' { [void](Invoke-LWMagnakaiBookEightGoldPayment -FlagName 'Book8Section089BargeFarePaid' -Amount 10 -ContextLabel 'Section 89 barge fare') }
        '299->266' { [void](Invoke-LWMagnakaiBookEightGoldPayment -FlagName 'Book8Section299BargeFarePaid' -Amount 10 -ContextLabel 'Section 299 barge fare') }
        '316->139' { [void](Invoke-LWMagnakaiBookEightGoldPayment -FlagName 'Book8Section316RingPaid' -Amount 30 -ContextLabel 'Section 316 Grey Crystal Ring') }
        '267->350' { Set-LWStoryAchievementFlag -Name 'Book8LevitronEscapeRoute' }
    }
}

function Get-LWMagnakaiBookEightInstantDeathCause {
    param([int]$Section)

    switch ($Section) {
        21 { return 'Section 21: the creature venom swiftly kills you.' }
        51 { return 'Section 51: the cabin disease overwhelms you before help can arrive.' }
        57 { return 'Section 57: the fall from the Levitron kills you.' }
        69 { return 'Section 69: poison from the Danarg claims your life.' }
        75 { return 'Section 75: the Helghast fireball kills you.' }
        121 { return 'Section 121: the swamp trap drags you under.' }
        134 { return 'Section 134: the Danarg closes around you forever.' }
        154 { return 'Section 154: the bowyer''s shot kills you.' }
        158 { return 'Section 158: the Levitron is destroyed before you can save it.' }
        165 { return 'Section 165: the swamp horror kills you.' }
        200 { return 'Section 200: delaying too long dooms the Levitron.' }
        222 { return 'Section 222: the poisoned blade ends your quest.' }
        223 { return 'Section 223: the monks overwhelm you.' }
        237 { return 'Section 237: your quest fails in the swamp.' }
        263 { return 'Section 263: the Danarg claims another victim.' }
        281 { return 'Section 281: the jungle poison kills you instantly.' }
        295 { return 'Section 295: the swamp swallows you.' }
        322 { return 'Section 322: your final mistake ends the quest.' }
        default { return $null }
    }
}

function Invoke-LWMagnakaiBookEightSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if (-not (Test-LWHasState)) {
        return
    }

    $section = [int]$script:GameState.CurrentSection
    $instantDeathCause = Get-LWMagnakaiBookEightInstantDeathCause -Section $section
    if (-not [string]::IsNullOrWhiteSpace($instantDeathCause)) {
        if ($section -eq 281) {
            Set-LWStoryAchievementFlag -Name 'Book8JungleHorrorFailureSeen'
        }
        Invoke-LWInstantDeath -Cause $instantDeathCause
        return
    }

    switch ($section) {
        1 {
            [void](Ensure-LWBookEightSectionOnePass)
        }
        7 {
            Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved'
            Invoke-LWBookFourChoiceTable -Title 'Section 7 Prize' -PromptLabel 'Section 7 choice' -ContextLabel 'Section 7' -Choices (Get-LWMagnakaiBookEightSection007ChoiceDefinitions) -Intro 'Section 7: take the Silver Box if you want to keep it.'
        }
        15 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section015DamageApplied' -Delta -2 -MessagePrefix 'Section 15: the Fireseed blast leaves your hand in agony.' -FatalCause 'The Fireseed injury at section 15 reduced your Endurance to zero.')
        }
        16 {
            Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved'
            [void](Invoke-LWSectionGoldReward -FlagName 'Book8Section016LuneClaimed' -Amount 5 -ContextLabel 'Section 16' -MessagePrefix 'Section 16: Count Conundrum pays 20 Lune.')
        }
        34 {
            Invoke-LWMagnakaiBookEightRemoveMeal -FlagName 'Book8Section034MealSpent' -ContextLabel 'Section 34'
        }
        39 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section039DamageApplied' -Delta -8 -MessagePrefix 'Section 39: the Helghast fireball slams into your chest.' -FatalCause 'The fireball at section 39 reduced your Endurance to zero.')
            if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Divination') -and (Test-LWBookEightHasTutelaryRank -State $script:GameState)) {
                Write-LWInfo 'Section 39: Divination at Tutelary rank opens the route to section 131.'
            }
        }
        40 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section040DamageApplied' -Delta -2 -MessagePrefix 'Section 40: the bowyer''s arrow grazes your forearm.' -FatalCause 'The wound at section 40 reduced your Endurance to zero.')
        }
        59 {
            Set-LWStoryAchievementFlag -Name 'Book8ConundrumSolved'
            [void](Invoke-LWSectionGoldReward -FlagName 'Book8Section059LuneClaimed' -Amount 10 -ContextLabel 'Section 59' -MessagePrefix 'Section 59: Count Conundrum pays 40 Lune.')
        }
        87 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book8Section087SilverBowDestroyed')) {
                Set-LWStoryAchievementFlag -Name 'Book8Section087SilverBowDestroyed'
                $silverBow = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'
                if (-not [string]::IsNullOrWhiteSpace($silverBow)) {
                    [void](Remove-LWInventoryItemSilently -Type 'special' -Name $silverBow -Quantity 1)
                    Write-LWInfo 'Section 87: Silver Bow of Duadon destroyed and removed from Special Items.'
                }
            }
        }
        100 {
            Set-LWStoryAchievementFlag -Name 'Book8OhridoLorestoneClaimed'
            if (-not (Test-LWStoryAchievementFlag -Name 'Book8Section100EnduranceRestored')) {
                Set-LWStoryAchievementFlag -Name 'Book8Section100EnduranceRestored'
                $oldEndurance = [int]$script:GameState.Character.EnduranceCurrent
                $newEndurance = [int]$script:GameState.Character.EnduranceMax
                $script:GameState.Character.EnduranceCurrent = $newEndurance
                if ($newEndurance -gt $oldEndurance) {
                    Add-LWBookEnduranceDelta -Delta ($newEndurance - $oldEndurance)
                    Write-LWInfo ("Section 100: the Lorestone restores ENDURANCE to {0}/{1}." -f $newEndurance, [int]$script:GameState.Character.EnduranceMax)
                }
            }
        }
        104 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section104DamageApplied' -Delta -2 -MessagePrefix 'Section 104: the Bor Brew aftermath pounds through your skull.' -FatalCause 'The injury at section 104 reduced your Endurance to zero.')
        }
        105 {
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section105MealHandled' -NoMealFlagName 'Book8Section105NoMealLossApplied' -SectionLabel 'Section 105' -NoMealMessagePrefix 'Section 105: hunger weakens you in the Danarg.' -FatalCause 'The hunger at section 105 reduced your Endurance to zero.'
        }
        115 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section115DamageApplied' -Delta -8 -MessagePrefix 'Section 115: the crossbow bolt paralyses your arm.' -FatalCause 'The crossbow wound at section 115 reduced your Endurance to zero.')
        }
        129 {
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section129MealHandled' -NoMealFlagName 'Book8Section129NoMealLossApplied' -SectionLabel 'Section 129' -NoMealMessagePrefix 'Section 129: hunger weakens you after the Taan-spider.' -FatalCause 'The hunger at section 129 reduced your Endurance to zero.'
        }
        139 {
            [void](Add-LWBookEightSpecialItem -Name 'Grey Crystal Ring' -FlagName 'Book8GreyCrystalRingClaimed' -SuccessMessage 'Section 139: Grey Crystal Ring added to Special Items.')
            Write-LWInfo 'Section 139: optional Special Item sales for 8 Gold Crowns each remain manual.'
        }
        146 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section146DamageApplied' -Delta -5 -MessagePrefix 'Section 146: the wound costs you blood and strength.' -FatalCause 'The wound at section 146 reduced your Endurance to zero.')
        }
        150 {
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section150MealHandled' -NoMealFlagName 'Book8Section150NoMealLossApplied' -SectionLabel 'Section 150' -NoMealMessagePrefix 'Section 150: hunger weakens you at noon.' -FatalCause 'The hunger at section 150 reduced your Endurance to zero.'
        }
        152 {
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section152MealHandled' -NoMealFlagName 'Book8Section152NoMealLossApplied' -SectionLabel 'Section 152' -NoMealMessagePrefix 'Section 152: hunger weakens you on the ridge road.' -FatalCause 'The hunger at section 152 reduced your Endurance to zero.'
        }
        156 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section156DamageApplied' -Delta -6 -MessagePrefix 'Section 156: blood loss from the infected wound drains you.' -FatalCause 'The wound at section 156 reduced your Endurance to zero.')
            Write-LWInfo 'Section 156: if you possess Tincture of Oxydine or Oede herb, use it now to cure the korovax infection.'
        }
        159 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section159DamageApplied' -Delta -5 -MessagePrefix 'Section 159: Kezoor''s sorcery burns your body.' -FatalCause 'Kezoor''s sorcery at section 159 reduced your Endurance to zero.')
        }
        170 {
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section170MealHandled' -NoMealFlagName 'Book8Section170NoMealLossApplied' -SectionLabel 'Section 170' -NoMealMessagePrefix 'Section 170: the long ride leaves you tired and hungry.' -FatalCause 'The hunger at section 170 reduced your Endurance to zero.'
        }
        175 {
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section175MealHandled' -NoMealFlagName 'Book8Section175NoMealLossApplied' -SectionLabel 'Section 175' -NoMealMessagePrefix 'Section 175: hunger weakens you in the mire.' -FatalCause 'The hunger at section 175 reduced your Endurance to zero.'
        }
        201 {
            Invoke-LWBookFourChoiceTable -Title 'Section 201 Chamber Loot' -PromptLabel 'Section 201 choice' -ContextLabel 'Section 201' -Choices (Get-LWMagnakaiBookEightSection201ChoiceDefinitions) -Intro 'Section 201: take any useful gear before leaving the chamber.'
        }
        202 {
            [void](Add-LWBookEightSpecialItem -Name 'Lodestone' -FlagName 'Book8LodestoneClaimed' -SuccessMessage 'Section 202: Lodestone added to Special Items.')
        }
        226 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section226ColdDamageApplied' -Delta -3 -MessagePrefix 'Section 226: the cold night drains your strength.' -FatalCause 'The cold at section 226 reduced your Endurance to zero.')
            Invoke-LWMagnakaiBookEightMealRequirement -ResolvedFlagName 'Book8Section226MealHandled' -NoMealFlagName 'Book8Section226NoMealLossApplied' -SectionLabel 'Section 226' -NoMealMessagePrefix 'Section 226: hunger weakens you after the cold night.' -FatalCause 'The hunger at section 226 reduced your Endurance to zero.'
        }
        228 {
            Invoke-LWBookFourChoiceTable -Title 'Section 228 Flask' -PromptLabel 'Section 228 choice' -ContextLabel 'Section 228' -Choices (Get-LWMagnakaiBookEightSection228ChoiceDefinitions) -Intro 'Section 228: keep the Flask of Larnuma if you want the two 3-ENDURANCE draughts later.'
        }
        230 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section230DamageApplied' -Delta -8 -MessagePrefix 'Section 230: the psychic assault cuts through your Mindshield.' -FatalCause 'The psychic assault at section 230 reduced your Endurance to zero.')
        }
        242 {
            Invoke-LWMagnakaiBookEightGreyRingExchange
        }
        258 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section258DamageApplied' -Delta -8 -MessagePrefix 'Section 258: the exploding fireball burns your arms and body.' -FatalCause 'The explosion at section 258 reduced your Endurance to zero.')
            Invoke-LWMagnakaiBookEightLoseCurrentWeapon -FlagName 'Book8Section258WeaponDestroyed'
        }
        269 {
            Invoke-LWMagnakaiBookEightRiddlePenalty
        }
        274 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section274HealingApplied' -Delta 3 -MessagePrefix 'Section 274: you recover from the strain.' -FatalCause '')
        }
        294 {
            Invoke-LWMagnakaiBookEightRemoveMeal -FlagName 'Book8Section294MealGivenToPaido' -ContextLabel 'Section 294'
        }
        306 {
            Invoke-LWBookFourChoiceTable -Title 'Section 306 Mill Chest' -PromptLabel 'Section 306 choice' -ContextLabel 'Section 306' -Choices (Get-LWMagnakaiBookEightSection306ChoiceDefinitions) -Intro 'Section 306: take any items you want from the mill chest.'
        }
        312 {
            [void](Add-LWBookEightPocketItem -Name 'Giak Scroll' -FlagName 'Book8GiakScrollClaimed' -SuccessMessage 'Section 312: Giak Scroll added to Pocket Items.')
        }
        325 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section325DamageApplied' -Delta -3 -MessagePrefix 'Section 325: the sudden chill makes you shiver.' -FatalCause 'The chill at section 325 reduced your Endurance to zero.')
        }
        337 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book8Section337DamageApplied' -Delta -3 -MessagePrefix 'Section 337: crystal shrapnel strikes your leg.' -FatalCause 'The crystal shrapnel at section 337 reduced your Endurance to zero.')
        }
    }
}

function Apply-LWMagnakaiBookEightStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 8) {
        return
    }

    $script:GameState.RuleSet = 'Magnakai'
    $script:GameState.Character.LegacyKaiComplete = $true

    $requiredDisciplines = 5
    $ownedDisciplines = @($script:GameState.Character.MagnakaiDisciplines)
    if ($ownedDisciplines.Count -lt $requiredDisciplines) {
        $needed = $requiredDisciplines - $ownedDisciplines.Count
        $script:GameState.Character.MagnakaiDisciplines = @($ownedDisciplines + @(Select-LWMagnakaiDisciplines -Count $needed -Exclude $ownedDisciplines))
        Write-LWInfo ("Magnakai disciplines chosen: {0}" -f (@($script:GameState.Character.MagnakaiDisciplines) -join ', '))
    }
    if ([int]$script:GameState.Character.MagnakaiRank -lt $requiredDisciplines) {
        $script:GameState.Character.MagnakaiRank = $requiredDisciplines
    }
    if (@($script:GameState.Character.MagnakaiDisciplines) -contains 'Weaponmastery') {
        $ownedWeaponmasteryWeapons = @($script:GameState.Character.WeaponmasteryWeapons)
        $neededWeaponmasteryWeapons = $requiredDisciplines - $ownedWeaponmasteryWeapons.Count
        if ($neededWeaponmasteryWeapons -gt 0) {
            $script:GameState.Character.WeaponmasteryWeapons = @($ownedWeaponmasteryWeapons + @(Select-LWWeaponmasteryWeapons -Count $neededWeaponmasteryWeapons -Exclude $ownedWeaponmasteryWeapons))
            Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
        }
    }

    Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages

    if ($CarryExistingGear -and ((@($script:GameState.Inventory.SpecialItems).Count -gt 0) -or (@($script:GameState.Storage.SafekeepingSpecialItems).Count -gt 0))) {
        Invoke-LWBookTransitionSafekeepingPrompt -BookNumber 8
    }

    if ($CarryExistingGear) {
        Clear-LWLegacyBackpackCarryover -WriteMessages
    }

    Restore-LWBackpackState
    if ($CarryExistingGear) {
        Write-LWInfo 'Book 8 carry-over preserves your current Weapons and Special Items.'
    }

    [void](Ensure-LWBookEightSectionOnePass -SuccessMessage 'Book 8 startup: Pass added to Pocket Items.')

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold
    Write-LWInfo ("Book 8 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 8 starting gold is lost.'
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to five Book 8 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to five Book 8 starting items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 5) {
        $availableChoices = @(Get-LWMagnakaiBookEightStartingChoices | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 8 Starting Gear' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/5" -f $selectedIds.Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        if ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
            Write-LWKeyValue -Label 'Arrows' -Value (Format-LWQuiverArrowCounter -State $script:GameState) -ValueColor 'DarkYellow'
        }
        Write-Host ''
        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        $manageIndex = $availableChoices.Count + 1
        Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt ("Book 8 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }
        if ($choiceIndex -eq $manageIndex) {
            Invoke-LWBookFourStartingInventoryManagement
            continue
        }

        $choice = $availableChoices[$choiceIndex - 1]
        $granted = Grant-LWMagnakaiBookEightStartingChoice -Choice $choice
        if ($granted) {
            $selectedIds += [string]$choice.Id
        }
        elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
            Invoke-LWBookFourStartingInventoryManagement
        }
    }
}

function Get-LWBookEightSectionContextAchievementIds {
    Set-LWModuleContext -Context (Get-LWModuleContext)

    return @(
        'conundrum_conqueror',
        'lodestone_bearer_book8',
        'grey_area',
        'ohrido_lorestone',
        'silver_box_prize',
        'levitron_lifeline',
        'jungle_horror'
    )
}

Export-ModuleMember -Function `
    Get-LWMagnakaiBookEightStartingChoices, `
    Grant-LWMagnakaiBookEightStartingChoice, `
    Get-LWMagnakaiBookEightSectionRandomNumberContext, `
    Invoke-LWMagnakaiBookEightSectionRandomNumberResolution, `
    Invoke-LWMagnakaiBookEightStorySectionAchievementTriggers, `
    Invoke-LWMagnakaiBookEightStorySectionTransitionAchievementTriggers, `
    Get-LWMagnakaiBookEightInstantDeathCause, `
    Invoke-LWMagnakaiBookEightSectionEntryRules, `
    Apply-LWMagnakaiBookEightStartingEquipment, `
    Get-LWBookEightSectionContextAchievementIds
