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

$script:LWWebPendingToken = '__LW_WEB_PENDING_PROMPT__'
$script:LWWebPromptReplay = [ordered]@{
    Active    = $false
    Responses = @()
    Index     = 0
    Pending   = $null
}
$script:LWWebFlow = $null

function Refresh-LWScreen {
    if ($null -ne $script:LWUi) {
        $script:LWUi.NeedsRender = $false
    }
}

function Copy-LWWebValue {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    $json = $Value | ConvertTo-Json -Depth 40
    if ([string]::IsNullOrWhiteSpace($json)) {
        return $null
    }

    return ($json | ConvertFrom-Json)
}

function New-LWWebCheckpoint {
    return [pscustomobject]@{
        GameState          = Copy-LWWebValue $script:GameState
        CurrentScreen      = if ($null -ne $script:LWUi) { [string]$script:LWUi.CurrentScreen } else { 'welcome' }
        ScreenData         = if ($null -ne $script:LWUi) { Copy-LWWebValue $script:LWUi.ScreenData } else { $null }
        Notifications      = if ($null -ne $script:LWUi -and $null -ne $script:LWUi.Notifications) { Copy-LWWebValue @($script:LWUi.Notifications) } else { @() }
        LastRenderedScreen = if ($null -ne $script:LWUi -and (Test-LWPropertyExists -Object $script:LWUi -Name 'LastRenderedScreen')) { [string]$script:LWUi.LastRenderedScreen } else { '' }
    }
}

function Restore-LWWebCheckpoint {
    param([Parameter(Mandatory = $true)][object]$Checkpoint)

    Set-LWHostGameState -State (Copy-LWWebValue $Checkpoint.GameState) | Out-Null
    if ($null -ne $script:LWUi) {
        $script:LWUi.CurrentScreen = [string]$Checkpoint.CurrentScreen
        $script:LWUi.ScreenData = Copy-LWWebValue $Checkpoint.ScreenData
        $script:LWUi.Notifications = @(
            foreach ($entry in @(Copy-LWWebValue $Checkpoint.Notifications)) {
                if ($null -eq $entry) { continue }
                $entry
            }
        )
        $script:LWUi.LastRenderedScreen = [string]$Checkpoint.LastRenderedScreen
        $script:LWUi.NeedsRender = $false
    }
}

function Start-LWWebPromptReplay {
    param([object[]]$Responses = @())

    $script:LWWebPromptReplay = [ordered]@{
        Active    = $true
        Responses = @($Responses)
        Index     = 0
        Pending   = $null
    }
}

function Stop-LWWebPromptReplay {
    $script:LWWebPromptReplay.Active = $false
    $script:LWWebPromptReplay.Responses = @()
    $script:LWWebPromptReplay.Index = 0
}

function New-LWWebPendingPrompt {
    param(
        [Parameter(Mandatory = $true)][string]$PromptType,
        [Parameter(Mandatory = $true)][string]$Prompt,
        $Default = $null,
        $Min = $null,
        $Max = $null
    )

    return [ordered]@{
        Mode       = 'prompt'
        PromptType = $PromptType
        Prompt     = $Prompt
        Default    = $Default
        Min        = $Min
        Max        = $Max
        FlowType   = if ($null -ne $script:LWWebFlow) { [string]$script:LWWebFlow.Type } else { '' }
        Step       = if ($null -ne $script:LWWebFlow) { [string]$script:LWWebFlow.Step } else { '' }
    }
}

function Get-LWWebQueuedResponse {
    param(
        [Parameter(Mandatory = $true)][string]$PromptType,
        [Parameter(Mandatory = $true)][string]$Prompt,
        $Default = $null,
        $Min = $null,
        $Max = $null
    )

    if (-not $script:LWWebPromptReplay.Active) {
        throw 'Interactive prompts are not available directly in the web session.'
    }

    if ($script:LWWebPromptReplay.Index -lt @($script:LWWebPromptReplay.Responses).Count) {
        $response = $script:LWWebPromptReplay.Responses[$script:LWWebPromptReplay.Index]
        $script:LWWebPromptReplay.Index++
        return $response
    }

    $script:LWWebPromptReplay.Pending = New-LWWebPendingPrompt -PromptType $PromptType -Prompt $Prompt -Default $Default -Min $Min -Max $Max
    throw [System.InvalidOperationException]::new($script:LWWebPendingToken)
}

function Test-LWWebPendingException {
    param([Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord)

    return $null -ne $ErrorRecord.Exception -and [string]$ErrorRecord.Exception.Message -eq $script:LWWebPendingToken
}

function Convert-LWWebResponseToString {
    param($Response)

    if ($null -eq $Response) {
        return ''
    }
    if ($Response -is [string]) {
        return $Response
    }
    if ($Response -is [bool]) {
        return $(if ($Response) { 'y' } else { 'n' })
    }
    if ($Response -is [int] -or $Response -is [long] -or $Response -is [double] -or $Response -is [decimal]) {
        return [string]$Response
    }
    if (($Response -is [pscustomobject] -or $Response -is [hashtable]) -and (Test-LWPropertyExists -Object $Response -Name 'value')) {
        return [string]$Response.value
    }

    if ($Response -is [System.Collections.IDictionary] -and $Response.Contains('value')) {
        return [string]$Response['value']
    }

    return [string]$Response
}

function Read-LWPromptLine {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [switch]$ReturnNullOnEof
    )

    $raw = Convert-LWWebResponseToString (Get-LWWebQueuedResponse -PromptType 'text' -Prompt $Prompt)
    if ([string]::IsNullOrWhiteSpace($raw) -and $ReturnNullOnEof) {
        return $null
    }

    return $raw
}

function Read-LWYesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [bool]$Default = $true
    )

    $raw = Convert-LWWebResponseToString (Get-LWWebQueuedResponse -PromptType 'yesno' -Prompt $Prompt -Default $Default)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    switch ($raw.Trim().ToLowerInvariant()) {
        'y' { return $true }
        'yes' { return $true }
        'true' { return $true }
        '1' { return $true }
        'on' { return $true }
        'n' { return $false }
        'no' { return $false }
        'false' { return $false }
        '0' { return $false }
        'off' { return $false }
        default { throw "Prompt '$Prompt' expected a yes/no response." }
    }
}

function Read-LWInlineYesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [bool]$Default = $true
    )

    return (Read-LWYesNo -Prompt $Prompt -Default $Default)
}

function Read-LWInt {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Nullable[int]]$Default = $null,
        [Nullable[int]]$Min = $null,
        [Nullable[int]]$Max = $null,
        [switch]$NoRefresh
    )

    $raw = Convert-LWWebResponseToString (Get-LWWebQueuedResponse -PromptType 'int' -Prompt $Prompt -Default $Default -Min $Min -Max $Max)
    if ([string]::IsNullOrWhiteSpace($raw) -and $null -ne $Default) {
        return [int]$Default
    }

    $value = 0
    if (-not [int]::TryParse($raw, [ref]$value)) {
        throw "Prompt '$Prompt' expected a whole number."
    }
    if ($null -ne $Min -and $value -lt $Min) {
        throw "Prompt '$Prompt' expected a value at least $Min."
    }
    if ($null -ne $Max -and $value -gt $Max) {
        throw "Prompt '$Prompt' expected a value at most $Max."
    }

    return $value
}

function Read-LWText {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [string]$Default = '',
        [switch]$NoRefresh
    )

    $raw = Convert-LWWebResponseToString (Get-LWWebQueuedResponse -PromptType 'text' -Prompt $Prompt -Default $Default)
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    return $raw.Trim()
}

function Invoke-LWWebSuppressedOperation {
    param([Parameter(Mandatory = $true)][scriptblock]$Operation)

    & $Operation 6>$null 5>$null 4>$null 3>$null 2>$null | Out-Null
}

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
                EnemyName   = if ((Test-LWPropertyExists -Object $entry -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$entry.EnemyName)) { [string]$entry.EnemyName } else { '' }
                Outcome     = if ((Test-LWPropertyExists -Object $entry -Name 'Outcome') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Outcome)) { [string]$entry.Outcome } else { '' }
                RoundCount  = if ((Test-LWPropertyExists -Object $entry -Name 'RoundCount') -and $null -ne $entry.RoundCount) { [int]$entry.RoundCount } else { 0 }
                Section     = if ((Test-LWPropertyExists -Object $entry -Name 'Section') -and $null -ne $entry.Section) { [int]$entry.Section } else { $null }
                BookNumber  = if ((Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and $null -ne $entry.BookNumber) { [int]$entry.BookNumber } else { $null }
                BookTitle   = if ((Test-LWPropertyExists -Object $entry -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$entry.BookTitle)) { [string]$entry.BookTitle } else { '' }
                Weapon      = if ((Test-LWPropertyExists -Object $entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Weapon)) { [string]$entry.Weapon } else { '' }
                CombatRatio = if ((Test-LWPropertyExists -Object $entry -Name 'CombatRatio') -and $null -ne $entry.CombatRatio) { [int]$entry.CombatRatio } else { 0 }
                EnemyEnd    = if ((Test-LWPropertyExists -Object $entry -Name 'EnemyEnd') -and $null -ne $entry.EnemyEnd) { [int]$entry.EnemyEnd } else { 0 }
                PlayerEnd   = if ((Test-LWPropertyExists -Object $entry -Name 'PlayerEnd') -and $null -ne $entry.PlayerEnd) { [int]$entry.PlayerEnd } else { 0 }
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

function Get-LWWebOptionEntries {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [string]$NameProperty = 'Name',
        [string]$DescriptionProperty = 'Description'
    )

    $options = @()
    for ($i = 0; $i -lt @($Items).Count; $i++) {
        $item = $Items[$i]
        if ($null -eq $item) {
            continue
        }

        $label = if ($item -is [string]) {
            [string]$item
        }
        elseif (Test-LWPropertyExists -Object $item -Name $NameProperty) {
            [string]$item.$NameProperty
        }
        else {
            [string]$item
        }

        $description = if ($item -isnot [string] -and (Test-LWPropertyExists -Object $item -Name $DescriptionProperty) -and -not [string]::IsNullOrWhiteSpace([string]$item.$DescriptionProperty)) {
            [string]$item.$DescriptionProperty
        }
        else {
            ''
        }

        $options += [ordered]@{
            Value       = ($i + 1)
            Label       = $label
            Description = $description
        }
    }

    return @($options)
}

function Get-LWWebRequiredMagnakaiCount {
    param([int]$BookNumber)
    return [Math]::Min(10, [Math]::Max(3, ($BookNumber - 3)))
}

function Ensure-LWWebFlowRolls {
    param([Parameter(Mandatory = $true)][object]$Flow)

    if ($null -eq $Flow.Data.CombatSkillRoll) {
        $Flow.Data.CombatSkillRoll = Get-LWRandomDigit
    }
    if ($null -eq $Flow.Data.EnduranceRoll) {
        $Flow.Data.EnduranceRoll = Get-LWRandomDigit
    }
    if (@($Flow.Data.KaiDisciplines).Count -gt 0 -and (@($Flow.Data.KaiDisciplines) -contains 'Weaponskill') -and $null -eq $Flow.Data.WeaponskillRoll) {
        $Flow.Data.WeaponskillRoll = Get-LWRandomDigit
        $Flow.Data.WeaponskillWeapon = Get-LWWeaponskillWeapon -Roll ([int]$Flow.Data.WeaponskillRoll)
    }
}

function New-LWWebFlowPrompt {
    param([Parameter(Mandatory = $true)][object]$Flow)

    $summary = [ordered]@{
        Difficulty = [string]$Flow.Data.Difficulty
        Permadeath = [bool]$Flow.Data.Permadeath
        Name       = [string]$Flow.Data.Name
        BookNumber = [int]$Flow.Data.BookNumber
        StartSection = [int]$Flow.Data.StartSection
    }

    switch ([string]$Flow.Step) {
        'replaceConfirm' {
            return [ordered]@{
                Active       = $true
                Type         = 'newGame'
                Step         = 'replaceConfirm'
                Mode         = 'confirm'
                Title        = 'Replace Current Run?'
                Description  = 'Starting a new game here will replace the active in-memory run. Your save files remain untouched unless you overwrite them later.'
                Prompt       = 'Start a fresh run in this session?'
                Default      = $false
                Summary      = $summary
                SubmitLabel  = 'Continue'
                CancelLabel  = 'Cancel'
            }
        }
        'runConfig' {
            return [ordered]@{
                Active      = $true
                Type        = 'newGame'
                Step        = 'runConfig'
                Mode        = 'runConfig'
                Title       = 'New Run Settings'
                Description = 'Choose the difficulty and optional permadeath settings for the new run.'
                Options     = @(
                    foreach ($entry in @(Get-LWDifficultyDefinitions)) {
                        [ordered]@{
                            Value             = [string]$entry.Name
                            Label             = [string]$entry.Name
                            Description       = [string]$entry.Description
                            PermadeathAllowed = [bool]$entry.PermadeathAllowed
                        }
                    }
                )
                SelectedDifficulty = [string]$Flow.Data.Difficulty
                SelectedPermadeath = [bool]$Flow.Data.Permadeath
                Summary     = $summary
                SubmitLabel = 'Next'
                CancelLabel = 'Cancel'
            }
        }
        'identity' {
            return [ordered]@{
                Active      = $true
                Type        = 'newGame'
                Step        = 'identity'
                Mode        = 'identity'
                Title       = 'Character Setup'
                Description = 'Set the character name, starting book, and opening section.'
                Values      = [ordered]@{
                    Name         = [string]$Flow.Data.Name
                    BookNumber   = [int]$Flow.Data.BookNumber
                    StartSection = [int]$Flow.Data.StartSection
                }
                BookOptions  = @(
                    foreach ($bookNumber in 1..7) {
                        [ordered]@{
                            Value = $bookNumber
                            Label = (Format-LWBookLabel -BookNumber $bookNumber -IncludePrefix)
                        }
                    }
                )
                Summary     = $summary
                SubmitLabel = 'Next'
                CancelLabel = 'Cancel'
            }
        }
        'kaiDisciplines' {
            $available = @($script:GameData.KaiDisciplines)
            return [ordered]@{
                Active        = $true
                Type          = 'newGame'
                Step          = 'kaiDisciplines'
                Mode          = 'selectMany'
                Title         = 'Choose Kai Disciplines'
                Description   = 'Select exactly 5 Kai Disciplines for this run.'
                SelectionKind = 'Kai Disciplines'
                RequiredCount = 5
                Options       = @(Get-LWWebOptionEntries -Items $available)
                Selected      = @($Flow.Data.KaiDisciplineIndices)
                Summary       = $summary
                SubmitLabel   = 'Next'
                CancelLabel   = 'Cancel'
            }
        }
        'magnakaiDisciplines' {
            $count = Get-LWWebRequiredMagnakaiCount -BookNumber ([int]$Flow.Data.BookNumber)
            $available = @($script:GameData.MagnakaiDisciplines)
            return [ordered]@{
                Active        = $true
                Type          = 'newGame'
                Step          = 'magnakaiDisciplines'
                Mode          = 'selectMany'
                Title         = 'Choose Magnakai Disciplines'
                Description   = ("Select exactly {0} Magnakai Disciplines for this run." -f $count)
                SelectionKind = 'Magnakai Disciplines'
                RequiredCount = $count
                Options       = @(Get-LWWebOptionEntries -Items $available)
                Selected      = @($Flow.Data.MagnakaiDisciplineIndices)
                Summary       = $summary
                SubmitLabel   = 'Next'
                CancelLabel   = 'Cancel'
            }
        }
        'weaponmastery' {
            $count = Get-LWWebRequiredMagnakaiCount -BookNumber ([int]$Flow.Data.BookNumber)
            $available = @(Get-LWMagnakaiWeaponmasteryOptions)
            return [ordered]@{
                Active        = $true
                Type          = 'newGame'
                Step          = 'weaponmastery'
                Mode          = 'selectMany'
                Title         = 'Choose Weaponmastery Weapons'
                Description   = ("Select exactly {0} mastered weapon(s)." -f $count)
                SelectionKind = 'Weaponmastery Weapons'
                RequiredCount = $count
                Options       = @(Get-LWWebOptionEntries -Items $available)
                Selected      = @($Flow.Data.WeaponmasteryIndices)
                Summary       = $summary
                SubmitLabel   = 'Next'
                CancelLabel   = 'Cancel'
            }
        }
        'startupEquipment' {
            return [ordered]@{
                Active      = $true
                Type        = 'newGame'
                Step        = 'startupEquipment'
                Mode        = 'prompt'
                Title       = 'Starting Equipment'
                Description = 'The book-specific startup package needs one more choice before the run can continue.'
                Summary     = $summary
                Prompt      = $Flow.PendingPrompt
                SubmitLabel = 'Continue'
                CancelLabel = 'Cancel'
            }
        }
        default {
            return $null
        }
    }
}

function Resolve-LWWebSelectedNames {
    param(
        [Parameter(Mandatory = $true)][int[]]$SelectedIndices,
        [Parameter(Mandatory = $true)][object[]]$AvailableItems,
        [Parameter(Mandatory = $true)][int]$RequiredCount,
        [string]$NameProperty = 'Name'
    )

    $items = @($AvailableItems)
    $unique = @($SelectedIndices | Sort-Object -Unique)
    if ($unique.Count -ne $RequiredCount) {
        throw "Select exactly $RequiredCount item(s)."
    }

    $resolved = @()
    foreach ($index in $unique) {
        if ($index -lt 1 -or $index -gt $items.Count) {
            throw 'One or more selected entries are out of range.'
        }

        $item = $items[$index - 1]
        if ($item -is [string]) {
            $resolved += [string]$item
        }
        else {
            $resolved += [string]$item.$NameProperty
        }
    }

    return @($resolved)
}

function New-LWWebFlow {
    param([string]$Type = 'newGame')

    $hasActiveState = Test-LWHasState
    $defaultName = if ($hasActiveState -and $null -ne $script:GameState.Character -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Character.Name)) {
        [string]$script:GameState.Character.Name
    }
    else {
        'Lone Wolf'
    }

    return [pscustomobject]@{
        Type         = $Type
        Step         = if ($hasActiveState) { 'replaceConfirm' } else { 'runConfig' }
        PendingPrompt = $null
        Checkpoint   = $null
        Data         = [pscustomobject]@{
            Difficulty                = 'Normal'
            Permadeath                = $false
            Name                      = $defaultName
            BookNumber                = 1
            StartSection              = 1
            KaiDisciplineIndices      = @()
            KaiDisciplines            = @()
            MagnakaiDisciplineIndices = @()
            MagnakaiDisciplines       = @()
            WeaponmasteryIndices      = @()
            WeaponmasteryWeapons      = @()
            CombatSkillRoll           = $null
            EnduranceRoll             = $null
            WeaponskillRoll           = $null
            WeaponskillWeapon         = $null
            StartupResponses          = @()
        }
    }
}

function Start-LWWebNewGameWizard {
    $script:LWWebFlow = New-LWWebFlow -Type 'newGame'
    return 'New game wizard started.'
}

function Complete-LWWebDisciplineSelection {
    param([Parameter(Mandatory = $true)][object]$Flow)

    if ([int]$Flow.Data.BookNumber -ge 6) {
        $requiredMagnakaiCount = Get-LWWebRequiredMagnakaiCount -BookNumber ([int]$Flow.Data.BookNumber)
        $selectedMagnakai = Resolve-LWWebSelectedNames -SelectedIndices @([int[]]$Flow.Data.MagnakaiDisciplineIndices) -AvailableItems @($script:GameData.MagnakaiDisciplines) -RequiredCount $requiredMagnakaiCount
        $Flow.Data.MagnakaiDisciplines = @($selectedMagnakai)
        if (@($selectedMagnakai) -contains 'Weaponmastery') {
            $Flow.Step = 'weaponmastery'
            return
        }
    }
    else {
        $selectedKai = Resolve-LWWebSelectedNames -SelectedIndices @([int[]]$Flow.Data.KaiDisciplineIndices) -AvailableItems @($script:GameData.KaiDisciplines) -RequiredCount 5
        $Flow.Data.KaiDisciplines = @($selectedKai)
    }

    $Flow.Step = 'startupEquipment'
}

function Initialize-LWWebNewGameBaseState {
    param([Parameter(Mandatory = $true)][object]$Flow)

    $stage = 'roll setup'
    try {
        Ensure-LWWebFlowRolls -Flow $Flow

        $stage = 'default state'
        Set-LWHostGameState -State (New-LWDefaultState) | Out-Null
        $script:GameState.Settings.CombatMode = (Get-LWDefaultCombatMode)
        $script:GameState.Run = (New-LWRunState -Difficulty ([string]$Flow.Data.Difficulty) -Permadeath ([bool]$Flow.Data.Permadeath))
        Set-LWScreen -Name 'sheet'
        Clear-LWNotifications

        $stage = 'core stats'
        $combatSkill = 10 + [int]$Flow.Data.CombatSkillRoll
        $endurance = 20 + [int]$Flow.Data.EnduranceRoll

        $script:GameState.Character.Name = [string]$Flow.Data.Name
        $script:GameState.Character.BookNumber = [int]$Flow.Data.BookNumber
        $script:GameState.Character.CombatSkillBase = $combatSkill
        $script:GameState.Character.EnduranceCurrent = $endurance
        $script:GameState.Character.EnduranceMax = $endurance
        $script:GameState.CurrentSection = [int]$Flow.Data.StartSection

        Write-LWInfo ("Combat Skill roll: {0} -> {1}" -f ([int]$Flow.Data.CombatSkillRoll), $combatSkill)
        Write-LWInfo ("Endurance roll: {0} -> {1}" -f ([int]$Flow.Data.EnduranceRoll), $endurance)

        if ([int]$Flow.Data.BookNumber -ge 6) {
            $stage = 'magnakai setup'
            $requiredMagnakaiCount = Get-LWWebRequiredMagnakaiCount -BookNumber ([int]$Flow.Data.BookNumber)
            $script:GameState.RuleSet = 'Magnakai'
            $script:GameState.Character.LegacyKaiComplete = $true
            $script:GameState.Character.MagnakaiDisciplines = @($Flow.Data.MagnakaiDisciplines)
            $script:GameState.Character.MagnakaiRank = $requiredMagnakaiCount
            if (@($Flow.Data.MagnakaiDisciplines) -contains 'Weaponmastery') {
                $script:GameState.Character.WeaponmasteryWeapons = @($Flow.Data.WeaponmasteryWeapons)
                Write-LWInfo ("Weaponmastery selection: {0}" -f (@($Flow.Data.WeaponmasteryWeapons) -join ', '))
            }
            Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages
        }
        else {
            $stage = 'kai setup'
            $script:GameState.Character.Disciplines = @($Flow.Data.KaiDisciplines)
            if (@($Flow.Data.KaiDisciplines) -contains 'Weaponskill') {
                $script:GameState.Character.WeaponskillWeapon = [string]$Flow.Data.WeaponskillWeapon
                Write-LWInfo ("Weaponskill roll: {0} -> {1}" -f ([int]$Flow.Data.WeaponskillRoll), [string]$Flow.Data.WeaponskillWeapon)
            }
        }
    }
    catch {
        throw ("Web new-game initialization failed during {0}: {1}" -f $stage, $_.Exception.Message)
    }
}

function Invoke-LWWebStartingEquipmentPhase {
    param([Parameter(Mandatory = $true)][object]$Flow)

    if ($null -eq $Flow.Checkpoint) {
        Initialize-LWWebNewGameBaseState -Flow $Flow
        $Flow.Checkpoint = New-LWWebCheckpoint
    }

    Restore-LWWebCheckpoint -Checkpoint $Flow.Checkpoint
    Start-LWWebPromptReplay -Responses @($Flow.Data.StartupResponses)

    try {
        switch ([int]$Flow.Data.BookNumber) {
            1 { Invoke-LWWebSuppressedOperation { Apply-LWBookOneStartingEquipment } }
            2 { Invoke-LWWebSuppressedOperation { Apply-LWBookTwoStartingEquipment } }
            3 { Invoke-LWWebSuppressedOperation { Apply-LWBookThreeStartingEquipment } }
            4 { Invoke-LWWebSuppressedOperation { Apply-LWBookFourStartingEquipment } }
            5 { Invoke-LWWebSuppressedOperation { Apply-LWBookFiveStartingEquipment } }
            6 { Invoke-LWWebSuppressedOperation { Apply-LWBookSixStartingEquipment } }
            7 { Invoke-LWWebSuppressedOperation { Apply-LWBookSevenStartingEquipment } }
            default { throw 'Unsupported starting book.' }
        }

        $script:GameState.SectionHadCombat = $false
        $script:GameState.SectionHealingResolved = $false
        Clear-LWDeathState
        Reset-LWCurrentBookStats -BookNumber ([int]$Flow.Data.BookNumber) -StartSection ([int]$Flow.Data.StartSection) | Out-Null
        Reset-LWSectionCheckpoints -SeedCurrentSection | Out-Null
        Sync-LWRunIntegrityState -State $script:GameState -Reseal | Out-Null
        Warm-LWRuntimeCaches | Out-Null
        Set-LWScreen -Name 'sheet'
        Write-LWInfo ("New {0} run created." -f [string]$Flow.Data.Difficulty)
        if ([bool]$Flow.Data.Permadeath) {
            Write-LWWarn 'Permadeath is locked on for this run.'
        }

        Stop-LWWebPromptReplay
        $script:LWWebFlow = $null
        return 'New run created.'
    }
    catch {
        Stop-LWWebPromptReplay
        if (Test-LWWebPendingException -ErrorRecord $_) {
            $Flow.PendingPrompt = Copy-LWWebValue $script:LWWebPromptReplay.Pending
            return 'Additional starting-equipment input is required.'
        }

        throw
    }
}

function Submit-LWWebFlow {
    param([object]$Data = $null)

    if ($null -eq $script:LWWebFlow) {
        throw 'No active web flow exists.'
    }

    $flow = $script:LWWebFlow
    $step = [string]$flow.Step

    switch ($step) {
        'replaceConfirm' {
            $confirm = [bool]($Data.confirm)
            if (-not $confirm) {
                $script:LWWebFlow = $null
                return 'New game cancelled.'
            }

            $flow.Step = 'runConfig'
            return 'Replace confirmed.'
        }
        'runConfig' {
            $difficulty = Get-LWNormalizedDifficultyName -Difficulty ([string]$Data.difficulty)
            $definition = Get-LWDifficultyDefinition -Difficulty $difficulty
            if ($null -eq $definition) {
                throw 'Choose a valid difficulty.'
            }

            $permadeath = [bool]$Data.permadeath
            if (-not [bool]$definition.PermadeathAllowed) {
                $permadeath = $false
            }

            $flow.Data.Difficulty = [string]$difficulty
            $flow.Data.Permadeath = [bool]$permadeath
            $flow.Step = 'identity'
            return 'Run settings saved.'
        }
        'identity' {
            $name = [string]$Data.name
            if ([string]::IsNullOrWhiteSpace($name)) {
                $name = 'Lone Wolf'
            }

            $bookNumber = [int]$Data.bookNumber
            $startSection = [int]$Data.startSection
            if ($bookNumber -lt 1 -or $bookNumber -gt 7) {
                throw 'Starting book must be between 1 and 7.'
            }
            if ($startSection -lt 1) {
                throw 'Starting section must be at least 1.'
            }

            $flow.Data.Name = $name.Trim()
            $flow.Data.BookNumber = $bookNumber
            $flow.Data.StartSection = $startSection
            $flow.PendingPrompt = $null
            $flow.Checkpoint = $null

            if ($bookNumber -ge 6) {
                $flow.Step = 'magnakaiDisciplines'
            }
            else {
                $flow.Step = 'kaiDisciplines'
            }

            return 'Character setup saved.'
        }
        'kaiDisciplines' {
            $selected = @([int[]]$Data.selected)
            $flow.Data.KaiDisciplineIndices = @($selected)
            Complete-LWWebDisciplineSelection -Flow $flow
            return 'Kai disciplines saved.'
        }
        'magnakaiDisciplines' {
            $selected = @([int[]]$Data.selected)
            $flow.Data.MagnakaiDisciplineIndices = @($selected)
            Complete-LWWebDisciplineSelection -Flow $flow
            return 'Magnakai disciplines saved.'
        }
        'weaponmastery' {
            $selected = @([int[]]$Data.selected)
            $requiredCount = Get-LWWebRequiredMagnakaiCount -BookNumber ([int]$flow.Data.BookNumber)
            $resolved = Resolve-LWWebSelectedNames -SelectedIndices @($selected) -AvailableItems @(Get-LWMagnakaiWeaponmasteryOptions) -RequiredCount $requiredCount
            $flow.Data.WeaponmasteryIndices = @($selected)
            $flow.Data.WeaponmasteryWeapons = @($resolved)
            $flow.Step = 'startupEquipment'
            return 'Weaponmastery choices saved.'
        }
        'startupEquipment' {
            $response = $null
            if ($null -ne $Data) {
                if (Test-LWPropertyExists -Object $Data -Name 'response') {
                    $response = $Data.response
                }
                elseif ($Data -is [System.Collections.IDictionary] -and $Data.Contains('response')) {
                    $response = $Data['response']
                }
            }
            $flow.Data.StartupResponses = @($flow.Data.StartupResponses + @($response))
            return (Invoke-LWWebStartingEquipmentPhase -Flow $flow)
        }
        default {
            throw "Unknown web flow step: $step"
        }
    }
}

function Cancel-LWWebFlow {
    $script:LWWebFlow = $null
    return 'Web flow cancelled.'
}

function Get-LWWebStateSnapshot {
    $stage = 'screen metadata'
    try {
        $screenName = if ($null -ne $script:LWUi -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.CurrentScreen)) {
            [string]$script:LWUi.CurrentScreen
        }
        else {
            [string](Get-LWDefaultScreen)
        }

        $screenData = if ($null -ne $script:LWUi) { $script:LWUi.ScreenData } else { $null }
        $notifications = if ($null -ne $script:LWUi -and $null -ne $script:LWUi.Notifications) { @($script:LWUi.Notifications) } else { @() }

        $stage = 'pending flow'
        $pendingFlow = if ($null -ne $script:LWWebFlow) { New-LWWebFlowPrompt -Flow $script:LWWebFlow } else { $null }

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
                pendingFlow      = $pendingFlow
                availableScreens = @('welcome', 'sheet', 'inventory', 'disciplines', 'notes', 'history', 'stats', 'campaign', 'achievements', 'combat', 'combatlog', 'bookcomplete', 'help')
            }
        }

        $stage = 'active state metadata'
        $bookNumber = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 1 }
        $section = if ($null -ne $script:GameState.CurrentSection) { [int]$script:GameState.CurrentSection } else { 1 }
        $bookTitle = [string](Get-LWBookTitle -BookNumber $bookNumber)
        $inventory = $script:GameState.Inventory
        $character = $script:GameState.Character
        $combat = $script:GameState.Combat

        $stage = 'active state payload'
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
                Active                        = [bool]$combat.Active
                EnemyName                     = if ((Test-LWPropertyExists -Object $combat -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$combat.EnemyName)) { [string]$combat.EnemyName } else { '' }
                EnemyCombatSkill              = if ($null -ne $combat.EnemyCombatSkill) { [int]$combat.EnemyCombatSkill } else { 0 }
                EnemyEnduranceCurrent         = if ($null -ne $combat.EnemyEnduranceCurrent) { [int]$combat.EnemyEnduranceCurrent } else { 0 }
                EnemyEnduranceMax             = if ($null -ne $combat.EnemyEnduranceMax) { [int]$combat.EnemyEnduranceMax } else { 0 }
                UseMindblast                  = [bool]$combat.UseMindblast
                EquippedWeapon                = if ((Test-LWPropertyExists -Object $combat -Name 'EquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$combat.EquippedWeapon)) { [string]$combat.EquippedWeapon } else { '' }
                CanEvade                      = [bool]$combat.CanEvade
                MindblastCombatSkillBonus     = if ((Test-LWPropertyExists -Object $combat -Name 'MindblastCombatSkillBonus') -and $null -ne $combat.MindblastCombatSkillBonus) { [int]$combat.MindblastCombatSkillBonus } else { 0 }
                PlayerEnduranceLossMultiplier = if ((Test-LWPropertyExists -Object $combat -Name 'PlayerEnduranceLossMultiplier') -and $null -ne $combat.PlayerEnduranceLossMultiplier) { [int]$combat.PlayerEnduranceLossMultiplier } else { 1 }
                Log                           = @($combat.Log)
            }
            notes            = @($character.Notes)
            history          = @(Get-LWWebHistoryPreview -History @($script:GameState.History))
            currentBookStats = if ($null -ne $script:GameState.CurrentBookStats) { $script:GameState.CurrentBookStats } else { $null }
            campaign         = Get-LWWebCampaignSnapshot
            saves            = @(Get-LWWebSaveEntries)
            pendingFlow      = $pendingFlow
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
    catch {
        throw ("Web state snapshot failed during {0}: {1}" -f $stage, $_.Exception.Message)
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

    $script:LWWebFlow = $null
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

            $script:LWWebFlow = $null
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
        'startNewGameWizard' {
            return (Start-LWWebNewGameWizard)
        }
        'submitFlow' {
            $data = if ((Test-LWPropertyExists -Object $Request -Name 'data')) { $Request.data } else { $null }
            return (Submit-LWWebFlow -Data $data)
        }
        'cancelFlow' {
            return (Cancel-LWWebFlow)
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

    [Console]::Out.WriteLine(($response | ConvertTo-Json -Compress -Depth 30))
    [Console]::Out.Flush()
}
