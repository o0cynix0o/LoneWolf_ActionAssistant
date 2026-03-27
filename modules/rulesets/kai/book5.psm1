Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWKaiBookFiveSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 5) {
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
            11 {
                $description = 'Stealth-around-the-pillars check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Camouflage') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                    $modifier -= 2
                    $modifierNotes += 'Camouflage or Hunting'
                }
            }
            15 {
                $description = 'Hide-in-the-tunnel check.'
                if ($disciplineCount -ge 7) {
                    $modifier -= 1
                    $modifierNotes += 'Kai rank Guardian+'
                }
            }
            23 {
                $description = 'Steam-shaft climb check.'
                if (Test-LWBookFiveLimbdeathActive) {
                    $modifier -= 3
                    $modifierNotes += 'Limbdeath'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            48 {
                $description = 'Kai lock-opening check.'
                if ($disciplineCount -ge 7) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Guardian+'
                }
            }
            49 {
                $description = 'Courier ambush check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 1
                    $modifierNotes += 'Hunting'
                }
                if ($disciplineCount -ge 9) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Savant+'
                }
            }
            56 {
                $description = 'Harbour bow-shot check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                    $modifier += 2
                    $modifierNotes += 'Weaponskill'
                }
            }
            118 {
                $description = 'Blowpipe dodge check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
                if ($disciplineCount -ge 8) {
                    $modifier += 1
                    $modifierNotes += 'Kai rank Warmarn+'
                }
            }
            125 {
                $description = 'Leap-from-the-oars balance check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            127 {
                $description = 'Smash-the-door check. Add 10 and compare against Combat Skill.'
            }
            146 {
                $description = 'Forge stealth check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Camouflage') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                    $modifier -= 2
                    $modifierNotes += 'Camouflage or Hunting'
                }
            }
            152 {
                $description = 'Outer-ledge balance check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
                if ($disciplineCount -ge 9) {
                    $modifier += 2
                    $modifierNotes += 'Kai rank Savant+'
                }
            }
            162 {
                $description = 'Steamspider climb damage roll. 0 counts as 10 if you cannot fight.'
                $zeroCountsAsTen = $true
            }
            180 {
                $description = 'Dagger-throw escape check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                    $modifier += 3
                    $modifierNotes += 'Sixth Sense or Hunting'
                }
            }
            198 {
                $description = 'Maouk dart dodge check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 3
                    $modifierNotes += 'Hunting'
                }
            }
            205 {
                $description = 'Freefall landing check.'
            }
            222 {
                $description = 'Vordak detection check.'
            }
            224 {
                if (Test-LWStateHasDiscipline -State $State -Name 'Animal Kinship') {
                    $bypassed = $true
                    $bypassReason = 'Animal Kinship bypasses this Itikar random-number check.'
                }
                elseif (Test-LWStateHasInventoryItem -State $State -Names (Get-LWOnyxMedallionItemNames) -Type 'special') {
                    $bypassed = $true
                    $bypassReason = 'The Onyx Medallion bypasses this Itikar random-number check.'
                }
                else {
                    $description = 'Itikar approach check.'
                    if ($disciplineCount -ge 6) {
                        $modifier += 2
                        $modifierNotes += 'Kai rank Aspirant+'
                    }
                }
            }
            229 {
                $description = 'Black Crystal Cube backlash check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') {
                    $modifier += 3
                    $modifierNotes += 'Sixth Sense'
                }
            }
            239 {
                if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWGraveweedItemNames) -Type 'backpack') {
                    $bypassed = $true
                    $bypassReason = 'A Tincture of Graveweed bypasses this check.'
                }
                else {
                    $description = 'Hidden-door discovery check.'
                    if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $State -Name 'Camouflage')) {
                        $modifier += 2
                        $modifierNotes += 'Hunting, Tracking, or Camouflage'
                    }
                    if ($disciplineCount -ge 7) {
                        $modifier += 3
                        $modifierNotes += 'Kai rank Guardian+'
                    }
                }
            }
            242 {
                $description = 'Hide-from-the-Vordak check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                    $modifier += 2
                    $modifierNotes += 'Camouflage'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Mindshield') {
                    $modifier += 3
                    $modifierNotes += 'Mindshield'
                }
            }
            247 { $description = 'Approach-to-Ikaresh check.' }
            275 { $description = 'Falling-Itikar landing check.' }
            282 {
                if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                    $bypassed = $true
                    $bypassReason = 'Mind Over Matter bypasses this gangplank stealth check.'
                }
                else {
                    $description = 'Gangplank stealth check.'
                    if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Camouflage')) {
                        $modifier += 2
                        $modifierNotes += 'Hunting or Camouflage'
                    }
                    if ($disciplineCount -ge 8) {
                        $modifier += 3
                        $modifierNotes += 'Kai rank Warmarn+'
                    }
                }
            }
            301 {
                $description = 'Gate-spike climb check.'
                if ($disciplineCount -ge 7) {
                    $modifier -= 2
                    $modifierNotes += 'Kai rank Guardian+'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier -= 1
                    $modifierNotes += 'Hunting'
                }
            }
            305 { $description = 'Falling-rope landing check.' }
            312 {
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                    $bypassed = $true
                    $bypassReason = 'Hunting or Sixth Sense bypasses this thrown-axe random-number check.'
                }
                else {
                    $description = 'Thrown-axe survival check.'
                }
            }
            323 { $description = 'Skyship escape check.' }
            325 {
                $description = 'Blowpipe shot check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                    $modifier += 2
                    $modifierNotes += 'Weaponskill'
                }
            }
            336 { $description = 'Falling-Itikar landing check.' }
            357 {
                $description = 'Platform fight fall check. Picking a 1 makes you fall.'
            }
            360 {
                $description = 'Twin-roll surprise check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 1
                    $modifierNotes += 'Hunting'
                }
            }
            372 {
                $description = 'Crossbow-bolt exposure check.'
                if ($disciplineCount -ge 6) {
                    $modifier += 2
                    $modifierNotes += 'Kai rank Aspirant+'
                }
            }
            381 {
                $description = 'Axe-feint reaction check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            392 {
                $description = 'Ale-drinking balance check.'
                if ([int]$State.Character.EnduranceCurrent -lt 15) {
                    $modifier -= 2
                    $modifierNotes += 'Current END below 15'
                }
                elseif ([int]$State.Character.EnduranceCurrent -gt 25) {
                    $modifier += 2
                    $modifierNotes += 'Current END above 25'
                }
                if ($disciplineCount -ge 9) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Savant+'
                }
            }
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

function Apply-LWKaiBookFiveStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

        if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 5) {
            return
        }

        if ($CarryExistingGear -and @($script:GameState.Inventory.SpecialItems).Count -gt 0) {
            $safekeepingPromptComplete = $false
            while (-not $safekeepingPromptComplete) {
                Write-LWPanelHeader -Title 'Book 5 Safekeeping' -AccentColor 'DarkYellow'
                Write-LWSubtle '  Leave carried Special Items at the Kai Monastery if you do not want to take them into Book 5.'
                Write-Host ''
                Write-LWBulletItem -Text 'Y. Choose Special Items to leave in safekeeping' -TextColor 'Gray' -BulletColor 'Yellow'
                Write-LWBulletItem -Text 'I. Review inventory first' -TextColor 'Gray' -BulletColor 'Yellow'
                Write-LWBulletItem -Text 'N. Keep everything with you' -TextColor 'Gray' -BulletColor 'Yellow'

                $safekeepingChoice = [string](Read-LWText -Prompt 'Safekeeping choice' -Default 'N' -NoRefresh)
                switch ($safekeepingChoice.Trim().ToLowerInvariant()) {
                    'y' {
                        Invoke-LWBookFiveSafekeepingSelection
                        $safekeepingPromptComplete = $true
                        break
                    }
                    'yes' {
                        Invoke-LWBookFiveSafekeepingSelection
                        $safekeepingPromptComplete = $true
                        break
                    }
                    'i' {
                        Show-LWInventory
                        [void](Read-LWText -Prompt 'Press Enter to return to the Book 5 safekeeping prompt' -NoRefresh)
                        break
                    }
                    'inv' {
                        Show-LWInventory
                        [void](Read-LWText -Prompt 'Press Enter to return to the Book 5 safekeeping prompt' -NoRefresh)
                        break
                    }
                    'inventory' {
                        Show-LWInventory
                        [void](Read-LWText -Prompt 'Press Enter to return to the Book 5 safekeeping prompt' -NoRefresh)
                        break
                    }
                    'n' {
                        $safekeepingPromptComplete = $true
                        break
                    }
                    'no' {
                        $safekeepingPromptComplete = $true
                        break
                    }
                    default {
                        Write-LWWarn 'Choose Y to safekeep items, I to review inventory, or N to keep everything with you.'
                    }
                }
            }
        }

        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfVassagoniaItemNames) -Type 'special')) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of Vassagonia') {
                Write-LWInfo 'Book 5 starting Special Item added: Map of Vassagonia.'
            }
            else {
                Write-LWWarn 'No room to add the Book 5 map automatically. Make room and add it manually if needed.'
            }
        }

        Restore-LWBackpackState

        $startingGoldRoll = Get-LWRandomDigit
        $goldGain = 10 + [int]$startingGoldRoll
        $oldGold = [int]$script:GameState.Inventory.GoldCrowns
        $newGold = [Math]::Min(50, ($oldGold + $goldGain))
        $script:GameState.Inventory.GoldCrowns = $newGold

        Write-LWInfo ("Book 5 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
        if ($newGold -ne ($oldGold + $goldGain)) {
            Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 5 starting gold is lost.'
        }

        Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to four Book 5 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to four Book 5 starting items now.' })

        $selectedIds = @()
        while ($selectedIds.Count -lt 4) {
            $availableChoices = @(Get-LWBookFiveStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
            if ($availableChoices.Count -eq 0) {
                break
            }

            Write-LWPanelHeader -Title 'Book 5 Starting Gear' -AccentColor 'DarkYellow'
            Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/4" -f $selectedIds.Count) -ValueColor 'Gray'
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

            $choiceIndex = Read-LWInt -Prompt ("Book 5 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
            if ($choiceIndex -eq 0) {
                break
            }
            if ($choiceIndex -eq $manageIndex) {
                Invoke-LWBookFourStartingInventoryManagement
                continue
            }

            $choice = $availableChoices[$choiceIndex - 1]
            $granted = Grant-LWBookFiveStartingChoice -Choice $choice
            if ($granted) {
                $selectedIds += [string]$choice.Id
            }
            elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
                Invoke-LWBookFourStartingInventoryManagement
            }
        }
}

Export-ModuleMember -Function `
    Get-LWKaiBookFiveSectionRandomNumberContext, `
    Apply-LWKaiBookFiveStartingEquipment

