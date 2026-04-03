Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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
        default { return $null }
    }
}

function Invoke-LWMagnakaiStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    switch ([int]$State.Character.BookNumber) {
        6 { Invoke-LWMagnakaiBookSixStorySectionAchievementTriggers -State $State -Section $Section; return }
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
    }
}

function Invoke-LWMagnakaiSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    switch ([int]$State.Character.BookNumber) {
        6 { Invoke-LWMagnakaiBookSixSectionEntryRules -State $State; return }
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
    }
}

Export-ModuleMember -Function `
    Get-LWMagnakaiRulesetVersion, `
    Get-LWMagnakaiSectionRandomNumberContext, `
    Invoke-LWMagnakaiStorySectionAchievementTriggers, `
    Invoke-LWMagnakaiStorySectionTransitionAchievementTriggers, `
    Invoke-LWMagnakaiSectionEntryRules, `
    Invoke-LWMagnakaiStartingEquipment
