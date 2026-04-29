Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

. (Join-Path $repoRoot 'lonewolf.ps1')

Initialize-LWRuntimeShell
Initialize-LWData
$script:LWUi.Enabled = $true
$script:LWUi.NeedsRender = $false
Set-LWScreen -Name 'welcome'

function Get-LWWebBookFolders {
    return @{
        1  = 'lw/01fftd'
        2  = 'lw/02fotw'
        3  = 'lw/03tcok'
        4  = 'lw/04tcod'
        5  = 'lw/05sots'
        6  = 'lw/06tkot'
        7  = 'lw/07cd'
        8  = 'lw/08tjoh'
        9  = 'lw/09tcof'
        10 = 'lw/10tdot'
        11 = 'lw/11tpot'
        12 = 'lw/12tmod'
        13 = 'lw/13tplor'
        14 = 'lw/14tcok'
        15 = 'lw/15tdc'
        16 = 'lw/16tlov'
        17 = 'lw/17tdoi'
        18 = 'lw/18dotd'
        19 = 'lw/19wb'
        20 = 'lw/20tcon'
        21 = 'lw/21votm'
        22 = 'lw/22tbos'
        23 = 'lw/23mh'
        24 = 'lw/24rw'
        25 = 'lw/25totw'
        26 = 'lw/26tfobm'
        27 = 'lw/27v'
        28 = 'lw/28thos'
        29 = 'lw/29tsoc'
    }
}

function Get-LWWebReaderUrl {
    param(
        [int]$BookNumber,
        [int]$Section
    )

    if ($BookNumber -le 0 -or $Section -le 0) {
        return '/web/frontend/library.html'
    }

    $folders = Get-LWWebBookFolders
    if (-not $folders.ContainsKey($BookNumber)) {
        return '/web/frontend/library.html'
    }

    return ('/books/{0}/sect{1}.htm' -f $folders[$BookNumber], $Section)
}

function Get-LWWebSaveEntries {
    return @(
        foreach ($entry in @(Get-LWSaveCatalog)) {
            if ($null -eq $entry) {
                continue
            }

            [ordered]@{
                Index          = if ((Test-LWPropertyExists -Object $entry -Name 'Index') -and $null -ne $entry.Index) { [int]$entry.Index } else { 0 }
                Name           = if ((Test-LWPropertyExists -Object $entry -Name 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Name)) { [string]$entry.Name } else { '' }
                FullName       = if ((Test-LWPropertyExists -Object $entry -Name 'FullName') -and -not [string]::IsNullOrWhiteSpace([string]$entry.FullName)) { [string]$entry.FullName } else { '' }
                CharacterName  = if ((Test-LWPropertyExists -Object $entry -Name 'CharacterName') -and -not [string]::IsNullOrWhiteSpace([string]$entry.CharacterName)) { [string]$entry.CharacterName } else { '' }
                BookNumber     = if ((Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and $null -ne $entry.BookNumber) { [int]$entry.BookNumber } else { $null }
                CurrentSection = if ((Test-LWPropertyExists -Object $entry -Name 'CurrentSection') -and $null -ne $entry.CurrentSection) { [int]$entry.CurrentSection } else { $null }
                RuleSet        = if ((Test-LWPropertyExists -Object $entry -Name 'RuleSet') -and -not [string]::IsNullOrWhiteSpace([string]$entry.RuleSet)) { [string]$entry.RuleSet } else { '' }
                Difficulty     = if ((Test-LWPropertyExists -Object $entry -Name 'Difficulty') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Difficulty)) { [string]$entry.Difficulty } else { '' }
                LastWriteTime  = if ((Test-LWPropertyExists -Object $entry -Name 'LastWriteTime') -and $null -ne $entry.LastWriteTime) { ([datetime]$entry.LastWriteTime).ToString('s') } else { '' }
                IsCurrent      = [bool]((Test-LWPropertyExists -Object $entry -Name 'IsCurrent') -and [bool]$entry.IsCurrent)
            }
        }
    )
}

function Get-LWWebHistoryPreview {
    param([object[]]$History)

    $entries = @($History)
    if ($entries.Count -eq 0) {
        return @()
    }

    $startIndex = [Math]::Max(0, ($entries.Count - 12))
    return @(
        foreach ($entry in @($entries[$startIndex..($entries.Count - 1)])) {
            if ($null -eq $entry) {
                continue
            }

            [ordered]@{
                EnemyName    = if ((Test-LWPropertyExists -Object $entry -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$entry.EnemyName)) { [string]$entry.EnemyName } else { '' }
                Outcome      = if ((Test-LWPropertyExists -Object $entry -Name 'Outcome') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Outcome)) { [string]$entry.Outcome } else { '' }
                RoundCount   = if ((Test-LWPropertyExists -Object $entry -Name 'RoundCount') -and $null -ne $entry.RoundCount) { [int]$entry.RoundCount } else { 0 }
                Section      = if ((Test-LWPropertyExists -Object $entry -Name 'Section') -and $null -ne $entry.Section) { [int]$entry.Section } else { $null }
                BookNumber   = if ((Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and $null -ne $entry.BookNumber) { [int]$entry.BookNumber } else { $null }
                BookTitle    = if ((Test-LWPropertyExists -Object $entry -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$entry.BookTitle)) { [string]$entry.BookTitle } else { '' }
                Weapon       = if ((Test-LWPropertyExists -Object $entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Weapon)) { [string]$entry.Weapon } else { '' }
                CombatRatio  = if ((Test-LWPropertyExists -Object $entry -Name 'CombatRatio') -and $null -ne $entry.CombatRatio) { [int]$entry.CombatRatio } else { 0 }
                EnemyEnd     = if ((Test-LWPropertyExists -Object $entry -Name 'EnemyEnd') -and $null -ne $entry.EnemyEnd) { [int]$entry.EnemyEnd } else { 0 }
                PlayerEnd    = if ((Test-LWPropertyExists -Object $entry -Name 'PlayerEnd') -and $null -ne $entry.PlayerEnd) { [int]$entry.PlayerEnd } else { 0 }
            }
        }
    )
}

function Get-LWWebCampaignSnapshot {
    if ($null -eq $script:GameState) {
        return $null
    }

    $completedBooks = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.CompletedBooks) {
        @($script:GameState.Character.CompletedBooks)
    }
    else {
        @()
    }

    $difficulty = if (
        (Test-LWPropertyExists -Object $script:GameState -Name 'Run') -and
        $null -ne $script:GameState.Run -and
        (Test-LWPropertyExists -Object $script:GameState.Run -Name 'Difficulty') -and
        -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.Difficulty)
    ) {
        [string]$script:GameState.Run.Difficulty
    }
    else {
        'Normal'
    }

    $permadeathEnabled = (
        (Test-LWPropertyExists -Object $script:GameState -Name 'Run') -and
        $null -ne $script:GameState.Run -and
        (Test-LWPropertyExists -Object $script:GameState.Run -Name 'Permadeath') -and
        [bool]$script:GameState.Run.Permadeath
    )

    $currentBookStats = if ($null -ne $script:GameState.CurrentBookStats) { $script:GameState.CurrentBookStats } else { $null }

    return [ordered]@{
        CharacterName     = if ($null -ne $script:GameState.Character) { [string]$script:GameState.Character.Name } else { '' }
        Difficulty        = $difficulty
        PermadeathEnabled = [bool]$permadeathEnabled
        CurrentBookLabel  = ("Book {0} - {1}" -f ([int]$script:GameState.Character.BookNumber), (Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber)))
        CurrentSection    = [int]$script:GameState.CurrentSection
        CompletedBooks    = @($completedBooks)
        CombatCount       = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'CombatCount')) { [int]$currentBookStats.CombatCount } else { 0 }
        Victories         = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'Victories')) { [int]$currentBookStats.Victories } else { 0 }
        Defeats           = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'Defeats')) { [int]$currentBookStats.Defeats } else { 0 }
        Evades            = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'Evades')) { [int]$currentBookStats.Evades } else { 0 }
        Deaths            = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'CombatDeaths')) { [int]$currentBookStats.CombatDeaths } else { 0 }
        RewindsUsed       = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'RewindsUsed')) { [int]$currentBookStats.RewindsUsed } else { 0 }
        BooksCompleted    = @($completedBooks).Count
        SectionsVisited   = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'SectionsVisited')) { [int]$currentBookStats.SectionsVisited } else { 0 }
        CurrentGold       = [int]$script:GameState.Inventory.GoldCrowns
        CurrentEndurance  = [int]$script:GameState.Character.EnduranceCurrent
        EnduranceMax      = [int]$script:GameState.Character.EnduranceMax
        RunStyle          = if ($null -ne $currentBookStats -and (Test-LWPropertyExists -Object $currentBookStats -Name 'PartialTracking') -and [bool]$currentBookStats.PartialTracking) { 'Partial Tracking' } else { 'Tracked Run' }
    }
}

function Get-LWWebStateSnapshot {
    $screenName = if ($null -ne $script:LWUi -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.CurrentScreen)) {
        [string]$script:LWUi.CurrentScreen
    }
    else {
        [string](Get-LWDefaultScreen)
    }

    $screenData = if ($null -ne $script:LWUi) { $script:LWUi.ScreenData } else { $null }
    $notifications = if ($null -ne $script:LWUi -and $null -ne $script:LWUi.Notifications) { @($script:LWUi.Notifications) } else { @() }

    if ($null -eq $script:GameState) {
        return [ordered]@{
            app              = [ordered]@{
                Name    = $script:LWAppName
                Version = $script:LWAppVersion
            }
            session          = [ordered]@{
                HasState      = $false
                CurrentScreen = $screenName
                ScreenData    = $screenData
                Notifications = @($notifications)
            }
            reader           = [ordered]@{
                BookNumber = $null
                BookTitle  = ''
                Section    = $null
                Url        = '/web/frontend/library.html'
            }
            saves            = @(Get-LWWebSaveEntries)
            campaign         = $null
            availableScreens = @('welcome', 'sheet', 'inventory', 'disciplines', 'notes', 'history', 'stats', 'campaign', 'achievements', 'combat', 'combatlog', 'bookcomplete', 'help')
        }
    }

    $bookNumber = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 1 }
    $section = if ($null -ne $script:GameState.CurrentSection) { [int]$script:GameState.CurrentSection } else { 1 }
    $bookTitle = [string](Get-LWBookTitle -BookNumber $bookNumber)
    $inventory = $script:GameState.Inventory
    $character = $script:GameState.Character
    $combat = $script:GameState.Combat

    return [ordered]@{
        app              = [ordered]@{
            Name    = $script:LWAppName
            Version = $script:LWAppVersion
            RuleSet = if ((Test-LWPropertyExists -Object $script:GameState -Name 'RuleSet') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.RuleSet)) { [string]$script:GameState.RuleSet } else { '' }
        }
        session          = [ordered]@{
            HasState      = $true
            CurrentScreen = $screenName
            ScreenData    = $screenData
            Notifications = @($notifications)
        }
        reader           = [ordered]@{
            BookNumber = $bookNumber
            BookTitle  = $bookTitle
            Section    = $section
            Url        = Get-LWWebReaderUrl -BookNumber $bookNumber -Section $section
        }
        character        = [ordered]@{
            Name                 = if ($null -ne $character -and -not [string]::IsNullOrWhiteSpace([string]$character.Name)) { [string]$character.Name } else { '' }
            BookNumber           = $bookNumber
            BookTitle            = $bookTitle
            CombatSkillBase      = if ($null -ne $character.CombatSkillBase) { [int]$character.CombatSkillBase } else { 0 }
            EnduranceCurrent     = if ($null -ne $character.EnduranceCurrent) { [int]$character.EnduranceCurrent } else { 0 }
            EnduranceMax         = if ($null -ne $character.EnduranceMax) { [int]$character.EnduranceMax } else { 0 }
            Disciplines          = @($character.Disciplines)
            MagnakaiDisciplines  = @($character.MagnakaiDisciplines)
            WeaponskillWeapon    = if ((Test-LWPropertyExists -Object $character -Name 'WeaponskillWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$character.WeaponskillWeapon)) { [string]$character.WeaponskillWeapon } else { '' }
            WeaponmasteryWeapons = @($character.WeaponmasteryWeapons)
            CompletedBooks       = @($character.CompletedBooks)
        }
        inventory        = [ordered]@{
            Weapons            = @($inventory.Weapons)
            BackpackItems      = @($inventory.BackpackItems)
            HerbPouchItems     = @($inventory.HerbPouchItems)
            SpecialItems       = @($inventory.SpecialItems)
            PocketSpecialItems = @($inventory.PocketSpecialItems)
            GoldCrowns         = if ($null -ne $inventory.GoldCrowns) { [int]$inventory.GoldCrowns } else { 0 }
            HasBackpack        = [bool]$inventory.HasBackpack
            HasHerbPouch       = [bool]$inventory.HasHerbPouch
            QuiverArrows       = if ((Test-LWPropertyExists -Object $inventory -Name 'QuiverArrows') -and $null -ne $inventory.QuiverArrows) { [int]$inventory.QuiverArrows } else { 0 }
        }
        combat           = [ordered]@{
            Active                      = [bool]$combat.Active
            EnemyName                   = if ((Test-LWPropertyExists -Object $combat -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$combat.EnemyName)) { [string]$combat.EnemyName } else { '' }
            EnemyCombatSkill            = if ($null -ne $combat.EnemyCombatSkill) { [int]$combat.EnemyCombatSkill } else { 0 }
            EnemyEnduranceCurrent       = if ($null -ne $combat.EnemyEnduranceCurrent) { [int]$combat.EnemyEnduranceCurrent } else { 0 }
            EnemyEnduranceMax           = if ($null -ne $combat.EnemyEnduranceMax) { [int]$combat.EnemyEnduranceMax } else { 0 }
            UseMindblast                = [bool]$combat.UseMindblast
            EquippedWeapon              = if ((Test-LWPropertyExists -Object $combat -Name 'EquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$combat.EquippedWeapon)) { [string]$combat.EquippedWeapon } else { '' }
            CanEvade                    = [bool]$combat.CanEvade
            MindblastCombatSkillBonus   = if ((Test-LWPropertyExists -Object $combat -Name 'MindblastCombatSkillBonus') -and $null -ne $combat.MindblastCombatSkillBonus) { [int]$combat.MindblastCombatSkillBonus } else { 0 }
            PlayerEnduranceLossMultiplier = if ((Test-LWPropertyExists -Object $combat -Name 'PlayerEnduranceLossMultiplier') -and $null -ne $combat.PlayerEnduranceLossMultiplier) { [int]$combat.PlayerEnduranceLossMultiplier } else { 1 }
            Log                         = @($combat.Log)
        }
        notes            = @($character.Notes)
        history          = @(Get-LWWebHistoryPreview -History @($script:GameState.History))
        currentBookStats = if ($null -ne $script:GameState.CurrentBookStats) { $script:GameState.CurrentBookStats } else { $null }
        campaign         = Get-LWWebCampaignSnapshot
        saves            = @(Get-LWWebSaveEntries)
        availableScreens = @('sheet', 'inventory', 'disciplines', 'notes', 'history', 'stats', 'campaign', 'achievements', 'combat', 'combatlog', 'bookcomplete', 'help')
        safeCommands     = @(
            'sheet',
            'inventory',
            'notes',
            'history',
            'help',
            'stats',
            'campaign',
            'achievements',
            'combat status',
            'combat log',
            'set <section>'
        )
    }
}

function Load-LWWebLastSave {
    $lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
    if (-not (Test-Path -LiteralPath $lastSaveFile)) {
        return 'No last save file found.'
    }

    $path = (Get-Content -LiteralPath $lastSaveFile -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($path)) {
        return 'Last save file is empty.'
    }

    if (-not (Test-Path -LiteralPath $path)) {
        return "Last save not found: $path"
    }

    Load-LWGame -Path $path
    return ("Loaded last save: {0}" -f (Split-Path -Leaf $path))
}

function Test-LWWebSafeCommand {
    param([Parameter(Mandatory = $true)][string]$InputLine)

    $trimmed = $InputLine.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $false
    }

    return (
        $trimmed -match '^(sheet|inv|inventory|notes|history|help|disciplines)$' -or
        $trimmed -match '^stats(\s+(overview|combat|survival))?$' -or
        $trimmed -match '^campaign(\s+(overview|books|combat|survival|milestones))?$' -or
        $trimmed -match '^achievements(\s+(overview|recent|unlocked|locked|progress|planned))?$' -or
        $trimmed -match '^combat\s+(status|log)$' -or
        $trimmed -match '^set\s+\d+$'
    )
}

function Invoke-LWWebRequest {
    param([Parameter(Mandatory = $true)][object]$Request)

    $action = if ((Test-LWPropertyExists -Object $Request -Name 'action') -and -not [string]::IsNullOrWhiteSpace([string]$Request.action)) {
        [string]$Request.action
    }
    else {
        'state'
    }

    switch ($action) {
        'bootstrap' {
            return (Load-LWWebLastSave)
        }
        'state' {
            return 'State refreshed.'
        }
        'loadLastSave' {
            return (Load-LWWebLastSave)
        }
        'loadGame' {
            $path = if ((Test-LWPropertyExists -Object $Request -Name 'path') -and -not [string]::IsNullOrWhiteSpace([string]$Request.path)) { [string]$Request.path } else { '' }
            if ([string]::IsNullOrWhiteSpace($path)) {
                throw 'A save path is required.'
            }

            Load-LWGame -Path $path
            return ("Loaded save: {0}" -f (Split-Path -Leaf $path))
        }
        'saveGame' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            Save-LWGame
            return 'Saved current run.'
        }
        'setSection' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $section = if ((Test-LWPropertyExists -Object $Request -Name 'section') -and $null -ne $Request.section) { [int]$Request.section } else { 0 }
            if ($section -le 0) {
                throw 'A positive section number is required.'
            }

            Set-LWSection -Section $section
            return ("Moved to section {0}." -f $section)
        }
        'showScreen' {
            $name = if ((Test-LWPropertyExists -Object $Request -Name 'name') -and -not [string]::IsNullOrWhiteSpace([string]$Request.name)) { [string]$Request.name } else { '' }
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw 'A screen name is required.'
            }

            Set-LWScreen -Name $name
            return ("Showing screen: {0}" -f $name)
        }
        'safeCommand' {
            $commandText = if ((Test-LWPropertyExists -Object $Request -Name 'command') -and -not [string]::IsNullOrWhiteSpace([string]$Request.command)) { [string]$Request.command } else { '' }
            if (-not (Test-LWWebSafeCommand -InputLine $commandText)) {
                throw 'That command is not available through the web scaffold yet.'
            }

            [void](Invoke-LWCommand -InputLine $commandText)
            return ("Ran command: {0}" -f $commandText)
        }
        default {
            throw ("Unknown action: {0}" -f $action)
        }
    }
}

while ($true) {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) {
        break
    }

    $response = $null
    try {
        $request = if ([string]::IsNullOrWhiteSpace($line)) { [pscustomobject]@{ action = 'state' } } else { $line | ConvertFrom-Json }
        $message = Invoke-LWWebRequest -Request $request
        $response = [ordered]@{
            ok      = $true
            message = $message
            payload = Get-LWWebStateSnapshot
        }
    }
    catch {
        $response = [ordered]@{
            ok      = $false
            message = $_.Exception.Message
            payload = Get-LWWebStateSnapshot
        }
    }

    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 20))
    [Console]::Out.Flush()
}
