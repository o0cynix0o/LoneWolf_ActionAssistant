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
        'magnakai' { return (Get-LWMagnakaiRulesetVersion) }
        default { return '1.0.0' }
    }
}

function Get-LWRuleSetSectionRandomNumberContext {
    param([object]$State = $null)

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { return (Get-LWKaiSectionRandomNumberContext -State $State) }
        'magnakai' { return (Get-LWMagnakaiSectionRandomNumberContext -State $State) }
        default { return $null }
    }
}

function Invoke-LWRuleSetSectionRandomNumberResolution {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object]$Context = $null,
        [int[]]$Rolls = @(),
        [int[]]$EffectiveRolls = @(),
        [int]$Subtotal = 0,
        [int]$AdjustedTotal = 0
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiSectionRandomNumberResolution -State $State -Context $Context -Rolls $Rolls -EffectiveRolls $EffectiveRolls -Subtotal $Subtotal -AdjustedTotal $AdjustedTotal; return }
        'magnakai' { Invoke-LWMagnakaiSectionRandomNumberResolution -State $State -Context $Context -Rolls $Rolls -EffectiveRolls $EffectiveRolls -Subtotal $Subtotal -AdjustedTotal $AdjustedTotal; return }
    }
}

function Invoke-LWRuleSetStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiStorySectionAchievementTriggers -State $State -Section $Section; return }
        'magnakai' { Invoke-LWMagnakaiStorySectionAchievementTriggers -State $State -Section $Section; return }
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
        'magnakai' { Invoke-LWMagnakaiStorySectionTransitionAchievementTriggers -State $State -FromSection $FromSection -ToSection $ToSection; return }
    }
}

function Invoke-LWRuleSetSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiSectionEntryRules -State $State; return }
        'magnakai' { Invoke-LWMagnakaiSectionEntryRules -State $State; return }
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
        'magnakai' { Invoke-LWMagnakaiStartingEquipment -State $State -BookNumber $BookNumber -CarryExistingGear:$CarryExistingGear; return }
    }
}

function Get-LWRuleSetCombatEncounterProfile {
    param([Parameter(Mandatory = $true)][object]$State)

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { return (Get-LWKaiCombatEncounterProfile -State $State) }
        'magnakai' { return (Get-LWMagnakaiCombatEncounterProfile -State $State) }
        default { return $null }
    }
}

function Invoke-LWRuleSetCombatScenarioRules {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][hashtable]$Scenario
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiCombatScenarioRules -State $State -Scenario $Scenario; return }
        'magnakai' { Invoke-LWMagnakaiCombatScenarioRules -State $State -Scenario $Scenario; return }
    }
}

Export-ModuleMember -Function `
    Get-LWActiveRuleSetName, `
    Get-LWActiveRuleSetVersion, `
    Get-LWRuleSetSectionRandomNumberContext, `
    Invoke-LWRuleSetSectionRandomNumberResolution, `
    Invoke-LWRuleSetStorySectionAchievementTriggers, `
    Invoke-LWRuleSetStorySectionTransitionAchievementTriggers, `
    Invoke-LWRuleSetSectionEntryRules, `
    Invoke-LWRuleSetStartingEquipment, `
    Get-LWRuleSetCombatEncounterProfile, `
    Invoke-LWRuleSetCombatScenarioRules
