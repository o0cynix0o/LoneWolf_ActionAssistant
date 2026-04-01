Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWKaiBookTwoSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State }

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
            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$availableChoices[$i].DisplayName) -TextColor 'Gray' -BulletColor 'Yellow'
            }

            $choiceIndex = Read-LWInt -Prompt ("Armory choice #{0}" -f ($selectedIds.Count + 1)) -Min 1 -Max $availableChoices.Count -NoRefresh
            $choice = $availableChoices[$choiceIndex - 1]
            $selectedIds += [string]$choice.Id
            Grant-LWBookTwoArmoryChoice -Choice $choice
        }
}

Export-ModuleMember -Function `
    Get-LWKaiBookTwoSectionRandomNumberContext, `
    Apply-LWKaiBookTwoStartingEquipment

