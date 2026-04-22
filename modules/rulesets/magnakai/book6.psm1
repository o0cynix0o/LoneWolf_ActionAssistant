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

        $rawChoice = Read-LWPromptLine -Prompt 'Book 6 DE option [0]' -ReturnNullOnEof
        if ($null -eq $rawChoice -or [string]::IsNullOrWhiteSpace($rawChoice)) {
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

function Get-LWMagnakaiBookSixSection002ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book6Section002LaumspurBought'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'gallowbrush'; FlagName = 'Book6Section002GallowbrushBought'; DisplayName = 'Potion of Gallowbrush'; Type = 'backpack'; Name = 'Potion of Gallowbrush'; Quantity = 1; Description = 'Potion of Gallowbrush'; GoldCost = 2 },
        [pscustomobject]@{ Id = 'rendalims'; FlagName = 'Book6Section002RendalimsBought'; DisplayName = "Rendalim's Elixir"; Type = 'backpack'; Name = "Rendalim's Elixir"; Quantity = 1; Description = "Rendalim's Elixir"; GoldCost = 7 },
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book6Section002AletherBought'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Potion of Alether'; Quantity = 1; Description = 'Potion of Alether'; GoldCost = 4 },
        [pscustomobject]@{ Id = 'graveweed'; FlagName = 'Book6Section002GraveweedBought'; DisplayName = 'Graveweed Concentrate'; Type = 'backpack'; Name = 'Graveweed Concentrate'; Quantity = 1; Description = 'Graveweed Concentrate'; GoldCost = 4 }
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

function Get-LWMagnakaiBookSixSection123ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'berries_1'; FlagName = 'Book6Section123AletherOneBought'; DisplayName = 'Alether Berries'; Type = 'backpack'; Name = 'Alether Berries'; Quantity = 1; Description = 'Alether Berries'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'berries_2'; FlagName = 'Book6Section123AletherTwoBought'; DisplayName = 'Alether Berries'; Type = 'backpack'; Name = 'Alether Berries'; Quantity = 1; Description = 'Alether Berries'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'berries_3'; FlagName = 'Book6Section123AletherThreeBought'; DisplayName = 'Alether Berries'; Type = 'backpack'; Name = 'Alether Berries'; Quantity = 1; Description = 'Alether Berries'; GoldCost = 3 }
    )
}

function Get-LWMagnakaiBookSixSection275BuyDefinitions {
    return @(
        [pscustomobject]@{ Name = 'Map of Sommerlund'; DisplayName = 'Map of Sommerlund'; Price = 5 },
        [pscustomobject]@{ Name = 'Map of Tekaro'; DisplayName = 'Map of Tekaro'; Price = 4 },
        [pscustomobject]@{ Name = 'Map of Luyen'; DisplayName = 'Map of Luyen'; Price = 3 }
    )
}

function Get-LWMagnakaiBookSixSection275SaleDefinitions {
    return @(
        [pscustomobject]@{ Name = 'Map of Sommerlund'; DisplayName = 'Map of Sommerlund'; Price = 4 },
        [pscustomobject]@{ Name = 'Map of Tekaro'; DisplayName = 'Map of Tekaro'; Price = 3 },
        [pscustomobject]@{ Name = 'Map of Luyen'; DisplayName = 'Map of Luyen'; Price = 2 }
    )
}

function Get-LWMagnakaiBookSixSection008ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book6Section008GoldClaimed'; DisplayName = '10 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 10; Description = '10 Gold Crowns' },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book6Section008LaumspurClaimed'; DisplayName = 'Potion of Laumspur (+3 END)'; Type = 'backpack'; Name = 'Potion of Laumspur (3 END)'; Quantity = 1; Description = 'Potion of Laumspur (+3 END)' },
        [pscustomobject]@{ Id = 'map'; FlagName = 'Book6Section008MapClaimed'; DisplayName = 'Map of Varetta'; Type = 'special'; Name = 'Map of Varetta'; Quantity = 1; Description = 'Map of Varetta' }
    )
}

function Get-LWMagnakaiBookSixSection139ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book6Section139GoldClaimed'; DisplayName = '11 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 11; Description = '11 Gold Crowns' },
        [pscustomobject]@{ Id = 'brooch'; FlagName = 'Book6Section139BroochClaimed'; DisplayName = 'Silver Brooch'; Type = 'special'; Name = 'Silver Brooch'; Quantity = 1; Description = 'Silver Brooch' }
    )
}

function Get-LWMagnakaiBookSixSection145ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book6Section145GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' },
        [pscustomobject]@{ Id = 'ring'; FlagName = 'Book6Section145RingClaimed'; DisplayName = 'Ruby Ring'; Type = 'special'; Name = 'Ruby Ring'; Quantity = 1; Description = 'Ruby Ring' }
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

function Get-LWMagnakaiBookSixSection010TicketDefinitions {
    return @(
        [pscustomobject]@{ Id = 'luyen'; Name = 'Riverboat Ticket to Luyen'; DisplayName = 'Riverboat Ticket to Luyen'; GoldCost = 10 },
        [pscustomobject]@{ Id = 'rhem'; Name = 'Riverboat Ticket to Rhem'; DisplayName = 'Riverboat Ticket to Rhem'; GoldCost = 15 },
        [pscustomobject]@{ Id = 'eula'; Name = 'Riverboat Ticket to Eula'; DisplayName = 'Riverboat Ticket to Eula'; GoldCost = 20 }
    )
}

function Invoke-LWMagnakaiBookSixSection010TicketPrompt {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section010TicketClaimed') {
        return
    }

    if (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBook6RiverboatTicketItemNames)) {
        Set-LWStoryAchievementFlag -Name 'Book6Section010TicketClaimed'
        return
    }

    $choices = @(Get-LWMagnakaiBookSixSection010TicketDefinitions)
    while ($true) {
        Write-LWPanelHeader -Title 'Section 10 Ticket' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Pocket Item' -Value 'Does not use a Special Item slot' -ValueColor 'DarkYellow'
        Write-Host ''

        for ($i = 0; $i -lt $choices.Count; $i++) {
            $choice = $choices[$i]
            Write-LWBulletItem -Text ("{0}. {1} ({2} Gold Crowns)" -f ($i + 1), [string]$choice.DisplayName, [int]$choice.GoldCost) -TextColor 'Gray' -BulletColor 'Yellow'
        }

        $choiceIndex = Read-LWInt -Prompt 'Section 10 ticket choice' -Default 1 -Min 1 -Max $choices.Count -NoRefresh
        $selectedChoice = $choices[$choiceIndex - 1]
        $ticketCost = [int]$selectedChoice.GoldCost

        if ([int]$script:GameState.Inventory.GoldCrowns -lt $ticketCost) {
            Write-LWInlineWarn ("You need {0} Gold Crowns for that ticket, but only have {1}." -f $ticketCost, [int]$script:GameState.Inventory.GoldCrowns)
            continue
        }

        Update-LWGold -Delta (-$ticketCost)
        if (TryAdd-LWPocketSpecialItemSilently -Name ([string]$selectedChoice.Name)) {
            Set-LWStoryAchievementFlag -Name 'Book6Section010TicketClaimed'
            Write-LWInfo ("Section 10: {0} added to Pocket Items for {1} Gold Crowns." -f [string]$selectedChoice.DisplayName, $ticketCost)
        }
        else {
            Write-LWInfo ("Section 10: {0} should now be marked as a pocket-carried Special Item. It does not use a normal Special Item slot." -f [string]$selectedChoice.DisplayName)
        }

        return
    }
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

function Get-LWMagnakaiBookSixSection098BuyDefinitions {
    return @(
        [pscustomobject]@{ Type = 'weapon'; Name = 'Broadsword'; DisplayName = 'Broadsword'; Price = 7 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Dagger'; DisplayName = 'Dagger'; Price = 2 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Short Sword'; DisplayName = 'Short Sword'; Price = 3 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Warhammer'; DisplayName = 'Warhammer'; Price = 6 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Spear'; DisplayName = 'Spear'; Price = 5 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Mace'; DisplayName = 'Mace'; Price = 4 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Axe'; DisplayName = 'Axe'; Price = 3 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Bow'; DisplayName = 'Bow'; Price = 7 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Quarterstaff'; DisplayName = 'Quarterstaff'; Price = 3 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Sword'; DisplayName = 'Sword'; Price = 4 },
        [pscustomobject]@{ Type = 'backpack'; Name = 'Arrow'; DisplayName = '2 Arrows'; Quantity = 2; Price = 1 },
        [pscustomobject]@{ Type = 'special'; Name = 'Quiver'; DisplayName = 'Quiver [DE]'; Price = 3; StartsEmpty = $true },
        [pscustomobject]@{ Type = 'special'; Name = 'Large Quiver'; DisplayName = 'Large Quiver [DE]'; Price = 5; StartsEmpty = $true }
    )
}

function Get-LWMagnakaiBookSixSection098SaleDefinitions {
    return @(
        [pscustomobject]@{ Type = 'weapon'; Name = 'Broadsword'; Price = 6 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Dagger'; Price = 1 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Short Sword'; Price = 2 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Warhammer'; Price = 5 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Spear'; Price = 4 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Mace'; Price = 3 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Axe'; Price = 2 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Bow'; Price = 6 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Quarterstaff'; Price = 2 },
        [pscustomobject]@{ Type = 'weapon'; Name = 'Sword'; Price = 3 },
        [pscustomobject]@{ Type = 'special'; Name = 'Quiver'; Price = 2 },
        [pscustomobject]@{ Type = 'special'; Name = 'Large Quiver'; Price = 4 }
    )
}

function Get-LWMagnakaiBookSixSection098SellableArrowCount {
    $looseArrows = 0
    foreach ($item in @(Get-LWInventoryItems -Type 'backpack')) {
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWArrowItemNames) -Target ([string]$item)))) {
            $looseArrows++
        }
    }

    return ($looseArrows + (Get-LWQuiverArrowCount -State $script:GameState))
}

function Remove-LWMagnakaiBookSixSection098Arrows {
    param([int]$Quantity = 3)

    if ($Quantity -lt 1) {
        return 0
    }

    $removed = 0
    while ($removed -lt $Quantity) {
        if ((Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWArrowItemNames) -Quantity 1 -Types @('backpack')) -gt 0) {
            $removed++
            continue
        }

        $currentQuiverArrows = Get-LWQuiverArrowCount -State $script:GameState
        if ($currentQuiverArrows -gt 0) {
            $script:GameState.Inventory.QuiverArrows = ($currentQuiverArrows - 1)
            $removed++
            continue
        }

        break
    }

    if (Test-LWStateHasQuiver -State $script:GameState) {
        [void](Sync-LWQuiverArrowState -State $script:GameState)
    }

    return $removed
}

function Complete-LWMagnakaiBookSixSection098QuiverPurchase {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Price
    )

    $hadQuiver = Test-LWStateHasQuiver -State $script:GameState
    $currentArrows = Sync-LWQuiverArrowState -State $script:GameState
    if (-not (TryAdd-LWInventoryItemSilently -Type 'special' -Name $Name -Quantity 1)) {
        return $false
    }

    if ($hadQuiver) {
        $script:GameState.Inventory.QuiverArrows = [Math]::Min($currentArrows, (Get-LWQuiverArrowCapacity -State $script:GameState))
    }
    else {
        $script:GameState.Inventory.QuiverArrows = 0
    }

    Update-LWGold -Delta (-$Price)
    if ($hadQuiver) {
        Write-LWInfo ("Section 98: purchased {0} for {1} Gold Crowns. Arrow capacity is now {2}." -f $Name, $Price, (Format-LWQuiverArrowCounter -State $script:GameState))
    }
    else {
        Write-LWInfo ("Section 98: purchased {0} for {1} Gold Crowns. It is recorded as empty ({2})." -f $Name, $Price, (Format-LWQuiverArrowCounter -State $script:GameState))
    }

    return $true
}

function Complete-LWMagnakaiBookSixSection098ArrowPurchase {
    param(
        [Parameter(Mandatory = $true)][int]$Price,
        [int]$Quantity = 2
    )

    if ($Quantity -lt 1) {
        return $false
    }

    $storedQuantity = 0
    $leftBehindQuantity = 0

    if (Test-LWStateHasQuiver -State $script:GameState) {
        $currentArrows = Sync-LWQuiverArrowState -State $script:GameState
        $capacity = Get-LWQuiverArrowCapacity -State $script:GameState
        $freeArrows = [Math]::Max(0, ($capacity - $currentArrows))
        if ($freeArrows -le 0) {
            Write-LWInlineWarn 'Your quiver has no room for more arrows.'
            return $false
        }

        $storedQuantity = [Math]::Min($Quantity, $freeArrows)
        $leftBehindQuantity = [Math]::Max(0, ($Quantity - $storedQuantity))
        $script:GameState.Inventory.QuiverArrows = ($currentArrows + $storedQuantity)
    }
    else {
        $capacity = Get-LWInventoryTypeCapacity -Type 'backpack'
        $usedCapacity = Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')
        $freeSlots = [Math]::Max(0, ([int]$capacity - [int]$usedCapacity))
        if ($freeSlots -le 0) {
            Write-LWInlineWarn 'You do not have enough Backpack space for more arrows.'
            return $false
        }

        $storedQuantity = [Math]::Min($Quantity, $freeSlots)
        $leftBehindQuantity = [Math]::Max(0, ($Quantity - $storedQuantity))
        if (-not (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Arrow' -Quantity $storedQuantity)) {
            return $false
        }
    }

    Update-LWGold -Delta (-$Price)
    if ($leftBehindQuantity -gt 0) {
        Write-LWInfo ("Section 98: purchased {0} Arrows for {1} Gold Crown{2}; only {3} could be carried, so {4} {5} left behind." -f $Quantity, $Price, $(if ($Price -eq 1) { '' } else { 's' }), $storedQuantity, $leftBehindQuantity, $(if ($leftBehindQuantity -eq 1) { 'was' } else { 'were' }))
    }
    else {
        Write-LWInfo ("Section 98: purchased {0} Arrows for {1} Gold Crown{2}." -f $Quantity, $Price, $(if ($Price -eq 1) { '' } else { 's' }))
    }

    return $true
}

function Invoke-LWMagnakaiBookSixSection098BuyTable {
    $choices = @(Get-LWMagnakaiBookSixSection098BuyDefinitions)
    while ($true) {
        Write-LWPanelHeader -Title 'Section 98 Buy Table' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        if ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
            Write-LWKeyValue -Label 'Arrows' -Value (Format-LWQuiverArrowCounter -State $script:GameState) -ValueColor 'DarkYellow'
        }

        for ($i = 0; $i -lt $choices.Count; $i++) {
            $choice = $choices[$i]
            Write-LWBulletItem -Text ("{0}. {1} - {2} Gold Crown{3}" -f ($i + 1), [string]$choice.DisplayName, [int]$choice.Price, $(if ([int]$choice.Price -eq 1) { '' } else { 's' })) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text '0. Done buying' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choiceIndex = Read-LWInt -Prompt 'Section 98 buy choice' -Default 0 -Min 0 -Max $choices.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            return
        }

        $choice = $choices[$choiceIndex - 1]
        $price = [int]$choice.Price
        if ([int]$script:GameState.Inventory.GoldCrowns -lt $price) {
            Write-LWInlineWarn ("You need {0} Gold Crowns for that purchase, but only have {1}." -f $price, [int]$script:GameState.Inventory.GoldCrowns)
            continue
        }

        switch ([string]$choice.Type) {
            'weapon' {
                if (Add-LWWeaponWithOptionalReplace -Name ([string]$choice.Name) -PromptLabel ([string]$choice.DisplayName)) {
                    Update-LWGold -Delta (-$price)
                    Write-LWInfo ("Section 98: purchased {0} for {1} Gold Crowns." -f [string]$choice.DisplayName, $price)
                }
            }
            'backpack' {
                $quantity = if ((Test-LWPropertyExists -Object $choice -Name 'Quantity') -and $null -ne $choice.Quantity) { [int]$choice.Quantity } else { 1 }
                if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWArrowItemNames) -Target ([string]$choice.Name)))) {
                    [void](Complete-LWMagnakaiBookSixSection098ArrowPurchase -Price $price -Quantity $quantity)
                }
                elseif (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name ([string]$choice.Name) -Quantity $quantity) {
                    Update-LWGold -Delta (-$price)
                    Write-LWInfo ("Section 98: purchased {0} for {1} Gold Crown{2}." -f [string]$choice.DisplayName, $price, $(if ($price -eq 1) { '' } else { 's' }))
                }
            }
            'special' {
                [void](Complete-LWMagnakaiBookSixSection098QuiverPurchase -Name ([string]$choice.Name) -Price $price)
            }
        }
    }
}

function Get-LWMagnakaiBookSixSection098SaleOffers {
    $definitions = @(Get-LWMagnakaiBookSixSection098SaleDefinitions)
    $offers = @()

    foreach ($weapon in @(Get-LWInventoryItems -Type 'weapon')) {
        $definition = @($definitions | Where-Object { [string]$_.Type -eq 'weapon' -and [string]$_.Name -ieq [string]$weapon } | Select-Object -First 1)
        if ($definition.Count -gt 0) {
            $offers += [pscustomobject]@{
                Kind          = 'weapon'
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
                Kind          = 'special'
                InventoryType = 'special'
                Name          = [string]$special
                DisplayName   = ('{0} [Special Item]' -f [string]$special)
                Price         = [int]$definition[0].Price
            }
        }
    }

    if ((Get-LWMagnakaiBookSixSection098SellableArrowCount) -ge 3) {
        $offers += [pscustomobject]@{
            Kind        = 'arrows'
            DisplayName = '3 Arrows [DE]'
            Price       = 1
            Quantity    = 3
        }
    }

    return @($offers)
}

function Invoke-LWMagnakaiBookSixSection098SaleTable {
    while ($true) {
        $offers = @(Get-LWMagnakaiBookSixSection098SaleOffers)
        if ($offers.Count -eq 0) {
            Write-LWInfo 'Section 98: you have nothing this weaponsmith will buy.'
            return
        }

        Write-LWPanelHeader -Title 'Section 98 Sale Table' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Sale Rule' -Value 'Weapons and quivers sell for 1 less; 3 Arrows sell for 1 Gold [DE]' -ValueColor 'Gray'
        for ($i = 0; $i -lt $offers.Count; $i++) {
            $offer = $offers[$i]
            Write-LWBulletItem -Text ("{0}. {1} - sell for {2} Gold" -f ($i + 1), [string]$offer.DisplayName, [int]$offer.Price) -TextColor 'Gray' -BulletColor 'DarkGray'
        }
        Write-LWBulletItem -Text '0. Done selling' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choiceIndex = Read-LWInt -Prompt 'Section 98 sale choice' -Default 0 -Min 0 -Max $offers.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            return
        }

        $offer = $offers[$choiceIndex - 1]
        switch ([string]$offer.Kind) {
            'weapon' {
                if (-not (Remove-LWInventoryItemSilently -Type ([string]$offer.InventoryType) -Name ([string]$offer.Name) -Quantity 1)) {
                    Write-LWWarn ("Could not remove {0}. Try again." -f [string]$offer.Name)
                    continue
                }

                Update-LWGold -Delta ([int]$offer.Price)
                Write-LWInfo ("Section 98: sold {0} for {1} Gold Crowns." -f [string]$offer.Name, [int]$offer.Price)
            }
            'special' {
                if (-not (Remove-LWInventoryItemSilently -Type ([string]$offer.InventoryType) -Name ([string]$offer.Name) -Quantity 1)) {
                    Write-LWWarn ("Could not remove {0}. Try again." -f [string]$offer.Name)
                    continue
                }

                Update-LWGold -Delta ([int]$offer.Price)
                Write-LWInfo ("Section 98: sold {0} for {1} Gold Crowns." -f [string]$offer.Name, [int]$offer.Price)
            }
            'arrows' {
                $removed = Remove-LWMagnakaiBookSixSection098Arrows -Quantity ([int]$offer.Quantity)
                if ($removed -lt [int]$offer.Quantity) {
                    Write-LWWarn 'Could not remove enough Arrows to complete the sale.'
                    continue
                }

                Update-LWGold -Delta ([int]$offer.Price)
                Write-LWInfo ("Section 98: sold {0} Arrows for {1} Gold Crown." -f [int]$offer.Quantity, [int]$offer.Price)
            }
        }
    }
}

function Invoke-LWMagnakaiBookSixSection098Shop {
    while ($true) {
        Write-LWPanelHeader -Title 'Section 98 Weapons Shop' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        if ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
            Write-LWKeyValue -Label 'Arrows' -Value (Format-LWQuiverArrowCounter -State $script:GameState) -ValueColor 'DarkYellow'
        }

        Write-LWBulletItem -Text '1. Buy weapons, arrows, or quivers' -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '2. Sell weapons, quivers, or arrows' -TextColor 'Gray' -BulletColor 'DarkYellow'
        Write-LWBulletItem -Text '0. Leave the shop' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choice = Read-LWInt -Prompt 'Section 98 shop choice' -Default 0 -Min 0 -Max 2 -NoRefresh
        switch ($choice) {
            0 { return }
            1 { Invoke-LWMagnakaiBookSixSection098BuyTable }
            2 { Invoke-LWMagnakaiBookSixSection098SaleTable }
        }
    }
}

function Get-LWMagnakaiBookSixSection275SaleOffers {
    $definitions = @(Get-LWMagnakaiBookSixSection275SaleDefinitions)
    $offers = @()

    foreach ($map in @(Get-LWInventoryItems -Type 'backpack')) {
        $definition = @($definitions | Where-Object { [string]$_.Name -ieq [string]$map } | Select-Object -First 1)
        if ($definition.Count -gt 0) {
            $offers += [pscustomobject]@{
                Name        = [string]$map
                DisplayName = ('{0} [Backpack Item]' -f [string]$map)
                Price       = [int]$definition[0].Price
            }
        }
    }

    return @($offers)
}

function Invoke-LWMagnakaiBookSixSection275BuyTable {
    $choices = @(Get-LWMagnakaiBookSixSection275BuyDefinitions)
    while ($true) {
        Write-LWPanelHeader -Title 'Section 275 Buy Table' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Backpack' -Value ("{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))) -ValueColor 'Gray'

        for ($i = 0; $i -lt $choices.Count; $i++) {
            $choice = $choices[$i]
            Write-LWBulletItem -Text ("{0}. {1} - {2} Gold Crown{3}" -f ($i + 1), [string]$choice.DisplayName, [int]$choice.Price, $(if ([int]$choice.Price -eq 1) { '' } else { 's' })) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text '0. Done buying' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choiceIndex = Read-LWInt -Prompt 'Section 275 buy choice' -Default 0 -Min 0 -Max $choices.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            return
        }

        $choice = $choices[$choiceIndex - 1]
        $price = [int]$choice.Price
        if ([int]$script:GameState.Inventory.GoldCrowns -lt $price) {
            Write-LWInlineWarn ("You need {0} Gold Crowns for that purchase, but only have {1}." -f $price, [int]$script:GameState.Inventory.GoldCrowns)
            continue
        }

        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name ([string]$choice.Name) -Quantity 1) {
            Update-LWGold -Delta (-$price)
            Write-LWInfo ("Section 275: purchased {0} for {1} Gold Crown{2}." -f [string]$choice.DisplayName, $price, $(if ($price -eq 1) { '' } else { 's' }))
        }
    }
}

function Invoke-LWMagnakaiBookSixSection275SaleTable {
    while ($true) {
        $offers = @(Get-LWMagnakaiBookSixSection275SaleOffers)
        if ($offers.Count -eq 0) {
            Write-LWInfo 'Section 275: you have no maps this cartographer will buy.'
            return
        }

        Write-LWPanelHeader -Title 'Section 275 Sale Table' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Sale Rule' -Value 'Maps sell for 1 less than list price [DE]' -ValueColor 'Gray'

        for ($i = 0; $i -lt $offers.Count; $i++) {
            $offer = $offers[$i]
            Write-LWBulletItem -Text ("{0}. {1} - sell for {2} Gold" -f ($i + 1), [string]$offer.DisplayName, [int]$offer.Price) -TextColor 'Gray' -BulletColor 'DarkGray'
        }
        Write-LWBulletItem -Text '0. Done selling' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choiceIndex = Read-LWInt -Prompt 'Section 275 sale choice' -Default 0 -Min 0 -Max $offers.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            return
        }

        $offer = $offers[$choiceIndex - 1]
        $removed = Remove-LWInventoryItemSilently -Type 'backpack' -Name ([string]$offer.Name) -Quantity 1
        if ($removed -lt 1) {
            Write-LWWarn ("Could not remove {0}. Try again." -f [string]$offer.Name)
            continue
        }

        Update-LWGold -Delta ([int]$offer.Price)
        Write-LWInfo ("Section 275: sold {0} for {1} Gold Crowns." -f [string]$offer.Name, [int]$offer.Price)
    }
}

function Invoke-LWMagnakaiBookSixSection275Shop {
    while ($true) {
        Write-LWPanelHeader -Title 'Section 275 Cartographer' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Backpack' -Value ("{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))) -ValueColor 'Gray'

        Write-LWBulletItem -Text '1. Buy maps' -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '2. Sell carried maps' -TextColor 'Gray' -BulletColor 'DarkYellow'
        Write-LWBulletItem -Text '0. Leave the cartographer' -TextColor 'Gray' -BulletColor 'DarkGray'

        $choice = Read-LWInt -Prompt 'Section 275 shop choice' -Default 0 -Min 0 -Max 2 -NoRefresh
        switch ($choice) {
            0 {
                Write-LWInfo 'Section 275: return to the apothecary and continue to section 231.'
                return
            }
            1 { Invoke-LWMagnakaiBookSixSection275BuyTable }
            2 { Invoke-LWMagnakaiBookSixSection275SaleTable }
        }
    }
}

function Invoke-LWMagnakaiBookSixTaunorWaterPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedFlagName,
        [Parameter(Mandatory = $true)][string]$SectionLabel,
        [switch]$AllowDrinkAndKeep,
        [switch]$AllowHerbPouchStorage
    )

    if (Test-LWStoryAchievementFlag -Name $ResolvedFlagName) {
        return
    }

    $storageTypes = if ($AllowHerbPouchStorage) { @('herbpouch', 'backpack') } else { @('backpack') }
    $drinkPrompt = if ($AllowDrinkAndKeep) {
        "{0}: drink one jarful of Taunor Water now for 6 ENDURANCE?" -f $SectionLabel
    }
    else {
        "{0}: drink the Taunor Water now for 6 ENDURANCE?" -f $SectionLabel
    }

    $drinkNow = Read-LWInlineYesNo -Prompt $drinkPrompt -Default $false
    if ($drinkNow) {
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + 6))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
        }
        Write-LWInfo ("{0}: Taunor Water restores {1} ENDURANCE. Current Endurance: {2}." -f $SectionLabel, $restored, [int]$script:GameState.Character.EnduranceCurrent)
        if (-not $AllowDrinkAndKeep) {
            Set-LWStoryAchievementFlag -Name $ResolvedFlagName
            return
        }
    }

    $keepForLater = $true
    if ($AllowDrinkAndKeep) {
        $keepForLater = Read-LWInlineYesNo -Prompt ("{0}: refill the glass jar and keep Taunor Water for later use?" -f $SectionLabel) -Default $true
    }

    if (-not $keepForLater) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        if ($drinkNow) {
            Write-LWInfo ("{0}: no filled glass jar is kept for later use." -f $SectionLabel)
        }
        return
    }

    $existingWaterLocation = Find-LWStateInventoryItemLocation -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Types $storageTypes
    if ($null -ne $existingWaterLocation) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Set-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored'
        $storageLabel = if ([string]$existingWaterLocation.Type -eq 'herbpouch') { 'Herb Pouch' } else { 'Backpack' }
        Write-LWInfo ("{0}: you keep a filled glass jar of Taunor Water for later use in your {1}." -f $SectionLabel, $storageLabel)
        return
    }

    if ($AllowDrinkAndKeep) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
    }

    $stored = if ($AllowHerbPouchStorage) {
        TryAdd-LWPreferredPotionStorageSilently -Name 'Taunor Water'
    }
    else {
        TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Taunor Water'
    }

    if ($stored) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Set-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored'
        $storedLocation = Find-LWStateInventoryItemLocation -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Types $storageTypes
        $storageLabel = if ($null -ne $storedLocation -and [string]$storedLocation.Type -eq 'herbpouch') { 'Herb Pouch' } else { 'Backpack' }
        Write-LWInfo ("{0}: Taunor Water stored in your {1}. It restores 6 ENDURANCE when used." -f $SectionLabel, $storageLabel)
        return
    }

    if ($AllowHerbPouchStorage) {
        Write-LWWarn ("{0}: no room to store the Taunor Water automatically in your Herb Pouch or Backpack. Make room and add it manually if you want to keep it." -f $SectionLabel)
        return
    }

    Write-LWWarn ("{0}: no room to store the Taunor Water automatically. Drink it now or make room and add it manually if you want to keep it." -f $SectionLabel)
}

function Get-LWMagnakaiBookSixConditionValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $Default
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'Conditions') -or $null -eq $script:GameState.Conditions) {
        return $Default
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState.Conditions -Name $Name) -or $null -eq $script:GameState.Conditions.$Name) {
        return $Default
    }

    return $script:GameState.Conditions.$Name
}

function Set-LWMagnakaiBookSixConditionValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value
    )

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'Conditions') -or $null -eq $script:GameState.Conditions) {
        $script:GameState | Add-Member -Force -NotePropertyName Conditions -NotePropertyValue (New-LWConditionState)
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState.Conditions -Name $Name)) {
        $script:GameState.Conditions | Add-Member -Force -NotePropertyName $Name -NotePropertyValue $Value
        return
    }

    $script:GameState.Conditions.$Name = $Value
}

function Clear-LWMagnakaiBookSixConditionValue {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name)) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'Conditions') -or $null -eq $script:GameState.Conditions) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState.Conditions -Name $Name)) {
        return
    }

    $script:GameState.Conditions.$Name = $null
}

function Test-LWMagnakaiBookSixHasLoreCircleOfFire {
    param([object]$State = $script:GameState)

    return (
        (Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and
        (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery')
    )
}

function Invoke-LWMagnakaiBookSixSection016MapClaim {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section016MapClaimed') {
        return
    }

    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfVarettaItemNames) -Type 'special') {
        Set-LWStoryAchievementFlag -Name 'Book6Section016MapClaimed'
        return
    }

    if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of Varetta') {
        Set-LWStoryAchievementFlag -Name 'Book6Section016MapClaimed'
        Write-LWInfo 'Section 16: Map of Varetta added to Special Items.'
        return
    }

    Write-LWWarn 'No room to add the Map of Varetta automatically. Make room and add it manually if needed.'
}

function Invoke-LWMagnakaiBookSixSectionCessPurchaseSource {
    param([Parameter(Mandatory = $true)][string]$SectionLabel)

    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWCessItemNames) -Type 'special') {
        Write-LWInfo ("{0}: you already carry a Cess, so this purchase can be skipped." -f $SectionLabel)
        return
    }

    if (Test-LWStoryAchievementFlag -Name 'Book6CessPurchasePaid') {
        Write-LWInfo ("{0}: the 3 Gold Crown payment has already been made. Continue to section 304 to collect the Cess." -f $SectionLabel)
        return
    }

    $goldCrowns = [int]$script:GameState.Inventory.GoldCrowns
    if ($goldCrowns -lt 3) {
        Write-LWWarn ("{0}: the Cess route assumes you can pay 3 Gold Crowns, but only {1} are currently recorded." -f $SectionLabel, $goldCrowns)
        return
    }

    if (Read-LWInlineYesNo -Prompt ("{0}: pay 3 Gold Crowns for a Cess now?" -f $SectionLabel) -Default $true) {
        Update-LWGold -Delta -3
        Set-LWStoryAchievementFlag -Name 'Book6CessPurchasePaid'
        Write-LWInfo ("{0}: 3 Gold Crowns paid for a Cess. Continue to section 304 to collect it." -f $SectionLabel)
        return
    }

    Write-LWInfo ("{0}: no payment taken. Follow the original section text manually for the non-purchase branches." -f $SectionLabel)
}

function Invoke-LWMagnakaiBookSixSection137LevyPrompt {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section137LevyPaid') {
        Write-LWInfo 'Section 137: the Quarlen levy has already been paid. Continue to section 332.'
        return
    }

    $goldCrowns = [int]$script:GameState.Inventory.GoldCrowns
    if ($goldCrowns -lt 3) {
        Write-LWWarn ("Section 137: entering Quarlen by the gate route assumes you can pay the 3 Gold Crown levy, but only {0} are currently recorded." -f $goldCrowns)
        return
    }

    if (Read-LWInlineYesNo -Prompt 'Section 137: pay the 3 Gold Crown levy now?' -Default $true) {
        Update-LWGold -Delta -3
        Set-LWStoryAchievementFlag -Name 'Book6Section137LevyPaid'
        Write-LWInfo 'Section 137: 3 Gold Crowns paid to enter Quarlen. Continue to section 332.'
        return
    }

    Write-LWInfo 'Section 137: no levy is paid. Follow the original section text manually if you ride on to section 115 instead.'
}

function Invoke-LWMagnakaiBookSixSection165MapPurchasePrompt {
    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfVarettaItemNames) -Type 'special') {
        Set-LWStoryAchievementFlag -Name 'Book6Section016MapClaimed'
        Write-LWInfo 'Section 165: you already carry the Map of Varetta, so this purchase can be skipped.'
        return
    }

    if (Test-LWStoryAchievementFlag -Name 'Book6Section165MapPaid') {
        Write-LWInfo 'Section 165: the 5 Gold Crown payment has already been made. Continue to section 16 to mark the Map of Varetta.'
        return
    }

    $goldCrowns = [int]$script:GameState.Inventory.GoldCrowns
    if ($goldCrowns -lt 5) {
        Write-LWWarn ("Section 165: the Map of Varetta purchase assumes you can pay 5 Gold Crowns, but only {0} are currently recorded." -f $goldCrowns)
        return
    }

    if (Read-LWInlineYesNo -Prompt 'Section 165: pay 5 Gold Crowns for the Map of Varetta now?' -Default $true) {
        Update-LWGold -Delta -5
        Set-LWStoryAchievementFlag -Name 'Book6Section165MapPaid'
        Write-LWInfo 'Section 165: 5 Gold Crowns paid for the Map of Varetta. Continue to section 16 to claim it.'
        return
    }

    Write-LWInfo 'Section 165: no purchase is made. Follow the original section text manually if you turn away to section 262 instead.'
}

function Invoke-LWMagnakaiBookSixSection328MealPurchase {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section328MealPaid') {
        return
    }

    $goldCrowns = [int]$script:GameState.Inventory.GoldCrowns
    if ($goldCrowns -lt 2) {
        Write-LWWarn ("Section 328: the roast-beef route assumes you can pay 2 Gold Crowns, but only {0} are currently recorded." -f $goldCrowns)
        return
    }

    Update-LWGold -Delta -2
    Set-LWStoryAchievementFlag -Name 'Book6Section328MealPaid'
    Write-LWInfo 'Section 328: 2 Gold Crowns paid for the roast beef before continuing to section 219.'
}

function Invoke-LWMagnakaiBookSixLaumspurPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedFlagName,
        [Parameter(Mandatory = $true)][string]$SectionLabel
    )

    if (Test-LWStoryAchievementFlag -Name $ResolvedFlagName) {
        return
    }

    $drinkNow = Read-LWInlineYesNo -Prompt ("{0}: swallow the Potion of Laumspur now for 4 ENDURANCE?" -f $SectionLabel) -Default $false
    if ($drinkNow) {
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + 4))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
            Register-LWManualRecoveryShortcut
        }
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Write-LWInfo ("{0}: Potion of Laumspur restores {1} ENDURANCE." -f $SectionLabel, $restored)
        return
    }

    if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Potion of Laumspur') {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Write-LWInfo ("{0}: Potion of Laumspur stored in your Backpack for later use." -f $SectionLabel)
        return
    }

    Write-LWWarn ("{0}: no room to store the Potion of Laumspur automatically. Make room and add it manually if you are keeping it." -f $SectionLabel)
}

function Invoke-LWMagnakaiBookSixMealRequirement {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedFlagName,
        [Parameter(Mandatory = $true)][string]$NoMealFlagName,
        [Parameter(Mandatory = $true)][string]$SectionLabel,
        [Parameter(Mandatory = $true)][string]$NoMealMessagePrefix,
        [Parameter(Mandatory = $true)][string]$FatalCause,
        [switch]$AllowInnMeal,
        [int]$InnMealCost = 0,
        [string]$InnMealLabel = 'inn meal'
    )

    if (Test-LWStoryAchievementFlag -Name $ResolvedFlagName) {
        return
    }

    $maxOption = if ($AllowInnMeal) { 2 } else { 1 }
    Write-LWRetroPanelHeader -Title ("{0} Meal Check" -f $SectionLabel) -AccentColor 'DarkYellow'
    Write-LWRetroPanelTextRow -Text '1. Use normal meal rules now' -TextColor 'Gray'
    if ($AllowInnMeal) {
        Write-LWRetroPanelTextRow -Text ("2. Pay {0} Gold Crowns for {1}" -f $InnMealCost, $InnMealLabel) -TextColor 'Gray'
    }
    Write-LWRetroPanelTextRow -Text '0. Go without and take the ENDURANCE loss' -TextColor 'DarkGray'
    Write-LWRetroPanelFooter

    $choice = Read-LWInt -Prompt ("{0} meal choice" -f $SectionLabel) -Default 1 -Min 0 -Max $maxOption -NoRefresh
    switch ($choice) {
        1 {
            Use-LWMeal
            Set-LWStoryAchievementFlag -Name $ResolvedFlagName
            return
        }
        2 {
            if ($AllowInnMeal) {
                if ([int]$script:GameState.Inventory.GoldCrowns -lt $InnMealCost) {
                    Write-LWWarn ("{0}: you do not have the {1} Gold Crowns needed for {2}." -f $SectionLabel, $InnMealCost, $InnMealLabel)
                    return
                }

                Update-LWGold -Delta (-[int]$InnMealCost)
                Set-LWStoryAchievementFlag -Name $ResolvedFlagName
                Write-LWInfo ("{0}: {1} paid for with {2} Gold Crowns." -f $SectionLabel, $InnMealLabel, $InnMealCost)
                return
            }
        }
    }

    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName $NoMealFlagName -Delta -3 -MessagePrefix $NoMealMessagePrefix -FatalCause $FatalCause)
    Set-LWStoryAchievementFlag -Name $ResolvedFlagName
}

function Invoke-LWMagnakaiBookSixSection157MealsPrompt {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section157MealsClaimed') {
        return
    }

    if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'Section 157: you have no Backpack, so the spare bread cannot be carried.'
        Set-LWStoryAchievementFlag -Name 'Book6Section157MealsClaimed'
        return
    }

    $freeSlots = [Math]::Max(0, (8 - (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))))
    $maxMeals = [Math]::Min(2, $freeSlots)
    if ($maxMeals -le 0) {
        Write-LWWarn 'Section 157: there is no Backpack space left for the spare bread.'
        Set-LWStoryAchievementFlag -Name 'Book6Section157MealsClaimed'
        return
    }

    $mealCount = Read-LWInt -Prompt ("Section 157: how many extra Meals do you take? (0-{0})" -f $maxMeals) -Default $maxMeals -Min 0 -Max $maxMeals -NoRefresh
    if ($mealCount -gt 0) {
        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity ([int]$mealCount))
        Write-LWInfo ("Section 157: added {0} Meal{1} to your Backpack." -f [int]$mealCount, $(if ($mealCount -eq 1) { '' } else { 's' }))
    }
    else {
        Write-LWInfo 'Section 157: you leave the extra bread behind.'
    }

    Set-LWStoryAchievementFlag -Name 'Book6Section157MealsClaimed'
}

function Invoke-LWMagnakaiBookSixSection172InnRoute {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section172Handled') {
        return
    }

    $foodCost = 2
    $roomCost = 3
    $totalCost = $foodCost + $roomCost
    if ([int]$script:GameState.Inventory.GoldCrowns -lt $totalCost) {
        Write-LWWarn ("Section 172: this route assumes you can pay {0} Gold Crowns for food and room, but you only have {1}." -f $totalCost, [int]$script:GameState.Inventory.GoldCrowns)
    }
    else {
        Update-LWGold -Delta (-$foodCost)
        Update-LWGold -Delta (-$roomCost)
        Write-LWInfo 'Section 172: 2 Gold Crowns paid for supper and 3 Gold Crowns paid for Room 17.'
    }

    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWIronKeyItemNames) -Type 'special')) {
        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Iron Key') {
            Write-LWInfo 'Section 172: Iron Key added to Special Items.'
        }
        else {
            Write-LWWarn 'Section 172: no room to add the Iron Key automatically. Make room and add it manually if needed.'
        }
    }

    Set-LWStoryAchievementFlag -Name 'Book6Section172Handled'
}

function Invoke-LWMagnakaiBookSixSection017RoomRoute {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section017Handled') {
        $resolvedTarget = [int](Get-LWMagnakaiBookSixConditionValue -Name 'BookSixSection017RoomTarget' -Default 0)
        if ($resolvedTarget -gt 0) {
            Write-LWInfo ("Section 17: lodging already arranged. Continue to section {0}." -f $resolvedTarget)
        }
        return
    }

    $gold = [int]$script:GameState.Inventory.GoldCrowns
    $roomOptions = @()

    if ($gold -ge 2) {
        $roomOptions += [pscustomobject]@{
            Label     = 'Dormitory'
            CostLabel = '2 Gold Crowns'
            CostType  = 'gold'
            Cost      = 2
            Target    = 144
        }
    }
    if ($gold -ge 3) {
        $roomOptions += [pscustomobject]@{
            Label     = 'Single Room (second class)'
            CostLabel = '3 Gold Crowns'
            CostType  = 'gold'
            Cost      = 3
            Target    = 202
        }
    }
    if ($gold -ge 5) {
        $roomOptions += [pscustomobject]@{
            Label     = 'Single Room (with hot bath)'
            CostLabel = '5 Gold Crowns'
            CostType  = 'gold'
            Cost      = 5
            Target    = 251
        }
    }

    if ($gold -lt 2) {
        $barterItems = @()
        foreach ($weapon in @(Get-LWInventoryItems -Type 'weapon' | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
            $barterItems += [pscustomobject]@{
                Type  = 'weapon'
                Name  = [string]$weapon
                Label = ("Weapon: {0}" -f [string]$weapon)
            }
        }
        foreach ($backpackItem in @(Get-LWInventoryItems -Type 'backpack' | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
            $barterItems += [pscustomobject]@{
                Type  = 'backpack'
                Name  = [string]$backpackItem
                Label = ("Backpack: {0}" -f [string]$backpackItem)
            }
        }

        if ($barterItems.Count -gt 0) {
            $roomOptions += [pscustomobject]@{
                Label       = 'Dormitory'
                CostLabel   = '1 Backpack Item or Weapon'
                CostType    = 'barter'
                Cost        = 1
                Target      = 144
                BarterItems = @($barterItems)
            }
        }
    }

    if ($roomOptions.Count -le 0) {
        Write-LWWarn ("Section 17: you cannot currently afford even the dormitory, and you have no Backpack Item or Weapon to trade. Gold Crowns: {0}." -f $gold)
        return
    }

    Write-LWRetroPanelHeader -Title 'Section 17 Lodging' -AccentColor 'DarkYellow'
    for ($i = 0; $i -lt $roomOptions.Count; $i++) {
        $option = $roomOptions[$i]
        Write-LWRetroPanelTextRow -Text ("{0}. {1} - {2} -> section {3}" -f ($i + 1), [string]$option.Label, [string]$option.CostLabel, [int]$option.Target) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter

    $choiceIndex = if ($roomOptions.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Section 17 lodging choice' -Default 1 -Min 1 -Max $roomOptions.Count -NoRefresh }
    $choice = $roomOptions[$choiceIndex - 1]

    if ([string]$choice.CostType -eq 'gold') {
        Update-LWGold -Delta (-[int]$choice.Cost)
        Write-LWInfo ("Section 17: paid {0} for {1}." -f [string]$choice.CostLabel, [string]$choice.Label)
    }
    else {
        $barterItems = @($choice.BarterItems)
        Write-LWRetroPanelHeader -Title 'Section 17 Barter Payment' -AccentColor 'DarkYellow'
        for ($i = 0; $i -lt $barterItems.Count; $i++) {
            Write-LWRetroPanelTextRow -Text ("{0}. {1}" -f ($i + 1), [string]$barterItems[$i].Label) -TextColor 'Gray'
        }
        Write-LWRetroPanelFooter

        $barterIndex = if ($barterItems.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Section 17 barter item' -Default 1 -Min 1 -Max $barterItems.Count -NoRefresh }
        $barterChoice = $barterItems[$barterIndex - 1]
        if (Remove-LWInventoryItemSilently -Type ([string]$barterChoice.Type) -Name ([string]$barterChoice.Name) -Quantity 1) {
            Write-LWInfo ("Section 17: traded {0} for a night in the dormitory." -f [string]$barterChoice.Name)
        }
        else {
            Write-LWWarn ("Section 17: could not remove {0} automatically. Update your inventory manually before continuing." -f [string]$barterChoice.Name)
            return
        }
    }

    Set-LWMagnakaiBookSixConditionValue -Name 'BookSixSection017RoomTarget' -Value ([int]$choice.Target)
    Set-LWStoryAchievementFlag -Name 'Book6Section017Handled'
    Write-LWInfo ("Section 17: continue to section {0}." -f [int]$choice.Target)
}

function Invoke-LWMagnakaiBookSixSection212HorseTrade {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section212HorseTradeResolved') {
        return
    }

    $specialItems = @((Get-LWInventoryItems -Type 'special') | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $hasGoldOption = ([int]$script:GameState.Inventory.GoldCrowns -ge 20)
    $hasSpecialOption = ($specialItems.Count -ge 2)
    if (-not $hasGoldOption -and -not $hasSpecialOption) {
        Write-LWWarn 'Section 212: you do not currently have the 20 Gold Crowns or 2 Special Items needed to honour Altan''s bargain.'
        return
    }

    $paymentMethod = 1
    if ($hasGoldOption -and $hasSpecialOption) {
        Write-LWRetroPanelHeader -Title 'Section 212 Horse Trade' -AccentColor 'DarkYellow'
        Write-LWRetroPanelTextRow -Text '1. Pay 20 Gold Crowns' -TextColor 'Gray'
        Write-LWRetroPanelTextRow -Text '2. Surrender 2 Special Items' -TextColor 'Gray'
        Write-LWRetroPanelFooter
        $paymentMethod = Read-LWInt -Prompt 'Section 212 payment choice' -Default 1 -Min 1 -Max 2 -NoRefresh
    }
    elseif (-not $hasGoldOption) {
        $paymentMethod = 2
    }

    if ($paymentMethod -eq 1) {
        Update-LWGold -Delta -20
        Write-LWInfo 'Section 212: 20 Gold Crowns paid to Altan for his horse.'
        Set-LWStoryAchievementFlag -Name 'Book6Section212HorseTradeResolved'
        return
    }

    for ($lossIndex = 1; $lossIndex -le 2; $lossIndex++) {
        $specialItems = @((Get-LWInventoryItems -Type 'special') | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if ($specialItems.Count -le 0) {
            Write-LWWarn 'Section 212: no more Special Items are available to surrender.'
            break
        }

        Write-LWInfo ("Section 212: choose Special Item {0} to trade away." -f $lossIndex)
        Show-LWInventorySlotsSection -Type 'special'
        $slot = Read-LWInt -Prompt ("Section 212 Special Item #{0}" -f $lossIndex) -Default 1 -Min 1 -Max $specialItems.Count -NoRefresh
        $lostItem = [string]$specialItems[$slot - 1]
        [void](Remove-LWInventoryItemSilently -Type 'special' -Name $lostItem -Quantity 1)
        Write-LWInfo ("Section 212: surrendered {0} to Altan." -f $lostItem)
    }

    Set-LWStoryAchievementFlag -Name 'Book6Section212HorseTradeResolved'
}

function Invoke-LWMagnakaiBookSixSection220Donation {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section220DonationHandled') {
        return
    }

    $maxDonation = [int]$script:GameState.Inventory.GoldCrowns
    $donation = Read-LWInt -Prompt ("Section 220: donate how many Gold Crowns? (0-{0})" -f $maxDonation) -Default 0 -Min 0 -Max $maxDonation -NoRefresh
    if ($donation -gt 0) {
        Update-LWGold -Delta (-[int]$donation)
        Write-LWInfo ("Section 220: donated {0} Gold Crown{1} to the statue of Vynar Jupe." -f [int]$donation, $(if ($donation -eq 1) { '' } else { 's' }))
    }
    else {
        Write-LWInfo 'Section 220: no donation is made to the statue.'
    }

    Set-LWStoryAchievementFlag -Name 'Book6Section220DonationHandled'
}

function Invoke-LWMagnakaiBookSixSection297BroninSleeveShieldTrade {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section297Handled') {
        return
    }

    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBroninSleeveShieldItemNames) -Type 'special') {
        Set-LWStoryAchievementFlag -Name 'Book6Section297Handled'
        return
    }

    $tradeOptions = @()

    $helmetItem = Get-LWMatchingStateInventoryItem -State $script:GameState -Names @((Get-LWHelmetItemNames) + (Get-LWSilverHelmItemNames)) -Type 'special'
    if (-not [string]::IsNullOrWhiteSpace($helmetItem)) {
        $tradeOptions += [pscustomobject]@{
            Label = ("Helmet: {0}" -f [string]$helmetItem)
            Name  = [string]$helmetItem
        }
    }

    $shieldItem = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWShieldItemNames) -Type 'special'
    if (-not [string]::IsNullOrWhiteSpace($shieldItem)) {
        $tradeOptions += [pscustomobject]@{
            Label = ("Shield: {0}" -f [string]$shieldItem)
            Name  = [string]$shieldItem
        }
    }

    foreach ($waistcoatName in @(
            (Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWChainmailItemNames) -Type 'special'),
            (Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWPaddedLeatherItemNames) -Type 'special')
        )) {
        if (-not [string]::IsNullOrWhiteSpace($waistcoatName)) {
            $tradeOptions += [pscustomobject]@{
                Label = ("Waistcoat: {0}" -f [string]$waistcoatName)
                Name  = [string]$waistcoatName
            }
        }
    }

    if ($tradeOptions.Count -le 0) {
        Write-LWInfo 'Section 297: no Helmet, Shield, or Waistcoat is available to trade for the Bronin Sleeve-shield.'
        Set-LWStoryAchievementFlag -Name 'Book6Section297Handled'
        return
    }

    $acceptTrade = Read-LWInlineYesNo -Prompt 'Section 297: trade one Helmet, Shield, or Waistcoat for the Bronin Sleeve-shield?' -Default $true
    if (-not $acceptTrade) {
        Write-LWInfo 'Section 297: the Bronin Sleeve-shield is declined.'
        Set-LWStoryAchievementFlag -Name 'Book6Section297Handled'
        return
    }

    $choiceIndex = 1
    if ($tradeOptions.Count -gt 1) {
        Write-LWRetroPanelHeader -Title 'Section 297 Armor Trade' -AccentColor 'DarkYellow'
        for ($i = 0; $i -lt $tradeOptions.Count; $i++) {
            Write-LWRetroPanelTextRow -Text ("{0}. {1}" -f ($i + 1), [string]$tradeOptions[$i].Label) -TextColor 'Gray'
        }
        Write-LWRetroPanelFooter
        $choiceIndex = Read-LWInt -Prompt 'Section 297 trade choice' -Default 1 -Min 1 -Max $tradeOptions.Count -NoRefresh
    }

    $tradedItem = [string]$tradeOptions[$choiceIndex - 1].Name
    if (-not (Remove-LWInventoryItemSilently -Type 'special' -Name $tradedItem -Quantity 1)) {
        Write-LWWarn ("Section 297: unable to remove {0} automatically. Please update your inventory manually." -f $tradedItem)
        Set-LWStoryAchievementFlag -Name 'Book6Section297Handled'
        return
    }

    if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Bronin Sleeve-shield') {
        Write-LWInfo ("Section 297: traded {0} for the Bronin Sleeve-shield." -f $tradedItem)
        Set-LWStoryAchievementFlag -Name 'Book6BroninSleeveShieldClaimed'
    }
    else {
        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name $tradedItem)
        Write-LWWarn 'Section 297: no room to add the Bronin Sleeve-shield automatically. Your original armor has been restored.'
    }

    Set-LWStoryAchievementFlag -Name 'Book6Section297Handled'
}

function Invoke-LWMagnakaiBookSixSection245ConundrumPrompt {
    if (Test-LWStoryAchievementFlag -Name 'Book6Section245StakeRecorded') {
        return
    }

    $maxStake = [Math]::Min(50, [int]$script:GameState.Inventory.GoldCrowns)
    if ($maxStake -le 0) {
        Write-LWWarn 'Section 245: you have no Gold Crowns available to wager on the conundrum.'
        Set-LWMagnakaiBookSixConditionValue -Name 'BookSixSection245ConundrumStake' -Value 0
        Set-LWStoryAchievementFlag -Name 'Book6Section245StakeRecorded'
        return
    }

    $stake = Read-LWInt -Prompt ("Section 245: conundrum wager (0-{0})" -f $maxStake) -Default ([Math]::Min(5, $maxStake)) -Min 0 -Max $maxStake -NoRefresh
    Set-LWMagnakaiBookSixConditionValue -Name 'BookSixSection245ConundrumStake' -Value ([int]$stake)
    Set-LWStoryAchievementFlag -Name 'Book6Section245StakeRecorded'
    if ($stake -gt 0) {
        Write-LWInfo ("Section 245: wager of {0} Gold Crown{1} recorded for the conundrum." -f [int]$stake, $(if ($stake -eq 1) { '' } else { 's' }))
    }
    else {
        Write-LWInfo 'Section 245: no Gold Crowns are wagered on the conundrum.'
    }
}

function Resolve-LWMagnakaiBookSixSection245ConundrumOutcome {
    param(
        [Parameter(Mandatory = $true)][int]$Section,
        [Parameter(Mandatory = $true)][bool]$Won
    )

    $resolvedFlag = ("Book6Section{0:000}ConundrumResolved" -f $Section)
    if (Test-LWStoryAchievementFlag -Name $resolvedFlag) {
        return
    }

    $stake = [int](Get-LWMagnakaiBookSixConditionValue -Name 'BookSixSection245ConundrumStake' -Default 0)
    if ($stake -gt 0) {
        if ($Won) {
            Update-LWGold -Delta $stake
            Write-LWInfo ("Section {0}: the conjurer pays you {1} Gold Crown{2}, equal to your wager." -f $Section, $stake, $(if ($stake -eq 1) { '' } else { 's' }))
        }
        else {
            Update-LWGold -Delta (-$stake)
            Write-LWInfo ("Section {0}: you lose the {1} Gold Crown{2} staked on the conundrum." -f $Section, $stake, $(if ($stake -eq 1) { '' } else { 's' }))
        }
    }
    else {
        Write-LWInfo ("Section {0}: no Gold Crowns were at stake on the conundrum." -f $Section)
    }

    Set-LWStoryAchievementFlag -Name $resolvedFlag
    Clear-LWMagnakaiBookSixConditionValue -Name 'BookSixSection245ConundrumStake'
}

function Invoke-LWMagnakaiBookSixSection284BettingRound {
    param([object]$State = $script:GameState)

    if ($null -ne $State) {
        $script:GameState = $State
        if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
    }
    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 6 -or [int]$script:GameState.CurrentSection -ne 284) {
        return $false
    }

    $roundsPlayed = [int](Get-LWMagnakaiBookSixConditionValue -Name 'BookSixSection284RoundsPlayed' -Default 0)
    if ($roundsPlayed -ge 3) {
        Write-LWInfo 'Section 284: all three betting rounds have already been resolved. If any Gold remains, turn to 347; otherwise, turn to 76.'
        return $true
    }

    $currentGold = [int]$script:GameState.Inventory.GoldCrowns
    if ($currentGold -le 0) {
        Write-LWInfo 'Section 284: you have lost all your Gold Crowns. Turn to 76.'
        Set-LWMagnakaiBookSixConditionValue -Name 'BookSixSection284RoundsPlayed' -Value 3
        return $true
    }

    $maxStake = [Math]::Min(10, $currentGold)
    $stake = Read-LWInt -Prompt ("Section 284 stake for round {0} (1-{1}, 0 to quit)" -f ($roundsPlayed + 1), $maxStake) -Default ([Math]::Min(5, $maxStake)) -Min 0 -Max $maxStake -NoRefresh
    if ($stake -eq 0) {
        Write-LWInfo 'Section 284: you quit the betting game. Turn to 336.'
        return $true
    }

    $firstRoll = Get-LWRandomDigit
    $secondRoll = Get-LWRandomDigit
    $secondTotal = [int]$secondRoll + 3
    Write-LWInfo ("Random Number Table rolls: {0}, {1}" -f $firstRoll, $secondRoll)
    Write-LWInfo ("Section 284: first roll is {0}; second roll is {1} and gains +3, for {2}." -f $firstRoll, $secondRoll, $secondTotal)
    if ($firstRoll -gt $secondTotal) {
        $winnings = [int]$stake * 2
        Update-LWGold -Delta $winnings
        Write-LWInfo ("Section 284: you win the bet and gain {0} Gold Crowns." -f $winnings)
    }
    else {
        Update-LWGold -Delta (-[int]$stake)
        Write-LWInfo ("Section 284: the rider wins and you lose your {0} Gold Crown stake." -f $stake)
    }

    $roundsPlayed++
    Set-LWMagnakaiBookSixConditionValue -Name 'BookSixSection284RoundsPlayed' -Value $roundsPlayed
    $remainingGold = [int]$script:GameState.Inventory.GoldCrowns
    if ($remainingGold -le 0) {
        Write-LWInfo 'Section 284: you have lost all your Gold Crowns. Turn to 76.'
    }
    elseif ($roundsPlayed -ge 3) {
        Write-LWInfo 'Section 284: three rounds are complete and you still have Gold. Turn to 347.'
    }
    else {
        Write-LWInfo ("Section 284: you may bet again for round {0} or quit to section 336." -f ($roundsPlayed + 1))
    }

    return $true
}

function Invoke-LWMagnakaiBookSixSectionRandomNumberResolution {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][object]$Context,
        [int[]]$Rolls = @(),
        [int[]]$EffectiveRolls = @(),
        [int]$Subtotal = 0,
        [int]$AdjustedTotal = 0
    )

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 6 -or $null -eq $Context) {
        return
    }

    switch ([int]$Context.Section) {
        34 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section034GoldResolved')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section034GoldResolved'
                Update-LWGold -Delta ([int]$AdjustedTotal)
                Write-LWInfo ("Section 34: the guard's purse yields {0} Gold Crowns." -f [int]$AdjustedTotal)
            }
        }
        56 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section056DamageApplied')) {
                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section056DamageApplied' -Delta (-[int]$AdjustedTotal) -MessagePrefix 'Section 56: the chest wound drops you hard to the ground.' -FatalCause 'The chest wound at section 56 reduced your Endurance to zero.')
            }
        }
        91 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section091WinningsResolved')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section091WinningsResolved'
                Update-LWGold -Delta ([int]$AdjustedTotal)
                Write-LWInfo ("Section 91: the marked deck wins you {0} Gold Crowns before the dealer catches on." -f [int]$AdjustedTotal)
            }
        }
    }
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

function Test-LWMagnakaiBookSixArcheryContestVisited {
    param([int[]]$VisitedSections = @())

    return (@(@(340, 26, 103, 183, 252, 335) | Where-Object { @($VisitedSections) -contains [int]$_ }).Count -gt 0)
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
    $visitedSections = if ($null -ne $State -and $null -ne $State.CurrentBookStats -and (Test-LWPropertyExists -Object $State.CurrentBookStats -Name 'VisitedSections') -and $null -ne $State.CurrentBookStats.VisitedSections) {
        @($State.CurrentBookStats.VisitedSections | ForEach-Object { [int]$_ })
    }
    else {
        @()
    }

    switch ($section) {
        24 {
            $description = 'Return-to-Cyrilus chance check.'
            if (Test-LWMagnakaiBookSixArcheryContestVisited -VisitedSections @($visitedSections)) {
                $modifier -= 2
                $modifierNotes += 'Earlier archery contest participation'
            }
        }
        34 {
            $description = 'Guard-purse gold check. Add 5 to the roll to determine the Gold Crowns found.'
            $modifier += 5
            $modifierNotes += 'Guard purse value'
            if (Test-LWStoryAchievementFlag -Name 'Book6Section034GoldResolved') {
                $bypassed = $true
                $bypassReason = 'The guard-purse gold from this section has already been applied.'
            }
        }
        56 {
            $description = 'Chest-wound loss check. In this instance, 0 counts as 10.'
            $zeroCountsAsTen = $true
            if (Test-LWStoryAchievementFlag -Name 'Book6Section056DamageApplied') {
                $bypassed = $true
                $bypassReason = 'The chest-wound ENDURANCE loss from this section has already been applied.'
            }
        }
        69 {
            $description = 'Creature-passage check: 0-5 -> 128, 6-14 -> 246.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Invisibility') {
                $modifier += 5
                $modifierNotes += 'Invisibility'
            }
        }
        72 {
            $description = 'Jump-the-wagon mounted leap check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Animal Control') {
                $modifier += 2
                $modifierNotes += 'Animal Control'
            }
        }
        91 {
            $description = 'Marked-deck winnings check. Add 5 to the roll to determine the Gold Crowns won.'
            $modifier += 5
            $modifierNotes += 'Marked deck winnings'
            if (Test-LWStoryAchievementFlag -Name 'Book6Section091WinningsResolved') {
                $bypassed = $true
                $bypassReason = 'The marked-deck winnings from this section have already been applied.'
            }
        }
        95 {
            $description = 'Close-range bow-shot check.'
            if (@($State.Character.WeaponmasteryWeapons) -contains 'Bow') {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow'
            }
        }
        97 {
            $description = 'Ambush branch check: 0-3 -> 174, 4-6 -> 313, 7-9 -> 57.'
        }
        101 {
            $description = 'Warhammer retrieval check.'
            $hasHuntmastery = Test-LWStateHasDiscipline -State $State -Name 'Huntmastery'
            $hasWeaponmastery = Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery'
            $hasLongRope = -not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWLongRopeItemNames) -Type 'backpack'))
            $ropeCount = @((Get-LWInventoryItems -Type 'backpack') | Where-Object { [string]$_ -ieq 'Rope' }).Count

            if ($hasHuntmastery) {
                if ($hasWeaponmastery) {
                    $modifier += 3
                    $modifierNotes += 'Lore-circle of Fire (Weaponmastery and Huntmastery)'
                }
                else {
                    $modifier += 2
                    $modifierNotes += 'Huntmastery'
                }
            }

            if ($hasLongRope -or $ropeCount -ge 2) {
                $modifier += 2
                if ($hasLongRope) {
                    $modifierNotes += 'Long Rope'
                }
                else {
                    $modifierNotes += 'Two or more Ropes'
                }
            }
        }
        126 {
            $description = 'Tekaro bridge charge check: 0-3 -> 244, 4-6 -> 29, 7-9 -> 150.'
        }
        142 {
            $description = 'Thrown-blade avoidance check: 4 or less -> 184, 5 or more -> 51.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Nexus') -or (Test-LWStateHasDiscipline -State $State -Name 'Divination')) {
                $modifier -= 2
                $modifierNotes += 'Nexus or Divination'
            }
            if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames)) {
                $modifier -= 3
                $modifierNotes += 'Shield'
            }
        }
        163 {
            $description = 'River escape check: 3 or less -> 197, 4 or higher -> 229.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Invisibility') {
                $modifier += 4
                $modifierNotes += 'Invisibility'
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
        }
        207 {
            $description = 'Return-to-Cyrilus chance check after recovering the Bronin Warhammer.'
            if (Test-LWMagnakaiBookSixArcheryContestVisited -VisitedSections @($visitedSections)) {
                $modifier -= 2
                $modifierNotes += 'Earlier archery contest participation'
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
        261 {
            $description = 'Gate escape check: 0-2 -> 99, 3-6 -> 187, 7 or higher -> 22.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Animal Control') {
                $modifier += 3
                $modifierNotes += 'Animal Control'
            }
        }
        271 {
            $description = 'Archers-at-the-field check: 5 or below -> 52, 6 or higher -> 81.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Animal Control') -or (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery')) {
                $modifier += 3
                $modifierNotes += 'Animal Control or Huntmastery'
            }
        }
        291 {
            $description = 'Dice challenge check: 0-4 -> 177, 5-9 -> 309.'
        }
        317 {
            $description = 'Crossbow ambush check: 6 or less -> 85, 7 or higher -> 153.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Divination') -or (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery')) {
                $modifier -= 5
                $modifierNotes += 'Divination or Huntmastery'
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

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
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

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
    if ($FromSection -eq 232 -and $ToSection -eq 219 -and -not (Test-LWStoryAchievementFlag -Name 'Book6Section232MealDeducted')) {
        if (Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 1) {
            Set-LWStoryAchievementFlag -Name 'Book6Section232MealDeducted'
            Write-LWInfo 'Section 232: Meal deducted immediately before you head to your room.'
        }
        else {
            Write-LWWarn 'Section 232: the room route assumes you eat a Meal immediately, but no Meal was available to deduct.'
        }
    }
    if ($FromSection -eq 253 -and $ToSection -eq 35 -and -not (Test-LWStoryAchievementFlag -Name 'Book6Section253RoomPaid')) {
        if ([int]$script:GameState.Inventory.GoldCrowns -ge 3) {
            Update-LWGold -Delta -3
            Set-LWStoryAchievementFlag -Name 'Book6Section253RoomPaid'
            Write-LWInfo 'Section 253: 3 Gold Crowns paid for the room and your horse''s keep.'
        }
        else {
            Write-LWWarn 'Section 253: the lodging route assumes you can pay 3 Gold Crowns for the room and your horse''s keep.'
        }
    }
}

function Get-LWMagnakaiBookSixInstantDeathCause {
    param([Parameter(Mandatory = $true)][int]$Section)

    switch ($Section) {
        29 { return 'Section 29: arrows cut you down beneath the Tekaro gate.' }
        36 { return 'Section 36: your horse collapses at the wagon jump and crushes you.' }
        52 { return 'Section 52: the archers on the highway to Varetta kill you.' }
        57 { return 'Section 57: the bolt at Denka Gate kills you instantly.' }
        80 { return 'Section 80: the Dakomyd knocks you into the acid pit.' }
        84 { return 'Section 84: the taxidermist''s drugged wine leaves you helpless.' }
        90 { return 'Section 90: the Dakomyd hurls you into the pit and acid.' }
        99 { return 'Section 99: the pike ambush leaves you bleeding to death.' }
        128 { return 'Section 128: the twin Yawshaths tear you apart in their lair.' }
        129 { return 'Section 129: you are condemned and executed by order of Lord Roark.' }
        161 { return 'Section 161: the robbers murder you after taking your Belt Pouch.' }
        192 { return 'Section 192: the twin Yawshaths kill you in the dungeons of Castle Taunor.' }
        218 { return 'Section 218: you are trampled to death on the bridge.' }
        242 { return 'Section 242: the temple congregation hacks you to pieces.' }
        257 { return 'Section 257: the energy bolt hurls you onto the altar and kills you.' }
        311 { return 'Section 311: the falling Yawshath carries you over the precipice.' }
        323 { return 'Section 323: the Dakomyd''s blood destroys your weapon before it kills you.' }
        329 { return 'Section 329: the arrow storm and the captain''s charge crush you on Tekaro Bridge.' }
        349 { return 'Section 349: the Dakomyd spawning chamber dissolves you in acid.' }
        default { return $null }
    }
}

function Invoke-LWMagnakaiBookSixSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
    if (-not (Test-LWHasState)) {
        return
    }

    $section = [int]$script:GameState.CurrentSection
    $instantDeathCause = Get-LWMagnakaiBookSixInstantDeathCause -Section $section
    if (-not [string]::IsNullOrWhiteSpace($instantDeathCause)) {
        Invoke-LWInstantDeath -Cause $instantDeathCause
        return
    }

    switch ($section) {
        2 {
            Invoke-LWBookFourChoiceTable -Title 'Section 2 Apothecary' -PromptLabel 'Section 2 choice' -ContextLabel 'Section 2' -Choices (Get-LWMagnakaiBookSixSection002ChoiceDefinitions) -Intro 'Section 2: the herbmaster will sell these potions as Backpack Items while you wait for the captain.'
        }
        16 {
            Invoke-LWMagnakaiBookSixSection016MapClaim
        }
        17 {
            Invoke-LWMagnakaiBookSixSection017RoomRoute
        }
        27 {
            Invoke-LWMagnakaiBookSixSectionCessPurchaseSource -SectionLabel 'Section 27'
        }
        10 {
            Invoke-LWMagnakaiBookSixSection010TicketPrompt
        }
        4 {
            Invoke-LWMagnakaiBookSixSection004WeaponLoss
        }
        8 {
            Invoke-LWBookFourChoiceTable -Title 'Section 8 Loot' -PromptLabel 'Section 8 choice' -ContextLabel 'Section 8' -Choices (Get-LWMagnakaiBookSixSection008ChoiceDefinitions) -Intro 'Section 8: keep any of Chanda''s valuables before you leave the shop.'
        }
        37 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section037DamageApplied' -Delta -12 -MessagePrefix 'Section 37: the acid flask shatters against your shoulder.' -FatalCause 'The acid attack at section 37 reduced your Endurance to zero.')
        }
        44 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section044DamageApplied' -Delta -2 -MessagePrefix 'Section 44: the crash throws you head-first against the rail.' -FatalCause 'The river-rail impact at section 44 reduced your Endurance to zero.')
        }
        49 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section049CessUsed')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section049CessUsed'
                if ((Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWCessItemNames) -Types @('special')) -gt 0) {
                    Write-LWInfo 'Section 49: the guard keeps the Cess to admit you through the gate.'
                }
                else {
                    Write-LWInfo 'Section 49: the Cess should now be erased from your Action Chart.'
                }
            }
        }
        50 {
            Resolve-LWMagnakaiBookSixSection245ConundrumOutcome -Section 50 -Won:$false
        }
        51 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section051DamageApplied' -Delta -2 -MessagePrefix 'Section 51: the thrown blade gashes your hip before your counterattack.' -FatalCause 'The blade wound at section 51 reduced your Endurance to zero.')
        }
        54 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section054DamageApplied' -Delta -2 -MessagePrefix 'Section 54: the draughty stable robs you of rest through the night.' -FatalCause 'The miserable night at section 54 reduced your Endurance to zero.')
        }
        62 {
            Resolve-LWMagnakaiBookSixSection245ConundrumOutcome -Section 62 -Won:$true
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
        85 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section085DamageApplied' -Delta -2 -MessagePrefix 'Section 85: the crossbow bolt grazes your scalp.' -FatalCause 'The crossbow graze at section 85 reduced your Endurance to zero.')
        }
        88 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section088GoldClaimed')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section088GoldClaimed'
                Update-LWGold -Delta 5
                Write-LWInfo 'Section 88: recovered 5 Gold Crowns from the dead robbers.'
            }
        }
        96 {
            if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWCessItemNames) -Type 'special') {
                Write-LWInfo 'Section 96: a carried Cess unlocks the Amory gate route to section 49.'
            }
            else {
                Write-LWInfo 'Section 96: without a Cess, the guard turns you away to section 221.'
            }
        }
        98 {
            Invoke-LWMagnakaiBookSixSection098Shop
        }
        65 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section065TaunorWaterResolved' -SectionLabel 'Section 65'
        }
        111 {
            Invoke-LWMagnakaiBookSixLaumspurPrompt -ResolvedFlagName 'Book6Section111LaumspurResolved' -SectionLabel 'Section 111'
        }
        113 {
            Resolve-LWMagnakaiBookSixSection245ConundrumOutcome -Section 113 -Won:$false
        }
        106 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section106TaunorWaterResolved' -SectionLabel 'Section 106'
        }
        112 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section112TaunorWaterResolved' -SectionLabel 'Section 112' -AllowDrinkAndKeep -AllowHerbPouchStorage
        }
        109 {
            if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfTekaroItemNames) -Type 'backpack')) {
                Invoke-LWBookFourChoiceTable -Title 'Section 109 Map' -PromptLabel 'Section 109 choice' -ContextLabel 'Section 109' -Choices (Get-LWMagnakaiBookSixSection109ChoiceDefinitions) -Intro 'Section 109: keep the Map of Tekaro if you want it.'
            }
        }
        123 {
            Invoke-LWBookFourChoiceTable -Title 'Section 123 Apothecary' -PromptLabel 'Section 123 choice' -ContextLabel 'Section 123' -Choices (Get-LWMagnakaiBookSixSection123ChoiceDefinitions) -Intro 'Section 123: Alether Berries cost 3 Gold Crowns each and may be bought up to three times.'
        }
        124 {
            if ((Test-LWStoryAchievementFlag -Name 'Book6Section010TicketClaimed') -or (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBook6RiverboatTicketItemNames))) {
                Write-LWInfo 'Section 124: the Riverboat Ticket route is available here. Turn to 59 if you are following the ticket branch.'
            }
            else {
                Write-LWInfo 'Section 124: without the Riverboat Ticket, this route continues to 290.'
            }
        }
        137 {
            Invoke-LWMagnakaiBookSixSection137LevyPrompt
        }
        139 {
            Invoke-LWBookFourChoiceTable -Title 'Section 139 Search' -PromptLabel 'Section 139 choice' -ContextLabel 'Section 139' -Choices (Get-LWMagnakaiBookSixSection139ChoiceDefinitions) -Intro 'Section 139: keep the slain assassin''s purse and Silver Brooch if you want them.'
        }
        141 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section141FeePaid')) {
                if ([int]$script:GameState.Inventory.GoldCrowns -ge 2) {
                    Update-LWGold -Delta -2
                    Write-LWInfo 'Section 141: 2 Gold Crowns paid as the tournament entrance fee.'
                }
                else {
                    Write-LWWarn 'Section 141: the tournament entry route assumes you can pay 2 Gold Crowns.'
                }
                Set-LWStoryAchievementFlag -Name 'Book6Section141FeePaid'
            }
        }
        145 {
            Invoke-LWBookFourChoiceTable -Title 'Section 145 Leader''s Purse' -PromptLabel 'Section 145 choice' -ContextLabel 'Section 145' -Choices (Get-LWMagnakaiBookSixSection145ChoiceDefinitions) -Intro 'Section 145: keep the Crowns and Ruby Ring if you want them.'
        }
        146 {
            Invoke-LWMagnakaiBookSixMealRequirement -ResolvedFlagName 'Book6Section146MealHandled' -NoMealFlagName 'Book6Section146NoMealLossApplied' -SectionLabel 'Section 146' -NoMealMessagePrefix 'Section 146: you ride on through the hunger and growing fatigue.' -FatalCause 'Hunger at section 146 reduced your Endurance to zero.'
        }
        153 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section153DamageApplied' -Delta -5 -MessagePrefix 'Section 153: the crossbow bolt tears a furrow from your ribs.' -FatalCause 'The crossbow wound at section 153 reduced your Endurance to zero.')
        }
        157 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section157RecoveryApplied' -Delta 1 -MessagePrefix 'Section 157: the hearty food restores 1 ENDURANCE point.')
            Invoke-LWMagnakaiBookSixSection157MealsPrompt
        }
        158 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name "Sinede's Silver Key") {
                    Set-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed'
                    Set-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed'
                    Write-LWInfo "Section 158: Sinede's Silver Key added to Special Items."
                }
                else {
                    Write-LWWarn "No room to add Sinede's Silver Key automatically. Make room and add it manually if needed."
                }
            }
            Invoke-LWBookFourChoiceTable -Title 'Section 158 Cellar' -PromptLabel 'Section 158 choice' -ContextLabel 'Section 158' -Choices (Get-LWMagnakaiBookSixSection158ChoiceDefinitions) -Intro 'Section 158: take whatever cellar supplies you want before midnight.'
        }
        160 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section160CessClaimed')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Cess') {
                    Set-LWStoryAchievementFlag -Name 'Book6Section160CessClaimed'
                    Set-LWStoryAchievementFlag -Name 'Book6CessClaimed'
                    Write-LWInfo 'Section 160: Cess added to Special Items.'
                }
                else {
                    Write-LWWarn 'No room to add the Cess automatically. Make room and add it manually if needed.'
                }
            }
        }
        164 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section164DamageApplied' -Delta -2 -MessagePrefix 'Section 164: the quarrel grazes your shoulder as you dodge aside.' -FatalCause 'The crossbow graze at section 164 reduced your Endurance to zero.')
        }
        165 {
            Invoke-LWMagnakaiBookSixSection165MapPurchasePrompt
        }
        169 {
            if (Test-LWMagnakaiBookSixHasLoreCircleOfFire -State $script:GameState) {
                Write-LWInfo 'Section 169: the Lore-circle of Fire route is available here. Turn to section 65 if you use it; otherwise the other branches are 222 and 285.'
            }
            else {
                Write-LWInfo 'Section 169: without the Lore-circle of Fire, this section branches to 222 if you stand and fight or 285 if you flee.'
            }
        }
        171 {
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section171ColdDamageApplied' -Delta -1 -MessagePrefix 'Section 171: the freezing river leaves you drained and numb.' -FatalCause 'The freezing river at section 171 reduced your Endurance to zero.')
            }
            elseif (-not (Test-LWStoryAchievementFlag -Name 'Book6Section171NexusProtected')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section171NexusProtected'
                Write-LWInfo 'Section 171: Nexus protects you from the freezing river water.'
            }
        }
        172 {
            Invoke-LWMagnakaiBookSixSection172InnRoute
        }
        174 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section174DamageApplied' -Delta -5 -MessagePrefix 'Section 174: the bolt tears skin and muscle from your ribs.' -FatalCause 'The crossbow bolt at section 174 reduced your Endurance to zero.')
        }
        187 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section187DamageApplied' -Delta -3 -MessagePrefix 'Section 187: one of the pike heads rips into your tunic and flesh.' -FatalCause 'The pike wound at section 187 reduced your Endurance to zero.')
        }
        190 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section190TaunorWaterResolved' -SectionLabel 'Section 190'
        }
        191 {
            Invoke-LWMagnakaiBookSixMealRequirement -ResolvedFlagName 'Book6Section191MealHandled' -NoMealFlagName 'Book6Section191NoMealLossApplied' -SectionLabel 'Section 191' -NoMealMessagePrefix 'Section 191: the long night''s ride leaves you weak with hunger at the ford.' -FatalCause 'Hunger at section 191 reduced your Endurance to zero.'
        }
        197 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section197DamageApplied' -Delta -2 -MessagePrefix 'Section 197: an arrow gashes your calf as you drift downstream.' -FatalCause 'The arrow wound at section 197 reduced your Endurance to zero.')
        }
        205 {
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery') {
                Write-LWInfo 'Section 205: Huntmastery identifies the Durenese hunting bow as the safe choice. Continue to section 60.'
            }
            else {
                Write-LWInfo 'Section 205: this is the Huntmastery bow-choice route to section 60.'
            }
        }
        207 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section207Handled')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section207Handled'
                $keepBroninWarhammer = Read-LWInlineYesNo -Prompt 'Section 207: keep the Bronin Warhammer as a weapon-like Special Item?' -Default $true
                if ($keepBroninWarhammer) {
                    if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Bronin Warhammer') {
                        Write-LWInfo 'Section 207: Bronin Warhammer added to Special Items.'
                    }
                    else {
                        Write-LWWarn 'No room to add the Bronin Warhammer automatically. Make room and add it manually if you want to keep it.'
                    }
                }
                else {
                    Write-LWInfo 'Section 207: Bronin Warhammer left behind.'
                }
            }
        }
        212 {
            Invoke-LWMagnakaiBookSixSection212HorseTrade
        }
        211 {
            if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfVarettaItemNames) -Type 'special') {
                Write-LWInfo 'Section 211: the Map of Varetta route is available here. Turn to section 17 instead of section 104.'
            }
            else {
                Write-LWInfo 'Section 211: without the Map of Varetta, this route continues to section 104.'
            }
        }
        214 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section214KalteBowPenaltySet')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section214KalteBowPenaltySet'
                Set-LWMagnakaiBookSixConditionValue -Name 'BookSixSection214KalteBowPenalty' -Value $true
                Write-LWInfo 'Section 214: the Kalte hunting bow applies -4 Combat Skill for the duration of the tournament.'
            }
        }
        220 {
            Invoke-LWMagnakaiBookSixSection220Donation
        }
        222 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section222DamageApplied' -Delta -12 -MessagePrefix 'Section 222: the dead Yawshath crushes you as it falls.' -FatalCause 'The Yawshath''s dying weight at section 222 reduced your Endurance to zero.')
        }
        223 {
            Resolve-LWMagnakaiBookSixSection245ConundrumOutcome -Section 223 -Won:$false
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
        245 {
            Invoke-LWMagnakaiBookSixSection245ConundrumPrompt
        }
        246 {
            Invoke-LWMagnakaiBookSixTaunorWaterPrompt -ResolvedFlagName 'Book6Section246TaunorWaterResolved' -SectionLabel 'Section 246'
        }
        248 {
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Invisibility') {
                Write-LWInfo 'Section 248: Invisibility opens the section 322 route here; the straight retaliation route is section 201.'
            }
            else {
                Write-LWInfo 'Section 248: without Invisibility, this confrontation goes to section 201 if you retaliate.'
            }
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
        253 {
            Invoke-LWMagnakaiBookSixMealRequirement -ResolvedFlagName 'Book6Section253MealHandled' -NoMealFlagName 'Book6Section253NoMealLossApplied' -SectionLabel 'Section 253' -NoMealMessagePrefix 'Section 253: the inn offers no comfort against your hunger tonight.' -FatalCause 'Hunger at section 253 reduced your Endurance to zero.' -AllowInnMeal -InnMealCost 1 -InnMealLabel 'the inn meal of black bread and eggs'
        }
        266 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section266RecoveryApplied' -Delta 1 -MessagePrefix 'Section 266: the cool ale restores 1 ENDURANCE point.')
        }
        273 {
            Invoke-LWMagnakaiBookSixSectionCessPurchaseSource -SectionLabel 'Section 273'
        }
        275 {
            Invoke-LWMagnakaiBookSixSection275Shop
        }
        276 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section276Handled')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section276Handled'
                $keepBroninWarhammer = Read-LWInlineYesNo -Prompt 'Section 276: keep the Bronin Warhammer?' -Default $true
                if ($keepBroninWarhammer) {
                    if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Bronin Warhammer') {
                        Write-LWInfo 'Section 276: Bronin Warhammer added to Special Items.'
                    }
                    else {
                        Write-LWWarn 'No room to add the Bronin Warhammer automatically. Make room and add it manually if you want to keep it.'
                    }
                }
                else {
                    Write-LWInfo 'Section 276: Bronin Warhammer left behind.'
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
                if (Remove-LWInventoryItemSilently -Type 'special' -Name "Sinede's Silver Key" -Quantity 1) {
                    Write-LWInfo "Section 293: Sinede's Silver Key is used to open the tomb and is erased."
                }
                else {
                    Write-LWInfo "Section 293: Sinede's Silver Key should now be erased from your Action Chart."
                }
            }
        }
        295 {
            if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Type 'special') {
                Write-LWInfo 'Section 295: the Sommerswerd route is available here. Turn to section 321 instead of the attack (257) or flight (182) branches.'
            }
            else {
                Write-LWInfo 'Section 295: without the Sommerswerd, this section branches to 257 if you attack or 182 if you flee.'
            }
        }
        297 {
            Invoke-LWMagnakaiBookSixSection297BroninSleeveShieldTrade
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
        313 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book6Section313DamageApplied' -Delta -8 -MessagePrefix 'Section 313: the bolt sinks deeply into your shoulder.' -FatalCause 'The bolt wound at section 313 reduced your Endurance to zero.')
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
        316 {
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery') {
                Write-LWInfo 'Section 316: Huntmastery opens the section 114 route here. Otherwise fighting goes to 282, and surrendering all current Gold Crowns leads to the fatal section 161.'
            }
            elseif ([int]$script:GameState.Inventory.GoldCrowns -le 0) {
                Write-LWInfo 'Section 316: with no Gold Crowns to surrender, this ambush goes straight to the fight route at section 282.'
            }
            else {
                Write-LWInfo 'Section 316: without Huntmastery, fighting goes to section 282 and surrendering all current Gold Crowns leads to the fatal section 161.'
            }
        }
        318 {
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
                Write-LWInfo 'Section 318: Animal Control opens the safe route to section 32 here. The other branches are 349 and 4.'
            }
            else {
                Write-LWInfo 'Section 318: without Animal Control, this section branches to 349 if you push through the strands or 4 if you sweep them aside with a weapon.'
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
        328 {
            Invoke-LWMagnakaiBookSixSection328MealPurchase
        }
        348 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost'
                Write-LWInfo 'Section 348: the chapel Warhammer slips back into the black puddle and is lost.'
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

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

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


function Get-LWBook6LatestCessSectionEvent {
    param([Parameter(Mandatory = $true)][object]$State)

    $timeline = @()
    if ((Test-LWPropertyExists -Object $State -Name 'SectionCheckpoints') -and $null -ne $State.SectionCheckpoints) {
        foreach ($checkpoint in @($State.SectionCheckpoints)) {
            if ($null -eq $checkpoint -or -not (Test-LWPropertyExists -Object $checkpoint -Name 'Section') -or $null -eq $checkpoint.Section) {
                continue
            }

            $sectionNumber = [int]$checkpoint.Section
            if ($sectionNumber -in @(49, 160, 304)) {
                $timeline += $sectionNumber
            }
        }
    }

    if ((Test-LWPropertyExists -Object $State -Name 'CurrentSection') -and $null -ne $State.CurrentSection) {
        $currentSection = [int]$State.CurrentSection
        if ($currentSection -in @(49, 160, 304)) {
            $timeline += $currentSection
        }
    }

    if ($timeline.Count -gt 0) {
        return [int]$timeline[-1]
    }

    return $null
}

function Get-LWBook6RiverboatTicketItemNames {
    return @(
        'Riverboat Ticket to Luyen',
        'Riverboat Ticket to Rhem',
        'Riverboat Ticket to Eula',
        'Riverboat Ticket'
    )
}

function Get-LWBookSixSectionContextAchievementIds {
    return @(
        'jump_the_wagons',
        'water_bearer',
        'tekaro_cartographer',
        'key_to_varetta',
        'silver_oak_prize',
        'cess_to_enter',
        'cold_comfort',
        'mind_over_malice_book6'
    )
}



function Get-LWBookSixDECuringOption {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State -or $null -eq $State.Conditions) {
        return -1
    }
    if (-not (Test-LWPropertyExists -Object $State.Conditions -Name 'BookSixDECuringOption') -or $null -eq $State.Conditions.BookSixDECuringOption) {
        return -1
    }

    return [int]$State.Conditions.BookSixDECuringOption
}

function Set-LWBookSixDECuringOption {
    param(
        [Parameter(Mandatory = $true)][int]$Option,
        [object]$State = $script:GameState
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State) {
        return
    }
    if (-not (Test-LWPropertyExists -Object $State -Name 'Conditions') -or $null -eq $State.Conditions) {
        $State | Add-Member -Force -NotePropertyName Conditions -NotePropertyValue (New-LWConditionState)
    }
    if (-not (Test-LWPropertyExists -Object $State.Conditions -Name 'BookSixDECuringOption')) {
        $State.Conditions | Add-Member -Force -NotePropertyName BookSixDECuringOption -NotePropertyValue $Option
    }
    else {
        $State.Conditions.BookSixDECuringOption = $Option
    }
}

function Get-LWBookSixDECuringOptionLabel {
    param(
        [int]$Option = (Get-LWBookSixDECuringOption),
        [object]$State = $script:GameState
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    switch ([int]$Option) {
        0 {
            if ($null -ne $State -and -not (Test-LWStateHasDiscipline -State $State -Name 'Curing')) {
                return 'Standard Magnakai'
            }
            return 'Standard Curing'
        }
        1 { return 'Curing Cap' }
        2 { return 'Healing Instead' }
        3 { return 'Herb Pouch' }
        default { return 'Not Selected' }
    }
}

function Get-LWBookSixDEWeaponskillOption {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State -or $null -eq $State.Conditions) {
        return -1
    }

    if (-not (Test-LWPropertyExists -Object $State.Conditions -Name 'BookSixDEWeaponskillOption') -or $null -eq $State.Conditions.BookSixDEWeaponskillOption) {
        return -1
    }

    return [int]$State.Conditions.BookSixDEWeaponskillOption
}

function Set-LWBookSixDEWeaponskillOption {
    param(
        [object]$State = $script:GameState,
        [ValidateSet(-1, 0, 1)][int]$Option
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'Conditions') -or $null -eq $State.Conditions) {
        $State | Add-Member -Force -NotePropertyName Conditions -NotePropertyValue (New-LWConditionState)
    }

    if (-not (Test-LWPropertyExists -Object $State.Conditions -Name 'BookSixDEWeaponskillOption')) {
        $State.Conditions | Add-Member -Force -NotePropertyName BookSixDEWeaponskillOption -NotePropertyValue $Option
    }
    else {
        $State.Conditions.BookSixDEWeaponskillOption = $Option
    }
}

function Test-LWBookSixDEWeaponskillEnabled {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    return ($null -ne $State -and
        (Test-LWStateIsMagnakaiRuleset -State $State) -and
        [int]$State.Character.BookNumber -eq 6 -and
        (Get-LWBookSixDEWeaponskillOption -State $State) -eq 1 -and
        -not [string]::IsNullOrWhiteSpace([string]$State.Character.WeaponskillWeapon))
}

function Get-LWBookSixDEWeaponskillOptionLabel {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWBookSixDEWeaponskillEnabled -State $State)) {
        return 'Disabled'
    }

    return ('Weaponskill ({0})' -f [string]$State.Character.WeaponskillWeapon)
}

function Get-LWBookSixDEAdventureRuleSummary {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State -or -not (Test-LWStateIsMagnakaiRuleset -State $State) -or [int]$State.Character.BookNumber -ne 6) {
        return @()
    }

    $rules = @()
    switch (Get-LWBookSixDECuringOption -State $State) {
        1 { $rules += 'Curing Cap' }
        2 { $rules += 'Healing Instead' }
        3 { $rules += 'Herb Pouch' }
    }

    if (Test-LWBookSixDEWeaponskillEnabled -State $State) {
        $rules += (Get-LWBookSixDEWeaponskillOptionLabel -State $State)
    }

    return @($rules)
}


Export-ModuleMember -Function `
    Get-LWMagnakaiBookSixStartingChoices, `
    Grant-LWMagnakaiBookSixStartingChoice, `
    Get-LWMagnakaiBookSixInstantDeathCause, `
    Get-LWMagnakaiBookSixConditionValue, `
    Get-LWMagnakaiBookSixSectionRandomNumberContext, `
    Invoke-LWMagnakaiBookSixSectionRandomNumberResolution, `
    Invoke-LWMagnakaiBookSixSection284BettingRound, `
    Invoke-LWMagnakaiBookSixStorySectionAchievementTriggers, `
    Invoke-LWMagnakaiBookSixStorySectionTransitionAchievementTriggers, `
    Invoke-LWMagnakaiBookSixSectionEntryRules, `
    Apply-LWMagnakaiBookSixStartingEquipment, `
    Get-LWBook6LatestCessSectionEvent, `
    Get-LWBook6RiverboatTicketItemNames, `
    Get-LWBookSixSectionContextAchievementIds, `
    Get-LWBookSixDECuringOption, `
    Set-LWBookSixDECuringOption, `
    Get-LWBookSixDECuringOptionLabel, `
    Get-LWBookSixDEWeaponskillOption, `
    Set-LWBookSixDEWeaponskillOption, `
    Test-LWBookSixDEWeaponskillEnabled, `
    Get-LWBookSixDEWeaponskillOptionLabel, `
    Get-LWBookSixDEAdventureRuleSummary


