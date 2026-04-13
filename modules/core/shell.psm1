Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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
    if ($existingCount -gt 8) {
        $existing = @($existing[($existingCount - 8)..($existingCount - 1)])
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
        Write-Host '[INFO] ' -NoNewline -ForegroundColor Cyan
        Write-Host $Message -ForegroundColor Gray
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
        Write-Host '[WARN] ' -NoNewline -ForegroundColor Yellow
        Write-Host $Message -ForegroundColor Gray
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
        Write-Host '[ERROR] ' -NoNewline -ForegroundColor Red
        Write-Host $Message -ForegroundColor Gray
    }
}

function Invoke-LWCoreWriteMessageLine {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

    switch ($Level) {
        'Info' {
            Write-Host '[INFO] ' -NoNewline -ForegroundColor Cyan
            Write-Host $Message -ForegroundColor Gray
        }
        'Warn' {
            Write-Host '[WARN] ' -NoNewline -ForegroundColor Yellow
            Write-Host $Message -ForegroundColor Gray
        }
        'Error' {
            Write-Host '[ERROR] ' -NoNewline -ForegroundColor Red
            Write-Host $Message -ForegroundColor Gray
        }
        default {
            Write-Host $Message -ForegroundColor Gray
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
    $script:LWAchievementDisplayCountsCache = $null
}

function Invoke-LWCoreWarmRuntimeCaches {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    if (-not (Test-LWHasState)) {
        return
    }

    try {
        [void](Get-LWAchievementDisplayCounts)
        [void](Get-LWAchievementDefinitionsForContext -Context 'section' -State $script:GameState)
        [void](Get-LWAchievementDefinitionsForContext -Context 'healing' -State $script:GameState)
        [void](Get-LWAchievementDefinitionsForContext -Context 'sectionmove' -State $script:GameState)
    }
    catch {
    }
}

function Invoke-LWCoreClearScreenHost {
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
            Write-Host "`e[2J`e[H" -NoNewline
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
        'recent' {
            Write-LWRetroPanelHeader -Title 'Recent Unlocks' -AccentColor 'DarkYellow'
            $entries = @(Get-LWAchievementRecentUnlocks -Count 10)
            if ($entries.Count -eq 0) {
                Write-LWRetroPanelTextRow -Text '(none yet)' -TextColor 'DarkGray'
            }
            else {
                foreach ($entry in $entries) {
                    Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray'
                }
            }
            Write-LWRetroPanelFooter
        }
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

    Write-LWBanner
    Write-LWRetroPanelHeader -Title 'Save Catalog' -AccentColor 'Cyan'
    if (@($SaveFiles).Count -gt 0) {
        Show-LWSaveCatalog -SaveFiles $SaveFiles
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
    Show-LWBookCompletionSummary -Summary $screenData.Summary -CharacterName $screenData.CharacterName
    Show-LWHelpfulCommandsPanel -ScreenName 'bookcomplete'
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

    Invoke-LWCoreClearScreenHost

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
        if (Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender') {
            $script:LWUi.NeedsRender = $false
        }
    }

    Invoke-LWCoreWriteNotifications -Context $Context
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
