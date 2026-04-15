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


function Resolve-LWHealingState {
    param([object]$State = $null)

    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ($null -ne $State) {
        return $State
    }

    return $script:GameState
}

function Resolve-LWGameplayEnduranceLoss {
    param(
        [int]$Loss,
        [string]$Source = 'damage',
        [object]$State = $null
    )

    $State = Resolve-LWHealingState -State $State
    $requestedLoss = [Math]::Max(0, [int]$Loss)
    if ($requestedLoss -le 0) {
        return [pscustomobject]@{
            RequestedLoss = 0
            AppliedLoss   = 0
            PreventedLoss = 0
            Note          = $null
        }
    }

    $difficulty = Get-LWCurrentDifficulty -State $State
    switch ($difficulty) {
        'Story' {
            return [pscustomobject]@{
                RequestedLoss = $requestedLoss
                AppliedLoss   = 0
                PreventedLoss = $requestedLoss
                Note          = 'Story mode prevents END loss from normal gameplay damage.'
            }
        }
        'Easy' {
            $appliedLoss = [int][Math]::Ceiling($requestedLoss / 2.0)
            $prevented = $requestedLoss - $appliedLoss
            return [pscustomobject]@{
                RequestedLoss = $requestedLoss
                AppliedLoss   = $appliedLoss
                PreventedLoss = $prevented
                Note          = $(if ($prevented -gt 0) { "Easy mode halves END loss: $appliedLoss instead of $requestedLoss." } else { $null })
            }
        }
        default {
            return [pscustomobject]@{
                RequestedLoss = $requestedLoss
                AppliedLoss   = $requestedLoss
                PreventedLoss = 0
                Note          = $null
            }
        }
    }
}

function Get-LWHealingRestorationCap {
    param([object]$State = $null)

    $State = Resolve-LWHealingState -State $State
    $capInfo = Get-LWHealingRestorationCapInfo -State $State
    if ($null -eq $capInfo) {
        return $null
    }

    return [int]$capInfo.Cap
}

function Get-LWHealingRestorationCapInfo {
    param([object]$State = $null)

    $State = Resolve-LWHealingState -State $State
    $capRules = @()
    if (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State)) {
        $capRules += [pscustomobject]@{
            Cap         = 10
            ZeroNote    = 'Healing is capped at 10 END restored per book in this mode.'
            PartialNote = 'Healing is capped in this mode: {0} END can be restored now ({1} remaining this book).'
        }
    }

    if ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.BookNumber -eq 6 -and (Test-LWStateIsMagnakaiRuleset -State $State)) {
        switch (Get-LWBookSixDECuringOption -State $State) {
            1 {
                $capRules += [pscustomobject]@{
                    Cap         = 15
                    ZeroNote    = 'Book 6 DE Play Option 1 caps Curing and Healing at 15 END restored this book.'
                    PartialNote = 'Book 6 DE Play Option 1 caps Curing/Healing: {0} END can be restored now ({1} remaining this book).'
                }
            }
            2 {
                $capRules += [pscustomobject]@{
                    Cap         = 10
                    ZeroNote    = 'Book 6 DE Play Option 2 caps Healing at 10 END restored this book.'
                    PartialNote = 'Book 6 DE Play Option 2 caps Healing: {0} END can be restored now ({1} remaining this book).'
                }
            }
        }
    }

    if ($capRules.Count -eq 0) {
        return $null
    }

    $minCap = [int](($capRules | Measure-Object -Property Cap -Minimum).Minimum)
    return @($capRules | Where-Object { [int]$_.Cap -eq $minCap } | Select-Object -First 1)[0]
}

function Test-LWStateHasSectionHealing {
    param([object]$State = $null)

    $State = Resolve-LWHealingState -State $State
    if ($null -eq $State -or $null -eq $State.Character) {
        return $false
    }

    $isBookSixMagnakai = ((Test-LWStateIsMagnakaiRuleset -State $State) -and [int]$State.Character.BookNumber -eq 6)
    if (-not $isBookSixMagnakai) {
        return (Test-LWStateHasDiscipline -State $State -Name 'Healing')
    }

    if (Test-LWStateHasDiscipline -State $State -Name 'Curing') {
        return $true
    }

    return ((Get-LWBookSixDECuringOption -State $State) -eq 2 -and (Test-LWStateHasDiscipline -State $State -Name 'Healing'))
}

function Get-LWSectionHealingSourceLabel {
    param([object]$State = $null)

    $State = Resolve-LWHealingState -State $State
    if ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.BookNumber -eq 6 -and (Test-LWStateIsMagnakaiRuleset -State $State) -and (Test-LWStateHasDiscipline -State $State -Name 'Curing')) {
        return 'Curing'
    }

    return 'Healing'
}

function Get-LWPreferredHealingPotionChoice {
    param([object]$State = $null)

    $State = Resolve-LWHealingState -State $State
    return @((Get-LWAvailableHealingPotionChoices -State $State) | Select-Object -First 1)[0]
}

function Get-LWAvailableHealingPotionChoices {
    param(
        [object]$State = $null,
        [switch]$HerbPouchOnly
    )

    $State = Resolve-LWHealingState -State $State
    if ($null -eq $State) {
        return @()
    }

    $definitions = @(
        [pscustomobject]@{ Names = (Get-LWConcentratedHealingPotionItemNames); RestoreAmount = 8; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWOedeHerbItemNames); RestoreAmount = 10; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWTaunorWaterItemNames); RestoreAmount = 6; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWRendalimsElixirItemNames); RestoreAmount = 6; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWPotentHealingPotionItemNames); RestoreAmount = 5; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWHealingPotionItemNames); RestoreAmount = 4; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWBottleOfKourshahItemNames); RestoreAmount = 4; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWMinorHealingPotionItemNames); RestoreAmount = 3; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWLaumspurHerbItemNames); RestoreAmount = 3; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWMealOfLaumspurItemNames); RestoreAmount = 3; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWLarnumaOilItemNames); RestoreAmount = 2; Types = @('backpack') }
    )

    $choices = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $definitions) {
        $types = if ($HerbPouchOnly) { @('herbpouch') } else { @($definition.Types) }
        foreach ($type in $types) {
            if (@($definition.Types) -notcontains $type) {
                continue
            }
            if ($type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $State)) {
                continue
            }
            if ($type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $State)) {
                continue
            }

            $items = @(Get-LWStateInventoryItems -State $State -Type $type)
            $matchedItems = @($items | Where-Object {
                    -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @($definition.Names) -Target ([string]$_)))
                })
            if ($matchedItems.Count -eq 0) {
                continue
            }

            foreach ($itemName in @($matchedItems | Select-Object -Unique)) {
                $matchCount = @($matchedItems | Where-Object { [string]$_ -eq [string]$itemName }).Count
                $choices.Add([pscustomobject]@{
                        Name          = [string]$itemName
                        RestoreAmount = [int]$definition.RestoreAmount
                        Type          = [string]$type
                        Quantity      = [int]$matchCount
                        LocationLabel = $(if ($type -eq 'herbpouch') { 'Herb Pouch' } else { 'Backpack' })
                    })
            }
        }
    }

    return @($choices.ToArray())
}

function Format-LWHealingPotionChoiceText {
    param([Parameter(Mandatory = $true)][object]$Choice)

    $countSuffix = if ((Test-LWPropertyExists -Object $Choice -Name 'Quantity') -and [int]$Choice.Quantity -gt 1) {
        " x$([int]$Choice.Quantity)"
    }
    else {
        ''
    }

    $locationLabel = if ((Test-LWPropertyExists -Object $Choice -Name 'LocationLabel') -and -not [string]::IsNullOrWhiteSpace([string]$Choice.LocationLabel)) {
        [string]$Choice.LocationLabel
    }
    elseif ((Test-LWPropertyExists -Object $Choice -Name 'Type') -and [string]$Choice.Type -eq 'herbpouch') {
        'Herb Pouch'
    }
    else {
        'Backpack'
    }

    return ("{0}{1} [{2}] +{3} END" -f [string]$Choice.Name, $countSuffix, $locationLabel, [int]$Choice.RestoreAmount)
}

function Select-LWHealingPotionChoice {
    param(
        [object]$State = $null,
        [switch]$HerbPouchOnly
    )

    $State = Resolve-LWHealingState -State $State
    $choices = @(Get-LWAvailableHealingPotionChoices -State $State -HerbPouchOnly:$HerbPouchOnly)
    if ($choices.Count -eq 0) {
        if ($HerbPouchOnly) {
            Write-LWWarn 'No usable healing potion is currently stored in the Herb Pouch.'
        }
        else {
            Write-LWWarn 'No usable healing item found in Herb Pouch or Backpack.'
        }
        return $null
    }

    if ($choices.Count -eq 1) {
        return $choices[0]
    }

    $title = if ($HerbPouchOnly) { 'Choose Combat Potion' } else { 'Choose Potion' }
    $accent = if ($HerbPouchOnly) { 'Red' } else { 'DarkGreen' }
    Write-LWRetroPanelHeader -Title $title -AccentColor $accent
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-LWRetroPanelTextRow -Text ("{0,2}. {1}" -f ($i + 1), (Format-LWHealingPotionChoiceText -Choice $choices[$i])) -TextColor 'Gray'
    }
    Write-LWRetroPanelTextRow -Text ' 0. Cancel' -TextColor 'DarkGray'
    Write-LWRetroPanelFooter

    $choiceIndex = Read-LWInt -Prompt 'Potion number' -Default 0 -Min 0 -Max $choices.Count -NoRefresh
    if ($choiceIndex -eq 0) {
        Write-LWInfo 'Potion use cancelled.'
        return $null
    }

    return $choices[$choiceIndex - 1]
}

function Use-LWResolvedHealingPotion {
    param(
        [Parameter(Mandatory = $true)][string]$PotionName,
        [Parameter(Mandatory = $true)][int]$RestoreAmount,
        [string]$InventoryType = '',
        [switch]$SkipAutosave
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ([string]::IsNullOrWhiteSpace($PotionName)) {
        Write-LWWarn 'No usable healing item found in Herb Pouch or Backpack.'
        return $null
    }

    $removeType = if (@('backpack', 'herbpouch') -contains $InventoryType) {
        [string]$InventoryType
    }
    else {
        $location = Find-LWStateInventoryItemLocation -State $script:GameState -Names @($PotionName) -Types @('herbpouch', 'backpack')
        if ($null -ne $location) { [string]$location.Type } else { 'backpack' }
    }

    [void](Remove-LWInventoryItemSilently -Type $removeType -Name $PotionName -Quantity 1)
    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent += [int]$RestoreAmount
    if ($script:GameState.Character.EnduranceCurrent -gt $script:GameState.Character.EnduranceMax) {
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    }
    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before

    $conditionMessages = @()
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHealingPotionItemNames) -Target $PotionName)) -or
        -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWLaumspurHerbItemNames) -Target $PotionName))) {
        if (Test-LWBookFiveBloodPoisoningActive -State $script:GameState) {
            $script:GameState.Conditions.BookFiveBloodPoisoning = $false
            $conditionMessages += 'Blood poisoning cured.'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOedeHerbItemNames) -Target $PotionName))) {
        if (Test-LWBookFiveLimbdeathActive -State $script:GameState) {
            $script:GameState.Conditions.BookFiveLimbdeath = $false
            Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
            $conditionMessages += 'Limbdeath cured.'
        }
    }

    Add-LWBookEnduranceDelta -Delta $restored
    Register-LWPotionUsed -PotionName $PotionName -EnduranceRestored $restored
    $message = "$PotionName restores $RestoreAmount Endurance. Current Endurance: $($script:GameState.Character.EnduranceCurrent)."
    if ($conditionMessages.Count -gt 0) {
        $message += " $($conditionMessages -join ' ')"
    }
    Write-LWInfo $message
    if (-not $SkipAutosave) {
        Invoke-LWMaybeAutosave
    }

    return [pscustomobject]@{
        PotionName    = $PotionName
        RestoreAmount = [int]$RestoreAmount
        AppliedAmount = $restored
    }
}

function Get-LWRemainingHealingRestoration {
    param([object]$State = $null)

    $State = Resolve-LWHealingState -State $State
    $cap = Get-LWHealingRestorationCap -State $State
    if ($null -eq $cap) {
        return $null
    }

    $stats = Ensure-LWCurrentBookStats
    $used = if ($null -ne $stats -and (Test-LWPropertyExists -Object $stats -Name 'HealingEnduranceRestored')) { [int]$stats.HealingEnduranceRestored } else { 0 }
    return [Math]::Max(0, ([int]$cap - $used))
}

function Resolve-LWHealingRestoreAmount {
    param(
        [int]$RequestedAmount,
        [object]$State = $null
    )

    $State = Resolve-LWHealingState -State $State
    $requested = [Math]::Max(0, [int]$RequestedAmount)
    $remaining = Get-LWRemainingHealingRestoration -State $State
    if ($null -eq $remaining) {
        return [pscustomobject]@{
            RequestedAmount = $requested
            AppliedAmount   = $requested
            Note            = $null
        }
    }

    $applied = [Math]::Min($requested, [int]$remaining)
    $note = $null
    $capInfo = Get-LWHealingRestorationCapInfo -State $State
    if ($applied -lt $requested) {
        if ($remaining -le 0) {
            $note = if ($null -ne $capInfo -and -not [string]::IsNullOrWhiteSpace([string]$capInfo.ZeroNote)) { [string]$capInfo.ZeroNote } else { 'Healing is capped this book.' }
        }
        else {
            $note = if ($null -ne $capInfo -and -not [string]::IsNullOrWhiteSpace([string]$capInfo.PartialNote)) {
                [string]::Format([string]$capInfo.PartialNote, $applied, $remaining)
            }
            else {
                "Healing is capped this book: $applied END can be restored now ($remaining remaining this book)."
            }
        }
    }

    return [pscustomobject]@{
        RequestedAmount = $requested
        AppliedAmount   = $applied
        Note            = $note
    }
}

function Invoke-LWHealingCheck {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Resolve-LWSectionExit
    Invoke-LWMaybeAutosave
}

function Use-LWHealingPotion {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($script:GameState.Combat.Active) {
        if (Test-LWCombatHerbPouchOptionActive -State $script:GameState) {
            Invoke-LWCombatPotionRound
            return
        }
        Write-LWWarn 'Healing Potions cannot be used during combat.'
        return
    }

    if (-not (Test-LWStateHasBackpack -State $script:GameState) -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack or a usable Herb Pouch, so you cannot use stored healing items right now.'
        return
    }

    $choice = Select-LWHealingPotionChoice -State $script:GameState
    if ($null -eq $choice) {
        return
    }

    [void](Use-LWResolvedHealingPotion -PotionName ([string]$choice.Name) -RestoreAmount ([int]$choice.RestoreAmount) -InventoryType ([string]$choice.Type))
}

Export-ModuleMember -Function Resolve-LWGameplayEnduranceLoss, Get-LWHealingRestorationCap, Get-LWHealingRestorationCapInfo, Test-LWStateHasSectionHealing, Get-LWSectionHealingSourceLabel, Get-LWPreferredHealingPotionChoice, Get-LWAvailableHealingPotionChoices, Format-LWHealingPotionChoiceText, Select-LWHealingPotionChoice, Use-LWResolvedHealingPotion, Get-LWRemainingHealingRestoration, Resolve-LWHealingRestoreAmount, Invoke-LWHealingCheck, Use-LWHealingPotion

