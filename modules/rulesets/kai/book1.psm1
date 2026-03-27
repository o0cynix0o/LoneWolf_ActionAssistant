Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWKaiBookOneSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 1) {
            return $null
        }

        $section = [int]$State.CurrentSection
        if (@(2, 7, 17, 21, 22, 36, 44, 49, 89, 158, 160, 188, 205, 226, 237, 275, 279, 294, 302, 314, 337, 350) -contains $section) {
            return (New-LWSectionRandomNumberContext -Section $section)
        }

        return $null
}

function Apply-LWKaiBookOneStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

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

Export-ModuleMember -Function `
    Get-LWKaiBookOneSectionRandomNumberContext, `
    Apply-LWKaiBookOneStartingEquipment

