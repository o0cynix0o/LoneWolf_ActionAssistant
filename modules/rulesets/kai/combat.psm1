Set-StrictMode -Version Latest

function Get-LWKaiCombatEncounterProfile {
    param([Parameter(Mandatory = $true)][object]$State)

    if ($null -eq $State.Character) {
        return $null
    }

    switch ([int]$State.Character.BookNumber) {
        2 {
            switch ([int]$State.CurrentSection) {
                106 {
                    return [pscustomobject]@{
                        EnemyName        = 'Helghast'
                        EnemyCombatSkill = 22
                        EnemyEndurance   = 30
                        InfoMessage      = 'Book 2 section 106 combat detected: Helghast (CS 22, END 30).'
                    }
                }
                332 {
                    return [pscustomobject]@{
                        EnemyName        = 'Helghast'
                        EnemyCombatSkill = 21
                        EnemyEndurance   = 30
                        InfoMessage      = 'Book 2 section 332 combat detected: Helghast (CS 21, END 30).'
                    }
                }
                344 {
                    return [pscustomobject]@{
                        Blocked = $true
                        Warning = 'Section 344 is not a combat. The correct route there is to flee to section 183.'
                    }
                }
            }
        }
        3 {
            if (@(170, 328) -contains [int]$State.CurrentSection) {
                return [pscustomobject]@{
                    DisableAlether = $true
                }
            }
        }
    }

    return $null
}

function Invoke-LWKaiCombatScenarioRules {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][hashtable]$Scenario
    )

    $script:GameState = $State
    $enemyName = [string]$Scenario.EnemyName
    $useQuickDefaults = [bool]$Scenario.UseQuickDefaults

    if ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 29 -and [string]$enemyName -ieq 'Vordak') {
        $Scenario.EnemyUndead = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            Write-LWWarn 'Book 1 section 29: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        $Scenario.VictoryResolutionSection = 270
        $Scenario.VictoryResolutionNote = 'Section 29 result: victory sends you to 270.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 34 -and [string]$enemyName -ieq 'Vordak') {
        $Scenario.EnemyUndead = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            Write-LWWarn 'Book 1 section 34: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        $Scenario.VictoryResolutionSection = 328
        $Scenario.VictoryResolutionNote = 'Section 34 result: victory sends you to 328.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 43 -and [string]$enemyName -ieq 'Black Bear') {
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 3
        $Scenario.EvadeResolutionSection = 106
        $Scenario.EvadeResolutionNote = 'Section 43 result: after round 3 you may flee downhill to 106.'
        $Scenario.VictoryResolutionSection = 195
        $Scenario.VictoryResolutionNote = 'Section 43 result: victory sends you to 195.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 55 -and [string]$enemyName -ieq 'Giak') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 4
        Write-LWInfo 'Book 1 section 55: surprise attack grants +4 Combat Skill for the whole fight.'
        $Scenario.VictoryResolutionSection = 325
        $Scenario.VictoryResolutionNote = 'Section 55 result: victory sends you to 325.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 133 -and [string]$enemyName -ieq 'Winged Serpent') {
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 1 section 133: Winged Serpent is immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 266
        $Scenario.VictoryResolutionNote = 'Section 133 result: victory sends you to 266.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 170 -and [string]$enemyName -ieq 'Burrowcrawler') {
        $Scenario.EnemyImmune = $true
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
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 3
            Write-LWWarn 'Book 1 section 170: fighting in darkness applies -3 Combat Skill.'
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and @(180, 343) -contains [int]$script:GameState.CurrentSection) {
        Write-LWInfo ("Book 1 section {0}: fight these enemies one at a time." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and @(191, 220) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Bodyguard') {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 234
        $Scenario.EvadeResolutionNote = ("Section {0} result: evading means jumping from the caravan to 234." -f [int]$script:GameState.CurrentSection)
        $Scenario.VictoryResolutionSection = 24
        $Scenario.VictoryResolutionNote = ("Section {0} result: victory sends you to 24." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 231 -and [string]$enemyName -ieq 'Robber') {
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 2
        $Scenario.EvadeResolutionSection = 7
        $Scenario.EvadeResolutionNote = 'Section 231 result: after round 2 you may flee through the front door to 7.'
        $Scenario.VictoryWithinRoundsSection = 94
        $Scenario.VictoryWithinRoundsMax = 4
        $Scenario.VictoryWithinRoundsNote = 'Section 231 result: kill the robber within 4 rounds and turn to 94.'
        $Scenario.OngoingFailureAfterRoundsSection = 203
        $Scenario.OngoingFailureAfterRoundsThreshold = 4
        $Scenario.OngoingFailureAfterRoundsNote = 'Section 231 result: if you are still fighting after 4 rounds, turn to 203.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 255 -and [string]$enemyName -ieq 'Gourgaz') {
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 1 section 255: Gourgaz is immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 82
        $Scenario.VictoryResolutionNote = 'Section 255 result: victory sends you to 82.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 283 -and [string]$enemyName -ieq 'Vordak') {
        $Scenario.EnemyUndead = $true
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
        $Scenario.PlayerModRounds = 1
        Write-LWInfo 'Book 1 section 283: surprise grants +2 Combat Skill in round 1.'
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerModAfterRounds = [int]$Scenario.PlayerModAfterRounds - 2
            $Scenario.PlayerModAfterRoundStart = 2
            Write-LWWarn 'Book 1 section 283: Vordak Mindforce applies -2 Combat Skill from round 2 onward unless you possess Mindshield.'
        }
        $Scenario.VictoryResolutionSection = 123
        $Scenario.VictoryResolutionNote = 'Section 283 result: victory sends you to 123.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 339 -and [string]$enemyName -ieq 'Robber') {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 7
        $Scenario.EvadeResolutionNote = 'Section 339 result: you may flee through the front door to 7.'
        $Scenario.VictoryWithinRoundsSection = 94
        $Scenario.VictoryWithinRoundsMax = 4
        $Scenario.VictoryWithinRoundsNote = 'Section 339 result: kill the robber within 4 rounds and turn to 94.'
        $Scenario.OngoingFailureAfterRoundsSection = 203
        $Scenario.OngoingFailureAfterRoundsThreshold = 4
        $Scenario.OngoingFailureAfterRoundsNote = 'Section 339 result: if you are still fighting after 4 rounds, turn to 203.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 342 -and [string]$enemyName -ieq 'Vordak') {
        $Scenario.EnemyUndead = $true
        $Scenario.EnemyImmune = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            Write-LWWarn 'Book 1 section 342: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        Write-LWInfo 'Book 1 section 342: Vordak is immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 123
        $Scenario.VictoryResolutionNote = 'Section 342 result: victory sends you to 123.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 5 -and [string]$enemyName -ieq 'Wounded Helghast') {
        $Scenario.EnemyUndead = $true
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 2 section 5: Wounded Helghast is undead and immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 166
        $Scenario.VictoryResolutionNote = 'Section 5 result: victory sends you to 166.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and @(7, 270) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -match 'Ganon|Dorier') {
        $Scenario.EnemyImmune = $true
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
        $Scenario.PlayerModRounds = 1
        Write-LWInfo ("Book 2 section {0}: surprise grants +2 Combat Skill in round 1 and the brothers are immune to Mindblast." -f [int]$script:GameState.CurrentSection)
        $Scenario.VictoryResolutionSection = 33
        $Scenario.VictoryResolutionNote = ("Section {0} result: victory sends you to 33." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 17 -and [string]$enemyName -ieq 'Helghast') {
        $Scenario.EnemyUndead = $true
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 2 section 17: Helghast is undead and immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 166
        $Scenario.VictoryResolutionNote = 'Section 17 result: victory sends you to 166.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 59 -and [string]$enemyName -ieq 'Helghast') {
        $Scenario.EnemyImmune = $true
        $Scenario.EnemyRequiresMagicalWeapon = $true
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 311
        $Scenario.EvadeResolutionNote = 'Section 59 result: without a magical weapon you must evade and dive into the forest to 311.'
        Write-LWInfo 'Book 2 section 59: this Helghast is immune to Mindblast and can only be wounded by a magical weapon.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 66 -and [string]$enemyName -ieq 'Zombie Captain') {
        $Scenario.EnemyUndead = $true
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 2 section 66: Zombie Captain is undead and immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 218
        $Scenario.VictoryResolutionNote = 'Section 66 result: victory sends you to 218.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 106 -and [string]$enemyName -ieq 'Helghast') {
        $Scenario.EnemyImmune = $true
        $Scenario.EnemyUsesMindforce = $true
        $Scenario.EnemyRequiresMagicSpear = $true
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 2 section 106: this Helghast is immune to Mindblast, attacks with Mindforce each round, and can only be harmed by the Magic Spear.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 128 -and [string]$enemyName -ieq 'Zombie Crew') {
        $Scenario.EnemyUndead = $true
        Write-LWInfo 'Book 2 section 128: Zombie Crew is undead.'
        $Scenario.VictoryResolutionSection = 237
        $Scenario.VictoryResolutionNote = 'Section 128 result: victory sends you to 237.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 268 -and [string]$enemyName -ieq 'Harbour Thugs') {
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 2
        $Scenario.EvadeResolutionSection = 125
        $Scenario.EvadeResolutionNote = 'Section 268 result: after round 2 you may run through the side door to 125.'
        $Scenario.VictoryResolutionSection = 333
        $Scenario.VictoryResolutionNote = 'Section 268 result: victory sends you to 333.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 332 -and [string]$enemyName -ieq 'Helghast') {
        $Scenario.EnemyImmune = $true
        $Scenario.EnemyUsesMindforce = $true
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 183
        $Scenario.EvadeResolutionNote = 'Section 332 result: evading sends you into the forest to 183.'
        $Scenario.VictoryResolutionSection = 92
        $Scenario.VictoryResolutionNote = 'Section 332 result: victory sends you to 92.'
        Write-LWInfo 'Book 2 section 332: Helghast is immune to Mindblast and its Mindforce costs 2 END per round unless Mindshield blocks it.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 83) {
        $Scenario.EnemyImmune = $true
        $Scenario.EnemyUsesMindforce = $true
        $Scenario.MindforceLossPerRound = 2
        Write-LWInfo 'Book 3 section 83: the mutants are immune to Mindblast and their controller attacks with Mindforce for 2 END each round unless blocked by Mindshield.'
        $Scenario.VictoryResolutionSection = 313
        $Scenario.VictoryResolutionNote = 'Section 83 result: victory sends you to 313.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 88 -and [string]$enemyName -ieq 'Javek') {
        $Scenario.EnemyImmune = $true
        $Scenario.UseJavekPoisonRule = $true
        Write-LWInfo 'Book 3 section 88: Javek is immune to Mindblast and uses the special venom-survival rule instead of normal END loss.'
        $Scenario.VictoryResolutionSection = 269
        $Scenario.VictoryResolutionNote = 'Section 88 result: victory sends you to 269.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 106) {
        $Scenario.EnemyImmune = $true
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 145
        $Scenario.EvadeResolutionNote = 'Section 106 result: evading sends you back to the chamber and north passage at 145.'
        Write-LWInfo 'Book 3 section 106: Ice Barbarians are immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 338
        $Scenario.VictoryResolutionNote = 'Section 106 result: victory sends you to 338.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 137) {
        $Scenario.MindblastCombatSkillBonus = 1
        Write-LWInfo 'Book 3 section 137: Mindblast only grants +1 Combat Skill in this fight.'
        $Scenario.VictoryResolutionSection = 28
        $Scenario.VictoryResolutionNote = 'Section 137 result: victory sends you to 28.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 138) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 277
        $Scenario.EvadeResolutionNote = 'Section 138 result: you may evade by turning to 277.'
        $Scenario.PlayerLossResolutionSection = 66
        $Scenario.PlayerLossResolutionNote = 'Section 138 result: if you lose any ENDURANCE, turn immediately to 66.'
        $Scenario.VictoryWithoutLossSection = 25
        $Scenario.VictoryWithoutLossNote = 'Section 138 result: if you win without losing any ENDURANCE, turn to 25.'
        Write-LWInfo 'Book 3 section 138: the Kalkoths attack one at a time.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 147) {
        $Scenario.CanEvade = $false
        $Scenario.PlayerLossResolutionSection = 66
        $Scenario.PlayerLossResolutionNote = 'Section 147 result: if you lose any ENDURANCE, turn immediately to 66.'
        $Scenario.VictoryWithoutLossSection = 84
        $Scenario.VictoryWithoutLossNote = 'Section 147 result: if you win without losing any ENDURANCE, turn to 84.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 161 -and [string]$enemyName -ieq 'Ice Barbarian') {
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 3 section 161: Ice Barbarian is immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 210
        $Scenario.VictoryResolutionNote = 'Section 161 result: victory sends you to 210.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 164) {
        $Scenario.EnemyUndead = $true
        $Scenario.VictoryWithinRoundsSection = 272
        $Scenario.VictoryWithinRoundsMax = 5
        $Scenario.VictoryWithinRoundsNote = 'Section 164 result: defeat the Akraa''Neonor in 5 rounds or less and turn to 272.'
        $Scenario.OngoingFailureAfterRoundsSection = 324
        $Scenario.OngoingFailureAfterRoundsThreshold = 5
        $Scenario.OngoingFailureAfterRoundsNote = 'Section 164 result: if the combat takes longer than 5 rounds, turn to 324.'
        Write-LWInfo 'Book 3 section 164: Akraa''Neonor is undead and must be defeated in 5 rounds or less.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and @(170, 328) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Helghast') {
        $Scenario.EnemyUndead = $true
        $Scenario.EnemyImmune = $true
        Write-LWWarn ("Book 3 section {0}: no potions may be taken before this combat." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 263) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 277
        $Scenario.EvadeResolutionNote = 'Section 263 result: you may evade at any time by turning to 277.'
        $Scenario.PlayerLossResolutionSection = 66
        $Scenario.PlayerLossResolutionNote = 'Section 263 result: if you lose any ENDURANCE, turn immediately to 66.'
        $Scenario.VictoryWithoutLossSection = 25
        $Scenario.VictoryWithoutLossNote = 'Section 263 result: if you win without losing any ENDURANCE, turn to 25.'
        Write-LWInfo 'Book 3 section 263: the Kalkoths attack one at a time.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 343) {
        if ([string]$enemyName -ieq 'Ice Barbarian') {
            $Scenario.EnemyImmune = $true
            Write-LWInfo 'Book 3 section 343: the final Ice Barbarian is immune to Mindblast.'
        }
        else {
            Write-LWInfo 'Book 3 section 343: fight these enemies one at a time in the listed order.'
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [string]$enemyName -match '^Barraka') {
        $Scenario.EnemyImmune = $true
        if ([int]$script:GameState.CurrentSection -eq 122) {
            Write-LWInfo 'Book 4 section 122: Barraka is immune to Mindblast.'
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 4
                Write-LWWarn 'Book 4 section 122: Barraka''s mind attack applies -4 Combat Skill unless you possess Mindshield.'
            }
            else {
                Write-LWInfo 'Mindshield blocks Barraka''s Combat Skill penalty in section 122.'
            }
        }
        elseif ([int]$script:GameState.CurrentSection -eq 325) {
            Write-LWInfo 'Book 4 section 325: Barraka is immune to Mindblast.'
            $Scenario.CanEvade = $false
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 26 -and [string]$enemyName -ieq 'Stoneworm') {
        $Scenario.EnemyImmune = $true
        Write-LWInfo 'Book 4 section 26: Stoneworm is immune to Mindblast.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 62 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.PlayerModRounds = 3
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 62: you fight from the ground at -2 Combat Skill for the first 3 rounds and cannot evade.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 65 -and [string]$enemyName -ieq 'Tunnel Fiends') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 65: Tunnel Fiends combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 77 -and [string]$enemyName -ieq 'Vassagonian Captain') {
        $Scenario.EnemyImmune = $true
        $Scenario.EnemyUsesMindforce = $true
        $Scenario.MindforceLossPerRound = 1
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 2
        Write-LWInfo 'Book 4 section 77: the captain is immune to Mindblast, attacks your mind for 1 END each round unless blocked by Mindshield, and can only be evaded after 2 rounds.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 88 -and [string]$enemyName -ieq 'Stoneworm') {
        $Scenario.EnemyImmune = $true
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 88: Stoneworm is immune to Mindblast and the combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 89 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 89: mounted combat here cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 147 -and [string]$enemyName -ieq 'Bridge Guard') {
        $Scenario.IgnoreFirstRoundEnduranceLoss = $true
        Write-LWInfo 'Book 4 section 147: surprise attack lets you ignore all Lone Wolf END loss in the first round.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 176 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 176: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and @(194, 234) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Giant Meresquid') {
        $oxygenRoll = Get-LWRandomDigit
        $oxygenRounds = if ($oxygenRoll -eq 0) { 10 } else { $oxygenRoll }
        if (Test-LWDiscipline -Name 'Mind Over Matter') {
            $oxygenRounds += 2
        }
        $Scenario.SpecialPlayerEnduranceLossAmount = 2
        $Scenario.SpecialPlayerEnduranceLossStartRound = $oxygenRounds + 1
        $Scenario.SpecialPlayerEnduranceLossReason = 'Lack of oxygen'
        Write-LWInfo ("Book 4 section {0}: underwater oxygen threshold roll {1} gives you {2} safe round{3} before lack-of-oxygen loss begins." -f [int]$script:GameState.CurrentSection, $oxygenRoll, $oxygenRounds, $(if ($oxygenRounds -eq 1) { '' } else { 's' }))
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 196 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 196: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 233) {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 233: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 308 -and [string]$enemyName -ieq 'Elix') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 308: Elix combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 310 -and [string]$enemyName -ieq 'Vassagonian Warrior') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 4 section 310: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 316 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.CanEvade = $true
        Write-LWInfo 'Book 4 section 316: bad footing applies -2 Combat Skill, but you may evade by diving into the River Xane.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 333 -and [string]$enemyName -ieq 'Vassagonian Horseman') {
        $Scenario.OneRoundOnly = $true
        Write-LWInfo 'Book 4 section 333: this mounted pass lasts exactly one combat round before the horseman rushes past.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 4 -and [string]$enemyName -ieq 'Palace Gaoler') {
        $Scenario.IgnoreEnemyEnduranceLossRounds = 1
        $Scenario.VictoryWithinRoundsSection = 165
        $Scenario.VictoryWithinRoundsMax = 4
        $Scenario.VictoryWithinRoundsNote = 'Section 4 result: win within 4 rounds and turn to 165.'
        $Scenario.VictoryResolutionSection = 180
        $Scenario.VictoryResolutionNote = 'Section 4 result: if the fight lasts longer than 4 rounds, victory sends you to 180.'
        Write-LWInfo 'Book 5 section 4: enemy ENDURANCE loss is ignored in round 1.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 12 -and [string]$enemyName -ieq 'Bloodlug') {
        $Scenario.EnemyImmune = $true
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.VictoryResolutionSection = 95
        $Scenario.VictoryResolutionNote = 'Section 12 result: victory sends you to 95.'
        Write-LWInfo 'Book 5 section 12: Bloodlug is immune to Mindblast and you fight at -2 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 20 -and [string]$enemyName -ieq 'Horseman') {
        $Scenario.CanEvade = $true
        $Scenario.RestoreHalfEnduranceLossOnVictory = $true
        $Scenario.RestoreHalfEnduranceLossOnEvade = $true
        $Scenario.VictoryWithinRoundsSection = 125
        $Scenario.VictoryWithinRoundsMax = 3
        $Scenario.VictoryWithinRoundsNote = 'Section 20 result: win in 3 rounds or less and turn to 125.'
        $Scenario.OngoingFailureAfterRoundsSection = 82
        $Scenario.OngoingFailureAfterRoundsThreshold = 4
        $Scenario.OngoingFailureAfterRoundsNote = 'Section 20 result: if the fight lasts longer than 3 rounds, stop and turn to 82.'
        $Scenario.DefeatResolutionSection = 161
        $Scenario.DefeatResolutionNote = 'Section 20 result: losing this fight sends you to 161, where half your lost ENDURANCE is restored.'
        Write-LWInfo 'Book 5 section 20: you may evade manually to 142 or surrender to 176, and half END lost is restored after the clash.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 57 -and [string]$enemyName -ieq 'Elix') {
        if (@($script:GameState.History | Where-Object { [string]$_.EnemyName -ieq 'Elix' }).Count -gt 0) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
            Write-LWInfo 'Book 5 section 57: prior Elix experience grants +2 Combat Skill.'
        }
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 2
        $Scenario.VictoryResolutionNote = 'Section 57 result: victory sends you to 2.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and @(64, 110) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Kwaraz') {
        $Scenario.MindblastCombatSkillBonus = 4
        Write-LWInfo ("Book 5 section {0}: Kwaraz is unusually susceptible to Mindblast, which grants +4 Combat Skill here." -f [int]$script:GameState.CurrentSection)
        if ([int]$script:GameState.CurrentSection -eq 64) {
            $Scenario.VictoryResolutionSection = 177
            $Scenario.VictoryResolutionNote = 'Section 64 result: victory sends you to 177.'
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 91 -and [string]$enemyName -ieq 'Palace Gaoler') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 4
        $Scenario.VictoryWithinRoundsSection = 65
        $Scenario.VictoryWithinRoundsMax = 4
        $Scenario.VictoryWithinRoundsNote = 'Section 91 result: win within 4 rounds and turn to 65.'
        $Scenario.VictoryResolutionSection = 180
        $Scenario.VictoryResolutionNote = 'Section 91 result: if the fight lasts longer than 4 rounds, victory sends you to 180.'
        Write-LWInfo 'Book 5 section 91: fighting unarmed applies -4 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 106 -and [string]$enemyName -ieq 'Courier') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.PlayerModRounds = 3
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 189
        $Scenario.VictoryResolutionNote = 'Section 106 result: victory sends you to 189.'
        Write-LWInfo 'Book 5 section 106: you fight at -2 Combat Skill for the first 3 rounds and cannot evade.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 119 -and [string]$enemyName -ieq 'Palace Gate Guardians') {
        $Scenario.IgnorePlayerEnduranceLossRounds = 3
        $Scenario.VictoryResolutionSection = 137
        $Scenario.VictoryResolutionNote = 'Section 119 result: victory sends you to 137.'
        Write-LWInfo 'Book 5 section 119: ignore Lone Wolf ENDURANCE loss in the first 3 rounds.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 123 -and [string]$enemyName -ieq 'Sharnazim Underlord') {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 51
        $Scenario.EvadeResolutionNote = 'Section 123 result: evading sends you through the trapdoor to 51.'
        $Scenario.VictoryResolutionSection = 198
        $Scenario.VictoryResolutionNote = 'Section 123 result: victory sends you to 198.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 135 -and [string]$enemyName -ieq 'Sharnazim Warrior') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.DefeatResolutionSection = 161
        $Scenario.DefeatResolutionNote = 'Section 135 result: losing this combat sends you to 161, where half your lost ENDURANCE is restored.'
        $Scenario.VictoryResolutionSection = 130
        $Scenario.VictoryResolutionNote = 'Section 135 result: victory sends you to 130 after half your lost ENDURANCE is restored.'
        $Scenario.RestoreHalfEnduranceLossOnVictory = $true
        Write-LWInfo 'Book 5 section 135: the noxious fumes apply -2 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 159 -and [string]$enemyName -ieq 'Armoury Guard') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.PlayerModRounds = 3
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 52
        $Scenario.VictoryResolutionNote = 'Section 159 result: victory sends you to 52.'
        Write-LWInfo 'Book 5 section 159: you fight from the floor at -2 Combat Skill for the first 3 rounds and cannot evade.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 168 -and [string]$enemyName -ieq 'Vestibule Guard') {
        $Scenario.VictoryWithinRoundsSection = 101
        $Scenario.VictoryWithinRoundsMax = 3
        $Scenario.VictoryWithinRoundsNote = 'Section 168 result: win in 3 rounds or less and turn to 101.'
        $Scenario.VictoryResolutionSection = 46
        $Scenario.VictoryResolutionNote = 'Section 168 result: if the fight lasts longer than 3 rounds, victory sends you to 46.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 178 -and [string]$enemyName -ieq 'Armoury Guard') {
        $Scenario.CanEvade = $false
        Write-LWInfo 'Book 5 section 178: this combat cannot be evaded. On victory, choose manually between searching the body (52) or entering the armoury (140).'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 190 -and [string]$enemyName -ieq 'Hammerfist the Armourer') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.VictoryResolutionSection = 111
        $Scenario.VictoryResolutionNote = 'Section 190 result: victory sends you to 111.'
        Write-LWInfo 'Book 5 section 190: the heat of the forge room applies -2 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 194 -and [string]$enemyName -ieq 'Yas') {
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 3
            Write-LWWarn 'Book 5 section 194: the Yas hypnotizes you for -3 Combat Skill unless you possess Mindshield.'
        }
        $Scenario.VictoryResolutionSection = 35
        $Scenario.VictoryResolutionNote = 'Section 194 result: victory sends you to 35.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 223 -and [string]$enemyName -ieq 'Crypt Spawn') {
        $Scenario.VictoryResolutionSection = 353
        $Scenario.VictoryResolutionNote = 'Section 223 result: victory sends you to 353.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and @(240, 370) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Itikar') {
        $Scenario.DoubleEnemyEnduranceLoss = $true
        if ([int]$script:GameState.CurrentSection -eq 240) {
            $Scenario.VictoryResolutionSection = 217
            $Scenario.VictoryResolutionNote = 'Section 240 result: subduing the Itikar sends you to 217.'
        }
        else {
            $Scenario.VictoryResolutionSection = 267
            $Scenario.VictoryResolutionNote = 'Section 370 result: subduing the Itikar sends you to 267.'
        }
        Write-LWInfo ("Book 5 section {0}: double all ENDURANCE lost by the Itikar." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 280 -and [string]$enemyName -ieq 'Drakkar') {
        $Scenario.IgnoreFirstRoundEnduranceLoss = $true
        $Scenario.VictoryResolutionSection = 213
        $Scenario.VictoryResolutionNote = 'Section 280 result: victory sends you to 213.'
        Write-LWInfo 'Book 5 section 280: surprise attack lets you ignore all Lone Wolf END loss in the first round.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 299 -and [string]$enemyName -ieq 'Vordak') {
        $Scenario.EnemyImmune = $true
        $Scenario.CanEvade = $false
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            Write-LWWarn 'Book 5 section 299: the Vordak''s Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        Write-LWInfo 'Book 5 section 299: the Vordak is immune to Mindblast.'
        $Scenario.VictoryResolutionSection = 203
        $Scenario.VictoryResolutionNote = 'Section 299 result: victory sends you to 203.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 316 -and [string]$enemyName -ieq 'Drakkar') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.PlayerModRounds = 3
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 333
        $Scenario.VictoryResolutionNote = 'Section 316 result: victory sends you to 333.'
        Write-LWInfo 'Book 5 section 316: surprise attack applies -2 Combat Skill for the first 3 rounds and the fight cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 330 -and [string]$enemyName -ieq 'Drakkar') {
        $Scenario.VictoryWithinRoundsSection = 243
        $Scenario.VictoryWithinRoundsMax = 2
        $Scenario.VictoryWithinRoundsNote = 'Section 330 result: win in 2 rounds or less and turn to 243.'
        $Scenario.OngoingFailureAfterRoundsSection = 394
        $Scenario.OngoingFailureAfterRoundsThreshold = 3
        $Scenario.OngoingFailureAfterRoundsNote = 'Section 330 result: if the combat lasts longer than 2 rounds, stop and turn to 394.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 353 -and [string]$enemyName -ieq 'Darklord Haakon') {
        if (Test-LWWeaponIsSommerswerd -Weapon ([string]$Scenario.EquippedWeapon)) {
            $Scenario.SommerswerdSuppressed = $true
            Write-LWWarn 'Book 5 section 353: underground, the Sommerswerd cannot discharge its power.'
        }
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            Write-LWWarn 'Book 5 section 353: Haakon''s psychic assault applies -2 Combat Skill unless you possess Mindshield.'
        }
        $Scenario.VictoryResolutionSection = 400
        $Scenario.VictoryResolutionNote = 'Section 353 result: victory sends you to 400.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 355 -and [string]$enemyName -ieq 'Vordak') {
        $Scenario.EnemyImmune = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            Write-LWWarn 'Book 5 section 355: the Vordak''s Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        Write-LWInfo 'Book 5 section 355: the Vordak is immune to Mindblast.'
        $Scenario.VictoryWithinRoundsSection = 249
        $Scenario.VictoryWithinRoundsMax = 4
        $Scenario.VictoryWithinRoundsNote = 'Section 355 result: win in 4 rounds or less and turn to 249.'
        $Scenario.VictoryResolutionSection = 304
        $Scenario.VictoryResolutionNote = 'Section 355 result: if the fight lasts longer than 4 rounds, victory sends you to 304.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 357 -and [string]$enemyName -ieq 'Platform Sentry') {
        $Scenario.CanEvade = $false
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.FallOnRollValue = 1
        $Scenario.FallOnRollResolutionSection = 293
        $Scenario.FallOnRollResolutionNote = 'Section 357 result: a Random Number Table roll of 1 makes you lose your balance and fall to 293.'
        Write-LWInfo 'Book 5 section 357: unstable footing applies -2 Combat Skill and a roll of 1 makes you fall.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 361 -and [string]$enemyName -ieq 'Drakkar') {
        $Scenario.VictoryWithinRoundsSection = 288
        $Scenario.VictoryWithinRoundsMax = 3
        $Scenario.VictoryWithinRoundsNote = 'Section 361 result: win in 3 rounds or less and turn to 288.'
        $Scenario.OngoingFailureAfterRoundsSection = 382
        $Scenario.OngoingFailureAfterRoundsThreshold = 4
        $Scenario.OngoingFailureAfterRoundsNote = 'Section 361 result: if the fight reaches round 4, stop and turn to 382.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 393 -and [string]$enemyName -ieq 'Drakkar') {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
        $Scenario.PlayerModRounds = 1
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 3
        $Scenario.EvadeResolutionSection = 228
        $Scenario.EvadeResolutionNote = 'Section 393 result: you may evade after round 3 by turning to 228.'
        $Scenario.VictoryResolutionSection = 255
        $Scenario.VictoryResolutionNote = 'Section 393 result: victory sends you to 255.'
        Write-LWInfo 'Book 5 section 393: surprise attack applies -2 Combat Skill in round 1.'
    }
}

Export-ModuleMember -Function `
    Get-LWKaiCombatEncounterProfile, `
    Invoke-LWKaiCombatScenarioRules
