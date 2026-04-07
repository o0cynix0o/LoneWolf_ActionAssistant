Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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

        $bookTwoSection106Helghast = ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 106)
        $bookTwoSection332Helghast = ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 332)
        $quickStart = Get-LWCombatStartArguments -Arguments $Arguments
        $useQuickDefaults = $false
        if ($null -ne $quickStart) {
            $enemyName = $quickStart.EnemyName
            $enemyCombatSkill = $quickStart.EnemyCombatSkill
            $enemyEndurance = $quickStart.EnemyEndurance
            Write-LWInfo "Quick combat setup: $enemyName (CS $enemyCombatSkill, END $enemyEndurance)."
            $useQuickDefaults = Read-LWYesNo -Prompt 'Use default combat assumptions for the rest of setup?' -Default $true
        }
        elseif ($bookTwoSection106Helghast) {
            $enemyName = 'Helghast'
            $enemyCombatSkill = 22
            $enemyEndurance = 30
            Write-LWInfo 'Book 2 section 106 combat detected: Helghast (CS 22, END 30).'
        }
        elseif ($bookTwoSection332Helghast) {
            $enemyName = 'Helghast'
            $enemyCombatSkill = 21
            $enemyEndurance = 30
            Write-LWInfo 'Book 2 section 332 combat detected: Helghast (CS 21, END 30).'
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

        if ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 344 -and [string]$enemyName -ieq 'Helghast') {
            Write-LWWarn 'Section 344 is not a combat. The correct route there is to flee to section 183.'
            return $false
        }

        $enemyImmune = $false
        $enemyUndead = $false
        $enemyUsesMindforce = $false
        $enemyRequiresMagicSpear = $false
        $enemyRequiresMagicalWeapon = $false
        $canEvade = $false
        $evadeAvailableAfterRound = 0
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
        if (-not $useQuickDefaults) {
            $enemyImmune = Read-LWYesNo -Prompt 'Is the enemy immune to Mindblast?' -Default $false
            $enemyUndead = Read-LWYesNo -Prompt 'Is the enemy undead?' -Default $false
            $enemyUsesMindforce = Read-LWYesNo -Prompt 'Is the enemy attacking with Mindforce each combat round?' -Default $false
            $canEvade = Read-LWYesNo -Prompt 'Can Lone Wolf evade this combat if desired?' -Default $false
        }

        if ($bookTwoSection106Helghast) {
            $enemyImmune = $true
            $enemyUsesMindforce = $true
            $enemyRequiresMagicSpear = $true
            $canEvade = $false
            Write-LWInfo 'Book 2 section 106: this Helghast is immune to Mindblast, attacks with Mindforce each round, and can only be harmed by the Magic Spear.'
        }
        elseif ($bookTwoSection332Helghast) {
            $enemyImmune = $true
            $enemyUsesMindforce = $true
            $canEvade = $true
            Write-LWInfo 'Book 2 section 332: this Helghast is immune to Mindblast and attacks with a Mindforce-style assault each round.'
        }

        $equippedWeapon = Select-LWCombatWeapon -DefaultWeapon (Get-LWPreferredCombatWeapon -State $script:GameState)
        $sommerswerdSuppressed = $false
        $aletherCombatSkillBonus = 0
        $attemptKnockout = $false
        if ([int]$script:GameState.Character.BookNumber -eq 3 -and @(170, 328) -contains [int]$script:GameState.CurrentSection) {
            $allowAletherBeforeCombat = $false
        }
        if ($allowAletherBeforeCombat -and (Test-LWCombatAletherAvailable -State $script:GameState)) {
            $aletherPotionName = Get-LWStateAletherPotionName -State $script:GameState
            if (-not [string]::IsNullOrWhiteSpace($aletherPotionName)) {
                $useAlether = Read-LWYesNo -Prompt 'Use Alether before this fight for +4 Combat Skill?' -Default $false
                if ($useAlether) {
                    Remove-LWInventoryItem -Type 'backpack' -Name $aletherPotionName -Quantity 1
                    $aletherCombatSkillBonus = 4
                    Write-LWInfo "$aletherPotionName is used before combat and grants +4 Combat Skill for this fight."
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

        $bookSixSection26Altan = ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 26 -and [string]$enemyName -ieq 'Altan')
        if ((-not $bookSixSection26Altan) -and (Test-LWCombatKnockoutAvailable -State $script:GameState)) {
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
        if ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 29 -and [string]$enemyName -ieq 'Vordak') {
            $enemyUndead = $true
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 2
                Write-LWWarn 'Book 1 section 29: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
            }
            $victoryResolutionSection = 270
            $victoryResolutionNote = 'Section 29 result: victory sends you to 270.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 34 -and [string]$enemyName -ieq 'Vordak') {
            $enemyUndead = $true
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 2
                Write-LWWarn 'Book 1 section 34: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
            }
            $victoryResolutionSection = 328
            $victoryResolutionNote = 'Section 34 result: victory sends you to 328.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 43 -and [string]$enemyName -ieq 'Black Bear') {
            $canEvade = $true
            $evadeAvailableAfterRound = 3
            $evadeResolutionSection = 106
            $evadeResolutionNote = 'Section 43 result: after round 3 you may flee downhill to 106.'
            $victoryResolutionSection = 195
            $victoryResolutionNote = 'Section 43 result: victory sends you to 195.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 55 -and [string]$enemyName -ieq 'Giak') {
            $playerMod += 4
            Write-LWInfo 'Book 1 section 55: surprise attack grants +4 Combat Skill for the whole fight.'
            $victoryResolutionSection = 325
            $victoryResolutionNote = 'Section 55 result: victory sends you to 325.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 133 -and [string]$enemyName -ieq 'Winged Serpent') {
            $enemyImmune = $true
            Write-LWInfo 'Book 1 section 133: Winged Serpent is immune to Mindblast.'
            $victoryResolutionSection = 266
            $victoryResolutionNote = 'Section 133 result: victory sends you to 266.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 170 -and [string]$enemyName -ieq 'Burrowcrawler') {
            $enemyImmune = $true
            Write-LWInfo 'Book 1 section 170: Burrowcrawler is immune to Mindblast.'

            $hasTorch = -not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWTorchItemNames) -Type 'backpack'))
            $hasTinderbox = -not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWTinderboxItemNames) -Type 'backpack'))
            $torchLit = $false
            if ($hasTorch -and $hasTinderbox) {
                if ($useQuickDefaults) {
                    $torchLit = $true
                }
                else {
                    $torchLit = Read-LWYesNo -Prompt 'Light a Torch to avoid the darkness penalty?' -Default $true
                }
            }

            if ($torchLit) {
                Write-LWInfo 'Torch lit. No darkness penalty applies in this fight.'
            }
            else {
                $playerMod -= 3
                Write-LWWarn 'Book 1 section 170: fighting in darkness applies -3 Combat Skill.'
            }
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and @(180, 343) -contains [int]$script:GameState.CurrentSection) {
            Write-LWInfo ("Book 1 section {0}: fight these enemies one at a time." -f [int]$script:GameState.CurrentSection)
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and @(191, 220) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Bodyguard') {
            $canEvade = $true
            $evadeResolutionSection = 234
            $evadeResolutionNote = ("Section {0} result: evading means jumping from the caravan to 234." -f [int]$script:GameState.CurrentSection)
            $victoryResolutionSection = 24
            $victoryResolutionNote = ("Section {0} result: victory sends you to 24." -f [int]$script:GameState.CurrentSection)
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 231 -and [string]$enemyName -ieq 'Robber') {
            $canEvade = $true
            $evadeAvailableAfterRound = 2
            $evadeResolutionSection = 7
            $evadeResolutionNote = 'Section 231 result: after round 2 you may flee through the front door to 7.'
            $victoryWithinRoundsSection = 94
            $victoryWithinRoundsMax = 4
            $victoryWithinRoundsNote = 'Section 231 result: kill the robber within 4 rounds and turn to 94.'
            $ongoingFailureAfterRoundsSection = 203
            $ongoingFailureAfterRoundsThreshold = 4
            $ongoingFailureAfterRoundsNote = 'Section 231 result: if you are still fighting after 4 rounds, turn to 203.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 255 -and [string]$enemyName -ieq 'Gourgaz') {
            $enemyImmune = $true
            Write-LWInfo 'Book 1 section 255: Gourgaz is immune to Mindblast.'
            $victoryResolutionSection = 82
            $victoryResolutionNote = 'Section 255 result: victory sends you to 82.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 283 -and [string]$enemyName -ieq 'Vordak') {
            $enemyUndead = $true
            $playerMod += 2
            $playerModRounds = 1
            Write-LWInfo 'Book 1 section 283: surprise grants +2 Combat Skill in round 1.'
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerModAfterRounds -= 2
                $playerModAfterRoundStart = 2
                Write-LWWarn 'Book 1 section 283: Vordak Mindforce applies -2 Combat Skill from round 2 onward unless you possess Mindshield.'
            }
            $victoryResolutionSection = 123
            $victoryResolutionNote = 'Section 283 result: victory sends you to 123.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 339 -and [string]$enemyName -ieq 'Robber') {
            $canEvade = $true
            $evadeResolutionSection = 7
            $evadeResolutionNote = 'Section 339 result: you may flee through the front door to 7.'
            $victoryWithinRoundsSection = 94
            $victoryWithinRoundsMax = 4
            $victoryWithinRoundsNote = 'Section 339 result: kill the robber within 4 rounds and turn to 94.'
            $ongoingFailureAfterRoundsSection = 203
            $ongoingFailureAfterRoundsThreshold = 4
            $ongoingFailureAfterRoundsNote = 'Section 339 result: if you are still fighting after 4 rounds, turn to 203.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 342 -and [string]$enemyName -ieq 'Vordak') {
            $enemyUndead = $true
            $enemyImmune = $true
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 2
                Write-LWWarn 'Book 1 section 342: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
            }
            Write-LWInfo 'Book 1 section 342: Vordak is immune to Mindblast.'
            $victoryResolutionSection = 123
            $victoryResolutionNote = 'Section 342 result: victory sends you to 123.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 5 -and [string]$enemyName -ieq 'Wounded Helghast') {
            $enemyUndead = $true
            $enemyImmune = $true
            Write-LWInfo 'Book 2 section 5: Wounded Helghast is undead and immune to Mindblast.'
            $victoryResolutionSection = 166
            $victoryResolutionNote = 'Section 5 result: victory sends you to 166.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and @(7, 270) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -match 'Ganon|Dorier') {
            $enemyImmune = $true
            $playerMod += 2
            $playerModRounds = 1
            Write-LWInfo ("Book 2 section {0}: surprise grants +2 Combat Skill in round 1 and the brothers are immune to Mindblast." -f [int]$script:GameState.CurrentSection)
            $victoryResolutionSection = 33
            $victoryResolutionNote = ("Section {0} result: victory sends you to 33." -f [int]$script:GameState.CurrentSection)
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 17 -and [string]$enemyName -ieq 'Helghast') {
            $enemyUndead = $true
            $enemyImmune = $true
            Write-LWInfo 'Book 2 section 17: Helghast is undead and immune to Mindblast.'
            $victoryResolutionSection = 166
            $victoryResolutionNote = 'Section 17 result: victory sends you to 166.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 59 -and [string]$enemyName -ieq 'Helghast') {
            $enemyImmune = $true
            $enemyRequiresMagicalWeapon = $true
            $canEvade = $true
            $evadeResolutionSection = 311
            $evadeResolutionNote = 'Section 59 result: without a magical weapon you must evade and dive into the forest to 311.'
            Write-LWInfo 'Book 2 section 59: this Helghast is immune to Mindblast and can only be wounded by a magical weapon.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 66 -and [string]$enemyName -ieq 'Zombie Captain') {
            $enemyUndead = $true
            $enemyImmune = $true
            Write-LWInfo 'Book 2 section 66: Zombie Captain is undead and immune to Mindblast.'
            $victoryResolutionSection = 218
            $victoryResolutionNote = 'Section 66 result: victory sends you to 218.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 128 -and [string]$enemyName -ieq 'Zombie Crew') {
            $enemyUndead = $true
            Write-LWInfo 'Book 2 section 128: Zombie Crew is undead.'
            $victoryResolutionSection = 237
            $victoryResolutionNote = 'Section 128 result: victory sends you to 237.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 268 -and [string]$enemyName -ieq 'Harbour Thugs') {
            $canEvade = $true
            $evadeAvailableAfterRound = 2
            $evadeResolutionSection = 125
            $evadeResolutionNote = 'Section 268 result: after round 2 you may run through the side door to 125.'
            $victoryResolutionSection = 333
            $victoryResolutionNote = 'Section 268 result: victory sends you to 333.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 332 -and [string]$enemyName -ieq 'Helghast') {
            $enemyImmune = $true
            $enemyUsesMindforce = $true
            $canEvade = $true
            $evadeResolutionSection = 183
            $evadeResolutionNote = 'Section 332 result: evading sends you into the forest to 183.'
            $victoryResolutionSection = 92
            $victoryResolutionNote = 'Section 332 result: victory sends you to 92.'
            Write-LWInfo 'Book 2 section 332: Helghast is immune to Mindblast and its Mindforce costs 2 END per round unless Mindshield blocks it.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 83) {
            $enemyImmune = $true
            $enemyUsesMindforce = $true
            $mindforceLossPerRound = 2
            Write-LWInfo 'Book 3 section 83: the mutants are immune to Mindblast and their controller attacks with Mindforce for 2 END each round unless blocked by Mindshield.'
            $victoryResolutionSection = 313
            $victoryResolutionNote = 'Section 83 result: victory sends you to 313.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 88 -and [string]$enemyName -ieq 'Javek') {
            $enemyImmune = $true
            $useJavekPoisonRule = $true
            Write-LWInfo 'Book 3 section 88: Javek is immune to Mindblast and uses the special venom-survival rule instead of normal END loss.'
            $victoryResolutionSection = 269
            $victoryResolutionNote = 'Section 88 result: victory sends you to 269.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 106) {
            $enemyImmune = $true
            $canEvade = $true
            $evadeResolutionSection = 145
            $evadeResolutionNote = 'Section 106 result: evading sends you back to the chamber and north passage at 145.'
            Write-LWInfo 'Book 3 section 106: Ice Barbarians are immune to Mindblast.'
            $victoryResolutionSection = 338
            $victoryResolutionNote = 'Section 106 result: victory sends you to 338.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 137) {
            $mindblastCombatSkillBonus = 1
            Write-LWInfo 'Book 3 section 137: Mindblast only grants +1 Combat Skill in this fight.'
            $victoryResolutionSection = 28
            $victoryResolutionNote = 'Section 137 result: victory sends you to 28.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 138) {
            $canEvade = $true
            $evadeResolutionSection = 277
            $evadeResolutionNote = 'Section 138 result: you may evade by turning to 277.'
            $playerLossResolutionSection = 66
            $playerLossResolutionNote = 'Section 138 result: if you lose any ENDURANCE, turn immediately to 66.'
            $victoryWithoutLossSection = 25
            $victoryWithoutLossNote = 'Section 138 result: if you win without losing any ENDURANCE, turn to 25.'
            Write-LWInfo 'Book 3 section 138: the Kalkoths attack one at a time.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 147) {
            $canEvade = $false
            $playerLossResolutionSection = 66
            $playerLossResolutionNote = 'Section 147 result: if you lose any ENDURANCE, turn immediately to 66.'
            $victoryWithoutLossSection = 84
            $victoryWithoutLossNote = 'Section 147 result: if you win without losing any ENDURANCE, turn to 84.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 161 -and [string]$enemyName -ieq 'Ice Barbarian') {
            $enemyImmune = $true
            Write-LWInfo 'Book 3 section 161: Ice Barbarian is immune to Mindblast.'
            $victoryResolutionSection = 210
            $victoryResolutionNote = 'Section 161 result: victory sends you to 210.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 164) {
            $enemyUndead = $true
            $victoryWithinRoundsSection = 272
            $victoryWithinRoundsMax = 5
            $victoryWithinRoundsNote = 'Section 164 result: defeat the Akraa''Neonor in 5 rounds or less and turn to 272.'
            $ongoingFailureAfterRoundsSection = 324
            $ongoingFailureAfterRoundsThreshold = 5
            $ongoingFailureAfterRoundsNote = 'Section 164 result: if the combat takes longer than 5 rounds, turn to 324.'
            Write-LWInfo 'Book 3 section 164: Akraa''Neonor is undead and must be defeated in 5 rounds or less.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and @(170, 328) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Helghast') {
            $enemyUndead = $true
            $enemyImmune = $true
            Write-LWWarn ("Book 3 section {0}: no potions may be taken before this combat." -f [int]$script:GameState.CurrentSection)
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 263) {
            $canEvade = $true
            $evadeResolutionSection = 277
            $evadeResolutionNote = 'Section 263 result: you may evade at any time by turning to 277.'
            $playerLossResolutionSection = 66
            $playerLossResolutionNote = 'Section 263 result: if you lose any ENDURANCE, turn immediately to 66.'
            $victoryWithoutLossSection = 25
            $victoryWithoutLossNote = 'Section 263 result: if you win without losing any ENDURANCE, turn to 25.'
            Write-LWInfo 'Book 3 section 263: the Kalkoths attack one at a time.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 343) {
            if ([string]$enemyName -ieq 'Ice Barbarian') {
                $enemyImmune = $true
                Write-LWInfo 'Book 3 section 343: the final Ice Barbarian is immune to Mindblast.'
            }
            else {
                Write-LWInfo 'Book 3 section 343: fight these enemies one at a time in the listed order.'
            }
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [string]$enemyName -match '^Barraka') {
            $enemyImmune = $true
            if ([int]$script:GameState.CurrentSection -eq 122) {
                Write-LWInfo 'Book 4 section 122: Barraka is immune to Mindblast.'
                if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                    $playerMod -= 4
                    Write-LWWarn 'Book 4 section 122: Barraka''s mind attack applies -4 Combat Skill unless you possess Mindshield.'
                }
                else {
                    Write-LWInfo 'Mindshield blocks Barraka''s Combat Skill penalty in section 122.'
                }
            }
            elseif ([int]$script:GameState.CurrentSection -eq 325) {
                Write-LWInfo 'Book 4 section 325: Barraka is immune to Mindblast.'
                $canEvade = $false
            }
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 26 -and [string]$enemyName -ieq 'Stoneworm') {
            $enemyImmune = $true
            Write-LWInfo 'Book 4 section 26: Stoneworm is immune to Mindblast.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 62 -and [string]$enemyName -ieq 'Bandit Warrior') {
            $playerMod -= 2
            $playerModRounds = 3
            $canEvade = $false
            Write-LWInfo 'Book 4 section 62: you fight from the ground at -2 Combat Skill for the first 3 rounds and cannot evade.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 65 -and [string]$enemyName -ieq 'Tunnel Fiends') {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 65: Tunnel Fiends combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 77 -and [string]$enemyName -ieq 'Vassagonian Captain') {
            $enemyImmune = $true
            $enemyUsesMindforce = $true
            $mindforceLossPerRound = 1
            $canEvade = $true
            $evadeAvailableAfterRound = 2
            Write-LWInfo 'Book 4 section 77: the captain is immune to Mindblast, attacks your mind for 1 END each round unless blocked by Mindshield, and can only be evaded after 2 rounds.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 88 -and [string]$enemyName -ieq 'Stoneworm') {
            $enemyImmune = $true
            $canEvade = $false
            Write-LWInfo 'Book 4 section 88: Stoneworm is immune to Mindblast and the combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 89 -and [string]$enemyName -ieq 'Bandit Warrior') {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 89: mounted combat here cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 147 -and [string]$enemyName -ieq 'Bridge Guard') {
            $ignoreFirstRoundEnduranceLoss = $true
            Write-LWInfo 'Book 4 section 147: surprise attack lets you ignore all Lone Wolf END loss in the first round.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 176 -and [string]$enemyName -ieq 'Bandit Warrior') {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 176: this combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and @(
                194,
                234
            ) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Giant Meresquid') {
            $oxygenRoll = Get-LWRandomDigit
            $oxygenRounds = if ($oxygenRoll -eq 0) { 10 } else { $oxygenRoll }
            if (Test-LWDiscipline -Name 'Mind Over Matter') {
                $oxygenRounds += 2
            }
            $specialPlayerLossAmount = 2
            $specialPlayerLossStartRound = $oxygenRounds + 1
            $specialPlayerLossReason = 'Lack of oxygen'
            Write-LWInfo ("Book 4 section {0}: underwater oxygen threshold roll {1} gives you {2} safe round{3} before lack-of-oxygen loss begins." -f [int]$script:GameState.CurrentSection, $oxygenRoll, $oxygenRounds, $(if ($oxygenRounds -eq 1) { '' } else { 's' }))
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 196 -and [string]$enemyName -ieq 'Bandit Warrior') {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 196: this combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 233) {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 233: this combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 308 -and [string]$enemyName -ieq 'Elix') {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 308: Elix combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 310 -and [string]$enemyName -ieq 'Vassagonian Warrior') {
            $canEvade = $false
            Write-LWInfo 'Book 4 section 310: this combat cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 316 -and [string]$enemyName -ieq 'Bandit Warrior') {
            $playerMod -= 2
            $canEvade = $true
            Write-LWInfo 'Book 4 section 316: bad footing applies -2 Combat Skill, but you may evade by diving into the River Xane.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 333 -and [string]$enemyName -ieq 'Vassagonian Horseman') {
            $oneRoundOnly = $true
            Write-LWInfo 'Book 4 section 333: this mounted pass lasts exactly one combat round before the horseman rushes past.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 4 -and [string]$enemyName -ieq 'Palace Gaoler') {
            $ignoreEnemyEnduranceLossRounds = 1
            $victoryWithinRoundsSection = 165
            $victoryWithinRoundsMax = 4
            $victoryWithinRoundsNote = 'Section 4 result: win within 4 rounds and turn to 165.'
            $victoryResolutionSection = 180
            $victoryResolutionNote = 'Section 4 result: if the fight lasts longer than 4 rounds, victory sends you to 180.'
            Write-LWInfo 'Book 5 section 4: enemy ENDURANCE loss is ignored in round 1.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 12 -and [string]$enemyName -ieq 'Bloodlug') {
            $enemyImmune = $true
            $playerMod -= 2
            $victoryResolutionSection = 95
            $victoryResolutionNote = 'Section 12 result: victory sends you to 95.'
            Write-LWInfo 'Book 5 section 12: Bloodlug is immune to Mindblast and you fight at -2 Combat Skill.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 20 -and [string]$enemyName -ieq 'Horseman') {
            $canEvade = $true
            $restoreHalfEnduranceLossOnVictory = $true
            $restoreHalfEnduranceLossOnEvade = $true
            $victoryWithinRoundsSection = 125
            $victoryWithinRoundsMax = 3
            $victoryWithinRoundsNote = 'Section 20 result: win in 3 rounds or less and turn to 125.'
            $ongoingFailureAfterRoundsSection = 82
            $ongoingFailureAfterRoundsThreshold = 4
            $ongoingFailureAfterRoundsNote = 'Section 20 result: if the fight lasts longer than 3 rounds, stop and turn to 82.'
            $defeatResolutionSection = 161
            $defeatResolutionNote = 'Section 20 result: losing this fight sends you to 161, where half your lost ENDURANCE is restored.'
            Write-LWInfo 'Book 5 section 20: you may evade manually to 142 or surrender to 176, and half END lost is restored after the clash.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 57 -and [string]$enemyName -ieq 'Elix') {
            if (@($script:GameState.History | Where-Object { [string]$_.EnemyName -ieq 'Elix' }).Count -gt 0) {
                $playerMod += 2
                Write-LWInfo 'Book 5 section 57: prior Elix experience grants +2 Combat Skill.'
            }
            $canEvade = $false
            $victoryResolutionSection = 2
            $victoryResolutionNote = 'Section 57 result: victory sends you to 2.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and @(64, 110) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Kwaraz') {
            $mindblastCombatSkillBonus = 4
            Write-LWInfo ("Book 5 section {0}: Kwaraz is unusually susceptible to Mindblast, which grants +4 Combat Skill here." -f [int]$script:GameState.CurrentSection)
            if ([int]$script:GameState.CurrentSection -eq 64) {
                $victoryResolutionSection = 177
                $victoryResolutionNote = 'Section 64 result: victory sends you to 177.'
            }
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 91 -and [string]$enemyName -ieq 'Palace Gaoler') {
            $playerMod -= 4
            $victoryWithinRoundsSection = 65
            $victoryWithinRoundsMax = 4
            $victoryWithinRoundsNote = 'Section 91 result: win within 4 rounds and turn to 65.'
            $victoryResolutionSection = 180
            $victoryResolutionNote = 'Section 91 result: if the fight lasts longer than 4 rounds, victory sends you to 180.'
            Write-LWInfo 'Book 5 section 91: fighting unarmed applies -4 Combat Skill.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 106 -and [string]$enemyName -ieq 'Courier') {
            $playerMod -= 2
            $playerModRounds = 3
            $canEvade = $false
            $victoryResolutionSection = 189
            $victoryResolutionNote = 'Section 106 result: victory sends you to 189.'
            Write-LWInfo 'Book 5 section 106: you fight at -2 Combat Skill for the first 3 rounds and cannot evade.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 119 -and [string]$enemyName -ieq 'Palace Gate Guardians') {
            $ignorePlayerEnduranceLossRounds = 3
            $victoryResolutionSection = 137
            $victoryResolutionNote = 'Section 119 result: victory sends you to 137.'
            Write-LWInfo 'Book 5 section 119: ignore Lone Wolf ENDURANCE loss in the first 3 rounds.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 123 -and [string]$enemyName -ieq 'Sharnazim Underlord') {
            $canEvade = $true
            $evadeResolutionSection = 51
            $evadeResolutionNote = 'Section 123 result: evading sends you through the trapdoor to 51.'
            $victoryResolutionSection = 198
            $victoryResolutionNote = 'Section 123 result: victory sends you to 198.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 135 -and [string]$enemyName -ieq 'Sharnazim Warrior') {
            $playerMod -= 2
            $defeatResolutionSection = 161
            $defeatResolutionNote = 'Section 135 result: losing this combat sends you to 161, where half your lost ENDURANCE is restored.'
            $victoryResolutionSection = 130
            $victoryResolutionNote = 'Section 135 result: victory sends you to 130 after half your lost ENDURANCE is restored.'
            $restoreHalfEnduranceLossOnVictory = $true
            Write-LWInfo 'Book 5 section 135: the noxious fumes apply -2 Combat Skill.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 159 -and [string]$enemyName -ieq 'Armoury Guard') {
            $playerMod -= 2
            $playerModRounds = 3
            $canEvade = $false
            $victoryResolutionSection = 52
            $victoryResolutionNote = 'Section 159 result: victory sends you to 52.'
            Write-LWInfo 'Book 5 section 159: you fight from the floor at -2 Combat Skill for the first 3 rounds and cannot evade.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 168 -and [string]$enemyName -ieq 'Vestibule Guard') {
            $victoryWithinRoundsSection = 101
            $victoryWithinRoundsMax = 3
            $victoryWithinRoundsNote = 'Section 168 result: win in 3 rounds or less and turn to 101.'
            $victoryResolutionSection = 46
            $victoryResolutionNote = 'Section 168 result: if the fight lasts longer than 3 rounds, victory sends you to 46.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 178 -and [string]$enemyName -ieq 'Armoury Guard') {
            $canEvade = $false
            Write-LWInfo 'Book 5 section 178: this combat cannot be evaded. On victory, choose manually between searching the body (52) or entering the armoury (140).'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 190 -and [string]$enemyName -ieq 'Hammerfist the Armourer') {
            $playerMod -= 2
            $victoryResolutionSection = 111
            $victoryResolutionNote = 'Section 190 result: victory sends you to 111.'
            Write-LWInfo 'Book 5 section 190: the heat of the forge room applies -2 Combat Skill.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 194 -and [string]$enemyName -ieq 'Yas') {
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 3
                Write-LWWarn 'Book 5 section 194: the Yas hypnotizes you for -3 Combat Skill unless you possess Mindshield.'
            }
            $victoryResolutionSection = 35
            $victoryResolutionNote = 'Section 194 result: victory sends you to 35.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 223 -and [string]$enemyName -ieq 'Crypt Spawn') {
            $victoryResolutionSection = 353
            $victoryResolutionNote = 'Section 223 result: victory sends you to 353.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and @(240, 370) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Itikar') {
            $doubleEnemyEnduranceLoss = $true
            if ([int]$script:GameState.CurrentSection -eq 240) {
                $victoryResolutionSection = 217
                $victoryResolutionNote = 'Section 240 result: subduing the Itikar sends you to 217.'
            }
            else {
                $victoryResolutionSection = 267
                $victoryResolutionNote = 'Section 370 result: subduing the Itikar sends you to 267.'
            }
            Write-LWInfo ("Book 5 section {0}: double all ENDURANCE lost by the Itikar." -f [int]$script:GameState.CurrentSection)
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 280 -and [string]$enemyName -ieq 'Drakkar') {
            $ignoreFirstRoundEnduranceLoss = $true
            $victoryResolutionSection = 213
            $victoryResolutionNote = 'Section 280 result: victory sends you to 213.'
            Write-LWInfo 'Book 5 section 280: surprise attack lets you ignore all Lone Wolf END loss in the first round.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 299 -and [string]$enemyName -ieq 'Vordak') {
            $enemyImmune = $true
            $canEvade = $false
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 2
                Write-LWWarn 'Book 5 section 299: the Vordak''s Mindforce applies -2 Combat Skill unless you possess Mindshield.'
            }
            Write-LWInfo 'Book 5 section 299: the Vordak is immune to Mindblast.'
            $victoryResolutionSection = 203
            $victoryResolutionNote = 'Section 299 result: victory sends you to 203.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 316 -and [string]$enemyName -ieq 'Drakkar') {
            $playerMod -= 2
            $playerModRounds = 3
            $canEvade = $false
            $victoryResolutionSection = 333
            $victoryResolutionNote = 'Section 316 result: victory sends you to 333.'
            Write-LWInfo 'Book 5 section 316: surprise attack applies -2 Combat Skill for the first 3 rounds and the fight cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 330 -and [string]$enemyName -ieq 'Drakkar') {
            $victoryWithinRoundsSection = 243
            $victoryWithinRoundsMax = 2
            $victoryWithinRoundsNote = 'Section 330 result: win in 2 rounds or less and turn to 243.'
            $ongoingFailureAfterRoundsSection = 394
            $ongoingFailureAfterRoundsThreshold = 3
            $ongoingFailureAfterRoundsNote = 'Section 330 result: if the combat lasts longer than 2 rounds, stop and turn to 394.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 353 -and [string]$enemyName -ieq 'Darklord Haakon') {
            if (Test-LWWeaponIsSommerswerd -Weapon $equippedWeapon) {
                $sommerswerdSuppressed = $true
                Write-LWWarn 'Book 5 section 353: underground, the Sommerswerd cannot discharge its power.'
            }
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 2
                Write-LWWarn 'Book 5 section 353: Haakon''s psychic assault applies -2 Combat Skill unless you possess Mindshield.'
            }
            $victoryResolutionSection = 400
            $victoryResolutionNote = 'Section 353 result: victory sends you to 400.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 355 -and [string]$enemyName -ieq 'Vordak') {
            $enemyImmune = $true
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 2
                Write-LWWarn 'Book 5 section 355: the Vordak''s Mindforce applies -2 Combat Skill unless you possess Mindshield.'
            }
            Write-LWInfo 'Book 5 section 355: the Vordak is immune to Mindblast.'
            $victoryWithinRoundsSection = 249
            $victoryWithinRoundsMax = 4
            $victoryWithinRoundsNote = 'Section 355 result: win in 4 rounds or less and turn to 249.'
            $victoryResolutionSection = 304
            $victoryResolutionNote = 'Section 355 result: if the fight lasts longer than 4 rounds, victory sends you to 304.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 357 -and [string]$enemyName -ieq 'Platform Sentry') {
            $canEvade = $false
            $playerMod -= 2
            $fallOnRollValue = 1
            $fallOnRollResolutionSection = 293
            $fallOnRollResolutionNote = 'Section 357 result: a Random Number Table roll of 1 makes you lose your balance and fall to 293.'
            Write-LWInfo 'Book 5 section 357: unstable footing applies -2 Combat Skill and a roll of 1 makes you fall.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 361 -and [string]$enemyName -ieq 'Drakkar') {
            $victoryWithinRoundsSection = 288
            $victoryWithinRoundsMax = 3
            $victoryWithinRoundsNote = 'Section 361 result: win in 3 rounds or less and turn to 288.'
            $ongoingFailureAfterRoundsSection = 382
            $ongoingFailureAfterRoundsThreshold = 4
            $ongoingFailureAfterRoundsNote = 'Section 361 result: if the fight reaches round 4, stop and turn to 382.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 393 -and [string]$enemyName -ieq 'Drakkar') {
            $playerMod -= 2
            $playerModRounds = 1
            $canEvade = $true
            $evadeAvailableAfterRound = 3
            $evadeResolutionSection = 228
            $evadeResolutionNote = 'Section 393 result: you may evade after round 3 by turning to 228.'
            $victoryResolutionSection = 255
            $victoryResolutionNote = 'Section 393 result: victory sends you to 255.'
            Write-LWInfo 'Book 5 section 393: surprise attack applies -2 Combat Skill in round 1.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 26 -and [string]$enemyName -ieq 'Altan') {
            $canEvade = $false
            $suppressShieldCombatSkillBonus = $true
            $usePlayerTargetEndurance = $true
            $playerTargetEnduranceCurrent = 50
            $playerTargetEnduranceMax = 50
            $selectedBowWeapon = [string](Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$equippedWeapon))
            if (-not [string]::IsNullOrWhiteSpace($selectedBowWeapon)) {
                $equippedWeapon = $selectedBowWeapon
            }
            else {
                $fallbackBowWeapon = [string](@($script:GameState.Inventory.Weapons | Where-Object {
                            -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$_)))
                        } | Select-Object -First 1))
                if (-not [string]::IsNullOrWhiteSpace($fallbackBowWeapon)) {
                    $equippedWeapon = $fallbackBowWeapon
                }
                else {
                    $equippedWeapon = 'Bow'
                }
            }
            $attemptKnockout = $false
            $victoryResolutionSection = 252
            $victoryResolutionNote = 'Section 26 result: if Altan loses all 50 TARGET points, turn to 252.'
            $defeatResolutionSection = 183
            $defeatResolutionNote = 'Section 26 result: if you lose all 50 TARGET points, turn to 183.'
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWJakanBowWeaponNames) -Target ([string]$equippedWeapon)))) {
                $fallOnRollValue = 0
                $fallOnRollResolutionSection = 335
                $fallOnRollResolutionNote = 'Section 26 result: while using the Jakan, a roll of 0 sends you immediately to 335.'
                Write-LWInfo 'Book 6 section 26: while using the Jakan, a roll of 0 sends you immediately to section 335.'
            }
            Write-LWInfo 'Book 6 section 26: the final is fought with Bow shots only, Shield bonuses are suppressed, and both archers use 50 TARGET points instead of normal ENDURANCE.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 71 -and [string]$enemyName -ieq 'Redbeard') {
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
                $playerMod += 2
                Write-LWInfo 'Book 6 section 71: Animal Control grants +2 Combat Skill while you fight from the saddle.'
            }
            $canEvade = $true
            $evadeResolutionSection = 279
            $evadeResolutionNote = 'Section 71 result: you may evade at any time by galloping along the street to 279.'
            $victoryResolutionSection = 237
            $victoryResolutionNote = 'Section 71 result: victory sends you to 237.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 77 -and [string]$enemyName -ieq 'Pirate Berserkers') {
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                $enemyImmune = $true
            }
            $victoryResolutionSection = 297
            $victoryResolutionNote = 'Section 77 result: victory sends you to 297.'
            Write-LWInfo 'Book 6 section 77: pirate berserkers are immune to Mindblast, but not Psi-surge.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 138 -and [string]$enemyName -ieq 'Varetta City Watch') {
            $canEvade = $false
            $victoryResolutionSection = 34
            $victoryResolutionNote = 'Section 138 result: victory sends you to 34.'
            Write-LWInfo 'Book 6 section 138: this fight cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 159 -and [string]$enemyName -ieq 'Varettian Mercenaries') {
            $canEvade = $false
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$equippedWeapon)))) {
                $fallbackWeapon = [string](@($script:GameState.Inventory.Weapons | Where-Object {
                            [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$_)))
                        } | Select-Object -First 1))
                if (-not [string]::IsNullOrWhiteSpace($fallbackWeapon)) {
                    $equippedWeapon = $fallbackWeapon
                    Write-LWWarn ("Book 6 section 159: a Bow cannot be used here, so you switch to {0}." -f $fallbackWeapon)
                }
                else {
                    $equippedWeapon = $null
                    Write-LWWarn 'Book 6 section 159: a Bow cannot be used here and no other weapon is ready, so you fight unarmed.'
                }
            }
            $victoryResolutionSection = 48
            $victoryResolutionNote = 'Section 159 result: victory sends you to 48.'
            Write-LWInfo 'Book 6 section 159: this fight cannot be evaded and Bows are unusable.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 194 -and [string]$enemyName -ieq 'Acolytes of Vashna') {
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
                $playerMod += 2
                Write-LWInfo 'Book 6 section 194: Animal Control grants +2 Combat Skill while you command your horse to attack.'
            }
            $canEvade = $true
            $evadeResolutionSection = 289
            $evadeResolutionNote = 'Section 194 result: you may evade at any time by turning to 289.'
            $victoryResolutionSection = 145
            $victoryResolutionNote = 'Section 194 result: victory sends you to 145.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 270 -and [string]$enemyName -ieq 'Undead Summonation') {
            $enemyUndead = $true
            $enemyImmune = $true
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery')) {
                $playerMod -= 2
                $playerModRounds = 2
            }
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
                $specialPlayerLossAmount = 2
                $specialPlayerLossStartRound = 1
                $specialPlayerLossReason = 'Bitter cold'
            }
            if (Test-LWWeaponIsSommerswerd -Weapon ([string]$equippedWeapon)) {
                $doubleEnemyEnduranceLoss = $true
            }
            $victoryResolutionSection = 326
            $victoryResolutionNote = 'Section 270 result: victory sends you to 326.'
            Write-LWInfo 'Book 6 section 270: the undead are immune to Psi-surge and Mindblast, and the Sommerswerd doubles the ENDURANCE you inflict here.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 282 -and [string]$enemyName -ieq 'Backstabbers') {
            $canEvade = $false
            $victoryResolutionSection = 88
            $victoryResolutionNote = 'Section 282 result: victory sends you to 88.'
            Write-LWInfo 'Book 6 section 282: this fight cannot be evaded.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 283 -and [string]$enemyName -ieq 'Armoured Assassin') {
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$equippedWeapon)))) {
                $fallbackWeapon = [string](@($script:GameState.Inventory.Weapons | Where-Object {
                            [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$_)))
                        } | Select-Object -First 1))
                if (-not [string]::IsNullOrWhiteSpace($fallbackWeapon)) {
                    $equippedWeapon = $fallbackWeapon
                    Write-LWWarn ("Book 6 section 283: a Bow cannot be used here, so you switch to {0}." -f $fallbackWeapon)
                }
                else {
                    $equippedWeapon = $null
                    Write-LWWarn 'Book 6 section 283: a Bow cannot be used here and no other weapon is ready, so you fight unarmed.'
                }
            }
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
                $playerMod += 1
                Write-LWInfo 'Book 6 section 283: Animal Control grants +1 Combat Skill for this fight.'
            }
            $canEvade = $false
            $victoryResolutionSection = 28
            $victoryResolutionNote = 'Section 283 result: victory sends you to 28.'
            Write-LWInfo 'Book 6 section 283: this fight cannot be evaded and Bows are unusable.'
        }
        elseif ([int]$script:GameState.Character.BookNumber -eq 6 -and [int]$script:GameState.CurrentSection -eq 344 -and [string]$enemyName -ieq 'Dakomyd') {
            $enemyImmune = $true
            $enemyEnduranceThreshold = 25
            $enemyEnduranceThresholdSection = 310
            $enemyEnduranceThresholdNote = 'Section 344 result: once Dakomyd is reduced to 25 ENDURANCE or less, stop combat and turn to 310.'
            Write-LWInfo 'Book 6 section 344: Dakomyd is immune to Psi-surge and Mindblast, and combat stops once it falls to 25 ENDURANCE or less.'
        }

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
            EvadeResolutionSection    = $evadeResolutionSection
            EvadeResolutionNote       = $evadeResolutionNote
            EquippedWeapon            = $equippedWeapon
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
    Invoke-LWCoreStartCombat

