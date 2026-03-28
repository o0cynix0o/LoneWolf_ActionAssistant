Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWKaiRulesetVersion {
    return '1.0.0'
}

function Get-LWKaiSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -eq $State -or $null -eq $State.Character) {
        return $null
    }

    switch ([int]$State.Character.BookNumber) {
        1 { return (Get-LWKaiBookOneSectionRandomNumberContext -State $State) }
        2 { return (Get-LWKaiBookTwoSectionRandomNumberContext -State $State) }
        3 { return (Get-LWKaiBookThreeSectionRandomNumberContext -State $State) }
        4 { return (Get-LWKaiBookFourSectionRandomNumberContext -State $State) }
        5 { return (Get-LWKaiBookFiveSectionRandomNumberContext -State $State) }
        default { return $null }
    }
}

function Invoke-LWKaiStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [int]$BookNumber,
        [switch]$CarryExistingGear
    )

    switch ([int]$BookNumber) {
        1 { Apply-LWKaiBookOneStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
        2 { Apply-LWKaiBookTwoStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
        3 { Apply-LWKaiBookThreeStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
        4 { Apply-LWKaiBookFourStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
        5 { Apply-LWKaiBookFiveStartingEquipment -State $State -CarryExistingGear:$CarryExistingGear; return }
    }
}

function Invoke-LWKaiStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    $script:GameState = $State

        if (-not (Test-LWHasState)) {
            return
        }

        switch ([int]$script:GameState.Character.BookNumber) {
            1 {
                switch ($Section) {
                    7 { Set-LWStoryAchievementFlag -Name 'Book1AimForTheBushesVisited' }
                    13 { Set-LWStoryAchievementFlag -Name 'Book1ClubhouseFound' }
                    66 { Set-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone' }
                    212 { Set-LWStoryAchievementFlag -Name 'Book1RoyalRecovery' }
                    332 { Set-LWStoryAchievementFlag -Name 'Book1BackWayIn' }
                }
            }
            2 {
                switch ($Section) {
                    10 { Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed' }
                    40 { Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed' }
                    103 { Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed' }
                    105 { Set-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute' }
                    109 { Set-LWStoryAchievementFlag -Name 'Book2SkyfallRoute' }
                    126 {
                        if (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought') {
                            Set-LWStoryAchievementFlag -Name 'Book2PapersPleasePath'
                        }
                    }
                    142 { Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed' }
                    185 { Set-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute' }
                    196 { Set-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute' }
                    263 { Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed' }
                    337 { Set-LWStoryAchievementFlag -Name 'Book2StormTossedSeen' }
                }
            }
            3 {
                switch ($Section) {
                    19 { Set-LWStoryAchievementFlag -Name 'Book3CliffhangerSeen' }
                    34 { Set-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached' }
                    56 { Set-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued' }
                    58 { Set-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed' }
                    65 {
                        if (Test-LWStoryAchievementFlag -Name 'Book3LuckyButtonTheorySeen') {
                            Set-LWStoryAchievementFlag -Name 'Book3WellItWorkedOnceSeen'
                        }
                    }
                    102 { Set-LWStoryAchievementFlag -Name 'Book3LuckyButtonTheorySeen' }
                    213 { Set-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed' }
                    276 {
                        if (Test-LWStoryAchievementFlag -Name 'Book3FirstCellAbandoned') {
                            Set-LWStoryAchievementFlag -Name 'Book3CellfishPathTaken'
                        }
                    }
                    324 { Set-LWStoryAchievementFlag -Name 'Book3TooSlowFailureSeen' }
                    88 { Set-LWStoryAchievementFlag -Name 'Book3SnakePitVisited' }
                    251 { Set-LWStoryAchievementFlag -Name 'Book3SnowblindSeen' }
                }
            }
            4 {
                switch ($Section) {
                    22 {
                        Set-LWStoryAchievementFlag -Name 'Book4LightInTheDepths'
                        Set-LWStoryAchievementFlag -Name 'Book4Section117LightPath'
                    }
                    122 { Set-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute' }
                    279 { Set-LWStoryAchievementFlag -Name 'Book4ScrollRoute' }
                    283 {
                        Set-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute'
                    }
                    305 { Set-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute' }
                    325 { Set-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute' }
                    347 { Set-LWStoryAchievementFlag -Name 'Book4ChasmOfDoomSeen' }
                }
            }
            5 {
                switch ($Section) {
                    2 {
                        Set-LWStoryAchievementFlag -Name 'Book5OedeClaimed'
                        Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
                    }
                    14 { Set-LWStoryAchievementFlag -Name 'Book5PrisonBreak' }
                    307 { Set-LWStoryAchievementFlag -Name 'Book5SoushillaAsked' }
                    308 { Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed' }
                    319 { Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed' }
                    336 { Set-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute' }
                    353 { Set-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute' }
                    356 { Set-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard' }
                }
            }
        }
}

function Invoke-LWKaiStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    $script:GameState = $State

        if (-not (Test-LWHasState)) {
            return
        }

        if ([int]$script:GameState.Character.BookNumber -eq 1 -and $FromSection -eq 131 -and $ToSection -eq 302) {
            Set-LWStoryAchievementFlag -Name 'Book1UseTheForcePath'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 1 -and $FromSection -eq 23 -and $ToSection -eq 326) {
            Set-LWStoryAchievementFlag -Name 'Book1OpenSesameRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 1 -and $FromSection -eq 88 -and $ToSection -eq 216) {
            Set-LWStoryAchievementFlag -Name 'Book1FieldMedicPath'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 2 -and $FromSection -eq 62 -and $ToSection -eq 126 -and (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought')) {
            Set-LWStoryAchievementFlag -Name 'Book2PapersPleasePath'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 2 -and $FromSection -eq 299 -and $ToSection -eq 118) {
            $magicSpearName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMagicSpearItemNames) -Type 'special'
            if (-not [string]::IsNullOrWhiteSpace($magicSpearName)) {
                [void](Remove-LWInventoryItemSilently -Type 'special' -Name $magicSpearName -Quantity 1)
                Write-LWInfo 'Section 299: Rhygar keeps the Magic Spear.'
            }
        }
        if ([int]$script:GameState.Character.BookNumber -eq 2 -and $FromSection -eq 338 -and $ToSection -eq 349) {
            $magicSpearName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMagicSpearItemNames) -Type 'special'
            if (-not [string]::IsNullOrWhiteSpace($magicSpearName)) {
                [void](Remove-LWInventoryItemSilently -Type 'special' -Name $magicSpearName -Quantity 1)
                Write-LWInfo 'Section 338: you leave the Magic Spear behind.'
            }
        }
        if ([int]$script:GameState.Character.BookNumber -eq 3 -and $FromSection -eq 13 -and $ToSection -eq 254) {
            Set-LWStoryAchievementFlag -Name 'Book3FirstCellAbandoned'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 95 -and $ToSection -eq 195) {
            Set-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 117 -and $ToSection -eq 22) {
            Set-LWStoryAchievementFlag -Name 'Book4LightInTheDepths'
            Set-LWStoryAchievementFlag -Name 'Book4Section117LightPath'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 258 -and $ToSection -eq 305) {
            Set-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 296 -and $ToSection -eq 122) {
            Set-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 4 -and @(
                73,
                274
            ) -contains $FromSection -and $ToSection -eq 283) {
            Set-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 4 -and @(
                73,
                274
            ) -contains $FromSection -and $ToSection -eq 325) {
            Set-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 5 -and $FromSection -eq 221 -and $ToSection -eq 336) {
            Set-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 5 -and @(
                204,
                335
            ) -contains $FromSection -and $ToSection -eq 268) {
            Set-LWStoryAchievementFlag -Name 'Book5BanishmentRoute'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 5 -and $FromSection -eq 224 -and @(
                308,
                319
            ) -contains $ToSection) {
            Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed'
        }
        if ([int]$script:GameState.Character.BookNumber -eq 5 -and $FromSection -eq 397 -and $ToSection -eq 307) {
            Set-LWStoryAchievementFlag -Name 'Book5SoushillaAsked'
        }
}

function Invoke-LWKaiSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    $script:GameState = $State

    if (-not (Test-LWHasState)) {
            return
        }

        $bookNumber = [int]$script:GameState.Character.BookNumber
        $section = [int]$script:GameState.CurrentSection

        switch ($bookNumber) {
            1 {
                switch ($section) {
                    76 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1VordakGem76Claimed')) {
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss

                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }

                            $message = 'Section 76: the Vordak Gem burns your hand.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                            }
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message

                            if (Invoke-LWFatalEnduranceCheck -Cause 'The heat of the Vordak Gem reduced your Endurance to zero.') {
                                return
                            }

                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Vordak Gem') {
                                Write-LWInfo 'Vordak Gem added to backpack.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Vordak Gem automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    113 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1LaumspurClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Laumspur Herb' -Quantity 2) {
                                Set-LWStoryAchievementFlag -Name 'Book1LaumspurClaimed'
                                Write-LWInfo 'Section 113: added 2 x Laumspur Herb. Each use restores 3 ENDURANCE and can also satisfy a Meal.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Laumspur Herb automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    124 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 124 Box' -PromptLabel 'Section 124 choice' -ContextLabel 'Section 124' -Choices (Get-LWBookOneSection124ChoiceDefinitions) -Intro 'Section 124: take the Gold Crowns and keep the Silver Key if you want it.'
                    }
                    137 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section137GemsClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Tomb Guardian Gems') {
                                Set-LWStoryAchievementFlag -Name 'Book1Section137GemsClaimed'
                                Write-LWInfo 'Section 137: Tomb Guardian Gems added as a single Backpack Item.'
                            }
                            else {
                                Write-LWWarn 'No room to add Tomb Guardian Gems automatically. Make room and add them manually if you are keeping them.'
                            }
                        }
                    }
                    144 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section144Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book1Section144Resolved'
                            Invoke-LWBookFourForcedPackOrWeaponLoss -Reason 'Section 144: something is stolen in the crush.'
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book1Section144DamageApplied' -Delta -2 -MessagePrefix 'Section 144: the runaway cart leaves you badly stunned.' -FatalCause 'The impact at section 144 reduced your Endurance to zero.')
                        }
                    }
                    146 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book1Section146DamageApplied' -Delta -3 -MessagePrefix 'Section 146: the ambush arrow grazes your forehead.' -FatalCause 'The ambush at section 146 reduced your Endurance to zero.')
                    }
                    188 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section188Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book1Section188Resolved'
                            $roll = Get-LWRandomDigit
                            Write-LWCurrentSectionRandomNumberRoll -Roll $roll
                            if ($roll -le 6) {
                                Lose-LWBackpack -WriteMessages -Reason 'Section 188: the Kraan rips away your Backpack'
                            }
                            else {
                                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book1Section188DamageApplied' -Delta -3 -MessagePrefix 'Section 188: the Kraan''s attack leaves both your arms badly wounded.' -FatalCause 'The Kraan assault at section 188 reduced your Endurance to zero.')
                            }
                        }
                    }
                    205 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section205LossApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book1Section205LossApplied'
                            Save-LWInventoryRecoveryEntry -Type 'weapon' -Items @(Get-LWInventoryItems -Type 'weapon')
                            Save-LWInventoryRecoveryEntry -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')
                            Set-LWInventoryItems -Type 'weapon' -Items @()
                            Set-LWInventoryItems -Type 'backpack' -Items @()
                            Write-LWInfo 'Section 205: all Weapons and Backpack Items are taken from you.'
                        }
                    }
                    267 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 267 Saddlebag' -PromptLabel 'Section 267 choice' -ContextLabel 'Section 267' -Choices (Get-LWBookOneSection267ChoiceDefinitions) -Intro 'Section 267: keep the Message and Dagger if you want them.'
                    }
                    277 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section277BrokenWeapon')) {
                            Set-LWStoryAchievementFlag -Name 'Book1Section277BrokenWeapon'
                            Invoke-LWBookFourLoseOneWeapon -Reason 'Section 277: one Weapon is broken in the fall.'
                        }
                    }
                    236 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1VordakGemCurseTriggered')) {
                            $vordakGemName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWVordakGemItemNames) -Type 'backpack'
                            if (-not [string]::IsNullOrWhiteSpace($vordakGemName)) {
                                Set-LWStoryAchievementFlag -Name 'Book1VordakGemCurseTriggered'
                                [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $vordakGemName -Quantity 1)

                                $before = [int]$script:GameState.Character.EnduranceCurrent
                                $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 6 -Source 'sectiondamage'
                                $appliedLoss = [int]$lossResolution.AppliedLoss
                                if ($appliedLoss -gt 0) {
                                    $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                    Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                                }

                                $oldBaseCs = [int]$script:GameState.Character.CombatSkillBase
                                $script:GameState.Character.CombatSkillBase = [Math]::Max(0, ([int]$script:GameState.Character.CombatSkillBase - 1))

                                $message = 'Section 236: the Vordak Gem curses you.'
                                if ($appliedLoss -gt 0) {
                                    $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                                }
                                if ($script:GameState.Character.CombatSkillBase -lt $oldBaseCs) {
                                    $message += ' Base Combat Skill is permanently reduced by 1.'
                                }
                                $message += ' One Vordak Gem is erased.'
                                if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                    $message += " $($lossResolution.Note)"
                                }
                                Write-LWInfo $message

                                [void](Invoke-LWFatalEnduranceCheck -Cause 'The curse of the Vordak Gem reduced your Endurance to zero.')
                            }
                        }
                    }
                    338 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section338RecoveryShown')) {
                            Set-LWStoryAchievementFlag -Name 'Book1Section338RecoveryShown'
                            $recoverWeapons = @((Get-LWInventoryRecoveryItems -Type 'weapon')).Count -gt 0
                            $recoverBackpack = @((Get-LWInventoryRecoveryItems -Type 'backpack')).Count -gt 0
                            if ($recoverWeapons -or $recoverBackpack) {
                                if ($recoverWeapons) {
                                    Restore-LWInventorySection -Type 'weapon'
                                }
                                if ($recoverBackpack) {
                                    Restore-LWInventorySection -Type 'backpack'
                                }
                                Write-LWInfo 'Section 338: recovered dropped Weapons and Backpack gear from the slope.'
                            }
                            else {
                                Write-LWInfo 'Section 338: recover any dropped Weapons and Backpack items if this route made you lose them earlier.'
                            }
                        }
                    }
                    347 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 347 Cabin' -PromptLabel 'Section 347 choice' -ContextLabel 'Section 347' -Choices (Get-LWBookOneSection347ChoiceDefinitions) -Intro 'Section 347: take the Torch, Short Sword, and Tinderbox if you want them.'
                    }
                    349 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section349PendantClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Crystal Star Pendant') {
                                Set-LWStoryAchievementFlag -Name 'Book1Section349PendantClaimed'
                                Set-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed'
                                Write-LWInfo 'Section 349: Crystal Star Pendant added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Crystal Star Pendant automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    304 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book1VordakGem304Claimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Vordak Gem') {
                                Write-LWInfo 'Section 304: Vordak Gem added to backpack.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Vordak Gem automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    315 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 315 Purse' -PromptLabel 'Section 315 choice' -ContextLabel 'Section 315' -Choices (Get-LWBookOneSection315ChoiceDefinitions) -Intro 'Section 315: take the purse contents if you want them before moving on.'
                    }
                }
            }
            2 {
                switch ($section) {
                    10 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Coach Ticket') {
                                Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed'
                                Write-LWInfo 'Section 10: Coach Ticket added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Coach Ticket automatically. Make room and add it manually if needed.'
                            }
                        }
                    }
                    31 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section31Restored')) {
                            Set-LWStoryAchievementFlag -Name 'Book2Section31Restored'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + 6))
                            $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
                            if ($restored -gt 0) {
                                Add-LWBookEnduranceDelta -Delta $restored
                                Register-LWManualRecoveryShortcut
                            }
                            if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
                                Restore-LWBackpackState -WriteMessages
                                Write-LWInfo 'Section 31: if you had lost your Backpack, Rhygar outfits you with one here.'
                            }
                            Write-LWInfo ("Section 31: the physician restores {0} ENDURANCE." -f $restored)
                        }
                    }
                    40 {
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $script:GameState.Character.EnduranceCurrent = [int]$script:GameState.Character.EnduranceMax
                        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
                        if ($restored -gt 0) {
                            Add-LWBookEnduranceDelta -Delta $restored
                            Write-LWInfo ('Section 40: Madin Rendalim restores all ENDURANCE lost so far.')
                        }

                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Potent Laumspur Potion') {
                                Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed'
                                Write-LWInfo 'Section 40: added Potent Laumspur Potion (+5 ENDURANCE after combat).'
                            }
                            else {
                                Write-LWWarn 'No room to add the Potent Laumspur Potion automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    103 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal of Laumspur') {
                                Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed'
                                Write-LWInfo 'Section 103: added Meal of Laumspur. It can satisfy a Meal and restore 3 ENDURANCE, or be used any time for 3 ENDURANCE.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Meal of Laumspur automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    106 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section106DamageApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book2Section106DamageApplied'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }

                            $message = 'Section 106: the Magic Spear burns your mind as you pull it free.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                            }
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            $message += ' The Helghast fight here is immune to Mindblast, uses Mindforce every round, and can only be harmed by the Magic Spear.'
                            Write-LWInfo $message

                            [void](Invoke-LWFatalEnduranceCheck -Cause 'The shock of the Magic Spear reduced your Endurance to zero.')
                        }
                    }
                    142 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'White Pass') {
                                Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed'
                                Write-LWInfo 'Section 142: White Pass added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the White Pass automatically. Make room and add it manually if needed.'
                            }
                        }
                    }
                    196 {
                        Set-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute'
                        $sealName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSealOfHammerdalItemNames) -Type 'special'
                        if (-not [string]::IsNullOrWhiteSpace($sealName)) {
                            [void](Remove-LWInventoryItemSilently -Type 'special' -Name $sealName -Quantity 1)
                            Write-LWInfo 'Section 196: the Seal of Hammerdal is removed from your Special Items.'
                        }
                    }
                    69 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section69MindforceApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book2Section69MindforceApplied'
                            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindshield')) {
                                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book2Section69DamageApplied' -Delta -2 -MessagePrefix 'Section 69: the Helghast''s Mindforce tears at your thoughts.' -FatalCause 'The Helghast Mindforce at section 69 reduced your Endurance to zero.')
                            }
                            else {
                                Write-LWInfo 'Section 69: Mindshield blocks the Helghast''s Mindforce attack.'
                            }
                        }
                    }
                    263 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2RedPassClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Red Pass') {
                                Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed'
                                Write-LWInfo 'Section 263: Red Pass added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Red Pass automatically. Make room and add it manually if needed.'
                            }
                        }
                    }
                    289 {
                        if ([string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSealOfHammerdalItemNames) -Type 'special'))) {
                            Write-LWWarn 'Section 289 continuity note: if you no longer possess the Seal of Hammerdal, you should leave immediately for section 186.'
                        }
                    }
                    313 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section313Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book2Section313Resolved'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 4 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }
                            $magicSpearName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMagicSpearItemNames) -Type 'special'
                            if (-not [string]::IsNullOrWhiteSpace($magicSpearName)) {
                                [void](Remove-LWInventoryItemSilently -Type 'special' -Name $magicSpearName -Quantity 1)
                            }

                            $message = 'Section 313: the Helghast''s burnt claws tear into your neck.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                            }
                            $message += ' The Magic Spear is erased.'
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message

                            [void](Invoke-LWFatalEnduranceCheck -Cause 'The Helghast''s burnt claws reduced your Endurance to zero.')
                        }
                    }
                    327 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought')) {
                            $buyPapers = Read-LWYesNo -Prompt 'Buy the forged access papers here?' -Default $false
                            if ($buyPapers) {
                                $currentGold = [int]$script:GameState.Inventory.GoldCrowns
                                $pricePaid = [Math]::Min(6, $currentGold)
                                if ($pricePaid -gt 0) {
                                    $script:GameState.Inventory.GoldCrowns = [int]($currentGold - $pricePaid)
                                    Add-LWBookGoldDelta -Delta (-$pricePaid)
                                }
                                Set-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought'
                                Write-LWInfo ("Section 327: forged access papers acquired for the Red Pass route. Gold paid: {0}." -f $pricePaid)
                            }
                        }
                    }
                    337 {
                        Set-LWStoryAchievementFlag -Name 'Book2StormTossedSeen'
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section337StormLossApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book2Section337StormLossApplied'
                            $lostWeapons = @(Get-LWInventoryItems -Type 'weapon')
                            $lostBackpack = @(Get-LWInventoryItems -Type 'backpack')
                            if ($lostWeapons.Count -gt 0) {
                                Save-LWInventoryRecoveryEntry -Type 'weapon' -Items @($lostWeapons)
                                Set-LWInventoryItems -Type 'weapon' -Items @()
                            }
                            if ($lostBackpack.Count -gt 0) {
                                Save-LWInventoryRecoveryEntry -Type 'backpack' -Items @($lostBackpack)
                                Set-LWInventoryItems -Type 'backpack' -Items @()
                            }
                            Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
                            Write-LWInfo 'Section 337: the storm strips away all Weapons and Backpack Items. Gold, your Backpack, and surviving Special Items are kept.'
                        }
                    }
                    145 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book2Section145PoisonApplied' -Delta -5 -MessagePrefix 'Section 145: the tainted Laumspur purges the poison but leaves you violently ill.' -FatalCause 'The poisoned Laumspur at section 145 reduced your Endurance to zero.')
                    }
                    194 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section194TheftApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book2Section194TheftApplied'
                            $script:GameState.Inventory.GoldCrowns = 0
                            Set-LWInventoryItems -Type 'weapon' -Items @()
                            Set-LWInventoryItems -Type 'backpack' -Items @()
                            Set-LWInventoryItems -Type 'special' -Items @()
                            Set-LWBackpackState -HasBackpack:$false
                            Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
                            Write-LWInfo 'Section 194: your Gold, Backpack, Weapons, and Special Items are stolen.'
                        }
                    }
                    262 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 262 Storeroom' -PromptLabel 'Section 262 choice' -ContextLabel 'Section 262' -Choices (Get-LWBookTwoSection262ChoiceDefinitions) -Intro 'Section 262: take whatever you want from the storeroom before you flee.'
                    }
                    302 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 302 Watchtower' -PromptLabel 'Section 302 choice' -ContextLabel 'Section 302' -Choices (Get-LWBookTwoSection302ChoiceDefinitions) -Intro 'Section 302: take whatever you want from the watchtower quarters before you leave.'
                    }
                }
            }
            3 {
                switch ($section) {
                    4 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 4 Search' -PromptLabel 'Section 4 choice' -ContextLabel 'Section 4' -Choices (Get-LWBookThreeSection004ChoiceDefinitions) -Intro 'Section 4: search the body and keep whatever you want.'
                    }
                    8 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied'
                            Write-LWInfo 'Section 8: Baknar oil applied. It lasts for the rest of Book 3 and protects you against some cold-based losses.'
                        }
                    }
                    91 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied'
                            Write-LWInfo 'Section 91: Baknar oil applied. It lasts for the rest of Book 3 and protects you against some cold-based losses.'
                        }
                    }
                    10 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section10BackpackHandled')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section10BackpackHandled'
                            Write-LWInfo 'Section 10: each liquid may only be examined once.'
                            if (-not (Test-LWStateHasBackpack -State $script:GameState) -and (Read-LWYesNo -Prompt 'Use the abandoned pack as your Backpack here?' -Default $true)) {
                                Restore-LWBackpackState -WriteMessages
                            }
                        }
                    }
                    12 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 12 Expedition Gear' -PromptLabel 'Section 12 choice' -ContextLabel 'Section 12' -Choices (Get-LWBookThreeSection012ChoiceDefinitions) -Intro 'Section 12: pack your share of the expedition gear now.'
                    }
                    18 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section18LossApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section18LossApplied'
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section18DamageApplied' -Delta -3 -MessagePrefix 'Section 18: the Ice Demon''s freezing blast rakes your arm.' -FatalCause 'The freezing blast at section 18 reduced your Endurance to zero.')
                            Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem -Reason 'Section 18: the freezing cyclone tears your weapon away.'
                        }
                    }
                    38 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 38 Supplies' -PromptLabel 'Section 38 choice' -ContextLabel 'Section 38' -Choices (Get-LWBookThreeSection038ChoiceDefinitions) -Intro 'Section 38: search the junk-filled room for anything useful.'
                    }
                    49 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section49BackpackLost')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section49BackpackLost'
                            Lose-LWBackpack -WriteMessages -Reason 'Section 49: your Backpack remains behind in the tent after the fall'
                        }
                    }
                    55 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section55Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section55Resolved'
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section55DamageApplied' -Delta -5 -MessagePrefix 'Section 55: the return climb leaves you badly frostbitten.' -FatalCause 'The frostbite at section 55 reduced your Endurance to zero.')
                            $oldBaseCs = [int]$script:GameState.Character.CombatSkillBase
                            $script:GameState.Character.CombatSkillBase = [Math]::Max(0, ($oldBaseCs - 2))
                            if ($script:GameState.Character.CombatSkillBase -lt $oldBaseCs) {
                                Write-LWWarn 'Section 55: base Combat Skill is permanently reduced by 2.'
                            }
                        }
                    }
                    79 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section79Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section79Resolved'
                            $graveweedName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWGraveweedItemNames) -Type 'backpack'
                            if (-not [string]::IsNullOrWhiteSpace($graveweedName)) {
                                [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $graveweedName -Quantity 1)
                                Write-LWInfo 'Section 79: Vial of Graveweed erased after poisoning the gruel.'
                            }
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section79RecoveryApplied' -Delta 6 -MessagePrefix 'Section 79: the herbs Loi-Kymar mixes restore your strength.')
                        }
                    }
                    84 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 84 Trophy' -PromptLabel 'Section 84 choice' -ContextLabel 'Section 84' -Choices (Get-LWBookThreeSection084ChoiceDefinitions) -Intro 'Section 84: keep the Blue Stone Triangle if you want it.'
                    }
                    102 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 102 Effigy' -PromptLabel 'Section 102 choice' -ContextLabel 'Section 102' -Choices (Get-LWBookThreeSection102ChoiceDefinitions) -Intro 'Section 102: keep the Stone Effigy if you want it before leaving the temple.'
                    }
                    129 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section129Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section129Resolved'
                            if (-not (Test-LWStateHasBaknarOilApplied -State $script:GameState)) {
                                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section129DamageApplied' -Delta -3 -MessagePrefix 'Section 129: without Baknar oil, the winds of Kalte bite deep.' -FatalCause 'The cold at section 129 reduced your Endurance to zero.')
                            }
                            else {
                                Write-LWInfo 'Section 129: Baknar oil protects you from the cold-based ENDURANCE loss here.'
                            }
                        }
                    }
                    150 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section150Resolved')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section150Resolved'
                            if (-not (Test-LWStateHasBaknarOilApplied -State $script:GameState)) {
                                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section150DamageApplied' -Delta -2 -MessagePrefix 'Section 150: the sudden cold from the Ice Demon punishes you.' -FatalCause 'The sudden cold at section 150 reduced your Endurance to zero.')
                            }
                            else {
                                Write-LWInfo 'Section 150: Baknar oil protects you from the sudden cold here.'
                            }
                        }
                    }
                    170 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section170DamageApplied')) {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section170DamageApplied' -Delta -6 -MessagePrefix 'Section 170: the Helghast tears at your throat before the fight begins.' -FatalCause 'The Helghast''s surprise attack at section 170 reduced your Endurance to zero.')
                        }
                    }
                    187 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section187BraceletClaimed') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Type 'special')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Gold Bracelet') {
                                Set-LWStoryAchievementFlag -Name 'Book3Section187BraceletClaimed'
                                Write-LWInfo 'Section 187: Gold Bracelet added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Gold Bracelet automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    231 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 231 Bracelet' -PromptLabel 'Section 231 choice' -ContextLabel 'Section 231' -Choices (Get-LWBookThreeSection231ChoiceDefinitions) -Intro 'Section 231: take a Gold Bracelet if you want it.'
                    }
                    236 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section236BraceletClaimed') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Type 'special')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Gold Bracelet') {
                                Set-LWStoryAchievementFlag -Name 'Book3Section236BraceletClaimed'
                                Write-LWInfo 'Section 236: Gold Bracelet added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Gold Bracelet automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    237 {
                        Write-LWInfo 'Section 237: this is still a meal section. Use meal here to resolve it before moving on.'
                    }
                    258 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section258BraceletRemoved')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section258BraceletRemoved'
                            [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Types @('special'))
                            Write-LWInfo 'Section 258: Gold Bracelet erased after you tear it away.'
                        }
                    }
                    280 {
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 1 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss

                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }

                        $message = 'Section 280: the Ornate Silver Key''s corrosive acid burns your hand.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        $message += " Current Endurance: $($script:GameState.Character.EnduranceCurrent) / $($script:GameState.Character.EnduranceMax)."
                        Write-LWInfo $message

                        [void](Invoke-LWFatalEnduranceCheck -Cause 'The corrosive acid on the Ornate Silver Key reduced your Endurance to zero.')
                    }
                    282 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 282 Loot' -PromptLabel 'Section 282 choice' -ContextLabel 'Section 282' -Choices (Get-LWBookThreeSection282ChoiceDefinitions) -Intro 'Section 282: take the Spear and Blue Stone Disc if you want them.'
                    }
                    295 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 295 Firesphere' -PromptLabel 'Section 295 choice' -ContextLabel 'Section 295' -Choices (Get-LWBookThreeSection295ChoiceDefinitions) -Intro 'Section 295: keep the Firesphere if you want it before leaving the chamber.'
                    }
                    298 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 298 Trophy' -PromptLabel 'Section 298 choice' -ContextLabel 'Section 298' -Choices (Get-LWBookThreeSection298ChoiceDefinitions) -Intro 'Section 298: keep the Blue Stone Triangle if you want it.'
                    }
                    303 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section303KeyErased')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section303KeyErased'
                            [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWOrnateSilverKeyItemNames) -Types @('special', 'backpack'))
                            Write-LWInfo 'Section 303: Ornate Silver Key erased after opening the helm chamber.'
                        }
                    }
                    308 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section308SilverHelmClaimed') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSilverHelmItemNames) -Type 'special')) {
                            $helmetName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWHelmetItemNames) -Type 'special'
                            if (-not [string]::IsNullOrWhiteSpace($helmetName)) {
                                [void](Remove-LWInventoryItemSilently -Type 'special' -Name $helmetName -Quantity 1)
                                Write-LWInfo 'Section 308: ordinary Helmet discarded to keep the Silver Helm.'
                            }
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Silver Helm') {
                                Set-LWStoryAchievementFlag -Name 'Book3Section308SilverHelmClaimed'
                                Write-LWInfo 'Section 308: Silver Helm added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Silver Helm automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                    309 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 309 Finds' -PromptLabel 'Section 309 choice' -ContextLabel 'Section 309' -Choices (Get-LWBookThreeSection309ChoiceDefinitions) -Intro 'Section 309: keep the Blue Stone Triangle and Firesphere if you want them before returning to the tunnel.'
                    }
                    321 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 321 Stream' -PromptLabel 'Section 321 choice' -ContextLabel 'Section 321' -Choices (Get-LWBookThreeSection321ChoiceDefinitions) -Intro 'Section 321: keep the Blue Stone Triangle if you want it before moving on.'
                    }
                    326 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section326DamageApplied' -Delta -1 -MessagePrefix 'Section 326: forcing the lock with Kai skill leaves you badly fatigued.' -FatalCause 'The strain at section 326 reduced your Endurance to zero.')
                    }
                    328 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section328DamageApplied')) {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section328DamageApplied' -Delta -6 -MessagePrefix 'Section 328: the Helghast tears at your throat before the fight begins.' -FatalCause 'The Helghast''s surprise attack at section 328 reduced your Endurance to zero.')
                        }
                    }
                    345 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section345BraceletRemoved')) {
                            Set-LWStoryAchievementFlag -Name 'Book3Section345BraceletRemoved'
                            [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Types @('special'))
                            Write-LWInfo 'Section 345: Gold Bracelet erased after you tear it from your wrist.'
                        }
                    }
                }
            }
            4 {
                switch ($section) {
                    2 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 2 Loot' -PromptLabel 'Section 2 choice' -ContextLabel 'Section 2' -Choices (Get-LWBookFourSection002ChoiceDefinitions) -Intro 'Section 2: search the bodies and keep whatever you want before leaving the mines.'
                    }
                    3 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section003DamageApplied' -Delta -1 -MessagePrefix 'Section 3: the feigned-dead bandit lashes out and clips your legs.' -FatalCause 'The surprise attack at section 3 reduced your Endurance to zero.')
                    }
                    22 {
                        Invoke-LWBookFourForcedPackOrWeaponLoss -Reason 'Section 22: you fumble in the darkness and drop gear.'
                    }
                    44 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 44 Loot' -PromptLabel 'Section 44 choice' -ContextLabel 'Section 44' -Choices (Get-LWBookFourSection044ChoiceDefinitions) -Intro 'Section 44: search the fallen strangers and keep whatever you want.'
                    }
                    52 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section052DamageApplied' -Delta -1 -MessagePrefix 'Section 52: an arrow passes so close that it grazes your eye.' -FatalCause 'The arrow graze at section 52 reduced your Endurance to zero.')
                    }
                    67 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section067DamageApplied')) {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section067DamageApplied' -Delta -1 -MessagePrefix 'Section 67: a razor disc grazes the back of your hand and hurls you from your horse.' -FatalCause 'The ambush at section 67 reduced your Endurance to zero.')
                        }
                    }
                    74 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section074RestApplied' -Delta 1 -MessagePrefix 'Section 74: the quiet night refreshes you.')
                    }
                    75 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section075DamageApplied' -Delta -2 -MessagePrefix 'Section 75: a spear thrust gashes your arm in the crush of battle.' -FatalCause 'The wound at section 75 reduced your Endurance to zero.')
                    }
                    10 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed')) {
                            if (Read-LWYesNo -Prompt 'Take the Onyx Medallion?' -Default $true) {
                                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Onyx Medallion') {
                                    Set-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed'
                                    Write-LWInfo 'Section 10: Onyx Medallion added to Special Items.'
                                }
                                else {
                                    Write-LWWarn 'No room to add the Onyx Medallion automatically. Make room and add it manually if you are keeping it.'
                                }
                            }
                        }
                    }
                    12 {
                        if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
                            Restore-LWBackpackState -WriteMessages
                            Set-LWStoryAchievementFlag -Name 'Book4BackpackRecovered'
                            Write-LWInfo 'Section 12: Captain D''Val outfits you with a fresh empty Backpack.'
                        }

                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section12ResupplyHandled')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section12ResupplyHandled'
                        }

                        $availableChoices = @(Get-LWBookFourSection12ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                        if ($availableChoices.Count -gt 0) {
                            Write-LWInfo 'Section 12: Captain D''Val offers you supplies from the wagon. Take whatever you want to keep.'
                        }

                        while ($availableChoices.Count -gt 0) {
                            Write-LWPanelHeader -Title 'Section 12 Supplies' -AccentColor 'DarkYellow'
                            Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
                            Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
                            Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
                            Write-Host ''

                            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
                            }
                            Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
                            Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

                            $choiceText = [string](Read-LWText -Prompt 'Section 12 choice' -Default '0' -NoRefresh)
                            if ([string]::IsNullOrWhiteSpace($choiceText)) {
                                $choiceText = '0'
                            }
                            $choiceText = $choiceText.Trim()

                            if ($choiceText -eq '0') {
                                break
                            }

                            if ($choiceText -match '^[dD]$') {
                                Remove-LWInventoryInteractive -InputParts @('drop')
                                $availableChoices = @(Get-LWBookFourSection12ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                                continue
                            }

                            $choiceIndex = 0
                            if (-not [int]::TryParse($choiceText, [ref]$choiceIndex)) {
                                Write-LWInlineWarn 'Choose a numbered item, D to drop something, or 0 when you are done here.'
                                continue
                            }
                            if ($choiceIndex -lt 1 -or $choiceIndex -gt $availableChoices.Count) {
                                Write-LWInlineWarn ("Choose a number from 1 to {0}, D to drop something, or 0 when you are done here." -f $availableChoices.Count)
                                continue
                            }

                            $choice = $availableChoices[$choiceIndex - 1]
                            if (-not (Grant-LWBookFourSection12Choice -Choice $choice) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
                                Invoke-LWBookFourStartingInventoryManagement
                            }

                            $availableChoices = @(Get-LWBookFourSection12ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                        }
                    }
                    78 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 78 Loot' -PromptLabel 'Section 78 choice' -ContextLabel 'Section 78' -Choices @(
                            [pscustomobject]@{ Id = 'holy_water'; FlagName = 'Book4Section078HolyWaterClaimed'; DisplayName = 'Flask of Holy Water'; Type = 'backpack'; Name = 'Flask of Holy Water'; Quantity = 1; Description = 'Flask of Holy Water' }
                        ) -Intro 'Section 78: claim the Flask of Holy Water if you want to keep it.'
                    }
                    79 {
                        Invoke-LWBookFourTorchSupplies -ExtraTorchCount 4 -Section 79
                    }
                    84 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4ScrollClaimed')) {
                            if (Read-LWYesNo -Prompt 'Take the Scroll?' -Default $true) {
                                if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Scroll') {
                                    Set-LWStoryAchievementFlag -Name 'Book4ScrollClaimed'
                                    Write-LWInfo 'Section 84: Scroll added to Special Items.'
                                }
                            }
                        }
                    }
                    94 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section94LossApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section94LossApplied'
                            Invoke-LWBookFourBackpackLoss -Reason 'Section 94'
                        }
                    }
                    103 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section103DamageApplied' -Delta -4 -MessagePrefix 'Section 103: the scimitar wound bites deep as you escape.' -FatalCause 'The scimitar wound at section 103 reduced your Endurance to zero.')
                    }
                    109 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 109 Loot' -PromptLabel 'Section 109 choice' -ContextLabel 'Section 109' -Choices (Get-LWBookFourSection109ChoiceDefinitions) -Intro 'Section 109: search the dead bandit and keep whatever you want.'
                    }
                    117 {
                        if (Test-LWStateCanRelightTorch -State $script:GameState) {
                            Write-LWInfo 'Section 117: you have the means to relight and follow the lit path to section 22.'
                        }
                        elseif (Test-LWStateHasFiresphere -State $script:GameState) {
                            Write-LWInfo 'Section 117: your Kalte Firesphere can guide the way onward.'
                        }
                        else {
                            Write-LWWarn 'Section 117: without another Torch and Tinderbox, or a Kalte Firesphere, you cannot follow the lit path.'
                        }
                    }
                    122 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section122MindAttackApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section122MindAttackApplied'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 1 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }
                            $message = 'Section 122: Barraka''s mind assault strikes before the duel.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE."
                            }
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message
                            [void](Invoke-LWFatalEnduranceCheck -Cause 'Barraka''s opening mind assault reduced your Endurance to zero.')
                        }
                    }
                    123 {
                        Invoke-LWBookFourTorchSupplies -ExtraTorchCount 5 -Section 123
                    }
                    137 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section137RecoveryApplied' -Delta 6 -MessagePrefix 'Section 137: Laumspur treatment restores your strength.')
                    }
                    152 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 152 Loot' -PromptLabel 'Section 152 choice' -ContextLabel 'Section 152' -Choices (Get-LWBookFourSection152ChoiceDefinitions) -Intro 'Section 152: search the dead guard and keep whatever you want.'
                    }
                    157 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section157RestApplied' -Delta 1 -MessagePrefix 'Section 157: the forced sleep leaves you refreshed.')
                    }
                    158 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section158LossApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section158LossApplied'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }
                            Invoke-LWBookFourBackpackLoss -Reason 'Section 158'
                            $message = 'Section 158: the river batters you as your Backpack is swept away.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE."
                            }
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message
                            if (-not (Invoke-LWFatalEnduranceCheck -Cause 'The river route reduced your Endurance to zero.')) {
                                Set-LWStoryAchievementFlag -Name 'Book4WashedAway'
                            }
                        }
                    }
                    176 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section176DamageApplied' -Delta -3 -MessagePrefix 'Section 176: the mounted crash hurls you down and a blade bites into your shoulder.' -FatalCause 'The crash at section 176 reduced your Endurance to zero.')
                    }
                    167 {
                        if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
                            Restore-LWBackpackState -WriteMessages
                        }
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section167RecoveryClaimed')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section167RecoveryClaimed'
                            Set-LWStoryAchievementFlag -Name 'Book4BackpackRecovered'
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal') {
                                Write-LWInfo 'Section 167: the miner''s Backpack contains 1 Meal.'
                            }
                            if (Read-LWYesNo -Prompt 'Take the Shovel here? (2 Backpack slots)' -Default $false) {
                                [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Shovel')
                            }
                        }
                    }
                    213 {
                        $availableChoices = @(Get-LWBookFourSection213ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                        if ($availableChoices.Count -gt 0) {
                            Write-LWInfo 'Section 213: choose any loot you want to keep from the supply table.'
                        }

                        while ($availableChoices.Count -gt 0) {
                            Write-LWPanelHeader -Title 'Section 213 Loot' -AccentColor 'DarkYellow'
                            Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
                            Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
                            Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
                            Write-Host ''

                            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
                            }
                            Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
                            Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

                            $choiceText = [string](Read-LWText -Prompt 'Section 213 choice' -Default '0' -NoRefresh)
                            if ([string]::IsNullOrWhiteSpace($choiceText)) {
                                $choiceText = '0'
                            }
                            $choiceText = $choiceText.Trim()

                            if ($choiceText -eq '0') {
                                break
                            }

                            if ($choiceText -match '^[dD]$') {
                                Remove-LWInventoryInteractive -InputParts @('drop')
                                $availableChoices = @(Get-LWBookFourSection213ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                                continue
                            }

                            $choiceIndex = 0
                            if (-not [int]::TryParse($choiceText, [ref]$choiceIndex)) {
                                Write-LWInlineWarn 'Choose a numbered item, D to drop something, or 0 when you are done here.'
                                continue
                            }
                            if ($choiceIndex -lt 1 -or $choiceIndex -gt $availableChoices.Count) {
                                Write-LWInlineWarn ("Choose a number from 1 to {0}, D to drop something, or 0 when you are done here." -f $availableChoices.Count)
                                continue
                            }

                            $choice = $availableChoices[$choiceIndex - 1]
                            if (-not (Grant-LWBookFourSection213Choice -Choice $choice) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
                                Invoke-LWBookFourStartingInventoryManagement
                            }

                            $availableChoices = @(Get-LWBookFourSection213ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                        }
                    }
                    222 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed')) {
                            if (Read-LWYesNo -Prompt 'Take Captain D''Val''s Sword?' -Default $true) {
                                if (Add-LWWeaponWithOptionalReplace -Name "Captain D'Val's Sword" -PromptLabel "Captain D'Val's Sword") {
                                    Set-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed'
                                }
                            }
                        }
                    }
                    230 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 230 Loot' -PromptLabel 'Section 230 choice' -ContextLabel 'Section 230' -Choices (Get-LWBookFourSection230ChoiceDefinitions) -Intro 'Section 230: search the bodies and keep whatever you want before fleeing.'
                    }
                    231 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 231 Loot' -PromptLabel 'Section 231 choice' -ContextLabel 'Section 231' -Choices (Get-LWBookFourSection231ChoiceDefinitions) -Intro 'Section 231: search the dead guard and keep whatever you want before you cross the bridge.'
                    }
                    236 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section236DamageApplied' -Delta -4 -MessagePrefix 'Section 236: a thrown knife buries itself in your arm.' -FatalCause 'The knife wound at section 236 reduced your Endurance to zero.')
                    }
                    268 {
                        Write-LWInfo 'Section 268: loot here can include Spear, Broadsword, Iron Key, Brass Key, 2 Meals, and Potion of Red Liquid.'
                        if (Read-LWYesNo -Prompt 'Take the Spear?' -Default $false) {
                            [void](Add-LWWeaponWithOptionalReplace -Name 'Spear' -PromptLabel 'Spear')
                        }
                        if (Read-LWYesNo -Prompt 'Take the Broadsword?' -Default $false) {
                            [void](Add-LWWeaponWithOptionalReplace -Name 'Broadsword' -PromptLabel 'Broadsword')
                        }
                        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWIronKeyItemNames) -Type 'special') -and (Read-LWYesNo -Prompt 'Take the Iron Key?' -Default $true)) {
                            [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Iron Key')
                        }
                        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBrassKeyItemNames) -Type 'special') -and (Read-LWYesNo -Prompt 'Take the Brass Key?' -Default $true)) {
                            [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Brass Key')
                        }
                        if (Read-LWYesNo -Prompt 'Take the 2 Meals?' -Default $true) {
                            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 2)
                        }
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4PotionOfRedLiquidClaimed') -and (Read-LWYesNo -Prompt 'Take the Potion of Red Liquid?' -Default $true)) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Potion of Red Liquid') {
                                Set-LWStoryAchievementFlag -Name 'Book4PotionOfRedLiquidClaimed'
                                Write-LWInfo 'Section 268: Potion of Red Liquid added to Backpack.'
                            }
                        }
                    }
                    270 {
                        if (Test-LWStateHasFiresphere -State $script:GameState) {
                            Write-LWInfo 'Section 270: your Kalte Firesphere can guide you through the vault.'
                        }
                        elseif (Test-LWStateCanRelightTorch -State $script:GameState) {
                            Write-LWInfo 'Section 270: you have Torch + Tinderbox to take the lit vault path.'
                        }
                        else {
                            Write-LWWarn 'Section 270: without Torch + Tinderbox, or a Kalte Firesphere, the lit vault path is unavailable.'
                        }
                    }
                    269 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 269 Loot' -PromptLabel 'Section 269 choice' -ContextLabel 'Section 269' -Choices @(
                            [pscustomobject]@{ Id = 'shovel'; FlagName = 'Book4Section269ShovelClaimed'; DisplayName = 'Shovel'; Type = 'backpack'; Name = 'Shovel'; Quantity = 1; Description = 'Shovel' }
                        ) -Intro 'Section 269: you may take one of the discarded Shovels if you want to keep it.'
                    }
                    272 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section272LossApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section272LossApplied'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 5 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }
                            Invoke-LWBookFourLoseOneWeapon -Reason 'Section 272 forces you to lose one Weapon.'
                            $message = 'Section 272: you are battered by the fall.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE."
                            }
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message
                            [void](Invoke-LWFatalEnduranceCheck -Cause 'The fall at section 272 reduced your Endurance to zero.')
                        }
                    }
                    263 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section263DamageApplied' -Delta -4 -MessagePrefix 'Section 263: the razor disc bites deeply into your shoulder.' -FatalCause 'The disc wound at section 263 reduced your Endurance to zero.')
                    }
                    275 {
                        if (Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section275DamageApplied' -Delta -1 -MessagePrefix 'Section 275: the cave-in blast throws you to the floor as the tunnel collapses.' -FatalCause 'The cave-in at section 275 reduced your Endurance to zero.') {
                            Write-LWInfo 'Section 275: all Torches are extinguished and must be relit if the text later allows it.'
                        }
                    }
                    280 {
                        $availableChoices = @(Get-LWBookFourSection280ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                        if ($availableChoices.Count -gt 0) {
                            Write-LWInfo 'Section 280: search the Bridge Guard and keep whatever you want before crossing the bridge.'
                        }

                        while ($availableChoices.Count -gt 0) {
                            Write-LWPanelHeader -Title 'Section 280 Loot' -AccentColor 'DarkYellow'
                            Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
                            Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
                            Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
                            Write-Host ''

                            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                                $choice = $availableChoices[$i]
                                $line = switch ([string]$choice.Type) {
                                    'gold' { [string]$choice.DisplayName }
                                    'weapon' { ("{0} [Weapon]" -f [string]$choice.DisplayName) }
                                    'backpack' { ("{0} [Backpack, 1 slot]" -f [string]$choice.DisplayName) }
                                    default { [string]$choice.DisplayName }
                                }
                                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), $line) -TextColor 'Gray' -BulletColor 'Yellow'
                            }
                            Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
                            Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

                            $choiceText = [string](Read-LWText -Prompt 'Section 280 choice' -Default '0' -NoRefresh)
                            if ([string]::IsNullOrWhiteSpace($choiceText)) {
                                $choiceText = '0'
                            }
                            $choiceText = $choiceText.Trim()

                            if ($choiceText -eq '0') {
                                break
                            }

                            if ($choiceText -match '^[dD]$') {
                                Remove-LWInventoryInteractive -InputParts @('drop')
                                $availableChoices = @(Get-LWBookFourSection280ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                                continue
                            }

                            $choiceIndex = 0
                            if (-not [int]::TryParse($choiceText, [ref]$choiceIndex)) {
                                Write-LWInlineWarn 'Choose a numbered item, D to drop something, or 0 when you are done here.'
                                continue
                            }
                            if ($choiceIndex -lt 1 -or $choiceIndex -gt $availableChoices.Count) {
                                Write-LWInlineWarn ("Choose a number from 1 to {0}, D to drop something, or 0 when you are done here." -f $availableChoices.Count)
                                continue
                            }

                            $choice = $availableChoices[$choiceIndex - 1]
                            if (-not (Grant-LWBookFourSection280Choice -Choice $choice) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
                                Invoke-LWBookFourStartingInventoryManagement
                            }

                            $availableChoices = @(Get-LWBookFourSection280ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                        }
                    }
                    283 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section283HolyWaterApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section283HolyWaterApplied'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }
                            [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWFlaskOfHolyWaterItemNames) -Types @('backpack', 'special'))
                            $message = 'Section 283: the Flask of Holy Water is used in the final assault.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE."
                            }
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message
                            [void](Invoke-LWFatalEnduranceCheck -Cause 'The final assault at section 283 reduced your Endurance to zero.')
                        }
                    }
                    302 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 302 Satchel' -PromptLabel 'Section 302 choice' -ContextLabel 'Section 302' -Choices (Get-LWBookFourSection302ChoiceDefinitions) -Intro 'Section 302: the herbwarden''s satchel holds whatever you want to keep.'
                    }
                    303 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section303DamageApplied' -Delta -2 -MessagePrefix 'Section 303: the climb out of the bridge shaft leaves your knees and knuckles badly bruised.' -FatalCause 'The climb at section 303 reduced your Endurance to zero.')
                    }
                    29 {
                        Set-LWStoryAchievementFlag -Name 'Book4TorchesWillNotLight'
                        Write-LWInfo 'Section 29: torches no longer relight in these tunnels.'
                    }
                    118 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 118 Loot' -PromptLabel 'Section 118 choice' -ContextLabel 'Section 118' -Choices @(
                            [pscustomobject]@{ Id = 'whip'; FlagName = 'Book4Section118WhipClaimed'; DisplayName = 'Whip'; Type = 'backpack'; Name = 'Whip'; Quantity = 1; Description = 'Whip' }
                        ) -Intro 'Section 118: take the Whip if you want to keep it.'
                    }
                    322 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section322RestApplied')) {
                            Set-LWStoryAchievementFlag -Name 'Book4Section322RestApplied'
                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ([int]$script:GameState.Character.EnduranceCurrent + 2))
                            $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
                            if ($restored -gt 0) {
                                Add-LWBookEnduranceDelta -Delta $restored
                                Write-LWInfo ("Section 322: the rest restores {0} ENDURANCE." -f $restored)
                            }

                            Write-LWPanelHeader -Title 'Book 4 Mine Tools' -AccentColor 'DarkYellow'
                            Write-LWBulletItem -Text '0. Take nothing' -TextColor 'DarkGray' -BulletColor 'Yellow'
                            Write-LWBulletItem -Text '1. Pick' -TextColor 'Gray' -BulletColor 'Yellow'
                            Write-LWBulletItem -Text '2. Shovel' -TextColor 'Gray' -BulletColor 'Yellow'
                            $toolChoice = Read-LWInt -Prompt 'Choose a tool to take from section 322' -Default 0 -Min 0 -Max 2
                            if ($toolChoice -eq 1) {
                                [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Pick')
                            }
                            elseif ($toolChoice -eq 2) {
                                [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Shovel')
                            }
                        }
                    }
                    340 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section340DamageApplied' -Delta -2 -MessagePrefix 'Section 340: lack of oxygen makes your head spin and your legs turn to lead.' -FatalCause 'The suffocating water at section 340 reduced your Endurance to zero.')
                    }
                    341 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section341DamageApplied' -Delta -4 -MessagePrefix 'Section 341: the arrow wound in your thigh is treated, but it still costs you dearly.' -FatalCause 'The arrow wound aftermath at section 341 reduced your Endurance to zero.')
                    }
                    327 {
                        $captainSwordName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCaptainDValSwordWeaponNames) -Type 'weapon'
                        if (-not [string]::IsNullOrWhiteSpace($captainSwordName)) {
                            [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $captainSwordName -Quantity 1)
                            Set-LWStoryAchievementFlag -Name 'Book4ReturnToSenderPath'
                            Write-LWInfo 'Section 327: Captain D''Val''s Sword is handed back and erased from your Weapons.'
                        }
                    }
                    350 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Dagger of Vashna') {
                                Set-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed'
                                Write-LWInfo 'Section 350: Dagger of Vashna added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Dagger of Vashna automatically. Make room and add it manually if needed.'
                            }
                        }
                    }
                }
            }
            5 {
                switch ($section) {
                    2 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 2 Herbal Cache' -PromptLabel 'Section 2 choice' -ContextLabel 'Section 2' -Choices (Get-LWBookFiveSection002ChoiceDefinitions) -Intro 'Section 2: take the Oede Herb if you want to keep it.'
                        if ((Test-LWStoryAchievementFlag -Name 'Book5Section002OedeClaimed') -and (Test-LWBookFiveLimbdeathActive -State $script:GameState)) {
                            $script:GameState.Conditions.BookFiveLimbdeath = $false
                            Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
                            Write-LWInfo 'Section 2: the Oede Herb cures your Limbdeath. Your Shield can be used again.'
                        }
                    }
                    3 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 3 Loot' -PromptLabel 'Section 3 choice' -ContextLabel 'Section 3' -Choices (Get-LWBookFiveSection003ChoiceDefinitions) -Intro 'Section 3: search the dead guards and keep whatever you want.'
                    }
                    4 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 4 Sword' -PromptLabel 'Section 4 choice' -ContextLabel 'Section 4' -Choices (Get-LWBookFiveSection004ChoiceDefinitions) -Intro 'Section 4: grab the fallen sword if you want to fight with it.'
                    }
                    10 {
                        if (-not (Test-LWStateHasConfiscatedEquipment)) {
                            Save-LWConfiscatedEquipment -WriteMessages -Reason 'Section 10: your captors strip you of all carried gear'
                        }
                    }
                    14 {
                        if (Restore-LWConfiscatedEquipment -WriteMessages) {
                            Set-LWStoryAchievementFlag -Name 'Book5PrisonBreak'
                        }
                    }
                    19 {
                        [void](Invoke-LWBookFiveLoseBackpackItems -Count 2 -Reason 'Section 19: the guards seize part of your kit.' -ExcludeMeals)
                    }
                    27 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 27 Apothecary' -PromptLabel 'Section 27 choice' -ContextLabel 'Section 27' -Choices (Get-LWBookFiveSection027ChoiceDefinitions) -Intro 'Section 27: buy whatever remedies you want before you move on.'
                    }
                    29 {
                        if ((Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Rope' -Quantity 1) -gt 0) {
                            Write-LWInfo 'Section 29: the Rope is used here and erased from your Backpack.'
                        }
                    }
                    35 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 35 Chamber Loot' -PromptLabel 'Section 35 choice' -ContextLabel 'Section 35' -Choices (Get-LWBookFiveSection035ChoiceDefinitions) -Intro 'Section 35: keep the Jewelled Mace and Copper Key if you want them.'
                    }
                    40 {
                        [void](Invoke-LWBookFiveLoseBackpackItems -Count 1 -Reason 'Section 40: the crowd strips one Backpack Item from you.')
                        if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                            Add-LWBookGoldDelta -Delta (-[int]$script:GameState.Inventory.GoldCrowns)
                            $script:GameState.Inventory.GoldCrowns = 0
                            Write-LWInfo 'Section 40: all Gold Crowns are taken from you.'
                        }
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section040DamageApplied' -Delta -2 -MessagePrefix 'Section 40: the beating leaves you dazed and aching.' -FatalCause 'The beating at section 40 reduced your Endurance to zero.')
                    }
                    52 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 52 Loot' -PromptLabel 'Section 52 choice' -ContextLabel 'Section 52' -Choices (Get-LWBookFiveSection052ChoiceDefinitions) -Intro 'Section 52: search the dead guards and keep whatever you want.'
                    }
                    63 {
                        if (-not (Test-LWBookFiveBloodPoisoningActive -State $script:GameState)) {
                            $script:GameState.Conditions.BookFiveBloodPoisoning = $true
                            Write-LWInfo 'Section 63: blood poisoning sets in. Lose 2 ENDURANCE at each new section until you swallow a Potion of Laumspur.'
                        }
                    }
                    67 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section067QuarterstaffClaimed')) {
                            if (Read-LWYesNo -Prompt 'Take the Quarterstaff?' -Default $true) {
                                if (Add-LWWeaponWithOptionalReplace -Name 'Quarterstaff' -PromptLabel 'Quarterstaff') {
                                    Set-LWStoryAchievementFlag -Name 'Book5Section067QuarterstaffClaimed'
                                }
                            }
                        }
                    }
                    69 {
                        if (-not (Test-LWStateHasConfiscatedEquipment)) {
                            Save-LWConfiscatedEquipment -WriteMessages -Reason 'Section 69: you are imprisoned and all your gear is confiscated'
                        }
                    }
                    71 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section071TowelClaimed')) {
                            if (Read-LWYesNo -Prompt 'Keep the Towel? (2 Backpack slots)' -Default $false) {
                                if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Towel') {
                                    Set-LWStoryAchievementFlag -Name 'Book5Section071TowelClaimed'
                                    Write-LWInfo 'Section 71: Towel added to Backpack (2 slots).'
                                }
                                else {
                                    Write-LWWarn 'No room to keep the Towel. Make room and add it manually if you are keeping it.'
                                }
                            }
                        }
                    }
                    100 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 100 Finds' -PromptLabel 'Section 100 choice' -ContextLabel 'Section 100' -Choices (Get-LWBookFiveSection100ChoiceDefinitions) -Intro 'Section 100: keep the Copper Key and Prism if you want them.'
                    }
                    101 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 101 Loot' -PromptLabel 'Section 101 choice' -ContextLabel 'Section 101' -Choices (Get-LWBookFiveSection003ChoiceDefinitions) -Intro 'Section 101: search the dead guards and keep whatever you want.'
                    }
                    102 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 102 Armoury Loot' -PromptLabel 'Section 102 choice' -ContextLabel 'Section 102' -Choices (Get-LWBookFiveSection102ChoiceDefinitions) -Intro 'Section 102: take whatever gear you want from the armoury.'
                    }
                    103 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section103RecoveryApplied' -Delta 2 -MessagePrefix 'Section 103: the soothing purple oil restores your strength.')
                    }
                    108 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section108DamageApplied' -Delta -2 -MessagePrefix 'Section 108: the corrosive gas burns your lungs and eyes.' -FatalCause 'The gas at section 108 reduced your Endurance to zero.')
                    }
                    130 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section130HerbPadClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Herb Pad') {
                                Set-LWStoryAchievementFlag -Name 'Book5Section130HerbPadClaimed'
                                Write-LWInfo 'Section 130: Herb Pad added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Herb Pad automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section130RecoveryApplied' -Delta 1 -MessagePrefix 'Section 130: the poultice refreshes you.')
                    }
                    131 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 131 Chamber Loot' -PromptLabel 'Section 131 choice' -ContextLabel 'Section 131' -Choices (Get-LWBookFiveSection131ChoiceDefinitions) -Intro 'Section 131: take whatever you want from the chamber.'
                    }
                    154 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 154 Apothecary' -PromptLabel 'Section 154 choice' -ContextLabel 'Section 154' -Choices (Get-LWBookFiveSection154ChoiceDefinitions) -Intro 'Section 154: buy whatever potions you want before moving on.'
                    }
                    159 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section159DamageApplied' -Delta -2 -MessagePrefix 'Section 159: you crash through the door and take the brunt of the impact.' -FatalCause 'The crash at section 159 reduced your Endurance to zero.')
                    }
                    166 {
                        if (-not (Test-LWBookFiveLimbdeathActive -State $script:GameState)) {
                            $script:GameState.Conditions.BookFiveLimbdeath = $true
                            Write-LWInfo 'Section 166: Limbdeath cripples your sword-arm. Shield use is lost and your Combat Skill suffers -3 until cured.'
                        }
                    }
                    169 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 169 Market Stall' -PromptLabel 'Section 169 choice' -ContextLabel 'Section 169' -Choices (Get-LWBookFiveSection169ChoiceDefinitions) -Intro 'Section 169: buy the Black Sash if you want it.'
                    }
                    176 {
                        if (-not (Test-LWStateHasConfiscatedEquipment)) {
                            Save-LWConfiscatedEquipment -WriteMessages -Reason 'Section 176: surrender leaves you stripped of all your gear'
                        }
                    }
                    207 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 207 Loot' -PromptLabel 'Section 207 choice' -ContextLabel 'Section 207' -Choices (Get-LWBookFiveSection207ChoiceDefinitions) -Intro 'Section 207: take the purse and Brass Whistle if you want them.'
                    }
                    211 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section211RecoveryApplied' -Delta 2 -MessagePrefix 'Section 211: the rest and food restore your strength.')
                        Invoke-LWBookFourChoiceTable -Title 'Section 211 Market' -PromptLabel 'Section 211 choice' -ContextLabel 'Section 211' -Choices (Get-LWBookFiveSection211ChoiceDefinitions) -Intro 'Section 211: buy the Bottle of Kourshah if you want it.'
                    }
                    254 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section254DamageApplied' -Delta -2 -MessagePrefix 'Section 254: the brutal climb tears at your hands and knees.' -FatalCause 'The climb at section 254 reduced your Endurance to zero.')
                    }
                    255 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 255 Discovery' -PromptLabel 'Section 255 choice' -ContextLabel 'Section 255' -Choices (Get-LWBookFiveSection255ChoiceDefinitions) -Intro 'Section 255: keep the Black Crystal Cube if you want it.'
                    }
                    270 {
                        $backpackCount = @(Get-LWInventoryItems -Type 'backpack').Count
                        if ($backpackCount -gt 0) {
                            $lossCount = [Math]::Min(2, $backpackCount)
                            [void](Invoke-LWBookFiveLoseBackpackItems -Count $lossCount -Reason 'Section 270: the chaos costs you Backpack gear.')
                        }
                        else {
                            Invoke-LWBookFourLoseOneWeapon -Reason 'Section 270 forces you to lose one Weapon.'
                            $specialItems = @(Get-LWInventoryItems -Type 'special')
                            if ($specialItems.Count -gt 0) {
                                Show-LWInventorySlotsSection -Type 'special'
                                $slot = if ($specialItems.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Special Item slot to lose' -Min 1 -Max $specialItems.Count }
                                $lostSpecial = [string]$specialItems[$slot - 1]
                                [void](Remove-LWInventoryItemSilently -Type 'special' -Name $lostSpecial -Quantity 1)
                                Write-LWInfo ("Section 270: lost Special Item {0}." -f $lostSpecial)
                            }
                        }
                    }
                    281 {
                        Invoke-LWBookFourChoiceTable -Title 'Section 281 Treasure' -PromptLabel 'Section 281 choice' -ContextLabel 'Section 281' -Choices (Get-LWBookFiveSection281ChoiceDefinitions) -Intro 'Section 281: keep the Jewelled Mace if you want it.'
                    }
                    302 {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section302RecoveryApplied' -Delta 3 -MessagePrefix 'Section 302: the food and rest restore your strength.')
                        Write-LWInfo 'Section 302: if you accept the drugged ale here, move to section 392.'
                    }
                    350 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section350SommerswerdLost')) {
                            $removed = Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Types @('special')
                            if ($removed -gt 0) {
                                Set-LWStoryAchievementFlag -Name 'Book5Section350SommerswerdLost'
                                Write-LWInfo 'Section 350: the Sommerswerd is torn from your grasp and lost in the abyss.'
                            }
                        }
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section350DamageApplied' -Delta -3 -MessagePrefix 'Section 350: the battle with the shadow drains you badly.' -FatalCause 'The confrontation at section 350 reduced your Endurance to zero.')
                    }
                    393 {
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section393MindAttackApplied') -and -not (Test-LWStateHasMindshield -State $script:GameState)) {
                            Set-LWStoryAchievementFlag -Name 'Book5Section393MindAttackApplied'
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section393DamageApplied' -Delta -2 -MessagePrefix 'Section 393: the mental assault hits before steel is drawn.' -FatalCause 'The mental assault at section 393 reduced your Endurance to zero.')
                        }
                    }
                    400 {
                        if ((Test-LWStoryAchievementFlag -Name 'Book5Section350SommerswerdLost') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Type 'special')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Sommerswerd') {
                                Write-LWInfo 'Section 400: the Sommerswerd is recovered from the ruins.'
                            }
                            else {
                                Write-LWWarn 'No room to restore the Sommerswerd automatically. Make room and add it manually if needed.'
                            }
                        }
                        if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section400MagnakaiClaimed')) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Book of the Magnakai') {
                                Set-LWStoryAchievementFlag -Name 'Book5Section400MagnakaiClaimed'
                                Write-LWInfo 'Section 400: Book of the Magnakai added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Book of the Magnakai automatically. Make room and add it manually if needed.'
                            }
                        }
                    }
                }
            }
        }

        Show-LWSectionGateHints
}

Export-ModuleMember -Function `
    Get-LWKaiRulesetVersion, `
    Get-LWKaiSectionRandomNumberContext, `
    Invoke-LWKaiStartingEquipment, `
    Invoke-LWKaiStorySectionAchievementTriggers, `
    Invoke-LWKaiStorySectionTransitionAchievementTriggers, `
    Invoke-LWKaiSectionEntryRules

