Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

$script:LWCombatHostCommandCache = @{}
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

function Get-LWCombatHostCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    if ($script:LWCombatHostCommandCache.ContainsKey($Name)) {
        $cachedCommand = $script:LWCombatHostCommandCache[$Name]
        if ($null -ne $cachedCommand) {
            return $cachedCommand
        }
    }

    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $script:LWCombatHostCommandCache[$Name] = $command
    }
    return $command
}

function Get-LWModuleGameData {
    $localGameData = Get-Variable -Scope Script -Name GameData -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $localGameData) {
        return $localGameData
    }

    $contextCommand = Get-LWCombatHostCommand -Name 'Get-LWModuleContext'
    if ($null -ne $contextCommand) {
        $context = & $contextCommand
        if ($context -is [hashtable] -and $context.ContainsKey('GameData') -and $null -ne $context.GameData) {
            Set-Variable -Scope Script -Name GameData -Value $context.GameData -Force
            return $context.GameData
        }
    }

    return $null
}

function Resolve-LWCoreRestrictedBowWeapon {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$EquippedWeapon = $null,
        [string]$SectionLabel = 'This section'
    )

    $restrictedNames = @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames))
    if ([string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $restrictedNames -Target ([string]$EquippedWeapon)))) {
        return $EquippedWeapon
    }

    $fallbackWeapon = [string](
        @(
            $State.Inventory.Weapons | Where-Object {
                [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $restrictedNames -Target ([string]$_)))
            } | Select-Object -First 1
        )
    )

    if (-not [string]::IsNullOrWhiteSpace($fallbackWeapon)) {
        Write-LWWarn ("{0}: a Bow cannot be used here, so you switch to {1}." -f $SectionLabel, $fallbackWeapon)
        return $fallbackWeapon
    }

    Write-LWWarn ("{0}: a Bow cannot be used here and no other weapon is ready, so you fight unarmed." -f $SectionLabel)
    return $null
}

function Invoke-LWCoreStartCombat {
    param(
        [hashtable]$Context,
        [string[]]$Arguments = @()
    )

    Set-LWModuleContext -Context $Context

        if ($null -eq $Arguments) {
            $Arguments = @()
        }
        else {
            $Arguments = @($Arguments)
        }

        if (-not (Test-LWHasState)) {
            Write-LWWarn 'No active character. Use new or load first.'
            return $false
        }
        if ($script:GameState.Combat.Active) {
            Write-LWWarn 'A combat is already active.'
            return $false
        }

        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View = 'setup'
            })

        $encounterProfile = Get-LWRuleSetCombatEncounterProfile -State $script:GameState
        if ($null -ne $encounterProfile -and (Test-LWPropertyExists -Object $encounterProfile -Name 'Blocked') -and [bool]$encounterProfile.Blocked) {
            $warningText = if ((Test-LWPropertyExists -Object $encounterProfile -Name 'Warning') -and -not [string]::IsNullOrWhiteSpace([string]$encounterProfile.Warning)) { [string]$encounterProfile.Warning } else { 'This section is not a valid combat.' }
            Write-LWWarn $warningText
            return $false
        }

        $quickStart = Get-LWCombatStartArguments -Arguments $Arguments
        $useQuickDefaults = $false
        if ($null -ne $quickStart) {
            $enemyName = $quickStart.EnemyName
            $enemyCombatSkill = $quickStart.EnemyCombatSkill
            $enemyEndurance = $quickStart.EnemyEndurance
            Write-LWInfo "Quick combat setup: $enemyName (CS $enemyCombatSkill, END $enemyEndurance)."
            $useQuickDefaults = Read-LWYesNo -Prompt 'Use default combat assumptions for the rest of setup?' -Default $true
        }
        elseif ($null -ne $encounterProfile -and (Test-LWPropertyExists -Object $encounterProfile -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$encounterProfile.EnemyName)) {
            $enemyName = [string]$encounterProfile.EnemyName
            $enemyCombatSkill = [int]$encounterProfile.EnemyCombatSkill
            $enemyEndurance = [int]$encounterProfile.EnemyEndurance
            if ((Test-LWPropertyExists -Object $encounterProfile -Name 'InfoMessage') -and -not [string]::IsNullOrWhiteSpace([string]$encounterProfile.InfoMessage)) {
                Write-LWInfo ([string]$encounterProfile.InfoMessage)
            }
        }
        else {
            $enemyName = Read-LWText -Prompt 'Enemy name'
            $enemyCombatSkill = Read-LWInt -Prompt 'Enemy Combat Skill' -Min 0
            $enemyEndurance = Read-LWInt -Prompt 'Enemy Endurance' -Min 1
        }

        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View             = 'setup'
                EnemyName        = $enemyName
                EnemyCombatSkill = $enemyCombatSkill
                EnemyEndurance   = $enemyEndurance
            })

        $enemyImmune = $false
        $enemyUndead = $false
        $enemyUsesMindforce = $false
        $enemyRequiresMagicSpear = $false
        $enemyRequiresMagicalWeapon = $false
        $canEvade = $false
        $evadeAvailableAfterRound = 0
        $evadeExpiresAfterRound = 0
        $deferredEquippedWeapon = $null
        $equipDeferredWeaponAfterRound = 0
        $evadeResolutionSection = $null
        $evadeResolutionNote = $null
        $oneRoundOnly = $false
        $mindforceLossPerRound = 2
        $playerModRounds = 0
        $playerModAfterRounds = 0
        $playerModAfterRoundStart = $null
        $mindblastCombatSkillBonus = 2
        $victoryResolutionSection = $null
        $victoryResolutionNote = $null
        $victoryWithoutLossSection = $null
        $victoryWithoutLossNote = $null
        $victoryWithinRoundsSection = $null
        $victoryWithinRoundsMax = $null
        $victoryWithinRoundsNote = $null
        $ongoingFailureAfterRoundsSection = $null
        $ongoingFailureAfterRoundsThreshold = $null
        $ongoingFailureAfterRoundsNote = $null
        $playerLossResolutionSection = $null
        $playerLossResolutionNote = $null
        $useJavekPoisonRule = $false
        $allowAletherBeforeCombat = $true
        $specialPlayerLossAmount = 0
        $specialPlayerLossStartRound = 1
        $specialPlayerLossReason = $null
        $ignorePlayerEnduranceLossRounds = 0
        $ignoreEnemyEnduranceLossRounds = 0
        $doubleEnemyEnduranceLoss = $false
        $defeatResolutionSection = $null
        $defeatResolutionNote = $null
        $fallOnRollValue = $null
        $fallOnRollResolutionSection = $null
        $fallOnRollResolutionNote = $null
        $restoreHalfEnduranceLossOnVictory = $false
        $restoreHalfEnduranceLossOnEvade = $false
        $enemyEnduranceThreshold = $null
        $enemyEnduranceThresholdSection = $null
        $enemyEnduranceThresholdNote = $null
        $usePlayerTargetEndurance = $false
        $playerTargetEnduranceCurrent = 0
        $playerTargetEnduranceMax = 0
        $suppressShieldCombatSkillBonus = $false
        $combatPotionsAllowed = $true
        $bowRestricted = $false
        if (-not $useQuickDefaults) {
            $enemyImmune = Read-LWYesNo -Prompt 'Is the enemy immune to Mindblast?' -Default $false
            $enemyUndead = Read-LWYesNo -Prompt 'Is the enemy undead?' -Default $false
            $enemyUsesMindforce = Read-LWYesNo -Prompt 'Is the enemy attacking with Mindforce each combat round?' -Default $false
            $canEvade = Read-LWYesNo -Prompt 'Can Lone Wolf evade this combat if desired?' -Default $false
        }

        if ($null -ne $encounterProfile -and (Test-LWPropertyExists -Object $encounterProfile -Name 'DisableAlether') -and [bool]$encounterProfile.DisableAlether) {
            $allowAletherBeforeCombat = $false
        }

        $equippedWeapon = Select-LWCombatWeapon -DefaultWeapon (Get-LWPreferredCombatWeapon -State $script:GameState)
        $sommerswerdSuppressed = $false
        $aletherCombatSkillBonus = 0
        $attemptKnockout = $false
        if ($allowAletherBeforeCombat -and (Test-LWCombatAletherAvailable -State $script:GameState)) {
            $aletherLocation = Find-LWStateInventoryItemLocation -State $script:GameState -Names @((Get-LWAletherPotionItemNames) + (Get-LWAletherBerryItemNames)) -Types @('herbpouch', 'backpack')
            if ($null -ne $aletherLocation) {
                $aletherPotionName = [string]$aletherLocation.Name
                $aletherInventoryType = [string]$aletherLocation.Type
                $aletherBonus = if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWAletherBerryItemNames) -Target $aletherPotionName))) { 2 } else { 4 }
                $useAlether = Read-LWYesNo -Prompt ("Use {0} before this fight for +{1} Combat Skill?" -f $aletherPotionName, $aletherBonus) -Default $false
                if ($useAlether) {
                    Remove-LWInventoryItem -Type $aletherInventoryType -Name $aletherPotionName -Quantity 1
                    $aletherCombatSkillBonus = $aletherBonus
                    Write-LWInfo ("{0} is used before combat and grants +{1} Combat Skill for this fight." -f $aletherPotionName, $aletherBonus)
                }
            }
        }
        if (Test-LWWeaponIsSommerswerd -Weapon $equippedWeapon) {
            if ((Get-LWCurrentDifficulty) -eq 'Veteran') {
                $textAllowsSommerswerd = Read-LWYesNo -Prompt 'Does the text explicitly allow the Sommerswerd''s power in this combat?' -Default $false
                if (-not $textAllowsSommerswerd) {
                    $sommerswerdSuppressed = $true
                    Write-LWWarn 'Veteran mode suppresses the Sommerswerd unless the text explicitly allows it.'
                }
            }

            if (-not $sommerswerdSuppressed -and -not $useQuickDefaults) {
                $sommerswerdSuppressed = Read-LWYesNo -Prompt 'Is the Sommerswerd suppressed or unable to function in this combat?' -Default $false
            }
        }

        $suppressKnockoutSelection = ($null -ne $encounterProfile -and (Test-LWPropertyExists -Object $encounterProfile -Name 'SuppressKnockout') -and [bool]$encounterProfile.SuppressKnockout)
        if ((-not $suppressKnockoutSelection) -and (Test-LWCombatKnockoutAvailable -State $script:GameState)) {
            $attemptKnockout = Read-LWYesNo -Prompt 'Try to knock this foe unconscious?' -Default $false
            if ($attemptKnockout) {
                $knockoutPenalty = Get-LWCombatKnockoutCombatSkillPenalty -State ([pscustomobject]@{
                        Character = $script:GameState.Character
                        Combat    = [pscustomobject]@{
                            AttemptKnockout = $true
                            EquippedWeapon  = $equippedWeapon
                        }
                    }) -Weapon $equippedWeapon
                if ($knockoutPenalty -gt 0) {
                    Write-LWWarn "Knockout attempt will apply -$knockoutPenalty Combat Skill with $((Get-LWCombatDisplayWeapon -Weapon $equippedWeapon))."
                }
                else {
                    Write-LWInfo 'Knockout attempt has no extra Combat Skill penalty with this weapon.'
                }
            }
        }

        $playerMod = 0
        $enemyMod = 0
        $ignoreFirstRoundEnduranceLoss = $false
        $combatScenario = @{
            EnemyName                        = $enemyName
            UseQuickDefaults                 = $useQuickDefaults
            EnemyImmune                      = $enemyImmune
            EnemyUndead                      = $enemyUndead
            EnemyUsesMindforce               = $enemyUsesMindforce
            EnemyRequiresMagicSpear          = $enemyRequiresMagicSpear
            EnemyRequiresMagicalWeapon       = $enemyRequiresMagicalWeapon
            CanEvade                         = $canEvade
            EvadeAvailableAfterRound         = $evadeAvailableAfterRound
            EvadeExpiresAfterRound           = $evadeExpiresAfterRound
            DeferredEquippedWeapon           = $deferredEquippedWeapon
            EquipDeferredWeaponAfterRound    = $equipDeferredWeaponAfterRound
            EvadeResolutionSection           = $evadeResolutionSection
            EvadeResolutionNote              = $evadeResolutionNote
            OneRoundOnly                     = $oneRoundOnly
            MindforceLossPerRound            = $mindforceLossPerRound
            PlayerMod                        = $playerMod
            EnemyMod                         = $enemyMod
            PlayerModRounds                  = $playerModRounds
            PlayerModAfterRounds             = $playerModAfterRounds
            PlayerModAfterRoundStart         = $playerModAfterRoundStart
            MindblastCombatSkillBonus        = $mindblastCombatSkillBonus
            VictoryResolutionSection         = $victoryResolutionSection
            VictoryResolutionNote            = $victoryResolutionNote
            VictoryWithoutLossSection        = $victoryWithoutLossSection
            VictoryWithoutLossNote           = $victoryWithoutLossNote
            VictoryWithinRoundsSection       = $victoryWithinRoundsSection
            VictoryWithinRoundsMax           = $victoryWithinRoundsMax
            VictoryWithinRoundsNote          = $victoryWithinRoundsNote
            OngoingFailureAfterRoundsSection = $ongoingFailureAfterRoundsSection
            OngoingFailureAfterRoundsThreshold = $ongoingFailureAfterRoundsThreshold
            OngoingFailureAfterRoundsNote    = $ongoingFailureAfterRoundsNote
            PlayerLossResolutionSection      = $playerLossResolutionSection
            PlayerLossResolutionNote         = $playerLossResolutionNote
            UseJavekPoisonRule               = $useJavekPoisonRule
            SpecialPlayerEnduranceLossAmount = $specialPlayerLossAmount
            SpecialPlayerEnduranceLossStartRound = $specialPlayerLossStartRound
            SpecialPlayerEnduranceLossReason = $specialPlayerLossReason
            IgnoreFirstRoundEnduranceLoss    = $ignoreFirstRoundEnduranceLoss
            IgnorePlayerEnduranceLossRounds  = $ignorePlayerEnduranceLossRounds
            IgnoreEnemyEnduranceLossRounds   = $ignoreEnemyEnduranceLossRounds
            DoubleEnemyEnduranceLoss         = $doubleEnemyEnduranceLoss
            DefeatResolutionSection          = $defeatResolutionSection
            DefeatResolutionNote             = $defeatResolutionNote
            FallOnRollValue                  = $fallOnRollValue
            FallOnRollResolutionSection      = $fallOnRollResolutionSection
            FallOnRollResolutionNote         = $fallOnRollResolutionNote
            RestoreHalfEnduranceLossOnVictory = $restoreHalfEnduranceLossOnVictory
            RestoreHalfEnduranceLossOnEvade  = $restoreHalfEnduranceLossOnEvade
            EnemyEnduranceThreshold          = $enemyEnduranceThreshold
            EnemyEnduranceThresholdSection   = $enemyEnduranceThresholdSection
            EnemyEnduranceThresholdNote      = $enemyEnduranceThresholdNote
            UsePlayerTargetEndurance         = $usePlayerTargetEndurance
            PlayerTargetEnduranceCurrent     = $playerTargetEnduranceCurrent
            PlayerTargetEnduranceMax         = $playerTargetEnduranceMax
            SuppressShieldCombatSkillBonus   = $suppressShieldCombatSkillBonus
            CombatPotionsAllowed             = $combatPotionsAllowed
            BowRestricted                    = $bowRestricted
            SommerswerdSuppressed            = $sommerswerdSuppressed
            AttemptKnockout                  = $attemptKnockout
            EquippedWeapon                   = $equippedWeapon
        }
        Invoke-LWRuleSetCombatScenarioRules -State $script:GameState -Scenario $combatScenario
        $enemyImmune = [bool]$combatScenario.EnemyImmune
        $enemyUndead = [bool]$combatScenario.EnemyUndead
        $enemyUsesMindforce = [bool]$combatScenario.EnemyUsesMindforce
        $enemyRequiresMagicSpear = [bool]$combatScenario.EnemyRequiresMagicSpear
        $enemyRequiresMagicalWeapon = [bool]$combatScenario.EnemyRequiresMagicalWeapon
        $canEvade = [bool]$combatScenario.CanEvade
        $evadeAvailableAfterRound = [int]$combatScenario.EvadeAvailableAfterRound
        $evadeExpiresAfterRound = [int]$combatScenario.EvadeExpiresAfterRound
        $deferredEquippedWeapon = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.DeferredEquippedWeapon)) { $null } else { [string]$combatScenario.DeferredEquippedWeapon }
        $equipDeferredWeaponAfterRound = [int]$combatScenario.EquipDeferredWeaponAfterRound
        $evadeResolutionSection = if ($null -eq $combatScenario.EvadeResolutionSection) { $null } else { [int]$combatScenario.EvadeResolutionSection }
        $evadeResolutionNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.EvadeResolutionNote)) { $null } else { [string]$combatScenario.EvadeResolutionNote }
        $oneRoundOnly = [bool]$combatScenario.OneRoundOnly
        $mindforceLossPerRound = [int]$combatScenario.MindforceLossPerRound
        $playerMod = [int]$combatScenario.PlayerMod
        $enemyMod = [int]$combatScenario.EnemyMod
        $playerModRounds = [int]$combatScenario.PlayerModRounds
        $playerModAfterRounds = [int]$combatScenario.PlayerModAfterRounds
        $playerModAfterRoundStart = if ($null -eq $combatScenario.PlayerModAfterRoundStart) { $null } else { [int]$combatScenario.PlayerModAfterRoundStart }
        $mindblastCombatSkillBonus = [int]$combatScenario.MindblastCombatSkillBonus
        $victoryResolutionSection = if ($null -eq $combatScenario.VictoryResolutionSection) { $null } else { [int]$combatScenario.VictoryResolutionSection }
        $victoryResolutionNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.VictoryResolutionNote)) { $null } else { [string]$combatScenario.VictoryResolutionNote }
        $victoryWithoutLossSection = if ($null -eq $combatScenario.VictoryWithoutLossSection) { $null } else { [int]$combatScenario.VictoryWithoutLossSection }
        $victoryWithoutLossNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.VictoryWithoutLossNote)) { $null } else { [string]$combatScenario.VictoryWithoutLossNote }
        $victoryWithinRoundsSection = if ($null -eq $combatScenario.VictoryWithinRoundsSection) { $null } else { [int]$combatScenario.VictoryWithinRoundsSection }
        $victoryWithinRoundsMax = if ($null -eq $combatScenario.VictoryWithinRoundsMax) { $null } else { [int]$combatScenario.VictoryWithinRoundsMax }
        $victoryWithinRoundsNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.VictoryWithinRoundsNote)) { $null } else { [string]$combatScenario.VictoryWithinRoundsNote }
        $ongoingFailureAfterRoundsSection = if ($null -eq $combatScenario.OngoingFailureAfterRoundsSection) { $null } else { [int]$combatScenario.OngoingFailureAfterRoundsSection }
        $ongoingFailureAfterRoundsThreshold = if ($null -eq $combatScenario.OngoingFailureAfterRoundsThreshold) { $null } else { [int]$combatScenario.OngoingFailureAfterRoundsThreshold }
        $ongoingFailureAfterRoundsNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.OngoingFailureAfterRoundsNote)) { $null } else { [string]$combatScenario.OngoingFailureAfterRoundsNote }
        $playerLossResolutionSection = if ($null -eq $combatScenario.PlayerLossResolutionSection) { $null } else { [int]$combatScenario.PlayerLossResolutionSection }
        $playerLossResolutionNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.PlayerLossResolutionNote)) { $null } else { [string]$combatScenario.PlayerLossResolutionNote }
        $useJavekPoisonRule = [bool]$combatScenario.UseJavekPoisonRule
        $specialPlayerLossAmount = [int]$combatScenario.SpecialPlayerEnduranceLossAmount
        $specialPlayerLossStartRound = [int]$combatScenario.SpecialPlayerEnduranceLossStartRound
        $specialPlayerLossReason = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.SpecialPlayerEnduranceLossReason)) { $null } else { [string]$combatScenario.SpecialPlayerEnduranceLossReason }
        $ignoreFirstRoundEnduranceLoss = [bool]$combatScenario.IgnoreFirstRoundEnduranceLoss
        $ignorePlayerEnduranceLossRounds = [int]$combatScenario.IgnorePlayerEnduranceLossRounds
        $ignoreEnemyEnduranceLossRounds = [int]$combatScenario.IgnoreEnemyEnduranceLossRounds
        $doubleEnemyEnduranceLoss = [bool]$combatScenario.DoubleEnemyEnduranceLoss
        $defeatResolutionSection = if ($null -eq $combatScenario.DefeatResolutionSection) { $null } else { [int]$combatScenario.DefeatResolutionSection }
        $defeatResolutionNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.DefeatResolutionNote)) { $null } else { [string]$combatScenario.DefeatResolutionNote }
        $fallOnRollValue = if ($null -eq $combatScenario.FallOnRollValue) { $null } else { [int]$combatScenario.FallOnRollValue }
        $fallOnRollResolutionSection = if ($null -eq $combatScenario.FallOnRollResolutionSection) { $null } else { [int]$combatScenario.FallOnRollResolutionSection }
        $fallOnRollResolutionNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.FallOnRollResolutionNote)) { $null } else { [string]$combatScenario.FallOnRollResolutionNote }
        $restoreHalfEnduranceLossOnVictory = [bool]$combatScenario.RestoreHalfEnduranceLossOnVictory
        $restoreHalfEnduranceLossOnEvade = [bool]$combatScenario.RestoreHalfEnduranceLossOnEvade
        $enemyEnduranceThreshold = if ($null -eq $combatScenario.EnemyEnduranceThreshold) { $null } else { [int]$combatScenario.EnemyEnduranceThreshold }
        $enemyEnduranceThresholdSection = if ($null -eq $combatScenario.EnemyEnduranceThresholdSection) { $null } else { [int]$combatScenario.EnemyEnduranceThresholdSection }
        $enemyEnduranceThresholdNote = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.EnemyEnduranceThresholdNote)) { $null } else { [string]$combatScenario.EnemyEnduranceThresholdNote }
        $usePlayerTargetEndurance = [bool]$combatScenario.UsePlayerTargetEndurance
        $playerTargetEnduranceCurrent = [int]$combatScenario.PlayerTargetEnduranceCurrent
        $playerTargetEnduranceMax = [int]$combatScenario.PlayerTargetEnduranceMax
        $suppressShieldCombatSkillBonus = [bool]$combatScenario.SuppressShieldCombatSkillBonus
        $combatPotionsAllowed = [bool]$combatScenario.CombatPotionsAllowed
        $bowRestricted = [bool]$combatScenario.BowRestricted
        $sommerswerdSuppressed = [bool]$combatScenario.SommerswerdSuppressed
        $attemptKnockout = [bool]$combatScenario.AttemptKnockout
        $equippedWeapon = if ([string]::IsNullOrWhiteSpace([string]$combatScenario.EquippedWeapon)) { $null } else { [string]$combatScenario.EquippedWeapon }

        $psychicAttackMode = 'Mindblast'
        $useMindblast = $false
        $hasPsiSurge = (Test-LWStateIsMagnakaiRuleset -State $script:GameState) -and (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')
        $hasMindblast = Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindblast'
        if (-not $enemyImmune -and ($hasPsiSurge -or $hasMindblast)) {
            if ($hasPsiSurge -and [int]$script:GameState.Character.EnduranceCurrent -le 6) {
                Write-LWWarn 'Psi-surge cannot be used at 6 ENDURANCE or lower.'
            }
            elseif ($hasPsiSurge) {
                $psychicAttackMode = 'Psi-surge'
                if ($useQuickDefaults) {
                    $useMindblast = $true
                    Write-LWInfo 'Psi-surge is available and enabled by default for this combat.'
                }
                else {
                    $useMindblast = Read-LWYesNo -Prompt 'Use Psi-surge in this combat?' -Default $true
                }
            }
            elseif ($hasMindblast) {
                $psychicAttackMode = 'Mindblast'
                if ($useQuickDefaults) {
                    $useMindblast = $true
                    Write-LWInfo 'Mindblast is available and enabled by default for this combat.'
                }
                else {
                    $useMindblast = Read-LWYesNo -Prompt 'Use Mindblast in this combat?' -Default $true
                }
            }
        }

        if (-not $useQuickDefaults) {
            if (Read-LWYesNo -Prompt 'Any manual Combat Skill modifiers for this fight?' -Default $false) {
                $playerMod += Read-LWInt -Prompt 'Manual player Combat Skill modifier for this combat' -Default 0
                $enemyMod += Read-LWInt -Prompt 'Manual enemy Combat Skill modifier for this combat' -Default 0
            }
        }

        $script:GameState.Combat = [pscustomobject]@{
            Active                    = $true
            EnemyName                 = $enemyName
            EnemyCombatSkill          = $enemyCombatSkill
            EnemyEnduranceCurrent     = $enemyEndurance
            EnemyEnduranceMax         = $enemyEndurance
            EnemyIsUndead             = $enemyUndead
            EnemyUsesMindforce        = $enemyUsesMindforce
            EnemyRequiresMagicSpear   = $enemyRequiresMagicSpear
            EnemyRequiresMagicalWeapon = $enemyRequiresMagicalWeapon
            EnemyImmuneToMindblast    = $enemyImmune
            UseMindblast              = $useMindblast
            PsychicAttackMode         = $psychicAttackMode
            MindblastCombatSkillBonus = $mindblastCombatSkillBonus
            AletherCombatSkillBonus   = $aletherCombatSkillBonus
            AttemptKnockout           = $attemptKnockout
            CanEvade                  = $canEvade
            EvadeAvailableAfterRound  = $evadeAvailableAfterRound
            EvadeExpiresAfterRound    = $evadeExpiresAfterRound
            EvadeResolutionSection    = $evadeResolutionSection
            EvadeResolutionNote       = $evadeResolutionNote
            EquippedWeapon            = $equippedWeapon
            DeferredEquippedWeapon    = $deferredEquippedWeapon
            EquipDeferredWeaponAfterRound = $equipDeferredWeaponAfterRound
            SommerswerdSuppressed     = $sommerswerdSuppressed
            IgnoreFirstRoundEnduranceLoss = $ignoreFirstRoundEnduranceLoss
            IgnorePlayerEnduranceLossRounds = $(if ($ignorePlayerEnduranceLossRounds -gt 0) { $ignorePlayerEnduranceLossRounds } elseif ($ignoreFirstRoundEnduranceLoss) { 1 } else { 0 })
            IgnoreEnemyEnduranceLossRounds = $ignoreEnemyEnduranceLossRounds
            DoubleEnemyEnduranceLoss  = $doubleEnemyEnduranceLoss
            OneRoundOnly              = $oneRoundOnly
            SpecialResolutionSection  = $null
            SpecialResolutionNote     = $null
            VictoryResolutionSection  = $victoryResolutionSection
            VictoryResolutionNote     = $victoryResolutionNote
            VictoryWithoutLossSection = $victoryWithoutLossSection
            VictoryWithoutLossNote    = $victoryWithoutLossNote
            VictoryWithinRoundsSection = $victoryWithinRoundsSection
            VictoryWithinRoundsMax    = $victoryWithinRoundsMax
            VictoryWithinRoundsNote   = $victoryWithinRoundsNote
            OngoingFailureAfterRoundsSection = $ongoingFailureAfterRoundsSection
            OngoingFailureAfterRoundsThreshold = $ongoingFailureAfterRoundsThreshold
            OngoingFailureAfterRoundsNote = $ongoingFailureAfterRoundsNote
            PlayerLossResolutionSection = $playerLossResolutionSection
            PlayerLossResolutionNote  = $playerLossResolutionNote
            DefeatResolutionSection   = $defeatResolutionSection
            DefeatResolutionNote      = $defeatResolutionNote
            JavekPoisonRule           = $useJavekPoisonRule
            FallOnRollValue           = $fallOnRollValue
            FallOnRollResolutionSection = $fallOnRollResolutionSection
            FallOnRollResolutionNote  = $fallOnRollResolutionNote
            RestoreHalfEnduranceLossOnVictory = $restoreHalfEnduranceLossOnVictory
            RestoreHalfEnduranceLossOnEvade = $restoreHalfEnduranceLossOnEvade
            EnemyEnduranceThreshold = $enemyEnduranceThreshold
            EnemyEnduranceThresholdSection = $enemyEnduranceThresholdSection
            EnemyEnduranceThresholdNote = $enemyEnduranceThresholdNote
            MindforceLossPerRound     = $mindforceLossPerRound
            UsePlayerTargetEndurance = $usePlayerTargetEndurance
            PlayerTargetEnduranceCurrent = $playerTargetEnduranceCurrent
            PlayerTargetEnduranceMax = $playerTargetEnduranceMax
            CombatPotionsAllowed     = $combatPotionsAllowed
            BowRestricted            = $bowRestricted
            SuppressShieldCombatSkillBonus = $suppressShieldCombatSkillBonus
            PlayerCombatSkillModifier = $playerMod
            PlayerCombatSkillModifierRounds = $playerModRounds
            PlayerCombatSkillModifierAfterRounds = $playerModAfterRounds
            PlayerCombatSkillModifierAfterRoundStart = $playerModAfterRoundStart
            EnemyCombatSkillModifier  = $enemyMod
            SpecialPlayerEnduranceLossAmount = $specialPlayerLossAmount
            SpecialPlayerEnduranceLossStartRound = $specialPlayerLossStartRound
            SpecialPlayerEnduranceLossReason = $specialPlayerLossReason
            Log                       = @()
        }
        if (-not [string]::IsNullOrWhiteSpace($equippedWeapon)) {
            $script:GameState.Character.LastCombatWeapon = $equippedWeapon
        }
        elseif (-not [string]::IsNullOrWhiteSpace($deferredEquippedWeapon)) {
            $script:GameState.Character.LastCombatWeapon = $deferredEquippedWeapon
        }

        $script:GameState.SectionHadCombat = $true
        Register-LWCombatStarted

        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View = 'status'
            })
        Write-LWInfo "Combat started against $enemyName."
        Invoke-LWMaybeAutosave
        return $true
}

Export-ModuleMember -Function `
    Invoke-LWCoreStartCombat, `
    Resolve-LWCoreRestrictedBowWeapon

function Get-LWPreferredCombatWeapon {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $weapons = @(Get-LWStateCombatWeapons -State $State)
    if ($weapons.Count -eq 0) {
        return $null
    }

    $lastWeapon = Get-LWMatchingValue -Values $weapons -Target ([string]$State.Character.LastCombatWeapon)
    if (-not [string]::IsNullOrWhiteSpace($lastWeapon)) {
        return $lastWeapon
    }

    $sommerswerd = Get-LWMatchingValue -Values $weapons -Target 'Sommerswerd'
    if (-not [string]::IsNullOrWhiteSpace($sommerswerd)) {
        return $sommerswerd
    }

    if (Test-LWStateHasActiveWeaponskill -State $State) {
        $weaponskillWeapon = Get-LWMatchingValue -Values $weapons -Target ([string]$State.Character.WeaponskillWeapon)
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Warhammer') {
            $weaponskillWeapon = [string]($weapons | Where-Object { (Test-LWWeaponIsDrodarinWarHammer -Weapon ([string]$_)) -or (Test-LWWeaponIsBroninWarhammer -Weapon ([string]$_)) } | Select-Object -First 1)
        }
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Broadsword') {
            $weaponskillWeapon = [string]($weapons | Where-Object { (Test-LWWeaponIsBroadswordPlusOne -Weapon ([string]$_)) -or (Test-LWWeaponIsSolnaris -Weapon ([string]$_)) } | Select-Object -First 1)
        }
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Sword') {
            $weaponskillWeapon = [string]($weapons | Where-Object { (Test-LWWeaponIsCaptainDValSword -Weapon ([string]$_)) -or (Test-LWWeaponIsSolnaris -Weapon ([string]$_)) } | Select-Object -First 1)
        }
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Spear') {
            $weaponskillWeapon = [string]($weapons | Where-Object { Test-LWWeaponIsMagicSpear -Weapon ([string]$_) } | Select-Object -First 1)
        }
        if (-not [string]::IsNullOrWhiteSpace($weaponskillWeapon)) {
            return $weaponskillWeapon
        }
    }

    if ((Test-LWStateIsMagnakaiRuleset -State $State) -and @($State.Character.WeaponmasteryWeapons).Count -gt 0) {
        $weaponmasteryWeapon = [string]($weapons | Where-Object { Test-LWWeaponMatchesWeaponmastery -Weapon ([string]$_) -WeaponmasteryWeapons @($State.Character.WeaponmasteryWeapons) } | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($weaponmasteryWeapon)) {
            return $weaponmasteryWeapon
        }
    }

    return [string]$weapons[0]
}

function Get-LWCombatStartArguments {
    param([string[]]$Arguments = @())
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $Arguments) {
        $Arguments = @()
    }
    else {
        $Arguments = @($Arguments)
    }

    if ($Arguments.Count -lt 3) {
        return $null
    }

    $enemyCombatSkill = 0
    $enemyEndurance = 0
    if (-not [int]::TryParse($Arguments[$Arguments.Count - 2], [ref]$enemyCombatSkill)) {
        return $null
    }
    if (-not [int]::TryParse($Arguments[$Arguments.Count - 1], [ref]$enemyEndurance)) {
        return $null
    }

    $enemyName = (@($Arguments[0..($Arguments.Count - 3)]) -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($enemyName)) {
        return $null
    }

    return [pscustomobject]@{
        EnemyName        = $enemyName
        EnemyCombatSkill = $enemyCombatSkill
        EnemyEndurance   = $enemyEndurance
    }
}

function Get-LWCRTValidation {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $gameData = Get-LWModuleGameData
    $requiredRatios = -11..11
    $messages = @()
    $missingEntries = @()
    $invalidEntries = @()
    $usableEntryCount = 0
    $ratioKeys = @()

    if ($null -eq $gameData -or $null -eq $gameData.CRT) {
        return [pscustomobject]@{
            Present          = $false
            IsComplete       = $false
            UsableEntryCount = 0
            RatioKeys        = @()
            MissingEntries   = @('crt.json not found')
            InvalidEntries   = @()
            Messages         = @('No data/crt.json found.')
        }
    }

    foreach ($property in $gameData.CRT.PSObject.Properties) {
        $ratioValue = 0
        if ([int]::TryParse($property.Name, [ref]$ratioValue)) {
            $ratioKeys += $ratioValue
        }
    }

    foreach ($ratio in $requiredRatios) {
        $ratioNode = Get-LWJsonProperty -Object $gameData.CRT -Name ([string]$ratio)
        if ($null -eq $ratioNode) {
            foreach ($roll in 0..9) {
                $missingEntries += "$ratio/$roll"
            }
            continue
        }

        foreach ($roll in 0..9) {
            $entry = Get-LWJsonProperty -Object $ratioNode -Name ([string]$roll)
            if ($null -eq $entry) {
                $missingEntries += "$ratio/$roll"
                continue
            }

            $enemyLossRaw = Get-LWJsonProperty -Object $entry -Name 'EnemyLoss'
            $playerLossRaw = Get-LWJsonProperty -Object $entry -Name 'PlayerLoss'
            $enemyValid = $false
            $playerValid = $false

            if ([string]$enemyLossRaw -eq 'K') {
                $enemyValid = $true
            }
            else {
                $enemyLoss = 0
                $enemyValid = [int]::TryParse([string]$enemyLossRaw, [ref]$enemyLoss)
            }

            if ([string]$playerLossRaw -eq 'K') {
                $playerValid = $true
            }
            else {
                $playerLoss = 0
                $playerValid = [int]::TryParse([string]$playerLossRaw, [ref]$playerLoss)
            }

            if (-not $enemyValid -or -not $playerValid) {
                $invalidEntries += "$ratio/$roll"
                continue
            }

            $usableEntryCount += 1
        }
    }

    if ($missingEntries.Count -gt 0) {
        $messages += "CRT data is missing $($missingEntries.Count) result(s). Missing results will fall back to manual entry."
    }
    if ($invalidEntries.Count -gt 0) {
        $messages += "CRT data has $($invalidEntries.Count) invalid result(s). Invalid results will fall back to manual entry."
    }
    if ($usableEntryCount -eq 0) {
        $messages += 'CRT data does not contain any usable results yet.'
    }

    return [pscustomobject]@{
        Present          = $true
        IsComplete       = ($missingEntries.Count -eq 0 -and $invalidEntries.Count -eq 0 -and $usableEntryCount -gt 0)
        UsableEntryCount = $usableEntryCount
        RatioKeys        = @($ratioKeys | Sort-Object -Unique)
        MissingEntries   = @($missingEntries)
        InvalidEntries   = @($invalidEntries)
        Messages         = @($messages)
    }
}

function Get-LWDefaultCombatMode {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $validation = Get-LWCRTValidation
    if ($validation.IsComplete) {
        return 'DataFile'
    }

    return 'ManualCRT'
}

function Convert-LWCRTLossValue {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][int]$CurrentEndurance
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]$Value -eq 'K') {
        return $CurrentEndurance
    }

    $loss = 0
    if ([int]::TryParse([string]$Value, [ref]$loss)) {
        return $loss
    }

    return $null
}

function Get-LWWeaponskillWeapon {
    param([Parameter(Mandatory = $true)][int]$Roll)
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $gameData = Get-LWModuleGameData


    if ($null -eq $gameData -or $null -eq $gameData.WeaponskillMap) {
        return $null
    }

    return (Get-LWJsonProperty -Object $gameData.WeaponskillMap -Name ([string]$Roll))
}

function Get-LWCombatPlayerEndurancePool {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $combatEnduranceBonus = Get-LWStateBroninSleeveShieldCombatEnduranceBonus -State $State
    $usesTarget = ((Test-LWPropertyExists -Object $State -Name 'Combat') -and
        (Test-LWPropertyExists -Object $State.Combat -Name 'UsePlayerTargetEndurance') -and
        [bool]$State.Combat.UsePlayerTargetEndurance)

    if ($usesTarget) {
        $current = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerTargetEnduranceCurrent') -and $null -ne $State.Combat.PlayerTargetEnduranceCurrent) { [int]$State.Combat.PlayerTargetEnduranceCurrent } else { 0 }
        $max = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerTargetEnduranceMax') -and $null -ne $State.Combat.PlayerTargetEnduranceMax) { [int]$State.Combat.PlayerTargetEnduranceMax } else { $current }
        return [pscustomobject]@{
            UsesTarget = $true
            Current    = $current + $combatEnduranceBonus
            Max        = $max + $combatEnduranceBonus
            Label      = 'Target'
            CombatBonus = $combatEnduranceBonus
        }
    }

    return [pscustomobject]@{
        UsesTarget = $false
        Current    = [int]$State.Character.EnduranceCurrent + $combatEnduranceBonus
        Max        = [int]$State.Character.EnduranceMax + $combatEnduranceBonus
        Label      = 'Endurance'
        CombatBonus = $combatEnduranceBonus
    }
}

function Get-LWCombatBreakdownFromState {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not $State.Combat.Active) {
        return $null
    }

    $playerCombatSkill = [int]$State.Character.CombatSkillBase
    $enemyCombatSkill = [int]$State.Combat.EnemyCombatSkill
    $notes = @()

    $shieldBonus = Get-LWStateShieldCombatSkillBonus -State $State
    if ($shieldBonus -gt 0) {
        $playerCombatSkill += $shieldBonus
        $notes += "Shield +$shieldBonus"
    }
    elseif ((Test-LWPropertyExists -Object $State.Combat -Name 'SuppressShieldCombatSkillBonus') -and
        [bool]$State.Combat.SuppressShieldCombatSkillBonus -and
        (Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames))) {
        $notes += 'Shield suppressed'
    }

    $broninSleeveShieldBonus = Get-LWStateBroninSleeveShieldCombatSkillBonus -State $State
    if ($broninSleeveShieldBonus -gt 0) {
        $playerCombatSkill += $broninSleeveShieldBonus
        $notes += "Bronin Sleeve-shield +$broninSleeveShieldBonus"
    }

    $silverHelmBonus = Get-LWStateSilverHelmCombatSkillBonus -State $State
    if ($silverHelmBonus -gt 0) {
        $playerCombatSkill += $silverHelmBonus
        $notes += "Silver Helm +$silverHelmBonus"
    }

    if ($State.Combat.UseMindblast) {
        $psychicBonus = Get-LWCombatPsychicAttackBonus -State $State
        $psychicLabel = Get-LWCombatPsychicAttackLabel -State $State
        $playerCombatSkill += $psychicBonus
        $notes += "$psychicLabel +$psychicBonus"
    }

    $aletherBonus = Get-LWStateAletherCombatSkillBonus -State $State
    if ($aletherBonus -gt 0) {
        $playerCombatSkill += $aletherBonus
        $notes += "Alether +$aletherBonus"
    }

    if (Test-LWBookFiveLimbdeathActive -State $State) {
        $playerCombatSkill -= 3
        $notes += 'Limbdeath -3'
        if ((Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames)) -and (Get-LWStateShieldCombatSkillBonus -State $State) -eq 0) {
            $notes += 'Shield unusable'
        }
    }

    $knockoutPenalty = Get-LWCombatKnockoutCombatSkillPenalty -State $State
    if ([bool]$State.Combat.AttemptKnockout) {
        if ($knockoutPenalty -gt 0) {
            $playerCombatSkill -= $knockoutPenalty
            $notes += "Knockout attempt -$knockoutPenalty"
        }
        else {
            $notes += 'Knockout attempt (no CS penalty)'
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$State.Combat.EquippedWeapon)) {
        $playerCombatSkill -= 4
        $notes += 'Unarmed -4'
    }
    elseif (Test-LWWeaponIsSommerswerd -Weapon ([string]$State.Combat.EquippedWeapon)) {
        if (-not (Test-LWCombatSommerswerdAvailable -State $State)) {
            $notes += 'Sommerswerd unavailable before Book 2'
        }
        elseif ([bool]$State.Combat.SommerswerdSuppressed) {
            $notes += 'Sommerswerd suppressed'

            $fallbackBonus = Get-LWStateSommerswerdFallbackWeaponskillBonus -State $State
            if ($fallbackBonus -gt 0) {
                $playerCombatSkill += $fallbackBonus
                $notes += "Weaponskill +$fallbackBonus (Sommerswerd as sword)"
            }
        }
        else {
            $sommerswerdBonus = Get-LWStateSommerswerdCombatSkillBonus -State $State
            if ($sommerswerdBonus -gt 0) {
                $playerCombatSkill += $sommerswerdBonus
                if ($sommerswerdBonus -ge 10) {
                    $notes += "Sommerswerd +$sommerswerdBonus (Weaponskill)"
                }
                else {
                    $notes += "Sommerswerd +$sommerswerdBonus"
                }
            }
            if ([bool]$State.Combat.EnemyIsUndead) {
                $notes += 'Undead damage x2'
            }
        }
    }
    elseif (Test-LWWeaponIsBoneSword -Weapon ([string]$State.Combat.EquippedWeapon)) {
        $boneSwordBonus = Get-LWStateBoneSwordCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($boneSwordBonus -gt 0) {
            $playerCombatSkill += $boneSwordBonus
            $notes += "Bone Sword +$boneSwordBonus (Kalte)"
        }
        else {
            $notes += 'Bone Sword inactive outside Kalte'
        }
    }
    else {
        $broadswordPlusOneBonus = Get-LWStateBroadswordPlusOneCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($broadswordPlusOneBonus -gt 0) {
            $playerCombatSkill += $broadswordPlusOneBonus
            $notes += "Broadsword +$broadswordPlusOneBonus"
        }

        $drodarinWarHammerBonus = Get-LWStateDrodarinWarHammerCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($drodarinWarHammerBonus -gt 0) {
            $playerCombatSkill += $drodarinWarHammerBonus
            $notes += "Drodarin War Hammer +$drodarinWarHammerBonus"
        }

        $broninWarhammerBonus = Get-LWStateBroninWarhammerCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($broninWarhammerBonus -gt 0) {
            $playerCombatSkill += $broninWarhammerBonus
            $notes += "Bronin Warhammer +$broninWarhammerBonus"
        }

        $captainDValSwordBonus = Get-LWStateCaptainDValSwordCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($captainDValSwordBonus -gt 0) {
            $playerCombatSkill += $captainDValSwordBonus
            $notes += "Captain D'Val's Sword +$captainDValSwordBonus"
        }

        $solnarisBonus = Get-LWStateSolnarisCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($solnarisBonus -gt 0) {
            $playerCombatSkill += $solnarisBonus
            $notes += "Solnaris +$solnarisBonus"
        }

        $weaponmasteryBonus = Get-LWStateWeaponmasteryCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($weaponmasteryBonus -gt 0) {
            $playerCombatSkill += $weaponmasteryBonus
            $notes += "Weaponmastery +$weaponmasteryBonus"
        }

        if ((Test-LWStateHasActiveWeaponskill -State $State) -and (Test-LWWeaponMatchesWeaponskill -Weapon ([string]$State.Combat.EquippedWeapon) -WeaponskillWeapon ([string]$State.Character.WeaponskillWeapon))) {
            $playerCombatSkill += 2
            $weaponskillLabel = if ((Test-LWWeaponIsDrodarinWarHammer -Weapon ([string]$State.Combat.EquippedWeapon)) -or (Test-LWWeaponIsBroninWarhammer -Weapon ([string]$State.Combat.EquippedWeapon))) { 'Warhammer' } elseif (Test-LWWeaponIsBroadswordPlusOne -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Broadsword' } elseif (Test-LWWeaponIsCaptainDValSword -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Sword' } elseif (Test-LWWeaponIsSolnaris -Weapon ([string]$State.Combat.EquippedWeapon)) { [string]$State.Character.WeaponskillWeapon } else { [string]$State.Combat.EquippedWeapon }
            $notes += "Weaponskill +2 ($weaponskillLabel)"
        }
    }

    if ([bool]$State.Combat.EnemyUsesMindforce) {
        if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
            $notes += ("Mindforce blocked by {0}" -f $(if (Test-LWStateHasDiscipline -State $State -Name 'Psi-screen') { 'Psi-screen' } else { 'Mindshield' }))
        }
        else {
            $notes += ("Mindforce -{0} END each round" -f (Get-LWCombatMindforceLossPerRound -State $State))
        }
    }
    if ([bool]$State.Combat.EnemyRequiresMagicSpear) {
        if (Test-LWWeaponIsMagicSpear -Weapon ([string]$State.Combat.EquippedWeapon)) {
            $notes += 'Only Magic Spear can wound this foe'
        }
        else {
            $notes += 'Enemy can only be harmed by Magic Spear'
        }
    }
    elseif ((Test-LWPropertyExists -Object $State.Combat -Name 'EnemyRequiresMagicalWeapon') -and [bool]$State.Combat.EnemyRequiresMagicalWeapon) {
        if (Test-LWWeaponIsMagicalForCombat -Weapon ([string]$State.Combat.EquippedWeapon)) {
            $notes += 'Only a magical weapon can wound this foe'
        }
        else {
            $notes += 'Enemy can only be harmed by a magical weapon'
        }
    }

    $activePlayerModifier = Get-LWCombatActivePlayerCombatSkillModifier -State $State
    if ($activePlayerModifier -ne 0) {
        $playerCombatSkill += $activePlayerModifier
        $modifierRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierRounds) { [int]$State.Combat.PlayerCombatSkillModifierRounds } else { 0 }
        $afterModifier = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRounds) { [int]$State.Combat.PlayerCombatSkillModifierAfterRounds } else { 0 }
        $afterStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRoundStart') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRoundStart) { [int]$State.Combat.PlayerCombatSkillModifierAfterRoundStart } else { 0 }
        if ($modifierRounds -gt 0 -and $afterModifier -ne 0 -and $afterStartRound -gt 0) {
            $notes += "Player modifier changes after round $($afterStartRound - 1)"
        }
        elseif ($modifierRounds -gt 0) {
            $notes += "Player modifier $(Format-LWSigned -Value $activePlayerModifier) (rounds 1-$modifierRounds)"
        }
        elseif ($afterModifier -ne 0 -and $afterStartRound -gt 0) {
            $notes += "Player modifier $(Format-LWSigned -Value $activePlayerModifier) (round $afterStartRound+)"
        }
        else {
            $notes += "Player modifier $(Format-LWSigned -Value $activePlayerModifier)"
        }
    }

    if ([int]$State.Combat.EnemyCombatSkillModifier -ne 0) {
        $enemyCombatSkill += [int]$State.Combat.EnemyCombatSkillModifier
        $notes += "Enemy modifier $(Format-LWSigned -Value ([int]$State.Combat.EnemyCombatSkillModifier))"
    }

    $playerEndurancePool = Get-LWCombatPlayerEndurancePool -State $State
    if ([bool]$playerEndurancePool.UsesTarget) {
        $notes += 'Target points combat'
    }

    $specialLossAmount = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossAmount) { [int]$State.Combat.SpecialPlayerEnduranceLossAmount } else { 0 }
    if ($specialLossAmount -gt 0) {
        $specialLossStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$State.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
        $specialLossReason = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossReason') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.SpecialPlayerEnduranceLossReason)) { [string]$State.Combat.SpecialPlayerEnduranceLossReason } else { 'Special hazard' }
        $notes += ("{0} -{1} END from round {2}" -f $specialLossReason, $specialLossAmount, $specialLossStartRound)
    }

    if ([bool]$State.Combat.CanEvade) {
        $evadeStatus = Get-LWCombatEvadeStatusText -State $State
        if ($evadeStatus -ne 'Yes') {
            $notes += ("Evade {0}" -f $evadeStatus.ToLowerInvariant())
        }
    }

    return [pscustomobject]@{
        PlayerCombatSkill = $playerCombatSkill
        EnemyCombatSkill  = $enemyCombatSkill
        CombatRatio       = ($playerCombatSkill - $enemyCombatSkill)
        Notes             = $notes
    }
}

function Get-LWCombatBreakdown {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        return $null
    }

    return (Get-LWCombatBreakdownFromState -State $script:GameState)
}

function Get-LWNearestSupportedValue {
    param(
        [int]$Value,
        [int[]]$Supported
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Supported.Count -eq 0) {
        return $Value
    }

    $sorted = @($Supported | Sort-Object)
    if ($Value -le $sorted[0]) {
        return $sorted[0]
    }
    if ($Value -ge $sorted[$sorted.Count - 1]) {
        return $sorted[$sorted.Count - 1]
    }

    foreach ($candidate in $sorted) {
        if ($candidate -eq $Value) {
            return $candidate
        }
    }

    $best = $sorted[0]
    $bestDelta = [Math]::Abs($Value - $best)
    foreach ($candidate in $sorted) {
        $delta = [Math]::Abs($Value - $candidate)
        if ($delta -lt $bestDelta) {
            $best = $candidate
            $bestDelta = $delta
        }
    }
    return $best
}

function Get-LWCRTResult {
    param(
        [Parameter(Mandatory = $true)][int]$Ratio,
        [Parameter(Mandatory = $true)][int]$Roll
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $gameData = Get-LWModuleGameData


    if ($null -eq $gameData -or $null -eq $gameData.CRT) {
        return $null
    }

    $ratioKeys = @()
    if ((Test-LWPropertyExists -Object $gameData -Name 'CRTRatioKeys') -and $null -ne $gameData.CRTRatioKeys) {
        $ratioKeys = @($gameData.CRTRatioKeys | ForEach-Object { [int]$_ })
    }
    else {
        foreach ($property in $gameData.CRT.PSObject.Properties) {
            $value = 0
            if ([int]::TryParse($property.Name, [ref]$value)) {
                $ratioKeys += $value
            }
        }
        $ratioKeys = @($ratioKeys | Sort-Object)
        if ($ratioKeys.Count -gt 0) {
            $gameData | Add-Member -Force -NotePropertyName CRTRatioKeys -NotePropertyValue @($ratioKeys)
        }
    }

    if ($ratioKeys.Count -eq 0) {
        return $null
    }

    $ratioKey = Get-LWNearestSupportedValue -Value $Ratio -Supported $ratioKeys
    $ratioNode = Get-LWJsonProperty -Object $gameData.CRT -Name ([string]$ratioKey)
    if ($null -eq $ratioNode) {
        return $null
    }

    $entry = Get-LWJsonProperty -Object $ratioNode -Name ([string]$Roll)
    if ($null -eq $entry) {
        return $null
    }

    return [pscustomobject]@{
        RatioKey      = $ratioKey
        EnemyLossRaw  = (Get-LWJsonProperty -Object $entry -Name 'EnemyLoss')
        PlayerLossRaw = (Get-LWJsonProperty -Object $entry -Name 'PlayerLoss')
    }
}

function Select-LWCombatWeapon {
    param([string]$DefaultWeapon = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $weapons = @(Get-LWStateCombatWeapons -State $script:GameState)
    if ($weapons.Count -eq 0) {
        Write-LWWarn 'No weapons carried. Combat will be unarmed unless you add one.'
        return $null
    }

    if ($weapons.Count -eq 1) {
        Write-LWInfo "Using your only available combat weapon: $($weapons[0])."
        return [string]$weapons[0]
    }

    if ([string]::IsNullOrWhiteSpace($DefaultWeapon)) {
        $DefaultWeapon = Get-LWPreferredCombatWeapon -State $script:GameState
    }

    $defaultIndex = 1
    if (-not [string]::IsNullOrWhiteSpace($DefaultWeapon)) {
        for ($i = 0; $i -lt $weapons.Count; $i++) {
            if ($weapons[$i] -ieq $DefaultWeapon) {
                $defaultIndex = $i + 1
                break
            }
        }
    }

    if ($script:LWUi.Enabled) {
        $currentData = $script:LWUi.ScreenData
        $enemyName = if ($null -ne $currentData -and (Test-LWPropertyExists -Object $currentData -Name 'EnemyName')) { $currentData.EnemyName } else { $null }
        $enemyCombatSkill = if ($null -ne $currentData -and (Test-LWPropertyExists -Object $currentData -Name 'EnemyCombatSkill')) { $currentData.EnemyCombatSkill } else { $null }
        $enemyEndurance = if ($null -ne $currentData -and (Test-LWPropertyExists -Object $currentData -Name 'EnemyEndurance')) { $currentData.EnemyEndurance } else { $null }

        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View             = 'setup'
                EnemyName        = $enemyName
                EnemyCombatSkill = $enemyCombatSkill
                EnemyEndurance   = $enemyEndurance
                Weapons          = @($weapons)
                DefaultIndex     = $defaultIndex
            })
    }

    while ($true) {
        $choice = Read-LWInt -Prompt 'Weapon number' -Default $defaultIndex -Min 0 -Max $weapons.Count
        if ($choice -eq 0) {
            return $null
        }
        return [string]$weapons[$choice - 1]
    }
}

function Get-LWCombatDisplayWeapon {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return 'Unarmed'
    }
    if (Test-LWWeaponIsDrodarinWarHammer -Weapon $Weapon) {
        return 'Drodarin War Hammer'
    }
    if (Test-LWWeaponIsBroninWarhammer -Weapon $Weapon) {
        return 'Bronin Warhammer'
    }
    if (Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) {
        return 'Broadsword +1'
    }
    if (Test-LWWeaponIsBoneSword -Weapon $Weapon) {
        return 'Bone Sword'
    }
    if (Test-LWWeaponIsSolnaris -Weapon $Weapon) {
        return 'Solnaris'
    }
    if (Test-LWWeaponIsMagicSpear -Weapon $Weapon) {
        return 'Magic Spear'
    }

    return $Weapon
}

function Show-LWCombatPromptHint {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        return
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'combat'
}

function Get-LWCombatMeterText {
    param(
        [int]$Current,
        [int]$Max,
        [int]$Width = 18
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $safeMax = [Math]::Max(1, $Max)
    $clampedCurrent = [Math]::Max(0, [Math]::Min($Current, $safeMax))
    $filled = [Math]::Round(($clampedCurrent / [double]$safeMax) * $Width)
    if ($filled -lt 0) {
        $filled = 0
    }
    if ($filled -gt $Width) {
        $filled = $Width
    }

    return ('[' + ('#' * $filled) + ('-' * ($Width - $filled)) + ']')
}

function Write-LWCombatMeterLine {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][int]$Current,
        [Parameter(Mandatory = $true)][int]$Max,
        [Parameter(Mandatory = $true)][int]$CombatSkill,
        [string]$LabelColor = 'White'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $displayLabel = if ($Label.Length -gt 14) { ($Label.Substring(0, 12) + '..') } else { $Label }
    $meterColor = Get-LWEnduranceColor -Current $Current -Max $Max
    $meterText = Get-LWCombatMeterText -Current $Current -Max $Max

    Write-Host ("  {0,-14}" -f $displayLabel) -NoNewline -ForegroundColor $LabelColor
    Write-Host (" CS {0,-3}" -f $CombatSkill) -NoNewline -ForegroundColor Cyan
    Write-Host (" END {0,2}/{1,-2} " -f $Current, $Max) -NoNewline -ForegroundColor $meterColor
    Write-Host $meterText -ForegroundColor $meterColor
}

function Write-LWCombatRoundLine {
    param([Parameter(Mandatory = $true)][object]$Round)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $crtSuffix = ''
    if ((Test-LWPropertyExists -Object $Round -Name 'CRTColumn') -and $null -ne $Round.CRTColumn -and [int]$Round.CRTColumn -ne [int]$Round.Ratio) {
        $crtSuffix = " -> CRT $($Round.CRTColumn)"
    }

    Write-Host ("  R{0,-2}" -f $Round.Round) -NoNewline -ForegroundColor DarkYellow
    Write-Host (" ratio {0,3}" -f (Format-LWSigned -Value ([int]$Round.Ratio))) -NoNewline -ForegroundColor (Get-LWCombatRatioColor -Ratio ([int]$Round.Ratio))
    Write-Host ("  roll {0}{1}" -f $Round.Roll, $crtSuffix) -NoNewline -ForegroundColor Gray
    Write-Host ("  enemy -{0}" -f $Round.EnemyLoss) -NoNewline -ForegroundColor Red
    if ((Test-LWPropertyExists -Object $Round -Name 'SpecialNote') -and -not [string]::IsNullOrWhiteSpace([string]$Round.SpecialNote)) {
        Write-Host (" [{0}]" -f [string]$Round.SpecialNote) -NoNewline -ForegroundColor DarkYellow
    }
    Write-Host ("  Lone Wolf -{0}" -f $Round.PlayerLoss) -NoNewline -ForegroundColor Red
    Write-Host ("  END {0}/{1}" -f $Round.PlayerEnd, $Round.EnemyEnd) -ForegroundColor DarkGray
}

function Get-LWCombatRoundSummaryText {
    param([Parameter(Mandatory = $true)][object]$Round)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ("R{0}  Ratio {1}   You lose {2}   Enemy loses {3}" -f [int]$Round.Round, (Format-LWSigned -Value ([int]$Round.Ratio)), [int]$Round.PlayerLoss, [int]$Round.EnemyLoss)
}

function Show-LWCombatRecentRounds {
    param(
        [object[]]$Rounds = @(),
        [int]$Count = 3,
        [string]$Title = 'Recent Rounds'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title $Title -AccentColor 'DarkRed'
    $rounds = @($Rounds)
    if ($rounds.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text 'No rounds resolved yet.' -TextColor 'DarkGray'
        Write-LWRetroPanelFooter
        return
    }

    $start = [Math]::Max(0, $rounds.Count - $Count)
    foreach ($round in @($rounds[$start..($rounds.Count - 1)])) {
        Write-LWRetroPanelTextRow -Text (Get-LWCombatRoundSummaryText -Round $round) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWCombatDuelPanel {
    param(
        [Parameter(Mandatory = $true)][string]$EnemyName,
        [Parameter(Mandatory = $true)][int]$PlayerCurrent,
        [Parameter(Mandatory = $true)][int]$PlayerMax,
        [Parameter(Mandatory = $true)][int]$EnemyCurrent,
        [Parameter(Mandatory = $true)][int]$EnemyMax,
        [Parameter(Mandatory = $true)][int]$PlayerCombatSkill,
        [Parameter(Mandatory = $true)][int]$EnemyCombatSkill,
        [Parameter(Mandatory = $true)][int]$CombatRatio,
        [Nullable[int]]$RoundCount = $null,
        [string]$Title = 'The Duel'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title $Title -AccentColor 'Red'
    Write-LWRetroPanelTwoColumnRow -LeftText 'Lone Wolf' -RightText $EnemyName -LeftColor 'White' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText ("CS {0}" -f $PlayerCombatSkill) -RightText ("CS {0}" -f $EnemyCombatSkill) -LeftColor 'Cyan' -RightColor 'Cyan' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText ("END {0} / {1}" -f $PlayerCurrent, $PlayerMax) -RightText ("END {0} / {1}" -f $EnemyCurrent, $EnemyMax) -LeftColor (Get-LWEnduranceColor -Current $PlayerCurrent -Max $PlayerMax) -RightColor (Get-LWEnduranceColor -Current $EnemyCurrent -Max $EnemyMax) -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText (Get-LWCombatMeterText -Current $PlayerCurrent -Max $PlayerMax) -RightText (Get-LWCombatMeterText -Current $EnemyCurrent -Max $EnemyMax) -LeftColor (Get-LWEnduranceColor -Current $PlayerCurrent -Max $PlayerMax) -RightColor (Get-LWEnduranceColor -Current $EnemyCurrent -Max $EnemyMax) -LeftWidth 28 -Gap 2
    Write-LWRetroPanelFooter
}

function Write-LWCombatTacticalTwoColumnRows {
    param(
        [string[]]$Items = @(),
        [string]$TextColor = 'Gray'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $rows = @($Items | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($rows.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
        return
    }

    for ($i = 0; $i -lt $rows.Count; $i += 2) {
        $leftText = [string]$rows[$i]
        $rightText = if (($i + 1) -lt $rows.Count) { [string]$rows[$i + 1] } else { '' }
        Write-LWRetroPanelTwoColumnRow -LeftText $leftText -RightText $rightText -LeftColor $TextColor -RightColor $TextColor -LeftWidth 29 -Gap 2
    }
}

function Show-LWCombatTacticalPanel {
    param(
        [Parameter(Mandatory = $true)][string]$Weapon,
        [Parameter(Mandatory = $true)][bool]$UseMindblast,
        [string]$PsychicAttackLabel = 'Mindblast',
        [Parameter(Mandatory = $true)][bool]$EnemyIsUndead,
        [Parameter(Mandatory = $true)][string]$MindforceStatus,
        [Parameter(Mandatory = $true)][string]$KnockoutStatus,
        [Parameter(Mandatory = $true)][string]$EvadeStatus,
        [Parameter(Mandatory = $true)][string]$Mode,
        [object[]]$Notes = @(),
        [string]$BowStatus = '',
        [string]$PotionStatus = '',
        [switch]$UsesSommerswerd,
        [switch]$SommerswerdSuppressed
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $notes = @(
        $Notes |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    $bonusNotes = @($notes | Where-Object { $_ -match '\+' } | Select-Object -Unique)
    $overflowRuleNotes = @(
        $notes | Where-Object {
            $_ -notmatch '\+' -and
            $_ -notmatch '^Mindforce ' -and
            $_ -notmatch '^Evade ' -and
            $_ -notmatch '^Sommerswerd ' -and
            $_ -notmatch '^Undead damage x2$'
        } | Select-Object -Unique
    )

    $ruleStatusNotes = @(
        ("Mindforce : {0}" -f $MindforceStatus),
        ("Evade     : {0}" -f $EvadeStatus)
    )
    if ($UsesSommerswerd) {
        $ruleStatusNotes += ("Sommerswerd: {0}" -f $(if ($SommerswerdSuppressed) { 'Suppressed' } elseif ($EnemyIsUndead) { 'Active (undead x2)' } else { 'Active' }))
    }
    if ($KnockoutStatus -ne 'Off') {
        $ruleStatusNotes += ("Knockout  : {0}" -f $KnockoutStatus)
    }
    if (-not [string]::IsNullOrWhiteSpace($BowStatus)) {
        $ruleStatusNotes += ("Bow       : {0}" -f $BowStatus)
    }
    if (-not [string]::IsNullOrWhiteSpace($PotionStatus)) {
        $ruleStatusNotes += ("Potions   : {0}" -f $PotionStatus)
    }

    Write-LWRetroPanelHeader -Title 'Weapons / Rules' -AccentColor 'DarkYellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Weapon' -LeftValue $Weapon -RightLabel 'Mode' -RightValue $Mode -LeftColor 'Gray' -RightColor (Get-LWModeColor -Mode $Mode) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelDivider
    Write-LWCombatTacticalTwoColumnRows -Items $bonusNotes -TextColor 'Gray'
    Write-LWRetroPanelDivider
    Write-LWCombatTacticalTwoColumnRows -Items $ruleStatusNotes -TextColor 'Gray'
    $overflowNoteText = @($overflowRuleNotes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ' | '
    if (-not [string]::IsNullOrWhiteSpace($overflowNoteText)) {
        Write-LWRetroPanelWrappedKeyValueRows -Label 'Notes' -Value $overflowNoteText -ValueColor 'Gray' -LabelWidth 13
    }
    Write-LWRetroPanelFooter
}

function Get-LWCurrentCombatLogEntry {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        return $null
    }

    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $breakdown = Get-LWCombatBreakdown
    return [pscustomobject]@{
        BookNumber = [int]$script:GameState.Character.BookNumber
        BookTitle  = [string](Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber))
        Section    = [int]$script:GameState.CurrentSection
        EnemyName  = $script:GameState.Combat.EnemyName
        Outcome    = 'In Progress'
        RoundCount = @($script:GameState.Combat.Log).Count
        PlayerEnd  = [int]$playerPool.Current
        PlayerEnduranceMax = [int]$playerPool.Max
        UsesPlayerTargetEndurance = [bool]$playerPool.UsesTarget
        EnemyEnd   = $script:GameState.Combat.EnemyEnduranceCurrent
        EnemyEnduranceMax = [int]$script:GameState.Combat.EnemyEnduranceMax
        EnemyIsUndead = [bool]$script:GameState.Combat.EnemyIsUndead
        EnemyUsesMindforce = [bool]$script:GameState.Combat.EnemyUsesMindforce
        MindforceBlockedByMindshield = [bool](Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)
        AletherCombatSkillBonus = [int]$script:GameState.Combat.AletherCombatSkillBonus
        AttemptKnockout = [bool]$script:GameState.Combat.AttemptKnockout
        Weapon     = [string]$script:GameState.Combat.EquippedWeapon
        SommerswerdSuppressed = [bool]$script:GameState.Combat.SommerswerdSuppressed
        BowRestricted = [bool]$script:GameState.Combat.BowRestricted
        CombatPotionsAllowed = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and $null -ne $script:GameState.Combat.CombatPotionsAllowed) { [bool]$script:GameState.Combat.CombatPotionsAllowed } else { $true }
        Mindblast  = [bool]$script:GameState.Combat.UseMindblast
        CanEvade   = [bool]$script:GameState.Combat.CanEvade
        EvadeAvailableAfterRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $script:GameState.Combat.EvadeAvailableAfterRound) { [int]$script:GameState.Combat.EvadeAvailableAfterRound } else { 0 }
        Mode       = [string]$script:GameState.Settings.CombatMode
        PlayerCombatSkill = if ($null -ne $breakdown) { [int]$breakdown.PlayerCombatSkill } else { $null }
        EnemyCombatSkill = if ($null -ne $breakdown) { [int]$breakdown.EnemyCombatSkill } else { $null }
        CombatRatio = if ($null -ne $breakdown) { [int]$breakdown.CombatRatio } else { $null }
        Notes      = if ($null -ne $breakdown) { @($breakdown.Notes) } else { @() }
        Log        = @($script:GameState.Combat.Log)
    }
}

function Write-LWCombatLogEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [string]$TitleSuffix = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $playerEndMax = if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerEnduranceMax') -and $null -ne $Entry.PlayerEnduranceMax) { [int]$Entry.PlayerEnduranceMax } else { [Math]::Max([int]$Entry.PlayerEnd, 1) }
    $enemyEndMax = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyEnduranceMax') -and $null -ne $Entry.EnemyEnduranceMax) { [int]$Entry.EnemyEnduranceMax } else { [Math]::Max([int]$Entry.EnemyEnd, 1) }
    $bookLabel = Get-LWCombatEntryBookLabel -Entry $Entry
    $combatSummary = if ([int](Get-LWCombatEntryBookNumber -Entry $Entry) -eq [int]$script:GameState.Character.BookNumber) {
        Get-LWLiveBookStatsSummary
    }
    else {
        $historicalSummary = @($script:GameState.BookHistory | Where-Object { [int]$_.BookNumber -eq [int](Get-LWCombatEntryBookNumber -Entry $Entry) } | Select-Object -Last 1)
        if ($historicalSummary.Count -gt 0) {
            $historicalSummary[0]
        }
        else {
            $null
        }
    }

    $displayWeapon = if ((Test-LWPropertyExists -Object $Entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Weapon)) { (Get-LWCombatDisplayWeapon -Weapon ([string]$Entry.Weapon)) } else { '' }

    $recordTitle = 'Combat Record'
    if (-not [string]::IsNullOrWhiteSpace($TitleSuffix)) {
        $recordTitle = ("Combat Record {0}" -f $TitleSuffix)
    }
    Write-LWRetroPanelHeader -Title $recordTitle -AccentColor 'DarkRed'
    if (-not [string]::IsNullOrWhiteSpace($displayWeapon)) {
        Write-LWRetroPanelPairRow -LeftLabel 'Enemy' -LeftValue ([string]$Entry.EnemyName) -RightLabel 'Weapon' -RightValue $displayWeapon -LeftColor 'White' -RightColor 'Gray' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    }
    else {
        Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$Entry.EnemyName) -ValueColor 'White'
    }
    Write-LWRetroPanelPairRow -LeftLabel 'Book / Section' -LeftValue ("{0} / {1}" -f [int](Get-LWCombatEntryBookNumber -Entry $Entry), $(if ((Test-LWPropertyExists -Object $Entry -Name 'Section') -and $null -ne $Entry.Section) { [string]$Entry.Section } else { '?' })) -RightLabel 'Outcome' -RightValue ([string]$Entry.Outcome) -LeftColor 'Gray' -RightColor (Get-LWOutcomeColor -Outcome ([string]$Entry.Outcome)) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    if ((Test-LWPropertyExists -Object $Entry -Name 'CombatRatio') -and $null -ne $Entry.CombatRatio) {
        Write-LWRetroPanelPairRow -LeftLabel 'Rounds Fought' -LeftValue ([string]$Entry.RoundCount) -RightLabel 'Combat Ratio' -RightValue (Format-LWSigned -Value ([int]$Entry.CombatRatio)) -LeftColor 'Gray' -RightColor (Get-LWCombatRatioColor -Ratio ([int]$Entry.CombatRatio)) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    }
    else {
        Write-LWRetroPanelKeyValueRow -Label 'Rounds Fought' -Value ([string]$Entry.RoundCount) -ValueColor 'Gray'
    }
    Write-LWRetroPanelFooter

    Show-LWCombatDuelPanel -Title 'Player / Enemy' -EnemyName ([string]$Entry.EnemyName) -PlayerCurrent ([int]$Entry.PlayerEnd) -PlayerMax $playerEndMax -EnemyCurrent ([int]$Entry.EnemyEnd) -EnemyMax $enemyEndMax -PlayerCombatSkill $(if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerCombatSkill') -and $null -ne $Entry.PlayerCombatSkill) { [int]$Entry.PlayerCombatSkill } else { 0 }) -EnemyCombatSkill $(if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyCombatSkill') -and $null -ne $Entry.EnemyCombatSkill) { [int]$Entry.EnemyCombatSkill } else { 0 }) -CombatRatio $(if ((Test-LWPropertyExists -Object $Entry -Name 'CombatRatio') -and $null -ne $Entry.CombatRatio) { [int]$Entry.CombatRatio } else { 0 })

    Show-LWCombatTacticalPanel -Weapon $(if ((Test-LWPropertyExists -Object $Entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Weapon)) { Get-LWCombatDisplayWeapon -Weapon ([string]$Entry.Weapon) } else { 'Unknown' }) -UseMindblast:([bool]((Test-LWPropertyExists -Object $Entry -Name 'Mindblast') -and [bool]$Entry.Mindblast)) -PsychicAttackLabel (Get-LWCombatPsychicAttackLabel -State $script:GameState) -EnemyIsUndead:([bool]((Test-LWPropertyExists -Object $Entry -Name 'EnemyIsUndead') -and [bool]$Entry.EnemyIsUndead)) -MindforceStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyUsesMindforce') -and [bool]$Entry.EnemyUsesMindforce) { $(if ((Test-LWPropertyExists -Object $Entry -Name 'MindforceBlockedByMindshield') -and [bool]$Entry.MindforceBlockedByMindshield) { 'Blocked by Mindshield' } else { 'Active' }) } else { 'Off' }) -KnockoutStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'AttemptKnockout') -and [bool]$Entry.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }) -EvadeStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'CanEvade') -and [bool]$Entry.CanEvade) { 'Yes' } else { 'No' }) -Mode $(if ((Test-LWPropertyExists -Object $Entry -Name 'Mode') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Mode)) { [string]$Entry.Mode } else { [string]$script:GameState.Settings.CombatMode }) -Notes @($Entry.Notes) -BowStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'BowRestricted') -and [bool]$Entry.BowRestricted) { 'Locked' } else { '' }) -PotionStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'CombatPotionsAllowed') -and -not [bool]$Entry.CombatPotionsAllowed) { 'Locked' } else { '' }) -UsesSommerswerd:(Test-LWWeaponIsSommerswerd -Weapon ([string]$Entry.Weapon)) -SommerswerdSuppressed:([bool]((Test-LWPropertyExists -Object $Entry -Name 'SommerswerdSuppressed') -and [bool]$Entry.SommerswerdSuppressed))

    Show-LWCombatRecentRounds -Rounds @($Entry.Log) -Count ([Math]::Max(1, @($Entry.Log).Count)) -Title 'Round Log'

    Write-LWRetroPanelHeader -Title 'Book Combat Totals' -AccentColor 'DarkYellow'
    if ($null -ne $combatSummary) {
        Write-LWRetroPanelPairRow -LeftLabel 'Fights Won' -LeftValue ([string]$combatSummary.Victories) -RightLabel 'Fights Lost' -RightValue ([string]$combatSummary.Defeats) -LeftColor 'Green' -RightColor 'Red'
        Write-LWRetroPanelPairRow -LeftLabel 'Total Rounds' -LeftValue ([string]$combatSummary.RoundsFought) -RightLabel 'Damage Taken' -RightValue ([string]$combatSummary.EnduranceLost) -LeftColor 'Gray' -RightColor 'Red'
    }
    else {
        Write-LWRetroPanelTextRow -Text '(unavailable)' -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWCombatLog {
    param(
        [object]$Entry = $null,
        [Nullable[int]]$HistoryIndex = $null,
        [Nullable[int]]$BookNumber = $null,
        [switch]$All
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($All) {
        $history = @($script:GameState.History)
        $activeEntry = Get-LWCurrentCombatLogEntry
        $renderedCount = 0
        $currentBookKey = $null
        $currentBookEntry = $null
        $bookItems = @()

        $flushArchiveGroup = {
            param(
                [object]$BookEntry,
                [object[]]$Items
            )

            if ($null -eq $BookEntry -or @($Items).Count -eq 0) {
                return
            }

            Write-LWCombatArchiveBookHeader -Entry $BookEntry
            Show-LWCombatArchiveEntriesPanel -Items @($Items)
        }

        if ($null -ne $BookNumber -and $null -ne $activeEntry -and (Get-LWCombatEntryBookNumber -Entry $activeEntry) -ne [int]$BookNumber) {
            $activeEntry = $null
        }

        if ($history.Count -eq 0 -and $null -eq $activeEntry) {
            Write-LWWarn 'No combat log available.'
            return
        }

        for ($i = 0; $i -lt $history.Count; $i++) {
            if ($null -ne $BookNumber -and (Get-LWCombatEntryBookNumber -Entry $history[$i]) -ne [int]$BookNumber) {
                continue
            }

            $bookKey = Get-LWCombatEntryBookKey -Entry $history[$i]
            if ($bookKey -ne $currentBookKey) {
                & $flushArchiveGroup -BookEntry $currentBookEntry -Items @($bookItems)
                $currentBookKey = $bookKey
                $currentBookEntry = $history[$i]
                $bookItems = @()
            }
            $bookItems += [pscustomobject]@{
                Entry  = $history[$i]
                Prefix = ("#{0}" -f ($i + 1))
                Color  = (Get-LWOutcomeColor -Outcome ([string]$history[$i].Outcome))
            }
            $renderedCount++
        }

        if ($null -ne $activeEntry) {
            $activeBookKey = Get-LWCombatEntryBookKey -Entry $activeEntry
            if ($activeBookKey -ne $currentBookKey) {
                & $flushArchiveGroup -BookEntry $currentBookEntry -Items @($bookItems)
                $bookItems = @()
                $currentBookKey = $activeBookKey
                $currentBookEntry = $activeEntry
            }
            $bookItems += [pscustomobject]@{
                Entry  = $activeEntry
                Prefix = 'Current'
                Color  = 'Cyan'
            }
            $renderedCount++
        }

        if ($renderedCount -gt 0) {
            & $flushArchiveGroup -BookEntry $currentBookEntry -Items @($bookItems)
        }

        if ($renderedCount -eq 0) {
            if ($null -ne $BookNumber) {
                Write-LWWarn ("No combat log available for {0}." -f (Format-LWBookLabel -BookNumber ([int]$BookNumber) -IncludePrefix))
            }
            else {
                Write-LWWarn 'No combat log available.'
            }
        }

        return
    }

    if ($null -ne $HistoryIndex) {
        $history = @($script:GameState.History)
        if ($HistoryIndex -lt 1 -or $HistoryIndex -gt $history.Count) {
            Write-LWWarn "Combat log number must be between 1 and $($history.Count)."
            return
        }

        Write-LWCombatLogEntry -Entry $history[$HistoryIndex - 1] -TitleSuffix ("#{0}" -f $HistoryIndex)
        return
    }

    if ($null -eq $Entry) {
        if ($script:GameState.Combat.Active) {
            $Entry = Get-LWCurrentCombatLogEntry
        }
        elseif (@($script:GameState.History).Count -gt 0) {
            $Entry = $script:GameState.History[-1]
        }
        else {
            Write-LWWarn 'No combat log available.'
            return
        }
    }

    Write-LWCombatLogEntry -Entry $Entry
}

function Show-LWCombatSummary {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $notes = if ((Test-LWPropertyExists -Object $Summary -Name 'Notes') -and @($Summary.Notes).Count -gt 0) { @($Summary.Notes) } else { @() }
    $weapon = if (Test-LWPropertyExists -Object $Summary -Name 'Weapon') { Get-LWCombatDisplayWeapon -Weapon ([string]$Summary.Weapon) } else { 'Unknown' }
    $ratio = if (Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') { [int]$Summary.CombatRatio } else { 0 }
    $usingSommerswerd = (Test-LWPropertyExists -Object $Summary -Name 'Weapon') -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$Summary.Weapon)) -and (Test-LWPropertyExists -Object $Summary -Name 'BookNumber') -and [int]$Summary.BookNumber -ge 2
    $enemyUndead = (Test-LWPropertyExists -Object $Summary -Name 'EnemyIsUndead') -and [bool]$Summary.EnemyIsUndead
    $enemyUsesMindforce = (Test-LWPropertyExists -Object $Summary -Name 'EnemyUsesMindforce') -and [bool]$Summary.EnemyUsesMindforce
    $mindforceBlocked = (Test-LWPropertyExists -Object $Summary -Name 'MindforceBlockedByMindshield') -and [bool]$Summary.MindforceBlockedByMindshield
    $useMindblast = (Test-LWPropertyExists -Object $Summary -Name 'Mindblast') -and [bool]$Summary.Mindblast
    $playerCombatSkill = if ((Test-LWPropertyExists -Object $Summary -Name 'PlayerCombatSkill') -and $null -ne $Summary.PlayerCombatSkill) { [int]$Summary.PlayerCombatSkill } else { 0 }
    $enemyCombatSkill = if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyCombatSkill') -and $null -ne $Summary.EnemyCombatSkill) { [int]$Summary.EnemyCombatSkill } else { 0 }
    $playerEndMax = if ((Test-LWPropertyExists -Object $Summary -Name 'PlayerEnduranceMax') -and $null -ne $Summary.PlayerEnduranceMax) { [int]$Summary.PlayerEnduranceMax } else { [Math]::Max([int]$Summary.PlayerEnd, 1) }
    $enemyEndMax = if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyEnduranceMax') -and $null -ne $Summary.EnemyEnduranceMax) { [int]$Summary.EnemyEnduranceMax } else { [Math]::Max([int]$Summary.EnemyEnd, 1) }
    $mode = if ((Test-LWPropertyExists -Object $Summary -Name 'Mode') -and -not [string]::IsNullOrWhiteSpace([string]$Summary.Mode)) { [string]$Summary.Mode } else { $script:GameState.Settings.CombatMode }
    $canEvade = (Test-LWPropertyExists -Object $Summary -Name 'CanEvade') -and [bool]$Summary.CanEvade
    $evadeStatus = if (-not $canEvade) { 'No' } elseif ((Test-LWPropertyExists -Object $Summary -Name 'EvadeAvailableAfterRound') -and [int]$Summary.EvadeAvailableAfterRound -gt 0 -and [int]$Summary.RoundCount -lt [int]$Summary.EvadeAvailableAfterRound) { "After round $([int]$Summary.EvadeAvailableAfterRound)" } else { 'Yes' }
    $mindforceLossPerRound = if ((Test-LWPropertyExists -Object $Summary -Name 'MindforceLossPerRound') -and $null -ne $Summary.MindforceLossPerRound) { [int]$Summary.MindforceLossPerRound } else { 2 }
    $mindforceStatus = if (-not $enemyUsesMindforce) { 'Off' } elseif ($mindforceBlocked) { 'Blocked by Mindshield' } else { "Active (-$mindforceLossPerRound END/round)" }
    $knockoutStatus = if ((Test-LWPropertyExists -Object $Summary -Name 'AttemptKnockout') -and [bool]$Summary.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }

    Write-LWRetroPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$Summary.EnemyName) -ValueColor 'White'
    Write-LWRetroPanelKeyValueRow -Label 'Outcome' -Value ([string]$Summary.Outcome) -ValueColor (Get-LWOutcomeColor -Outcome ([string]$Summary.Outcome))
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Ratio' -LeftValue (Format-LWSigned -Value $ratio) -RightLabel 'Rounds' -RightValue ([string]$Summary.RoundCount) -LeftColor (Get-LWCombatRatioColor -Ratio $ratio) -RightColor 'Gray'
    if ((Test-LWPropertyExists -Object $Summary -Name 'SpecialResolutionSection') -and $null -ne $Summary.SpecialResolutionSection) {
        Write-LWRetroPanelKeyValueRow -Label 'Next Section' -Value ([string]$Summary.SpecialResolutionSection) -ValueColor 'Yellow'
    }
    Write-LWRetroPanelFooter

    Show-LWCombatDuelPanel -Title 'Player / Enemy' -EnemyName ([string]$Summary.EnemyName) -PlayerCurrent ([int]$Summary.PlayerEnd) -PlayerMax $playerEndMax -EnemyCurrent ([int]$Summary.EnemyEnd) -EnemyMax $enemyEndMax -PlayerCombatSkill $playerCombatSkill -EnemyCombatSkill $enemyCombatSkill -CombatRatio $ratio -RoundCount ([int]$Summary.RoundCount)
    Show-LWCombatTacticalPanel -Weapon $weapon -UseMindblast:$useMindblast -PsychicAttackLabel (Get-LWCombatPsychicAttackLabel -State $script:GameState) -EnemyIsUndead:$enemyUndead -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -EvadeStatus $evadeStatus -Mode $mode -Notes $notes -BowStatus $(if ((Test-LWPropertyExists -Object $Summary -Name 'BowRestricted') -and [bool]$Summary.BowRestricted) { 'Locked' } else { '' }) -PotionStatus $(if ((Test-LWPropertyExists -Object $Summary -Name 'CombatPotionsAllowed') -and -not [bool]$Summary.CombatPotionsAllowed) { 'Locked' } else { '' }) -UsesSommerswerd:$usingSommerswerd -SommerswerdSuppressed:([bool]((Test-LWPropertyExists -Object $Summary -Name 'SommerswerdSuppressed') -and [bool]$Summary.SommerswerdSuppressed))
    Show-LWCombatRecentRounds -Rounds @($Summary.Log) -Count 5 -Title 'Round History'
    if ((Test-LWPropertyExists -Object $Summary -Name 'SpecialResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$Summary.SpecialResolutionNote)) {
        Write-LWRetroPanelHeader -Title 'Combat Note' -AccentColor 'DarkYellow'
        Write-LWRetroPanelTextRow -Text ([string]$Summary.SpecialResolutionNote) -TextColor 'Gray'
        Write-LWRetroPanelFooter
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'combat' -Variant 'summary'
}

function Show-LWCombatStatus {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return
    }

    $breakdown = Get-LWCombatBreakdown
    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $mindforceStatus = Get-LWCombatMindforceStatusText -State $script:GameState
    $knockoutStatus = if ([bool]$script:GameState.Combat.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }
    $evadeStatus = Get-LWCombatEvadeStatusText -State $script:GameState

    Write-LWRetroPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$script:GameState.Combat.EnemyName) -ValueColor 'White'
    Write-LWRetroPanelPairRow -LeftLabel 'Section' -LeftValue ([string]$script:GameState.CurrentSection) -RightLabel 'Combat Round' -RightValue ([string]@($script:GameState.Combat.Log).Count) -LeftColor 'White' -RightColor 'Gray' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Ratio' -LeftValue (Format-LWSigned -Value ([int]$breakdown.CombatRatio)) -RightLabel 'Result' -RightValue 'In Progress' -LeftColor (Get-LWCombatRatioColor -Ratio ([int]$breakdown.CombatRatio)) -RightColor 'Cyan' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Evade' -LeftValue $evadeStatus -RightLabel 'Mindforce' -RightValue $(if ($mindforceStatus -like 'Blocked*') { 'Blocked' } elseif ($mindforceStatus -like 'Active*') { 'Active' } else { $mindforceStatus }) -LeftColor $(if ($evadeStatus -eq 'No') { 'Gray' } else { 'Yellow' }) -RightColor $(if ($mindforceStatus -like 'Active*') { 'Red' } elseif ($mindforceStatus -like 'Blocked*') { 'Cyan' } else { 'Gray' }) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelFooter

    Show-LWCombatDuelPanel -Title 'Player / Enemy' -EnemyName ([string]$script:GameState.Combat.EnemyName) -PlayerCurrent ([int]$playerPool.Current) -PlayerMax ([int]$playerPool.Max) -EnemyCurrent ([int]$script:GameState.Combat.EnemyEnduranceCurrent) -EnemyMax ([int]$script:GameState.Combat.EnemyEnduranceMax) -PlayerCombatSkill ([int]$breakdown.PlayerCombatSkill) -EnemyCombatSkill ([int]$breakdown.EnemyCombatSkill) -CombatRatio ([int]$breakdown.CombatRatio) -RoundCount (@($script:GameState.Combat.Log).Count)
    Show-LWCombatTacticalPanel -Weapon (Get-LWCombatDisplayWeapon -Weapon $script:GameState.Combat.EquippedWeapon) -UseMindblast:([bool]$script:GameState.Combat.UseMindblast) -PsychicAttackLabel (Get-LWCombatPsychicAttackLabel -State $script:GameState) -EnemyIsUndead:([bool]$script:GameState.Combat.EnemyIsUndead) -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -EvadeStatus $evadeStatus -Mode ([string]$script:GameState.Settings.CombatMode) -Notes @($breakdown.Notes) -BowStatus $(if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'BowRestricted') -and [bool]$script:GameState.Combat.BowRestricted) { 'Locked' } else { '' }) -PotionStatus $(if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and -not [bool]$script:GameState.Combat.CombatPotionsAllowed) { 'Locked' } else { '' }) -UsesSommerswerd:(Test-LWCombatUsesSommerswerd -State $script:GameState) -SommerswerdSuppressed:([bool]$script:GameState.Combat.SommerswerdSuppressed)
    Show-LWCombatRecentRounds -Rounds @($script:GameState.Combat.Log) -Count 4 -Title 'Round History'
    Show-LWCombatPromptHint
}

function Resolve-LWCombatRound {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Roll,
        [Nullable[int]]$EnemyLoss = $null,
        [Nullable[int]]$PlayerLoss = $null,
        [switch]$IgnoreEnemyLossThisRound,
        [switch]$UseCRT
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not $State.Combat.Active) {
        return $null
    }

    $breakdown = Get-LWCombatBreakdownFromState -State $State
    $roundNumber = @($State.Combat.Log).Count + 1
    $messages = @()
    $crtResult = $null
    $crtColumn = $null
    $usedCRT = $false

    if ($UseCRT) {
        $crtResult = Get-LWCRTResult -Ratio $breakdown.CombatRatio -Roll $Roll
        if ($null -eq $crtResult) {
            $messages += 'CRT data is missing this result. Falling back to manual entry.'
        }
        else {
            $EnemyLoss = Convert-LWCRTLossValue -Value $crtResult.EnemyLossRaw -CurrentEndurance ([int]$State.Combat.EnemyEnduranceCurrent)
            $playerEndurancePool = Get-LWCombatPlayerEndurancePool -State $State
            $PlayerLoss = Convert-LWCRTLossValue -Value $crtResult.PlayerLossRaw -CurrentEndurance ([int]$playerEndurancePool.Current)
            if ($null -eq $EnemyLoss -or $null -eq $PlayerLoss) {
                $messages += 'CRT data contains an invalid result. Falling back to manual entry.'
                $EnemyLoss = $null
                $PlayerLoss = $null
            }
            $crtColumn = $crtResult.RatioKey
            if ($null -ne $EnemyLoss -and $null -ne $PlayerLoss) {
                $usedCRT = $true
                if ([string]$crtResult.EnemyLossRaw -eq 'K' -or [string]$crtResult.PlayerLossRaw -eq 'K') {
                    $messages += 'CRT produced an automatic kill result.'
                }
                if ($crtColumn -ne $breakdown.CombatRatio) {
                    $messages += "Combat ratio matched nearest available CRT column: $crtColumn."
                }
            }
        }
    }

    if ($null -eq $EnemyLoss -or $null -eq $PlayerLoss) {
        return [pscustomobject]@{
            RequiresManualEntry = $true
            Breakdown           = $breakdown
            RoundNumber         = $roundNumber
            Roll                = $Roll
            UsedCRT             = $usedCRT
            CRTColumn           = $crtColumn
            Messages            = @($messages)
            Outcome             = 'AwaitingInput'
        }
    }

    $playerLossResolution = Resolve-LWGameplayEnduranceLoss -Loss ([int]$PlayerLoss) -Source 'combat' -State $State
    $baseEnemyLoss = [int]$EnemyLoss
    $enemyLossApplied = $baseEnemyLoss
    $combatPlayerLossApplied = [int]$playerLossResolution.AppliedLoss
    $playerEndurancePool = Get-LWCombatPlayerEndurancePool -State $State
    $currentPlayerEnd = [int]$playerEndurancePool.Current
    $mindforceBaseLoss = 0
    $mindforceAppliedLoss = 0
    $specialBaseLoss = 0
    $specialAppliedLoss = 0
    $psychicBaseLoss = 0
    $psychicAppliedLoss = 0
    $specialNotes = @()

    if ([bool]$State.Combat.EnemyRequiresMagicSpear -and -not (Test-LWWeaponIsMagicSpear -Weapon ([string]$State.Combat.EquippedWeapon))) {
        if ($baseEnemyLoss -gt 0) {
            $messages += 'Only the Magic Spear can wound this foe. Your attack deals no damage.'
        }
        $enemyLossApplied = 0
        $specialNotes += 'Needs Magic Spear'
    }
    elseif ([bool]$State.Combat.EnemyRequiresMagicalWeapon -and -not (Test-LWWeaponIsMagicalForCombat -Weapon ([string]$State.Combat.EquippedWeapon))) {
        if ($baseEnemyLoss -gt 0) {
            $messages += 'Only a magical weapon can wound this foe. Your attack deals no damage.'
        }
        $enemyLossApplied = 0
        $specialNotes += 'Needs magical weapon'
    }

    if ($enemyLossApplied -gt 0 -and (Test-LWCombatSommerswerdUndeadDoubleDamageActive -State $State)) {
        $enemyLossApplied = [Math]::Min([int]$State.Combat.EnemyEnduranceCurrent, ($baseEnemyLoss * 2))
        if ($enemyLossApplied -gt $baseEnemyLoss) {
            $specialNotes += 'Undead x2'
            $messages += "Sommerswerd doubles damage against undead: enemy loses $enemyLossApplied instead of $baseEnemyLoss."
        }
    }
    if ($enemyLossApplied -gt 0 -and (Test-LWPropertyExists -Object $State.Combat -Name 'DoubleEnemyEnduranceLoss') -and [bool]$State.Combat.DoubleEnemyEnduranceLoss) {
        $doubledLoss = [Math]::Min([int]$State.Combat.EnemyEnduranceCurrent, ($enemyLossApplied * 2))
        if ($doubledLoss -gt $enemyLossApplied) {
            $messages += "Special rule doubles the enemy's ENDURANCE loss to $doubledLoss."
            $enemyLossApplied = $doubledLoss
            $specialNotes += 'Enemy loss x2'
        }
    }
    $ignoreEnemyLossRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'IgnoreEnemyEnduranceLossRounds') -and $null -ne $State.Combat.IgnoreEnemyEnduranceLossRounds) { [int]$State.Combat.IgnoreEnemyEnduranceLossRounds } else { 0 }
    if ($enemyLossApplied -gt 0 -and $ignoreEnemyLossRounds -gt 0 -and $roundNumber -le $ignoreEnemyLossRounds) {
        $messages += ("Special rule: ignore all enemy ENDURANCE loss in round {0}." -f $roundNumber)
        $enemyLossApplied = 0
        $specialNotes += 'Enemy loss ignored'
    }
    if ($IgnoreEnemyLossThisRound) {
        if ($enemyLossApplied -gt 0) {
            $messages += 'Herb Pouch action: you drink a potion instead of attacking, so enemy ENDURANCE loss is ignored this round.'
        }
        else {
            $messages += 'Herb Pouch action: you drink a potion instead of attacking this round.'
        }
        $enemyLossApplied = 0
        $specialNotes += 'Potion round'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$playerLossResolution.Note)) {
        $messages += [string]$playerLossResolution.Note
    }

    if (Test-LWCombatUsesMindforce -State $State) {
        $mindforceBaseLoss = Get-LWCombatMindforceLossPerRound -State $State
        if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
            $specialNotes += 'Mindshield'
            $messages += 'Mindshield blocks the enemy''s Mindforce.'
        }
        else {
            $mindforceResolution = Resolve-LWGameplayEnduranceLoss -Loss $mindforceBaseLoss -Source 'mindforce' -State $State
            $remainingAfterCombat = [Math]::Max(0, ($currentPlayerEnd - $combatPlayerLossApplied))
            $mindforceAppliedLoss = [Math]::Min($remainingAfterCombat, [int]$mindforceResolution.AppliedLoss)
            if ($mindforceAppliedLoss -gt 0) {
                $specialNotes += 'Mindforce'
                $messages += "Enemy Mindforce inflicts $mindforceAppliedLoss END."
            }
            else {
                $messages += 'Enemy Mindforce surges, but no END is lost.'
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$mindforceResolution.Note)) {
                $messages += [string]$mindforceResolution.Note
            }
        }
    }

    $specialLossAmount = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossAmount) { [int]$State.Combat.SpecialPlayerEnduranceLossAmount } else { 0 }
    $specialLossStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$State.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
    $specialLossReason = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossReason') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.SpecialPlayerEnduranceLossReason)) { [string]$State.Combat.SpecialPlayerEnduranceLossReason } else { 'Special hazard' }
    if ($specialLossAmount -gt 0 -and $roundNumber -ge $specialLossStartRound) {
        $specialBaseLoss = $specialLossAmount
        $specialResolution = Resolve-LWGameplayEnduranceLoss -Loss $specialBaseLoss -Source 'combat' -State $State
        $remainingAfterCombatAndMindforce = [Math]::Max(0, ($currentPlayerEnd - $combatPlayerLossApplied - $mindforceAppliedLoss))
        $specialAppliedLoss = [Math]::Min($remainingAfterCombatAndMindforce, [int]$specialResolution.AppliedLoss)
        if ($specialAppliedLoss -gt 0) {
            $specialNotes += $specialLossReason
            $messages += ("{0} inflicts {1} END." -f $specialLossReason, $specialAppliedLoss)
        }
        else {
            $messages += ("{0} surges, but no END is lost." -f $specialLossReason)
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$specialResolution.Note)) {
            $messages += [string]$specialResolution.Note
        }
    }

    $psychicDrain = Get-LWCombatPsychicAttackEnduranceDrain -State $State
    if ([bool]$State.Combat.UseMindblast -and $psychicDrain -gt 0) {
        $psychicBaseLoss = $psychicDrain
        $psychicResolution = Resolve-LWGameplayEnduranceLoss -Loss $psychicBaseLoss -Source 'combat' -State $State
        $remainingAfterAllHazards = [Math]::Max(0, ($currentPlayerEnd - $combatPlayerLossApplied - $mindforceAppliedLoss - $specialAppliedLoss))
        $psychicAppliedLoss = [Math]::Min($remainingAfterAllHazards, [int]$psychicResolution.AppliedLoss)
        if ($psychicAppliedLoss -gt 0) {
            $specialNotes += 'Psi-surge drain'
            $messages += ("Psi-surge costs {0} END." -f $psychicAppliedLoss)
        }
        else {
            $messages += 'Psi-surge is active, but no END is lost.'
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$psychicResolution.Note)) {
            $messages += [string]$psychicResolution.Note
        }
    }

    $totalPlayerLossApplied = $combatPlayerLossApplied + $mindforceAppliedLoss + $specialAppliedLoss + $psychicAppliedLoss
    $totalPlayerLossBase = [int]$PlayerLoss + $mindforceBaseLoss + $specialBaseLoss + $psychicBaseLoss
    $ignorePlayerLossRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'IgnorePlayerEnduranceLossRounds') -and $null -ne $State.Combat.IgnorePlayerEnduranceLossRounds) { [int]$State.Combat.IgnorePlayerEnduranceLossRounds } else { 0 }
    if ([bool]$State.Combat.IgnoreFirstRoundEnduranceLoss -and $ignorePlayerLossRounds -lt 1) {
        $ignorePlayerLossRounds = 1
    }
    if ($ignorePlayerLossRounds -gt 0 -and $roundNumber -le $ignorePlayerLossRounds -and $totalPlayerLossApplied -gt 0) {
        if ($ignorePlayerLossRounds -eq 1) {
            $messages += 'Surprise attack advantage: ignore all Lone Wolf END loss in the first round.'
        }
        else {
            $messages += ("Surprise attack advantage: ignore all Lone Wolf END loss in rounds 1-{0}." -f $ignorePlayerLossRounds)
        }
        $specialNotes += 'First-round loss ignored'
        $combatPlayerLossApplied = 0
        $mindforceAppliedLoss = 0
        $specialAppliedLoss = 0
        $psychicAppliedLoss = 0
        $totalPlayerLossApplied = 0
    }

    if ([bool]$State.Combat.JavekPoisonRule -and [int]$PlayerLoss -gt 0) {
        $javekRoll = Get-LWRandomDigit
        Write-LWCurrentSectionRandomNumberRoll -Roll $javekRoll -State $State
        if ($javekRoll -eq 9) {
            $combatPlayerLossApplied = $currentPlayerEnd
            $mindforceAppliedLoss = 0
            $specialAppliedLoss = 0
            $psychicAppliedLoss = 0
            $totalPlayerLossApplied = $currentPlayerEnd
            $messages += 'The Javek''s fangs pierce your padded arm. The venom stops your heart.'
            $specialNotes += 'Javek venom'
        }
        else {
            $combatPlayerLossApplied = 0
            $mindforceAppliedLoss = 0
            $specialAppliedLoss = 0
            $psychicAppliedLoss = 0
            $totalPlayerLossApplied = 0
            $messages += 'The Javek''s fangs sink harmlessly into your padded arm. You lose no ENDURANCE.'
            $specialNotes += 'Padded arm'
        }
    }

    $newEnemyEnd = [Math]::Max(0, ([int]$State.Combat.EnemyEnduranceCurrent - $enemyLossApplied))
    $newPlayerEnd = [Math]::Max(0, ($currentPlayerEnd - $totalPlayerLossApplied))
    $outcome = 'Continue'
    $specialResolutionSection = $null
    $specialResolutionNote = $null
    $fallOnRollValue = if ((Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollValue') -and $null -ne $State.Combat.FallOnRollValue) { [int]$State.Combat.FallOnRollValue } else { $null }
    if ($null -ne $fallOnRollValue -and [int]$Roll -eq $fallOnRollValue -and (Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollResolutionSection') -and $null -ne $State.Combat.FallOnRollResolutionSection) {
        $outcome = 'Special'
        $specialResolutionSection = [int]$State.Combat.FallOnRollResolutionSection
        $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.FallOnRollResolutionNote)) { [string]$State.Combat.FallOnRollResolutionNote } else { ("Section result: this roll makes you fall. Turn to {0}." -f $specialResolutionSection) }
        $messages += $specialResolutionNote
    }
    elseif ($newPlayerEnd -le 0) {
        if ((Test-LWPropertyExists -Object $State.Combat -Name 'DefeatResolutionSection') -and $null -ne $State.Combat.DefeatResolutionSection) {
            $outcome = 'Special'
            $specialResolutionSection = [int]$State.Combat.DefeatResolutionSection
            $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'DefeatResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.DefeatResolutionNote)) { [string]$State.Combat.DefeatResolutionNote } else { ("Section result: losing this combat sends you to {0}." -f $specialResolutionSection) }
            $messages += $specialResolutionNote
        }
        else {
            $outcome = 'Defeat'
        }
    }
    elseif ($totalPlayerLossApplied -gt 0 -and (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerLossResolutionSection') -and $null -ne $State.Combat.PlayerLossResolutionSection) {
        $outcome = 'Special'
        $specialResolutionSection = [int]$State.Combat.PlayerLossResolutionSection
        $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerLossResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.PlayerLossResolutionNote)) { [string]$State.Combat.PlayerLossResolutionNote } else { ("Section result: losing ENDURANCE sends you to {0}." -f $specialResolutionSection) }
        $messages += $specialResolutionNote
    }
    elseif ((Test-LWPropertyExists -Object $State.Combat -Name 'EnemyEnduranceThreshold') -and $null -ne $State.Combat.EnemyEnduranceThreshold -and
        (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyEnduranceThresholdSection') -and $null -ne $State.Combat.EnemyEnduranceThresholdSection -and
        $newEnemyEnd -le [int]$State.Combat.EnemyEnduranceThreshold) {
        $outcome = 'Special'
        $specialResolutionSection = [int]$State.Combat.EnemyEnduranceThresholdSection
        $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EnemyEnduranceThresholdNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.EnemyEnduranceThresholdNote)) { [string]$State.Combat.EnemyEnduranceThresholdNote } else { ("Section result: once the enemy reaches the threshold, turn to {0}." -f $specialResolutionSection) }
        $messages += $specialResolutionNote
    }
    elseif ($newEnemyEnd -le 0) {
        if ([bool]$State.Combat.AttemptKnockout) {
            $outcome = 'Knockout'
            $messages += ("{0} is knocked unconscious." -f [string]$State.Combat.EnemyName)
            $specialNotes += 'Knockout'
        }
        else {
            $outcome = 'Victory'
        }
    }

    return [pscustomobject]@{
        RequiresManualEntry = $false
        Breakdown           = $breakdown
        RoundNumber         = $roundNumber
        Roll                = $Roll
        EnemyLoss           = $enemyLossApplied
        EnemyLossBase       = $baseEnemyLoss
        PlayerLoss          = $totalPlayerLossApplied
        PlayerLossBase      = $totalPlayerLossBase
        MindforceLoss       = $mindforceAppliedLoss
        MindforceLossBase   = $mindforceBaseLoss
        SpecialLoss         = $specialAppliedLoss
        SpecialLossBase     = $specialBaseLoss
        NewEnemyEnd         = $newEnemyEnd
        NewPlayerEnd        = $newPlayerEnd
        UsedCRT             = $usedCRT
        CRTColumn           = $crtColumn
        Messages            = @($messages)
        Outcome             = $outcome
        SpecialResolutionSection = $specialResolutionSection
        SpecialResolutionNote = $specialResolutionNote
        LogEntry            = [pscustomobject]@{
            Round      = $roundNumber
            Ratio      = $breakdown.CombatRatio
            Roll       = $Roll
            CRTColumn  = $crtColumn
            EnemyLoss  = $enemyLossApplied
            EnemyLossBase = $baseEnemyLoss
            PlayerLoss = $totalPlayerLossApplied
            PlayerLossBase = $totalPlayerLossBase
            MindforceLoss = $mindforceAppliedLoss
            MindforceLossBase = $mindforceBaseLoss
            SpecialLoss = $specialAppliedLoss
            SpecialLossBase = $specialBaseLoss
            PsychicLoss = $psychicAppliedLoss
            PsychicLossBase = $psychicBaseLoss
            EnemyEnd   = $newEnemyEnd
            PlayerEnd  = $newPlayerEnd
            SpecialNote = $(if ($specialNotes.Count -gt 0) { $specialNotes -join ', ' } else { $null })
        }
    }
}

function Apply-LWCombatRoundResolution {
    param([Parameter(Mandatory = $true)][object]$Resolution)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $script:GameState.Combat.EnemyEnduranceCurrent = $Resolution.NewEnemyEnd
    $actualPlayerLoss = [int]$Resolution.PlayerLoss
    if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'UsePlayerTargetEndurance') -and [bool]$script:GameState.Combat.UsePlayerTargetEndurance) {
        $script:GameState.Combat.PlayerTargetEnduranceCurrent = $Resolution.NewPlayerEnd
    }
    else {
        $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
        $combatEnduranceBonus = if ((Test-LWPropertyExists -Object $playerPool -Name 'CombatBonus') -and $null -ne $playerPool.CombatBonus) { [int]$playerPool.CombatBonus } else { 0 }
        $currentCharacterEndurance = [int]$script:GameState.Character.EnduranceCurrent
        $newCharacterEndurance = [Math]::Max(0, [int]$Resolution.NewPlayerEnd - $combatEnduranceBonus)
        if ($newCharacterEndurance -gt [int]$script:GameState.Character.EnduranceMax) {
            $newCharacterEndurance = [int]$script:GameState.Character.EnduranceMax
        }
        $actualPlayerLoss = [Math]::Max(0, $currentCharacterEndurance - $newCharacterEndurance)
        $script:GameState.Character.EnduranceCurrent = $newCharacterEndurance
    }
    $script:GameState.Combat.Log = @($script:GameState.Combat.Log) + $Resolution.LogEntry
    if ([int]$Resolution.PlayerLoss -gt 0 -and -not ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'UsePlayerTargetEndurance') -and [bool]$script:GameState.Combat.UsePlayerTargetEndurance)) {
        Add-LWBookEnduranceDelta -Delta (-[int]$actualPlayerLoss)
    }

    $equipDeferredAfterRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EquipDeferredWeaponAfterRound') -and $null -ne $script:GameState.Combat.EquipDeferredWeaponAfterRound) { [int]$script:GameState.Combat.EquipDeferredWeaponAfterRound } else { 0 }
    $deferredWeapon = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'DeferredEquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.DeferredEquippedWeapon)) { [string]$script:GameState.Combat.DeferredEquippedWeapon } else { $null }
    if ($Resolution.Outcome -eq 'Continue' -and $equipDeferredAfterRound -gt 0 -and [int]$Resolution.RoundNumber -ge $equipDeferredAfterRound -and -not [string]::IsNullOrWhiteSpace($deferredWeapon)) {
        $script:GameState.Combat.EquippedWeapon = $deferredWeapon
        $script:GameState.Combat.DeferredEquippedWeapon = $null
        $script:GameState.Combat.EquipDeferredWeaponAfterRound = 0
        $script:GameState.Character.LastCombatWeapon = $deferredWeapon
        Write-LWInfo ("You draw {0} for the next round." -f (Get-LWCombatDisplayWeapon -Weapon $deferredWeapon))
    }
}

function Stop-LWCombat {
    param(
        [string]$Outcome = 'Stopped',
        [switch]$SkipAutosave
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return $null
    }

    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $combatLossMeasure = @(@($script:GameState.Combat.Log) | Measure-Object -Property PlayerLoss -Sum)
    $combatTotalPlayerLoss = if ($combatLossMeasure.Count -gt 0) { $combatLossMeasure[0].Sum } else { $null }
    if ($null -eq $combatTotalPlayerLoss) {
        $combatTotalPlayerLoss = 0
    }
    $restoreHalfLoss = 0
    if (([string]$Outcome -eq 'Victory' -and (Test-LWPropertyExists -Object $script:GameState.Combat -Name 'RestoreHalfEnduranceLossOnVictory') -and [bool]$script:GameState.Combat.RestoreHalfEnduranceLossOnVictory) -or
        ([string]$Outcome -eq 'Evaded' -and (Test-LWPropertyExists -Object $script:GameState.Combat -Name 'RestoreHalfEnduranceLossOnEvade') -and [bool]$script:GameState.Combat.RestoreHalfEnduranceLossOnEvade) -or
        ([string]$Outcome -eq 'Special' -and $null -ne $script:GameState.Combat.SpecialResolutionSection -and [int]$script:GameState.Combat.SpecialResolutionSection -eq 161)) {
        $restoreHalfLoss = [math]::Floor(([int]$combatTotalPlayerLoss) / 2)
    }
    if ($restoreHalfLoss -gt 0) {
        $beforeRestore = [int]$playerPool.Current
        $restoredTarget = [Math]::Min([int]$playerPool.Max, ($beforeRestore + $restoreHalfLoss))
        if ([bool]$playerPool.UsesTarget) {
            $script:GameState.Combat.PlayerTargetEnduranceCurrent = $restoredTarget
        }
        else {
            $script:GameState.Character.EnduranceCurrent = $restoredTarget
        }
        $actualRestore = $restoredTarget - $beforeRestore
        if ($actualRestore -gt 0) {
            if (-not [bool]$playerPool.UsesTarget) {
                Add-LWBookEnduranceDelta -Delta $actualRestore
                Register-LWManualRecoveryShortcut
            }
            Write-LWInfo ("Special combat rule restores {0} {1} after the fight." -f $actualRestore, $(if ([bool]$playerPool.UsesTarget) { 'TARGET point(s)' } else { 'ENDURANCE' }))
        }
    }

    $breakdown = Get-LWCombatBreakdown
    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $summary = [pscustomobject]@{
        BookNumber        = [int]$script:GameState.Character.BookNumber
        BookTitle         = Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber)
        Section           = if ($null -ne $script:GameState.CurrentSection) { [int]$script:GameState.CurrentSection } else { $null }
        EnemyName         = $script:GameState.Combat.EnemyName
        Outcome           = $Outcome
        RoundCount        = @($script:GameState.Combat.Log).Count
        PlayerEnd         = [int]$playerPool.Current
        PlayerEnduranceMax = [int]$playerPool.Max
        UsesPlayerTargetEndurance = [bool]$playerPool.UsesTarget
        EnemyEnd          = $script:GameState.Combat.EnemyEnduranceCurrent
        EnemyEnduranceMax = $script:GameState.Combat.EnemyEnduranceMax
        EnemyIsUndead     = [bool]$script:GameState.Combat.EnemyIsUndead
        EnemyUsesMindforce = [bool]$script:GameState.Combat.EnemyUsesMindforce
        MindforceLossPerRound = [int](Get-LWCombatMindforceLossPerRound -State $script:GameState)
        EnemyRequiresMagicSpear = [bool]$script:GameState.Combat.EnemyRequiresMagicSpear
        MindforceBlockedByMindshield = [bool](Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)
        AletherCombatSkillBonus = [int]$script:GameState.Combat.AletherCombatSkillBonus
        AttemptKnockout   = [bool]$script:GameState.Combat.AttemptKnockout
        Weapon            = $script:GameState.Combat.EquippedWeapon
        SommerswerdSuppressed = [bool]$script:GameState.Combat.SommerswerdSuppressed
        BowRestricted     = [bool]$script:GameState.Combat.BowRestricted
        CombatPotionsAllowed = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and $null -ne $script:GameState.Combat.CombatPotionsAllowed) { [bool]$script:GameState.Combat.CombatPotionsAllowed } else { $true }
        Mindblast         = [bool]$script:GameState.Combat.UseMindblast
        CanEvade          = [bool]$script:GameState.Combat.CanEvade
        EvadeAvailableAfterRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $script:GameState.Combat.EvadeAvailableAfterRound) { [int]$script:GameState.Combat.EvadeAvailableAfterRound } else { 0 }
        Mode              = [string]$script:GameState.Settings.CombatMode
        PlayerCombatSkill = if ($null -ne $breakdown) { $breakdown.PlayerCombatSkill } else { $null }
        EnemyCombatSkill  = if ($null -ne $breakdown) { $breakdown.EnemyCombatSkill } else { $null }
        CombatRatio       = if ($null -ne $breakdown) { $breakdown.CombatRatio } else { $null }
        Notes             = if ($null -ne $breakdown) { @($breakdown.Notes) } else { @() }
        SpecialPlayerEnduranceLossAmount = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossAmount) { [int]$script:GameState.Combat.SpecialPlayerEnduranceLossAmount } else { 0 }
        SpecialPlayerEnduranceLossStartRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$script:GameState.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
        SpecialPlayerEnduranceLossReason = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossReason') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossReason) { [string]$script:GameState.Combat.SpecialPlayerEnduranceLossReason } else { $null }
        RestoredAfterCombat = $restoreHalfLoss
        SpecialResolutionSection = $script:GameState.Combat.SpecialResolutionSection
        SpecialResolutionNote = $script:GameState.Combat.SpecialResolutionNote
        Log               = @($script:GameState.Combat.Log)
    }

    if (@('Victory', 'Knockout') -contains [string]$Outcome -and [int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 106) {
        if (-not (Test-LWStateHasMagicSpear -State $script:GameState)) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Magic Spear') {
                Write-LWInfo 'The Magic Spear is kept as a Special Item.'
            }
            else {
                Write-LWWarn 'No room to keep the Magic Spear automatically. Make room and add it manually if you are keeping it.'
            }
        }
    }

    $script:GameState.History = @($script:GameState.History) + $summary
    $script:GameState.Combat = (New-LWCombatState)
    Register-LWCombatResolved -Summary $summary
    if ($Outcome -eq 'Defeat') {
        [void](Register-LWDeath -Type 'Combat' -Cause ("Defeated by {0}." -f $summary.EnemyName))
        Set-LWScreen -Name 'death'
    }
    else {
        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View    = 'summary'
                Summary = $summary
            })
    }
    Write-LWInfo "Combat ended: $Outcome."
    if (-not $SkipAutosave) {
        Invoke-LWMaybeAutosave
    }

    return $summary
}

function Invoke-LWCombatRound {
    param(
        [switch]$Quiet,
        [switch]$SkipAutosave,
        [switch]$IgnoreEnemyLossThisRound,
        [object]$PotionChoice = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return $null
    }

    $roll = Get-LWRandomDigit
    $useCRT = ($script:GameState.Settings.CombatMode -eq 'DataFile')
    $resolution = Resolve-LWCombatRound -State $script:GameState -Roll $roll -IgnoreEnemyLossThisRound:$IgnoreEnemyLossThisRound -UseCRT:$useCRT
    $needsManualEntry = $resolution.RequiresManualEntry

    if (-not $Quiet -or $needsManualEntry) {
        if ($script:LWUi.Enabled) {
            Add-LWNotification -Level 'Info' -Message ("Combat Ratio: {0}" -f $resolution.Breakdown.CombatRatio)
            Add-LWNotification -Level 'Info' -Message ("Random Number: {0}" -f $roll)
        }
        else {
            Write-Host ''
            Write-Host ("Combat Ratio: {0}" -f $resolution.Breakdown.CombatRatio)
            Write-Host ("Random Number: {0}" -f $roll)
        }
    }

    foreach ($message in @($resolution.Messages)) {
        if ($message -like 'CRT data is missing*' -or $message -like 'CRT data contains an invalid result*') {
            Write-LWWarn $message
        }
        else {
            Write-LWInfo $message
        }
    }

    if ($needsManualEntry) {
        if (-not $useCRT) {
            Write-LWInfo 'Consult your Combat Results Table and enter the losses below.'
        }
        if (Test-LWCombatSommerswerdUndeadDoubleDamageActive -State $script:GameState) {
            Write-LWInfo 'Enter the normal enemy END loss from the CRT. The Sommerswerd undead bonus will double it automatically.'
        }
        if ((Test-LWCombatUsesMindforce -State $script:GameState) -and -not (Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)) {
            Write-LWInfo ("Enter the normal Lone Wolf END loss from the CRT. Mindforce will add {0} END automatically." -f (Get-LWCombatMindforceLossPerRound -State $script:GameState))
        }
        if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and [int]$script:GameState.Combat.SpecialPlayerEnduranceLossAmount -gt 0) {
            $specialStartRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$script:GameState.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
            $specialReason = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossReason') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.SpecialPlayerEnduranceLossReason)) { [string]$script:GameState.Combat.SpecialPlayerEnduranceLossReason } else { 'special hazard' }
            Write-LWInfo ("Enter the normal Lone Wolf END loss from the CRT. {0} will add {1} END from round {2} onward." -f $specialReason, [int]$script:GameState.Combat.SpecialPlayerEnduranceLossAmount, $specialStartRound)
        }

        $enemyLoss = Read-LWInt -Prompt 'Enemy END loss this round' -Default 0 -Min 0
        $playerLoss = Read-LWInt -Prompt 'Lone Wolf END loss this round' -Default 0 -Min 0
        $resolution = Resolve-LWCombatRound -State $script:GameState -Roll $roll -EnemyLoss $enemyLoss -PlayerLoss $playerLoss -IgnoreEnemyLossThisRound:$IgnoreEnemyLossThisRound
    }

    Apply-LWCombatRoundResolution -Resolution $resolution

    if ($null -ne $PotionChoice) {
        $potionResult = Use-LWResolvedHealingPotion -PotionName ([string]$PotionChoice.Name) -RestoreAmount ([int]$PotionChoice.RestoreAmount) -InventoryType ([string]$PotionChoice.Type) -SkipAutosave
        if ($null -ne $potionResult) {
            $historyLog = @($script:GameState.Combat.Log)
            if ($historyLog.Count -gt 0) {
                $lastEntry = $historyLog[-1]
                $lastEntry.PlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $potionNote = ("Potion: {0}" -f [string]$potionResult.PotionName)
                if ([string]::IsNullOrWhiteSpace([string]$lastEntry.SpecialNote)) {
                    $lastEntry.SpecialNote = $potionNote
                }
                else {
                    $lastEntry.SpecialNote = ("{0}, {1}" -f [string]$lastEntry.SpecialNote, $potionNote)
                }
            }
            if ($resolution.Outcome -eq 'Defeat' -and [int]$script:GameState.Character.EnduranceCurrent -gt 0) {
                $resolution.Outcome = 'Continue'
                $resolution.NewPlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $resolution.LogEntry.PlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                Write-LWInfo ("{0} keeps Lone Wolf in the fight." -f [string]$potionResult.PotionName)
            }
            elseif ($resolution.Outcome -eq 'Special' -and [int]$resolution.NewPlayerEnd -le 0 -and [int]$script:GameState.Character.EnduranceCurrent -gt 0) {
                $resolution.Outcome = 'Continue'
                $resolution.NewPlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $resolution.LogEntry.PlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $resolution.SpecialResolutionSection = $null
                $resolution.SpecialResolutionNote = $null
                Write-LWInfo ("{0} keeps Lone Wolf in the fight." -f [string]$potionResult.PotionName)
            }
        }
    }

    if (-not $Quiet -or $needsManualEntry) {
        Write-LWInfo ("Round {0}: enemy loses {1}, Lone Wolf loses {2}." -f $resolution.LogEntry.Round, $resolution.EnemyLoss, $resolution.PlayerLoss)
    }

    if ($resolution.Outcome -eq 'Defeat') {
        [void](Stop-LWCombat -Outcome 'Defeat' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    if ($resolution.Outcome -eq 'Special') {
        $script:GameState.Combat.SpecialResolutionSection = $resolution.SpecialResolutionSection
        $script:GameState.Combat.SpecialResolutionNote = $resolution.SpecialResolutionNote
        [void](Stop-LWCombat -Outcome 'Special' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    if ([bool]$script:GameState.Combat.OneRoundOnly -and [int]$resolution.RoundNumber -eq 1) {
        $nextSection = 344
        $branchMessage = ''
        if ([int]$resolution.EnemyLoss -gt [int]$resolution.PlayerLoss) {
            $nextSection = 220
            $branchMessage = 'Section 333 result: the horseman loses more ENDURANCE than you. Turn to 220.'
        }
        elseif ([int]$resolution.PlayerLoss -gt [int]$resolution.EnemyLoss) {
            $nextSection = 209
            $branchMessage = 'Section 333 result: you lose more ENDURANCE than the horseman. Turn to 209.'
        }
        else {
            $nextSection = 344
            $branchMessage = 'Section 333 result: you both lose the same ENDURANCE. Turn to 344.'
        }

        $script:GameState.Combat.SpecialResolutionSection = $nextSection
        $script:GameState.Combat.SpecialResolutionNote = $branchMessage
        Write-LWInfo $branchMessage
        [void](Stop-LWCombat -Outcome 'Special' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    $combatLossMeasure = @(@($script:GameState.Combat.Log) | Measure-Object -Property PlayerLoss -Sum)
    $combatTotalPlayerLoss = if ($combatLossMeasure.Count -gt 0) { $combatLossMeasure[0].Sum } else { $null }
    if ($null -eq $combatTotalPlayerLoss) {
        $combatTotalPlayerLoss = 0
    }
    if ($resolution.Outcome -eq 'Continue' -and (Test-LWPropertyExists -Object $script:GameState.Combat -Name 'OngoingFailureAfterRoundsSection') -and $null -ne $script:GameState.Combat.OngoingFailureAfterRoundsSection) {
        $failureThreshold = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'OngoingFailureAfterRoundsThreshold') -and $null -ne $script:GameState.Combat.OngoingFailureAfterRoundsThreshold) { [int]$script:GameState.Combat.OngoingFailureAfterRoundsThreshold } else { 0 }
        if ($failureThreshold -gt 0 -and [int]$resolution.RoundNumber -ge $failureThreshold) {
            $script:GameState.Combat.SpecialResolutionSection = [int]$script:GameState.Combat.OngoingFailureAfterRoundsSection
            $script:GameState.Combat.SpecialResolutionNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'OngoingFailureAfterRoundsNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.OngoingFailureAfterRoundsNote)) { [string]$script:GameState.Combat.OngoingFailureAfterRoundsNote } else { ("Section result: after round {0}, turn to {1}." -f $failureThreshold, [int]$script:GameState.Combat.OngoingFailureAfterRoundsSection) }
            Write-LWInfo $script:GameState.Combat.SpecialResolutionNote
            [void](Stop-LWCombat -Outcome 'Special' -SkipAutosave:$SkipAutosave)
            return $resolution
        }
    }
    if ($resolution.Outcome -eq 'Victory') {
        $specialVictorySection = $null
        $specialVictoryNote = $null
        if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithoutLossSection') -and $null -ne $script:GameState.Combat.VictoryWithoutLossSection -and [int]$combatTotalPlayerLoss -eq 0) {
            $specialVictorySection = [int]$script:GameState.Combat.VictoryWithoutLossSection
            $specialVictoryNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithoutLossNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.VictoryWithoutLossNote)) { [string]$script:GameState.Combat.VictoryWithoutLossNote } else { ("Section result: perfect victory sends you to {0}." -f $specialVictorySection) }
        }
        elseif ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithinRoundsSection') -and $null -ne $script:GameState.Combat.VictoryWithinRoundsSection) {
            $victoryMaxRounds = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithinRoundsMax') -and $null -ne $script:GameState.Combat.VictoryWithinRoundsMax) { [int]$script:GameState.Combat.VictoryWithinRoundsMax } else { 0 }
            if ($victoryMaxRounds -le 0 -or [int]$resolution.RoundNumber -le $victoryMaxRounds) {
                $specialVictorySection = [int]$script:GameState.Combat.VictoryWithinRoundsSection
                $specialVictoryNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithinRoundsNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.VictoryWithinRoundsNote)) { [string]$script:GameState.Combat.VictoryWithinRoundsNote } else { ("Section result: victory sends you to {0}." -f $specialVictorySection) }
            }
        }
        elseif ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryResolutionSection') -and $null -ne $script:GameState.Combat.VictoryResolutionSection) {
            $specialVictorySection = [int]$script:GameState.Combat.VictoryResolutionSection
            $specialVictoryNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.VictoryResolutionNote)) { [string]$script:GameState.Combat.VictoryResolutionNote } else { ("Section result: victory sends you to {0}." -f $specialVictorySection) }
        }
        if ($null -ne $specialVictorySection) {
            $script:GameState.Combat.SpecialResolutionSection = $specialVictorySection
            $script:GameState.Combat.SpecialResolutionNote = $specialVictoryNote
            Write-LWInfo $specialVictoryNote
        }
        [void](Stop-LWCombat -Outcome 'Victory' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    if ($resolution.Outcome -eq 'Knockout') {
        [void](Stop-LWCombat -Outcome 'Knockout' -SkipAutosave:$SkipAutosave)
        return $resolution
    }

    if (-not $SkipAutosave) {
        Invoke-LWMaybeAutosave
    }

    return $resolution
}

function Resolve-LWCombatToOutcome {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return
    }

    if ($script:GameState.Settings.CombatMode -eq 'DataFile') {
        Write-LWInfo 'Auto-resolving combat with CRT data where available.'
    }
    else {
        Write-LWInfo 'Auto-resolving combat. You will still enter manual CRT losses each round.'
    }

    while ($script:GameState.Combat.Active) {
        $resolution = Invoke-LWCombatRound -Quiet -SkipAutosave
        if ($null -eq $resolution -or $resolution.Outcome -ne 'Continue') {
            break
        }
    }

    Invoke-LWMaybeAutosave
}

function Invoke-LWEvade {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return
    }
    if (-not $script:GameState.Combat.CanEvade) {
        Write-LWWarn 'Evade is not marked as available for this combat.'
        return
    }
    if (-not (Test-LWCombatCanEvadeNow -State $script:GameState)) {
        $requiredRounds = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $script:GameState.Combat.EvadeAvailableAfterRound) { [int]$script:GameState.Combat.EvadeAvailableAfterRound } else { 0 }
        if ($requiredRounds -gt 0) {
            Write-LWWarn ("Evade is only available after round {0} in this combat." -f $requiredRounds)
            return
        }

        $expiryRounds = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeExpiresAfterRound') -and $null -ne $script:GameState.Combat.EvadeExpiresAfterRound) { [int]$script:GameState.Combat.EvadeExpiresAfterRound } else { 0 }
        if ($expiryRounds -gt 0) {
            Write-LWWarn $(if ($expiryRounds -eq 1) { 'Evade is only available in round 1 of this combat.' } else { "Evade is only available through round $expiryRounds in this combat." })
            return
        }
    }

    if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeResolutionSection') -and $null -ne $script:GameState.Combat.EvadeResolutionSection) {
        $script:GameState.Combat.SpecialResolutionSection = [int]$script:GameState.Combat.EvadeResolutionSection
        $script:GameState.Combat.SpecialResolutionNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.EvadeResolutionNote)) { [string]$script:GameState.Combat.EvadeResolutionNote } else { ("Evading sends you to {0}." -f [int]$script:GameState.Combat.EvadeResolutionSection) }
        Write-LWInfo $script:GameState.Combat.SpecialResolutionNote
    }
    [void](Stop-LWCombat -Outcome 'Evaded')
}

Export-ModuleMember -Function Get-LWPreferredCombatWeapon, Get-LWCombatStartArguments, Get-LWCRTValidation, Get-LWDefaultCombatMode, Convert-LWCRTLossValue, Get-LWWeaponskillWeapon, Get-LWCombatPlayerEndurancePool, Get-LWCombatBreakdownFromState, Get-LWCombatBreakdown, Get-LWNearestSupportedValue, Get-LWCRTResult, Select-LWCombatWeapon, Get-LWCombatDisplayWeapon, Show-LWCombatPromptHint, Get-LWCombatMeterText, Write-LWCombatMeterLine, Write-LWCombatRoundLine, Get-LWCombatRoundSummaryText, Show-LWCombatRecentRounds, Show-LWCombatDuelPanel, Write-LWCombatTacticalTwoColumnRows, Show-LWCombatTacticalPanel, Get-LWCurrentCombatLogEntry, Write-LWCombatLogEntry, Show-LWCombatLog, Show-LWCombatSummary, Show-LWCombatStatus, Resolve-LWCombatRound, Apply-LWCombatRoundResolution, Stop-LWCombat, Invoke-LWCombatRound, Resolve-LWCombatToOutcome, Invoke-LWEvade

function Set-LWCombatEntryBookMetadata {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [Nullable[int]]$BookNumber = $null,
        [string]$BookTitle = ''
    )

    $resolvedBookNumber = $BookNumber
    if ($null -eq $resolvedBookNumber -or [int]$resolvedBookNumber -le 0) {
        $resolvedBookNumber = Get-LWBookNumberFromTitle -Title $BookTitle
    }

    $resolvedBookTitle = $BookTitle
    if ([string]::IsNullOrWhiteSpace($resolvedBookTitle) -and $null -ne $resolvedBookNumber -and [int]$resolvedBookNumber -gt 0) {
        $resolvedBookTitle = Get-LWBookTitle -BookNumber ([int]$resolvedBookNumber)
    }

    if (-not (Test-LWPropertyExists -Object $Entry -Name 'BookNumber')) {
        $Entry | Add-Member -NotePropertyName BookNumber -NotePropertyValue $resolvedBookNumber
    }
    else {
        $Entry.BookNumber = $resolvedBookNumber
    }

    if (-not (Test-LWPropertyExists -Object $Entry -Name 'BookTitle')) {
        $Entry | Add-Member -NotePropertyName BookTitle -NotePropertyValue $resolvedBookTitle
    }
    else {
        $Entry.BookTitle = $resolvedBookTitle
    }
}

function Get-LWCurrentBookResolvedCombatCount {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State -Name 'CurrentBookStats') -or $null -eq $State.CurrentBookStats) {
        return 0
    }

    $stats = $State.CurrentBookStats
    $resolved = 0
    foreach ($propertyName in @('Victories', 'Defeats', 'Evades')) {
        if ((Test-LWPropertyExists -Object $stats -Name $propertyName) -and $null -ne $stats.$propertyName) {
            $resolved += [int]$stats.$propertyName
        }
    }

    return $resolved
}

function Get-LWCombatHistorySectionBackfillName {
    param([string]$EnemyName = '')

    $name = [string]$EnemyName
    if ([string]::IsNullOrWhiteSpace($name)) {
        return ''
    }

    switch -Regex ($name.Trim()) {
        '^Winged Serpant$' { return 'Winged Serpent' }
        '^Harbor Thugs$' { return 'Harbour Thugs' }
        '^Palace Jailer$' { return 'Palace Gaoler' }
        '^Dark Lord Haakon$' { return 'Darklord Haakon' }
        '^Yawshsth$' { return 'Yawshath' }
        '^Drakar$' { return 'Drakkar' }
        default { return $name.Trim() }
    }
}

function Get-LWCombatHistorySectionBackfill {
    param([Parameter(Mandatory = $true)][object]$Entry)

    $bookNumber = if ((Test-LWPropertyExists -Object $Entry -Name 'BookNumber') -and $null -ne $Entry.BookNumber) { [int]$Entry.BookNumber } else { $null }
    if ($null -eq $bookNumber) {
        return $null
    }

    $enemyName = Get-LWCombatHistorySectionBackfillName -EnemyName $(if (Test-LWPropertyExists -Object $Entry -Name 'EnemyName') { [string]$Entry.EnemyName } else { '' })
    $enemyCombatSkill = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyCombatSkill') -and $null -ne $Entry.EnemyCombatSkill) { [int]$Entry.EnemyCombatSkill } else { $null }
    $enemyEndurance = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyEnduranceMax') -and $null -ne $Entry.EnemyEnduranceMax) { [int]$Entry.EnemyEnduranceMax } else { $null }
    $notesText = ''
    if ((Test-LWPropertyExists -Object $Entry -Name 'Notes') -and $null -ne $Entry.Notes) {
        $notesText = (@($Entry.Notes | ForEach-Object { [string]$_ }) -join ' | ')
    }

    $signature = "{0}|{1}|{2}|{3}" -f $bookNumber, $enemyName, $(if ($null -ne $enemyCombatSkill) { [string]$enemyCombatSkill } else { '' }), $(if ($null -ne $enemyEndurance) { [string]$enemyEndurance } else { '' })
    switch ($signature) {
        '1|Winged Serpent|16|' { return 133 }
        '2|Harbour Thugs|16|25' { return 268 }
        '2|Town Guard Sergeant|13|22' { return 296 }
        '2|Town Guard Corporal|12|20' { return 296 }
        '2|Town Guard 1|11|19' { return 296 }
        '2|Town Guard 2|11|19' { return 296 }
        '2|Town Guard 3|10|18' { return 296 }
        '2|Town Guard 4|10|17' { return 296 }
        '2|Villager 1|10|16' { return 90 }
        '2|Szall 1|6|9' { return 90 }
        '2|Villager 2|11|14' { return 90 }
        '2|Szall 2|5|8' { return 90 }
        '2|Villager 3|11|17' { return 90 }
        '2|Zombie Crew|13|16' { return 128 }
        '2|Wounded Helghast|22|20' { return 5 }
        '2|Drakkar 1|17|25' { return 185 }
        '2|Drakkar 2|16|26' { return 185 }
        '3|Kalkoth 1|11|35' { return 138 }
        '3|Kalkoth 2|10|32' { return 138 }
        '3|Crystal Frostwyrm|20|30' { return 265 }
        '3|Ice Barbarian|14|25' { return 270 }
        '4|Bridge Guard|14|23' { return 147 }
        '4|Vassagonian Warhound|17|25' { return 36 }
        '4|Vassagonian Horseman|20|28' { return 333 }
        '4|Bandit Horseman|17|24' { return 90 }
        '4|Wounded Bandit|13|16' { return 53 }
        '5|Yas|14|28' { return 194 }
        '5|Drakkarim|18|35' { return 273 }
        '5|Drakkarim|17|35' { return 387 }
        '5|Drakkarim|18|34' { return 231 }
        '5|Sentry|15|23' { return 389 }
        '5|Drakkar|18|26' { return 316 }
        '5|Drakkar|18|23' { return 330 }
        '5|Darklord Haakon|28|45' { return 353 }
        '6|Altan|28|50' { return 26 }
    }

    if ($bookNumber -eq 1 -and $enemyName -eq 'Oghashez Giak Ambusher (wounded)' -and $enemyCombatSkill -eq 9 -and $notesText -match 'Player modifier \+4') {
        return 55
    }

    if ($bookNumber -eq 1 -and $enemyName -eq 'Mad Butcher' -and $enemyCombatSkill -eq 11) {
        return 63
    }

    return $null
}

function Normalize-LWCombatHistorySections {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State -Name 'History') -or $null -eq $State.History) {
        return
    }

    foreach ($entry in @($State.History)) {
        $sectionMissing = (-not (Test-LWPropertyExists -Object $entry -Name 'Section')) -or $null -eq $entry.Section
        if (-not $sectionMissing) {
            continue
        }

        $backfilledSection = Get-LWCombatHistorySectionBackfill -Entry $entry
        if ($null -ne $backfilledSection) {
            $entry | Add-Member -NotePropertyName 'Section' -NotePropertyValue ([int]$backfilledSection) -Force
        }
    }
}

function Test-LWCombatKnockoutAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -ge 3)
}

function Test-LWCombatAletherAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -ge 3)
}

function Test-LWWeaponIsNonEdgeForKnockout {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWNonEdgeKnockoutWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsSommerswerd {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSommerswerdItemNames) -Target $Weapon)))
}

function Test-LWWeaponIsMagicalForCombat {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    if (Test-LWWeaponIsSommerswerd -Weapon $Weapon) {
        return $true
    }

    if (Test-LWWeaponIsMagicSpear -Weapon $Weapon) {
        return $true
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWDaggerOfVashnaItemNames) -Target $Weapon)))
}

function Test-LWCombatMagicSpearAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasMagicSpear -State $State) {
        return $true
    }

    return ([int]$State.Character.BookNumber -eq 2 -and [int]$State.CurrentSection -eq 106)
}

function Test-LWStateHasSommerswerd {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatSommerswerdAvailable -State $State) -and (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special'))
}

function Test-LWStateHasSommerswerdWeaponskill {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill')) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSommerswerdWeaponskillNames) -Target ([string]$State.Character.WeaponskillWeapon))))
}

function Get-LWStateCombatWeapons {
    param([Parameter(Mandatory = $true)][object]$State)

    $choices = @($State.Inventory.Weapons)
    $magicSpear = $null
    if (Test-LWCombatMagicSpearAvailable -State $State) {
        $magicSpear = if ([int]$State.Character.BookNumber -eq 2 -and [int]$State.CurrentSection -eq 106) { 'Magic Spear' } else { Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWMagicSpearItemNames) -Type 'special' }
    }
    if (-not [string]::IsNullOrWhiteSpace($magicSpear) -and [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $choices -Target $magicSpear))) {
        $choices = @($choices) + @([string]$magicSpear)
    }
    $sommerswerd = $null
    if (Test-LWCombatSommerswerdAvailable -State $State) {
        $sommerswerd = Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special'
    }
    if (-not [string]::IsNullOrWhiteSpace($sommerswerd) -and [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $choices -Target $sommerswerd))) {
        $choices = @($choices) + @([string]$sommerswerd)
    }
    $broninWarhammer = Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWBroninWarhammerItemNames) -Type 'special'
    if (-not [string]::IsNullOrWhiteSpace($broninWarhammer) -and [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $choices -Target $broninWarhammer))) {
        $choices = @($choices) + @([string]$broninWarhammer)
    }

    return @($choices)
}

function Get-LWStateBoneSwordCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (-not (Test-LWWeaponIsBoneSword -Weapon $activeWeapon)) {
        return 0
    }

    if (Test-LWStateIsInKalte -State $State) {
        return 1
    }

    return 0
}

function Get-LWStateDrodarinWarHammerCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsDrodarinWarHammer -Weapon $activeWeapon) {
        return 1
    }

    return 0
}

function Get-LWStateBroninWarhammerCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (-not (Test-LWWeaponIsBroninWarhammer -Weapon $activeWeapon)) {
        return 0
    }

    $enemyName = if ($null -ne $State.Combat -and (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.EnemyName)) {
        [string]$State.Combat.EnemyName
    }
    else {
        ''
    }

    if ($enemyName -match '(?i)armou?red') {
        return 2
    }

    return 1
}

function Get-LWStateBroadswordPlusOneCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsBroadswordPlusOne -Weapon $activeWeapon) {
        return 1
    }

    return 0
}

function Get-LWStateSolnarisCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsSolnaris -Weapon $activeWeapon) {
        return 2
    }

    return 0
}

function Test-LWWeaponMatchesWeaponmastery {
    param(
        [string]$Weapon,
        [string[]]$WeaponmasteryWeapons = @()
    )

    if ([string]::IsNullOrWhiteSpace($Weapon) -or @($WeaponmasteryWeapons).Count -eq 0) {
        return $false
    }

    foreach ($masteredWeapon in @($WeaponmasteryWeapons)) {
        if ($Weapon -ieq [string]$masteredWeapon) {
            return $true
        }

        if ((-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWJakanBowWeaponNames) -Target $Weapon))) -and [string]$masteredWeapon -ieq 'Bow') {
            return $true
        }
        if ((Test-LWWeaponIsDrodarinWarHammer -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Warhammer') {
            return $true
        }
        if ((Test-LWWeaponIsBroninWarhammer -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Warhammer') {
            return $true
        }
        if ((Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Broadsword') {
            return $true
        }
        if ((Test-LWWeaponIsCaptainDValSword -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Sword') {
            return $true
        }
        if ((Test-LWWeaponIsSolnaris -Weapon $Weapon) -and @('Sword', 'Broadsword') -contains [string]$masteredWeapon) {
            return $true
        }
    }

    return $false
}

function Get-LWStateWeaponmasteryCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    if (-not (Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery')) {
        return 0
    }

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if ([string]::IsNullOrWhiteSpace($activeWeapon)) {
        return 0
    }

    if (Test-LWWeaponMatchesWeaponmastery -Weapon $activeWeapon -WeaponmasteryWeapons @($State.Character.WeaponmasteryWeapons)) {
        return 3
    }

    return 0
}

function Test-LWCombatPsychicAttackUsesPsiSurge {
    param([Parameter(Mandatory = $true)][object]$State)

    if ((Test-LWPropertyExists -Object $State.Combat -Name 'PsychicAttackMode') -and [string]$State.Combat.PsychicAttackMode -ieq 'Psi-surge') {
        return [bool]$State.Combat.UseMindblast
    }

    return ((Test-LWStateIsMagnakaiRuleset -State $State) -and [bool]$State.Combat.UseMindblast -and (Test-LWStateHasDiscipline -State $State -Name 'Psi-surge'))
}

function Get-LWCombatPsychicAttackLabel {
    param([Parameter(Mandatory = $true)][object]$State)

    if ((Test-LWPropertyExists -Object $State.Combat -Name 'PsychicAttackMode') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.PsychicAttackMode)) {
        return [string]$State.Combat.PsychicAttackMode
    }

    if (Test-LWCombatPsychicAttackUsesPsiSurge -State $State) {
        return 'Psi-surge'
    }

    return 'Mindblast'
}

function Get-LWCombatPsychicAttackBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWCombatPsychicAttackUsesPsiSurge -State $State) {
        return 4
    }

    if ((Test-LWPropertyExists -Object $State.Combat -Name 'MindblastCombatSkillBonus') -and $null -ne $State.Combat.MindblastCombatSkillBonus) {
        return [int]$State.Combat.MindblastCombatSkillBonus
    }

    return 2
}

function Get-LWCombatPsychicAttackEnduranceDrain {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWCombatPsychicAttackUsesPsiSurge -State $State) {
        return 2
    }

    return 0
}

function Get-LWStateDaggerOfVashnaEndurancePenalty {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWDaggerOfVashnaItemNames) -Type 'special') {
        return -3
    }

    return 0
}

function Get-LWStateCaptainDValSwordCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsCaptainDValSword -Weapon $activeWeapon) {
        return 1
    }

    return 0
}

function Get-LWCombatKnockoutCombatSkillPenalty {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    if (-not [bool]$State.Combat.AttemptKnockout) {
        return 0
    }

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if ([string]::IsNullOrWhiteSpace($activeWeapon)) {
        return 0
    }
    if (Test-LWWeaponIsNonEdgeForKnockout -Weapon $activeWeapon) {
        return 0
    }

    return 2
}

function Test-LWCombatSommerswerdAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -ge 2)
}

function Get-LWStateSommerswerdCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$Suppressed
    )

    if ($Suppressed -or -not (Test-LWStateHasSommerswerd -State $State)) {
        return 0
    }

    $baseBonus = 8
    if (Test-LWStateHasSommerswerdWeaponskill -State $State) {
        $baseBonus = 10
    }

    return (Get-LWModeAdjustedSommerswerdBonus -BaseBonus $baseBonus -State $State)
}

function Get-LWStateSommerswerdFallbackWeaponskillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWCombatSommerswerdAvailable -State $State)) {
        return 0
    }

    if (Test-LWStateHasSommerswerdWeaponskill -State $State) {
        return 2
    }

    return 0
}

function Test-LWCombatUsesSommerswerd {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatSommerswerdAvailable -State $State) -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$State.Combat.EquippedWeapon)))
}

function Test-LWCombatSommerswerdPowerActive {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatUsesSommerswerd -State $State) -and -not [bool]$State.Combat.SommerswerdSuppressed)
}

function Test-LWCombatSommerswerdUndeadDoubleDamageActive {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatSommerswerdPowerActive -State $State) -and [bool]$State.Combat.EnemyIsUndead)
}

function Test-LWCombatUsesMindforce {
    param([Parameter(Mandatory = $true)][object]$State)

    return [bool]$State.Combat.EnemyUsesMindforce
}

function Test-LWCombatMindforceBlockedByMindshield {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatUsesMindforce -State $State) -and (Test-LWStateHasDiscipline -State $State -Name 'Mindshield'))
}

function Get-LWStateCompletedLoreCircles {
    param([Parameter(Mandatory = $true)][object]$State)
    $gameData = Get-LWModuleGameData

    $definitions = @()
    if ($null -ne $gameData -and (Test-LWPropertyExists -Object $gameData -Name 'MagnakaiLoreCircles') -and $null -ne $gameData.MagnakaiLoreCircles) {
        $definitions = @($gameData.MagnakaiLoreCircles)
    }

    $owned = @()
    if ($null -ne $State.Character -and (Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiDisciplines') -and $null -ne $State.Character.MagnakaiDisciplines) {
        $owned = @($State.Character.MagnakaiDisciplines | ForEach-Object { [string]$_ })
    }
    if ($definitions.Count -eq 0 -or $owned.Count -eq 0) {
        return @()
    }

    return @(
        foreach ($definition in $definitions) {
            $required = @($definition.Disciplines | ForEach-Object { [string]$_ })
            if ($required.Count -gt 0 -and @($required | Where-Object { $owned -notcontains $_ }).Count -eq 0) {
                $definition
            }
        }
    )
}

function Get-LWStateLoreCircleCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object[]]$CompletedCircles = $null
    )

    $bonus = 0
    $circles = if ($null -eq $CompletedCircles) { @(Get-LWStateCompletedLoreCircles -State $State) } else { @($CompletedCircles) }
    foreach ($circle in $circles) {
        $bonus += [int]$circle.CombatSkillBonus
    }

    return $bonus
}

function Get-LWStateLoreCircleEnduranceBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object[]]$CompletedCircles = $null
    )

    $bonus = 0
    $circles = if ($null -eq $CompletedCircles) { @(Get-LWStateCompletedLoreCircles -State $State) } else { @($CompletedCircles) }
    foreach ($circle in $circles) {
        $bonus += [int]$circle.EnduranceBonus
    }

    return $bonus
}

function Sync-LWMagnakaiLoreCircleBonuses {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$WriteMessages
    )

    Ensure-LWEquipmentBonusState -State $State

    $completedCircles = @(Get-LWStateCompletedLoreCircles -State $State)
    $circleNames = @($completedCircles | ForEach-Object { [string]$_.Name })
    $desiredCombatSkill = Get-LWStateLoreCircleCombatSkillBonus -State $State
    $desiredEndurance = Get-LWStateLoreCircleEnduranceBonus -State $State
    $appliedCombatSkill = [int]$State.EquipmentBonuses.LoreCircleCombatSkill
    $appliedEndurance = [int]$State.EquipmentBonuses.LoreCircleEndurance
    $combatDelta = $desiredCombatSkill - $appliedCombatSkill
    $enduranceDelta = $desiredEndurance - $appliedEndurance

    $State.Character.LoreCirclesCompleted = @($circleNames)

    if ($combatDelta -eq 0 -and $enduranceDelta -eq 0) {
        return
    }

    $State.Character.CombatSkillBase = [Math]::Max(0, ([int]$State.Character.CombatSkillBase + $combatDelta))
    $newMax = [Math]::Max(1, ([int]$State.Character.EnduranceMax + $enduranceDelta))
    $newCurrent = [int]$State.Character.EnduranceCurrent + $enduranceDelta
    if ($newCurrent -lt 0) {
        $newCurrent = 0
    }
    if ($newCurrent -gt $newMax) {
        $newCurrent = $newMax
    }

    $State.Character.EnduranceMax = $newMax
    $State.Character.EnduranceCurrent = $newCurrent
    $State.EquipmentBonuses.LoreCircleCombatSkill = $desiredCombatSkill
    $State.EquipmentBonuses.LoreCircleEndurance = $desiredEndurance

    if ($WriteMessages) {
        $circleSummary = if ($circleNames.Count -gt 0) { $circleNames -join ', ' } else { 'none' }
        Write-LWInfo ("Lore-circle bonuses updated: CS {0}, END {1}. Circles: {2}." -f (Format-LWSigned -Value $combatDelta), (Format-LWSigned -Value $enduranceDelta), $circleSummary)
    }
}

function Get-LWLoreCircleDisplayName {
    param([string]$Name)

    return (([string]$Name) -replace '^Circle of the ', '' -replace '^Circle of ', '')
}

function Get-LWLoreCircleDisplayOrder {
    param([string]$Name)

    switch (Get-LWLoreCircleDisplayName -Name $Name) {
        'Spirit' { return 0 }
        'Fire' { return 1 }
        'Solaris' { return 2 }
        'Light' { return 3 }
        default { return 99 }
    }
}

function Format-LWLoreCirclePanelRow {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [string[]]$OwnedDisciplines = @()
    )

    $required = @($Definition.Disciplines | ForEach-Object { [string]$_ })
    $ownedCount = @($required | Where-Object { $OwnedDisciplines -contains $_ }).Count
    $status = if ($ownedCount -ge $required.Count) { 'done' } elseif ($ownedCount -gt 0) { 'partial' } else { 'empty' }
    $circleName = Get-LWLoreCircleDisplayName -Name ([string]$Definition.Name)
    $statusText = $status

    if ($status -eq 'done') {
        $bonusParts = @()
        if ([int]$Definition.CombatSkillBonus -gt 0) {
            $bonusParts += ("+{0} CS" -f [int]$Definition.CombatSkillBonus)
        }
        if ([int]$Definition.EnduranceBonus -gt 0) {
            $bonusParts += ("+{0} E" -f [int]$Definition.EnduranceBonus)
        }
        if ($bonusParts.Count -gt 0) {
            $statusText = ("done ({0})" -f ($bonusParts -join ', '))
        }
    }

    return [pscustomobject]@{
        Name  = $circleName
        Text  = ("{0,-7}: {1}" -f $circleName, $statusText)
        Color = $(if ($status -eq 'done') { 'Green' } elseif ($status -eq 'partial') { 'Yellow' } else { 'DarkGray' })
        Order = Get-LWLoreCircleDisplayOrder -Name ([string]$Definition.Name)
    }
}

function Get-LWCombatMindforceLossPerRound {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'MindforceLossPerRound') -or $null -eq $State.Combat.MindforceLossPerRound) {
        return 2
    }

    return [Math]::Max(0, [int]$State.Combat.MindforceLossPerRound)
}

function Get-LWCombatCurrentRoundNumber {
    param([Parameter(Mandatory = $true)][object]$State)

    return (@($State.Combat.Log).Count + 1)
}

function Get-LWCombatActivePlayerCombatSkillModifier {
    param([Parameter(Mandatory = $true)][object]$State)

    $modifier = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifier') -and $null -ne $State.Combat.PlayerCombatSkillModifier) { [int]$State.Combat.PlayerCombatSkillModifier } else { 0 }
    $currentRound = Get-LWCombatCurrentRoundNumber -State $State
    $durationRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierRounds) { [int]$State.Combat.PlayerCombatSkillModifierRounds } else { 0 }
    if ($durationRounds -gt 0 -and $currentRound -gt $durationRounds) {
        $modifier = 0
    }

    $afterModifier = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRounds) { [int]$State.Combat.PlayerCombatSkillModifierAfterRounds } else { 0 }
    $afterStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRoundStart') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRoundStart) { [int]$State.Combat.PlayerCombatSkillModifierAfterRoundStart } else { 0 }
    if ($afterModifier -ne 0 -and $afterStartRound -gt 0 -and $currentRound -ge $afterStartRound) {
        $modifier += $afterModifier
    }

    return $modifier
}

function Get-LWCombatEvadeStatusText {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.CanEvade) {
        return 'No'
    }

    $completedRounds = @($State.Combat.Log).Count
    $requiredRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $State.Combat.EvadeAvailableAfterRound) { [int]$State.Combat.EvadeAvailableAfterRound } else { 0 }
    if ($requiredRounds -le 0) {
        $expiryRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeExpiresAfterRound') -and $null -ne $State.Combat.EvadeExpiresAfterRound) { [int]$State.Combat.EvadeExpiresAfterRound } else { 0 }
        if ($expiryRounds -gt 0) {
            if ($completedRounds -ge $expiryRounds) {
                return 'No'
            }

            return $(if ($expiryRounds -eq 1) { 'Round 1 only' } else { "Through round $expiryRounds" })
        }

        return 'Yes'
    }

    if ($completedRounds -ge $requiredRounds) {
        return 'Yes'
    }

    return ("After round {0}" -f $requiredRounds)
}

function Test-LWCombatCanEvadeNow {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.CanEvade) {
        return $false
    }

    $completedRounds = @($State.Combat.Log).Count
    $requiredRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $State.Combat.EvadeAvailableAfterRound) { [int]$State.Combat.EvadeAvailableAfterRound } else { 0 }
    if ($requiredRounds -gt 0 -and $completedRounds -lt $requiredRounds) {
        return $false
    }

    $expiryRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeExpiresAfterRound') -and $null -ne $State.Combat.EvadeExpiresAfterRound) { [int]$State.Combat.EvadeExpiresAfterRound } else { 0 }
    if ($expiryRounds -gt 0 -and $completedRounds -ge $expiryRounds) {
        return $false
    }

    return $true
}

function Get-LWCombatMindforceStatusText {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.EnemyUsesMindforce) {
        return 'Off'
    }

    if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
        $usesPsiScreen = ((Test-LWCombatPsychicAttackUsesPsiSurge -State $State) -or (Test-LWStateHasDiscipline -State $State -Name 'Psi-screen'))
        $shieldLabel = if ($usesPsiScreen) { 'Psi-screen' } else { 'Mindshield' }
        return ("Blocked by {0}" -f $shieldLabel)
    }

    $loss = Get-LWCombatMindforceLossPerRound -State $State
    return ("Active (-{0} END/round)" -f $loss)
}

function New-LWCombatState {
    return [pscustomobject]@{
        Active                    = $false
        EnemyName                 = $null
        EnemyCombatSkill          = 0
        EnemyEnduranceCurrent     = 0
        EnemyEnduranceMax         = 0
        EnemyIsUndead             = $false
        EnemyUsesMindforce        = $false
        MindforceLossPerRound     = 2
        EnemyRequiresMagicSpear   = $false
        EnemyRequiresMagicalWeapon = $false
        EnemyImmuneToMindblast    = $false
        UseMindblast              = $false
        PsychicAttackMode         = 'Mindblast'
        MindblastCombatSkillBonus = 2
        AletherCombatSkillBonus   = 0
        AttemptKnockout           = $false
        CanEvade                  = $false
        EvadeAvailableAfterRound  = 0
        EvadeExpiresAfterRound    = 0
        EvadeResolutionSection    = $null
        EvadeResolutionNote       = $null
        EquippedWeapon            = $null
        DeferredEquippedWeapon    = $null
        EquipDeferredWeaponAfterRound = 0
        SommerswerdSuppressed     = $false
        IgnoreFirstRoundEnduranceLoss = $false
        IgnorePlayerEnduranceLossRounds = 0
        IgnoreEnemyEnduranceLossRounds = 0
        DoubleEnemyEnduranceLoss  = $false
        OneRoundOnly              = $false
        SpecialResolutionSection  = $null
        SpecialResolutionNote     = $null
        VictoryResolutionSection  = $null
        VictoryResolutionNote     = $null
        VictoryWithoutLossSection = $null
        VictoryWithoutLossNote    = $null
        VictoryWithinRoundsSection = $null
        VictoryWithinRoundsMax    = $null
        VictoryWithinRoundsNote   = $null
        OngoingFailureAfterRoundsSection = $null
        OngoingFailureAfterRoundsThreshold = $null
        OngoingFailureAfterRoundsNote = $null
        PlayerLossResolutionSection = $null
        PlayerLossResolutionNote  = $null
        DefeatResolutionSection   = $null
        DefeatResolutionNote      = $null
        JavekPoisonRule           = $false
        FallOnRollValue           = $null
        FallOnRollResolutionSection = $null
        FallOnRollResolutionNote  = $null
        RestoreHalfEnduranceLossOnVictory = $false
        RestoreHalfEnduranceLossOnEvade = $false
        UsePlayerTargetEndurance = $false
        PlayerTargetEnduranceCurrent = 0
        PlayerTargetEnduranceMax = 0
        SuppressShieldCombatSkillBonus = $false
        PlayerCombatSkillModifier = 0
        PlayerCombatSkillModifierRounds = 0
        PlayerCombatSkillModifierAfterRounds = 0
        PlayerCombatSkillModifierAfterRoundStart = $null
        EnemyCombatSkillModifier  = 0
        SpecialPlayerEnduranceLossAmount = 0
        SpecialPlayerEnduranceLossStartRound = 1
        SpecialPlayerEnduranceLossReason = $null
        Log                       = @()
    }
}

function Test-LWStateHasActiveWeaponskill {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Character -or [string]::IsNullOrWhiteSpace([string]$State.Character.WeaponskillWeapon)) {
        return $false
    }

    if ((Test-LWStateIsMagnakaiRuleset -State $State) -and [int]$State.Character.BookNumber -eq 6) {
        return (Test-LWBookSixDEWeaponskillEnabled -State $State)
    }

    return (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill')
}

function Test-LWCombatHerbPouchOptionActive {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and
        $null -ne $State.Character -and
        (Test-LWStateIsMagnakaiRuleset -State $State) -and
        [int]$State.Character.BookNumber -ge 6 -and
        (Get-LWBookSixDECuringOption -State $State) -eq 3 -and
        (Test-LWStateHasHerbPouch -State $State))
}

function Get-LWPreferredHerbPouchCombatPotionChoice {
    param([object]$State = $script:GameState)

    return @((Get-LWAvailableHealingPotionChoices -State $State -HerbPouchOnly) | Select-Object -First 1)[0]
}

function Get-LWModeAdjustedSommerswerdBonus {
    param(
        [int]$BaseBonus,
        [object]$State = $script:GameState
    )

    $normalized = [Math]::Max(0, [int]$BaseBonus)
    if (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State)) {
        return [int][Math]::Floor($normalized / 2)
    }

    return $normalized
}

function Register-LWCombatStarted {
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.CombatCount = [int]$stats.CombatCount + 1
    if ($script:GameState.Combat.UseMindblast) {
        $stats.MindblastCombats = [int]$stats.MindblastCombats + 1
    }

    if ([int]$script:GameState.Combat.EnemyCombatSkill -gt [int]$stats.HighestEnemyCombatSkillFaced) {
        $stats.HighestEnemyCombatSkillFaced = [int]$script:GameState.Combat.EnemyCombatSkill
    }
    if ([int]$script:GameState.Combat.EnemyEnduranceMax -gt [int]$stats.HighestEnemyEnduranceFaced) {
        $stats.HighestEnemyEnduranceFaced = [int]$script:GameState.Combat.EnemyEnduranceMax
    }

    $weaponName = Get-LWCombatDisplayWeapon -Weapon $(if (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.EquippedWeapon)) { [string]$script:GameState.Combat.EquippedWeapon } elseif ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'DeferredEquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.DeferredEquippedWeapon)) { [string]$script:GameState.Combat.DeferredEquippedWeapon } else { $null })
    Add-LWBookNamedCount -PropertyName 'WeaponUsage' -Name $weaponName
}

function Register-LWCombatResolved {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.RoundsFought = [int]$stats.RoundsFought + [int]$Summary.RoundCount

    switch ([string]$Summary.Outcome) {
        'Victory' {
            $stats.Victories = [int]$stats.Victories + 1
            if ((Test-LWPropertyExists -Object $Summary -Name 'Mindblast') -and $Summary.Mindblast) {
                $stats.MindblastVictories = [int]$stats.MindblastVictories + 1
            }
            $weaponName = Get-LWCombatDisplayWeapon -Weapon ([string]$Summary.Weapon)
            Add-LWBookNamedCount -PropertyName 'WeaponVictories' -Name $weaponName

            $summaryRounds = if ((Test-LWPropertyExists -Object $Summary -Name 'RoundCount') -and $null -ne $Summary.RoundCount) { [int]$Summary.RoundCount } else { 0 }
            $summaryRatio = if ((Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') -and $null -ne $Summary.CombatRatio) { [int]$Summary.CombatRatio } else { $null }
            if ($null -ne $Summary.EnemyCombatSkill -and [int]$Summary.EnemyCombatSkill -gt [int]$stats.HighestEnemyCombatSkillDefeated) {
                $stats.HighestEnemyCombatSkillDefeated = [int]$Summary.EnemyCombatSkill
            }
            if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyEnduranceMax') -and $null -ne $Summary.EnemyEnduranceMax -and [int]$Summary.EnemyEnduranceMax -gt [int]$stats.HighestEnemyEnduranceDefeated) {
                $stats.HighestEnemyEnduranceDefeated = [int]$Summary.EnemyEnduranceMax
            }

            if ($summaryRounds -gt 0 -and ([int]$stats.FastestVictoryRounds -eq 0 -or $summaryRounds -lt [int]$stats.FastestVictoryRounds)) {
                $stats.FastestVictoryRounds = $summaryRounds
                $stats.FastestVictoryEnemyName = [string]$Summary.EnemyName
            }

            if ($null -ne $summaryRatio -and ($null -eq $stats.EasiestVictoryRatio -or [int]$summaryRatio -gt [int]$stats.EasiestVictoryRatio)) {
                $stats.EasiestVictoryRatio = [int]$summaryRatio
                $stats.EasiestVictoryEnemyName = [string]$Summary.EnemyName
            }
        }
        'Knockout' {
            $stats.Victories = [int]$stats.Victories + 1
            if ((Test-LWPropertyExists -Object $Summary -Name 'Mindblast') -and $Summary.Mindblast) {
                $stats.MindblastVictories = [int]$stats.MindblastVictories + 1
            }
            $weaponName = Get-LWCombatDisplayWeapon -Weapon ([string]$Summary.Weapon)
            Add-LWBookNamedCount -PropertyName 'WeaponVictories' -Name $weaponName
            if ($null -ne $Summary.EnemyCombatSkill -and [int]$Summary.EnemyCombatSkill -gt [int]$stats.HighestEnemyCombatSkillDefeated) {
                $stats.HighestEnemyCombatSkillDefeated = [int]$Summary.EnemyCombatSkill
            }
            if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyEnduranceMax') -and $null -ne $Summary.EnemyEnduranceMax -and [int]$Summary.EnemyEnduranceMax -gt [int]$stats.HighestEnemyEnduranceDefeated) {
                $stats.HighestEnemyEnduranceDefeated = [int]$Summary.EnemyEnduranceMax
            }
            $summaryRounds = if ($null -ne $Summary.RoundCount) { [int]$Summary.RoundCount } else { 0 }
            if ($summaryRounds -gt 0 -and ([int]$stats.FastestVictoryRounds -eq 0 -or $summaryRounds -lt [int]$stats.FastestVictoryRounds)) {
                $stats.FastestVictoryRounds = $summaryRounds
                $stats.FastestVictoryEnemyName = [string]$Summary.EnemyName
            }
            $summaryRatio = $null
            if ((Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') -and $null -ne $Summary.CombatRatio) {
                $summaryRatio = [int]$Summary.CombatRatio
            }
            if ($null -ne $summaryRatio -and ($null -eq $stats.EasiestVictoryRatio -or [int]$summaryRatio -gt [int]$stats.EasiestVictoryRatio)) {
                $stats.EasiestVictoryRatio = [int]$summaryRatio
                $stats.EasiestVictoryEnemyName = [string]$Summary.EnemyName
            }
        }
        'Defeat' {
            $stats.Defeats = [int]$stats.Defeats + 1
        }
        'Evaded' {
            $stats.Evades = [int]$stats.Evades + 1
        }
    }

    $roundCount = if ($null -ne $Summary.RoundCount) { [int]$Summary.RoundCount } else { 0 }
    if ($roundCount -gt [int]$stats.LongestFightRounds) {
        $stats.LongestFightRounds = $roundCount
        $stats.LongestFightEnemyName = [string]$Summary.EnemyName
    }

    [void](Sync-LWAchievements -Context 'combat' -Data $Summary)
}

function Test-LWWeaponMatchesWeaponskill {
    param(
        [string]$Weapon,
        [string]$WeaponskillWeapon
    )

    if ([string]::IsNullOrWhiteSpace($Weapon) -or [string]::IsNullOrWhiteSpace($WeaponskillWeapon)) {
        return $false
    }

    if ($Weapon -ieq $WeaponskillWeapon) {
        return $true
    }

    if ((Test-LWWeaponIsDrodarinWarHammer -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Warhammer') {
        return $true
    }

    if ((Test-LWWeaponIsBroninWarhammer -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Warhammer') {
        return $true
    }

    if ((Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Broadsword') {
        return $true
    }

    if ((Test-LWWeaponIsSolnaris -Weapon $Weapon) -and @('Broadsword', 'Sword') -contains [string]$WeaponskillWeapon) {
        return $true
    }

    if ((Test-LWWeaponIsMagicSpear -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Spear') {
        return $true
    }

    if ((Test-LWWeaponIsCaptainDValSword -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Sword') {
        return $true
    }

    return $false
}

function Get-LWStateAletherPotionName {
    param([Parameter(Mandatory = $true)][object]$State)

    $location = Find-LWStateInventoryItemLocation -State $State -Names @((Get-LWAletherPotionItemNames) + (Get-LWAletherBerryItemNames)) -Types @('herbpouch', 'backpack')
    if ($null -eq $location) {
        return $null
    }

    return [string]$location.Name
}

function Get-LWStateAletherCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWCombatAletherAvailable -State $State)) {
        return 0
    }

    return [int]$State.Combat.AletherCombatSkillBonus
}

function Get-LWMagnakaiWeaponmasteryOptions {
    return @('Dagger', 'Spear', 'Mace', 'Warhammer', 'Sword', 'Axe', 'Short Sword', 'Quarterstaff', 'Broadsword', 'Bow')
}

function Invoke-LWCombatCommand {
    param([string[]]$Parts)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Parts) {
        $Parts = @()
    }
    else {
        $Parts = @($Parts)
    }

    if ($Parts.Count -lt 2) {
        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View = if ($script:GameState.Combat.Active) { 'status' } else { 'summary' }
            })
        return
    }

    $combatSubcommand = $Parts[1].ToLowerInvariant()
    switch ($combatSubcommand) {
        'start'  {
            if ($Parts.Count -gt 2) {
                [void](Start-LWCombat -Arguments @($Parts[2..($Parts.Count - 1)]))
            }
            else {
                [void](Start-LWCombat)
            }
        }
        'round'  { [void](Invoke-LWCombatRound) }
        'next'   { [void](Invoke-LWCombatRound) }
        'potion' { [void](Invoke-LWCombatPotionRound) }
        'auto'   { Resolve-LWCombatToOutcome }
        'status' {
            if ($script:GameState.Combat.Active) {
                Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                        View = 'status'
                    })
            }
            elseif (@($script:GameState.History).Count -gt 0) {
                Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                        View    = 'summary'
                        Summary = $script:GameState.History[-1]
                    })
            }
            else {
                Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                        View = 'summary'
                    })
                Write-LWWarn 'No active combat.'
            }
        }
        'log'    {
            if ($Parts.Count -gt 2) {
                $logTarget = $Parts[2].Trim()
                if ($logTarget.ToLowerInvariant() -eq 'all') {
                    Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                            All = $true
                        })
                }
                elseif ($logTarget.ToLowerInvariant() -eq 'book') {
                    if ($Parts.Count -lt 4) {
                        Write-LWWarn 'combat log book <n> expects a book number.'
                    }
                    else {
                        $bookNumber = 0
                        if ([int]::TryParse($Parts[3], [ref]$bookNumber) -and $bookNumber -ge 1) {
                            Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                                    All        = $true
                                    BookNumber = $bookNumber
                                })
                        }
                        else {
                            Write-LWWarn 'combat log book <n> expects a valid book number.'
                        }
                    }
                }
                else {
                    $historyIndex = 0
                    if ([int]::TryParse($logTarget, [ref]$historyIndex)) {
                        $history = @($script:GameState.History)
                        if ($historyIndex -lt 1 -or $historyIndex -gt $history.Count) {
                            Write-LWWarn 'combat log accepts a history number, all, or book <n>.'
                        }
                        else {
                            Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                                    Entry = $history[$historyIndex - 1]
                                })
                        }
                    }
                    else {
                        Write-LWWarn 'combat log accepts a history number, all, or book <n>.'
                    }
                }
            }
            else {
                $entry = $null
                if ($script:GameState.Combat.Active) {
                    $entry = Get-LWCurrentCombatLogEntry
                }
                elseif (@($script:GameState.History).Count -gt 0) {
                    $entry = $script:GameState.History[-1]
                }

                if ($null -eq $entry) {
                    Write-LWWarn 'No combat log available.'
                }
                else {
                    Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                            Entry = $entry
                        })
                }
            }
        }
        'evade'  { Invoke-LWEvade }
        'stop'   { [void](Stop-LWCombat) }
        default  {
            if ($Parts.Count -ge 4) {
                [void](Start-LWCombat -Arguments @($Parts[1..($Parts.Count - 1)]))
                return
            }

            Write-LWWarn 'Unknown combat subcommand. Use start, round, next, potion, auto, status, log, evade, or stop.'
        }
    }
}

Export-ModuleMember -Function Set-LWCombatEntryBookMetadata, Get-LWCurrentBookResolvedCombatCount, Get-LWCombatHistorySectionBackfillName, Get-LWCombatHistorySectionBackfill, Normalize-LWCombatHistorySections, Test-LWCombatKnockoutAvailable, Test-LWCombatAletherAvailable, Test-LWWeaponIsNonEdgeForKnockout, Test-LWWeaponIsSommerswerd, Test-LWWeaponIsMagicalForCombat, Test-LWCombatMagicSpearAvailable, Test-LWStateHasSommerswerd, Test-LWStateHasSommerswerdWeaponskill, Get-LWStateCombatWeapons, Get-LWStateBoneSwordCombatSkillBonus, Get-LWStateDrodarinWarHammerCombatSkillBonus, Get-LWStateBroninWarhammerCombatSkillBonus, Get-LWStateBroadswordPlusOneCombatSkillBonus, Get-LWStateSolnarisCombatSkillBonus, Test-LWWeaponMatchesWeaponmastery, Get-LWStateWeaponmasteryCombatSkillBonus, Test-LWCombatPsychicAttackUsesPsiSurge, Get-LWCombatPsychicAttackLabel, Get-LWCombatPsychicAttackBonus, Get-LWCombatPsychicAttackEnduranceDrain, Get-LWStateDaggerOfVashnaEndurancePenalty, Get-LWStateCaptainDValSwordCombatSkillBonus, Get-LWCombatKnockoutCombatSkillPenalty, Test-LWCombatSommerswerdAvailable, Get-LWStateSommerswerdCombatSkillBonus, Get-LWStateSommerswerdFallbackWeaponskillBonus, Test-LWCombatUsesSommerswerd, Test-LWCombatSommerswerdPowerActive, Test-LWCombatSommerswerdUndeadDoubleDamageActive, Test-LWCombatUsesMindforce, Test-LWCombatMindforceBlockedByMindshield, Get-LWStateCompletedLoreCircles, Get-LWStateLoreCircleCombatSkillBonus, Get-LWStateLoreCircleEnduranceBonus, Sync-LWMagnakaiLoreCircleBonuses, Get-LWLoreCircleDisplayName, Get-LWLoreCircleDisplayOrder, Format-LWLoreCirclePanelRow, Get-LWCombatMindforceLossPerRound, Get-LWCombatCurrentRoundNumber, Get-LWCombatActivePlayerCombatSkillModifier, Get-LWCombatEvadeStatusText, Test-LWCombatCanEvadeNow, Get-LWCombatMindforceStatusText, New-LWCombatState, Test-LWStateHasActiveWeaponskill, Test-LWCombatHerbPouchOptionActive, Get-LWPreferredHerbPouchCombatPotionChoice, Get-LWModeAdjustedSommerswerdBonus, Register-LWCombatStarted, Register-LWCombatResolved, Test-LWWeaponMatchesWeaponskill, Get-LWStateAletherPotionName, Get-LWStateAletherCombatSkillBonus, Get-LWMagnakaiWeaponmasteryOptions, Invoke-LWCombatCommand

