Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Get-LWChainmailItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Chainmail Waistcoat', 'Chainmail Wastecoat', 'Chainmail')
}

function Get-LWPaddedLeatherItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Padded Leather Waistcoat', 'Padded Leather Wastecoat', 'Padded Leather Waste Coat', 'Padded Leather')
}

function Get-LWHelmetItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Helmet')
}

function Get-LWShieldItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Shield', 'Kai Shield')
}

function Get-LWSilverHelmItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Silver Helm')
}

function Get-LWMapOfSommerlundItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Map of Sommerlund')
}

function Get-LWGoldenKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Golden Key')
}

function Get-LWSealOfHammerdalItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Seal of Hammerdal')
}

function Get-LWCoachTicketItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Coach Ticket', 'Ticket')
}

function Get-LWWhitePassItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('White Pass')
}

function Get-LWRedPassItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Red Pass')
}

function Get-LWVordakGemItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Vordak Gem', 'Vordak Gems')
}

function Get-LWCrystalStarPendantItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Crystal Star Pendant')
}

function Get-LWMapOfKalteItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Map of Kalte')
}

function Get-LWSilverKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Silver Key')
}

function Get-LWTombGuardianGemsItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Tomb Guardian Gems')
}

function Get-LWPrincePelatharMessageItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @("Prince Pelathar's Message", 'Prince Pelathar Message', 'Message')
}

function Get-LWTabletOfPerfumedSoapItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Tablet of Perfumed Soap')
}

function Get-LWMapOfSouthlandsItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Map of the Southlands')
}

function Get-LWMapOfVassagoniaItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Map of Vassagonia', 'Map of the Desert Empire', 'Map of Vassagonia / Desert Empire')
}

function Get-LWMapOfStornlandsItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Map of the Stornlands', 'Map of Stornlands')
}

function Get-LWOedeHerbItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Oede Herb')
}

function Get-LWBlowpipeItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Blowpipe')
}

function Get-LWSleepDartItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Sleep Dart', 'Sleep Darts')
}

function Get-LWGaolersKeysItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @("Gaoler's Keys", "Gaoler's Keys", 'Gaolers Keys')
}

function Get-LWJakanBowWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Jakan Bow')
}

function Get-LWBowWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Bow')
}

function Get-LWQuiverItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Quiver')
}

function Get-LWArrowItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Arrow', 'Arrows')
}

function Get-LWQuiverArrowCapacity {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return 6
}

function Test-LWStateHasQuiver {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWQuiverItemNames) -Type 'special')))
}

function Get-LWQuiverArrowCount {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Inventory) {
        return 0
    }

    $rawValue = 0
    if ((Test-LWPropertyExists -Object $State.Inventory -Name 'QuiverArrows') -and $null -ne $State.Inventory.QuiverArrows) {
        $rawValue = [int]$State.Inventory.QuiverArrows
    }

    if (-not (Test-LWStateHasQuiver -State $State)) {
        return 0
    }

    $capacity = Get-LWQuiverArrowCapacity
    return [Math]::Max(0, [Math]::Min($rawValue, $capacity))
}

function Sync-LWQuiverArrowState {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Inventory) {
        return 0
    }

    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'QuiverArrows') -or $null -eq $State.Inventory.QuiverArrows) {
        $State.Inventory | Add-Member -Force -NotePropertyName QuiverArrows -NotePropertyValue 0
    }

    $normalized = if (Test-LWStateHasQuiver -State $State) {
        [Math]::Max(0, [Math]::Min([int]$State.Inventory.QuiverArrows, (Get-LWQuiverArrowCapacity)))
    }
    else {
        0
    }

    $State.Inventory.QuiverArrows = $normalized
    return $normalized
}

function Format-LWQuiverArrowCounter {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $current = Sync-LWQuiverArrowState -State $State
    return ("{0}/{1}" -f $current, (Get-LWQuiverArrowCapacity))
}

function Get-LWTowelItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Towel')
}

function Get-LWCopperKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Copper Key')
}

function Get-LWHerbPadItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Herb Pad')
}

function Get-LWSilverCombItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Silver Comb')
}

function Get-LWHourglassItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Hourglass')
}

function Get-LWMapOfTekaroItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Map of Tekaro')
}

function Get-LWTaunorWaterItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Taunor Water')
}

function Get-LWSmallSilverKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Small Silver Key')
}

function Get-LWSilverBowOfDuadonItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Silver Bow of Duadon', 'Silver Bow')
}

function Get-LWCessItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Cess')
}

function Get-LWBottleOfWineItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Bottle of Wine')
}

function Get-LWMirrorItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Mirror')
}

function Get-LWPrismItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Prism')
}

function Get-LWLarnumaOilItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Larnuma Oil', 'Vial of Larnuma Oil')
}

function Get-LWRendalimsElixirItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @("Rendalim's Elixir", 'Rendalims Elixir')
}

function Get-LWGallowbrushItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Potion of Gallowbrush', 'Gallowbrush')
}

function Get-LWCalacenaItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Tincture of Calacena', 'Calacena')
}

function Get-LWBlackSashItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Black Sash')
}

function Get-LWBrassWhistleItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Brass Whistle')
}

function Get-LWBottleOfKourshahItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Bottle of Kourshah', 'Kourshah')
}

function Get-LWBlackCrystalCubeItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Black Crystal Cube')
}

function Get-LWJewelledMaceItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Jewelled Mace')
}

function Get-LWBadgeOfRankItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Badge of Rank')
}

function Get-LWSpecialRationsItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Special Rations', 'Special Ration')
}

function Get-LWOnyxMedallionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Onyx Medallion')
}

function Get-LWFlaskOfHolyWaterItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Flask of Holy Water', 'Holy Water')
}

function Get-LWScrollItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Scroll')
}

function Get-LWCaptainDValSwordWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @("Captain D'Val's Sword", 'Captain DVal Sword')
}

function Get-LWSolnarisWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Solnaris', "Prince's Sword", 'Princes Sword', "Prince's Broadsword", 'Princes Broadsword')
}

function Get-LWDaggerOfVashnaItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Dagger of Vashna')
}

function Get-LWIronKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Iron Key')
}

function Get-LWBrassKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Brass Key')
}

function Get-LWWhipItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Whip')
}

function Get-LWPotionOfRedLiquidItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Potion of Red Liquid')
}

function Get-LWMiningToolItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Shovel', 'Pick', 'Pickaxe')
}

function Get-LWFiresphereItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Kalte Firesphere', 'Firesphere')
}

function Get-LWTorchItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Torch', 'Torches')
}

function Get-LWTinderboxItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Tinderbox')
}

function Get-LWBlanketItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Blanket')
}

function Get-LWHerbPouchItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Herb Pouch')
}

function Get-LWHerbPouchPotionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($group in @(
            (Get-LWHealingPotionItemNames),
            (Get-LWPotentHealingPotionItemNames),
            (Get-LWConcentratedHealingPotionItemNames),
            (Get-LWMinorHealingPotionItemNames),
            (Get-LWTaunorWaterItemNames),
            (Get-LWAletherPotionItemNames),
            (Get-LWGallowbrushItemNames),
            (Get-LWCalacenaItemNames),
            (Get-LWPotionOfRedLiquidItemNames),
            (Get-LWPotionOfOrangeLiquidItemNames)
        )) {
        foreach ($name in @($group)) {
            $resolvedName = [string]$name
            if ([string]::IsNullOrWhiteSpace($resolvedName)) {
                continue
            }
            if (-not $names.Contains($resolvedName)) {
                [void]$names.Add($resolvedName)
            }
        }
    }

    return @($names.ToArray())
}

function Test-LWHerbPouchPotionItemName {
    param([string]$Name = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHerbPouchPotionItemNames) -Target $Name)))
}

function Test-LWStateHasHerbPouch {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ($null -ne $State -and
        $null -ne $State.Inventory -and
        (Test-LWPropertyExists -Object $State.Inventory -Name 'HasHerbPouch') -and
        [bool]$State.Inventory.HasHerbPouch)
}

function Test-LWHerbPouchFeatureAvailable {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ($null -ne $State -and
        (Test-LWStateIsMagnakaiRuleset -State $State) -and
        [int]$State.Character.BookNumber -ge 6 -and
        (Get-LWBookSixDECuringOption -State $State) -eq 3)
}

function Get-LWBaknarOilItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Baknar Oil')
}

function Get-LWSleepingFursItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Sleeping Furs')
}

function Get-LWBlueStoneTriangleItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Blue Stone Triangle')
}

function Get-LWBlueStoneDiscItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Blue Stone Disc')
}

function Get-LWStoneEffigyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Stone Effigy', 'Effigy')
}

function Get-LWGoldBraceletItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Gold Bracelet')
}

function Get-LWOrnateSilverKeyItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Ornate Silver Key')
}

function Get-LWPotionOfOrangeLiquidItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Potion of Orange Liquid')
}

function Get-LWLaumspurHerbItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Laumspur Herb', 'Laumspur Herbs')
}

function Get-LWDrodarinWarHammerWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Drodarin War Hammer', 'Drodarin War Hammer +1', 'Drodarin Warhammer', 'Drodarin Warhammer +1')
}

function Get-LWBroninWarhammerItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Bronin Warhammer')
}

function Get-LWBroadswordPlusOneWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Broadsword +1')
}

function Get-LWSommerswerdItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Sommerswerd')
}

function Get-LWSommerswerdWeaponskillNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Short Sword', 'Sword', 'Broadsword')
}

function Get-LWBoneSwordWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Bone Sword', 'Bone Sword +1(K)', 'Bone Sowrd', 'Bone Sowrd +1(K)')
}

function Get-LWNonEdgeKnockoutWeaponNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Warhammer', 'Quarterstaff', 'Mace', 'Drodarin War Hammer', 'Drodarin War Hammer +1', 'Drodarin Warhammer', 'Drodarin Warhammer +1', 'Bronin Warhammer')
}

function Get-LWHealingPotionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Healing Potion', 'Laumspur Potion', 'Potion of Laumspur', 'Laumspur', 'Potion of Red Liquid')
}

function Get-LWPotentHealingPotionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Potent Laumspur Potion')
}

function Get-LWConcentratedHealingPotionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Concentrated Laumspur', 'Concentrated Laumspur Potion', 'Potion of Concentrated Laumspur')
}

function Get-LWMinorHealingPotionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Potion of Laumspur (3 END)')
}

function Get-LWAletherPotionItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Alether', 'Alether Potion', 'Potion of Alether')
}

function Get-LWAletherBerryItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Alether Berries')
}

function Get-LWMealOfLaumspurItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Meal of Laumspur')
}

function Get-LWGraveweedItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Vial of Graveweed', 'Graveweed')
}

function Get-LWMagicSpearItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Magic Spear')
}

function Get-LWKnownInventoryNameGroups {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @(
        @('Axe'),
        @('Sword'),
        @('Short Sword'),
        @('Dagger'),
        @('Spear'),
        @('Mace'),
        @('Warhammer'),
        @('Quarterstaff'),
        @('Broadsword'),
        @('Rope'),
        @('Meal'),
        @('Backpack'),
        (Get-LWChainmailItemNames),
        (Get-LWPaddedLeatherItemNames),
        (Get-LWHelmetItemNames),
        (Get-LWShieldItemNames),
        (Get-LWSilverHelmItemNames),
        (Get-LWMapOfSommerlundItemNames),
        (Get-LWGoldenKeyItemNames),
        (Get-LWSealOfHammerdalItemNames),
        (Get-LWCoachTicketItemNames),
        (Get-LWWhitePassItemNames),
        (Get-LWRedPassItemNames),
        (Get-LWVordakGemItemNames),
        (Get-LWCrystalStarPendantItemNames),
        (Get-LWMapOfKalteItemNames),
        (Get-LWSilverKeyItemNames),
        (Get-LWTombGuardianGemsItemNames),
        (Get-LWPrincePelatharMessageItemNames),
        (Get-LWTabletOfPerfumedSoapItemNames),
        (Get-LWMapOfSouthlandsItemNames),
        (Get-LWMapOfVassagoniaItemNames),
        (Get-LWMapOfStornlandsItemNames),
        (Get-LWOedeHerbItemNames),
        (Get-LWBlowpipeItemNames),
        (Get-LWSleepDartItemNames),
        (Get-LWGaolersKeysItemNames),
        (Get-LWJakanBowWeaponNames),
        (Get-LWBowWeaponNames),
        (Get-LWQuiverItemNames),
        (Get-LWArrowItemNames),
        (Get-LWTowelItemNames),
        (Get-LWCopperKeyItemNames),
        (Get-LWHerbPadItemNames),
        (Get-LWSilverCombItemNames),
        (Get-LWHourglassItemNames),
        (Get-LWMapOfTekaroItemNames),
        (Get-LWTaunorWaterItemNames),
        (Get-LWSmallSilverKeyItemNames),
        (Get-LWSilverBowOfDuadonItemNames),
        (Get-LWCessItemNames),
        (Get-LWBottleOfWineItemNames),
        (Get-LWMirrorItemNames),
        (Get-LWPrismItemNames),
        (Get-LWLarnumaOilItemNames),
        (Get-LWRendalimsElixirItemNames),
        (Get-LWGallowbrushItemNames),
        (Get-LWCalacenaItemNames),
        (Get-LWBlackSashItemNames),
        (Get-LWBrassWhistleItemNames),
        (Get-LWBottleOfKourshahItemNames),
        (Get-LWBlackCrystalCubeItemNames),
        (Get-LWJewelledMaceItemNames),
        (Get-LWBookOfMagnakaiItemNames),
        (Get-LWBadgeOfRankItemNames),
        (Get-LWSpecialRationsItemNames),
        (Get-LWOnyxMedallionItemNames),
        (Get-LWFlaskOfHolyWaterItemNames),
        (Get-LWScrollItemNames),
        (Get-LWCaptainDValSwordWeaponNames),
        (Get-LWSolnarisWeaponNames),
        (Get-LWDaggerOfVashnaItemNames),
        (Get-LWIronKeyItemNames),
        (Get-LWBrassKeyItemNames),
        (Get-LWWhipItemNames),
        (Get-LWPotionOfRedLiquidItemNames),
        (Get-LWMiningToolItemNames),
        (Get-LWFiresphereItemNames),
        (Get-LWTorchItemNames),
        (Get-LWTinderboxItemNames),
        (Get-LWBlanketItemNames),
        (Get-LWHerbPouchItemNames),
        (Get-LWBaknarOilItemNames),
        (Get-LWSleepingFursItemNames),
        (Get-LWBlueStoneTriangleItemNames),
        (Get-LWBlueStoneDiscItemNames),
        (Get-LWStoneEffigyItemNames),
        (Get-LWGoldBraceletItemNames),
        (Get-LWOrnateSilverKeyItemNames),
        (Get-LWPotionOfOrangeLiquidItemNames),
        (Get-LWLaumspurHerbItemNames),
        (Get-LWDrodarinWarHammerWeaponNames),
        (Get-LWBroninWarhammerItemNames),
        (Get-LWBroadswordPlusOneWeaponNames),
        (Get-LWSommerswerdItemNames),
        (Get-LWBoneSwordWeaponNames),
        (Get-LWHealingPotionItemNames),
        (Get-LWPotentHealingPotionItemNames),
        (Get-LWConcentratedHealingPotionItemNames),
        (Get-LWAletherPotionItemNames),
        (Get-LWMealOfLaumspurItemNames),
        (Get-LWGraveweedItemNames),
        (Get-LWMagicSpearItemNames),
        (Get-LWLongRopeItemNames)
    )
}

function Convert-LWInventoryNameToDisplayCase {
    param([Parameter(Mandatory = $true)][string]$Name)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $text = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $text
    }

    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    $displayName = $textInfo.ToTitleCase($text.ToLowerInvariant())
    $displayName = [regex]::Replace($displayName, "\b(Of|The|And|Or|To|In|On|For|With|From|A|An)\b", { param($match) $match.Value.ToLowerInvariant() })
    $displayName = [regex]::Replace($displayName, "(?<=\b[A-Za-z])'([a-z])", { param($match) "'" + $match.Groups[1].Value.ToUpperInvariant() })

    if ($displayName.Length -gt 0) {
        $displayName = $displayName.Substring(0, 1).ToUpperInvariant() + $displayName.Substring(1)
    }

    return $displayName
}

function Get-LWCanonicalInventoryItemName {
    param([string]$Name = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $Name
    }

    $trimmedName = $Name.Trim()
    foreach ($group in @(Get-LWKnownInventoryNameGroups)) {
        $match = Get-LWMatchingValue -Values @($group) -Target $trimmedName
        if (-not [string]::IsNullOrWhiteSpace($match)) {
            return [string]$match
        }
    }

    return (Convert-LWInventoryNameToDisplayCase -Name $trimmedName)
}

function Test-LWPotentHealingPotionName {
    param([string]$Name)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWPotentHealingPotionItemNames) -Target $Name)))
}

function Test-LWConcentratedHealingPotionName {
    param([string]$Name)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWConcentratedHealingPotionItemNames) -Target $Name)))
}

function Get-LWStateInventoryItems {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Type = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ($Type.Trim().ToLowerInvariant()) {
        'weapon' {
            return @($State.Inventory.Weapons)
        }
        'backpack' {
            return @($State.Inventory.BackpackItems)
        }
        'herbpouch' {
            return @($State.Inventory.HerbPouchItems)
        }
        'special' {
            return @($State.Inventory.SpecialItems)
        }
        default {
            return @($State.Inventory.Weapons) + @($State.Inventory.BackpackItems) + @($State.Inventory.HerbPouchItems) + @($State.Inventory.SpecialItems)
        }
    }
}

function Get-LWMatchingStateInventoryItem {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [string]$Type = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $items = @(Get-LWStateInventoryItems -State $State -Type $Type)
    foreach ($item in $items) {
        foreach ($name in @($Names)) {
            if ([string]$item -ieq $name) {
                return [string]$item
            }
        }
    }

    return $null
}

function Test-LWStateHasInventoryItem {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [string]$Type = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names $Names -Type $Type)))
}

function Find-LWStateInventoryItemLocation {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [string[]]$Types = @('herbpouch', 'backpack', 'special', 'weapon')
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    foreach ($type in @($Types)) {
        $match = Get-LWMatchingStateInventoryItem -State $State -Names $Names -Type $type
        if (-not [string]::IsNullOrWhiteSpace($match)) {
            return [pscustomobject]@{
                Type = [string]$type
                Name = [string]$match
            }
        }
    }

    return $null
}

function Remove-LWStateInventoryItemByNames {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [int]$Quantity = 1,
        [string[]]$Types = @('herbpouch', 'backpack', 'special', 'weapon')
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Quantity -lt 1) {
        return 0
    }

    $location = Find-LWStateInventoryItemLocation -State $State -Names $Names -Types $Types
    if ($null -eq $location) {
        return 0
    }

    return (Remove-LWInventoryItemSilently -Type ([string]$location.Type) -Name ([string]$location.Name) -Quantity $Quantity)
}

function Get-LWStateChainmailEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWChainmailItemNames)) {
        return 4
    }

    return 0
}

function Get-LWStatePaddedLeatherEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWPaddedLeatherItemNames) -Type 'special') {
        return 2
    }

    return 0
}

function Get-LWStateHelmetEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ((Get-LWStateSilverHelmCombatSkillBonus -State $State) -gt 0) {
        return 0
    }

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWHelmetItemNames) -Type 'special') {
        return 2
    }

    return 0
}

function Get-LWStateShieldCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ((Test-LWPropertyExists -Object $State -Name 'Combat') -and
        (Test-LWPropertyExists -Object $State.Combat -Name 'SuppressShieldCombatSkillBonus') -and
        [bool]$State.Combat.SuppressShieldCombatSkillBonus) {
        return 0
    }

    if (Test-LWBookFiveLimbdeathActive -State $State) {
        return 0
    }

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames)) {
        return 2
    }

    return 0
}

function Get-LWStateSilverHelmCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSilverHelmItemNames) -Type 'special') {
        return 2
    }

    return 0
}

function Test-LWWeaponIsBoneSword {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBoneSwordWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsDrodarinWarHammer {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWDrodarinWarHammerWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsBroninWarhammer {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBroninWarhammerItemNames) -Target $Weapon)))
}

function Test-LWWeaponIsBroadswordPlusOne {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBroadswordPlusOneWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsSolnaris {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSolnarisWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsMagicSpear {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMagicSpearItemNames) -Target $Weapon)))
}

function Test-LWStateHasBoneSword {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBoneSwordWeaponNames) -Type 'weapon')
}

function Test-LWStateHasDrodarinWarHammer {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWDrodarinWarHammerWeaponNames) -Type 'weapon')
}

function Test-LWStateHasBroninWarhammer {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBroninWarhammerItemNames) -Type 'special')
}

function Test-LWStateHasBroadswordPlusOne {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBroadswordPlusOneWeaponNames) -Type 'weapon')
}

function Test-LWStateHasSolnaris {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSolnarisWeaponNames) -Type 'weapon')
}

function Test-LWStateHasMagicSpear {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWMagicSpearItemNames) -Type 'special')
}

function Test-LWWeaponIsCaptainDValSword {
    param([string]$Weapon)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCaptainDValSwordWeaponNames) -Target $Weapon)))
}

function Test-LWStateHasBackpack {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Inventory) {
        return $true
    }

    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasBackpack') -or $null -eq $State.Inventory.HasBackpack) {
        return $true
    }

    return [bool]$State.Inventory.HasBackpack
}

function Test-LWStateHasFiresphere {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWFiresphereItemNames))
}

function Test-LWStateHasBaknarOilApplied {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return $false
    }

    if ($State -eq $script:GameState) {
        return (Test-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied')
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'Achievements') -or $null -eq $State.Achievements) {
        return $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'StoryFlags') -or $null -eq $State.Achievements.StoryFlags) {
        return $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Achievements.StoryFlags -Name 'Book3BaknarOilApplied')) {
        return $false
    }

    return [bool]$State.Achievements.StoryFlags.Book3BaknarOilApplied
}

function Ensure-LWEquipmentBonusState {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWPropertyExists -Object $State -Name 'EquipmentBonuses') -or $null -eq $State.EquipmentBonuses) {
        $State | Add-Member -Force -NotePropertyName EquipmentBonuses -NotePropertyValue ([pscustomobject]@{
                ChainmailEndurance = 0
                PaddedLeatherEndurance = 0
                HelmetEndurance = 0
            })
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'ChainmailEndurance') -or $null -eq $State.EquipmentBonuses.ChainmailEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName ChainmailEndurance -NotePropertyValue 0
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'PaddedLeatherEndurance') -or $null -eq $State.EquipmentBonuses.PaddedLeatherEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName PaddedLeatherEndurance -NotePropertyValue 0
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'HelmetEndurance') -or $null -eq $State.EquipmentBonuses.HelmetEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName HelmetEndurance -NotePropertyValue 0
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'DaggerOfVashnaEndurance') -or $null -eq $State.EquipmentBonuses.DaggerOfVashnaEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName DaggerOfVashnaEndurance -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'LoreCircleCombatSkill') -or $null -eq $State.EquipmentBonuses.LoreCircleCombatSkill) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName LoreCircleCombatSkill -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'LoreCircleEndurance') -or $null -eq $State.EquipmentBonuses.LoreCircleEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName LoreCircleEndurance -NotePropertyValue 0
    }
}

function Sync-LWStateEquipmentBonuses {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$WriteMessages
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Ensure-LWEquipmentBonusState -State $State

    $desiredChainmail = Get-LWStateChainmailEnduranceBonus -State $State
    $appliedChainmail = [int]$State.EquipmentBonuses.ChainmailEndurance
    $chainmailDelta = $desiredChainmail - $appliedChainmail

    $desiredPaddedLeather = Get-LWStatePaddedLeatherEnduranceBonus -State $State
    $appliedPaddedLeather = [int]$State.EquipmentBonuses.PaddedLeatherEndurance
    $paddedLeatherDelta = $desiredPaddedLeather - $appliedPaddedLeather

    $desiredHelmet = Get-LWStateHelmetEnduranceBonus -State $State
    $appliedHelmet = [int]$State.EquipmentBonuses.HelmetEndurance
    $helmetDelta = $desiredHelmet - $appliedHelmet

    $desiredDaggerOfVashna = Get-LWStateDaggerOfVashnaEndurancePenalty -State $State
    $appliedDaggerOfVashna = [int]$State.EquipmentBonuses.DaggerOfVashnaEndurance
    $daggerOfVashnaDelta = $desiredDaggerOfVashna - $appliedDaggerOfVashna

    $desiredLoreCircleEndurance = Get-LWStateLoreCircleEnduranceBonus -State $State
    $appliedLoreCircleEndurance = [int]$State.EquipmentBonuses.LoreCircleEndurance
    $loreCircleEnduranceDelta = $desiredLoreCircleEndurance - $appliedLoreCircleEndurance

    $delta = $chainmailDelta + $paddedLeatherDelta + $helmetDelta + $daggerOfVashnaDelta + $loreCircleEnduranceDelta

    if ($delta -eq 0) {
        $State.EquipmentBonuses.LoreCircleCombatSkill = Get-LWStateLoreCircleCombatSkillBonus -State $State
        $State.EquipmentBonuses.LoreCircleEndurance = $desiredLoreCircleEndurance
        $State.Character.LoreCirclesCompleted = @((Get-LWStateCompletedLoreCircles -State $State) | ForEach-Object { [string]$_.Name })
        return
    }

    $newMax = [Math]::Max(1, ([int]$State.Character.EnduranceMax + $delta))
    $newCurrent = [int]$State.Character.EnduranceCurrent + $delta
    if ($newCurrent -lt 0) {
        $newCurrent = 0
    }
    if ($newCurrent -gt $newMax) {
        $newCurrent = $newMax
    }

    $State.Character.EnduranceMax = $newMax
    $State.Character.EnduranceCurrent = $newCurrent
    $State.EquipmentBonuses.ChainmailEndurance = $desiredChainmail
    $State.EquipmentBonuses.PaddedLeatherEndurance = $desiredPaddedLeather
    $State.EquipmentBonuses.HelmetEndurance = $desiredHelmet
    $State.EquipmentBonuses.DaggerOfVashnaEndurance = $desiredDaggerOfVashna
    $State.EquipmentBonuses.LoreCircleCombatSkill = Get-LWStateLoreCircleCombatSkillBonus -State $State
    $State.EquipmentBonuses.LoreCircleEndurance = $desiredLoreCircleEndurance
    $State.Character.LoreCirclesCompleted = @((Get-LWStateCompletedLoreCircles -State $State) | ForEach-Object { [string]$_.Name })

    if ($WriteMessages) {
        if ($chainmailDelta -ne 0) {
            $direction = if ($chainmailDelta -gt 0) { 'applied' } else { 'removed' }
            Write-LWInfo ("Chainmail Waistcoat bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $chainmailDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($paddedLeatherDelta -ne 0) {
            $direction = if ($paddedLeatherDelta -gt 0) { 'applied' } else { 'removed' }
            Write-LWInfo ("Padded Leather Waistcoat bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $paddedLeatherDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($helmetDelta -ne 0) {
            $direction = if ($helmetDelta -gt 0) { 'applied' } else { 'removed' }
            Write-LWInfo ("Helmet bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $helmetDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($daggerOfVashnaDelta -ne 0) {
            $direction = if ($daggerOfVashnaDelta -lt 0) { 'applied' } else { 'removed' }
            Write-LWWarn ("Dagger of Vashna drain {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $daggerOfVashnaDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($loreCircleEnduranceDelta -ne 0) {
            Write-LWInfo ("Lore-circle END bonus updated: {0}. Current Endurance: {1} / {2}." -f (Format-LWSigned -Value $loreCircleEnduranceDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
    }
}

function Get-LWRandomDigit {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return (Get-Random -Minimum 0 -Maximum 10)
}

Export-ModuleMember -Function Get-LWChainmailItemNames, Get-LWPaddedLeatherItemNames, Get-LWHelmetItemNames, Get-LWShieldItemNames, Get-LWSilverHelmItemNames, Get-LWMapOfSommerlundItemNames, Get-LWGoldenKeyItemNames, Get-LWSealOfHammerdalItemNames, Get-LWCoachTicketItemNames, Get-LWWhitePassItemNames, Get-LWRedPassItemNames, Get-LWVordakGemItemNames, Get-LWCrystalStarPendantItemNames, Get-LWMapOfKalteItemNames, Get-LWSilverKeyItemNames, Get-LWTombGuardianGemsItemNames, Get-LWPrincePelatharMessageItemNames, Get-LWTabletOfPerfumedSoapItemNames, Get-LWMapOfSouthlandsItemNames, Get-LWMapOfVassagoniaItemNames, Get-LWMapOfStornlandsItemNames, Get-LWOedeHerbItemNames, Get-LWBlowpipeItemNames, Get-LWSleepDartItemNames, Get-LWGaolersKeysItemNames, Get-LWJakanBowWeaponNames, Get-LWBowWeaponNames, Get-LWQuiverItemNames, Get-LWArrowItemNames, Get-LWQuiverArrowCapacity, Test-LWStateHasQuiver, Get-LWQuiverArrowCount, Sync-LWQuiverArrowState, Format-LWQuiverArrowCounter, Get-LWTowelItemNames, Get-LWCopperKeyItemNames, Get-LWHerbPadItemNames, Get-LWSilverCombItemNames, Get-LWHourglassItemNames, Get-LWMapOfTekaroItemNames, Get-LWTaunorWaterItemNames, Get-LWSmallSilverKeyItemNames, Get-LWSilverBowOfDuadonItemNames, Get-LWCessItemNames, Get-LWBottleOfWineItemNames, Get-LWMirrorItemNames, Get-LWPrismItemNames, Get-LWLarnumaOilItemNames, Get-LWRendalimsElixirItemNames, Get-LWGallowbrushItemNames, Get-LWCalacenaItemNames, Get-LWBlackSashItemNames, Get-LWBrassWhistleItemNames, Get-LWBottleOfKourshahItemNames, Get-LWBlackCrystalCubeItemNames, Get-LWJewelledMaceItemNames, Get-LWBadgeOfRankItemNames, Get-LWSpecialRationsItemNames, Get-LWOnyxMedallionItemNames, Get-LWFlaskOfHolyWaterItemNames, Get-LWScrollItemNames, Get-LWCaptainDValSwordWeaponNames, Get-LWSolnarisWeaponNames, Get-LWDaggerOfVashnaItemNames, Get-LWIronKeyItemNames, Get-LWBrassKeyItemNames, Get-LWWhipItemNames, Get-LWPotionOfRedLiquidItemNames, Get-LWMiningToolItemNames, Get-LWFiresphereItemNames, Get-LWTorchItemNames, Get-LWTinderboxItemNames, Get-LWBlanketItemNames, Get-LWHerbPouchItemNames, Get-LWHerbPouchPotionItemNames, Test-LWHerbPouchPotionItemName, Test-LWStateHasHerbPouch, Test-LWHerbPouchFeatureAvailable, Get-LWBaknarOilItemNames, Get-LWSleepingFursItemNames, Get-LWBlueStoneTriangleItemNames, Get-LWBlueStoneDiscItemNames, Get-LWStoneEffigyItemNames, Get-LWGoldBraceletItemNames, Get-LWOrnateSilverKeyItemNames, Get-LWPotionOfOrangeLiquidItemNames, Get-LWLaumspurHerbItemNames, Get-LWDrodarinWarHammerWeaponNames, Get-LWBroninWarhammerItemNames, Get-LWBroadswordPlusOneWeaponNames, Get-LWSommerswerdItemNames, Get-LWSommerswerdWeaponskillNames, Get-LWBoneSwordWeaponNames, Get-LWNonEdgeKnockoutWeaponNames, Get-LWHealingPotionItemNames, Get-LWPotentHealingPotionItemNames, Get-LWConcentratedHealingPotionItemNames, Get-LWMinorHealingPotionItemNames, Get-LWAletherPotionItemNames, Get-LWAletherBerryItemNames, Get-LWMealOfLaumspurItemNames, Get-LWGraveweedItemNames, Get-LWMagicSpearItemNames, Get-LWKnownInventoryNameGroups, Convert-LWInventoryNameToDisplayCase, Get-LWCanonicalInventoryItemName, Test-LWPotentHealingPotionName, Test-LWConcentratedHealingPotionName, Get-LWStateInventoryItems, Get-LWMatchingStateInventoryItem, Test-LWStateHasInventoryItem, Find-LWStateInventoryItemLocation, Remove-LWStateInventoryItemByNames, Get-LWStateChainmailEnduranceBonus, Get-LWStatePaddedLeatherEnduranceBonus, Get-LWStateHelmetEnduranceBonus, Get-LWStateShieldCombatSkillBonus, Get-LWStateSilverHelmCombatSkillBonus, Test-LWWeaponIsBoneSword, Test-LWWeaponIsDrodarinWarHammer, Test-LWWeaponIsBroninWarhammer, Test-LWWeaponIsBroadswordPlusOne, Test-LWWeaponIsSolnaris, Test-LWWeaponIsMagicSpear, Test-LWStateHasBoneSword, Test-LWStateHasDrodarinWarHammer, Test-LWStateHasBroninWarhammer, Test-LWStateHasBroadswordPlusOne, Test-LWStateHasSolnaris, Test-LWStateHasMagicSpear, Test-LWWeaponIsCaptainDValSword, Test-LWStateHasBackpack, Test-LWStateHasFiresphere, Test-LWStateHasBaknarOilApplied, Ensure-LWEquipmentBonusState, Sync-LWStateEquipmentBonuses, Get-LWRandomDigit

