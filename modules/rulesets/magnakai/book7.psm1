Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

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

function Get-LWBookSevenPowerKeyItemNames { return @('Power-key', 'Power Key') }
function Get-LWBookSevenSkeletonKeyItemNames { return @('Skeleton Key') }
function Get-LWBookSevenParchmentItemNames { return @('Parchment') }
function Get-LWBookSevenPlatinumAmuletItemNames { return @('Kazan-Oud Platinum Amulet', 'Platinum Amulet') }
function Get-LWBookSevenDiamondItemNames { return @('Diamond') }
function Get-LWBookSevenSilverWhistleItemNames { return @('Silver Whistle') }
function Get-LWBookSevenGoldKeyItemNames { return @('Gold Key') }
function Get-LWBookSevenFireseedItemNames { return @('Fireseed', 'Fireseeds') }
function Get-LWBookSevenLanternItemNames { return @('Lantern') }
function Get-LWBookSevenSabitoItemNames { return @('Sabito', 'Blue Pills') }
function Get-LWBookSevenBottleOfWaterItemNames { return @('Bottle of Water') }
function Get-LWBookSevenRedRobeItemNames { return @('Red Robe') }
function Get-LWBookSevenWeaponLikeSpecialItemNames {
    return @(
        (Get-LWSommerswerdItemNames)
        (Get-LWMagicSpearItemNames)
        (Get-LWSilverBowOfDuadonItemNames)
        (Get-LWBroninWarhammerItemNames)
        (Get-LWDaggerOfVashnaItemNames)
        (Get-LWJewelledMaceItemNames)
    )
}

function Test-LWBookSevenHasPrimateRank {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Character) {
        return $false
    }

    return ([int]$State.Character.MagnakaiRank -ge 4)
}

function Test-LWBookSevenHasPlatinumAmulet {
    param([object]$State = $script:GameState)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBookSevenPlatinumAmuletItemNames) -Type 'special')
}

function Get-LWMagnakaiBookSevenStartingChoices {
    Set-LWModuleContext -Context (Get-LWModuleContext)

    return @(
        [pscustomobject]@{ Id = 'sword'; Type = 'weapon'; Name = 'Sword'; DisplayName = 'Sword'; Description = 'Sword' },
        [pscustomobject]@{ Id = 'bow'; Type = 'weapon'; Name = 'Bow'; DisplayName = 'Bow'; Description = 'Bow' },
        [pscustomobject]@{ Id = 'quiver'; Type = 'special'; Name = 'Quiver'; DisplayName = 'Quiver'; Description = 'Quiver with 6 Arrows' },
        [pscustomobject]@{ Id = 'rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; DisplayName = 'Rope'; Description = 'Rope' },
        [pscustomobject]@{ Id = 'laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; DisplayName = 'Potion of Laumspur'; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'lantern'; Type = 'backpack'; Name = 'Lantern'; Quantity = 1; DisplayName = 'Lantern'; Description = 'Lantern' },
        [pscustomobject]@{ Id = 'mace'; Type = 'weapon'; Name = 'Mace'; DisplayName = 'Mace'; Description = 'Mace' },
        [pscustomobject]@{ Id = 'meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; DisplayName = '3 Meals'; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'dagger'; Type = 'weapon'; Name = 'Dagger'; DisplayName = 'Dagger'; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'fireseeds'; Type = 'pocketspecial'; Name = 'Fireseed'; Quantity = 3; DisplayName = '3 Fireseeds'; Description = '3 Fireseeds' }
    )
}

function Grant-LWMagnakaiBookSevenStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    $quantity = if ((Test-LWPropertyExists -Object $Choice -Name 'Quantity') -and $null -ne $Choice.Quantity) { [int]$Choice.Quantity } else { 1 }

    if ([string]$Choice.Id -eq 'quiver') {
        if (-not (Test-LWStateHasQuiver -State $script:GameState)) {
            if (-not (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Quiver' -Quantity 1)) {
                Write-LWWarn 'No room to add the Quiver automatically. Make room and try again if you are keeping it.'
                return $false
            }
        }

        $script:GameState.Inventory.QuiverArrows = Get-LWQuiverArrowCapacity
        Write-LWInfo 'Book 7 starting item added: Quiver with 6 Arrows.'
        return $true
    }

    if ([string]$Choice.Type -eq 'pocketspecial') {
        $added = 0
        for ($i = 0; $i -lt $quantity; $i++) {
            if (TryAdd-LWPocketSpecialItemSilently -Name ([string]$Choice.Name)) {
                $added++
            }
        }

        if ($added -eq $quantity) {
            Write-LWInfo ("Book 7 starting item added: {0}." -f [string]$Choice.Description)
            return $true
        }

        Write-LWWarn ("Could not add all of the Book 7 starting item '{0}' automatically." -f [string]$Choice.DisplayName)
        return $false
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity $quantity) {
        Write-LWInfo ("Book 7 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 7 starting item '{0}' automatically. Make room and add it manually if needed." -f [string]$Choice.DisplayName)
    return $false
}

function Add-LWBookSevenPocketItem {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$FlagName = '',
        [string]$SuccessMessage = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($FlagName) -and (Test-LWStoryAchievementFlag -Name $FlagName)) {
        return $true
    }

    if (TryAdd-LWPocketSpecialItemSilently -Name $Name) {
        if (-not [string]::IsNullOrWhiteSpace($FlagName)) {
            Set-LWStoryAchievementFlag -Name $FlagName
        }
        if (-not [string]::IsNullOrWhiteSpace($SuccessMessage)) {
            Write-LWInfo $SuccessMessage
        }
        return $true
    }

    Write-LWWarn ("No room to add {0} automatically. Make room and add it manually if you are keeping it." -f $Name)
    return $false
}

function Ensure-LWBookSevenSectionOnePowerKey {
    param(
        [string]$SuccessMessage = 'Section 1: Power-key added to Pocket Items.'
    )

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 7) {
        return $false
    }

    if ([int]$script:GameState.CurrentSection -ne 1) {
        return $false
    }

    if (-not (Test-LWStoryAchievementFlag -Name 'Book7PowerKeyClaimed') -and -not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenPowerKeyItemNames))) {
        return (Add-LWBookSevenPocketItem -Name 'Power-key' -FlagName 'Book7PowerKeyClaimed' -SuccessMessage $SuccessMessage)
    }

    if (-not (Test-LWStoryAchievementFlag -Name 'Book7PowerKeyClaimed')) {
        Set-LWStoryAchievementFlag -Name 'Book7PowerKeyClaimed'
    }

    return $true
}

function Get-LWMagnakaiBookSevenSection015ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book7Section015ConcentratedLaumspurClaimed'; DisplayName = 'Concentrated Laumspur'; Type = 'backpack'; Name = 'Concentrated Healing Potion'; Quantity = 1; Description = 'Concentrated Laumspur' },
        [pscustomobject]@{ Id = 'amulet'; FlagName = 'Book7PlatinumAmuletClaimed'; DisplayName = 'Kazan-Oud Platinum Amulet'; Type = 'special'; Name = 'Kazan-Oud Platinum Amulet'; Quantity = 1; Description = 'Kazan-Oud Platinum Amulet' }
    )
}

function Get-LWMagnakaiBookSevenSection080ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book7Section080SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'short_sword_a'; FlagName = 'Book7Section080ShortSwordAClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'short_sword_b'; FlagName = 'Book7Section080ShortSwordBClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'axe'; FlagName = 'Book7Section080AxeClaimed'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'dagger_a'; FlagName = 'Book7Section080DaggerAClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'dagger_b'; FlagName = 'Book7Section080DaggerBClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book7Section080MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book7Section080GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' }
    )
}

function Get-LWMagnakaiBookSevenSection148ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book7Section148MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'padded'; FlagName = 'Book7Section148PaddedClaimed'; DisplayName = 'Padded Leather Waistcoat'; Type = 'special'; Name = 'Padded Leather Waistcoat'; Quantity = 1; Description = 'Padded Leather Waistcoat' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book7Section148SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'helmet'; FlagName = 'Book7Section148HelmetClaimed'; DisplayName = 'Helmet'; Type = 'special'; Name = 'Helmet'; Quantity = 1; Description = 'Helmet' },
        [pscustomobject]@{ Id = 'blanket'; FlagName = 'Book7Section148BlanketClaimed'; DisplayName = 'Blanket'; Type = 'backpack'; Name = 'Blanket'; Quantity = 1; Description = 'Blanket' },
        [pscustomobject]@{ Id = 'wine'; FlagName = 'Book7Section148WineClaimed'; DisplayName = 'Bottle of Wine'; Type = 'backpack'; Name = 'Bottle of Wine'; Quantity = 1; Description = 'Bottle of Wine' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book7Section148DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book7Section148LaumspurClaimed'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' }
    )
}

function Get-LWMagnakaiBookSevenSection186ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book7Section186SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'whistle'; FlagName = 'Book7SilverWhistleClaimed'; DisplayName = 'Silver Whistle'; Type = 'special'; Name = 'Silver Whistle'; Quantity = 1; Description = 'Silver Whistle' }
    )
}

function Get-LWMagnakaiBookSevenSection199ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book7Section199GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book7Section199RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' },
        [pscustomobject]@{ Id = 'lantern'; FlagName = 'Book7Section199LanternClaimed'; DisplayName = 'Lantern'; Type = 'backpack'; Name = 'Lantern'; Quantity = 1; Description = 'Lantern' }
    )
}

function Get-LWMagnakaiBookSevenSection220ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'axe'; FlagName = 'Book7Section220AxeClaimed'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book7Section220DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' }
    )
}

function Get-LWMagnakaiBookSevenSection227ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book7Section227MealClaimed'; DisplayName = '1 Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = '1 Meal' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book7Section227RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' },
        [pscustomobject]@{ Id = 'blanket'; FlagName = 'Book7Section227BlanketClaimed'; DisplayName = 'Blanket'; Type = 'backpack'; Name = 'Blanket'; Quantity = 1; Description = 'Blanket' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book7Section227DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'water'; FlagName = 'Book7Section227WaterClaimed'; DisplayName = 'Bottle of Water'; Type = 'backpack'; Name = 'Bottle of Water'; Quantity = 1; Description = 'Bottle of Water' },
        [pscustomobject]@{ Id = 'sabito'; FlagName = 'Book7SabitoIdentified'; DisplayName = 'Sabito'; Type = 'backpack'; Name = 'Sabito'; Quantity = 1; Description = 'Sabito' },
        [pscustomobject]@{ Id = 'blue_pills'; FlagName = 'Book7Section227BluePillsClaimed'; DisplayName = 'Blue Pills'; Type = 'backpack'; Name = 'Blue Pills'; Quantity = 1; Description = 'Blue Pills' }
    )
}

function Get-LWMagnakaiBookSevenSection238ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'axe'; FlagName = 'Book7Section238AxeClaimed'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book7Section238ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book7Section238DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book7Section238GoldClaimed'; DisplayName = '2 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 2; Description = '2 Gold Crowns' }
    )
}

function Get-LWMagnakaiBookSevenSection262ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book7Section262ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'shield'; FlagName = 'Book7Section262ShieldClaimed'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' }
    )
}

function Get-LWMagnakaiBookSevenSection333ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book7Section333SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'quarterstaff'; FlagName = 'Book7Section333QuarterstaffClaimed'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' }
    )
}

function Invoke-LWMagnakaiBookSevenMealRequirement {
    param(
        [Parameter(Mandatory = $true)][string]$ResolvedFlagName,
        [Parameter(Mandatory = $true)][string]$NoMealFlagName,
        [Parameter(Mandatory = $true)][string]$SectionLabel,
        [Parameter(Mandatory = $true)][string]$NoMealMessagePrefix,
        [Parameter(Mandatory = $true)][string]$FatalCause
    )

    if (Test-LWStoryAchievementFlag -Name $ResolvedFlagName) {
        return
    }

    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Huntmastery') {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Register-LWMealCoveredByHunting
        Write-LWInfo ("{0}: Huntmastery covers the Meal requirement." -f $SectionLabel)
        return
    }

    if (Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 1) {
        Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        Register-LWMealConsumed
        Write-LWInfo ("{0}: 1 Meal consumed." -f $SectionLabel)
        return
    }

    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName $NoMealFlagName -Delta -3 -MessagePrefix $NoMealMessagePrefix -FatalCause $FatalCause)
    Set-LWStoryAchievementFlag -Name $ResolvedFlagName
    Register-LWStarvationPenalty
}

function Invoke-LWMagnakaiBookSevenChooseLostBackpackItems {
    param([int]$Count = 2)

    $remaining = [Math]::Max(0, [int]$Count)
    while ($remaining -gt 0) {
        $items = @(Get-LWInventoryItems -Type 'backpack')
        if ($items.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Choose Lost Backpack Item' -AccentColor 'DarkYellow'
        Write-LWSubtle ("  Choose item #{0} to lose." -f (($Count - $remaining) + 1))
        Write-Host ''
        for ($i = 0; $i -lt $items.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$items[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
        }

        $choiceIndex = if ($items.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Lost backpack item number' -Min 1 -Max $items.Count -NoRefresh }
        $lostItem = [string]$items[$choiceIndex - 1]
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $lostItem -Quantity 1)
        Write-LWInfo ("Backpack item lost: {0}." -f $lostItem)
        $remaining--
    }
}

function Invoke-LWMagnakaiBookSevenSection158BackpackLoss {
    if (Test-LWStoryAchievementFlag -Name 'Book7Section158BackpackLossApplied') {
        return
    }

    Set-LWStoryAchievementFlag -Name 'Book7Section158BackpackLossApplied'

    $foodRemoved = 0
    foreach ($foodName in @('Meal', 'Special Rations', 'Meal of Laumspur')) {
        while (Remove-LWInventoryItemSilently -Type 'backpack' -Name $foodName -Quantity 1) {
            $foodRemoved++
        }
    }

    if ($foodRemoved -gt 0) {
        Write-LWInfo ("Section 158: tainted water ruins {0} food item{1}." -f $foodRemoved, $(if ($foodRemoved -eq 1) { '' } else { 's' }))
    }

    Invoke-LWMagnakaiBookSevenChooseLostBackpackItems -Count 2
}

function Invoke-LWMagnakaiBookSevenLoseCurrentWeapon {
    param([Parameter(Mandatory = $true)][string]$FlagName)

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return
    }

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($weapons.Count -eq 0) {
        Set-LWStoryAchievementFlag -Name $FlagName
        Write-LWInfo 'No carried weapon is available to lose here.'
        return
    }

    Write-LWPanelHeader -Title 'Choose Lost Weapon' -AccentColor 'DarkYellow'
    Write-LWSubtle '  Choose the weapon that is lost here.'
    Write-Host ''
    for ($i = 0; $i -lt $weapons.Count; $i++) {
        Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$weapons[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
    }

    $choiceIndex = if ($weapons.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Lost weapon number' -Min 1 -Max $weapons.Count -NoRefresh }
    $lostWeapon = [string]$weapons[$choiceIndex - 1]
    [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $lostWeapon -Quantity 1)
    Set-LWStoryAchievementFlag -Name $FlagName
    Write-LWInfo ("Weapon lost: {0}." -f $lostWeapon)
}

function Invoke-LWMagnakaiBookSevenWeaponConfiscation {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][string]$Reason,
        [int]$EnduranceLoss = 0,
        [switch]$AllCarriedGear
    )

    if ($AllCarriedGear) {
        $recoveryWeapons = @(Get-LWInventoryRecoveryItems -Type 'weapon')
        $recoveryBackpack = @(Get-LWInventoryRecoveryItems -Type 'backpack')
        $recoveryHerbPouch = @(Get-LWInventoryRecoveryItems -Type 'herbpouch')
        $recoverySpecials = @(Get-LWInventoryRecoveryItems -Type 'special')
        $hasRecoveryGear = (($recoveryWeapons.Count + $recoveryBackpack.Count + $recoveryHerbPouch.Count + $recoverySpecials.Count) -gt 0)
        $hasCarriedGear = (
            @($script:GameState.Inventory.Weapons).Count -gt 0 -or
            @($script:GameState.Inventory.BackpackItems).Count -gt 0 -or
            @($script:GameState.Inventory.HerbPouchItems).Count -gt 0 -or
            @($script:GameState.Inventory.SpecialItems).Count -gt 0 -or
            @(Get-LWPocketSpecialItems).Count -gt 0 -or
            [int]$script:GameState.Inventory.GoldCrowns -gt 0 -or
            [bool]$script:GameState.Inventory.HasBackpack -or
            [bool]$script:GameState.Inventory.HasHerbPouch
        )

        $alreadyApplied = Test-LWStoryAchievementFlag -Name $FlagName
        if ($alreadyApplied -and -not $hasCarriedGear -and -not $hasRecoveryGear) {
            return
        }

        if ($alreadyApplied) {
            if ($hasCarriedGear) {
                Write-LWWarn ("Section {0}: confiscation was already marked as handled, but carried gear remains. Stashing it now." -f [int]$script:GameState.CurrentSection)
            }
        }
        elseif ($EnduranceLoss -gt 0) {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName ("{0}LossApplied" -f $FlagName) -Delta (-1 * $EnduranceLoss) -MessagePrefix $Reason -FatalCause ("The ordeal at section {0} reduced your Endurance to zero." -f [int]$script:GameState.CurrentSection))
        }
        else {
            Write-LWInfo $Reason
        }

        if ($hasCarriedGear) {
            Save-LWConfiscatedEquipment -WriteMessages -Reason ("Section {0}: all carried gear confiscated for later recovery" -f [int]$script:GameState.CurrentSection)
        }
        if ($hasRecoveryGear) {
            $script:GameState.Storage.Confiscated.Weapons = @($script:GameState.Storage.Confiscated.Weapons + $recoveryWeapons)
            $script:GameState.Storage.Confiscated.BackpackItems = @($script:GameState.Storage.Confiscated.BackpackItems + $recoveryBackpack)
            $script:GameState.Storage.Confiscated.HerbPouchItems = @($script:GameState.Storage.Confiscated.HerbPouchItems + $recoveryHerbPouch)
            $script:GameState.Storage.Confiscated.SpecialItems = @($script:GameState.Storage.Confiscated.SpecialItems + $recoverySpecials)
            if ($null -eq $script:GameState.Storage.Confiscated.BookNumber) {
                $script:GameState.Storage.Confiscated.BookNumber = [int]$script:GameState.Character.BookNumber
            }
            if ($null -eq $script:GameState.Storage.Confiscated.Section) {
                $script:GameState.Storage.Confiscated.Section = [int]$script:GameState.CurrentSection
            }
            if ([string]::IsNullOrWhiteSpace([string]$script:GameState.Storage.Confiscated.SavedOn)) {
                $script:GameState.Storage.Confiscated.SavedOn = (Get-Date).ToString('o')
            }
            Clear-LWInventoryRecoveryEntry -Type 'weapon'
            Clear-LWInventoryRecoveryEntry -Type 'backpack'
            Clear-LWInventoryRecoveryEntry -Type 'herbpouch'
            Clear-LWInventoryRecoveryEntry -Type 'special'
            Write-LWInfo ("Section {0}: folded older recovery-stash gear into confiscated equipment." -f [int]$script:GameState.CurrentSection)
        }

        Set-LWStoryAchievementFlag -Name $FlagName
        return
    }

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    $weaponLikeSpecials = @(
        foreach ($group in @((Get-LWBookSevenWeaponLikeSpecialItemNames))) {
            foreach ($item in @($script:GameState.Inventory.SpecialItems)) {
                if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @($group) -Target ([string]$item)))) {
                    [string]$item
                }
            }
        }
    )
    $weaponLikeSpecials = @($weaponLikeSpecials | Select-Object -Unique)

    $alreadyApplied = Test-LWStoryAchievementFlag -Name $FlagName
    if ($alreadyApplied -and @($weapons).Count -eq 0 -and @($weaponLikeSpecials).Count -eq 0) {
        return
    }

    if ($alreadyApplied) {
        Write-LWWarn ("Section {0}: confiscation was already marked as handled, but carried confiscatable gear remains. Stashing it now." -f [int]$script:GameState.CurrentSection)
    }
    elseif ($EnduranceLoss -gt 0) {
        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName ("{0}LossApplied" -f $FlagName) -Delta (-1 * $EnduranceLoss) -MessagePrefix $Reason -FatalCause ("The ordeal at section {0} reduced your Endurance to zero." -f [int]$script:GameState.CurrentSection))
    }
    else {
        Write-LWInfo $Reason
    }

    if (@($weapons).Count -gt 0) {
        Save-LWInventoryRecoveryEntry -Type 'weapon' -Items @($weapons)
        Set-LWInventoryItems -Type 'weapon' -Items @()
        Write-LWInfo ("Section {0}: stashed Weapons for later recovery: {1}." -f [int]$script:GameState.CurrentSection, (Format-LWList -Items @($weapons)))
    }

    if (@($weaponLikeSpecials).Count -gt 0) {
        Save-LWInventoryRecoveryEntry -Type 'special' -Items @($weaponLikeSpecials)
        foreach ($item in @($weaponLikeSpecials)) {
            [void](Remove-LWInventoryItemSilently -Type 'special' -Name ([string]$item) -Quantity 1)
        }
        Write-LWInfo ("Section {0}: stashed weapon-like Special Items for later recovery: {1}." -f [int]$script:GameState.CurrentSection, (Format-LWList -Items @($weaponLikeSpecials)))
    }

    Set-LWStoryAchievementFlag -Name $FlagName
    if ((@($weapons).Count -gt 0) -or (@($weaponLikeSpecials).Count -gt 0)) {
        Write-LWInfo ("Section {0}: confiscated weapons saved to the recovery stash." -f [int]$script:GameState.CurrentSection)
    }
}

function Restore-LWMagnakaiBookSevenRecoveredWeapons {
    $restoredAnything = $false
    if (Test-LWStateHasConfiscatedEquipment) {
        if (Restore-LWConfiscatedEquipment -WriteMessages) {
            $restoredAnything = $true
        }
    }
    if (@(Get-LWInventoryRecoveryItems -Type 'weapon').Count -gt 0) {
        Restore-LWInventorySection -Type 'weapon'
        $restoredAnything = $true
    }
    if (@(Get-LWInventoryRecoveryItems -Type 'special').Count -gt 0) {
        Restore-LWInventorySection -Type 'special'
        $restoredAnything = $true
    }
    return $restoredAnything
}

function Get-LWMagnakaiBookSevenSectionRandomNumberContext {
    param([Parameter(Mandatory = $true)][object]$State)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $State -or $null -eq $State.Character -or [int]$State.Character.BookNumber -ne 7) {
        return $null
    }

    $section = [int]$State.CurrentSection
    $modifier = 0
    $modifierNotes = @()

    switch ($section) {
        26 {
            $modifier += 3
            $modifierNotes += 'base +3 from the bubble prison'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Sword') -ne $null)) {
                $modifier -= 2
                $modifierNotes += 'Weaponmastery with Sword -2'
            }
            return (New-LWSectionRandomNumberContext -Section 26 -Description 'Transparent prison oxygen-loss check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        35 {
            if (Test-LWBookSevenHasPrimateRank -State $State) {
                $modifier += 1
                $modifierNotes += 'Primate rank +1'
            }
            return (New-LWSectionRandomNumberContext -Section 35 -Description 'Psychic command test against the black sphere.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        39 { return (New-LWSectionRandomNumberContext -Section 39 -Description 'Search for the invisible bridge.' ) }
        55 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') -or (Test-LWStateHasDiscipline -State $State -Name 'Divination')) {
                $modifier += 3
                $modifierNotes += 'Huntmastery or Divination +3'
            }
            return (New-LWSectionRandomNumberContext -Section 55 -Description 'Crossbow ambush reaction check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        85 {
            $modifier += 2
            $modifierNotes += 'base +2 from the cliff climb'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') -and (Test-LWBookSevenHasPrimateRank -State $State)) {
                $modifier -= 2
                $modifierNotes += 'Huntmastery with Primate rank -2'
            }
            return (New-LWSectionRandomNumberContext -Section 85 -Description 'Cliff-climb fatigue and wound loss.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        86 { return (New-LWSectionRandomNumberContext -Section 86 -Description 'Cocoon hiding-place detection check.') }
        116 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 3
                $modifierNotes += 'Huntmastery +3'
            }
            return (New-LWSectionRandomNumberContext -Section 116 -Description 'Rahkos hand ambush check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        128 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 3
                $modifierNotes += 'Huntmastery +3'
            }
            return (New-LWSectionRandomNumberContext -Section 128 -Description 'Burnt Rahkos hand ambush check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        129 { return (New-LWSectionRandomNumberContext -Section 129 -Description 'Adgana addiction check after combat.') }
        148 { return (New-LWSectionRandomNumberContext -Section 148 -Description 'Nest search aftermath reaction check: 0-4 -> 63; 5-9 -> 346.') }
        166 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 2
                $modifierNotes += 'Huntmastery +2'
            }
            return (New-LWSectionRandomNumberContext -Section 166 -Description 'Invisible whip bridge scramble.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        169 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 3
                $modifierNotes += 'Huntmastery +3'
            }
            return (New-LWSectionRandomNumberContext -Section 169 -Description 'Descending wall escape check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        175 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Bow') -ne $null)) {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow +3'
            }
            elseif (Test-LWStateHasDiscipline -State $State -Name 'Nexus') {
                $modifier += 3
                $modifierNotes += 'Nexus avoids the smoke penalty'
            }
            else {
                $modifier -= 3
                $modifierNotes += 'smoke and fumes -3'
            }
            return (New-LWSectionRandomNumberContext -Section 175 -Description 'Smoke-blinded bowshot check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        185 { return (New-LWSectionRandomNumberContext -Section 185 -Description 'Sprint back to the tunnel before the Dhax arrive.') }
        225 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Bow') -ne $null)) {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow +3'
            }
            return (New-LWSectionRandomNumberContext -Section 225 -Description 'Long-range bowshot at the fleeing target.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        241 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Curing') {
                $modifier -= 1
                $modifierNotes += 'Curing -1'
            }
            return (New-LWSectionRandomNumberContext -Section 241 -Description 'Red-fire bolt injury loss.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        255 {
            if ([int]$State.Character.EnduranceCurrent -ge 20) {
                $modifier += 2
                $modifierNotes += 'current ENDURANCE 20 or more +2'
            }
            return (New-LWSectionRandomNumberContext -Section 255 -Description 'Falling-tree bridge placement check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        266 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Bow') -ne $null)) {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow +3'
            }
            return (New-LWSectionRandomNumberContext -Section 266 -Description 'Snap-shot bow check before the bell-rope is reached.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        327 {
            if (Test-LWBookSevenHasPrimateRank -State $State) {
                $modifier += 2
                $modifierNotes += 'Primate rank +2'
            }
            return (New-LWSectionRandomNumberContext -Section 327 -Description 'Underwater lock-opening check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        328 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery') -and ((Get-LWMatchingValue -Values @($State.Character.WeaponmasteryWeapons) -Target 'Bow') -ne $null)) {
                $modifier += 3
                $modifierNotes += 'Weaponmastery with Bow +3'
            }
            if (@(Get-LWStateCompletedLoreCircles -State $State) -contains 'Fire') {
                $modifier += 1
                $modifierNotes += 'Lore-circle of Fire +1'
            }
            return (New-LWSectionRandomNumberContext -Section 328 -Description 'Bow volley at the slinking creatures.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        337 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Huntmastery') {
                $modifier += 3
                $modifierNotes += 'Huntmastery +3'
            }
            return (New-LWSectionRandomNumberContext -Section 337 -Description 'Descending wall escape check.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        343 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Invisibility') {
                $modifier += 3
                $modifierNotes += 'Invisibility +3'
            }
            return (New-LWSectionRandomNumberContext -Section 343 -Description 'Hide in the torchlit chamber.' -Modifier $modifier -ModifierNotes $modifierNotes)
        }
        default { return $null }
    }
}

function Invoke-LWMagnakaiBookSevenRandomEnduranceLoss {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][int]$Loss,
        [Parameter(Mandatory = $true)][string]$MessagePrefix,
        [Parameter(Mandatory = $true)][string]$FatalCause
    )

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return
    }

    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName $FlagName -Delta (-1 * [Math]::Abs($Loss)) -MessagePrefix $MessagePrefix -FatalCause $FatalCause)
}

function Invoke-LWMagnakaiBookSevenSectionRandomNumberResolution {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [object]$Context = $null,
        [int[]]$Rolls = @(),
        [int[]]$EffectiveRolls = @(),
        [int]$Subtotal = 0,
        [int]$AdjustedTotal = 0
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if ($null -eq $Context) {
        return
    }

    switch ([int]$Context.Section) {
        26 {
            Invoke-LWMagnakaiBookSevenRandomEnduranceLoss -FlagName 'Book7Section026OxygenLossApplied' -Loss $AdjustedTotal -MessagePrefix 'Section 26: oxygen loss inside the transparent prison.' -FatalCause 'The transparent prison at section 26 reduced your Endurance to zero.'
        }
        85 {
            Invoke-LWMagnakaiBookSevenRandomEnduranceLoss -FlagName 'Book7Section085ClimbLossApplied' -Loss $AdjustedTotal -MessagePrefix 'Section 85: the cliff climb drains your strength.' -FatalCause 'The climb at section 85 reduced your Endurance to zero.'
        }
        129 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section129AdganaCheckResolved')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section129AdganaCheckResolved'
                if ([int]$AdjustedTotal -le 1) {
                    Set-LWStoryAchievementFlag -Name 'Book7AdganaAddicted'
                    $oldMax = [int]$script:GameState.Character.EnduranceMax
                    $newMax = [Math]::Max(1, ($oldMax - 4))
                    $script:GameState.Character.EnduranceMax = $newMax
                    if ([int]$script:GameState.Character.EnduranceCurrent -gt $newMax) {
                        $script:GameState.Character.EnduranceCurrent = $newMax
                    }
                    Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $oldMax)
                    Write-LWWarn ("Section 129: Adgana addiction reduces maximum ENDURANCE by 4. Current Endurance: {0} / {1}." -f [int]$script:GameState.Character.EnduranceCurrent, [int]$script:GameState.Character.EnduranceMax)
                }
                else {
                    Write-LWInfo 'Section 129: you avoid Adgana addiction.'
                }
            }
        }
        241 {
            Invoke-LWMagnakaiBookSevenRandomEnduranceLoss -FlagName 'Book7Section241BoltLossApplied' -Loss $AdjustedTotal -MessagePrefix 'Section 241: the red-fire bolts slam into your back.' -FatalCause 'The red-fire attack at section 241 reduced your Endurance to zero.'
        }
    }
}

function Invoke-LWMagnakaiBookSevenStorySectionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Section
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    switch ($Section) {
        1 { Set-LWStoryAchievementFlag -Name 'Book7PowerKeyClaimed' }
        12 { Set-LWStoryAchievementFlag -Name 'Book7TavigMet' }
        43 { Set-LWStoryAchievementFlag -Name 'Book7SabitoIdentified' }
        73 {
            Set-LWStoryAchievementFlag -Name 'Book7Snake123ClueSeen'
        }
        105 {
            Set-LWStoryAchievementFlag -Name 'Book7KasinWarningHeard'
            Set-LWStoryAchievementFlag -Name 'Book7SecretPassageLearned'
            Set-LWStoryAchievementFlag -Name 'Book7JettyBoatLoreLearned'
        }
        133 { Set-LWStoryAchievementFlag -Name 'Book7TavigWarningHeard' }
        186 {
            if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBookSevenSilverWhistleItemNames) -Type 'special') {
                Set-LWStoryAchievementFlag -Name 'Book7SilverWhistleClaimed'
            }
        }
        271 {
            if (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenGoldKeyItemNames)) {
                Set-LWStoryAchievementFlag -Name 'Book7GoldKeyClaimed'
            }
        }
        291 { Set-LWStoryAchievementFlag -Name 'Book7TavigSavedBriefly' }
        305 { Set-LWStoryAchievementFlag -Name 'Book7DiamondClaimed' }
        317 { Set-LWStoryAchievementFlag -Name 'Book7TendrilSevered' }
        333 {
            Set-LWStoryAchievementFlag -Name 'Book7GoldKeyUsed'
            Set-LWStoryAchievementFlag -Name 'Book7Snake123ClueSeen'
        }
        340 {
            Set-LWStoryAchievementFlag -Name 'Book7KasinWarningHeard'
            Set-LWStoryAchievementFlag -Name 'Book7SecretPassageLearned'
            Set-LWStoryAchievementFlag -Name 'Book7JettyBoatLoreLearned'
        }
        347 { Set-LWStoryAchievementFlag -Name 'Book7SilverWhistleRoute' }
        349 {
            Set-LWStoryAchievementFlag -Name 'Book7CastleDeathFailureSeen'
            Set-LWStoryAchievementFlag -Name 'Book7CastleDeathSeen'
        }
    }
}

function Invoke-LWMagnakaiBookSevenStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    switch ("$FromSection->$ToSection") {
        '1->135' { Set-LWStoryAchievementFlag -Name 'Book7WestJettyLanding' }
        '1->288' { Set-LWStoryAchievementFlag -Name 'Book7EastBayLanding' }
        '100->34' { Set-LWStoryAchievementFlag -Name 'Book7ZakhanRiddleSolved' }
        '119->280' { Set-LWStoryAchievementFlag -Name 'Book7TavigRescueAttempted' }
        '138->118' {
            Set-LWStoryAchievementFlag -Name 'Book7ZahdaBlueBeamPursuit'
            Set-LWStoryAchievementFlag -Name 'Book7BlueBeamRoute'
        }
        '174->149' {
            Set-LWStoryAchievementFlag -Name 'Book7ZahdaDirectDuel'
            Set-LWStoryAchievementFlag -Name 'Book7ThroneOfFireRoute'
        }
        '202->149' {
            Set-LWStoryAchievementFlag -Name 'Book7ZahdaDirectDuel'
            Set-LWStoryAchievementFlag -Name 'Book7ThroneOfFireRoute'
        }
        '138->250' {
            Set-LWStoryAchievementFlag -Name 'Book7LorestoneTubeEscape'
            Set-LWStoryAchievementFlag -Name 'Book7OutThroughTheAshRoute'
        }
        '149->250' {
            Set-LWStoryAchievementFlag -Name 'Book7LorestoneTubeEscape'
            Set-LWStoryAchievementFlag -Name 'Book7OutThroughTheAshRoute'
        }
        '149->267' { Set-LWStoryAchievementFlag -Name 'Book7LorestoneTransporterEscape' }
        '267->200' { Set-LWStoryAchievementFlag -Name 'Book7LorestoneTransporterEscape' }
        '315->122' {
            Set-LWStoryAchievementFlag -Name 'Book7LowerLevelSafeEscape'
            Set-LWStoryAchievementFlag -Name 'Book7OutThroughTheAshRoute'
        }
        '338->122' {
            Set-LWStoryAchievementFlag -Name 'Book7LowerLevelSafeEscape'
            Set-LWStoryAchievementFlag -Name 'Book7OutThroughTheAshRoute'
        }
    }
}

function Get-LWMagnakaiBookSevenInstantDeathCause {
    param([Parameter(Mandatory = $true)][int]$Section)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    switch ($Section) {
        28 { return 'Section 28: a second crossbow bolt passes through your skull.' }
        51 { return 'Section 51: the bubble suffocates you in its airless prison.' }
        64 { return 'Section 64: the skeletal warrior''s spear kills you instantly.' }
        77 { return 'Section 77: the Rahkos hand burrows into your skull and devours your brain.' }
        84 { return 'Section 84: the wolf and bubble kill you together.' }
        105 { return $null }
        106 { return 'Section 106: the Dhax power-staff tears you apart with destructive energy.' }
        121 { return 'Section 121: the monster swallows you whole.' }
        159 { return 'Section 159: Lord Zahda''s challenge ends in your death.' }
        163 { return 'Section 163: the green jadin arch annihilates you.' }
        189 { return 'Section 189: the crossbow bolt kills you instantly.' }
        237 { return 'Section 237: the falling wall crushes you beneath your trapped Backpack.' }
        263 { return 'Section 263: you drown as your lungs fill with water.' }
        273 { return 'Section 273: the power-maces slay you before they close with you.' }
        275 { return 'Section 275: the lava pit incinerates you.' }
        292 { return 'Section 292: you die of suffocation in the thinning air.' }
        300 { return 'Section 300: the collapsing stairway hurls you into the lava-filled chasm.' }
        331 { return 'Section 331: corrosive saliva paralyses you as the monster devours you.' }
        340 { return $null }
        349 { return 'Section 349: the ruby corridor maze seals you into Castle Death forever.' }
        default { return $null }
    }
}

function Invoke-LWMagnakaiBookSevenSectionEntryRules {
    param([Parameter(Mandatory = $true)][object]$State)

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if (-not (Test-LWHasState)) {
        return
    }

    $section = [int]$script:GameState.CurrentSection
    $instantDeathCause = Get-LWMagnakaiBookSevenInstantDeathCause -Section $section
    if (-not [string]::IsNullOrWhiteSpace($instantDeathCause)) {
        Invoke-LWInstantDeath -Cause $instantDeathCause
        return
    }

    switch ($section) {
        1 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7PowerKeyClaimed') -and -not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenPowerKeyItemNames))) {
                [void](Add-LWBookSevenPocketItem -Name 'Power-key' -FlagName 'Book7PowerKeyClaimed' -SuccessMessage 'Section 1: Power-key added to Pocket Items.')
            }
            else {
                Set-LWStoryAchievementFlag -Name 'Book7PowerKeyClaimed'
            }
        }
        5 {
            Invoke-LWMagnakaiBookSevenMealRequirement -ResolvedFlagName 'Book7Section005MealHandled' -NoMealFlagName 'Book7Section005NoMealLossApplied' -SectionLabel 'Section 5' -NoMealMessagePrefix 'Section 5: hunger and cold weaken you in the storm.' -FatalCause 'The hunger at section 5 reduced your Endurance to zero.'
        }
        7 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section007ArrowsLost')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section007ArrowsLost'
                if (Test-LWStateHasQuiver -State $script:GameState) {
                    $script:GameState.Inventory.QuiverArrows = 0
                    Write-LWInfo 'Section 7: all carried Arrows are lost in the nest.'
                }
            }
        }
        10 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section010FireseedSpent')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section010FireseedSpent'
                if (Remove-LWPocketSpecialItemSilently -Name 'Fireseed' -Quantity 1) {
                    Write-LWInfo 'Section 10: 1 Fireseed spent.'
                }
                else {
                    Write-LWWarn 'Section 10: no Fireseed was available to spend automatically.'
                }
            }
        }
        15 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section015RecoveredWeapons')) {
                if (Restore-LWMagnakaiBookSevenRecoveredWeapons) {
                    Write-LWInfo 'Section 15: confiscated weapons recovered.'
                }
                Set-LWStoryAchievementFlag -Name 'Book7Section015RecoveredWeapons'
            }
            Invoke-LWBookFourChoiceTable -Title 'Section 15 Recovery' -PromptLabel 'Section 15 choice' -ContextLabel 'Section 15' -Choices (Get-LWMagnakaiBookSevenSection015ChoiceDefinitions) -Intro 'Section 15: reclaim the concentrated Laumspur and the Kazan-Oud Platinum Amulet if you want them.'
        }
        18 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section018DamageApplied' -Delta -2 -MessagePrefix 'Section 18: the invisible whip opens a red weal around your wrist.' -FatalCause 'The invisible whip at section 18 reduced your Endurance to zero.')
        }
        31 {
            [void](Add-LWBookSevenPocketItem -Name 'Skeleton Key' -FlagName 'Book7Section031SkeletonKeyClaimed' -SuccessMessage 'Section 31: Skeleton Key added to Pocket Items.')
            [void](Add-LWBookSevenPocketItem -Name 'Parchment' -FlagName 'Book7Section031ParchmentClaimed' -SuccessMessage 'Section 31: Parchment added to Pocket Items.')
        }
        32 {
            Invoke-LWMagnakaiBookSevenLoseCurrentWeapon -FlagName 'Book7Section032WeaponLost'
        }
        42 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section042DamageApplied' -Delta -3 -MessagePrefix 'Section 42: the Lorestone''s black fire burns your hand.' -FatalCause 'The black fire at section 42 reduced your Endurance to zero.')
        }
        43 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7SabitoIdentified')) {
                if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Sabito' -Quantity 1) {
                    Set-LWStoryAchievementFlag -Name 'Book7SabitoIdentified'
                    Write-LWInfo 'Section 43: Sabito added to Backpack Items.'
                }
                else {
                    Write-LWWarn 'No room to add Sabito automatically. Make room and add it manually if needed.'
                }
            }
        }
        44 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section044DamageApplied' -Delta -3 -MessagePrefix 'Section 44: a vicious kick smashes into your ribs at the edge of the pit.' -FatalCause 'The kick at section 44 reduced your Endurance to zero.')
        }
        58 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section058DamageApplied' -Delta -2 -MessagePrefix 'Section 58: the invisible whip lashes the back of your hand.' -FatalCause 'The invisible whip at section 58 reduced your Endurance to zero.')
        }
        59 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section059HeatHandled')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section059HeatHandled'
                if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus') -and (Test-LWBookSevenHasPrimateRank -State $script:GameState)) {
                    Write-LWInfo 'Section 59: Nexus at Primate rank protects you from the tunnel heat and fumes.'
                }
                else {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section059DamageApplied' -Delta -3 -MessagePrefix 'Section 59: the tunnel heat and sulphurous fumes sap your strength.' -FatalCause 'The heat and fumes at section 59 reduced your Endurance to zero.')
                }
            }
        }
        60 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section060ShockDamageApplied' -Delta -4 -MessagePrefix 'Section 60: blue lightning hurls you into the lake.' -FatalCause 'The lightning shock at section 60 reduced your Endurance to zero.')
        }
        73 {
            Set-LWStoryAchievementFlag -Name 'Book7Snake123ClueSeen'
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7DiamondClaimed') -and -not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenDiamondItemNames))) {
                if (Read-LWInlineYesNo -Prompt 'Section 73: keep the Diamond in your pocket?' -Default $true) {
                    [void](Add-LWBookSevenPocketItem -Name 'Diamond' -FlagName 'Book7DiamondClaimed' -SuccessMessage 'Section 73: Diamond added to Pocket Items.')
                }
            }
        }
        80 {
            Invoke-LWBookFourChoiceTable -Title 'Section 80 Body Loot' -PromptLabel 'Section 80 choice' -ContextLabel 'Section 80' -Choices (Get-LWMagnakaiBookSevenSection080ChoiceDefinitions) -Intro 'Section 80: search the bodies and take any weapons or Gold Crowns you want.'
        }
        88 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section088DamageApplied' -Delta -2 -MessagePrefix 'Section 88: the fire-jets singe your face and force you backwards.' -FatalCause 'The fire-jets at section 88 reduced your Endurance to zero.')
        }
        105 {
            Set-LWStoryAchievementFlag -Name 'Book7KasinWarningHeard'
            Set-LWStoryAchievementFlag -Name 'Book7SecretPassageLearned'
            Set-LWStoryAchievementFlag -Name 'Book7JettyBoatLoreLearned'
        }
        103 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section103BarrierDamageApplied')) {
                $damage = if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus') { 6 } else { 8 }
                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section103BarrierDamageApplied' -Delta (-1 * $damage) -MessagePrefix ("Section 103: the energy barrier throws you back (-{0} END)." -f $damage) -FatalCause 'The energy barrier at section 103 reduced your Endurance to zero.')
            }
        }
        104 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section104HeatHandled')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section104HeatHandled'
                if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus') {
                    Write-LWInfo 'Section 104: Nexus protects you from the scorching sand.'
                }
                else {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section104HeatDamageApplied' -Delta -3 -MessagePrefix 'Section 104: the scorching sand burns your feet and drains your strength.' -FatalCause 'The scorching sand at section 104 reduced your Endurance to zero.')
                }
            }
        }
        107 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section107BubbleDamageApplied' -Delta -6 -MessagePrefix 'Section 107: the airtight bubble prison burns your lungs.' -FatalCause 'The bubble prison at section 107 reduced your Endurance to zero.')
        }
        108 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section108DamageApplied' -Delta -5 -MessagePrefix 'Section 108: the polluted stream and lack of oxygen sap your strength.' -FatalCause 'The stream at section 108 reduced your Endurance to zero.')
        }
        112 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section112DamageApplied' -Delta -1 -MessagePrefix 'Section 112: the exploding sphere sears your face.' -FatalCause 'The blast at section 112 reduced your Endurance to zero.')
        }
        120 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section120DamageApplied' -Delta -4 -MessagePrefix 'Section 120: the wolf slams you to the ground and claws your chest.' -FatalCause 'The wolf attack at section 120 reduced your Endurance to zero.')
        }
        122 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section122BackpackLost')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section122BackpackLost'
                Lose-LWBackpack -WriteMessages -Reason 'Section 122'
            }
        }
        134 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section134DamageApplied' -Delta -4 -MessagePrefix 'Section 134: psychic strain from the Psi-surge duel drains you.' -FatalCause 'The psychic strain at section 134 reduced your Endurance to zero.')
        }
        148 {
            Invoke-LWBookFourChoiceTable -Title 'Section 148 Nest Loot' -PromptLabel 'Section 148 choice' -ContextLabel 'Section 148' -Choices (Get-LWMagnakaiBookSevenSection148ChoiceDefinitions) -Intro 'Section 148: search the nest and take any useful gear before you make your escape check.'
        }
        154 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section154DamageApplied' -Delta -3 -MessagePrefix 'Section 154: the falling tree tears open your cheek and ribs.' -FatalCause 'The falling tree at section 154 reduced your Endurance to zero.')
        }
        155 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section155DamageApplied' -Delta -2 -MessagePrefix 'Section 155: the jets of fire scorch your face.' -FatalCause 'The fire jets at section 155 reduced your Endurance to zero.')
        }
        158 {
            Invoke-LWMagnakaiBookSevenSection158BackpackLoss
        }
        170 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section170DamageApplied' -Delta -4 -MessagePrefix 'Section 170: the exploding creature sears your face and hair.' -FatalCause 'The blast at section 170 reduced your Endurance to zero.')
        }
        186 {
            Invoke-LWBookFourChoiceTable -Title 'Section 186 Aftermath' -PromptLabel 'Section 186 choice' -ContextLabel 'Section 186' -Choices (Get-LWMagnakaiBookSevenSection186ChoiceDefinitions) -Intro 'Section 186: take the Spear and Silver Whistle if you want them.'
        }
        190 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section190PsychicCostApplied' -Delta -2 -MessagePrefix 'Section 190: forcing your psychic discipline through the wounded eye costs you 2 ENDURANCE.' -FatalCause 'The psychic effort at section 190 reduced your Endurance to zero.')
        }
        198 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section198DamageApplied' -Delta -2 -MessagePrefix 'Section 198: the Rahkos claws scratch your scalp as you dive clear.' -FatalCause 'The Rahkos attack at section 198 reduced your Endurance to zero.')
        }
        199 {
            Invoke-LWBookFourChoiceTable -Title 'Section 199 Mercenary Corpse' -PromptLabel 'Section 199 choice' -ContextLabel 'Section 199' -Choices (Get-LWMagnakaiBookSevenSection199ChoiceDefinitions) -Intro 'Section 199: take the Gold Crowns, Rope, and Lantern if you want them.'
        }
        219 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section219DamageApplied' -Delta -6 -MessagePrefix 'Section 219: the red-fire bolt paralyses your arm and knocks your weapon away.' -FatalCause 'The red-fire bolt at section 219 reduced your Endurance to zero.')
        }
        220 {
            Invoke-LWBookFourChoiceTable -Title 'Section 220 Guard Loot' -PromptLabel 'Section 220 choice' -ContextLabel 'Section 220' -Choices (Get-LWMagnakaiBookSevenSection220ChoiceDefinitions) -Intro 'Section 220: take the Axe and Dagger if you want them before you choose how to react.'
        }
        222 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section222DamageApplied' -Delta -3 -MessagePrefix 'Section 222: the bridge fall and repeated whip cracks rip into your body.' -FatalCause 'The bridge ordeal at section 222 reduced your Endurance to zero.')
        }
        227 {
            $choices = if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing') {
                @((Get-LWMagnakaiBookSevenSection227ChoiceDefinitions) | Where-Object { $_.Id -ne 'blue_pills' })
            }
            else {
                @((Get-LWMagnakaiBookSevenSection227ChoiceDefinitions) | Where-Object { $_.Id -ne 'sabito' })
            }
            Invoke-LWBookFourChoiceTable -Title 'Section 227 Body Search' -PromptLabel 'Section 227 choice' -ContextLabel 'Section 227' -Choices $choices -Intro 'Section 227: take whatever body-loot you want before you move on.'
            if (-not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenPowerKeyItemNames))) {
                if (Read-LWInlineYesNo -Prompt 'Section 227: keep the Power-key from the body?' -Default $true) {
                    [void](Add-LWBookSevenPocketItem -Name 'Power-key' -FlagName 'Book7PowerKeyClaimed' -SuccessMessage 'Section 227: Power-key added to Pocket Items.')
                }
            }
        }
        238 {
            Invoke-LWBookFourChoiceTable -Title 'Section 238 Loot' -PromptLabel 'Section 238 choice' -ContextLabel 'Section 238' -Choices (Get-LWMagnakaiBookSevenSection238ChoiceDefinitions) -Intro 'Section 238: take whatever loot you want from the fallen guard.'
        }
        262 {
            Invoke-LWBookFourChoiceTable -Title 'Section 262 Weapon Rack' -PromptLabel 'Section 262 choice' -ContextLabel 'Section 262' -Choices (Get-LWMagnakaiBookSevenSection262ChoiceDefinitions) -Intro 'Section 262: take the Short Sword and Shield if you want them before deciding where to go next.'
        }
        264 {
            Invoke-LWMagnakaiBookSevenWeaponConfiscation -FlagName 'Book7Section264ConfiscationApplied' -Reason 'Section 264: all Weapons and weapon-like Special Items are confiscated before the maze.'
        }
        265 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section265DamageApplied' -Delta -2 -MessagePrefix 'Section 265: the blast of steam and grit hurls you to the ground.' -FatalCause 'The blast at section 265 reduced your Endurance to zero.')
        }
        271 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7GoldKeyClaimed') -and -not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenGoldKeyItemNames))) {
                if (Read-LWInlineYesNo -Prompt 'Section 271: take the Gold Key?' -Default $true) {
                    [void](Add-LWBookSevenPocketItem -Name 'Gold Key' -FlagName 'Book7GoldKeyClaimed' -SuccessMessage 'Section 271: Gold Key added to Pocket Items.')
                }
            }
        }
        284 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section284BarrierDamageApplied')) {
                $damage = if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus') { 6 } else { 8 }
                [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section284BarrierDamageApplied' -Delta (-1 * $damage) -MessagePrefix ("Section 284: the energy barrier hurls you back (-{0} END)." -f $damage) -FatalCause 'The energy barrier at section 284 reduced your Endurance to zero.')
            }
        }
        297 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section297DamageApplied' -Delta -2 -MessagePrefix 'Section 297: the relentless psychic attack takes its toll.' -FatalCause 'The psychic assault at section 297 reduced your Endurance to zero.')
        }
        301 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section301ArrowsLost')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section301ArrowsLost'
                if (Test-LWStateHasQuiver -State $script:GameState -and [int]$script:GameState.Inventory.QuiverArrows -gt 0) {
                    $script:GameState.Inventory.QuiverArrows = 0
                    Write-LWInfo 'Section 301: all Arrows fall from your Quiver during the fall.'
                }
            }
        }
        304 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section304DamageApplied' -Delta -3 -MessagePrefix 'Section 304: the invisible whip opens a weal from temple to chin.' -FatalCause 'The invisible whip at section 304 reduced your Endurance to zero.')
        }
        305 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7DiamondClaimed') -and -not (Test-LWStateHasPocketSpecialItem -State $script:GameState -Names (Get-LWBookSevenDiamondItemNames))) {
                [void](Add-LWBookSevenPocketItem -Name 'Diamond' -FlagName 'Book7DiamondClaimed' -SuccessMessage 'Section 305: Diamond added to Pocket Items.')
            }
        }
        311 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section311DamageApplied' -Delta -2 -MessagePrefix 'Section 311: the invisible whip catches you as you sprint clear.' -FatalCause 'The invisible whip at section 311 reduced your Endurance to zero.')
        }
        313 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section313DamageApplied' -Delta -3 -MessagePrefix 'Section 313: lack of oxygen leaves you light-headed and reeling.' -FatalCause 'The suffocation at section 313 reduced your Endurance to zero.')
        }
        324 {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section324HeatHandled')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section324HeatHandled'
                if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus') -or (Test-LWBookSevenHasPlatinumAmulet -State $script:GameState)) {
                    Set-LWStoryAchievementFlag -Name 'Book7HotTunnelSurvived'
                    Write-LWInfo 'Section 324: Nexus or the Platinum Amulet protects you from the worst of the heat.'
                }
                else {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section324DamageApplied' -Delta -4 -MessagePrefix 'Section 324: the oven-like tunnel burns your flesh.' -FatalCause 'The heat tunnel at section 324 reduced your Endurance to zero.')
                }
            }
        }
        333 {
            Set-LWStoryAchievementFlag -Name 'Book7GoldKeyUsed'
            Set-LWStoryAchievementFlag -Name 'Book7Snake123ClueSeen'
            if (-not (Test-LWStoryAchievementFlag -Name 'Book7Section333GoldKeyRemoved')) {
                Set-LWStoryAchievementFlag -Name 'Book7Section333GoldKeyRemoved'
                if (Remove-LWPocketSpecialItemSilently -Name 'Gold Key' -Quantity 1) {
                    Write-LWInfo 'Section 333: Gold Key consumed.'
                }
                else {
                    Write-LWWarn 'Section 333: no Gold Key was present to remove automatically.'
                }
            }
            Invoke-LWBookFourChoiceTable -Title 'Section 333 Door Rack' -PromptLabel 'Section 333 choice' -ContextLabel 'Section 333' -Choices (Get-LWMagnakaiBookSevenSection333ChoiceDefinitions) -Intro 'Section 333: take the Spear and Quarterstaff if you want them before choosing a tunnel.'
        }
        335 {
            Invoke-LWMagnakaiBookSevenWeaponConfiscation -FlagName 'Book7Section335ConfiscationApplied' -Reason 'Section 335: Zahda strips you of all carried gear.' -EnduranceLoss 1 -AllCarriedGear
        }
        340 {
            Set-LWStoryAchievementFlag -Name 'Book7KasinWarningHeard'
            Set-LWStoryAchievementFlag -Name 'Book7SecretPassageLearned'
            Set-LWStoryAchievementFlag -Name 'Book7JettyBoatLoreLearned'
        }
        344 {
            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book7Section344DamageApplied' -Delta -2 -MessagePrefix 'Section 344: the invisible whip lashes the back of your hand as you find the bridge.' -FatalCause 'The invisible whip at section 344 reduced your Endurance to zero.')
        }
    }
}

function Apply-LWMagnakaiBookSevenStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)
    $script:GameState = $State
    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 7) {
        return
    }

    $script:GameState.RuleSet = 'Magnakai'
    $script:GameState.Character.LegacyKaiComplete = $true

    $requiredDisciplines = 4
    $ownedDisciplines = @($script:GameState.Character.MagnakaiDisciplines)
    if ($ownedDisciplines.Count -lt $requiredDisciplines) {
        $needed = $requiredDisciplines - $ownedDisciplines.Count
        $script:GameState.Character.MagnakaiDisciplines = @($ownedDisciplines + @(Select-LWMagnakaiDisciplines -Count $needed -Exclude $ownedDisciplines))
        Write-LWInfo ("Magnakai disciplines chosen: {0}" -f (@($script:GameState.Character.MagnakaiDisciplines) -join ', '))
    }
    if ([int]$script:GameState.Character.MagnakaiRank -lt $requiredDisciplines) {
        $script:GameState.Character.MagnakaiRank = $requiredDisciplines
    }
    if (@($script:GameState.Character.MagnakaiDisciplines) -contains 'Weaponmastery') {
        $ownedWeaponmasteryWeapons = @($script:GameState.Character.WeaponmasteryWeapons)
        $neededWeaponmasteryWeapons = $requiredDisciplines - $ownedWeaponmasteryWeapons.Count
        if ($neededWeaponmasteryWeapons -gt 0) {
            $script:GameState.Character.WeaponmasteryWeapons = @($ownedWeaponmasteryWeapons + @(Select-LWWeaponmasteryWeapons -Count $neededWeaponmasteryWeapons -Exclude $ownedWeaponmasteryWeapons))
            Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
        }
    }

    Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages

    if ($CarryExistingGear -and ((@($script:GameState.Inventory.SpecialItems).Count -gt 0) -or (@($script:GameState.Storage.SafekeepingSpecialItems).Count -gt 0))) {
        Invoke-LWBookTransitionSafekeepingPrompt -BookNumber 7
    }

    if ($CarryExistingGear) {
        Clear-LWLegacyBackpackCarryover -WriteMessages
    }

    Restore-LWBackpackState
    if ($CarryExistingGear) {
        Write-LWInfo 'Book 7 carry-over preserves your current Weapons and Special Items.'
    }

    [void](Ensure-LWBookSevenSectionOnePowerKey -SuccessMessage 'Book 7 startup: Power-key added to Pocket Items.')

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold
    Write-LWInfo ("Book 7 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 7 starting gold is lost.'
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to five Book 7 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to five Book 7 starting items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 5) {
        $availableChoices = @(Get-LWMagnakaiBookSevenStartingChoices | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 7 Starting Gear' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/5" -f $selectedIds.Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        if ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
            Write-LWKeyValue -Label 'Arrows' -Value (Format-LWQuiverArrowCounter -State $script:GameState) -ValueColor 'DarkYellow'
        }
        Write-Host ''
        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        $manageIndex = $availableChoices.Count + 1
        Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt ("Book 7 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }
        if ($choiceIndex -eq $manageIndex) {
            Invoke-LWBookFourStartingInventoryManagement
            continue
        }

        $choice = $availableChoices[$choiceIndex - 1]
        $granted = Grant-LWMagnakaiBookSevenStartingChoice -Choice $choice
        if ($granted) {
            $selectedIds += [string]$choice.Id
        }
        elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
            Invoke-LWBookFourStartingInventoryManagement
        }
    }
}

function Get-LWBookSevenSectionContextAchievementIds {
    Set-LWModuleContext -Context (Get-LWModuleContext)

    return @(
        'riddle_of_the_zakhan',
        'heat_of_the_moment',
        'blue_breath',
        'snake_eyes',
        'kasin_last_words',
        'green_is_death',
        'silent_no_more',
        'one_eye_open',
        'cool_head_hot_tunnel',
        'sever_the_tendril',
        'up_the_blue_beam',
        'throne_of_fire',
        'out_through_the_ash',
        'castle_death'
    )
}

Export-ModuleMember -Function `
    Get-LWMagnakaiBookSevenStartingChoices, `
    Grant-LWMagnakaiBookSevenStartingChoice, `
    Get-LWMagnakaiBookSevenSectionRandomNumberContext, `
    Invoke-LWMagnakaiBookSevenSectionRandomNumberResolution, `
    Invoke-LWMagnakaiBookSevenStorySectionAchievementTriggers, `
    Invoke-LWMagnakaiBookSevenStorySectionTransitionAchievementTriggers, `
    Get-LWMagnakaiBookSevenInstantDeathCause, `
    Invoke-LWMagnakaiBookSevenSectionEntryRules, `
    Apply-LWMagnakaiBookSevenStartingEquipment, `
    Get-LWBookSevenSectionContextAchievementIds
