Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

function Resolve-LWMagnakaiRestrictedWeapon {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$EquippedWeapon = $null,
        [Parameter(Mandatory = $true)][string[]]$RestrictedNames,
        [string]$SectionLabel = 'This section',
        [string]$RestrictionDescription = 'that weapon'
    )

    if ([string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $RestrictedNames -Target ([string]$EquippedWeapon)))) {
        return $EquippedWeapon
    }

    $fallbackWeapon = [string](
        @(
            $State.Inventory.Weapons | Where-Object {
                [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $RestrictedNames -Target ([string]$_)))
            } | Select-Object -First 1
        )
    )

    if (-not [string]::IsNullOrWhiteSpace($fallbackWeapon)) {
        Write-LWWarn ("{0}: {1} cannot be used here, so you switch to {2}." -f $SectionLabel, $RestrictionDescription, $fallbackWeapon)
        return $fallbackWeapon
    }

    Write-LWWarn ("{0}: {1} cannot be used here and no other weapon is ready, so you fight unarmed." -f $SectionLabel, $RestrictionDescription)
    return $null
}

function Get-LWMagnakaiCombatEncounterProfile {
    param([Parameter(Mandatory = $true)][object]$State)

    if ($null -eq $State.Character -or [int]$State.Character.BookNumber -lt 6 -or [int]$State.Character.BookNumber -gt 7) {
        return $null
    }

    if ([int]$State.Character.BookNumber -eq 6) {
        switch ([int]$State.CurrentSection) {
            26 {
                return [pscustomobject]@{
                    SuppressKnockout = $true
                }
            }
            234 {
                return [pscustomobject]@{
                    EnemyName        = 'Plate-Armored Assassin'
                    EnemyCombatSkill = 24
                    EnemyEndurance   = 30
                    DisableAlether   = $true
                    InfoMessage      = 'Book 6 DE section 234 combat detected: Plate-Armored Assassin (CS 24, END 30).'
                }
            }
        }
    }
    elseif ([int]$State.Character.BookNumber -eq 7) {
        switch ([int]$State.CurrentSection) {
            8 { return [pscustomobject]@{ EnemyName = 'Hound of Death'; EnemyCombatSkill = 22; EnemyEndurance = 40 } }
            19 { return [pscustomobject]@{ EnemyName = 'Dhax'; EnemyCombatSkill = 25; EnemyEndurance = 32 } }
            27 { return [pscustomobject]@{ EnemyName = 'Oudakon'; EnemyCombatSkill = 20; EnemyEndurance = 29 } }
            45 { return [pscustomobject]@{ EnemyName = 'Flood of Giant Rats'; EnemyCombatSkill = 15; EnemyEndurance = 80 } }
            76 { return [pscustomobject]@{ EnemyName = 'Lekhor'; EnemyCombatSkill = 16; EnemyEndurance = 30 } }
            78 { return [pscustomobject]@{ EnemyName = 'Hound of Death'; EnemyCombatSkill = 22; EnemyEndurance = 40 } }
            93 { return [pscustomobject]@{ EnemyName = 'Trap-webs'; EnemyCombatSkill = 14; EnemyEndurance = 34 } }
            118 { return [pscustomobject]@{ EnemyName = 'Lord Zahda'; EnemyCombatSkill = 23; EnemyEndurance = 45 } }
            126 { return [pscustomobject]@{ EnemyName = 'Flame-man'; EnemyCombatSkill = 14; EnemyEndurance = 40 } }
            174 { return [pscustomobject]@{ EnemyName = 'Lord Zahda'; EnemyCombatSkill = 33; EnemyEndurance = 45 } }
            198 { return [pscustomobject]@{ EnemyName = 'Rahkos'; EnemyCombatSkill = 18; EnemyEndurance = 30 } }
            202 { return [pscustomobject]@{ EnemyName = 'Lord Zahda'; EnemyCombatSkill = 25; EnemyEndurance = 45 } }
            219 { return [pscustomobject]@{ EnemyName = 'Giant Hactaraton'; EnemyCombatSkill = 20; EnemyEndurance = 45 } }
            221 { return [pscustomobject]@{ EnemyName = 'Zagothal'; EnemyCombatSkill = 29; EnemyEndurance = 28 } }
            235 { return [pscustomobject]@{ EnemyName = 'Rahkos'; EnemyCombatSkill = 18; EnemyEndurance = 30 } }
            245 { return [pscustomobject]@{ EnemyName = 'Hound of Death'; EnemyCombatSkill = 22; EnemyEndurance = 40 } }
            249 { return [pscustomobject]@{ EnemyName = 'Dhax'; EnemyCombatSkill = 27; EnemyEndurance = 35 } }
            253 { return [pscustomobject]@{ EnemyName = 'Dhax'; EnemyCombatSkill = 20; EnemyEndurance = 26 } }
            257 { return [pscustomobject]@{ EnemyName = 'Invisible Whipmaster'; EnemyCombatSkill = 24; EnemyEndurance = 26 } }
            299 { return [pscustomobject]@{ EnemyName = 'Dhax'; EnemyCombatSkill = 27; EnemyEndurance = 35 } }
            301 { return [pscustomobject]@{ EnemyName = 'Giant Hactaraton'; EnemyCombatSkill = 22; EnemyEndurance = 60 } }
            314 { return [pscustomobject]@{ EnemyName = 'Dhax'; EnemyCombatSkill = 20; EnemyEndurance = 28 } }
            319 { return [pscustomobject]@{ EnemyName = 'Zahda Beastmen'; EnemyCombatSkill = 28; EnemyEndurance = 35 } }
            325 {
                return [pscustomobject]@{
                    EnemyName        = 'Black Lakeweed'
                    EnemyCombatSkill = 10
                    EnemyEndurance   = 50
                }
            }
        }
    }

    return $null
}

function Invoke-LWMagnakaiCombatScenarioRules {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][hashtable]$Scenario
    )

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
    $enemyName = [string]$Scenario.EnemyName

    $bookNumber = [int]$script:GameState.Character.BookNumber
    if ($bookNumber -lt 6 -or $bookNumber -gt 7) {
        return
    }

    if ($bookNumber -eq 7) {
        switch ([int]$script:GameState.CurrentSection) {
            8 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                $Scenario.VictoryResolutionSection = 194
                $Scenario.VictoryResolutionNote = 'Section 8 result: victory sends you to 194.'
                Write-LWInfo 'Book 7 section 8: the Hound of Death is immune to Mindblast, but not Psi-surge.'
                return
            }
            19 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery')) {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 3
                    $Scenario.PlayerModRounds = 2
                }
                $Scenario.CanEvade = $true
                $Scenario.EvadeAvailableAfterRound = 3
                $Scenario.EvadeResolutionSection = 241
                $Scenario.EvadeResolutionNote = 'Section 19 result: after 3 rounds you may evade into the archway and turn to 241.'
                $Scenario.VictoryResolutionSection = 141
                $Scenario.VictoryResolutionNote = 'Section 19 result: victory sends you to 141.'
                Write-LWInfo 'Book 7 section 19: unless you have Huntmastery, the surprise attack applies -3 Combat Skill in rounds 1-2.'
                return
            }
            27 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery')) {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 3
                    $Scenario.PlayerModRounds = 3
                }
                if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWJewelledMaceItemNames) -Type 'special'))) {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 5
                    Write-LWInfo 'Book 7 section 27: the Jewelled Mace grants +5 Combat Skill against Oudakon.'
                }
                $Scenario.CanEvade = $false
                $Scenario.VictoryResolutionSection = 5
                $Scenario.VictoryResolutionNote = 'Section 27 result: victory sends you to 5.'
                Write-LWInfo 'Book 7 section 27: unless you have Huntmastery, the sudden attack applies -3 Combat Skill in rounds 1-3.'
                return
            }
            45 {
                if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') -and (Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing')) {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
                    Write-LWInfo 'Book 7 section 45: Lore-circle of Light grants +2 Combat Skill for this fight.'
                }
                $Scenario.CanEvade = $true
                $Scenario.EvadeAvailableAfterRound = 3
                $Scenario.EvadeResolutionSection = 336
                $Scenario.EvadeResolutionNote = 'Section 45 result: after 3 rounds you may climb over the reef and turn to 336.'
                $Scenario.VictoryResolutionSection = 283
                $Scenario.VictoryResolutionNote = 'Section 45 result: victory sends you to 283.'
                return
            }
            76 {
                $Scenario.SuppressShieldCombatSkillBonus = $true
                $Scenario.PlayerEnduranceLossMultiplier = 3
                $Scenario.EquippedWeapon = Resolve-LWMagnakaiRestrictedWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -RestrictedNames @('Broadsword', 'Spear', 'Quarterstaff') -SectionLabel 'Book 7 section 76' -RestrictionDescription 'two-handed weapons'
                $Scenario.VictoryResolutionSection = 296
                $Scenario.VictoryResolutionNote = 'Section 76 result: victory sends you to 296.'
                Write-LWInfo 'Book 7 section 76: Shield bonuses are suppressed, two-handed weapons are unusable, and venom trebles Lone Wolf ENDURANCE loss.'
                return
            }
            78 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                $Scenario.VictoryResolutionSection = 341
                $Scenario.VictoryResolutionNote = 'Section 78 result: victory sends you to 341.'
                Write-LWInfo 'Book 7 section 78: the Hound of Death is immune to Mindblast, but not Psi-surge.'
                return
            }
            93 {
                $Scenario.EnemyImmune = $true
                $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 4
                $Scenario.CanEvade = $false
                $Scenario.VictoryResolutionSection = 131
                $Scenario.VictoryResolutionNote = 'Section 93 result: victory sends you to 131.'
                Write-LWInfo 'Book 7 section 93: Trap-webs are immune to Mindblast and Psi-surge, and your movement is restricted by -4 Combat Skill.'
                return
            }
            118 {
                $script:GameState.Character.EnduranceCurrent = [int]$script:GameState.Character.EnduranceMax
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery') {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
                }
                $Scenario.VictoryResolutionSection = 200
                $Scenario.VictoryResolutionNote = 'Section 118 result: victory sends you to 200.'
                Write-LWInfo 'Book 7 section 118: the Lorestone restores you to full ENDURANCE before the duel begins.'
                return
            }
            126 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
                    $Scenario.PlayerEnduranceLossMultiplier = 2
                    Write-LWInfo 'Book 7 section 126: the flames double Lone Wolf ENDURANCE loss unless you have Nexus.'
                }
                else {
                    Write-LWInfo 'Book 7 section 126: Nexus protects you from the worst of the flames.'
                }
                $Scenario.VictoryResolutionSection = 147
                $Scenario.VictoryResolutionNote = 'Section 126 result: victory sends you to 147.'
                return
            }
            174 {
                $Scenario.EnemyImmune = $true
                $Scenario.VictoryResolutionSection = 149
                $Scenario.VictoryResolutionNote = 'Section 174 result: victory sends you to 149.'
                Write-LWInfo 'Book 7 section 174: Zahda with the power-staff is immune to Mindblast and Psi-surge.'
                return
            }
            198 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                $Scenario.VictoryResolutionSection = 22
                $Scenario.VictoryResolutionNote = 'Section 198 result: victory sends you to 22.'
                Write-LWInfo 'Book 7 section 198: Rahkos is immune to Mindblast, but not Psi-surge.'
                return
            }
            202 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                $Scenario.VictoryResolutionSection = 149
                $Scenario.VictoryResolutionNote = 'Section 202 result: victory sends you to 149.'
                Write-LWInfo 'Book 7 section 202: Zahda is immune to Mindblast, but not Psi-surge.'
                return
            }
            219 {
                $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 4
                $Scenario.PlayerModRounds = 2
                if (-not [string]::IsNullOrWhiteSpace([string]$Scenario.EquippedWeapon)) {
                    $Scenario.DeferredEquippedWeapon = [string]$Scenario.EquippedWeapon
                    $Scenario.EquipDeferredWeaponAfterRound = 2
                    $Scenario.EquippedWeapon = $null
                }
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing')) {
                    $Scenario.PlayerEnduranceLossMultiplier = 2
                    Write-LWInfo 'Book 7 section 219: without Curing, the Hactaraton''s venom doubles Lone Wolf ENDURANCE loss.'
                }
                else {
                    Write-LWInfo 'Book 7 section 219: Curing protects you from the worst of the Hactaraton''s venom.'
                }
                $Scenario.VictoryResolutionSection = 21
                $Scenario.VictoryResolutionNote = 'Section 219 result: victory sends you to 21.'
                Write-LWInfo 'Book 7 section 219: you fight at -4 Combat Skill in rounds 1-2 and recover your weapon at the start of round 3.'
                return
            }
            221 {
                $Scenario.BowRestricted = $true
                $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 7 section 221'
                $Scenario.CanEvade = $true
                if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Invisibility') {
                    $Scenario.EvadeAvailableAfterRound = 0
                    $Scenario.EvadeResolutionSection = 70
                    $Scenario.EvadeResolutionNote = 'Section 221 result: Invisibility lets you evade immediately and reach 70.'
                    Write-LWInfo 'Book 7 section 221: Invisibility lets you evade at any time without ENDURANCE loss.'
                }
                else {
                    $Scenario.EvadeAvailableAfterRound = 2
                    $Scenario.EvadeResolutionSection = 229
                    $Scenario.EvadeResolutionNote = 'Section 221 result: after 2 rounds you may evade into the tunnel and turn to 229.'
                }
                $Scenario.VictoryResolutionSection = 271
                $Scenario.VictoryResolutionNote = 'Section 221 result: victory sends you to 271.'
                return
            }
            233 {
                $Scenario.VictoryResolutionSection = 209
                $Scenario.VictoryResolutionNote = 'Section 233 result: victory sends you to 209.'
                Write-LWInfo 'Book 7 section 233: Oudagorg is especially susceptible to Mindblast and Psi-surge.'
                return
            }
            235 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                $Scenario.VictoryResolutionSection = 22
                $Scenario.VictoryResolutionNote = 'Section 235 result: victory sends you to 22.'
                Write-LWInfo 'Book 7 section 235: Rahkos is immune to Mindblast, but not Psi-surge.'
                return
            }
            245 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
                    $Scenario.EnemyImmune = $true
                }
                $Scenario.VictoryResolutionSection = 259
                $Scenario.VictoryResolutionNote = 'Section 245 result: victory sends you to 259.'
                Write-LWInfo 'Book 7 section 245: the Hound of Death is immune to Mindblast, but not Psi-surge.'
                return
            }
            249 {
                $Scenario.CanEvade = $true
                $Scenario.EvadeAvailableAfterRound = 3
                $Scenario.EvadeResolutionSection = 241
                $Scenario.EvadeResolutionNote = 'Section 249 result: after 3 rounds you may evade into the archway and turn to 241.'
                $Scenario.VictoryResolutionSection = 141
                $Scenario.VictoryResolutionNote = 'Section 249 result: victory sends you to 141.'
                return
            }
            253 {
                $Scenario.BowRestricted = $true
                $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 7 section 253'
                $Scenario.CanEvade = $true
                $Scenario.EvadeResolutionSection = 277
                $Scenario.EvadeResolutionNote = 'Section 253 result: you may evade at any time into the archway and turn to 277.'
                $Scenario.VictoryResolutionSection = 141
                $Scenario.VictoryResolutionNote = 'Section 253 result: victory sends you to 141.'
                Write-LWInfo 'Book 7 section 253: the opening Bow shot is over and you must finish the fight with another weapon.'
                return
            }
            257 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery')) {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
                }
                if ((Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBlanketItemNames) -Type 'backpack') -or
                    (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBookSevenRedRobeItemNames) -Type 'backpack') -or
                    (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWTowelItemNames) -Type 'backpack')) {
                    $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 1
                    Write-LWInfo 'Book 7 section 257: improvised protection grants +1 Combat Skill.'
                }
                $Scenario.CanEvade = $true
                $Scenario.EvadeAvailableAfterRound = 3
                $Scenario.EvadeResolutionSection = 64
                $Scenario.EvadeResolutionNote = 'Section 257 result: after 3 rounds you may evade back along the passage to 64.'
                $Scenario.VictoryResolutionSection = 186
                $Scenario.VictoryResolutionNote = 'Section 257 result: victory sends you to 186.'
                return
            }
            299 {
                $Scenario.CanEvade = $false
                $Scenario.VictoryResolutionSection = 339
                $Scenario.VictoryResolutionNote = 'Section 299 result: victory sends you to 339.'
                Write-LWInfo 'Book 7 section 299: with the trap at your back, this fight cannot be evaded.'
                return
            }
            301 {
                if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing')) {
                    $Scenario.PlayerEnduranceLossMultiplier = 2
                    Write-LWInfo 'Book 7 section 301: without Curing, the Hactaraton''s venom doubles Lone Wolf ENDURANCE loss.'
                }
                else {
                    Write-LWInfo 'Book 7 section 301: Curing protects you from the worst of the Hactaraton''s venom.'
                }
                $Scenario.CanEvade = $true
                $Scenario.EvadeAvailableAfterRound = 4
                $Scenario.EvadeResolutionSection = 91
                $Scenario.EvadeResolutionNote = 'Section 301 result: after 4 rounds you may crawl into the tunnel and turn to 91.'
                $Scenario.VictoryResolutionSection = 21
                $Scenario.VictoryResolutionNote = 'Section 301 result: victory sends you to 21.'
                return
            }
            314 {
                $Scenario.BowRestricted = $true
                $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 7 section 314'
                $Scenario.CanEvade = $true
                $Scenario.EvadeResolutionSection = 277
                $Scenario.EvadeResolutionNote = 'Section 314 result: you may evade at any time into the archway and turn to 277.'
                $Scenario.VictoryResolutionSection = 141
                $Scenario.VictoryResolutionNote = 'Section 314 result: victory sends you to 141.'
                Write-LWInfo 'Book 7 section 314: the opening Bow shot is over and you must finish the fight with another weapon.'
                return
            }
            319 {
                $Scenario.CanEvade = $false
                $Scenario.VictoryResolutionSection = 56
                $Scenario.VictoryResolutionNote = 'Section 319 result: victory sends you to 56.'
                Write-LWInfo 'Book 7 section 319: the surviving beastmen fight together as one enemy and cannot be evaded.'
                return
            }
            325 {
                $Scenario.SpecialPlayerEnduranceLossAmount = 2
                $Scenario.SpecialPlayerEnduranceLossStartRound = 1
                $Scenario.SpecialPlayerEnduranceLossReason = 'Lack of air'
                $Scenario.VictoryResolutionSection = 158
                $Scenario.VictoryResolutionNote = 'Section 325 result: victory sends you to 158.'
                Write-LWInfo 'Book 7 section 325: lack of air inflicts 2 ENDURANCE loss every round of combat.'
                return
            }
        }
    }

    if ([int]$script:GameState.CurrentSection -eq 12) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 305
        $Scenario.EvadeResolutionNote = 'Section 12 result: evading sends you back through the chapel arch to 305.'
        $Scenario.IgnorePlayerEnduranceLossRounds = 2
        $Scenario.VictoryResolutionSection = 112
        $Scenario.VictoryResolutionNote = 'Section 12 result: victory sends you to 112.'
        Write-LWInfo 'Book 6 section 12: ignore Lone Wolf ENDURANCE loss in the first two rounds, and you may evade at any time.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 37) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 279
        $Scenario.EvadeResolutionNote = 'Section 37 result: evading means fleeing the shop, mounting your horse, and galloping to 279.'
        $Scenario.VictoryResolutionSection = 8
        $Scenario.VictoryResolutionNote = 'Section 37 result: victory sends you to 8.'
        Write-LWInfo 'Book 6 section 37: you may evade at any time by fleeing the taxidermist''s shop.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 47) {
        $Scenario.BowRestricted = $true
        $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 6 section 47'
        $Scenario.VictoryResolutionSection = 263
        $Scenario.VictoryResolutionNote = 'Section 47 result: victory sends you to 263.'
        Write-LWInfo 'Book 6 section 47: the bodyguards attack too fast for Bow use.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 78) {
        $Scenario.EnemyEnduranceThreshold = 11
        $Scenario.EnemyEnduranceThresholdSection = 180
        $Scenario.EnemyEnduranceThresholdNote = 'Section 78 result: once Roark falls to 11 ENDURANCE or less, stop combat and turn to 180.'
        Write-LWInfo 'Book 6 section 78: reduce Roark to 11 ENDURANCE or less to end the duel.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 92) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 286
        $Scenario.EvadeResolutionNote = 'Section 92 result: evading sends you to 286.'
        $Scenario.VictoryWithinRoundsSection = 77
        $Scenario.VictoryWithinRoundsMax = 3
        $Scenario.VictoryWithinRoundsNote = 'Section 92 result: if you win in 3 rounds or less, turn to 77.'
        $Scenario.VictoryResolutionSection = 215
        $Scenario.VictoryResolutionNote = 'Section 92 result: if the fight lasts longer than 3 rounds, victory sends you to 215.'
        Write-LWInfo 'Book 6 section 92: you may evade at any time, and the route changes if the fight lasts longer than 3 rounds.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 114) {
        $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
        $Scenario.PlayerModRounds = 1
        $Scenario.VictoryResolutionSection = 88
        $Scenario.VictoryResolutionNote = 'Section 114 result: victory sends you to 88.'
        Write-LWInfo 'Book 6 section 114: surprise grants +2 Combat Skill in round 1.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 116) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeExpiresAfterRound = 1
        $Scenario.EvadeResolutionSection = 105
        $Scenario.EvadeResolutionNote = 'Section 116 result: if you evade in round 1, run downstairs to 105.'
        $Scenario.VictoryResolutionSection = 193
        $Scenario.VictoryResolutionNote = 'Section 116 result: victory sends you to 193.'
        Write-LWInfo 'Book 6 section 116: evade is only available in the first round.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 155) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 4
        $Scenario.EvadeResolutionSection = 305
        $Scenario.EvadeResolutionNote = 'Section 155 result: after surviving 4 rounds, you may escape through the chapel arch to 305.'
        $Scenario.VictoryResolutionSection = 112
        $Scenario.VictoryResolutionNote = 'Section 155 result: victory sends you to 112.'
        if (-not [string]::IsNullOrWhiteSpace([string]$Scenario.EquippedWeapon)) {
            $Scenario.DeferredEquippedWeapon = [string]$Scenario.EquippedWeapon
            $Scenario.EquipDeferredWeaponAfterRound = 1
            $Scenario.EquippedWeapon = $null
        }
        Write-LWInfo 'Book 6 section 155: you fight bare-handed in round 1, then may draw a weapon from round 2 onward.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 156) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 339
        $Scenario.EvadeResolutionNote = 'Section 156 result: if you stop forcing the sewer door, turn to 339.'
        $Scenario.VictoryResolutionSection = 200
        $Scenario.VictoryResolutionNote = 'Section 156 result: if the door''s RESISTANCE reaches 0, turn to 200.'
        Write-LWInfo 'Book 6 section 156: this is treated as normal combat against the sewer door, but you may stop at any time.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 164) {
        $Scenario.BowRestricted = $true
        $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 6 section 164'
        if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 1
            Write-LWInfo 'Book 6 section 164: Animal Control grants +1 Combat Skill for this fight.'
        }
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 28
        $Scenario.VictoryResolutionNote = 'Section 164 result: victory sends you to 28.'
        Write-LWInfo 'Book 6 section 164: this fight cannot be evaded and Bows are unusable.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 201) {
        $Scenario.BowRestricted = $true
        $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 6 section 201'
        $Scenario.VictoryWithinRoundsSection = 15
        $Scenario.VictoryWithinRoundsMax = 3
        $Scenario.VictoryWithinRoundsNote = 'Section 201 result: if you win in 3 rounds or less, turn to 15.'
        $Scenario.VictoryResolutionSection = 87
        $Scenario.VictoryResolutionNote = 'Section 201 result: if the fight lasts longer than 3 rounds, victory sends you to 87.'
        Write-LWInfo 'Book 6 section 201: you may fight with any weapon except a Bow.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 208) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 279
        $Scenario.EvadeResolutionNote = 'Section 208 result: evading means fleeing the shop, mounting your horse, and galloping to 279.'
        $Scenario.VictoryResolutionSection = 8
        $Scenario.VictoryResolutionNote = 'Section 208 result: victory sends you to 8.'
        Write-LWInfo 'Book 6 section 208: your warning came in time, so only the duel remains.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 26 -and [string]$enemyName -ieq 'Altan') {
        $Scenario.CanEvade = $false
        $Scenario.SuppressShieldCombatSkillBonus = $true
        $Scenario.UsePlayerTargetEndurance = $true
        $Scenario.PlayerTargetEnduranceCurrent = 50
        $Scenario.PlayerTargetEnduranceMax = 50
        $selectedBowWeapon = [string](Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$Scenario.EquippedWeapon))
        if (-not [string]::IsNullOrWhiteSpace($selectedBowWeapon)) {
            $Scenario.EquippedWeapon = $selectedBowWeapon
        }
        else {
            $fallbackBowWeapon = [string](@($script:GameState.Inventory.Weapons | Where-Object {
                        -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @((Get-LWBowWeaponNames), (Get-LWJakanBowWeaponNames)) -Target ([string]$_)))
                    } | Select-Object -First 1))
            if (-not [string]::IsNullOrWhiteSpace($fallbackBowWeapon)) {
                $Scenario.EquippedWeapon = $fallbackBowWeapon
            }
            else {
                $Scenario.EquippedWeapon = 'Bow'
            }
        }
        $Scenario.AttemptKnockout = $false
        $Scenario.VictoryResolutionSection = 252
        $Scenario.VictoryResolutionNote = 'Section 26 result: if Altan loses all 50 TARGET points, turn to 252.'
        $Scenario.DefeatResolutionSection = 183
        $Scenario.DefeatResolutionNote = 'Section 26 result: if you lose all 50 TARGET points, turn to 183.'
        if ([bool](Get-LWMagnakaiBookSixConditionValue -Name 'BookSixSection214KalteBowPenalty' -Default $false)) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 4
            Write-LWWarn 'Book 6 section 26: the Kalte hunting bow applies -4 Combat Skill for the duration of the tournament.'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWJakanBowWeaponNames) -Target ([string]$Scenario.EquippedWeapon)))) {
            $Scenario.FallOnRollValue = 0
            $Scenario.FallOnRollResolutionSection = 335
            $Scenario.FallOnRollResolutionNote = 'Section 26 result: while using the Jakan, a roll of 0 sends you immediately to 335.'
            Write-LWInfo 'Book 6 section 26: while using the Jakan, a roll of 0 sends you immediately to section 335.'
        }
        Write-LWInfo 'Book 6 section 26: the final is fought with Bow shots only, Shield bonuses are suppressed, and both archers use 50 TARGET points instead of normal ENDURANCE.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 71 -and [string]$enemyName -ieq 'Redbeard') {
        if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
            Write-LWInfo 'Book 6 section 71: Animal Control grants +2 Combat Skill while you fight from the saddle.'
        }
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 279
        $Scenario.EvadeResolutionNote = 'Section 71 result: you may evade at any time by galloping along the street to 279.'
        $Scenario.VictoryResolutionSection = 237
        $Scenario.VictoryResolutionNote = 'Section 71 result: victory sends you to 237.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 77 -and [string]$enemyName -ieq 'Pirate Berserkers') {
        if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-surge')) {
            $Scenario.EnemyImmune = $true
        }
        $Scenario.VictoryResolutionSection = 297
        $Scenario.VictoryResolutionNote = 'Section 77 result: victory sends you to 297.'
        Write-LWInfo 'Book 6 section 77: pirate berserkers are immune to Mindblast, but not Psi-surge.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 138 -and [string]$enemyName -ieq 'Varetta City Watch') {
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 34
        $Scenario.VictoryResolutionNote = 'Section 138 result: victory sends you to 34.'
        Write-LWInfo 'Book 6 section 138: this fight cannot be evaded.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 159 -and [string]$enemyName -ieq 'Varettian Mercenaries') {
        $Scenario.CanEvade = $false
        $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 6 section 159'
        $Scenario.VictoryResolutionSection = 48
        $Scenario.VictoryResolutionNote = 'Section 159 result: victory sends you to 48.'
        Write-LWInfo 'Book 6 section 159: this fight cannot be evaded and Bows are unusable.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 194 -and [string]$enemyName -ieq 'Acolytes of Vashna') {
        if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 2
            Write-LWInfo 'Book 6 section 194: Animal Control grants +2 Combat Skill while you command your horse to attack.'
        }
        $Scenario.CanEvade = $true
        $Scenario.EvadeResolutionSection = 289
        $Scenario.EvadeResolutionNote = 'Section 194 result: you may evade at any time by turning to 289.'
        $Scenario.VictoryResolutionSection = 145
        $Scenario.VictoryResolutionNote = 'Section 194 result: victory sends you to 145.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 215) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 2
        $Scenario.EvadeResolutionSection = 286
        $Scenario.EvadeResolutionNote = 'Section 215 result: after 2 rounds you may evade to 286.'
        $Scenario.VictoryResolutionSection = 111
        $Scenario.VictoryResolutionNote = 'Section 215 result: victory sends you to 111.'
        Write-LWInfo 'Book 6 section 215: evade is only available after round 2.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 254) {
        if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            $Scenario.PlayerModRounds = 1
            Write-LWInfo 'Book 6 section 254: the rear attack applies -2 Combat Skill in round 1 unless you possess Huntmastery.'
        }
        $Scenario.VictoryResolutionSection = 77
        $Scenario.VictoryResolutionNote = 'Section 254 result: victory sends you to 77.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 270 -and [string]$enemyName -ieq 'Undead Summonation') {
        $Scenario.EnemyUndead = $true
        $Scenario.EnemyImmune = $true
        if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod - 2
            $Scenario.PlayerModRounds = 2
        }
        if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
            $Scenario.SpecialPlayerEnduranceLossAmount = 2
            $Scenario.SpecialPlayerEnduranceLossStartRound = 1
            $Scenario.SpecialPlayerEnduranceLossReason = 'Bitter cold'
        }
        if (Test-LWWeaponIsSommerswerd -Weapon ([string]$Scenario.EquippedWeapon)) {
            $Scenario.DoubleEnemyEnduranceLoss = $true
        }
        $Scenario.VictoryResolutionSection = 326
        $Scenario.VictoryResolutionNote = 'Section 270 result: victory sends you to 326.'
        Write-LWInfo 'Book 6 section 270: the undead are immune to Psi-surge and Mindblast, and the Sommerswerd doubles the ENDURANCE you inflict here.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 282 -and [string]$enemyName -ieq 'Backstabbers') {
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 88
        $Scenario.VictoryResolutionNote = 'Section 282 result: victory sends you to 88.'
        Write-LWInfo 'Book 6 section 282: this fight cannot be evaded.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 234 -and [string]$enemyName -match '^(?i)(Plate-)?Armou?red Assassin$') {
        $Scenario.BowRestricted = $true
        $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 6 DE section 234'
        if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing') -and (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control')) {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 3
            Write-LWInfo 'Book 6 DE section 234: Lore-circle of Light grants +3 Combat Skill for this fight.'
        }
        $Scenario.CombatPotionsAllowed = $false
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 28
        $Scenario.VictoryResolutionNote = 'Section 234 result: victory sends you to 28.'
        Write-LWWarn 'Book 6 DE section 234: no potion may be used before or during this combat.'
        Write-LWInfo 'Book 6 DE section 234: this fight cannot be evaded and Bows are unusable.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 283 -and [string]$enemyName -ieq 'Armoured Assassin') {
        $Scenario.BowRestricted = $true
        $Scenario.EquippedWeapon = Resolve-LWCoreRestrictedBowWeapon -State $script:GameState -EquippedWeapon ([string]$Scenario.EquippedWeapon) -SectionLabel 'Book 6 section 283'
        if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') {
            $Scenario.PlayerMod = [int]$Scenario.PlayerMod + 1
            Write-LWInfo 'Book 6 section 283: Animal Control grants +1 Combat Skill for this fight.'
        }
        $Scenario.CanEvade = $false
        $Scenario.VictoryResolutionSection = 28
        $Scenario.VictoryResolutionNote = 'Section 283 result: victory sends you to 28.'
        Write-LWInfo 'Book 6 section 283: this fight cannot be evaded and Bows are unusable.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 337) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeExpiresAfterRound = 1
        $Scenario.EvadeResolutionSection = 191
        $Scenario.EvadeResolutionNote = 'Section 337 result: if you evade in round 1, gallop west to 191.'
        $Scenario.VictoryResolutionSection = 40
        $Scenario.VictoryResolutionNote = 'Section 337 result: victory sends you to 40.'
        Write-LWInfo 'Book 6 section 337: evade is only available in the first round.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 343) {
        $Scenario.CanEvade = $true
        $Scenario.EvadeAvailableAfterRound = 3
        $Scenario.EvadeResolutionSection = 305
        $Scenario.EvadeResolutionNote = 'Section 343 result: after surviving 3 rounds, you may escape through the chapel arch to 305.'
        $Scenario.VictoryResolutionSection = 112
        $Scenario.VictoryResolutionNote = 'Section 343 result: victory sends you to 112.'
        Write-LWInfo 'Book 6 section 343: evade is only available after surviving 3 rounds.'
    }
    elseif ([int]$script:GameState.CurrentSection -eq 344 -and [string]$enemyName -ieq 'Dakomyd') {
        $Scenario.EnemyImmune = $true
        $Scenario.EnemyEnduranceThreshold = 25
        $Scenario.EnemyEnduranceThresholdSection = 310
        $Scenario.EnemyEnduranceThresholdNote = 'Section 344 result: once Dakomyd is reduced to 25 ENDURANCE or less, stop combat and turn to 310.'
        Write-LWInfo 'Book 6 section 344: Dakomyd is immune to Psi-surge and Mindblast, and combat stops once it falls to 25 ENDURANCE or less.'
    }
}

function Invoke-LWMagnakaiCombatPsychicAttackRules {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][hashtable]$Scenario
    )

    if ([int]$State.Character.BookNumber -eq 7 -and
        [int]$State.CurrentSection -eq 233 -and
        (Test-LWPropertyExists -Object $Scenario -Name 'UseMindblast') -and
        [bool]$Scenario.UseMindblast) {
        $psychicAttackLabel = if ((Test-LWPropertyExists -Object $Scenario -Name 'PsychicAttackMode') -and -not [string]::IsNullOrWhiteSpace([string]$Scenario.PsychicAttackMode)) { [string]$Scenario.PsychicAttackMode } else { 'psychic attack' }
        $suppressMessages = ((Test-LWPropertyExists -Object $Scenario -Name 'SuppressMessages') -and [bool]$Scenario.SuppressMessages)
        $Scenario.DoubleEnemyEnduranceLoss = $true
        if (-not $suppressMessages) {
            Write-LWInfo ("Book 7 section 233: {0} doubles all ENDURANCE loss sustained by Oudagorg." -f $psychicAttackLabel)
        }
    }
}

Export-ModuleMember -Function `
    Get-LWMagnakaiCombatEncounterProfile, `
    Invoke-LWMagnakaiCombatScenarioRules, `
    Invoke-LWMagnakaiCombatPsychicAttackRules


