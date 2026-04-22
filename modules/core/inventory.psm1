Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

$script:LWBackpackLayoutCache = $null
$script:LWBackpackSlotSizeLookup = $null
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

function Resolve-LWInventoryType {
    param([string]$Value)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    switch ($Value.Trim().ToLowerInvariant()) {
        'weapon' { return 'weapon' }
        'weapons' { return 'weapon' }
        'backpack' { return 'backpack' }
        'backpackitem' { return 'backpack' }
        'backpackitems' { return 'backpack' }
        'pack' { return 'backpack' }
        'herb' { return 'herbpouch' }
        'herbpouch' { return 'herbpouch' }
        'pouch' { return 'herbpouch' }
        'special' { return 'special' }
        'specialitem' { return 'special' }
        'specialitems' { return 'special' }
        default { return $null }
    }
}

function Get-LWInventoryTypeLabel {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ($Type) {
        'weapon' { return 'Weapons' }
        'backpack' { return 'Backpack' }
        'herbpouch' { return 'Herb Pouch' }
        'special' { return 'Special Items' }
    }
}

function Get-LWInventoryTypeColor {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ($Type) {
        'weapon' { return 'Green' }
        'backpack' { return 'Yellow' }
        'herbpouch' { return 'DarkGreen' }
        'special' { return 'DarkCyan' }
    }
}

function Get-LWInventoryTypeCapacity {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ($Type) {
        'weapon' { return 2 }
        'backpack' { return 8 }
        'herbpouch' { return 6 }
        'special' { return 12 }
    }
}

function Get-LWLongRopeItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Long Rope')
}

function Get-LWBackpackSlotSizeLookup {
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -ne $script:LWBackpackSlotSizeLookup) {
        return $script:LWBackpackSlotSizeLookup
    }

    $lookup = @{}
    foreach ($name in @(
            (Get-LWLongRopeItemNames)
            (Get-LWMiningToolItemNames)
            (Get-LWSleepingFursItemNames)
            (Get-LWTowelItemNames)
        )) {
        $canonicalName = [string](Get-LWCanonicalInventoryItemName -Name ([string]$name))
        if ([string]::IsNullOrWhiteSpace($canonicalName)) {
            continue
        }

        $lookup[$canonicalName.Trim().ToLowerInvariant()] = 2
    }

    $script:LWBackpackSlotSizeLookup = $lookup
    return $script:LWBackpackSlotSizeLookup
}

function Get-LWBackpackLayoutCacheKey {
    param([object[]]$Items = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    $resolvedItems = @($(if ($null -eq $Items) { @($script:GameState.Inventory.BackpackItems) } else { @($Items) }))
    if ($resolvedItems.Count -eq 0) {
        return '[empty]'
    }

    return (@(
            foreach ($item in $resolvedItems) {
                [string]$item
            }
        ) -join "`u{241F}")
}

function Get-LWBackpackLayoutData {
    param([object[]]$Items = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    $resolvedItems = @($(if ($null -eq $Items) { @($script:GameState.Inventory.BackpackItems) } else { @($Items) }))
    $cacheKey = Get-LWBackpackLayoutCacheKey -Items $resolvedItems
    if ($null -ne $script:LWBackpackLayoutCache -and
        (Test-LWPropertyExists -Object $script:LWBackpackLayoutCache -Name 'Key') -and
        [string]$script:LWBackpackLayoutCache.Key -eq $cacheKey) {
        return $script:LWBackpackLayoutCache
    }

    $slotMap = New-Object 'System.Collections.Generic.List[object]'
    $slotNumber = 1
    $itemIndex = 0
    foreach ($resolvedItem in @($resolvedItems)) {
        $itemName = [string]$resolvedItem
        $slotSize = Get-LWBackpackItemSlotSize -Name $itemName
        $slotMap.Add([pscustomobject]@{
                Slot        = $slotNumber
                ItemIndex   = $itemIndex
                ItemName    = $itemName
                DisplayText = $(if ($slotSize -gt 1) { "$itemName [2 slots]" } else { $itemName })
                IsPrimary   = $true
            })

        for ($extraSlot = 2; $extraSlot -le $slotSize; $extraSlot++) {
            $slotMap.Add([pscustomobject]@{
                    Slot        = ($slotNumber + $extraSlot - 1)
                    ItemIndex   = $itemIndex
                    ItemName    = $itemName
                    DisplayText = "(occupied by $itemName)"
                    IsPrimary   = $false
                })
        }

        $slotNumber += $slotSize
        $itemIndex++
    }

    $layout = [pscustomobject]@{
        Key       = $cacheKey
        UsedSlots = [Math]::Max(0, ($slotNumber - 1))
        SlotMap   = @($slotMap.ToArray())
    }
    $script:LWBackpackLayoutCache = $layout
    return $layout
}

function Get-LWBackpackItemSlotSize {
    param([string]$Name = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return 1
    }

    $lookup = Get-LWBackpackSlotSizeLookup
    $rawKey = $Name.Trim().ToLowerInvariant()
    if ($lookup.ContainsKey($rawKey)) {
        return [int]$lookup[$rawKey]
    }

    $canonicalName = [string](Get-LWCanonicalInventoryItemName -Name $Name)
    if (-not [string]::IsNullOrWhiteSpace($canonicalName)) {
        $canonicalKey = $canonicalName.Trim().ToLowerInvariant()
        if ($lookup.ContainsKey($canonicalKey)) {
            return [int]$lookup[$canonicalKey]
        }
    }

    return 1
}

function Get-LWBackpackOccupiedSlotCount {
    param([object[]]$Items = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $resolvedItems = @($(if ($null -eq $Items) { @($script:GameState.Inventory.BackpackItems) } else { @($Items) }))
    return [int](Get-LWBackpackLayoutData -Items $resolvedItems).UsedSlots
}

function Get-LWInventoryUsedCapacity {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [object[]]$Items = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $resolvedItems = @($(if ($null -eq $Items) { @(Get-LWInventoryItems -Type $Type) } else { @($Items) }))
    if ($Type -eq 'backpack') {
        return (Get-LWBackpackOccupiedSlotCount -Items $resolvedItems)
    }

    return @($resolvedItems).Count
}

function Get-LWBackpackSlotMap {
    param([object[]]$Items = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $resolvedItems = @($(if ($null -eq $Items) { @($script:GameState.Inventory.BackpackItems) } else { @($Items) }))
    return @((Get-LWBackpackLayoutData -Items $resolvedItems).SlotMap)
}

function Get-LWInventoryItems {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ($Type) {
        'weapon' { return @($script:GameState.Inventory.Weapons) }
        'backpack' { return @($script:GameState.Inventory.BackpackItems) }
        'herbpouch' { return @($script:GameState.Inventory.HerbPouchItems) }
        'special' { return @($script:GameState.Inventory.SpecialItems) }
    }
}

function Set-LWInventoryItems {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Items
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $normalizedItems = Normalize-LWInventoryItemCollection -Type $Type -Items @($Items)

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = @($normalizedItems) }
        'backpack' { $script:GameState.Inventory.BackpackItems = @($normalizedItems) }
        'herbpouch' { $script:GameState.Inventory.HerbPouchItems = @($normalizedItems) }
        'special' { $script:GameState.Inventory.SpecialItems = @($normalizedItems) }
    }

    [void](Sync-LWAchievements -Context 'inventory')
}

function Get-LWPocketSpecialItems {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState) -or $null -eq $script:GameState.Inventory) {
        return @()
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState.Inventory -Name 'PocketSpecialItems') -or $null -eq $script:GameState.Inventory.PocketSpecialItems) {
        return @()
    }

    return @(Normalize-LWInventoryItemCollection -Type 'special' -Items @($script:GameState.Inventory.PocketSpecialItems))
}

function Test-LWStateHasPocketSpecialItem {
    param(
        [object]$State = $script:GameState,
        [string[]]$Names = @()
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Inventory -or -not (Test-LWPropertyExists -Object $State.Inventory -Name 'PocketSpecialItems') -or $null -eq $State.Inventory.PocketSpecialItems) {
        return $false
    }

    if (@($Names).Count -eq 0) {
        return @($State.Inventory.PocketSpecialItems).Count -gt 0
    }

    foreach ($item in @($State.Inventory.PocketSpecialItems)) {
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $Names -Target ([string]$item)))) {
            return $true
        }
    }

    return $false
}

function TryAdd-LWPocketSpecialItemSilently {
    param([Parameter(Mandatory = $true)][string]$Name)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState.Inventory -Name 'PocketSpecialItems') -or $null -eq $script:GameState.Inventory.PocketSpecialItems) {
        $script:GameState.Inventory | Add-Member -Force -NotePropertyName PocketSpecialItems -NotePropertyValue @()
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name
    $current = @(Get-LWPocketSpecialItems)
    if (@($current) -icontains $resolvedName) {
        return $false
    }

    $script:GameState.Inventory.PocketSpecialItems = @(Normalize-LWInventoryItemCollection -Type 'special' -Items (@($current) + @($resolvedName)))
    [void](Sync-LWAchievements -Context 'inventory')
    return $true
}

function Remove-LWPocketSpecialItemSilently {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return 0
    }

    $source = @(Get-LWPocketSpecialItems)
    $remaining = @()
    $removed = 0
    foreach ($item in $source) {
        if ($removed -lt $Quantity -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @($Name) -Target ([string]$item)))) {
            $removed++
            continue
        }

        $remaining += $item
    }

    if ($removed -gt 0) {
        $script:GameState.Inventory.PocketSpecialItems = @(Normalize-LWInventoryItemCollection -Type 'special' -Items @($remaining))
        [void](Sync-LWAchievements -Context 'inventory')
    }

    return $removed
}

function Normalize-LWInventoryItemCollection {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Items
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $normalizedItems = @(
        foreach ($item in @($Items)) {
            if ($item -is [string]) {
                Get-LWCanonicalInventoryItemName -Name ([string]$item)
            }
            else {
                $item
            }
        }
    )

    if ($Type -ne 'special') {
        return @($normalizedItems)
    }

    $seen = @{}
    $deduped = @()
    foreach ($item in @($normalizedItems)) {
        if (-not ($item -is [string])) {
            $deduped += $item
            continue
        }

        $key = ([string]$item).ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            continue
        }

        $seen[$key] = $true
        $deduped += $item
    }

    return @($deduped)
}

function Move-LWHerbPouchPotionItemsFromBackpack {
    param(
        [object]$State = $script:GameState,
        [switch]$WriteMessages
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or -not (Test-LWStateHasHerbPouch -State $State)) {
        return 0
    }

    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HerbPouchItems') -or $null -eq $State.Inventory.HerbPouchItems) {
        $State.Inventory | Add-Member -Force -NotePropertyName HerbPouchItems -NotePropertyValue @()
    }

    $freeSlots = [Math]::Max(0, (6 - @($State.Inventory.HerbPouchItems).Count))
    if ($freeSlots -le 0) {
        return 0
    }

    $remainingBackpack = @()
    $moved = @()
    foreach ($item in @($State.Inventory.BackpackItems)) {
        if ($freeSlots -gt 0 -and (Test-LWHerbPouchPotionItemName -Name ([string]$item))) {
            $State.Inventory.HerbPouchItems = @($State.Inventory.HerbPouchItems) + @([string]$item)
            $moved += [string]$item
            $freeSlots--
        }
        else {
            $remainingBackpack += $item
        }
    }

    $State.Inventory.HerbPouchItems = @(Normalize-LWInventoryItemCollection -Type 'herbpouch' -Items @($State.Inventory.HerbPouchItems))
    $State.Inventory.BackpackItems = @(Normalize-LWInventoryItemCollection -Type 'backpack' -Items @($remainingBackpack))

    if ($WriteMessages -and $moved.Count -gt 0) {
        Write-LWInfo ("Moved to Herb Pouch: {0}." -f (Format-LWCompactInventorySummary -Items $moved -MaxGroups 4))
    }

    return $moved.Count
}

function Grant-LWHerbPouch {
    param([switch]$WriteMessages)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return $false
    }

    if (-not (Test-LWHerbPouchFeatureAvailable -State $script:GameState)) {
        if ($WriteMessages) {
            Write-LWWarn 'Herb Pouch is only available from Book 6 onward when DE Curing Option 3 is active.'
        }
        return $false
    }

    if (Test-LWStateHasHerbPouch -State $script:GameState) {
        if ($WriteMessages) {
            Write-LWWarn 'Herb Pouch is already carried.'
        }
        return $false
    }

    $script:GameState.Inventory.HasHerbPouch = $true
    if ($null -eq $script:GameState.Inventory.HerbPouchItems) {
        $script:GameState.Inventory.HerbPouchItems = @()
    }
    [void](Move-LWHerbPouchPotionItemsFromBackpack -State $script:GameState -WriteMessages:$WriteMessages)
    [void](Sync-LWAchievements -Context 'inventory')
    if ($WriteMessages) {
        Write-LWInfo 'Herb Pouch added as a separate carried container.'
    }
    return $true
}

function TryAdd-LWPreferredPotionStorageSilently {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return $false
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name
    $herbPouchFree = 0
    if (Test-LWStateHasHerbPouch -State $script:GameState) {
        $herbPouchFree = [Math]::Max(0, (6 - (Get-LWInventoryUsedCapacity -Type 'herbpouch' -Items @(Get-LWInventoryItems -Type 'herbpouch'))))
    }

    $backpackFree = 0
    if (Test-LWStateHasBackpack -State $script:GameState) {
        $backpackFree = [Math]::Max(0, (8 - (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))))
    }

    if (($herbPouchFree + $backpackFree) -lt $Quantity) {
        if (-not (Test-LWStateHasBackpack -State $script:GameState) -and $herbPouchFree -le 0) {
            Write-LWWarn 'You do not currently have a Backpack, and Herb Pouch has no free slots.'
        }
        else {
            Write-LWWarn ("{0} needs {1} total carried potion slot{2}, but only {3} are free across Herb Pouch and Backpack." -f $resolvedName, $Quantity, $(if ($Quantity -eq 1) { '' } else { 's' }), ($herbPouchFree + $backpackFree))
        }
        return $false
    }

    $herbToAdd = [Math]::Min($Quantity, $herbPouchFree)
    $backpackToAdd = $Quantity - $herbToAdd

    if ($herbToAdd -gt 0) {
        $script:GameState.Inventory.HerbPouchItems = @(Normalize-LWInventoryItemCollection -Type 'herbpouch' -Items (@($script:GameState.Inventory.HerbPouchItems) + @((1..$herbToAdd | ForEach-Object { $resolvedName }))))
    }
    if ($backpackToAdd -gt 0) {
        $script:GameState.Inventory.BackpackItems = @(Normalize-LWInventoryItemCollection -Type 'backpack' -Items (@($script:GameState.Inventory.BackpackItems) + @((1..$backpackToAdd | ForEach-Object { $resolvedName }))))
    }

    Register-LWStoryInventoryAchievementTriggers -Type $(if ($herbToAdd -gt 0 -and $backpackToAdd -eq 0) { 'herbpouch' } else { 'backpack' }) -Name $resolvedName
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    return $true
}

function Sync-LWHerbPouchState {
    param([object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Inventory) {
        return $State
    }

    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasHerbPouch') -or $null -eq $State.Inventory.HasHerbPouch) {
        $State.Inventory | Add-Member -Force -NotePropertyName HasHerbPouch -NotePropertyValue $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HerbPouchItems') -or $null -eq $State.Inventory.HerbPouchItems) {
        $State.Inventory | Add-Member -Force -NotePropertyName HerbPouchItems -NotePropertyValue @()
    }
    else {
        $State.Inventory.HerbPouchItems = @(Normalize-LWInventoryItemCollection -Type 'herbpouch' -Items @($State.Inventory.HerbPouchItems))
    }

    if ($null -ne $State.Storage -and $null -ne $State.Storage.Confiscated) {
        if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name 'HerbPouchItems') -or $null -eq $State.Storage.Confiscated.HerbPouchItems) {
            $State.Storage.Confiscated | Add-Member -Force -NotePropertyName HerbPouchItems -NotePropertyValue @()
        }
        else {
            $State.Storage.Confiscated.HerbPouchItems = @(Normalize-LWInventoryItemCollection -Type 'herbpouch' -Items @($State.Storage.Confiscated.HerbPouchItems))
        }
        if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name 'HasHerbPouch') -or $null -eq $State.Storage.Confiscated.HasHerbPouch) {
            $State.Storage.Confiscated | Add-Member -Force -NotePropertyName HasHerbPouch -NotePropertyValue $false
        }
    }

    if ($null -ne $State.RecoveryStash) {
        if (-not (Test-LWPropertyExists -Object $State.RecoveryStash -Name 'HerbPouch') -or $null -eq $State.RecoveryStash.HerbPouch) {
            $State.RecoveryStash | Add-Member -Force -NotePropertyName HerbPouch -NotePropertyValue (New-LWInventoryRecoveryEntry)
        }
        elseif (-not (Test-LWPropertyExists -Object $State.RecoveryStash.HerbPouch -Name 'Items') -or $null -eq $State.RecoveryStash.HerbPouch.Items) {
            $State.RecoveryStash.HerbPouch | Add-Member -Force -NotePropertyName Items -NotePropertyValue @()
        }
        else {
            $State.RecoveryStash.HerbPouch.Items = @(Normalize-LWInventoryItemCollection -Type 'herbpouch' -Items @($State.RecoveryStash.HerbPouch.Items))
        }
        foreach ($propertyName in @('BookNumber', 'Section', 'SavedOn')) {
            if (-not (Test-LWPropertyExists -Object $State.RecoveryStash.HerbPouch -Name $propertyName)) {
                $State.RecoveryStash.HerbPouch | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $null
            }
        }
    }

    $migratedLegacyHerbPouch = $false
    if ($null -ne $State.Inventory.SpecialItems) {
        $remainingSpecialItems = @()
        foreach ($item in @($State.Inventory.SpecialItems)) {
            if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHerbPouchItemNames) -Target ([string]$item)))) {
                $migratedLegacyHerbPouch = $true
                $State.Inventory.HasHerbPouch = $true
                continue
            }
            $remainingSpecialItems += $item
        }
        $State.Inventory.SpecialItems = @(Normalize-LWInventoryItemCollection -Type 'special' -Items @($remainingSpecialItems))
    }

    if (@($State.Inventory.HerbPouchItems).Count -gt 0) {
        $State.Inventory.HasHerbPouch = $true
    }

    if ($migratedLegacyHerbPouch -and $null -ne $State.Inventory.BackpackItems -and @($State.Inventory.HerbPouchItems).Count -lt 6) {
        $freeSlots = 6 - @($State.Inventory.HerbPouchItems).Count
        $remainingBackpack = @()
        foreach ($item in @($State.Inventory.BackpackItems)) {
            if ($freeSlots -gt 0 -and (Test-LWHerbPouchPotionItemName -Name ([string]$item))) {
                $State.Inventory.HerbPouchItems += [string]$item
                $freeSlots--
            }
            else {
                $remainingBackpack += $item
            }
        }
        $State.Inventory.HerbPouchItems = @(Normalize-LWInventoryItemCollection -Type 'herbpouch' -Items @($State.Inventory.HerbPouchItems))
        $State.Inventory.BackpackItems = @(Normalize-LWInventoryItemCollection -Type 'backpack' -Items @($remainingBackpack))
    }

    return $State
}

function Set-LWBackpackState {
    param(
        [Parameter(Mandatory = $true)][bool]$HasBackpack,
        [switch]$ClearContents,
        [switch]$WriteMessages
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    $alreadyHadBackpack = Test-LWStateHasBackpack -State $script:GameState
    $script:GameState.Inventory.HasBackpack = [bool]$HasBackpack

    if (-not $HasBackpack -and $ClearContents) {
        Set-LWInventoryItems -Type 'backpack' -Items @()
    }

    if ($WriteMessages) {
        if ($HasBackpack -and -not $alreadyHadBackpack) {
            Write-LWInfo 'Backpack restored.'
        }
        elseif (-not $HasBackpack -and $alreadyHadBackpack) {
            Write-LWInfo 'Backpack lost.'
        }
    }
}

function Lose-LWBackpack {
    param(
        [switch]$WriteMessages,
        [string]$Reason = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    $hadBackpack = Test-LWStateHasBackpack -State $script:GameState
    $lostItems = @(Get-LWInventoryItems -Type 'backpack')
    Set-LWBackpackState -HasBackpack:$false -ClearContents -WriteMessages:$WriteMessages

    if ($WriteMessages) {
        if ($hadBackpack -and $lostItems.Count -gt 0) {
            $prefix = if ([string]::IsNullOrWhiteSpace($Reason)) { 'Backpack lost' } else { $Reason }
            Write-LWInfo ("{0}. Backpack contents lost: {1}." -f $prefix, (Format-LWList -Items $lostItems))
        }
        elseif ($hadBackpack -and [string]::IsNullOrWhiteSpace($Reason) -eq $false) {
            Write-LWInfo ("{0}. Backpack was empty." -f $Reason)
        }
    }
}

function Restore-LWBackpackState {
    param([switch]$WriteMessages)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    Set-LWBackpackState -HasBackpack:$true -WriteMessages:$WriteMessages
}

function Get-LWConfiscatedInventorySummaryText {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Storage -or $null -eq $State.Storage.Confiscated) {
        return '(none)'
    }

    $parts = @()
    $weapons = @($State.Storage.Confiscated.Weapons)
    $backpack = @($State.Storage.Confiscated.BackpackItems)
    $herbPouch = @($State.Storage.Confiscated.HerbPouchItems)
    $special = @($State.Storage.Confiscated.SpecialItems)
    $pocket = @(
        if ((Test-LWPropertyExists -Object $State.Storage.Confiscated -Name 'PocketSpecialItems') -and $null -ne $State.Storage.Confiscated.PocketSpecialItems) {
            @($State.Storage.Confiscated.PocketSpecialItems)
        }
        else {
            @()
        }
    )
    $gold = if ($null -ne $State.Storage.Confiscated.GoldCrowns) { [int]$State.Storage.Confiscated.GoldCrowns } else { 0 }

    if ($weapons.Count -gt 0) {
        $parts += ('Weapons: {0}' -f (Format-LWList -Items $weapons))
    }
    if ($backpack.Count -gt 0) {
        $parts += ('Backpack: {0}' -f (Format-LWList -Items $backpack))
    }
    if ([bool]$State.Storage.Confiscated.HasHerbPouch -or $herbPouch.Count -gt 0) {
        $pouchValue = if ($herbPouch.Count -gt 0) { Format-LWList -Items $herbPouch } else { '(empty)' }
        $parts += ('Herb Pouch: {0}' -f $pouchValue)
    }
    if ($special.Count -gt 0) {
        $parts += ('Special: {0}' -f (Format-LWList -Items $special))
    }
    if ($pocket.Count -gt 0) {
        $parts += ('Pocket: {0}' -f (Format-LWList -Items $pocket))
    }
    if ($gold -gt 0) {
        $parts += ('Gold: {0}' -f $gold)
    }

    if ($parts.Count -eq 0) {
        return '(none)'
    }

    return ($parts -join ' | ')
}

function Test-LWStateHasConfiscatedEquipment {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State -or $null -eq $State.Storage -or $null -eq $State.Storage.Confiscated) {
        return $false
    }

    return (
        @($State.Storage.Confiscated.Weapons).Count -gt 0 -or
        @($State.Storage.Confiscated.BackpackItems).Count -gt 0 -or
        @($State.Storage.Confiscated.HerbPouchItems).Count -gt 0 -or
        [bool]$State.Storage.Confiscated.HasHerbPouch -or
        @($State.Storage.Confiscated.SpecialItems).Count -gt 0 -or
        ((Test-LWPropertyExists -Object $State.Storage.Confiscated -Name 'PocketSpecialItems') -and @($State.Storage.Confiscated.PocketSpecialItems).Count -gt 0) -or
        [int]$State.Storage.Confiscated.GoldCrowns -gt 0
    )
}

function Save-LWConfiscatedEquipment {
    param(
        [switch]$WriteMessages,
        [string]$Reason = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    $script:GameState.Storage.Confiscated.Weapons = @($script:GameState.Inventory.Weapons)
    $script:GameState.Storage.Confiscated.BackpackItems = @($script:GameState.Inventory.BackpackItems)
    $script:GameState.Storage.Confiscated.HerbPouchItems = @($script:GameState.Inventory.HerbPouchItems)
    $script:GameState.Storage.Confiscated.HasHerbPouch = [bool]$script:GameState.Inventory.HasHerbPouch
    $script:GameState.Storage.Confiscated.SpecialItems = @($script:GameState.Inventory.SpecialItems)
    $script:GameState.Storage.Confiscated.PocketSpecialItems = @(Get-LWPocketSpecialItems)
    $script:GameState.Storage.Confiscated.GoldCrowns = [int]$script:GameState.Inventory.GoldCrowns
    $script:GameState.Storage.Confiscated.BookNumber = [int]$script:GameState.Character.BookNumber
    $script:GameState.Storage.Confiscated.Section = [int]$script:GameState.CurrentSection
    $script:GameState.Storage.Confiscated.SavedOn = (Get-Date).ToString('o')

    $script:GameState.Inventory.Weapons = @()
    $script:GameState.Inventory.HerbPouchItems = @()
    $script:GameState.Inventory.HasHerbPouch = $false
    $script:GameState.Inventory.SpecialItems = @()
    $script:GameState.Inventory.PocketSpecialItems = @()
    $script:GameState.Inventory.GoldCrowns = 0
    Set-LWBackpackState -HasBackpack:$false -ClearContents
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages

    if ($WriteMessages) {
        $label = if ([string]::IsNullOrWhiteSpace($Reason)) { 'Confiscated equipment stored' } else { $Reason }
        Write-LWInfo ("{0}: {1}." -f $label, (Get-LWConfiscatedInventorySummaryText))
    }
}

function Restore-LWConfiscatedEquipment {
    param([switch]$WriteMessages)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or -not (Test-LWStateHasConfiscatedEquipment)) {
        return $false
    }

    $currentWeapons = @($script:GameState.Inventory.Weapons)
    $currentBackpackItems = @($script:GameState.Inventory.BackpackItems)
    $currentHerbPouchItems = @($script:GameState.Inventory.HerbPouchItems)
    $currentSpecialItems = @($script:GameState.Inventory.SpecialItems)
    $currentPocketSpecialItems = @(Get-LWPocketSpecialItems)
    $currentGoldCrowns = [int]$script:GameState.Inventory.GoldCrowns

    $restoredWeapons = @($script:GameState.Storage.Confiscated.Weapons)
    $restoredBackpackItems = @($script:GameState.Storage.Confiscated.BackpackItems)
    $restoredHerbPouchItems = @($script:GameState.Storage.Confiscated.HerbPouchItems)
    $restoredHasHerbPouch = [bool]$script:GameState.Storage.Confiscated.HasHerbPouch
    $restoredSpecialItems = @($script:GameState.Storage.Confiscated.SpecialItems)
    $restoredPocketSpecialItems = @(
        if ((Test-LWPropertyExists -Object $script:GameState.Storage.Confiscated -Name 'PocketSpecialItems') -and $null -ne $script:GameState.Storage.Confiscated.PocketSpecialItems) {
            @($script:GameState.Storage.Confiscated.PocketSpecialItems)
        }
        else {
            @()
        }
    )
    $restoredGoldCrowns = [int]$script:GameState.Storage.Confiscated.GoldCrowns

    Set-LWInventoryItems -Type 'weapon' -Items @($currentWeapons + $restoredWeapons)
    Set-LWInventoryItems -Type 'backpack' -Items @($currentBackpackItems + $restoredBackpackItems)
    $script:GameState.Inventory.HasHerbPouch = ([bool]$script:GameState.Inventory.HasHerbPouch -or $restoredHasHerbPouch -or @($currentHerbPouchItems + $restoredHerbPouchItems).Count -gt 0)
    Set-LWInventoryItems -Type 'herbpouch' -Items @($currentHerbPouchItems + $restoredHerbPouchItems)
    Set-LWInventoryItems -Type 'special' -Items @($currentSpecialItems + $restoredSpecialItems)
    $script:GameState.Inventory.PocketSpecialItems = @(Normalize-LWInventoryItemCollection -Type 'special' -Items @($currentPocketSpecialItems + $restoredPocketSpecialItems))
    $totalGoldCrowns = $currentGoldCrowns + $restoredGoldCrowns
    $script:GameState.Inventory.GoldCrowns = [Math]::Min(50, $totalGoldCrowns)
    $script:GameState.Inventory.HasBackpack = $true

    $script:GameState.Storage.Confiscated.Weapons = @()
    $script:GameState.Storage.Confiscated.BackpackItems = @()
    $script:GameState.Storage.Confiscated.HerbPouchItems = @()
    $script:GameState.Storage.Confiscated.HasHerbPouch = $false
    $script:GameState.Storage.Confiscated.SpecialItems = @()
    $script:GameState.Storage.Confiscated.PocketSpecialItems = @()
    $script:GameState.Storage.Confiscated.GoldCrowns = 0
    $script:GameState.Storage.Confiscated.BookNumber = $null
    $script:GameState.Storage.Confiscated.Section = $null
    $script:GameState.Storage.Confiscated.SavedOn = $null
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages

    if ($WriteMessages) {
        Write-LWInfo 'Your confiscated equipment has been restored.'
        if ($totalGoldCrowns -gt 50) {
            Write-LWWarn ("Restoring your confiscated Gold Crowns would take you to {0}. Gold remains capped at 50, so the excess is lost." -f $totalGoldCrowns)
        }

        $weaponCount = @($script:GameState.Inventory.Weapons).Count
        $backpackUsedCapacity = Get-LWInventoryUsedCapacity -Type 'backpack' -Items @($script:GameState.Inventory.BackpackItems)
        $herbPouchUsedCapacity = Get-LWInventoryUsedCapacity -Type 'herbpouch' -Items @($script:GameState.Inventory.HerbPouchItems)
        $specialCount = @($script:GameState.Inventory.SpecialItems).Count
        $overLimitWarnings = @()
        if ($weaponCount -gt 2) {
            $overLimitWarnings += ("Weapons {0}/2" -f $weaponCount)
        }
        if ($backpackUsedCapacity -gt 8) {
            $overLimitWarnings += ("Backpack {0}/8" -f $backpackUsedCapacity)
        }
        if ($script:GameState.Inventory.HasHerbPouch -and $herbPouchUsedCapacity -gt 6) {
            $overLimitWarnings += ("Herb Pouch {0}/6" -f $herbPouchUsedCapacity)
        }
        if ($specialCount -gt 12) {
            $overLimitWarnings += ("Special Items {0}/12" -f $specialCount)
        }
        if ($overLimitWarnings.Count -gt 0) {
            Write-LWWarn ("Restoring your confiscated gear leaves you over the normal carry limits: {0}. Remove or drop items when you can." -f ($overLimitWarnings -join ', '))
        }
    }

    return $true
}

function Move-LWSpecialItemsToSafekeeping {
    param(
        [Parameter(Mandatory = $true)][string[]]$Items,
        [switch]$WriteMessages
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    foreach ($item in @($Items)) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $removed = Remove-LWInventoryItemSilently -Type 'special' -Name $item -Quantity 1
        if ($removed -gt 0) {
            $script:GameState.Storage.SafekeepingSpecialItems = @($script:GameState.Storage.SafekeepingSpecialItems) + @($item)
        }
    }

    if ($WriteMessages -and @($Items).Count -gt 0) {
        Write-LWInfo ("Placed in safekeeping: {0}." -f (Format-LWList -Items @($Items)))
    }
}

function Move-LWSpecialItemsFromSafekeeping {
    param(
        [Parameter(Mandatory = $true)][string[]]$Items,
        [switch]$WriteMessages
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return
    }

    $reclaimed = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    $remaining = New-Object System.Collections.Generic.List[string]
    foreach ($storedItem in @($script:GameState.Storage.SafekeepingSpecialItems)) {
        [void]$remaining.Add([string]$storedItem)
    }

    foreach ($item in @($Items)) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        $matchIndex = -1
        for ($i = 0; $i -lt $remaining.Count; $i++) {
            if ([string]$remaining[$i] -ieq [string]$item) {
                $matchIndex = $i
                break
            }
        }

        if ($matchIndex -lt 0) {
            continue
        }

        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name ([string]$remaining[$matchIndex])) {
            [void]$reclaimed.Add([string]$remaining[$matchIndex])
            $remaining.RemoveAt($matchIndex)
        }
        else {
            [void]$failed.Add([string]$remaining[$matchIndex])
        }
    }

    $script:GameState.Storage.SafekeepingSpecialItems = @($remaining.ToArray())

    if ($WriteMessages -and $reclaimed.Count -gt 0) {
        Write-LWInfo ("Recovered from safekeeping: {0}." -f (Format-LWList -Items @($reclaimed.ToArray())))
    }
    if ($WriteMessages -and $failed.Count -gt 0) {
        Write-LWWarn ("No room to reclaim from safekeeping right now: {0}." -f (Format-LWList -Items @($failed.ToArray())))
    }
}

function Add-LWWeaponWithOptionalReplace {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$PromptLabel = '',
        [switch]$Silent
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($weapons.Count -lt 2) {
        return (TryAdd-LWInventoryItemSilently -Type 'weapon' -Name $resolvedName)
    }

    $displayName = if ([string]::IsNullOrWhiteSpace($PromptLabel)) { $resolvedName } else { $PromptLabel }
    if (-not $Silent) {
        Write-LWInfo ("You must replace a carried weapon to take {0}." -f $displayName)
        Show-LWInventorySlotsSection -Type 'weapon'
    }

    $slot = Read-LWInt -Prompt ("Replace which weapon with {0}?" -f $displayName) -Min 1 -Max 2
    $replacedWeapon = [string]$weapons[$slot - 1]
    $weapons[$slot - 1] = $resolvedName
    Set-LWInventoryItems -Type 'weapon' -Items @($weapons)
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages

    if (-not $Silent) {
        Write-LWInfo ("Exchanged {0} for {1}." -f $replacedWeapon, $displayName)
    }

    return $true
}

function Get-LWRecoveryStashPropertyName {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ($Type) {
        'weapon' { return 'Weapon' }
        'backpack' { return 'Backpack' }
        'herbpouch' { return 'HerbPouch' }
        'special' { return 'Special' }
    }
}

function Get-LWRecoveryStashEntry {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $propertyName = Get-LWRecoveryStashPropertyName -Type $Type
    return $script:GameState.RecoveryStash.$propertyName
}

function Save-LWInventoryRecoveryEntry {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][object[]]$Items
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $entry = Get-LWRecoveryStashEntry -Type $Type
    $entry.Items = @($Items)
    $entry.BookNumber = [int]$script:GameState.Character.BookNumber
    $entry.Section = [int]$script:GameState.CurrentSection
    $entry.SavedOn = (Get-Date).ToString('o')
}

function Clear-LWInventoryRecoveryEntry {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $entry = Get-LWRecoveryStashEntry -Type $Type
    $entry.Items = @()
    $entry.BookNumber = $null
    $entry.Section = $null
    $entry.SavedOn = $null
}

function Get-LWInventoryRecoveryItems {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return @((Get-LWRecoveryStashEntry -Type $Type).Items)
}

function Show-LWInventorySlotsSection {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $items = @(Get-LWInventoryItems -Type $Type)
    $label = Get-LWInventoryTypeLabel -Type $Type
    $labelColor = Get-LWInventoryTypeColor -Type $Type
    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState

    if ($Type -eq 'backpack' -and -not $hasBackpack) {
        Write-Host ("  {0} (lost)" -f $label) -ForegroundColor $labelColor
        for ($i = 1; $i -le $capacity; $i++) {
            Write-Host ("    {0,2}. " -f $i) -NoNewline -ForegroundColor DarkGray
            Write-Host '(unavailable)' -ForegroundColor DarkGray
        }
        return
    }

    if ($Type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        return
    }

    if ($null -ne $capacity) {
        $usedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $items
        Write-Host ("  {0} ({1}/{2})" -f $label, $usedCapacity, $capacity) -ForegroundColor $labelColor
        $slotCount = [Math]::Max([int]$capacity, [int]$usedCapacity)
        $slotMap = if ($Type -eq 'backpack') { @(Get-LWBackpackSlotMap -Items $items) } else { @() }
        for ($i = 1; $i -le $slotCount; $i++) {
            if ($Type -eq 'backpack') {
                $slotMatches = @($slotMap | Where-Object { [int]$_.Slot -eq $i })
                $slotEntry = if ($slotMatches.Count -gt 0) { $slotMatches[0] } else { $null }
                $hasItem = ($null -ne $slotEntry)
                $slotText = if ($hasItem) { [string]$slotEntry.DisplayText } else { '(empty)' }
                $slotColor = if (-not $hasItem) { 'DarkGray' } elseif ([bool]$slotEntry.IsPrimary) { 'Gray' } else { 'DarkGray' }
            }
            else {
                $hasItem = ($i -le $items.Count)
                $slotText = if ($hasItem) { [string]$items[$i - 1] } else { '(empty)' }
                $slotColor = if ($hasItem) { 'Gray' } else { 'DarkGray' }
            }
            Write-Host ("    {0,2}. " -f $i) -NoNewline -ForegroundColor DarkGray
            Write-Host $slotText -ForegroundColor $slotColor
        }
        return
    }

    Write-Host ("  {0} ({1})" -f $label, $items.Count) -ForegroundColor $labelColor
    if ($items.Count -eq 0) {
        Write-LWSubtle '    (none)'
        return
    }

    for ($i = 0; $i -lt $items.Count; $i++) {
        Write-Host ("    {0,2}. " -f ($i + 1)) -NoNewline -ForegroundColor DarkGray
        Write-Host ([string]$items[$i]) -ForegroundColor 'Gray'
    }
}

function Get-LWInventorySlotDisplayText {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][int]$Slot,
        [object[]]$Items = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $items = @($(if ($null -eq $Items) { @(Get-LWInventoryItems -Type $Type) } else { @($Items) }))
    $items = @($items | Where-Object {
            $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_)
        })
    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState

    if ($Slot -lt 1 -or $Slot -gt [int]$capacity) {
        return ''
    }

    if ($Type -eq 'backpack' -and -not $hasBackpack) {
        return '(unavailable)'
    }

    if ($Type -eq 'backpack') {
        $slotMatches = @((Get-LWBackpackSlotMap -Items $items) | Where-Object { [int]$_.Slot -eq $Slot })
        if ($slotMatches.Count -gt 0) {
            return [string]$slotMatches[0].DisplayText
        }
        return '(empty)'
    }

    $itemList = @($items)
    if ($Slot -le @($itemList).Count) {
        return [string]@($itemList)[$Slot - 1]
    }

    return '(empty)'
}

function Show-LWInventorySlotsGridSection {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        return
    }

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $title = Get-LWInventoryTypeLabel -Type $Type
    $accentColor = Get-LWInventoryTypeColor -Type $Type
    $items = @(Get-LWInventoryItems -Type $Type)
    $leftColumnCount = [int][Math]::Ceiling([double]$capacity / 2.0)
    $slotMapBySlot = @{}

    if ($Type -eq 'backpack') {
        foreach ($slotEntry in @(Get-LWBackpackSlotMap -Items $items)) {
            if ($null -eq $slotEntry) {
                continue
            }

            $slotMapBySlot[[int]$slotEntry.Slot] = $slotEntry
        }
    }

    Write-LWRetroPanelHeader -Title $title -AccentColor $accentColor
    for ($row = 1; $row -le $leftColumnCount; $row++) {
        $leftSlot = $row
        $rightSlot = $row + $leftColumnCount

        if ($Type -eq 'backpack') {
            $leftSlotEntry = if ($slotMapBySlot.ContainsKey($leftSlot)) { $slotMapBySlot[$leftSlot] } else { $null }
            $leftSlotText = if ($null -ne $leftSlotEntry) { [string]$leftSlotEntry.DisplayText } else { '(empty)' }
            $leftColor = if ($null -eq $leftSlotEntry) { 'DarkGray' } elseif ([bool]$leftSlotEntry.IsPrimary) { 'Gray' } else { 'DarkGray' }

            if ($rightSlot -le $capacity) {
                $rightSlotEntry = if ($slotMapBySlot.ContainsKey($rightSlot)) { $slotMapBySlot[$rightSlot] } else { $null }
                $rightSlotText = if ($null -ne $rightSlotEntry) { [string]$rightSlotEntry.DisplayText } else { '(empty)' }
                $rightColor = if ($null -eq $rightSlotEntry) { 'DarkGray' } elseif ([bool]$rightSlotEntry.IsPrimary) { 'Gray' } else { 'DarkGray' }
            }
            else {
                $rightSlotText = ''
                $rightColor = 'DarkGray'
            }
        }
        else {
            $leftSlotText = Get-LWInventorySlotDisplayText -Type $Type -Slot $leftSlot -Items $items
            $leftColor = if ($leftSlotText -eq '(empty)' -or $leftSlotText -eq '(unavailable)') { 'DarkGray' } else { 'Gray' }

            if ($rightSlot -le $capacity) {
                $rightSlotText = Get-LWInventorySlotDisplayText -Type $Type -Slot $rightSlot -Items $items
                $rightColor = if ($rightSlotText -eq '(empty)' -or $rightSlotText -eq '(unavailable)') { 'DarkGray' } else { 'Gray' }
            }
            else {
                $rightSlotText = ''
                $rightColor = 'DarkGray'
            }
        }

        $leftText = ("{0,2}. {1}" -f $leftSlot, $leftSlotText)
        $rightText = if ($rightSlot -le $capacity) {
            ("{0,2}. {1}" -f $rightSlot, $rightSlotText)
        }
        else {
            ''
        }

        Write-LWRetroPanelTwoColumnRow `
            -LeftText $leftText `
            -RightText $rightText `
            -LeftColor $leftColor `
            -RightColor $(if ([string]::IsNullOrWhiteSpace($rightText)) { 'DarkGray' } else { $rightColor }) `
            -LeftWidth 28 `
            -Gap 2
    }
    Write-LWRetroPanelFooter
}

function Show-LWInventorySummary {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $weapons = @($script:GameState.Inventory.Weapons)
    $backpack = @($script:GameState.Inventory.BackpackItems)
    $herbPouch = @($script:GameState.Inventory.HerbPouchItems)
    $special = @($script:GameState.Inventory.SpecialItems)
    $safekeeping = @($script:GameState.Storage.SafekeepingSpecialItems)
    $backpackUsedCapacity = Get-LWInventoryUsedCapacity -Type 'backpack' -Items $backpack
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState
    $showHerbPouch = Test-LWStateHasHerbPouch -State $script:GameState
    $showArrows = ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0)

    $formatSummaryCell = {
        param(
            [Parameter(Mandatory = $true)][string]$Label,
            [Parameter(Mandatory = $true)][string]$Value
        )

        return ("{0,-11}: {1}" -f $Label, $Value)
    }

    $weaponSummary = (Format-LWCompactInventorySummary -Items $weapons -MaxGroups 2)
    $backpackSummary = if ($hasBackpack) { (Format-LWCompactInventorySummary -Items $backpack -MaxGroups 3) } else { 'unavailable (lost)' }
    $herbPouchSummary = if ($showHerbPouch) { (Format-LWCompactInventorySummary -Items $herbPouch -MaxGroups 3) } else { '' }
    $specialSummary = (Format-LWList -Items $special)
    $safekeepingSummary = if ($safekeeping.Count -gt 0) { (Format-LWList -Items $safekeeping) } else { '' }

    Write-LWRetroPanelHeader -Title 'Inventory' -AccentColor 'Yellow'
    Write-LWRetroPanelTwoColumnRow `
        -LeftText (& $formatSummaryCell 'Weapons' ("{0}/2  {1}" -f $weapons.Count, $weaponSummary)) `
        -RightText (& $formatSummaryCell 'Backpack' ("{0}/8  {1}" -f $backpackUsedCapacity, $backpackSummary)) `
        -LeftColor 'Gray' `
        -RightColor $(if ($hasBackpack) { 'Gray' } else { 'DarkGray' }) `
        -LeftWidth 35 `
        -Gap 2

    if ($showHerbPouch -or $showArrows) {
        Write-LWRetroPanelTwoColumnRow `
            -LeftText $(if ($showHerbPouch) { (& $formatSummaryCell 'Herb Pouch' ("{0}/6  {1}" -f $herbPouch.Count, $herbPouchSummary)) } else { '' }) `
            -RightText $(if ($showArrows) { (& $formatSummaryCell 'Arrows' (Format-LWQuiverArrowCounter -State $script:GameState)) } else { '' }) `
            -LeftColor $(if ($showHerbPouch) { 'DarkGreen' } else { 'DarkGray' }) `
            -RightColor $(if ($showArrows) { 'DarkYellow' } else { 'DarkGray' }) `
            -LeftWidth 35 `
            -Gap 2
    }

    Write-LWRetroPanelTwoColumnRow `
        -LeftText (& $formatSummaryCell 'Special Items' ("{0}/12" -f $special.Count)) `
        -RightText (& $formatSummaryCell 'Gold Crowns' ("{0}/50" -f $script:GameState.Inventory.GoldCrowns)) `
        -LeftColor 'Gray' `
        -RightColor 'Yellow' `
        -LeftWidth 35 `
        -Gap 2

    Write-LWRetroPanelFooter
}

function Get-LWInventoryNoteRows {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return @()
    }

    $rows = @()

    if (Test-LWStateHasSommerswerd -State $script:GameState) {
        $sommerswerdBonus = Get-LWStateSommerswerdCombatSkillBonus -State $script:GameState
        $rows += [pscustomobject]@{
            Label = 'Sommerswerd'
            Value = ("+{0} CS in combat; undead x2" -f $sommerswerdBonus)
        }
    }
    if (Test-LWStateHasBoneSword -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Bone Sword'
            Value = '+1 CS in Book 3 only'
        }
    }
    if (Test-LWStateHasBroadswordPlusOne -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Broadsword +1'
            Value = '+1 CS; counts as Broadsword'
        }
    }
    if (Test-LWStateHasMagicSpear -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Magic Spear'
            Value = 'Counts as Spear; special Book 2 use'
        }
    }
    if (Test-LWStateHasDrodarinWarHammer -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'War Hammer'
            Value = '+1 CS; counts as Warhammer'
        }
    }
    if (Test-LWStateHasBroninWarhammer -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Bronin Warhammer'
            Value = '+1 CS; +2 vs armoured; counts as Warhammer'
        }
    }
    if (Test-LWStateHasBroninSleeveShield -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Bronin Sleeve-shield'
            Value = '+1 CS and +1 END in physical combat; does not stack with Shield'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCaptainDValSwordWeaponNames) -Type 'weapon'))) {
        $rows += [pscustomobject]@{
            Label = 'Captain Sword'
            Value = '+1 CS; counts as Sword'
        }
    }
    if (Test-LWStateHasSolnaris -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Solnaris'
            Value = '+2 CS; counts as Sword/Broadsword'
        }
    }
    if ((Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState) -gt 0) {
        $rows += [pscustomobject]@{
            Label = 'Silver Helm'
            Value = '+2 CS carried'
        }
    }
    if ((Get-LWStateHelmetEnduranceBonus -State $script:GameState) -gt 0) {
        $rows += [pscustomobject]@{
            Label = 'Helmet'
            Value = '+2 END carried'
        }
    }
    elseif ((Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWHelmetItemNames) -Type 'special') -and (Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState) -gt 0) {
        $rows += [pscustomobject]@{
            Label = 'Helmet'
            Value = 'No END bonus while Silver Helm is carried'
        }
    }
    if ((Get-LWStatePaddedLeatherEnduranceBonus -State $script:GameState) -gt 0) {
        $rows += [pscustomobject]@{
            Label = 'Padded Waistcoat'
            Value = '+2 END carried'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWVordakGemItemNames) -Type 'backpack'))) {
        $rows += [pscustomobject]@{
            Label = 'Vordak Gem'
            Value = 'Cursed item; some routes punish it'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCrystalStarPendantItemNames) -Type 'special'))) {
        $rows += [pscustomobject]@{
            Label = 'Crystal Pendant'
            Value = 'Carry-forward story item'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMealOfLaumspurItemNames) -Type 'backpack'))) {
        $rows += [pscustomobject]@{
            Label = 'Meal of Laumspur'
            Value = 'Meal or restore 3 END'
        }
    }
    if (Test-LWStateHasHerbPouch -State $script:GameState) {
        $rows += [pscustomobject]@{
            Label = 'Herb Pouch'
            Value = '6 potion slots'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWPotentHealingPotionItemNames) -Type 'backpack'))) {
        $rows += [pscustomobject]@{
            Label = 'Potent Laumspur'
            Value = 'Restores 5 END'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWLongRopeItemNames) -Type 'backpack'))) {
        $rows += [pscustomobject]@{
            Label = 'Long Rope'
            Value = 'Uses 2 backpack slots'
        }
    }
    if (Test-LWStateHasQuiver -State $script:GameState) {
        $quiverName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWAnyQuiverItemNames) -Type 'special'
        if ([string]::IsNullOrWhiteSpace($quiverName)) {
            $quiverName = 'Quiver'
        }
        $rows += [pscustomobject]@{
            Label = [string]$quiverName
            Value = ("{0} arrows for Bow" -f (Format-LWQuiverArrowCounter -State $script:GameState))
        }
    }

    return @($rows)
}

function Show-LWInventoryNotesPanel {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $rows = @(Get-LWInventoryNoteRows)
    if ($rows.Count -eq 0) {
        return
    }

    $labelWidth = 16
    foreach ($row in $rows) {
        $labelText = if ($null -eq $row.Label) { '' } else { [string]$row.Label }
        if ($labelText.Length -gt $labelWidth) {
            $labelWidth = $labelText.Length
        }
    }
    $labelWidth = [Math]::Min(18, [Math]::Max(12, $labelWidth))

    Write-LWRetroPanelHeader -Title 'Inventory Notes' -AccentColor 'DarkYellow'
    foreach ($row in $rows) {
        Write-LWRetroPanelKeyValueRow -Label ([string]$row.Label) -Value ([string]$row.Value) -LabelColor 'DarkYellow' -ValueColor 'Gray' -LabelWidth $labelWidth
    }
    Write-LWRetroPanelFooter
}

function Show-LWInventory {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowInventoryScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
}

function Show-LWSheet {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowSheetScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
}

function Add-LWInventoryItem {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-LWWarn 'Item name cannot be empty.'
        return
    }
    if ($Quantity -lt 1) {
        Write-LWWarn 'Quantity must be at least 1.'
        return
    }
    if ($Type -eq 'special' -and $Quantity -gt 1) {
        Write-LWWarn 'Special Items cannot be stacked. Add them one at a time.'
        return
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

    if ($Type -eq 'backpack' -and
        -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWArrowItemNames) -Target $resolvedName)) -and
        (Test-LWStateHasQuiver -State $script:GameState)) {
        $currentArrows = Sync-LWQuiverArrowState -State $script:GameState
        $capacity = Get-LWQuiverArrowCapacity
        if (($currentArrows + $Quantity) -gt $capacity) {
            $freeArrows = [Math]::Max(0, ($capacity - $currentArrows))
            Write-LWWarn ("Quiver can only hold {0} more arrow{1}." -f $freeArrows, $(if ($freeArrows -eq 1) { '' } else { 's' }))
            return
        }

        $script:GameState.Inventory.QuiverArrows = ($currentArrows + $Quantity)
        Write-LWInfo ("Added {0} x Arrow to quiver. Now {1}." -f $Quantity, (Format-LWQuiverArrowCounter -State $script:GameState))
        Invoke-LWMaybeAutosave
        return
    }

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHerbPouchItemNames) -Target $resolvedName))) {
        if (Grant-LWHerbPouch -WriteMessages) {
            Invoke-LWMaybeAutosave
        }
        return
    }

    if (($Type -eq 'herbpouch' -or ($Type -eq 'backpack' -and (Test-LWHerbPouchPotionItemName -Name $resolvedName) -and (Test-LWStateHasHerbPouch -State $script:GameState)))) {
        if (-not (Test-LWStateHasHerbPouch -State $script:GameState)) {
            Write-LWWarn 'You are not carrying a Herb Pouch.'
            return
        }
        if (-not (Test-LWHerbPouchPotionItemName -Name $resolvedName)) {
            Write-LWWarn 'Only potion items can be stored in the Herb Pouch.'
            return
        }
        if (-not (TryAdd-LWPreferredPotionStorageSilently -Name $resolvedName -Quantity $Quantity)) {
            return
        }
        Write-LWInfo "Added $Quantity x $resolvedName to carried potion storage."
        Invoke-LWMaybeAutosave
        return
    }

    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack. Recover one before adding Backpack items.'
        return
    }

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $label = Get-LWInventoryTypeLabel -Type $Type
    $current = @(Get-LWInventoryItems -Type $Type)
    if ($Type -eq 'special' -and (@($current) -icontains $resolvedName)) {
        Write-LWWarn ("{0} is already in Special Items." -f $resolvedName)
        return
    }
    $currentUsedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $current
    $requiredCapacity = if ($Type -eq 'backpack') { $Quantity * (Get-LWBackpackItemSlotSize -Name $resolvedName) } else { $Quantity }
    if ($null -ne $capacity -and (($currentUsedCapacity + $requiredCapacity) -gt $capacity)) {
        if ($Type -eq 'backpack') {
            $freeSlots = [Math]::Max(0, ([int]$capacity - [int]$currentUsedCapacity))
            $neededLabel = if ($requiredCapacity -eq 1) { 'slot' } else { 'slots' }
            $freeLabel = if ($freeSlots -eq 1) { 'is' } else { 'are' }
            Write-LWWarn ("{0} needs {1} backpack {2}, but only {3} {4} free. Drop or use an item first." -f $resolvedName, $requiredCapacity, $neededLabel, $freeSlots, $freeLabel)
        }
        else {
            Write-LWWarn ("You can only carry {0} {1}." -f $capacity, $label.ToLowerInvariant())
        }
        return
    }

    for ($i = 0; $i -lt $Quantity; $i++) {
        $current += $resolvedName
    }
    $current = Normalize-LWInventoryItemCollection -Type $Type -Items @($current)

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = $current }
        'backpack' { $script:GameState.Inventory.BackpackItems = $current }
        'herbpouch' { $script:GameState.Inventory.HerbPouchItems = $current }
        'special' { $script:GameState.Inventory.SpecialItems = $current }
    }

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWAnyQuiverItemNames) -Target $resolvedName))) {
        $script:GameState.Inventory.QuiverArrows = Get-LWQuiverArrowCapacity -State $script:GameState
    }

    Register-LWStoryInventoryAchievementTriggers -Type $Type -Name $resolvedName
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    Write-LWInfo "Added $Quantity x $resolvedName to $Type inventory."
    Invoke-LWMaybeAutosave
}

function TryAdd-LWInventoryItemSilently {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return $false
    }
    if ($Type -eq 'special' -and $Quantity -gt 1) {
        Write-LWWarn 'Special Items cannot be stacked. Add them one at a time.'
        return $false
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

    if ($Type -eq 'backpack' -and
        -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWArrowItemNames) -Target $resolvedName)) -and
        (Test-LWStateHasQuiver -State $script:GameState)) {
        $currentArrows = Sync-LWQuiverArrowState -State $script:GameState
        $capacity = Get-LWQuiverArrowCapacity
        if (($currentArrows + $Quantity) -gt $capacity) {
            $freeArrows = [Math]::Max(0, ($capacity - $currentArrows))
            Write-LWWarn ("Quiver can only hold {0} more arrow{1}." -f $freeArrows, $(if ($freeArrows -eq 1) { '' } else { 's' }))
            return $false
        }

        $script:GameState.Inventory.QuiverArrows = ($currentArrows + $Quantity)
        return $true
    }

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHerbPouchItemNames) -Target $resolvedName))) {
        return (Grant-LWHerbPouch)
    }

    if (($Type -eq 'herbpouch' -or ($Type -eq 'backpack' -and (Test-LWHerbPouchPotionItemName -Name $resolvedName) -and (Test-LWStateHasHerbPouch -State $script:GameState)))) {
        if (-not (Test-LWStateHasHerbPouch -State $script:GameState)) {
            Write-LWWarn 'You are not carrying a Herb Pouch.'
            return $false
        }
        if (-not (Test-LWHerbPouchPotionItemName -Name $resolvedName)) {
            Write-LWWarn 'Only potion items can be stored in the Herb Pouch.'
            return $false
        }
        return (TryAdd-LWPreferredPotionStorageSilently -Name $resolvedName -Quantity $Quantity)
    }

    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack. Recover one before adding Backpack items.'
        return $false
    }

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $current = @(Get-LWInventoryItems -Type $Type)
    if ($Type -eq 'special' -and (@($current) -icontains $resolvedName)) {
        Write-LWWarn ("{0} is already in Special Items." -f $resolvedName)
        return $false
    }
    $currentUsedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $current
    $requiredCapacity = if ($Type -eq 'backpack') { $Quantity * (Get-LWBackpackItemSlotSize -Name $resolvedName) } else { $Quantity }
    if ($null -ne $capacity -and (($currentUsedCapacity + $requiredCapacity) -gt $capacity)) {
        if ($Type -eq 'backpack') {
            $freeSlots = [Math]::Max(0, ([int]$capacity - [int]$currentUsedCapacity))
            $neededLabel = if ($requiredCapacity -eq 1) { 'slot' } else { 'slots' }
            $freeLabel = if ($freeSlots -eq 1) { 'is' } else { 'are' }
            Write-LWWarn ("{0} needs {1} backpack {2}, but only {3} {4} free. Drop or use an item first." -f $resolvedName, $requiredCapacity, $neededLabel, $freeSlots, $freeLabel)
        }
        else {
            Write-LWWarn ("You can only carry {0} {1}." -f $capacity, (Get-LWInventoryTypeLabel -Type $Type).ToLowerInvariant())
        }
        return $false
    }

    for ($i = 0; $i -lt $Quantity; $i++) {
        $current += $resolvedName
    }
    $current = Normalize-LWInventoryItemCollection -Type $Type -Items @($current)

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = @($current) }
        'backpack' { $script:GameState.Inventory.BackpackItems = @($current) }
        'herbpouch' { $script:GameState.Inventory.HerbPouchItems = @($current) }
        'special' { $script:GameState.Inventory.SpecialItems = @($current) }
    }

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWAnyQuiverItemNames) -Target $resolvedName))) {
        $script:GameState.Inventory.QuiverArrows = Get-LWQuiverArrowCapacity -State $script:GameState
    }

    Register-LWStoryInventoryAchievementTriggers -Type $Type -Name $resolvedName
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    return $true
}

function Remove-LWInventoryItemSilently {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return 0
    }

    $source = switch ($Type) {
        'weapon' { @($script:GameState.Inventory.Weapons) }
        'backpack' { @($script:GameState.Inventory.BackpackItems) }
        'herbpouch' { @($script:GameState.Inventory.HerbPouchItems) }
        'special' { @($script:GameState.Inventory.SpecialItems) }
    }

    $remaining = @()
    $removed = 0
    foreach ($item in $source) {
        if ($removed -lt $Quantity -and [string]$item -ieq $Name) {
            $removed++
            continue
        }
        $remaining += $item
    }

    if ($removed -eq 0) {
        return 0
    }

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = @($remaining) }
        'backpack' { $script:GameState.Inventory.BackpackItems = @($remaining) }
        'herbpouch' { $script:GameState.Inventory.HerbPouchItems = @($remaining) }
        'special' { $script:GameState.Inventory.SpecialItems = @($remaining) }
    }

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWAnyQuiverItemNames) -Target $Name)) -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWAnyQuiverItemNames) -Type 'special')) {
        $script:GameState.Inventory.QuiverArrows = 0
    }

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    return $removed
}

function Add-LWInventoryInteractive {
    param([string[]]$InputParts = @())
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $InputParts) {
        $InputParts = @()
    }
    else {
        $InputParts = @($InputParts)
    }

    Set-LWScreen -Name 'inventory'
    $type = $null
    if ($InputParts.Count -gt 1) {
        $type = Resolve-LWInventoryType -Value $InputParts[1]
        if ($null -eq $type) {
            Write-LWWarn 'Type must be weapon, backpack, herbpouch, or special.'
            return
        }
    }

    if ($null -eq $type) {
        $type = Resolve-LWInventoryType -Value (Read-LWText -Prompt 'Item type (weapon/backpack/herbpouch/special)')
        if ($null -eq $type) {
            Write-LWWarn 'Type must be weapon, backpack, herbpouch, or special.'
            return
        }
    }

    $name = ''
    $quantity = 1
    if ($InputParts.Count -gt 2) {
        $nameParts = @($InputParts[2..($InputParts.Count - 1)])
        $quantityValue = 0
        if ($nameParts.Count -gt 1 -and [int]::TryParse($nameParts[-1], [ref]$quantityValue) -and $quantityValue -ge 1) {
            $quantity = $quantityValue
            $nameParts = @($nameParts[0..($nameParts.Count - 2)])
        }
        $name = (@($nameParts) -join ' ').Trim()
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = Read-LWText -Prompt 'Item name'
    }

    if ($InputParts.Count -le 2) {
        $quantity = Read-LWInt -Prompt 'Quantity' -Default 1 -Min 1
    }

    Add-LWInventoryItem -Type $type -Name $name -Quantity $quantity
}

function Remove-LWInventoryItem {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Quantity -lt 1) {
        Write-LWWarn 'Quantity must be at least 1.'
        return
    }

    $source = switch ($Type) {
        'weapon'   { @($script:GameState.Inventory.Weapons) }
        'backpack' { @($script:GameState.Inventory.BackpackItems) }
        'herbpouch' { @($script:GameState.Inventory.HerbPouchItems) }
        'special'  { @($script:GameState.Inventory.SpecialItems) }
    }

    $remaining = @()
    $removed = 0
    foreach ($item in $source) {
        if ($removed -lt $Quantity -and $item -ieq $Name) {
            $removed += 1
            continue
        }
        $remaining += $item
    }

    if ($removed -eq 0) {
        Write-LWWarn "No item named '$Name' found in $Type inventory."
        return
    }

    switch ($Type) {
        'weapon'   { $script:GameState.Inventory.Weapons = $remaining }
        'backpack' { $script:GameState.Inventory.BackpackItems = $remaining }
        'herbpouch' { $script:GameState.Inventory.HerbPouchItems = $remaining }
        'special'  { $script:GameState.Inventory.SpecialItems = $remaining }
    }

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    Write-LWInfo "Removed $removed x $Name from $Type inventory."
    Invoke-LWMaybeAutosave
}

function Remove-LWInventoryItemBySlot {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][int]$Slot
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Slot -lt 1) {
        Write-LWWarn 'Slot number must be at least 1.'
        return
    }

    $items = @(Get-LWInventoryItems -Type $Type)
    $label = Get-LWInventoryTypeLabel -Type $Type
    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $usedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $items
    $maxSlot = if ($null -ne $capacity) { [Math]::Max([int]$capacity, [int]$usedCapacity) } else { [int]$items.Count }

    if ($items.Count -eq 0) {
        Write-LWWarn "$label is empty."
        return
    }

    if ($Slot -gt $maxSlot) {
        Write-LWWarn "$label slot must be between 1 and $maxSlot."
        return
    }
    if ($Type -eq 'backpack') {
        $slotEntry = @(Get-LWBackpackSlotMap -Items $items | Where-Object { [int]$_.Slot -eq $Slot } | Select-Object -First 1)
        if ($slotEntry.Count -eq 0) {
            Write-LWWarn "$label slot $Slot is empty."
            return
        }
        $removeIndex = [int]$slotEntry[0].ItemIndex
    }
    else {
        if ($Slot -gt $items.Count) {
            Write-LWWarn "$label slot $Slot is empty."
            return
        }
        $removeIndex = ($Slot - 1)
    }

    $removedItem = [string]$items[$removeIndex]
    $remaining = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($i -ne $removeIndex) {
            $remaining += $items[$i]
        }
    }

    Set-LWInventoryItems -Type $Type -Items $remaining
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    Write-LWInfo "Removed $removedItem from $label slot $Slot."
    Invoke-LWMaybeAutosave
}

function Remove-LWInventorySection {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $items = @(Get-LWInventoryItems -Type $Type)
    $label = Get-LWInventoryTypeLabel -Type $Type

    if ($items.Count -eq 0) {
        Write-LWWarn "$label is empty."
        return
    }

    Save-LWInventoryRecoveryEntry -Type $Type -Items @($items)
    Set-LWInventoryItems -Type $Type -Items @()
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    Write-LWInfo ("Removed all {0} item{1} from {2}. Use recover {3} to restore them later." -f $items.Count, $(if ($items.Count -eq 1) { '' } else { 's' }), $label, $Type)
    Invoke-LWMaybeAutosave
}

function Test-LWInventoryRecoveryFits {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        return $false
    }
    if ($Type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        return $false
    }

    $recoveryItems = @(Get-LWInventoryRecoveryItems -Type $Type)
    if ($recoveryItems.Count -eq 0) {
        return $true
    }

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    if ($null -eq $capacity) {
        return $true
    }

    $currentItems = @(Get-LWInventoryItems -Type $Type)
    $currentUsedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $currentItems
    $recoveryUsedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $recoveryItems
    return (($currentUsedCapacity + $recoveryUsedCapacity) -le $capacity)
}

function Restore-LWInventorySection {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack. Recover one before restoring Backpack items.'
        return
    }
    if ($Type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        Write-LWWarn 'You are not currently carrying a Herb Pouch. Recover one before restoring Herb Pouch items.'
        return
    }

    $recoveryItems = @(Get-LWInventoryRecoveryItems -Type $Type)
    $label = Get-LWInventoryTypeLabel -Type $Type
    if ($recoveryItems.Count -eq 0) {
        Write-LWWarn "No saved $label stash is available."
        return
    }

    if (-not (Test-LWInventoryRecoveryFits -Type $Type)) {
        $capacity = Get-LWInventoryTypeCapacity -Type $Type
        Write-LWWarn "$label does not have enough room to recover the saved items. Make space first."
        if ($null -ne $capacity) {
            $currentItems = @(Get-LWInventoryItems -Type $Type)
            $currentUsedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $currentItems
            $recoveryUsedCapacity = Get-LWInventoryUsedCapacity -Type $Type -Items $recoveryItems
            $recoveryUnitLabel = if ($Type -eq 'backpack') { 'slot' } else { 'item' }
            Write-LWSubtle ("  carrying {0}/{1}, recovery stash uses {2} {3}{4}" -f $currentUsedCapacity, $capacity, $recoveryUsedCapacity, $recoveryUnitLabel, $(if ($recoveryUsedCapacity -eq 1) { '' } else { 's' }))
        }
        return
    }

    $currentItems = @(Get-LWInventoryItems -Type $Type)
    Set-LWInventoryItems -Type $Type -Items @($currentItems + $recoveryItems)
    Clear-LWInventoryRecoveryEntry -Type $Type
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    Write-LWInfo ("Recovered {0} saved {1} item{2}." -f $recoveryItems.Count, $label.ToLowerInvariant(), $(if ($recoveryItems.Count -eq 1) { '' } else { 's' }))
    Invoke-LWMaybeAutosave
}

function Restore-LWAllInventorySections {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $recoverableTypes = @('weapon', 'backpack', 'herbpouch', 'special') | Where-Object { @(Get-LWInventoryRecoveryItems -Type $_).Count -gt 0 }
    if (@($recoverableTypes).Count -eq 0) {
        Write-LWWarn 'No saved inventory stash is available.'
        return
    }

    foreach ($type in @($recoverableTypes)) {
        if (-not (Test-LWInventoryRecoveryFits -Type $type)) {
            $label = Get-LWInventoryTypeLabel -Type $type
            Write-LWWarn "Cannot recover all stashed gear because $label does not have enough room."
            return
        }
    }

    foreach ($type in @($recoverableTypes)) {
        $recoveryItems = @(Get-LWInventoryRecoveryItems -Type $type)
        $currentItems = @(Get-LWInventoryItems -Type $type)
        Set-LWInventoryItems -Type $type -Items @($currentItems + $recoveryItems)
        Clear-LWInventoryRecoveryEntry -Type $type
    }

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    Write-LWInfo 'Recovered all saved inventory sections.'
    Invoke-LWMaybeAutosave
}

function Remove-LWInventoryInteractive {
    param([string[]]$InputParts = @())
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $InputParts) {
        $InputParts = @()
    }
    else {
        $InputParts = @($InputParts)
    }

    Set-LWScreen -Name 'inventory'
    $type = $null
    if ($InputParts.Count -gt 1) {
        $type = Resolve-LWInventoryType -Value $InputParts[1]
        if ($null -eq $type) {
            Write-LWWarn 'Type must be weapon, backpack, herbpouch, or special.'
            return
        }
    }

    if ($null -eq $type) {
        $type = Resolve-LWInventoryType -Value (Read-LWText -Prompt 'Item type to remove (weapon/backpack/herbpouch/special)')
        if ($null -eq $type) {
            Write-LWWarn 'Type must be weapon, backpack, herbpouch, or special.'
            return
        }
    }

    $removeLabel = Get-LWInventoryTypeLabel -Type $type

    $removeAll = $false
    $slot = $null
    if ($InputParts.Count -gt 2) {
        if ([string]$InputParts[2] -ieq 'all') {
            $removeAll = $true
        }
        else {
            $slotValue = 0
            if (-not [int]::TryParse($InputParts[2], [ref]$slotValue)) {
                Write-LWWarn 'Slot number must be a whole number, or use all.'
                return
            }
            $slot = $slotValue
        }
    }
    else {
        $selection = Read-LWText -Prompt ("{0} slot to remove (or all)" -f $removeLabel)
        if ([string]$selection -ieq 'all') {
            $removeAll = $true
        }
        else {
            $slotValue = 0
            if (-not [int]::TryParse([string]$selection, [ref]$slotValue)) {
                Write-LWWarn 'Slot number must be a whole number, or use all.'
                return
            }
            $slot = $slotValue
        }
    }

    if ($removeAll) {
        Remove-LWInventorySection -Type $type
        return
    }

    if ($null -eq $slot) {
        Write-LWWarn 'Slot number must be a whole number.'
        return
    }

    Remove-LWInventoryItemBySlot -Type $type -Slot $slot
}

function Restore-LWInventoryInteractive {
    param([string[]]$InputParts = @())
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $InputParts) {
        $InputParts = @()
    }
    else {
        $InputParts = @($InputParts)
    }

    Set-LWScreen -Name 'inventory'
    $selection = $null
    if ($InputParts.Count -gt 1) {
        $selection = [string]$InputParts[1]
    }
    else {
        $selection = Read-LWText -Prompt 'Recover which section? (weapon/backpack/herbpouch/special/all)'
    }

    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-LWWarn 'Type must be weapon, backpack, herbpouch, special, or all.'
        return
    }

    if ($selection.Trim().ToLowerInvariant() -eq 'all') {
        Restore-LWAllInventorySections
        return
    }

    $type = Resolve-LWInventoryType -Value $selection
    if ($null -eq $type) {
        Write-LWWarn 'Type must be weapon, backpack, herbpouch, special, or all.'
        return
    }

    Restore-LWInventorySection -Type $type
}

function Set-LWGold {
    param([int]$NewValue)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $oldValue = [int]$script:GameState.Inventory.GoldCrowns
    if ($NewValue -lt 0) {
        $NewValue = 0
    }
    if ($NewValue -gt 50) {
        Write-LWWarn 'Gold Crowns are capped at 50. Clamping to 50.'
        $NewValue = 50
    }

    $script:GameState.Inventory.GoldCrowns = $NewValue
    Add-LWBookGoldDelta -Delta ($NewValue - $oldValue)
    [void](Sync-LWAchievements -Context 'gold')
    Write-LWInfo "Gold Crowns set to $NewValue."
    Invoke-LWMaybeAutosave
}

Export-ModuleMember -Function Resolve-LWInventoryType, Get-LWInventoryTypeLabel, Get-LWInventoryTypeColor, Get-LWInventoryTypeCapacity, Get-LWLongRopeItemNames, Get-LWBackpackItemSlotSize, Get-LWBackpackOccupiedSlotCount, Get-LWInventoryUsedCapacity, Get-LWBackpackSlotMap, Get-LWInventoryItems, Set-LWInventoryItems, Get-LWPocketSpecialItems, Test-LWStateHasPocketSpecialItem, TryAdd-LWPocketSpecialItemSilently, Remove-LWPocketSpecialItemSilently, Normalize-LWInventoryItemCollection, Move-LWHerbPouchPotionItemsFromBackpack, Grant-LWHerbPouch, TryAdd-LWPreferredPotionStorageSilently, Sync-LWHerbPouchState, Set-LWBackpackState, Lose-LWBackpack, Restore-LWBackpackState, Get-LWConfiscatedInventorySummaryText, Test-LWStateHasConfiscatedEquipment, Save-LWConfiscatedEquipment, Restore-LWConfiscatedEquipment, Move-LWSpecialItemsToSafekeeping, Move-LWSpecialItemsFromSafekeeping, Add-LWWeaponWithOptionalReplace, Get-LWRecoveryStashPropertyName, Get-LWRecoveryStashEntry, Save-LWInventoryRecoveryEntry, Clear-LWInventoryRecoveryEntry, Get-LWInventoryRecoveryItems, Show-LWInventorySlotsSection, Get-LWInventorySlotDisplayText, Show-LWInventorySlotsGridSection, Show-LWInventorySummary, Get-LWInventoryNoteRows, Show-LWInventoryNotesPanel, Show-LWInventory, Show-LWSheet, Add-LWInventoryItem, TryAdd-LWInventoryItemSilently, Remove-LWInventoryItemSilently, Add-LWInventoryInteractive, Remove-LWInventoryItem, Remove-LWInventoryItemBySlot, Remove-LWInventorySection, Test-LWInventoryRecoveryFits, Restore-LWInventorySection, Restore-LWAllInventorySections, Remove-LWInventoryInteractive, Restore-LWInventoryInteractive, Set-LWGold

