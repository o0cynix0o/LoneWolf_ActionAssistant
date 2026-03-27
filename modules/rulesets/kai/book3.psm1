Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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

Export-ModuleMember -Function `
    Get-LWKaiBookThreeSectionRandomNumberContext, `
    Apply-LWKaiBookThreeStartingEquipment

