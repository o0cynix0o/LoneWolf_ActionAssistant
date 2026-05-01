$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location -LiteralPath $root

. .\lonewolf.ps1

Initialize-LWRuntimeShell
Initialize-LWData | Out-Null

$failures = New-Object 'System.Collections.Generic.List[string]'

function Add-Failure {
    param([Parameter(Mandatory = $true)][string]$Message)
    [void]$failures.Add($Message)
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        Add-Failure -Message $Message
    }
}

function Reset-BookEightSmokeState {
    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.Character.Name = 'Book 8 Smoke'
    $state.Character.BookNumber = 8
    $state.Character.CombatSkillBase = 21
    $state.Character.EnduranceMax = 28
    $state.Character.EnduranceCurrent = 20
    $state.Character.MagnakaiRank = 5
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Huntmastery', 'Psi-screen', 'Divination', 'Animal Control', 'Psi-surge')
    $state.Character.WeaponmasteryWeapons = @('Bow')
    Set-LWHostGameState -State $state | Out-Null
    Reset-LWCurrentBookStats -BookNumber 8 -StartSection 1 | Out-Null
}

Reset-BookEightSmokeState
$achievementIds = @(Get-LWAchievementDefinitions | ForEach-Object { [string]$_.Id })
foreach ($requiredAchievementId in @(
        'book_eight_complete',
        'jungle_lorestone_bearer',
        'conundrum_conqueror',
        'lodestone_bearer_book8',
        'grey_area',
        'ohrido_lorestone',
        'silver_box_prize',
        'levitron_lifeline',
        'jungle_horror'
    )) {
    Assert-True -Condition ($achievementIds -contains $requiredAchievementId) -Message ("Missing Book 8 achievement definition: {0}" -f $requiredAchievementId)
}

$totalAchievementCount = @($achievementIds).Count
Assert-True -Condition ($totalAchievementCount -eq 136) -Message ("Expected 136 achievement definitions after Book 8 build, found {0}." -f $totalAchievementCount)

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 1
Invoke-LWSectionEntryRules
Assert-True -Condition (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names @('Pass')) -Message 'Section 1 did not add the Pass as a pocket item.'

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 16
$script:GameState.Inventory.GoldCrowns = 0
Invoke-LWSectionEntryRules
Assert-True -Condition ([int]$script:GameState.Inventory.GoldCrowns -eq 5) -Message 'Section 16 did not convert 20 Lune into 5 Gold Crowns.'

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 105
$script:GameState.Inventory.BackpackItems = @('Meal')
Invoke-LWSectionEntryRules
Assert-True -Condition ((@($script:GameState.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count) -eq 0) -Message 'Section 105 did not consume one Meal.'

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 86
$script:GameState.Character.EnduranceCurrent = 20
$context = Get-LWSectionRandomNumberContext -State $script:GameState
Assert-True -Condition ($null -ne $context -and [int]$context.Section -eq 86 -and [bool]$context.ZeroCountsAsTen) -Message 'Section 86 random context is missing zero-counts-as-ten.'
if ($null -ne $context) {
    Invoke-LWMagnakaiBookEightSectionRandomNumberResolution -State $script:GameState -Context $context -Rolls @(0) -EffectiveRolls @(10) -Subtotal 10 -AdjustedTotal 10
}
Assert-True -Condition ([int]$script:GameState.Character.EnduranceCurrent -eq 10) -Message 'Section 86 did not apply adjusted Grey Crystal Ring backlash damage.'

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 269
$script:GameState.Inventory.SpecialItems = @('One', 'Two', 'Three', 'Four')
Invoke-LWSectionEntryRules
Assert-True -Condition ((@($script:GameState.Inventory.SpecialItems) -join ',') -eq 'One,Two,Three') -Message 'Section 269 did not remove the fourth Special Item.'

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 233
$profile = Get-LWRuleSetCombatEncounterProfile -State $script:GameState
Assert-True -Condition ($null -ne $profile -and [string]$profile.EnemyName -eq 'Rogue Miner' -and [int]$profile.EnemyCombatSkill -eq 17 -and [int]$profile.EnemyEndurance -eq 25) -Message 'Section 233 combat profile does not match Rogue Miner CS 17 END 25.'

Reset-BookEightSmokeState
$script:GameState.CurrentSection = 52
$section52Scenario = @{
    EnemyName                     = 'Taan-spider'
    PlayerEnduranceLossMultiplier = 1
    VictoryResolutionSection      = $null
    VictoryResolutionNote         = ''
}
Invoke-LWRuleSetCombatScenarioRules -State $script:GameState -Scenario $section52Scenario
Assert-True -Condition ([int]$section52Scenario.PlayerEnduranceLossMultiplier -eq 2 -and [int]$section52Scenario.VictoryResolutionSection -eq 129) -Message 'Section 52 scenario rules did not double Lone Wolf venom losses and route victory to 129.'

$psiSurgeScenario = @{
    UseMindblast               = $true
    PsychicAttackMode          = 'Psi-surge'
    PlayerMod                  = 0
    MindblastCombatSkillBonus  = 2
    DoubleEnemyEnduranceLoss   = $false
}
Invoke-LWRuleSetCombatPsychicAttackRules -State $script:GameState -Scenario $psiSurgeScenario
Assert-True -Condition ([int]$psiSurgeScenario.PlayerMod -eq 8) -Message 'Section 52 Psi-surge did not apply the extra tripled psychic bonus.'

$mindblastScenario = @{
    UseMindblast               = $true
    PsychicAttackMode          = 'Mindblast'
    PlayerMod                  = 0
    MindblastCombatSkillBonus  = 2
    DoubleEnemyEnduranceLoss   = $false
}
Invoke-LWRuleSetCombatPsychicAttackRules -State $script:GameState -Scenario $mindblastScenario
Assert-True -Condition ([int]$mindblastScenario.MindblastCombatSkillBonus -eq 6) -Message 'Section 52 Mindblast did not triple the psychic bonus.'

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Output ("FAIL: {0}" -f $failure)
    }
    exit 1
}

Write-Output 'BOOK8_RULES_SMOKE_OK'
