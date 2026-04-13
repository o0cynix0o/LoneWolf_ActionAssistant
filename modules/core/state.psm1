Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}

function Resolve-LWCoreInventoryItemName {
    param([string]$Name = '')

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $Name
    }

    if ($CanonicalInventoryItemResolver -is [scriptblock]) {
        return (& $CanonicalInventoryItemResolver -Name $Name)
    }

    if (Get-Command -Name 'Get-LWCanonicalInventoryItemName' -ErrorAction SilentlyContinue) {
        return (Get-LWCanonicalInventoryItemName -Name $Name)
    }

    return $Name.Trim()
}

function Resolve-LWCoreInventoryItemList {
    param(
        [object[]]$Items = @(),
        [string]$Type = ''
    )

    $resolved = @(
        foreach ($item in @($Items)) {
            if ($item -is [string]) {
                Resolve-LWCoreInventoryItemName -Name ([string]$item)
            }
            else {
                $item
            }
        }
    )

    if ($Type -ne 'special') {
        return @($resolved)
    }

    $seen = @{}
    $deduped = @()
    foreach ($item in @($resolved)) {
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

function Invoke-LWCoreInitializeData {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-Path -LiteralPath $DataDir)) {
            New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $SaveDir)) {
            New-Item -ItemType Directory -Path $SaveDir -Force | Out-Null
        }

        $disciplinesPath = Join-Path $DataDir 'kai-disciplines.json'
        $magnakaiDisciplinesPath = Join-Path $DataDir 'magnakai-disciplines.json'
        $magnakaiRanksPath = Join-Path $DataDir 'magnakai-ranks.json'
        $magnakaiLoreCirclesPath = Join-Path $DataDir 'magnakai-lore-circles.json'
        $weaponskillPath = Join-Path $DataDir 'weaponskill-map.json'
        $crtPath = Join-Path $DataDir 'crt.json'

        $script:GameData = [pscustomobject]@{
            KaiDisciplines      = @(Import-LWJson -Path $disciplinesPath -Default @())
            MagnakaiDisciplines = @(Import-LWJson -Path $magnakaiDisciplinesPath -Default @())
            MagnakaiRanks       = @(Import-LWJson -Path $magnakaiRanksPath -Default @())
            MagnakaiLoreCircles = @(Import-LWJson -Path $magnakaiLoreCirclesPath -Default @())
            WeaponskillMap      = (Import-LWJson -Path $weaponskillPath -Default $null)
            CRT                 = (Import-LWJson -Path $crtPath -Default $null)
        }
        if (Get-Command -Name 'Set-LWHostGameData' -ErrorAction SilentlyContinue) { Set-LWHostGameData -Data $script:GameData | Out-Null }

    return $script:GameData
}

function Invoke-LWCoreNewDefaultState {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    return [pscustomobject]@{
            Version           = $script:LWStateVersion
            RuleSet           = 'Kai'
            CurrentSection          = 1
            SectionHadCombat        = $false
            SectionHealingResolved  = $false
            Character         = [pscustomobject]@{
                Name             = ''
                BookNumber       = 1
                CombatSkillBase  = 0
                EnduranceCurrent = 0
                EnduranceMax     = 0
                Disciplines      = @()
                MagnakaiDisciplines = @()
                MagnakaiRank     = $null
                WeaponskillWeapon = $null
                WeaponmasteryWeapons = @()
                LoreCirclesCompleted = @()
                ImprovedDisciplines = @()
                LegacyKaiComplete = $false
                LastCombatWeapon = $null
                CompletedBooks   = @()
                Notes            = @()
            }
            Inventory         = [pscustomobject]@{
                Weapons       = @()
                BackpackItems = @()
                HerbPouchItems = @()
                SpecialItems  = @()
                PocketSpecialItems = @()
                GoldCrowns    = 0
                HasBackpack   = $true
                HasHerbPouch  = $false
                QuiverArrows  = 0
            }
            Combat            = (New-LWCombatState)
            History           = @()
            BookHistory       = @()
            RunHistory        = @()
            RecoveryStash     = (New-LWInventoryRecoveryState)
            Storage           = (New-LWStorageState)
            Conditions        = (New-LWConditionState)
            SectionCheckpoints = @()
            DeathState        = (New-LWDeathState)
            DeathHistory      = @()
            Run              = (New-LWRunState)
            CurrentBookStats  = (New-LWBookStats -BookNumber 1 -StartSection 1)
            Achievements      = (New-LWAchievementState)
            EquipmentBonuses  = [pscustomobject]@{
                ChainmailEndurance = 0
                PaddedLeatherEndurance = 0
                HelmetEndurance = 0
                DaggerOfVashnaEndurance = 0
                LoreCircleCombatSkill = 0
                LoreCircleEndurance = 0
            }
            Settings          = [pscustomobject]@{
                CombatMode = 'ManualCRT'
                SavePath   = $null
                AutoSave   = $false
                DataDir    = $DataDir
            }
        }
}

function Invoke-LWCoreAddBookSectionVisit {
    param(
        [hashtable]$Context,
        [int]$Section
    )

    Set-LWModuleContext -Context $Context

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Section -lt 1) {
        return
    }

    if ($null -eq $stats.StartSection) {
        $stats.StartSection = $Section
    }

    $stats.LastSection = $Section
    $stats.SectionsVisited = [int]$stats.SectionsVisited + 1

    $visited = @($stats.VisitedSections)
    if ($visited -notcontains $Section) {
        $stats.VisitedSections = @($visited + $Section)
    }

    Register-LWStorySectionAchievementTriggers -Section $Section
    if (-not (Test-LWAchievementSyncSuppressed -Context 'section')) {
        [void](Sync-LWAchievements -Context 'section')
    }
}

function Invoke-LWCoreAddBookEnduranceDelta {
    param(
        [hashtable]$Context,
        [int]$Delta
    )

    Set-LWModuleContext -Context $Context

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Delta -eq 0) {
        return
    }

    if ($Delta -lt 0) {
        $stats.EnduranceLost = [int]$stats.EnduranceLost + [Math]::Abs($Delta)
        return
    }

    $stats.EnduranceGained = [int]$stats.EnduranceGained + $Delta
}

function Invoke-LWCoreAddBookGoldDelta {
    param(
        [hashtable]$Context,
        [int]$Delta
    )

    Set-LWModuleContext -Context $Context

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Delta -eq 0) {
        return
    }

    if ($Delta -lt 0) {
        $stats.GoldSpent = [int]$stats.GoldSpent + [Math]::Abs($Delta)
        return
    }

    $stats.GoldGained = [int]$stats.GoldGained + $Delta
}

function Invoke-LWCoreAddBookNamedCount {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Delta = 1
    )

    Set-LWModuleContext -Context $Context

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or [string]::IsNullOrWhiteSpace($PropertyName) -or [string]::IsNullOrWhiteSpace($Name) -or $Delta -eq 0) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $stats -Name $PropertyName) -or $null -eq $stats.$PropertyName) {
        $stats | Add-Member -Force -NotePropertyName $PropertyName -NotePropertyValue @()
    }

    $currentEntries = @(Normalize-LWNamedCountEntries -Entries @($stats.$PropertyName))
    $updatedEntries = @()
    $matched = $false
    foreach ($entry in $currentEntries) {
        if ([string]$entry.Name -ieq $Name) {
            $updatedEntries += [pscustomobject]@{
                Name  = [string]$entry.Name
                Count = [Math]::Max(0, ([int]$entry.Count + $Delta))
            }
            $matched = $true
        }
        else {
            $updatedEntries += $entry
        }
    }

    if (-not $matched -and $Delta -gt 0) {
        $updatedEntries += [pscustomobject]@{
            Name  = $Name
            Count = $Delta
        }
    }

    $stats.$PropertyName = @($updatedEntries | Where-Object { [int]$_.Count -gt 0 })
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
            $entry | Add-Member -NotePropertyName Section -NotePropertyValue ([int]$backfilledSection) -Force
        }
    }
}

function Invoke-LWCoreNormalizeState {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][object]$State
    )

    Set-LWModuleContext -Context $Context

        if (-not (Test-LWPropertyExists -Object $State -Name 'Combat')) {
            $State | Add-Member -NotePropertyName Combat -NotePropertyValue (New-LWCombatState)
        }
        elseif ($null -eq $State.Combat) {
            $State.Combat = (New-LWCombatState)
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'History')) {
            $State | Add-Member -NotePropertyName History -NotePropertyValue @()
        }
        elseif ($null -eq $State.History) {
            $State.History = @()
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'BookHistory')) {
            $State | Add-Member -NotePropertyName BookHistory -NotePropertyValue @()
        }
        elseif ($null -eq $State.BookHistory) {
            $State.BookHistory = @()
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'SectionCheckpoints')) {
            $State | Add-Member -NotePropertyName SectionCheckpoints -NotePropertyValue @()
        }
        elseif ($null -eq $State.SectionCheckpoints) {
            $State.SectionCheckpoints = @()
        }
        else {
            $State.SectionCheckpoints = @(Normalize-LWSectionCheckpoints -Checkpoints @($State.SectionCheckpoints))
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'DeathHistory')) {
            $State | Add-Member -NotePropertyName DeathHistory -NotePropertyValue @()
        }
        elseif ($null -eq $State.DeathHistory) {
            $State.DeathHistory = @()
        }

        Ensure-LWDeathState -State $State
        Ensure-LWAchievementState -State $State
        Ensure-LWRunState -State $State
        Ensure-LWRunHistory -State $State

        if (-not (Test-LWPropertyExists -Object $State -Name 'Storage') -or $null -eq $State.Storage) {
            $State | Add-Member -Force -NotePropertyName Storage -NotePropertyValue (New-LWStorageState)
        }
        if (-not (Test-LWPropertyExists -Object $State.Storage -Name 'SafekeepingSpecialItems') -or $null -eq $State.Storage.SafekeepingSpecialItems) {
            $State.Storage | Add-Member -Force -NotePropertyName SafekeepingSpecialItems -NotePropertyValue @()
        }
        else {
            $State.Storage.SafekeepingSpecialItems = @(Resolve-LWCoreInventoryItemList -Items @($State.Storage.SafekeepingSpecialItems) -Type 'special')
        }
        if (-not (Test-LWPropertyExists -Object $State.Storage -Name 'Confiscated') -or $null -eq $State.Storage.Confiscated) {
            $State.Storage | Add-Member -Force -NotePropertyName Confiscated -NotePropertyValue (New-LWStorageState).Confiscated
        }
        foreach ($entryName in @('Weapons', 'BackpackItems', 'HerbPouchItems', 'SpecialItems', 'PocketSpecialItems')) {
            if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name $entryName) -or $null -eq $State.Storage.Confiscated.$entryName) {
                $State.Storage.Confiscated | Add-Member -Force -NotePropertyName $entryName -NotePropertyValue @()
            }
            else {
                $normalizedType = switch ($entryName) {
                    'SpecialItems' { 'special' }
                    'PocketSpecialItems' { 'special' }
                    'Weapons' { 'weapon' }
                    'HerbPouchItems' { 'herbpouch' }
                    default { 'backpack' }
                }
                $State.Storage.Confiscated.$entryName = @(Resolve-LWCoreInventoryItemList -Items @($State.Storage.Confiscated.$entryName) -Type $normalizedType)
            }
        }
        foreach ($propertyName in @('GoldCrowns', 'BookNumber', 'Section', 'SavedOn', 'HasHerbPouch')) {
            if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name $propertyName)) {
                $State.Storage.Confiscated | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $(if ($propertyName -eq 'HasHerbPouch') { $false } else { $null })
            }
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'Conditions') -or $null -eq $State.Conditions) {
            $State | Add-Member -Force -NotePropertyName Conditions -NotePropertyValue (New-LWConditionState)
        }
        foreach ($propertyName in @('BookFiveBloodPoisoning', 'BookFiveLimbdeath')) {
            if (-not (Test-LWPropertyExists -Object $State.Conditions -Name $propertyName) -or $null -eq $State.Conditions.$propertyName) {
                $State.Conditions | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $false
            }
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'RecoveryStash') -or $null -eq $State.RecoveryStash) {
            $State | Add-Member -Force -NotePropertyName RecoveryStash -NotePropertyValue (New-LWInventoryRecoveryState)
        }

        foreach ($entryName in @('Weapon', 'Backpack', 'HerbPouch', 'Special')) {
            if (-not (Test-LWPropertyExists -Object $State.RecoveryStash -Name $entryName) -or $null -eq $State.RecoveryStash.$entryName) {
                $State.RecoveryStash | Add-Member -Force -NotePropertyName $entryName -NotePropertyValue (New-LWInventoryRecoveryEntry)
            }
            elseif (-not (Test-LWPropertyExists -Object $State.RecoveryStash.$entryName -Name 'Items') -or $null -eq $State.RecoveryStash.$entryName.Items) {
                $State.RecoveryStash.$entryName | Add-Member -Force -NotePropertyName Items -NotePropertyValue @()
            }
            else {
                $normalizedType = switch ($entryName) {
                    'Special' { 'special' }
                    'Weapon' { 'weapon' }
                    'HerbPouch' { 'herbpouch' }
                    default { 'backpack' }
                }
                $State.RecoveryStash.$entryName.Items = @(Resolve-LWCoreInventoryItemList -Items @($State.RecoveryStash.$entryName.Items) -Type $normalizedType)
            }

            foreach ($propertyName in @('BookNumber', 'Section', 'SavedOn')) {
                if (-not (Test-LWPropertyExists -Object $State.RecoveryStash.$entryName -Name $propertyName)) {
                    $State.RecoveryStash.$entryName | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $null
                }
            }
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'SectionHealingResolved')) {
            $State | Add-Member -NotePropertyName SectionHealingResolved -NotePropertyValue $false
        }
        elseif ($null -eq $State.SectionHealingResolved) {
            $State.SectionHealingResolved = $false
        }

        if (-not (Test-LWPropertyExists -Object $State -Name 'Settings')) {
            $State | Add-Member -NotePropertyName Settings -NotePropertyValue ([pscustomobject]@{ CombatMode = 'ManualCRT'; SavePath = $null; AutoSave = $false; DataDir = $DataDir })
        }
        elseif ($null -eq $State.Settings) {
            $State.Settings = [pscustomobject]@{ CombatMode = 'ManualCRT'; SavePath = $null; AutoSave = $false; DataDir = $DataDir }
        }

        if (-not (Test-LWPropertyExists -Object $State.Settings -Name 'CombatMode')) {
            $State.Settings | Add-Member -NotePropertyName CombatMode -NotePropertyValue 'ManualCRT'
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$State.Settings.CombatMode)) {
            $State.Settings.CombatMode = 'ManualCRT'
        }

        if (-not (Test-LWPropertyExists -Object $State.Settings -Name 'SavePath')) {
            $State.Settings | Add-Member -NotePropertyName SavePath -NotePropertyValue $null
        }
        else {
            $State.Settings.SavePath = [string]$State.Settings.SavePath
        }

        if (-not (Test-LWPropertyExists -Object $State.Settings -Name 'AutoSave')) {
            $State.Settings | Add-Member -NotePropertyName AutoSave -NotePropertyValue $false
        }
        elseif ($null -eq $State.Settings.AutoSave) {
            $State.Settings.AutoSave = $false
        }

        if (-not (Test-LWPropertyExists -Object $State.Settings -Name 'DataDir')) {
            $State.Settings | Add-Member -NotePropertyName DataDir -NotePropertyValue $DataDir
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$State.Settings.DataDir)) {
            $State.Settings.DataDir = $DataDir
        }

        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'Disciplines') -or $null -eq $State.Character.Disciplines) {
            $State.Character.Disciplines = @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiDisciplines') -or $null -eq $State.Character.MagnakaiDisciplines) {
            $State.Character | Add-Member -Force -NotePropertyName MagnakaiDisciplines -NotePropertyValue @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiRank')) {
            $State.Character | Add-Member -Force -NotePropertyName MagnakaiRank -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'WeaponmasteryWeapons') -or $null -eq $State.Character.WeaponmasteryWeapons) {
            $State.Character | Add-Member -Force -NotePropertyName WeaponmasteryWeapons -NotePropertyValue @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'LoreCirclesCompleted') -or $null -eq $State.Character.LoreCirclesCompleted) {
            $State.Character | Add-Member -Force -NotePropertyName LoreCirclesCompleted -NotePropertyValue @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'ImprovedDisciplines') -or $null -eq $State.Character.ImprovedDisciplines) {
            $State.Character | Add-Member -Force -NotePropertyName ImprovedDisciplines -NotePropertyValue @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'LegacyKaiComplete') -or $null -eq $State.Character.LegacyKaiComplete) {
            $State.Character | Add-Member -Force -NotePropertyName LegacyKaiComplete -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'LastCombatWeapon')) {
            $State.Character | Add-Member -NotePropertyName LastCombatWeapon -NotePropertyValue $null
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$State.Character.LastCombatWeapon)) {
            $State.Character.LastCombatWeapon = $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'CompletedBooks') -or $null -eq $State.Character.CompletedBooks) {
            $State.Character.CompletedBooks = @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Character -Name 'Notes') -or $null -eq $State.Character.Notes) {
            $State.Character.Notes = @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'Weapons') -or $null -eq $State.Inventory.Weapons) {
            $State.Inventory.Weapons = @()
        }
        else {
            $State.Inventory.Weapons = @(Resolve-LWCoreInventoryItemList -Items @($State.Inventory.Weapons) -Type 'weapon')
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'BackpackItems') -or $null -eq $State.Inventory.BackpackItems) {
            $State.Inventory.BackpackItems = @()
        }
        else {
            $State.Inventory.BackpackItems = @(Resolve-LWCoreInventoryItemList -Items @($State.Inventory.BackpackItems) -Type 'backpack')
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HerbPouchItems') -or $null -eq $State.Inventory.HerbPouchItems) {
            $State.Inventory | Add-Member -Force -NotePropertyName HerbPouchItems -NotePropertyValue @()
        }
        else {
            $State.Inventory.HerbPouchItems = @(Resolve-LWCoreInventoryItemList -Items @($State.Inventory.HerbPouchItems) -Type 'herbpouch')
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasBackpack') -or $null -eq $State.Inventory.HasBackpack) {
            $State.Inventory | Add-Member -Force -NotePropertyName HasBackpack -NotePropertyValue $true
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasHerbPouch') -or $null -eq $State.Inventory.HasHerbPouch) {
            $State.Inventory | Add-Member -Force -NotePropertyName HasHerbPouch -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'QuiverArrows') -or $null -eq $State.Inventory.QuiverArrows) {
            $State.Inventory | Add-Member -Force -NotePropertyName QuiverArrows -NotePropertyValue 0
        }
        else {
            $State.Inventory.QuiverArrows = [Math]::Max(0, [Math]::Min([int]$State.Inventory.QuiverArrows, 6))
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'SpecialItems') -or $null -eq $State.Inventory.SpecialItems) {
            $State.Inventory.SpecialItems = @()
        }
        else {
            $State.Inventory.SpecialItems = @(Resolve-LWCoreInventoryItemList -Items @($State.Inventory.SpecialItems) -Type 'special')
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'PocketSpecialItems') -or $null -eq $State.Inventory.PocketSpecialItems) {
            $State.Inventory | Add-Member -Force -NotePropertyName PocketSpecialItems -NotePropertyValue @()
        }
        else {
            $State.Inventory.PocketSpecialItems = @(Resolve-LWCoreInventoryItemList -Items @($State.Inventory.PocketSpecialItems) -Type 'special')
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'Log') -or $null -eq $State.Combat.Log) {
            $State.Combat.Log = @()
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyIsUndead') -or $null -eq $State.Combat.EnemyIsUndead) {
            $State.Combat | Add-Member -Force -NotePropertyName EnemyIsUndead -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyUsesMindforce') -or $null -eq $State.Combat.EnemyUsesMindforce) {
            $State.Combat | Add-Member -Force -NotePropertyName EnemyUsesMindforce -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'MindforceLossPerRound') -or $null -eq $State.Combat.MindforceLossPerRound) {
            $State.Combat | Add-Member -Force -NotePropertyName MindforceLossPerRound -NotePropertyValue 2
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyRequiresMagicSpear') -or $null -eq $State.Combat.EnemyRequiresMagicSpear) {
            $State.Combat | Add-Member -Force -NotePropertyName EnemyRequiresMagicSpear -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyRequiresMagicalWeapon') -or $null -eq $State.Combat.EnemyRequiresMagicalWeapon) {
            $State.Combat | Add-Member -Force -NotePropertyName EnemyRequiresMagicalWeapon -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'AletherCombatSkillBonus') -or $null -eq $State.Combat.AletherCombatSkillBonus) {
            $State.Combat | Add-Member -Force -NotePropertyName AletherCombatSkillBonus -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'MindblastCombatSkillBonus') -or $null -eq $State.Combat.MindblastCombatSkillBonus) {
            $State.Combat | Add-Member -Force -NotePropertyName MindblastCombatSkillBonus -NotePropertyValue 2
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PsychicAttackMode') -or [string]::IsNullOrWhiteSpace([string]$State.Combat.PsychicAttackMode)) {
            $State.Combat | Add-Member -Force -NotePropertyName PsychicAttackMode -NotePropertyValue 'Mindblast'
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'AttemptKnockout') -or $null -eq $State.Combat.AttemptKnockout) {
            $State.Combat | Add-Member -Force -NotePropertyName AttemptKnockout -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EvadeAvailableAfterRound') -or $null -eq $State.Combat.EvadeAvailableAfterRound) {
            $State.Combat | Add-Member -Force -NotePropertyName EvadeAvailableAfterRound -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EvadeExpiresAfterRound') -or $null -eq $State.Combat.EvadeExpiresAfterRound) {
            $State.Combat | Add-Member -Force -NotePropertyName EvadeExpiresAfterRound -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EvadeResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName EvadeResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EvadeResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName EvadeResolutionNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'DeferredEquippedWeapon')) {
            $State.Combat | Add-Member -Force -NotePropertyName DeferredEquippedWeapon -NotePropertyValue $null
        }
        elseif ([string]::IsNullOrWhiteSpace([string]$State.Combat.DeferredEquippedWeapon)) {
            $State.Combat.DeferredEquippedWeapon = $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EquipDeferredWeaponAfterRound') -or $null -eq $State.Combat.EquipDeferredWeaponAfterRound) {
            $State.Combat | Add-Member -Force -NotePropertyName EquipDeferredWeaponAfterRound -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SommerswerdSuppressed') -or $null -eq $State.Combat.SommerswerdSuppressed) {
            $State.Combat | Add-Member -Force -NotePropertyName SommerswerdSuppressed -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'OneRoundOnly') -or $null -eq $State.Combat.OneRoundOnly) {
            $State.Combat | Add-Member -Force -NotePropertyName OneRoundOnly -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SpecialResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName SpecialResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SpecialResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName SpecialResolutionNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryResolutionNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryWithoutLossSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryWithoutLossSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryWithoutLossNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryWithoutLossNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryWithinRoundsSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryWithinRoundsSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryWithinRoundsMax')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryWithinRoundsMax -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'VictoryWithinRoundsNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName VictoryWithinRoundsNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'OngoingFailureAfterRoundsSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName OngoingFailureAfterRoundsSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'OngoingFailureAfterRoundsThreshold')) {
            $State.Combat | Add-Member -Force -NotePropertyName OngoingFailureAfterRoundsThreshold -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'OngoingFailureAfterRoundsNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName OngoingFailureAfterRoundsNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerLossResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerLossResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerLossResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerLossResolutionNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'DefeatResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName DefeatResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'DefeatResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName DefeatResolutionNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'JavekPoisonRule') -or $null -eq $State.Combat.JavekPoisonRule) {
            $State.Combat | Add-Member -Force -NotePropertyName JavekPoisonRule -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'IgnorePlayerEnduranceLossRounds') -or $null -eq $State.Combat.IgnorePlayerEnduranceLossRounds) {
            $roundValue = if ((Test-LWPropertyExists -Object $State.Combat -Name 'IgnoreFirstRoundEnduranceLoss') -and [bool]$State.Combat.IgnoreFirstRoundEnduranceLoss) { 1 } else { 0 }
            $State.Combat | Add-Member -Force -NotePropertyName IgnorePlayerEnduranceLossRounds -NotePropertyValue $roundValue
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'IgnoreEnemyEnduranceLossRounds') -or $null -eq $State.Combat.IgnoreEnemyEnduranceLossRounds) {
            $State.Combat | Add-Member -Force -NotePropertyName IgnoreEnemyEnduranceLossRounds -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'DoubleEnemyEnduranceLoss') -or $null -eq $State.Combat.DoubleEnemyEnduranceLoss) {
            $State.Combat | Add-Member -Force -NotePropertyName DoubleEnemyEnduranceLoss -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollValue')) {
            $State.Combat | Add-Member -Force -NotePropertyName FallOnRollValue -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName FallOnRollResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName FallOnRollResolutionNote -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'RestoreHalfEnduranceLossOnVictory') -or $null -eq $State.Combat.RestoreHalfEnduranceLossOnVictory) {
            $State.Combat | Add-Member -Force -NotePropertyName RestoreHalfEnduranceLossOnVictory -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'RestoreHalfEnduranceLossOnEvade') -or $null -eq $State.Combat.RestoreHalfEnduranceLossOnEvade) {
            $State.Combat | Add-Member -Force -NotePropertyName RestoreHalfEnduranceLossOnEvade -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'UsePlayerTargetEndurance') -or $null -eq $State.Combat.UsePlayerTargetEndurance) {
            $State.Combat | Add-Member -Force -NotePropertyName UsePlayerTargetEndurance -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerTargetEnduranceCurrent') -or $null -eq $State.Combat.PlayerTargetEnduranceCurrent) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerTargetEnduranceCurrent -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerTargetEnduranceMax') -or $null -eq $State.Combat.PlayerTargetEnduranceMax) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerTargetEnduranceMax -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SuppressShieldCombatSkillBonus') -or $null -eq $State.Combat.SuppressShieldCombatSkillBonus) {
            $State.Combat | Add-Member -Force -NotePropertyName SuppressShieldCombatSkillBonus -NotePropertyValue $false
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifier')) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerCombatSkillModifier -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierRounds') -or $null -eq $State.Combat.PlayerCombatSkillModifierRounds) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerCombatSkillModifierRounds -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRounds') -or $null -eq $State.Combat.PlayerCombatSkillModifierAfterRounds) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerCombatSkillModifierAfterRounds -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRoundStart')) {
            $State.Combat | Add-Member -Force -NotePropertyName PlayerCombatSkillModifierAfterRoundStart -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyCombatSkillModifier')) {
            $State.Combat | Add-Member -Force -NotePropertyName EnemyCombatSkillModifier -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossAmount') -or $null -eq $State.Combat.SpecialPlayerEnduranceLossAmount) {
            $State.Combat | Add-Member -Force -NotePropertyName SpecialPlayerEnduranceLossAmount -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -or $null -eq $State.Combat.SpecialPlayerEnduranceLossStartRound) {
            $State.Combat | Add-Member -Force -NotePropertyName SpecialPlayerEnduranceLossStartRound -NotePropertyValue 1
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossReason')) {
            $State.Combat | Add-Member -Force -NotePropertyName SpecialPlayerEnduranceLossReason -NotePropertyValue $null
        }

        $currentBookNumber = 1
        if ((Test-LWPropertyExists -Object $State.Character -Name 'BookNumber') -and $null -ne $State.Character.BookNumber) {
            $currentBookNumber = [int]$State.Character.BookNumber
        }

        $currentSection = $null
        if ((Test-LWPropertyExists -Object $State -Name 'CurrentSection') -and $null -ne $State.CurrentSection) {
            $currentSection = [int]$State.CurrentSection
        }

        $partialTracking = $false
        if (-not (Test-LWPropertyExists -Object $State -Name 'CurrentBookStats')) {
            $partialTracking = $true
            $State | Add-Member -NotePropertyName CurrentBookStats -NotePropertyValue (New-LWBookStats -BookNumber $currentBookNumber -StartSection $currentSection -PartialTracking $partialTracking)
        }
        elseif ($null -eq $State.CurrentBookStats) {
            $partialTracking = $true
            $State.CurrentBookStats = (New-LWBookStats -BookNumber $currentBookNumber -StartSection $currentSection -PartialTracking $partialTracking)
        }
        else {
            $State.CurrentBookStats = Normalize-LWBookStats -Stats $State.CurrentBookStats -BookNumber $currentBookNumber -CurrentSection $currentSection
        }

        Normalize-LWCombatHistoryMetadata -State $State
        Normalize-LWCombatHistorySections -State $State
        Ensure-LWEquipmentBonusState -State $State
        Sync-LWStateEquipmentBonuses -State $State
        Sync-LWRunIntegrityState -State $State

        if (@($State.SectionCheckpoints).Count -eq 0 -and $null -ne $currentSection -and [int]$currentSection -ge 1 -and -not [bool]$State.DeathState.Active) {
            $seedCheckpoint = New-LWSectionCheckpoint -State $State
            if ($null -ne $seedCheckpoint) {
                $State.SectionCheckpoints = @($seedCheckpoint)
            }
        }

    return $State
}

Export-ModuleMember -Function `
    Invoke-LWCoreInitializeData, `
    Invoke-LWCoreNewDefaultState, `
    Invoke-LWCoreAddBookSectionVisit, `
    Invoke-LWCoreAddBookEnduranceDelta, `
    Invoke-LWCoreAddBookGoldDelta, `
    Invoke-LWCoreAddBookNamedCount, `
    Invoke-LWCoreNormalizeState

function New-LWRunState {
    param(
        [string]$Difficulty = 'Normal',
        [bool]$Permadeath = $false
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $normalizedDifficulty = Get-LWNormalizedDifficultyName -Difficulty $Difficulty
    if ($normalizedDifficulty -eq 'Story') {
        $Permadeath = $false
    }

    return [pscustomobject]@{
        Id             = ([guid]::NewGuid().ToString())
        Difficulty     = $normalizedDifficulty
        Permadeath     = [bool]$Permadeath
        Status         = 'Active'
        StartedOn      = (Get-Date).ToString('o')
        CompletedOn    = $null
        IntegrityState = 'Clean'
        IntegrityNote  = $null
        Signature      = $null
    }
}

function New-LWRunArchiveEntry {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Status = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $run = if ((Test-LWPropertyExists -Object $State -Name 'Run') -and $null -ne $State.Run) { $State.Run } else { $null }
    $campaign = $null
    $previousState = $script:GameState
    try {
        $script:GameState = $State
        if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
        $campaign = Get-LWCampaignSummary
    }
    finally {
        $script:GameState = $previousState
        if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
    }

    return [pscustomobject]@{
        RunId          = $(if ($null -ne $run) { [string]$run.Id } else { ([guid]::NewGuid().ToString()) })
        CharacterName  = [string]$State.Character.Name
        Difficulty     = $(if ($null -ne $run) { [string]$run.Difficulty } else { 'Normal' })
        Permadeath     = $(if ($null -ne $run) { [bool]$run.Permadeath } else { $false })
        IntegrityState = $(if ($null -ne $run) { [string]$run.IntegrityState } else { 'Clean' })
        Status         = $(if ([string]::IsNullOrWhiteSpace($Status)) { if ($null -ne $run) { [string]$run.Status } else { 'Archived' } } else { $Status })
        StartedOn      = $(if ($null -ne $run) { [string]$run.StartedOn } else { $null })
        EndedOn        = (Get-Date).ToString('o')
        LastBook       = [int]$State.Character.BookNumber
        CompletedBooks = @($State.Character.CompletedBooks)
        Summary        = $campaign
    }
}

function Ensure-LWRunState {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWPropertyExists -Object $State -Name 'Run') -or $null -eq $State.Run) {
        $State | Add-Member -Force -NotePropertyName Run -NotePropertyValue (New-LWRunState)
        return
    }

    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'Id') -or [string]::IsNullOrWhiteSpace([string]$State.Run.Id)) {
        $State.Run | Add-Member -Force -NotePropertyName Id -NotePropertyValue ([guid]::NewGuid().ToString())
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'Difficulty')) {
        $State.Run | Add-Member -Force -NotePropertyName Difficulty -NotePropertyValue 'Normal'
    }
    else {
        $State.Run.Difficulty = Get-LWNormalizedDifficultyName -Difficulty ([string]$State.Run.Difficulty)
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'Permadeath') -or $null -eq $State.Run.Permadeath) {
        $State.Run | Add-Member -Force -NotePropertyName Permadeath -NotePropertyValue $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'Status') -or [string]::IsNullOrWhiteSpace([string]$State.Run.Status)) {
        $State.Run | Add-Member -Force -NotePropertyName Status -NotePropertyValue 'Active'
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'StartedOn') -or [string]::IsNullOrWhiteSpace([string]$State.Run.StartedOn)) {
        $State.Run | Add-Member -Force -NotePropertyName StartedOn -NotePropertyValue (Get-Date).ToString('o')
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'CompletedOn')) {
        $State.Run | Add-Member -Force -NotePropertyName CompletedOn -NotePropertyValue $null
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'IntegrityState') -or [string]::IsNullOrWhiteSpace([string]$State.Run.IntegrityState)) {
        $State.Run | Add-Member -Force -NotePropertyName IntegrityState -NotePropertyValue 'Clean'
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'IntegrityNote')) {
        $State.Run | Add-Member -Force -NotePropertyName IntegrityNote -NotePropertyValue $null
    }
    if (-not (Test-LWPropertyExists -Object $State.Run -Name 'Signature')) {
        $State.Run | Add-Member -Force -NotePropertyName Signature -NotePropertyValue $null
    }
}

function Ensure-LWRunHistory {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWPropertyExists -Object $State -Name 'RunHistory') -or $null -eq $State.RunHistory) {
        $State | Add-Member -Force -NotePropertyName RunHistory -NotePropertyValue @()
        return
    }

    $State.RunHistory = @($State.RunHistory)
}

function Get-LWRunSignaturePayload {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Ensure-LWRunState -State $State

    $completedBooks = @()
    if ($null -ne $State.Character -and (Test-LWPropertyExists -Object $State.Character -Name 'CompletedBooks') -and $null -ne $State.Character.CompletedBooks) {
        $completedBooks = @($State.Character.CompletedBooks | ForEach-Object { [int]$_ } | Sort-Object)
    }

    return @(
        [string]$State.Run.Id,
        [string]$State.Run.Difficulty,
        [string]([bool]$State.Run.Permadeath),
        [string]$State.Run.Status,
        (Get-LWCanonicalDateText -Value $State.Run.StartedOn),
        [string]([int]$State.Character.BookNumber),
        [string]([int]$State.CurrentSection),
        ($completedBooks -join ',')
    ) -join '|'
}

function Get-LWRunSignature {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Get-LWStringHash -Text (Get-LWRunSignaturePayload -State $State))
}

function Mark-LWRunTampered {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Reason = 'Run settings were modified outside the assistant.'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Ensure-LWRunState -State $State
    $State.Run.IntegrityState = 'Tampered'
    $State.Run.IntegrityNote = $Reason
}

function Sync-LWRunIntegrityState {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$Reseal
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Ensure-LWRunState -State $State

    if ([string]$State.Run.Difficulty -eq 'Story' -and [bool]$State.Run.Permadeath) {
        $State.Run.Permadeath = $false
        Mark-LWRunTampered -State $State -Reason 'Story mode cannot be combined with Permadeath.'
    }

    $computed = Get-LWRunSignature -State $State
    $stored = [string]$State.Run.Signature

    if ($Reseal) {
        if ([string]$State.Run.IntegrityState -ne 'Tampered') {
            $State.Run.IntegrityState = 'Clean'
            $State.Run.IntegrityNote = $null
        }
        $State.Run.Signature = $computed
        return
    }

    if ([string]::IsNullOrWhiteSpace($stored)) {
        $State.Run.Signature = $computed
        if ([string]$State.Run.IntegrityState -ne 'Tampered') {
            $State.Run.IntegrityState = 'Clean'
            $State.Run.IntegrityNote = $null
        }
        return
    }

    if ($stored -ne $computed) {
        Mark-LWRunTampered -State $State -Reason 'Locked run settings or signed progress fields were edited outside the assistant.'
        $State.Run.Signature = $computed
        return
    }

    $State.Run.IntegrityState = 'Clean'
    $State.Run.IntegrityNote = $null
    $State.Run.Signature = $computed
}

function Get-LWCurrentDifficulty {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return 'Normal'
    }

    if ((Test-LWPropertyExists -Object $State -Name 'Run') -and $null -ne $State.Run -and (Test-LWPropertyExists -Object $State.Run -Name 'Difficulty')) {
        return (Get-LWNormalizedDifficultyName -Difficulty ([string]$State.Run.Difficulty))
    }

    return 'Normal'
}

function Test-LWPermadeathEnabled {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return $false
    }

    if ((Get-LWCurrentDifficulty -State $State) -eq 'Story') {
        return $false
    }

    return ((Test-LWPropertyExists -Object $State -Name 'Run') -and $null -ne $State.Run -and (Test-LWPropertyExists -Object $State.Run -Name 'Permadeath') -and [bool]$State.Run.Permadeath)
}

function Test-LWRunTampered {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State) {
        return $false
    }

    return ((Test-LWPropertyExists -Object $State -Name 'Run') -and $null -ne $State.Run -and (Test-LWPropertyExists -Object $State.Run -Name 'IntegrityState') -and [string]$State.Run.IntegrityState -eq 'Tampered')
}

function Test-LWDifficultyAllowsChallengeAchievements {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State))
}

function New-LWDeathState {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return [pscustomobject]@{
        Active     = $false
        Type       = $null
        Cause      = $null
        BookNumber = $null
        BookTitle  = $null
        Section    = $null
        RecordedOn = $null
    }
}

function Ensure-LWDeathState {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWPropertyExists -Object $State -Name 'DeathState') -or $null -eq $State.DeathState) {
        $State | Add-Member -Force -NotePropertyName DeathState -NotePropertyValue (New-LWDeathState)
        return
    }

    foreach ($propertyName in @('Active', 'Type', 'Cause', 'BookNumber', 'BookTitle', 'Section', 'RecordedOn')) {
        if (-not (Test-LWPropertyExists -Object $State.DeathState -Name $propertyName)) {
            $State.DeathState | Add-Member -NotePropertyName $propertyName -NotePropertyValue $null
        }
    }

    if ($null -eq $State.DeathState.Active) {
        $State.DeathState.Active = $false
    }
}

function Get-LWActiveDeathState {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ($null -eq $script:GameState) {
        return $null
    }
    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'DeathState') -or $null -eq $script:GameState.DeathState) {
        return $null
    }
    if (-not (Test-LWPropertyExists -Object $script:GameState.DeathState -Name 'Active') -or -not [bool]$script:GameState.DeathState.Active) {
        return $null
    }

    return $script:GameState.DeathState
}

function Test-LWDeathActive {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return ($null -ne (Get-LWActiveDeathState))
}

function Clear-LWDeathState {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ($null -eq $script:GameState) {
        return
    }

    $script:GameState.DeathState = (New-LWDeathState)
}

function Normalize-LWSectionCheckpoints {
    param([object[]]$Checkpoints = @())
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $normalized = @()
    foreach ($checkpoint in @($Checkpoints)) {
        if ($null -eq $checkpoint) {
            continue
        }

        $snapshot = if ((Test-LWPropertyExists -Object $checkpoint -Name 'Snapshot') -and -not [string]::IsNullOrWhiteSpace([string]$checkpoint.Snapshot)) { [string]$checkpoint.Snapshot } else { $null }
        $section = if ((Test-LWPropertyExists -Object $checkpoint -Name 'Section') -and $null -ne $checkpoint.Section) { [int]$checkpoint.Section } else { 0 }
        if ([string]::IsNullOrWhiteSpace($snapshot) -or $section -lt 1) {
            continue
        }

        $bookNumber = if ((Test-LWPropertyExists -Object $checkpoint -Name 'BookNumber') -and $null -ne $checkpoint.BookNumber) { [int]$checkpoint.BookNumber } else { $null }
        $bookTitle = if ((Test-LWPropertyExists -Object $checkpoint -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$checkpoint.BookTitle)) { [string]$checkpoint.BookTitle } else { '' }
        if (($null -eq $bookNumber -or $bookNumber -le 0) -and -not [string]::IsNullOrWhiteSpace($bookTitle)) {
            $bookNumber = Get-LWBookNumberFromTitle -Title $bookTitle
        }
        if ([string]::IsNullOrWhiteSpace($bookTitle) -and $null -ne $bookNumber -and [int]$bookNumber -gt 0) {
            $bookTitle = Get-LWBookTitle -BookNumber ([int]$bookNumber)
        }

        $normalized += [pscustomobject]@{
            BookNumber = $bookNumber
            BookTitle  = $bookTitle
            Section    = $section
            Snapshot   = $snapshot
        }
    }

    return @($normalized)
}

function Get-LWCheckpointSnapshotObject {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    # Rewind restores the current tactical state, then preserves the live run history,
    # book history, book stats, achievements, and notes from the active state.
    return [pscustomobject]@{
        Version                = $State.Version
        RuleSet                = $State.RuleSet
        CurrentSection         = $State.CurrentSection
        SectionHadCombat       = $State.SectionHadCombat
        SectionHealingResolved = $State.SectionHealingResolved
        Character              = $State.Character
        Inventory              = $State.Inventory
        Combat                 = $State.Combat
        EquipmentBonuses       = $State.EquipmentBonuses
    }
}

function Get-LWCheckpointSnapshotJson {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ((Get-LWCheckpointSnapshotObject -State $State) | ConvertTo-Json -Depth 20 -Compress)
}

function New-LWSectionCheckpoint {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $State.Character -or $null -eq $State.CurrentSection -or [int]$State.CurrentSection -lt 1) {
        return $null
    }

    $bookNumber = if ($null -ne $State.Character.BookNumber) { [int]$State.Character.BookNumber } else { $null }
    return [pscustomobject]@{
        BookNumber = $bookNumber
        BookTitle  = if ($null -ne $bookNumber -and $bookNumber -gt 0) { Get-LWBookTitle -BookNumber $bookNumber } else { $null }
        Section    = [int]$State.CurrentSection
        Snapshot   = Get-LWCheckpointSnapshotJson -State $State
    }
}

function Reset-LWSectionCheckpoints {
    param([switch]$SeedCurrentSection)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $script:GameState) {
        return
    }

    $script:GameState.SectionCheckpoints = @()
    if (-not $SeedCurrentSection -or -not (Test-LWHasState) -or [int]$script:GameState.CurrentSection -lt 1) {
        return
    }

    $checkpoint = New-LWSectionCheckpoint -State $script:GameState
    if ($null -ne $checkpoint) {
        $script:GameState.SectionCheckpoints = @($checkpoint)
    }
}

function Ensure-LWCurrentSectionCheckpoint {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState) -or (Test-LWDeathActive)) {
        return
    }

    if (@($script:GameState.SectionCheckpoints).Count -eq 0) {
        Reset-LWSectionCheckpoints -SeedCurrentSection
    }
}

function Save-LWCurrentSectionCheckpoint {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState) -or [int]$script:GameState.CurrentSection -lt 1) {
        return
    }

    $checkpoint = New-LWSectionCheckpoint -State $script:GameState
    if ($null -eq $checkpoint) {
        return
    }

    $checkpoints = @($script:GameState.SectionCheckpoints)
    if ($checkpoints.Count -gt 0) {
        $last = $checkpoints[-1]
        $sameBook = ((Test-LWPropertyExists -Object $last -Name 'BookNumber') -and $null -ne $last.BookNumber -and [int]$last.BookNumber -eq [int]$checkpoint.BookNumber)
        $sameSection = ((Test-LWPropertyExists -Object $last -Name 'Section') -and $null -ne $last.Section -and [int]$last.Section -eq [int]$checkpoint.Section)
        if ($sameBook -and $sameSection) {
            $checkpoints[$checkpoints.Count - 1] = $checkpoint
        }
        else {
            $checkpoints = @($checkpoints) + @($checkpoint)
        }
    }
    else {
        $checkpoints = @($checkpoint)
    }

    $script:GameState.SectionCheckpoints = @($checkpoints)
}

function Sync-LWCurrentSectionCheckpoint {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState) -or (Test-LWDeathActive)) {
        return
    }

    Ensure-LWCurrentSectionCheckpoint
    Save-LWCurrentSectionCheckpoint
}

function Get-LWBookDeathCount {
    param([int]$BookNumber)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or $BookNumber -lt 1 -or -not (Test-LWPropertyExists -Object $script:GameState -Name 'DeathHistory') -or $null -eq $script:GameState.DeathHistory) {
        return 0
    }

    $count = 0
    foreach ($entry in @($script:GameState.DeathHistory)) {
        if ($null -ne $entry -and (Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and $null -ne $entry.BookNumber -and [int]$entry.BookNumber -eq $BookNumber) {
            $count++
        }
    }

    return $count
}

function Register-LWDeath {
    param(
        [string]$Type = 'Instant',
        [string]$Cause = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return $null
    }

    Ensure-LWDeathState -State $script:GameState
    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'DeathHistory') -or $null -eq $script:GameState.DeathHistory) {
        $script:GameState.DeathHistory = @()
    }

    $bookNumber = [int]$script:GameState.Character.BookNumber
    $entry = [pscustomobject]@{
        Type       = if ([string]::IsNullOrWhiteSpace($Type)) { 'Instant' } else { $Type }
        Cause      = if ([string]::IsNullOrWhiteSpace($Cause)) { 'A fatal choice ended this path.' } else { $Cause.Trim() }
        BookNumber = $bookNumber
        BookTitle  = Get-LWBookTitle -BookNumber $bookNumber
        Section    = [int]$script:GameState.CurrentSection
        RecordedOn = (Get-Date).ToString('o')
    }

    $script:GameState.DeathState.Active = $true
    $script:GameState.DeathState.Type = $entry.Type
    $script:GameState.DeathState.Cause = $entry.Cause
    $script:GameState.DeathState.BookNumber = $entry.BookNumber
    $script:GameState.DeathState.BookTitle = $entry.BookTitle
    $script:GameState.DeathState.Section = $entry.Section
    $script:GameState.DeathState.RecordedOn = $entry.RecordedOn
    $script:GameState.DeathHistory = @($script:GameState.DeathHistory) + @($entry)
    if ((Test-LWPropertyExists -Object $script:GameState -Name 'Run') -and $null -ne $script:GameState.Run) {
        $script:GameState.Run.Status = 'Failed'
        $script:GameState.Run.CompletedOn = $entry.RecordedOn
    }
    Register-LWDeathStat -Type $entry.Type
    [void](Sync-LWAchievements -Context 'death' -Data $entry)

    if (Test-LWPermadeathEnabled) {
        $path = if ((Test-LWPropertyExists -Object $script:GameState.Settings -Name 'SavePath')) { [string]$script:GameState.Settings.SavePath } else { $null }
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            try {
                Remove-Item -LiteralPath $path -Force
                Write-LWError "Permadeath is active. Deleted save file: $path"
            }
            catch {
                Write-LWError "Permadeath is active, but the save file could not be deleted: $path"
            }
        }
        else {
            Write-LWError 'Permadeath is active. This run cannot be resumed from a save.'
        }

        $script:GameState.Settings.AutoSave = $false
        $script:GameState.Settings.SavePath = $null
    }

    return $entry
}

function Register-LWFailureState {
    param([string]$Cause = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        return $null
    }

    Ensure-LWDeathState -State $script:GameState

    $bookNumber = [int]$script:GameState.Character.BookNumber
    $entry = [pscustomobject]@{
        Type       = 'Failure'
        Cause      = if ([string]::IsNullOrWhiteSpace($Cause)) { 'The mission failed.' } else { $Cause.Trim() }
        BookNumber = $bookNumber
        BookTitle  = Get-LWBookTitle -BookNumber $bookNumber
        Section    = [int]$script:GameState.CurrentSection
        RecordedOn = (Get-Date).ToString('o')
    }

    $script:GameState.DeathState.Active = $true
    $script:GameState.DeathState.Type = $entry.Type
    $script:GameState.DeathState.Cause = $entry.Cause
    $script:GameState.DeathState.BookNumber = $entry.BookNumber
    $script:GameState.DeathState.BookTitle = $entry.BookTitle
    $script:GameState.DeathState.Section = $entry.Section
    $script:GameState.DeathState.RecordedOn = $entry.RecordedOn
    if ((Test-LWPropertyExists -Object $script:GameState -Name 'Run') -and $null -ne $script:GameState.Run) {
        $script:GameState.Run.Status = 'Failed'
        $script:GameState.Run.CompletedOn = $entry.RecordedOn
    }

    return $entry
}

function Get-LWAvailableRewindCount {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (Test-LWPermadeathEnabled) {
        return 0
    }

    if (-not (Test-LWHasState) -or -not (Test-LWPropertyExists -Object $script:GameState -Name 'SectionCheckpoints') -or $null -eq $script:GameState.SectionCheckpoints) {
        return 0
    }

    return [Math]::Max(0, (@($script:GameState.SectionCheckpoints).Count - 1))
}

function Get-LWBookPathSectionCount {
    param([int]$BookNumber)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or $BookNumber -lt 1 -or -not (Test-LWPropertyExists -Object $script:GameState -Name 'SectionCheckpoints') -or $null -eq $script:GameState.SectionCheckpoints) {
        return 0
    }

    $count = 0
    foreach ($checkpoint in @($script:GameState.SectionCheckpoints)) {
        if ($null -ne $checkpoint -and (Test-LWPropertyExists -Object $checkpoint -Name 'BookNumber') -and $null -ne $checkpoint.BookNumber -and [int]$checkpoint.BookNumber -eq $BookNumber) {
            $count++
        }
    }

    return $count
}

function Restore-LWSectionCheckpoint {
    param(
        [Parameter(Mandatory = $true)][object]$Checkpoint,
        [object[]]$RemainingCheckpoints = @()
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $snapshotJson = if ((Test-LWPropertyExists -Object $Checkpoint -Name 'Snapshot') -and -not [string]::IsNullOrWhiteSpace([string]$Checkpoint.Snapshot)) { [string]$Checkpoint.Snapshot } else { $null }
    if ([string]::IsNullOrWhiteSpace($snapshotJson)) {
        throw 'Checkpoint snapshot is missing.'
    }

    $currentSettings = $script:GameState.Settings
    $currentHistory = @($script:GameState.History)
    $currentBookHistory = @($script:GameState.BookHistory)
    $currentBookStats = $script:GameState.CurrentBookStats
    $currentDeathHistory = @($script:GameState.DeathHistory)
    $currentAchievements = $script:GameState.Achievements
    $currentNotes = @($script:GameState.Character.Notes)

    $restored = Normalize-LWState -State ($snapshotJson | ConvertFrom-Json)
    $restored.Settings = $currentSettings
    $restored.History = @($currentHistory)
    $restored.BookHistory = @($currentBookHistory)
    $restored.CurrentBookStats = $currentBookStats
    $restored.DeathHistory = @($currentDeathHistory)
    $restored.Achievements = $currentAchievements
    $restored.DeathState = (New-LWDeathState)
    $restored.SectionCheckpoints = @(Normalize-LWSectionCheckpoints -Checkpoints @($RemainingCheckpoints))
    if ($null -ne $restored.Character) {
        $restored.Character.Notes = @($currentNotes)
    }

    $script:GameState = Normalize-LWState -State $restored

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }
}

function Invoke-LWInstantDeath {
    param([string]$Cause = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }
    if ($script:GameState.Combat.Active) {
        Write-LWWarn 'Combat defeat is handled through the combat flow. Finish the combat or stop it first.'
        return
    }
    if (Test-LWDeathActive) {
        Write-LWWarn 'The character is already dead. Use rewind, load, new, or quit.'
        return
    }

    $script:GameState.Character.EnduranceCurrent = 0
    [void](Register-LWDeath -Type 'Instant' -Cause $Cause)
    Set-LWScreen -Name 'death'
    Write-LWError 'Instant death recorded.'
    Invoke-LWMaybeAutosave
}

function Invoke-LWFailure {
    param([string]$Cause = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }
    if ($script:GameState.Combat.Active) {
        Write-LWWarn 'Finish the combat or stop it before recording a failed mission.'
        return
    }
    if (Test-LWDeathActive) {
        Write-LWWarn 'A death or failed mission is already active. Use rewind, load, new, or quit.'
        return
    }

    [void](Register-LWFailureState -Cause $Cause)
    Set-LWScreen -Name 'death'
    Write-LWError 'Mission failed.'
    Invoke-LWMaybeAutosave
}

function Invoke-LWFatalEnduranceCheck {
    param([string]$Cause = 'Endurance has fallen to zero.')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState) -or $script:GameState.Combat.Active -or (Test-LWDeathActive)) {
        return $false
    }
    if ([int]$script:GameState.Character.EnduranceCurrent -gt 0) {
        return $false
    }

    [void](Register-LWDeath -Type 'Endurance' -Cause $Cause)
    Set-LWScreen -Name 'death'
    Write-LWError 'Lone Wolf has fallen.'
    Invoke-LWMaybeAutosave
    return $true
}

function Invoke-LWRewind {
    param([Nullable[int]]$Steps = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }
    if (-not (Test-LWDeathActive)) {
        Write-LWWarn 'rewind is only available after a death or failed mission.'
        return
    }
    if (Test-LWPermadeathEnabled) {
        Write-LWWarn 'Permadeath disables rewind for this run.'
        return
    }

    if ($null -eq $Steps) {
        $Steps = 1
    }

    $rewindSteps = [int]$Steps
    if ($rewindSteps -lt 1) {
        $rewindSteps = 1
    }

    $available = Get-LWAvailableRewindCount
    if ($available -lt 1) {
        Write-LWWarn 'No earlier safe section is available to rewind to.'
        return
    }
    if ($rewindSteps -gt $available) {
        Write-LWWarn "You can rewind at most $available section(s) from this death."
        return
    }

    $checkpoints = @($script:GameState.SectionCheckpoints)
    $targetCount = $checkpoints.Count - $rewindSteps
    $remaining = @($checkpoints[0..($targetCount - 1)])
    $target = $remaining[-1]

    Register-LWRewindUsed -Count $rewindSteps
    Restore-LWSectionCheckpoint -Checkpoint $target -RemainingCheckpoints $remaining
    Clear-LWDeathState
    Set-LWScreen -Name 'sheet'
    Write-LWInfo ("Rewound {0} section{1}. You are back at section {2}." -f $rewindSteps, $(if ($rewindSteps -eq 1) { '' } else { 's' }), $script:GameState.CurrentSection)
    Invoke-LWMaybeAutosave
}

function Normalize-LWCombatHistoryMetadata {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-LWPropertyExists -Object $State -Name 'History') -or $null -eq $State.History) {
        return
    }

    $history = @($State.History)
    if (@($history).Count -eq 0) {
        return
    }

    foreach ($entry in $history) {
        $entryBookNumber = $null
        if ((Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and $null -ne $entry.BookNumber -and [int]$entry.BookNumber -gt 0) {
            $entryBookNumber = [int]$entry.BookNumber
        }

        $entryBookTitle = ''
        if ((Test-LWPropertyExists -Object $entry -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$entry.BookTitle)) {
            $entryBookTitle = [string]$entry.BookTitle
        }

        if ($null -ne $entryBookNumber -or -not [string]::IsNullOrWhiteSpace($entryBookTitle)) {
            Set-LWCombatEntryBookMetadata -Entry $entry -BookNumber $entryBookNumber -BookTitle $entryBookTitle
        }
    }

    $missingEntries = @($history | Where-Object {
            $bookNumberMissing = (-not (Test-LWPropertyExists -Object $_ -Name 'BookNumber')) -or $null -eq $_.BookNumber -or [int]$_.BookNumber -le 0
            $bookTitleMissing = (-not (Test-LWPropertyExists -Object $_ -Name 'BookTitle')) -or [string]::IsNullOrWhiteSpace([string]$_.BookTitle)
            $bookNumberMissing -and $bookTitleMissing
        })

    if (@($missingEntries).Count -eq 0) {
        return
    }

    $bookHistory = if ((Test-LWPropertyExists -Object $State -Name 'BookHistory') -and $null -ne $State.BookHistory) { @($State.BookHistory) } else { @() }
    $historyIndex = 0

    foreach ($bookSummary in $bookHistory) {
        if ($historyIndex -ge @($history).Count) {
            break
        }

        if (-not (Test-LWPropertyExists -Object $bookSummary -Name 'BookNumber') -or $null -eq $bookSummary.BookNumber) {
            continue
        }

        $bookNumber = [int]$bookSummary.BookNumber
        $combatCount = if ((Test-LWPropertyExists -Object $bookSummary -Name 'CombatCount') -and $null -ne $bookSummary.CombatCount) { [int]$bookSummary.CombatCount } else { 0 }
        for ($i = 0; $i -lt $combatCount -and $historyIndex -lt @($history).Count; $i++) {
            Set-LWCombatEntryBookMetadata -Entry $history[$historyIndex] -BookNumber $bookNumber -BookTitle ([string](Get-LWBookTitle -BookNumber $bookNumber))
            $historyIndex++
        }
    }

    $missingEntries = @($history | Where-Object {
            ((-not (Test-LWPropertyExists -Object $_ -Name 'BookNumber')) -or $null -eq $_.BookNumber -or [int]$_.BookNumber -le 0) -and
            ((-not (Test-LWPropertyExists -Object $_ -Name 'BookTitle')) -or [string]::IsNullOrWhiteSpace([string]$_.BookTitle))
        })

    if (@($missingEntries).Count -eq 0) {
        return
    }

    $currentBookNumber = if ((Test-LWPropertyExists -Object $State.Character -Name 'BookNumber') -and $null -ne $State.Character.BookNumber) { [int]$State.Character.BookNumber } else { 1 }
    $completedBooks = if ((Test-LWPropertyExists -Object $State.Character -Name 'CompletedBooks') -and $null -ne $State.Character.CompletedBooks) { @($State.Character.CompletedBooks | ForEach-Object { [int]$_ }) } else { @() }
    $currentBookResolvedCombats = Get-LWCurrentBookResolvedCombatCount -State $State

    if ($currentBookNumber -eq 1) {
        foreach ($entry in $missingEntries) {
            Set-LWCombatEntryBookMetadata -Entry $entry -BookNumber 1 -BookTitle (Get-LWBookTitle -BookNumber 1)
        }
        return
    }

    if (@($completedBooks).Count -eq 1 -and $completedBooks[0] -eq ($currentBookNumber - 1) -and $currentBookResolvedCombats -eq 0) {
        foreach ($entry in $missingEntries) {
            Set-LWCombatEntryBookMetadata -Entry $entry -BookNumber $completedBooks[0] -BookTitle (Get-LWBookTitle -BookNumber $completedBooks[0])
        }
    }

    Normalize-LWCombatHistorySections -State $State
}

function New-LWBookStats {
    param(
        [int]$BookNumber,
        [Nullable[int]]$StartSection = $null,
        [bool]$PartialTracking = $false
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $visitedSections = @()
    $sectionsVisited = 0
    $startValue = $null
    $lastValue = $null

    if ($null -ne $StartSection -and [int]$StartSection -gt 0) {
        $startValue = [int]$StartSection
        $lastValue = [int]$StartSection
        $visitedSections = @([int]$StartSection)
        $sectionsVisited = 1
    }

    return [pscustomobject]@{
        BookNumber                    = $BookNumber
        BookTitle                     = Get-LWBookTitle -BookNumber $BookNumber
        StartSection                  = $startValue
        LastSection                   = $lastValue
        SectionsVisited               = $sectionsVisited
        VisitedSections               = @($visitedSections)
        EnduranceLost                 = 0
        EnduranceGained               = 0
        MealsEaten                    = 0
        MealsCoveredByHunting         = 0
        StarvationPenalties           = 0
        PotionsUsed                   = 0
        ConcentratedPotionsUsed       = 0
        PotionEnduranceRestored       = 0
        RewindsUsed                   = 0
        ManualRecoveryShortcuts       = 0
        GoldGained                    = 0
        GoldSpent                     = 0
        HealingTriggers               = 0
        HealingEnduranceRestored      = 0
        MindblastCombats              = 0
        MindblastVictories            = 0
        WeaponUsage                   = @()
        WeaponVictories               = @()
        InstantDeaths                 = 0
        CombatDeaths                  = 0
        CombatCount                   = 0
        Victories                     = 0
        Defeats                       = 0
        Evades                        = 0
        RoundsFought                  = 0
        HighestEnemyCombatSkillFaced  = 0
        HighestEnemyEnduranceFaced    = 0
        HighestEnemyCombatSkillDefeated = 0
        HighestEnemyEnduranceDefeated = 0
        FastestVictoryEnemyName       = $null
        FastestVictoryRounds          = 0
        EasiestVictoryEnemyName       = $null
        EasiestVictoryRatio           = $null
        LongestFightEnemyName         = $null
        LongestFightRounds            = 0
        PartialTracking               = [bool]$PartialTracking
    }
}

function Normalize-LWBookStats {
    param(
        [object]$Stats,
        [int]$BookNumber,
        [Nullable[int]]$CurrentSection = $null,
        [bool]$PartialTracking = $false
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($null -eq $Stats) {
        return (New-LWBookStats -BookNumber $BookNumber -StartSection $CurrentSection -PartialTracking $PartialTracking)
    }

    if (-not (Test-LWPropertyExists -Object $Stats -Name 'BookNumber') -or [int]$Stats.BookNumber -ne $BookNumber) {
        return (New-LWBookStats -BookNumber $BookNumber -StartSection $CurrentSection -PartialTracking $PartialTracking)
    }

    if (-not (Test-LWPropertyExists -Object $Stats -Name 'BookTitle')) {
        $Stats | Add-Member -NotePropertyName BookTitle -NotePropertyValue (Get-LWBookTitle -BookNumber $BookNumber)
    }
    else {
        $Stats.BookTitle = Get-LWBookTitle -BookNumber $BookNumber
    }

    if (-not (Test-LWPropertyExists -Object $Stats -Name 'StartSection')) {
        $Stats | Add-Member -NotePropertyName StartSection -NotePropertyValue $CurrentSection
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'LastSection')) {
        $Stats | Add-Member -NotePropertyName LastSection -NotePropertyValue $Stats.StartSection
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'SectionsVisited')) {
        $Stats | Add-Member -NotePropertyName SectionsVisited -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'VisitedSections') -or $null -eq $Stats.VisitedSections) {
        $Stats | Add-Member -Force -NotePropertyName VisitedSections -NotePropertyValue @()
    }
    else {
        $Stats.VisitedSections = @($Stats.VisitedSections)
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'EnduranceLost')) {
        $Stats | Add-Member -NotePropertyName EnduranceLost -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'EnduranceGained')) {
        $Stats | Add-Member -NotePropertyName EnduranceGained -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'MealsEaten')) {
        $Stats | Add-Member -NotePropertyName MealsEaten -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'MealsCoveredByHunting')) {
        $Stats | Add-Member -NotePropertyName MealsCoveredByHunting -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'StarvationPenalties')) {
        $Stats | Add-Member -NotePropertyName StarvationPenalties -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'PotionsUsed')) {
        $Stats | Add-Member -NotePropertyName PotionsUsed -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'ConcentratedPotionsUsed')) {
        $Stats | Add-Member -NotePropertyName ConcentratedPotionsUsed -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'PotionEnduranceRestored')) {
        $Stats | Add-Member -NotePropertyName PotionEnduranceRestored -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'RewindsUsed')) {
        $Stats | Add-Member -NotePropertyName RewindsUsed -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'ManualRecoveryShortcuts')) {
        $Stats | Add-Member -NotePropertyName ManualRecoveryShortcuts -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'GoldGained')) {
        $Stats | Add-Member -NotePropertyName GoldGained -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'GoldSpent')) {
        $Stats | Add-Member -NotePropertyName GoldSpent -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'HealingTriggers')) {
        $Stats | Add-Member -NotePropertyName HealingTriggers -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'HealingEnduranceRestored')) {
        $Stats | Add-Member -NotePropertyName HealingEnduranceRestored -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'MindblastCombats')) {
        $Stats | Add-Member -NotePropertyName MindblastCombats -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'MindblastVictories')) {
        $Stats | Add-Member -NotePropertyName MindblastVictories -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'WeaponUsage') -or $null -eq $Stats.WeaponUsage) {
        $Stats | Add-Member -Force -NotePropertyName WeaponUsage -NotePropertyValue @()
    }
    else {
        $Stats.WeaponUsage = @(Normalize-LWNamedCountEntries -Entries @($Stats.WeaponUsage))
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'WeaponVictories') -or $null -eq $Stats.WeaponVictories) {
        $Stats | Add-Member -Force -NotePropertyName WeaponVictories -NotePropertyValue @()
    }
    else {
        $Stats.WeaponVictories = @(Normalize-LWNamedCountEntries -Entries @($Stats.WeaponVictories))
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'InstantDeaths')) {
        $Stats | Add-Member -NotePropertyName InstantDeaths -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'CombatDeaths')) {
        $Stats | Add-Member -NotePropertyName CombatDeaths -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'CombatCount')) {
        $Stats | Add-Member -NotePropertyName CombatCount -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'Victories')) {
        $Stats | Add-Member -NotePropertyName Victories -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'Defeats')) {
        $Stats | Add-Member -NotePropertyName Defeats -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'Evades')) {
        $Stats | Add-Member -NotePropertyName Evades -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'RoundsFought')) {
        $Stats | Add-Member -NotePropertyName RoundsFought -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'HighestEnemyCombatSkillFaced')) {
        $Stats | Add-Member -NotePropertyName HighestEnemyCombatSkillFaced -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'HighestEnemyEnduranceFaced')) {
        $Stats | Add-Member -NotePropertyName HighestEnemyEnduranceFaced -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'HighestEnemyCombatSkillDefeated')) {
        $Stats | Add-Member -NotePropertyName HighestEnemyCombatSkillDefeated -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'HighestEnemyEnduranceDefeated')) {
        $Stats | Add-Member -NotePropertyName HighestEnemyEnduranceDefeated -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'FastestVictoryEnemyName')) {
        $Stats | Add-Member -NotePropertyName FastestVictoryEnemyName -NotePropertyValue $null
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'FastestVictoryRounds')) {
        $Stats | Add-Member -NotePropertyName FastestVictoryRounds -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'EasiestVictoryEnemyName')) {
        $Stats | Add-Member -NotePropertyName EasiestVictoryEnemyName -NotePropertyValue $null
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'EasiestVictoryRatio')) {
        $Stats | Add-Member -NotePropertyName EasiestVictoryRatio -NotePropertyValue $null
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'LongestFightEnemyName')) {
        $Stats | Add-Member -NotePropertyName LongestFightEnemyName -NotePropertyValue $null
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'LongestFightRounds')) {
        $Stats | Add-Member -NotePropertyName LongestFightRounds -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $Stats -Name 'PartialTracking')) {
        $Stats | Add-Member -NotePropertyName PartialTracking -NotePropertyValue $PartialTracking
    }

    if (@($Stats.VisitedSections).Count -eq 0 -and $null -ne $Stats.StartSection) {
        $Stats.VisitedSections = @([int]$Stats.StartSection)
    }
    if ([int]$Stats.SectionsVisited -lt @($Stats.VisitedSections).Count) {
        $Stats.SectionsVisited = @($Stats.VisitedSections).Count
    }
    if ($null -eq $Stats.LastSection -and @($Stats.VisitedSections).Count -gt 0) {
        $Stats.LastSection = @($Stats.VisitedSections)[-1]
    }

    return $Stats
}

function Import-LWJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [object]$Default = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (-not (Test-Path -LiteralPath $Path)) {
        return $Default
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    return ($raw | ConvertFrom-Json)
}

function Ensure-LWCurrentBookStats {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return $null
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'BookHistory') -or $null -eq $script:GameState.BookHistory) {
        $script:GameState.BookHistory = @()
    }

    $bookNumber = [int]$script:GameState.Character.BookNumber
    $currentSection = if ($null -ne $script:GameState.CurrentSection) { [int]$script:GameState.CurrentSection } else { $null }

    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'CurrentBookStats') -or $null -eq $script:GameState.CurrentBookStats) {
        $script:GameState.CurrentBookStats = (New-LWBookStats -BookNumber $bookNumber -StartSection $currentSection -PartialTracking $true)
    }
    else {
        $script:GameState.CurrentBookStats = Normalize-LWBookStats -Stats $script:GameState.CurrentBookStats -BookNumber $bookNumber -CurrentSection $currentSection
    }

    return $script:GameState.CurrentBookStats
}

function Reset-LWCurrentBookStats {
    param(
        [int]$BookNumber,
        [Nullable[int]]$StartSection = $null,
        [bool]$PartialTracking = $false
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $script:GameState.CurrentBookStats = (New-LWBookStats -BookNumber $BookNumber -StartSection $StartSection -PartialTracking $PartialTracking)
    return $script:GameState.CurrentBookStats
}

function Add-LWBookSectionVisit {
    param([int]$Section)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreAddBookSectionVisit -Context (Get-LWModuleContext) -Section $Section
}

function Add-LWBookEnduranceDelta {
    param([int]$Delta)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreAddBookEnduranceDelta -Context (Get-LWModuleContext) -Delta $Delta
}

function Add-LWBookGoldDelta {
    param([int]$Delta)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreAddBookGoldDelta -Context (Get-LWModuleContext) -Delta $Delta
}

function Add-LWBookNamedCount {
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Delta = 1
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreAddBookNamedCount -Context (Get-LWModuleContext) -PropertyName $PropertyName -Name $Name -Delta $Delta
}

function Register-LWMealConsumed {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.MealsEaten = [int]$stats.MealsEaten + 1
    [void](Sync-LWAchievements -Context 'meal')
}

function Register-LWMealCoveredByHunting {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.MealsCoveredByHunting = [int]$stats.MealsCoveredByHunting + 1
    [void](Sync-LWAchievements -Context 'hunting')
}

function Register-LWStarvationPenalty {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.StarvationPenalties = [int]$stats.StarvationPenalties + 1
    [void](Sync-LWAchievements -Context 'starvation')
}

function Register-LWPotionUsed {
    param(
        [string]$PotionName = '',
        [int]$EnduranceRestored = 0
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.PotionsUsed = [int]$stats.PotionsUsed + 1
    if (Test-LWConcentratedHealingPotionName -Name $PotionName) {
        $stats.ConcentratedPotionsUsed = [int]$stats.ConcentratedPotionsUsed + 1
    }
    if ($EnduranceRestored -gt 0) {
        $stats.PotionEnduranceRestored = [int]$stats.PotionEnduranceRestored + $EnduranceRestored
    }
    [void](Sync-LWAchievements -Context 'potion')
}

function Register-LWRewindUsed {
    param([int]$Count = 1)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Count -le 0) {
        return
    }

    $stats.RewindsUsed = [int]$stats.RewindsUsed + $Count
    [void](Sync-LWAchievements -Context 'rewind')
}

function Register-LWManualRecoveryShortcut {
    param([int]$Count = 1)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Count -le 0) {
        return
    }

    $stats.ManualRecoveryShortcuts = [int]$stats.ManualRecoveryShortcuts + $Count
    [void](Sync-LWAchievements -Context 'recovery')
}

function Register-LWHealingRestore {
    param([int]$Amount)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Amount -le 0) {
        return
    }

    $stats.HealingTriggers = [int]$stats.HealingTriggers + 1
    $stats.HealingEnduranceRestored = [int]$stats.HealingEnduranceRestored + $Amount
    if (-not (Test-LWAchievementSyncSuppressed -Context 'healing')) {
        [void](Sync-LWAchievements -Context 'healing')
    }
}

function Get-LWModeAchievementPools {
    param([object]$State = $script:GameState)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $difficulty = Get-LWCurrentDifficulty -State $State
    switch ($difficulty) {
        'Story' { return @('Universal', 'Story') }
        'Easy' { return @('Universal') }
        'Hard' { return @('Universal', 'Combat', 'Exploration', 'Challenge') }
        'Veteran' { return @('Universal', 'Combat', 'Exploration', 'Challenge') }
        default { return @('Universal', 'Combat', 'Exploration') }
    }
}

Export-ModuleMember -Function New-LWRunState, New-LWRunArchiveEntry, Ensure-LWRunState, Ensure-LWRunHistory, Get-LWRunSignaturePayload, Get-LWRunSignature, Mark-LWRunTampered, Sync-LWRunIntegrityState, Get-LWCurrentDifficulty, Test-LWPermadeathEnabled, Test-LWRunTampered, Test-LWDifficultyAllowsChallengeAchievements, New-LWDeathState, Ensure-LWDeathState, Get-LWActiveDeathState, Test-LWDeathActive, Clear-LWDeathState, Normalize-LWSectionCheckpoints, Get-LWCheckpointSnapshotObject, Get-LWCheckpointSnapshotJson, New-LWSectionCheckpoint, Reset-LWSectionCheckpoints, Ensure-LWCurrentSectionCheckpoint, Save-LWCurrentSectionCheckpoint, Sync-LWCurrentSectionCheckpoint, Get-LWBookDeathCount, Register-LWDeath, Register-LWFailureState, Get-LWAvailableRewindCount, Get-LWBookPathSectionCount, Restore-LWSectionCheckpoint, Invoke-LWInstantDeath, Invoke-LWFailure, Invoke-LWFatalEnduranceCheck, Invoke-LWRewind, Normalize-LWCombatHistoryMetadata, New-LWBookStats, Normalize-LWBookStats, Import-LWJson, Ensure-LWCurrentBookStats, Reset-LWCurrentBookStats, Add-LWBookSectionVisit, Add-LWBookEnduranceDelta, Add-LWBookGoldDelta, Add-LWBookNamedCount, Register-LWMealConsumed, Register-LWMealCoveredByHunting, Register-LWStarvationPenalty, Register-LWPotionUsed, Register-LWRewindUsed, Register-LWManualRecoveryShortcut, Register-LWHealingRestore, Get-LWModeAchievementPools

function New-LWInventoryRecoveryEntry {
    return [pscustomobject]@{
        Items      = @()
        BookNumber = $null
        Section    = $null
        SavedOn    = $null
    }
}

function New-LWInventoryRecoveryState {
    return [pscustomobject]@{
        Weapon    = (New-LWInventoryRecoveryEntry)
        Backpack  = (New-LWInventoryRecoveryEntry)
        Special   = (New-LWInventoryRecoveryEntry)
        HerbPouch = (New-LWInventoryRecoveryEntry)
    }
}

function New-LWStorageState {
    return [pscustomobject]@{
        SafekeepingSpecialItems = @()
        Confiscated             = [pscustomobject]@{
            Weapons        = @()
            BackpackItems  = @()
            SpecialItems   = @()
            PocketSpecialItems = @()
            HerbPouchItems = @()
            HasHerbPouch   = $false
            GoldCrowns     = 0
            BookNumber     = $null
            Section        = $null
            SavedOn        = $null
        }
    }
}

function New-LWConditionState {
    return [pscustomobject]@{
        BookFiveBloodPoisoning = $false
        BookFiveLimbdeath      = $false
        BookSixDECuringOption  = -1
        BookSixDEWeaponskillOption = -1
    }
}

function Test-LWHasState {
    return ($script:GameState -and $script:GameState.Character -and -not [string]::IsNullOrWhiteSpace($script:GameState.Character.Name))
}

function Register-LWDeathStat {
    param([string]$Type = 'Instant')

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    if ([string]$Type -ieq 'Combat') {
        $stats.CombatDeaths = [int]$stats.CombatDeaths + 1
        return
    }

    $stats.InstantDeaths = [int]$stats.InstantDeaths + 1
}

function New-LWBookHistoryEntry {
    param([Parameter(Mandatory = $true)][object]$Stats)

    $stats = Normalize-LWBookStats -Stats $Stats -BookNumber ([int]$Stats.BookNumber) -CurrentSection $Stats.LastSection
    $bookNumber = [int]$Stats.BookNumber
    return [pscustomobject]@{
        BookNumber                    = $bookNumber
        BookTitle                     = [string](Get-LWBookTitle -BookNumber $bookNumber)
        Difficulty                    = Get-LWCurrentDifficulty
        Permadeath                    = [bool](Test-LWPermadeathEnabled)
        RunIntegrityState             = [string]$script:GameState.Run.IntegrityState
        StartSection                  = $Stats.StartSection
        LastSection                   = $Stats.LastSection
        SuccessfulPathSections        = (Get-LWBookPathSectionCount -BookNumber $bookNumber)
        SectionsVisited               = [int]$Stats.SectionsVisited
        UniqueSectionsVisited         = @($Stats.VisitedSections).Count
        EnduranceLost                 = [int]$Stats.EnduranceLost
        EnduranceGained               = [int]$Stats.EnduranceGained
        MealsEaten                    = [int]$Stats.MealsEaten
        MealsCoveredByHunting         = [int]$Stats.MealsCoveredByHunting
        StarvationPenalties           = [int]$Stats.StarvationPenalties
        PotionsUsed                   = [int]$Stats.PotionsUsed
        ConcentratedPotionsUsed       = [int]$Stats.ConcentratedPotionsUsed
        PotionEnduranceRestored       = [int]$Stats.PotionEnduranceRestored
        RewindsUsed                   = [int]$Stats.RewindsUsed
        ManualRecoveryShortcuts       = [int]$Stats.ManualRecoveryShortcuts
        GoldGained                    = [int]$Stats.GoldGained
        GoldSpent                     = [int]$Stats.GoldSpent
        HealingTriggers               = [int]$Stats.HealingTriggers
        HealingEnduranceRestored      = [int]$Stats.HealingEnduranceRestored
        CombatCount                   = [int]$Stats.CombatCount
        Victories                     = [int]$Stats.Victories
        Defeats                       = [int]$Stats.Defeats
        Evades                        = [int]$Stats.Evades
        RoundsFought                  = [int]$Stats.RoundsFought
        MindblastCombats              = [int]$Stats.MindblastCombats
        MindblastVictories            = [int]$Stats.MindblastVictories
        WeaponUsage                   = @(Normalize-LWNamedCountEntries -Entries @($Stats.WeaponUsage))
        WeaponVictories               = @(Normalize-LWNamedCountEntries -Entries @($Stats.WeaponVictories))
        InstantDeaths                 = [int]$Stats.InstantDeaths
        CombatDeaths                  = [int]$Stats.CombatDeaths
        HighestEnemyCombatSkillFaced  = [int]$Stats.HighestEnemyCombatSkillFaced
        HighestEnemyEnduranceFaced    = [int]$Stats.HighestEnemyEnduranceFaced
        HighestEnemyCombatSkillDefeated = [int]$Stats.HighestEnemyCombatSkillDefeated
        HighestEnemyEnduranceDefeated = [int]$Stats.HighestEnemyEnduranceDefeated
        FastestVictoryEnemyName       = $Stats.FastestVictoryEnemyName
        FastestVictoryRounds          = [int]$Stats.FastestVictoryRounds
        EasiestVictoryEnemyName       = $Stats.EasiestVictoryEnemyName
        EasiestVictoryRatio           = $Stats.EasiestVictoryRatio
        LongestFightEnemyName         = $Stats.LongestFightEnemyName
        LongestFightRounds            = [int]$Stats.LongestFightRounds
        DeathCount                    = (Get-LWBookDeathCount -BookNumber $bookNumber)
        PartialTracking               = [bool]$Stats.PartialTracking
        CompletionQuote               = Get-LWBookCompletionQuote -BookNumber $bookNumber
    }
}

function New-LWDefaultState {
    $state = Invoke-LWCoreNewDefaultState -Context (Get-LWModuleContext)
    $state = Sync-LWHerbPouchState -State $state
    return (Sync-LWStateRefactorMetadata -State $state)
}

Export-ModuleMember -Function New-LWInventoryRecoveryEntry, New-LWInventoryRecoveryState, New-LWStorageState, New-LWConditionState, Test-LWHasState, Register-LWDeathStat, New-LWBookHistoryEntry, New-LWDefaultState

