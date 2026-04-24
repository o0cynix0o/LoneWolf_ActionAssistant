Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

$script:LWShellHostCommandCache = @{}
$script:LWShellHelpfulCommandsPanelCache = @{}
$script:LWShellCampaignSummaryCache = $null
$script:LWNotificationBufferSize = 12
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

function Get-LWShellHostCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    if ($script:LWShellHostCommandCache.ContainsKey($Name)) {
        $cachedCommand = $script:LWShellHostCommandCache[$Name]
        if ($null -ne $cachedCommand) {
            return $cachedCommand
        }
    }

    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $script:LWShellHostCommandCache[$Name] = $command
    }
    return $command
}

function Get-LWModuleGameData {
    $localGameData = Get-Variable -Scope Script -Name GameData -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $localGameData) {
        return $localGameData
    }

    $contextCommand = Get-LWShellHostCommand -Name 'Get-LWModuleContext'
    if ($null -ne $contextCommand) {
        $context = & $contextCommand
        if ($context -is [hashtable] -and $context.ContainsKey('GameData') -and $null -ne $context.GameData) {
            Set-Variable -Scope Script -Name GameData -Value $context.GameData -Force
            return $context.GameData
        }
    }

    return $null
}

function Invoke-LWCoreEnsureErrorLogCapacity {
    param(
        [string]$LogPath,
        [long]$MaxBytes = 5MB,
        [int]$MaxArchives = 5
    )

    if ([string]::IsNullOrWhiteSpace($LogPath) -or -not (Test-Path -LiteralPath $LogPath)) {
        return
    }

    $logFile = Get-Item -LiteralPath $LogPath -ErrorAction SilentlyContinue
    if ($null -eq $logFile -or $logFile.Length -lt $MaxBytes) {
        return
    }

    $logDirectory = Split-Path -Parent $LogPath
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($LogPath)
    $extension = [System.IO.Path]::GetExtension($LogPath)
    $archivePath = Join-Path $logDirectory ("{0}-{1}{2}" -f $baseName, (Get-Date -Format 'yyyyMMdd-HHmmss'), $extension)
    Move-Item -LiteralPath $LogPath -Destination $archivePath -Force

    $archives = @(
        Get-ChildItem -LiteralPath $logDirectory -Filter ("{0}-*{1}" -f $baseName, $extension) -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending
    )

    if (@($archives).Count -gt $MaxArchives) {
        foreach ($archive in @($archives | Select-Object -Skip $MaxArchives)) {
            Remove-Item -LiteralPath $archive.FullName -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-LWCoreMaintainRuntime {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if ([string]::IsNullOrWhiteSpace([string]$script:LWErrorLogFile)) {
        return
    }

    $logDirectory = Split-Path -Parent $script:LWErrorLogFile
    if (-not [string]::IsNullOrWhiteSpace($logDirectory) -and -not (Test-Path -LiteralPath $logDirectory)) {
        [void](New-Item -ItemType Directory -Path $logDirectory -Force)
    }

    Invoke-LWCoreEnsureErrorLogCapacity -LogPath $script:LWErrorLogFile
}

function Invoke-LWCoreRequestRender {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if ($null -eq $script:LWUi) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender')) {
        $script:LWUi | Add-Member -Force -NotePropertyName NeedsRender -NotePropertyValue $true
        return
    }

    $script:LWUi.NeedsRender = $true
}

function Invoke-LWCoreAddNotification {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Set-LWModuleContext -Context $Context

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return
    }

    $existing = @()
    if ($null -ne $script:LWUi.Notifications) {
        $existing = @($script:LWUi.Notifications)
    }

    $existing = @($existing) + @([pscustomobject]@{
            Level   = $Level
            Message = $Message
        })

    $existingCount = @($existing).Count
    if ($existingCount -gt $script:LWNotificationBufferSize) {
        $existing = @($existing[($existingCount - $script:LWNotificationBufferSize)..($existingCount - 1)])
    }

    $script:LWUi.Notifications = @($existing)
    Invoke-LWCoreRequestRender -Context $Context
}

function Invoke-LWCoreWriteInfo {
    param(
        [hashtable]$Context,
        [string]$Message
    )

    Set-LWModuleContext -Context $Context
    Invoke-LWCoreAddNotification -Context $Context -Level 'Info' -Message $Message
    if (-not $script:LWUi.Enabled) {
        Write-LWDisplaySegmentedLine -Segments @(
            [pscustomobject]@{ Text = '[INFO] '; Color = 'Cyan' },
            [pscustomobject]@{ Text = $Message; Color = 'Gray' }
        )
    }
}

function Invoke-LWCoreWriteWarn {
    param(
        [hashtable]$Context,
        [string]$Message
    )

    Set-LWModuleContext -Context $Context
    Invoke-LWCoreAddNotification -Context $Context -Level 'Warn' -Message $Message
    if (-not $script:LWUi.Enabled) {
        Write-LWDisplaySegmentedLine -Segments @(
            [pscustomobject]@{ Text = '[WARN] '; Color = 'Yellow' },
            [pscustomobject]@{ Text = $Message; Color = 'Gray' }
        )
    }
}

function Invoke-LWCoreWriteError {
    param(
        [hashtable]$Context,
        [string]$Message
    )

    Set-LWModuleContext -Context $Context
    Invoke-LWCoreAddNotification -Context $Context -Level 'Error' -Message $Message
    if (-not $script:LWUi.Enabled) {
        Write-LWDisplaySegmentedLine -Segments @(
            [pscustomobject]@{ Text = '[ERROR] '; Color = 'Red' },
            [pscustomobject]@{ Text = $Message; Color = 'Gray' }
        )
    }
}

function Invoke-LWCoreWriteMessageLine {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

    switch ($Level) {
        'Info' {
            Write-LWDisplaySegmentedLine -Segments @(
                [pscustomobject]@{ Text = '[INFO] '; Color = 'Cyan' },
                [pscustomobject]@{ Text = $Message; Color = 'Gray' }
            )
        }
        'Warn' {
            Write-LWDisplaySegmentedLine -Segments @(
                [pscustomobject]@{ Text = '[WARN] '; Color = 'Yellow' },
                [pscustomobject]@{ Text = $Message; Color = 'Gray' }
            )
        }
        'Error' {
            Write-LWDisplaySegmentedLine -Segments @(
                [pscustomobject]@{ Text = '[ERROR] '; Color = 'Red' },
                [pscustomobject]@{ Text = $Message; Color = 'Gray' }
            )
        }
        default {
            Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $Message; Color = 'Gray' })
        }
    }
}

function Invoke-LWCoreWriteCrashLog {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$InputLine = '',
        [string]$Stage = 'command'
    )

    Set-LWModuleContext -Context $Context

    $logPath = $script:LWErrorLogFile
    $logDir = Split-Path -Parent $logPath
    if (-not [string]::IsNullOrWhiteSpace($logDir) -and -not (Test-Path -LiteralPath $logDir)) {
        [void](New-Item -ItemType Directory -Path $logDir -Force)
    }

    Invoke-LWCoreEnsureErrorLogCapacity -LogPath $logPath

    $bookNumber = ''
    $sectionNumber = ''
    $characterName = ''
    if ($null -ne $script:GameState) {
        if ($null -ne $script:GameState.Character) {
            $characterName = [string]$script:GameState.Character.Name
            $bookNumber = [string]$script:GameState.Character.BookNumber
        }
        $sectionNumber = [string]$script:GameState.CurrentSection
    }

    $entry = @(
        ('=' * 72)
        ('Timestamp : {0}' -f (Get-Date).ToString('o'))
        ('App       : {0} v{1}' -f $script:LWAppName, $script:LWAppVersion)
        ('Stage     : {0}' -f $Stage)
        ('Command   : {0}' -f $InputLine)
        ('Character : {0}' -f $characterName)
        ('Book      : {0}' -f $bookNumber)
        ('Section   : {0}' -f $sectionNumber)
        ('Message   : {0}' -f $ErrorRecord.Exception.Message)
        ('ErrorId   : {0}' -f $ErrorRecord.FullyQualifiedErrorId)
    )

    if ($ErrorRecord.InvocationInfo -and -not [string]::IsNullOrWhiteSpace($ErrorRecord.InvocationInfo.PositionMessage)) {
        $entry += 'Position  :'
        $entry += $ErrorRecord.InvocationInfo.PositionMessage.TrimEnd()
    }
    if (-not [string]::IsNullOrWhiteSpace($ErrorRecord.ScriptStackTrace)) {
        $entry += 'Stack     :'
        $entry += $ErrorRecord.ScriptStackTrace.TrimEnd()
    }
    $entry += ''

    Add-Content -Path $logPath -Value $entry -Encoding UTF8
    return $logPath
}

function Invoke-LWCoreClearNotifications {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context
    $script:LWUi.Notifications = @()
    Invoke-LWCoreRequestRender -Context $Context
}

function Invoke-LWCoreClearAchievementDisplayCountsCache {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context
    Clear-LWAchievementRenderCaches
}

function Invoke-LWCoreWarmRuntimeCaches {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        return
    }

    try {
        [void](Get-LWAchievementDefinitions)
        [void](Get-LWAchievementModeAvailabilitySnapshot -State $script:GameState)
        [void](Get-LWAchievementDisplayCounts)
        [void](Get-LWAchievementDefinitionsForContext -Context 'section' -State $script:GameState)
        [void](Get-LWAchievementDefinitionsForContext -Context 'healing' -State $script:GameState)
        [void](Get-LWCampaignSummary)
    }
    catch {
    }
}

function Invoke-LWCoreClearScreenHost {
    param([switch]$FullReset)

    $supportsAnsi = $false

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        try {
            if ($null -ne $PSStyle -and $null -ne $PSStyle.OutputRendering -and [string]$PSStyle.OutputRendering -ne 'PlainText') {
                $supportsAnsi = $true
            }
        }
        catch {
        }
    }

    if (-not $supportsAnsi) {
        if (-not [string]::IsNullOrWhiteSpace([string]$env:WT_SESSION) -or [string]$env:TERM_PROGRAM -eq 'vscode' -or [string]$env:ConEmuANSI -eq 'ON') {
            $supportsAnsi = $true
        }
    }

    if ($supportsAnsi) {
        try {
            if ($FullReset) {
                Write-Host "`e[2J`e[H" -NoNewline
            }
            else {
                Write-Host "`e[H`e[0J" -NoNewline
            }
            return
        }
        catch {
        }
    }

    try {
        Clear-Host
    }
    catch {
    }
}

function Invoke-LWCoreGetDefaultScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if ((Test-LWHasState) -and (Test-LWDeathActive)) {
        return 'death'
    }
    if ((Test-LWHasState) -and $script:GameState.Combat.Active) {
        return 'combat'
    }
    if (Test-LWHasState) {
        return 'sheet'
    }

    return 'welcome'
}

function Invoke-LWCoreSetScreen {
    param(
        [hashtable]$Context,
        [string]$Name = '',
        $Data = $null
    )

    Set-LWModuleContext -Context $Context

    $screenName = if ([string]::IsNullOrWhiteSpace($Name)) { Invoke-LWCoreGetDefaultScreen -Context $Context } else { $Name.Trim().ToLowerInvariant() }
    $script:LWUi.CurrentScreen = $screenName
    $script:LWUi.ScreenData = $Data
    Invoke-LWCoreRequestRender -Context $Context
}

function Invoke-LWCoreWriteNotifications {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $notifications = @($script:LWUi.Notifications)
    if (@($notifications).Count -eq 0) {
        return
    }

    Write-Host ''
    foreach ($notification in $notifications) {
        Invoke-LWCoreWriteMessageLine -Level ([string]$notification.Level) -Message ([string]$notification.Message)
    }
}

function Invoke-LWCoreWriteBannerFooter {
    param(
        [hashtable]$Context,
        [string]$ProductName = '',
        [switch]$VersionOnly,
        [switch]$ShowHelpLine
    )

    Set-LWModuleContext -Context $Context
    if ([string]::IsNullOrWhiteSpace($ProductName)) {
        $ProductName = $script:LWAppName
    }

    if ($VersionOnly -or [string]::IsNullOrWhiteSpace($ProductName)) {
        Write-LWSubtle ("  {0}" -f ("v{0}" -f $script:LWAppVersion).PadLeft(28))
    }
    else {
        Write-LWSubtle ("  {0}  v{1}" -f $ProductName, $script:LWAppVersion)
    }

    Write-LWSubtle '  ------------------------------------------------------------'
    if ($ShowHelpLine) {
        Write-LWSubtle '  Type help for commands.'
    }
    Write-Host ''
}

function Invoke-LWCoreWriteBanner {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $width = 64
    $contentWidth = $width - 4
    $border = '+' + ('=' * ($width - 2)) + '+'
    $titleText = "LONE WOLF ACTION ASSISTANT :: v$($script:LWAppVersion)"
    if ($titleText.Length -gt $contentWidth) {
        $titleText = $titleText.Substring(0, $contentWidth)
    }
    $title = $titleText.PadRight($contentWidth)

    Write-Host ''
    Write-Host $border -ForegroundColor (Get-LWScreenAccentColor)
    Write-Host '| ' -NoNewline -ForegroundColor DarkGray
    Write-Host $title -NoNewline -ForegroundColor 'Cyan'
    Write-Host ' |' -ForegroundColor DarkGray
    Write-Host $border -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-LWCoreWriteCommandPromptHint {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context
    Write-LWSubtle 'Type help for commands.'
}

function Format-LWBookFourStartingChoiceLine {
    param([Parameter(Mandatory = $true)][object]$Choice)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $costSuffix = ''
    if ((Test-LWPropertyExists -Object $Choice -Name 'GoldCost') -and $null -ne $Choice.GoldCost -and [int]$Choice.GoldCost -gt 0) {
        $costSuffix = " - $([int]$Choice.GoldCost) Gold"
    }

    $typeLabel = switch ([string]$Choice.Type) {
        'weapon' { 'Weapon' }
        'special' { 'Special Item' }
        'gold' { 'Gold' }
        'backpack_restore' { 'Backpack' }
        'backpack' {
            $slotCost = [int]$Choice.Quantity * (Get-LWBackpackItemSlotSize -Name ([string]$Choice.Name))
            "Backpack, $slotCost slot$(if ($slotCost -eq 1) { '' } else { 's' })"
        }
        default { [string]$Choice.Type }
    }

    return ("{0} [{1}]{2}" -f [string]$Choice.DisplayName, $typeLabel, $costSuffix)
}

function Invoke-LWBookFourStartingInventoryManagement {
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState)) {
        return
    }

    while ($true) {
        Set-LWScreen -Name 'inventory'
        Show-LWInventory
        if (-not (Read-LWYesNo -Prompt 'Drop an item to make room?' -Default $true)) {
            break
        }

        Remove-LWInventoryInteractive -InputParts @('drop')
        if (-not (Read-LWYesNo -Prompt 'Drop another item?' -Default $false)) {
            break
        }
    }
}

function Invoke-LWCoreWriteScreenFooterNote {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Set-LWModuleContext -Context $Context
    Write-Host ''
    Write-LWSubtle ("Note: {0}" -f $Message)
}

function Invoke-LWCoreShowHelpScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    Write-LWPanelHeader -Title 'Commands' -AccentColor 'Cyan'
    Write-LWKeyValue -Label 'new' -Value 'Create a new Kai character' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'newrun' -Value 'Start a fresh run on the same profile and keep achievements' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'sheet' -Value 'Show character sheet' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'modes' -Value 'Show run mode rules and locked settings' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'difficulty [name]' -Value 'Show the locked run difficulty' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'permadeath [on|off]' -Value 'Show the locked permadeath setting' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'inv' -Value 'Show inventory slots' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'disciplines' -Value 'Show disciplines' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'discipline add [name]' -Value 'Add a missed discipline reward for the active ruleset' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'notes' -Value 'Show notes' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'note [text]' -Value 'Add a note' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'note remove [n]' -Value 'Remove a note by number' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'history' -Value 'Show combat history grouped by book' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'stats [combat|survival]' -Value 'Show live current-book stats' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'campaign [view]' -Value 'Show whole-run overview, books, combat, survival, or milestones' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'achievements [view]' -Value 'Show unlocked, locked, recent, progress, or planned achievements' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'roll' -Value 'Roll the random number table (0-9)' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'section [n]' -Value 'Move to a new section' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'healcheck' -Value 'Apply Healing for a non-combat section' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'add [type name [qty]]' -Value 'Add inventory item' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'drop [type slot|all]' -Value 'Remove inventory item by slot or clear a section' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'recover [type|all]' -Value 'Restore stashed gear from a bulk drop' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'gold [delta]' -Value 'Gain or spend Gold Crowns' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'meal' -Value 'Resolve an eat instruction' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'potion' -Value 'Use a Healing or Laumspur Potion outside combat' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'end [delta]' -Value 'Adjust current Endurance only' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'die [cause]' -Value 'Record an instant death and open rewind options' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'fail [cause]' -Value 'Record a failed mission and open rewind options' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'rewind [n]' -Value 'After death or failure, return to an earlier safe section' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat start' -Value 'Start combat' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat round' -Value 'Resolve one combat round' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat next' -Value 'Alias for combat round' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat auto' -Value 'Resolve combat until it ends' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat status' -Value 'Show combat status' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat log [n|all|book n]' -Value 'Show the current, last, or archived combat log' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat evade' -Value 'Evade if allowed' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'combat stop' -Value 'Stop and archive current combat' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'fight [enemy cs end]' -Value 'Start combat, then auto-resolve it' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'mode [manual|data]' -Value 'Switch combat mode' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'complete' -Value 'Mark current book complete and add 1 discipline' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'setcs' -Value 'Manually set base Combat Skill' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'setend [current]' -Value 'Manually set current Endurance only' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'setmaxend [max]' -Value 'Manually set maximum Endurance' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'save' -Value 'Save to JSON' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'load [n|path]' -Value 'Load from JSON' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'quit' -Value 'Exit the terminal' -ValueColor 'Gray'
    Write-LWPanelHeader -Title 'Aliases' -AccentColor 'Magenta'
    Write-LWBulletItem -Text 'fight is a quick combat alias: it starts combat and auto-resolves it in one command.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'fight status/log/auto/round/next/evade/stop mirror the matching combat subcommands.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'inventory is the same as inv.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'combat next is the same as combat round.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'mode manual maps to ManualCRT, and mode data maps to DataFile.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'exit is the same as quit.' -TextColor 'Gray'
    Write-LWPanelHeader -Title 'Tips' -AccentColor 'DarkYellow'
    Write-LWBulletItem -Text 'While combat is active, pressing Enter advances one round.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Quick start syntax: combat start Giak 12 10' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use inv to see exact weapon, backpack, and special-item slots, including empty spaces.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use drop backpack 2 or drop weapon 1 to remove by slot number, or drop backpack all to clear a section.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Bulk drop stashes that section''s contents, so recover backpack or recover all can restore them later.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use discipline add to open the current ruleset discipline picker, or discipline add [name] to grant one directly.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use end -1 for section damage and end +1 for simple recovery without touching max END.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Shield and Silver Helm each add +2 Combat Skill automatically; Chainmail Waistcoat adds +4 END, Padded Leather Waistcoat adds +2 END, and Helmet adds +2 END unless Silver Helm is also carried.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Bone Sword is treated as a weapon and adds +1 Combat Skill in Book 3 / Kalte only; Broadsword +1 adds +1 Combat Skill and still counts as a Broadsword; Drodarin War Hammer adds +1 Combat Skill and counts as a Warhammer; Captain D''Val''s Sword adds +1 Combat Skill and counts as a Sword; Solnaris adds +2 Combat Skill and counts as a Sword or Broadsword for Weaponskill.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'From Book 2 onward, Sommerswerd is a weapon-like Special Item: +8 Combat Skill in combat, or +10 total with Sword, Short Sword, or Broadsword Weaponskill.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'When Sommerswerd is active against undead foes, their END loss is doubled automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'If an enemy is using Mindforce, the app can apply its extra END loss each round and Mindshield blocks it automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'In Book 3 and later, combat can attempt a knockout: edged weapons take -2 CS, while unarmed, Warhammer, Quarterstaff, and Mace do not.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'potion works with Healing Potion, Laumspur Potion, and Book 1 Laumspur Herb item names.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'potion now prefers Concentrated Laumspur first and restores 8 END when one is available.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'From Book 3 onward, if Alether is in your backpack, combat start can consume it before the fight to grant +4 Combat Skill for that combat only.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'New Book 1 runs now seed the starting Axe, Meal, Map of Sommerlund, random Gold, and random monastery item automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Book 1 section 170 now handles the Burrowcrawler''s torch darkness rule and Mindblast immunity automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use die for instant-death sections and fail for dead-end story failures. Then use rewind or rewind 2 to go back to earlier safe sections.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'history and combat log all now group archived fights by book for easier browsing.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use combat log book 2 to review archived fights from one book only.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use campaign to review the whole run, or campaign books/combat/survival/milestones for focused views.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use achievements, achievements progress, or achievements planned to browse the new achievement system.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Book 3 now has hidden story achievements tied to specific sections and discoveries, including the Diamond from section 218.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use modes to review Story, Easy, Normal, Hard, Veteran, and Permadeath before starting a run.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Difficulty is locked for the whole run, and Permadeath can only be chosen at run start.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'ManualCRT gives you the ratio and roll, then asks for losses from your own CRT.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'DataFile reads those losses from data/crt.json when the file is populated.' -TextColor 'Gray'
}

function Invoke-LWCoreShowStatsScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $summary = Get-LWLiveBookStatsSummary
    if ($null -eq $summary) {
        Write-LWWarn 'No live stats are available yet.'
        return
    }

    $view = 'overview'
    if ($null -ne $script:LWUi.ScreenData -and (Test-LWPropertyExists -Object $script:LWUi.ScreenData -Name 'View') -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.ScreenData.View)) {
        $view = [string]$script:LWUi.ScreenData.View
    }

    switch ($view.ToLowerInvariant()) {
        'combat' { Show-LWStatsCombat -Summary $summary }
        'survival' { Show-LWStatsSurvival -Summary $summary }
        default { Show-LWStatsOverview -Summary $summary }
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'stats' -View $view

    if ($summary.PartialTracking) {
        Write-LWScreenFooterNote -Message 'current-book totals may be partial.'
    }
}

function Invoke-LWCoreShowCampaignScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $summary = Get-LWCampaignSummary
    if ($null -eq $summary) {
        Write-LWWarn 'No campaign data is available yet.'
        return
    }

    $view = 'overview'
    if ($null -ne $script:LWUi.ScreenData -and (Test-LWPropertyExists -Object $script:LWUi.ScreenData -Name 'View') -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.ScreenData.View)) {
        $view = [string]$script:LWUi.ScreenData.View
    }

    switch ($view.ToLowerInvariant()) {
        'books' { Show-LWCampaignBooks -Summary $summary }
        'combat' { Show-LWCampaignCombat -Summary $summary }
        'survival' { Show-LWCampaignSurvival -Summary $summary }
        'milestones' { Show-LWCampaignMilestones -Summary $summary }
        default { Show-LWCampaignOverview -Summary $summary }
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'campaign' -View $view

    if ($summary.PartialTracking) {
        Write-LWScreenFooterNote -Message 'older run totals may be partial.'
    }
}

function Invoke-LWCoreShowAchievementsScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $view = 'overview'
    if ($null -ne $script:LWUi.ScreenData -and (Test-LWPropertyExists -Object $script:LWUi.ScreenData -Name 'View') -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.ScreenData.View)) {
        $view = [string]$script:LWUi.ScreenData.View
    }

    switch ($view.ToLowerInvariant()) {
        'unlocked' { Show-LWAchievementUnlockedList }
        'locked' { Show-LWAchievementLockedList }
        'recent' { Show-LWAchievementRecentList }
        'progress' { Show-LWAchievementProgressList }
        'planned' { Show-LWAchievementPlannedList }
        default { Show-LWAchievementOverview }
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'achievements' -View $view
}

function Invoke-LWCoreShowInventoryScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $weapons = @($script:GameState.Inventory.Weapons)
    $backpack = @($script:GameState.Inventory.BackpackItems)
    $special = @($script:GameState.Inventory.SpecialItems)
    $pocketSpecial = @(Get-LWPocketSpecialItems)
    $herbPouch = @($script:GameState.Inventory.HerbPouchItems)
    $backpackUsedCapacity = Get-LWInventoryUsedCapacity -Type 'backpack' -Items $backpack
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState
    $summaryEntries = @(
        [pscustomobject]@{ Label = 'Gold Crowns'; Value = ("{0}/50" -f $script:GameState.Inventory.GoldCrowns); Color = 'Yellow' }
        [pscustomobject]@{ Label = 'Weapons'; Value = ("{0}/2" -f $weapons.Count); Color = 'Green' }
        [pscustomobject]@{ Label = 'Backpack'; Value = $(if ($hasBackpack) { "{0}/8" -f $backpackUsedCapacity } else { 'lost' }); Color = $(if ($hasBackpack) { 'Yellow' } else { 'DarkGray' }) }
    )
    if (Test-LWStateHasHerbPouch -State $script:GameState) {
        $summaryEntries += [pscustomobject]@{ Label = 'Herb Pouch'; Value = ("{0}/6" -f $herbPouch.Count); Color = 'DarkGreen' }
    }
    $summaryEntries += [pscustomobject]@{ Label = 'Special Items'; Value = ("{0}/12" -f $special.Count); Color = 'DarkCyan' }
    if ((Test-LWStateHasQuiver -State $script:GameState) -or (Get-LWQuiverArrowCount -State $script:GameState) -gt 0) {
        $summaryEntries += [pscustomobject]@{ Label = 'Arrows'; Value = (Format-LWQuiverArrowCounter -State $script:GameState); Color = 'DarkYellow' }
    }

    Write-LWRetroPanelHeader -Title 'Inventory' -AccentColor 'Yellow'
    for ($i = 0; $i -lt $summaryEntries.Count; $i += 2) {
        $leftEntry = $summaryEntries[$i]
        $rightEntry = if (($i + 1) -lt $summaryEntries.Count) { $summaryEntries[$i + 1] } else { $null }

        if ($null -ne $rightEntry) {
            Write-LWRetroPanelPairRow `
                -LeftLabel ([string]$leftEntry.Label) `
                -LeftValue ([string]$leftEntry.Value) `
                -RightLabel ([string]$rightEntry.Label) `
                -RightValue ([string]$rightEntry.Value) `
                -LeftColor ([string]$leftEntry.Color) `
                -RightColor ([string]$rightEntry.Color)
        }
        else {
            Write-LWRetroPanelKeyValueRow -Label ([string]$leftEntry.Label) -Value ([string]$leftEntry.Value) -ValueColor ([string]$leftEntry.Color)
        }
    }
    Write-LWRetroPanelFooter

    Show-LWInventorySlotsGridSection -Type 'weapon'
    Show-LWInventorySlotsGridSection -Type 'backpack'
    if (Test-LWStateHasHerbPouch -State $script:GameState) {
        Show-LWInventorySlotsGridSection -Type 'herbpouch'
    }
    Show-LWInventorySlotsGridSection -Type 'special'

    Write-LWRetroPanelHeader -Title 'Stored / Stashed' -AccentColor 'DarkGray'
    if ($pocketSpecial.Count -gt 0) {
        Write-LWRetroPanelWrappedKeyValueRows -Label 'Pocket Items' -Value (Format-LWList -Items $pocketSpecial) -ValueColor 'DarkYellow'
    }
    Write-LWRetroPanelWrappedKeyValueRows -Label 'Safekeeping' -Value $(if (@($script:GameState.Storage.SafekeepingSpecialItems).Count -gt 0) { Format-LWList -Items @($script:GameState.Storage.SafekeepingSpecialItems) } else { '(none)' }) -ValueColor 'DarkGray'
    Write-LWRetroPanelWrappedKeyValueRows -Label 'Confiscated' -Value $(if (Test-LWStateHasConfiscatedEquipment) { Get-LWConfiscatedInventorySummaryText } else { '(none)' }) -ValueColor 'DarkGray'
    Write-LWRetroPanelFooter

    Show-LWInventoryNotesPanel

    Show-LWHelpfulCommandsPanel -ScreenName 'inventory'
}

function Invoke-LWCoreShowSheetScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $shieldBonus = Get-LWStateShieldCombatSkillBonus -State $script:GameState
    $silverHelmBonus = Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState
    $displayCombatSkill = [int]$script:GameState.Character.CombatSkillBase + $shieldBonus + $silverHelmBonus
    $combatSkillText = [string]$displayCombatSkill
    if (Test-LWBookFiveLimbdeathActive -State $script:GameState) {
        $displayCombatSkill -= 3
        $combatSkillText = [string]$displayCombatSkill
    }

    $enduranceText = "{0} / {1}" -f $script:GameState.Character.EnduranceCurrent, $script:GameState.Character.EnduranceMax

    Write-LWRetroPanelHeader -Title 'Character Sheet' -AccentColor 'Cyan'
    Write-LWRetroPanelKeyValueRow -Label 'Name' -Value $script:GameState.Character.Name -ValueColor 'White' -LabelWidth 12
    $rankText = [string](Get-LWCurrentRankLabel -State $script:GameState)
    if ($rankText -match '^\d+\s*-\s*(.+)$') {
        $rankText = [string]$Matches[1]
    }
    Write-LWRetroPanelPairRow -LeftLabel 'Section' -LeftValue ([string]$script:GameState.CurrentSection) -RightLabel 'Rank' -RightValue $rankText -LeftColor 'White' -RightColor 'DarkYellow' -LeftLabelWidth 12 -RightLabelWidth 12 -LeftWidth 24 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Skill' -LeftValue $combatSkillText -RightLabel 'Endurance' -RightValue $enduranceText -LeftColor 'Cyan' -RightColor (Get-LWEnduranceColor -Current $script:GameState.Character.EnduranceCurrent -Max $script:GameState.Character.EnduranceMax) -LeftLabelWidth 12 -RightLabelWidth 12 -LeftWidth 24 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Difficulty' -LeftValue (Get-LWCurrentDifficulty) -RightLabel 'Run Integrity' -RightValue ([string]$script:GameState.Run.IntegrityState) -LeftColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty)) -RightColor (Get-LWIntegrityColor -IntegrityState ([string]$script:GameState.Run.IntegrityState)) -LeftLabelWidth 12 -RightLabelWidth 12 -LeftWidth 24 -Gap 2
    Write-LWRetroPanelFooter
    Show-LWDisciplines
    Show-LWInventorySummary
    Show-LWHelpfulCommandsPanel -ScreenName 'sheet'
}

function Invoke-LWCoreShowWelcomeScreen {
    param(
        [hashtable]$Context,
        [switch]$NoBanner
    )

    Set-LWModuleContext -Context $Context

    if (-not $NoBanner) {
        Invoke-LWCoreWriteBanner -Context $Context
    }
    Write-LWRetroPanelHeader -Title 'Welcome' -AccentColor 'Cyan'
    Write-LWRetroPanelPairRow -LeftLabel 'load' -LeftValue 'open a save' -RightLabel 'new' -RightValue 'create a character' -LeftColor 'Gray' -RightColor 'Gray' -LeftLabelWidth 8 -RightLabelWidth 7 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'newrun' -LeftValue 'begin a new run' -RightLabel 'help' -RightValue 'show commands' -LeftColor 'Gray' -RightColor 'Gray' -LeftLabelWidth 8 -RightLabelWidth 7 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Quick Start' -AccentColor 'DarkYellow'
    Write-LWRetroPanelTextRow -Text '1. Load a save to continue an adventure.' -TextColor 'Gray'
    Write-LWRetroPanelTextRow -Text '2. Use sheet, inv, or campaign to review state.' -TextColor 'Gray'
    Write-LWRetroPanelTextRow -Text '3. Use section <n> as you read through the book.' -TextColor 'Gray'
    Write-LWRetroPanelFooter

    Show-LWHelpfulCommandsPanel -ScreenName 'welcome'
}

function Invoke-LWCoreShowLoadScreen {
    param(
        [hashtable]$Context,
        [object[]]$SaveFiles = @()
    )

    Set-LWModuleContext -Context $Context

    $catalogEntries = @()
    foreach ($entry in @($SaveFiles)) {
        if ($null -eq $entry) {
            continue
        }

        if ((Test-LWPropertyExists -Object $entry -Name 'SaveFiles') -and $null -ne $entry.SaveFiles) {
            foreach ($nestedEntry in @($entry.SaveFiles)) {
                if ($null -ne $nestedEntry) {
                    $catalogEntries += $nestedEntry
                }
            }
            continue
        }

        $catalogEntries += $entry
    }

    $catalogEntries = @(
        foreach ($entry in @($catalogEntries)) {
            if ($null -eq $entry) {
                continue
            }

            if ((Test-LWPropertyExists -Object $entry -Name 'FullName') -or
                (Test-LWPropertyExists -Object $entry -Name 'Index') -or
                (Test-LWPropertyExists -Object $entry -Name 'BookNumber')) {
                $entry
            }
        }
    )

    Write-LWBanner
    Write-LWRetroPanelHeader -Title 'Save Catalog' -AccentColor 'Cyan'
    if (@($catalogEntries).Count -gt 0) {
        Show-LWSaveCatalog -SaveFiles $catalogEntries
    }
    else {
        Write-LWRetroPanelTextRow -Text ("No saves found in {0} yet." -f $SaveDir) -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter

    Show-LWHelpfulCommandsPanel -ScreenName 'load'
}

function Invoke-LWCoreShowDisciplineSelectionScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $screenData = $script:LWUi.ScreenData
    $available = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Available')) { @($screenData.Available) } else { @() }
    $count = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Count')) { [int]$screenData.Count } else { 1 }
    $ruleSetName = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'RuleSet') -and -not [string]::IsNullOrWhiteSpace([string]$screenData.RuleSet)) { [string]$screenData.RuleSet } else { 'Kai' }
    $title = if ($ruleSetName -ieq 'Magnakai') { 'Choose Magnakai Discipline' } else { 'Choose Kai Discipline' }

    Write-LWBanner
    Write-LWPanelHeader -Title $title -AccentColor 'DarkYellow'
    Write-LWBulletItem -Text ("Choose {0} discipline{1} for this character." -f $count, $(if ($count -eq 1) { '' } else { 's' })) -TextColor 'Gray'
    Write-LWSubtle ''

    for ($i = 0; $i -lt @($available).Count; $i++) {
        $entry = $available[$i]
        Write-Host ("  {0,2}. " -f ($i + 1)) -NoNewline -ForegroundColor DarkYellow
        Write-Host ([string]$entry.Name) -NoNewline -ForegroundColor Green
        Write-Host (" - {0}" -f [string]$entry.Effect) -ForegroundColor Gray
    }

    Write-Host ''
    Write-LWSubtle ("  Enter {0} number(s) separated by commas." -f $count)

    Show-LWHelpfulCommandsPanel -ScreenName 'disciplineselect'
}

function Invoke-LWCoreShowCombatScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $screenData = $script:LWUi.ScreenData

    if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'View') -and [string]$screenData.View -eq 'setup') {
        Write-LWRetroPanelHeader -Title 'Combat Setup' -AccentColor 'Red'

        if ((Test-LWPropertyExists -Object $screenData -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$screenData.EnemyName)) {
            Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$screenData.EnemyName) -ValueColor 'White'
        }
        if ((Test-LWPropertyExists -Object $screenData -Name 'EnemyCombatSkill') -and $null -ne $screenData.EnemyCombatSkill) {
            Write-LWRetroPanelKeyValueRow -Label 'Enemy CS' -Value ([string]$screenData.EnemyCombatSkill) -ValueColor 'Gray'
        }
        if ((Test-LWPropertyExists -Object $screenData -Name 'EnemyEndurance') -and $null -ne $screenData.EnemyEndurance) {
            Write-LWRetroPanelKeyValueRow -Label 'Enemy END' -Value ([string]$screenData.EnemyEndurance) -ValueColor 'Red'
        }
        Write-LWRetroPanelTextRow -Text 'Answer the prompts below to begin the fight.' -TextColor 'Gray'
        Write-LWRetroPanelFooter

        if ((Test-LWPropertyExists -Object $screenData -Name 'Weapons') -and @($screenData.Weapons).Count -gt 1) {
            $defaultIndex = if ((Test-LWPropertyExists -Object $screenData -Name 'DefaultIndex') -and $null -ne $screenData.DefaultIndex) { [int]$screenData.DefaultIndex } else { 1 }
            Write-LWRetroPanelHeader -Title 'Weapon Selection' -AccentColor 'DarkYellow'
            Write-LWRetroPanelTextRow -Text ' 0. Bare hands / unarmed' -TextColor 'DarkGray'
            for ($i = 0; $i -lt @($screenData.Weapons).Count; $i++) {
                $suffix = if (($i + 1) -eq $defaultIndex) { ' (default)' } else { '' }
                Write-LWRetroPanelTextRow -Text ("{0,2}. {1}{2}" -f ($i + 1), [string]$screenData.Weapons[$i], $suffix) -TextColor 'Gray'
            }
            Write-LWRetroPanelFooter
        }
        Show-LWHelpfulCommandsPanel -ScreenName 'combat' -Variant 'setup'
        return
    }

    if ((Test-LWHasState) -and $script:GameState.Combat.Active) {
        Show-LWCombatStatus
        return
    }

    if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'View') -and [string]$screenData.View -eq 'summary' -and (Test-LWPropertyExists -Object $screenData -Name 'Summary') -and $null -ne $screenData.Summary) {
        Show-LWCombatSummary -Summary $screenData.Summary
        return
    }

    Write-LWRetroPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWRetroPanelTextRow -Text 'No active combat.' -TextColor 'DarkGray'
    Write-LWRetroPanelFooter
    Show-LWHelpfulCommandsPanel -ScreenName 'combat' -Variant 'inactive'
}

function Invoke-LWCoreShowCombatLogScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $screenData = $script:LWUi.ScreenData
    $hasEntry = ($null -ne $screenData) -and (Test-LWPropertyExists -Object $screenData -Name 'Entry') -and ($null -ne $screenData.Entry)
    $showAll = ($null -ne $screenData) -and (Test-LWPropertyExists -Object $screenData -Name 'All') -and [bool]$screenData.All
    $bookNumber = if (($null -ne $screenData) -and (Test-LWPropertyExists -Object $screenData -Name 'BookNumber') -and $null -ne $screenData.BookNumber) { [int]$screenData.BookNumber } else { $null }

    if ($showAll -or $null -ne $bookNumber) {
        Show-LWCombatLog -All -BookNumber $bookNumber
        Show-LWHelpfulCommandsPanel -ScreenName 'combatlog'
        return
    }

    if ($hasEntry) {
        Write-LWCombatLogEntry -Entry $screenData.Entry
        Show-LWHelpfulCommandsPanel -ScreenName 'combatlog'
        return
    }

    Show-LWCombatLog
    Show-LWHelpfulCommandsPanel -ScreenName 'combatlog'
}

function Invoke-LWCoreShowModesScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $screenData = $script:LWUi.ScreenData
    $selectedDifficulty = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Difficulty')) { Get-LWNormalizedDifficultyName -Difficulty ([string]$screenData.Difficulty) } elseif (Test-LWHasState) { Get-LWCurrentDifficulty } else { 'Normal' }
    $selectedPermadeath = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Permadeath')) { [bool]$screenData.Permadeath } elseif (Test-LWHasState) { [bool](Test-LWPermadeathEnabled) } else { $false }
    $poolLabel = Get-LWModeAchievementPoolLabel -State ([pscustomobject]@{ Run = [pscustomobject]@{ Difficulty = $selectedDifficulty; Permadeath = $selectedPermadeath; IntegrityState = 'Clean' } })

    Write-LWRetroPanelHeader -Title 'Current Mode Setup' -AccentColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Difficulty' -LeftValue $selectedDifficulty -RightLabel 'Permadeath' -RightValue $(if ($selectedPermadeath) { 'On' } else { 'Off' }) -LeftColor (Get-LWDifficultyColor -Difficulty $selectedDifficulty) -RightColor $(if ($selectedPermadeath) { 'Red' } else { 'Gray' })
    if (Test-LWHasState) {
        Write-LWRetroPanelPairRow -LeftLabel 'Combat Mode' -LeftValue ([string]$script:GameState.Settings.CombatMode) -RightLabel 'Run Integrity' -RightValue ([string]$script:GameState.Run.IntegrityState) -LeftColor (Get-LWModeColor -Mode ([string]$script:GameState.Settings.CombatMode)) -RightColor (Get-LWIntegrityColor -IntegrityState ([string]$script:GameState.Run.IntegrityState))
    }
    else {
        Write-LWRetroPanelPairRow -LeftLabel 'Achievement' -LeftValue $poolLabel -RightLabel 'Locked For Run' -RightValue 'Yes' -LeftColor 'DarkYellow' -RightColor 'Yellow'
    }
    Write-LWRetroPanelFooter

    $definitions = @(Get-LWDifficultyDefinitions)
    Write-LWRetroPanelHeader -Title 'Difficulty Options' -AccentColor 'Cyan'
    for ($i = 0; $i -lt @($definitions).Count; $i += 2) {
        $left = $definitions[$i]
        $right = if (($i + 1) -lt @($definitions).Count) { $definitions[$i + 1] } else { $null }
        Write-LWRetroPanelTwoColumnRow `
            -LeftText ([string]$left.Name) `
            -RightText $(if ($null -ne $right) { [string]$right.Name } else { '' }) `
            -LeftColor (Get-LWDifficultyColor -Difficulty ([string]$left.Name)) `
            -RightColor $(if ($null -ne $right) { Get-LWDifficultyColor -Difficulty ([string]$right.Name) } else { 'Gray' }) `
            -LeftWidth 28 `
            -Gap 2
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Mode Rules' -AccentColor 'DarkYellow'
    foreach ($entry in @($definitions)) {
        Write-LWRetroPanelTextRow -Text ("{0}: {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray'
    }
    Write-LWRetroPanelTextRow -Text 'Permadeath disables rewind after death.' -TextColor 'Gray'
    Write-LWRetroPanelFooter

    Show-LWHelpfulCommandsPanel -ScreenName 'modes'
}

function Invoke-LWCoreShowDeathScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
        return
    }

    $deathState = Get-LWActiveDeathState
    if ($null -eq $deathState) {
        Invoke-LWCoreSetScreen -Context $Context -Name (Invoke-LWCoreGetDefaultScreen -Context $Context)
        Show-LWSheet
        return
    }

    $causeText = if ([string]::IsNullOrWhiteSpace([string]$deathState.Cause)) { 'A fatal choice ended this path.' } else { [string]$deathState.Cause }

    Write-LWRetroPanelHeader -Title 'Death' -AccentColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Character' -LeftValue $script:GameState.Character.Name -RightLabel 'Book / Section' -RightValue ("{0} / {1}" -f [int]$deathState.BookNumber, [string]$deathState.Section) -LeftColor 'White' -RightColor 'Gray' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Difficulty' -LeftValue (Get-LWCurrentDifficulty) -RightLabel 'Permadeath' -RightValue $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }) -LeftColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty)) -RightColor $(if (Test-LWPermadeathEnabled) { 'Red' } else { 'Gray' }) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelDivider
    Write-LWRetroPanelWrappedKeyValueRows -Label 'Cause' -Value $causeText -ValueColor 'Gray'
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Final State' -AccentColor 'DarkYellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Skill' -LeftValue ([string]$script:GameState.Character.CombatSkillBase) -RightLabel 'Endurance' -RightValue ("{0} / {1}" -f [int]$script:GameState.Character.EnduranceCurrent, [int]$script:GameState.Character.EnduranceMax) -LeftColor 'Cyan' -RightColor (Get-LWEnduranceColor -Current ([int]$script:GameState.Character.EnduranceCurrent) -Max ([int]$script:GameState.Character.EnduranceMax))
    Write-LWRetroPanelPairRow -LeftLabel 'Gold Crowns' -LeftValue ("{0} / 50" -f [int]$script:GameState.Inventory.GoldCrowns) -RightLabel 'Run Integrity' -RightValue ([string]$script:GameState.Run.IntegrityState) -LeftColor 'Yellow' -RightColor (Get-LWIntegrityColor -IntegrityState ([string]$script:GameState.Run.IntegrityState))
    Write-LWRetroPanelFooter

    Show-LWHelpfulCommandsPanel -ScreenName 'death'
}

function Invoke-LWCoreShowBookCompleteScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $screenData = $script:LWUi.ScreenData
    if ($null -eq $screenData) {
        Invoke-LWCoreSetScreen -Context $Context -Name 'sheet'
        Show-LWSheet
        return
    }

    Write-LWBanner
    $continueToBookLabel = if ((Test-LWPropertyExists -Object $screenData -Name 'ContinueToBookLabel') -and -not [string]::IsNullOrWhiteSpace([string]$screenData.ContinueToBookLabel)) {
        [string]$screenData.ContinueToBookLabel
    }
    else {
        ''
    }
    $snapshot = if ((Test-LWPropertyExists -Object $screenData -Name 'Snapshot') -and $null -ne $screenData.Snapshot) {
        $screenData.Snapshot
    }
    else {
        $null
    }

    Show-LWBookCompletionSummary -Summary $screenData.Summary -CharacterName $screenData.CharacterName -Snapshot $snapshot -ContinueToBookLabel $continueToBookLabel

    if ([string]::IsNullOrWhiteSpace($continueToBookLabel)) {
        Show-LWHelpfulCommandsPanel -ScreenName 'bookcomplete'
    }
    else {
        Write-LWScreenFooterNote -Message ("Press Enter to continue to {0} setup." -f $continueToBookLabel)
    }
}

function Invoke-LWCoreRefreshScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not $script:LWUi.Enabled) {
        return
    }

    if ((Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender') -and -not [bool]$script:LWUi.NeedsRender) {
        return
    }

    $currentScreenName = if ($null -ne $script:LWUi -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.CurrentScreen)) {
        [string]$script:LWUi.CurrentScreen
    }
    else {
        'welcome'
    }
    $lastRenderedScreen = if ((Test-LWPropertyExists -Object $script:LWUi -Name 'LastRenderedScreen') -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.LastRenderedScreen)) {
        [string]$script:LWUi.LastRenderedScreen
    }
    else {
        ''
    }
    $screenChanged = ($currentScreenName -ne $lastRenderedScreen)

    Invoke-LWCoreClearScreenHost -FullReset:$screenChanged

    $script:LWUi.IsRendering = $true
    try {
        switch ($script:LWUi.CurrentScreen) {
            'sheet' {
                Invoke-LWCoreWriteBanner -Context $Context
                if (Test-LWHasState) {
                    Invoke-LWCoreShowSheetScreen -Context $Context
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'inventory' {
                Invoke-LWCoreWriteBanner -Context $Context
                if (Test-LWHasState) {
                    Invoke-LWCoreShowInventoryScreen -Context $Context
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'combat' {
                Invoke-LWCoreWriteBanner -Context $Context
                Invoke-LWCoreShowCombatScreen -Context $Context
            }
            'combatlog' {
                Invoke-LWCoreWriteBanner -Context $Context
                Invoke-LWCoreShowCombatLogScreen -Context $Context
            }
            'disciplines' {
                Invoke-LWCoreWriteBanner -Context $Context
                if (Test-LWHasState) {
                    Show-LWDisciplines
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'notes' {
                Invoke-LWCoreWriteBanner -Context $Context
                if (Test-LWHasState) {
                    Show-LWNotes
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'history' {
                Invoke-LWCoreWriteBanner -Context $Context
                if (Test-LWHasState) {
                    Show-LWHistory
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'stats' {
                Invoke-LWCoreWriteBanner -Context $Context
                if (Test-LWHasState) {
                    Invoke-LWCoreShowStatsScreen -Context $Context
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'campaign' {
                Write-LWBanner
                if (Test-LWHasState) {
                    Invoke-LWCoreShowCampaignScreen -Context $Context
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'achievements' {
                Write-LWBanner
                if (Test-LWHasState) {
                    Invoke-LWCoreShowAchievementsScreen -Context $Context
                }
                else {
                    Invoke-LWCoreShowWelcomeScreen -Context $Context -NoBanner
                }
            }
            'modes' {
                Write-LWBanner
                Invoke-LWCoreShowModesScreen -Context $Context
            }
            'help' {
                Invoke-LWCoreWriteBanner -Context $Context
                Invoke-LWCoreShowHelpScreen -Context $Context
            }
            'load' {
                $saveFiles = if ($null -ne $script:LWUi.ScreenData -and (Test-LWPropertyExists -Object $script:LWUi.ScreenData -Name 'SaveFiles')) { @($script:LWUi.ScreenData.SaveFiles) } else { @() }
                Invoke-LWCoreShowLoadScreen -Context $Context -SaveFiles $saveFiles
            }
            'disciplineselect' {
                Invoke-LWCoreShowDisciplineSelectionScreen -Context $Context
            }
            'bookcomplete' {
                Invoke-LWCoreShowBookCompleteScreen -Context $Context
            }
            'death' {
                Invoke-LWCoreWriteBanner -Context $Context
                Invoke-LWCoreShowDeathScreen -Context $Context
            }
            default {
                Invoke-LWCoreShowWelcomeScreen -Context $Context
            }
        }
    }
    finally {
        $script:LWUi.IsRendering = $false
        $script:LWUi.LastRenderedScreen = $currentScreenName
        if (Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender') {
            $script:LWUi.NeedsRender = $false
        }
    }

    Invoke-LWCoreWriteNotifications -Context $Context
}

function Get-LWBookDisplayLine {
    param([int]$BookNumber)

    return ("{0}. {1}" -f $BookNumber, (Get-LWBookTitle -BookNumber $BookNumber))
}

function Get-LWBookFourSectionChoiceLine {
    param([Parameter(Mandatory = $true)][object]$Choice)

    return (Format-LWBookFourStartingChoiceLine -Choice $Choice)
}

function Get-LWAvailableSectionChoices {
    param([Parameter(Mandatory = $true)][object[]]$Choices)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $claimedGroups = @(
        foreach ($choice in @($Choices)) {
            if ($null -eq $choice) { continue }
            $groupName = if (Test-LWPropertyExists -Object $choice -Name 'ExclusiveGroup') { [string]$choice.ExclusiveGroup } else { '' }
            $flagName = if (Test-LWPropertyExists -Object $choice -Name 'FlagName') { [string]$choice.FlagName } else { '' }
            if ([string]::IsNullOrWhiteSpace($groupName) -or [string]::IsNullOrWhiteSpace($flagName)) {
                continue
            }
            if (Test-LWStoryAchievementFlag -Name $flagName) {
                $groupName
            }
        }
    ) | Sort-Object -Unique

    return @(
        foreach ($choice in @($Choices)) {
            if ($null -eq $choice) { continue }
            $flagName = if (Test-LWPropertyExists -Object $choice -Name 'FlagName') { [string]$choice.FlagName } else { '' }
            $groupName = if (Test-LWPropertyExists -Object $choice -Name 'ExclusiveGroup') { [string]$choice.ExclusiveGroup } else { '' }

            if (-not [string]::IsNullOrWhiteSpace($flagName) -and (Test-LWStoryAchievementFlag -Name $flagName)) {
                continue
            }
            if (-not [string]::IsNullOrWhiteSpace($groupName) -and ($claimedGroups -contains $groupName)) {
                continue
            }

            $choice
        }
    )
}

function Grant-LWSectionGenericChoice {
    param(
        [Parameter(Mandatory = $true)][object]$Choice,
        [Parameter(Mandatory = $true)][string]$ContextLabel
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Choice) {
        return $false
    }

    $goldCost = if ((Test-LWPropertyExists -Object $Choice -Name 'GoldCost') -and $null -ne $Choice.GoldCost) { [int]$Choice.GoldCost } else { 0 }
    if ($goldCost -gt 0) {
        if ([int]$script:GameState.Inventory.GoldCrowns -lt $goldCost) {
            Write-LWWarn ("You need {0} Gold Crown{1} for {2}." -f $goldCost, $(if ($goldCost -eq 1) { '' } else { 's' }), [string]$Choice.DisplayName)
            return $false
        }
    }

    $granted = $false
    $successMessage = $null
    switch ([string]$Choice.Type) {
        'weapon' {
            $granted = Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName)
        }
        'gold' {
            $oldGold = [int]$script:GameState.Inventory.GoldCrowns
            $newGold = [Math]::Min(50, ($oldGold + [int]$Choice.Quantity))
            $addedGold = $newGold - $oldGold
            if ($addedGold -le 0) {
                Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Spend some Gold Crowns first if you want to keep it.'
                return $false
            }

            $script:GameState.Inventory.GoldCrowns = $newGold
            Add-LWBookGoldDelta -Delta $addedGold
            [void](Sync-LWAchievements -Context 'gold')
            if ($newGold -lt ($oldGold + [int]$Choice.Quantity)) {
                Write-LWWarn ("Gold Crowns are capped at 50. Excess gold from {0} is lost." -f $ContextLabel.ToLowerInvariant())
            }
            $granted = $true
        }
        'backpack_restore' {
            if (Test-LWStateHasBackpack -State $script:GameState) {
                $successMessage = ("{0}: you already have a Backpack." -f $ContextLabel)
            }
            else {
                Restore-LWBackpackState
                $successMessage = ("{0}: Backpack restored." -f $ContextLabel)
            }
            $granted = $true
        }
        default {
            $granted = TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)
        }
    }

    if (-not $granted) {
        Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Make room and try again if you are keeping it.'
        return $false
    }

    if ($goldCost -gt 0) {
        $script:GameState.Inventory.GoldCrowns = [Math]::Max(0, ([int]$script:GameState.Inventory.GoldCrowns - $goldCost))
        Add-LWBookGoldDelta -Delta (-$goldCost)
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    if (-not [string]::IsNullOrWhiteSpace($successMessage)) {
        Write-LWInfo $successMessage
    }
    else {
        if ($goldCost -gt 0) {
            Write-LWInfo ("{0}: added {1} for {2} Gold Crown{3}." -f $ContextLabel, [string]$Choice.Description, $goldCost, $(if ($goldCost -eq 1) { '' } else { 's' }))
        }
        else {
            Write-LWInfo ("{0}: added {1}." -f $ContextLabel, [string]$Choice.Description)
        }
    }
    return $true
}

function Grant-LWBookFourGenericChoice {
    param(
        [Parameter(Mandatory = $true)][object]$Choice,
        [Parameter(Mandatory = $true)][string]$ContextLabel
    )

    return (Grant-LWSectionGenericChoice -Choice $Choice -ContextLabel $ContextLabel)
}

function Invoke-LWSectionGoldReward {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][int]$Amount,
        [Parameter(Mandatory = $true)][string]$ContextLabel,
        [string]$MessagePrefix = ''
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return $false
    }

    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + [int]$Amount))
    $addedGold = $newGold - $oldGold
    if ($addedGold -le 0) {
        Write-LWWarn ("{0}: you cannot carry any more Gold Crowns right now." -f $ContextLabel)
        return $false
    }

    $script:GameState.Inventory.GoldCrowns = $newGold
    Add-LWBookGoldDelta -Delta $addedGold
    [void](Sync-LWAchievements -Context 'gold')
    Set-LWStoryAchievementFlag -Name $FlagName

    if (-not [string]::IsNullOrWhiteSpace($MessagePrefix)) {
        Write-LWInfo ("{0} Added {1} Gold Crown{2}." -f $MessagePrefix, $addedGold, $(if ($addedGold -eq 1) { '' } else { 's' }))
    }
    else {
        Write-LWInfo ("{0}: added {1} Gold Crown{2}." -f $ContextLabel, $addedGold, $(if ($addedGold -eq 1) { '' } else { 's' }))
    }

    if ($newGold -lt ($oldGold + [int]$Amount)) {
        Write-LWWarn ("Gold Crowns are capped at 50. Excess gold from {0} is lost." -f $ContextLabel.ToLowerInvariant())
    }
    return $true
}

function Invoke-LWSectionPaymentChoice {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$PromptLabel,
        [Parameter(Mandatory = $true)][string]$ContextLabel,
        [Parameter(Mandatory = $true)][object[]]$Options,
        [string]$Intro = '',
        [string]$ResolvedFlagName = '',
        [string]$DeclineText = '0. Do nothing'
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not [string]::IsNullOrWhiteSpace($ResolvedFlagName) -and (Test-LWStoryAchievementFlag -Name $ResolvedFlagName)) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($Intro)) {
        Write-LWInfo $Intro
    }

    while ($true) {
        Write-LWRetroPanelHeader -Title $Title -AccentColor 'DarkYellow'
        Write-LWRetroPanelKeyValueRow -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWRetroPanelKeyValueRow -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        Write-LWRetroPanelDivider

        for ($i = 0; $i -lt @($Options).Count; $i++) {
            $option = $Options[$i]
            $line = [string]$option.DisplayName
            if ((Test-LWPropertyExists -Object $option -Name 'GoldCost') -and $null -ne $option.GoldCost -and [int]$option.GoldCost -gt 0) {
                $line = "{0} ({1} Gold Crown{2})" -f $line, [int]$option.GoldCost, $(if ([int]$option.GoldCost -eq 1) { '' } else { 's' })
            }
            elseif ((Test-LWPropertyExists -Object $option -Name 'SpecialItemCount') -and $null -ne $option.SpecialItemCount -and [int]$option.SpecialItemCount -gt 0) {
                $line = "{0} ({1} Special Item{2})" -f $line, [int]$option.SpecialItemCount, $(if ([int]$option.SpecialItemCount -eq 1) { '' } else { 's' })
            }
            Write-LWRetroPanelTextRow -Text ("{0}. {1}" -f ($i + 1), $line) -TextColor 'Gray'
        }
        Write-LWRetroPanelTextRow -Text $DeclineText -TextColor 'DarkGray'
        Write-LWRetroPanelFooter

        $choiceIndex = Read-LWInt -Prompt $PromptLabel -Default 0 -Min 0 -Max @($Options).Count -NoRefresh
        if ($choiceIndex -eq 0) {
            return $null
        }

        $option = @($Options)[$choiceIndex - 1]
        $goldCost = if ((Test-LWPropertyExists -Object $option -Name 'GoldCost') -and $null -ne $option.GoldCost) { [int]$option.GoldCost } else { 0 }
        $specialItemCount = if ((Test-LWPropertyExists -Object $option -Name 'SpecialItemCount') -and $null -ne $option.SpecialItemCount) { [int]$option.SpecialItemCount } else { 0 }

        if ($goldCost -gt 0) {
            if ([int]$script:GameState.Inventory.GoldCrowns -lt $goldCost) {
                Write-LWWarn ("{0}: you need {1} Gold Crown{2} for that option." -f $ContextLabel, $goldCost, $(if ($goldCost -eq 1) { '' } else { 's' }))
                continue
            }

            Update-LWGold -Delta (-$goldCost)
        }
        elseif ($specialItemCount -gt 0) {
            for ($lossIndex = 1; $lossIndex -le $specialItemCount; $lossIndex++) {
                $specialItems = @((Get-LWInventoryItems -Type 'special') | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
                if ($specialItems.Count -le 0) {
                    Write-LWWarn ("{0}: no more Special Items are available for payment." -f $ContextLabel)
                    break
                }

                Show-LWInventorySlotsSection -Type 'special'
                $slot = Read-LWInt -Prompt ("{0} Special Item #{1}" -f $PromptLabel, $lossIndex) -Min 1 -Max $specialItems.Count -NoRefresh
                $lostItem = [string]$specialItems[$slot - 1]
                [void](Remove-LWInventoryItemSilently -Type 'special' -Name $lostItem -Quantity 1)
                Write-LWInfo ("{0}: surrendered {1}." -f $ContextLabel, $lostItem)
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($ResolvedFlagName)) {
            Set-LWStoryAchievementFlag -Name $ResolvedFlagName
        }
        if ((Test-LWPropertyExists -Object $option -Name 'FlagName') -and -not [string]::IsNullOrWhiteSpace([string]$option.FlagName)) {
            Set-LWStoryAchievementFlag -Name ([string]$option.FlagName)
        }

        if ((Test-LWPropertyExists -Object $option -Name 'Message') -and -not [string]::IsNullOrWhiteSpace([string]$option.Message)) {
            Write-LWInfo ([string]$option.Message)
        }

        return $option
    }
}

function Invoke-LWSectionChoiceTable {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$PromptLabel,
        [Parameter(Mandatory = $true)][string]$ContextLabel,
        [Parameter(Mandatory = $true)][object[]]$Choices,
        [string]$Intro = '',
        [int]$SelectionLimit = 0
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    $claimedChoiceCount = @(
        foreach ($choice in @($Choices)) {
            if ($null -eq $choice) { continue }
            $flagName = if (Test-LWPropertyExists -Object $choice -Name 'FlagName') { [string]$choice.FlagName } else { '' }
            if (-not [string]::IsNullOrWhiteSpace($flagName) -and (Test-LWStoryAchievementFlag -Name $flagName)) {
                1
            }
        }
    ).Count

    if ($SelectionLimit -gt 0 -and $claimedChoiceCount -ge $SelectionLimit) {
        return
    }

    $availableChoices = @(Get-LWAvailableSectionChoices -Choices $Choices)
    if ($availableChoices.Count -le 0) {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($Intro)) {
        Write-LWInfo $Intro
    }

    while ($availableChoices.Count -gt 0) {
        Write-LWPanelHeader -Title $Title -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        if ($SelectionLimit -gt 0) {
            $remainingSelections = [Math]::Max(0, ($SelectionLimit - $claimedChoiceCount))
            Write-LWKeyValue -Label 'Choices Left' -Value ("{0}/{1}" -f $remainingSelections, $SelectionLimit) -ValueColor 'Gray'
        }
        Write-Host ''

        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Get-LWBookFourSectionChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceText = [string](Read-LWText -Prompt $PromptLabel -Default '0' -NoRefresh)
        if ([string]::IsNullOrWhiteSpace($choiceText)) {
            $choiceText = '0'
        }
        $choiceText = $choiceText.Trim()

        if ($choiceText -eq '0') {
            break
        }

        if ($choiceText -match '^[dD]$') {
            Remove-LWInventoryInteractive -InputParts @('drop')
            $availableChoices = @(Get-LWAvailableSectionChoices -Choices $Choices)
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
        if (-not (Grant-LWSectionGenericChoice -Choice $choice -ContextLabel $ContextLabel) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
            Invoke-LWBookFourStartingInventoryManagement
        }

        $claimedChoiceCount = @(
            foreach ($claimedChoice in @($Choices)) {
                if ($null -eq $claimedChoice) { continue }
                $flagName = if (Test-LWPropertyExists -Object $claimedChoice -Name 'FlagName') { [string]$claimedChoice.FlagName } else { '' }
                if (-not [string]::IsNullOrWhiteSpace($flagName) -and (Test-LWStoryAchievementFlag -Name $flagName)) {
                    1
                }
            }
        ).Count
        if ($SelectionLimit -gt 0 -and $claimedChoiceCount -ge $SelectionLimit) {
            break
        }

        $availableChoices = @(Get-LWAvailableSectionChoices -Choices $Choices)
    }
}

function Invoke-LWBookFourChoiceTable {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$PromptLabel,
        [Parameter(Mandatory = $true)][string]$ContextLabel,
        [Parameter(Mandatory = $true)][object[]]$Choices,
        [string]$Intro = '',
        [int]$SelectionLimit = 0
    )

    Invoke-LWSectionChoiceTable -Title $Title -PromptLabel $PromptLabel -ContextLabel $ContextLabel -Choices $Choices -Intro $Intro -SelectionLimit $SelectionLimit
}

function Invoke-LWTransitionSafekeepingInventorySelection {
    param([Parameter(Mandatory = $true)][int]$BookNumber)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState)) {
        return
    }

    $selected = @()
    while ($true) {
        $available = @($script:GameState.Inventory.SpecialItems | Where-Object { $selected -notcontains [string]$_ })
        if ($available.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title ("Book {0} Safekeeping" -f $BookNumber) -AccentColor 'DarkYellow'
        Write-LWSubtle ("  Choose carried Special Items to leave in safekeeping before Book {0} begins." -f $BookNumber)
        Write-Host ''
        for ($i = 0; $i -lt $available.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$available[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt 'Safekeep which Special Item' -Default 0 -Min 0 -Max $available.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }

        $selected += [string]$available[$choiceIndex - 1]
    }

    if ($selected.Count -gt 0) {
        Move-LWSpecialItemsToSafekeeping -Items @($selected) -WriteMessages
    }
}

function Invoke-LWTransitionSafekeepingReclaimSelection {
    param([Parameter(Mandatory = $true)][int]$BookNumber)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState)) {
        return
    }

    $selected = @()
    while ($true) {
        $available = @($script:GameState.Storage.SafekeepingSpecialItems | Where-Object { $selected -notcontains [string]$_ })
        if ($available.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title ("Book {0} Safekeeping" -f $BookNumber) -AccentColor 'DarkYellow'
        Write-LWSubtle ("  Reclaim stored Special Items before Book {0} begins." -f $BookNumber)
        Write-Host ''
        for ($i = 0; $i -lt $available.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$available[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt 'Reclaim which Special Item' -Default 0 -Min 0 -Max $available.Count -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }

        $selected += [string]$available[$choiceIndex - 1]
    }

    if ($selected.Count -gt 0) {
        Move-LWSpecialItemsFromSafekeeping -Items @($selected) -WriteMessages
    }
}

function Invoke-LWBookTransitionSafekeepingPrompt {
    param([Parameter(Mandatory = $true)][int]$BookNumber)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState)) {
        return
    }

    $targetBookTitle = [string](Get-LWBookTitle -BookNumber $BookNumber)
    $continueLabel = if ([string]::IsNullOrWhiteSpace($targetBookTitle)) { "Book $BookNumber" } else { "Book $BookNumber - $targetBookTitle" }

    $promptComplete = $false
    while (-not $promptComplete) {
        $carriedItems = @($script:GameState.Inventory.SpecialItems)
        $storedItems = @($script:GameState.Storage.SafekeepingSpecialItems)

        if ($carriedItems.Count -eq 0 -and $storedItems.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title ("Book {0} Safekeeping" -f $BookNumber) -AccentColor 'DarkYellow'
        Write-LWSubtle ("  Manage Special Items in safekeeping before {0} begins." -f $continueLabel)
        Write-LWSubtle '  You can leave carried Special Items here and reclaim stored ones during book-to-book transitions.'
        Write-Host ''
        Write-LWKeyValue -Label 'Carried Special Items' -Value $(if ($carriedItems.Count -gt 0) { Format-LWCompactInventorySummary -Items $carriedItems -MaxGroups 4 } else { '(none)' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Safekeeping' -Value $(if ($storedItems.Count -gt 0) { Format-LWCompactInventorySummary -Items $storedItems -MaxGroups 4 } else { '(none)' }) -ValueColor 'DarkGray'
        Write-Host ''
        if ($carriedItems.Count -gt 0) {
            Write-LWBulletItem -Text 'Y. Choose carried Special Items to leave in safekeeping' -TextColor 'Gray' -BulletColor 'Yellow'
        }
        if ($storedItems.Count -gt 0) {
            Write-LWBulletItem -Text 'R. Reclaim Special Items from safekeeping' -TextColor 'Gray' -BulletColor 'Yellow'
        }
        Write-LWBulletItem -Text 'I. Review inventory first' -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text ("N. Continue into {0}" -f $continueLabel) -TextColor 'Gray' -BulletColor 'Yellow'

        $safekeepingChoice = [string](Read-LWText -Prompt 'Safekeeping choice' -Default 'N' -NoRefresh)
        switch ($safekeepingChoice.Trim().ToLowerInvariant()) {
            'y' {
                if ($carriedItems.Count -gt 0) {
                    Invoke-LWTransitionSafekeepingInventorySelection -BookNumber $BookNumber
                }
                else {
                    Write-LWWarn 'There are no carried Special Items to place in safekeeping right now.'
                }
                break
            }
            'yes' {
                if ($carriedItems.Count -gt 0) {
                    Invoke-LWTransitionSafekeepingInventorySelection -BookNumber $BookNumber
                }
                else {
                    Write-LWWarn 'There are no carried Special Items to place in safekeeping right now.'
                }
                break
            }
            'r' {
                if ($storedItems.Count -gt 0) {
                    Invoke-LWTransitionSafekeepingReclaimSelection -BookNumber $BookNumber
                }
                else {
                    Write-LWWarn 'There are no safekept Special Items to reclaim right now.'
                }
                break
            }
            'reclaim' {
                if ($storedItems.Count -gt 0) {
                    Invoke-LWTransitionSafekeepingReclaimSelection -BookNumber $BookNumber
                }
                else {
                    Write-LWWarn 'There are no safekept Special Items to reclaim right now.'
                }
                break
            }
            'i' {
                Show-LWInventory
                [void](Read-LWText -Prompt 'Press Enter to return to the safekeeping prompt' -NoRefresh)
                break
            }
            'inv' {
                Show-LWInventory
                [void](Read-LWText -Prompt 'Press Enter to return to the safekeeping prompt' -NoRefresh)
                break
            }
            'inventory' {
                Show-LWInventory
                [void](Read-LWText -Prompt 'Press Enter to return to the safekeeping prompt' -NoRefresh)
                break
            }
            'n' {
                $promptComplete = $true
                break
            }
            'no' {
                $promptComplete = $true
                break
            }
            '0' {
                $promptComplete = $true
                break
            }
            'done' {
                $promptComplete = $true
                break
            }
            'continue' {
                $promptComplete = $true
                break
            }
            default {
                Write-LWWarn 'Choose Y to safekeep items, R to reclaim items, I to review inventory, or N/0 to continue.'
            }
        }
    }
}

Export-ModuleMember -Function `
    Invoke-LWCoreMaintainRuntime, `
    Invoke-LWCoreRequestRender, `
    Invoke-LWCoreAddNotification, `
    Invoke-LWCoreWriteInfo, `
    Invoke-LWCoreWriteWarn, `
    Invoke-LWCoreWriteError, `
    Invoke-LWCoreWriteMessageLine, `
    Invoke-LWCoreWriteCrashLog, `
    Invoke-LWCoreClearNotifications, `
    Invoke-LWCoreClearAchievementDisplayCountsCache, `
    Invoke-LWCoreWarmRuntimeCaches, `
    Invoke-LWCoreClearScreenHost, `
    Invoke-LWCoreGetDefaultScreen, `
    Invoke-LWCoreSetScreen, `
    Invoke-LWCoreWriteNotifications, `
    Invoke-LWCoreWriteBannerFooter, `
    Invoke-LWCoreWriteBanner, `
    Invoke-LWCoreWriteCommandPromptHint, `
    Get-LWBookDisplayLine, `
    Get-LWBookFourSectionChoiceLine, `
    Grant-LWBookFourGenericChoice, `
    Format-LWBookFourStartingChoiceLine, `
    Invoke-LWBookFourChoiceTable, `
    Invoke-LWBookFourStartingInventoryManagement, `
    Invoke-LWTransitionSafekeepingInventorySelection, `
    Invoke-LWTransitionSafekeepingReclaimSelection, `
    Invoke-LWBookTransitionSafekeepingPrompt, `
    Invoke-LWCoreWriteScreenFooterNote, `
    Invoke-LWCoreShowHelpScreen, `
    Invoke-LWCoreShowStatsScreen, `
    Invoke-LWCoreShowCampaignScreen, `
    Invoke-LWCoreShowAchievementsScreen, `
    Invoke-LWCoreShowInventoryScreen, `
    Invoke-LWCoreShowSheetScreen, `
    Invoke-LWCoreShowWelcomeScreen, `
    Invoke-LWCoreShowLoadScreen, `
    Invoke-LWCoreShowDisciplineSelectionScreen, `
    Invoke-LWCoreShowCombatScreen, `
    Invoke-LWCoreShowCombatLogScreen, `
    Invoke-LWCoreShowModesScreen, `
    Invoke-LWCoreShowDeathScreen, `
    Invoke-LWCoreShowBookCompleteScreen, `
    Invoke-LWCoreRefreshScreen

function Write-LWInfo {
    param([string]$Message)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    Invoke-LWCoreWriteInfo -Context (Get-LWModuleContext) -Message $Message
}

function Write-LWWarn {
    param([string]$Message)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    Invoke-LWCoreWriteWarn -Context (Get-LWModuleContext) -Message $Message
}

function Write-LWError {
    param([string]$Message)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    Invoke-LWCoreWriteError -Context (Get-LWModuleContext) -Message $Message
}

function Write-LWMessageLine {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreWriteMessageLine -Level $Level -Message $Message
}

function Add-LWNotification {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreAddNotification -Context (Get-LWModuleContext) -Level $Level -Message $Message
}

function Write-LWCrashLog {
    param(
        [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$InputLine = '',
        [string]$Stage = 'command'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return (Invoke-LWCoreWriteCrashLog -Context (Get-LWModuleContext) -ErrorRecord $ErrorRecord -InputLine $InputLine -Stage $Stage)
}

function Clear-LWNotifications {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreClearNotifications -Context (Get-LWModuleContext)
}

function Clear-LWAchievementDisplayCountsCache {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreClearAchievementDisplayCountsCache -Context (Get-LWModuleContext)
}

function Warm-LWRuntimeCaches {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreWarmRuntimeCaches -Context (Get-LWModuleContext)
}

function Request-LWRender {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreRequestRender -Context (Get-LWModuleContext)
}

function Clear-LWScreenHost {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreClearScreenHost
}

function Get-LWDefaultScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return (Invoke-LWCoreGetDefaultScreen -Context (Get-LWModuleContext))
}

function Set-LWScreen {
    param(
        [string]$Name = '',
        $Data = $null
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreSetScreen -Context (Get-LWModuleContext) -Name $Name -Data $Data
}

function Write-LWNotifications {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreWriteNotifications -Context (Get-LWModuleContext)
}

function Write-LWBannerFooter {
    param(
        [string]$ProductName = $script:LWAppName,
        [switch]$VersionOnly,
        [switch]$ShowHelpLine
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreWriteBannerFooter -Context (Get-LWModuleContext) -ProductName $ProductName -VersionOnly:$VersionOnly -ShowHelpLine:$ShowHelpLine
}

function Write-LWInventoryBanner {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWBanner
}

function Write-LWCombatBanner {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWBanner
}

function Write-LWStatsBanner {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWBanner
}

function Write-LWCampaignBanner {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWBanner
}

function Write-LWAchievementsBanner {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWBanner
}

function Write-LWDeathBanner {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Write-LWBanner
}

function Show-LWWelcomeScreen {
    param([switch]$NoBanner)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreShowWelcomeScreen -Context (Get-LWModuleContext) -NoBanner:$NoBanner
}

function Show-LWLoadScreen {
    param([object[]]$SaveFiles = @())
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Invoke-LWCoreShowLoadScreen -Context (Get-LWModuleContext) -SaveFiles $SaveFiles
}

function Show-LWDisciplineSelectionScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowDisciplineSelectionScreen -Context (Get-LWModuleContext)
}

function Show-LWCombatScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowCombatScreen -Context (Get-LWModuleContext)
}

function Show-LWCombatLogScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowCombatLogScreen -Context (Get-LWModuleContext)
}

function Show-LWModesScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowModesScreen -Context (Get-LWModuleContext)
}

function Show-LWDeathScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowDeathScreen -Context (Get-LWModuleContext)
}

function Show-LWBookCompleteScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowBookCompleteScreen -Context (Get-LWModuleContext)
}

function Refresh-LWScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreRefreshScreen -Context (Get-LWModuleContext)
}

function Get-LWCombatEntryBookNumber {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ((Test-LWPropertyExists -Object $Entry -Name 'BookNumber') -and $null -ne $Entry.BookNumber) {
        return [int]$Entry.BookNumber
    }

    return 0
}

function Get-LWCombatEntryBookTitle {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ((Test-LWPropertyExists -Object $Entry -Name 'BookTitle') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.BookTitle)) {
        return [string]$Entry.BookTitle
    }

    $bookNumber = Get-LWCombatEntryBookNumber -Entry $Entry
    if ($bookNumber -gt 0) {
        return [string](Get-LWBookTitle -BookNumber $bookNumber)
    }

    return ''
}

function Get-LWCombatEntryBookLabel {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $bookNumber = Get-LWCombatEntryBookNumber -Entry $Entry
    $bookTitle = Get-LWCombatEntryBookTitle -Entry $Entry

    if ($bookNumber -gt 0) {
        return (Format-LWBookLabel -BookNumber $bookNumber -IncludePrefix)
    }
    if (-not [string]::IsNullOrWhiteSpace($bookTitle)) {
        return $bookTitle
    }

    return 'Book Unknown'
}

function Get-LWCombatEntryBookKey {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ('{0}|{1}' -f (Get-LWCombatEntryBookNumber -Entry $Entry), (Get-LWCombatEntryBookTitle -Entry $Entry))
}

function Write-LWCombatArchiveBookHeader {
    param([Parameter(Mandatory = $true)][object]$Entry)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-Host ''
    Write-Host ("  {0}" -f (Get-LWCombatEntryBookLabel -Entry $Entry)) -ForegroundColor DarkYellow
    Write-LWSubtle '  ------------------------------------------------------------'
}

function Get-LWCombatArchiveOutcomeLabel {
    param([string]$Outcome = '')
    Set-LWModuleContext -Context (Get-LWModuleContext)


    switch ([string]$Outcome) {
        'Victory' { return 'Win' }
        'Defeat' { return 'Loss' }
        'Knockout' { return 'KO' }
        'Special' { return 'Spec' }
        'Evaded' { return 'Evade' }
        'In Progress' { return 'Live' }
        'Stopped' { return 'Stop' }
        default { return ([string]$Outcome) }
    }
}

function Format-LWCombatArchiveCellText {
    param(
        [string]$Text,
        [int]$Width
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $value = if ($null -eq $Text) { '' } else { [string]$Text }
    if ($Width -le 0) {
        return ''
    }

    if ($value.Length -gt $Width) {
        if ($Width -le 3) {
            return $value.Substring(0, $Width)
        }

        return ($value.Substring(0, ($Width - 3)) + '...')
    }

    return $value.PadRight($Width)
}

function Get-LWCombatArchiveEntryText {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [Parameter(Mandatory = $true)][string]$Prefix
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $sectionText = if ((Test-LWPropertyExists -Object $Entry -Name 'Section') -and $null -ne $Entry.Section) { [string]$Entry.Section } else { '?' }
    $enemyName = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.EnemyName)) { [string]$Entry.EnemyName } else { 'Unknown' }
    $outcomeLabel = Get-LWCombatArchiveOutcomeLabel -Outcome $(if (Test-LWPropertyExists -Object $Entry -Name 'Outcome') { [string]$Entry.Outcome } else { '' })
    $roundText = if ((Test-LWPropertyExists -Object $Entry -Name 'RoundCount') -and $null -ne $Entry.RoundCount) { ("R{0}" -f [int]$Entry.RoundCount) } else { 'R?' }
    $ratioText = if ((Test-LWPropertyExists -Object $Entry -Name 'CombatRatio') -and $null -ne $Entry.CombatRatio) { (Format-LWSigned -Value ([int]$Entry.CombatRatio)) } else { '?' }
    $weaponText = if ((Test-LWPropertyExists -Object $Entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Weapon)) { (Get-LWCombatDisplayWeapon -Weapon ([string]$Entry.Weapon)) } else { 'Unknown' }
    $entryFieldText = ("{0} {1}" -f $Prefix, $sectionText).Trim()
    $fields = @(
        (Format-LWCombatArchiveCellText -Text $entryFieldText -Width 8),
        (Format-LWCombatArchiveCellText -Text $enemyName -Width 15),
        (Format-LWCombatArchiveCellText -Text $outcomeLabel -Width 5),
        (Format-LWCombatArchiveCellText -Text $roundText -Width 3),
        (Format-LWCombatArchiveCellText -Text $ratioText -Width 3),
        (Format-LWCombatArchiveCellText -Text $weaponText -Width 11)
    )

    return ([string]::Join(' | ', $fields))
}

function Get-LWCombatArchiveHeaderText {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $fields = @(
        (Format-LWCombatArchiveCellText -Text '#/Sect' -Width 8),
        (Format-LWCombatArchiveCellText -Text 'Enemy' -Width 15),
        (Format-LWCombatArchiveCellText -Text 'Out' -Width 5),
        (Format-LWCombatArchiveCellText -Text 'Rnd' -Width 3),
        (Format-LWCombatArchiveCellText -Text 'CR' -Width 3),
        (Format-LWCombatArchiveCellText -Text 'Weapon' -Width 11)
    )

    return ([string]::Join(' | ', $fields))
}

function Show-LWCombatArchiveEntriesPanel {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [string]$Title = 'Combat Archive'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title $Title -AccentColor 'DarkRed'
    Write-LWRetroPanelTextRow -Text (Get-LWCombatArchiveHeaderText) -TextColor 'DarkGray'
    foreach ($item in @($Items)) {
        if ($null -eq $item) {
            continue
        }

        $entry = if (Test-LWPropertyExists -Object $item -Name 'Entry') { $item.Entry } else { $item }
        $prefix = if (Test-LWPropertyExists -Object $item -Name 'Prefix') { [string]$item.Prefix } else { '#' }
        $textColor = if (Test-LWPropertyExists -Object $item -Name 'Color') { [string]$item.Color } else { 'Gray' }
        Write-LWRetroPanelTextRow -Text (Get-LWCombatArchiveEntryText -Entry $entry -Prefix $prefix) -TextColor $textColor
    }
    Write-LWRetroPanelFooter
}

function Show-LWHistory {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $campaignSummary = Get-LWCampaignSummary
    $recentAchievements = @(Get-LWAchievementRecentUnlocks -Count 4)
    $runHistoryLines = @(Get-LWCompactRunHistoryLines)
    $lastEnemy = if (@($script:GameState.History).Count -gt 0) { [string]$script:GameState.History[-1].EnemyName } else { '(none)' }

    Write-LWRetroPanelHeader -Title 'Run History' -AccentColor 'DarkYellow'
    if ($runHistoryLines.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $runHistoryLines.Count; $i += 2) {
            $left = $runHistoryLines[$i]
            $right = if (($i + 1) -lt $runHistoryLines.Count) { $runHistoryLines[$i + 1] } else { $null }
            Write-LWRetroPanelTwoColumnRow `
                -LeftText ([string]$left.Text) `
                -RightText $(if ($null -ne $right) { [string]$right.Text } else { '' }) `
                -LeftColor ([string]$left.Color) `
                -RightColor $(if ($null -ne $right) { [string]$right.Color } else { 'Gray' }) `
                -LeftWidth 28 `
                -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Recent Events' -AccentColor 'Cyan'
    if ($recentAchievements.Count -gt 0) {
        foreach ($entry in $recentAchievements) {
            Write-LWRetroPanelTextRow -Text ("{0} : {1}" -f (Format-LWBookLabel -BookNumber ([int]$entry.BookNumber)), (Get-LWAchievementUnlockedDisplayName -Entry $entry)) -TextColor 'Gray'
        }
    }
    elseif (@($script:GameState.Character.Notes).Count -gt 0) {
        foreach ($note in @($script:GameState.Character.Notes | Select-Object -Last 4)) {
            Write-LWRetroPanelTextRow -Text ([string]$note) -TextColor 'Gray'
        }
    }
    else {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Combat History' -AccentColor 'Red'
    if ($null -ne $campaignSummary) {
        Write-LWRetroPanelPairRow -LeftLabel 'Fights Won' -LeftValue ([string]$campaignSummary.TotalVictories) -RightLabel 'Fights Lost' -RightValue ([string]$campaignSummary.TotalDefeats) -LeftColor 'Green' -RightColor 'Red'
        Write-LWRetroPanelPairRow -LeftLabel 'Total Rounds' -LeftValue ([string]$campaignSummary.TotalRoundsFought) -RightLabel 'Last Enemy' -RightValue $lastEnemy -LeftColor 'Gray' -RightColor 'Gray'
    }
    else {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter

    Show-LWHelpfulCommandsPanel -ScreenName 'history'
}

function Get-LWLiveBookStatsSummary {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return $null
    }

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return $null
    }

    return (New-LWBookHistoryEntry -Stats $stats)
}

function Show-LWStatsOverview {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $campaignSummary = Get-LWCampaignSummary

    Write-LWRetroPanelHeader -Title 'Run Stats' -AccentColor 'Cyan'
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Wins' -LeftValue ([string]$campaignSummary.TotalVictories) -RightLabel 'Combat Losses' -RightValue ([string]$campaignSummary.TotalDefeats) -LeftColor 'Green' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Total Rounds' -LeftValue ([string]$campaignSummary.TotalRoundsFought) -RightLabel 'Damage Taken' -RightValue ([string]$campaignSummary.TotalEnduranceLost) -LeftColor 'Gray' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Gold Gained' -LeftValue ([string]$campaignSummary.TotalGoldGained) -RightLabel 'Sections Seen' -RightValue ([string]$campaignSummary.TotalSectionsVisited) -LeftColor 'Yellow' -RightColor 'Gray'
    Write-LWRetroPanelPairRow -LeftLabel 'Notes Added' -LeftValue ([string]@($script:GameState.Character.Notes).Count) -RightLabel 'Rewinds Used' -RightValue ([string]$campaignSummary.TotalRewindsUsed) -LeftColor 'Gray' -RightColor 'Yellow'
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Current Book Stats' -AccentColor 'Cyan'
    Write-LWRetroPanelKeyValueRow -Label 'Book' -Value (Format-LWBookLabel -BookNumber ([int]$Summary.BookNumber)) -ValueColor 'White'
    Write-LWRetroPanelPairRow -LeftLabel 'Fights Won' -LeftValue ([string]$Summary.Victories) -RightLabel 'Fights Lost' -RightValue ([string]$Summary.Defeats) -LeftColor 'Green' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Rounds Fought' -LeftValue ([string]$Summary.RoundsFought) -RightLabel 'Damage Taken' -RightValue ([string]$Summary.EnduranceLost) -LeftColor 'Gray' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Sections Seen' -LeftValue ([string]$Summary.SectionsVisited) -RightLabel 'Notes Added' -RightValue ([string]@($script:GameState.Character.Notes).Count) -LeftColor 'Gray' -RightColor 'Gray'
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Mode Summary' -AccentColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Difficulty' -LeftValue (Get-LWCurrentDifficulty) -RightLabel 'Permadeath' -RightValue $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }) -LeftColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty)) -RightColor $(if (Test-LWPermadeathEnabled) { 'Red' } else { 'Gray' })
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Mode' -LeftValue ([string]$script:GameState.Settings.CombatMode) -RightLabel 'Run Integrity' -RightValue ([string]$script:GameState.Run.IntegrityState) -LeftColor (Get-LWModeColor -Mode ([string]$script:GameState.Settings.CombatMode)) -RightColor (Get-LWIntegrityColor -IntegrityState ([string]$script:GameState.Run.IntegrityState))
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Milestones' -AccentColor 'DarkYellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Books Complete' -LeftValue $(if (@($script:GameState.Character.CompletedBooks).Count -gt 0) { [string](@($script:GameState.Character.CompletedBooks | Sort-Object) -join '-') } else { '(none)' }) -RightLabel 'Achievements' -RightValue ("{0} / {1}" -f (Get-LWAchievementEligibleUnlockedCount), (Get-LWAchievementAvailableCount)) -LeftColor 'Gray' -RightColor 'Magenta'
    Write-LWRetroPanelFooter
}

function Show-LWStatsCombat {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $highestCSFaced = if ([int]$Summary.HighestEnemyCombatSkillFaced -gt 0) { [string]$Summary.HighestEnemyCombatSkillFaced } else { '(none)' }
    $highestEndFaced = if ([int]$Summary.HighestEnemyEnduranceFaced -gt 0) { [string]$Summary.HighestEnemyEnduranceFaced } else { '(none)' }
    $highestCSDefeated = if ([int]$Summary.HighestEnemyCombatSkillDefeated -gt 0) { [string]$Summary.HighestEnemyCombatSkillDefeated } else { '(none)' }
    $highestEndDefeated = if ([int]$Summary.HighestEnemyEnduranceDefeated -gt 0) { [string]$Summary.HighestEnemyEnduranceDefeated } else { '(none)' }
    $weaponUsage = Format-LWNamedCountSummary -Entries @($Summary.WeaponUsage)
    $weaponVictories = Format-LWNamedCountSummary -Entries @($Summary.WeaponVictories)
    $fastestVictory = if ([int]$Summary.FastestVictoryRounds -gt 0) { "{0} ({1} round{2})" -f $Summary.FastestVictoryEnemyName, $Summary.FastestVictoryRounds, $(if ([int]$Summary.FastestVictoryRounds -eq 1) { '' } else { 's' }) } else { '(none)' }
    $easiestVictory = if ($null -ne $Summary.EasiestVictoryRatio) { "{0} (ratio {1})" -f $Summary.EasiestVictoryEnemyName, [int]$Summary.EasiestVictoryRatio } else { '(none)' }
    $longestFight = if ([int]$Summary.LongestFightRounds -gt 0) { "{0} ({1} round{2})" -f $Summary.LongestFightEnemyName, $Summary.LongestFightRounds, $(if ([int]$Summary.LongestFightRounds -eq 1) { '' } else { 's' }) } else { '(none)' }

    Write-LWRetroPanelHeader -Title 'Combat Stats' -AccentColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Fights' -LeftValue ([string]$Summary.CombatCount) -RightLabel 'Victories' -RightValue ([string]$Summary.Victories) -LeftColor 'Gray' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Defeats' -LeftValue ([string]$Summary.Defeats) -RightLabel 'Evades' -RightValue ([string]$Summary.Evades) -LeftColor 'Red' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Rounds Fought' -LeftValue ([string]$Summary.RoundsFought) -RightLabel 'Mindblast Wins' -RightValue ([string]$Summary.MindblastVictories) -LeftColor 'Gray' -RightColor 'Cyan'
    Write-LWRetroPanelPairRow -LeftLabel 'Highest CS Faced' -LeftValue $highestCSFaced -RightLabel 'Highest END Faced' -RightValue $highestEndFaced -LeftColor 'Cyan' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Highest CS Defeated' -LeftValue $highestCSDefeated -RightLabel 'Highest END Defeated' -RightValue $highestEndDefeated -LeftColor 'Cyan' -RightColor 'Red'
    Write-LWRetroPanelDivider
    Write-LWRetroPanelKeyValueRow -Label 'Fastest Victory' -Value $fastestVictory -ValueColor 'Green'
    Write-LWRetroPanelKeyValueRow -Label 'Easiest Victory' -Value $easiestVictory -ValueColor 'Green'
    Write-LWRetroPanelKeyValueRow -Label 'Longest Fight' -Value $longestFight -ValueColor 'Yellow'
    Write-LWRetroPanelKeyValueRow -Label 'Weapons Used' -Value $weaponUsage -ValueColor 'Gray'
    Write-LWRetroPanelKeyValueRow -Label 'Weapon Wins' -Value $weaponVictories -ValueColor 'Gray'
    Write-LWRetroPanelFooter
}

function Show-LWStatsSurvival {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $deathCount = if ((Test-LWPropertyExists -Object $Summary -Name 'DeathCount') -and $null -ne $Summary.DeathCount) { [string]$Summary.DeathCount } else { '0' }

    Write-LWRetroPanelHeader -Title 'Survival Stats' -AccentColor 'DarkYellow'
    Write-LWRetroPanelPairRow -LeftLabel 'END Lost' -LeftValue ([string]$Summary.EnduranceLost) -RightLabel 'END Gained' -RightValue ([string]$Summary.EnduranceGained) -LeftColor 'Red' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Healing Uses' -LeftValue ([string]$Summary.HealingTriggers) -RightLabel 'Healing END' -RightValue ([string]$Summary.HealingEnduranceRestored) -LeftColor 'Green' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Gold Gained' -LeftValue ([string]$Summary.GoldGained) -RightLabel 'Gold Spent' -RightValue ([string]$Summary.GoldSpent) -LeftColor 'Yellow' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Meals Eaten' -LeftValue ([string]$Summary.MealsEaten) -RightLabel 'Hunting Meals' -RightValue ([string]$Summary.MealsCoveredByHunting) -LeftColor 'Yellow' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Potions Used' -LeftValue ([string]$Summary.PotionsUsed) -RightLabel 'Potion END' -RightValue ([string]$Summary.PotionEnduranceRestored) -LeftColor 'Green' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Deaths' -LeftValue $deathCount -RightLabel 'Starvation' -RightValue ([string]$Summary.StarvationPenalties) -LeftColor 'Red' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Rewinds' -LeftValue ([string]$Summary.RewindsUsed) -RightLabel 'Recovery' -RightValue ([string]$Summary.ManualRecoveryShortcuts) -LeftColor 'Yellow' -RightColor 'Yellow'
    Write-LWRetroPanelFooter
}

function Show-LWStatsScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowStatsScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
}

function Merge-LWNamedCountEntries {
    param([object[]]$Entries)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $totals = @{}
    foreach ($entry in @(Normalize-LWNamedCountEntries -Entries $Entries)) {
        $name = [string]$entry.Name
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if (-not $totals.ContainsKey($name)) {
            $totals[$name] = 0
        }

        $totals[$name] = [int]$totals[$name] + [int]$entry.Count
    }

    $merged = @()
    foreach ($name in @($totals.Keys | Sort-Object)) {
        $merged += [pscustomobject]@{
            Name  = [string]$name
            Count = [int]$totals[$name]
        }
    }

    return @(Normalize-LWNamedCountEntries -Entries $merged)
}

function Get-LWCampaignBookEntries {
    param([object]$CurrentSummary = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return @()
    }

    $entries = @()
    foreach ($summary in @($script:GameState.BookHistory)) {
        $entries += [pscustomobject]@{
            Status  = 'Completed'
            Summary = $summary
        }
    }

    if ($null -eq $CurrentSummary) {
        $CurrentSummary = Get-LWLiveBookStatsSummary
    }
    $currentSummary = $CurrentSummary
    if ($null -ne $currentSummary) {
        $entries += [pscustomobject]@{
            Status  = 'Current'
            Summary = $currentSummary
        }
    }

    return @($entries)
}

function Get-LWCampaignTopNamedCountEntry {
    param([object[]]$Entries)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $values = @(Merge-LWNamedCountEntries -Entries $Entries | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    if ($values.Count -eq 0) {
        return $null
    }

    return $values[0]
}

function Get-LWCampaignRunStatus {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return 'No active run'
    }

    if (Test-LWDeathActive) {
        return 'Fallen'
    }
    if ($script:GameState.Combat.Active) {
        return 'In Combat'
    }

    return 'Adventure Ongoing'
}

function Get-LWCampaignRunStyle {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([int]$Summary.TotalDeaths -eq 0 -and [int]$Summary.TotalRewindsUsed -eq 0 -and [int]$Summary.TotalVictories -ge 10) {
        return 'Iron-Willed'
    }
    if ([int]$Summary.TotalDeaths -ge 3) {
        return 'Death-Touched'
    }
    if ([int]$Summary.TotalCombatCount -ge 10) {
        return 'Battle-Hardened'
    }
    if ([int]$Summary.TotalEnduranceGained -ge [int]$Summary.TotalEnduranceLost -and [int]$Summary.TotalDeaths -eq 0) {
        return 'Steady Survivor'
    }
    if ([int]$Summary.TotalSectionsVisited -le 5) {
        return 'Trail Beginner'
    }

    return 'Kai in Progress'
}

function Get-LWBookSummaryCacheSignature {
    param([object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if ($null -eq $Summary) {
        return 'none'
    }

    $weaponUsageSignature = (@(
        foreach ($entry in @($Summary.WeaponUsage)) {
            '{0}:{1}' -f [string]$entry.Name, [int]$entry.Count
        }
    ) -join ',')
    $weaponVictorySignature = (@(
        foreach ($entry in @($Summary.WeaponVictories)) {
            '{0}:{1}' -f [string]$entry.Name, [int]$entry.Count
        }
    ) -join ',')

    $signatureFormat = '{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|{11}|{12}|{13}|{14}|{15}|{16}|{17}|{18}|{19}|{20}|{21}|{22}|{23}|{24}|{25}|{26}|{27}|{28}|{29}|{30}|{31}|{32}|{33}|{34}|{35}|{36}|{37}|{38}|{39}|{40}'
    return ($signatureFormat -f
        [int]$Summary.BookNumber,
        [int]$Summary.SuccessfulPathSections,
        [int]$Summary.SectionsVisited,
        [int]$Summary.UniqueSectionsVisited,
        [int]$Summary.EnduranceLost,
        [int]$Summary.EnduranceGained,
        [int]$Summary.MealsEaten,
        [int]$Summary.MealsCoveredByHunting,
        [int]$Summary.StarvationPenalties,
        [int]$Summary.PotionsUsed,
        [int]$Summary.ConcentratedPotionsUsed,
        [int]$Summary.PotionEnduranceRestored,
        [int]$Summary.RewindsUsed,
        [int]$Summary.ManualRecoveryShortcuts,
        [int]$Summary.GoldGained,
        [int]$Summary.GoldSpent,
        [int]$Summary.HealingTriggers,
        [int]$Summary.HealingEnduranceRestored,
        [int]$Summary.CombatCount,
        [int]$Summary.Victories,
        [int]$Summary.Defeats,
        [int]$Summary.Evades,
        [int]$Summary.RoundsFought,
        [int]$Summary.MindblastCombats,
        [int]$Summary.MindblastVictories,
        [int]$Summary.InstantDeaths,
        [int]$Summary.CombatDeaths,
        [int]$Summary.DeathCount,
        [int]$Summary.HighestEnemyCombatSkillFaced,
        [int]$Summary.HighestEnemyEnduranceFaced,
        [int]$Summary.HighestEnemyCombatSkillDefeated,
        [int]$Summary.HighestEnemyEnduranceDefeated,
        [string]$Summary.FastestVictoryEnemyName,
        [int]$Summary.FastestVictoryRounds,
        [string]$Summary.EasiestVictoryEnemyName,
        [string]$Summary.EasiestVictoryRatio,
        [string]$Summary.LongestFightEnemyName,
        [int]$Summary.LongestFightRounds,
        [int][bool]$Summary.PartialTracking,
        $weaponUsageSignature,
        $weaponVictorySignature)
}

function Get-LWCampaignSummaryCacheKey {
    param([object]$CurrentSummary = $null)
    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState)) {
        return 'no-state'
    }

    if ($null -eq $CurrentSummary) {
        $CurrentSummary = Get-LWLiveBookStatsSummary
    }

    $runId = if ($null -ne $script:GameState.Run -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.Id)) { [string]$script:GameState.Run.Id } else { 'no-run' }
    $integrity = if ($null -ne $script:GameState.Run -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityState)) { [string]$script:GameState.Run.IntegrityState } else { 'unknown' }
    $combatMode = if ($null -ne $script:GameState.Settings -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Settings.CombatMode)) { [string]$script:GameState.Settings.CombatMode } else { 'unknown' }

    $cacheFormat = '{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}'
    return ($cacheFormat -f
        $runId,
        @($script:GameState.BookHistory).Count,
        @($script:GameState.History).Count,
        @($script:GameState.Achievements.Unlocked).Count,
        @($script:GameState.Character.CompletedBooks).Count,
        [int]$script:GameState.CurrentSection,
        [int]$script:GameState.Character.BookNumber,
        $integrity,
        $combatMode,
        [int][bool]$script:GameState.Combat.Active,
        (Get-LWBookSummaryCacheSignature -Summary $CurrentSummary))
}

function Get-LWCampaignSummary {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not (Test-LWHasState)) {
        return $null
    }

    $currentSummary = Get-LWLiveBookStatsSummary
    $cacheKey = Get-LWCampaignSummaryCacheKey -CurrentSummary $currentSummary
    if ($null -ne $script:LWShellCampaignSummaryCache -and
        (Test-LWPropertyExists -Object $script:LWShellCampaignSummaryCache -Name 'Key') -and
        [string]$script:LWShellCampaignSummaryCache.Key -eq $cacheKey) {
        return $script:LWShellCampaignSummaryCache.Summary
    }

    $bookEntries = @(Get-LWCampaignBookEntries -CurrentSummary $currentSummary)
    if ($bookEntries.Count -eq 0) {
        return $null
    }

    $totalSuccessfulPathSections = 0
    $totalSectionsVisited = 0
    $totalUniqueSectionsVisited = 0
    $totalEnduranceLost = 0
    $totalEnduranceGained = 0
    $totalMealsEaten = 0
    $totalHuntingMeals = 0
    $totalStarvationPenalties = 0
    $totalPotionsUsed = 0
    $totalStrongPotions = 0
    $totalPotionEnduranceRestored = 0
    $totalRewindsUsed = 0
    $totalManualRecoveryShortcuts = 0
    $totalGoldGained = 0
    $totalGoldSpent = 0
    $totalHealingTriggers = 0
    $totalHealingEnduranceRestored = 0
    $totalCombatCount = 0
    $totalVictories = 0
    $totalDefeats = 0
    $totalEvades = 0
    $totalRoundsFought = 0
    $totalMindblastCombats = 0
    $totalMindblastVictories = 0
    $totalInstantDeaths = 0
    $totalCombatDeaths = 0
    $totalDeaths = 0
    $highestEnemyCombatSkillFaced = 0
    $highestEnemyEnduranceFaced = 0
    $highestEnemyCombatSkillDefeated = 0
    $highestEnemyEnduranceDefeated = 0
    $fastestVictoryEnemyName = $null
    $fastestVictoryRounds = 0
    $fastestVictoryBookLabel = $null
    $easiestVictoryEnemyName = $null
    $easiestVictoryRatio = $null
    $easiestVictoryBookLabel = $null
    $longestFightEnemyName = $null
    $longestFightRounds = 0
    $longestFightBookLabel = $null
    $partialTracking = $false
    $weaponUsageEntries = @()
    $weaponVictoryEntries = @()

    foreach ($entry in $bookEntries) {
        $summary = $entry.Summary
        if ($null -eq $summary) {
            continue
        }

        $bookLabel = Format-LWBookLabel -BookNumber ([int]$summary.BookNumber) -IncludePrefix

        $totalSuccessfulPathSections += [int]$summary.SuccessfulPathSections
        $totalSectionsVisited += [int]$summary.SectionsVisited
        $totalUniqueSectionsVisited += [int]$summary.UniqueSectionsVisited
        $totalEnduranceLost += [int]$summary.EnduranceLost
        $totalEnduranceGained += [int]$summary.EnduranceGained
        $totalMealsEaten += [int]$summary.MealsEaten
        $totalHuntingMeals += [int]$summary.MealsCoveredByHunting
        $totalStarvationPenalties += [int]$summary.StarvationPenalties
        $totalPotionsUsed += [int]$summary.PotionsUsed
        $totalStrongPotions += [int]$summary.ConcentratedPotionsUsed
        $totalPotionEnduranceRestored += [int]$summary.PotionEnduranceRestored
        $totalRewindsUsed += [int]$summary.RewindsUsed
        $totalManualRecoveryShortcuts += [int]$summary.ManualRecoveryShortcuts
        $totalGoldGained += [int]$summary.GoldGained
        $totalGoldSpent += [int]$summary.GoldSpent
        $totalHealingTriggers += [int]$summary.HealingTriggers
        $totalHealingEnduranceRestored += [int]$summary.HealingEnduranceRestored
        $totalCombatCount += [int]$summary.CombatCount
        $totalVictories += [int]$summary.Victories
        $totalDefeats += [int]$summary.Defeats
        $totalEvades += [int]$summary.Evades
        $totalRoundsFought += [int]$summary.RoundsFought
        $totalMindblastCombats += [int]$summary.MindblastCombats
        $totalMindblastVictories += [int]$summary.MindblastVictories
        $totalInstantDeaths += [int]$summary.InstantDeaths
        $totalCombatDeaths += [int]$summary.CombatDeaths
        $totalDeaths += [int]$summary.DeathCount

        if ([int]$summary.HighestEnemyCombatSkillFaced -gt $highestEnemyCombatSkillFaced) {
            $highestEnemyCombatSkillFaced = [int]$summary.HighestEnemyCombatSkillFaced
        }
        if ([int]$summary.HighestEnemyEnduranceFaced -gt $highestEnemyEnduranceFaced) {
            $highestEnemyEnduranceFaced = [int]$summary.HighestEnemyEnduranceFaced
        }
        if ([int]$summary.HighestEnemyCombatSkillDefeated -gt $highestEnemyCombatSkillDefeated) {
            $highestEnemyCombatSkillDefeated = [int]$summary.HighestEnemyCombatSkillDefeated
        }
        if ([int]$summary.HighestEnemyEnduranceDefeated -gt $highestEnemyEnduranceDefeated) {
            $highestEnemyEnduranceDefeated = [int]$summary.HighestEnemyEnduranceDefeated
        }

        if ([int]$summary.FastestVictoryRounds -gt 0 -and ($fastestVictoryRounds -eq 0 -or [int]$summary.FastestVictoryRounds -lt $fastestVictoryRounds)) {
            $fastestVictoryEnemyName = [string]$summary.FastestVictoryEnemyName
            $fastestVictoryRounds = [int]$summary.FastestVictoryRounds
            $fastestVictoryBookLabel = $bookLabel
        }

        if ($null -ne $summary.EasiestVictoryRatio -and ($null -eq $easiestVictoryRatio -or [int]$summary.EasiestVictoryRatio -gt [int]$easiestVictoryRatio)) {
            $easiestVictoryEnemyName = [string]$summary.EasiestVictoryEnemyName
            $easiestVictoryRatio = [int]$summary.EasiestVictoryRatio
            $easiestVictoryBookLabel = $bookLabel
        }

        if ([int]$summary.LongestFightRounds -gt $longestFightRounds) {
            $longestFightEnemyName = [string]$summary.LongestFightEnemyName
            $longestFightRounds = [int]$summary.LongestFightRounds
            $longestFightBookLabel = $bookLabel
        }

        if ($summary.PartialTracking) {
            $partialTracking = $true
        }

        $weaponUsageEntries += @($summary.WeaponUsage)
        $weaponVictoryEntries += @($summary.WeaponVictories)
    }

    $mergedWeaponUsage = @(Merge-LWNamedCountEntries -Entries $weaponUsageEntries)
    $mergedWeaponVictories = @(Merge-LWNamedCountEntries -Entries $weaponVictoryEntries)
    $favoriteWeapon = Get-LWCampaignTopNamedCountEntry -Entries $mergedWeaponUsage
    $deadliestWeapon = Get-LWCampaignTopNamedCountEntry -Entries $mergedWeaponVictories
    $completedBooks = @($script:GameState.Character.CompletedBooks | Sort-Object | ForEach-Object { Format-LWBookLabel -BookNumber ([int]$_) -IncludePrefix })
    $recentAchievements = @(Get-LWAchievementRecentUnlocks -Count 5)

    $summary = [pscustomobject]@{
        CharacterName                     = [string]$script:GameState.Character.Name
        CurrentBookLabel                  = Format-LWBookLabel -BookNumber ([int]$script:GameState.Character.BookNumber) -IncludePrefix
        CurrentRankLabel                  = Get-LWCurrentRankLabel -State $script:GameState
        CurrentRankFieldLabel             = $(if (Test-LWStateIsMagnakaiRuleset -State $script:GameState) { 'Magnakai Rank' } else { 'Kai Rank' })
        Difficulty                        = Get-LWCurrentDifficulty
        PermadeathEnabled                 = [bool](Test-LWPermadeathEnabled)
        RunIntegrityState                 = [string]$script:GameState.Run.IntegrityState
        AchievementPoolLabel              = Get-LWModeAchievementPoolLabel
        CurrentSection                    = [int]$script:GameState.CurrentSection
        RunStatus                         = Get-LWCampaignRunStatus
        BooksCompletedCount               = @($script:GameState.Character.CompletedBooks).Count
        CompletedBooksLabel               = $(if ($completedBooks.Count -gt 0) { $completedBooks -join '; ' } else { '(none)' })
        BooksTrackedCount                 = $bookEntries.Count
        AchievementsUnlocked              = Get-LWAchievementEligibleUnlockedCount
        AchievementsAvailable             = Get-LWAchievementAvailableCount
        ProfileAchievementsUnlocked       = Get-LWAchievementUnlockedCount
        ProfileAchievementsAvailable      = @((Get-LWAchievementDefinitions)).Count
        ActiveCombat                      = [bool]$script:GameState.Combat.Active
        DeathActive                       = [bool](Test-LWDeathActive)
        AutoSaveEnabled                   = [bool]$script:GameState.Settings.AutoSave
        TotalSuccessfulPathSections       = $totalSuccessfulPathSections
        TotalSectionsVisited              = $totalSectionsVisited
        TotalUniqueSectionsVisited        = $totalUniqueSectionsVisited
        TotalEnduranceLost                = $totalEnduranceLost
        TotalEnduranceGained              = $totalEnduranceGained
        TotalMealsEaten                   = $totalMealsEaten
        TotalHuntingMeals                 = $totalHuntingMeals
        TotalStarvationPenalties          = $totalStarvationPenalties
        TotalPotionsUsed                  = $totalPotionsUsed
        TotalStrongPotions                = $totalStrongPotions
        TotalPotionEnduranceRestored      = $totalPotionEnduranceRestored
        TotalRewindsUsed                  = $totalRewindsUsed
        TotalManualRecoveryShortcuts      = $totalManualRecoveryShortcuts
        TotalGoldGained                   = $totalGoldGained
        TotalGoldSpent                    = $totalGoldSpent
        TotalHealingTriggers              = $totalHealingTriggers
        TotalHealingEnduranceRestored     = $totalHealingEnduranceRestored
        TotalCombatCount                  = $totalCombatCount
        TotalVictories                    = $totalVictories
        TotalDefeats                      = $totalDefeats
        TotalEvades                       = $totalEvades
        TotalRoundsFought                 = $totalRoundsFought
        TotalMindblastCombats             = $totalMindblastCombats
        TotalMindblastVictories           = $totalMindblastVictories
        TotalInstantDeaths                = $totalInstantDeaths
        TotalCombatDeaths                 = $totalCombatDeaths
        TotalDeaths                       = $totalDeaths
        HighestEnemyCombatSkillFaced      = $highestEnemyCombatSkillFaced
        HighestEnemyEnduranceFaced        = $highestEnemyEnduranceFaced
        HighestEnemyCombatSkillDefeated   = $highestEnemyCombatSkillDefeated
        HighestEnemyEnduranceDefeated     = $highestEnemyEnduranceDefeated
        FastestVictoryEnemyName           = $fastestVictoryEnemyName
        FastestVictoryRounds              = $fastestVictoryRounds
        FastestVictoryBookLabel           = $fastestVictoryBookLabel
        EasiestVictoryEnemyName           = $easiestVictoryEnemyName
        EasiestVictoryRatio               = $easiestVictoryRatio
        EasiestVictoryBookLabel           = $easiestVictoryBookLabel
        LongestFightEnemyName             = $longestFightEnemyName
        LongestFightRounds                = $longestFightRounds
        LongestFightBookLabel             = $longestFightBookLabel
        FavoriteWeapon                    = $favoriteWeapon
        DeadliestWeapon                   = $deadliestWeapon
        WeaponUsage                       = @($mergedWeaponUsage)
        WeaponVictories                   = @($mergedWeaponVictories)
        BookEntries                       = @($bookEntries)
        RecentAchievements                = @($recentAchievements)
        PartialTracking                   = [bool]$partialTracking
    }

    $summary | Add-Member -NotePropertyName RunStyle -NotePropertyValue (Get-LWCampaignRunStyle -Summary $summary)
    $script:LWShellCampaignSummaryCache = [pscustomobject]@{
        Key     = $cacheKey
        Summary = $summary
    }
    return $summary
}

function Format-LWCampaignFightHighlight {
    param(
        [string]$EnemyName,
        [object]$Value,
        [string]$Suffix = '',
        [string]$BookLabel = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($EnemyName) -or $null -eq $Value -or ([string]$Value) -eq '' -or ([int]$Value) -le 0) {
        return '(none)'
    }

    $bookText = if ([string]::IsNullOrWhiteSpace($BookLabel)) { '' } else { " | $BookLabel" }
    return ("{0} ({1}{2}){3}" -f $EnemyName, $Value, $Suffix, $bookText)
}

function Show-LWCampaignOverview {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $completedBookLines = @($script:GameState.Character.CompletedBooks | Sort-Object | ForEach-Object {
            [pscustomobject]@{
                Text  = Get-LWBookDisplayLine -BookNumber ([int]$_)
                Color = 'Gray'
            }
        })
    $progressLines = @(Get-LWCompactRunHistoryLines)

    Write-LWRetroPanelHeader -Title 'Campaign Status' -AccentColor 'DarkCyan'
    Write-LWRetroPanelPairRow -LeftLabel 'Character' -LeftValue $Summary.CharacterName -RightLabel 'Difficulty' -RightValue ([string]$Summary.Difficulty) -LeftColor 'White' -RightColor (Get-LWDifficultyColor -Difficulty ([string]$Summary.Difficulty))
    Write-LWRetroPanelPairRow -LeftLabel 'Current Sect.' -LeftValue ([string]$Summary.CurrentSection) -RightLabel 'Permadeath' -RightValue $(if ($Summary.PermadeathEnabled) { 'On' } else { 'Off' }) -LeftColor 'White' -RightColor $(if ($Summary.PermadeathEnabled) { 'Red' } else { 'Gray' })
    Write-LWRetroPanelKeyValueRow -Label 'Current Book' -Value $Summary.CurrentBookLabel -ValueColor 'White' -LabelWidth 12
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Completed Books' -AccentColor 'Cyan'
    if ($completedBookLines.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $completedBookLines.Count; $i += 2) {
            $left = $completedBookLines[$i]
            $right = if (($i + 1) -lt $completedBookLines.Count) { $completedBookLines[$i + 1] } else { $null }
            Write-LWRetroPanelTwoColumnRow -LeftText ([string]$left.Text) -RightText $(if ($null -ne $right) { [string]$right.Text } else { '' }) -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Book Progression' -AccentColor 'DarkYellow'
    if ($progressLines.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $progressLines.Count; $i += 2) {
            $left = $progressLines[$i]
            $right = if (($i + 1) -lt $progressLines.Count) { $progressLines[$i + 1] } else { $null }
            Write-LWRetroPanelTwoColumnRow `
                -LeftText ([string]$left.Text) `
                -RightText $(if ($null -ne $right) { [string]$right.Text } else { '' }) `
                -LeftColor ([string]$left.Color) `
                -RightColor $(if ($null -ne $right) { [string]$right.Color } else { 'Gray' }) `
                -LeftWidth 28 `
                -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Campaign Notes' -AccentColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Run Integrity' -LeftValue ([string]$Summary.RunIntegrityState) -RightLabel 'Achievements' -RightValue ("{0}/{1}" -f $Summary.AchievementsUnlocked, $Summary.AchievementsAvailable) -LeftColor (Get-LWIntegrityColor -IntegrityState ([string]$Summary.RunIntegrityState)) -RightColor 'Magenta' -LeftLabelWidth 13 -RightLabelWidth 12 -LeftWidth 29 -Gap 2
    if (Test-LWStateIsMagnakaiRuleset -State $script:GameState) {
        Write-LWRetroPanelTextRow -Text 'Kai campaign has crossed into Magnakai rules.' -TextColor 'Gray'
        Write-LWRetroPanelTextRow -Text 'Transition safekeeping appears between later books.' -TextColor 'Gray'
    }
    else {
        Write-LWRetroPanelTextRow -Text 'Campaign is still operating under the Kai ruleset.' -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Format-LWCampaignFightHighlightWrappedText {
    param(
        [string]$Label,
        [string]$EnemyName,
        [object]$Value,
        [string]$Suffix = '',
        [string]$BookLabel = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ([string]::IsNullOrWhiteSpace($EnemyName) -or $null -eq $Value -or ([string]$Value) -eq '' -or ([int]$Value) -le 0) {
        return ("{0}: (none)" -f $Label)
    }

    return ("{0}: {1} ({2}{3}) | {4}" -f $Label, $EnemyName, $Value, $Suffix, $BookLabel)
}

function Get-LWDisplayBookHighlightTitle {
    param([string]$BookLabel)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $value = if ($null -eq $BookLabel) { '' } else { [string]$BookLabel }
    $value = [regex]::Replace($value, '^\s*Book\s+\d+\s*-\s*', '')
    $value = [regex]::Replace($value, '^\s*The\s+', '')
    if ([string]::IsNullOrWhiteSpace($value)) {
        return '(unknown)'
    }

    return $value.Trim()
}

function Show-LWCampaignBooks {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title 'Campaign Books' -AccentColor 'DarkCyan'
    $shownBookNumbers = @()
    foreach ($entry in @($Summary.BookEntries)) {
        $bookSummary = $entry.Summary
        $bookLabel = Format-LWBookLabel -BookNumber ([int]$bookSummary.BookNumber) -IncludePrefix
        $statusText = if ([string]$entry.Status -eq 'Current') { 'Current' } else { 'Completed' }
        $statusColor = if ([string]$entry.Status -eq 'Current') { 'Yellow' } else { 'Green' }
        $shownBookNumbers += [int]$bookSummary.BookNumber
        Write-LWRetroPanelTextRow -Text ("{0} | {1} | sections {2} | victories {3}" -f $bookLabel, $statusText, [int]$bookSummary.SectionsVisited, [int]$bookSummary.Victories) -TextColor $statusColor
    }

    $missingCompletedBooks = @($script:GameState.Character.CompletedBooks | Where-Object { $shownBookNumbers -notcontains [int]$_ } | Sort-Object)
    foreach ($bookNumber in $missingCompletedBooks) {
        $bookLabel = Format-LWBookLabel -BookNumber ([int]$bookNumber) -IncludePrefix
        Write-LWRetroPanelTextRow -Text ("{0} | Completed | summary unavailable from older save history" -f $bookLabel) -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWCampaignCombat {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $usageEntries = @(Merge-LWNamedCountEntries -Entries @($Summary.WeaponUsage) | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    $victoryEntries = @(Merge-LWNamedCountEntries -Entries @($Summary.WeaponVictories) | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    $favoriteWeapons = @($usageEntries | Select-Object -First 2 | ForEach-Object { "{0} x{1}" -f [string]$_.Name, [int]$_.Count })
    $deadliestWeapons = @($victoryEntries | Select-Object -First 2 | ForEach-Object { "{0} x{1}" -f [string]$_.Name, [int]$_.Count })
    $favoriteWeaponOne = if ($favoriteWeapons.Count -gt 0) { [string]$favoriteWeapons[0] } else { '(none)' }
    $favoriteWeaponTwo = if ($favoriteWeapons.Count -gt 1) { [string]$favoriteWeapons[1] } else { '(none)' }
    $deadliestWeaponOne = if ($deadliestWeapons.Count -gt 0) { [string]$deadliestWeapons[0] } else { '(none)' }
    $deadliestWeaponTwo = if ($deadliestWeapons.Count -gt 1) { [string]$deadliestWeapons[1] } else { '(none)' }
    $fastestVictoryLeft = if ([string]::IsNullOrWhiteSpace([string]$Summary.FastestVictoryEnemyName) -or [int]$Summary.FastestVictoryRounds -le 0) { 'Fastest Victory: (none)' } else { "Fastest Victory: $([string]$Summary.FastestVictoryEnemyName) ($([int]$Summary.FastestVictoryRounds) round$(if ([int]$Summary.FastestVictoryRounds -eq 1) { '' } else { 's' }))" }
    $fastestVictoryRight = Get-LWDisplayBookHighlightTitle -BookLabel ([string]$Summary.FastestVictoryBookLabel)
    $easiestVictoryLeft = if ([string]::IsNullOrWhiteSpace([string]$Summary.EasiestVictoryEnemyName) -or $null -eq $Summary.EasiestVictoryRatio) { 'Easiest Victory: (none)' } else { "Easiest Victory: $([string]$Summary.EasiestVictoryEnemyName) ($([int]$Summary.EasiestVictoryRatio) ratio)" }
    $easiestVictoryRight = Get-LWDisplayBookHighlightTitle -BookLabel ([string]$Summary.EasiestVictoryBookLabel)
    $longestFightLeft = if ([string]::IsNullOrWhiteSpace([string]$Summary.LongestFightEnemyName) -or [int]$Summary.LongestFightRounds -le 0) { 'Longest Fight  : (none)' } else { "Longest Fight  : $([string]$Summary.LongestFightEnemyName) ($([int]$Summary.LongestFightRounds) round$(if ([int]$Summary.LongestFightRounds -eq 1) { '' } else { 's' }))" }
    $longestFightRight = Get-LWDisplayBookHighlightTitle -BookLabel ([string]$Summary.LongestFightBookLabel)

    Write-LWRetroPanelHeader -Title 'Campaign Combat' -AccentColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Fights' -LeftValue ([string]$Summary.TotalCombatCount) -RightLabel 'Victories' -RightValue ([string]$Summary.TotalVictories) -LeftColor 'Gray' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Defeats' -LeftValue ([string]$Summary.TotalDefeats) -RightLabel 'Evades' -RightValue ([string]$Summary.TotalEvades) -LeftColor 'Red' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Rounds Fought' -LeftValue ([string]$Summary.TotalRoundsFought) -RightLabel 'Mindblast Wins' -RightValue ([string]$Summary.TotalMindblastVictories) -LeftColor 'Gray' -RightColor 'Cyan'
    Write-LWRetroPanelDivider
    Write-LWRetroPanelTwoColumnRow -LeftText $fastestVictoryLeft -RightText $fastestVictoryRight -LeftColor 'Green' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText $easiestVictoryLeft -RightText $easiestVictoryRight -LeftColor 'Green' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText $longestFightLeft -RightText $longestFightRight -LeftColor 'Yellow' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelDivider
    Write-LWRetroPanelTwoColumnRow -LeftText ("Favorite Weapons : {0}" -f $favoriteWeaponOne) -RightText $favoriteWeaponTwo -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText ("Deadliest Weapons: {0}" -f $deadliestWeaponOne) -RightText $deadliestWeaponTwo -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelFooter
}

function Show-LWCampaignSurvival {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title 'Campaign Survival' -AccentColor 'DarkYellow'
    Write-LWRetroPanelPairRow -LeftLabel 'END Lost' -LeftValue ([string]$Summary.TotalEnduranceLost) -RightLabel 'END Gained' -RightValue ([string]$Summary.TotalEnduranceGained) -LeftColor 'Red' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Healing Uses' -LeftValue ([string]$Summary.TotalHealingTriggers) -RightLabel 'Healing END' -RightValue ([string]$Summary.TotalHealingEnduranceRestored) -LeftColor 'Green' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Gold Gained' -LeftValue ([string]$Summary.TotalGoldGained) -RightLabel 'Gold Spent' -RightValue ([string]$Summary.TotalGoldSpent) -LeftColor 'Yellow' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Deaths' -LeftValue ([string]$Summary.TotalDeaths) -RightLabel 'Rewinds Used' -RightValue ([string]$Summary.TotalRewindsUsed) -LeftColor 'Red' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Potions Used' -LeftValue ([string]$Summary.TotalPotionsUsed) -RightLabel 'Autosave' -RightValue $(if ($Summary.AutoSaveEnabled) { 'On' } else { 'Off' }) -LeftColor 'Green' -RightColor $(if ($Summary.AutoSaveEnabled) { 'Green' } else { 'DarkGray' })
    Write-LWRetroPanelFooter
}

function Show-LWCampaignMilestones {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $recentAchievements = @($Summary.RecentAchievements)
    $fastestVictoryLeft = if ([string]::IsNullOrWhiteSpace([string]$Summary.FastestVictoryEnemyName) -or [int]$Summary.FastestVictoryRounds -le 0) { 'Fastest Victory: (none)' } else { "Fastest Victory: $([string]$Summary.FastestVictoryEnemyName) ($([int]$Summary.FastestVictoryRounds) round$(if ([int]$Summary.FastestVictoryRounds -eq 1) { '' } else { 's' }))" }
    $fastestVictoryRight = Get-LWDisplayBookHighlightTitle -BookLabel ([string]$Summary.FastestVictoryBookLabel)
    $easiestVictoryLeft = if ([string]::IsNullOrWhiteSpace([string]$Summary.EasiestVictoryEnemyName) -or $null -eq $Summary.EasiestVictoryRatio) { 'Easiest Victory: (none)' } else { "Easiest Victory: $([string]$Summary.EasiestVictoryEnemyName) ($([int]$Summary.EasiestVictoryRatio) ratio)" }
    $easiestVictoryRight = Get-LWDisplayBookHighlightTitle -BookLabel ([string]$Summary.EasiestVictoryBookLabel)
    $longestFightLeft = if ([string]::IsNullOrWhiteSpace([string]$Summary.LongestFightEnemyName) -or [int]$Summary.LongestFightRounds -le 0) { 'Longest Fight  : (none)' } else { "Longest Fight  : $([string]$Summary.LongestFightEnemyName) ($([int]$Summary.LongestFightRounds) round$(if ([int]$Summary.LongestFightRounds -eq 1) { '' } else { 's' }))" }
    $longestFightRight = Get-LWDisplayBookHighlightTitle -BookLabel ([string]$Summary.LongestFightBookLabel)

    Write-LWRetroPanelHeader -Title 'Campaign Milestones' -AccentColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Books Comp.' -LeftValue ([string]$Summary.BooksCompletedCount) -RightLabel 'Achievements' -RightValue ("{0}/{1}" -f $Summary.AchievementsUnlocked, $Summary.AchievementsAvailable) -LeftColor 'Green' -RightColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Profile Total' -LeftValue ("{0}/{1}" -f $Summary.ProfileAchievementsUnlocked, $Summary.ProfileAchievementsAvailable) -RightLabel 'Run Style' -RightValue $Summary.RunStyle -LeftColor 'DarkMagenta' -RightColor 'Cyan'
    Write-LWRetroPanelDivider
    Write-LWRetroPanelTwoColumnRow -LeftText $fastestVictoryLeft -RightText $fastestVictoryRight -LeftColor 'Green' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText $easiestVictoryLeft -RightText $easiestVictoryRight -LeftColor 'Green' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText $longestFightLeft -RightText $longestFightRight -LeftColor 'Yellow' -RightColor 'Gray' -LeftWidth 40 -Gap 2
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Recent Achievements' -AccentColor 'DarkYellow'
    if ($recentAchievements.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none yet)' -TextColor 'DarkGray'
    }
    else {
        foreach ($entry in $recentAchievements) {
            Write-LWRetroPanelWrappedKeyValueRows -Label (Get-LWAchievementUnlockedDisplayName -Entry $entry) -Value ([string]$entry.Description) -LabelColor 'White' -ValueColor 'Gray' -LabelWidth 21
        }
    }
    Write-LWRetroPanelFooter
}

function Show-LWCampaignScreen {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    Invoke-LWCoreShowCampaignScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
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

function Show-LWCombatPromptHint {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        return
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'combat'
}

function Get-LWCombatMeterText {
    param(
        [int]$Current,
        [int]$Max,
        [int]$Width = 18
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $safeMax = [Math]::Max(1, $Max)
    $clampedCurrent = [Math]::Max(0, [Math]::Min($Current, $safeMax))
    $filled = [Math]::Round(($clampedCurrent / [double]$safeMax) * $Width)
    if ($filled -lt 0) {
        $filled = 0
    }
    if ($filled -gt $Width) {
        $filled = $Width
    }

    return ('[' + ('#' * $filled) + ('-' * ($Width - $filled)) + ']')
}

function Write-LWCombatMeterLine {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][int]$Current,
        [Parameter(Mandatory = $true)][int]$Max,
        [Parameter(Mandatory = $true)][int]$CombatSkill,
        [string]$LabelColor = 'White'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $displayLabel = if ($Label.Length -gt 14) { ($Label.Substring(0, 12) + '..') } else { $Label }
    $meterColor = Get-LWEnduranceColor -Current $Current -Max $Max
    $meterText = Get-LWCombatMeterText -Current $Current -Max $Max

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = ("  {0,-14}" -f $displayLabel); Color = $LabelColor },
        [pscustomobject]@{ Text = (" CS {0,-3}" -f $CombatSkill); Color = 'Cyan' },
        [pscustomobject]@{ Text = (" END {0,2}/{1,-2} " -f $Current, $Max); Color = $meterColor },
        [pscustomobject]@{ Text = $meterText; Color = $meterColor }
    )
}

function Write-LWCombatRoundLine {
    param([Parameter(Mandatory = $true)][object]$Round)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $crtSuffix = ''
    if ((Test-LWPropertyExists -Object $Round -Name 'CRTColumn') -and $null -ne $Round.CRTColumn -and [int]$Round.CRTColumn -ne [int]$Round.Ratio) {
        $crtSuffix = " -> CRT $($Round.CRTColumn)"
    }

    $segments = @(
        [pscustomobject]@{ Text = ("  R{0,-2}" -f $Round.Round); Color = 'DarkYellow' },
        [pscustomobject]@{ Text = (" ratio {0,3}" -f (Format-LWSigned -Value ([int]$Round.Ratio))); Color = (Get-LWCombatRatioColor -Ratio ([int]$Round.Ratio)) },
        [pscustomobject]@{ Text = ("  roll {0}{1}" -f $Round.Roll, $crtSuffix); Color = 'Gray' },
        [pscustomobject]@{ Text = ("  enemy -{0}" -f $Round.EnemyLoss); Color = 'Red' }
    )
    if ((Test-LWPropertyExists -Object $Round -Name 'SpecialNote') -and -not [string]::IsNullOrWhiteSpace([string]$Round.SpecialNote)) {
        $segments += [pscustomobject]@{ Text = (" [{0}]" -f [string]$Round.SpecialNote); Color = 'DarkYellow' }
    }
    $segments += [pscustomobject]@{ Text = ("  Lone Wolf -{0}" -f $Round.PlayerLoss); Color = 'Red' }
    $segments += [pscustomobject]@{ Text = ("  END {0}/{1}" -f $Round.PlayerEnd, $Round.EnemyEnd); Color = 'DarkGray' }
    Write-LWDisplaySegmentedLine -Segments $segments
}

function Get-LWCombatRoundSummaryText {
    param([Parameter(Mandatory = $true)][object]$Round)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ("R{0}  Ratio {1}   You lose {2}   Enemy loses {3}" -f [int]$Round.Round, (Format-LWSigned -Value ([int]$Round.Ratio)), [int]$Round.PlayerLoss, [int]$Round.EnemyLoss)
}

function Show-LWCombatRecentRounds {
    param(
        [object[]]$Rounds = @(),
        [int]$Count = 3,
        [string]$Title = 'Recent Rounds'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title $Title -AccentColor 'DarkRed'
    $rounds = @($Rounds)
    if ($rounds.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text 'No rounds resolved yet.' -TextColor 'DarkGray'
        Write-LWRetroPanelFooter
        return
    }

    $start = [Math]::Max(0, $rounds.Count - $Count)
    foreach ($round in @($rounds[$start..($rounds.Count - 1)])) {
        Write-LWRetroPanelTextRow -Text (Get-LWCombatRoundSummaryText -Round $round) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWCombatDuelPanel {
    param(
        [Parameter(Mandatory = $true)][string]$EnemyName,
        [Parameter(Mandatory = $true)][int]$PlayerCurrent,
        [Parameter(Mandatory = $true)][int]$PlayerMax,
        [Parameter(Mandatory = $true)][int]$EnemyCurrent,
        [Parameter(Mandatory = $true)][int]$EnemyMax,
        [Parameter(Mandatory = $true)][int]$PlayerCombatSkill,
        [Parameter(Mandatory = $true)][int]$EnemyCombatSkill,
        [Parameter(Mandatory = $true)][int]$CombatRatio,
        [Nullable[int]]$RoundCount = $null,
        [string]$Title = 'The Duel'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    Write-LWRetroPanelHeader -Title $Title -AccentColor 'Red'
    Write-LWRetroPanelTwoColumnRow -LeftText 'Lone Wolf' -RightText $EnemyName -LeftColor 'White' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText ("CS {0}" -f $PlayerCombatSkill) -RightText ("CS {0}" -f $EnemyCombatSkill) -LeftColor 'Cyan' -RightColor 'Cyan' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText ("END {0} / {1}" -f $PlayerCurrent, $PlayerMax) -RightText ("END {0} / {1}" -f $EnemyCurrent, $EnemyMax) -LeftColor (Get-LWEnduranceColor -Current $PlayerCurrent -Max $PlayerMax) -RightColor (Get-LWEnduranceColor -Current $EnemyCurrent -Max $EnemyMax) -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText (Get-LWCombatMeterText -Current $PlayerCurrent -Max $PlayerMax) -RightText (Get-LWCombatMeterText -Current $EnemyCurrent -Max $EnemyMax) -LeftColor (Get-LWEnduranceColor -Current $PlayerCurrent -Max $PlayerMax) -RightColor (Get-LWEnduranceColor -Current $EnemyCurrent -Max $EnemyMax) -LeftWidth 28 -Gap 2
    Write-LWRetroPanelFooter
}

function Write-LWCombatTacticalTwoColumnRows {
    param(
        [string[]]$Items = @(),
        [string]$TextColor = 'Gray'
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $rows = @($Items | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($rows.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
        return
    }

    for ($i = 0; $i -lt $rows.Count; $i += 2) {
        $leftText = [string]$rows[$i]
        $rightText = if (($i + 1) -lt $rows.Count) { [string]$rows[$i + 1] } else { '' }
        Write-LWRetroPanelTwoColumnRow -LeftText $leftText -RightText $rightText -LeftColor $TextColor -RightColor $TextColor -LeftWidth 29 -Gap 2
    }
}

function Show-LWCombatTacticalPanel {
    param(
        [Parameter(Mandatory = $true)][string]$Weapon,
        [Parameter(Mandatory = $true)][bool]$UseMindblast,
        [string]$PsychicAttackLabel = 'Mindblast',
        [Parameter(Mandatory = $true)][bool]$EnemyIsUndead,
        [Parameter(Mandatory = $true)][string]$MindforceStatus,
        [Parameter(Mandatory = $true)][string]$KnockoutStatus,
        [Parameter(Mandatory = $true)][string]$EvadeStatus,
        [Parameter(Mandatory = $true)][string]$Mode,
        [object[]]$Notes = @(),
        [string]$BowStatus = '',
        [string]$PotionStatus = '',
        [switch]$UsesSommerswerd,
        [switch]$SommerswerdSuppressed
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $notes = @(
        $Notes |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    $bonusNotes = @($notes | Where-Object { $_ -match '\+' } | Select-Object -Unique)
    $overflowRuleNotes = @(
        $notes | Where-Object {
            $_ -notmatch '\+' -and
            $_ -notmatch '^Mindforce ' -and
            $_ -notmatch '^Evade ' -and
            $_ -notmatch '^Sommerswerd ' -and
            $_ -notmatch '^Undead damage x2$'
        } | Select-Object -Unique
    )

    $ruleStatusNotes = @(
        ("Mindforce : {0}" -f $MindforceStatus),
        ("Evade     : {0}" -f $EvadeStatus)
    )
    if ($UsesSommerswerd) {
        $ruleStatusNotes += ("Sommerswerd: {0}" -f $(if ($SommerswerdSuppressed) { 'Suppressed' } elseif ($EnemyIsUndead) { 'Active (undead x2)' } else { 'Active' }))
    }
    if ($KnockoutStatus -ne 'Off') {
        $ruleStatusNotes += ("Knockout  : {0}" -f $KnockoutStatus)
    }
    if (-not [string]::IsNullOrWhiteSpace($BowStatus)) {
        $ruleStatusNotes += ("Bow       : {0}" -f $BowStatus)
    }
    if (-not [string]::IsNullOrWhiteSpace($PotionStatus)) {
        $ruleStatusNotes += ("Potions   : {0}" -f $PotionStatus)
    }

    Write-LWRetroPanelHeader -Title 'Weapons / Rules' -AccentColor 'DarkYellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Weapon' -LeftValue $Weapon -RightLabel 'Mode' -RightValue $Mode -LeftColor 'Gray' -RightColor (Get-LWModeColor -Mode $Mode) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelDivider
    Write-LWCombatTacticalTwoColumnRows -Items $bonusNotes -TextColor 'Gray'
    Write-LWRetroPanelDivider
    Write-LWCombatTacticalTwoColumnRows -Items $ruleStatusNotes -TextColor 'Gray'
    $overflowNoteText = @($overflowRuleNotes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) -join ' | '
    if (-not [string]::IsNullOrWhiteSpace($overflowNoteText)) {
        Write-LWRetroPanelWrappedKeyValueRows -Label 'Notes' -Value $overflowNoteText -ValueColor 'Gray' -LabelWidth 13
    }
    Write-LWRetroPanelFooter
}

function Get-LWCurrentCombatLogEntry {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if (-not $script:GameState.Combat.Active) {
        return $null
    }

    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $breakdown = Get-LWCombatBreakdown
    return [pscustomobject]@{
        BookNumber = [int]$script:GameState.Character.BookNumber
        BookTitle  = [string](Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber))
        Section    = [int]$script:GameState.CurrentSection
        EnemyName  = $script:GameState.Combat.EnemyName
        Outcome    = 'In Progress'
        RoundCount = @($script:GameState.Combat.Log).Count
        PlayerEnd  = [int]$playerPool.Current
        PlayerEnduranceMax = [int]$playerPool.Max
        UsesPlayerTargetEndurance = [bool]$playerPool.UsesTarget
        EnemyEnd   = $script:GameState.Combat.EnemyEnduranceCurrent
        EnemyEnduranceMax = [int]$script:GameState.Combat.EnemyEnduranceMax
        EnemyIsUndead = [bool]$script:GameState.Combat.EnemyIsUndead
        EnemyUsesMindforce = [bool]$script:GameState.Combat.EnemyUsesMindforce
        MindforceBlockedByMindshield = [bool](Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)
        AletherCombatSkillBonus = [int]$script:GameState.Combat.AletherCombatSkillBonus
        AttemptKnockout = [bool]$script:GameState.Combat.AttemptKnockout
        Weapon     = [string]$script:GameState.Combat.EquippedWeapon
        SommerswerdSuppressed = [bool]$script:GameState.Combat.SommerswerdSuppressed
        BowRestricted = [bool]$script:GameState.Combat.BowRestricted
        CombatPotionsAllowed = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and $null -ne $script:GameState.Combat.CombatPotionsAllowed) { [bool]$script:GameState.Combat.CombatPotionsAllowed } else { $true }
        Mindblast  = [bool]$script:GameState.Combat.UseMindblast
        CanEvade   = [bool]$script:GameState.Combat.CanEvade
        EvadeAvailableAfterRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $script:GameState.Combat.EvadeAvailableAfterRound) { [int]$script:GameState.Combat.EvadeAvailableAfterRound } else { 0 }
        Mode       = [string]$script:GameState.Settings.CombatMode
        PlayerCombatSkill = if ($null -ne $breakdown) { [int]$breakdown.PlayerCombatSkill } else { $null }
        EnemyCombatSkill = if ($null -ne $breakdown) { [int]$breakdown.EnemyCombatSkill } else { $null }
        CombatRatio = if ($null -ne $breakdown) { [int]$breakdown.CombatRatio } else { $null }
        Notes      = if ($null -ne $breakdown) { @($breakdown.Notes) } else { @() }
        Log        = @($script:GameState.Combat.Log)
    }
}

function Write-LWCombatLogEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [string]$TitleSuffix = ''
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $playerEndMax = if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerEnduranceMax') -and $null -ne $Entry.PlayerEnduranceMax) { [int]$Entry.PlayerEnduranceMax } else { [Math]::Max([int]$Entry.PlayerEnd, 1) }
    $enemyEndMax = if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyEnduranceMax') -and $null -ne $Entry.EnemyEnduranceMax) { [int]$Entry.EnemyEnduranceMax } else { [Math]::Max([int]$Entry.EnemyEnd, 1) }
    $bookLabel = Get-LWCombatEntryBookLabel -Entry $Entry
    $combatSummary = if ([int](Get-LWCombatEntryBookNumber -Entry $Entry) -eq [int]$script:GameState.Character.BookNumber) {
        Get-LWLiveBookStatsSummary
    }
    else {
        $historicalSummary = @($script:GameState.BookHistory | Where-Object { [int]$_.BookNumber -eq [int](Get-LWCombatEntryBookNumber -Entry $Entry) } | Select-Object -Last 1)
        if ($historicalSummary.Count -gt 0) {
            $historicalSummary[0]
        }
        else {
            $null
        }
    }

    $displayWeapon = if ((Test-LWPropertyExists -Object $Entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Weapon)) { (Get-LWCombatDisplayWeapon -Weapon ([string]$Entry.Weapon)) } else { '' }

    $recordTitle = 'Combat Record'
    if (-not [string]::IsNullOrWhiteSpace($TitleSuffix)) {
        $recordTitle = ("Combat Record {0}" -f $TitleSuffix)
    }
    Write-LWRetroPanelHeader -Title $recordTitle -AccentColor 'DarkRed'
    if (-not [string]::IsNullOrWhiteSpace($displayWeapon)) {
        Write-LWRetroPanelPairRow -LeftLabel 'Enemy' -LeftValue ([string]$Entry.EnemyName) -RightLabel 'Weapon' -RightValue $displayWeapon -LeftColor 'White' -RightColor 'Gray' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    }
    else {
        Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$Entry.EnemyName) -ValueColor 'White'
    }
    Write-LWRetroPanelPairRow -LeftLabel 'Book / Section' -LeftValue ("{0} / {1}" -f [int](Get-LWCombatEntryBookNumber -Entry $Entry), $(if ((Test-LWPropertyExists -Object $Entry -Name 'Section') -and $null -ne $Entry.Section) { [string]$Entry.Section } else { '?' })) -RightLabel 'Outcome' -RightValue ([string]$Entry.Outcome) -LeftColor 'Gray' -RightColor (Get-LWOutcomeColor -Outcome ([string]$Entry.Outcome)) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    if ((Test-LWPropertyExists -Object $Entry -Name 'CombatRatio') -and $null -ne $Entry.CombatRatio) {
        Write-LWRetroPanelPairRow -LeftLabel 'Rounds Fought' -LeftValue ([string]$Entry.RoundCount) -RightLabel 'Combat Ratio' -RightValue (Format-LWSigned -Value ([int]$Entry.CombatRatio)) -LeftColor 'Gray' -RightColor (Get-LWCombatRatioColor -Ratio ([int]$Entry.CombatRatio)) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    }
    else {
        Write-LWRetroPanelKeyValueRow -Label 'Rounds Fought' -Value ([string]$Entry.RoundCount) -ValueColor 'Gray'
    }
    Write-LWRetroPanelFooter

    Show-LWCombatDuelPanel -Title 'Player / Enemy' -EnemyName ([string]$Entry.EnemyName) -PlayerCurrent ([int]$Entry.PlayerEnd) -PlayerMax $playerEndMax -EnemyCurrent ([int]$Entry.EnemyEnd) -EnemyMax $enemyEndMax -PlayerCombatSkill $(if ((Test-LWPropertyExists -Object $Entry -Name 'PlayerCombatSkill') -and $null -ne $Entry.PlayerCombatSkill) { [int]$Entry.PlayerCombatSkill } else { 0 }) -EnemyCombatSkill $(if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyCombatSkill') -and $null -ne $Entry.EnemyCombatSkill) { [int]$Entry.EnemyCombatSkill } else { 0 }) -CombatRatio $(if ((Test-LWPropertyExists -Object $Entry -Name 'CombatRatio') -and $null -ne $Entry.CombatRatio) { [int]$Entry.CombatRatio } else { 0 })

    Show-LWCombatTacticalPanel -Weapon $(if ((Test-LWPropertyExists -Object $Entry -Name 'Weapon') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Weapon)) { Get-LWCombatDisplayWeapon -Weapon ([string]$Entry.Weapon) } else { 'Unknown' }) -UseMindblast:([bool]((Test-LWPropertyExists -Object $Entry -Name 'Mindblast') -and [bool]$Entry.Mindblast)) -PsychicAttackLabel (Get-LWCombatPsychicAttackLabel -State $script:GameState) -EnemyIsUndead:([bool]((Test-LWPropertyExists -Object $Entry -Name 'EnemyIsUndead') -and [bool]$Entry.EnemyIsUndead)) -MindforceStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'EnemyUsesMindforce') -and [bool]$Entry.EnemyUsesMindforce) { $(if ((Test-LWPropertyExists -Object $Entry -Name 'MindforceBlockedByMindshield') -and [bool]$Entry.MindforceBlockedByMindshield) { 'Blocked by Mindshield' } else { 'Active' }) } else { 'Off' }) -KnockoutStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'AttemptKnockout') -and [bool]$Entry.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }) -EvadeStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'CanEvade') -and [bool]$Entry.CanEvade) { 'Yes' } else { 'No' }) -Mode $(if ((Test-LWPropertyExists -Object $Entry -Name 'Mode') -and -not [string]::IsNullOrWhiteSpace([string]$Entry.Mode)) { [string]$Entry.Mode } else { [string]$script:GameState.Settings.CombatMode }) -Notes @($Entry.Notes) -BowStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'BowRestricted') -and [bool]$Entry.BowRestricted) { 'Locked' } else { '' }) -PotionStatus $(if ((Test-LWPropertyExists -Object $Entry -Name 'CombatPotionsAllowed') -and -not [bool]$Entry.CombatPotionsAllowed) { 'Locked' } else { '' }) -UsesSommerswerd:(Test-LWWeaponIsSommerswerd -Weapon ([string]$Entry.Weapon)) -SommerswerdSuppressed:([bool]((Test-LWPropertyExists -Object $Entry -Name 'SommerswerdSuppressed') -and [bool]$Entry.SommerswerdSuppressed))

    Show-LWCombatRecentRounds -Rounds @($Entry.Log) -Count ([Math]::Max(1, @($Entry.Log).Count)) -Title 'Round Log'

    Write-LWRetroPanelHeader -Title 'Book Combat Totals' -AccentColor 'DarkYellow'
    if ($null -ne $combatSummary) {
        Write-LWRetroPanelPairRow -LeftLabel 'Fights Won' -LeftValue ([string]$combatSummary.Victories) -RightLabel 'Fights Lost' -RightValue ([string]$combatSummary.Defeats) -LeftColor 'Green' -RightColor 'Red'
        Write-LWRetroPanelPairRow -LeftLabel 'Total Rounds' -LeftValue ([string]$combatSummary.RoundsFought) -RightLabel 'Damage Taken' -RightValue ([string]$combatSummary.EnduranceLost) -LeftColor 'Gray' -RightColor 'Red'
    }
    else {
        Write-LWRetroPanelTextRow -Text '(unavailable)' -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWCombatLog {
    param(
        [object]$Entry = $null,
        [Nullable[int]]$HistoryIndex = $null,
        [Nullable[int]]$BookNumber = $null,
        [switch]$All
    )
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($All) {
        $history = @($script:GameState.History)
        $activeEntry = Get-LWCurrentCombatLogEntry
        $renderedCount = 0
        $currentBookKey = $null
        $currentBookEntry = $null
        $bookItems = @()

        $flushArchiveGroup = {
            param(
                [object]$BookEntry,
                [object[]]$Items
            )

            if ($null -eq $BookEntry -or @($Items).Count -eq 0) {
                return
            }

            Write-LWCombatArchiveBookHeader -Entry $BookEntry
            Show-LWCombatArchiveEntriesPanel -Items @($Items)
        }

        if ($null -ne $BookNumber -and $null -ne $activeEntry -and (Get-LWCombatEntryBookNumber -Entry $activeEntry) -ne [int]$BookNumber) {
            $activeEntry = $null
        }

        if ($history.Count -eq 0 -and $null -eq $activeEntry) {
            Write-LWWarn 'No combat log available.'
            return
        }

        for ($i = 0; $i -lt $history.Count; $i++) {
            if ($null -ne $BookNumber -and (Get-LWCombatEntryBookNumber -Entry $history[$i]) -ne [int]$BookNumber) {
                continue
            }

            $bookKey = Get-LWCombatEntryBookKey -Entry $history[$i]
            if ($bookKey -ne $currentBookKey) {
                & $flushArchiveGroup -BookEntry $currentBookEntry -Items @($bookItems)
                $currentBookKey = $bookKey
                $currentBookEntry = $history[$i]
                $bookItems = @()
            }
            $bookItems += [pscustomobject]@{
                Entry  = $history[$i]
                Prefix = ("#{0}" -f ($i + 1))
                Color  = (Get-LWOutcomeColor -Outcome ([string]$history[$i].Outcome))
            }
            $renderedCount++
        }

        if ($null -ne $activeEntry) {
            $activeBookKey = Get-LWCombatEntryBookKey -Entry $activeEntry
            if ($activeBookKey -ne $currentBookKey) {
                & $flushArchiveGroup -BookEntry $currentBookEntry -Items @($bookItems)
                $bookItems = @()
                $currentBookKey = $activeBookKey
                $currentBookEntry = $activeEntry
            }
            $bookItems += [pscustomobject]@{
                Entry  = $activeEntry
                Prefix = 'Current'
                Color  = 'Cyan'
            }
            $renderedCount++
        }

        if ($renderedCount -gt 0) {
            & $flushArchiveGroup -BookEntry $currentBookEntry -Items @($bookItems)
        }

        if ($renderedCount -eq 0) {
            if ($null -ne $BookNumber) {
                Write-LWWarn ("No combat log available for {0}." -f (Format-LWBookLabel -BookNumber ([int]$BookNumber) -IncludePrefix))
            }
            else {
                Write-LWWarn 'No combat log available.'
            }
        }

        return
    }

    if ($null -ne $HistoryIndex) {
        $history = @($script:GameState.History)
        if ($HistoryIndex -lt 1 -or $HistoryIndex -gt $history.Count) {
            Write-LWWarn "Combat log number must be between 1 and $($history.Count)."
            return
        }

        Write-LWCombatLogEntry -Entry $history[$HistoryIndex - 1] -TitleSuffix ("#{0}" -f $HistoryIndex)
        return
    }

    if ($null -eq $Entry) {
        if ($script:GameState.Combat.Active) {
            $Entry = Get-LWCurrentCombatLogEntry
        }
        elseif (@($script:GameState.History).Count -gt 0) {
            $Entry = $script:GameState.History[-1]
        }
        else {
            Write-LWWarn 'No combat log available.'
            return
        }
    }

    Write-LWCombatLogEntry -Entry $Entry
}

function Show-LWCombatSummary {
    param([Parameter(Mandatory = $true)][object]$Summary)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $notes = if ((Test-LWPropertyExists -Object $Summary -Name 'Notes') -and @($Summary.Notes).Count -gt 0) { @($Summary.Notes) } else { @() }
    $weapon = if (Test-LWPropertyExists -Object $Summary -Name 'Weapon') { Get-LWCombatDisplayWeapon -Weapon ([string]$Summary.Weapon) } else { 'Unknown' }
    $ratio = if (Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') { [int]$Summary.CombatRatio } else { 0 }
    $usingSommerswerd = (Test-LWPropertyExists -Object $Summary -Name 'Weapon') -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$Summary.Weapon)) -and (Test-LWPropertyExists -Object $Summary -Name 'BookNumber') -and [int]$Summary.BookNumber -ge 2
    $enemyUndead = (Test-LWPropertyExists -Object $Summary -Name 'EnemyIsUndead') -and [bool]$Summary.EnemyIsUndead
    $enemyUsesMindforce = (Test-LWPropertyExists -Object $Summary -Name 'EnemyUsesMindforce') -and [bool]$Summary.EnemyUsesMindforce
    $mindforceBlocked = (Test-LWPropertyExists -Object $Summary -Name 'MindforceBlockedByMindshield') -and [bool]$Summary.MindforceBlockedByMindshield
    $useMindblast = (Test-LWPropertyExists -Object $Summary -Name 'Mindblast') -and [bool]$Summary.Mindblast
    $playerCombatSkill = if ((Test-LWPropertyExists -Object $Summary -Name 'PlayerCombatSkill') -and $null -ne $Summary.PlayerCombatSkill) { [int]$Summary.PlayerCombatSkill } else { 0 }
    $enemyCombatSkill = if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyCombatSkill') -and $null -ne $Summary.EnemyCombatSkill) { [int]$Summary.EnemyCombatSkill } else { 0 }
    $playerEndMax = if ((Test-LWPropertyExists -Object $Summary -Name 'PlayerEnduranceMax') -and $null -ne $Summary.PlayerEnduranceMax) { [int]$Summary.PlayerEnduranceMax } else { [Math]::Max([int]$Summary.PlayerEnd, 1) }
    $enemyEndMax = if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyEnduranceMax') -and $null -ne $Summary.EnemyEnduranceMax) { [int]$Summary.EnemyEnduranceMax } else { [Math]::Max([int]$Summary.EnemyEnd, 1) }
    $mode = if ((Test-LWPropertyExists -Object $Summary -Name 'Mode') -and -not [string]::IsNullOrWhiteSpace([string]$Summary.Mode)) { [string]$Summary.Mode } else { $script:GameState.Settings.CombatMode }
    $canEvade = (Test-LWPropertyExists -Object $Summary -Name 'CanEvade') -and [bool]$Summary.CanEvade
    $evadeStatus = if (-not $canEvade) { 'No' } elseif ((Test-LWPropertyExists -Object $Summary -Name 'EvadeAvailableAfterRound') -and [int]$Summary.EvadeAvailableAfterRound -gt 0 -and [int]$Summary.RoundCount -lt [int]$Summary.EvadeAvailableAfterRound) { "After round $([int]$Summary.EvadeAvailableAfterRound)" } else { 'Yes' }
    $mindforceLossPerRound = if ((Test-LWPropertyExists -Object $Summary -Name 'MindforceLossPerRound') -and $null -ne $Summary.MindforceLossPerRound) { [int]$Summary.MindforceLossPerRound } else { 2 }
    $mindforceStatus = if (-not $enemyUsesMindforce) { 'Off' } elseif ($mindforceBlocked) { 'Blocked by Mindshield' } else { "Active (-$mindforceLossPerRound END/round)" }
    $knockoutStatus = if ((Test-LWPropertyExists -Object $Summary -Name 'AttemptKnockout') -and [bool]$Summary.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }

    Write-LWRetroPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$Summary.EnemyName) -ValueColor 'White'
    Write-LWRetroPanelKeyValueRow -Label 'Outcome' -Value ([string]$Summary.Outcome) -ValueColor (Get-LWOutcomeColor -Outcome ([string]$Summary.Outcome))
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Ratio' -LeftValue (Format-LWSigned -Value $ratio) -RightLabel 'Rounds' -RightValue ([string]$Summary.RoundCount) -LeftColor (Get-LWCombatRatioColor -Ratio $ratio) -RightColor 'Gray'
    if ((Test-LWPropertyExists -Object $Summary -Name 'SpecialResolutionSection') -and $null -ne $Summary.SpecialResolutionSection) {
        Write-LWRetroPanelKeyValueRow -Label 'Next Section' -Value ([string]$Summary.SpecialResolutionSection) -ValueColor 'Yellow'
    }
    Write-LWRetroPanelFooter

    Show-LWCombatDuelPanel -Title 'Player / Enemy' -EnemyName ([string]$Summary.EnemyName) -PlayerCurrent ([int]$Summary.PlayerEnd) -PlayerMax $playerEndMax -EnemyCurrent ([int]$Summary.EnemyEnd) -EnemyMax $enemyEndMax -PlayerCombatSkill $playerCombatSkill -EnemyCombatSkill $enemyCombatSkill -CombatRatio $ratio -RoundCount ([int]$Summary.RoundCount)
    Show-LWCombatTacticalPanel -Weapon $weapon -UseMindblast:$useMindblast -PsychicAttackLabel (Get-LWCombatPsychicAttackLabel -State $script:GameState) -EnemyIsUndead:$enemyUndead -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -EvadeStatus $evadeStatus -Mode $mode -Notes $notes -BowStatus $(if ((Test-LWPropertyExists -Object $Summary -Name 'BowRestricted') -and [bool]$Summary.BowRestricted) { 'Locked' } else { '' }) -PotionStatus $(if ((Test-LWPropertyExists -Object $Summary -Name 'CombatPotionsAllowed') -and -not [bool]$Summary.CombatPotionsAllowed) { 'Locked' } else { '' }) -UsesSommerswerd:$usingSommerswerd -SommerswerdSuppressed:([bool]((Test-LWPropertyExists -Object $Summary -Name 'SommerswerdSuppressed') -and [bool]$Summary.SommerswerdSuppressed))
    Show-LWCombatRecentRounds -Rounds @($Summary.Log) -Count 5 -Title 'Round History'
    if ((Test-LWPropertyExists -Object $Summary -Name 'SpecialResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$Summary.SpecialResolutionNote)) {
        Write-LWRetroPanelHeader -Title 'Combat Note' -AccentColor 'DarkYellow'
        Write-LWRetroPanelTextRow -Text ([string]$Summary.SpecialResolutionNote) -TextColor 'Gray'
        Write-LWRetroPanelFooter
    }

    Show-LWHelpfulCommandsPanel -ScreenName 'combat' -Variant 'summary'
}

Export-ModuleMember -Function Write-LWInfo, Write-LWWarn, Write-LWError, Write-LWMessageLine, Add-LWNotification, Write-LWCrashLog, Clear-LWNotifications, Clear-LWAchievementDisplayCountsCache, Warm-LWRuntimeCaches, Request-LWRender, Clear-LWScreenHost, Get-LWDefaultScreen, Set-LWScreen, Write-LWNotifications, Write-LWBannerFooter, Write-LWInventoryBanner, Write-LWCombatBanner, Write-LWStatsBanner, Write-LWCampaignBanner, Write-LWAchievementsBanner, Write-LWDeathBanner, Show-LWWelcomeScreen, Show-LWLoadScreen, Show-LWDisciplineSelectionScreen, Show-LWCombatScreen, Show-LWCombatLogScreen, Show-LWModesScreen, Show-LWDeathScreen, Show-LWBookCompleteScreen, Refresh-LWScreen, Get-LWCombatEntryBookNumber, Get-LWCombatEntryBookTitle, Get-LWCombatEntryBookLabel, Get-LWCombatEntryBookKey, Write-LWCombatArchiveBookHeader, Get-LWCombatArchiveOutcomeLabel, Format-LWCombatArchiveCellText, Get-LWCombatArchiveEntryText, Get-LWCombatArchiveHeaderText, Show-LWCombatArchiveEntriesPanel, Show-LWHistory, Get-LWLiveBookStatsSummary, Show-LWStatsOverview, Show-LWStatsCombat, Show-LWStatsSurvival, Show-LWStatsScreen, Merge-LWNamedCountEntries, Get-LWCampaignBookEntries, Get-LWCampaignTopNamedCountEntry, Get-LWCampaignRunStatus, Get-LWCampaignRunStyle, Get-LWCampaignSummary, Format-LWCampaignFightHighlight, Show-LWCampaignOverview, Format-LWCampaignFightHighlightWrappedText, Get-LWDisplayBookHighlightTitle, Show-LWCampaignBooks, Show-LWCampaignCombat, Show-LWCampaignSurvival, Show-LWCampaignMilestones, Show-LWCampaignScreen, Get-LWAchievementDefinitionById, Show-LWCombatPromptHint, Get-LWCombatMeterText, Write-LWCombatMeterLine, Write-LWCombatRoundLine, Get-LWCombatRoundSummaryText, Show-LWCombatRecentRounds, Show-LWCombatDuelPanel, Write-LWCombatTacticalTwoColumnRows, Show-LWCombatTacticalPanel, Get-LWCurrentCombatLogEntry, Write-LWCombatLogEntry, Show-LWCombatLog, Show-LWCombatSummary

function Write-LWInlineWarn {
    param([Parameter(Mandatory = $true)][string]$Message)

    if ($script:LWUi.Enabled) {
        Write-LWMessageLine -Level 'Warn' -Message $Message
        return
    }

    Write-LWWarn $Message
}

function Write-LWLootNoRoomWarning {
    param(
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [string]$ExtraMessage = ''
    )

    $message = "You don't have room for {0} right now." -f $DisplayName
    if (-not [string]::IsNullOrWhiteSpace($ExtraMessage)) {
        $message = "{0} {1}" -f $message, $ExtraMessage.Trim()
    }

    Write-LWInlineWarn $message
}

function Format-LWCompletedBooks {
    param([object[]]$Books)

    $books = @($Books | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ } | Sort-Object -Unique)
    if ($books.Count -eq 0) {
        return '(none)'
    }

    if ($books.Count -eq 1) {
        return [string]$books[0]
    }

    $ranges = @()
    $rangeStart = [int]$books[0]
    $rangeEnd = [int]$books[0]
    for ($i = 1; $i -lt $books.Count; $i++) {
        $bookNumber = [int]$books[$i]
        if ($bookNumber -eq ($rangeEnd + 1)) {
            $rangeEnd = $bookNumber
            continue
        }

        $ranges += $(if ($rangeStart -eq $rangeEnd) { [string]$rangeStart } else { "{0}-{1}" -f $rangeStart, $rangeEnd })
        $rangeStart = $bookNumber
        $rangeEnd = $bookNumber
    }

    $ranges += $(if ($rangeStart -eq $rangeEnd) { [string]$rangeStart } else { "{0}-{1}" -f $rangeStart, $rangeEnd })
    return ($ranges -join ', ')
}

function Get-LWBookCompletionQuote {
    param([int]$BookNumber)

    $quotes = @(
        'A Kai Lord''s finest victories are the ones that light the next road forward.',
        'When the dark is beaten back, wisdom bids you take the next step without fear.',
        'The true strength of the Kai is not only in the blade, but in the will to endure.',
        'Each trial survived becomes a lesson carried into the battles yet to come.',
        'Sommerlund is guarded not by steel alone, but by courage, discipline, and hope.'
    )

    if ($quotes.Count -eq 0) {
        return 'The wisdom of the Kai goes with you into the next chapter of your journey.'
    }

    $index = [Math]::Abs(($BookNumber - 1) % $quotes.Count)
    return $quotes[$index]
}

function Show-LWSectionGateHints {
    if (-not (Test-LWHasState)) {
        return
    }

    $bookNumber = [int]$script:GameState.Character.BookNumber
    $section = [int]$script:GameState.CurrentSection

    switch ($bookNumber) {
        1 {
            switch ($section) {
                78 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Write-LWInfo 'Section 78: the bribe route is available here if you want to spend Gold Crowns for safe passage.'
                    }
                }
                23 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGoldenKeyItemNames) -Type 'special') {
                        Write-LWInfo 'Section 23: Golden Key route is available here.'
                    }
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mind Over Matter') {
                        Write-LWInfo 'Section 23: Mind Over Matter route is available here.'
                    }
                }
                88 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Healing') {
                        Write-LWInfo 'Section 88: Healing can save the wounded man here.'
                    }
                }
                105 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Kinship') {
                        Write-LWInfo 'Section 105: Animal Kinship route is available here.'
                    }
                }
                128 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Hunting') {
                        Write-LWInfo 'Section 128: Hunting route is available here.'
                    }
                }
                151 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mind Over Matter') {
                        Write-LWInfo 'Section 151: Mind Over Matter route is available here.'
                    }
                }
                242 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindshield') {
                        Write-LWInfo 'Section 242: Mindshield route is available here.'
                    }
                }
                311 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Camouflage') {
                        Write-LWInfo 'Section 311: Camouflage route is available here.'
                    }
                }
            }
        }
        2 {
            switch ($section) {
                4 {
                    Write-LWInfo 'Section 4: the arm-wrestling route is available here if you want to gamble for Gold Crowns.'
                }
                39 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWCoachTicketItemNames) -Type 'special') {
                        Write-LWInfo 'Section 39: coach-ticket continuity is active here; you qualify for the coach-passenger inn route.'
                    }
                }
                { @(59, 134, 299, 338) -contains $_ } {
                    if (Test-LWStateHasMagicSpear -State $script:GameState) {
                        Write-LWInfo ("Section {0}: Magic Spear route is available here." -f $section)
                    }
                }
                { @(62, 223, 273, 291, 349) -contains $_ } {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSealOfHammerdalItemNames) -Type 'special') {
                        Write-LWInfo ("Section {0}: Seal of Hammerdal route is available here." -f $section)
                    }
                }
                { @(170, 202, 246, 287) -contains $_ } {
                    $passes = @()
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWWhitePassItemNames) -Type 'special') { $passes += 'White Pass' }
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWRedPassItemNames) -Type 'special') { $passes += 'Red Pass' }
                    if ($passes.Count -gt 0) {
                        Write-LWInfo ("Section {0}: pass route available ({1})." -f $section, ($passes -join ', '))
                    }
                }
                95 {
                    if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Healing') -or
                        (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWHealingPotionItemNames) -Type 'backpack') -or
                        (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWLaumspurHerbItemNames) -Type 'backpack')) {
                        Write-LWInfo 'Section 95: recovery route options are available here.'
                    }
                }
                130 {
                    Write-LWInfo 'Section 130: the priest pays for your room here; no Gold deduction is required.'
                }
                168 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Write-LWInfo 'Section 168: you can pay 1 Gold Crown for a room if you want the inn route.'
                    }
                    else {
                        Write-LWInfo 'Section 168: without 1 Gold Crown for the room, this route sends you onward without shelter.'
                    }
                }
                238 {
                    Write-LWInfo 'Section 238: the gaming-house grants one free silver token the first time you enter, and Weapons must be checked at the door.'
                }
                276 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindblast') {
                        Write-LWInfo 'Section 276: Mindblast lets you bypass the arm-wrestling combat route here.'
                    }
                }
                346 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWCoachTicketItemNames) -Type 'special') {
                        Write-LWInfo 'Section 346: coach ticket continuity route is available here.'
                    }
                    if ((@($script:GameState.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -gt 0) -or [int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Write-LWInfo 'Section 346: you can satisfy the forced meal here with a carried Meal or by spending 1 Gold Crown.'
                    }
                    if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Write-LWInfo 'Section 346: if you still have 1 Gold Crown left after the meal, the room route remains available.'
                    }
                }
            }
        }
        3 {
            switch ($section) {
                41 {
                    $stoneNames = @((Get-LWBlueStoneTriangleItemNames) + (Get-LWBlueStoneDiscItemNames))
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names $stoneNames -Type 'special') {
                        Write-LWInfo 'Section 41: the Blue Stone Triangle is retained here; do not erase it.'
                    }
                }
                15 {
                    $names = @('Dagger') + (Get-LWBoneSwordWeaponNames)
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names $names -Type 'weapon') {
                        Write-LWInfo 'Section 15: Dagger / Bone Sword route is available here.'
                    }
                }
                50 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Glowing Crystal') -Type 'special') {
                        Write-LWInfo 'Section 50: Glowing Crystal route is available here.'
                    }
                }
                { @(45, 303) -contains $_ } {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWOrnateSilverKeyItemNames) -Type 'special') {
                        Write-LWInfo ("Section {0}: Ornate Silver Key route is available here." -f $section)
                    }
                }
                97 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Diamond') -Type 'special') {
                        Write-LWInfo 'Section 97: Diamond distraction route is available here.'
                    }
                    if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Write-LWInfo 'Section 97: Gold-distraction route is available here.'
                    }
                }
                { @(67, 104, 202) -contains $_ } {
                    $stoneNames = @((Get-LWBlueStoneTriangleItemNames) + (Get-LWBlueStoneDiscItemNames))
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names $stoneNames -Type 'special') {
                        Write-LWInfo ("Section {0}: Blue Stone route is available here." -f $section)
                    }
                }
                { @(76, 114, 194, 319) -contains $_ } {
                    if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Kinship')) {
                        Write-LWInfo ("Section {0}: Hunting / Animal Kinship route is available here." -f $section)
                    }
                }
                { @(170, 271, 345) -contains $_ } {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Rope', 'Long Rope') -Type 'backpack') {
                        Write-LWInfo ("Section {0}: Rope route is available here." -f $section)
                    }
                }
                181 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Write-LWInfo 'Section 181: you can retry the Gold distraction if you still want to spend more Gold Crowns.'
                    }
                }
                173 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWStoneEffigyItemNames) -Type 'special') {
                        Write-LWInfo 'Section 173: Effigy endgame route is available here.'
                    }
                    if (Test-LWStateHasSommerswerd -State $script:GameState) {
                        Write-LWInfo 'Section 173: Sommerswerd endgame route is available here.'
                    }
                }
                { @(187, 236, 258, 345) -contains $_ } {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Type 'special') {
                        Write-LWInfo ("Section {0}: Gold Bracelet continuity is active here." -f $section)
                    }
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindshield') {
                        Write-LWInfo ("Section {0}: Mindshield route is available here." -f $section)
                    }
                }
                349 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Glowing Crystal') -Type 'special') {
                        Write-LWInfo 'Section 349: Glowing Crystal route is available here.'
                    }
                }
            }
        }
        4 {
            switch ($section) {
                { @(70, 258) -contains $_ } {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWOnyxMedallionItemNames) -Type 'special') {
                        Write-LWInfo ("Section {0}: Onyx Medallion route is available here." -f $section)
                    }
                    if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Camouflage') -and @($script:GameState.Character.Disciplines).Count -ge 7) {
                        Write-LWInfo ("Section {0}: Camouflage + Guardian route is available here." -f $section)
                    }
                }
                { @(168, 246, 296) -contains $_ } {
                    if (Test-LWStateHasSommerswerd -State $script:GameState) {
                        Write-LWInfo ("Section {0}: Sommerswerd route is available here." -f $section)
                    }
                }
                274 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWFlaskOfHolyWaterItemNames) -Type 'backpack') {
                        Write-LWInfo 'Section 274: Flask of Holy Water route is available here.'
                    }
                }
            }
        }
        5 {
            switch ($section) {
                31 {
                    if ((Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWFiresphereItemNames) -Type 'special') -or (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWTinderboxItemNames) -Type 'backpack')) {
                        Write-LWInfo 'Section 31: your Firesphere or Tinderbox opens the lit-market route here.'
                    }
                }
                122 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGaolersKeysItemNames) -Type 'special') {
                        Write-LWInfo 'Section 122: Gaoler''s Keys route is available here.'
                    }
                }
                137 {
                    if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $script:GameState -Name 'Sixth Sense')) {
                        Write-LWInfo 'Section 137: Tracking / Sixth Sense can guide you onto the safer route here.'
                    }
                }
                212 {
                    if (Test-LWStateHasSommerswerd -State $script:GameState) {
                        Write-LWInfo 'Section 212: Sommerswerd route is available here.'
                    }
                }
                221 {
                    if (Test-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed') {
                        Write-LWInfo 'Section 221: Crystal Star Pendant continuity route is available here.'
                    }
                }
                224 {
                    if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Kinship') {
                        Write-LWInfo 'Section 224: Animal Kinship route is available here.'
                    }
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWOnyxMedallionItemNames) -Type 'special') {
                        Write-LWInfo 'Section 224: Onyx Medallion route is available here.'
                    }
                }
                239 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGraveweedItemNames) -Type 'backpack') {
                        Write-LWInfo 'Section 239: Tincture of Graveweed route is available here.'
                    }
                }
                248 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -ge 5) {
                        Write-LWInfo 'Section 248: you can pay 5 Gold Crowns for the merchant''s absurd waistcoat and the Tipasa lead.'
                    }
                }
                256 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -ge 1) {
                        Write-LWInfo 'Section 256: paying 1 Gold Crown keeps the questioning route open here.'
                    }
                }
                264 {
                    if (Test-LWStateHasSommerswerd -State $script:GameState) {
                        Write-LWInfo 'Section 264: Sommerswerd route is available here.'
                    }
                }
                265 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -ge 1) {
                        Write-LWInfo 'Section 265: paying 1 Gold Crown opens the Soushilla route from here.'
                    }
                }
                276 {
                    if ([int]$script:GameState.Inventory.GoldCrowns -ge 5) {
                        Write-LWInfo 'Section 276: paying 5 Gold Crowns refreshes Soushilla''s memory here.'
                    }
                }
                288 {
                    if (Test-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed') {
                        Write-LWInfo 'Section 288: Crystal Star Pendant continuity route is available here.'
                    }
                }
                289 {
                    if (Test-LWStateHasSommerswerd -State $script:GameState) {
                        Write-LWInfo 'Section 289: Sommerswerd route is available here.'
                    }
                }
                300 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBlackCrystalCubeItemNames) -Type 'special') {
                        Write-LWInfo 'Section 300: Black Crystal Cube route is available here.'
                    }
                }
                319 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWOnyxMedallionItemNames) -Type 'special') {
                        Write-LWInfo 'Section 319: Onyx Medallion continuity is active here.'
                    }
                }
                333 {
                    if (Test-LWStateHasSommerswerd -State $script:GameState) {
                        Write-LWInfo 'Section 333: Sommerswerd route is available here.'
                    }
                }
                380 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBlackCrystalCubeItemNames) -Type 'special') {
                        Write-LWInfo 'Section 380: Black Crystal Cube route is available here.'
                    }
                }
                382 {
                    if (Test-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed') {
                        Write-LWInfo 'Section 382: Crystal Star Pendant continuity route is available here.'
                    }
                }
                395 {
                    if ((Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWPrismItemNames) -Type 'backpack') -or (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBlueStoneTriangleItemNames) -Type 'special')) {
                        Write-LWInfo 'Section 395: Prism / Blue Stone Triangle route is available here.'
                    }
                }
                397 {
                    if (Test-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard') {
                        Write-LWInfo 'Section 397: you may ask whether the vaxeler is Soushilla.'
                    }
                }
                256 {
                    if (Test-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard') {
                        Write-LWInfo 'Section 256: the Soushilla question is available here because you learned her name earlier.'
                    }
                }
            }
        }
    }
}

function Get-LWScreenAccentColor {
    $screen = if ($null -ne $script:LWUi -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.CurrentScreen)) {
        [string]$script:LWUi.CurrentScreen
    }
    else {
        'sheet'
    }

    switch ($screen) {
        'inventory' { return 'Yellow' }
        'combat' { return 'Red' }
        'combatlog' { return 'DarkRed' }
        'disciplines' { return 'DarkYellow' }
        'notes' { return 'DarkCyan' }
        'history' { return 'DarkYellow' }
        'stats' { return 'Cyan' }
        'campaign' { return 'DarkCyan' }
        'achievements' { return 'Magenta' }
        'modes' { return 'Magenta' }
        'help' { return 'Cyan' }
        'load' { return 'Cyan' }
        'bookcomplete' { return 'Green' }
        'death' { return 'Red' }
        default { return 'Cyan' }
    }
}

function Get-LWScreenBannerStatusText {
    $versionText = "v$($script:LWAppVersion)"
    $screen = if ($null -ne $script:LWUi -and -not [string]::IsNullOrWhiteSpace([string]$script:LWUi.CurrentScreen)) {
        [string]$script:LWUi.CurrentScreen
    }
    else {
        'sheet'
    }

    if (-not (Test-LWHasState)) {
        switch ($screen) {
            'load' { return "LOAD SAVE :: $versionText" }
            'help' { return "HELP :: $versionText" }
            'modes' { return "RUN MODES :: $versionText" }
            default { return "CAMPAIGN READY :: $versionText" }
        }
    }

    $bookNumber = [int]$script:GameState.Character.BookNumber
    switch ($screen) {
        'inventory' { return ("INVENTORY :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'combat' { return ("COMBAT MODE :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'combatlog' { return ("COMBAT LOG :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'disciplines' { return ("DISCIPLINES :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'notes' { return ("NOTES :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'history' { return ("HISTORY :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'stats' { return ("STATS :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'campaign' { return ("CAMPAIGN :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'achievements' { return ("ACHIEVEMENTS :: BOOK {0} :: {1}" -f $bookNumber, $versionText) }
        'modes' { return ("RUN MODES :: {0}" -f $versionText) }
        'help' { return ("HELP :: {0}" -f $versionText) }
        'load' { return ("LOAD SAVE :: {0}" -f $versionText) }
        'bookcomplete' { return ("BOOK COMPLETE :: {0}" -f $versionText) }
        'death' { return ("YOU HAVE FALLEN :: {0}" -f $versionText) }
        default { return ("{0} MODE :: BOOK {1} :: {2}" -f ([string]$script:GameState.RuleSet).ToUpperInvariant(), $bookNumber, $versionText) }
    }
}

function Get-LWInlineKeyValueText {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value,
        [int]$LabelWidth = 13
    )

    return ("{0,-$LabelWidth}: {1}" -f $Label, $Value)
}

function Write-LWRetroPanelPairRow {
    param(
        [Parameter(Mandatory = $true)][string]$LeftLabel,
        [Parameter(Mandatory = $true)][string]$LeftValue,
        [Parameter(Mandatory = $true)][string]$RightLabel,
        [Parameter(Mandatory = $true)][string]$RightValue,
        [string]$LeftColor = 'Gray',
        [string]$RightColor = 'Gray',
        [int]$LeftLabelWidth = 13,
        [int]$RightLabelWidth = 13,
        [int]$LeftWidth = 28,
        [int]$Gap = 2
    )

    Write-LWRetroPanelTwoColumnRow `
        -LeftText (Get-LWInlineKeyValueText -Label $LeftLabel -Value $LeftValue -LabelWidth $LeftLabelWidth) `
        -RightText (Get-LWInlineKeyValueText -Label $RightLabel -Value $RightValue -LabelWidth $RightLabelWidth) `
        -LeftColor $LeftColor `
        -RightColor $RightColor `
        -LeftWidth $LeftWidth `
        -Gap $Gap
}

function New-LWHelpfulCommandRow {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value,
        [string]$LabelColor = 'DarkYellow'
    )

    return [pscustomobject]@{
        Label      = $Label
        Value      = $Value
        LabelColor = $LabelColor
    }
}

function Get-LWHelpfulCommandRows {
    param(
        [Parameter(Mandatory = $true)][string]$ScreenName,
        [string]$View = '',
        [string]$Variant = ''
    )

    $screen = $ScreenName.Trim().ToLowerInvariant()
    $viewName = if ([string]::IsNullOrWhiteSpace($View)) { '' } else { $View.Trim().ToLowerInvariant() }
    $variantName = if ([string]::IsNullOrWhiteSpace($Variant)) { '' } else { $Variant.Trim().ToLowerInvariant() }

    switch ($screen) {
        'welcome' {
            return @(
                (New-LWHelpfulCommandRow -Label 'load' -Value 'open the save catalog'),
                (New-LWHelpfulCommandRow -Label 'new' -Value 'create a fresh character'),
                (New-LWHelpfulCommandRow -Label 'newrun' -Value 'restart the run on this profile'),
                (New-LWHelpfulCommandRow -Label 'modes' -Value 'review run difficulty and rules')
            )
        }
        'load' {
            return @(
                (New-LWHelpfulCommandRow -Label 'load 2' -Value 'open save number 2 from the catalog'),
                (New-LWHelpfulCommandRow -Label 'load sample-save.json' -Value 'load a save by file name'),
                (New-LWHelpfulCommandRow -Label 'new' -Value 'start a new character instead'),
                (New-LWHelpfulCommandRow -Label 'help' -Value 'show the full command reference')
            )
        }
        'help' {
            return @(
                (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet'),
                (New-LWHelpfulCommandRow -Label 'section <n>' -Value 'move to the section you are reading'),
                (New-LWHelpfulCommandRow -Label 'load' -Value 'open the save picker'),
                (New-LWHelpfulCommandRow -Label 'quit' -Value 'leave the app')
            )
        }
        'disciplineselect' {
            return @(
                (New-LWHelpfulCommandRow -Label '1' -Value 'choose the first listed option'),
                (New-LWHelpfulCommandRow -Label '1,3' -Value 'choose multiple numbered options'),
                (New-LWHelpfulCommandRow -Label 'help' -Value 'show the full command reference'),
                (New-LWHelpfulCommandRow -Label 'quit' -Value 'leave the app')
            )
        }
        'sheet' {
            return @(
                (New-LWHelpfulCommandRow -Label 'section <n>' -Value 'move to the section you are reading'),
                (New-LWHelpfulCommandRow -Label 'inv' -Value 'open the full inventory screen'),
                (New-LWHelpfulCommandRow -Label 'disciplines' -Value 'review Kai or Magnakai abilities'),
                (New-LWHelpfulCommandRow -Label 'campaign' -Value 'open run-wide progress and summaries')
            )
        }
        'inventory' {
            $rows = @(
                (New-LWHelpfulCommandRow -Label 'add <type> <name>' -Value 'add an item to a carried section'),
                (New-LWHelpfulCommandRow -Label 'drop <type> <slot>' -Value 'remove one carried item by slot'),
                (New-LWHelpfulCommandRow -Label 'recover <type|all>' -Value 'restore gear from the recovery stash')
            )
            if (Test-LWStateHasQuiver -State $script:GameState) {
                $rows += (New-LWHelpfulCommandRow -Label 'arrows +/-n' -Value 'spend or refill quiver arrows')
            }
            else {
                $rows += (New-LWHelpfulCommandRow -Label 'gold +/-n' -Value 'adjust carried Gold Crowns')
            }

            return $rows
        }
        'disciplines' {
            return @(
                (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet'),
                (New-LWHelpfulCommandRow -Label 'section <n>' -Value 'continue play from the next section'),
                (New-LWHelpfulCommandRow -Label 'campaign' -Value 'compare this book to the full run'),
                (New-LWHelpfulCommandRow -Label 'help' -Value 'show the full command reference')
            )
        }
        'notes' {
            return @(
                (New-LWHelpfulCommandRow -Label 'note <text>' -Value 'add a new reminder'),
                (New-LWHelpfulCommandRow -Label 'note remove <n>' -Value 'erase a note by number'),
                (New-LWHelpfulCommandRow -Label 'history' -Value 'review recent events and combat history'),
                (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
            )
        }
        'history' {
            return @(
                (New-LWHelpfulCommandRow -Label 'combat log' -Value 'inspect the latest or current fight'),
                (New-LWHelpfulCommandRow -Label 'campaign' -Value 'open the full run overview'),
                (New-LWHelpfulCommandRow -Label 'achievements' -Value 'review unlock progress'),
                (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
            )
        }
        'stats' {
            switch ($viewName) {
                'combat' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'stats' -Value 'return to the overview stats'),
                        (New-LWHelpfulCommandRow -Label 'stats survival' -Value 'switch to survival totals'),
                        (New-LWHelpfulCommandRow -Label 'combat log' -Value 'inspect a fight in detail'),
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'open full run summaries')
                    )
                }
                'survival' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'stats' -Value 'return to the overview stats'),
                        (New-LWHelpfulCommandRow -Label 'stats combat' -Value 'switch to combat totals'),
                        (New-LWHelpfulCommandRow -Label 'inv' -Value 'review current inventory and gear'),
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'open full run summaries')
                    )
                }
                default {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'stats combat' -Value 'switch to combat totals'),
                        (New-LWHelpfulCommandRow -Label 'stats survival' -Value 'switch to survival totals'),
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'open full run summaries'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
            }
        }
        'campaign' {
            switch ($viewName) {
                'books' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'return to campaign overview'),
                        (New-LWHelpfulCommandRow -Label 'campaign combat' -Value 'switch to combat totals'),
                        (New-LWHelpfulCommandRow -Label 'achievements' -Value 'review unlock progress'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                'combat' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'return to campaign overview'),
                        (New-LWHelpfulCommandRow -Label 'combat log' -Value 'inspect archived fights'),
                        (New-LWHelpfulCommandRow -Label 'stats combat' -Value 'switch to current-book combat stats'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                'survival' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'return to campaign overview'),
                        (New-LWHelpfulCommandRow -Label 'stats survival' -Value 'switch to current-book survival stats'),
                        (New-LWHelpfulCommandRow -Label 'inv' -Value 'review current gear and resources'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                'milestones' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'return to campaign overview'),
                        (New-LWHelpfulCommandRow -Label 'achievements recent' -Value 'show the latest unlocks'),
                        (New-LWHelpfulCommandRow -Label 'stats' -Value 'switch to current-book stats'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                default {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'campaign books' -Value 'show book-by-book status'),
                        (New-LWHelpfulCommandRow -Label 'campaign combat' -Value 'show run-wide combat totals'),
                        (New-LWHelpfulCommandRow -Label 'campaign milestones' -Value 'show achievements and highlights'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
            }
        }
        'achievements' {
            switch ($viewName) {
                'unlocked' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'achievements' -Value 'return to achievement overview'),
                        (New-LWHelpfulCommandRow -Label 'achievements locked' -Value 'show locked achievement slots'),
                        (New-LWHelpfulCommandRow -Label 'achievements recent' -Value 'show the latest unlocks'),
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'compare against run progress')
                    )
                }
                'locked' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'achievements' -Value 'return to achievement overview'),
                        (New-LWHelpfulCommandRow -Label 'achievements progress' -Value 'show tracked milestone progress'),
                        (New-LWHelpfulCommandRow -Label 'achievements recent' -Value 'show the latest unlocks'),
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'compare against run progress')
                    )
                }
                'recent' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'achievements' -Value 'return to achievement overview'),
                        (New-LWHelpfulCommandRow -Label 'achievements unlocked' -Value 'show unlocked achievements'),
                        (New-LWHelpfulCommandRow -Label 'campaign' -Value 'compare against run progress'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                'progress' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'achievements' -Value 'return to achievement overview'),
                        (New-LWHelpfulCommandRow -Label 'achievements unlocked' -Value 'show unlocked achievements'),
                        (New-LWHelpfulCommandRow -Label 'achievements locked' -Value 'show locked achievement slots'),
                        (New-LWHelpfulCommandRow -Label 'campaign milestones' -Value 'compare run milestones')
                    )
                }
                'planned' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'achievements' -Value 'return to achievement overview'),
                        (New-LWHelpfulCommandRow -Label 'achievements progress' -Value 'show tracked milestone progress'),
                        (New-LWHelpfulCommandRow -Label 'campaign milestones' -Value 'compare run milestones'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                default {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'achievements unlocked' -Value 'show unlocked achievements'),
                        (New-LWHelpfulCommandRow -Label 'achievements locked' -Value 'show locked achievement slots'),
                        (New-LWHelpfulCommandRow -Label 'achievements recent' -Value 'show the latest unlocks'),
                        (New-LWHelpfulCommandRow -Label 'achievements progress' -Value 'show tracked milestone progress'),
                        (New-LWHelpfulCommandRow -Label 'campaign milestones' -Value 'compare run milestones')
                    )
                }
            }
        }
        'modes' {
            return @(
                (New-LWHelpfulCommandRow -Label 'difficulty <name>' -Value 'set Story, Easy, Normal, Hard, or Veteran'),
                (New-LWHelpfulCommandRow -Label 'permadeath on|off' -Value 'toggle permadeath for the next run'),
                (New-LWHelpfulCommandRow -Label 'mode manual|data' -Value 'switch combat resolution mode'),
                (New-LWHelpfulCommandRow -Label 'newrun' -Value 'start a fresh run with the current mode rules')
            )
        }
        'combat' {
            switch ($variantName) {
                'setup' {
                    return @(
                        (New-LWHelpfulCommandRow -Label '1 / 2 / ...' -Value 'choose one of the listed weapons'),
                        (New-LWHelpfulCommandRow -Label '0' -Value 'fight unarmed'),
                        (New-LWHelpfulCommandRow -Label 'help' -Value 'show the full command reference'),
                        (New-LWHelpfulCommandRow -Label 'quit' -Value 'leave the app')
                    )
                }
                'summary' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'combat log' -Value 'inspect the archived fight details'),
                        (New-LWHelpfulCommandRow -Label 'section <n>' -Value 'continue into the next section'),
                        (New-LWHelpfulCommandRow -Label 'history' -Value 'review recent events'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                'inactive' {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'combat <enemy cs end>' -Value 'start a tracked combat'),
                        (New-LWHelpfulCommandRow -Label 'fight <enemy cs end>' -Value 'start and auto-resolve a combat'),
                        (New-LWHelpfulCommandRow -Label 'combat log' -Value 'inspect the latest recorded fight'),
                        (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
                    )
                }
                default {
                    return @(
                        (New-LWHelpfulCommandRow -Label 'fight' -Value 'resolve the next combat round'),
                        (New-LWHelpfulCommandRow -Label 'evade' -Value 'attempt escape if this fight allows it'),
                        (New-LWHelpfulCommandRow -Label 'potion' -Value 'use a healing item before the next round'),
                        (New-LWHelpfulCommandRow -Label 'combat log' -Value 'inspect the current fight record')
                    )
                }
            }
        }
        'combatlog' {
            return @(
                (New-LWHelpfulCommandRow -Label 'combat log all' -Value 'show the full combat archive'),
                (New-LWHelpfulCommandRow -Label 'combat log 1' -Value 'open one archived fight by number'),
                (New-LWHelpfulCommandRow -Label 'history' -Value 'review recent events and run context'),
                (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
            )
        }
        'death' {
            $rows = @()
            if (-not (Test-LWPermadeathEnabled) -and (Get-LWAvailableRewindCount) -gt 0) {
                $rows += (New-LWHelpfulCommandRow -Label 'rewind 1' -Value 'return to the latest safe checkpoint')
            }
            $rows += (New-LWHelpfulCommandRow -Label 'load' -Value 'open a save and recover the run')
            $rows += (New-LWHelpfulCommandRow -Label 'newrun' -Value 'start a fresh run on the same profile')
            $rows += (New-LWHelpfulCommandRow -Label 'quit' -Value 'leave the app')
            return $rows
        }
        'bookcomplete' {
            return @(
                (New-LWHelpfulCommandRow -Label 'campaign' -Value 'review full-run progress after the book'),
                (New-LWHelpfulCommandRow -Label 'achievements' -Value 'review unlocks earned so far'),
                (New-LWHelpfulCommandRow -Label 'save' -Value 'write the new campaign state to disk'),
                (New-LWHelpfulCommandRow -Label 'sheet' -Value 'return to the main character sheet')
            )
        }
        default {
            return @()
        }
    }
}

function Get-LWHelpfulCommandsPanelCacheEntry {
    param(
        [Parameter(Mandatory = $true)][string]$ScreenName,
        [string]$View = '',
        [string]$Variant = '',
        [string]$AccentColor = 'DarkYellow'
    )

    $screenKey = $ScreenName.Trim().ToLowerInvariant()
    $viewKey = if ([string]::IsNullOrWhiteSpace($View)) { '' } else { $View.Trim().ToLowerInvariant() }
    $variantKey = if ([string]::IsNullOrWhiteSpace($Variant)) { '' } else { $Variant.Trim().ToLowerInvariant() }
    $dynamicKey = switch ($screenKey) {
        'death' { '{0}|{1}' -f ([int](Get-LWAvailableRewindCount)), [int][bool](Test-LWPermadeathEnabled) }
        default { '' }
    }
    $cacheKey = '{0}|{1}|{2}|{3}|{4}' -f $screenKey, $viewKey, $variantKey, $AccentColor, $dynamicKey

    if ($script:LWShellHelpfulCommandsPanelCache.ContainsKey($cacheKey)) {
        return $script:LWShellHelpfulCommandsPanelCache[$cacheKey]
    }

    $rows = @(Get-LWHelpfulCommandRows -ScreenName $ScreenName -View $View -Variant $Variant)
    $labelWidth = 18
    foreach ($row in $rows) {
        $labelText = if ($null -eq $row.Label) { '' } else { [string]$row.Label }
        if ($labelText.Length -gt $labelWidth) {
            $labelWidth = $labelText.Length
        }
    }
    $labelWidth = [Math]::Min(24, [Math]::Max(16, $labelWidth))

    $entry = [pscustomobject]@{
        Rows       = @($rows)
        LabelWidth = $labelWidth
    }
    $script:LWShellHelpfulCommandsPanelCache[$cacheKey] = $entry
    return $entry
}

function Show-LWHelpfulCommandsPanel {
    param(
        [Parameter(Mandatory = $true)][string]$ScreenName,
        [string]$View = '',
        [string]$Variant = '',
        [string]$AccentColor = 'DarkYellow'
    )

    $cacheEntry = Get-LWHelpfulCommandsPanelCacheEntry -ScreenName $ScreenName -View $View -Variant $Variant -AccentColor $AccentColor
    $rows = @($cacheEntry.Rows)
    if ($rows.Count -eq 0) {
        return
    }

    $labelWidth = [int]$cacheEntry.LabelWidth

    Write-LWRetroPanelHeader -Title 'Helpful Commands' -AccentColor $AccentColor
    foreach ($row in $rows) {
        $labelColor = if ($null -ne $row -and (Test-LWPropertyExists -Object $row -Name 'LabelColor') -and -not [string]::IsNullOrWhiteSpace([string]$row.LabelColor)) {
            [string]$row.LabelColor
        }
        else {
            'DarkYellow'
        }
        Write-LWRetroPanelKeyValueRow -Label ([string]$row.Label) -Value ([string]$row.Value) -LabelColor $labelColor -ValueColor 'Gray' -LabelWidth $labelWidth
    }
    Write-LWRetroPanelFooter
}

function Get-LWCompactRunHistoryLines {
    if (-not (Test-LWHasState)) {
        return @()
    }

    $lines = @()
    foreach ($bookNumber in @(1..[int]$script:GameState.Character.BookNumber)) {
        $status = if ([int]$bookNumber -eq [int]$script:GameState.Character.BookNumber) {
            if (@($script:GameState.Character.CompletedBooks) -contains $bookNumber) { 'Complete' } else { 'In Progress' }
        }
        elseif (@($script:GameState.Character.CompletedBooks) -contains $bookNumber) {
            'Complete'
        }
        else {
            'Unplayed'
        }

        $lines += [pscustomobject]@{
            BookNumber = $bookNumber
            Text       = ("Book {0} : {1}" -f $bookNumber, $status)
            Color      = $(if ($status -eq 'Complete') { 'Green' } elseif ($status -eq 'In Progress') { 'Yellow' } else { 'DarkGray' })
        }
    }

    return @($lines)
}

function Write-LWBanner {
    Invoke-LWCoreWriteBanner -Context (Get-LWModuleContext)
}

function Write-LWCommandPromptHint {
    Invoke-LWCoreWriteCommandPromptHint -Context (Get-LWModuleContext)
}

function Write-LWScreenFooterNote {
    param([Parameter(Mandatory = $true)][string]$Message)

    Invoke-LWCoreWriteScreenFooterNote -Context (Get-LWModuleContext) -Message $Message
}

function Show-LWDisciplines {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    $gameData = Get-LWModuleGameData

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $isMagnakai = Test-LWStateIsMagnakaiRuleset -State $script:GameState
    $panelTitle = if ($isMagnakai) { 'Magnakai Disciplines' } else { 'Kai Disciplines' }
    $displayDisciplines = @()
    $definitionsByName = @{}
    $kaiDefinitions = if ($null -ne $gameData -and (Test-LWPropertyExists -Object $gameData -Name 'KaiDisciplines') -and $null -ne $gameData.KaiDisciplines) {
        @($gameData.KaiDisciplines)
    }
    else {
        @()
    }
    $magnakaiDefinitions = if ($null -ne $gameData -and (Test-LWPropertyExists -Object $gameData -Name 'MagnakaiDisciplines') -and $null -ne $gameData.MagnakaiDisciplines) {
        @($gameData.MagnakaiDisciplines)
    }
    else {
        @()
    }
    $magnakaiDisciplines = if ($null -ne $script:GameState.Character -and (Test-LWPropertyExists -Object $script:GameState.Character -Name 'MagnakaiDisciplines') -and $null -ne $script:GameState.Character.MagnakaiDisciplines) {
        @($script:GameState.Character.MagnakaiDisciplines | ForEach-Object { [string]$_ })
    }
    else {
        @()
    }

    if ($isMagnakai) {
        foreach ($definition in $magnakaiDefinitions) {
            $definitionsByName[[string]$definition.Name] = $definition
        }
        $displayDisciplines = @($magnakaiDisciplines)
    }
    else {
        foreach ($definition in $kaiDefinitions) {
            $definitionsByName[[string]$definition.Name] = $definition
        }
        foreach ($discipline in @($script:GameState.Character.Disciplines)) {
            if ([string]$discipline -eq 'Weaponskill' -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Character.WeaponskillWeapon)) {
                $displayDisciplines += ("Weaponskill ({0})" -f [string]$script:GameState.Character.WeaponskillWeapon)
            }
            else {
                $displayDisciplines += [string]$discipline
            }
        }
    }

    Write-LWRetroPanelHeader -Title $panelTitle -AccentColor 'DarkYellow'
    if ($displayDisciplines.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        if ($isMagnakai) {
            for ($i = 0; $i -lt $displayDisciplines.Count; $i += 3) {
                $leftLabel = [string]$displayDisciplines[$i]
                $middleLabel = if (($i + 1) -lt $displayDisciplines.Count) { [string]$displayDisciplines[$i + 1] } else { '' }
                $rightLabel = if (($i + 2) -lt $displayDisciplines.Count) { [string]$displayDisciplines[$i + 2] } else { '' }
                Write-LWRetroPanelThreeColumnRow `
                    -LeftText $leftLabel `
                    -MiddleText $middleLabel `
                    -RightText $rightLabel `
                    -LeftColor 'Green' `
                    -MiddleColor 'Green' `
                    -RightColor 'Green' `
                    -LeftWidth 18 `
                    -MiddleWidth 18 `
                    -Gap 2
            }
        }
        else {
            for ($i = 0; $i -lt $displayDisciplines.Count; $i += 2) {
                $leftLabel = [string]$displayDisciplines[$i]
                $rightLabel = if (($i + 1) -lt $displayDisciplines.Count) { [string]$displayDisciplines[$i + 1] } else { '' }
                Write-LWRetroPanelTwoColumnRow -LeftText $leftLabel -RightText $rightLabel -LeftColor 'Green' -RightColor 'Green' -LeftWidth 28 -Gap 2
            }
        }
    }
    Write-LWRetroPanelFooter

    if ($isMagnakai -and @($script:GameState.Character.WeaponmasteryWeapons).Count -gt 0) {
        Write-LWRetroPanelHeader -Title 'Weaponmastery' -AccentColor 'DarkYellow'
        $weapons = @($script:GameState.Character.WeaponmasteryWeapons | ForEach-Object { [string]$_ })
        for ($i = 0; $i -lt $weapons.Count; $i += 3) {
            $leftText = [string]$weapons[$i]
            $middleText = if (($i + 1) -lt $weapons.Count) { [string]$weapons[$i + 1] } else { '' }
            $rightText = if (($i + 2) -lt $weapons.Count) { [string]$weapons[$i + 2] } else { '' }
            Write-LWRetroPanelThreeColumnRow `
                -LeftText $leftText `
                -MiddleText $middleText `
                -RightText $rightText `
                -LeftColor 'Gray' `
                -MiddleColor 'Gray' `
                -RightColor 'Gray' `
                -LeftWidth 18 `
                -MiddleWidth 18 `
                -Gap 2
        }
        Write-LWRetroPanelFooter
    }

    if ($isMagnakai -and $null -ne $gameData -and (Test-LWPropertyExists -Object $gameData -Name 'MagnakaiLoreCircles') -and @($gameData.MagnakaiLoreCircles).Count -gt 0) {
        Write-LWRetroPanelHeader -Title 'Lore Circles' -AccentColor 'Magenta'
        $owned = @($magnakaiDisciplines)
        $circleRows = @()
        foreach ($definition in @($gameData.MagnakaiLoreCircles | Sort-Object @{ Expression = { Get-LWLoreCircleDisplayOrder -Name ([string]$_.Name) } }, @{ Expression = { [string]$_.Name } })) {
            $circleRows += (Format-LWLoreCirclePanelRow -Definition $definition -OwnedDisciplines $owned)
        }

        for ($i = 0; $i -lt $circleRows.Count; $i += 2) {
            $left = $circleRows[$i]
            $right = if (($i + 1) -lt $circleRows.Count) { $circleRows[$i + 1] } else { $null }
            Write-LWRetroPanelTwoColumnRow `
                -LeftText ([string]$left.Text) `
                -RightText $(if ($null -ne $right) { [string]$right.Text } else { '' }) `
                -LeftColor ([string]$left.Color) `
                -RightColor $(if ($null -ne $right) { [string]$right.Color } else { 'Gray' }) `
                -LeftWidth 27 `
                -Gap 2
        }
        Write-LWRetroPanelFooter
    }

    if ($isMagnakai -and @($script:GameState.Character.ImprovedDisciplines).Count -gt 0) {
        Write-LWRetroPanelHeader -Title 'Improved Disciplines' -AccentColor 'DarkCyan'
        for ($i = 0; $i -lt @($script:GameState.Character.ImprovedDisciplines).Count; $i += 2) {
            $leftText = [string]$script:GameState.Character.ImprovedDisciplines[$i]
            $rightText = if (($i + 1) -lt @($script:GameState.Character.ImprovedDisciplines).Count) { [string]$script:GameState.Character.ImprovedDisciplines[$i + 1] } else { '' }
            Write-LWRetroPanelTwoColumnRow -LeftText $leftText -RightText $rightText -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
        }
        Write-LWRetroPanelFooter
    }

    if ([string]$script:LWUi.CurrentScreen -eq 'disciplines') {
        Write-LWRetroPanelHeader -Title 'Discipline Notes' -AccentColor 'Cyan'
        if ($displayDisciplines.Count -eq 0) {
            Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
        }
        else {
            $noteNames = if ($isMagnakai) {
                @($magnakaiDisciplines)
            }
            else {
                @($script:GameState.Character.Disciplines | ForEach-Object { [string]$_ })
            }

            foreach ($disciplineName in $noteNames) {
                $effect = if ($definitionsByName.ContainsKey([string]$disciplineName) -and -not [string]::IsNullOrWhiteSpace([string]$definitionsByName[[string]$disciplineName].Effect)) {
                    [string]$definitionsByName[[string]$disciplineName].Effect
                }
                else {
                    'No note available.'
                }

                Write-LWRetroPanelTextRow -Text ("{0}: {1}" -f [string]$disciplineName, $effect) -TextColor 'Gray'
            }
        }
        Write-LWRetroPanelFooter

        Show-LWHelpfulCommandsPanel -ScreenName 'disciplines'
    }
}

function Show-LWNotes {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $notes = @($script:GameState.Character.Notes)

    Write-LWRetroPanelHeader -Title 'Notes' -AccentColor 'DarkCyan'
    if ($notes.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $notes.Count; $i++) {
            Write-LWRetroPanelTextRow -Text ("{0,2}. {1}" -f ($i + 1), [string]$notes[$i]) -TextColor 'Gray'
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Note Summary' -AccentColor 'Cyan'
    Write-LWRetroPanelKeyValueRow -Label 'Total Notes' -Value ([string]$notes.Count) -ValueColor 'White'
    Write-LWRetroPanelFooter

    Show-LWHelpfulCommandsPanel -ScreenName 'notes'
}

function Show-LWRunDifficulty {
    if (-not (Test-LWHasState)) {
        Set-LWScreen -Name 'modes'
        Write-LWWarn 'Difficulty is chosen when a new run begins.'
        return
    }

    Set-LWScreen -Name 'modes'
    Write-LWInfo ("Current difficulty: {0}. Difficulty is locked for this run." -f (Get-LWCurrentDifficulty))
}

function Show-LWRunPermadeath {
    if (-not (Test-LWHasState)) {
        Set-LWScreen -Name 'modes'
        Write-LWWarn 'Permadeath is chosen when a new run begins.'
        return
    }

    Set-LWScreen -Name 'modes'
    Write-LWInfo ("Permadeath is {0} for this run and cannot be changed now." -f $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }))
}

function Show-LWHelp {
    Invoke-LWCoreShowHelpScreen -Context (Get-LWModuleContext)
}

function Show-LWBookCompletionSummary {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$CharacterName,
        [object]$Snapshot = $null,
        [string]$ContinueToBookLabel = ''
    )

    $completedBookLabel = Format-LWBookLabel -BookNumber ([int]$Summary.BookNumber) -IncludePrefix
    $bookAchievements = @($script:GameState.Achievements.Unlocked | Where-Object { [int]$_.BookNumber -eq [int]$Summary.BookNumber } | Select-Object -Last 4)
    $difficulty = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'Difficulty') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.Difficulty)) {
        [string]$Snapshot.Difficulty
    }
    else {
        Get-LWCurrentDifficulty
    }
    $ruleSet = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'RuleSet') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.RuleSet)) {
        [string]$Snapshot.RuleSet
    }
    else {
        [string]$script:GameState.RuleSet
    }
    $runIntegrityState = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'RunIntegrityState') -and -not [string]::IsNullOrWhiteSpace([string]$Snapshot.RunIntegrityState)) {
        [string]$Snapshot.RunIntegrityState
    }
    else {
        [string]$script:GameState.Run.IntegrityState
    }
    $goldCrowns = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'GoldCrowns') -and $null -ne $Snapshot.GoldCrowns) {
        [int]$Snapshot.GoldCrowns
    }
    else {
        [int]$script:GameState.Inventory.GoldCrowns
    }
    $enduranceCurrent = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'EnduranceCurrent') -and $null -ne $Snapshot.EnduranceCurrent) {
        [int]$Snapshot.EnduranceCurrent
    }
    else {
        [int]$script:GameState.Character.EnduranceCurrent
    }
    $enduranceMax = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'EnduranceMax') -and $null -ne $Snapshot.EnduranceMax) {
        [int]$Snapshot.EnduranceMax
    }
    else {
        [int]$script:GameState.Character.EnduranceMax
    }
    $notesCount = if ($null -ne $Snapshot -and (Test-LWPropertyExists -Object $Snapshot -Name 'NotesCount') -and $null -ne $Snapshot.NotesCount) {
        [int]$Snapshot.NotesCount
    }
    else {
        @($script:GameState.Character.Notes).Count
    }
    $uniqueSections = if ((Test-LWPropertyExists -Object $Summary -Name 'UniqueSectionsVisited') -and $null -ne $Summary.UniqueSectionsVisited) {
        [string]$Summary.UniqueSectionsVisited
    }
    else {
        [string]$Summary.SectionsVisited
    }
    $deathCount = if ((Test-LWPropertyExists -Object $Summary -Name 'DeathCount') -and $null -ne $Summary.DeathCount) {
        [string]$Summary.DeathCount
    }
    else {
        '0'
    }

    Write-LWRetroPanelHeader -Title 'Adventure Complete' -AccentColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Character' -LeftValue $CharacterName -RightLabel 'Difficulty' -RightValue $difficulty -LeftColor 'White' -RightColor (Get-LWDifficultyColor -Difficulty $difficulty) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Rule Set' -LeftValue $ruleSet -RightLabel 'Outcome' -RightValue 'Victory' -LeftColor 'Gray' -RightColor 'Green' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    if (-not [string]::IsNullOrWhiteSpace($ContinueToBookLabel)) {
        Write-LWRetroPanelPairRow -LeftLabel 'Completed Book' -LeftValue $completedBookLabel -RightLabel 'Next Book' -RightValue $ContinueToBookLabel -LeftColor 'White' -RightColor 'Cyan' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    }
    else {
        Write-LWRetroPanelKeyValueRow -Label 'Completed Book' -Value $completedBookLabel -ValueColor 'White'
    }
    Write-LWRetroPanelTextRow -Text (Get-LWBookCompletionQuote -BookNumber ([int]$Summary.BookNumber)) -TextColor 'Gray'
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'This Playthrough' -AccentColor 'Cyan'
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Wins' -LeftValue ([string]$Summary.Victories) -RightLabel 'Combat Losses' -RightValue ([string]$Summary.Defeats) -LeftColor 'Green' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Sections Seen' -LeftValue ([string]$Summary.SectionsVisited) -RightLabel 'Unique Sections' -RightValue $uniqueSections -LeftColor 'Gray' -RightColor 'Gray'
    Write-LWRetroPanelPairRow -LeftLabel 'END Lost' -LeftValue ([string]$Summary.EnduranceLost) -RightLabel 'END Gained' -RightValue ([string]$Summary.EnduranceGained) -LeftColor 'Red' -RightColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Gold Gained' -LeftValue ([string]$Summary.GoldGained) -RightLabel 'Gold Spent' -RightValue ([string]$Summary.GoldSpent) -LeftColor 'Yellow' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Deaths' -LeftValue $deathCount -RightLabel 'Rewinds' -RightValue ([string]$Summary.RewindsUsed) -LeftColor 'Red' -RightColor 'Yellow'
    Write-LWRetroPanelPairRow -LeftLabel 'Notes Added' -LeftValue ([string]$notesCount) -RightLabel 'Run Integrity' -RightValue $runIntegrityState -LeftColor 'Gray' -RightColor (Get-LWIntegrityColor -IntegrityState $runIntegrityState)
    Write-LWRetroPanelPairRow -LeftLabel 'Final Gold' -LeftValue ("{0} / 50" -f $goldCrowns) -RightLabel 'Final END' -RightValue ("{0} / {1}" -f $enduranceCurrent, $enduranceMax) -LeftColor 'Yellow' -RightColor (Get-LWEnduranceColor -Current $enduranceCurrent -Max $enduranceMax)
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Achievements Earned' -AccentColor 'Magenta'
    if ($bookAchievements.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none recorded)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $bookAchievements.Count; $i += 2) {
            $leftText = Get-LWAchievementUnlockedDisplayName -Entry $bookAchievements[$i]
            $rightText = if (($i + 1) -lt $bookAchievements.Count) { Get-LWAchievementUnlockedDisplayName -Entry $bookAchievements[$i + 1] } else { '' }
            Write-LWRetroPanelTwoColumnRow -LeftText $leftText -RightText $rightText -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
        }
    }
    Write-LWRetroPanelFooter
}

Export-ModuleMember -Function Write-LWInlineWarn, Write-LWLootNoRoomWarning, Format-LWCompletedBooks, Get-LWBookCompletionQuote, Show-LWSectionGateHints, Get-LWScreenAccentColor, Get-LWScreenBannerStatusText, Get-LWInlineKeyValueText, Write-LWRetroPanelPairRow, New-LWHelpfulCommandRow, Get-LWHelpfulCommandRows, Show-LWHelpfulCommandsPanel, Get-LWCompactRunHistoryLines, Write-LWBanner, Write-LWCommandPromptHint, Write-LWScreenFooterNote, Show-LWDisciplines, Show-LWNotes, Show-LWRunDifficulty, Show-LWRunPermadeath, Show-LWHelp, Show-LWBookCompletionSummary, Get-LWAvailableSectionChoices, Grant-LWSectionGenericChoice, Invoke-LWSectionGoldReward, Invoke-LWSectionPaymentChoice, Invoke-LWSectionChoiceTable

