$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

function global:Write-LWInfo { param([string]$Message) }
function global:Write-LWWarn { param([string]$Message) }
function global:Write-LWError { param([string]$Message) }
function global:Add-LWNotification { param([string]$Message, [string]$Level) }

function New-LWBookSevenCombatSmokeState {
    param(
        [Parameter(Mandatory = $true)][int]$Section
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Book7 Combat Smoke'
    $state.Character.BookNumber = 7
    $state.CurrentSection = $Section
    $state.RuleSet = 'Magnakai'
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Psi-surge', 'Huntmastery', 'Animal Control', 'Invisibility', 'Pathsmanship')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.Character.CombatSkillBase = 24
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.Inventory.Weapons = @('Sword', 'Bow', 'Quarterstaff', 'Dagger')
    $state.Inventory.BackpackItems = @('Blanket', 'Red Robe', 'Towel')
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)
    Set-LWHostGameState -State $state | Out-Null
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function New-LWBookSevenCombatSmokeScenario {
    param(
        [Parameter(Mandatory = $true)][string]$EnemyName,
        [string]$Weapon = 'Sword'
    )

    return @{
        EnemyName                         = $EnemyName
        EnemyCombatSkill                  = 20
        EnemyEndurance                    = 20
        EnemyImmune                       = $false
        EnemyUndead                       = $false
        EnemyUsesMindforce                = $false
        MindforceLossPerRound             = 0
        CanEvade                          = $false
        EquippedWeapon                    = $Weapon
        UseQuickDefaults                  = $true
        PlayerMod                         = 0
        EnemyMod                          = 0
        PlayerEnduranceLossMultiplier     = 1
        SpecialPlayerEnduranceLossAmount  = 0
        SpecialPlayerEnduranceLossStartRound = 0
        SpecialPlayerEnduranceLossReason  = ''
        SuppressShieldCombatSkillBonus    = $false
        BowRestricted                     = $false
        PlayerModRounds                   = 0
        DeferredEquippedWeapon            = $null
        EquipDeferredWeaponAfterRound     = 0
    }
}

function Assert-LWBookSevenCombatSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$tests = @(
    @{
        Name = 'Section 8 Hound of Death'
        Section = 8
        Enemy = 'Hound of Death'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Psi-surge' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 8 should mark the Hound immune without Psi-surge.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 194) -Message 'Section 8 victory route is wrong.' }
    }
    @{
        Name = 'Section 19 Dhax ambush'
        Section = 19
        Enemy = 'Dhax'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Huntmastery' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq -3) -Message 'Section 19 should apply -3 CS without Huntmastery.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerModRounds -eq 2) -Message 'Section 19 should limit the ambush penalty to 2 rounds.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeAvailableAfterRound -eq 3 -and [int]$scenario.EvadeResolutionSection -eq 241) -Message 'Section 19 evade routing is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 141) -Message 'Section 19 victory route is wrong.' }
    }
    @{
        Name = 'Section 27 Oudakon and Jewelled Mace'
        Section = 27
        Enemy = 'Oudakon'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Huntmastery' }); [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Jewelled Mace') }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq 2) -Message 'Section 27 should net +2 CS (-3 + Jewelled Mace +5).'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerModRounds -eq 3) -Message 'Section 27 should limit the ambush penalty to 3 rounds.'; Assert-LWBookSevenCombatSmoke -Condition (-not [bool]$scenario.CanEvade) -Message 'Section 27 should not allow evasion.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 5) -Message 'Section 27 victory route is wrong.' }
    }
    @{
        Name = 'Section 45 reef rats lore-circle bonus'
        Section = 45
        Enemy = 'Giant Rats'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq 2) -Message 'Section 45 should grant +2 CS from the Lore-circle of Light.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeAvailableAfterRound -eq 3 -and [int]$scenario.EvadeResolutionSection -eq 336) -Message 'Section 45 evade routing is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 283) -Message 'Section 45 victory route is wrong.' }
    }
    @{
        Name = 'Section 76 Lekhor venom'
        Section = 76
        Enemy = 'Lekhor'
        Weapon = 'Quarterstaff'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.SuppressShieldCombatSkillBonus) -Message 'Section 76 should suppress shield bonuses.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerEnduranceLossMultiplier -eq 3) -Message 'Section 76 should treble END loss.'; Assert-LWBookSevenCombatSmoke -Condition ([string]$scenario.EquippedWeapon -eq 'Sword') -Message 'Section 76 should force a fallback away from Quarterstaff.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 296) -Message 'Section 76 victory route is wrong.' }
    }
    @{
        Name = 'Section 78 Hound of Death'
        Section = 78
        Enemy = 'Hound of Death'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Psi-surge' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 78 should mark the Hound immune without Psi-surge.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 341) -Message 'Section 78 victory route is wrong.' }
    }
    @{
        Name = 'Section 93 trap-webs'
        Section = 93
        Enemy = 'Trap-webs'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 93 should mark Trap-webs immune.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq -4) -Message 'Section 93 should apply -4 CS.'; Assert-LWBookSevenCombatSmoke -Condition (-not [bool]$scenario.CanEvade) -Message 'Section 93 should not allow evasion.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 131) -Message 'Section 93 victory route is wrong.' }
    }
    @{
        Name = 'Section 118 Lorestone duel'
        Section = 118
        Enemy = 'Zahda'
        Assert = { param($scenario, $state) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq 2) -Message 'Section 118 should grant +2 CS with Huntmastery.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq [int]$state.Character.EnduranceMax) -Message 'Section 118 should restore END to full before combat.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 200) -Message 'Section 118 victory route is wrong.' }
    }
    @{
        Name = 'Section 126 flame-man without Nexus'
        Section = 126
        Enemy = 'Flame-man'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Nexus' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerEnduranceLossMultiplier -eq 2) -Message 'Section 126 should double END loss without Nexus.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 147) -Message 'Section 126 victory route is wrong.' }
    }
    @{
        Name = 'Section 174 Zahda staff duel'
        Section = 174
        Enemy = 'Zahda'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 174 should mark Zahda immune.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 149) -Message 'Section 174 victory route is wrong.' }
    }
    @{
        Name = 'Section 198 Rahkos'
        Section = 198
        Enemy = 'Rahkos'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Psi-surge' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 198 should mark Rahkos immune without Psi-surge.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 22) -Message 'Section 198 victory route is wrong.' }
    }
    @{
        Name = 'Section 202 Zahda'
        Section = 202
        Enemy = 'Zahda'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Psi-surge' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 202 should mark Zahda immune without Psi-surge.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 149) -Message 'Section 202 victory route is wrong.' }
    }
    @{
        Name = 'Section 219 Hactaraton'
        Section = 219
        Enemy = 'Giant Hactaraton'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Curing' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq -4 -and [int]$scenario.PlayerModRounds -eq 2) -Message 'Section 219 should apply -4 CS in rounds 1-2.'; Assert-LWBookSevenCombatSmoke -Condition ($null -eq $scenario.EquippedWeapon -and [string]$scenario.DeferredEquippedWeapon -eq 'Sword' -and [int]$scenario.EquipDeferredWeaponAfterRound -eq 2) -Message 'Section 219 should defer the equipped weapon until round 3.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerEnduranceLossMultiplier -eq 2) -Message 'Section 219 should double END loss without Curing.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 21) -Message 'Section 219 victory route is wrong.' }
    }
    @{
        Name = 'Section 221 Zagothal with Invisibility'
        Section = 221
        Enemy = 'Zagothal'
        Weapon = 'Bow'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.BowRestricted) -Message 'Section 221 should restrict Bows.'; Assert-LWBookSevenCombatSmoke -Condition ([string]$scenario.EquippedWeapon -eq 'Sword') -Message 'Section 221 should swap away from Bow.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeAvailableAfterRound -eq 0 -and [int]$scenario.EvadeResolutionSection -eq 70) -Message 'Section 221 should allow immediate evade with Invisibility.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 271) -Message 'Section 221 victory route is wrong.' }
    }
    @{
        Name = 'Section 235 Rahkos'
        Section = 235
        Enemy = 'Rahkos'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Psi-surge' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 235 should mark Rahkos immune without Psi-surge.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 22) -Message 'Section 235 victory route is wrong.' }
    }
    @{
        Name = 'Section 245 Hound of Death'
        Section = 245
        Enemy = 'Hound of Death'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Psi-surge' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.EnemyImmune) -Message 'Section 245 should mark the Hound immune without Psi-surge.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 259) -Message 'Section 245 victory route is wrong.' }
    }
    @{
        Name = 'Section 249 Dhax pursuit'
        Section = 249
        Enemy = 'Dhax'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeAvailableAfterRound -eq 3 -and [int]$scenario.EvadeResolutionSection -eq 241) -Message 'Section 249 evade routing is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 141) -Message 'Section 249 victory route is wrong.' }
    }
    @{
        Name = 'Section 253 Dhax bow restriction'
        Section = 253
        Enemy = 'Dhax'
        Weapon = 'Bow'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.BowRestricted) -Message 'Section 253 should restrict Bows.'; Assert-LWBookSevenCombatSmoke -Condition ([string]$scenario.EquippedWeapon -eq 'Sword') -Message 'Section 253 should switch away from Bow.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeResolutionSection -eq 277) -Message 'Section 253 evade route is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 141) -Message 'Section 253 victory route is wrong.' }
    }
    @{
        Name = 'Section 257 Whipmaster'
        Section = 257
        Enemy = 'Invisible Whipmaster'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Huntmastery' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerMod -eq -1) -Message 'Section 257 should net -1 CS without Huntmastery but with improvised protection.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeAvailableAfterRound -eq 3 -and [int]$scenario.EvadeResolutionSection -eq 64) -Message 'Section 257 evade route is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 186) -Message 'Section 257 victory route is wrong.' }
    }
    @{
        Name = 'Section 299 trapped beastmen'
        Section = 299
        Enemy = 'Beastmen'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition (-not [bool]$scenario.CanEvade) -Message 'Section 299 should not allow evasion.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 339) -Message 'Section 299 victory route is wrong.' }
    }
    @{
        Name = 'Section 301 Hactaraton venom'
        Section = 301
        Enemy = 'Giant Hactaraton'
        Arrange = { param($state) $state.Character.MagnakaiDisciplines = @($state.Character.MagnakaiDisciplines | Where-Object { $_ -ne 'Curing' }) }
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.PlayerEnduranceLossMultiplier -eq 2) -Message 'Section 301 should double END loss without Curing.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeAvailableAfterRound -eq 4 -and [int]$scenario.EvadeResolutionSection -eq 91) -Message 'Section 301 evade route is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 21) -Message 'Section 301 victory route is wrong.' }
    }
    @{
        Name = 'Section 314 Dhax bow restriction'
        Section = 314
        Enemy = 'Dhax'
        Weapon = 'Bow'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.BowRestricted) -Message 'Section 314 should restrict Bows.'; Assert-LWBookSevenCombatSmoke -Condition ([string]$scenario.EquippedWeapon -eq 'Sword') -Message 'Section 314 should switch away from Bow.'; Assert-LWBookSevenCombatSmoke -Condition ([bool]$scenario.CanEvade -and [int]$scenario.EvadeResolutionSection -eq 277) -Message 'Section 314 evade route is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 141) -Message 'Section 314 victory route is wrong.' }
    }
    @{
        Name = 'Section 319 Zahda beastmen'
        Section = 319
        Enemy = 'Zahda Beastmen'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition (-not [bool]$scenario.CanEvade) -Message 'Section 319 should not allow evasion.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 56) -Message 'Section 319 victory route is wrong.' }
    }
    @{
        Name = 'Section 325 Black Lakeweed'
        Section = 325
        Enemy = 'Black Lakeweed'
        Assert = { param($scenario) Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.SpecialPlayerEnduranceLossAmount -eq 2) -Message 'Section 325 should apply 2 END loss each round.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.SpecialPlayerEnduranceLossStartRound -eq 1) -Message 'Section 325 should start the special END loss in round 1.'; Assert-LWBookSevenCombatSmoke -Condition ([string]$scenario.SpecialPlayerEnduranceLossReason -eq 'Lack of air') -Message 'Section 325 special loss reason is wrong.'; Assert-LWBookSevenCombatSmoke -Condition ([int]$scenario.VictoryResolutionSection -eq 158) -Message 'Section 325 victory route is wrong.' }
    }
)

$results = @()

foreach ($test in $tests) {
    $state = New-LWBookSevenCombatSmokeState -Section ([int]$test.Section)
    if ($test.ContainsKey('Arrange') -and $null -ne $test.Arrange) {
        & $test.Arrange $state
    }

    $scenario = New-LWBookSevenCombatSmokeScenario -EnemyName ([string]$test.Enemy) -Weapon $(if ($test.ContainsKey('Weapon')) { [string]$test.Weapon } else { 'Sword' })

    try {
        Invoke-LWRuleSetCombatScenarioRules -State $state -Scenario $scenario
        & $test.Assert $scenario $state
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'ok'; Error = '' }
    }
    catch {
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'fail'; Error = $_.Exception.Message }
    }
}

$failures = @($results | Where-Object { $_.Status -ne 'ok' })
Write-Host ("Book 7 combat hook tests: {0}" -f $results.Count)
Write-Host ("Failures: {0}" -f $failures.Count)

foreach ($result in $results) {
    if ($result.Status -eq 'ok') {
        Write-Host ("[PASS] {0}" -f $result.Name)
    }
    else {
        Write-Host ("[FAIL] {0} -- {1}" -f $result.Name, $result.Error)
    }
}

if ($failures.Count -gt 0) {
    exit 1
}
