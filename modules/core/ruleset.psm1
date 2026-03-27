Set-StrictMode -Version Latest

function Get-LWActiveRuleSetName {
    param([object]$State = $null)

    if ($null -eq $State) {
        return 'Kai'
    }

    if ($State.PSObject.Properties['RuleSet'] -and -not [string]::IsNullOrWhiteSpace([string]$State.RuleSet)) {
        return [string]$State.RuleSet
    }

    return 'Kai'
}

function Get-LWActiveRuleSetVersion {
    param([object]$State = $null)

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { return (Get-LWKaiRulesetVersion) }
        default { return '1.0.0' }
    }
}

function Get-LWRuleSetSectionRandomNumberContext {
    param([object]$State = $null)

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { return (Get-LWKaiSectionRandomNumberContext -State $State) }
        default { return $null }
    }
}

function Invoke-LWRuleSetStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiStorySectionAchievementTriggers -State $State -Section $Section; return }
    }
}

function Invoke-LWRuleSetStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiStorySectionTransitionAchievementTriggers -State $State -FromSection $FromSection -ToSection $ToSection; return }
    }
}

function Invoke-LWRuleSetSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiSectionEntryRules -State $State; return }
    }
}

function Invoke-LWRuleSetStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [int]$BookNumber,
        [switch]$CarryExistingGear
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiStartingEquipment -State $State -BookNumber $BookNumber -CarryExistingGear:$CarryExistingGear; return }
    }
}

Export-ModuleMember -Function `
    Get-LWActiveRuleSetName, `
    Get-LWActiveRuleSetVersion, `
    Get-LWRuleSetSectionRandomNumberContext, `
    Invoke-LWRuleSetStorySectionAchievementTriggers, `
    Invoke-LWRuleSetStorySectionTransitionAchievementTriggers, `
    Invoke-LWRuleSetSectionEntryRules, `
    Invoke-LWRuleSetStartingEquipment
