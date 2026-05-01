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
$script:LWWebOriginalGetRandomDigit = (Get-Command -Name 'Get-LWRandomDigit' -CommandType Function).ScriptBlock
$script:LWWebPromptReplay = [ordered]@{
    Active          = $false
    Responses       = @()
    Index           = 0
    Pending         = $null
    ContextOverride = ''
}
$script:LWWebRandomReplay = [ordered]@{
    Active    = $false
    Values    = @()
    Index     = 0
    Generated = @()
}
$script:LWWebFlow = $null
$script:LWWebLastRoll = $null
$script:LWWebHostCapture = [ordered]@{
    Active      = $false
    CurrentLine = ''
    Lines       = @()
}

function Write-Host {
    [CmdletBinding(DefaultParameterSetName = 'NoObject', RemotingCapability = 'None')]
    param(
        [Parameter(ParameterSetName = 'Object', Position = 0, ValueFromRemainingArguments = $true)]
        [object[]]$Object,
        [ConsoleColor]$ForegroundColor,
        [ConsoleColor]$BackgroundColor,
        [switch]$NoNewline,
        [object]$Separator
    )

    if ($script:LWWebHostCapture.Active) {
        $separatorText = if ($PSBoundParameters.ContainsKey('Separator') -and $null -ne $Separator) { [string]$Separator } else { ' ' }
        $text = if ($null -eq $Object) { '' } else { (@($Object) | ForEach-Object { [string]$_ }) -join $separatorText }
        $script:LWWebHostCapture.CurrentLine = [string]$script:LWWebHostCapture.CurrentLine + $text
        if (-not $NoNewline) {
            $script:LWWebHostCapture.Lines = @($script:LWWebHostCapture.Lines + @([string]$script:LWWebHostCapture.CurrentLine))
            $script:LWWebHostCapture.CurrentLine = ''
        }
        return
    }

    Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
}

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
        Active          = $true
        Responses       = @($Responses)
        Index           = 0
        Pending         = $null
        ContextOverride = ''
    }
}

function Stop-LWWebPromptReplay {
    $script:LWWebPromptReplay.Active = $false
    $script:LWWebPromptReplay.Responses = @()
    $script:LWWebPromptReplay.Index = 0
}

function Set-LWWebPendingContextOverride {
    param([string]$ContextText = '')

    if ($script:LWWebPromptReplay.Active -and -not [string]::IsNullOrWhiteSpace($ContextText)) {
        $script:LWWebPromptReplay.ContextOverride = [string]$ContextText
    }
}

function Start-LWWebRandomReplay {
    param([int[]]$Values = @())

    $script:LWWebRandomReplay = [ordered]@{
        Active    = $true
        Values    = @($Values)
        Index     = 0
        Generated = @()
    }
}

function Stop-LWWebRandomReplay {
    $generated = @($script:LWWebRandomReplay.Generated)
    $script:LWWebRandomReplay = [ordered]@{
        Active    = $false
        Values    = @()
        Index     = 0
        Generated = @()
    }

    return @($generated)
}

function Get-LWRandomDigit {
    if ($script:LWWebRandomReplay.Active) {
        if ($script:LWWebRandomReplay.Index -lt @($script:LWWebRandomReplay.Values).Count) {
            $value = [int]$script:LWWebRandomReplay.Values[$script:LWWebRandomReplay.Index]
            $script:LWWebRandomReplay.Index++
            return $value
        }

        $value = & $script:LWWebOriginalGetRandomDigit
        $script:LWWebRandomReplay.Generated = @($script:LWWebRandomReplay.Generated + @([int]$value))
        $script:LWWebRandomReplay.Index++
        return [int]$value
    }

    return (& $script:LWWebOriginalGetRandomDigit)
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

function Start-LWWebHostCapture {
    $script:LWWebHostCapture.Active = $true
    $script:LWWebHostCapture.CurrentLine = ''
    $script:LWWebHostCapture.Lines = @()
}

function Stop-LWWebHostCapture {
    if ($script:LWWebHostCapture.Active -and -not [string]::IsNullOrEmpty([string]$script:LWWebHostCapture.CurrentLine)) {
        $script:LWWebHostCapture.Lines = @($script:LWWebHostCapture.Lines + @([string]$script:LWWebHostCapture.CurrentLine))
    }

    $lines = @($script:LWWebHostCapture.Lines)
    $script:LWWebHostCapture.Active = $false
    $script:LWWebHostCapture.CurrentLine = ''
    $script:LWWebHostCapture.Lines = @()
    return @($lines)
}

function Invoke-LWWebCapturedOperation {
    param([Parameter(Mandatory = $true)][scriptblock]$Operation)

    $captured = [System.Collections.ArrayList]::new()
    $transcriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("lw-web-capture-{0}.log" -f ([guid]::NewGuid().ToString('N')))
    $transcriptStarted = $false
    Start-LWWebHostCapture
    try {
        try {
            Start-Transcript -Path $transcriptPath -Force | Out-Null
            $transcriptStarted = $true
        }
        catch {
        }

        & $Operation 6>&1 5>&1 4>&1 3>&1 2>&1 | ForEach-Object {
            [void]$captured.Add($_)
        }
    }
    finally {
        if ($transcriptStarted) {
            try {
                Stop-Transcript | Out-Null
            }
            catch {
            }
        }
        foreach ($line in @(Stop-LWWebHostCapture)) {
            [void]$captured.Add([string]$line)
        }
        foreach ($line in @(Get-LWWebTranscriptLines -Path $transcriptPath)) {
            [void]$captured.Add([string]$line)
        }
        if (Test-Path -LiteralPath $transcriptPath) {
            Remove-Item -LiteralPath $transcriptPath -Force -ErrorAction SilentlyContinue
        }
    }

    return @($captured)
}

function Convert-LWWebOutputRecordsToText {
    param([object[]]$Records = @())

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($record in @($Records)) {
        if ($null -eq $record) {
            continue
        }

        $text = switch ($record.GetType().FullName) {
            'System.Management.Automation.InformationRecord' { [string]$record.MessageData; break }
            'System.Management.Automation.WarningRecord' { [string]$record.Message; break }
            'System.Management.Automation.VerboseRecord' { [string]$record.Message; break }
            'System.Management.Automation.DebugRecord' { [string]$record.Message; break }
            'System.Management.Automation.ErrorRecord' { [string]$record; break }
            default { [string]$record; break }
        }

        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }

        foreach ($line in @($text -split "`r?`n")) {
            $cleanLine = [regex]::Replace([string]$line, "`e\[[0-9;?]*[ -/]*[@-~]", '')
            if ([string]::IsNullOrWhiteSpace($cleanLine)) {
                continue
            }
            $lines.Add($cleanLine)
        }
    }

    return ($lines -join [Environment]::NewLine).Trim()
}

function Get-LWWebTranscriptLines {
    param([string]$Path = '')

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $metadataPrefixes = @(
        'PowerShell transcript ',
        'Start time:',
        'End time:',
        'Username:',
        'RunAs User:',
        'Configuration Name:',
        'Machine:',
        'Host Application:',
        'Process ID:',
        'PSVersion:',
        'PSEdition:',
        'GitCommitId:',
        'OS:',
        'Platform:',
        'PSCompatibleVersions:',
        'PSRemotingProtocolVersion:',
        'SerializationVersion:',
        'WSManStackVersion:'
    )

    $escapePattern = ([regex]::Escape([string][char]27) + '\[[0-9;]*m')
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($rawLine in @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)) {
        $line = [string]$rawLine
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $line = [regex]::Replace($line, $escapePattern, '')
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed -eq '**********************') {
            continue
        }
        if ($metadataPrefixes | Where-Object { $trimmed.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }) {
            continue
        }
        if ($lines.Count -gt 0 -and [string]$lines[$lines.Count - 1] -eq $trimmed) {
            continue
        }

        $lines.Add($trimmed)
    }

    return @($lines)
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

function Get-LWWebBookPageUrl {
    param(
        [int]$BookNumber,
        [Parameter(Mandatory = $true)][string]$PageName,
        [string]$Fragment = ''
    )

    if ($BookNumber -le 0 -or [string]::IsNullOrWhiteSpace($PageName)) {
        return '/web/frontend/library.html'
    }

    $folders = Get-LWWebBookFolders
    if (-not $folders.ContainsKey($BookNumber)) {
        return '/web/frontend/library.html'
    }

    $safePageName = Split-Path -Leaf $PageName
    $url = ('/books/{0}/{1}' -f $folders[$BookNumber], $safePageName)
    if (-not [string]::IsNullOrWhiteSpace($Fragment)) {
        $url += ('#{0}' -f $Fragment.TrimStart('#'))
    }

    return $url
}

function Get-LWWebReaderTarget {
    param(
        [int]$BookNumber,
        [int]$Section,
        [object]$PendingFlow = $null
    )

    $targetBook = $BookNumber
    $targetSection = $Section
    $url = Get-LWWebReaderUrl -BookNumber $targetBook -Section $targetSection
    $locationLabel = if ($targetSection -gt 0) { "Section $targetSection" } else { 'Library' }

    if ($null -ne $script:LWWebFlow -and $null -ne $PendingFlow) {
        $flowType = Get-LWWebOptionalString -Object $script:LWWebFlow -Name 'Type'
        $flowStep = Get-LWWebOptionalString -Object $script:LWWebFlow -Name 'Step'
        $flowBook = if ($null -ne $script:LWWebFlow.Data -and
            (Test-LWPropertyExists -Object $script:LWWebFlow.Data -Name 'BookNumber') -and
            [int]$script:LWWebFlow.Data.BookNumber -gt 0) {
            [int]$script:LWWebFlow.Data.BookNumber
        }
        else {
            $targetBook
        }
        $promptKind = Get-LWWebOptionalString -Object $PendingFlow -Name 'PromptKind'

        if ($flowType -eq 'continueBook' -or ($flowType -eq 'newGame' -and $flowStep -eq 'startupEquipment')) {
            $targetBook = $flowBook
            switch ($promptKind) {
                'disciplineChoice' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'discplnz.htm'
                    $locationLabel = 'Magnakai Disciplines'
                }
                'weaponmasteryChoice' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'discplnz.htm' -Fragment 'wpnmstry'
                    $locationLabel = 'Weaponmastery'
                }
                'safekeepingMenu' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm' -Fragment 'howmuch'
                    $locationLabel = 'Equipment Capacity'
                }
                'safekeepingStore' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm' -Fragment 'howmuch'
                    $locationLabel = 'Equipment Capacity'
                }
                'safekeepingReclaim' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm' -Fragment 'howmuch'
                    $locationLabel = 'Equipment Capacity'
                }
                'makeRoomConfirm' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm' -Fragment 'howmuch'
                    $locationLabel = 'Equipment Capacity'
                }
                'inventoryManageStart' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm' -Fragment 'howmuch'
                    $locationLabel = 'Equipment Capacity'
                }
                'inventoryManageContinue' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm' -Fragment 'howmuch'
                    $locationLabel = 'Equipment Capacity'
                }
                'startingGearChoice' {
                    $url = Get-LWWebBookPageUrl -BookNumber $targetBook -PageName 'equipmnt.htm'
                    $locationLabel = 'Equipment'
                }
                default {
                    if ($targetBook -gt 0 -and $targetSection -gt 0) {
                        $url = Get-LWWebReaderUrl -BookNumber $targetBook -Section $targetSection
                        $locationLabel = "Section $targetSection"
                    }
                }
            }
        }
    }

    return [ordered]@{
        BookNumber    = $targetBook
        BookTitle     = if ($targetBook -gt 0) { [string](Get-LWBookTitle -BookNumber $targetBook) } else { '' }
        Section       = $targetSection
        Url           = $url
        LocationLabel = $locationLabel
    }
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

    return (Copy-LWWebValue (Get-LWCampaignSummary))
}

function Get-LWWebDeathSnapshot {
    if ($null -eq $script:GameState) {
        return $null
    }

    $deathState = Get-LWActiveDeathState
    if ($null -eq $deathState) {
        return $null
    }

    $bookNumber = if ((Test-LWPropertyExists -Object $deathState -Name 'BookNumber') -and $null -ne $deathState.BookNumber) {
        [int]$deathState.BookNumber
    }
    elseif ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.BookNumber) {
        [int]$script:GameState.Character.BookNumber
    }
    else {
        0
    }

    $bookTitle = if ((Test-LWPropertyExists -Object $deathState -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$deathState.BookTitle)) {
        [string]$deathState.BookTitle
    }
    elseif ($bookNumber -gt 0) {
        [string](Get-LWBookTitle -BookNumber $bookNumber)
    }
    else {
        ''
    }

    $savePath = if ((Test-LWPropertyExists -Object $script:GameState.Settings -Name 'SavePath') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Settings.SavePath)) {
        [string]$script:GameState.Settings.SavePath
    }
    else {
        ''
    }

    return [ordered]@{
        Active            = $true
        Type              = if ((Test-LWPropertyExists -Object $deathState -Name 'Type') -and -not [string]::IsNullOrWhiteSpace([string]$deathState.Type)) { [string]$deathState.Type } else { 'Instant' }
        Cause             = if ((Test-LWPropertyExists -Object $deathState -Name 'Cause') -and -not [string]::IsNullOrWhiteSpace([string]$deathState.Cause)) { [string]$deathState.Cause } else { 'A fatal choice ended this path.' }
        BookNumber        = $bookNumber
        BookTitle         = $bookTitle
        Section           = if ((Test-LWPropertyExists -Object $deathState -Name 'Section') -and $null -ne $deathState.Section) { [int]$deathState.Section } else { $null }
        RecordedOn        = if ((Test-LWPropertyExists -Object $deathState -Name 'RecordedOn') -and $null -ne $deathState.RecordedOn) { [string]$deathState.RecordedOn } else { '' }
        CharacterName     = if ($null -ne $script:GameState.Character -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Character.Name)) { [string]$script:GameState.Character.Name } else { '' }
        Difficulty        = [string](Get-LWCurrentDifficulty)
        PermadeathEnabled = [bool](Test-LWPermadeathEnabled)
        AvailableRewinds  = [int](Get-LWAvailableRewindCount)
        CombatSkill       = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.CombatSkillBase) { [int]$script:GameState.Character.CombatSkillBase } else { 0 }
        EnduranceCurrent  = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.EnduranceCurrent) { [int]$script:GameState.Character.EnduranceCurrent } else { 0 }
        EnduranceMax      = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.EnduranceMax) { [int]$script:GameState.Character.EnduranceMax } else { 0 }
        GoldCrowns        = if ($null -ne $script:GameState.Inventory -and $null -ne $script:GameState.Inventory.GoldCrowns) { [int]$script:GameState.Inventory.GoldCrowns } else { 0 }
        IntegrityState    = if ((Test-LWPropertyExists -Object $script:GameState -Name 'Run') -and $null -ne $script:GameState.Run -and (Test-LWPropertyExists -Object $script:GameState.Run -Name 'IntegrityState') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityState)) { [string]$script:GameState.Run.IntegrityState } else { '' }
        SavePath          = $savePath
    }
}

function Get-LWWebAchievementEntrySnapshot {
    param([Parameter(Mandatory = $true)][object]$Definition)

    $id = if ((Test-LWPropertyExists -Object $Definition -Name 'Id') -and -not [string]::IsNullOrWhiteSpace([string]$Definition.Id)) {
        [string]$Definition.Id
    }
    else {
        ''
    }

    if ([string]::IsNullOrWhiteSpace($id)) {
        return $null
    }

    $unlocked = [bool](Test-LWAchievementUnlocked -Id $id)
    $available = [bool](Test-LWAchievementAvailableInCurrentMode -Definition $Definition)
    $progressText = if (-not $unlocked) { [string](Get-LWAchievementProgressText -Definition $Definition) } else { '' }

    return [ordered]@{
        Id                 = $id
        Name               = if ($unlocked) { [string](Get-LWAchievementDisplayNameById -Id $id -DefaultName ([string]$Definition.Name)) } else { [string](Get-LWAchievementLockedDisplayName -Definition $Definition) }
        Category           = if ((Test-LWPropertyExists -Object $Definition -Name 'Category') -and -not [string]::IsNullOrWhiteSpace([string]$Definition.Category)) { [string]$Definition.Category } else { '' }
        Description        = if ($unlocked) { [string]$Definition.Description } else { [string](Get-LWAchievementLockedDisplayDescription -Definition $Definition) }
        BookNumber         = if ((Test-LWPropertyExists -Object $Definition -Name 'BookNumber') -and $null -ne $Definition.BookNumber) { [int]$Definition.BookNumber } else { $null }
        Hidden             = [bool]((Test-LWPropertyExists -Object $Definition -Name 'Hidden') -and [bool]$Definition.Hidden)
        Unlocked           = $unlocked
        AvailableInMode    = $available
        AvailabilityReason = if ($available) { '' } else { [string](Get-LWAchievementAvailabilityReason -Definition $Definition) }
        Progress           = if ([string]::IsNullOrWhiteSpace($progressText)) { '' } else { $progressText }
    }
}

function Get-LWWebAchievementBookTotals {
    if ($null -eq $script:GameState -or $null -eq $script:GameState.Character) {
        return @()
    }

    $currentBook = if ($null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 1 }
    $completedBooks = if ($null -ne $script:GameState.Character.CompletedBooks) { @($script:GameState.Character.CompletedBooks) } else { @() }

    return @(
        foreach ($bookNumber in @(1..$currentBook)) {
            $definitions = @(Get-LWAchievementBookDisplayDefinitions -BookNumber $bookNumber)
            if ($definitions.Count -eq 0) {
                continue
            }

            $unlockedCount = 0
            foreach ($definition in $definitions) {
                if ($null -ne $definition -and (Test-LWAchievementUnlocked -Id ([string]$definition.Id))) {
                    $unlockedCount++
                }
            }

            [ordered]@{
                BookNumber    = $bookNumber
                BookTitle     = [string](Get-LWBookTitle -BookNumber $bookNumber)
                UnlockedCount = $unlockedCount
                TotalCount    = @($definitions).Count
                Completed     = [bool]($completedBooks -contains $bookNumber)
                Current       = ($bookNumber -eq $currentBook)
            }
        }
    )
}

function Get-LWWebAchievementSnapshot {
    if ($null -eq $script:GameState -or $null -eq $script:GameState.Character) {
        return $null
    }

    $currentBook = if ($null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 1 }
    $currentBookDefinitions = @(Get-LWAchievementBookDisplayDefinitions -BookNumber $currentBook)
    $currentBookEntries = @(
        foreach ($definition in $currentBookDefinitions) {
            $entry = Get-LWWebAchievementEntrySnapshot -Definition $definition
            if ($null -ne $entry) {
                $entry
            }
        }
    )

    $recentUnlocks = @(
        foreach ($entry in @((Get-LWAchievementRecentUnlocks) | Sort-Object -Property UnlockedOn -Descending)) {
            if ($null -eq $entry) {
                continue
            }

            [ordered]@{
                Id          = if ((Test-LWPropertyExists -Object $entry -Name 'Id') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Id)) { [string]$entry.Id } else { '' }
                Name        = if ((Test-LWPropertyExists -Object $entry -Name 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Name)) { [string]$entry.Name } else { '' }
                Category    = if ((Test-LWPropertyExists -Object $entry -Name 'Category') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Category)) { [string]$entry.Category } else { '' }
                Description = if ((Test-LWPropertyExists -Object $entry -Name 'Description') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Description)) { [string]$entry.Description } else { '' }
                BookNumber  = if ((Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and $null -ne $entry.BookNumber) { [int]$entry.BookNumber } else { $null }
                Section     = if ((Test-LWPropertyExists -Object $entry -Name 'Section') -and $null -ne $entry.Section) { [int]$entry.Section } else { $null }
                UnlockedOn  = if ((Test-LWPropertyExists -Object $entry -Name 'UnlockedOn') -and $null -ne $entry.UnlockedOn) { ([datetime]$entry.UnlockedOn).ToString('s') } else { '' }
            }
        }
    )

    $currentBookUnlocked = @($currentBookEntries | Where-Object { $_.Unlocked }).Count
    $currentBookAvailable = @($currentBookEntries | Where-Object { $_.AvailableInMode }).Count
    $currentBookProgress = @($currentBookEntries | Where-Object { -not $_.Unlocked -and -not [string]::IsNullOrWhiteSpace([string]$_.Progress) })

    return [ordered]@{
        CurrentBookNumber      = $currentBook
        CurrentBookTitle       = [string](Get-LWBookTitle -BookNumber $currentBook)
        UnlockedCount          = [int](Get-LWAchievementUnlockedCount)
        AvailableCount         = [int](Get-LWAchievementAvailableCount)
        ProfileUnlockedCount   = @($script:GameState.Achievements.Unlocked).Count
        ProfileAvailableCount  = @(Get-LWAchievementDefinitions).Count
        CurrentBookUnlocked    = $currentBookUnlocked
        CurrentBookAvailable   = $currentBookAvailable
        CurrentBookTotal       = @($currentBookEntries).Count
        CurrentBookEntries     = @($currentBookEntries)
        CurrentBookProgress    = @($currentBookProgress)
        RecentUnlocks          = @($recentUnlocks)
        BookTotals             = @(Get-LWWebAchievementBookTotals)
    }
}

function Convert-LWWebDisciplineDefinition {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [string[]]$SelectedNames = @()
    )

    $name = if ($Definition -is [string]) {
        [string]$Definition
    }
    elseif (Test-LWPropertyExists -Object $Definition -Name 'Name') {
        [string]$Definition.Name
    }
    else {
        [string]$Definition
    }

    $effect = ''
    if ($Definition -isnot [string]) {
        if ((Test-LWPropertyExists -Object $Definition -Name 'Effect') -and -not [string]::IsNullOrWhiteSpace([string]$Definition.Effect)) {
            $effect = [string]$Definition.Effect
        }
        elseif ((Test-LWPropertyExists -Object $Definition -Name 'Description') -and -not [string]::IsNullOrWhiteSpace([string]$Definition.Description)) {
            $effect = [string]$Definition.Description
        }
    }

    return [ordered]@{
        Name     = $name
        Effect   = $effect
        Selected = [bool]($SelectedNames -contains $name)
    }
}

function Get-LWWebDisciplineSnapshot {
    $kaiSelected = @()
    $magnakaiSelected = @()
    $weaponskillWeapon = ''
    $weaponmasteryWeapons = @()
    $completedLoreCircles = @()
    $improvedDisciplines = @()

    if ($null -ne $script:GameState -and $null -ne $script:GameState.Character) {
        $character = $script:GameState.Character
        $kaiSelected = if ((Test-LWPropertyExists -Object $character -Name 'Disciplines') -and $null -ne $character.Disciplines) { @($character.Disciplines | ForEach-Object { [string]$_ }) } else { @() }
        $magnakaiSelected = if ((Test-LWPropertyExists -Object $character -Name 'MagnakaiDisciplines') -and $null -ne $character.MagnakaiDisciplines) { @($character.MagnakaiDisciplines | ForEach-Object { [string]$_ }) } else { @() }
        $weaponskillWeapon = if ((Test-LWPropertyExists -Object $character -Name 'WeaponskillWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$character.WeaponskillWeapon)) { [string]$character.WeaponskillWeapon } else { '' }
        $weaponmasteryWeapons = if ((Test-LWPropertyExists -Object $character -Name 'WeaponmasteryWeapons') -and $null -ne $character.WeaponmasteryWeapons) { @($character.WeaponmasteryWeapons | ForEach-Object { [string]$_ }) } else { @() }
        $completedLoreCircles = if ((Test-LWPropertyExists -Object $character -Name 'LoreCirclesCompleted') -and $null -ne $character.LoreCirclesCompleted) { @($character.LoreCirclesCompleted | ForEach-Object { [string]$_ }) } else { @() }
        $improvedDisciplines = if ((Test-LWPropertyExists -Object $character -Name 'ImprovedDisciplines') -and $null -ne $character.ImprovedDisciplines) { @($character.ImprovedDisciplines | ForEach-Object { [string]$_ }) } else { @() }
    }

    $kaiDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'KaiDisciplines') -and $null -ne $script:GameData.KaiDisciplines) { @($script:GameData.KaiDisciplines) } else { @() }
    $magnakaiDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiDisciplines') -and $null -ne $script:GameData.MagnakaiDisciplines) { @($script:GameData.MagnakaiDisciplines) } else { @() }
    $loreCircleDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiLoreCircles') -and $null -ne $script:GameData.MagnakaiLoreCircles) { @($script:GameData.MagnakaiLoreCircles) } else { @() }

    return [ordered]@{
        Kai                   = @($kaiDefinitions | ForEach-Object { Convert-LWWebDisciplineDefinition -Definition $_ -SelectedNames $kaiSelected })
        Magnakai              = @($magnakaiDefinitions | ForEach-Object { Convert-LWWebDisciplineDefinition -Definition $_ -SelectedNames $magnakaiSelected })
        SelectedKai           = @($kaiSelected)
        SelectedMagnakai      = @($magnakaiSelected)
        WeaponskillWeapon     = $weaponskillWeapon
        WeaponmasteryWeapons  = @($weaponmasteryWeapons)
        ImprovedDisciplines   = @($improvedDisciplines)
        LoreCirclesCompleted  = @($completedLoreCircles)
        LoreCircles           = @(
            foreach ($definition in @($loreCircleDefinitions | Sort-Object @{ Expression = { Get-LWLoreCircleDisplayOrder -Name ([string]$_.Name) } }, @{ Expression = { [string]$_.Name } })) {
                $required = if ((Test-LWPropertyExists -Object $definition -Name 'Disciplines') -and $null -ne $definition.Disciplines) { @($definition.Disciplines | ForEach-Object { [string]$_ }) } else { @() }
                [ordered]@{
                    Name               = if ((Test-LWPropertyExists -Object $definition -Name 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$definition.Name)) { [string]$definition.Name } else { '' }
                    Disciplines        = @($required)
                    MissingDisciplines = @($required | Where-Object { $magnakaiSelected -notcontains $_ })
                    CombatSkillBonus   = if ((Test-LWPropertyExists -Object $definition -Name 'CombatSkillBonus') -and $null -ne $definition.CombatSkillBonus) { [int]$definition.CombatSkillBonus } else { 0 }
                    EnduranceBonus     = if ((Test-LWPropertyExists -Object $definition -Name 'EnduranceBonus') -and $null -ne $definition.EnduranceBonus) { [int]$definition.EnduranceBonus } else { 0 }
                    Completed          = [bool]($completedLoreCircles -contains [string]$definition.Name)
                }
            }
        )
    }
}

function Get-LWWebModeSnapshot {
    $hasState = ($null -ne $script:GameState)
    $difficulty = if ($hasState) { [string](Get-LWCurrentDifficulty) } else { 'Normal' }
    $permadeath = if ($hasState) { [bool](Test-LWPermadeathEnabled) } else { $false }
    $integrityState = ''
    $integrityNote = ''

    if ($hasState -and (Test-LWPropertyExists -Object $script:GameState -Name 'Run') -and $null -ne $script:GameState.Run) {
        $integrityState = if ((Test-LWPropertyExists -Object $script:GameState.Run -Name 'IntegrityState') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityState)) { [string]$script:GameState.Run.IntegrityState } else { '' }
        $integrityNote = if ((Test-LWPropertyExists -Object $script:GameState.Run -Name 'IntegrityNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityNote)) { [string]$script:GameState.Run.IntegrityNote } else { '' }
    }

    return [ordered]@{
        HasState          = [bool]$hasState
        Difficulty        = $difficulty
        PermadeathEnabled = $permadeath
        IntegrityState    = $integrityState
        IntegrityNote     = $integrityNote
        AchievementPools  = if ($hasState) { @(Get-LWModeAchievementPools) } else { @('Universal', 'Combat', 'Exploration') }
        Definitions       = @(
            foreach ($definition in @(Get-LWDifficultyDefinitions)) {
                [ordered]@{
                    Name              = [string]$definition.Name
                    Description       = [string]$definition.Description
                    AchievementNote   = [string]$definition.AchievementNote
                    PermadeathAllowed = [bool]$definition.PermadeathAllowed
                    Current           = ([string]$definition.Name -eq $difficulty)
                }
            }
        )
    }
}

function Convert-LWWebCombatLogEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [int]$Index = 0,
        [string]$Source = 'archive'
    )

    $roundLog = @()
    if ((Test-LWPropertyExists -Object $Entry -Name 'Log') -and $null -ne $Entry.Log) {
        $roundLog = @(
            foreach ($round in @($Entry.Log)) {
                if ($null -ne $round) {
                    Copy-LWWebValue -Value $round
                }
            }
        )
    }

    return [ordered]@{
        Index                     = $Index
        Source                    = $Source
        EnemyName                 = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.EnemyName)) { [string]$Entry.EnemyName } else { '' }
        Outcome                   = if ((Test-LWPropertyExists -Object $Entry -Name 'Outcome') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Outcome)) { [string]$Entry.Outcome } else { '' }
        BookNumber                = if ((Test-LWPropertyExists -Object $Entry -Name 'BookNumber') -and $null -ne $Entry.BookNumber) { [int]$Entry.BookNumber } else { $null }
        BookTitle                 = if ((Test-LWPropertyExists -Object $Entry -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.BookTitle)) { [string]$Entry.BookTitle } else { '' }
        Section                   = if ((Test-LWPropertyExists -Object $Entry -Name 'Section') -and $null -ne $Entry.Section) { [int]$Entry.Section } else { $null }
        RoundCount                = if ((Test-LWPropertyExists -Object $Entry -Name 'RoundCount') -and $null -ne $Entry.RoundCount) { [int]$Entry.RoundCount } else { @($Entry.Log).Count }
        PlayerEnd                 = if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerEnd') -and $null -ne $Entry.PlayerEnd) { [int]$Entry.PlayerEnd } else { 0 }
        PlayerEnduranceMax        = if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerEnduranceMax') -and $null -ne $Entry.PlayerEnduranceMax) { [int]$Entry.PlayerEnduranceMax } else { $null }
        EnemyEnd                  = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyEnd') -and $null -ne $Entry.EnemyEnd) { [int]$Entry.EnemyEnd } else { 0 }
        EnemyEnduranceMax         = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyEnduranceMax') -and $null -ne $Entry.EnemyEnduranceMax) { [int]$Entry.EnemyEnduranceMax } else { $null }
        Weapon                    = if ((Test-LWPropertyExists -Object $Entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Weapon)) { [string]$Entry.Weapon } else { '' }
        Mode                      = if ((Test-LWPropertyExists -Object $Entry -Name 'Mode') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Mode)) { [string]$Entry.Mode } else { '' }
        Mindblast                 = [bool]((Test-LWPropertyExists -Object $Entry -Name 'Mindblast') -and [bool]$Entry.Mindblast)
        CanEvade                  = [bool]((Test-LWPropertyExists -Object $Entry -Name 'CanEvade') -and [bool]$Entry.CanEvade)
        PlayerCombatSkill         = if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerCombatSkill') -and $null -ne $Entry.PlayerCombatSkill) { [int]$Entry.PlayerCombatSkill } else { $null }
        EnemyCombatSkill          = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyCombatSkill') -and $null -ne $Entry.EnemyCombatSkill) { [int]$Entry.EnemyCombatSkill } else { $null }
        CombatRatio               = if ((Test-LWPropertyExists -Object $Entry -Name 'CombatRatio') -and $null -ne $Entry.CombatRatio) { [int]$Entry.CombatRatio } else { $null }
        Notes                     = if ((Test-LWPropertyExists -Object $Entry -Name 'Notes') -and $null -ne $Entry.Notes) { @($Entry.Notes) } else { @() }
        Log                       = @($roundLog)
    }
}

function Get-LWWebCombatLogSnapshot {
    if ($null -eq $script:GameState) {
        return $null
    }

    $activeEntry = Get-LWCurrentCombatLogEntry
    $history = @($script:GameState.History)
    $entries = @()
    for ($i = 0; $i -lt $history.Count; $i++) {
        $entries += (Convert-LWWebCombatLogEntry -Entry $history[$i] -Index ($i + 1) -Source 'archive')
    }

    return [ordered]@{
        Active  = if ($null -ne $activeEntry) { Convert-LWWebCombatLogEntry -Entry $activeEntry -Index 0 -Source 'active' } else { $null }
        Entries = @($entries)
        Recent  = @($entries | Select-Object -Last 12)
        Count   = [int]$entries.Count
    }
}

function Get-LWWebSafeCommandList {
    return @(
        'sheet',
        'inventory',
        'notes',
        'history',
        'help',
        'disciplines',
        'modes',
        'stats',
        'stats combat',
        'stats survival',
        'campaign',
        'campaign books',
        'campaign combat',
        'campaign survival',
        'campaign milestones',
        'achievements',
        'achievements recent',
        'achievements unlocked',
        'achievements locked',
        'achievements progress',
        'achievements planned',
        'roll',
        'gold +/-n',
        'arrows +/-n',
        'combat status',
        'combat log',
        'set <section>'
    )
}

function New-LWWebCommandButton {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Command,
        [string]$Description = ''
    )

    return [ordered]@{
        Label       = $Label
        Command     = $Command
        Description = $Description
    }
}

function Get-LWWebSafeCommandGroups {
    return @(
        [ordered]@{
            Title    = 'Navigation'
            Commands = @(
                (New-LWWebCommandButton -Label 'Sheet' -Command 'sheet' -Description 'Return to the character sheet.'),
                (New-LWWebCommandButton -Label 'Inventory' -Command 'inventory' -Description 'Open inventory and resources.'),
                (New-LWWebCommandButton -Label 'Disciplines' -Command 'disciplines' -Description 'Review Kai and Magnakai abilities.'),
                (New-LWWebCommandButton -Label 'Notes' -Command 'notes' -Description 'Open run notes.'),
                (New-LWWebCommandButton -Label 'History' -Command 'history' -Description 'Review recent combat history.'),
                (New-LWWebCommandButton -Label 'Modes' -Command 'modes' -Description 'Review difficulty, permadeath, and combat mode.'),
                (New-LWWebCommandButton -Label 'Help' -Command 'help' -Description 'Open this command reference.')
            )
        },
        [ordered]@{
            Title    = 'Stats'
            Commands = @(
                (New-LWWebCommandButton -Label 'Overview' -Command 'stats' -Description 'Show current-book summary.'),
                (New-LWWebCommandButton -Label 'Combat' -Command 'stats combat' -Description 'Show current-book combat totals.'),
                (New-LWWebCommandButton -Label 'Survival' -Command 'stats survival' -Description 'Show current-book survival totals.')
            )
        },
        [ordered]@{
            Title    = 'Campaign'
            Commands = @(
                (New-LWWebCommandButton -Label 'Overview' -Command 'campaign' -Description 'Show whole-run overview.'),
                (New-LWWebCommandButton -Label 'Books' -Command 'campaign books' -Description 'Show book-by-book status.'),
                (New-LWWebCommandButton -Label 'Combat' -Command 'campaign combat' -Description 'Show run-wide combat totals.'),
                (New-LWWebCommandButton -Label 'Survival' -Command 'campaign survival' -Description 'Show run-wide survival totals.'),
                (New-LWWebCommandButton -Label 'Milestones' -Command 'campaign milestones' -Description 'Show achievements and highlights.')
            )
        },
        [ordered]@{
            Title    = 'Achievements'
            Commands = @(
                (New-LWWebCommandButton -Label 'Overview' -Command 'achievements' -Description 'Show achievement overview.'),
                (New-LWWebCommandButton -Label 'Recent' -Command 'achievements recent' -Description 'Show recent unlocks.'),
                (New-LWWebCommandButton -Label 'Unlocked' -Command 'achievements unlocked' -Description 'Show unlocked achievements.'),
                (New-LWWebCommandButton -Label 'Locked' -Command 'achievements locked' -Description 'Show locked achievement slots.'),
                (New-LWWebCommandButton -Label 'Progress' -Command 'achievements progress' -Description 'Show tracked milestone progress.'),
                (New-LWWebCommandButton -Label 'Planned' -Command 'achievements planned' -Description 'Show planned achievement entries.')
            )
        },
        [ordered]@{
            Title    = 'Combat And Randomness'
            Commands = @(
                (New-LWWebCommandButton -Label 'Roll' -Command 'roll' -Description 'Roll the Random Number Table for the current section.'),
                (New-LWWebCommandButton -Label 'Combat Status' -Command 'combat status' -Description 'Open the current combat state.'),
                (New-LWWebCommandButton -Label 'Combat Log' -Command 'combat log' -Description 'Open active and archived combat records.')
            )
        },
        [ordered]@{
            Title    = 'Inventory Resources'
            Commands = @(
                (New-LWWebCommandButton -Label 'Spend 10 Gold' -Command 'gold -10' -Description 'Spend 10 Gold Crowns for a fare or fee.'),
                (New-LWWebCommandButton -Label 'Add Gold' -Command 'gold +1' -Description 'Add 1 Gold Crown after a reward.'),
                (New-LWWebCommandButton -Label 'Spend Arrow' -Command 'arrows -1' -Description 'Spend one arrow from your quiver.'),
                (New-LWWebCommandButton -Label 'Fill Arrows' -Command 'arrows +12' -Description 'Refill arrows up to your quiver capacity.')
            )
        }
    )
}

function Get-LWWebCliOnlyCommands {
    return @(
        [ordered]@{ Label = 'newrun'; Reason = 'Use New Game for browser setup until the new-run profile flow is converted.' },
        [ordered]@{ Label = 'difficulty / permadeath'; Reason = 'Run settings are chosen through setup and locked after the run starts.' },
        [ordered]@{ Label = 'mode manual|data'; Reason = 'Combat-mode mutation is still terminal-only.' },
        [ordered]@{ Label = 'discipline add'; Reason = 'Manual discipline repair still needs a prompt-backed browser flow.' },
        [ordered]@{ Label = 'complete'; Reason = 'Use the browser Complete Book button to mark the current book complete.' },
        [ordered]@{ Label = 'healcheck'; Reason = 'Healing is applied through section automation; manual trigger remains terminal-only.' },
        [ordered]@{ Label = 'die / fail'; Reason = 'Manual terminal death/failure shortcuts are not exposed in the browser.' },
        [ordered]@{ Label = 'setcs / setend / setmaxend'; Reason = 'Manual stat override controls are not exposed in the browser.' },
        [ordered]@{ Label = 'fight'; Reason = 'Use the Combat tab Start Combat plus Auto Resolve buttons.' },
        [ordered]@{ Label = 'combat potion'; Reason = 'Combat potion use still needs a browser combat-round prompt flow.' },
        [ordered]@{ Label = 'combat log [n|all|book n]'; Reason = 'The browser shows active and archived fights, but exact archive filters are not exposed yet.' },
        [ordered]@{ Label = 'quit / exit'; Reason = 'Close the browser tab or stop the local web server from the launcher terminal.' }
    )
}

function Get-LWWebHelpSnapshot {
    return [ordered]@{
        PrimaryCommands   = @(
            [ordered]@{ Label = 'sheet'; Value = 'Return to the character sheet.' },
            [ordered]@{ Label = 'inventory'; Value = 'Open inventory and resources.' },
            [ordered]@{ Label = 'section <n>'; Value = 'Move to a numbered section.' },
            [ordered]@{ Label = 'roll'; Value = 'Roll the Random Number Table for the current section.' },
            [ordered]@{ Label = 'arrows +/-n'; Value = 'Spend or refill quiver arrows.' },
            [ordered]@{ Label = 'combat status'; Value = 'Open current combat state.' },
            [ordered]@{ Label = 'combat log'; Value = 'Open detailed combat records.' },
            [ordered]@{ Label = 'save'; Value = 'Save the current run.' },
            [ordered]@{ Label = 'load'; Value = 'Load a saved run.' },
            [ordered]@{ Label = 'modes'; Value = 'Review difficulty and permadeath state.' }
        )
        SafeCommands      = @(Get-LWWebSafeCommandList)
        SafeCommandGroups = @(Get-LWWebSafeCommandGroups)
        CliOnlyCommands   = @(Get-LWWebCliOnlyCommands)
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

function Get-LWWebOptionalProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $Default
}

function Get-LWWebOptionalString {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Default = ''
    )

    $value = Get-LWWebOptionalProperty -Object $Object -Name $Name -Default $null
    if ($null -eq $value) {
        return $Default
    }

    $text = [string]$value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Default
    }

    return $text
}

function Get-LWWebRandomNumberSnapshot {
    param(
        [object]$State = $script:GameState,
        [int]$Section = 0,
        [bool]$PendingFlowActive = $false
    )

    $snapshot = [ordered]@{
        Available         = $false
        CanRoll           = $false
        PendingFlowActive = [bool]$PendingFlowActive
        HasContext        = $false
        BookNumber        = $null
        Section           = if ($Section -gt 0) { [int]$Section } else { $null }
        Description       = ''
        Modifier          = 0
        ModifierNotes     = @()
        RollCount         = 1
        SequenceMode      = 'combined'
        ZeroCountsAsTen   = $false
        Bypassed          = $false
        BypassReason      = ''
        LastRoll          = $null
        Error             = ''
    }

    if ($null -eq $State) {
        $snapshot.Description = 'Load a run to use the Random Number Table.'
        return $snapshot
    }

    try {
        $bookNumber = if ($null -ne $State.Character -and $null -ne $State.Character.BookNumber) { [int]$State.Character.BookNumber } else { $null }
        $sectionNumber = if ($Section -gt 0) { [int]$Section } elseif ($null -ne $State.CurrentSection) { [int]$State.CurrentSection } else { $null }

        $snapshot.Available = $true
        $snapshot.CanRoll = (-not [bool]$PendingFlowActive) -and (-not [bool](Test-LWDeathActive))
        $snapshot.BookNumber = $bookNumber
        $snapshot.Section = $sectionNumber

        if ($null -ne $script:LWWebLastRoll -and
            (Test-LWPropertyExists -Object $script:LWWebLastRoll -Name 'BookNumber') -and
            (Test-LWPropertyExists -Object $script:LWWebLastRoll -Name 'Section') -and
            $null -ne $bookNumber -and
            $null -ne $sectionNumber -and
            [int]$script:LWWebLastRoll.BookNumber -eq [int]$bookNumber -and
            [int]$script:LWWebLastRoll.Section -eq [int]$sectionNumber) {
            $snapshot.LastRoll = [ordered]@{
                BookNumber  = [int]$script:LWWebLastRoll.BookNumber
                Section     = [int]$script:LWWebLastRoll.Section
                Messages    = @($script:LWWebLastRoll.Messages)
                RecordedUtc = [string]$script:LWWebLastRoll.RecordedUtc
            }
        }

        if ($null -eq $sectionNumber -or [int]$sectionNumber -le 0) {
            $snapshot.Description = 'No active section is available for a Random Number Table roll.'
            $snapshot.CanRoll = $false
            return $snapshot
        }

        $contextState = Copy-LWWebValue $State
        if ($null -ne $contextState) {
            if (Test-LWPropertyExists -Object $contextState -Name 'CurrentSection') {
                $contextState.CurrentSection = [int]$sectionNumber
            }
            else {
                $contextState | Add-Member -NotePropertyName CurrentSection -NotePropertyValue ([int]$sectionNumber)
            }
        }

        $context = Get-LWSectionRandomNumberContext -State $contextState
        if ($null -eq $context) {
            $snapshot.Description = 'No section-specific random-number rule is registered for this section.'
            return $snapshot
        }

        $snapshot.HasContext = $true
        $snapshot.Description = Get-LWWebOptionalString -Object $context -Name 'Description' -Default 'Plain random-number check.'
        $snapshot.Modifier = [int](Get-LWWebOptionalProperty -Object $context -Name 'Modifier' -Default 0)
        $snapshot.ModifierNotes = @(
            foreach ($note in @(Get-LWWebOptionalProperty -Object $context -Name 'ModifierNotes' -Default @())) {
                if (-not [string]::IsNullOrWhiteSpace([string]$note)) {
                    [string]$note
                }
            }
        )
        $snapshot.RollCount = [Math]::Max(1, [int](Get-LWWebOptionalProperty -Object $context -Name 'RollCount' -Default 1))
        $snapshot.SequenceMode = Get-LWWebOptionalString -Object $context -Name 'SequenceMode' -Default 'combined'
        $snapshot.ZeroCountsAsTen = [bool](Get-LWWebOptionalProperty -Object $context -Name 'ZeroCountsAsTen' -Default $false)
        $snapshot.Bypassed = [bool](Get-LWWebOptionalProperty -Object $context -Name 'Bypassed' -Default $false)
        $snapshot.BypassReason = Get-LWWebOptionalString -Object $context -Name 'BypassReason'
        if ([bool]$snapshot.Bypassed) {
            $snapshot.CanRoll = $false
        }

        return $snapshot
    }
    catch {
        $snapshot.CanRoll = $false
        $snapshot.Description = 'Random Number Table context could not be prepared.'
        $snapshot.Error = [string]$_.Exception.Message
        return $snapshot
    }
}

function New-LWWebFlowPrompt {
    param([Parameter(Mandatory = $true)][object]$Flow)

    $flowType = Get-LWWebOptionalString -Object $Flow -Name 'Type' -Default 'newGame'
    $flowStep = Get-LWWebOptionalString -Object $Flow -Name 'Step'
    $pendingPrompt = Get-LWWebOptionalProperty -Object $Flow -Name 'PendingPrompt'

    if ($flowType -ne 'newGame') {
        $summary = $null
        if ($null -ne $Flow.Data) {
            if ((Test-LWPropertyExists -Object $Flow.Data -Name 'Section') -and [int]$Flow.Data.Section -gt 0) {
                $summary = [ordered]@{ Section = [int]$Flow.Data.Section }
            }
            elseif ((Test-LWPropertyExists -Object $Flow.Data -Name 'BookNumber') -and [int]$Flow.Data.BookNumber -gt 0) {
                $summary = [ordered]@{ BookNumber = [int]$Flow.Data.BookNumber }
            }
        }

        $contextText = Get-LWWebOptionalString -Object $Flow -Name 'ContextText'
        $promptKind = if ($null -ne $pendingPrompt) { [string](Get-LWWebPendingPromptKind -Flow $Flow -PendingPrompt $pendingPrompt -ContextText $contextText) } else { 'generic' }

        return [ordered]@{
            Active      = $true
            Type        = $flowType
            Step        = $flowStep
            Mode        = 'prompt'
            Title       = Get-LWWebOptionalString -Object $Flow -Name 'Title' -Default 'Continue'
            Description = Get-LWWebOptionalString -Object $Flow -Name 'Description' -Default 'Answer the pending prompt to continue.'
            Prompt      = $pendingPrompt
            Summary     = $summary
            ContextText = $contextText
            PromptKind  = $promptKind
            SubmitLabel = Get-LWWebOptionalString -Object $Flow -Name 'SubmitLabel' -Default 'Continue'
            CancelLabel = Get-LWWebOptionalString -Object $Flow -Name 'CancelLabel' -Default 'Cancel'
        }
    }

    $summary = [ordered]@{
        Difficulty = [string]$Flow.Data.Difficulty
        Permadeath = [bool]$Flow.Data.Permadeath
        Name       = [string]$Flow.Data.Name
        BookNumber = [int]$Flow.Data.BookNumber
        StartSection = [int]$Flow.Data.StartSection
    }

    switch ($flowStep) {
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
            $contextText = Get-LWWebOptionalString -Object $Flow -Name 'ContextText'
            $promptKind = if ($null -ne $pendingPrompt) { [string](Get-LWWebPendingPromptKind -Flow $Flow -PendingPrompt $pendingPrompt -ContextText $contextText) } else { 'generic' }
            return [ordered]@{
                Active      = $true
                Type        = 'newGame'
                Step        = 'startupEquipment'
                Mode        = 'prompt'
                Title       = 'Starting Equipment'
                Description = 'The book-specific startup package needs one more choice before the run can continue.'
                Summary     = $summary
                Prompt      = $pendingPrompt
                ContextText = $contextText
                PromptKind  = $promptKind
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
        ContextText   = ''
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

function New-LWWebPromptActionFlow {
    param(
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Description,
        [string]$SubmitLabel = 'Continue',
        [string]$CancelLabel = 'Cancel'
    )

    return [pscustomobject]@{
        Type          = $Type
        Step          = 'prompt'
        Title         = $Title
        Description   = $Description
        SubmitLabel   = $SubmitLabel
        CancelLabel   = $CancelLabel
        PendingPrompt = $null
        ContextText   = ''
        Checkpoint    = New-LWWebCheckpoint
        Data          = [pscustomobject]@{
            Responses        = @()
            RandomRolls      = @()
            EnemyName        = ''
            EnemyCombatSkill = 0
            EnemyEndurance   = 0
            Section          = 0
            BookNumber       = 0
        }
    }
}

function Get-LWWebPendingContextText {
    param(
        [Parameter(Mandatory = $true)][object]$Flow,
        [Parameter(Mandatory = $true)][object]$PendingPrompt
    )

    $screenName = if ($null -ne $script:LWUi -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.CurrentScreen)) {
        [string]$script:LWUi.CurrentScreen
    }
    else {
        ''
    }
    $screenData = if ($null -ne $script:LWUi) { $script:LWUi.ScreenData } else { $null }

    if ($screenName -eq 'disciplineselect' -and $null -ne $screenData) {
        $available = @(if (Test-LWPropertyExists -Object $screenData -Name 'Available') { $screenData.Available })
        $count = if (Test-LWPropertyExists -Object $screenData -Name 'Count') { [int]$screenData.Count } else { 1 }
        $ruleSetName = if ((Test-LWPropertyExists -Object $screenData -Name 'RuleSet') -and -not [string]::IsNullOrWhiteSpace([string]$screenData.RuleSet)) { [string]$screenData.RuleSet } else { 'Kai' }
        $lines = @(
            $(if ($ruleSetName -ieq 'Magnakai') { 'Choose Magnakai Discipline' } else { 'Choose Kai Discipline' }),
            ''
        )
        for ($i = 0; $i -lt $available.Count; $i++) {
            $entry = $available[$i]
            $effect = if (Test-LWPropertyExists -Object $entry -Name 'Effect') { [string]$entry.Effect } else { '' }
            $lines += ("{0}. {1} - {2}" -f ($i + 1), [string]$entry.Name, $effect)
        }
        $lines += ''
        $lines += ("Enter {0} number(s) separated by commas." -f $count)
        return ($lines -join "`n").Trim()
    }

    $promptText = if ((Test-LWPropertyExists -Object $PendingPrompt -Name 'Prompt') -and -not [string]::IsNullOrWhiteSpace([string]$PendingPrompt.Prompt)) {
        [string]$PendingPrompt.Prompt
    }
    else {
        ''
    }

    if ($promptText -match '^Choose\s+(\d+)\s+mastered weapon number\(s\) separated by commas$') {
        $count = [int]$matches[1]
        $exclude = @(if ($null -ne $script:GameState.Character -and (Test-LWPropertyExists -Object $script:GameState.Character -Name 'WeaponmasteryWeapons')) {
                $script:GameState.Character.WeaponmasteryWeapons | ForEach-Object { [string]$_ }
        }
        )
        $available = @(Get-LWMagnakaiWeaponmasteryOptions | Where-Object { $exclude -notcontains [string]$_ })
        $lines = @('Weaponmastery', '')
        for ($i = 0; $i -lt $available.Count; $i++) {
            $lines += ("{0}. {1}" -f ($i + 1), [string]$available[$i])
        }
        $lines += ''
        $lines += ("Choose {0} mastered weapon number(s) separated by commas." -f $count)
        return ($lines -join "`n").Trim()
    }

    if ([string]$Flow.Type -eq 'continueBook' -and $promptText -match '^Enter\s+(\d+)\s+number\(s\) separated by commas$') {
        $count = [int]$matches[1]
        $exclude = @(if ($null -ne $script:GameState.Character -and (Test-LWPropertyExists -Object $script:GameState.Character -Name 'MagnakaiDisciplines')) {
                $script:GameState.Character.MagnakaiDisciplines | ForEach-Object { [string]$_ }
        }
        )
        $available = @($script:GameData.MagnakaiDisciplines | Where-Object { $exclude -notcontains [string]$_.Name })
        $lines = @('Choose Magnakai Discipline', '')
        for ($i = 0; $i -lt $available.Count; $i++) {
            $entry = $available[$i]
            $effect = if (Test-LWPropertyExists -Object $entry -Name 'Effect') { [string]$entry.Effect } else { '' }
            $lines += ("{0}. {1} - {2}" -f ($i + 1), [string]$entry.Name, $effect)
        }
        $lines += ''
        $lines += ("Enter {0} number(s) separated by commas." -f $count)
        return ($lines -join "`n").Trim()
    }

    if ($promptText -eq 'Safekeeping choice') {
        $currentBookNumber = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 0 }
        $targetBookNumber = if ([string]$Flow.Type -eq 'continueBook' -and $null -ne $Flow.Data -and (Test-LWPropertyExists -Object $Flow.Data -Name 'BookNumber') -and [int]$Flow.Data.BookNumber -gt 0) {
            [int]$Flow.Data.BookNumber
        }
        elseif ($currentBookNumber -gt 0) {
            $currentBookNumber + 1
        }
        else {
            0
        }
        $continueLabel = if ($targetBookNumber -gt 0) { Format-LWBookLabel -BookNumber $targetBookNumber -IncludePrefix } else { 'the next book' }
        $carriedItems = @(if ($null -ne $script:GameState.Inventory) { $script:GameState.Inventory.SpecialItems })
        $storedItems = @(if ($null -ne $script:GameState.Storage -and (Test-LWPropertyExists -Object $script:GameState.Storage -Name 'SafekeepingSpecialItems')) { $script:GameState.Storage.SafekeepingSpecialItems })
        $lines = @(
            ('Book {0} Safekeeping' -f $targetBookNumber),
            '',
            ('Carried Special Items: {0}' -f $(if ($carriedItems.Count -gt 0) { $carriedItems -join ', ' } else { '(none)' })),
            ('Safekeeping: {0}' -f $(if ($storedItems.Count -gt 0) { $storedItems -join ', ' } else { '(none)' })),
            ''
        )
        if ($carriedItems.Count -gt 0) {
            $lines += 'Y. Choose carried Special Items to leave in safekeeping'
        }
        if ($storedItems.Count -gt 0) {
            $lines += 'R. Reclaim Special Items from safekeeping'
        }
        $lines += 'I. Review inventory first'
        $lines += ('N. Continue into {0}' -f $continueLabel)
        return ($lines -join "`n").Trim()
    }

    switch ($promptText) {
        'Section 98 shop choice' {
            return @(
                'Section 98 Weapons Shop',
                '',
                '1. Buy gear',
                '2. Sell gear',
                '0. Leave the shop'
            ) -join "`n"
        }
        'Section 275 shop choice' {
            return @(
                'Section 275 Cartographer',
                '',
                '1. Buy gear',
                '2. Sell gear',
                '0. Leave the shop'
            ) -join "`n"
        }
        'Section 137: pay the 3 Gold Crown levy now?' {
            return 'Section 137 Levy'
        }
    }

    if ($promptText -eq 'Safekeep which Special Item') {
        $available = @(if ($null -ne $script:GameState.Inventory) { $script:GameState.Inventory.SpecialItems })
        $lines = @('Choose carried Special Items to leave in safekeeping', '')
        for ($i = 0; $i -lt $available.Count; $i++) {
            $lines += ("{0}. {1}" -f ($i + 1), [string]$available[$i])
        }
        $lines += '0. Done choosing'
        return ($lines -join "`n").Trim()
    }

    if ($promptText -eq 'Reclaim which Special Item') {
        $available = @(if ($null -ne $script:GameState.Storage -and (Test-LWPropertyExists -Object $script:GameState.Storage -Name 'SafekeepingSpecialItems')) { $script:GameState.Storage.SafekeepingSpecialItems })
        $lines = @('Reclaim stored Special Items', '')
        for ($i = 0; $i -lt $available.Count; $i++) {
            $lines += ("{0}. {1}" -f ($i + 1), [string]$available[$i])
        }
        $lines += '0. Done choosing'
        return ($lines -join "`n").Trim()
    }

    if ($promptText -match '^Book\s+(6|7|8)\s+choice\s+#(\d+)$') {
        $bookNumber = [int]$matches[1]
        $promptNumber = [int]$matches[2]
        $choices = switch ($bookNumber) {
            6 { @(Get-LWMagnakaiBookSixStartingChoices) }
            7 { @(Get-LWMagnakaiBookSevenStartingChoices) }
            8 { @(Get-LWMagnakaiBookEightStartingChoices) }
            default { @() }
        }
        if ($choices.Count -gt 0) {
            $lines = @(
                ("Book {0} Starting Gear" -f $bookNumber),
                '',
                ("Choices Made: {0}/5" -f ($promptNumber - 1)),
                ("Weapons: {0}/2" -f @($script:GameState.Inventory.Weapons).Count),
                ("Backpack: {0}" -f $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' })),
                ("Special Items: {0}/12" -f @($script:GameState.Inventory.SpecialItems).Count)
            )
            if ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
                $lines += ("Arrows: {0}" -f (Format-LWQuiverArrowCounter -State $script:GameState))
            }
            $lines += ''
            for ($i = 0; $i -lt $choices.Count; $i++) {
                $lines += ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $choices[$i]))
            }
            $manageIndex = $choices.Count + 1
            $lines += ("{0}. Review inventory / make room" -f $manageIndex)
            $lines += '0. Done choosing'
            if ($promptNumber -gt 1) {
                $lines += ''
                $lines += 'Reference list only: already taken choices may no longer appear in the live prompt.'
            }
            return ($lines -join "`n").Trim()
        }
    }

    return ''
}

function Get-LWWebPendingPromptKind {
    param(
        [Parameter(Mandatory = $true)][object]$Flow,
        [Parameter(Mandatory = $true)][object]$PendingPrompt,
        [string]$ContextText = ''
    )

    $promptText = if ((Test-LWPropertyExists -Object $PendingPrompt -Name 'Prompt') -and -not [string]::IsNullOrWhiteSpace([string]$PendingPrompt.Prompt)) {
        [string]$PendingPrompt.Prompt
    }
    else {
        ''
    }

    switch ($promptText) {
        'Review inventory and make room now?' { return 'makeRoomConfirm' }
        'Drop an item to make room?' { return 'inventoryManageStart' }
        'Drop another item?' { return 'inventoryManageContinue' }
        'Safekeeping choice' { return 'safekeepingMenu' }
        'Safekeep which Special Item' { return 'safekeepingStore' }
        'Reclaim which Special Item' { return 'safekeepingReclaim' }
    }

    if ($promptText -match '^Book\s+(6|7|8)\s+choice\s+#(\d+)$') {
        return 'startingGearChoice'
    }
    if ($promptText -match '^Choose\s+\d+\s+mastered weapon number\(s\) separated by commas$') {
        return 'weaponmasteryChoice'
    }
    if ([string]$Flow.Type -eq 'continueBook' -and $promptText -match '^Enter\s+\d+\s+number\(s\) separated by commas$') {
        return 'disciplineChoice'
    }

    $context = [string]$ContextText
    if ($context -match '(?m)^\s*(?:[-*]\s*)?[0-9A-Za-z]+\.\s+' -and $context -match '(?m)^\s*(?:[-*]\s*)?0\.\s+Done choosing') {
        return 'choiceTable'
    }
    if ($context -match '(?m)^\s*(?:[-*]\s*)?[0-9A-Za-z]+\.\s+') {
        return 'choiceMenu'
    }

    return 'generic'
}

function Get-LWWebPromptFlowResponse {
    param([object]$Data)

    if ($null -eq $Data) {
        return $null
    }
    if (Test-LWPropertyExists -Object $Data -Name 'response') {
        return $Data.response
    }
    if ($Data -is [System.Collections.IDictionary] -and $Data.Contains('response')) {
        return $Data['response']
    }

    return $null
}

function Invoke-LWWebPromptActionPhase {
    param(
        [Parameter(Mandatory = $true)][object]$Flow,
        [Parameter(Mandatory = $true)][scriptblock]$Operation,
        [Parameter(Mandatory = $true)][string]$SuccessMessage,
        [Parameter(Mandatory = $true)][string]$PendingMessage,
        [switch]$ReplayRandoms
    )

    if ($null -eq $Flow.Checkpoint) {
        $Flow.Checkpoint = New-LWWebCheckpoint
    }

    $Flow.PendingPrompt = $null
    $Flow.ContextText = ''
    Restore-LWWebCheckpoint -Checkpoint $Flow.Checkpoint
    Start-LWWebPromptReplay -Responses @($Flow.Data.Responses)
    if ($ReplayRandoms) {
        Start-LWWebRandomReplay -Values @([int[]]$Flow.Data.RandomRolls)
    }

    $capturedOutput = @()
    try {
        $capturedOutput = @(Invoke-LWWebCapturedOperation -Operation $Operation)
        $Flow.ContextText = [string](Convert-LWWebOutputRecordsToText -Records $capturedOutput)
        if ($ReplayRandoms) {
            [void](Stop-LWWebRandomReplay)
        }
        Stop-LWWebPromptReplay
        $script:LWWebFlow = $null
        return $SuccessMessage
    }
    catch {
        $generatedRolls = @()
        if ($ReplayRandoms) {
            $generatedRolls = @(Stop-LWWebRandomReplay)
            if (@($generatedRolls).Count -gt 0) {
                $Flow.Data.RandomRolls = @($Flow.Data.RandomRolls + @([int[]]$generatedRolls))
            }
        }
        $capturedContextText = [string](Convert-LWWebOutputRecordsToText -Records $capturedOutput)
        $Flow.ContextText = $capturedContextText
        Stop-LWWebPromptReplay
        if (Test-LWWebPendingException -ErrorRecord $_) {
            $Flow.PendingPrompt = Copy-LWWebValue $script:LWWebPromptReplay.Pending
            $specificContextText = [string](Get-LWWebPendingContextText -Flow $Flow -PendingPrompt $Flow.PendingPrompt)
            $overrideContextText = if ($script:LWWebPromptReplay.Contains('ContextOverride')) { [string]$script:LWWebPromptReplay.ContextOverride } else { '' }
            $Flow.ContextText = if (-not [string]::IsNullOrWhiteSpace($specificContextText)) { $specificContextText } elseif (-not [string]::IsNullOrWhiteSpace($overrideContextText)) { $overrideContextText } else { $capturedContextText }
            Restore-LWWebCheckpoint -Checkpoint $Flow.Checkpoint
            return $PendingMessage
        }

        throw
    }
}

function Start-LWWebSaveGameFlow {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'saveGame' -Title 'Save Run' -Description 'Provide a save path for the current run. The default comes from the active character name and book.'
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage 'Saved current run.' -PendingMessage 'Save path input is required.' -Operation {
            Save-LWGame -PromptForPath
        })
}

function Start-LWWebCombatStartFlow {
    param(
        [Parameter(Mandatory = $true)][string]$EnemyName,
        [Parameter(Mandatory = $true)][int]$EnemyCombatSkill,
        [Parameter(Mandatory = $true)][int]$EnemyEndurance
    )

    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'combatStart' -Title 'Combat Setup' -Description 'Finish the remaining combat setup prompts for this tracked fight.'
    $flow.Data.EnemyName = $EnemyName
    $flow.Data.EnemyCombatSkill = $EnemyCombatSkill
    $flow.Data.EnemyEndurance = $EnemyEndurance
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage ("Combat started: {0}." -f $EnemyName) -PendingMessage 'Combat setup needs more input.' -Operation {
            Start-LWCombat -Arguments @(
                [string]$flow.Data.EnemyName,
                [string]$flow.Data.EnemyCombatSkill,
                [string]$flow.Data.EnemyEndurance
            ) | Out-Null
        })
}

function Start-LWWebCombatRoundFlow {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'combatRound' -Title 'Combat Round' -Description 'This round needs manual CRT values or a follow-up answer before it can resolve.'
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage 'Combat round resolved.' -PendingMessage 'Combat round input is required.' -Operation {
            Invoke-LWCombatRound | Out-Null
        })
}

function Start-LWWebCombatAutoFlow {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'combatAuto' -Title 'Auto Resolve Combat' -Description 'Auto-resolve paused because the current fight needs manual CRT input or another combat answer.'
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage 'Combat auto-resolve finished.' -PendingMessage 'Combat auto-resolve needs more input.' -Operation {
            Resolve-LWCombatToOutcome | Out-Null
        })
}

function Start-LWWebSetSectionFlow {
    param([Parameter(Mandatory = $true)][int]$Section)

    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'setSection' -Title ("Section {0}" -f $Section) -Description 'This section needs one or more follow-up answers before the entry rules can finish processing.'
    $flow.Data.Section = $Section
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage ("Moved to section {0}." -f $Section) -PendingMessage ("Section {0} needs more input." -f $Section) -Operation {
            Set-LWSection -Section $Section
        })
}

function Start-LWWebContinueBookFlow {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $currentBook = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 0 }
    $nextBook = $currentBook + 1
    $flow = New-LWWebPromptActionFlow -Type 'continueBook' -Title 'Continue To Next Book' -Description ("Finish the book transition into {0}." -f (Format-LWBookLabel -BookNumber $nextBook -IncludePrefix))
    $flow.Data.BookNumber = $nextBook
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage ("Advanced into {0}." -f (Format-LWBookLabel -BookNumber $nextBook -IncludePrefix)) -PendingMessage 'The book transition needs more input.' -Operation {
            Advance-LWCompletedBookTransition
        })
}

function Show-LWWebBookCompleteScreen {
    param([Parameter(Mandatory = $true)][int]$BookNumber)

    $bookSummary = $null
    foreach ($entry in @($script:GameState.BookHistory)) {
        if ($null -ne $entry -and (Test-LWPropertyExists -Object $entry -Name 'BookNumber') -and [int]$entry.BookNumber -eq $BookNumber) {
            $bookSummary = $entry
        }
    }
    if ($null -eq $bookSummary) {
        $bookSummary = New-LWBookHistoryEntry -Stats (Ensure-LWCurrentBookStats)
    }

    $nextBookLabel = if ($BookNumber -lt 8) { Format-LWBookLabel -BookNumber ($BookNumber + 1) -IncludePrefix } else { '' }
    $completionSnapshot = [pscustomobject]@{
        RuleSet          = [string]$script:GameState.RuleSet
        Difficulty       = Get-LWCurrentDifficulty
        RunIntegrityState = [string]$script:GameState.Run.IntegrityState
        CombatMode       = [string]$script:GameState.Settings.CombatMode
        GoldCrowns       = [int]$script:GameState.Inventory.GoldCrowns
        EnduranceCurrent = [int]$script:GameState.Character.EnduranceCurrent
        EnduranceMax     = [int]$script:GameState.Character.EnduranceMax
        NotesCount       = @($script:GameState.Character.Notes).Count
    }

    Set-LWScreen -Name 'bookcomplete' -Data ([pscustomobject]@{
            Summary             = $bookSummary
            CharacterName       = $script:GameState.Character.Name
            Snapshot            = $completionSnapshot
            ContinueToBookLabel = $nextBookLabel
        })
}

function Start-LWWebUseMealFlow {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'useMeal' -Title 'Use Meal' -Description 'The meal flow paused because this run needs a hunting or wasteland answer before it can continue.'
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage 'Meal flow resolved.' -PendingMessage 'Meal input is required.' -Operation {
            Use-LWMeal
        })
}

function Start-LWWebUsePotionFlow {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

    $flow = New-LWWebPromptActionFlow -Type 'usePotion' -Title 'Use Healing Potion' -Description 'Choose which healing item to spend if more than one valid option is available.'
    $script:LWWebFlow = $flow
    return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage 'Healing potion used.' -PendingMessage 'Potion input is required.' -Operation {
            Use-LWHealingPotion
        })
}

function Start-LWWebNewGameWizard {
    if ($null -ne $script:LWWebFlow) {
        throw 'Finish or cancel the current web flow first.'
    }

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

    $Flow.PendingPrompt = $null
    $Flow.ContextText = ''
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
            $Flow.ContextText = [string](Get-LWWebPendingContextText -Flow $Flow -PendingPrompt $Flow.PendingPrompt)
            Restore-LWWebCheckpoint -Checkpoint $Flow.Checkpoint
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
    $flowType = [string]$flow.Type

    if ($flowType -ne 'newGame') {
        $response = Get-LWWebPromptFlowResponse -Data $Data
        $flow.Data.Responses = @($flow.Data.Responses + @($response))

        switch ($flowType) {
            'saveGame' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage 'Saved current run.' -PendingMessage 'Save path input is required.' -Operation {
                        Save-LWGame -PromptForPath
                    })
            }
            'combatStart' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage ("Combat started: {0}." -f [string]$flow.Data.EnemyName) -PendingMessage 'Combat setup needs more input.' -Operation {
                        Start-LWCombat -Arguments @(
                            [string]$flow.Data.EnemyName,
                            [string]$flow.Data.EnemyCombatSkill,
                            [string]$flow.Data.EnemyEndurance
                        ) | Out-Null
                    })
            }
            'combatRound' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage 'Combat round resolved.' -PendingMessage 'Combat round input is required.' -Operation {
                        Invoke-LWCombatRound | Out-Null
                    })
            }
            'combatAuto' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage 'Combat auto-resolve finished.' -PendingMessage 'Combat auto-resolve needs more input.' -Operation {
                        Resolve-LWCombatToOutcome | Out-Null
                    })
            }
            'setSection' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage ("Moved to section {0}." -f [int]$flow.Data.Section) -PendingMessage ("Section {0} needs more input." -f [int]$flow.Data.Section) -Operation {
                        Set-LWSection -Section ([int]$flow.Data.Section)
                    })
            }
            'continueBook' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -ReplayRandoms -SuccessMessage ("Advanced into {0}." -f (Format-LWBookLabel -BookNumber ([int]$flow.Data.BookNumber) -IncludePrefix)) -PendingMessage 'The book transition needs more input.' -Operation {
                        Advance-LWCompletedBookTransition
                    })
            }
            'useMeal' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage 'Meal flow resolved.' -PendingMessage 'Meal input is required.' -Operation {
                        Use-LWMeal
                    })
            }
            'usePotion' {
                return (Invoke-LWWebPromptActionPhase -Flow $flow -SuccessMessage 'Healing potion used.' -PendingMessage 'Potion input is required.' -Operation {
                        Use-LWHealingPotion
                    })
            }
            default {
                throw ("Unknown web flow type: {0}" -f $flowType)
            }
        }
    }

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
    if ($null -ne $script:LWWebFlow -and $null -ne $script:LWWebFlow.Checkpoint) {
        Restore-LWWebCheckpoint -Checkpoint $script:LWWebFlow.Checkpoint
    }
    $script:LWWebFlow = $null
    return 'Web flow cancelled.'
}

function Get-LWWebInventorySectionSnapshot {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'pocket', 'herbpouch', 'special')][string]$Type)

    $items = @(Get-LWInventoryItems -Type $Type)
    $capacity = if ($Type -eq 'pocket') { $null } else { Get-LWInventoryTypeCapacity -Type $Type }
    $used = Get-LWInventoryUsedCapacity -Type $Type -Items $items
    $hasContainer = $true
    $recoveryItems = @()

    switch ($Type) {
        'backpack' {
            $hasContainer = Test-LWStateHasBackpack -State $script:GameState
            $recoveryItems = @(Get-LWInventoryRecoveryItems -Type 'backpack')
        }
        'herbpouch' {
            $hasContainer = Test-LWStateHasHerbPouch -State $script:GameState
            $recoveryItems = @(Get-LWInventoryRecoveryItems -Type 'herbpouch')
        }
        'weapon' {
            $recoveryItems = @(Get-LWInventoryRecoveryItems -Type 'weapon')
        }
        'special' {
            $recoveryItems = @(Get-LWInventoryRecoveryItems -Type 'special')
        }
    }

    $slots = @()
    if ($null -ne $capacity) {
        for ($slot = 1; $slot -le [int]$capacity; $slot++) {
            $displayText = [string](Get-LWInventorySlotDisplayText -Type $Type -Slot $slot -Items $items)
            $slots += [pscustomobject]@{
                Number      = $slot
                DisplayText = $displayText
                Empty       = ($displayText -eq '(empty)')
                Unavailable = ($displayText -eq '(unavailable)')
            }
        }
    }

    return [ordered]@{
        Type          = $Type
        Label         = Get-LWInventoryTypeLabel -Type $Type
        Items         = @($items)
        Count         = @($items).Count
        Capacity      = $capacity
        Used          = $used
        HasContainer  = [bool]$hasContainer
        Slots         = @($slots)
        RecoveryItems = @($recoveryItems)
        RecoveryCount = @($recoveryItems).Count
    }
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
                    DeathActive   = $false
                    CurrentScreen = $screenName
                    ScreenData    = $screenData
                    Notifications = @($notifications)
                    SavePath      = ''
                }
                reader           = [ordered]@{
                    BookNumber = $null
                    BookTitle  = ''
                    Section    = $null
                    Url        = '/web/frontend/library.html'
                }
                saves            = @(Get-LWWebSaveEntries)
                campaign         = $null
                death            = $null
                disciplines       = Get-LWWebDisciplineSnapshot
                modes             = Get-LWWebModeSnapshot
                combatLog         = $null
                help              = Get-LWWebHelpSnapshot
                randomNumber      = Get-LWWebRandomNumberSnapshot
                pendingFlow      = $pendingFlow
                availableScreens = @('welcome', 'sheet', 'inventory', 'disciplines', 'notes', 'history', 'stats', 'campaign', 'achievements', 'combat', 'combatlog', 'modes', 'bookcomplete', 'help')
            }
        }

        $stage = 'active state metadata'
        $bookNumber = if ($null -ne $script:GameState.Character -and $null -ne $script:GameState.Character.BookNumber) { [int]$script:GameState.Character.BookNumber } else { 1 }
        $section = if ($null -ne $script:GameState.CurrentSection) { [int]$script:GameState.CurrentSection } else { 1 }
        $readerSection = $section
        if ($null -ne $script:LWWebFlow -and
            [string](Get-LWWebOptionalString -Object $script:LWWebFlow -Name 'Type') -eq 'setSection' -and
            $null -ne $script:LWWebFlow.Data -and
            (Test-LWPropertyExists -Object $script:LWWebFlow.Data -Name 'Section') -and
            $null -ne $script:LWWebFlow.Data.Section -and
            [int]$script:LWWebFlow.Data.Section -gt 0) {
            $readerSection = [int]$script:LWWebFlow.Data.Section
        }
        $readerTarget = Get-LWWebReaderTarget -BookNumber $bookNumber -Section $readerSection -PendingFlow $pendingFlow
        $bookTitle = if (-not [string]::IsNullOrWhiteSpace([string]$readerTarget.BookTitle)) { [string]$readerTarget.BookTitle } else { [string](Get-LWBookTitle -BookNumber $bookNumber) }
        $inventory = $script:GameState.Inventory
        $character = $script:GameState.Character
        $combat = $script:GameState.Combat
        $combatPlayerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
        $combatBreakdown = if ($null -ne $combat -and [bool]$combat.Active) { Get-LWCombatBreakdownFromState -State $script:GameState } else { $null }
        $playerEnduranceCurrent = if ($null -ne $combatPlayerPool -and (Test-LWPropertyExists -Object $combatPlayerPool -Name 'Current') -and $null -ne $combatPlayerPool.Current) { [int]$combatPlayerPool.Current } elseif ($null -ne $character.EnduranceCurrent) { [int]$character.EnduranceCurrent } else { 0 }
        $playerEnduranceMax = if ($null -ne $combatPlayerPool -and (Test-LWPropertyExists -Object $combatPlayerPool -Name 'Max') -and $null -ne $combatPlayerPool.Max) { [int]$combatPlayerPool.Max } elseif ($null -ne $character.EnduranceMax) { [int]$character.EnduranceMax } else { 0 }
        $playerEnduranceLabel = if ($null -ne $combatPlayerPool -and (Test-LWPropertyExists -Object $combatPlayerPool -Name 'Label') -and -not [string]::IsNullOrWhiteSpace([string]$combatPlayerPool.Label)) { [string]$combatPlayerPool.Label } else { 'Endurance' }
        $playerEnduranceCombatBonus = if ($null -ne $combatPlayerPool -and (Test-LWPropertyExists -Object $combatPlayerPool -Name 'CombatBonus') -and $null -ne $combatPlayerPool.CombatBonus) { [int]$combatPlayerPool.CombatBonus } else { 0 }
        $playerCombatSkill = if ($null -ne $combatBreakdown -and (Test-LWPropertyExists -Object $combatBreakdown -Name 'PlayerCombatSkill') -and $null -ne $combatBreakdown.PlayerCombatSkill) { [int]$combatBreakdown.PlayerCombatSkill } elseif ($null -ne $character.CombatSkillBase) { [int]$character.CombatSkillBase } else { 0 }
        $enemyCombatSkillEffective = if ($null -ne $combatBreakdown -and (Test-LWPropertyExists -Object $combatBreakdown -Name 'EnemyCombatSkill') -and $null -ne $combatBreakdown.EnemyCombatSkill) { [int]$combatBreakdown.EnemyCombatSkill } elseif ($null -ne $combat.EnemyCombatSkill) { [int]$combat.EnemyCombatSkill } else { 0 }
        $combatRatio = if ($null -ne $combatBreakdown -and (Test-LWPropertyExists -Object $combatBreakdown -Name 'CombatRatio') -and $null -ne $combatBreakdown.CombatRatio) { [int]$combatBreakdown.CombatRatio } else { [int]($playerCombatSkill - $enemyCombatSkillEffective) }
        $combatNotes = if ($null -ne $combatBreakdown -and (Test-LWPropertyExists -Object $combatBreakdown -Name 'Notes')) { @($combatBreakdown.Notes) } else { @() }
        $weaponSection = Get-LWWebInventorySectionSnapshot -Type 'weapon'
        $backpackSection = Get-LWWebInventorySectionSnapshot -Type 'backpack'
        $specialSection = Get-LWWebInventorySectionSnapshot -Type 'special'
        $pocketSection = Get-LWWebInventorySectionSnapshot -Type 'pocket'
        $herbPouchSection = Get-LWWebInventorySectionSnapshot -Type 'herbpouch'
        $confiscatedStorage = if ($null -ne $script:GameState.Storage -and (Test-LWPropertyExists -Object $script:GameState.Storage -Name 'Confiscated') -and $null -ne $script:GameState.Storage.Confiscated) {
            $script:GameState.Storage.Confiscated
        }
        else {
            $null
        }
        $randomNumber = Get-LWWebRandomNumberSnapshot -State $script:GameState -Section $readerSection -PendingFlowActive ($null -ne $pendingFlow)

        $stage = 'active state payload'
        return [ordered]@{
            app              = [ordered]@{
                Name    = $script:LWAppName
                Version = $script:LWAppVersion
                RuleSet = if ((Test-LWPropertyExists -Object $script:GameState -Name 'RuleSet') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.RuleSet)) { [string]$script:GameState.RuleSet } else { '' }
            }
            session          = [ordered]@{
                HasState      = $true
                DeathActive   = [bool](Test-LWDeathActive)
                CurrentScreen = $screenName
                ScreenData    = $screenData
                Notifications = @($notifications)
                SavePath      = if ((Test-LWPropertyExists -Object $script:GameState.Settings -Name 'SavePath') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Settings.SavePath)) { [string]$script:GameState.Settings.SavePath } else { '' }
            }
            reader           = [ordered]@{
                BookNumber    = [int]$readerTarget.BookNumber
                BookTitle     = $bookTitle
                Section       = $readerTarget.Section
                Url           = [string]$readerTarget.Url
                LocationLabel = [string]$readerTarget.LocationLabel
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
                SafekeepingSpecialItems = if ($null -ne $script:GameState.Storage -and (Test-LWPropertyExists -Object $script:GameState.Storage -Name 'SafekeepingSpecialItems')) { @($script:GameState.Storage.SafekeepingSpecialItems) } else { @() }
                GoldCrowns         = if ($null -ne $inventory.GoldCrowns) { [int]$inventory.GoldCrowns } else { 0 }
                HasBackpack        = [bool]$inventory.HasBackpack
                HasHerbPouch       = [bool]$inventory.HasHerbPouch
                QuiverArrows       = if ((Test-LWPropertyExists -Object $inventory -Name 'QuiverArrows') -and $null -ne $inventory.QuiverArrows) { [int]$inventory.QuiverArrows } else { 0 }
                Sections           = [ordered]@{
                    weapon    = $weaponSection
                    backpack  = $backpackSection
                    special   = $specialSection
                    pocket    = $pocketSection
                    herbpouch = $herbPouchSection
                }
                RecoveryStash      = [ordered]@{
                    weapon    = @($weaponSection.RecoveryItems)
                    backpack  = @($backpackSection.RecoveryItems)
                    special   = @($specialSection.RecoveryItems)
                    herbpouch = @($herbPouchSection.RecoveryItems)
                }
                Confiscated        = [ordered]@{
                    HasAny             = [bool](Test-LWStateHasConfiscatedEquipment)
                    Summary            = Get-LWConfiscatedInventorySummaryText
                    Weapons            = if ($null -ne $confiscatedStorage) { @($confiscatedStorage.Weapons) } else { @() }
                    BackpackItems      = if ($null -ne $confiscatedStorage) { @($confiscatedStorage.BackpackItems) } else { @() }
                    HerbPouchItems     = if ($null -ne $confiscatedStorage) { @($confiscatedStorage.HerbPouchItems) } else { @() }
                    SpecialItems       = if ($null -ne $confiscatedStorage) { @($confiscatedStorage.SpecialItems) } else { @() }
                    PocketSpecialItems = if ($null -ne $confiscatedStorage -and (Test-LWPropertyExists -Object $confiscatedStorage -Name 'PocketSpecialItems')) { @($confiscatedStorage.PocketSpecialItems) } else { @() }
                    GoldCrowns         = if ($null -ne $confiscatedStorage -and $null -ne $confiscatedStorage.GoldCrowns) { [int]$confiscatedStorage.GoldCrowns } else { 0 }
                    HasHerbPouch       = if ($null -ne $confiscatedStorage -and (Test-LWPropertyExists -Object $confiscatedStorage -Name 'HasHerbPouch')) { [bool]$confiscatedStorage.HasHerbPouch } else { $false }
                    BookNumber         = if ($null -ne $confiscatedStorage -and $null -ne $confiscatedStorage.BookNumber) { [int]$confiscatedStorage.BookNumber } else { $null }
                    Section            = if ($null -ne $confiscatedStorage -and $null -ne $confiscatedStorage.Section) { [int]$confiscatedStorage.Section } else { $null }
                    SavedOn            = if ($null -ne $confiscatedStorage -and $null -ne $confiscatedStorage.SavedOn) { [string]$confiscatedStorage.SavedOn } else { '' }
                }
            }
            combat           = [ordered]@{
                Active                        = [bool]$combat.Active
                EnemyName                     = if ((Test-LWPropertyExists -Object $combat -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$combat.EnemyName)) { [string]$combat.EnemyName } else { '' }
                EnemyCombatSkill              = if ($null -ne $combat.EnemyCombatSkill) { [int]$combat.EnemyCombatSkill } else { 0 }
                EnemyCombatSkillEffective     = $enemyCombatSkillEffective
                EnemyEnduranceCurrent         = if ($null -ne $combat.EnemyEnduranceCurrent) { [int]$combat.EnemyEnduranceCurrent } else { 0 }
                EnemyEnduranceMax             = if ($null -ne $combat.EnemyEnduranceMax) { [int]$combat.EnemyEnduranceMax } else { 0 }
                PlayerCombatSkill             = $playerCombatSkill
                PlayerEnduranceCurrent        = $playerEnduranceCurrent
                PlayerEnduranceMax            = $playerEnduranceMax
                PlayerEnduranceLabel          = $playerEnduranceLabel
                PlayerEnduranceCombatBonus    = $playerEnduranceCombatBonus
                PlayerUsesTargetEndurance     = [bool]($null -ne $combatPlayerPool -and (Test-LWPropertyExists -Object $combatPlayerPool -Name 'UsesTarget') -and [bool]$combatPlayerPool.UsesTarget)
                CombatRatio                   = $combatRatio
                CombatNotes                   = @($combatNotes)
                UseMindblast                  = [bool]$combat.UseMindblast
                EquippedWeapon                = if ((Test-LWPropertyExists -Object $combat -Name 'EquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$combat.EquippedWeapon)) { [string]$combat.EquippedWeapon } else { '' }
                CanEvade                      = [bool]$combat.CanEvade
                MindblastCombatSkillBonus     = if ((Test-LWPropertyExists -Object $combat -Name 'MindblastCombatSkillBonus') -and $null -ne $combat.MindblastCombatSkillBonus) { [int]$combat.MindblastCombatSkillBonus } else { 0 }
                PlayerEnduranceLossMultiplier = if ((Test-LWPropertyExists -Object $combat -Name 'PlayerEnduranceLossMultiplier') -and $null -ne $combat.PlayerEnduranceLossMultiplier) { [int]$combat.PlayerEnduranceLossMultiplier } else { 1 }
                Log                           = @($combat.Log)
            }
            notes            = @($character.Notes)
            history          = @(Get-LWWebHistoryPreview -History @($script:GameState.History))
            currentBookStats = Get-LWLiveBookStatsSummary
            campaign         = Get-LWWebCampaignSnapshot
            death            = Get-LWWebDeathSnapshot
            achievements     = Get-LWWebAchievementSnapshot
            disciplines      = Get-LWWebDisciplineSnapshot
            modes            = Get-LWWebModeSnapshot
            combatLog        = Get-LWWebCombatLogSnapshot
            help             = Get-LWWebHelpSnapshot
            randomNumber     = $randomNumber
            saves            = @(Get-LWWebSaveEntries)
            pendingFlow      = $pendingFlow
            availableScreens = @('sheet', 'inventory', 'disciplines', 'notes', 'history', 'stats', 'campaign', 'achievements', 'combat', 'combatlog', 'modes', 'death', 'bookcomplete', 'help')
            safeCommands     = @(Get-LWWebSafeCommandList)
        }
    }
    catch {
        throw ("Web state snapshot failed during {0}: {1}" -f $stage, $_.Exception.Message)
    }
}

function Load-LWWebLastSave {
    $lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
    $path = $null
    if (Test-Path -LiteralPath $lastSaveFile) {
        $candidate = (Get-Content -LiteralPath $lastSaveFile -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and -not (Test-LWBackupSavePath -Path $candidate) -and (Test-Path -LiteralPath $candidate)) {
            $path = $candidate
        }
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        $catalog = @(Get-LWSaveCatalog)
        if ($catalog.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$catalog[0].FullName) -and (Test-Path -LiteralPath ([string]$catalog[0].FullName))) {
            $path = [string]$catalog[0].FullName
        }
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        return 'No recent save was found.'
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
        $trimmed -match '^(sheet|inv|inventory|notes|history|help|disciplines|modes)$' -or
        $trimmed -match '^stats(\s+(overview|combat|survival))?$' -or
        $trimmed -match '^campaign(\s+(overview|books|combat|survival|milestones))?$' -or
        $trimmed -match '^achievements(\s+(overview|recent|unlocked|locked|progress|planned))?$' -or
        $trimmed -match '^roll$' -or
        $trimmed -match '^gold\s+[+-]?\d+$' -or
        $trimmed -match '^(arrow|arrows)\s+[+-]?\d+$' -or
        $trimmed -match '^combat\s+(status|log)$' -or
        $trimmed -match '^set\s+\d+$'
    )
}

function Save-LWWebLastRollSnapshot {
    if ($null -eq $script:GameState -or $null -eq $script:GameState.Character) {
        $script:LWWebLastRoll = $null
        return
    }

    $messages = @()
    $record = $false
    foreach ($notification in @($script:LWUi.Notifications)) {
        if ($null -eq $notification) {
            continue
        }

        $message = if (Test-LWPropertyExists -Object $notification -Name 'Message') { [string]$notification.Message } else { [string]$notification }
        if ([string]::IsNullOrWhiteSpace($message)) {
            continue
        }

        if ($message -match '^Random Number Table rolls?:') {
            $record = $true
        }

        if ($record -and (
                $message -match '^Random Number Table rolls?:' -or
                $message -match '^Book \d+ section \d+' -or
                $message -match '^Section \d+')) {
            $messages += $message
        }
    }

    $script:LWWebLastRoll = [ordered]@{
        BookNumber  = [int]$script:GameState.Character.BookNumber
        Section     = [int]$script:GameState.CurrentSection
        Messages    = @($messages)
        RecordedUtc = ([datetime]::UtcNow.ToString('o'))
    }
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

            $path = if ((Test-LWPropertyExists -Object $Request -Name 'path') -and -not [string]::IsNullOrWhiteSpace([string]$Request.path)) { [string]$Request.path } else { '' }
            $promptForPath = [bool]((Test-LWPropertyExists -Object $Request -Name 'promptForPath') -and $Request.promptForPath)
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $script:GameState.Settings.SavePath = $path
                Save-LWGame
                return ("Saved current run to {0}." -f (Split-Path -Leaf $path))
            }

            $currentSavePath = if ((Test-LWPropertyExists -Object $script:GameState.Settings -Name 'SavePath') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Settings.SavePath)) { [string]$script:GameState.Settings.SavePath } else { '' }
            if ($promptForPath -or [string]::IsNullOrWhiteSpace($currentSavePath)) {
                return (Start-LWWebSaveGameFlow)
            }

            Save-LWGame
            return 'Saved current run.'
        }
        'addNote' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $noteText = if ((Test-LWPropertyExists -Object $Request -Name 'text') -and -not [string]::IsNullOrWhiteSpace([string]$Request.text)) { [string]$Request.text } else { '' }
            if ([string]::IsNullOrWhiteSpace($noteText)) {
                throw 'Note text is required.'
            }

            Add-LWNote -Text $noteText
            return 'Note added.'
        }
        'inventoryAdd' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $typeText = if ((Test-LWPropertyExists -Object $Request -Name 'type') -and -not [string]::IsNullOrWhiteSpace([string]$Request.type)) { [string]$Request.type } else { '' }
            $type = Resolve-LWInventoryType -Value $typeText
            if ($null -eq $type -or $type -eq 'pocket') {
                throw 'Type must be weapon, backpack, herbpouch, or special.'
            }

            $name = if ((Test-LWPropertyExists -Object $Request -Name 'name') -and -not [string]::IsNullOrWhiteSpace([string]$Request.name)) { [string]$Request.name } else { '' }
            if ([string]::IsNullOrWhiteSpace($name)) {
                throw 'Item name is required.'
            }

            $quantity = if ((Test-LWPropertyExists -Object $Request -Name 'quantity') -and $null -ne $Request.quantity) { [int]$Request.quantity } else { 1 }
            if ($quantity -lt 1) {
                throw 'Quantity must be at least 1.'
            }
            if ($type -eq 'special' -and $quantity -gt 1) {
                throw 'Special Items cannot be stacked. Add them one at a time.'
            }

            Add-LWInventoryItem -Type $type -Name $name.Trim() -Quantity $quantity
            return ("Added {0} x {1} to {2}." -f $quantity, $name.Trim(), $type)
        }
        'inventoryDrop' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $typeText = if ((Test-LWPropertyExists -Object $Request -Name 'type') -and -not [string]::IsNullOrWhiteSpace([string]$Request.type)) { [string]$Request.type } else { '' }
            $type = Resolve-LWInventoryType -Value $typeText
            if ($null -eq $type) {
                throw 'Type must be weapon, backpack, pocket, herbpouch, or special.'
            }

            $removeAll = [bool]((Test-LWPropertyExists -Object $Request -Name 'all') -and $Request.all)
            if ($removeAll) {
                if (@(Get-LWInventoryItems -Type $type).Count -eq 0) {
                    throw ("{0} is empty." -f (Get-LWInventoryTypeLabel -Type $type))
                }
                Remove-LWInventorySection -Type $type
                return ("Removed all items from {0}." -f $type)
            }

            $slot = if ((Test-LWPropertyExists -Object $Request -Name 'slot') -and $null -ne $Request.slot) { [int]$Request.slot } else { 0 }
            if ($slot -lt 1) {
                throw 'A slot number of 1 or higher is required, or choose all.'
            }

            if ($type -eq 'pocket') {
                $pocketItems = @(Get-LWInventoryItems -Type 'pocket')
                if ($pocketItems.Count -eq 0) {
                    throw 'Pocket Items is empty.'
                }
                if ($slot -gt $pocketItems.Count) {
                    throw ("Pocket Items slot must be between 1 and {0}." -f $pocketItems.Count)
                }
            }
            else {
                $section = Get-LWWebInventorySectionSnapshot -Type $type
                if ($slot -gt @($section.Slots).Count) {
                    throw ("{0} slot must be between 1 and {1}." -f $section.Label, @($section.Slots).Count)
                }

                $slotEntry = @($section.Slots)[$slot - 1]
                if ([bool]$slotEntry.Empty -or [bool]$slotEntry.Unavailable) {
                    throw ("{0} slot {1} is not available to drop." -f $section.Label, $slot)
                }
            }

            Remove-LWInventoryItemBySlot -Type $type -Slot $slot
            return ("Removed slot {0} from {1}." -f $slot, $type)
        }
        'inventoryRecover' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $selection = if ((Test-LWPropertyExists -Object $Request -Name 'selection') -and -not [string]::IsNullOrWhiteSpace([string]$Request.selection)) { [string]$Request.selection } else { '' }
            if ([string]::IsNullOrWhiteSpace($selection)) {
                throw 'Choose weapon, backpack, herbpouch, special, or all.'
            }

            if ($selection.Trim().ToLowerInvariant() -eq 'all') {
                $recoverableTypes = @('weapon', 'backpack', 'herbpouch', 'special') | Where-Object { @(Get-LWInventoryRecoveryItems -Type $_).Count -gt 0 }
                if (@($recoverableTypes).Count -eq 0) {
                    throw 'No saved inventory stash is available.'
                }
                foreach ($recoverType in @($recoverableTypes)) {
                    if (-not (Test-LWInventoryRecoveryFits -Type $recoverType)) {
                        throw ("{0} does not have enough room to recover its saved items." -f (Get-LWInventoryTypeLabel -Type $recoverType))
                    }
                }
                Restore-LWAllInventorySections
                return 'Recovered all saved inventory sections.'
            }

            $type = Resolve-LWInventoryType -Value $selection
            if ($null -eq $type -or $type -eq 'pocket') {
                throw 'Type must be weapon, backpack, herbpouch, special, or all.'
            }
            if (@(Get-LWInventoryRecoveryItems -Type $type).Count -eq 0) {
                throw ("No saved {0} stash is available." -f (Get-LWInventoryTypeLabel -Type $type))
            }
            if (-not (Test-LWInventoryRecoveryFits -Type $type)) {
                throw ("{0} does not have enough room to recover the saved items." -f (Get-LWInventoryTypeLabel -Type $type))
            }

            Restore-LWInventorySection -Type $type
            return ("Recovered saved {0} items." -f $type)
        }
        'adjustGold' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            if (-not (Test-LWPropertyExists -Object $Request -Name 'delta') -or $null -eq $Request.delta) {
                throw 'A gold delta is required.'
            }

            Update-LWGold -Delta ([int]$Request.delta)
            return 'Gold updated.'
        }
        'adjustEndurance' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            if (-not (Test-LWPropertyExists -Object $Request -Name 'delta') -or $null -eq $Request.delta) {
                throw 'An END delta is required.'
            }

            Update-LWEndurance -Delta ([int]$Request.delta)
            return 'Endurance updated.'
        }
        'useMeal' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            return (Start-LWWebUseMealFlow)
        }
        'usePotion' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            return (Start-LWWebUsePotionFlow)
        }
        'removeNote' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $index = if ((Test-LWPropertyExists -Object $Request -Name 'index') -and $null -ne $Request.index) { [int]$Request.index } else { 0 }
            $noteCount = @($script:GameState.Character.Notes).Count
            if ($index -lt 1 -or $index -gt $noteCount) {
                throw ("Note number must be between 1 and {0}." -f $noteCount)
            }

            Remove-LWNote -Index $index
            return ("Removed note {0}." -f $index)
        }
        'setSection' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }

            $section = if ((Test-LWPropertyExists -Object $Request -Name 'section') -and $null -ne $Request.section) { [int]$Request.section } else { 0 }
            if ($section -le 0) {
                throw 'A positive section number is required.'
            }

            return (Start-LWWebSetSectionFlow -Section $section)
        }
        'rewindDeath' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if (-not (Test-LWDeathActive)) {
                throw 'Rewind is only available after a death or failed mission.'
            }
            if (Test-LWPermadeathEnabled) {
                throw 'Permadeath disables rewind for this run.'
            }

            $steps = if ((Test-LWPropertyExists -Object $Request -Name 'steps') -and $null -ne $Request.steps) { [int]$Request.steps } else { 1 }
            if ($steps -lt 1) {
                throw 'Rewind steps must be at least 1.'
            }

            $available = [int](Get-LWAvailableRewindCount)
            if ($available -lt 1) {
                throw 'No earlier safe section is available to rewind to.'
            }
            if ($steps -gt $available) {
                throw ("You can rewind at most {0} section(s) from this death." -f $available)
            }

            Invoke-LWRewind -Steps $steps
            return ("Rewound {0} section{1}. You are back at section {2}." -f $steps, $(if ($steps -eq 1) { '' } else { 's' }), [int]$script:GameState.CurrentSection)
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
            $trimmedCommand = $commandText.Trim()
            if (-not (Test-LWWebSafeCommand -InputLine $trimmedCommand)) {
                throw 'That command is not available through the web scaffold yet.'
            }

            if ($trimmedCommand -match '^set\s+(\d+)$') {
                return (Start-LWWebSetSectionFlow -Section ([int]$matches[1]))
            }

            [void](Invoke-LWCommand -InputLine $trimmedCommand)
            if ($trimmedCommand -ieq 'roll') {
                Save-LWWebLastRollSnapshot
            }
            return ("Ran command: {0}" -f $trimmedCommand)
        }
        'completeBook' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if ($null -ne $script:LWWebFlow) {
                throw 'Finish or cancel the current web flow first.'
            }
            if ([string]$script:LWUi.CurrentScreen -eq 'bookcomplete') {
                throw 'The current book is already on the book complete screen.'
            }

            $currentBook = [int]$script:GameState.Character.BookNumber
            if (@($script:GameState.Character.CompletedBooks) -contains $currentBook) {
                Show-LWWebBookCompleteScreen -BookNumber $currentBook
                return ("Showing Book {0} complete screen." -f $currentBook)
            }

            Complete-LWBook -DeferTransition
            return ("Marked Book {0} complete." -f $currentBook)
        }
        'continueBook' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if ([string]$script:LWUi.CurrentScreen -ne 'bookcomplete') {
                throw 'Book continuation is only available from the book complete screen.'
            }
            if ([int]$script:GameState.Character.BookNumber -ge 8) {
                throw 'The current supported Magnakai campaign is already complete.'
            }

            return (Start-LWWebContinueBookFlow)
        }
        'startCombat' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if ($script:GameState.Combat.Active) {
                throw 'A combat is already active.'
            }

            $enemyName = if ((Test-LWPropertyExists -Object $Request -Name 'enemyName') -and -not [string]::IsNullOrWhiteSpace([string]$Request.enemyName)) { [string]$Request.enemyName } else { '' }
            $enemyCombatSkill = if ((Test-LWPropertyExists -Object $Request -Name 'enemyCombatSkill') -and $null -ne $Request.enemyCombatSkill) { [int]$Request.enemyCombatSkill } else { 0 }
            $enemyEndurance = if ((Test-LWPropertyExists -Object $Request -Name 'enemyEndurance') -and $null -ne $Request.enemyEndurance) { [int]$Request.enemyEndurance } else { 0 }
            if ([string]::IsNullOrWhiteSpace($enemyName)) {
                throw 'Enemy name is required.'
            }
            if ($enemyCombatSkill -lt 0) {
                throw 'Enemy Combat Skill must be 0 or higher.'
            }
            if ($enemyEndurance -lt 1) {
                throw 'Enemy Endurance must be at least 1.'
            }

            return (Start-LWWebCombatStartFlow -EnemyName $enemyName.Trim() -EnemyCombatSkill $enemyCombatSkill -EnemyEndurance $enemyEndurance)
        }
        'combatRound' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if (-not $script:GameState.Combat.Active) {
                throw 'No active combat.'
            }

            return (Start-LWWebCombatRoundFlow)
        }
        'combatAuto' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if (-not $script:GameState.Combat.Active) {
                throw 'No active combat.'
            }

            return (Start-LWWebCombatAutoFlow)
        }
        'combatEvade' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if (-not $script:GameState.Combat.Active) {
                throw 'No active combat.'
            }

            Invoke-LWEvade
            return 'Combat evade attempted.'
        }
        'combatStop' {
            if ($null -eq $script:GameState) {
                throw 'No active run is loaded.'
            }
            if (-not $script:GameState.Combat.Active) {
                throw 'No active combat.'
            }

            Stop-LWCombat | Out-Null
            return 'Combat tracking stopped.'
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
