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

function Get-LWBookTwoSimpleSectionEffectDefinitions {
    return @{
        11  = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book2Section011DeathApplied'; Cause = 'Section 11: instant death.' })
        17  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section017EnduranceHandled'; Delta = -5; MessagePrefix = 'Section 17: apply the section ENDURANCE loss.'; FatalCause = 'Section 17 reduced your Endurance to zero.' })
        27  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section027EnduranceHandled'; Delta = 2; MessagePrefix = 'Section 27: apply the section ENDURANCE recovery.' })
        29  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section029EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 29: apply the section ENDURANCE loss.'; FatalCause = 'Section 29 reduced your Endurance to zero.' })
        32  = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section032MealHandled'; NoMealFlagName = 'Book2Section032NoMealLossApplied'; SectionLabel = 'Section 32'; Loss = 3; NoMealMessagePrefix = 'Section 32: the section meal requirement is not met.'; FatalCause = 'Hunger at section 32 reduced your Endurance to zero.' })
        37  = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section037MealHandled'; NoMealFlagName = 'Book2Section037NoMealLossApplied'; SectionLabel = 'Section 37'; Loss = 3; NoMealMessagePrefix = 'Section 37: the section meal requirement is not met.'; FatalCause = 'Hunger at section 37 reduced your Endurance to zero.' })
        41  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section041EnduranceHandled'; Delta = 1; MessagePrefix = 'Section 41: apply the section ENDURANCE recovery.' })
        44  = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book2Section044DeathApplied'; Cause = 'Section 44: instant death.' })
        54  = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book2Section054DeathApplied'; Cause = 'Section 54: instant death.' })
        72  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section072EnduranceHandled'; Delta = 1; MessagePrefix = 'Section 72: apply the section ENDURANCE recovery.' })
        78  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section078EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 78: apply the section ENDURANCE loss.'; FatalCause = 'Section 78 reduced your Endurance to zero.' })
        108 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section108EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 108: apply the section ENDURANCE loss.'; FatalCause = 'Section 108 reduced your Endurance to zero.' })
        127 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section127MealHandled'; NoMealFlagName = 'Book2Section127NoMealLossApplied'; SectionLabel = 'Section 127'; Loss = 3; NoMealMessagePrefix = 'Section 127: the section meal requirement is not met.'; FatalCause = 'Hunger at section 127 reduced your Endurance to zero.' })
        141 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section141EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 141: apply the section ENDURANCE loss.'; FatalCause = 'Section 141 reduced your Endurance to zero.' })
        148 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section148MealHandled'; NoMealFlagName = 'Book2Section148NoMealLossApplied'; SectionLabel = 'Section 148'; Loss = 3; NoMealMessagePrefix = 'Section 148: the section meal requirement is not met.'; FatalCause = 'Hunger at section 148 reduced your Endurance to zero.' })
        150 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section150MealHandled'; NoMealFlagName = 'Book2Section150NoMealLossApplied'; SectionLabel = 'Section 150'; Loss = 3; NoMealMessagePrefix = 'Section 150: the section meal requirement is not met.'; FatalCause = 'Hunger at section 150 reduced your Endurance to zero.' })
        154 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section154EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 154: apply the section ENDURANCE loss.'; FatalCause = 'Section 154 reduced your Endurance to zero.' })
        189 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section189EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 189: apply the section ENDURANCE loss.'; FatalCause = 'Section 189 reduced your Endurance to zero.' })
        190 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book2Section190DeathApplied'; Cause = 'Section 190: instant death.' })
        198 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section198EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 198: apply the section ENDURANCE loss.'; FatalCause = 'Section 198 reduced your Endurance to zero.' })
        219 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section219EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 219: apply the section ENDURANCE loss.'; FatalCause = 'Section 219 reduced your Endurance to zero.' })
        234 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book2Section234DeathApplied'; Cause = 'Section 234: instant death.' })
        258 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section258EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 258: apply the section ENDURANCE loss.'; FatalCause = 'Section 258 reduced your Endurance to zero.' })
        284 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section284MealHandled'; NoMealFlagName = 'Book2Section284NoMealLossApplied'; SectionLabel = 'Section 284'; Loss = 3; NoMealMessagePrefix = 'Section 284: the section meal requirement is not met.'; FatalCause = 'Hunger at section 284 reduced your Endurance to zero.' })
        314 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book2Section314MealHandled'; NoMealFlagName = 'Book2Section314NoMealLossApplied'; SectionLabel = 'Section 314'; Loss = 3; NoMealMessagePrefix = 'Section 314: the section meal requirement is not met.'; FatalCause = 'Hunger at section 314 reduced your Endurance to zero.' })
        321 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section321EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 321: apply the section ENDURANCE loss.'; FatalCause = 'Section 321 reduced your Endurance to zero.' })
        330 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section330EnduranceHandled'; Delta = -5; MessagePrefix = 'Section 330: apply the section ENDURANCE loss.'; FatalCause = 'Section 330 reduced your Endurance to zero.' })
        347 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book2Section347EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 347: apply the section ENDURANCE loss.'; FatalCause = 'Section 347 reduced your Endurance to zero.' })
    }
}

function Get-LWBookTwoSimpleCombatRuleDefinitions {
    return @{
        34  = [pscustomobject]@{ CanEvade = $false; Info = 'Book 2 section 34: the ambush cannot be evaded.' }
        90  = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 90: this fight can be evaded.' }
        110 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 110: this fight can be evaded.' }
        131 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 131: this fight can be evaded.' }
        157 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 157: this fight can be evaded.' }
        162 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 162: this fight can be evaded.' }
        185 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 185: this fight can be evaded.' }
        237 = [pscustomobject]@{ EnemyUndead = $true; EnemyImmune = $true; Info = 'Book 2 section 237: the Helghast is undead and immune to Mindblast.' }
        241 = [pscustomobject]@{ Info = 'Book 2 section 241: this is a forced duel to the death.' }
        282 = [pscustomobject]@{ CanEvade = $false; Info = 'Book 2 section 282: the bridge guards must be fought to the death.' }
        296 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 296: this fight can be evaded.' }
        298 = [pscustomobject]@{ CanEvade = $true; Info = 'Book 2 section 298: this fight can be evaded.' }
        326 = [pscustomobject]@{ Info = 'Book 2 section 326: this is a forced duel to the death.' }
        345 = [pscustomobject]@{ Info = 'Book 2 section 345: this is a forced duel to the death.' }
        348 = [pscustomobject]@{ CanEvade = $true; EvadeAvailableAfterRound = 2; Info = 'Book 2 section 348: you may evade after two rounds.' }
    }
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

function Get-LWBookTwoSection055ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'broadsword_plus_one'; FlagName = 'Book2Section055BroadswordBought'; DisplayName = 'Broadsword +1'; Type = 'weapon'; Name = 'Broadsword +1'; Quantity = 1; Description = 'Broadsword +1'; GoldCost = 12 }
    )
}

function Get-LWBookTwoSection076ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section076GoldClaimed'; DisplayName = '2 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 2; Description = '2 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book2Section076DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' }
    )
}

function Get-LWBookTwoSection124ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section124GoldClaimed'; DisplayName = '42 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 42; Description = '42 Gold Crowns' },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book2Section124ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book2Section124DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' }
    )
}

function Get-LWBookTwoSection181ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book2Section181SwordBought'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword'; GoldCost = 4 },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book2Section181DaggerBought'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger'; GoldCost = 2 },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book2Section181ShortSwordBought'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'warhammer'; FlagName = 'Book2Section181WarhammerBought'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer'; GoldCost = 6 },
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book2Section181SpearBought'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book2Section181MaceBought'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace'; GoldCost = 4 },
        [pscustomobject]@{ Id = 'blanket'; FlagName = 'Book2Section181BlanketBought'; DisplayName = 'Fur Blanket'; Type = 'backpack'; Name = 'Fur Blanket'; Quantity = 1; Description = 'Fur Blanket'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book2Section181BackpackBought'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack'; GoldCost = 1 }
    )
}

function Get-LWBookTwoSection187ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book2Section187SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book2Section187SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section187GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' }
    )
}

function Get-LWBookTwoSection231ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section231GoldClaimed'; DisplayName = '5 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 5; Description = '5 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book2Section231DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'seal'; FlagName = 'Book2Section231SealClaimed'; DisplayName = 'Seal of Hammerdal'; Type = 'special'; Name = 'Seal of Hammerdal'; Quantity = 1; Description = 'Seal of Hammerdal' }
    )
}

function Get-LWBookTwoSection274ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section274GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book2Section274SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book2Section274MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' }
    )
}

function Get-LWBookTwoSection301ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section301GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book2Section301DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book2Section301ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' }
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
    Get-LWBookTwoSimpleSectionEffectDefinitions, `
    Get-LWBookTwoSimpleCombatRuleDefinitions, `
    Apply-LWKaiBookTwoStartingEquipment, `
    Get-LWBookTwoSection055ChoiceDefinitions, `
    Get-LWBookTwoSection076ChoiceDefinitions, `
    Get-LWBookTwoSection124ChoiceDefinitions, `
    Get-LWBookTwoSection181ChoiceDefinitions, `
    Get-LWBookTwoSection187ChoiceDefinitions, `
    Get-LWBookTwoSection231ChoiceDefinitions, `
    Get-LWBookTwoSection262ChoiceDefinitions, `
    Get-LWBookTwoSection274ChoiceDefinitions, `
    Get-LWBookTwoSection301ChoiceDefinitions, `
    Get-LWBookTwoSection302ChoiceDefinitions, `
    Get-LWBookTwoSectionContextAchievementIds



