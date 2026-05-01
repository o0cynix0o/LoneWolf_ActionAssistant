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

function Invoke-LWRuleSetCombatPsychicAttackRules {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][hashtable]$Scenario
    )

    switch ((Get-LWActiveRuleSetName -State $State).ToLowerInvariant()) {
        'kai' { Invoke-LWKaiCombatPsychicAttackRules -State $State -Scenario $Scenario; return }
        'magnakai' { Invoke-LWMagnakaiCombatPsychicAttackRules -State $State -Scenario $Scenario; return }
    }
}

function Get-LWBookSectionContextAchievementIds {
    param([int]$BookNumber)

    switch ($BookNumber) {
        1 { return @(Get-LWBookOneSectionContextAchievementIds) }
        2 { return @(Get-LWBookTwoSectionContextAchievementIds) }
        3 { return @(Get-LWBookThreeSectionContextAchievementIds) }
        4 { return @(Get-LWBookFourSectionContextAchievementIds) }
        5 { return @(Get-LWBookFiveSectionContextAchievementIds) }
        6 { return @(Get-LWBookSixSectionContextAchievementIds) }
        7 { return @(Get-LWBookSevenSectionContextAchievementIds) }
        8 { return @(Get-LWBookEightSectionContextAchievementIds) }
        default { return @() }
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
    Invoke-LWRuleSetCombatScenarioRules, `
    Invoke-LWRuleSetCombatPsychicAttackRules, `
    Get-LWBookSectionContextAchievementIds

function Add-LWDiscipline {
    param([string]$Name = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if (Test-LWStateIsMagnakaiRuleset -State $script:GameState) {
        Add-LWMagnakaiDiscipline -Name $Name
        return
    }

    Add-LWKaiDiscipline -Name $Name
}

Export-ModuleMember -Function Add-LWDiscipline

function Test-LWStateHasTinderbox {
    param([Parameter(Mandatory = $true)][object]$State)

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWTinderboxItemNames) -Type 'backpack')))
}

function Test-LWStateCanRelightTorch {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasFiresphere -State $State) {
        return $true
    }

    if (Test-LWStoryAchievementFlag -Name 'Book4TorchesWillNotLight') {
        return $false
    }

    return ((Test-LWStateHasTorch -State $State) -and (Test-LWStateHasTinderbox -State $State))
}

function Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem {
    param([string]$Reason = 'You lose one Weapon or weapon-like Special Item.')

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $choices = @()
    foreach ($weapon in @(Get-LWInventoryItems -Type 'weapon')) {
        $choices += [pscustomobject]@{ Type = 'weapon'; Name = [string]$weapon; Display = ("Weapon: {0}" -f [string]$weapon) }
    }

    foreach ($specialName in @((Get-LWSommerswerdItemNames) + (Get-LWMagicSpearItemNames))) {
        $matching = Get-LWMatchingStateInventoryItem -State $script:GameState -Names @($specialName) -Type 'special'
        if (-not [string]::IsNullOrWhiteSpace($matching)) {
            $choices += [pscustomobject]@{ Type = 'special'; Name = [string]$matching; Display = ("Special Item: {0}" -f [string]$matching) }
        }
    }

    if ($choices.Count -eq 0) {
        Write-LWWarn $Reason
        return
    }

    Write-LWPanelHeader -Title 'Choose Lost Weapon' -AccentColor 'DarkYellow'
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$choices[$i].Display) -TextColor 'Gray' -BulletColor 'Yellow'
    }

    $choiceIndex = if ($choices.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Lost item number' -Min 1 -Max $choices.Count }
    $choice = $choices[$choiceIndex - 1]
    [void](Remove-LWInventoryItemSilently -Type ([string]$choice.Type) -Name ([string]$choice.Name) -Quantity 1)
    Write-LWInfo ("{0} Lost: {1}." -f $Reason, [string]$choice.Name)
}

function New-LWSectionRandomNumberContext {
    param(
        [Parameter(Mandatory = $true)][int]$Section,
        [string]$Description = 'Plain random-number check.',
        [int]$Modifier = 0,
        [string[]]$ModifierNotes = @(),
        [int]$RollCount = 1,
        [string]$SequenceMode = 'combined',
        [bool]$ZeroCountsAsTen = $false,
        [bool]$Bypassed = $false,
        [string]$BypassReason = $null
    )

    return [pscustomobject]@{
        Section         = $Section
        Description     = $Description
        Modifier        = $Modifier
        ModifierNotes   = @($ModifierNotes)
        RollCount       = [Math]::Max(1, [int]$RollCount)
        SequenceMode    = [string]$SequenceMode
        ZeroCountsAsTen = $ZeroCountsAsTen
        Bypassed        = $Bypassed
        BypassReason    = $BypassReason
    }
}

function Write-LWCurrentSectionRandomNumberRoll {
    param(
        [Parameter(Mandatory = $true)][int]$Roll,
        [object]$State = $script:GameState
    )

    $context = Get-LWSectionRandomNumberContext -State $State
    if ($null -eq $context) {
        Write-LWInfo ("Random Number Table roll: {0}" -f $Roll)
        return
    }

    $bookNumber = if ($null -ne $State -and $null -ne $State.Character) { [int]$State.Character.BookNumber } else { 0 }

    if ([bool]$context.Bypassed) {
        Write-LWInfo ("Random Number Table roll: {0}" -f $Roll)
        Write-LWInfo ("Book {0} section {1}: {2}" -f $bookNumber, [int]$context.Section, [string]$context.BypassReason)
        return
    }

    $effectiveBase = [int]$Roll
    if ([bool]$context.ZeroCountsAsTen -and $effectiveBase -eq 0) {
        $effectiveBase = 10
    }
    $adjusted = $effectiveBase + [int]$context.Modifier

    Write-LWInfo ("Random Number Table roll: {0}" -f $Roll)
    if ([bool]$context.ZeroCountsAsTen -and $Roll -eq 0) {
        Write-LWInfo ("Book {0} section {1}: this check treats 0 as 10." -f $bookNumber, [int]$context.Section)
    }
    if ([int]$context.Modifier -ne 0) {
        Write-LWInfo ("Book {0} section {1} modifier {2}: {3}." -f $bookNumber, [int]$context.Section, (Format-LWSigned -Value ([int]$context.Modifier)), ($(if (@($context.ModifierNotes).Count -gt 0) { (@($context.ModifierNotes) -join '; ') } else { 'context rule' })))
    }
    else {
        Write-LWInfo ("Book {0} section {1}: no automatic modifier applies." -f $bookNumber, [int]$context.Section)
    }
    Write-LWInfo ("Book {0} section {1} adjusted total: {2}. {3}" -f $bookNumber, [int]$context.Section, $adjusted, [string]$context.Description)
    Invoke-LWRuleSetSectionRandomNumberResolution -State $State -Context $context -Rolls @([int]$Roll) -EffectiveRolls @($effectiveBase) -Subtotal $effectiveBase -AdjustedTotal $adjusted
}

function Write-LWCurrentSectionRandomNumberRollSequence {
    param(
        [Parameter(Mandatory = $true)][int[]]$Rolls,
        [object]$State = $script:GameState
    )

    $context = Get-LWSectionRandomNumberContext -State $State
    if ($null -eq $context) {
        Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
        return
    }

    $bookNumber = if ($null -ne $State -and $null -ne $State.Character) { [int]$State.Character.BookNumber } else { 0 }

    if ([bool]$context.Bypassed) {
        Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
        Write-LWInfo ("Book {0} section {1}: {2}" -f $bookNumber, [int]$context.Section, [string]$context.BypassReason)
        return
    }

    $effectiveRolls = @()
    foreach ($roll in @($Rolls)) {
        $effectiveRoll = [int]$roll
        if ([bool]$context.ZeroCountsAsTen -and $effectiveRoll -eq 0) {
            $effectiveRoll = 10
        }
        $effectiveRolls += $effectiveRoll
    }

    if ((Test-LWPropertyExists -Object $context -Name 'SequenceMode') -and [string]$context.SequenceMode -ieq 'independent') {
        Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
        if ([bool]$context.ZeroCountsAsTen -and (@($Rolls) | Where-Object { [int]$_ -eq 0 }).Count -gt 0) {
            Write-LWInfo ("Book {0} section {1}: this sequence treats any 0 roll as 10." -f $bookNumber, [int]$context.Section)
        }
        if ([int]$context.Modifier -ne 0) {
            Write-LWInfo ("Book {0} section {1} modifier {2}: {3}." -f $bookNumber, [int]$context.Section, (Format-LWSigned -Value ([int]$context.Modifier)), ($(if (@($context.ModifierNotes).Count -gt 0) { (@($context.ModifierNotes) -join '; ') } else { 'context rule' })))
        }
        else {
            Write-LWInfo ("Book {0} section {1}: no automatic modifier applies." -f $bookNumber, [int]$context.Section)
        }
        Write-LWInfo ("Book {0} section {1}: {2}" -f $bookNumber, [int]$context.Section, [string]$context.Description)
        Invoke-LWRuleSetSectionRandomNumberResolution -State $State -Context $context -Rolls @($Rolls) -EffectiveRolls @($effectiveRolls) -Subtotal 0 -AdjustedTotal 0
        return
    }

    $subtotal = ((@($effectiveRolls) | Measure-Object -Sum).Sum)
    $adjusted = [int]$subtotal + [int]$context.Modifier

    Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
    if ([bool]$context.ZeroCountsAsTen -and (@($Rolls) | Where-Object { [int]$_ -eq 0 }).Count -gt 0) {
        Write-LWInfo ("Book {0} section {1}: this check treats any 0 roll as 10." -f $bookNumber, [int]$context.Section)
    }

    Write-LWInfo ("Book {0} section {1} subtotal from {2} pick(s): {3}." -f $bookNumber, [int]$context.Section, @($Rolls).Count, $subtotal)
    if ([int]$context.Modifier -ne 0) {
        Write-LWInfo ("Book {0} section {1} modifier {2} applies once to the combined total: {3}." -f $bookNumber, [int]$context.Section, (Format-LWSigned -Value ([int]$context.Modifier)), ($(if (@($context.ModifierNotes).Count -gt 0) { (@($context.ModifierNotes) -join '; ') } else { 'context rule' })))
    }
    else {
        Write-LWInfo ("Book {0} section {1}: no automatic modifier applies." -f $bookNumber, [int]$context.Section)
    }
    Write-LWInfo ("Book {0} section {1} adjusted total: {2}. {3}" -f $bookNumber, [int]$context.Section, $adjusted, [string]$context.Description)
    Invoke-LWRuleSetSectionRandomNumberResolution -State $State -Context $context -Rolls @($Rolls) -EffectiveRolls @($effectiveRolls) -Subtotal $subtotal -AdjustedTotal $adjusted
}

function Invoke-LWCurrentSectionRandomNumberCheck {
    param([object]$State = $script:GameState)

    if ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.BookNumber -eq 6 -and [int]$State.CurrentSection -eq 284) {
        [void](Invoke-LWMagnakaiBookSixSection284BettingRound -State $State)
        return
    }

    $context = Get-LWSectionRandomNumberContext -State $State
    $rollCount = 1
    if ($null -ne $context -and (Test-LWPropertyExists -Object $context -Name 'RollCount') -and $null -ne $context.RollCount) {
        $rollCount = [Math]::Max(1, [int]$context.RollCount)
    }

    if ($rollCount -le 1) {
        Write-LWCurrentSectionRandomNumberRoll -Roll (Get-LWRandomDigit) -State $State
        return
    }

    $rolls = @()
    for ($index = 0; $index -lt $rollCount; $index++) {
        $rolls += (Get-LWRandomDigit)
    }
    Write-LWCurrentSectionRandomNumberRollSequence -Rolls $rolls -State $State
}

function Test-LWStateIsInKalte {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -eq 3)
}

function Get-LWStateHuntingMealRestrictionReason {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateIsInKalte -State $State) {
        return 'Hunting cannot be used for meals anywhere in Kalte (Book 3).'
    }

    if ([int]$State.Character.BookNumber -eq 2 -and [int]$State.CurrentSection -eq 346) {
        return 'Hunting cannot be used when instructed to eat a Meal on your journey through the Wildlands.'
    }

    if ([int]$State.Character.BookNumber -eq 4 -and @(
            25,
            129,
            171,
            185,
            269
        ) -contains [int]$State.CurrentSection) {
        return 'Hunting cannot be used for meals here in Book 4.'
    }

    if ([int]$State.Character.BookNumber -eq 5 -and [int]$State.CurrentSection -eq 320) {
        return 'Hunting cannot be used for meals in the middle of this wasteland.'
    }

    return $null
}

Export-ModuleMember -Function Test-LWStateHasTinderbox, Test-LWStateCanRelightTorch, Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem, New-LWSectionRandomNumberContext, Write-LWCurrentSectionRandomNumberRoll, Write-LWCurrentSectionRandomNumberRollSequence, Invoke-LWCurrentSectionRandomNumberCheck, Test-LWStateIsInKalte, Get-LWStateHuntingMealRestrictionReason

