$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

function Set-LWAutomationSmokePromptShims {
    Set-Item -Path function:Read-LWYesNo -Value {
        param([string]$Prompt, [bool]$Default = $false, [switch]$NoRefresh)
        return [bool]$Default
    }

    Set-Item -Path function:Read-LWInlineYesNo -Value {
        param([string]$Prompt, [bool]$Default = $false)
        return [bool]$Default
    }

    Set-Item -Path function:Read-LWInt -Value {
        param(
            [string]$Prompt,
            [int]$Default = 0,
            [int]$Min = [int]::MinValue,
            [int]$Max = [int]::MaxValue,
            [switch]$NoRefresh
        )

        if ($PSBoundParameters.ContainsKey('Default')) { return [int]$Default }
        if ($Min -ne [int]::MinValue) { return [int]$Min }
        return 0
    }

    Set-Item -Path function:Read-LWText -Value {
        param(
            [string]$Prompt,
            [string]$Default = '',
            [switch]$NoRefresh
        )

        if ($PSBoundParameters.ContainsKey('Default')) { return [string]$Default }
        return ''
    }

    Set-Item -Path function:Read-Host -Value {
        param([string]$Prompt)
        return ''
    }

    Set-Item -Path function:Write-LWInfo -Value { param([string]$Message) }
    Set-Item -Path function:Write-LWWarn -Value { param([string]$Message) }
    Set-Item -Path function:Write-LWError -Value { param([string]$Message) }
    Set-Item -Path function:Add-LWNotification -Value { param([string]$Message, [string]$Level) }
    Set-Item -Path function:Request-LWRender -Value { param() }
    Set-Item -Path function:Refresh-LWScreen -Value { param() }
    Set-Item -Path function:Clear-LWScreenHost -Value { param([switch]$PreserveNotifications) }

    Set-Item -Path function:Select-LWKaiDisciplines -Value {
        param([int]$Count = 1, [string[]]$Exclude = @())
        return @($script:GameData.KaiDisciplines | Where-Object { $Exclude -notcontains $_.Name } | Select-Object -First $Count -ExpandProperty Name)
    }

    Set-Item -Path function:Select-LWMagnakaiDisciplines -Value {
        param([int]$Count = 1, [string[]]$Exclude = @())
        return @($script:GameData.MagnakaiDisciplines | Where-Object { $Exclude -notcontains $_.Name } | Select-Object -First $Count -ExpandProperty Name)
    }

    Set-Item -Path function:Select-LWWeaponmasteryWeapons -Value {
        param([int]$Count = 3, [string[]]$Exclude = @())
        $options = @('Sword', 'Bow', 'Warhammer', 'Dagger', 'Quarterstaff', 'Spear')
        return @($options | Where-Object { $Exclude -notcontains $_ } | Select-Object -First $Count)
    }

    Set-Item -Path function:Select-LWCombatWeapon -Value {
        param([string]$DefaultWeapon = $null)
        if (-not [string]::IsNullOrWhiteSpace($DefaultWeapon)) {
            return [string]$DefaultWeapon
        }

        return 'Sword'
    }
}

function Copy-LWAutomationSmokeState {
    param([Parameter(Mandatory = $true)][object]$State)

    return [System.Management.Automation.PSSerializer]::Deserialize(
        [System.Management.Automation.PSSerializer]::Serialize($State)
    )
}

function Add-LWAutomationSmokeBaselineGear {
    param([Parameter(Mandatory = $true)][object]$State)

    Set-LWHostGameState -State $State | Out-Null
    Set-LWBackpackState -HasBackpack $true

    [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Sword')
    [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Bow')
    [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Quiver')
    $State.Inventory.QuiverArrows = 6

    foreach ($item in @('Torch', 'Tinderbox', 'Rope', 'Meal', 'Potion of Laumspur')) {
        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name $item)
    }

    foreach ($item in @('Shield', 'Helmet')) {
        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name $item)
    }

    if ([int]$State.Character.BookNumber -eq 6) {
        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Book of the Magnakai')
        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Cess')
        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Taunor Water')
    }

    $State.Inventory.GoldCrowns = 50
    [void](Sync-LWStateEquipmentBonuses -State $State)
}

function New-LWAutomationSmokeState {
    param([Parameter(Mandatory = $true)][int]$BookNumber)

    $state = New-LWDefaultState
    $state.Character.Name = 'Automation Smoke'
    $state.Character.BookNumber = $BookNumber
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.CurrentSection = 1
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)

    if ($BookNumber -ge 6) {
        $state.RuleSet = 'Magnakai'
        $state.Character.LegacyKaiComplete = $true
        $state.Character.MagnakaiRank = 5
        $state.Character.MagnakaiDisciplines = @($script:GameData.MagnakaiDisciplines | ForEach-Object { [string]$_.Name })
        $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer')
    }
    else {
        $state.RuleSet = 'Kai'
        $state.Character.Disciplines = @($script:GameData.KaiDisciplines | ForEach-Object { [string]$_.Name })
        $state.Character.WeaponskillWeapon = 'Sword'
    }

    Set-LWHostGameState -State $state | Out-Null
    [void](Ensure-LWCurrentBookStats -State $state)
    Add-LWAutomationSmokeBaselineGear -State $state
    return $state
}

function New-LWAutomationSmokeScenario {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object]$EncounterProfile = $null
    )

    $enemyName = 'Smoke Enemy'
    $enemyCombatSkill = 20
    $enemyEndurance = 20

    if ($null -ne $EncounterProfile) {
        if ((Test-LWPropertyExists -Object $EncounterProfile -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$EncounterProfile.EnemyName)) {
            $enemyName = [string]$EncounterProfile.EnemyName
        }
        if ((Test-LWPropertyExists -Object $EncounterProfile -Name 'EnemyCombatSkill') -and $null -ne $EncounterProfile.EnemyCombatSkill) {
            $enemyCombatSkill = [int]$EncounterProfile.EnemyCombatSkill
        }
        if ((Test-LWPropertyExists -Object $EncounterProfile -Name 'EnemyEndurance') -and $null -ne $EncounterProfile.EnemyEndurance) {
            $enemyEndurance = [int]$EncounterProfile.EnemyEndurance
        }
    }

    return @{
        EnemyName         = $enemyName
        EnemyCombatSkill  = $enemyCombatSkill
        EnemyEndurance    = $enemyEndurance
        EnemyImmune       = $false
        EnemyUndead       = $false
        EnemyUsesMindforce = $false
        CanEvade          = $false
        EquippedWeapon    = 'Sword'
        UseQuickDefaults  = $true
        PlayerMod         = 0
        EnemyMod          = 0
    }
}

Set-LWAutomationSmokePromptShims

$startingEquipmentResults = @()
$sectionResults = @()
$combatResults = @()
$failures = @()
$baseStates = @{}

foreach ($bookNumber in 1..6) {
    try {
        $startState = New-LWDefaultState
        $startState.Character.Name = 'Automation Smoke'
        $startState.Character.BookNumber = $bookNumber
        $startState.Character.CombatSkillBase = 20
        $startState.Character.EnduranceCurrent = 30
        $startState.Character.EnduranceMax = 30
        $startState.Settings.SavePath = ''
        $startState.Settings.AutoSave = $false
        $startState.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)
        $startState.RuleSet = if ($bookNumber -ge 6) { 'Magnakai' } else { 'Kai' }

        Set-LWHostGameState -State $startState | Out-Null
        Invoke-LWRuleSetStartingEquipment -State $startState -BookNumber $bookNumber -CarryExistingGear:$false
        $startingEquipmentResults += [pscustomobject]@{
            Book   = $bookNumber
            Status = 'ok'
        }
    }
    catch {
        $failures += [pscustomobject]@{
            Phase   = 'starting-equipment'
            Book    = $bookNumber
            Section = $null
            Error   = $_.Exception.Message
        }
    }

    $baseStates[[string]$bookNumber] = (New-LWAutomationSmokeState -BookNumber $bookNumber)
}

foreach ($bookNumber in 1..6) {
    $baseState = $baseStates[[string]$bookNumber]
    foreach ($section in 1..350) {
        $state = Copy-LWAutomationSmokeState -State $baseState
        $state.CurrentSection = $section
        $state.SectionHadCombat = $false
        $state.SectionHealingResolved = $false
        Set-LWHostGameState -State $state | Out-Null

        try {
            Invoke-LWRuleSetStorySectionAchievementTriggers -State $state -Section $section
            if ($section -gt 1) {
                Invoke-LWRuleSetStorySectionTransitionAchievementTriggers -State $state -FromSection ($section - 1) -ToSection $section
            }
            Invoke-LWRuleSetSectionEntryRules -State $state
            $sectionResults += [pscustomobject]@{
                Book    = $bookNumber
                Section = $section
                Status  = 'ok'
            }
        }
        catch {
            $failures += [pscustomobject]@{
                Phase   = 'section-entry'
                Book    = $bookNumber
                Section = $section
                Error   = $_.Exception.Message
            }
        }

        $combatState = Copy-LWAutomationSmokeState -State $baseState
        $combatState.CurrentSection = $section
        Set-LWHostGameState -State $combatState | Out-Null

        try {
            $encounterProfile = Get-LWRuleSetCombatEncounterProfile -State $combatState
            if ($null -ne $encounterProfile -and (Test-LWPropertyExists -Object $encounterProfile -Name 'Blocked') -and [bool]$encounterProfile.Blocked) {
                $combatResults += [pscustomobject]@{
                    Book    = $bookNumber
                    Section = $section
                    Status  = 'blocked'
                }
            }
            else {
                $scenario = New-LWAutomationSmokeScenario -State $combatState -EncounterProfile $encounterProfile
                Invoke-LWRuleSetCombatScenarioRules -State $combatState -Scenario $scenario
                $combatResults += [pscustomobject]@{
                    Book    = $bookNumber
                    Section = $section
                    Status  = 'ok'
                }
            }
        }
        catch {
            $failures += [pscustomobject]@{
                Phase   = 'combat-scenario'
                Book    = $bookNumber
                Section = $section
                Error   = $_.Exception.Message
            }
        }
    }
}

"Starting-equipment checks: $(@($startingEquipmentResults).Count)"
"Section-entry checks: $(@($sectionResults).Count)"
"Combat-scenario checks: $(@($combatResults).Count)"
"Failures: $(@($failures).Count)"

if (@($failures).Count -gt 0) {
    $failures |
        Sort-Object Phase, Book, Section |
        Format-Table -AutoSize |
        Out-String
    exit 1
}
