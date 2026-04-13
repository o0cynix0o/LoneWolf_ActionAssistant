Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWKaiBookFourSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 4) {
            return $null
        }

        $section = [int]$State.CurrentSection
        $disciplineCount = @($State.Character.Disciplines).Count
        $modifier = 0
        $modifierNotes = @()
        $description = $null
        $zeroCountsAsTen = $false
        $bypassed = $false
        $bypassReason = $null

        switch ($section) {
            11 { $description = 'Plain random-number check.' }
            13 { $description = 'Plain random-number check.' }
            31 { $description = 'Plain random-number check.' }
            35 {
                $description = 'Bridge-guard dash check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or $disciplineCount -ge 7) {
                    $modifier += 3
                    $modifierNotes += 'Hunting or Kai rank Guardian+'
                }
            }
            43 {
                $description = 'Speed-and-accuracy check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') -or (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill')) {
                    $modifier += 1
                    $modifierNotes += 'Mind Over Matter or Weaponskill'
                }
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                    $modifier += 2
                    $modifierNotes += 'Hunting or Sixth Sense'
                }
            }
            50 { $description = 'Plain random-number check.' }
            59 { $description = 'Plain random-number check.' }
            63 { $description = 'Plain random-number check.' }
            67 {
                if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special') {
                    $bypassed = $true
                    $bypassReason = 'The Sommerswerd bypasses this random-number check here.'
                }
                else {
                    $description = 'Disc-ambush escape check.'
                    if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter')) {
                        $modifier += 2
                        $modifierNotes += 'Hunting or Mind Over Matter'
                    }
                }
            }
            75 {
                $description = 'Escape-from-the-melee check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                    $modifier += 3
                    $modifierNotes += 'Camouflage'
                }
            }
            96 { $description = 'Plain random-number check.' }
            112 {
                $description = 'Bridge impact survival check.'
                if ([int]$State.Character.EnduranceCurrent -lt 10) {
                    $modifier -= 3
                    $modifierNotes += 'Current END below 10'
                }
                elseif ([int]$State.Character.EnduranceCurrent -gt 20) {
                    $modifier += 3
                    $modifierNotes += 'Current END above 20'
                }
            }
            117 {
                if (Test-LWStateCanRelightTorch -State $State) {
                    $bypassed = $true
                    $bypassReason = 'A spare Torch and Tinderbox let you avoid this darkness roll.'
                }
                elseif (Test-LWStateHasFiresphere -State $State) {
                    $bypassed = $true
                    $bypassReason = 'A Kalte Firesphere lets you avoid this darkness roll.'
                }
                else {
                    $description = 'Dark-bridge balance check.'
                    if ((Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') -or (Test-LWStateHasDiscipline -State $State -Name 'Tracking')) {
                        $modifier += 3
                        $modifierNotes += 'Sixth Sense or Tracking'
                    }
                }
            }
            126 { $description = 'Plain random-number check.' }
            128 {
                $description = 'Trapdoor escape check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 3
                    $modifierNotes += 'Hunting'
                }
            }
            154 { $description = 'Plain random-number check.' }
            173 {
                if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special') {
                    $bypassed = $true
                    $bypassReason = 'The Sommerswerd bypasses this pillar-smash roll.'
                }
                else {
                    $description = 'Pillar-smash check.'
                    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWMiningToolItemNames) -Type 'backpack') {
                        $modifier += 2
                        $modifierNotes += 'Pick or Shovel'
                    }
                }
            }
            183 {
                $description = 'Crypt password bluff check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                    $modifier += 4
                    $modifierNotes += 'Camouflage'
                }
            }
            189 { $description = 'Plain random-number check.' }
            194 {
                $description = 'Underwater combat oxygen-threshold roll.'
                $zeroCountsAsTen = $true
                if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                    $modifier += 2
                    $modifierNotes += 'Mind Over Matter'
                }
            }
            207 {
                $description = 'Shot-saving check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                    $modifier += 2
                    $modifierNotes += 'Weaponskill'
                }
            }
            211 { $description = 'Plain random-number check.' }
            225 { $description = 'Plain random-number check.' }
            234 {
                $description = 'Underwater combat oxygen-threshold roll.'
                $zeroCountsAsTen = $true
                if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                    $modifier += 2
                    $modifierNotes += 'Mind Over Matter'
                }
            }
            240 { $description = 'Plain random-number check.' }
            247 { $description = 'Plain random-number check.' }
            249 {
                $description = 'Bow-shot leadership check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                    $modifier += 2
                    $modifierNotes += 'Weaponskill'
                }
            }
            271 {
                $description = 'Collapsing-bridge check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            309 {
                $description = 'Mine-ramp dash check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                    $modifier += 4
                    $modifierNotes += 'Camouflage'
                }
            }
            319 { $description = 'Plain random-number check.' }
            343 {
                $description = 'Boat-capsize avoidance check.'
                if ([int]$State.Character.EnduranceCurrent -ge 20) {
                    $modifier += 3
                    $modifierNotes += 'Current END 20 or higher'
                }
                elseif ([int]$State.Character.EnduranceCurrent -le 12) {
                    $modifier -= 2
                    $modifierNotes += 'Current END 12 or lower'
                }
            }
            345 { $description = 'Plain random-number check.' }
            default { return $null }
        }

        return [pscustomobject]@{
            Section         = $section
            Description     = $description
            Modifier        = $modifier
            ModifierNotes   = @($modifierNotes)
            ZeroCountsAsTen = $zeroCountsAsTen
            Bypassed        = $bypassed
            BypassReason    = $bypassReason
        }
}

function Apply-LWKaiBookFourStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

        if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 4) {
            return
        }

        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfSouthlandsItemNames) -Type 'special')) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of the Southlands') {
                Write-LWInfo 'Book 4 starting Special Item added: Map of the Southlands.'
            }
            else {
                Write-LWWarn 'No room to add Map of the Southlands automatically. Make room and add it manually if needed.'
            }
        }

        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBadgeOfRankItemNames) -Type 'special')) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Badge of Rank') {
                Write-LWInfo 'Book 4 starting Special Item added: Badge of Rank.'
            }
            else {
                Write-LWWarn 'No room to add Badge of Rank automatically. Make room and add it manually if needed.'
            }
        }

        Restore-LWBackpackState

        $startingGoldRoll = Get-LWRandomDigit
        $goldGain = 10 + [int]$startingGoldRoll
        $oldGold = [int]$script:GameState.Inventory.GoldCrowns
        $newGold = [Math]::Min(50, ($oldGold + $goldGain))
        $script:GameState.Inventory.GoldCrowns = $newGold

        Write-LWInfo ("Book 4 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
        if ($newGold -ne ($oldGold + $goldGain)) {
            Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 4 starting gold is lost.'
        }

        Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to six Book 4 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to six Book 4 starting items now.' })

        $selectedIds = @()
        while ($selectedIds.Count -lt 6) {
            $availableChoices = @(Get-LWBookFourStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
            if ($availableChoices.Count -eq 0) {
                break
            }

            Write-LWPanelHeader -Title 'Book 4 Starting Gear' -AccentColor 'DarkYellow'
            Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/6" -f $selectedIds.Count) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
            Write-Host ''
            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
            }
            $manageIndex = $availableChoices.Count + 1
            Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
            Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

            $choiceIndex = Read-LWInt -Prompt ("Book 4 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
            if ($choiceIndex -eq 0) {
                break
            }
            if ($choiceIndex -eq $manageIndex) {
                Invoke-LWBookFourStartingInventoryManagement
                continue
            }

            $choice = $availableChoices[$choiceIndex - 1]
            $granted = Grant-LWBookFourStartingChoice -Choice $choice
            if ($granted) {
                $selectedIds += [string]$choice.Id
            }
            elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
                Invoke-LWBookFourStartingInventoryManagement
            }
        }
}

function Get-LWBookFourStartingChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'warhammer'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'dagger'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'two_potions'; DisplayName = '2 Potions of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 2; Description = '2 Potions of Laumspur' },
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'special_rations'; DisplayName = '5 Special Rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 5; Description = '5 Special Rations' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'chainmail'; DisplayName = 'Chainmail Waistcoat'; Type = 'special'; Name = 'Chainmail Waistcoat'; Quantity = 1; Description = 'Chainmail Waistcoat' },
        [pscustomobject]@{ Id = 'shield'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' }
    )
}

function Grant-LWBookFourStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 4 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 4 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Get-LWBookFourSection12ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section12MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book4Section12RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' },
        [pscustomobject]@{ Id = 'potion'; FlagName = 'Book4Section12PotionClaimed'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section12SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book4Section12SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' }
    )
}

function Grant-LWBookFourSection12Choice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Choice) {
        return $false
    }

    $granted = $false
    if ([string]$Choice.Type -eq 'weapon') {
        $granted = Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName)
    }
    else {
        $granted = TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)
    }

    if (-not $granted) {
        Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Make room and try again if you are keeping it.'
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    Write-LWInfo ("Section 12: added {0}." -f [string]$Choice.Description)
    return $true
}

function Get-LWBookFourSection213ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'pickaxe'; FlagName = 'Book4Section213PickaxeClaimed'; DisplayName = 'Pickaxe'; Type = 'backpack'; Name = 'Pickaxe'; Quantity = 1; Description = 'Pickaxe' },
        [pscustomobject]@{ Id = 'shovel'; FlagName = 'Book4Section213ShovelClaimed'; DisplayName = 'Shovel'; Type = 'backpack'; Name = 'Shovel'; Quantity = 1; Description = 'Shovel' },
        [pscustomobject]@{ Id = 'axe'; FlagName = 'Book4Section213AxeClaimed'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'torch'; FlagName = 'Book4Section213TorchClaimed'; DisplayName = 'Torch'; Type = 'backpack'; Name = 'Torch'; Quantity = 1; Description = 'Torch' },
        [pscustomobject]@{ Id = 'tinderbox'; FlagName = 'Book4Section213TinderboxClaimed'; DisplayName = 'Tinderbox'; Type = 'backpack'; Name = 'Tinderbox'; Quantity = 1; Description = 'Tinderbox' },
        [pscustomobject]@{ Id = 'hourglass'; FlagName = 'Book4Section213HourglassClaimed'; DisplayName = 'Hourglass'; Type = 'backpack'; Name = 'Hourglass'; Quantity = 1; Description = 'Hourglass' }
    )
}

function Get-LWBookFourSection280ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section280GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book4Section280MealClaimed'; DisplayName = 'Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = 'Meal' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section280SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFourSection002ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section002SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book4Section002MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book4Section002DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'warhammer'; FlagName = 'Book4Section002WarhammerClaimed'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section002GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' },
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book4Section002BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section002MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWBookFourSection044ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section044GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section044MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWBookFourSection109ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section109GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book4Section109DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section109SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFourSection152ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section152SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section152GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section152MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' },
        [pscustomobject]@{ Id = 'brass_key'; FlagName = 'Book4Section152BrassKeyClaimed'; DisplayName = 'Brass Key'; Type = 'special'; Name = 'Brass Key'; Quantity = 1; Description = 'Brass Key' }
    )
}

function Get-LWBookFourSection230ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section230SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book4Section230DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section230GoldClaimed'; DisplayName = '9 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 9; Description = '9 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section230MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWBookFourSection231ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section231GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section231SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book4Section231MealClaimed'; DisplayName = 'Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = 'Meal' }
    )
}

function Get-LWBookFourSection302ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book4Section302LaumspurClaimed'; DisplayName = '2 Potions of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 2; Description = '2 Potions of Laumspur' },
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book4Section302AletherClaimed'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Alether'; Quantity = 1; Description = 'Potion of Alether' },
        [pscustomobject]@{ Id = 'holy_water'; FlagName = 'Book4Section302HolyWaterClaimed'; DisplayName = 'Flask of Holy Water'; Type = 'backpack'; Name = 'Flask of Holy Water'; Quantity = 1; Description = 'Flask of Holy Water' }
    )
}

function Grant-LWBookFourSection213Choice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Choice) {
        return $false
    }

    $granted = $false
    if ([string]$Choice.Type -eq 'weapon') {
        $granted = Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName)
    }
    else {
        $granted = TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)
    }

    if (-not $granted) {
        Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Make room and try again if you are keeping it.'
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    Write-LWInfo ("Section 213: added {0}." -f [string]$Choice.Description)
    return $true
}

function Grant-LWBookFourSection280Choice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Choice) {
        return $false
    }

    $granted = $false
    switch ([string]$Choice.Type) {
        'weapon' {
            $granted = Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName)
        }
        'gold' {
            $oldGold = [int]$script:GameState.Inventory.GoldCrowns
            $newGold = [Math]::Min(50, ($oldGold + [int]$Choice.Quantity))
            $addedGold = $newGold - $oldGold
            if ($addedGold -le 0) {
                Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Spend some Gold Crowns first if you want to keep it.'
                return $false
            }

            $script:GameState.Inventory.GoldCrowns = $newGold
            Add-LWBookGoldDelta -Delta $addedGold
            [void](Sync-LWAchievements -Context 'gold')
            if ($newGold -lt ($oldGold + [int]$Choice.Quantity)) {
                Write-LWWarn 'Gold Crowns are capped at 50. Excess gold from section 280 is lost.'
            }
            $granted = $true
        }
        default {
            $granted = TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)
        }
    }

    if (-not $granted) {
        Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Make room and try again if you are keeping it.'
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    Write-LWInfo ("Section 280: added {0}." -f [string]$Choice.Description)
    return $true
}

function Invoke-LWBookFourBackpackLoss {
    param([Parameter(Mandatory = $true)][string]$Reason)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    Set-LWStoryAchievementFlag -Name 'Book4BackpackLost'
    Lose-LWBackpack -WriteMessages -Reason $Reason
}

function Invoke-LWBookFourForcedPackOrWeaponLoss {
    param([string]$Reason = 'You lose an item while fumbling in the dark.')

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $backpackItems = @(Get-LWInventoryItems -Type 'backpack')
    if ($backpackItems.Count -gt 0) {
        Show-LWInventorySlotsSection -Type 'backpack'
        $slotMap = @(Get-LWBackpackSlotMap -Items $backpackItems | Where-Object { [bool]$_.IsPrimary })
        $validSlots = @($slotMap | ForEach-Object { [int]$_.Slot })
        $slot = if ($validSlots.Count -eq 1) { $validSlots[0] } else { $null }
        while ($null -eq $slot) {
            $candidate = Read-LWInt -Prompt ("Backpack slot to lose ({0})" -f (($validSlots -join ', '))) -Min ($validSlots | Measure-Object -Minimum).Minimum -Max ($validSlots | Measure-Object -Maximum).Maximum
            if ($validSlots -contains [int]$candidate) {
                $slot = [int]$candidate
            }
            else {
                Write-LWWarn ("Choose one of the occupied Backpack slots: {0}." -f ($validSlots -join ', '))
            }
        }

        $slotEntry = @($slotMap | Where-Object { [int]$_.Slot -eq $slot } | Select-Object -First 1)
        if ($slotEntry.Count -eq 0) {
            $slotEntry = @($slotMap | Select-Object -First 1)
        }
        $itemName = [string]$slotEntry[0].ItemName
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $itemName -Quantity 1)
        Write-LWInfo ("{0} Lost: {1}." -f $Reason, $itemName)
        return
    }

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($weapons.Count -gt 0) {
        Show-LWInventorySlotsSection -Type 'weapon'
        $slot = if ($weapons.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Weapon slot to lose' -Min 1 -Max $weapons.Count }
        $itemName = [string]$weapons[$slot - 1]
        [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $itemName -Quantity 1)
        Write-LWInfo ("{0} Lost weapon: {1}." -f $Reason, $itemName)
        return
    }

    Write-LWWarn $Reason
}

function Invoke-LWBookFourLoseOneWeapon {
    param([string]$Reason = 'You lose one Weapon.')

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($weapons.Count -eq 0) {
        Write-LWWarn $Reason
        return
    }

    Show-LWInventorySlotsSection -Type 'weapon'
    $slot = if ($weapons.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Weapon slot to lose' -Min 1 -Max $weapons.Count }
    $itemName = [string]$weapons[$slot - 1]
    [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $itemName -Quantity 1)
    Write-LWInfo ("{0} Lost weapon: {1}." -f $Reason, $itemName)
}

function Invoke-LWBookFourTorchSupplies {
    param(
        [Parameter(Mandatory = $true)][int]$ExtraTorchCount,
        [Parameter(Mandatory = $true)][int]$Section
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $supplyFlag = if ($Section -eq 79) { 'Book4Section79SuppliesClaimed' } else { 'Book4Section123SuppliesClaimed' }
    if (Test-LWStoryAchievementFlag -Name $supplyFlag) {
        return
    }

    Set-LWStoryAchievementFlag -Name $supplyFlag
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState
    $hasRelightSource = (Test-LWStateHasTinderbox -State $script:GameState) -or (Test-LWStateHasFiresphere -State $script:GameState)

    if (-not $hasRelightSource -and $hasBackpack) {
        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Tinderbox') {
            Write-LWInfo ("Section {0}: Tinderbox added from the mine stores." -f $Section)
        }
    }

    if (-not $hasBackpack) {
        Write-LWWarn ("Section {0}: you can use the lit Torch here, but without a Backpack you cannot keep the spare Torches or Tinderbox." -f $Section)
        return
    }

    $freeSlots = 8 - (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))
    $maxTake = [Math]::Min($ExtraTorchCount, [Math]::Max(0, $freeSlots))
    if ($maxTake -le 0) {
        Write-LWWarn ("Section {0}: no Backpack space remains for the spare Torches." -f $Section)
        return
    }

    $takeTorches = Read-LWInt -Prompt ("How many spare Torches keep from section {0}? (0-{1})" -f $Section, $maxTake) -Default $maxTake -Min 0 -Max $maxTake
    if ($takeTorches -gt 0) {
        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Torch' -Quantity $takeTorches)
        Write-LWInfo ("Section {0}: added {1} spare Torch{2}. The currently lit Torch is not recorded." -f $Section, $takeTorches, $(if ($takeTorches -eq 1) { '' } else { 'es' }))
    }
}

function Invoke-LWBookFourSectionEnduranceDelta {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][int]$Delta,
        [Parameter(Mandatory = $true)][string]$MessagePrefix,
        [string]$FatalCause = ''
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return $false
    }

    Set-LWStoryAchievementFlag -Name $FlagName
    if ($Delta -eq 0) {
        Write-LWInfo $MessagePrefix
        return $true
    }

    if ($Delta -lt 0) {
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss ([Math]::Abs([int]$Delta)) -Source 'sectiondamage'
        $appliedLoss = [int]$lossResolution.AppliedLoss
        if ($appliedLoss -gt 0) {
            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
        }

        $message = $MessagePrefix
        if ($appliedLoss -gt 0) {
            $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
        }
        else {
            $message += ' No ENDURANCE is lost.'
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
            $message += " $($lossResolution.Note)"
        }
        Write-LWInfo $message

        if (-not [string]::IsNullOrWhiteSpace($FatalCause)) {
            [void](Invoke-LWFatalEnduranceCheck -Cause $FatalCause)
        }

        return $true
    }

    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + [int]$Delta))
    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
    if ($restored -gt 0) {
        Add-LWBookEnduranceDelta -Delta $restored
        Register-LWManualRecoveryShortcut
    }

    $message = $MessagePrefix
    if ($restored -gt 0) {
        $message += " Restore $restored ENDURANCE point$(if ($restored -eq 1) { '' } else { 's' })."
    }
    else {
        $message += ' No ENDURANCE is restored because you are already at maximum.'
    }
    Write-LWInfo $message
    return $true
}

function Get-LWBookFourSectionContextAchievementIds {
    return @(
        'sun_below_the_earth',
        'blessed_be_the_throw',
        'steel_against_shadow',
        'badge_of_office',
        'wearing_the_enemys_colors',
        'read_the_signs',
        'return_to_sender',
        'deep_pockets_poor_timing',
        'bagless_but_breathing',
        'shovel_ready',
        'light_in_the_depths',
        'chasm_of_doom',
        'washed_away'
    )
}


Export-ModuleMember -Function `
    Get-LWKaiBookFourSectionRandomNumberContext, `
    Apply-LWKaiBookFourStartingEquipment, `
    Get-LWBookFourStartingChoiceDefinitions, `
    Grant-LWBookFourStartingChoice, `
    Get-LWBookFourSection12ChoiceDefinitions, `
    Grant-LWBookFourSection12Choice, `
    Get-LWBookFourSection213ChoiceDefinitions, `
    Get-LWBookFourSection280ChoiceDefinitions, `
    Get-LWBookFourSection002ChoiceDefinitions, `
    Get-LWBookFourSection044ChoiceDefinitions, `
    Get-LWBookFourSection109ChoiceDefinitions, `
    Get-LWBookFourSection152ChoiceDefinitions, `
    Get-LWBookFourSection230ChoiceDefinitions, `
    Get-LWBookFourSection231ChoiceDefinitions, `
    Get-LWBookFourSection302ChoiceDefinitions, `
    Grant-LWBookFourSection213Choice, `
    Grant-LWBookFourSection280Choice, `
    Invoke-LWBookFourBackpackLoss, `
    Invoke-LWBookFourForcedPackOrWeaponLoss, `
    Invoke-LWBookFourLoseOneWeapon, `
    Invoke-LWBookFourTorchSupplies, `
    Invoke-LWBookFourSectionEnduranceDelta, `
    Get-LWBookFourSectionContextAchievementIds
