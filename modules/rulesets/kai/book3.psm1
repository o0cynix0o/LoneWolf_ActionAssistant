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

function Get-LWBookThreeStartingChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'short_sword'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'padded_leather'; DisplayName = 'Padded Leather Waistcoat'; Type = 'special'; Name = 'Padded Leather Waistcoat'; Quantity = 1; Description = 'Padded Leather Waistcoat' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'warhammer'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'axe'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'laumspur_potion'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'quarterstaff'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'special_rations'; DisplayName = 'Special Rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 1; Description = 'Special Rations' },
        [pscustomobject]@{ Id = 'broadsword'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' }
    )
}

function Grant-LWBookThreeStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 3 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 3 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Get-LWKaiBookThreeSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State; if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null } }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 3) {
            return $null
        }

        $section = [int]$State.CurrentSection
        switch ($section) {
            29 { return (New-LWSectionRandomNumberContext -Section $section) }
            54 {
                $modifier = 0
                $notes = @()
                if ((Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') -or (Test-LWStateHasDiscipline -State $State -Name 'Mindblast')) {
                    $modifier += 3
                    $notes += 'Mind Over Matter or Mindblast'
                }
                return (New-LWSectionRandomNumberContext -Section $section -Description 'Book 3 snowfield reaction check.' -Modifier $modifier -ModifierNotes $notes)
            }
            73 { return (New-LWSectionRandomNumberContext -Section $section) }
            74 { return (New-LWSectionRandomNumberContext -Section $section) }
            80 { return (New-LWSectionRandomNumberContext -Section $section) }
            86 { return (New-LWSectionRandomNumberContext -Section $section) }
            88 { return (New-LWSectionRandomNumberContext -Section $section -Description 'Javek venom survival check. Only a 9 is fatal.') }
            94 { return (New-LWSectionRandomNumberContext -Section $section -Description 'Icy-water survival check.') }
            96 { return (New-LWSectionRandomNumberContext -Section $section) }
            134 { return (New-LWSectionRandomNumberContext -Section $section) }
            142 { return (New-LWSectionRandomNumberContext -Section $section) }
            146 { return (New-LWSectionRandomNumberContext -Section $section) }
            149 {
                $modifier = 0
                $notes = @()
                if ((Test-LWStateHasDiscipline -State $State -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                    $modifier += 2
                    $notes += 'Tracking, Hunting, or Sixth Sense'
                }
                return (New-LWSectionRandomNumberContext -Section $section -Description 'Book 3 route-finding check.' -Modifier $modifier -ModifierNotes $notes)
            }
            152 { return (New-LWSectionRandomNumberContext -Section $section) }
            155 { return (New-LWSectionRandomNumberContext -Section $section) }
            167 { return (New-LWSectionRandomNumberContext -Section $section) }
            179 { return (New-LWSectionRandomNumberContext -Section $section) }
            183 { return (New-LWSectionRandomNumberContext -Section $section) }
            185 { return (New-LWSectionRandomNumberContext -Section $section) }
            211 { return (New-LWSectionRandomNumberContext -Section $section) }
            232 { return (New-LWSectionRandomNumberContext -Section $section) }
            258 {
                $modifier = 0
                $notes = @()
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                    $modifier -= 2
                    $notes += 'Hunting or Sixth Sense'
                }
                return (New-LWSectionRandomNumberContext -Section $section -Description 'Gold Bracelet backlash check.' -Modifier $modifier -ModifierNotes $notes -ZeroCountsAsTen:$true)
            }
            262 { return (New-LWSectionRandomNumberContext -Section $section) }
            272 { return (New-LWSectionRandomNumberContext -Section $section) }
            281 {
                $modifier = 0
                $notes = @()
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                    $modifier -= 2
                    $notes += 'Hunting or Sixth Sense'
                }
                return (New-LWSectionRandomNumberContext -Section $section -Description 'Baknar avoidance check.' -Modifier $modifier -ModifierNotes $notes -ZeroCountsAsTen:$true)
            }
            283 { return (New-LWSectionRandomNumberContext -Section $section) }
            284 { return (New-LWSectionRandomNumberContext -Section $section) }
            291 { return (New-LWSectionRandomNumberContext -Section $section) }
            302 { return (New-LWSectionRandomNumberContext -Section $section) }
            322 { return (New-LWSectionRandomNumberContext -Section $section) }
            323 { return (New-LWSectionRandomNumberContext -Section $section) }
            327 { return (New-LWSectionRandomNumberContext -Section $section) }
            331 { return (New-LWSectionRandomNumberContext -Section $section) }
            346 { return (New-LWSectionRandomNumberContext -Section $section) }
            350 { return (New-LWSectionRandomNumberContext -Section $section) }
            default { return $null }
        }
}

function Get-LWBookThreeSimpleSectionEffectDefinitions {
    return @{
        27  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section027EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 27: apply the section ENDURANCE loss.'; FatalCause = 'Section 27 reduced your Endurance to zero.' })
        33  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section033EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 33: apply the section ENDURANCE loss.'; FatalCause = 'Section 33 reduced your Endurance to zero.' })
        37  = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book3Section037DeathApplied'; Cause = 'Section 37: you fall into an icy fissure and die there.' })
        43  = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book3Section043MealHandled'; NoMealFlagName = 'Book3Section043NoMealLossApplied'; SectionLabel = 'Section 43'; Loss = 1; NoMealMessagePrefix = 'Section 43: the section meal requirement is not met.'; FatalCause = 'Hunger at section 43 reduced your Endurance to zero.' })
        62  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section062EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 62: apply the section ENDURANCE loss.'; FatalCause = 'Section 62 reduced your Endurance to zero.' })
        77  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section077EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 77: apply the section ENDURANCE loss.'; FatalCause = 'Section 77 reduced your Endurance to zero.' })
        121 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book3Section121MealHandled'; NoMealFlagName = 'Book3Section121NoMealLossApplied'; SectionLabel = 'Section 121'; Loss = 1; NoMealMessagePrefix = 'Section 121: the section meal requirement is not met.'; FatalCause = 'Hunger at section 121 reduced your Endurance to zero.' })
        132 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section132EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 132: apply the section ENDURANCE loss.'; FatalCause = 'Section 132 reduced your Endurance to zero.' })
        136 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book3Section136DeathApplied'; Cause = 'Section 136: instant death.' })
        140 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section140EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 140: apply the section ENDURANCE loss.'; FatalCause = 'Section 140 reduced your Endurance to zero.' })
        144 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book3Section144DeathApplied'; Cause = 'Section 144: instant death.' })
        155 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book3Section155MealHandled'; NoMealFlagName = 'Book3Section155NoMealLossApplied'; SectionLabel = 'Section 155'; Loss = 3; NoMealMessagePrefix = 'Section 155: the section meal requirement is not met.'; FatalCause = 'Hunger at section 155 reduced your Endurance to zero.' })
        157 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section157EnduranceHandled'; Delta = 6; MessagePrefix = 'Section 157: apply the section ENDURANCE recovery.' })
        190 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book3Section190DeathApplied'; Cause = 'Section 190: instant death.' })
        193 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section193EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 193: apply the section ENDURANCE loss.'; FatalCause = 'Section 193 reduced your Endurance to zero.' })
        196 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section196EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 196: apply the section ENDURANCE loss.'; FatalCause = 'Section 196 reduced your Endurance to zero.' })
        206 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section206EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 206: apply the section ENDURANCE loss.'; FatalCause = 'Section 206 reduced your Endurance to zero.' })
        209 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section209EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 209: apply the section ENDURANCE loss.'; FatalCause = 'Section 209 reduced your Endurance to zero.' })
        214 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section214EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 214: apply the section ENDURANCE loss.'; FatalCause = 'Section 214 reduced your Endurance to zero.' })
        217 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section217EnduranceHandled'; Delta = -10; MessagePrefix = 'Section 217: apply the section ENDURANCE loss.'; FatalCause = 'Section 217 reduced your Endurance to zero.' })
        226 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book3Section226MealHandled'; NoMealFlagName = 'Book3Section226NoMealLossApplied'; SectionLabel = 'Section 226'; Loss = 1; NoMealMessagePrefix = 'Section 226: the section meal requirement is not met.'; FatalCause = 'Hunger at section 226 reduced your Endurance to zero.' })
        251 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section251EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 251: apply the section ENDURANCE loss.'; FatalCause = 'Section 251 reduced your Endurance to zero.' })
        294 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section294EnduranceHandled'; Delta = -6; MessagePrefix = 'Section 294: apply the section ENDURANCE loss.'; FatalCause = 'Section 294 reduced your Endurance to zero.' })
        299 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section299EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 299: apply the section ENDURANCE loss.'; FatalCause = 'Section 299 reduced your Endurance to zero.' })
        331 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section331EnduranceHandled'; Delta = -4; MessagePrefix = 'Section 331: frostbite and exhaustion cost 4 ENDURANCE.'; FatalCause = 'The storm at section 331 reduced your Endurance to zero.'; RequiresMissingDiscipline = 'Healing' })
        313 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book3Section313DeathApplied'; Cause = 'Section 313: instant death.' })
        340 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book3Section340EnduranceHandled'; Delta = 6; MessagePrefix = 'Section 340: apply the section ENDURANCE recovery.' })
    }
}

function Get-LWBookThreeSimpleCombatRuleDefinitions {
    return @{
        32  = [pscustomobject]@{ OneAtATime = $true; Info = 'Book 3 section 32: resolve the Kalkoths one at a time.' }
        78  = [pscustomobject]@{ CanEvade = $false; Info = 'Book 3 section 78: this fight cannot be evaded.' }
        89  = [pscustomobject]@{ OneAtATime = $true; Info = 'Book 3 section 89: the Doomwolves attack one at a time.' }
        103 = [pscustomobject]@{ CanEvade = $false; Info = 'Book 3 section 103: this fight cannot be evaded.' }
        123 = [pscustomobject]@{ CanEvade = $false; Info = 'Book 3 section 123: this fight cannot be evaded.' }
        200 = [pscustomobject]@{ CanEvade = $false; Info = 'Book 3 section 200: this fight cannot be evaded.' }
        241 = [pscustomobject]@{ Info = 'Book 3 section 241: ignore Lone Wolf ENDURANCE loss during the first two rounds.'; IgnorePlayerEnduranceLossRounds = 2 }
        259 = [pscustomobject]@{ CanEvade = $false; Info = 'Book 3 section 259: this fight cannot be evaded.' }
        265 = [pscustomobject]@{ EnemyImmune = $true; CanEvade = $false; Info = 'Book 3 section 265: the Crystal Frostwyrm is immune to Mindblast.' }
    }
}

function Apply-LWKaiBookThreeStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

        if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 3) {
            return
        }

        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfKalteItemNames) -Type 'special')) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of Kalte') {
                Write-LWInfo 'Book 3 starting Special Item added: Map of Kalte.'
            }
            else {
                Write-LWWarn 'No room to add Map of Kalte automatically. Make room and add it manually if needed.'
            }
        }

        $startingGoldRoll = Get-LWRandomDigit
        $goldGain = 10 + [int]$startingGoldRoll
        $oldGold = [int]$script:GameState.Inventory.GoldCrowns
        $newGold = [Math]::Min(50, ($oldGold + $goldGain))
        $script:GameState.Inventory.GoldCrowns = $newGold

        Write-LWInfo ("Book 3 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
        if ($newGold -ne ($oldGold + $goldGain)) {
            Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 3 starting gold is lost.'
        }

        Write-LWInfo $(if ($CarryExistingGear) { 'Choose two Book 3 starting items now. You may exchange carried weapons if needed.' } else { 'Choose two Book 3 starting items now.' })

        $selectedIds = @()
        while ($selectedIds.Count -lt 2) {
            $availableChoices = @(Get-LWBookThreeStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
            if ($availableChoices.Count -eq 0) {
                break
            }

            Write-LWPanelHeader -Title 'Book 3 Expedition Gear' -AccentColor 'DarkYellow'
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
            Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

            $choiceIndex = Read-LWInt -Prompt ("Book 3 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
            if ($choiceIndex -eq 0) {
                break
            }
            if ($choiceIndex -eq $manageIndex) {
                Invoke-LWBookFourStartingInventoryManagement
                continue
            }

            $choice = $availableChoices[$choiceIndex - 1]
            $granted = Grant-LWBookThreeStartingChoice -Choice $choice
            if ($granted) {
                $selectedIds += [string]$choice.Id
            }
            elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
                Invoke-LWBookFourStartingInventoryManagement
            }
        }
}


function Get-LWBookThreeSection004ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'bone_sword'; FlagName = 'Book3Section004BoneSwordClaimed'; DisplayName = 'Bone Sword'; Type = 'weapon'; Name = 'Bone Sword'; Quantity = 1; Description = 'Bone Sword' },
        [pscustomobject]@{ Id = 'blue_stone_disc'; FlagName = 'Book3Section004BlueStoneDiscClaimed'; DisplayName = 'Blue Stone Disc'; Type = 'special'; Name = 'Blue Stone Disc'; Quantity = 1; Description = 'Blue Stone Disc' }
    )
}

function Get-LWBookThreeSection012ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book3Section012MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'sleeping_furs'; FlagName = 'Book3Section012SleepingFursClaimed'; DisplayName = 'Sleeping Furs'; Type = 'backpack'; Name = 'Sleeping Furs'; Quantity = 1; Description = 'Sleeping Furs' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book3Section012RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' }
    )
}

function Get-LWBookThreeSection038ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book3Section038BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'long_rope'; FlagName = 'Book3Section038LongRopeClaimed'; DisplayName = 'Long Rope'; Type = 'backpack'; Name = 'Long Rope'; Quantity = 1; Description = 'Long Rope' }
    )
}

function Get-LWBookThreeSection084ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section084TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection025ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section025TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection026ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'bone_sword'; FlagName = 'Book3Section026BoneSwordClaimed'; DisplayName = 'Bone Sword'; Type = 'weapon'; Name = 'Bone Sword'; Quantity = 1; Description = 'Bone Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book3Section026DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book3Section026MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' }
    )
}

function Get-LWBookThreeSection059ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section059TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection102ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'stone_effigy'; FlagName = 'Book3Section102EffigyClaimed'; DisplayName = 'Stone Effigy'; Type = 'special'; Name = 'Stone Effigy'; Quantity = 1; Description = 'Stone Effigy' }
    )
}

function Get-LWBookThreeSection156ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gallowbrush'; FlagName = 'Book3Section156GallowbrushClaimed'; DisplayName = 'Potion of Gallowbrush'; Type = 'backpack'; Name = 'Potion of Gallowbrush'; Quantity = 1; Description = 'Potion of Gallowbrush' }
    )
}

function Get-LWBookThreeSection177ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'graveweed'; FlagName = 'Book3Section177GraveweedClaimed'; DisplayName = 'Vial of Graveweed'; Type = 'backpack'; Name = 'Vial of Graveweed'; Quantity = 1; Description = 'Vial of Graveweed' }
    )
}

function Get-LWBookThreeSection210ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'bone_sword'; FlagName = 'Book3Section210BoneSwordClaimed'; DisplayName = 'Bone Sword'; Type = 'weapon'; Name = 'Bone Sword'; Quantity = 1; Description = 'Bone Sword' }
    )
}

function Get-LWBookThreeSection218ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'diamond'; FlagName = 'Book3Section218DiamondClaimed'; DisplayName = 'Diamond'; Type = 'special'; Name = 'Diamond'; Quantity = 1; Description = 'Diamond' }
    )
}

function Get-LWBookThreeSection231ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold_bracelet'; FlagName = 'Book3Section231BraceletClaimed'; DisplayName = 'Gold Bracelet'; Type = 'special'; Name = 'Gold Bracelet'; Quantity = 1; Description = 'Gold Bracelet' }
    )
}

function Get-LWBookThreeSection233ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'distilled_laumspur'; FlagName = 'Book3Section233LaumspurClaimed'; DisplayName = 'Distilled Laumspur'; Type = 'backpack'; Name = 'Distilled Laumspur'; Quantity = 1; Description = 'Distilled Laumspur' }
    )
}

function Get-LWBookThreeSection295ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'firesphere'; FlagName = 'Book3Section295FiresphereClaimed'; DisplayName = 'Firesphere'; Type = 'special'; Name = 'Firesphere'; Quantity = 1; Description = 'Firesphere' }
    )
}

function Get-LWBookThreeSection298ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section298TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection282ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book3Section282SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'blue_stone_disc'; FlagName = 'Book3Section282BlueStoneDiscClaimed'; DisplayName = 'Blue Stone Disc'; Type = 'special'; Name = 'Blue Stone Disc'; Quantity = 1; Description = 'Blue Stone Disc' }
    )
}

function Get-LWBookThreeSection309ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section309TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' },
        [pscustomobject]@{ Id = 'firesphere'; FlagName = 'Book3Section309FiresphereClaimed'; DisplayName = 'Firesphere'; Type = 'special'; Name = 'Firesphere'; Quantity = 1; Description = 'Firesphere' }
    )
}

function Get-LWBookThreeSection311ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book3Section311AletherClaimed'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Potion of Alether'; Quantity = 1; Description = 'Potion of Alether' }
    )
}

function Get-LWBookThreeSection316ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold_bracelet'; FlagName = 'Book3Section316BraceletClaimed'; DisplayName = 'Gold Bracelet'; Type = 'special'; Name = 'Gold Bracelet'; Quantity = 1; Description = 'Gold Bracelet' }
    )
}

function Get-LWBookThreeSection321ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section321TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection334ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'glowing_crystal'; FlagName = 'Book3Section334GlowingCrystalClaimed'; DisplayName = 'Glowing Crystal'; Type = 'special'; Name = 'Glowing Crystal'; Quantity = 1; Description = 'Glowing Crystal' }
    )
}

function Get-LWBookThreeSectionContextAchievementIds {
    return @(
        'snakes_why',
        'cliffhanger',
        'whats_in_the_box',
        'snowblind',
        'you_touched_it_with_your_hands',
        'lucky_button_theory',
        'well_it_worked_once',
        'cellfish',
        'loi_kymar_lives',
        'puppet_master',
        'sun_on_the_ice',
        'lucky_break',
        'too_slow'
    )
}


Export-ModuleMember -Function `
    Get-LWKaiBookThreeSectionRandomNumberContext, `
    Get-LWBookThreeSimpleSectionEffectDefinitions, `
    Get-LWBookThreeSimpleCombatRuleDefinitions, `
    Apply-LWKaiBookThreeStartingEquipment, `
    Get-LWBookThreeSection004ChoiceDefinitions, `
    Get-LWBookThreeSection012ChoiceDefinitions, `
    Get-LWBookThreeSection038ChoiceDefinitions, `
    Get-LWBookThreeSection084ChoiceDefinitions, `
    Get-LWBookThreeSection025ChoiceDefinitions, `
    Get-LWBookThreeSection026ChoiceDefinitions, `
    Get-LWBookThreeSection059ChoiceDefinitions, `
    Get-LWBookThreeSection102ChoiceDefinitions, `
    Get-LWBookThreeSection156ChoiceDefinitions, `
    Get-LWBookThreeSection177ChoiceDefinitions, `
    Get-LWBookThreeSection210ChoiceDefinitions, `
    Get-LWBookThreeSection218ChoiceDefinitions, `
    Get-LWBookThreeSection231ChoiceDefinitions, `
    Get-LWBookThreeSection233ChoiceDefinitions, `
    Get-LWBookThreeSection295ChoiceDefinitions, `
    Get-LWBookThreeSection298ChoiceDefinitions, `
    Get-LWBookThreeSection282ChoiceDefinitions, `
    Get-LWBookThreeSection309ChoiceDefinitions, `
    Get-LWBookThreeSection311ChoiceDefinitions, `
    Get-LWBookThreeSection316ChoiceDefinitions, `
    Get-LWBookThreeSection321ChoiceDefinitions, `
    Get-LWBookThreeSection334ChoiceDefinitions, `
    Get-LWBookThreeSectionContextAchievementIds



