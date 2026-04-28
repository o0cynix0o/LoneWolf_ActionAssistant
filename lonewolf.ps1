#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Load,
    [string]$SaveDir,
    [string]$DataDir
)

$script:LWBootstrapRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

$script:LWBootstrapModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\bootstrap.psm1'
if (-not (Test-Path -LiteralPath $script:LWBootstrapModulePath)) {
    throw "Bootstrap module not found at $script:LWBootstrapModulePath"
}

Import-Module $script:LWBootstrapModulePath -Force -DisableNameChecking
$script:LWShellModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\shell.psm1'
$script:LWDisplayModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\display.psm1'
$script:LWCommonModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\common.psm1'
$script:LWAchievementsModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\achievements.psm1'
$script:LWItemsModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\items.psm1'
$script:LWInventoryModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\inventory.psm1'
$script:LWStateModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\state.psm1'
$script:LWHealingModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\healing.psm1'
$script:LWSaveModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\save.psm1'
$script:LWCommandsModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\commands.psm1'
$script:LWCombatModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\combat.psm1'
$script:LWRulesetCoreModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\ruleset.psm1'
$script:LWKaiBook1ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book1.psm1'
$script:LWKaiBook2ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book2.psm1'
$script:LWKaiBook3ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book3.psm1'
$script:LWKaiBook4ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book4.psm1'
$script:LWKaiBook5ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book5.psm1'
$script:LWKaiCombatModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\combat.psm1'
$script:LWKaiRulesetModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\kai.psm1'
$script:LWMagnakaiBook6ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\book6.psm1'
$script:LWMagnakaiBook7ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\book7.psm1'
$script:LWMagnakaiCombatModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\combat.psm1'
$script:LWMagnakaiRulesetModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\magnakai.psm1'
foreach ($modulePath in @(
        $script:LWShellModulePath,
        $script:LWDisplayModulePath,
        $script:LWCommonModulePath,
        $script:LWAchievementsModulePath,
        $script:LWItemsModulePath,
        $script:LWInventoryModulePath,
        $script:LWStateModulePath,
        $script:LWHealingModulePath,
        $script:LWSaveModulePath,
        $script:LWCommandsModulePath,
        $script:LWCombatModulePath,
        $script:LWKaiBook1ModulePath,
        $script:LWKaiBook2ModulePath,
        $script:LWKaiBook3ModulePath,
        $script:LWKaiBook4ModulePath,
        $script:LWKaiBook5ModulePath,
        $script:LWKaiCombatModulePath,
        $script:LWKaiRulesetModulePath,
        $script:LWMagnakaiBook6ModulePath,
        $script:LWMagnakaiBook7ModulePath,
        $script:LWMagnakaiCombatModulePath,
        $script:LWMagnakaiRulesetModulePath,
        $script:LWRulesetCoreModulePath
    )) {
    if (-not (Test-Path -LiteralPath $modulePath)) {
        throw "Core module not found at $modulePath"
    }

    Import-Module $modulePath -Force -DisableNameChecking
}

$script:LWBootstrap = New-LWBootstrapConfiguration -ScriptRoot $PSScriptRoot -MyCommandPath $MyInvocation.MyCommand.Path -SaveDir $SaveDir -DataDir $DataDir

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:LWRootDir = $script:LWBootstrap.RootDir
$SaveDir = $script:LWBootstrap.SaveDir
$DataDir = $script:LWBootstrap.DataDir
$script:LWAppName = $script:LWBootstrap.AppName
$script:LWAppVersion = $script:LWBootstrap.AppVersion
$script:LWStateVersion = $script:LWBootstrap.StateVersion
$script:LastUsedSavePathFile = $script:LWBootstrap.LastUsedSavePathFile
$script:LWErrorLogFile = $script:LWBootstrap.ErrorLogFile
$script:GameState = $null
$script:GameData = $null
$script:LWContextGeneration = 0
$script:LWContextCache = $null
$script:LWStateSchemaVersion = 1
$script:LWUi = $script:LWBootstrap.UiState

function Test-LWDiscipline {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Test-LWHasState)) {
        return $false
    }

    return (Test-LWStateHasDiscipline -State $script:GameState -Name $Name)
}

function Test-LWStateHasDiscipline {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $target = [string]$Name
    if ([string]::IsNullOrWhiteSpace($target) -or $null -eq $State -or $null -eq $State.Character) {
        return $false
    }

    $kaiDisciplines = @($State.Character.Disciplines | ForEach-Object { [string]$_ })
    $magnakaiDisciplines = if ((Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiDisciplines') -and $null -ne $State.Character.MagnakaiDisciplines) {
        @($State.Character.MagnakaiDisciplines | ForEach-Object { [string]$_ })
    }
    else {
        @()
    }

    if ($kaiDisciplines -icontains $target) {
        return $true
    }
    if ($magnakaiDisciplines -icontains $target) {
        return $true
    }

    $isMagnakai = Test-LWStateIsMagnakaiRuleset -State $State
    $hasLegacyKai = (Test-LWPropertyExists -Object $State.Character -Name 'LegacyKaiComplete') -and [bool]$State.Character.LegacyKaiComplete
    if ($isMagnakai -and $hasLegacyKai -and ((Get-LWKnownKaiDisciplineNames) -icontains $target)) {
        return $true
    }

    switch -Regex ($target) {
        '^Healing$' {
            return ($magnakaiDisciplines -icontains 'Curing')
        }
        '^Hunting$' {
            return ($magnakaiDisciplines -icontains 'Huntmastery')
        }
        '^Mindshield$' {
            return ($magnakaiDisciplines -icontains 'Psi-screen')
        }
        '^Mindblast$' {
            return ($magnakaiDisciplines -icontains 'Psi-surge')
        }
        '^Weaponskill$' {
            return ($magnakaiDisciplines -icontains 'Weaponmastery')
        }
        '^Animal Kinship$' {
            return ($magnakaiDisciplines -icontains 'Animal Control')
        }
        '^Mind Over Matter$' {
            return ($magnakaiDisciplines -icontains 'Nexus')
        }
    }

    return $false
}

function Resolve-LWSectionExit {
    if (-not (Test-LWHasState)) {
        return 0
    }

    if ($script:GameState.SectionHealingResolved) {
        return 0
    }

    $restoredTotal = 0

    if ((Test-LWStateHasSectionHealing -State $script:GameState) -and -not $script:GameState.SectionHadCombat) {
        if ($script:GameState.Character.EnduranceCurrent -lt $script:GameState.Character.EnduranceMax) {
            $before = [int]$script:GameState.Character.EnduranceCurrent
            $healingResolution = Resolve-LWHealingRestoreAmount -RequestedAmount 1
            $script:GameState.Character.EnduranceCurrent += [int]$healingResolution.AppliedAmount
            if ($script:GameState.Character.EnduranceCurrent -gt $script:GameState.Character.EnduranceMax) {
                $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
            }
            $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
            Add-LWBookEnduranceDelta -Delta $restored
            if ($restored -gt 0) {
                $restoredTotal = $restored
                Register-LWHealingRestore -Amount $restored
                Write-LWInfo ("{0} restores 1 Endurance for a non-combat section." -f (Get-LWSectionHealingSourceLabel -State $script:GameState))
            }
            elseif (-not [string]::IsNullOrWhiteSpace([string]$healingResolution.Note)) {
                Write-LWWarn ([string]$healingResolution.Note)
            }
        }
    }

    $script:GameState.SectionHealingResolved = $true
    return [int]$restoredTotal
}

function Set-LWSection {
    param([Nullable[int]]$Section = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $newSection = if ($null -ne $Section) { [int]$Section } else { Read-LWInt -Prompt 'New section number' -Default $script:GameState.CurrentSection -Min 1 }
    if ($newSection -eq $script:GameState.CurrentSection) {
        Write-LWInfo "Still in section $newSection."
        return
    }

    $previousSection = [int]$script:GameState.CurrentSection
    Save-LWCurrentSectionCheckpoint
    $sectionExitHealingRestored = 0
    $previousSuppression = if (Test-Path Variable:\script:LWAchievementSyncSuppression) { $script:LWAchievementSyncSuppression } else { $null }
    $script:LWAchievementSyncSuppression = @{ section = $true; healing = $true }
    try {
        $sectionExitHealingRestored = [int](Resolve-LWSectionExit)
        Register-LWStorySectionTransitionAchievementTriggers -FromSection $previousSection -ToSection $newSection
        $script:GameState.CurrentSection = $newSection
        $script:GameState.SectionHadCombat = $false
        $script:GameState.SectionHealingResolved = $false
        Add-LWBookSectionVisit -Section $newSection
        [void](Sync-LWAchievements -Context 'section')
        if ($sectionExitHealingRestored -gt 0) {
            [void](Sync-LWAchievements -Context 'healing')
        }
        if ([int]$script:GameState.Character.BookNumber -eq 5) {
            if (-not (Invoke-LWBookFiveBloodPoisoningSectionDamage -Section $newSection)) {
                Write-LWInfo "Moved to section $newSection."
                Invoke-LWMaybeAutosave
                return
            }
        }
        Invoke-LWSectionEntryRules
        if (Test-LWDeathActive) {
            return
        }
        Write-LWInfo "Moved to section $newSection."
        Invoke-LWMaybeAutosave
    }
    finally {
        $script:LWAchievementSyncSuppression = $previousSuppression
    }
}

function Add-LWNote {
    param([string]$Text)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Text = Read-LWText -Prompt 'Note text'
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-LWWarn 'No note added.'
        return
    }

    $script:GameState.Character.Notes = @($script:GameState.Character.Notes) + $Text.Trim()
    Write-LWInfo 'Note added.'
    Invoke-LWMaybeAutosave
}

function Remove-LWNote {
    param([Parameter(Mandatory = $true)][int]$Index)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $notes = @($script:GameState.Character.Notes)
    if ($notes.Count -eq 0) {
        Write-LWWarn 'There are no notes to remove.'
        return
    }

    if ($Index -lt 1 -or $Index -gt $notes.Count) {
        Write-LWWarn "Note number must be between 1 and $($notes.Count)."
        return
    }

    $removedNote = [string]$notes[$Index - 1]
    $updatedNotes = @()
    for ($i = 0; $i -lt $notes.Count; $i++) {
        if ($i -ne ($Index - 1)) {
            $updatedNotes += $notes[$i]
        }
    }

    $script:GameState.Character.Notes = @($updatedNotes)
    Write-LWInfo "Removed note ${Index}: $removedNote"
    Invoke-LWMaybeAutosave
}

function Remove-LWNoteInteractive {
    param([string[]]$InputParts = @())

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Set-LWScreen -Name 'notes'
    $noteCount = @($script:GameState.Character.Notes).Count
    if ($noteCount -eq 0) {
        Write-LWWarn 'There are no notes to remove.'
        return
    }

    $index = 0
    $hasDirectIndex = $false
    if ($null -ne $InputParts) {
        $InputParts = @($InputParts)
        if ($InputParts.Count -gt 2 -and [int]::TryParse($InputParts[2], [ref]$index)) {
            $hasDirectIndex = $true
        }
    }

    if (-not $hasDirectIndex) {
        $index = Read-LWInt -Prompt 'Note number to remove' -Min 1 -Max $noteCount
    }

    Remove-LWNote -Index $index
}

function Update-LWGold {
    param([int]$Delta)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $oldValue = [int]$script:GameState.Inventory.GoldCrowns
    $newValue = $oldValue + $Delta
    if ($newValue -lt 0) {
        Write-LWWarn 'You cannot go below 0 Gold Crowns. Clamping to 0.'
        $newValue = 0
    }
    if ($newValue -gt 50) {
        Write-LWWarn 'Gold Crowns are capped at 50. Clamping to 50.'
        $newValue = 50
    }

    $script:GameState.Inventory.GoldCrowns = $newValue
    Add-LWBookGoldDelta -Delta ($newValue - $oldValue)
    [void](Sync-LWAchievements -Context 'gold')
    Write-LWInfo "Gold Crowns now $newValue."
    Invoke-LWMaybeAutosave
}

function Update-LWGoldInteractive {
    param([string[]]$InputParts = @())

    if ($null -eq $InputParts) {
        $InputParts = @()
    }
    else {
        $InputParts = @($InputParts)
    }

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($InputParts.Count -gt 1) {
        $delta = 0
        if ([int]::TryParse($InputParts[1], [ref]$delta)) {
            Update-LWGold -Delta $delta
            return
        }
    }

    $deltaText = Read-LWText -Prompt 'Gold change (example: 10 or -4)'
    $delta = 0
    if (-not [int]::TryParse($deltaText, [ref]$delta)) {
        Write-LWWarn 'Please enter a whole number, such as 10 or -4.'
        return
    }
    Update-LWGold -Delta $delta
}

function Update-LWQuiverArrows {
    param([Nullable[int]]$Delta = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if (-not (Test-LWStateHasQuiver -State $script:GameState)) {
        Write-LWWarn 'You are not carrying a Quiver.'
        return
    }

    if ($null -eq $Delta) {
        $Delta = Read-LWInt -Prompt 'Arrow change (+/-)' -Default 0
    }

    $requestedDelta = [int]$Delta
    $current = Sync-LWQuiverArrowState -State $script:GameState
    $capacity = Get-LWQuiverArrowCapacity
    $newValue = [Math]::Max(0, [Math]::Min(($current + $requestedDelta), $capacity))
    $actualDelta = $newValue - $current
    $script:GameState.Inventory.QuiverArrows = $newValue

    $message = "Quiver arrows changed by $(Format-LWSigned -Value $actualDelta). Now $(Format-LWQuiverArrowCounter -State $script:GameState)."
    if ($actualDelta -ne $requestedDelta) {
        $message += ' Adjustment was capped by 0 or quiver capacity.'
    }

    Write-LWInfo $message
    Invoke-LWMaybeAutosave
}

function Get-LWBackpackItemCount {
    param([Parameter(Mandatory = $true)][string]$Name)
    return (@($script:GameState.Inventory.BackpackItems | Where-Object { $_ -ieq $Name }).Count)
}

function Use-LWMeal {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if (Test-LWDiscipline -Name 'Hunting') {
        $huntingRestrictionReason = Get-LWStateHuntingMealRestrictionReason -State $script:GameState
        if (-not [string]::IsNullOrWhiteSpace($huntingRestrictionReason)) {
            Write-LWInfo $huntingRestrictionReason
        }
        else {
            $isWasteland = Read-LWYesNo -Prompt 'Are you in a wasteland or desert where Hunting does not help?' -Default $false
            if (-not $isWasteland) {
                Register-LWMealCoveredByHunting
                Write-LWInfo 'Hunting covers the meal. No backpack item spent.'
                return
            }
        }
    }

    if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack, so you cannot eat stored meals right now.'
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'starvation'
        $appliedLoss = [int]$lossResolution.AppliedLoss
        if ($appliedLoss -gt 0) {
            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ([int]$script:GameState.Character.EnduranceCurrent - $appliedLoss))
            Add-LWBookEnduranceDelta -Delta (-$appliedLoss)
        }
        Register-LWStarvationPenalty
        $message = if ($appliedLoss -gt 0) { "No meal available. Lose $appliedLoss ENDURANCE." } else { 'No meal available, but your current mode prevents the ENDURANCE loss.' }
        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
            $message += " $($lossResolution.Note)"
        }
        Write-LWInfo $message
        Write-LWInfo "Endurance now $($script:GameState.Character.EnduranceCurrent)."
        if (Invoke-LWFatalEnduranceCheck -Cause 'Starved to death after failing to find a meal.') {
            return
        }
        Invoke-LWMaybeAutosave
        return
    }

    if ((Get-LWBackpackItemCount -Name 'Meal') -gt 0) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 1)
        Register-LWMealConsumed
        Write-LWInfo 'Meal consumed.'
        Invoke-LWMaybeAutosave
        return
    }

    $specialRationsName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSpecialRationsItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($specialRationsName)) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $specialRationsName -Quantity 1)
        Register-LWMealConsumed
        Write-LWInfo 'Special Rations consumed.'
        Invoke-LWMaybeAutosave
        return
    }

    $laumspurHerbName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWLaumspurHerbItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($laumspurHerbName)) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $laumspurHerbName -Quantity 1)
        Register-LWMealConsumed
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ([int]$script:GameState.Character.EnduranceCurrent + 3))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
            Write-LWInfo ("Laumspur Herb satisfies the meal and restores {0} ENDURANCE." -f $restored)
        }
        else {
            Write-LWInfo 'Laumspur Herb satisfies the meal.'
        }
        Invoke-LWMaybeAutosave
        return
    }

    $mealOfLaumspurName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMealOfLaumspurItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($mealOfLaumspurName)) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $mealOfLaumspurName -Quantity 1)
        Register-LWMealConsumed
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ([int]$script:GameState.Character.EnduranceCurrent + 3))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
            Write-LWInfo ("Meal of Laumspur satisfies the meal and restores {0} ENDURANCE." -f $restored)
        }
        else {
            Write-LWInfo 'Meal of Laumspur satisfies the meal.'
        }
        Invoke-LWMaybeAutosave
        return
    }

    Write-LWWarn 'No Meal available. Lose 3 Endurance.'
    Register-LWStarvationPenalty
    $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'starvation'
    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent -= [int]$lossResolution.AppliedLoss
    if ($script:GameState.Character.EnduranceCurrent -lt 0) {
        $script:GameState.Character.EnduranceCurrent = 0
    }
    Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
    if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
        Write-LWInfo ([string]$lossResolution.Note)
    }
    Write-LWInfo "Endurance now $($script:GameState.Character.EnduranceCurrent)."
    if (Invoke-LWFatalEnduranceCheck -Cause 'Starved to death after failing to find a meal.') {
        return
    }
    Invoke-LWMaybeAutosave
}

function Set-LWCombatMode {
    param([string]$Mode = '')

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($Mode)) {
        $Mode = Read-LWText -Prompt 'Combat mode (ManualCRT/DataFile)' -Default $script:GameState.Settings.CombatMode
    }

    switch ($Mode.Trim().ToLowerInvariant()) {
        'manualcrt' {
            $script:GameState.Settings.CombatMode = 'ManualCRT'
            Write-LWInfo 'Combat mode set to ManualCRT.'
        }
        'manual' {
            $script:GameState.Settings.CombatMode = 'ManualCRT'
            Write-LWInfo 'Combat mode set to ManualCRT.'
        }
        'datafile' {
            $validation = Get-LWCRTValidation
            if (-not $validation.Present -or $validation.UsableEntryCount -eq 0) {
                Write-LWWarn 'No usable data/crt.json found. Staying in ManualCRT mode.'
                return
            }
            $script:GameState.Settings.CombatMode = 'DataFile'
            Write-LWInfo 'Combat mode set to DataFile.'
            foreach ($message in @($validation.Messages)) {
                Write-LWWarn $message
            }
        }
        'data' {
            $validation = Get-LWCRTValidation
            if (-not $validation.Present -or $validation.UsableEntryCount -eq 0) {
                Write-LWWarn 'No usable data/crt.json found. Staying in ManualCRT mode.'
                return
            }
            $script:GameState.Settings.CombatMode = 'DataFile'
            Write-LWInfo 'Combat mode set to DataFile.'
            foreach ($message in @($validation.Messages)) {
                Write-LWWarn $message
            }
        }
        default {
            Write-LWWarn 'Mode must be ManualCRT or DataFile.'
            return
        }
    }

    Invoke-LWMaybeAutosave
}

function Set-LWRunDifficulty {
    param([string]$Difficulty = '')

    if (-not (Test-LWHasState)) {
        Set-LWScreen -Name 'modes'
        Write-LWWarn 'Difficulty is chosen when a new run begins.'
        return
    }

    $currentDifficulty = Get-LWCurrentDifficulty
    if ([string]::IsNullOrWhiteSpace($Difficulty)) {
        Show-LWRunDifficulty
        return
    }

    $normalized = Get-LWNormalizedDifficultyName -Difficulty $Difficulty
    Set-LWScreen -Name 'modes'
    if ($normalized -eq $currentDifficulty) {
        Write-LWInfo ("Difficulty remains {0} for this run." -f $currentDifficulty)
        return
    }

    Write-LWWarn ("Difficulty is locked to {0} for this run. Start a newrun to choose {1}." -f $currentDifficulty, $normalized)
}

function Set-LWRunPermadeath {
    param([string]$Value = '')

    if (-not (Test-LWHasState)) {
        Set-LWScreen -Name 'modes'
        Write-LWWarn 'Permadeath is chosen when a new run begins.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Show-LWRunPermadeath
        return
    }

    $target = $Value.Trim().ToLowerInvariant()
    $targetEnabled = @('on', 'true', 'yes', 'y', '1') -contains $target
    $targetDisabled = @('off', 'false', 'no', 'n', '0') -contains $target
    Set-LWScreen -Name 'modes'

    if (-not $targetEnabled -and -not $targetDisabled) {
        Write-LWWarn 'Permadeath must be on or off.'
        return
    }

    if ((Test-LWPermadeathEnabled) -and $targetDisabled) {
        Write-LWWarn 'Permadeath is locked on for this run and cannot be turned off.'
        return
    }

    if (-not (Test-LWPermadeathEnabled) -and $targetEnabled) {
        Write-LWWarn 'Permadeath can only be enabled when starting a new run.'
        return
    }

    Write-LWInfo ("Permadeath remains {0} for this run." -f $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }))
}

function Set-LWCombatSkillBase {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $value = Read-LWInt -Prompt 'New base Combat Skill' -Default $script:GameState.Character.CombatSkillBase -Min 0
    $script:GameState.Character.CombatSkillBase = $value
    Write-LWInfo "Base Combat Skill set to $value."
    Invoke-LWMaybeAutosave
}

function Set-LWEndurance {
    param([Nullable[int]]$Current = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $Current) {
        $Current = Read-LWInt -Prompt 'Current Endurance' -Default $script:GameState.Character.EnduranceCurrent -Min 0 -Max $script:GameState.Character.EnduranceMax
    }

    $oldCurrent = [int]$script:GameState.Character.EnduranceCurrent
    $newCurrent = [Math]::Max(0, [Math]::Min([int]$Current, [int]$script:GameState.Character.EnduranceMax))
    $script:GameState.Character.EnduranceCurrent = $newCurrent
    if ($newCurrent -gt $oldCurrent) {
        Register-LWManualRecoveryShortcut
    }
    Write-LWInfo "Current Endurance set to $newCurrent / $($script:GameState.Character.EnduranceMax)."
    if (Invoke-LWFatalEnduranceCheck -Cause 'Current Endurance was set to zero.') {
        return
    }
    Invoke-LWMaybeAutosave
}

function Update-LWEndurance {
    param([Nullable[int]]$Delta = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $Delta) {
        $Delta = Read-LWInt -Prompt 'Endurance change (+/-)' -Default 0
    }

    $current = [int]$script:GameState.Character.EnduranceCurrent
    $max = [int]$script:GameState.Character.EnduranceMax
    $requestedDelta = [int]$Delta
    $lossResolution = $null
    $effectiveDelta = $requestedDelta
    if ($requestedDelta -lt 0) {
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss ([Math]::Abs($requestedDelta)) -Source 'manualdamage'
        $effectiveDelta = -[int]$lossResolution.AppliedLoss
    }

    $newCurrent = [Math]::Max(0, [Math]::Min(($current + $effectiveDelta), $max))
    $actualDelta = $newCurrent - $current
    $script:GameState.Character.EnduranceCurrent = $newCurrent
    Add-LWBookEnduranceDelta -Delta $actualDelta
    if ($actualDelta -gt 0) {
        Register-LWManualRecoveryShortcut
    }

    $message = "Current Endurance changed by $(Format-LWSigned -Value $actualDelta). Now $newCurrent / $max."
    if ($null -ne $lossResolution -and -not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
        $message += " $($lossResolution.Note)"
    }
    if ($actualDelta -ne $requestedDelta) {
        $message += ' Adjustment was capped by 0 or max END.'
    }

    Write-LWInfo $message
    if (Invoke-LWFatalEnduranceCheck -Cause 'Endurance has fallen to zero.') {
        return
    }
    Invoke-LWMaybeAutosave
}

function Set-LWMaxEndurance {
    param([Nullable[int]]$Max = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $Max) {
        $Max = Read-LWInt -Prompt 'Maximum Endurance' -Default $script:GameState.Character.EnduranceMax -Min 1
    }

    $oldMax = [int]$script:GameState.Character.EnduranceMax
    $oldCurrent = [int]$script:GameState.Character.EnduranceCurrent
    $newMax = [Math]::Max(1, [int]$Max)
    $script:GameState.Character.EnduranceMax = $newMax
    if ($script:GameState.Character.EnduranceCurrent -gt $newMax) {
        $script:GameState.Character.EnduranceCurrent = $newMax
    }
    if ($newMax -gt $oldMax -or [int]$script:GameState.Character.EnduranceCurrent -gt $oldCurrent) {
        Register-LWManualRecoveryShortcut
    }

    Write-LWInfo "Maximum Endurance set to $newMax. Current Endurance: $($script:GameState.Character.EnduranceCurrent) / $newMax."
    Invoke-LWMaybeAutosave
}

function Complete-LWBook {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $currentBook = [int]$script:GameState.Character.BookNumber
    $stats = Ensure-LWCurrentBookStats
    $bookSummary = New-LWBookHistoryEntry -Stats $stats
    $nextBook = $currentBook + 1
    $nextBookLabel = if ($currentBook -lt 7) { Format-LWBookLabel -BookNumber $nextBook -IncludePrefix } else { '' }
    $completionSnapshot = [pscustomobject]@{
        RuleSet          = [string]$script:GameState.RuleSet
        Difficulty       = Get-LWCurrentDifficulty
        RunIntegrityState = [string]$script:GameState.Run.IntegrityState
        CombatMode       = [string]$script:GameState.Settings.CombatMode
        GoldCrowns       = [int]$script:GameState.Inventory.GoldCrowns
        EnduranceCurrent = [int]$script:GameState.Character.EnduranceCurrent
        EnduranceMax     = [int]$script:GameState.Character.EnduranceMax
        NotesCount       = @($script:GameState.Character.Notes).Count
    }

    if (@($script:GameState.Character.CompletedBooks) -notcontains $currentBook) {
        $script:GameState.Character.CompletedBooks = @($script:GameState.Character.CompletedBooks) + $currentBook
    }
    $script:GameState.BookHistory = @($script:GameState.BookHistory) + $bookSummary
    [void](Sync-LWAchievements -Context 'bookcomplete' -Data $bookSummary)

    Set-LWScreen -Name 'bookcomplete' -Data ([pscustomobject]@{
            Summary       = $bookSummary
            CharacterName = $script:GameState.Character.Name
            Snapshot      = $completionSnapshot
            ContinueToBookLabel = $nextBookLabel
        })

    if ($currentBook -ge 7) {
        $script:GameState.Run.Status = 'Completed'
        $script:GameState.Run.CompletedOn = (Get-Date).ToString('o')
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
        Clear-LWDeathState
        Write-LWInfo ("Book {0} complete. The current Magnakai campaign is now complete." -f $currentBook)
        Invoke-LWMaybeAutosave
        return
    }

    if ($script:LWUi.Enabled) {
        Refresh-LWScreen
        [void](Read-LWText -Prompt ("Press Enter to continue to {0} setup" -f $nextBookLabel) -NoRefresh)
        Set-LWScreen -Name 'sheet'
    }

    $nextBookStartSection = 1
    $script:GameState.Character.BookNumber = $nextBook
    if (Test-LWShouldRestoreEnduranceOnBookTransition -State $script:GameState) {
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    }
    $script:GameState.CurrentSection = $nextBookStartSection
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Clear-LWDeathState
    Reset-LWCurrentBookStats -BookNumber $nextBook -StartSection $nextBookStartSection
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Write-LWInfo "Advanced to $nextBookLabel. Current section reset to $nextBookStartSection."

    if ($nextBook -le 5) {
        $owned = @($script:GameState.Character.Disciplines)
        $availableNames = @($script:GameData.KaiDisciplines | ForEach-Object { $_.Name })
        if ($owned.Count -lt $availableNames.Count) {
            if (Read-LWYesNo -Prompt ("Choose your bonus Kai Discipline for {0} now?" -f $nextBookLabel) -Default $true) {
                $newDiscName = $null
                $newDiscSelection = @(Select-LWKaiDisciplines -Count 1 -Exclude $owned)
                if ($newDiscSelection.Count -gt 0) {
                    $newDiscName = [string]$newDiscSelection[0]
                    $script:GameState.Character.Disciplines = @($owned + $newDiscName)
                    Write-LWInfo "Added discipline: $newDiscName."
                }

                if ($newDiscName -eq 'Weaponskill' -and [string]::IsNullOrWhiteSpace($script:GameState.Character.WeaponskillWeapon)) {
                    $weaponRoll = Get-LWRandomDigit
                    $weaponName = Get-LWWeaponskillWeapon -Roll $weaponRoll
                    $script:GameState.Character.WeaponskillWeapon = $weaponName
                    Write-LWInfo "Weaponskill roll: $weaponRoll -> $weaponName"
                }
            }
        }
        else {
            Write-LWInfo 'All Kai Disciplines are already owned.'
        }
    }
    else {
        $script:GameState.RuleSet = 'Magnakai'
        $script:GameState.Character.LegacyKaiComplete = $true
        if (-not $script:GameState.Character.MagnakaiRank -or [int]$script:GameState.Character.MagnakaiRank -lt 3) {
            $script:GameState.Character.MagnakaiRank = 3
        }
    }

    if ($currentBook -eq 4 -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Restore-LWBackpackState -WriteMessages
        Write-LWInfo 'Book 4 completed without a Backpack recovery. An empty Backpack is restored for the next book.'
    }

    if ($nextBook -eq 2) {
        Apply-LWBookTwoStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 3) {
        Apply-LWBookThreeStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 4) {
        Apply-LWBookFourStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 5) {
        Apply-LWBookFiveStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 6) {
        Apply-LWBookSixStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 7) {
        Apply-LWBookSevenStartingEquipment -CarryExistingGear
    }

    Invoke-LWMaybeAutosave
}

function Invoke-LWCombatPotionRound {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return $null
    }

    if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and -not [bool]$script:GameState.Combat.CombatPotionsAllowed) {
        Write-LWWarn 'Potions cannot be used in this combat.'
        return $null
    }

    if (-not (Test-LWCombatHerbPouchOptionActive -State $script:GameState)) {
        Write-LWWarn 'Combat potion use is only available in Book 6 with DE Curing Option 3 and a carried Herb Pouch.'
        return $null
    }

    $choice = Select-LWHealingPotionChoice -State $script:GameState -HerbPouchOnly
    if ($null -eq $choice) {
        return $null
    }

    Write-LWInfo ("Herb Pouch action: using {0} instead of attacking this round." -f [string]$choice.Name)
    return (Invoke-LWCombatRound -IgnoreEnemyLossThisRound -PotionChoice $choice)
}

function Select-LWRunConfiguration {
    param(
        [string]$DefaultDifficulty = 'Normal',
        [bool]$DefaultPermadeath = $false
    )

    $definitions = @(Get-LWDifficultyDefinitions)
    $selectedDifficulty = Get-LWNormalizedDifficultyName -Difficulty $DefaultDifficulty
    $selectedPermadeath = [bool]$DefaultPermadeath

    while ($true) {
        $defaultIndex = 1
        for ($i = 0; $i -lt $definitions.Count; $i++) {
            if ([string]$definitions[$i].Name -eq $selectedDifficulty) {
                $defaultIndex = $i + 1
                break
            }
        }

        Set-LWScreen -Name 'modes' -Data ([pscustomobject]@{
                View       = 'setup'
                Difficulty = $selectedDifficulty
                Permadeath = $selectedPermadeath
            })

        $selection = Read-LWInt -Prompt 'Difficulty number' -Default $defaultIndex -Min 1 -Max $definitions.Count
        $selectedDifficulty = [string]$definitions[$selection - 1].Name

        if ($selectedDifficulty -eq 'Story') {
            $selectedPermadeath = $false
        }
        else {
            Set-LWScreen -Name 'modes' -Data ([pscustomobject]@{
                    View       = 'setup'
                    Difficulty = $selectedDifficulty
                    Permadeath = $selectedPermadeath
                })
            $selectedPermadeath = Read-LWYesNo -Prompt 'Enable Permadeath for this run?' -Default $selectedPermadeath
        }

        Set-LWScreen -Name 'modes' -Data ([pscustomobject]@{
                View       = 'confirm'
                Difficulty = $selectedDifficulty
                Permadeath = $selectedPermadeath
            })
        if (Read-LWYesNo -Prompt 'Start this run with these mode settings?' -Default $true) {
            return [pscustomobject]@{
                Difficulty = $selectedDifficulty
                Permadeath = $selectedPermadeath
            }
        }
    }
}

function Test-LWShouldRestoreEnduranceOnBookTransition {
    param([object]$State = $script:GameState)

    $difficulty = Get-LWCurrentDifficulty -State $State
    return (@('Story', 'Easy') -contains [string]$difficulty)
}

function Start-LWNewGameCore {
    param(
        [switch]$PreserveProfile
    )

    $preservedAchievements = $null
    $preservedRunHistory = @()
    $preservedSettings = $null
    $defaultName = 'Lone Wolf'

    if ($PreserveProfile -and (Test-LWHasState)) {
        $defaultName = if ([string]::IsNullOrWhiteSpace([string]$script:GameState.Character.Name)) { 'Lone Wolf' } else { [string]$script:GameState.Character.Name }
        $preservedAchievements = $script:GameState.Achievements
        $preservedRunHistory = @($script:GameState.RunHistory)
        $preservedRunHistory += @(New-LWRunArchiveEntry -State $script:GameState -Status 'Retired')
        $preservedSettings = [pscustomobject]@{
            CombatMode = [string]$script:GameState.Settings.CombatMode
            SavePath   = [string]$script:GameState.Settings.SavePath
            AutoSave   = [bool]$script:GameState.Settings.AutoSave
            DataDir    = [string]$script:GameState.Settings.DataDir
        }
    }

    $runConfig = Select-LWRunConfiguration -DefaultDifficulty 'Normal' -DefaultPermadeath $false
    if ($null -eq $runConfig) {
        return
    }

    Set-LWHostGameState -State (New-LWDefaultState) | Out-Null
    if ($PreserveProfile -and $null -ne $preservedAchievements) {
        $script:GameState.Achievements = $preservedAchievements
        $script:GameState.RunHistory = @($preservedRunHistory)
        if ($null -ne $preservedSettings) {
            $script:GameState.Settings.CombatMode = [string]$preservedSettings.CombatMode
            $script:GameState.Settings.SavePath = [string]$preservedSettings.SavePath
            $script:GameState.Settings.AutoSave = [bool]$preservedSettings.AutoSave
            $script:GameState.Settings.DataDir = [string]$preservedSettings.DataDir
        }
    }
    else {
        $script:GameState.Settings.CombatMode = (Get-LWDefaultCombatMode)
    }

    $script:GameState.Run = (New-LWRunState -Difficulty ([string]$runConfig.Difficulty) -Permadeath ([bool]$runConfig.Permadeath))
    Set-LWScreen -Name 'sheet'

    $name = Read-LWText -Prompt 'Character name' -Default $defaultName
    $bookNumber = Read-LWInt -Prompt 'Current book number' -Default 1 -Min 1 -Max 7
    $startSection = Read-LWInt -Prompt 'Starting section' -Default 1 -Min 1

    $csRoll = Get-LWRandomDigit
    $endRoll = Get-LWRandomDigit
    $combatSkill = 10 + $csRoll
    $endurance = 20 + $endRoll

    Write-LWInfo "Combat Skill roll: $csRoll -> $combatSkill"
    Write-LWInfo "Endurance roll: $endRoll -> $endurance"

    $script:GameState.Character.Name = $name
    $script:GameState.Character.BookNumber = $bookNumber
    $script:GameState.Character.CombatSkillBase = $combatSkill
    $script:GameState.Character.EnduranceCurrent = $endurance
    $script:GameState.Character.EnduranceMax = $endurance
    $script:GameState.CurrentSection = $startSection

    if ($bookNumber -ge 6) {
        $script:GameState.RuleSet = 'Magnakai'
        $script:GameState.Character.LegacyKaiComplete = $true
        $requiredMagnakaiCount = [Math]::Min(10, [Math]::Max(3, ($bookNumber - 3)))
        $magnakaiDisciplines = Select-LWMagnakaiDisciplines -Count $requiredMagnakaiCount
        $script:GameState.Character.MagnakaiDisciplines = @($magnakaiDisciplines)
        $script:GameState.Character.MagnakaiRank = $requiredMagnakaiCount
        if ($magnakaiDisciplines -contains 'Weaponmastery') {
            $script:GameState.Character.WeaponmasteryWeapons = @(Select-LWWeaponmasteryWeapons -Count $requiredMagnakaiCount)
            Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
        }
        Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages
    }
    else {
        $disciplines = Select-LWKaiDisciplines -Count 5
        $weaponskillWeapon = $null
        if ($disciplines -contains 'Weaponskill') {
            $weaponRoll = Get-LWRandomDigit
            $weaponskillWeapon = Get-LWWeaponskillWeapon -Roll $weaponRoll
            Write-LWInfo "Weaponskill roll: $weaponRoll -> $weaponskillWeapon"
        }

        $script:GameState.Character.Disciplines = $disciplines
        $script:GameState.Character.WeaponskillWeapon = $weaponskillWeapon
    }

    if ($bookNumber -eq 1) {
        Apply-LWBookOneStartingEquipment
    }
    elseif ($bookNumber -eq 2) {
        Apply-LWBookTwoStartingEquipment
    }
    elseif ($bookNumber -eq 3) {
        Apply-LWBookThreeStartingEquipment
    }
    elseif ($bookNumber -eq 4) {
        Apply-LWBookFourStartingEquipment
    }
    elseif ($bookNumber -eq 5) {
        Apply-LWBookFiveStartingEquipment
    }
    elseif ($bookNumber -eq 6) {
        Apply-LWBookSixStartingEquipment
    }
    elseif ($bookNumber -eq 7) {
        Apply-LWBookSevenStartingEquipment
    }
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Clear-LWDeathState
    Reset-LWCurrentBookStats -BookNumber $bookNumber -StartSection $startSection
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Sync-LWRunIntegrityState -State $script:GameState -Reseal
    Warm-LWRuntimeCaches

    Write-LWInfo ("New {0} run created." -f [string]$script:GameState.Run.Difficulty)
    if (Test-LWPermadeathEnabled) {
        Write-LWWarn 'Permadeath is locked on for this run.'
    }

    if ($PreserveProfile -and $null -ne $preservedSettings -and -not [string]::IsNullOrWhiteSpace([string]$preservedSettings.SavePath)) {
        Save-LWGame
    }
    else {
        if (Read-LWYesNo -Prompt 'Set a default save path now?' -Default $true) {
            Save-LWGame -PromptForPath
            if (Read-LWYesNo -Prompt 'Enable autosave after state changes?' -Default $true) {
                $script:GameState.Settings.AutoSave = $true
                Write-LWInfo 'Autosave enabled.'
            }
        }
    }

    Set-LWScreen -Name 'sheet'
}

function New-LWGame {
    Start-LWNewGameCore
}

function New-LWRun {
    if ((Test-LWHasState) -and -not (Read-LWYesNo -Prompt 'Archive the current run and start a fresh one on this same profile?' -Default $true)) {
        Write-LWWarn 'newrun cancelled.'
        return
    }

    Start-LWNewGameCore -PreserveProfile
}

function Invoke-LWMaybeAutosave {
    if (-not (Test-LWHasState)) {
        return
    }
    Sync-LWCurrentSectionCheckpoint
    if ($script:GameState.Settings.AutoSave -and -not [string]::IsNullOrWhiteSpace($script:GameState.Settings.SavePath)) {
        Save-LWGame
    }
}

function Start-LWTerminal {
    $script:LWUi.Enabled = $true
    Set-LWScreen -Name 'welcome'
    Clear-LWNotifications

    if (-not [string]::IsNullOrWhiteSpace($Load)) {
        Load-LWGame -Path $Load
    }
    else {
        Set-LWHostGameState -State (New-LWDefaultState) | Out-Null
        Set-LWScreen -Name 'welcome'
        Write-LWInfo 'No save loaded. Use new to create a character or load to open a save file.'
    }

    while ($true) {
        $line = ''
        try {
            Refresh-LWScreen
            Write-LWCommandPromptHint
            $line = Read-LWPromptLine -Prompt 'lw' -ReturnNullOnEof
            if ($null -eq $line) {
                break
            }
            $result = Invoke-LWCommand -InputLine $line
            if ($result -eq 'quit') {
                break
            }
        }
        catch {
            $logPath = Write-LWCrashLog -ErrorRecord $_ -InputLine $line -Stage 'main-loop'
            Write-LWError ("The assistant hit an unexpected error and wrote details to {0}. You can keep playing after this screen refresh." -f $logPath)
        }
    }

    $script:LWUi.Enabled = $false
    Write-LWInfo 'Good luck on the Kai trail.'
}

function Get-LWModuleContext {
    if ($null -eq $script:LWContextCache) {
        $script:LWContextCache = @{
            LWRootDir                      = $script:LWRootDir
            SaveDir                        = $SaveDir
            DataDir                        = $DataDir
            LWAppName                      = $script:LWAppName
            LWAppVersion                   = $script:LWAppVersion
            LWStateVersion                 = $script:LWStateVersion
            LastUsedSavePathFile           = $script:LastUsedSavePathFile
            LWErrorLogFile                 = $script:LWErrorLogFile
            GameState                      = $script:GameState
            GameData                       = $script:GameData
            LWUi                           = $script:LWUi
            CanonicalInventoryItemResolver = ${function:Get-LWCanonicalInventoryItemName}
            _Generation                    = $script:LWContextGeneration
        }
    }
    else {
        $script:LWContextCache.GameState = $script:GameState
        $script:LWContextCache.GameData = $script:GameData
        $script:LWContextCache['_Generation'] = $script:LWContextGeneration
    }

    return $script:LWContextCache
}

function Set-LWHostGameState {
    param([object]$State)

    $script:GameState = $State
    $script:LWContextGeneration++
    return $script:GameState
}

function Set-LWHostGameData {
    param([object]$Data)

    $script:GameData = $Data
    $script:LWContextGeneration++
    return $script:GameData
}

function Sync-LWStateRefactorMetadata {
    param([object]$State)

    if ($null -eq $State) {
        return $null
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'RuleSet') -or [string]::IsNullOrWhiteSpace([string]$State.RuleSet)) {
        $State | Add-Member -Force -NotePropertyName RuleSet -NotePropertyValue 'Kai'
    }

    $rulesetVersion = Get-LWActiveRuleSetVersion -State $State
    if (-not (Test-LWPropertyExists -Object $State -Name 'EngineVersion')) {
        $State | Add-Member -Force -NotePropertyName EngineVersion -NotePropertyValue $script:LWAppVersion
    }
    else {
        $State.EngineVersion = $script:LWAppVersion
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'RuleSetVersion')) {
        $State | Add-Member -Force -NotePropertyName RuleSetVersion -NotePropertyValue $rulesetVersion
    }
    else {
        $State.RuleSetVersion = $rulesetVersion
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'StateSchemaVersion')) {
        $State | Add-Member -Force -NotePropertyName StateSchemaVersion -NotePropertyValue $script:LWStateSchemaVersion
    }
    else {
        $State.StateSchemaVersion = $script:LWStateSchemaVersion
    }

    return $State
}

function Test-LWStateFastNormalizeEligible {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$SourceEngineVersion = ''
    )

    if ($null -eq $State -or [string]$SourceEngineVersion -ne $script:LWAppVersion) {
        return $false
    }

    $requiredRootProperties = @(
        'Character',
        'Inventory',
        'Combat',
        'Settings',
        'Run',
        'RunHistory',
        'Achievements',
        'CurrentBookStats',
        'DeathState',
        'DeathHistory',
        'Storage',
        'RecoveryStash',
        'Conditions',
        'EquipmentBonuses',
        'SectionCheckpoints',
        'EngineVersion',
        'RuleSetVersion'
    )
    foreach ($propertyName in $requiredRootProperties) {
        if (-not (Test-LWPropertyExists -Object $State -Name $propertyName) -or $null -eq $State.$propertyName) {
            return $false
        }
    }

    $rulesetVersion = Get-LWActiveRuleSetVersion -State $State
    if ([string]$State.RuleSetVersion -ne $rulesetVersion) {
        return $false
    }

    if ((Test-LWPropertyExists -Object $State -Name 'StateSchemaVersion') -and $null -ne $State.StateSchemaVersion) {
        return ([int]$State.StateSchemaVersion -ge $script:LWStateSchemaVersion)
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'SchemaVersion') -or
        -not (Test-LWPropertyExists -Object $State.Achievements -Name 'LoadBackfillVersion') -or
        [int]$State.Achievements.SchemaVersion -lt (Get-LWAchievementStateSchemaVersion) -or
        [int]$State.Achievements.LoadBackfillVersion -lt (Get-LWAchievementLoadBackfillVersion)) {
        return $false
    }

    $requiredCharacterProperties = @(
        'MagnakaiDisciplines',
        'WeaponmasteryWeapons',
        'LoreCirclesCompleted',
        'ImprovedDisciplines',
        'LegacyKaiComplete'
    )
    foreach ($propertyName in $requiredCharacterProperties) {
        if (-not (Test-LWPropertyExists -Object $State.Character -Name $propertyName) -or $null -eq $State.Character.$propertyName) {
            return $false
        }
    }

    $requiredInventoryProperties = @(
        'BackpackItems',
        'HerbPouchItems',
        'SpecialItems',
        'PocketSpecialItems',
        'HasBackpack',
        'HasHerbPouch',
        'QuiverArrows'
    )
    foreach ($propertyName in $requiredInventoryProperties) {
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name $propertyName) -or $null -eq $State.Inventory.$propertyName) {
            return $false
        }
    }

    $requiredCombatProperties = @(
        'Log',
        'SuppressShieldCombatSkillBonus',
        'DeferredEquippedWeapon',
        'EvadeExpiresAfterRound'
    )
    foreach ($propertyName in $requiredCombatProperties) {
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name $propertyName)) {
            return $false
        }
    }

    return $true
}


function Initialize-LWData {
    Set-LWHostGameData -Data (Invoke-LWCoreInitializeData -Context (Get-LWModuleContext)) | Out-Null
    [void](Get-LWAchievementDefinitions)
}

function Initialize-LWRuntimeShell {
    Invoke-LWCoreMaintainRuntime -Context (Get-LWModuleContext)
}

function Normalize-LWState {
    param([Parameter(Mandatory = $true)][object]$State)

    $sourceEngineVersion = if ($null -ne $State -and (Test-LWPropertyExists -Object $State -Name 'EngineVersion') -and -not [string]::IsNullOrWhiteSpace([string]$State.EngineVersion)) {
        [string]$State.EngineVersion
    }
    else {
        ''
    }

    $normalized = if (Test-LWStateFastNormalizeEligible -State $State -SourceEngineVersion $sourceEngineVersion) {
        $State
    }
    else {
        Invoke-LWCoreNormalizeState -Context (Get-LWModuleContext) -State $State
    }
    $normalized = Sync-LWHerbPouchState -State $normalized

    Ensure-LWAchievementState -State $normalized
    $currentBookNumber = if ($null -ne $normalized.Character -and $null -ne $normalized.Character.BookNumber) { [int]$normalized.Character.BookNumber } else { 1 }
    $requiresFullBookSixReconciliation = [string]::IsNullOrWhiteSpace($sourceEngineVersion) -or
        ($sourceEngineVersion -ne $script:LWAppVersion) -or
        ([int]$normalized.Achievements.LoadBackfillVersion -lt (Get-LWAchievementLoadBackfillVersion))
    if ($requiresFullBookSixReconciliation -and $currentBookNumber -ge 6) {
        $visitedSections = @()
        if ($null -ne $normalized.CurrentBookStats -and (Test-LWPropertyExists -Object $normalized.CurrentBookStats -Name 'VisitedSections') -and $null -ne $normalized.CurrentBookStats.VisitedSections) {
            $visitedSections = @($normalized.CurrentBookStats.VisitedSections | ForEach-Object { [int]$_ })
        }
        if ($null -ne $normalized.CurrentSection) {
            $visitedSections += [int]$normalized.CurrentSection
        }
        $visitedSections = @($visitedSections | Sort-Object -Unique)

        if ($visitedSections -contains 49) {
            if (-not (Test-LWPropertyExists -Object $normalized.Achievements.StoryFlags -Name 'Book6Section049CessUsed')) {
                $normalized.Achievements.StoryFlags | Add-Member -Force -NotePropertyName 'Book6Section049CessUsed' -NotePropertyValue $true
            }
            else {
                $normalized.Achievements.StoryFlags.Book6Section049CessUsed = $true
            }

            $latestCessEvent = Get-LWBook6LatestCessSectionEvent -State $normalized
            if ($latestCessEvent -eq 49) {
                $specialItems = @()
                if ($null -ne $normalized.Inventory -and $null -ne $normalized.Inventory.SpecialItems) {
                    $specialItems = @($normalized.Inventory.SpecialItems)
                }
                $normalized.Inventory.SpecialItems = @(
                    foreach ($item in $specialItems) {
                        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCessItemNames) -Target ([string]$item)))) {
                            continue
                        }

                        [string]$item
                    }
                )
            }
            elseif ($latestCessEvent -in @(160, 304)) {
                $specialItems = @()
                if ($null -ne $normalized.Inventory -and $null -ne $normalized.Inventory.SpecialItems) {
                    $specialItems = @($normalized.Inventory.SpecialItems)
                }

                $hasCess = $false
                foreach ($item in $specialItems) {
                    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCessItemNames) -Target ([string]$item)))) {
                        $hasCess = $true
                        break
                    }
                }

                if (-not $hasCess) {
                    $normalized.Inventory.SpecialItems = @($specialItems) + @('Cess')
                }
            }
        }

        $section209ArrowLost = (
            (Test-LWPropertyExists -Object $normalized.Achievements.StoryFlags -Name 'Book6Section209ArrowLost') -and
            [bool]$normalized.Achievements.StoryFlags.Book6Section209ArrowLost
        )
        if (($visitedSections -contains 209) -and -not $section209ArrowLost) {
            $removedArrow = 0
            $backpackItems = @()
            if ($null -ne $normalized.Inventory -and $null -ne $normalized.Inventory.BackpackItems) {
                $backpackItems = @($normalized.Inventory.BackpackItems)
            }

            $normalized.Inventory.BackpackItems = @(
                foreach ($item in $backpackItems) {
                    if ($removedArrow -lt 1 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWArrowItemNames) -Target ([string]$item)))) {
                        $removedArrow++
                        continue
                    }

                    [string]$item
                }
            )

            if ($removedArrow -eq 0 -and (Test-LWStateHasQuiver -State $normalized)) {
                $currentQuiverArrows = Get-LWQuiverArrowCount -State $normalized
                if ($currentQuiverArrows -gt 0) {
                    $normalized.Inventory.QuiverArrows = ($currentQuiverArrows - 1)
                    $removedArrow = 1
                }
            }

            if (Test-LWStateHasQuiver -State $normalized) {
                [void](Sync-LWQuiverArrowState -State $normalized)
            }

            if (-not (Test-LWPropertyExists -Object $normalized.Achievements.StoryFlags -Name 'Book6Section209ArrowLost')) {
                $normalized.Achievements.StoryFlags | Add-Member -Force -NotePropertyName 'Book6Section209ArrowLost' -NotePropertyValue $true
            }
            else {
                $normalized.Achievements.StoryFlags.Book6Section209ArrowLost = $true
            }
        }

    }

    $book7PowerKeyClaimed = (
        (Test-LWPropertyExists -Object $normalized.Achievements.StoryFlags -Name 'Book7PowerKeyClaimed') -and
        [bool]$normalized.Achievements.StoryFlags.Book7PowerKeyClaimed
    )
    $hasBook7PowerKey = (
        (Test-LWStateHasPocketSpecialItem -State $normalized -Names @('Power-key', 'Power Key')) -or
        (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $normalized -Names @('Power-key', 'Power Key') -Type 'special')))
    )
    if ($currentBookNumber -eq 7 -and [int]$normalized.CurrentSection -eq 1 -and -not $book7PowerKeyClaimed -and -not $hasBook7PowerKey) {
        if ($null -eq $normalized.Inventory.PocketSpecialItems) {
            $normalized.Inventory.PocketSpecialItems = @()
        }

        $normalized.Inventory.PocketSpecialItems = @(Normalize-LWInventoryItemCollection -Type 'special' -Items (@($normalized.Inventory.PocketSpecialItems) + @('Power-key')))

        if (-not (Test-LWPropertyExists -Object $normalized.Achievements.StoryFlags -Name 'Book7PowerKeyClaimed')) {
            $normalized.Achievements.StoryFlags | Add-Member -Force -NotePropertyName 'Book7PowerKeyClaimed' -NotePropertyValue $true
        }
        else {
            $normalized.Achievements.StoryFlags.Book7PowerKeyClaimed = $true
        }
    }

    return (Sync-LWStateRefactorMetadata -State $normalized)
}

function Save-LWGame {
    param([switch]$PromptForPath)

    if ($null -ne $script:GameState) {
        [void](Sync-LWStateRefactorMetadata -State $script:GameState)
    }

    Invoke-LWCoreSaveGame -Context (Get-LWModuleContext) -PromptForPath:$PromptForPath
}

function Load-LWGame {
    param([Parameter(Mandatory = $true)][string]$Path)

    $loadedState = Invoke-LWCoreLoadGame -Context (Get-LWModuleContext) -Path $Path
    if ($null -ne $loadedState) {
        Set-LWHostGameState -State (Sync-LWStateRefactorMetadata -State $loadedState) | Out-Null
        Warm-LWRuntimeCaches
        Set-LWScreen -Name (Get-LWDefaultScreen)
        if (-not (Test-LWDeathActive)) {
            $magnakaiInstantDeathCause = $null
            switch ([int]$script:GameState.Character.BookNumber) {
                6 { $magnakaiInstantDeathCause = Get-LWMagnakaiBookSixInstantDeathCause -Section ([int]$script:GameState.CurrentSection) }
                7 { $magnakaiInstantDeathCause = Get-LWMagnakaiBookSevenInstantDeathCause -Section ([int]$script:GameState.CurrentSection) }
            }
            if (-not [string]::IsNullOrWhiteSpace($magnakaiInstantDeathCause)) {
                Invoke-LWInstantDeath -Cause $magnakaiInstantDeathCause
            }
        }

    }
}

function Load-LWGameInteractive {
    param([string]$Selection)

    $loadedState = Invoke-LWCoreLoadGameInteractive -Context (Get-LWModuleContext) -Selection $Selection
    if ($null -ne $loadedState) {
        Set-LWHostGameState -State (Sync-LWStateRefactorMetadata -State $loadedState) | Out-Null
        Warm-LWRuntimeCaches
        Set-LWScreen -Name (Get-LWDefaultScreen)
        if (-not (Test-LWDeathActive)) {
            $magnakaiInstantDeathCause = $null
            switch ([int]$script:GameState.Character.BookNumber) {
                6 { $magnakaiInstantDeathCause = Get-LWMagnakaiBookSixInstantDeathCause -Section ([int]$script:GameState.CurrentSection) }
                7 { $magnakaiInstantDeathCause = Get-LWMagnakaiBookSevenInstantDeathCause -Section ([int]$script:GameState.CurrentSection) }
            }
            if (-not [string]::IsNullOrWhiteSpace($magnakaiInstantDeathCause)) {
                Invoke-LWInstantDeath -Cause $magnakaiInstantDeathCause
            }
        }
    }
}

function Invoke-LWCommand {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$InputLine)

    return (Invoke-LWCoreCommand -Context (Get-LWModuleContext) -InputLine $InputLine)
}

function Start-LWCombat {
    param([string[]]$Arguments = @())

    return (Invoke-LWCoreStartCombat -Context (Get-LWModuleContext) -Arguments $Arguments)
}

function Register-LWStorySectionAchievementTriggers {
    param([Parameter(Mandatory = $true)][int]$Section)

    if (-not (Test-LWHasState)) {
        return
    }

    Invoke-LWRuleSetStorySectionAchievementTriggers -State $script:GameState -Section $Section
}

function Register-LWStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    if (-not (Test-LWHasState)) {
        return
    }

    Invoke-LWRuleSetStorySectionTransitionAchievementTriggers -State $script:GameState -FromSection $FromSection -ToSection $ToSection
}

function Get-LWSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    return (Get-LWRuleSetSectionRandomNumberContext -State $State)
}

function Invoke-LWSectionEntryRules {
    if (-not (Test-LWHasState)) {
        return
    }

    Invoke-LWRuleSetSectionEntryRules -State $script:GameState
}

function Apply-LWBookOneStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 1 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookTwoStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 2 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookThreeStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 3 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookFourStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 4 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookFiveStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 5 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookSixStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 6 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookSevenStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 7 -CarryExistingGear:$CarryExistingGear
}

function Publish-LWScriptFunctionsToSession {
    $scriptPath = if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $PSCommandPath
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $MyInvocation.MyCommand.Path
    }
    else {
        $null
    }

    $functions = @(Get-Command -CommandType Function | Where-Object {
            $_.Name -like '*-LW*' -and
            $null -ne $_.ScriptBlock -and
            (
                [string]::IsNullOrWhiteSpace($scriptPath) -or
                [string]$_.ScriptBlock.File -eq $scriptPath
            )
        })

    foreach ($functionInfo in $functions) {
        Set-Item -Path ("Function:\global:{0}" -f $functionInfo.Name) -Value $functionInfo.ScriptBlock -Force
    }
}

if (Test-LWShouldAutoStart -InvocationName $MyInvocation.InvocationName) {
    Publish-LWScriptFunctionsToSession
    Initialize-LWRuntimeShell
    Initialize-LWData
    Start-LWTerminal
}


