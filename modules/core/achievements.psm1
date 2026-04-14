Set-StrictMode -Version Latest

$script:LWAchievementModeAvailabilityCache = $null
$script:LWAchievementStateSchemaVersion = 1
$script:LWAchievementLoadBackfillVersion = 1

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWAchievementStateSchemaVersion {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return [int]$script:LWAchievementStateSchemaVersion
}

function Get-LWAchievementLoadBackfillVersion {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return [int]$script:LWAchievementLoadBackfillVersion
}

function New-LWAchievementProgressFlags {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return [pscustomobject]@{
        PerfectVictories     = 0
        BrinkVictories       = 0
        AgainstOddsVictories = 0
    }
}

function New-LWStoryAchievementFlags {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return [pscustomobject]@{
        Book1AimForTheBushesVisited = $false
        Book1ClubhouseFound         = $false
        Book1SilverKeyClaimed       = $false
        Book1UseTheForcePath        = $false
        Book1StraightToTheThrone    = $false
        Book1RoyalRecovery          = $false
        Book1BackWayIn              = $false
        Book1OpenSesameRoute        = $false
        Book1HotHandsClaimed        = $false
        Book1StarOfToranClaimed     = $false
        Book1FieldMedicPath         = $false
        Book1LaumspurClaimed        = $false
        Book1VordakGem76Claimed     = $false
        Book1VordakGem304Claimed    = $false
        Book1VordakGemCurseTriggered = $false
        Book1Section61NoteAdded     = $false
        Book1Section255SolnarisClaimed = $false
        Book2CoachTicketClaimed     = $false
        Book2WhitePassClaimed       = $false
        Book2RedPassClaimed         = $false
        Book2PotentPotionClaimed    = $false
        Book2MealOfLaumspurClaimed  = $false
        Book2ForgedPapersBought     = $false
        Book2Section106DamageApplied = $false
        Book2Section313Resolved     = $false
        Book2Section337StormLossApplied = $false
        Book2SommerswerdClaimed     = $false
        Book2ByAThreadRoute         = $false
        Book2SkyfallRoute           = $false
        Book2FightThroughTheSmokeRoute = $false
        Book2StormTossedSeen        = $false
        Book2SealOfApprovalRoute    = $false
        Book2PapersPleasePath       = $false
        Book3SnakePitVisited        = $false
        Book3CliffhangerSeen        = $false
        Book3DiamondClaimed         = $false
        Book3SnowblindSeen          = $false
        Book3GrossKeyClaimed        = $false
        Book3LuckyButtonTheorySeen  = $false
        Book3WellItWorkedOnceSeen   = $false
        Book3FirstCellAbandoned     = $false
        Book3CellfishPathTaken      = $false
        Book3LoiKymarRescued        = $false
        Book3EffigyEndgameReached   = $false
        Book3SommerswerdEndgameUsed = $false
        Book3LuckyEndgameUsed       = $false
        Book3TooSlowFailureSeen     = $false
        Book4Section12ResupplyHandled = $false
        Book4Section12MealsClaimed   = $false
        Book4Section12RopeClaimed    = $false
        Book4Section12PotionClaimed  = $false
        Book4Section12SwordClaimed   = $false
        Book4Section12SpearClaimed   = $false
        Book4Section79SuppliesClaimed = $false
        Book4Section94LossApplied   = $false
        Book4BadgeOfOfficePath      = $false
        Book4OnyxMedallionClaimed   = $false
        Book4Section117LightPath    = $false
        Book4Section122MindAttackApplied = $false
        Book4Section123SuppliesClaimed = $false
        Book4Section158LossApplied  = $false
        Book4Section167RecoveryClaimed = $false
        Book4BackpackLost           = $false
        Book4BackpackRecovered      = $false
        Book4WashedAway             = $false
        Book4Section280GoldClaimed  = $false
        Book4Section280MealClaimed  = $false
        Book4Section280SwordClaimed = $false
        Book4CaptainSwordClaimed    = $false
        Book4PotionOfRedLiquidClaimed = $false
        Book4ShovelReadyClaimed     = $false
        Book4ScrollClaimed          = $false
        Book4TorchesWillNotLight    = $false
        Book4LightInTheDepths       = $false
        Book4Section272LossApplied  = $false
        Book4SteelAgainstShadowRoute = $false
        Book4BlessedBeTheThrowRoute = $false
        Book4ScrollRoute            = $false
        Book4Section283HolyWaterApplied = $false
        Book4SunBelowTheEarthRoute  = $false
        Book4OnyxBluffRoute         = $false
        Book4Section322RestApplied  = $false
        Book4ReturnToSenderPath     = $false
        Book4ChasmOfDoomSeen        = $false
        Book4DaggerOfVashnaClaimed  = $false
        Book5OedeClaimed            = $false
        Book5LimbdeathCured         = $false
        Book5PrisonBreak            = $false
        Book5TalonsTamed            = $false
        Book5CrystalPendantRoute    = $false
        Book5SoushillaNameHeard     = $false
        Book5SoushillaAsked         = $false
        Book5Section278DamageApplied = $false
        Book5Section385ExplosionApplied = $false
        Book5BanishmentRoute        = $false
        Book5HaakonDuelRoute        = $false
        Book5BookOfMagnakaiClaimed  = $false
        Book6Section004LossApplied  = $false
        Book6Section035MealsRuined  = $false
        Book6Section040GoldClaimed  = $false
        Book6Section040WineClaimed  = $false
        Book6Section040MirrorClaimed = $false
        Book6Section048GoldClaimed  = $false
        Book6Section048MapClaimed   = $false
        Book6Section049CessUsed     = $false
        Book6Section065TaunorWaterResolved = $false
        Book6Section106TaunorWaterResolved = $false
        Book6Section109MapClaimed   = $false
        Book6Section112TaunorWaterResolved = $false
        Book6Section158SilverKeyClaimed = $false
        Book6Section158QuarterstaffClaimed = $false
        Book6Section158MealsClaimed = $false
        Book6Section158MaceClaimed  = $false
        Book6Section158WhistleClaimed = $false
        Book6Section158RopeClaimed  = $false
        Book6Section158ShortSwordClaimed = $false
        Book6Section190TaunorWaterResolved = $false
        Book6Section207Handled   = $false
        Book6Section232RoomPaid     = $false
        Book6Section232MealDeducted = $false
        Book6Section246TaunorWaterResolved = $false
        Book6Section252SilverBowClaimed = $false
        Book6Section278DamageApplied = $false
        Book6Section282DamageApplied = $false
        Book6Section293SilverKeyUsed = $false
        Book6Section304CessClaimed  = $false
        Book6Section306ColdDamageApplied = $false
        Book6Section306NexusProtected = $false
        Book6Section307Handled      = $false
        Book6Section307NoMealLossApplied = $false
        Book6Section310DamageApplied = $false
        Book6Section313DamageApplied = $false
        Book6Section315MindforceApplied = $false
        Book6Section315MindforceLossApplied = $false
        Book6Section315MindforceBlocked = $false
        Book6Section322TollPaid     = $false
        Book6Section348WarhammerLost = $false
        Book6JumpTheWagonsRoute     = $false
        Book6TaunorWaterStored      = $false
        Book6MapOfTekaroClaimed     = $false
        Book6SmallSilverKeyClaimed  = $false
        Book6SilverBowClaimed       = $false
        Book6CessClaimed            = $false
    }
}

function New-LWAchievementState {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return [pscustomobject]@{
        SchemaVersion     = (Get-LWAchievementStateSchemaVersion)
        LoadBackfillVersion = 0
        Unlocked          = @()
        SeenNotifications = @()
        ProgressFlags     = (New-LWAchievementProgressFlags)
        StoryFlags        = (New-LWStoryAchievementFlags)
    }
}

function New-LWAchievementDefinition {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Description,
        [bool]$Backfill = $false,
        [string]$ModePool = 'Universal',
        [string[]]$RequiredDifficulty = @(),
        [bool]$RequiresPermadeath = $false,
        [bool]$Hidden = $false
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return [pscustomobject]@{
        Id                 = $Id
        Name               = $Name
        Category           = $Category
        Description        = $Description
        Backfill           = [bool]$Backfill
        ModePool           = $ModePool
        RequiredDifficulty = @($RequiredDifficulty)
        RequiresPermadeath = [bool]$RequiresPermadeath
        Hidden             = [bool]$Hidden
    }
}

function Get-LWAchievementDefinitions {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ($null -ne $script:LWAchievementDefinitionsCache) {
        return @($script:LWAchievementDefinitionsCache)
    }

    $script:LWAchievementDefinitionsCache = @(
        (New-LWAchievementDefinition -Id 'first_blood' -Name 'First Blood' -Category 'Combat' -Description 'Win your first combat.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'swift_blade' -Name 'Swift Blade' -Category 'Combat' -Description 'Win a fight in a single round.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'untouchable' -Name 'Untouchable' -Category 'Combat' -Description 'Win a fight without losing any Endurance.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'against_the_odds' -Name 'Against the Odds' -Category 'Combat' -Description 'Win a fight at combat ratio 0 or lower.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'mind_over_matter' -Name 'Mind Over Matter' -Category 'Combat' -Description 'Win a fight using Mindblast.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'giant_slayer' -Name 'Giant-Slayer' -Category 'Combat' -Description 'Defeat an enemy with Combat Skill 18 or higher.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'monster_hunter' -Name 'Monster-Hunter' -Category 'Combat' -Description 'Defeat an enemy with Endurance 30 or higher.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'back_from_the_brink' -Name 'Back From the Brink' -Category 'Combat' -Description 'Win a fight with only 1 Endurance remaining.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'kai_veteran' -Name 'Kai Veteran' -Category 'Combat' -Description 'Win 10 combats in a single run.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'weapon_master' -Name 'Weapon Master' -Category 'Combat' -Description 'Win 10 combats with the same weapon.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'seasoned_fighter' -Name 'Seasoned Fighter' -Category 'Combat' -Description 'Fight 25 total rounds in a single run.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'endurance_duelist' -Name 'Endurance Duelist' -Category 'Combat' -Description 'Survive a fight lasting 5 or more rounds.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'easy_pickings' -Name 'Easy Pickings' -Category 'Combat' -Description 'Win a fight at combat ratio 15 or higher.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'trail_survivor' -Name 'Trail Survivor' -Category 'Survival' -Description 'Eat your first meal.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'hunters_instinct' -Name 'Hunter''s Instinct' -Category 'Survival' -Description 'Have Hunting cover 5 meals.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'herbal_relief' -Name 'Herbal Relief' -Category 'Survival' -Description 'Use your first Laumspur potion.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'second_wind' -Name 'Second Wind' -Category 'Survival' -Description 'Restore 10 Endurance through Healing.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'loaded_purse' -Name 'Loaded Purse' -Category 'Survival' -Description 'Reach 50 Gold Crowns.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'hard_lessons' -Name 'Hard Lessons' -Category 'Survival' -Description 'Suffer your first starvation penalty.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'still_standing' -Name 'Still Standing' -Category 'Survival' -Description 'Survive 3 deaths in a single run.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'deep_draught' -Name 'Deep Draught' -Category 'Survival' -Description 'Use a dose of Concentrated Laumspur.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'pathfinder' -Name 'Pathfinder' -Category 'Journey' -Description 'Visit 25 sections in a single book.' -Backfill:$true -ModePool 'Exploration'),
        (New-LWAchievementDefinition -Id 'long_road' -Name 'Long Road' -Category 'Journey' -Description 'Visit 50 sections in a single book.' -Backfill:$true -ModePool 'Exploration'),
        (New-LWAchievementDefinition -Id 'no_quarter' -Name 'No Quarter' -Category 'Journey' -Description 'Win 5 combats in a single book.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'sun_sword' -Name 'Sun-sword' -Category 'Journey' -Description 'Claim the Sommerswerd.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'fully_armed' -Name 'Fully Armed' -Category 'Journey' -Description 'Carry two weapons and a Shield at the same time.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'relic_hunter' -Name 'Relic Hunter' -Category 'Journey' -Description 'Carry five Special Items at the same time.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'book_one_complete' -Name 'Book One Complete' -Category 'Journey' -Description 'Complete Book 1.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'book_two_complete' -Name 'Book Two Complete' -Category 'Journey' -Description 'Complete Book 2.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'book_three_complete' -Name 'Book Three Complete' -Category 'Journey' -Description 'Complete Book 3.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'grave_bane' -Name 'Grave-Bane' -Category 'Combat' -Description 'Defeat an undead enemy with the Sommerswerd.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'true_path' -Name 'True Path' -Category 'Legend' -Description 'Complete a book without using rewind.' -Backfill:$true -ModePool 'Exploration'),
        (New-LWAchievementDefinition -Id 'unbroken' -Name 'Unbroken' -Category 'Legend' -Description 'Complete a book without dying.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'wolf_of_sommerlund' -Name 'Wolf of Sommerlund' -Category 'Legend' -Description 'Complete a book without a combat defeat.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'iron_wolf' -Name 'Iron Wolf' -Category 'Legend' -Description 'Complete a book with no deaths, no rewinds, and no manual recovery shortcuts.' -ModePool 'Challenge' -RequiredDifficulty @('Hard', 'Veteran')),
        (New-LWAchievementDefinition -Id 'gentle_path' -Name 'A Gentle Path' -Category 'Story' -Description 'Complete a book in Story mode.' -ModePool 'Story' -RequiredDifficulty @('Story')),
        (New-LWAchievementDefinition -Id 'all_too_easy' -Name 'All Too Easy' -Category 'Story' -Description 'Win a combat in Story mode.' -ModePool 'Story' -RequiredDifficulty @('Story')),
        (New-LWAchievementDefinition -Id 'bedtime_tale' -Name 'Bedtime Tale' -Category 'Story' -Description 'Finish Book 1 in Story mode.' -ModePool 'Story' -RequiredDifficulty @('Story')),
        (New-LWAchievementDefinition -Id 'hard_road' -Name 'Hard Road' -Category 'Legend' -Description 'Complete a book on Hard.' -ModePool 'Challenge' -RequiredDifficulty @('Hard')),
        (New-LWAchievementDefinition -Id 'lean_healing' -Name 'Lean Healing' -Category 'Legend' -Description 'Complete a Hard book after pushing Healing to its 10 END cap.' -ModePool 'Challenge' -RequiredDifficulty @('Hard')),
        (New-LWAchievementDefinition -Id 'veteran_of_sommerlund' -Name 'Veteran of Sommerlund' -Category 'Legend' -Description 'Complete a book on Veteran.' -ModePool 'Challenge' -RequiredDifficulty @('Veteran')),
        (New-LWAchievementDefinition -Id 'by_the_text' -Name 'By the Text' -Category 'Legend' -Description 'Complete a Veteran book without ever using unauthorized Sommerswerd power.' -ModePool 'Challenge' -RequiredDifficulty @('Veteran')),
        (New-LWAchievementDefinition -Id 'only_one_life' -Name 'Only One Life' -Category 'Legend' -Description 'Complete a book with Permadeath enabled.' -ModePool 'Challenge' -RequiresPermadeath:$true),
        (New-LWAchievementDefinition -Id 'mortal_wolf' -Name 'Mortal Wolf' -Category 'Legend' -Description 'Complete a Hard or Veteran book with Permadeath enabled.' -ModePool 'Challenge' -RequiredDifficulty @('Hard', 'Veteran') -RequiresPermadeath:$true),
        (New-LWAchievementDefinition -Id 'aim_for_the_bushes' -Name 'Aim for the Bushes' -Category 'Journey' -Description 'Reach section 7 in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'found_the_clubhouse' -Name 'Found the Clubhouse' -Category 'Journey' -Description 'Reach section 13 in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'kill_the_mad_butcher' -Name 'Kill the Mad Butcher' -Category 'Journey' -Description 'Defeat the Mad Butcher in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'whats_in_the_box_book1' -Name 'What''s in the Box?' -Category 'Journey' -Description 'Claim the Silver Key from the box in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'use_the_force' -Name 'Use the Force' -Category 'Journey' -Description 'Take the hidden path from section 131 to 302 in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'straight_to_the_throne' -Name 'Straight to the Throne' -Category 'Journey' -Description 'Finish Book 1 through the palace courtyard route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'royal_recovery' -Name 'Royal Recovery' -Category 'Journey' -Description 'Finish Book 1 through the recovery route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'the_back_way_in' -Name 'The Back Way In' -Category 'Journey' -Description 'Finish Book 1 through the Guildhall secret passage route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'open_sesame' -Name 'Open Sesame' -Category 'Journey' -Description 'Use the Golden Key route in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'hot_hands' -Name 'Hot Hands' -Category 'Journey' -Description 'Claim a Vordak Gem in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'star_of_toran' -Name 'Star of Toran' -Category 'Journey' -Description 'Claim the Crystal Star Pendant in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'field_medic' -Name 'Field Medic' -Category 'Journey' -Description 'Use Healing to save the wounded soldier in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'found_the_sommerswerd' -Name 'Found the Sommerswerd' -Category 'Journey' -Description 'Claim the Sommerswerd in Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'you_have_chosen_wisely' -Name 'You Have Chosen Wisely' -Category 'Journey' -Description 'Defeat the Priest in section 158 of Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'neo_link' -Name 'Neo Link' -Category 'Journey' -Description 'Defeat Ganon + Dorier in section 270 of Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'by_a_thread' -Name 'By a Thread' -Category 'Journey' -Description 'Finish Book 2 through the rope-swing route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'skyfall' -Name 'Skyfall' -Category 'Journey' -Description 'Finish Book 2 through the Sommerswerd-and-Kraan skyfall route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'fight_through_the_smoke' -Name 'Fight Through the Smoke' -Category 'Journey' -Description 'Finish Book 2 by fighting back through the flagship deck.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'storm_tossed' -Name 'Storm-Tossed' -Category 'Journey' -Description 'Reach section 337 and still complete Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'seal_of_approval' -Name 'Seal of Approval' -Category 'Journey' -Description 'Reach the king''s audience route and claim the Sommerswerd in Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'papers_please' -Name 'Papers, Please' -Category 'Journey' -Description 'Trust forged access papers in Book 2 and pay the price.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'snakes_why' -Name 'Snakes, Why Did It Have to Be Snakes?' -Category 'Journey' -Description 'Reach the Javek ledge in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cliffhanger' -Name 'Cliffhanger' -Category 'Journey' -Description 'Witness Dyce''s fatal fall in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'whats_in_the_box' -Name 'What''s in the Box?' -Category 'Journey' -Description 'Claim the Diamond from the bone box in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'snowblind' -Name 'Snowblind' -Category 'Journey' -Description 'Suffer snow-blindness in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'you_touched_it_with_your_hands' -Name 'You Touched It With Your Hands?!' -Category 'Journey' -Description 'Claim the Ornate Silver Key as a Special Item in section 280 of Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'lucky_button_theory' -Name 'Lucky Button Theory' -Category 'Journey' -Description 'Press the right button sequence and reach section 102 in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'well_it_worked_once' -Name 'Well, It Worked Once' -Category 'Journey' -Description 'Reach section 65 after already reaching section 102 in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cellfish' -Name 'Cellfish' -Category 'Journey' -Description 'Leave both prisoners to their fate in Book 3 by taking the cold path from section 13 to 254 and then walking away again at section 276.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'loi_kymar_lives' -Name 'Loi-Kymar Lives' -Category 'Journey' -Description 'Rescue Loi-Kymar and still complete Book 3.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'puppet_master' -Name 'Puppet Master' -Category 'Journey' -Description 'Finish Book 3 by turning the Effigy path against Vonotar.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'sun_on_the_ice' -Name 'Sun on the Ice' -Category 'Journey' -Description 'Finish Book 3 through the Sommerswerd endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'lucky_break' -Name 'Lucky Break' -Category 'Journey' -Description 'Finish Book 3 through the no-Effigy, no-Sommerswerd lucky route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'too_slow' -Name 'Too Slow' -Category 'Journey' -Description 'Watch the Book 3 endgame collapse after taking too long to stop Vonotar.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'book_four_complete' -Name 'Book Four Complete' -Category 'Journey' -Description 'Complete Book 4.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'sun_below_the_earth' -Name 'Sun Below The Earth' -Category 'Journey' -Description 'Finish Book 4 through the Sommerswerd endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'blessed_be_the_throw' -Name 'Blessed Be The Throw' -Category 'Journey' -Description 'Finish Book 4 through the Holy Water route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'steel_against_shadow' -Name 'Steel Against Shadow' -Category 'Journey' -Description 'Finish Book 4 through the direct Barraka duel route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'badge_of_office' -Name 'Badge of Office' -Category 'Journey' -Description 'Use the Badge of Rank trust route in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'wearing_the_enemys_colors' -Name 'Wearing the Enemy''s Colors' -Category 'Journey' -Description 'Claim the Onyx Medallion and use it to bluff your way deeper in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'read_the_signs' -Name 'Read the Signs' -Category 'Journey' -Description 'Use the Scroll route in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'return_to_sender' -Name 'Return to Sender' -Category 'Journey' -Description 'Claim Captain D''Val''s Sword and return it in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'deep_pockets_poor_timing' -Name 'Deep Pockets, Poor Timing' -Category 'Journey' -Description 'Lose your Backpack in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'bagless_but_breathing' -Name 'Bagless but Breathing' -Category 'Journey' -Description 'Lose your Backpack and recover a new one in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'shovel_ready' -Name 'Shovel Ready' -Category 'Journey' -Description 'Take a two-slot mining tool in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'light_in_the_depths' -Name 'Light in the Depths' -Category 'Journey' -Description 'Follow the lit mine path in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'chasm_of_doom' -Name 'Chasm of Doom' -Category 'Journey' -Description 'Reach the signature failure ending at section 347 in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'washed_away' -Name 'Washed Away' -Category 'Journey' -Description 'Survive the Book 4 waterfall route that costs you your Backpack.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'book_five_complete' -Name 'Book Five Complete' -Category 'Journey' -Description 'Complete Book 5.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'kai_master' -Name 'Kai Master' -Category 'Legend' -Description 'Complete the full Kai sequence through Book 5.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'book_six_complete' -Name 'Book Six Complete' -Category 'Journey' -Description 'Complete Book 6.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'magnakai_rising' -Name 'Magnakai Rising' -Category 'Legend' -Description 'Carry a single character through the full Books 1-6 sequence.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'apothecarys_answer' -Name 'Apothecary''s Answer' -Category 'Journey' -Description 'Claim the Oede Herb and cure Limbdeath in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'prison_break' -Name 'Prison Break' -Category 'Journey' -Description 'Recover your confiscated gear in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'talons_tamed' -Name 'Talons Tamed' -Category 'Journey' -Description 'Mount the Itikar without having to subdue it in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'star_guided' -Name 'Star-Guided' -Category 'Journey' -Description 'Use the Crystal Star Pendant route in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'name_the_lost' -Name 'Name the Lost' -Category 'Journey' -Description 'Learn Soushilla''s name and ask for her in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'shadow_on_the_sand' -Name 'Shadow on the Sand' -Category 'Journey' -Description 'Finish Book 5 through the glowing-stone endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'face_to_face_with_haakon' -Name 'Face to Face with Haakon' -Category 'Journey' -Description 'Finish Book 5 through the Haakon duel route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'jump_the_wagons' -Name 'Jump the Wagons' -Category 'Journey' -Description 'Clear the wagon jump route in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'water_bearer' -Name 'Water Bearer' -Category 'Journey' -Description 'Keep Taunor Water stored for later use in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'tekaro_cartographer' -Name 'Tekaro Cartographer' -Category 'Journey' -Description 'Claim a Map of Tekaro in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'key_to_varetta' -Name 'Key to Varetta' -Category 'Journey' -Description 'Claim the Small Silver Key in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'silver_oak_prize' -Name 'Silver Oak Prize' -Category 'Journey' -Description 'Win the Silver Bow of Duadon in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cess_to_enter' -Name 'Cess to Enter' -Category 'Journey' -Description 'Pocket a valid Cess for Amory in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cold_comfort' -Name 'Cold Comfort' -Category 'Journey' -Description 'Let Nexus save you from the frozen river in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'mind_over_malice_book6' -Name 'Mind Over Malice' -Category 'Journey' -Description 'Have Psi-screen block the cursed Mindforce assault in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true)
    )

    return @($script:LWAchievementDefinitionsCache)
}

function Get-LWPhaseTwoAchievementPlans {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @(
        [pscustomobject]@{ Name = 'Eyes of the Kai'; Description = 'Hidden story achievement for discovering secret sections with the right discipline or clue.' },
        [pscustomobject]@{ Name = 'Kai Specialist'; Description = 'Discipline-specific achievement for solving a situation in a uniquely Kai way.' },
        [pscustomobject]@{ Name = 'Rune-Reader'; Description = 'Hidden story achievement for following a clue chain across books and sections without losing the thread.' }
    )
}

function Ensure-LWAchievementState {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWPropertyExists -Object $State -Name 'Achievements') -or $null -eq $State.Achievements) {
        $State | Add-Member -Force -NotePropertyName Achievements -NotePropertyValue (New-LWAchievementState)
    }

    $targetSchemaVersion = Get-LWAchievementStateSchemaVersion
    $schemaVersion = 0
    if ((Test-LWPropertyExists -Object $State.Achievements -Name 'SchemaVersion') -and $null -ne $State.Achievements.SchemaVersion) {
        $schemaVersion = [int]$State.Achievements.SchemaVersion
    }

    if ($schemaVersion -ge $targetSchemaVersion -and
        (Test-LWPropertyExists -Object $State.Achievements -Name 'Unlocked') -and $null -ne $State.Achievements.Unlocked -and
        (Test-LWPropertyExists -Object $State.Achievements -Name 'SeenNotifications') -and $null -ne $State.Achievements.SeenNotifications -and
        (Test-LWPropertyExists -Object $State.Achievements -Name 'ProgressFlags') -and $null -ne $State.Achievements.ProgressFlags -and
        (Test-LWPropertyExists -Object $State.Achievements -Name 'StoryFlags') -and $null -ne $State.Achievements.StoryFlags -and
        (Test-LWPropertyExists -Object $State.Achievements -Name 'LoadBackfillVersion') -and $null -ne $State.Achievements.LoadBackfillVersion) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'Unlocked') -or $null -eq $State.Achievements.Unlocked) {
        $State.Achievements | Add-Member -Force -NotePropertyName Unlocked -NotePropertyValue @()
    }
    else {
        $State.Achievements.Unlocked = @($State.Achievements.Unlocked)
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'SeenNotifications') -or $null -eq $State.Achievements.SeenNotifications) {
        $State.Achievements | Add-Member -Force -NotePropertyName SeenNotifications -NotePropertyValue @()
    }
    else {
        $State.Achievements.SeenNotifications = @($State.Achievements.SeenNotifications | ForEach-Object { [string]$_ })
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'ProgressFlags') -or $null -eq $State.Achievements.ProgressFlags) {
        $State.Achievements | Add-Member -Force -NotePropertyName ProgressFlags -NotePropertyValue (New-LWAchievementProgressFlags)
    }

    foreach ($propertyName in @('PerfectVictories', 'BrinkVictories', 'AgainstOddsVictories')) {
        if (-not (Test-LWPropertyExists -Object $State.Achievements.ProgressFlags -Name $propertyName) -or $null -eq $State.Achievements.ProgressFlags.$propertyName) {
            $State.Achievements.ProgressFlags | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue 0
        }
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'StoryFlags') -or $null -eq $State.Achievements.StoryFlags) {
        $State.Achievements | Add-Member -Force -NotePropertyName StoryFlags -NotePropertyValue (New-LWStoryAchievementFlags)
    }

    foreach ($propertyName in @('Book1AimForTheBushesVisited', 'Book1ClubhouseFound', 'Book1SilverKeyClaimed', 'Book1UseTheForcePath', 'Book1StraightToTheThrone', 'Book1RoyalRecovery', 'Book1BackWayIn', 'Book1OpenSesameRoute', 'Book1HotHandsClaimed', 'Book1StarOfToranClaimed', 'Book1FieldMedicPath', 'Book1LaumspurClaimed', 'Book1VordakGem76Claimed', 'Book1VordakGem304Claimed', 'Book1VordakGemCurseTriggered', 'Book1Section61NoteAdded', 'Book1Section255SolnarisClaimed', 'Book2CoachTicketClaimed', 'Book2WhitePassClaimed', 'Book2RedPassClaimed', 'Book2PotentPotionClaimed', 'Book2MealOfLaumspurClaimed', 'Book2ForgedPapersBought', 'Book2Section106DamageApplied', 'Book2Section313Resolved', 'Book2Section337StormLossApplied', 'Book2SommerswerdClaimed', 'Book2ByAThreadRoute', 'Book2SkyfallRoute', 'Book2FightThroughTheSmokeRoute', 'Book2StormTossedSeen', 'Book2SealOfApprovalRoute', 'Book2PapersPleasePath', 'Book3SnakePitVisited', 'Book3CliffhangerSeen', 'Book3DiamondClaimed', 'Book3SnowblindSeen', 'Book3GrossKeyClaimed', 'Book3LuckyButtonTheorySeen', 'Book3WellItWorkedOnceSeen', 'Book3FirstCellAbandoned', 'Book3CellfishPathTaken', 'Book3LoiKymarRescued', 'Book3EffigyEndgameReached', 'Book3SommerswerdEndgameUsed', 'Book3LuckyEndgameUsed', 'Book3TooSlowFailureSeen', 'Book4Section12ResupplyHandled', 'Book4Section12MealsClaimed', 'Book4Section12RopeClaimed', 'Book4Section12PotionClaimed', 'Book4Section12SwordClaimed', 'Book4Section12SpearClaimed', 'Book4Section79SuppliesClaimed', 'Book4Section94LossApplied', 'Book4BadgeOfOfficePath', 'Book4OnyxMedallionClaimed', 'Book4Section117LightPath', 'Book4Section122MindAttackApplied', 'Book4Section123SuppliesClaimed', 'Book4Section158LossApplied', 'Book4Section167RecoveryClaimed', 'Book4BackpackLost', 'Book4BackpackRecovered', 'Book4WashedAway', 'Book4Section280GoldClaimed', 'Book4Section280MealClaimed', 'Book4Section280SwordClaimed', 'Book4CaptainSwordClaimed', 'Book4PotionOfRedLiquidClaimed', 'Book4ShovelReadyClaimed', 'Book4ScrollClaimed', 'Book4TorchesWillNotLight', 'Book4LightInTheDepths', 'Book4Section272LossApplied', 'Book4SteelAgainstShadowRoute', 'Book4BlessedBeTheThrowRoute', 'Book4ScrollRoute', 'Book4Section283HolyWaterApplied', 'Book4SunBelowTheEarthRoute', 'Book4OnyxBluffRoute', 'Book4Section322RestApplied', 'Book4ReturnToSenderPath', 'Book4ChasmOfDoomSeen', 'Book4DaggerOfVashnaClaimed', 'Book5Section278DamageApplied', 'Book5Section385ExplosionApplied', 'Book6Section004LossApplied', 'Book6Section035MealsRuined', 'Book6Section040GoldClaimed', 'Book6Section040WineClaimed', 'Book6Section040MirrorClaimed', 'Book6Section048GoldClaimed', 'Book6Section048MapClaimed', 'Book6Section049CessUsed', 'Book6Section065TaunorWaterResolved', 'Book6Section106TaunorWaterResolved', 'Book6Section109MapClaimed', 'Book6Section112TaunorWaterResolved', 'Book6Section158SilverKeyClaimed', 'Book6Section158QuarterstaffClaimed', 'Book6Section158MealsClaimed', 'Book6Section158MaceClaimed', 'Book6Section158WhistleClaimed', 'Book6Section158RopeClaimed', 'Book6Section158ShortSwordClaimed', 'Book6Section190TaunorWaterResolved', 'Book6Section207Handled', 'Book6Section232RoomPaid', 'Book6Section232MealDeducted', 'Book6Section246TaunorWaterResolved', 'Book6Section252SilverBowClaimed', 'Book6Section278DamageApplied', 'Book6Section282DamageApplied', 'Book6Section293SilverKeyUsed', 'Book6Section304CessClaimed', 'Book6Section306ColdDamageApplied', 'Book6Section306NexusProtected', 'Book6Section307Handled', 'Book6Section307NoMealLossApplied', 'Book6Section310DamageApplied', 'Book6Section313DamageApplied', 'Book6Section315MindforceApplied', 'Book6Section315MindforceLossApplied', 'Book6Section315MindforceBlocked', 'Book6Section322TollPaid', 'Book6Section348WarhammerLost', 'Book6JumpTheWagonsRoute', 'Book6TaunorWaterStored', 'Book6MapOfTekaroClaimed', 'Book6SmallSilverKeyClaimed', 'Book6SilverBowClaimed', 'Book6CessClaimed')) {
        if (-not (Test-LWPropertyExists -Object $State.Achievements.StoryFlags -Name $propertyName) -or $null -eq $State.Achievements.StoryFlags.$propertyName) {
            $State.Achievements.StoryFlags | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $false
        }
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'LoadBackfillVersion') -or $null -eq $State.Achievements.LoadBackfillVersion) {
        $State.Achievements | Add-Member -Force -NotePropertyName LoadBackfillVersion -NotePropertyValue 0
    }
    else {
        $State.Achievements.LoadBackfillVersion = [int]$State.Achievements.LoadBackfillVersion
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'SchemaVersion') -or $null -eq $State.Achievements.SchemaVersion) {
        $State.Achievements | Add-Member -Force -NotePropertyName SchemaVersion -NotePropertyValue $targetSchemaVersion
    }
    else {
        $State.Achievements.SchemaVersion = $targetSchemaVersion
    }
}

function Rebuild-LWStoryAchievementFlagsFromState {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $visitedSections = @()
    if ($null -ne $script:GameState.CurrentBookStats -and (Test-LWPropertyExists -Object $script:GameState.CurrentBookStats -Name 'VisitedSections') -and $null -ne $script:GameState.CurrentBookStats.VisitedSections) {
        $visitedSections = @($script:GameState.CurrentBookStats.VisitedSections | ForEach-Object { [int]$_ })
    }
    if ($null -ne $script:GameState.CurrentSection) {
        $visitedSections += [int]$script:GameState.CurrentSection
    }
    $visitedSections = @($visitedSections | Sort-Object -Unique)

    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Type 'special'))) {
        Set-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed'
    }

    if ([int]$script:GameState.Character.BookNumber -eq 1) {
        if ($visitedSections -contains 66) {
            Set-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone'
        }
        if ($visitedSections -contains 212) {
            Set-LWStoryAchievementFlag -Name 'Book1RoyalRecovery'
        }
        if ($visitedSections -contains 332) {
            Set-LWStoryAchievementFlag -Name 'Book1BackWayIn'
        }
        if ($visitedSections -contains 326) {
            Set-LWStoryAchievementFlag -Name 'Book1OpenSesameRoute'
        }
        if ($visitedSections -contains 216) {
            Set-LWStoryAchievementFlag -Name 'Book1FieldMedicPath'
        }
        if ($visitedSections -contains 76) {
            Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
            Set-LWStoryAchievementFlag -Name 'Book1VordakGem76Claimed'
        }
        if ($visitedSections -contains 304) {
            Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
            Set-LWStoryAchievementFlag -Name 'Book1VordakGem304Claimed'
        }
        if ($visitedSections -contains 113) {
            Set-LWStoryAchievementFlag -Name 'Book1LaumspurClaimed'
        }
        if ($visitedSections -contains 236) {
            Set-LWStoryAchievementFlag -Name 'Book1VordakGemCurseTriggered'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCrystalStarPendantItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 2) {
        if ($visitedSections -contains 10) {
            Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed'
        }
        if ($visitedSections -contains 40) {
            Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed'
        }
        if ($visitedSections -contains 103) {
            Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed'
        }
        if ($visitedSections -contains 105) {
            Set-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute'
        }
        if ($visitedSections -contains 109) {
            Set-LWStoryAchievementFlag -Name 'Book2SkyfallRoute'
        }
        if ($visitedSections -contains 126 -and (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought')) {
            Set-LWStoryAchievementFlag -Name 'Book2PapersPleasePath'
        }
        if ($visitedSections -contains 142) {
            Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed'
        }
        if ($visitedSections -contains 185) {
            Set-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute'
        }
        if ($visitedSections -contains 196) {
            Set-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute'
        }
        if ($visitedSections -contains 263) {
            Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed'
        }
        if ($visitedSections -contains 337) {
            Set-LWStoryAchievementFlag -Name 'Book2StormTossedSeen'
            Set-LWStoryAchievementFlag -Name 'Book2Section337StormLossApplied'
        }
        if ($visitedSections -contains 313) {
            Set-LWStoryAchievementFlag -Name 'Book2Section313Resolved'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 3) {
        if ($visitedSections -contains 56) {
            Set-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued'
        }
        if ($visitedSections -contains 34) {
            Set-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached'
        }
        if ($visitedSections -contains 213) {
            Set-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed'
        }
        if ($visitedSections -contains 58) {
            Set-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed'
        }
        if ($visitedSections -contains 324) {
            Set-LWStoryAchievementFlag -Name 'Book3TooSlowFailureSeen'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 4) {
        if ($visitedSections -contains 22) {
            Set-LWStoryAchievementFlag -Name 'Book4LightInTheDepths'
            Set-LWStoryAchievementFlag -Name 'Book4Section117LightPath'
        }
        if ($visitedSections -contains 94) {
            Set-LWStoryAchievementFlag -Name 'Book4BackpackLost'
            Set-LWStoryAchievementFlag -Name 'Book4Section94LossApplied'
        }
        if ($visitedSections -contains 158) {
            Set-LWStoryAchievementFlag -Name 'Book4BackpackLost'
            Set-LWStoryAchievementFlag -Name 'Book4Section158LossApplied'
            Set-LWStoryAchievementFlag -Name 'Book4WashedAway'
        }
        if ($visitedSections -contains 167) {
            Set-LWStoryAchievementFlag -Name 'Book4BackpackRecovered'
            Set-LWStoryAchievementFlag -Name 'Book4Section167RecoveryClaimed'
        }
        if ($visitedSections -contains 195) {
            Set-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath'
        }
        if ($visitedSections -contains 279) {
            Set-LWStoryAchievementFlag -Name 'Book4ScrollRoute'
        }
        if ($visitedSections -contains 283) {
            Set-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute'
            Set-LWStoryAchievementFlag -Name 'Book4Section283HolyWaterApplied'
        }
        if ($visitedSections -contains 305) {
            Set-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute'
        }
        if ($visitedSections -contains 325) {
            Set-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute'
        }
        if ($visitedSections -contains 347) {
            Set-LWStoryAchievementFlag -Name 'Book4ChasmOfDoomSeen'
        }
        if ($visitedSections -contains 122) {
            Set-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute'
            Set-LWStoryAchievementFlag -Name 'Book4Section122MindAttackApplied'
        }
        if ($visitedSections -contains 322) {
            Set-LWStoryAchievementFlag -Name 'Book4Section322RestApplied'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWOnyxMedallionItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWScrollItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book4ScrollClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWDaggerOfVashnaItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMiningToolItemNames) -Type 'backpack'))) {
            Set-LWStoryAchievementFlag -Name 'Book4ShovelReadyClaimed'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 5) {
        if ($visitedSections -contains 2) {
            Set-LWStoryAchievementFlag -Name 'Book5OedeClaimed'
            Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
        }
        if ($visitedSections -contains 14) {
            Set-LWStoryAchievementFlag -Name 'Book5PrisonBreak'
        }
        if (@(308, 319) | Where-Object { $visitedSections -contains $_ }) {
            Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed'
        }
        if ($visitedSections -contains 336) {
            Set-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute'
        }
        if ($visitedSections -contains 356) {
            Set-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard'
        }
        if ($visitedSections -contains 307) {
            Set-LWStoryAchievementFlag -Name 'Book5SoushillaAsked'
        }
        if ($visitedSections -contains 268) {
            Set-LWStoryAchievementFlag -Name 'Book5BanishmentRoute'
        }
        if ($visitedSections -contains 353) {
            Set-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWBookOfMagnakaiItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book5BookOfMagnakaiClaimed'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -ge 6) {
        if ($visitedSections -contains 49) {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section049CessUsed')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section049CessUsed'
            }

            [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWCessItemNames) -Types @('special'))
        }
        if ($visitedSections -contains 4) { Set-LWStoryAchievementFlag -Name 'Book6Section004LossApplied' }
        if ($visitedSections -contains 35) { Set-LWStoryAchievementFlag -Name 'Book6Section035MealsRuined' }
        if ($visitedSections -contains 65) { Set-LWStoryAchievementFlag -Name 'Book6Section065TaunorWaterResolved' }
        if ($visitedSections -contains 106) { Set-LWStoryAchievementFlag -Name 'Book6Section106TaunorWaterResolved' }
        if ($visitedSections -contains 112) { Set-LWStoryAchievementFlag -Name 'Book6Section112TaunorWaterResolved' }
        if ($visitedSections -contains 158) {
            Set-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed'
            Set-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed'
        }
        if ($visitedSections -contains 190) { Set-LWStoryAchievementFlag -Name 'Book6Section190TaunorWaterResolved' }
        if ($visitedSections -contains 232) { Set-LWStoryAchievementFlag -Name 'Book6Section232RoomPaid' }
        if ($visitedSections -contains 246) { Set-LWStoryAchievementFlag -Name 'Book6Section246TaunorWaterResolved' }
        if ($visitedSections -contains 252) {
            Set-LWStoryAchievementFlag -Name 'Book6Section252SilverBowClaimed'
            Set-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed'
        }
        if ($visitedSections -contains 278) {
            Set-LWStoryAchievementFlag -Name 'Book6Section278DamageApplied'
        }
        if ($visitedSections -contains 282) {
            Set-LWStoryAchievementFlag -Name 'Book6Section282DamageApplied'
        }
        if ($visitedSections -contains 274) {
            Set-LWStoryAchievementFlag -Name 'Book6JumpTheWagonsRoute'
        }
        if ($visitedSections -contains 293) {
            Set-LWStoryAchievementFlag -Name 'Book6Section293SilverKeyUsed'
        }
        if ($visitedSections -contains 304) {
            Set-LWStoryAchievementFlag -Name 'Book6Section304CessClaimed'
            Set-LWStoryAchievementFlag -Name 'Book6CessClaimed'
        }
        if ($visitedSections -contains 306 -and (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
            Set-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected'
        }
        if ($visitedSections -contains 307) {
            Set-LWStoryAchievementFlag -Name 'Book6Section307Handled'
        }
        if ($visitedSections -contains 310) {
            Set-LWStoryAchievementFlag -Name 'Book6Section310DamageApplied'
        }
        if ($visitedSections -contains 313) {
            Set-LWStoryAchievementFlag -Name 'Book6Section313DamageApplied'
        }
        if ($visitedSections -contains 315) {
            Set-LWStoryAchievementFlag -Name 'Book6Section315MindforceApplied'
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-screen') {
                Set-LWStoryAchievementFlag -Name 'Book6Section315MindforceBlocked'
            }
        }
        if ($visitedSections -contains 348) {
            Set-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost'
        }
        if ($null -ne (Find-LWStateInventoryItemLocation -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Types @('herbpouch', 'backpack'))) {
            Set-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMapOfTekaroItemNames) -Type 'backpack'))) {
            Set-LWStoryAchievementFlag -Name 'Book6MapOfTekaroClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSmallSilverKeyItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCessItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book6CessClaimed'
        }
    }
}

function Test-LWStoryAchievementFlag {
    param([Parameter(Mandatory = $true)][string]$Name)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return $false
    }

    Ensure-LWAchievementState -State $script:GameState
    if (-not (Test-LWPropertyExists -Object $script:GameState.Achievements.StoryFlags -Name $Name)) {
        return $false
    }

    return [bool]$script:GameState.Achievements.StoryFlags.$Name
}

function Set-LWStoryAchievementFlag {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [bool]$Value = $true
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    if (-not (Test-LWPropertyExists -Object $script:GameState.Achievements.StoryFlags -Name $Name)) {
        $script:GameState.Achievements.StoryFlags | Add-Member -Force -NotePropertyName $Name -NotePropertyValue ([bool]$Value)
        return
    }

    $script:GameState.Achievements.StoryFlags.$Name = [bool]$Value
}

function Test-LWAchievementLoadBackfillCurrent {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State) {
        return $false
    }

    Ensure-LWAchievementState -State $State
    return ([int]$State.Achievements.LoadBackfillVersion -ge (Get-LWAchievementLoadBackfillVersion))
}

function Set-LWAchievementLoadBackfillCurrent {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State) {
        return
    }

    Ensure-LWAchievementState -State $State
    $State.Achievements.LoadBackfillVersion = (Get-LWAchievementLoadBackfillVersion)
}

function Test-LWAchievementStoryFlag {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$EvaluationContext = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -ne $EvaluationContext -and
        (Test-LWPropertyExists -Object $EvaluationContext -Name 'StoryFlags') -and
        $EvaluationContext.StoryFlags -is [System.Collections.IDictionary]) {
        return [bool]$EvaluationContext.StoryFlags[$Name]
    }

    return (Test-LWStoryAchievementFlag -Name $Name)
}

function Register-LWStoryInventoryAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    switch ([int]$script:GameState.Character.BookNumber) {
        1 {
            if (@('backpack', 'special') -contains $Type -and [int]$script:GameState.CurrentSection -eq 124 -and [string]$Name -match 'silver key') {
                Set-LWStoryAchievementFlag -Name 'Book1SilverKeyClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 76 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWVordakGemItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
                Set-LWStoryAchievementFlag -Name 'Book1VordakGem76Claimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 304 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWVordakGemItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
                Set-LWStoryAchievementFlag -Name 'Book1VordakGem304Claimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 349 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCrystalStarPendantItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed'
            }
        }
        2 {
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 79 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSommerswerdItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 10 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCoachTicketItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 142 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWWhitePassItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 263 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWRedPassItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 40 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWPotentHealingPotionItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 103 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMealOfLaumspurItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed'
            }
        }
        3 {
            if (@('backpack', 'special') -contains $Type -and [int]$script:GameState.CurrentSection -eq 218 -and [string]$Name -match 'diamond') {
                Set-LWStoryAchievementFlag -Name 'Book3DiamondClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 280 -and [string]$Name -match 'ornate silver key') {
                Set-LWStoryAchievementFlag -Name 'Book3GrossKeyClaimed'
            }
        }
        4 {
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 10 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOnyxMedallionItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 84 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWScrollItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4ScrollClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 350 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWDaggerOfVashnaItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed'
            }
            if ($Type -eq 'weapon' -and [int]$script:GameState.CurrentSection -eq 222 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCaptainDValSwordWeaponNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 268 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWPotionOfRedLiquidItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4PotionOfRedLiquidClaimed'
            }
            if ($Type -eq 'backpack' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMiningToolItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4ShovelReadyClaimed'
            }
        }
        5 {
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 2 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOedeHerbItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book5OedeClaimed'
                Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
            }
            if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBookOfMagnakaiItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book5BookOfMagnakaiClaimed'
            }
            if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBlackCrystalCubeItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute'
            }
        }
    }
}

function Test-LWStateHasTorch {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWTorchItemNames) -Type 'backpack')))
}

function Get-LWAchievementDefinitionById {
    param([Parameter(Mandatory = $true)][string]$Id)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if ([string]$definition.Id -eq $Id) {
            return $definition
        }
    }

    return $null
}

function Test-LWAchievementAvailableInCurrentMode {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [object]$State = $script:GameState
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return $true
    }

    $allowedPools = @(Get-LWModeAchievementPools -State $State)
    if ($allowedPools -notcontains [string]$Definition.ModePool) {
        return $false
    }

    $requiredDifficulty = @()
    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiredDifficulty') -and $null -ne $Definition.RequiredDifficulty) {
        $requiredDifficulty = @($Definition.RequiredDifficulty | ForEach-Object { Get-LWNormalizedDifficultyName -Difficulty ([string]$_) })
    }
    if ($requiredDifficulty.Count -gt 0 -and ($requiredDifficulty -notcontains (Get-LWCurrentDifficulty -State $State))) {
        return $false
    }

    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiresPermadeath') -and [bool]$Definition.RequiresPermadeath -and -not (Test-LWPermadeathEnabled -State $State)) {
        return $false
    }

    if ([string]$Definition.ModePool -eq 'Challenge' -and (Test-LWRunTampered -State $State)) {
        return $false
    }

    return $true
}

function Get-LWAchievementModeAvailabilitySnapshot {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State) {
        return [pscustomobject]@{
            Key           = 'no-state'
            Definitions   = @()
            AvailableById = @{}
        }
    }

    $runId = if ($null -ne $State.Run -and -not [string]::IsNullOrWhiteSpace([string]$State.Run.Id)) { [string]$State.Run.Id } else { 'no-run' }
    $difficulty = Get-LWCurrentDifficulty -State $State
    $permadeath = if (Test-LWPermadeathEnabled -State $State) { '1' } else { '0' }
    $integrity = if ($null -ne $State.Run -and -not [string]::IsNullOrWhiteSpace([string]$State.Run.IntegrityState)) { [string]$State.Run.IntegrityState } else { 'unknown' }
    $cacheKey = '{0}|{1}|{2}|{3}' -f $runId, $difficulty, $permadeath, $integrity

    if ($null -ne $script:LWAchievementModeAvailabilityCache -and
        (Test-LWPropertyExists -Object $script:LWAchievementModeAvailabilityCache -Name 'Key') -and
        [string]$script:LWAchievementModeAvailabilityCache.Key -eq $cacheKey) {
        return $script:LWAchievementModeAvailabilityCache
    }

    $availableDefinitions = @()
    $availableById = @{}
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition -State $State)) {
            continue
        }

        $availableDefinitions += $definition
        $availableById[[string]$definition.Id] = $true
    }

    $script:LWAchievementModeAvailabilityCache = [pscustomobject]@{
        Key           = $cacheKey
        Definitions   = @($availableDefinitions)
        AvailableById = $availableById
    }
    return $script:LWAchievementModeAvailabilityCache
}

function Get-LWAchievementAvailabilityReason {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [object]$State = $script:GameState
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return ''
    }

    $allowedPools = @(Get-LWModeAchievementPools -State $State)
    if ($allowedPools -notcontains [string]$Definition.ModePool) {
        return ("disabled by {0} mode" -f (Get-LWCurrentDifficulty -State $State))
    }

    $requiredDifficulty = @()
    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiredDifficulty') -and $null -ne $Definition.RequiredDifficulty) {
        $requiredDifficulty = @($Definition.RequiredDifficulty | ForEach-Object { Get-LWNormalizedDifficultyName -Difficulty ([string]$_) })
    }
    if ($requiredDifficulty.Count -gt 0 -and ($requiredDifficulty -notcontains (Get-LWCurrentDifficulty -State $State))) {
        return ("requires {0}" -f ($requiredDifficulty -join ' or '))
    }

    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiresPermadeath') -and [bool]$Definition.RequiresPermadeath -and -not (Test-LWPermadeathEnabled -State $State)) {
        return 'requires Permadeath'
    }

    if ([string]$Definition.ModePool -eq 'Challenge' -and (Test-LWRunTampered -State $State)) {
        return 'disabled by tampered run'
    }

    return ''
}

function Get-LWAchievementDisplayNameById {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$DefaultName
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ([string]$Id) {
        'whats_in_the_box' {
            if (Test-LWAchievementUnlocked -Id 'whats_in_the_box_book1') {
                return 'What''s also in the Box?'
            }
        }
    }

    return $DefaultName
}

function Get-LWAchievementLockedDisplayName {
    param([Parameter(Mandatory = $true)][object]$Definition)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ((Test-LWPropertyExists -Object $Definition -Name 'Hidden') -and [bool]$Definition.Hidden -and -not (Test-LWAchievementUnlocked -Id ([string]$Definition.Id))) {
        return '???'
    }

    return (Get-LWAchievementDisplayNameById -Id ([string]$Definition.Id) -DefaultName ([string]$Definition.Name))
}

function Get-LWAchievementUnlockedDisplayName {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Get-LWAchievementDisplayNameById -Id ([string]$Entry.Id) -DefaultName ([string]$Entry.Name))
}

function Get-LWAchievementLockedDisplayDescription {
    param([Parameter(Mandatory = $true)][object]$Definition)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ((Test-LWPropertyExists -Object $Definition -Name 'Hidden') -and [bool]$Definition.Hidden -and -not (Test-LWAchievementUnlocked -Id ([string]$Definition.Id))) {
        return 'Hidden story achievement.'
    }

    return [string]$Definition.Description
}

function Get-LWAchievementEligibleCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return 0
    }

    return (Get-LWAchievementDisplayCounts).EligibleCount
}

function Get-LWAchievementEligibleUnlockedCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return 0
    }

    return (Get-LWAchievementDisplayCounts).EligibleUnlockedCount
}

function Get-LWAchievementDisplayCounts {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return [pscustomobject]@{
            EligibleCount         = 0
            EligibleUnlockedCount = 0
        }
    }

    Ensure-LWAchievementState -State $script:GameState
    $runId = if ($null -ne $script:GameState.Run -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.Id)) { [string]$script:GameState.Run.Id } else { 'no-run' }
    $difficulty = Get-LWCurrentDifficulty
    $permadeath = if (Test-LWPermadeathEnabled) { '1' } else { '0' }
    $integrity = if ($null -ne $script:GameState.Run -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityState)) { [string]$script:GameState.Run.IntegrityState } else { 'unknown' }
    $unlockedCount = @($script:GameState.Achievements.Unlocked).Count
    $cacheKey = '{0}|{1}|{2}|{3}|{4}' -f $runId, $difficulty, $permadeath, $integrity, $unlockedCount

    if ($null -ne $script:LWAchievementDisplayCountsCache -and
        (Test-LWPropertyExists -Object $script:LWAchievementDisplayCountsCache -Name 'Key') -and
        [string]$script:LWAchievementDisplayCountsCache.Key -eq $cacheKey) {
        return $script:LWAchievementDisplayCountsCache
    }

    $availability = Get-LWAchievementModeAvailabilitySnapshot -State $script:GameState
    $eligibleCount = @($availability.Definitions).Count
    $eligibleUnlockedCount = 0
    foreach ($definition in @($availability.Definitions)) {
        if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
            $eligibleUnlockedCount++
        }
    }

    $script:LWAchievementDisplayCountsCache = [pscustomobject]@{
        Key                   = $cacheKey
        EligibleCount         = $eligibleCount
        EligibleUnlockedCount = $eligibleUnlockedCount
    }

    return $script:LWAchievementDisplayCountsCache
}

function Get-LWRunCombatEntries {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return @()
    }

    return @($script:GameState.History)
}

function Get-LWRunVictoryEntries {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @(Get-LWRunCombatEntries | Where-Object { @('Victory', 'Knockout') -contains [string]$_.Outcome })
}

function Get-LWRunTotalRounds {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $total = 0
    foreach ($entry in @(Get-LWRunCombatEntries)) {
        if ((Test-LWPropertyExists -Object $entry -Name 'RoundCount') -and $null -ne $entry.RoundCount) {
            $total += [int]$entry.RoundCount
        }
    }

    return $total
}

function Get-LWAllAchievementBookSummaries {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return @()
    }

    $summaries = @($script:GameState.BookHistory)
    $currentSummary = Get-LWLiveBookStatsSummary
    if ($null -ne $currentSummary) {
        $summaries += $currentSummary
    }

    return @($summaries)
}

function Get-LWCompletedAchievementBookSummaries {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return @()
    }

    return @($script:GameState.BookHistory)
}

function Get-LWCombatEntryPlayerLossTotal {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $total = 0
    if ((Test-LWPropertyExists -Object $Entry -Name 'Log') -and $null -ne $Entry.Log) {
        foreach ($round in @($Entry.Log)) {
            if ($null -ne $round -and (Test-LWPropertyExists -Object $round -Name 'PlayerLoss') -and $null -ne $round.PlayerLoss) {
                $total += [int]$round.PlayerLoss
            }
        }
    }

    return $total
}

function Rebuild-LWAchievementProgressFlags {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $flags = $script:GameState.Achievements.ProgressFlags
    $flags.PerfectVictories = 0
    $flags.BrinkVictories = 0
    $flags.AgainstOddsVictories = 0

    foreach ($entry in @(Get-LWRunVictoryEntries)) {
        if ((Get-LWCombatEntryPlayerLossTotal -Entry $entry) -le 0) {
            $flags.PerfectVictories = [int]$flags.PerfectVictories + 1
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'PlayerEnd') -and $null -ne $entry.PlayerEnd -and [int]$entry.PlayerEnd -eq 1) {
            $flags.BrinkVictories = [int]$flags.BrinkVictories + 1
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'CombatRatio') -and $null -ne $entry.CombatRatio -and [int]$entry.CombatRatio -le 0) {
            $flags.AgainstOddsVictories = [int]$flags.AgainstOddsVictories + 1
        }
    }
}

function Update-LWAchievementProgressFlagsFromSummary {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or @('Victory', 'Knockout') -notcontains [string]$Summary.Outcome) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $flags = $script:GameState.Achievements.ProgressFlags

    if ((Get-LWCombatEntryPlayerLossTotal -Entry $Summary) -le 0) {
        $flags.PerfectVictories = [int]$flags.PerfectVictories + 1
    }
    if ((Test-LWPropertyExists -Object $Summary -Name 'PlayerEnd') -and $null -ne $Summary.PlayerEnd -and [int]$Summary.PlayerEnd -eq 1) {
        $flags.BrinkVictories = [int]$flags.BrinkVictories + 1
    }
    if ((Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') -and $null -ne $Summary.CombatRatio -and [int]$Summary.CombatRatio -le 0) {
        $flags.AgainstOddsVictories = [int]$flags.AgainstOddsVictories + 1
    }
}

function New-LWAchievementDerivedMetrics {
    param(
        [object[]]$RunEntries = @(),
        [object[]]$RunVictories = @(),
        [object[]]$BookSummaries = @(),
        [object[]]$CompletedBookSummaries = @()
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)

    $metrics = [ordered]@{
        RunVictoryCount                 = @($RunVictories).Count
        OneRoundVictoryCount            = 0
        MindblastVictoryCount           = 0
        MaxEnemyCombatSkillVictory      = 0
        MaxEnemyEnduranceVictory        = 0
        MaxWeaponVictoryCount           = 0
        TotalRounds                     = 0
        LongFightCount                  = 0
        EasyPickingsCount               = 0
        UndeadSommerswerdVictoryCount   = 0
        Book1MadButcherVictory          = $false
        Book2Priest158Victory           = $false
        Book2NeoLinkVictory             = $false
        MaxSectionsVisited              = 0
        MaxVictoriesPerBook             = 0
        HasCompletedNoRewinds           = $false
        HasCompletedNoDeaths            = $false
        HasCompletedNoDefeats           = $false
        HasCompletedHard                = $false
        HasCompletedVeteran             = $false
        HasCompletedPermadeath          = $false
        HasCompletedPermadeathHardVet   = $false
    }

    $weaponVictoryCounts = @{}
    foreach ($entry in @($RunEntries)) {
        if ($null -eq $entry) {
            continue
        }

        if ((Test-LWPropertyExists -Object $entry -Name 'RoundCount') -and $null -ne $entry.RoundCount) {
            $roundCount = [int]$entry.RoundCount
            $metrics.TotalRounds += $roundCount
            if ($roundCount -ge 5) {
                $metrics.LongFightCount = [int]$metrics.LongFightCount + 1
            }
        }
    }

    foreach ($entry in @($RunVictories)) {
        if ($null -eq $entry) {
            continue
        }

        $bookNumber = Get-LWCombatEntryBookNumber -Entry $entry
        $enemyName = if (Test-LWPropertyExists -Object $entry -Name 'EnemyName') { [string]$entry.EnemyName } else { '' }
        $weaponName = if (Test-LWPropertyExists -Object $entry -Name 'Weapon') { [string]$entry.Weapon } else { '' }

        if ((Test-LWPropertyExists -Object $entry -Name 'RoundCount') -and $null -ne $entry.RoundCount -and [int]$entry.RoundCount -eq 1) {
            $metrics.OneRoundVictoryCount = [int]$metrics.OneRoundVictoryCount + 1
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'Mindblast') -and [bool]$entry.Mindblast) {
            $metrics.MindblastVictoryCount = [int]$metrics.MindblastVictoryCount + 1
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'EnemyCombatSkill') -and $null -ne $entry.EnemyCombatSkill) {
            $metrics.MaxEnemyCombatSkillVictory = [Math]::Max([int]$metrics.MaxEnemyCombatSkillVictory, [int]$entry.EnemyCombatSkill)
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'EnemyEnduranceMax') -and $null -ne $entry.EnemyEnduranceMax) {
            $metrics.MaxEnemyEnduranceVictory = [Math]::Max([int]$metrics.MaxEnemyEnduranceVictory, [int]$entry.EnemyEnduranceMax)
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'CombatRatio') -and $null -ne $entry.CombatRatio -and [int]$entry.CombatRatio -ge 15) {
            $metrics.EasyPickingsCount = [int]$metrics.EasyPickingsCount + 1
        }
        if (-not [string]::IsNullOrWhiteSpace($weaponName)) {
            $weaponKey = $weaponName.ToLowerInvariant()
            if (-not $weaponVictoryCounts.ContainsKey($weaponKey)) {
                $weaponVictoryCounts[$weaponKey] = 0
            }
            $weaponVictoryCounts[$weaponKey] = [int]$weaponVictoryCounts[$weaponKey] + 1
            $metrics.MaxWeaponVictoryCount = [Math]::Max([int]$metrics.MaxWeaponVictoryCount, [int]$weaponVictoryCounts[$weaponKey])
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'EnemyIsUndead') -and [bool]$entry.EnemyIsUndead -and (Test-LWWeaponIsSommerswerd -Weapon $weaponName) -and $bookNumber -ge 2) {
            $metrics.UndeadSommerswerdVictoryCount = [int]$metrics.UndeadSommerswerdVictoryCount + 1
        }

        if ($bookNumber -eq 1 -and $enemyName -ieq 'Mad Butcher') {
            $metrics.Book1MadButcherVictory = $true
        }
        if ($bookNumber -eq 2 -and (Test-LWPropertyExists -Object $entry -Name 'Section') -and $null -ne $entry.Section -and [int]$entry.Section -eq 158 -and $enemyName -ieq 'Priest') {
            $metrics.Book2Priest158Victory = $true
        }
        if ($bookNumber -eq 2 -and (Test-LWPropertyExists -Object $entry -Name 'Section') -and $null -ne $entry.Section -and [int]$entry.Section -eq 270 -and @('Ganon + Dorier', 'Ganon & Dorier', 'Ganon and Dorier') -contains $enemyName) {
            $metrics.Book2NeoLinkVictory = $true
        }
    }

    foreach ($summary in @($BookSummaries)) {
        if ($null -eq $summary) {
            continue
        }

        if ((Test-LWPropertyExists -Object $summary -Name 'SectionsVisited') -and $null -ne $summary.SectionsVisited) {
            $metrics.MaxSectionsVisited = [Math]::Max([int]$metrics.MaxSectionsVisited, [int]$summary.SectionsVisited)
        }
        if ((Test-LWPropertyExists -Object $summary -Name 'Victories') -and $null -ne $summary.Victories) {
            $metrics.MaxVictoriesPerBook = [Math]::Max([int]$metrics.MaxVictoriesPerBook, [int]$summary.Victories)
        }
    }

    foreach ($summary in @($CompletedBookSummaries)) {
        if ($null -eq $summary) {
            continue
        }

        $difficulty = if ((Test-LWPropertyExists -Object $summary -Name 'Difficulty') -and $null -ne $summary.Difficulty) { [string]$summary.Difficulty } else { '' }
        $permadeath = ((Test-LWPropertyExists -Object $summary -Name 'Permadeath') -and [bool]$summary.Permadeath)

        if ((Test-LWPropertyExists -Object $summary -Name 'RewindsUsed') -and $null -ne $summary.RewindsUsed -and [int]$summary.RewindsUsed -eq 0) {
            $metrics.HasCompletedNoRewinds = $true
        }
        if ((Test-LWPropertyExists -Object $summary -Name 'DeathCount') -and $null -ne $summary.DeathCount -and [int]$summary.DeathCount -eq 0) {
            $metrics.HasCompletedNoDeaths = $true
        }
        if ((Test-LWPropertyExists -Object $summary -Name 'Defeats') -and $null -ne $summary.Defeats -and [int]$summary.Defeats -eq 0) {
            $metrics.HasCompletedNoDefeats = $true
        }
        if ($difficulty -eq 'Hard') {
            $metrics.HasCompletedHard = $true
        }
        if ($difficulty -eq 'Veteran') {
            $metrics.HasCompletedVeteran = $true
        }
        if ($permadeath) {
            $metrics.HasCompletedPermadeath = $true
        }
        if ($permadeath -and @('Hard', 'Veteran') -contains $difficulty) {
            $metrics.HasCompletedPermadeathHardVet = $true
        }
    }

    return [pscustomobject]$metrics
}

function New-LWAchievementEvaluationContext {
    param([string]$Context = 'general')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return $null
    }

    Ensure-LWAchievementState -State $script:GameState
    $contextName = if ([string]::IsNullOrWhiteSpace($Context)) { 'general' } else { $Context.Trim().ToLowerInvariant() }

    $unlockedById = @{}
    foreach ($entry in @($script:GameState.Achievements.Unlocked)) {
        if ($null -ne $entry -and (Test-LWPropertyExists -Object $entry -Name 'Id') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Id)) {
            $unlockedById[[string]$entry.Id] = $true
        }
    }

    $storyFlags = @{}
    if ($null -ne $script:GameState.Achievements.StoryFlags) {
        foreach ($property in @($script:GameState.Achievements.StoryFlags.PSObject.Properties)) {
            $storyFlags[[string]$property.Name] = [bool]$property.Value
        }
    }

    $contextData = [ordered]@{
        Flags        = $script:GameState.Achievements.ProgressFlags
        StoryFlags   = $storyFlags
        UnlockedById = $unlockedById
    }

    switch ($contextName) {
        'load' {
            $contextData.RunEntries = @(Get-LWRunCombatEntries)
            $contextData.RunVictories = @(Get-LWRunVictoryEntries)
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'section' {
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'sectionmove' {
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'healing' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'inventory' { }
        'gold' { }
        'meal' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'hunting' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'starvation' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'potion' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'rewind' {
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'recovery' {
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'death' { }
        'combat' {
            $contextData.RunEntries = @(Get-LWRunCombatEntries)
            $contextData.RunVictories = @(Get-LWRunVictoryEntries)
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        default {
            $contextData.RunEntries = @(Get-LWRunCombatEntries)
            $contextData.RunVictories = @(Get-LWRunVictoryEntries)
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
    }

    if ($contextName -eq 'load') {
        $contextData.Metrics = (New-LWAchievementDerivedMetrics -RunEntries @($contextData.RunEntries) -RunVictories @($contextData.RunVictories) -BookSummaries @($contextData.BookSummaries) -CompletedBookSummaries @($contextData.CompletedBookSummaries))
    }

    return [pscustomobject]$contextData
}

function Test-LWAchievementSyncSuppressed {
    param([string]$Context = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Context)) {
        return $false
    }

    if (-not (Test-Path Variable:\script:LWAchievementSyncSuppression) -or $null -eq $script:LWAchievementSyncSuppression) {
        return $false
    }

    $contextName = $Context.Trim().ToLowerInvariant()
    return ($script:LWAchievementSyncSuppression.ContainsKey($contextName) -and [bool]$script:LWAchievementSyncSuppression[$contextName])
}

function Get-LWAchievementDefinitionsForContext {
    param(
        [string]$Context = 'general',
        [object]$State = $script:GameState
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $definitions = @(Get-LWAchievementDefinitions)
    $contextName = if ([string]::IsNullOrWhiteSpace($Context)) { 'general' } else { $Context.Trim().ToLowerInvariant() }
    $bookNumber = if ($null -ne $State -and $null -ne $State.Character -and $null -ne $State.Character.BookNumber) { [int]$State.Character.BookNumber } else { 0 }
    $ruleSet = if ($null -ne $State -and -not [string]::IsNullOrWhiteSpace([string]$State.RuleSet)) { [string]$State.RuleSet } else { 'none' }
    $cacheKey = '{0}|{1}|{2}' -f $contextName, $ruleSet, $bookNumber

    if ($script:LWAchievementContextDefinitionsCache.ContainsKey($cacheKey)) {
        return @($script:LWAchievementContextDefinitionsCache[$cacheKey])
    }

    $result = @()

    switch ($contextName) {
        'section' {
            $globalSectionIds = @(
                'pathfinder',
                'long_road'
            )
            $sectionIds = @($globalSectionIds + (Get-LWBookSectionContextAchievementIds -BookNumber $bookNumber))
            $result = @(
                $definitions |
                Where-Object { $sectionIds -contains [string]$_.Id }
            )
            break
        }
        'sectionmove' {
            $result = @(Get-LWAchievementDefinitionsForContext -Context 'section' -State $State)
            break
        }
        'healing' {
            $result = @(
                $definitions |
                Where-Object { @('second_wind', 'lean_healing') -contains [string]$_.Id }
            )
            break
        }
        'inventory' {
            $result = @(
                $definitions |
                Where-Object { @('sun_sword', 'loaded_purse', 'fully_armed', 'relic_hunter') -contains [string]$_.Id }
            )
            break
        }
        'gold' {
            $result = @(
                $definitions |
                Where-Object { @('loaded_purse') -contains [string]$_.Id }
            )
            break
        }
        'meal' {
            $result = @(
                $definitions |
                Where-Object { @('trail_survivor') -contains [string]$_.Id }
            )
            break
        }
        'hunting' {
            $result = @(
                $definitions |
                Where-Object { @('hunters_instinct') -contains [string]$_.Id }
            )
            break
        }
        'starvation' {
            $result = @(
                $definitions |
                Where-Object { @('hard_lessons') -contains [string]$_.Id }
            )
            break
        }
        'potion' {
            $result = @(
                $definitions |
                Where-Object { @('herbal_relief', 'deep_draught') -contains [string]$_.Id }
            )
            break
        }
        'rewind' {
            $result = @(
                $definitions |
                Where-Object { @('true_path', 'iron_wolf') -contains [string]$_.Id }
            )
            break
        }
        'recovery' {
            $result = @(
                $definitions |
                Where-Object { @('iron_wolf') -contains [string]$_.Id }
            )
            break
        }
        'death' {
            $result = @(
                $definitions |
                Where-Object { @('still_standing', 'unbroken', 'iron_wolf') -contains [string]$_.Id }
            )
            break
        }
        'load' {
            $result = @(
                $definitions |
                Where-Object { [bool]$_.Backfill }
            )
            break
        }
        default {
            $result = @($definitions)
            break
        }
    }

    $script:LWAchievementContextDefinitionsCache[$cacheKey] = @($result)
    return @($result)
}

function Test-LWAchievementUnlocked {
    param([Parameter(Mandatory = $true)][string]$Id)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or -not (Test-LWPropertyExists -Object $script:GameState -Name 'Achievements') -or $null -eq $script:GameState.Achievements) {
        return $false
    }

    foreach ($entry in @($script:GameState.Achievements.Unlocked)) {
        if ($null -ne $entry -and (Test-LWPropertyExists -Object $entry -Name 'Id') -and [string]$entry.Id -eq $Id) {
            return $true
        }
    }

    return $false
}

function Unlock-LWAchievement {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [switch]$Silent
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or $null -eq $Definition) {
        return $null
    }

    Ensure-LWAchievementState -State $script:GameState
    if (Test-LWAchievementUnlocked -Id ([string]$Definition.Id)) {
        return $null
    }

    $entry = [pscustomobject]@{
        Id         = [string]$Definition.Id
        Name       = (Get-LWAchievementDisplayNameById -Id ([string]$Definition.Id) -DefaultName ([string]$Definition.Name))
        Category   = [string]$Definition.Category
        Description = [string]$Definition.Description
        BookNumber = [int]$script:GameState.Character.BookNumber
        Section    = [int]$script:GameState.CurrentSection
        UnlockedOn = (Get-Date).ToString('o')
    }

    $script:GameState.Achievements.Unlocked = @($script:GameState.Achievements.Unlocked) + $entry
    if (@($script:GameState.Achievements.SeenNotifications) -notcontains [string]$Definition.Id) {
        $script:GameState.Achievements.SeenNotifications = @($script:GameState.Achievements.SeenNotifications) + [string]$Definition.Id
    }
    Clear-LWAchievementDisplayCountsCache

    if (-not $Silent) {
        Write-LWInfo ("Achievement unlocked: {0} - {1}" -f (Get-LWAchievementDisplayNameById -Id ([string]$Definition.Id) -DefaultName ([string]$Definition.Name)), [string]$Definition.Description)
    }

    return $entry
}

function Get-LWMaxWeaponVictoryCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $bestCount = 0
    foreach ($entry in @(Get-LWRunVictoryEntries | Group-Object -Property Weapon)) {
        if ($entry.Count -gt $bestCount) {
            $bestCount = [int]$entry.Count
        }
    }

    return $bestCount
}

function Get-LWSommerswerdUndeadVictoryCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $count = 0
    foreach ($entry in @(Get-LWRunVictoryEntries)) {
        if ((Test-LWPropertyExists -Object $entry -Name 'Weapon') -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$entry.Weapon)) -and (Get-LWCombatEntryBookNumber -Entry $entry) -ge 2 -and (Test-LWPropertyExists -Object $entry -Name 'EnemyIsUndead') -and [bool]$entry.EnemyIsUndead) {
            $count++
        }
    }

    return $count
}

function Test-LWAchievementSatisfied {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [object]$EvaluationContext = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return $false
    }

    $runEntries = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'RunEntries')) { @($EvaluationContext.RunEntries) } else { @(Get-LWRunCombatEntries) }
    $runVictories = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'RunVictories')) { @($EvaluationContext.RunVictories) } else { @(Get-LWRunVictoryEntries) }
    $bookSummaries = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'BookSummaries')) { @($EvaluationContext.BookSummaries) } else { @(Get-LWAllAchievementBookSummaries) }
    $completedBookSummaries = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'CompletedBookSummaries')) { @($EvaluationContext.CompletedBookSummaries) } else { @(Get-LWCompletedAchievementBookSummaries) }
    $currentSummary = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'CurrentSummary')) { $EvaluationContext.CurrentSummary } else { Get-LWLiveBookStatsSummary }
    $flags = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'Flags') -and $null -ne $EvaluationContext.Flags) { $EvaluationContext.Flags } else { $script:GameState.Achievements.ProgressFlags }
    $metrics = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'Metrics') -and $null -ne $EvaluationContext.Metrics) { $EvaluationContext.Metrics } else { $null }

    switch ([string]$Definition.Id) {
        'first_blood' { return $(if ($null -ne $metrics) { [int]$metrics.RunVictoryCount -ge 1 } else { @($runVictories).Count -ge 1 }) }
        'swift_blade' { return $(if ($null -ne $metrics) { [int]$metrics.OneRoundVictoryCount -ge 1 } else { @($runVictories | Where-Object { [int]$_.RoundCount -eq 1 }).Count -ge 1 }) }
        'untouchable' { return ([int]$flags.PerfectVictories -ge 1) }
        'against_the_odds' { return ([int]$flags.AgainstOddsVictories -ge 1) }
        'mind_over_matter' { return $(if ($null -ne $metrics) { [int]$metrics.MindblastVictoryCount -ge 1 } else { @($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Mindblast') -and $_.Mindblast }).Count -ge 1 }) }
        'giant_slayer' { return $(if ($null -ne $metrics) { [int]$metrics.MaxEnemyCombatSkillVictory -ge 18 } else { @($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'EnemyCombatSkill') -and $null -ne $_.EnemyCombatSkill -and [int]$_.EnemyCombatSkill -ge 18 }).Count -ge 1 }) }
        'monster_hunter' { return $(if ($null -ne $metrics) { [int]$metrics.MaxEnemyEnduranceVictory -ge 30 } else { @($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'EnemyEnduranceMax') -and $null -ne $_.EnemyEnduranceMax -and [int]$_.EnemyEnduranceMax -ge 30 }).Count -ge 1 }) }
        'back_from_the_brink' { return ([int]$flags.BrinkVictories -ge 1) }
        'kai_veteran' { return $(if ($null -ne $metrics) { [int]$metrics.RunVictoryCount -ge 10 } else { @($runVictories).Count -ge 10 }) }
        'weapon_master' { return $(if ($null -ne $metrics) { [int]$metrics.MaxWeaponVictoryCount -ge 10 } else { (Get-LWMaxWeaponVictoryCount) -ge 10 }) }
        'seasoned_fighter' { return $(if ($null -ne $metrics) { [int]$metrics.TotalRounds -ge 25 } else { (Get-LWRunTotalRounds) -ge 25 }) }
        'endurance_duelist' { return $(if ($null -ne $metrics) { [int]$metrics.LongFightCount -ge 1 } else { @($runEntries | Where-Object { [int]$_.RoundCount -ge 5 }).Count -ge 1 }) }
        'easy_pickings' { return $(if ($null -ne $metrics) { [int]$metrics.EasyPickingsCount -ge 1 } else { @($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'CombatRatio') -and $null -ne $_.CombatRatio -and [int]$_.CombatRatio -ge 15 }).Count -ge 1 }) }
        'trail_survivor' { return ($null -ne $currentSummary -and [int]$currentSummary.MealsEaten -ge 1) }
        'hunters_instinct' { return ($null -ne $currentSummary -and [int]$currentSummary.MealsCoveredByHunting -ge 5) }
        'herbal_relief' { return ($null -ne $currentSummary -and [int]$currentSummary.PotionsUsed -ge 1) }
        'second_wind' { return ($null -ne $currentSummary -and [int]$currentSummary.HealingEnduranceRestored -ge 10) }
        'loaded_purse' { return ([int]$script:GameState.Inventory.GoldCrowns -ge 50) }
        'hard_lessons' { return ($null -ne $currentSummary -and [int]$currentSummary.StarvationPenalties -ge 1) }
        'still_standing' { return (@($script:GameState.DeathHistory).Count -ge 3) }
        'deep_draught' { return ($null -ne $currentSummary -and [int]$currentSummary.ConcentratedPotionsUsed -ge 1) }
        'pathfinder' { return $(if ($null -ne $metrics) { [int]$metrics.MaxSectionsVisited -ge 25 } else { @($bookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'SectionsVisited') -and [int]$_.SectionsVisited -ge 25 }).Count -ge 1 }) }
        'long_road' { return $(if ($null -ne $metrics) { [int]$metrics.MaxSectionsVisited -ge 50 } else { @($bookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'SectionsVisited') -and [int]$_.SectionsVisited -ge 50 }).Count -ge 1 }) }
        'no_quarter' { return $(if ($null -ne $metrics) { [int]$metrics.MaxVictoriesPerBook -ge 5 } else { @($bookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Victories') -and [int]$_.Victories -ge 5 }).Count -ge 1 }) }
        'sun_sword' { return ((Test-LWStateHasSommerswerd -State $script:GameState) -or @($runEntries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Weapon') -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$_.Weapon)) -and (Get-LWCombatEntryBookNumber -Entry $_) -ge 2 }).Count -ge 1) }
        'fully_armed' { return (@($script:GameState.Inventory.Weapons).Count -ge 2 -and (Get-LWStateShieldCombatSkillBonus -State $script:GameState) -ge 2) }
        'relic_hunter' { return (@($script:GameState.Inventory.SpecialItems).Count -ge 5) }
        'book_one_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 1) }
        'book_two_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 2) }
        'book_three_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 3) }
        'grave_bane' { return $(if ($null -ne $metrics) { [int]$metrics.UndeadSommerswerdVictoryCount -ge 1 } else { (Get-LWSommerswerdUndeadVictoryCount) -ge 1 }) }
        'true_path' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedNoRewinds } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'RewindsUsed') -and [int]$_.RewindsUsed -eq 0 }).Count -ge 1 }) }
        'unbroken' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedNoDeaths } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'DeathCount') -and [int]$_.DeathCount -eq 0 }).Count -ge 1 }) }
        'wolf_of_sommerlund' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedNoDefeats } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Defeats') -and [int]$_.Defeats -eq 0 }).Count -ge 1 }) }
        'iron_wolf' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'DeathCount') -and [int]$_.DeathCount -eq 0 -and (Test-LWPropertyExists -Object $_ -Name 'RewindsUsed') -and [int]$_.RewindsUsed -eq 0 -and (Test-LWPropertyExists -Object $_ -Name 'ManualRecoveryShortcuts') -and [int]$_.ManualRecoveryShortcuts -eq 0 }).Count -ge 1) }
        'gentle_path' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Story' }).Count -ge 1) }
        'all_too_easy' { return ((Get-LWCurrentDifficulty) -eq 'Story' -and @($runVictories).Count -ge 1) }
        'bedtime_tale' { return (@($completedBookSummaries | Where-Object { [int]$_.BookNumber -eq 1 -and (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Story' }).Count -ge 1) }
        'hard_road' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedHard } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Hard' }).Count -ge 1 }) }
        'lean_healing' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Hard' -and (Test-LWPropertyExists -Object $_ -Name 'HealingEnduranceRestored') -and [int]$_.HealingEnduranceRestored -ge 10 }).Count -ge 1) }
        'veteran_of_sommerlund' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedVeteran } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Veteran' }).Count -ge 1 }) }
        'by_the_text' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedVeteran } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Veteran' }).Count -ge 1 }) }
        'only_one_life' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedPermadeath } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Permadeath') -and [bool]$_.Permadeath }).Count -ge 1 }) }
        'mortal_wolf' { return $(if ($null -ne $metrics) { [bool]$metrics.HasCompletedPermadeathHardVet } else { @($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Permadeath') -and [bool]$_.Permadeath -and (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and @('Hard', 'Veteran') -contains [string]$_.Difficulty }).Count -ge 1 }) }
        'aim_for_the_bushes' { return (Test-LWAchievementStoryFlag -Name 'Book1AimForTheBushesVisited' -EvaluationContext $EvaluationContext) }
        'found_the_clubhouse' { return (Test-LWAchievementStoryFlag -Name 'Book1ClubhouseFound' -EvaluationContext $EvaluationContext) }
        'kill_the_mad_butcher' { return $(if ($null -ne $metrics) { [bool]$metrics.Book1MadButcherVictory } else { @($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 1 -and [string]$_.EnemyName -ieq 'Mad Butcher' }).Count -ge 1 }) }
        'whats_in_the_box_book1' { return (Test-LWAchievementStoryFlag -Name 'Book1SilverKeyClaimed' -EvaluationContext $EvaluationContext) }
        'use_the_force' { return (Test-LWAchievementStoryFlag -Name 'Book1UseTheForcePath' -EvaluationContext $EvaluationContext) }
        'straight_to_the_throne' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWAchievementStoryFlag -Name 'Book1StraightToTheThrone' -EvaluationContext $EvaluationContext)) }
        'royal_recovery' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWAchievementStoryFlag -Name 'Book1RoyalRecovery' -EvaluationContext $EvaluationContext)) }
        'the_back_way_in' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWAchievementStoryFlag -Name 'Book1BackWayIn' -EvaluationContext $EvaluationContext)) }
        'open_sesame' { return (Test-LWAchievementStoryFlag -Name 'Book1OpenSesameRoute' -EvaluationContext $EvaluationContext) }
        'hot_hands' { return (Test-LWAchievementStoryFlag -Name 'Book1HotHandsClaimed' -EvaluationContext $EvaluationContext) }
        'star_of_toran' { return (Test-LWAchievementStoryFlag -Name 'Book1StarOfToranClaimed' -EvaluationContext $EvaluationContext) }
        'field_medic' { return (Test-LWAchievementStoryFlag -Name 'Book1FieldMedicPath' -EvaluationContext $EvaluationContext) }
        'found_the_sommerswerd' { return (Test-LWAchievementStoryFlag -Name 'Book2SommerswerdClaimed' -EvaluationContext $EvaluationContext) }
        'you_have_chosen_wisely' { return $(if ($null -ne $metrics) { [bool]$metrics.Book2Priest158Victory } else { @($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 2 -and (Test-LWPropertyExists -Object $_ -Name 'Section') -and [int]$_.Section -eq 158 -and [string]$_.EnemyName -ieq 'Priest' }).Count -ge 1 }) }
        'neo_link' { return $(if ($null -ne $metrics) { [bool]$metrics.Book2NeoLinkVictory } else { @($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 2 -and (Test-LWPropertyExists -Object $_ -Name 'Section') -and [int]$_.Section -eq 270 -and @('Ganon + Dorier', 'Ganon & Dorier', 'Ganon and Dorier') -contains [string]$_.EnemyName }).Count -ge 1 }) }
        'by_a_thread' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2ByAThreadRoute' -EvaluationContext $EvaluationContext)) }
        'skyfall' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2SkyfallRoute' -EvaluationContext $EvaluationContext)) }
        'fight_through_the_smoke' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2FightThroughTheSmokeRoute' -EvaluationContext $EvaluationContext)) }
        'storm_tossed' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2StormTossedSeen' -EvaluationContext $EvaluationContext)) }
        'seal_of_approval' { return ((Test-LWAchievementStoryFlag -Name 'Book2SealOfApprovalRoute' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book2SommerswerdClaimed' -EvaluationContext $EvaluationContext)) }
        'papers_please' { return (Test-LWAchievementStoryFlag -Name 'Book2PapersPleasePath' -EvaluationContext $EvaluationContext) }
        'snakes_why' { return (Test-LWAchievementStoryFlag -Name 'Book3SnakePitVisited' -EvaluationContext $EvaluationContext) }
        'cliffhanger' { return (Test-LWAchievementStoryFlag -Name 'Book3CliffhangerSeen' -EvaluationContext $EvaluationContext) }
        'whats_in_the_box' { return (Test-LWAchievementStoryFlag -Name 'Book3DiamondClaimed' -EvaluationContext $EvaluationContext) }
        'snowblind' { return (Test-LWAchievementStoryFlag -Name 'Book3SnowblindSeen' -EvaluationContext $EvaluationContext) }
        'you_touched_it_with_your_hands' { return (Test-LWAchievementStoryFlag -Name 'Book3GrossKeyClaimed' -EvaluationContext $EvaluationContext) }
        'lucky_button_theory' { return (Test-LWAchievementStoryFlag -Name 'Book3LuckyButtonTheorySeen' -EvaluationContext $EvaluationContext) }
        'well_it_worked_once' { return (Test-LWAchievementStoryFlag -Name 'Book3WellItWorkedOnceSeen' -EvaluationContext $EvaluationContext) }
        'cellfish' { return (Test-LWAchievementStoryFlag -Name 'Book3CellfishPathTaken' -EvaluationContext $EvaluationContext) }
        'loi_kymar_lives' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3LoiKymarRescued' -EvaluationContext $EvaluationContext)) }
        'puppet_master' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3EffigyEndgameReached' -EvaluationContext $EvaluationContext)) }
        'sun_on_the_ice' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3SommerswerdEndgameUsed' -EvaluationContext $EvaluationContext)) }
        'lucky_break' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3LuckyEndgameUsed' -EvaluationContext $EvaluationContext)) }
        'too_slow' { return (Test-LWAchievementStoryFlag -Name 'Book3TooSlowFailureSeen' -EvaluationContext $EvaluationContext) }
        'book_four_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 4) }
        'sun_below_the_earth' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWAchievementStoryFlag -Name 'Book4SunBelowTheEarthRoute' -EvaluationContext $EvaluationContext)) }
        'blessed_be_the_throw' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWAchievementStoryFlag -Name 'Book4BlessedBeTheThrowRoute' -EvaluationContext $EvaluationContext)) }
        'steel_against_shadow' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWAchievementStoryFlag -Name 'Book4SteelAgainstShadowRoute' -EvaluationContext $EvaluationContext)) }
        'badge_of_office' { return (Test-LWAchievementStoryFlag -Name 'Book4BadgeOfOfficePath' -EvaluationContext $EvaluationContext) }
        'wearing_the_enemys_colors' { return ((Test-LWAchievementStoryFlag -Name 'Book4OnyxMedallionClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4OnyxBluffRoute' -EvaluationContext $EvaluationContext)) }
        'read_the_signs' { return ((Test-LWAchievementStoryFlag -Name 'Book4ScrollClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4ScrollRoute' -EvaluationContext $EvaluationContext)) }
        'return_to_sender' { return ((Test-LWAchievementStoryFlag -Name 'Book4CaptainSwordClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4ReturnToSenderPath' -EvaluationContext $EvaluationContext)) }
        'deep_pockets_poor_timing' { return (Test-LWAchievementStoryFlag -Name 'Book4BackpackLost' -EvaluationContext $EvaluationContext) }
        'bagless_but_breathing' { return ((Test-LWAchievementStoryFlag -Name 'Book4BackpackLost' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4BackpackRecovered' -EvaluationContext $EvaluationContext)) }
        'shovel_ready' { return (Test-LWAchievementStoryFlag -Name 'Book4ShovelReadyClaimed' -EvaluationContext $EvaluationContext) }
        'light_in_the_depths' { return (Test-LWAchievementStoryFlag -Name 'Book4LightInTheDepths' -EvaluationContext $EvaluationContext) }
        'chasm_of_doom' { return (Test-LWAchievementStoryFlag -Name 'Book4ChasmOfDoomSeen' -EvaluationContext $EvaluationContext) }
        'washed_away' { return (Test-LWAchievementStoryFlag -Name 'Book4WashedAway' -EvaluationContext $EvaluationContext) }
        'book_five_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 5) }
        'kai_master' { return ((@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5 })).Count -ge 5) }
        'apothecarys_answer' { return ((Test-LWAchievementStoryFlag -Name 'Book5OedeClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book5LimbdeathCured' -EvaluationContext $EvaluationContext)) }
        'prison_break' { return (Test-LWAchievementStoryFlag -Name 'Book5PrisonBreak' -EvaluationContext $EvaluationContext) }
        'talons_tamed' { return (Test-LWAchievementStoryFlag -Name 'Book5TalonsTamed' -EvaluationContext $EvaluationContext) }
        'star_guided' { return (Test-LWAchievementStoryFlag -Name 'Book5CrystalPendantRoute' -EvaluationContext $EvaluationContext) }
        'name_the_lost' { return ((Test-LWAchievementStoryFlag -Name 'Book5SoushillaNameHeard' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book5SoushillaAsked' -EvaluationContext $EvaluationContext)) }
        'shadow_on_the_sand' { return ((@($script:GameState.Character.CompletedBooks) -contains 5) -and (Test-LWAchievementStoryFlag -Name 'Book5BanishmentRoute' -EvaluationContext $EvaluationContext)) }
        'face_to_face_with_haakon' { return ((@($script:GameState.Character.CompletedBooks) -contains 5) -and (Test-LWAchievementStoryFlag -Name 'Book5HaakonDuelRoute' -EvaluationContext $EvaluationContext)) }
        'book_six_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 6) }
        'magnakai_rising' { return ((@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5, 6 })).Count -ge 6) }
        'jump_the_wagons' { return (Test-LWAchievementStoryFlag -Name 'Book6JumpTheWagonsRoute' -EvaluationContext $EvaluationContext) }
        'water_bearer' { return (Test-LWAchievementStoryFlag -Name 'Book6TaunorWaterStored' -EvaluationContext $EvaluationContext) }
        'tekaro_cartographer' { return (Test-LWAchievementStoryFlag -Name 'Book6MapOfTekaroClaimed' -EvaluationContext $EvaluationContext) }
        'key_to_varetta' { return (Test-LWAchievementStoryFlag -Name 'Book6SmallSilverKeyClaimed' -EvaluationContext $EvaluationContext) }
        'silver_oak_prize' { return (Test-LWAchievementStoryFlag -Name 'Book6SilverBowClaimed' -EvaluationContext $EvaluationContext) }
        'cess_to_enter' { return (Test-LWAchievementStoryFlag -Name 'Book6CessClaimed' -EvaluationContext $EvaluationContext) }
        'cold_comfort' { return (Test-LWAchievementStoryFlag -Name 'Book6Section306NexusProtected' -EvaluationContext $EvaluationContext) }
        'mind_over_malice_book6' { return (Test-LWAchievementStoryFlag -Name 'Book6Section315MindforceBlocked' -EvaluationContext $EvaluationContext) }
        default { return $false }
    }
}

function Get-LWAchievementProgressText {
    param([Parameter(Mandatory = $true)][object]$Definition)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return ''
    }

    $currentSummary = Get-LWLiveBookStatsSummary
    $bookSummaries = @(Get-LWAllAchievementBookSummaries)
    $runVictories = @(Get-LWRunVictoryEntries)

    switch ([string]$Definition.Id) {
        'kai_veteran' { return ("{0}/10 wins" -f @($runVictories).Count) }
        'weapon_master' { return ("{0}/10 wins with one weapon" -f (Get-LWMaxWeaponVictoryCount)) }
        'seasoned_fighter' { return ("{0}/25 rounds" -f (Get-LWRunTotalRounds)) }
        'giant_slayer' { return ("best defeated CS {0}/18" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HighestEnemyCombatSkillDefeated } else { 0 })) }
        'monster_hunter' { return ("best defeated END {0}/30" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HighestEnemyEnduranceDefeated } else { 0 })) }
        'hunters_instinct' { return ("{0}/5 Hunting meals" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.MealsCoveredByHunting } else { 0 })) }
        'deep_draught' { return ("{0}/1 concentrated doses used" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.ConcentratedPotionsUsed } else { 0 })) }
        'second_wind' { return ("{0}/10 END restored" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HealingEnduranceRestored } else { 0 })) }
        'loaded_purse' { return ("{0}/50 Gold" -f [int]$script:GameState.Inventory.GoldCrowns) }
        'still_standing' { return ("{0}/3 deaths survived" -f @($script:GameState.DeathHistory).Count) }
        'pathfinder' { return ("best book {0}/25 sections" -f $(if (@($bookSummaries).Count -gt 0) { (@($bookSummaries | ForEach-Object { [int]$_.SectionsVisited } | Measure-Object -Maximum).Maximum) } else { 0 })) }
        'long_road' { return ("best book {0}/50 sections" -f $(if (@($bookSummaries).Count -gt 0) { (@($bookSummaries | ForEach-Object { [int]$_.SectionsVisited } | Measure-Object -Maximum).Maximum) } else { 0 })) }
        'no_quarter' { return ("best book {0}/5 victories" -f $(if (@($bookSummaries).Count -gt 0) { (@($bookSummaries | ForEach-Object { [int]$_.Victories } | Measure-Object -Maximum).Maximum) } else { 0 })) }
        'sun_sword' { return $(if (Test-LWStateHasSommerswerd -State $script:GameState) { 'Sommerswerd carried' } else { 'Sommerswerd not yet claimed' }) }
        'fully_armed' { return ("weapons {0}/2, shield {1}" -f @($script:GameState.Inventory.Weapons).Count, $(if ((Get-LWStateShieldCombatSkillBonus -State $script:GameState) -ge 2) { 'yes' } else { 'no' })) }
        'relic_hunter' { return ("{0}/5 Special Items carried" -f @($script:GameState.Inventory.SpecialItems).Count) }
        'grave_bane' { return ("{0}/1 undead Sommerswerd wins" -f (Get-LWSommerswerdUndeadVictoryCount)) }
        'true_path' {
            $bestCompletedRewinds = @(
                $bookSummaries |
                Where-Object { (Test-LWPropertyExists -Object $_ -Name 'RewindsUsed') } |
                ForEach-Object { [int]$_.RewindsUsed }
            )
            if ($bestCompletedRewinds.Count -gt 0) {
                return ("best completed book rewinds: {0}" -f (($bestCompletedRewinds | Measure-Object -Minimum).Minimum))
            }
            return ("current book rewinds: {0}" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.RewindsUsed } else { 0 }))
        }
        'iron_wolf' { return ("current book deaths {0}, rewinds {1}, shortcuts {2}" -f $(if ($null -ne $currentSummary -and (Test-LWPropertyExists -Object $currentSummary -Name 'DeathCount')) { [int]$currentSummary.DeathCount } else { 0 }), $(if ($null -ne $currentSummary) { [int]$currentSummary.RewindsUsed } else { 0 }), $(if ($null -ne $currentSummary) { [int]$currentSummary.ManualRecoveryShortcuts } else { 0 })) }
        'gentle_path' { return 'complete any book in Story mode' }
        'all_too_easy' { return ("Story mode victories: {0}" -f $(if ((Get-LWCurrentDifficulty) -eq 'Story') { $runVictories.Count } else { 0 })) }
        'bedtime_tale' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 1) { 'Book 1 complete' } else { 'complete Book 1 in Story mode' }) }
        'hard_road' { return 'complete any book on Hard' }
        'lean_healing' { return ("current book Healing restored: {0}/10" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HealingEnduranceRestored } else { 0 })) }
        'veteran_of_sommerlund' { return 'complete any book on Veteran' }
        'by_the_text' { return 'complete any book on Veteran' }
        'only_one_life' { return $(if (Test-LWPermadeathEnabled) { 'Permadeath active for this run' } else { 'start a Permadeath run' }) }
        'mortal_wolf' { return $(if ((Test-LWPermadeathEnabled) -and @('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty)) { 'eligible run active' } else { 'requires Hard/Veteran + Permadeath' }) }
        'aim_for_the_bushes' { return '' }
        'found_the_clubhouse' { return '' }
        'kill_the_mad_butcher' { return '' }
        'whats_in_the_box_book1' { return '' }
        'use_the_force' { return '' }
        'straight_to_the_throne' { return $(if (Test-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone') { 'palace route found; finish Book 1' } else { 'finish Book 1 through 139 -> 66 -> 350' }) }
        'royal_recovery' { return $(if (Test-LWStoryAchievementFlag -Name 'Book1RoyalRecovery') { 'recovery route found; finish Book 1' } else { 'finish Book 1 through 165 -> 212 -> 350' }) }
        'the_back_way_in' { return $(if (Test-LWStoryAchievementFlag -Name 'Book1BackWayIn') { 'Guildhall route found; finish Book 1' } else { 'finish Book 1 through 196/210 -> 332 -> 350' }) }
        'open_sesame' { return '' }
        'hot_hands' { return '' }
        'star_of_toran' { return '' }
        'field_medic' { return '' }
        'found_the_sommerswerd' { return '' }
        'you_have_chosen_wisely' { return '' }
        'neo_link' { return '' }
        'by_a_thread' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute') { 'rope-swing route found; finish Book 2' } else { 'finish Book 2 through 218 -> 105 -> 120 -> 225 -> 350' }) }
        'skyfall' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2SkyfallRoute') { 'skyfall route found; finish Book 2' } else { 'finish Book 2 through 336 -> 109 -> 120 -> 225 -> 350' }) }
        'fight_through_the_smoke' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute') { 'smoke route found; finish Book 2' } else { 'finish Book 2 through 336 -> 185 -> 120 -> 225 -> 350' }) }
        'storm_tossed' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2StormTossedSeen') { 'storm route found; finish Book 2' } else { 'reach section 337 and still complete Book 2' }) }
        'seal_of_approval' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute') { 'king''s audience route found; claim the Sommerswerd' } else { 'reach section 196 and claim the Sommerswerd' }) }
        'papers_please' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought') { 'forged papers bought; present them at the Red Pass counter' } else { 'buy the forged access papers at section 327' }) }
        'book_three_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 3) { 'Book 3 complete' } else { 'complete Book 3' }) }
        'snakes_why' { return '' }
        'cliffhanger' { return '' }
        'whats_in_the_box' { return '' }
        'snowblind' { return '' }
        'you_touched_it_with_your_hands' { return '' }
        'lucky_button_theory' { return '' }
        'well_it_worked_once' { return '' }
        'cellfish' { return '' }
        'loi_kymar_lives' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued') { 'Loi-Kymar rescued; finish Book 3' } else { 'rescue Loi-Kymar and finish Book 3' }) }
        'puppet_master' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached') { 'Effigy route found; finish Book 3' } else { 'finish Book 3 through the Effigy route' }) }
        'sun_on_the_ice' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed') { 'Sommerswerd route found; finish Book 3' } else { 'finish Book 3 through the Sommerswerd route' }) }
        'lucky_break' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed') { 'Lucky endgame route found; finish Book 3' } else { 'finish Book 3 through the lucky endgame route' }) }
        'too_slow' { return '' }
        'book_four_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 4) { 'Book 4 complete' } else { 'complete Book 4' }) }
        'sun_below_the_earth' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute') { 'Sommerswerd route found; finish Book 4' } else { 'finish Book 4 through 296 -> 122 -> 350' }) }
        'blessed_be_the_throw' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute') { 'Holy Water route found; finish Book 4' } else { 'finish Book 4 through 283 -> 350' }) }
        'steel_against_shadow' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute') { 'Barraka duel route found; finish Book 4' } else { 'finish Book 4 through 325 -> 350' }) }
        'badge_of_office' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath') { 'Badge route found' } else { 'use the Badge of Rank route at section 95' }) }
        'wearing_the_enemys_colors' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed') { 'Onyx Medallion claimed; use it at section 305' } else { 'claim the Onyx Medallion and bluff your way to section 305' }) }
        'read_the_signs' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4ScrollClaimed') { 'Scroll claimed; use it to reach section 279' } else { 'claim the Scroll and use it to reach section 279' }) }
        'return_to_sender' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed') { 'Captain D''Val''s Sword claimed; return it at section 327' } else { 'claim Captain D''Val''s Sword and return it at section 327' }) }
        'deep_pockets_poor_timing' { return '' }
        'bagless_but_breathing' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4BackpackLost') { 'Backpack lost; recover one at section 167 or 12' } else { 'lose your Backpack in Book 4 and recover a new one' }) }
        'shovel_ready' { return '' }
        'light_in_the_depths' { return '' }
        'chasm_of_doom' { return '' }
        'washed_away' { return '' }
        'book_five_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 5) { 'Book 5 complete' } else { 'complete Book 5' }) }
        'kai_master' { return ("{0}/5 Kai books complete" -f (@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5 })).Count) }
        'apothecarys_answer' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5OedeClaimed') { 'Oede Herb claimed; cure Limbdeath with it' } else { 'claim the Oede Herb and use it to cure Limbdeath' }) }
        'prison_break' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5PrisonBreak') { 'confiscated gear recovered' } else { 'recover your confiscated gear in Book 5' }) }
        'talons_tamed' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5TalonsTamed') { 'Itikar route found' } else { 'mount the Itikar through the special route in Book 5' }) }
        'star_guided' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute') { 'Crystal Star Pendant route found; finish Book 5' } else { 'use the Crystal Star Pendant route in Book 5' }) }
        'name_the_lost' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard') { 'Soushilla name learned; ask for her later' } else { 'learn Soushilla''s name and ask for her in Book 5' }) }
        'shadow_on_the_sand' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5BanishmentRoute') { 'banishment route found; finish Book 5' } else { 'finish Book 5 through the glowing-stone route' }) }
        'face_to_face_with_haakon' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute') { 'Haakon duel route found; finish Book 5' } else { 'finish Book 5 through the Haakon duel route' }) }
        'book_six_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 6) { 'Book 6 complete' } else { 'complete Book 6' }) }
        'magnakai_rising' { return ("{0}/6 books complete" -f (@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5, 6 }).Count)) }
        'jump_the_wagons' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6JumpTheWagonsRoute') { 'wagon-jump route cleared' } else { 'clear the wagon-jump route in Book 6' }) }
        'water_bearer' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored') { 'Taunor Water stored for later use' } else { 'store Taunor Water for later use in Book 6' }) }
        'tekaro_cartographer' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6MapOfTekaroClaimed') { 'Map of Tekaro claimed' } else { 'claim a Map of Tekaro in Book 6' }) }
        'key_to_varetta' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed') { 'Small Silver Key claimed' } else { 'claim the Small Silver Key in Book 6' }) }
        'silver_oak_prize' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed') { 'Silver Bow of Duadon claimed' } else { 'win the Silver Bow of Duadon in Book 6' }) }
        'cess_to_enter' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6CessClaimed') { 'Cess claimed' } else { 'pocket a valid Cess for Amory in Book 6' }) }
        'cold_comfort' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected') { 'Nexus has already protected you from the cold' } else { 'reach the frozen-river route with Nexus in Book 6' }) }
        'mind_over_malice_book6' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6Section315MindforceBlocked') { 'Psi-screen blocked the Mindforce assault' } else { 'reach section 315 with Psi-screen' }) }
        default { return '' }
    }
}

function Sync-LWAchievements {
    param(
        [string]$Context = 'general',
        [object]$Data = $null,
        [switch]$Silent
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return @()
    }

    Ensure-LWAchievementState -State $script:GameState
    if ([string]$Context -eq 'load') {
        Rebuild-LWAchievementProgressFlags
        Rebuild-LWStoryAchievementFlagsFromState
    }
    elseif ([string]$Context -eq 'combat' -and $null -ne $Data) {
        Update-LWAchievementProgressFlagsFromSummary -Summary $Data
    }

    $evaluationContext = New-LWAchievementEvaluationContext -Context $Context
    $newUnlocks = @()
    foreach ($definition in @(Get-LWAchievementDefinitionsForContext -Context $Context -State $script:GameState)) {
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition)) {
            continue
        }
        $definitionId = [string]$definition.Id
        if ($null -ne $evaluationContext -and $null -ne $evaluationContext.UnlockedById -and $evaluationContext.UnlockedById.ContainsKey($definitionId)) {
            continue
        }
        if (Test-LWAchievementSatisfied -Definition $definition -EvaluationContext $evaluationContext) {
            $unlocked = Unlock-LWAchievement -Definition $definition -Silent:$Silent
            if ($null -ne $unlocked) {
                if ($null -ne $evaluationContext -and $null -ne $evaluationContext.UnlockedById) {
                    $evaluationContext.UnlockedById[$definitionId] = $true
                }
                $newUnlocks += $unlocked
            }
        }
    }

    if ([string]$Context -eq 'load') {
        Set-LWAchievementLoadBackfillCurrent -State $script:GameState
    }

    return @($newUnlocks)
}

function Get-LWAchievementUnlockedCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return 0
    }

    Ensure-LWAchievementState -State $script:GameState
    return @($script:GameState.Achievements.Unlocked).Count
}

function Get-LWAchievementAvailableCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return @(Get-LWAchievementDefinitions).Count
    }

    return (Get-LWAchievementDisplayCounts).EligibleCount
}

function Get-LWAchievementRecentUnlocks {
    param([int]$Count = 5)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return @()
    }

    Ensure-LWAchievementState -State $script:GameState
    $entries = @($script:GameState.Achievements.Unlocked)
    if ($entries.Count -le $Count) {
        return @($entries)
    }

    return @($entries[($entries.Count - $Count)..($entries.Count - 1)])
}

function Get-LWAchievementBookDisplayDefinitions {
    param([int]$BookNumber)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $completionId = switch ($BookNumber) {
        1 { 'book_one_complete' }
        2 { 'book_two_complete' }
        3 { 'book_three_complete' }
        4 { 'book_four_complete' }
        5 { 'book_five_complete' }
        6 { 'book_six_complete' }
        default { $null }
    }

    $ids = @((Get-LWBookSectionContextAchievementIds -BookNumber $BookNumber))
    if (-not [string]::IsNullOrWhiteSpace([string]$completionId)) {
        $ids += $completionId
    }

    return @(
        Get-LWAchievementDefinitions |
        Where-Object { $ids -contains [string]$_.Id }
    )
}

function Show-LWAchievementOverview {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $definitions = @(Get-LWAchievementDefinitions)
    $availability = Get-LWAchievementModeAvailabilitySnapshot -State $script:GameState
    $availableById = $availability.AvailableById
    $profileUnlockedCount = Get-LWAchievementUnlockedCount
    $profileTotalCount = @($definitions).Count
    $eligibleUnlockedCount = Get-LWAchievementEligibleUnlockedCount
    $eligibleCount = Get-LWAchievementEligibleCount
    $recent = @(Get-LWAchievementRecentUnlocks -Count 6)
    $hiddenLockedCount = @(
        @($availability.Definitions) |
        Where-Object {
            (Test-LWPropertyExists -Object $_ -Name 'Hidden') -and [bool]$_.Hidden -and
            -not (Test-LWAchievementUnlocked -Id ([string]$_.Id))
        }
    ).Count
    $currentBook = [int]$script:GameState.Character.BookNumber
    $currentBookDefinitions = @(Get-LWAchievementBookDisplayDefinitions -BookNumber $currentBook)
    $currentBookUnlocked = @($currentBookDefinitions | Where-Object { Test-LWAchievementUnlocked -Id ([string]$_.Id) }).Count
    $currentBookLocked = @($currentBookDefinitions | Where-Object { -not (Test-LWAchievementUnlocked -Id ([string]$_.Id)) }).Count

    Write-LWRetroPanelHeader -Title 'Achievement Status' -AccentColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Unlocked' -LeftValue ("{0} / {1}" -f $eligibleUnlockedCount, $eligibleCount) -RightLabel 'Profile Total' -RightValue ("{0} / {1}" -f $profileUnlockedCount, $profileTotalCount) -LeftColor 'White' -RightColor 'Magenta' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Hidden' -LeftValue ([string]$hiddenLockedCount) -RightLabel 'Book Progress' -RightValue ("Book {0}: {1} / {2}" -f $currentBook, $currentBookUnlocked, $currentBookDefinitions.Count) -LeftColor 'DarkYellow' -RightColor 'White' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Book Totals' -AccentColor 'Cyan'
    $bookRows = @()
    foreach ($bookNumber in @(1..[Math]::Max(1, $currentBook))) {
        $bookDefinitions = @(Get-LWAchievementBookDisplayDefinitions -BookNumber $bookNumber)
        if ($bookDefinitions.Count -eq 0) {
            continue
        }
        $unlockedCount = @($bookDefinitions | Where-Object { Test-LWAchievementUnlocked -Id ([string]$_.Id) }).Count
        $bookRows += [pscustomobject]@{
            Text  = ("Book {0} : {1,2} / {2,2}" -f $bookNumber, $unlockedCount, $bookDefinitions.Count)
            Color = $(if ($bookNumber -eq $currentBook) { 'Yellow' } else { 'Gray' })
        }
    }
    if ($bookRows.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $bookRows.Count; $i += 2) {
            $left = $bookRows[$i]
            $right = if (($i + 1) -lt $bookRows.Count) { $bookRows[$i + 1] } else { $null }
            Write-LWRetroPanelTwoColumnRow -LeftText ([string]$left.Text) -RightText $(if ($null -ne $right) { [string]$right.Text } else { '' }) -LeftColor ([string]$left.Color) -RightColor $(if ($null -ne $right) { [string]$right.Color } else { 'Gray' }) -LeftWidth 28 -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Recent Unlocks' -AccentColor 'DarkYellow'
    if ($recent.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none yet)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $recent.Count; $i += 2) {
            $leftText = (Get-LWAchievementUnlockedDisplayName -Entry $recent[$i])
            $rightText = if (($i + 1) -lt $recent.Count) { (Get-LWAchievementUnlockedDisplayName -Entry $recent[$i + 1]) } else { '' }
            Write-LWRetroPanelTwoColumnRow -LeftText $leftText -RightText $rightText -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Current Book Hints' -AccentColor 'Cyan'
    if ($currentBookLocked -gt 0) {
        Write-LWRetroPanelTextRow -Text ("Hidden achievement slots remain in Book {0}." -f $currentBook) -TextColor 'Gray'
        Write-LWRetroPanelTextRow -Text 'Route and DE option choices can affect unlock coverage.' -TextColor 'Gray'
    }
    else {
        Write-LWRetroPanelTextRow -Text ("Book {0} story achievements are fully cleared." -f $currentBook) -TextColor 'Green'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementUnlockedList {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWRetroPanelHeader -Title 'Unlocked Achievements' -AccentColor 'Green'
    $entries = @($script:GameState.Achievements.Unlocked)
    if ($entries.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none yet)' -TextColor 'DarkGray'
        Write-LWRetroPanelFooter
        return
    }

    foreach ($entry in $entries) {
        Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementLockedList {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWRetroPanelHeader -Title 'Locked Achievements' -AccentColor 'DarkYellow'
    $availability = Get-LWAchievementModeAvailabilitySnapshot -State $script:GameState
    $availableById = $availability.AvailableById
    $locked = @()
    $disabled = @()
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (-not (Test-LWAchievementUnlocked -Id ([string]$definition.Id))) {
            if ($availableById.ContainsKey([string]$definition.Id)) {
                $locked += $definition
            }
            else {
                $disabled += $definition
            }
        }
    }

    if ($locked.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text 'No eligible locked achievements remain for this run.' -TextColor 'DarkGray'
    }
    else {
        foreach ($definition in $locked) {
            $progress = Get-LWAchievementProgressText -Definition $definition
            $displayName = Get-LWAchievementLockedDisplayName -Definition $definition
            $displayDescription = Get-LWAchievementLockedDisplayDescription -Definition $definition
            Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f $displayName, $displayDescription) -TextColor 'Gray'
            if (-not [string]::IsNullOrWhiteSpace($progress) -and $displayName -ne '???') {
                Write-LWRetroPanelTextRow -Text ("progress: {0}" -f $progress) -TextColor 'DarkGray'
            }
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Disabled For This Run' -AccentColor 'DarkGray'
    if ($disabled.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        foreach ($definition in $disabled) {
            $reason = Get-LWAchievementAvailabilityReason -Definition $definition
            $displayName = Get-LWAchievementLockedDisplayName -Definition $definition
            $displayDescription = Get-LWAchievementLockedDisplayDescription -Definition $definition
            Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f $displayName, $displayDescription) -TextColor 'Gray'
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                Write-LWRetroPanelTextRow -Text $reason -TextColor 'DarkGray'
            }
        }
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementProgressList {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWRetroPanelHeader -Title 'Achievement Progress' -AccentColor 'Cyan'
    $availability = Get-LWAchievementModeAvailabilitySnapshot -State $script:GameState
    $availableById = $availability.AvailableById
    $anyShown = $false
    $disabledCount = 0
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
            continue
        }
        if (-not $availableById.ContainsKey([string]$definition.Id)) {
            $disabledCount++
            continue
        }

        $progress = Get-LWAchievementProgressText -Definition $definition
        if ([string]::IsNullOrWhiteSpace($progress)) {
            continue
        }

        $anyShown = $true
        Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f (Get-LWAchievementLockedDisplayName -Definition $definition), $progress) -TextColor 'Gray'
    }

    if (-not $anyShown) {
        Write-LWRetroPanelTextRow -Text 'No tracked progress milestones are pending for the current run.' -TextColor 'DarkGray'
    }

    if ($disabledCount -gt 0) {
        Write-LWRetroPanelTextRow -Text ("{0} achievements are currently disabled by this run's mode settings." -f $disabledCount) -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementPlannedList {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWRetroPanelHeader -Title 'Planned Achievements' -AccentColor 'DarkMagenta'
    foreach ($entry in @(Get-LWPhaseTwoAchievementPlans)) {
        Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementsScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowAchievementsScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
}

Export-ModuleMember -Function New-LWAchievementProgressFlags, New-LWStoryAchievementFlags, New-LWAchievementState, New-LWAchievementDefinition, Get-LWAchievementStateSchemaVersion, Get-LWAchievementLoadBackfillVersion, Get-LWAchievementDefinitions, Get-LWPhaseTwoAchievementPlans, Ensure-LWAchievementState, Rebuild-LWStoryAchievementFlagsFromState, Test-LWStoryAchievementFlag, Set-LWStoryAchievementFlag, Test-LWAchievementStoryFlag, Register-LWStoryInventoryAchievementTriggers, Test-LWStateHasTorch, Get-LWAchievementDefinitionById, Test-LWAchievementAvailableInCurrentMode, Get-LWAchievementAvailabilityReason, Get-LWAchievementDisplayNameById, Get-LWAchievementLockedDisplayName, Get-LWAchievementUnlockedDisplayName, Get-LWAchievementLockedDisplayDescription, Get-LWAchievementEligibleCount, Get-LWAchievementEligibleUnlockedCount, Get-LWAchievementDisplayCounts, Get-LWRunCombatEntries, Get-LWRunVictoryEntries, Get-LWRunTotalRounds, Get-LWAllAchievementBookSummaries, Get-LWCompletedAchievementBookSummaries, Get-LWCombatEntryPlayerLossTotal, Rebuild-LWAchievementProgressFlags, Update-LWAchievementProgressFlagsFromSummary, New-LWAchievementEvaluationContext, Test-LWAchievementSyncSuppressed, Get-LWAchievementDefinitionsForContext, Test-LWAchievementUnlocked, Unlock-LWAchievement, Get-LWMaxWeaponVictoryCount, Get-LWSommerswerdUndeadVictoryCount, Test-LWAchievementSatisfied, Get-LWAchievementProgressText, Test-LWAchievementLoadBackfillCurrent, Set-LWAchievementLoadBackfillCurrent, Sync-LWAchievements, Get-LWAchievementUnlockedCount, Get-LWAchievementAvailableCount, Get-LWAchievementRecentUnlocks, Get-LWAchievementBookDisplayDefinitions, Show-LWAchievementOverview, Show-LWAchievementUnlockedList, Show-LWAchievementLockedList, Show-LWAchievementProgressList, Show-LWAchievementPlannedList, Show-LWAchievementsScreen

