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

Export-ModuleMember -Function `
    Get-LWKaiBookFourSectionRandomNumberContext, `
    Apply-LWKaiBookFourStartingEquipment

