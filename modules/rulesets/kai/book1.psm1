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
            21 {
                return (New-LWSectionRandomNumberContext -Section $section -Description 'Bog crossing sequence: first roll checks the marsh, second checks the first escape attempt, and the third is only used if you sink too deep.' -RollCount 3 -SequenceMode 'independent')
            }
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
                if (@(2, 7, 17, 22, 36, 44, 49, 89, 158, 160, 188, 205, 226, 237, 275, 279, 294, 302, 314, 337, 350) -contains $section) {
                    return (New-LWSectionRandomNumberContext -Section $section)
                }
            }
        }

        return $null
}

function Get-LWBookOneSimpleSectionEffectDefinitions {
    return @{
        119 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section119EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 119: apply the section ENDURANCE loss.'; FatalCause = 'Section 119 reduced your Endurance to zero.' })
        147 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book1Section147MealHandled'; NoMealFlagName = 'Book1Section147NoMealLossApplied'; SectionLabel = 'Section 147'; Loss = 3; NoMealMessagePrefix = 'Section 147: the section meal requirement is not met.'; FatalCause = 'Hunger at section 147 reduced your Endurance to zero.' })
        158 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section158FirstBoltApplied'; Delta = -6; MessagePrefix = 'Section 158: the first lightning bolt strikes you in the chest.'; FatalCause = 'The first lightning bolt at section 158 reduced your Endurance to zero.' })
        166 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section166EnduranceHandled'; Delta = -4; MessagePrefix = 'Section 166: apply the section ENDURANCE loss.'; FatalCause = 'Section 166 reduced your Endurance to zero.' })
        203 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section203EnduranceHandled'; Delta = -10; MessagePrefix = 'Section 203: apply the section ENDURANCE loss.'; FatalCause = 'Section 203 reduced your Endurance to zero.' })
        276 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section276EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 276: apply the section ENDURANCE loss.'; FatalCause = 'Section 276 reduced your Endurance to zero.' })
        308 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section308EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 308: apply the section ENDURANCE loss.'; FatalCause = 'Section 308 reduced your Endurance to zero.' })
        313 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section313EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 313: apply the section ENDURANCE loss.'; FatalCause = 'Section 313 reduced your Endurance to zero.' })
        320 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section320EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 320: apply the section ENDURANCE loss.'; FatalCause = 'Section 320 reduced your Endurance to zero.' })
        343 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book1Section343EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 343: apply the section ENDURANCE loss.'; FatalCause = 'Section 343 reduced your Endurance to zero.' })
    }
}

function Get-LWBookOneSimpleCombatRuleDefinitions {
    return @{
        17  = [pscustomobject]@{ PlayerMod = -1; Info = 'Book 1 section 17: the unstable footing applies -1 Combat Skill.' }
        136 = [pscustomobject]@{ PlayerMod = 1; OneAtATime = $true; Info = 'Book 1 section 136: the higher ground grants +1 Combat Skill and the Giaks attack one at a time.' }
        169 = [pscustomobject]@{ CanEvade = $true; EvadeAvailableAfterRound = 1; Info = 'Book 1 section 169: you may evade after the first round.' }
        229 = [pscustomobject]@{ PlayerMod = -1; Info = 'Book 1 section 229: the choking dust applies -1 Combat Skill.' }
        260 = [pscustomobject]@{ PlayerMod = -4; OneAtATime = $true; Info = 'Book 1 section 260: fighting bare-handed applies -4 Combat Skill and the Giaks attack one at a time.' }
    }
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

function Get-LWBookOneSection020ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book1Section020BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book1Section020MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book1Section020DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' }
    )
}

function Get-LWBookOneSection062ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section062GoldClaimed'; DisplayName = '28 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 28; Description = '28 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book1Section062MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book1Section062SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookOneSection164ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book1Section164AletherClaimed'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Alether'; Quantity = 1; Description = 'Potion of Alether' }
    )
}

function Get-LWBookOneSection184ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section184GoldClaimed'; DisplayName = '40 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 40; Description = '40 Gold Crowns' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book1Section184SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book1Section184MealsClaimed'; DisplayName = '4 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 4; Description = '4 Meals' }
    )
}

function Get-LWBookOneSection193ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'scroll'; FlagName = 'Book1Section193ScrollClaimed'; DisplayName = 'Scroll'; Type = 'special'; Name = 'Scroll'; Quantity = 1; Description = 'Scroll' }
    )
}

function Get-LWBookOneSection197ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book1Section197ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section197GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' }
    )
}

function Get-LWBookOneSection291ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section291GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book1Section291DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger'; ExclusiveGroup = 'weapon' },
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book1Section291SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear'; ExclusiveGroup = 'weapon' }
    )
}

function Get-LWBookOneSection319ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book1Section319DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section319GoldClaimed'; DisplayName = '20 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 20; Description = '20 Gold Crowns' }
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
    Get-LWBookOneSimpleSectionEffectDefinitions, `
    Get-LWBookOneSimpleCombatRuleDefinitions, `
    Apply-LWKaiBookOneStartingEquipment, `
    Get-LWBookOneSection020ChoiceDefinitions, `
    Get-LWBookOneSection062ChoiceDefinitions, `
    Get-LWBookOneSection124ChoiceDefinitions, `
    Get-LWBookOneSection164ChoiceDefinitions, `
    Get-LWBookOneSection184ChoiceDefinitions, `
    Get-LWBookOneSection193ChoiceDefinitions, `
    Get-LWBookOneSection197ChoiceDefinitions, `
    Get-LWBookOneSection291ChoiceDefinitions, `
    Get-LWBookOneSection255ChoiceDefinitions, `
    Get-LWBookOneSection267ChoiceDefinitions, `
    Get-LWBookOneSection315ChoiceDefinitions, `
    Get-LWBookOneSection319ChoiceDefinitions, `
    Get-LWBookOneSection347ChoiceDefinitions, `
    Get-LWBookOneSectionContextAchievementIds



