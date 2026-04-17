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

function Get-LWMagnakaiRulesetVersion {
    return '1.0.0'
}

function Get-LWMagnakaiSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -eq $State -or $null -eq $State.Character) {
        return $null
    }

    switch ([int]$State.Character.BookNumber) {
        6 { return (Get-LWMagnakaiBookSixSectionRandomNumberContext -State $State) }
        7 { return (Get-LWMagnakaiBookSevenSectionRandomNumberContext -State $State) }
        default { return $null }
    }
}

function Invoke-LWMagnakaiSectionRandomNumberResolution {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object]$Context = $null,
        [int[]]$Rolls = @(),
        [int[]]$EffectiveRolls = @(),
        [int]$Subtotal = 0,
        [int]$AdjustedTotal = 0
    )

    if ($null -eq $State -or $null -eq $State.Character) {
        return
    }

    switch ([int]$State.Character.BookNumber) {
        6 { Invoke-LWMagnakaiBookSixSectionRandomNumberResolution -State $State -Context $Context -Rolls $Rolls -EffectiveRolls $EffectiveRolls -Subtotal $Subtotal -AdjustedTotal $AdjustedTotal; return }
        7 { Invoke-LWMagnakaiBookSevenSectionRandomNumberResolution -State $State -Context $Context -Rolls $Rolls -EffectiveRolls $EffectiveRolls -Subtotal $Subtotal -AdjustedTotal $AdjustedTotal; return }
    }
}

function Invoke-LWMagnakaiStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    switch ([int]$State.Character.BookNumber) {
        6 { Invoke-LWMagnakaiBookSixStorySectionAchievementTriggers -State $State -Section $Section; return }
        7 { Invoke-LWMagnakaiBookSevenStorySectionAchievementTriggers -State $State -Section $Section; return }
    }
}

function Invoke-LWMagnakaiStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    switch ([int]$State.Character.BookNumber) {
        6 { Invoke-LWMagnakaiBookSixStorySectionTransitionAchievementTriggers -State $State -FromSection $FromSection -ToSection $ToSection; return }
        7 { Invoke-LWMagnakaiBookSevenStorySectionTransitionAchievementTriggers -State $State -FromSection $FromSection -ToSection $ToSection; return }
    }
}

function Invoke-LWMagnakaiSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    switch ([int]$State.Character.BookNumber) {
        6 { Invoke-LWMagnakaiBookSixSectionEntryRules -State $State; return }
        7 { Invoke-LWMagnakaiBookSevenSectionEntryRules -State $State; return }
    }
}

function Invoke-LWMagnakaiStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [int]$BookNumber,
        [switch]$CarryExistingGear
    )

    switch ([int]$BookNumber) {
        6 { Apply-LWMagnakaiBookSixStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
        7 { Apply-LWMagnakaiBookSevenStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
    }
}

function Get-LWBookOfMagnakaiItemNames {
    return @('Book of the Magnakai')
}

Export-ModuleMember -Function `
    Get-LWMagnakaiRulesetVersion, `
    Get-LWMagnakaiSectionRandomNumberContext, `
    Invoke-LWMagnakaiSectionRandomNumberResolution, `
    Invoke-LWMagnakaiStorySectionAchievementTriggers, `
    Invoke-LWMagnakaiStorySectionTransitionAchievementTriggers, `
    Invoke-LWMagnakaiSectionEntryRules, `
    Invoke-LWMagnakaiStartingEquipment, `
    Get-LWBookOfMagnakaiItemNames

function Select-LWMagnakaiDisciplines {
    param(
        [int]$Count = 3,
        [string[]]$Exclude = @()
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $available = @($script:GameData.MagnakaiDisciplines | Where-Object { $Exclude -notcontains [string]$_.Name })
    if ($available.Count -lt $Count) {
        throw "Not enough Magnakai disciplines available to choose $Count item(s)."
    }

    $previousScreen = $script:LWUi.CurrentScreen
    $previousData = $script:LWUi.ScreenData
    if ($script:LWUi.Enabled) {
        Set-LWScreen -Name 'disciplineselect' -Data ([pscustomobject]@{
                Available = @($available)
                Count     = $Count
                RuleSet   = 'Magnakai'
            })
    }

    try {
        while ($true) {
            Refresh-LWScreen
            $raw = Read-Host "Enter $Count number(s) separated by commas"
            if ([string]::IsNullOrWhiteSpace($raw)) {
                Write-LWWarn 'Please choose at least one discipline.'
                continue
            }

            $pieces = @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
            $numbers = @()
            $valid = $true

            foreach ($piece in $pieces) {
                $number = 0
                if (-not [int]::TryParse($piece, [ref]$number)) {
                    $valid = $false
                    break
                }
                if ($number -lt 1 -or $number -gt $available.Count) {
                    $valid = $false
                    break
                }
                if ($numbers -contains $number) {
                    $valid = $false
                    break
                }
                $numbers += $number
            }

            if (-not $valid -or $numbers.Count -ne $Count) {
                Write-LWWarn "Enter exactly $Count unique number(s) from the list."
                continue
            }

            return @(
                foreach ($number in $numbers) {
                    [string]$available[$number - 1].Name
                }
            )
        }
    }
    finally {
        if ($script:LWUi.Enabled) {
            Set-LWScreen -Name $previousScreen -Data $previousData
        }
    }
}

function Select-LWWeaponmasteryWeapons {
    param(
        [int]$Count = 3,
        [string[]]$Exclude = @()
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $available = @(Get-LWMagnakaiWeaponmasteryOptions | Where-Object { $Exclude -notcontains $_ })
    if ($available.Count -lt $Count) {
        throw "Not enough Weaponmastery weapons available to choose $Count item(s)."
    }

    while ($true) {
        Write-LWPanelHeader -Title 'Weaponmastery' -AccentColor 'DarkYellow'
        Write-LWSubtle '  Choose your mastered weapons.'
        Write-Host ''
        for ($i = 0; $i -lt $available.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$available[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
        }

        $raw = [string](Read-LWText -Prompt "Choose $Count mastered weapon number(s) separated by commas" -NoRefresh)
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-LWWarn 'Please choose at least one weapon.'
            continue
        }

        $pieces = @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        $numbers = @()
        $valid = $true
        foreach ($piece in $pieces) {
            $number = 0
            if (-not [int]::TryParse($piece, [ref]$number)) {
                $valid = $false
                break
            }
            if ($number -lt 1 -or $number -gt $available.Count -or $numbers -contains $number) {
                $valid = $false
                break
            }
            $numbers += $number
        }

        if (-not $valid -or $numbers.Count -ne $Count) {
            Write-LWWarn "Enter exactly $Count unique number(s) from the list."
            continue
        }

        return @(
            foreach ($number in $numbers) {
                [string]$available[$number - 1]
            }
        )
    }
}

function Add-LWMagnakaiDiscipline {
    param([string]$Name = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $owned = @($script:GameState.Character.MagnakaiDisciplines)
    $availableNames = @($script:GameData.MagnakaiDisciplines | ForEach-Object { [string]$_.Name })
    $remainingNames = @($availableNames | Where-Object { $owned -notcontains $_ })

    if ($remainingNames.Count -eq 0) {
        Write-LWWarn 'All Magnakai Disciplines are already owned.'
        return
    }

    $disciplineName = $null
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $selection = Select-LWMagnakaiDisciplines -Count 1 -Exclude $owned
        if (@($selection).Count -gt 0) {
            $disciplineName = [string]$selection[0]
        }
    }
    else {
        $disciplineName = Get-LWMatchingValue -Values $remainingNames -Target $Name.Trim()
        if ([string]::IsNullOrWhiteSpace($disciplineName)) {
            Write-LWWarn ("Unknown or already owned Magnakai discipline: {0}" -f $Name.Trim())
            return
        }
    }

    if ([string]::IsNullOrWhiteSpace($disciplineName)) {
        Write-LWWarn 'No discipline was selected.'
        return
    }

    $script:GameState.Character.MagnakaiDisciplines = @($owned + $disciplineName)
    if (-not $script:GameState.Character.MagnakaiRank -or [int]$script:GameState.Character.MagnakaiRank -lt @($script:GameState.Character.MagnakaiDisciplines).Count) {
        $script:GameState.Character.MagnakaiRank = @($script:GameState.Character.MagnakaiDisciplines).Count
    }

    if ($disciplineName -eq 'Weaponmastery' -and @($script:GameState.Character.WeaponmasteryWeapons).Count -lt 3) {
        $script:GameState.Character.WeaponmasteryWeapons = @(Select-LWWeaponmasteryWeapons -Count 3 -Exclude @())
        Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
    }

    Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages
    Set-LWScreen -Name 'disciplines'
    Write-LWInfo "Added Magnakai discipline: $disciplineName."
    Invoke-LWMaybeAutosave
}

Export-ModuleMember -Function Select-LWMagnakaiDisciplines, Select-LWWeaponmasteryWeapons, Add-LWMagnakaiDiscipline

