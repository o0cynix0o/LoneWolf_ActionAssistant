Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWMagnakaiBookSixStartingChoices {
    $choices = @(
        [pscustomobject]@{ Id = 'sword'; Type = 'weapon'; Name = 'Sword'; DisplayName = 'Sword'; Description = 'Sword' },
        [pscustomobject]@{ Id = 'laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; DisplayName = 'Potion of Laumspur'; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'warhammer'; Type = 'weapon'; Name = 'Warhammer'; DisplayName = 'Warhammer'; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'quiver'; Type = 'special'; Name = 'Quiver'; DisplayName = 'Quiver'; Description = 'Quiver with 6 Arrows' },
        [pscustomobject]@{ Id = 'bow'; Type = 'weapon'; Name = 'Bow'; DisplayName = 'Bow'; Description = 'Bow' },
        [pscustomobject]@{ Id = 'rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 5; DisplayName = '5 Special Rations [DE]'; Description = '5 Special Rations' },
        [pscustomobject]@{ Id = 'quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; DisplayName = 'Quarterstaff'; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'padded'; Type = 'special'; Name = 'Padded Leather Waistcoat'; DisplayName = 'Padded Leather Waistcoat'; Description = 'Padded Leather Waistcoat' },
        [pscustomobject]@{ Id = 'axe'; Type = 'weapon'; Name = 'Axe'; DisplayName = 'Axe'; Description = 'Axe' },
        [pscustomobject]@{ Id = 'dagger'; Type = 'weapon'; Name = 'Dagger'; DisplayName = 'Dagger'; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'tinderbox'; Type = 'backpack'; Name = 'Tinderbox'; Quantity = 1; DisplayName = 'Tinderbox'; Description = 'Tinderbox' },
        [pscustomobject]@{ Id = 'rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; DisplayName = 'Rope'; Description = 'Rope' },
        [pscustomobject]@{ Id = 'kai_shield'; Type = 'special'; Name = 'Kai Shield'; DisplayName = 'Kai Shield [DE]'; Description = 'Kai Shield' },
        [pscustomobject]@{ Id = 'helmet'; Type = 'special'; Name = 'Helmet'; DisplayName = 'Helmet [DE]'; Description = 'Helmet' },
        [pscustomobject]@{ Id = 'torch'; Type = 'backpack'; Name = 'Torch'; Quantity = 1; DisplayName = 'Torch [DE]'; Description = 'Torch' },
        [pscustomobject]@{ Id = 'blanket'; Type = 'backpack'; Name = 'Blanket'; Quantity = 1; DisplayName = 'Blanket [DE]'; Description = 'Blanket' }
    )

    if ((Get-LWBookSixDECuringOption -State $script:GameState) -eq 3) {
        $choices += [pscustomobject]@{
            Id = 'herb_pouch'
            Type = 'special'
            Name = 'Herb Pouch'
            DisplayName = 'Herb Pouch [DE Option 3]'
            Description = 'Herb Pouch'
        }
    }

    return @($choices)
}

function Grant-LWMagnakaiBookSixStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    $quantity = if ((Test-LWPropertyExists -Object $Choice -Name 'Quantity') -and $null -ne $Choice.Quantity -and [int]$Choice.Quantity -gt 0) {
        [int]$Choice.Quantity
    }
    else {
        1
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity $quantity) {
        Write-LWInfo ("Book 6 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 6 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Select-LWMagnakaiBookSixDECuringOption {
    $hasCuring = Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing'
    $hasHealing = Test-LWStateHasDiscipline -State $script:GameState -Name 'Healing'
    if (-not $hasCuring -and -not $hasHealing) {
        Set-LWBookSixDECuringOption -State $script:GameState -Option 0
        return 0
    }

    $options = @()
    if ($hasCuring) {
        $options += [pscustomobject]@{
            Value       = 0
            Label       = 'Standard Curing'
            Description = @('Use the normal Curing rules only.')
        }
        $options += [pscustomobject]@{
            Value       = 1
            Label       = 'Curing Cap'
            Description = @('Cap total END restored by Curing/Healing at 15 this book.')
        }
        $options += [pscustomobject]@{
            Value       = 3
            Label       = 'Herb Pouch'
            Description = @(
                'Unlock Herb Pouch in the starter equipment list.',
                'In combat, you may drink a potion instead of attacking.',
                'Enemy END loss that round is ignored.'
            )
        }
    }
    elseif ($hasHealing) {
        $options += [pscustomobject]@{
            Value       = 0
            Label       = 'Standard Magnakai'
            Description = @('Do not use a Book 6 DE Curing option.')
        }
        $options += [pscustomobject]@{
            Value       = 2
            Label       = 'Healing Instead'
            Description = @('Use legacy Healing this book without Curing.', 'Healing restoration is capped at 10 this book.')
        }
    }

    $currentOption = Get-LWBookSixDECuringOption -State $script:GameState
    if (@($options.Value) -contains [int]$currentOption) {
        return [int]$currentOption
    }

    while ($true) {
        Write-LWPanelHeader -Title 'Book 6 DE Adventure Options' -AccentColor 'DarkYellow'
        if ($hasCuring) {
            Write-Host '  Curing is selected. Choose one DE play option:' -ForegroundColor Gray
        }
        else {
            Write-Host '  Curing is not selected. Choose whether to use the DE Healing option:' -ForegroundColor Gray
        }
        Write-Host ''

        foreach ($option in $options) {
            Write-LWBulletItem -Text ("{0}. {1}" -f [int]$option.Value, [string]$option.Label) -TextColor 'Gray' -BulletColor 'Yellow'
            foreach ($line in @($option.Description)) {
                Write-Host ("      {0}" -f [string]$line) -ForegroundColor DarkGray
            }
        }

        $rawChoice = Read-Host 'Book 6 DE option [0]'
        if ([string]::IsNullOrWhiteSpace($rawChoice)) {
            $rawChoice = '0'
        }

        $selectedOption = 0
        if (-not [int]::TryParse([string]$rawChoice, [ref]$selectedOption)) {
            Write-LWInlineWarn 'Choose one of the displayed Book 6 DE options.'
            continue
        }

        $selected = @($options | Where-Object { [int]$_.Value -eq $selectedOption } | Select-Object -First 1)
        if ($selected.Count -eq 0) {
            Write-LWInlineWarn 'Choose one of the displayed Book 6 DE options.'
            continue
        }

        Set-LWBookSixDECuringOption -State $script:GameState -Option $selectedOption
        Write-LWInfo ("Book 6 DE option selected: {0}." -f [string]$selected[0].Label)
        if ([int]$selectedOption -eq 3) {
            Write-LWInfo 'Herb Pouch is now available in the Book 6 starting equipment list.'
        }
        return [int]$selectedOption
    }
}

function Select-LWMagnakaiBookSixDEWeaponskillOption {
    $currentOption = Get-LWBookSixDEWeaponskillOption -State $script:GameState
    if ($currentOption -eq 1 -and [string]::IsNullOrWhiteSpace([string]$script:GameState.Character.WeaponskillWeapon)) {
        $weaponRoll = Get-LWRandomDigit
        $weaponName = Get-LWWeaponskillWeapon -Roll $weaponRoll
        if (-not [string]::IsNullOrWhiteSpace($weaponName)) {
            $script:GameState.Character.WeaponskillWeapon = $weaponName
            Write-LWInfo ("Weaponskill roll: {0} -> {1}" -f $weaponRoll, $weaponName)
        }
    }
    if ($currentOption -ge 0) {
        return $currentOption
    }

    $knownWeapon = [string]$script:GameState.Character.WeaponskillWeapon
    Write-LWPanelHeader -Title 'Book 6 DE Weaponskill' -AccentColor 'DarkYellow'
    if (-not [string]::IsNullOrWhiteSpace($knownWeapon)) {
        Write-Host ("  Your proven Kai weapon is: {0}" -f $knownWeapon) -ForegroundColor Gray
        Write-Host '  If enabled, you gain +2 Combat Skill in combat when using this weapon.' -ForegroundColor DarkGray
        Write-Host '  This bonus can stack with Weaponmastery.' -ForegroundColor DarkGray
        Write-Host ''
        $enable = Read-LWYesNo -Prompt ("Use the Book 6 DE Weaponskill option with {0}?" -f $knownWeapon) -Default $true
    }
    else {
        Write-Host '  You do not have a carried Weaponskill weapon recorded from Books 1-5.' -ForegroundColor Gray
        Write-Host '  If enabled, the app will roll a proven Kai weapon now using the old Weaponskill table.' -ForegroundColor DarkGray
        Write-Host '  Bow is not a valid result on that table.' -ForegroundColor DarkGray
        Write-Host '  A matching weapon grants +2 Combat Skill in combat during Book 6.' -ForegroundColor DarkGray
        Write-Host ''
        $enable = Read-LWYesNo -Prompt 'Use the Book 6 DE Weaponskill option?' -Default $false
    }

    if (-not $enable) {
        Set-LWBookSixDEWeaponskillOption -State $script:GameState -Option 0
        Write-LWInfo 'Book 6 DE Weaponskill is disabled for this adventure.'
        return 0
    }

    if ([string]::IsNullOrWhiteSpace([string]$script:GameState.Character.WeaponskillWeapon)) {
        $weaponRoll = Get-LWRandomDigit
        $weaponName = Get-LWWeaponskillWeapon -Roll $weaponRoll
        if (-not [string]::IsNullOrWhiteSpace($weaponName)) {
            $script:GameState.Character.WeaponskillWeapon = $weaponName
            Write-LWInfo ("Weaponskill roll: {0} -> {1}" -f $weaponRoll, $weaponName)
        }
    }

    Set-LWBookSixDEWeaponskillOption -State $script:GameState -Option 1
    if (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Character.WeaponskillWeapon)) {
        Write-LWInfo ("Book 6 DE Weaponskill is active with {0} for +2 Combat Skill in combat." -f [string]$script:GameState.Character.WeaponskillWeapon)
    }
    else {
        Write-LWInfo 'Book 6 DE Weaponskill is active for +2 Combat Skill in combat.'
    }

    return 1
}

function Get-LWMagnakaiBookSixSection040ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book6Section040GoldClaimed'; DisplayName = '27 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 27; Description = '27 Gold Crowns' },
        [pscustomobject]@{ Id = 'wine'; FlagName = 'Book6Section040WineClaimed'; DisplayName = 'Bottle of Wine'; Type = 'backpack'; Name = 'Bottle of Wine'; Quantity = 1; Description = 'Bottle of Wine' },
        [pscustomobject]@{ Id = 'mirror'; FlagName = 'Book6Section040MirrorClaimed'; DisplayName = 'Mirror'; Type = 'backpack'; Name = 'Mirror'; Quantity = 1; Description = 'Mirror' }
    )
}

function Get-LWMagnakaiBookSixSection048ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book6Section048GoldClaimed'; DisplayName = '5 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 5; Description = '5 Gold Crowns' },
        [pscustomobject]@{ Id = 'map'; FlagName = 'Book6Section048MapClaimed'; DisplayName = 'Map of Tekaro'; Type = 'backpack'; Name = 'Map of Tekaro'; Quantity = 1; Description = 'Map of Tekaro' }
    )
}

function Get-LWMagnakaiBookSixSection109ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'map'; FlagName = 'Book6Section109MapClaimed'; DisplayName = 'Map of Tekaro'; Type = 'backpack'; Name = 'Map of Tekaro'; Quantity = 1; Description = 'Map of Tekaro' }
    )
}

function Get-LWMagnakaiBookSixSection158ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'quarterstaff'; FlagName = 'Book6Section158QuarterstaffClaimed'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book6Section158MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book6Section158MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'whistle'; FlagName = 'Book6Section158WhistleClaimed'; DisplayName = 'Brass Whistle'; Type = 'special'; Name = 'Brass Whistle'; Quantity = 1; Description = 'Brass Whistle' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book6Section158RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book6Section158ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' }
    )
}

function Get-LWMagnakaiBookSixSection304ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'cess'; FlagName = 'Book6Section304CessClaimed'; DisplayName = 'Cess'; Type = 'special'; Name = 'Cess'; Quantity = 1; Description = 'Cess' }
    )
}

function Get-LWMagnakaiBookSixSection076SaleDefinitions {
    return @(
        [pscustomobject]@{ Type = 'weapon'; Name = 'Sword'; Price = 3 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Dagger'; Price = 1 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Broadsword'; Price = 6 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Short Sword'; Price = 2 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Mace'; Price = 3 },
        [pscustomobject]@{ Type = 'special'; Name = 'Ruby Ring'; Price = 10 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Warhammer'; Price = 5 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Spear'; Price = 4 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Axe'; Price = 2 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Bow'; Price = 5 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Quarterstaff'; Price = 2 },
        [pscustomobject]@{ Type = 'special'; Name = 'Silver Brooch'; Price = 7 }
    )
}

function Get-LWMagnakaiBookSixSection076SaleOffers {
    $definitions = @(Get-LWMagnakaiBookSixSection076SaleDefinitions)
    $offers = @()

    foreach ($weapon in @(Get-LWInventoryItems -Type 'weapon')) {
        $definition = @($definitions | Where-Object { [string]$_.Type -eq 'weapon' -and [string]$_.Name -ieq [string]$weapon } | Select-Object -First 1)
        if ($definition.Count -gt 0) {
            $offers += [pscustomobject]@{
                Id            = ('weapon-{0}-{1}' -f [string]$weapon, @($offers).Count + 1)
                InventoryType = 'weapon'
                Name          = [string]$weapon
                DisplayName   = ('{0} [Weapon]' -f [string]$weapon)
                Price         = [int]$definition[0].Price
            }
        }
    }

    foreach ($special in @(Get-LWInventoryItems -Type 'special')) {
        $definition = @($definitions | Where-Object { [string]$_.Type -eq 'special' -and [string]$_.Name -ieq [string]$special } | Select-Object -First 1)
        if ($definition.Count -gt 0) {
            $offers += [pscustomobject]@{
                Id            = ('special-{0}-{1}' -f [string]$special, @($offers).Count + 1)
                InventoryType = 'special'
                Name          = [string]$special
                DisplayName   = ('{0} [Special Item]' -f [string]$special)
                Price         = [int]$definition[0].Price
            }
        }
    }

    return @($offers)
}

function Invoke-LWMagnakaiBookSixSection076SaleTable {
    while ($true) {
        $offers = @(Get-LWMagnakaiBookSixSection076SaleOffers)
        if ($offers.Count -eq 0) {
            Write-LWInfo 'Section 76: you have nothing this mercenary will buy.'
            return
        }

        Write-LWPanelHeader -Title 'Section 76 Sale Table' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Need For Bed' -Value '2 Gold Crowns' -ValueColor 'Gray'
        for ($i = 0; $i -lt $offers.Count; $i++) {
            $offer = $offers[$i]
            Write-LWBulletItem -Text ("{0}. {1} - sell for {2} Gold" -f ($i + 1), [string]$offer.DisplayName, [int]$offer.Price) -TextColor 'Gray' -BulletColor 'DarkGray'
        }
        Write-LWBulletItem -Text '0. Done selling' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choiceIndex = Read-LWInt -Prompt 'Section 76 sale choice' -Default 0 -Min 0 -Max $offers.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }

        $offer = $offers[$choiceIndex - 1]
        if (-not (Remove-LWInventoryItemSilently -Type ([string]$offer.InventoryType) -Name ([string]$offer.Name) -Quantity 1)) {
            Write-LWWarn ("Could not remove {0}. Try again." -f [string]$offer.Name)
            continue
        }

        Update-LWGold -Delta ([int]$offer.Price)
        Write-LWInfo ("Section 76: sold {0} for {1} Gold Crowns." -f [string]$offer.Name, [int]$offer.Price)
    }

    if ([int]$script:GameState.Inventory.GoldCrowns -ge 2) {
        Write-LWInfo 'Section 76: you now have enough Gold Crowns to pay for the night.'
    }
    else {
        Write-LWWarn 'Section 76: you still do not have the 2 Gold Crowns needed to stay at the inn.'
    }
}

function Invoke-LWMagnakaiBookSixTaunorWaterPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedFlagName,
        [Parameter(Mandatory = $true)][string]$SectionLabel
    )

    if (Test-LWStoryAchievementFlag -Name $ResolvedFlagName) {
        return
    }

    $drinkNow = Read-LWInlineYesNo -Prompt ("{0}: drink the Taunor Water now for 6 ENDURANCE?" -f $SectionLabel) -Default $false
    if ($drinkNow) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + 6))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
        }
        Write-LWInfo ("{0}: Taunor Water restores {1} ENDURANCE. Current Endurance: {2}." -f $SectionLabel, $restored, [int]$script:GameState.Character.EnduranceCurrent)
        return
    }

    $existingWater = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($existingWater)) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Set-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored'
        Write-LWInfo ("{0}: you keep the filled glass jar of Taunor Water for later use." -f $SectionLabel)
        return
    }

    if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Taunor Water') {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Set-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored'
        Write-LWInfo ("{0}: Taunor Water stored in your Backpack. It restores 6 ENDURANCE when used." -f $SectionLabel)
        return
    }

    Write-LWWarn ("{0}: no room to store the Taunor Water automatically. Drink it now or make room and add it manually if you want to keep it." -f $SectionLabel)
}

function Invoke-LWMagnakaiBookSixSection004WeaponLoss {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section004LossApplied') {
        return
    }

    Set-LWStoryAchievementFlag -Name 'Book6Section004LossApplied'

    $weaponToLose = $null
    $carriedWeapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($carriedWeapons.Count -gt 0) {
        if ($carriedWeapons.Count -eq 1) {
            $weaponToLose = [string]$carriedWeapons[0]
        }
        else {
            Write-LWPanelHeader -Title 'Section 4 Weapon Loss' -AccentColor 'DarkRed'
            Write-LWSubtle '  The living strands destroy one carried Weapon. Choose which one is lost.'
            Write-Host ''
            Show-LWInventorySlotsSection -Type 'weapon'
            $slot = Read-LWInt -Prompt 'Lose which weapon' -Min 1 -Max $carriedWeapons.Count -NoRefresh
            $weaponToLose = [string]$carriedWeapons[$slot - 1]
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($weaponToLose) -and (Remove-LWInventoryItemSilently -Type 'weapon' -Name $weaponToLose -Quantity 1)) {
        Write-LWInfo ("Section 4: the living strands consume your {0}." -f $weaponToLose)
        return
    }

    $specialFallbacks = @()
    $sommerswerd = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Type 'special'
    if (-not [string]::IsNullOrWhiteSpace($sommerswerd)) {
        $specialFallbacks += [string]$sommerswerd
    }
    $daggerOfVashna = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWDaggerOfVashnaItemNames) -Type 'special'
    if (-not [string]::IsNullOrWhiteSpace($daggerOfVashna) -and ($specialFallbacks -notcontains [string]$daggerOfVashna)) {
        $specialFallbacks += [string]$daggerOfVashna
    }

    $specialFallback = $null
    if ($specialFallbacks.Count -eq 1) {
        $specialFallback = [string]$specialFallbacks[0]
    }
    elseif ($specialFallbacks.Count -gt 1) {
        Write-LWPanelHeader -Title 'Section 4 Special Item Loss' -AccentColor 'DarkRed'
        Write-LWSubtle '  With no normal Weapons left, the corrosive strands destroy one Special Item weapon.'
        Write-Host ''
        for ($i = 0; $i -lt $specialFallbacks.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$specialFallbacks[$i]) -TextColor 'Gray' -BulletColor 'DarkRed'
        }
        $specialIndex = Read-LWInt -Prompt 'Lose which Special Item weapon' -Min 1 -Max $specialFallbacks.Count -NoRefresh
        $specialFallback = [string]$specialFallbacks[$specialIndex - 1]
    }

    if (-not [string]::IsNullOrWhiteSpace($specialFallback) -and (Remove-LWInventoryItemSilently -Type 'special' -Name $specialFallback -Quantity 1)) {
        Write-LWWarn ("Section 4: with no normal Weapon left to lose, the corrosive strands consume {0}." -f $specialFallback)
        return
    }

    Write-LWInfo 'Section 4: the corrosive strands lash out, but you have no carried Weapon to lose.'
}

function Get-LWMagnakaiBookSixSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -eq $State -or [int]$State.Character.BookNumber -ne 6) {
        return $null
    }

    $section = [int]$State.CurrentSection
    $modifier = 0
    $modifierNotes = @()
    $description = $null
    $bypassed = $false
    $bypassReason = $null
    $zeroCountsAsTen = $false
    $rollCount = 1

    switch ($section) {
        72 {
            $description = 'Jump-the-wagon mounted leap check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Animal Control') {
                $modifier += 2
                $modifierNotes += 'Animal Control'
            }
        }
        95 {
            $description = 'Close-range bow-shot check.'
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
        }
        170 {
            $description = 'Long-range bow-shot from the roadside.'
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 1
                $modifierNotes += 'Huntmastery'
            }
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'))) {
                $modifier += 3
                $modifierNotes += 'Silver Bow of Duadon'
            }
        }
        178 {
            $description = 'Mounted bow-shot check.'
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'))) {
                $modifier += 3
                $modifierNotes += 'Silver Bow of Duadon'
            }
        }
        243 {
            $description = 'Point-blank bow-shot check.'
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'))) {
                $modifier += 3
                $modifierNotes += 'Silver Bow of Duadon'
            }
        }
        268 {
            $description = 'Bow-shot while fleeing the tower.'
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'))) {
                $modifier += 3
                $modifierNotes += 'Silver Bow of Duadon'
            }
        }
        340 {
            $description = 'Archery tournament total check (3 picks added together).'
            $rollCount = 3
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
        }
        default { return $null }
    }

    return [pscustomobject]@{
        Section         = $section
        Description     = $description
        Modifier        = $modifier
        ModifierNotes   = @($modifierNotes)
        RollCount       = $rollCount
        ZeroCountsAsTen = $zeroCountsAsTen
        Bypassed        = $bypassed
        BypassReason    = $bypassReason
    }
}

function Invoke-LWMagnakaiBookSixStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    $script:GameState = $State
    switch ($Section) {
        274 { Set-LWStoryAchievementFlag -Name 'Book6JumpTheWagonsRoute' }
        304 { Set-LWStoryAchievementFlag -Name 'Book6CessClaimed' }
    }
}

function Invoke-LWMagnakaiBookSixStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    $script:GameState = $State
    if ($FromSection -eq 232 -and $ToSection -eq 219 -and -not (Test-LWStoryAchievementFlag -Name 'Book6Section232MealDeducted')) {
        if (Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 1) {
            Set-LWStoryAchievementFlag -Name 'Book6Section232MealDeducted'
            Write-LWInfo 'Section 232: Meal deducted immediately before you head to your room.'
        }
        else {
            Write-LWWarn 'Section 232: the room route assumes you eat a Meal immediately, but no Meal was available to deduct.'
        }
    }
}

function Invoke-LWMagnakaiBookSixSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    $script:GameState = $State
    if (-not (Test-LWHasState)) {
        return
    }

    $section = [int]$script:GameState.CurrentSection

    switch ($section) {
        4 {
            Invoke-LWMagnakaiBookSixSection004WeaponLoss
        }
        35 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section035MealsRuined')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section035MealsRuined'
                $backpackItems = @(Get-LWInventoryItems -Type 'backpack')
                $ruinedItems = @(
                    foreach ($item in $backpackItems) {
                        if ([string]$item -ieq 'Meal' -or -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSpecialRationsItemNames) -Target ([string]$item)))) {
                            [string]$item
                        }
                    }
                )

                if ($ruinedItems.Count -gt 0) {
                    $remainingItems = @(
                        foreach ($item in $backpackItems) {
                            if ([string]$item -ieq 'Meal' -or -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSpecialRationsItemNames) -Target ([string]$item)))) {
                                continue
                            }

                            [string]$item
                        }
                    )
                    Set-LWInventoryItems -Type 'backpack' -Items $remainingItems
                    Write-LWInfo ("Section 35: rats ruin your stored food. Lost {0} item{1}." -f $ruinedItems.Count, $(if ($ruinedItems.Count -eq 1) { '' } else { 's' }))
                }
                else {
                    Write-LWInfo 'Section 35: rats tear into your Backpack, but there are no Meals or Special Rations to lose.'
                }
            }
        }
        40 {
            Invoke-LWBookFourChoiceTable -Title 'Section 40 Loot' -PromptLabel 'Section 40 choice' -ContextLabel 'Section 40' -Choices (Get-LWMagnakaiBookSixSection040ChoiceDefinitions) -Intro 'Section 40: keep any of the grave robbers'' valuables before you move on.'
        }
        48 {
            Invoke-LWBookFourChoiceTable -Title 'Section 48 Tube' -PromptLabel 'Section 48 choice' -ContextLabel 'Section 48' -Choices (Get-LWMagnakaiBookSixSection048ChoiceDefinitions) -Intro 'Section 48: keep the Gold Crowns and Map of Tekaro if you want them.'
        }
        76 {
            Invoke-LWMagnakaiBookSixSection076SaleTable
        }
        65 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section065TaunorWaterResolved' -SectionLabel 'Section 65'
        }
        106 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section106TaunorWaterResolved' -SectionLabel 'Section 106'
        }
        112 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section112TaunorWaterResolved' -SectionLabel 'Section 112'
        }
        109 {
            if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfTekaroItemNames) -Type 'backpack')) {
                Invoke-LWBookFourChoiceTable -Title 'Section 109 Map' -PromptLabel 'Section 109 choice' -ContextLabel 'Section 109' -Choices (Get-LWMagnakaiBookSixSection109ChoiceDefinitions) -Intro 'Section 109: keep the Map of Tekaro if you want it.'
            }
        }
        158 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Small Silver Key') {
                    Set-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed'
                    Set-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed'
                    Write-LWInfo 'Section 158: Small Silver Key added to Special Items.'
                }
                else {
                    Write-LWWarn 'No room to add the Small Silver Key automatically. Make room and add it manually if needed.'
                }
            }
            Invoke-LWBookFourChoiceTable -Title 'Section 158 Cellar' -PromptLabel 'Section 158 choice' -ContextLabel 'Section 158' -Choices (Get-LWMagnakaiBookSixSection158ChoiceDefinitions) -Intro 'Section 158: take whatever cellar supplies you want before midnight.'
        }
        190 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section190TaunorWaterResolved' -SectionLabel 'Section 190'
        }
        232 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section232RoomPaid')) {
                if ([int]$script:GameState.Inventory.GoldCrowns -ge 3) {
                    Update-LWGold -Delta -3
                    Write-LWInfo 'Section 232: 3 Gold Crowns paid for room 17.'
                }
                else {
                    Write-LWWarn 'Section 232: this room route assumes you can pay 3 Gold Crowns, but your current total is short.'
                }
                Set-LWStoryAchievementFlag -Name 'Book6Section232RoomPaid'
            }
            if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWIronKeyItemNames) -Type 'special')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Iron Key') {
                    Write-LWInfo 'Section 232: Iron Key added to Special Items.'
                }
                else {
                    Write-LWWarn 'No room to add the Iron Key automatically. Make room and add it manually if needed.'
                }
            }
        }
        246 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section246TaunorWaterResolved' -SectionLabel 'Section 246'
        }
        252 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section252SilverBowClaimed')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Silver Bow of Duadon') {
                    Set-LWStoryAchievementFlag -Name 'Book6Section252SilverBowClaimed'
                    Set-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed'
                    Write-LWInfo 'Section 252: Silver Bow of Duadon added to Special Items.'
                }
                else {
                    Write-LWWarn 'No room to add the Silver Bow of Duadon automatically. Make room and add it manually if needed.'
                }
            }
        }
        278 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section278DamageApplied' -Delta -3 -MessagePrefix 'Section 278: the creature''s surprise attack tears a gaping wound in your arm.' -FatalCause 'The surprise attack at section 278 reduced your Endurance to zero.')
        }
        282 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section282DamageApplied' -Delta -1 -MessagePrefix 'Section 282: the thrown dagger grazes your side before the fight begins.' -FatalCause 'The ambush at section 282 reduced your Endurance to zero.')
        }
        293 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section293SilverKeyUsed')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section293SilverKeyUsed'
                if (Remove-LWInventoryItemSilently -Type 'special' -Name 'Small Silver Key' -Quantity 1) {
                    Write-LWInfo 'Section 293: Small Silver Key is used to open the tomb and is erased.'
                }
                else {
                    Write-LWInfo 'Section 293: Small Silver Key should now be erased from your Action Chart.'
                }
            }
        }
        301 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section301ArrowSpent')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section301ArrowSpent'
                if (Test-LWStateHasQuiver -State $script:GameState) {
                    if ((Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
                        Update-LWQuiverArrows -Delta -1
                        Write-LWInfo 'Section 301: 1 Arrow spent to wound Roark.'
                    }
                    else {
                        Write-LWWarn 'Section 301: this route assumes you fire 1 Arrow, but your Quiver is empty.'
                    }
                }
                else {
                    Write-LWWarn 'Section 301: this route assumes you fire 1 Arrow, but no Quiver is currently recorded.'
                }
            }
        }
        304 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section304CessClaimed')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Cess') {
                    Set-LWStoryAchievementFlag -Name 'Book6Section304CessClaimed'
                    Set-LWStoryAchievementFlag -Name 'Book6CessClaimed'
                    Write-LWInfo 'Section 304: Cess added to Special Items.'
                }
                else {
                    Write-LWWarn 'No room to add the Cess automatically. Make room and add it manually if needed.'
                }
            }
        }
        307 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section307Handled')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section307Handled'
                $eatNow = Read-LWInlineYesNo -Prompt 'Eat a Meal now to avoid the 3 ENDURANCE loss?' -Default $true
                if ($eatNow) {
                    Use-LWMeal
                }
                else {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section307NoMealLossApplied' -Delta -3 -MessagePrefix 'Section 307: hunger hits hard while the bread wagon empties around you.' -FatalCause 'Hunger at section 307 reduced your Endurance to zero.')
                }

                if (Test-LWStateHasBackpack -State $script:GameState) {
                    $freeSlots = 8 - (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))
                    $maxLoaves = [Math]::Min([Math]::Floor(([int]$script:GameState.Inventory.GoldCrowns / 2)), [Math]::Max(0, [int]$freeSlots))
                    if ($maxLoaves -gt 0 -and (Read-LWInlineYesNo -Prompt 'Buy bread to carry for later?' -Default $false)) {
                        $loafCount = Read-LWInt -Prompt ("How many loaves? (0-{0})" -f $maxLoaves) -Default 0 -Min 0 -Max $maxLoaves -NoRefresh
                        if ($loafCount -gt 0) {
                            Update-LWGold -Delta (-2 * [int]$loafCount)
                            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity ([int]$loafCount))
                            Write-LWInfo ("Section 307: bought {0} loaf{1} of bread." -f [int]$loafCount, $(if ($loafCount -eq 1) { '' } else { 's' }))
                        }
                    }
                }
            }
        }
        306 {
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section306ColdDamageApplied' -Delta -1 -MessagePrefix 'Section 306: the freezing river water leaves you numb and shaking.' -FatalCause 'The freezing river water at section 306 reduced your Endurance to zero.')
            }
            elseif (-not (Test-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected'
                Write-LWInfo 'Section 306: Nexus protects you from the freezing cold.'
            }
        }
        310 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section310DamageApplied' -Delta -2 -MessagePrefix 'Section 310: a severed Dakomyd hand claws into your leg.' -FatalCause 'The Dakomyd''s severed hand at section 310 reduced your Endurance to zero.')
        }
        315 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section315MindforceApplied')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section315MindforceApplied'
                if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-screen') {
                    Set-LWStoryAchievementFlag -Name 'Book6Section315MindforceBlocked'
                    Write-LWInfo 'Section 315: Psi-screen blocks the Mindforce assault.'
                }
                else {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section315MindforceLossApplied' -Delta -4 -MessagePrefix 'Section 315: the procession''s Mindforce attack tears through your thoughts.' -FatalCause 'The Mindforce attack at section 315 reduced your Endurance to zero.')
                }
            }
        }
        322 {
            if ([int]$script:GameState.Inventory.GoldCrowns -ge 10) {
                if (Read-LWInlineYesNo -Prompt 'Pay the sergeant 10 Gold Crowns now?' -Default $false) {
                    Update-LWGold -Delta -10
                    Set-LWStoryAchievementFlag -Name 'Book6Section322TollPaid'
                    Write-LWInfo 'Section 322: you pay the sergeant his crooked toll.'
                }
            }
            else {
                Write-LWWarn 'Section 322: you do not currently have the 10 Gold Crowns needed to pay the sergeant.'
            }
        }
        348 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost'
                if (Remove-LWInventoryItemSilently -Type 'weapon' -Name 'Warhammer' -Quantity 1) {
                    Write-LWInfo 'Section 348: the Warhammer slips into the black puddle and is lost.'
                }
                else {
                    Write-LWInfo 'Section 348: the Warhammer is lost to the black puddle.'
                }
            }
        }
    }
}

function Apply-LWMagnakaiBookSixStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 6) {
        return
    }

    $script:GameState.RuleSet = 'Magnakai'
    $script:GameState.Character.LegacyKaiComplete = $true
    if (-not $script:GameState.Character.MagnakaiRank -or [int]$script:GameState.Character.MagnakaiRank -lt 3) {
        $script:GameState.Character.MagnakaiRank = [Math]::Max(3, @($script:GameState.Character.MagnakaiDisciplines).Count)
    }

    $ownedDisciplines = @($script:GameState.Character.MagnakaiDisciplines)
    if ($ownedDisciplines.Count -lt 3) {
        $needed = 3 - $ownedDisciplines.Count
        $script:GameState.Character.MagnakaiDisciplines = @($ownedDisciplines + @(Select-LWMagnakaiDisciplines -Count $needed -Exclude $ownedDisciplines))
        Write-LWInfo ("Magnakai disciplines chosen: {0}" -f (@($script:GameState.Character.MagnakaiDisciplines) -join ', '))
    }
    if (@($script:GameState.Character.MagnakaiDisciplines).Count -ge 3 -and [int]$script:GameState.Character.MagnakaiRank -lt 3) {
        $script:GameState.Character.MagnakaiRank = 3
    }
    if (@($script:GameState.Character.MagnakaiDisciplines) -contains 'Weaponmastery' -and @($script:GameState.Character.WeaponmasteryWeapons).Count -lt 3) {
        $script:GameState.Character.WeaponmasteryWeapons = @(Select-LWWeaponmasteryWeapons -Count 3 -Exclude @($script:GameState.Character.WeaponmasteryWeapons))
        Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
    }

    [void](Select-LWMagnakaiBookSixDECuringOption)
    [void](Select-LWMagnakaiBookSixDEWeaponskillOption)

    Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages

    if ($CarryExistingGear -and ((@($script:GameState.Inventory.SpecialItems).Count -gt 0) -or (@($script:GameState.Storage.SafekeepingSpecialItems).Count -gt 0))) {
        Invoke-LWBookTransitionSafekeepingPrompt -BookNumber 6
    }

    Restore-LWBackpackState
    if ($CarryExistingGear) {
        Write-LWInfo 'Book 6 DE carry-over preserves your current Weapons, Backpack Items, and Special Items.'
    }

    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfStornlandsItemNames) -Type 'special')) {
        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of the Stornlands') {
            Write-LWInfo 'Book 6 starting Special Item added: Map of the Stornlands.'
        }
        else {
            Write-LWWarn 'No room to add the Book 6 map automatically. Make room and add it manually if needed.'
        }
    }

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold
    Write-LWInfo ("Book 6 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 6 starting gold is lost.'
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to seven Book 6 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to seven Book 6 starting items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 7) {
        $availableChoices = @(Get-LWMagnakaiBookSixStartingChoices | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 6 Starting Gear' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/7" -f $selectedIds.Count) -ValueColor 'Gray'
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

        $choiceIndex = Read-LWInt -Prompt ("Book 6 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }
        if ($choiceIndex -eq $manageIndex) {
            Invoke-LWBookFourStartingInventoryManagement
            continue
        }

        $choice = $availableChoices[$choiceIndex - 1]
        $granted = Grant-LWMagnakaiBookSixStartingChoice -Choice $choice
        if ($granted) {
            $selectedIds += [string]$choice.Id
        }
        elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
            Invoke-LWBookFourStartingInventoryManagement
        }
    }
}

Export-ModuleMember -Function `
    Get-LWMagnakaiBookSixStartingChoices, `
    Grant-LWMagnakaiBookSixStartingChoice, `
    Get-LWMagnakaiBookSixSectionRandomNumberContext, `
    Invoke-LWMagnakaiBookSixStorySectionAchievementTriggers, `
    Invoke-LWMagnakaiBookSixStorySectionTransitionAchievementTriggers, `
    Invoke-LWMagnakaiBookSixSectionEntryRules, `
    Apply-LWMagnakaiBookSixStartingEquipment
