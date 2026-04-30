Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location -LiteralPath $repoRoot

. (Join-Path $repoRoot 'lonewolf.ps1')
Initialize-LWData

function Assert-Section233PsychicSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-Section233State {
    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.CurrentSection = 233
    $state.Character.BookNumber = 7
    $state.Character.CombatSkillBase = 22
    $state.Character.EnduranceCurrent = 28
    $state.Character.EnduranceMax = 28
    $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    $state.Character.LegacyKaiComplete = $true
    $state.Character.Disciplines = @('Mindblast')
    $state.Character.MagnakaiDisciplines = @('Psi-surge')
    $state.Inventory.Weapons = @('Sword')
    $state.Combat.Active = $true
    $state.Combat.EnemyName = 'Oudagorg'
    $state.Combat.EnemyCombatSkill = 17
    $state.Combat.EnemyEnduranceCurrent = 17
    $state.Combat.EnemyEnduranceMax = 17
    $state.Combat.EquippedWeapon = 'Sword'
    $state.Combat.UseMindblast = $true
    $state.Combat.PsychicAttackMode = 'Psi-surge'
    $state.Combat.DoubleEnemyEnduranceLoss = $false
    $state.Combat.VictoryResolutionSection = 209
    $state.Combat.VictoryResolutionNote = 'Section 233 result: victory sends you to 209.'
    return $state
}

$state = New-Section233State
Set-LWHostGameState -State $state | Out-Null

$scenario = @{
    EnemyName                    = 'Oudagorg'
    DoubleEnemyEnduranceLoss     = $false
    UseMindblast                 = $false
    PsychicAttackMode            = 'Psi-surge'
    VictoryResolutionSection     = $null
    VictoryResolutionNote        = $null
}

Invoke-LWRuleSetCombatScenarioRules -State $state -Scenario $scenario
Assert-Section233PsychicSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 209) -Message 'Section 233 should route victory to 209.'
Assert-Section233PsychicSmoke -Condition (-not [bool]$scenario.DoubleEnemyEnduranceLoss) -Message 'Section 233 should not double enemy END loss before psychic attack is selected.'

Invoke-LWRuleSetCombatPsychicAttackRules -State $state -Scenario $scenario
Assert-Section233PsychicSmoke -Condition (-not [bool]$scenario.DoubleEnemyEnduranceLoss) -Message 'Section 233 should not double enemy END loss when Mindblast/Psi-surge is not used.'

$scenario.UseMindblast = $true
Invoke-LWRuleSetCombatPsychicAttackRules -State $state -Scenario $scenario
Assert-Section233PsychicSmoke -Condition ([bool]$scenario.DoubleEnemyEnduranceLoss) -Message 'Section 233 should double enemy END loss when Mindblast/Psi-surge is used.'

$normalState = New-Section233State
$normalState.Combat.UseMindblast = $false
$normalState.Combat.DoubleEnemyEnduranceLoss = $false
$normalResolution = Resolve-LWCombatRound -State $normalState -Roll 5 -EnemyLoss 3 -PlayerLoss 0
Assert-Section233PsychicSmoke -Condition ([int]$normalResolution.EnemyLoss -eq 3) -Message 'Section 233 combat damage should not be doubled when psychic attack is not used.'

$psychicState = New-Section233State
$psychicState.Combat.DoubleEnemyEnduranceLoss = $false
$psychicResolution = Resolve-LWCombatRound -State $psychicState -Roll 5 -EnemyLoss 3 -PlayerLoss 0
Assert-Section233PsychicSmoke -Condition ([int]$psychicResolution.EnemyLoss -eq 6) -Message 'Section 233 psychic combat damage should double enemy END loss, including already-started fights missing the stored flag.'
Assert-Section233PsychicSmoke -Condition (($psychicResolution.Messages -join "`n").Contains("doubles the enemy's ENDURANCE loss")) -Message 'Section 233 psychic doubling should emit a combat message.'

'[PASS] Book 7 section 233 psychic combat smoke'
