Set-StrictMode -Version Latest

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

function Get-LWBookTwoArmoryChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'short_sword'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'two_meals'; DisplayName = 'Two Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = 'Two Meals' },
        [pscustomobject]@{ Id = 'chainmail'; DisplayName = 'Chainmail Waistcoat'; Type = 'special'; Name = 'Chainmail Waistcoat'; Quantity = 1; Description = 'Chainmail Waistcoat' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'healing_potion'; DisplayName = 'Healing Potion'; Type = 'backpack'; Name = 'Healing Potion'; Quantity = 1; Description = 'Healing Potion' },
        [pscustomobject]@{ Id = 'quarterstaff'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'shield'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' },
        [pscustomobject]@{ Id = 'broadsword'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' }
    )
}

function Grant-LWBookTwoArmoryChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon' -and @($script:GameState.Inventory.Weapons).Count -ge 2) {
        Write-LWInfo 'Book 2 allows you to exchange one of your carried weapons for an armory choice.'
        Show-LWInventorySlotsSection -Type 'weapon'
        $slot = Read-LWInt -Prompt ("Replace which weapon with {0}?" -f [string]$Choice.DisplayName) -Min 1 -Max 2
        $weapons = @(Get-LWInventoryItems -Type 'weapon')
        $replacedWeapon = [string]$weapons[$slot - 1]
        $weapons[$slot - 1] = [string]$Choice.Name
        Set-LWInventoryItems -Type 'weapon' -Items @($weapons)
        Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
        Write-LWInfo ("Exchanged {0} for {1}." -f $replacedWeapon, [string]$Choice.DisplayName)
        return $true
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 2 armory choice added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 2 armory choice '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Get-LWKaiBookTwoSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State; if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null } }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 2) {
            return $null
        }

        $section = [int]$State.CurrentSection
        if (@(10, 12, 21, 22, 31, 45, 57, 81, 99, 105, 114, 116, 122, 151, 152, 169, 175, 183, 197, 201, 210, 238, 278, 280, 300, 308, 316, 350) -contains $section) {
            return (New-LWSectionRandomNumberContext -Section $section)
        }

        return $null
}

function Apply-LWKaiBookTwoStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

        if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 2) {
            return
        }

        $startingGoldRoll = Get-LWRandomDigit
        $goldGain = 10 + [int]$startingGoldRoll
        $oldGold = [int]$script:GameState.Inventory.GoldCrowns
        $newGold = [Math]::Min(50, ($oldGold + $goldGain))
        $script:GameState.Inventory.GoldCrowns = $newGold

        Write-LWInfo ("Book 2 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
        if ($newGold -ne ($oldGold + $goldGain)) {
            Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 2 starting gold is lost.'
        }

        foreach ($specialItem in @('Map of Sommerlund', 'Seal of Hammerdal')) {
            $names = if ($specialItem -eq 'Map of Sommerlund') { Get-LWMapOfSommerlundItemNames } else { Get-LWSealOfHammerdalItemNames }
            if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names $names -Type 'special')) {
                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name $specialItem) {
                    Write-LWInfo ("Book 2 starting Special Item added: {0}." -f $specialItem)
                }
                else {
                    Write-LWWarn ("No room to add {0} automatically. Make room and add it manually if needed." -f $specialItem)
                }
            }
        }

        Write-LWInfo $(if ($CarryExistingGear) { 'Choose two Book 2 armory items now. You may exchange one or both carried weapons.' } else { 'Choose two Book 2 armory items now.' })

        $selectedIds = @()
        while ($selectedIds.Count -lt 2) {
            $availableChoices = @(Get-LWBookTwoArmoryChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
            if ($availableChoices.Count -eq 0) {
                break
            }

            Write-LWPanelHeader -Title 'Book 2 Armory' -AccentColor 'DarkYellow'
            Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/2" -f $selectedIds.Count) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
            Write-Host ''
            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
            }
            $manageIndex = $availableChoices.Count + 1
            Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'

            $choiceIndex = Read-LWInt -Prompt ("Armory choice #{0}" -f ($selectedIds.Count + 1)) -Min 1 -Max $manageIndex -NoRefresh
            if ($choiceIndex -eq $manageIndex) {
                Invoke-LWBookFourStartingInventoryManagement
                continue
            }

            $choice = $availableChoices[$choiceIndex - 1]
            $granted = Grant-LWBookTwoArmoryChoice -Choice $choice
            if ($granted) {
                $selectedIds += [string]$choice.Id
            }
            elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
                Invoke-LWBookFourStartingInventoryManagement
            }
        }
}


function Get-LWBookTwoSection262ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book2Section262SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book2Section262MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'quarterstaff'; FlagName = 'Book2Section262QuarterstaffClaimed'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book2Section262MealClaimed'; DisplayName = 'Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = 'Meal' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section262GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'orange_potion'; FlagName = 'Book2Section262OrangePotionClaimed'; DisplayName = 'Potion of Orange Liquid'; Type = 'backpack'; Name = 'Potion of Orange Liquid'; Quantity = 1; Description = 'Potion of Orange Liquid' }
    )
}

function Get-LWBookTwoSection302ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book2Section302MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'broadsword'; FlagName = 'Book2Section302BroadswordClaimed'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' },
        [pscustomobject]@{ Id = 'quarterstaff'; FlagName = 'Book2Section302QuarterstaffClaimed'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'healing_potion'; FlagName = 'Book2Section302HealingPotionClaimed'; DisplayName = 'Healing Potion'; Type = 'backpack'; Name = 'Healing Potion'; Quantity = 1; Description = 'Healing Potion' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book2Section302MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book2Section302BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section302GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' }
    )
}

function Get-LWBookTwoSectionContextAchievementIds {
    return @(
        'found_the_sommerswerd',
        'by_a_thread',
        'skyfall',
        'fight_through_the_smoke',
        'storm_tossed',
        'seal_of_approval',
        'papers_please'
    )
}


Export-ModuleMember -Function `
    Get-LWKaiBookTwoSectionRandomNumberContext, `
    Apply-LWKaiBookTwoStartingEquipment, `
    Get-LWBookTwoSection262ChoiceDefinitions, `
    Get-LWBookTwoSection302ChoiceDefinitions, `
    Get-LWBookTwoSectionContextAchievementIds



