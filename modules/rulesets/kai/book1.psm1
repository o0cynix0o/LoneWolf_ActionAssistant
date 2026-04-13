Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWBookOneStartingExtraItemDefinition {
    param([Parameter(Mandatory = $true)][ValidateRange(0, 9)][int]$Roll)

    switch ($Roll) {
        1 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Sword'; Quantity = 1; Gold = 0; Description = 'Sword' } }
        2 { return [pscustomobject]@{ Type = 'special'; Name = 'Helmet'; Quantity = 1; Gold = 0; Description = 'Helmet' } }
        3 { return [pscustomobject]@{ Type = 'backpack'; Name = 'Meal'; Quantity = 2; Gold = 0; Description = 'Two Meals' } }
        4 { return [pscustomobject]@{ Type = 'special'; Name = 'Chainmail Waistcoat'; Quantity = 1; Gold = 0; Description = 'Chainmail Waistcoat' } }
        5 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Mace'; Quantity = 1; Gold = 0; Description = 'Mace' } }
        6 { return [pscustomobject]@{ Type = 'backpack'; Name = 'Healing Potion'; Quantity = 1; Gold = 0; Description = 'Healing Potion' } }
        7 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Gold = 0; Description = 'Quarterstaff' } }
        8 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Spear'; Quantity = 1; Gold = 0; Description = 'Spear' } }
        9 { return [pscustomobject]@{ Type = 'gold'; Name = ''; Quantity = 0; Gold = 12; Description = '12 Gold Crowns' } }
        default { return [pscustomobject]@{ Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Gold = 0; Description = 'Broadsword' } }
    }
}

function Get-LWKaiBookOneSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State; if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null } }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 1) {
            return $null
        }

        $section = [int]$State.CurrentSection
        switch ($section) {
            337 {
                $modifier = 0
                $notes = @()
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 1
                    $notes += 'Hunting'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') {
                    $modifier += 2
                    $notes += 'Sixth Sense'
                }
                return (New-LWSectionRandomNumberContext -Section $section -Description 'Book 1 route-finding check.' -Modifier $modifier -ModifierNotes $notes)
            }
            default {
                if (@(2, 7, 17, 21, 22, 36, 44, 49, 89, 158, 160, 188, 205, 226, 237, 275, 279, 294, 302, 314, 350) -contains $section) {
                    return (New-LWSectionRandomNumberContext -Section $section)
                }
            }
        }

        return $null
}

function Apply-LWKaiBookOneStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 1) {
            return
        }

        $startingGoldRoll = Get-LWRandomDigit
        $extraItemRoll = Get-LWRandomDigit
        $extraItem = Get-LWBookOneStartingExtraItemDefinition -Roll $extraItemRoll

        $weapons = @('Axe')
        $backpackItems = @('Meal')
        $specialItems = @('Map of Sommerlund')
        $goldCrowns = [int]$startingGoldRoll

        switch ([string]$extraItem.Type) {
            'weapon' {
                for ($i = 0; $i -lt [int]$extraItem.Quantity; $i++) {
                    $weapons += [string]$extraItem.Name
                }
            }
            'backpack' {
                for ($i = 0; $i -lt [int]$extraItem.Quantity; $i++) {
                    $backpackItems += [string]$extraItem.Name
                }
            }
            'special' {
                for ($i = 0; $i -lt [int]$extraItem.Quantity; $i++) {
                    $specialItems += [string]$extraItem.Name
                }
            }
            'gold' {
                $goldCrowns += [int]$extraItem.Gold
            }
        }

        $script:GameState.Inventory.Weapons = @($weapons)
        $script:GameState.Inventory.BackpackItems = @($backpackItems)
        $script:GameState.Inventory.SpecialItems = @($specialItems)
        $script:GameState.Inventory.GoldCrowns = [Math]::Min(50, [Math]::Max(0, $goldCrowns))

        Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages

        Write-LWInfo ("Book 1 starting gold roll: {0} Gold Crowns." -f $startingGoldRoll)
        Write-LWInfo ("Book 1 monastery find roll: {0} -> {1}." -f $extraItemRoll, [string]$extraItem.Description)
}


function Get-LWBookOneSection124ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section124GoldClaimed'; DisplayName = '15 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 15; Description = '15 Gold Crowns' },
        [pscustomobject]@{ Id = 'silver_key'; FlagName = 'Book1Section124SilverKeyClaimed'; DisplayName = 'Silver Key'; Type = 'special'; Name = 'Silver Key'; Quantity = 1; Description = 'Silver Key' }
    )
}

function Get-LWBookOneSection255ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'solnaris'; FlagName = 'Book1Section255SolnarisClaimed'; DisplayName = 'Solnaris'; Type = 'weapon'; Name = 'Solnaris'; Quantity = 1; Description = 'Solnaris' }
    )
}

function Get-LWBookOneSection267ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'message'; FlagName = 'Book1Section267MessageClaimed'; DisplayName = 'Prince Pelathar''s Message'; Type = 'special'; Name = 'Prince Pelathar''s Message'; Quantity = 1; Description = 'Prince Pelathar''s Message' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book1Section267DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' }
    )
}

function Get-LWBookOneSection315ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section315GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'soap'; FlagName = 'Book1Section315SoapClaimed'; DisplayName = 'Tablet of Perfumed Soap'; Type = 'backpack'; Name = 'Tablet of Perfumed Soap'; Quantity = 1; Description = 'Tablet of Perfumed Soap' }
    )
}

function Get-LWBookOneSection347ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'torch'; FlagName = 'Book1Section347TorchClaimed'; DisplayName = 'Torch'; Type = 'backpack'; Name = 'Torch'; Quantity = 1; Description = 'Torch' },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book1Section347ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'tinderbox'; FlagName = 'Book1Section347TinderboxClaimed'; DisplayName = 'Tinderbox'; Type = 'backpack'; Name = 'Tinderbox'; Quantity = 1; Description = 'Tinderbox' }
    )
}

function Get-LWBookOneSectionContextAchievementIds {
    return @(
        'aim_for_the_bushes',
        'found_the_clubhouse',
        'whats_in_the_box_book1',
        'use_the_force',
        'straight_to_the_throne',
        'royal_recovery',
        'the_back_way_in',
        'open_sesame',
        'hot_hands',
        'star_of_toran',
        'field_medic'
    )
}


Export-ModuleMember -Function `
    Get-LWKaiBookOneSectionRandomNumberContext, `
    Apply-LWKaiBookOneStartingEquipment, `
    Get-LWBookOneSection124ChoiceDefinitions, `
    Get-LWBookOneSection255ChoiceDefinitions, `
    Get-LWBookOneSection267ChoiceDefinitions, `
    Get-LWBookOneSection315ChoiceDefinitions, `
    Get-LWBookOneSection347ChoiceDefinitions, `
    Get-LWBookOneSectionContextAchievementIds



