Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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

    if ($null -ne $State) { $script:GameState = $State }

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

function Apply-LWKaiBookThreeStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

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

function Get-LWBookThreeSection102ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'stone_effigy'; FlagName = 'Book3Section102EffigyClaimed'; DisplayName = 'Stone Effigy'; Type = 'special'; Name = 'Stone Effigy'; Quantity = 1; Description = 'Stone Effigy' }
    )
}

function Get-LWBookThreeSection231ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold_bracelet'; FlagName = 'Book3Section231BraceletClaimed'; DisplayName = 'Gold Bracelet'; Type = 'special'; Name = 'Gold Bracelet'; Quantity = 1; Description = 'Gold Bracelet' }
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

function Get-LWBookThreeSection321ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section321TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
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
    Apply-LWKaiBookThreeStartingEquipment, `
    Get-LWBookThreeSection004ChoiceDefinitions, `
    Get-LWBookThreeSection012ChoiceDefinitions, `
    Get-LWBookThreeSection038ChoiceDefinitions, `
    Get-LWBookThreeSection084ChoiceDefinitions, `
    Get-LWBookThreeSection102ChoiceDefinitions, `
    Get-LWBookThreeSection231ChoiceDefinitions, `
    Get-LWBookThreeSection295ChoiceDefinitions, `
    Get-LWBookThreeSection298ChoiceDefinitions, `
    Get-LWBookThreeSection282ChoiceDefinitions, `
    Get-LWBookThreeSection309ChoiceDefinitions, `
    Get-LWBookThreeSection321ChoiceDefinitions, `
    Get-LWBookThreeSectionContextAchievementIds

