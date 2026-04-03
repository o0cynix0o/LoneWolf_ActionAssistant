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
                SpecialItems  = @()
                GoldCrowns    = 0
                HasBackpack   = $true
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
        foreach ($entryName in @('Weapons', 'BackpackItems', 'SpecialItems')) {
            if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name $entryName) -or $null -eq $State.Storage.Confiscated.$entryName) {
                $State.Storage.Confiscated | Add-Member -Force -NotePropertyName $entryName -NotePropertyValue @()
            }
            else {
                $normalizedType = switch ($entryName) {
                    'SpecialItems' { 'special' }
                    'Weapons' { 'weapon' }
                    default { 'backpack' }
                }
                $State.Storage.Confiscated.$entryName = @(Resolve-LWCoreInventoryItemList -Items @($State.Storage.Confiscated.$entryName) -Type $normalizedType)
            }
        }
        foreach ($propertyName in @('GoldCrowns', 'BookNumber', 'Section', 'SavedOn')) {
            if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name $propertyName)) {
                $State.Storage.Confiscated | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $null
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

        foreach ($entryName in @('Weapon', 'Backpack', 'Special')) {
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
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasBackpack') -or $null -eq $State.Inventory.HasBackpack) {
            $State.Inventory | Add-Member -Force -NotePropertyName HasBackpack -NotePropertyValue $true
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'QuiverArrows') -or $null -eq $State.Inventory.QuiverArrows) {
            $State.Inventory | Add-Member -Force -NotePropertyName QuiverArrows -NotePropertyValue 0
        }
        if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'SpecialItems') -or $null -eq $State.Inventory.SpecialItems) {
            $State.Inventory.SpecialItems = @()
        }
        else {
            $State.Inventory.SpecialItems = @(Resolve-LWCoreInventoryItemList -Items @($State.Inventory.SpecialItems) -Type 'special')
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
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EvadeResolutionSection')) {
            $State.Combat | Add-Member -Force -NotePropertyName EvadeResolutionSection -NotePropertyValue $null
        }
        if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'EvadeResolutionNote')) {
            $State.Combat | Add-Member -Force -NotePropertyName EvadeResolutionNote -NotePropertyValue $null
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
    Invoke-LWCoreNormalizeState

