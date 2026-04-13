Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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

