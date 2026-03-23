#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Load,
    [string]$SaveDir,
    [string]$DataDir
)

$script:LWRootDir = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

if ([string]::IsNullOrWhiteSpace($SaveDir)) {
    $SaveDir = Join-Path $script:LWRootDir 'saves'
}
if ([string]::IsNullOrWhiteSpace($DataDir)) {
    $DataDir = Join-Path $script:LWRootDir 'data'
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:LWAppName = 'Lone Wolf Action Assistant'
$script:LWAppVersion = '0.7.0'
$script:LWStateVersion = '0.5.0'
$script:LastUsedSavePathFile = Join-Path $DataDir 'last-save.txt'
$script:GameState = $null
$script:GameData = $null
$script:LWUi = [pscustomobject]@{
    Enabled       = $false
    CurrentScreen = 'welcome'
    ScreenData    = $null
    Notifications = @()
    IsRendering   = $false
}

function Write-LWInfo {
    param([string]$Message)
    Add-LWNotification -Level 'Info' -Message $Message
    if (-not $script:LWUi.Enabled) {
        Write-Host '[INFO] ' -NoNewline -ForegroundColor Cyan
        Write-Host $Message -ForegroundColor Gray
    }
}

function Write-LWWarn {
    param([string]$Message)
    Add-LWNotification -Level 'Warn' -Message $Message
    if (-not $script:LWUi.Enabled) {
        Write-Host '[WARN] ' -NoNewline -ForegroundColor Yellow
        Write-Host $Message -ForegroundColor Gray
    }
}

function Write-LWError {
    param([string]$Message)
    Add-LWNotification -Level 'Error' -Message $Message
    if (-not $script:LWUi.Enabled) {
        Write-Host '[ERROR] ' -NoNewline -ForegroundColor Red
        Write-Host $Message -ForegroundColor Gray
    }
}

function Write-LWMessageLine {
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

function Add-LWNotification {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

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

    if (@($existing).Count -gt 8) {
        $existing = @($existing[($existing.Count - 8)..($existing.Count - 1)])
    }

    $script:LWUi.Notifications = @($existing)
}

function Clear-LWNotifications {
    $script:LWUi.Notifications = @()
}

function Get-LWDefaultScreen {
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

function Set-LWScreen {
    param(
        [string]$Name = '',
        $Data = $null
    )

    $screenName = if ([string]::IsNullOrWhiteSpace($Name)) { Get-LWDefaultScreen } else { $Name.Trim().ToLowerInvariant() }
    $script:LWUi.CurrentScreen = $screenName
    $script:LWUi.ScreenData = $Data
}

function Write-LWNotifications {
    $notifications = @($script:LWUi.Notifications)
    if ($notifications.Count -eq 0) {
        return
    }

    Write-Host ''
    foreach ($notification in $notifications) {
        Write-LWMessageLine -Level ([string]$notification.Level) -Message ([string]$notification.Message)
    }
}

function Write-LWBannerFooter {
    param(
        [string]$ProductName = $script:LWAppName,
        [switch]$VersionOnly,
        [switch]$ShowHelpLine
    )

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

function Write-LWInventoryBanner {
    $lines = @(
        '        _________________________________',
        '       /___/___/___/___/___/___/___/__/|',
        '      /___/___/___/___/___/___/___/__/||',
        '     |        INVENTORY SCREEN         ||',
        '     |_________________________________||'
    )

    Write-Host ''
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Yellow
    }
    Write-LWBannerFooter
}

function Write-LWCombatBanner {
    $lines = @(
        '      <====||=================  C O M B A T  =================||====>',
        '           ||                                                 ||',
        '           ||               D U E L   B O A R D               ||',
        '           ||_________________________________________________||'
    )

    Write-Host ''
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Red
    }
    Write-LWBannerFooter
}

function Write-LWStatsBanner {
    $lines = @(
        '        _________________________________',
        '       /_____/_____/_____/_____/_____/ /|',
        '      |   _   _   _    S T A T S    _ | |',
        '      |  |_| |_| |_|               |_| | |',
        '      |________________________________|/'
    )

    Write-Host ''
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Cyan
    }
    Write-LWBannerFooter
}

function Write-LWCampaignBanner {
    $lines = @(
        '          ________________________________',
        '         /_____/_____/_____/_____/_____/ /|',
        '        |      C A M P A I G N         | |',
        '        |         R E C O R D          | |',
        '        |______________________________|/'
    )

    Write-Host ''
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor DarkCyan
    }
    Write-LWBannerFooter
}

function Write-LWAchievementsBanner {
    $lines = @(
        '                 _____________',
        '                ''.__==_==_._''',
        '                .-\:      /-.',
        '               | (|:.     |) |',
        '                ''-|:.     |-''',
        '                  \::.    /',
        '                   ''::. .''',
        '                     ) (',
        '           A C H I E V E M E N T S'
    )

    Write-Host ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $color = if ($i -eq ($lines.Count - 1)) { 'Magenta' } else { 'DarkYellow' }
        Write-Host $lines[$i] -ForegroundColor $color
    }
    Write-LWBannerFooter
}

function Write-LWDeathBanner {
    $lines = @(
        ' __      __   _   ___ _____ ___ ___  ',
        ' \ \    / /  /_\ / __|_   _| __|   \ ',
        '  \ \/\/ /  / _ \\__ \ | | | _|| |) |',
        '   \_/\_/  /_/ \_\___/ |_| |___|___/ '
    )

    Write-Host ''
    foreach ($line in $lines) {
        Write-Host $line -ForegroundColor Red
    }
    Write-LWBannerFooter
}

function Show-LWWelcomeScreen {
    param([switch]$NoBanner)

    if (-not $NoBanner) {
        Write-LWBanner
    }
    Write-LWPanelHeader -Title 'Campaign Ready' -AccentColor 'Cyan'
    Write-LWBulletItem -Text 'Use load to open an existing save from the numbered list.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use new to create a fresh Kai character and begin a run.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Type help to see the full command list and aliases.' -TextColor 'Gray'
}

function Show-LWLoadScreen {
    param([object[]]$SaveFiles = @())

    Write-LWBanner
    Write-LWPanelHeader -Title 'Load Save' -AccentColor 'Cyan'
    if (@($SaveFiles).Count -gt 0) {
        Show-LWSaveCatalog -SaveFiles $SaveFiles
    }
    else {
        Write-LWSubtle "No saves found in $SaveDir yet."
    }
}

function Show-LWDisciplineSelectionScreen {
    $screenData = $script:LWUi.ScreenData
    $available = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Available')) { @($screenData.Available) } else { @() }
    $count = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Count')) { [int]$screenData.Count } else { 1 }

    Write-LWBanner
    Write-LWPanelHeader -Title 'Choose Kai Discipline' -AccentColor 'DarkYellow'
    Write-LWBulletItem -Text ("Choose {0} discipline{1} for this character." -f $count, $(if ($count -eq 1) { '' } else { 's' })) -TextColor 'Gray'
    Write-LWSubtle ''

    for ($i = 0; $i -lt $available.Count; $i++) {
        $entry = $available[$i]
        Write-Host ("  {0,2}. " -f ($i + 1)) -NoNewline -ForegroundColor DarkYellow
        Write-Host ([string]$entry.Name) -NoNewline -ForegroundColor Green
        Write-Host (" - {0}" -f [string]$entry.Effect) -ForegroundColor Gray
    }

    Write-Host ''
    Write-LWSubtle ("  Enter {0} number(s) separated by commas." -f $count)
}

function Show-LWCombatScreen {
    $screenData = $script:LWUi.ScreenData

    if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'View') -and [string]$screenData.View -eq 'setup') {
        Write-LWPanelHeader -Title 'Combat Setup' -AccentColor 'DarkRed'

        if ((Test-LWPropertyExists -Object $screenData -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$screenData.EnemyName)) {
            Write-LWKeyValue -Label 'Enemy' -Value ([string]$screenData.EnemyName) -ValueColor 'White'
        }
        if ((Test-LWPropertyExists -Object $screenData -Name 'EnemyCombatSkill') -and $null -ne $screenData.EnemyCombatSkill) {
            Write-LWKeyValue -Label 'Enemy CS' -Value ([string]$screenData.EnemyCombatSkill) -ValueColor 'Gray'
        }
        if ((Test-LWPropertyExists -Object $screenData -Name 'EnemyEndurance') -and $null -ne $screenData.EnemyEndurance) {
            Write-LWKeyValue -Label 'Enemy END' -Value ([string]$screenData.EnemyEndurance) -ValueColor 'Red'
        }

        Write-LWBulletItem -Text 'Answer the prompts below to begin the fight.' -TextColor 'Gray'

        if ((Test-LWPropertyExists -Object $screenData -Name 'Weapons') -and @($screenData.Weapons).Count -gt 1) {
            $defaultIndex = if ((Test-LWPropertyExists -Object $screenData -Name 'DefaultIndex') -and $null -ne $screenData.DefaultIndex) { [int]$screenData.DefaultIndex } else { 1 }
            Write-LWPanelHeader -Title 'Weapon Selection' -AccentColor 'Yellow'
            Write-Host '   0. Bare hands / unarmed' -ForegroundColor DarkGray
            for ($i = 0; $i -lt @($screenData.Weapons).Count; $i++) {
                $suffix = if (($i + 1) -eq $defaultIndex) { ' (default)' } else { '' }
                Write-Host ("  {0,2}. " -f ($i + 1)) -NoNewline -ForegroundColor DarkGray
                Write-Host ("{0}{1}" -f $screenData.Weapons[$i], $suffix) -ForegroundColor Gray
            }
        }
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

    Write-LWPanelHeader -Title 'Combat Status' -AccentColor 'DarkRed'
    Write-LWSubtle '  No active combat.'
}

function Show-LWCombatLogScreen {
    $screenData = $script:LWUi.ScreenData
    $hasEntry = ($null -ne $screenData) -and (Test-LWPropertyExists -Object $screenData -Name 'Entry') -and ($null -ne $screenData.Entry)
    $showAll = ($null -ne $screenData) -and (Test-LWPropertyExists -Object $screenData -Name 'All') -and [bool]$screenData.All
    $bookNumber = if (($null -ne $screenData) -and (Test-LWPropertyExists -Object $screenData -Name 'BookNumber') -and $null -ne $screenData.BookNumber) { [int]$screenData.BookNumber } else { $null }

    if ($showAll -or $null -ne $bookNumber) {
        Show-LWCombatLog -All -BookNumber $bookNumber
        return
    }

    if ($hasEntry) {
        Write-LWCombatLogEntry -Entry $screenData.Entry
        return
    }

    Write-LWPanelHeader -Title 'Combat Log' -AccentColor 'DarkRed'
    Write-LWSubtle '  No combat log available.'
}

function Show-LWModesScreen {
    $screenData = $script:LWUi.ScreenData
    $selectedDifficulty = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Difficulty')) { Get-LWNormalizedDifficultyName -Difficulty ([string]$screenData.Difficulty) } elseif (Test-LWHasState) { Get-LWCurrentDifficulty } else { 'Normal' }
    $selectedPermadeath = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'Permadeath')) { [bool]$screenData.Permadeath } elseif (Test-LWHasState) { [bool](Test-LWPermadeathEnabled) } else { $false }
    $view = if ($null -ne $screenData -and (Test-LWPropertyExists -Object $screenData -Name 'View') -and -not [string]::IsNullOrWhiteSpace([string]$screenData.View)) { [string]$screenData.View } else { 'reference' }
    $poolLabel = Get-LWModeAchievementPoolLabel -State ([pscustomobject]@{ Run = [pscustomobject]@{ Difficulty = $selectedDifficulty; Permadeath = $selectedPermadeath; IntegrityState = 'Clean' } })

    Write-LWPanelHeader -Title 'Run Modes' -AccentColor 'Magenta'
    if (Test-LWHasState) {
        Write-LWKeyValue -Label 'Current Difficulty' -Value (Get-LWCurrentDifficulty) -ValueColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty))
        Write-LWKeyValue -Label 'Permadeath' -Value $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }) -ValueColor $(if (Test-LWPermadeathEnabled) { 'Red' } else { 'Gray' })
        Write-LWKeyValue -Label 'Run Integrity' -Value ([string]$script:GameState.Run.IntegrityState) -ValueColor (Get-LWIntegrityColor -IntegrityState ([string]$script:GameState.Run.IntegrityState))
        Write-LWKeyValue -Label 'Achievement Pool' -Value (Get-LWModeAchievementPoolLabel) -ValueColor 'DarkYellow'
        Write-Host ''
    }

    if ($view -eq 'setup' -or $view -eq 'confirm') {
        Write-LWPanelHeader -Title 'Selected Run Setup' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Difficulty' -Value $selectedDifficulty -ValueColor (Get-LWDifficultyColor -Difficulty $selectedDifficulty)
        Write-LWKeyValue -Label 'Permadeath' -Value $(if ($selectedPermadeath) { 'On' } else { 'Off' }) -ValueColor $(if ($selectedPermadeath) { 'Red' } else { 'Gray' })
        Write-LWKeyValue -Label 'Achievement Pool' -Value $poolLabel -ValueColor 'DarkYellow'
        Write-LWKeyValue -Label 'Locked For Run' -Value 'Yes' -ValueColor 'Yellow'
        Write-Host ''
    }

    Write-LWPanelHeader -Title 'Difficulty Options' -AccentColor 'Cyan'
    $definitions = @(Get-LWDifficultyDefinitions)
    for ($i = 0; $i -lt $definitions.Count; $i++) {
        $entry = $definitions[$i]
        $marker = if ([string]$entry.Name -eq $selectedDifficulty) { '>' } else { ' ' }
        Write-Host ("  {0} [{1}] {2}" -f $marker, ($i + 1), $entry.Name) -ForegroundColor (Get-LWDifficultyColor -Difficulty ([string]$entry.Name))
        Write-LWSubtle ("      {0}" -f [string]$entry.Description)
        Write-LWSubtle ("      {0}" -f [string]$entry.AchievementNote)
    }

    Write-LWPanelHeader -Title 'Run Rules' -AccentColor 'DarkYellow'
    Write-LWBulletItem -Text 'Difficulty is chosen at run start and stays locked for the entire run.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Permadeath can be enabled at run start, cannot be turned off, deletes the save on death, and disables rewind.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Story mode cannot be combined with Permadeath.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'If locked run settings are edited outside the assistant, challenge achievements are disabled for that run.' -TextColor 'Gray'

    if ($view -eq 'reference') {
        Write-Host ''
        Write-LWSubtle '  Use modes anytime to review the rules for each run setting.'
    }
}

function Show-LWDeathScreen {
    if (-not (Test-LWHasState)) {
        Show-LWWelcomeScreen -NoBanner
        return
    }

    $deathState = Get-LWActiveDeathState
    if ($null -eq $deathState) {
        Set-LWScreen -Name (Get-LWDefaultScreen)
        Show-LWSheet
        return
    }

    $bookLabel = Format-LWBookLabel -BookNumber ([int]$deathState.BookNumber) -IncludePrefix
    $rewindsAvailable = Get-LWAvailableRewindCount
    $deathType = if ([string]::IsNullOrWhiteSpace([string]$deathState.Type)) { 'Death' } else { [string]$deathState.Type }
    $causeText = if ([string]::IsNullOrWhiteSpace([string]$deathState.Cause)) { 'A fatal choice ended this path.' } else { [string]$deathState.Cause }

    Write-LWPanelHeader -Title 'You Have Fallen' -AccentColor 'Red'
    Write-LWKeyValue -Label 'Name' -Value $script:GameState.Character.Name -ValueColor 'White'
    Write-LWKeyValue -Label 'Book' -Value $bookLabel -ValueColor 'White'
    Write-LWKeyValue -Label 'Section' -Value ([string]$deathState.Section) -ValueColor 'White'
    Write-LWKeyValue -Label 'Difficulty' -Value (Get-LWCurrentDifficulty) -ValueColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty))
    Write-LWKeyValue -Label 'Permadeath' -Value $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }) -ValueColor $(if (Test-LWPermadeathEnabled) { 'Red' } else { 'Gray' })
    Write-LWKeyValue -Label 'Death Type' -Value $deathType -ValueColor 'Red'
    Write-LWKeyValue -Label 'Cause' -Value $causeText -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Rewinds Available' -Value ([string]$rewindsAvailable) -ValueColor $(if ($rewindsAvailable -gt 0) { 'Yellow' } else { 'DarkGray' })

    Write-LWPanelHeader -Title 'Next Step' -AccentColor 'DarkYellow'
    if (Test-LWPermadeathEnabled) {
        Write-LWBulletItem -Text 'Permadeath claimed this run. The save was deleted and cannot be rewound.' -TextColor 'Gray'
    }
    elseif ($rewindsAvailable -gt 0) {
        Write-LWBulletItem -Text 'Use rewind to return to the previous safe section.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use rewind <n> to step back more than one section.' -TextColor 'Gray'
    }
    else {
        Write-LWBulletItem -Text 'No rewind checkpoints are available for this death.' -TextColor 'Gray'
    }
    Write-LWBulletItem -Text 'You can also use load, new, or quit from this screen.' -TextColor 'Gray'
}

function Show-LWBookCompleteScreen {
    $screenData = $script:LWUi.ScreenData
    if ($null -eq $screenData) {
        Set-LWScreen -Name 'sheet'
        Show-LWSheet
        return
    }

    Write-LWBanner
    Show-LWBookCompletionSummary -Summary $screenData.Summary -CharacterName $screenData.CharacterName
}

function Refresh-LWScreen {
    if (-not $script:LWUi.Enabled) {
        return
    }

    try {
        Clear-Host
    }
    catch {
    }

    $script:LWUi.IsRendering = $true
    try {
        switch ($script:LWUi.CurrentScreen) {
            'sheet' {
                Write-LWBanner
                if (Test-LWHasState) {
                    Show-LWSheet
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'inventory' {
                Write-LWInventoryBanner
                if (Test-LWHasState) {
                    Show-LWInventory
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'combat' {
                Write-LWCombatBanner
                Show-LWCombatScreen
            }
            'combatlog' {
                Write-LWCombatBanner
                Show-LWCombatLogScreen
            }
            'disciplines' {
                Write-LWBanner
                if (Test-LWHasState) {
                    Show-LWDisciplines
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'notes' {
                Write-LWBanner
                if (Test-LWHasState) {
                    Show-LWNotes
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'history' {
                Write-LWBanner
                if (Test-LWHasState) {
                    Show-LWHistory
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'stats' {
                Write-LWStatsBanner
                if (Test-LWHasState) {
                    Show-LWStatsScreen
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'campaign' {
                Write-LWCampaignBanner
                if (Test-LWHasState) {
                    Show-LWCampaignScreen
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'achievements' {
                Write-LWAchievementsBanner
                if (Test-LWHasState) {
                    Show-LWAchievementsScreen
                }
                else {
                    Show-LWWelcomeScreen -NoBanner
                }
            }
            'modes' {
                Write-LWBanner
                Show-LWModesScreen
            }
            'help' {
                Write-LWBanner
                Show-LWHelp
            }
            'load' {
                $saveFiles = if ($null -ne $script:LWUi.ScreenData -and (Test-LWPropertyExists -Object $script:LWUi.ScreenData -Name 'SaveFiles')) { @($script:LWUi.ScreenData.SaveFiles) } else { @() }
                Show-LWLoadScreen -SaveFiles $saveFiles
            }
            'disciplineselect' {
                Show-LWDisciplineSelectionScreen
            }
            'bookcomplete' {
                Show-LWBookCompleteScreen
            }
            'death' {
                Write-LWDeathBanner
                Show-LWDeathScreen
            }
            default {
                Show-LWWelcomeScreen
            }
        }
    }
    finally {
        $script:LWUi.IsRendering = $false
    }

    Write-LWNotifications
}

function Write-LWPanelHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$AccentColor = 'Cyan',
        [int]$Width = 54
    )

    $innerWidth = [Math]::Max(($Width - 4), ($Title.Length + 2))
    $border = '+' + ('-' * ($innerWidth + 2)) + '+'

    Write-Host ''
    Write-Host $border -ForegroundColor DarkGray
    Write-Host '| ' -NoNewline -ForegroundColor DarkGray
    Write-Host $Title.PadRight($innerWidth) -NoNewline -ForegroundColor $AccentColor
    Write-Host ' |' -ForegroundColor DarkGray
    Write-Host $border -ForegroundColor DarkGray
}

function Write-LWKeyValue {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value,
        [string]$ValueColor = 'Gray',
        [string]$LabelColor = 'DarkGray'
    )

    Write-Host ("  {0,-16}: " -f $Label) -NoNewline -ForegroundColor $LabelColor
    Write-Host $Value -ForegroundColor $ValueColor
}

function Write-LWBulletItem {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$TextColor = 'Gray',
        [string]$BulletColor = 'DarkGray',
        [string]$Bullet = '-'
    )

    Write-Host "  $Bullet " -NoNewline -ForegroundColor $BulletColor
    Write-Host $Text -ForegroundColor $TextColor
}

function Write-LWSubtle {
    param([string]$Message)
    Write-Host $Message -ForegroundColor DarkGray
}

function Get-LWEnduranceColor {
    param(
        [int]$Current,
        [int]$Max
    )

    if ($Max -le 0) {
        return 'Gray'
    }

    $ratio = $Current / [double]$Max
    if ($ratio -le 0.25) {
        return 'Red'
    }
    if ($ratio -le 0.60) {
        return 'Yellow'
    }

    return 'Green'
}

function Get-LWOutcomeColor {
    param([string]$Outcome)

    switch ($Outcome) {
        'Victory' { return 'Green' }
        'Knockout' { return 'Green' }
        'Defeat' { return 'Red' }
        'Evaded' { return 'Yellow' }
        'In Progress' { return 'Cyan' }
        'Stopped' { return 'DarkYellow' }
        default { return 'Gray' }
    }
}

function Get-LWCombatRatioColor {
    param([int]$Ratio)

    if ($Ratio -ge 4) {
        return 'Green'
    }
    if ($Ratio -ge 0) {
        return 'Yellow'
    }

    return 'Red'
}

function Get-LWModeColor {
    param([string]$Mode)

    switch ($Mode) {
        'DataFile' { return 'Green' }
        'ManualCRT' { return 'Yellow' }
        default { return 'Gray' }
    }
}

function Get-LWDifficultyColor {
    param([string]$Difficulty)

    switch ([string]$Difficulty) {
        'Story' { return 'Magenta' }
        'Easy' { return 'Green' }
        'Normal' { return 'Cyan' }
        'Hard' { return 'Yellow' }
        'Veteran' { return 'Red' }
        default { return 'Gray' }
    }
}

function Get-LWIntegrityColor {
    param([string]$IntegrityState)

    switch ([string]$IntegrityState) {
        'Clean' { return 'Green' }
        'Tampered' { return 'Red' }
        default { return 'Gray' }
    }
}

function Format-LWSigned {
    param([int]$Value)
    if ($Value -gt 0) {
        return "+$Value"
    }
    return [string]$Value
}

function Format-LWList {
    param([object[]]$Items)
    if (@($Items).Count -gt 0) {
        return (@($Items) -join ', ')
    }
    return '(none)'
}

function Normalize-LWNamedCountEntries {
    param([object[]]$Entries)

    $normalized = @()
    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        $name = if ((Test-LWPropertyExists -Object $entry -Name 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Name)) {
            [string]$entry.Name
        }
        else {
            [string]$entry
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $count = 0
        if ((Test-LWPropertyExists -Object $entry -Name 'Count') -and $null -ne $entry.Count) {
            $count = [int]$entry.Count
        }

        if ($count -lt 0) {
            $count = 0
        }

        $normalized += [pscustomobject]@{
            Name  = $name
            Count = $count
        }
    }

    return @($normalized)
}

function Format-LWNamedCountSummary {
    param([object[]]$Entries)

    $values = @(Normalize-LWNamedCountEntries -Entries $Entries | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    if ($values.Count -eq 0) {
        return '(none)'
    }

    return (@($values | ForEach-Object { "{0} x{1}" -f $_.Name, ([int]$_.Count) }) -join ', ')
}

function Get-LWJsonProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $null
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) {
        return $prop.Value
    }

    return $null
}

function Test-LWPropertyExists {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }

    return ($null -ne $Object.PSObject.Properties[$Name])
}

function Get-LWBookTitle {
    param([int]$BookNumber)

    switch ($BookNumber) {
        1 { return 'Flight from the Dark' }
        2 { return 'Fire on the Water' }
        3 { return 'The Caverns of Kalte' }
        4 { return 'The Chasm of Doom' }
        5 { return 'Shadow on the Sand' }
        6 { return 'The Kingdoms of Terror' }
        7 { return 'Castle Death' }
        8 { return 'The Jungle of Horrors' }
        9 { return 'The Cauldron of Fear' }
        10 { return 'The Dungeons of Torgar' }
        11 { return 'The Prisoners of Time' }
        12 { return 'The Masters of Darkness' }
        13 { return 'The Plague Lords of Ruel' }
        14 { return 'The Captives of Kaag' }
        15 { return 'The Darke Crusade' }
        16 { return 'The Legacy of Vashna' }
        17 { return 'Deathlord of Ixia' }
        18 { return 'Dawn of the Dragons' }
        19 { return 'Wolf''s Bane' }
        20 { return 'The Curse of Naar' }
        21 { return 'Voyage of the Moonstone' }
        22 { return 'The Buccaneers of Shadaki' }
        23 { return 'Mydnight''s Hero' }
        24 { return 'Rune War' }
        25 { return 'Trail of the Wolf' }
        26 { return 'The Fall of Blood Mountain' }
        27 { return 'Vampire Trail' }
        28 { return 'The Hunger of Sejanoz' }
        default { return $null }
    }
}

function Get-LWBookNumberFromTitle {
    param([string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $null
    }

    for ($bookNumber = 1; $bookNumber -le 5; $bookNumber++) {
        if ((Get-LWBookTitle -BookNumber $bookNumber) -ieq $Title) {
            return $bookNumber
        }
    }

    return $null
}

function Format-LWBookLabel {
    param(
        [int]$BookNumber,
        [switch]$IncludePrefix
    )

    $title = Get-LWBookTitle -BookNumber $BookNumber
    if ([string]::IsNullOrWhiteSpace($title)) {
        if ($IncludePrefix) {
            return "Book $BookNumber"
        }
        return [string]$BookNumber
    }

    if ($IncludePrefix) {
        return "Book $BookNumber - $title"
    }

    return "$BookNumber - $title"
}

function Get-LWDifficultyDefinitions {
    return @(
        [pscustomobject]@{
            Name            = 'Story'
            Description     = 'No normal END loss. Story and universal achievements only.'
            AchievementNote = 'Universal + Story achievements'
            PermadeathAllowed = $false
        },
        [pscustomobject]@{
            Name            = 'Easy'
            Description     = 'Incoming END loss is halved.'
            AchievementNote = 'Universal achievements only'
            PermadeathAllowed = $true
        },
        [pscustomobject]@{
            Name            = 'Normal'
            Description     = 'Standard Lone Wolf rules.'
            AchievementNote = 'Universal + Combat achievements'
            PermadeathAllowed = $true
        },
        [pscustomobject]@{
            Name            = 'Hard'
            Description     = 'Sommerswerd bonus halved. Healing capped at 10 END per book.'
            AchievementNote = 'Universal + Combat + Challenge achievements'
            PermadeathAllowed = $true
        },
        [pscustomobject]@{
            Name            = 'Veteran'
            Description     = 'Hard rules plus Sommerswerd only when the text allows it.'
            AchievementNote = 'Universal + Combat + Challenge achievements'
            PermadeathAllowed = $true
        }
    )
}

function Get-LWNormalizedDifficultyName {
    param([string]$Difficulty = '')

    $target = if ([string]::IsNullOrWhiteSpace($Difficulty)) { 'Normal' } else { $Difficulty.Trim() }
    foreach ($entry in @(Get-LWDifficultyDefinitions)) {
        if ([string]$entry.Name -ieq $target) {
            return [string]$entry.Name
        }
    }

    switch ($target.ToLowerInvariant()) {
        'storymode' { return 'Story' }
        'easymode' { return 'Easy' }
        'hardmode' { return 'Hard' }
        default { return 'Normal' }
    }
}

function Get-LWDifficultyDefinition {
    param([string]$Difficulty = '')

    $normalized = Get-LWNormalizedDifficultyName -Difficulty $Difficulty
    foreach ($entry in @(Get-LWDifficultyDefinitions)) {
        if ([string]$entry.Name -eq $normalized) {
            return $entry
        }
    }

    return $null
}

function New-LWRunState {
    param(
        [string]$Difficulty = 'Normal',
        [bool]$Permadeath = $false
    )

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

    $run = if ((Test-LWPropertyExists -Object $State -Name 'Run') -and $null -ne $State.Run) { $State.Run } else { $null }
    $campaign = $null
    $previousState = $script:GameState
    try {
        $script:GameState = $State
        $campaign = Get-LWCampaignSummary
    }
    finally {
        $script:GameState = $previousState
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

    if (-not (Test-LWPropertyExists -Object $State -Name 'RunHistory') -or $null -eq $State.RunHistory) {
        $State | Add-Member -Force -NotePropertyName RunHistory -NotePropertyValue @()
        return
    }

    $State.RunHistory = @($State.RunHistory)
}

function Get-LWRunSignaturePayload {
    param([Parameter(Mandatory = $true)][object]$State)

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
        [string]$State.Run.StartedOn,
        [string]([int]$State.Character.BookNumber),
        [string]([int]$State.CurrentSection),
        ($completedBooks -join ',')
    ) -join '|'
}

function Get-LWStringHash {
    param([string]$Text = '')

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

function Get-LWRunSignature {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Get-LWStringHash -Text (Get-LWRunSignaturePayload -State $State))
}

function Mark-LWRunTampered {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Reason = 'Run settings were modified outside the assistant.'
    )

    Ensure-LWRunState -State $State
    $State.Run.IntegrityState = 'Tampered'
    $State.Run.IntegrityNote = $Reason
}

function Sync-LWRunIntegrityState {
    param([Parameter(Mandatory = $true)][object]$State)

    Ensure-LWRunState -State $State

    if ([string]$State.Run.Difficulty -eq 'Story' -and [bool]$State.Run.Permadeath) {
        $State.Run.Permadeath = $false
        Mark-LWRunTampered -State $State -Reason 'Story mode cannot be combined with Permadeath.'
    }

    $computed = Get-LWRunSignature -State $State
    $stored = [string]$State.Run.Signature

    if ([string]::IsNullOrWhiteSpace($stored)) {
        $State.Run.Signature = $computed
        if ([string]$State.Run.IntegrityState -ne 'Tampered') {
            $State.Run.IntegrityState = 'Clean'
            $State.Run.IntegrityNote = $null
        }
        return
    }

    if ([string]$State.Run.IntegrityState -eq 'Tampered') {
        $State.Run.Signature = $computed
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

    if ($null -eq $State) {
        return $false
    }

    return ((Test-LWPropertyExists -Object $State -Name 'Run') -and $null -ne $State.Run -and (Test-LWPropertyExists -Object $State.Run -Name 'IntegrityState') -and [string]$State.Run.IntegrityState -eq 'Tampered')
}

function Test-LWDifficultyAllowsChallengeAchievements {
    param([object]$State = $script:GameState)

    return (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State))
}

function Get-LWKaiRankTitle {
    param([int]$DisciplineCount)

    if ($DisciplineCount -le 0) {
        return $null
    }

    switch ($DisciplineCount) {
        1 { return 'Novice' }
        2 { return 'Intuite' }
        3 { return 'Doan' }
        4 { return 'Acolyte' }
        5 { return 'Initiate' }
        6 { return 'Aspirant' }
        7 { return 'Guardian' }
        8 { return 'Warmarn / Journeyman' }
        9 { return 'Savant' }
        default { return 'Master' }
    }
}

function Format-LWKaiRankLabel {
    param([int]$DisciplineCount)

    $rankTitle = Get-LWKaiRankTitle -DisciplineCount $DisciplineCount
    if ([string]::IsNullOrWhiteSpace($rankTitle)) {
        return '(unranked)'
    }

    $displayCount = if ($DisciplineCount -gt 10) { '10+' } else { [string]$DisciplineCount }
    return "{0} - {1}" -f $displayCount, $rankTitle
}

function New-LWAchievementProgressFlags {
    return [pscustomobject]@{
        PerfectVictories     = 0
        BrinkVictories       = 0
        AgainstOddsVictories = 0
    }
}

function New-LWAchievementState {
    return [pscustomobject]@{
        Unlocked          = @()
        SeenNotifications = @()
        ProgressFlags     = (New-LWAchievementProgressFlags)
    }
}

function New-LWAchievementDefinition {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Description,
        [bool]$Backfill = $false,
        [string]$ModePool = 'Universal',
        [string[]]$RequiredDifficulty = @(),
        [bool]$RequiresPermadeath = $false
    )

    return [pscustomobject]@{
        Id                 = $Id
        Name               = $Name
        Category           = $Category
        Description        = $Description
        Backfill           = [bool]$Backfill
        ModePool           = $ModePool
        RequiredDifficulty = @($RequiredDifficulty)
        RequiresPermadeath = [bool]$RequiresPermadeath
    }
}

function Get-LWAchievementDefinitions {
    return @(
        (New-LWAchievementDefinition -Id 'first_blood' -Name 'First Blood' -Category 'Combat' -Description 'Win your first combat.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'swift_blade' -Name 'Swift Blade' -Category 'Combat' -Description 'Win a fight in a single round.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'untouchable' -Name 'Untouchable' -Category 'Combat' -Description 'Win a fight without losing any Endurance.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'against_the_odds' -Name 'Against the Odds' -Category 'Combat' -Description 'Win a fight at combat ratio 0 or lower.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'mind_over_matter' -Name 'Mind Over Matter' -Category 'Combat' -Description 'Win a fight using Mindblast.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'giant_slayer' -Name 'Giant-Slayer' -Category 'Combat' -Description 'Defeat an enemy with Combat Skill 18 or higher.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'monster_hunter' -Name 'Monster-Hunter' -Category 'Combat' -Description 'Defeat an enemy with Endurance 30 or higher.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'back_from_the_brink' -Name 'Back From the Brink' -Category 'Combat' -Description 'Win a fight with only 1 Endurance remaining.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'kai_veteran' -Name 'Kai Veteran' -Category 'Combat' -Description 'Win 10 combats in a single run.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'weapon_master' -Name 'Weapon Master' -Category 'Combat' -Description 'Win 10 combats with the same weapon.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'seasoned_fighter' -Name 'Seasoned Fighter' -Category 'Combat' -Description 'Fight 25 total rounds in a single run.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'endurance_duelist' -Name 'Endurance Duelist' -Category 'Combat' -Description 'Survive a fight lasting 5 or more rounds.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'easy_pickings' -Name 'Easy Pickings' -Category 'Combat' -Description 'Win a fight at combat ratio 15 or higher.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'trail_survivor' -Name 'Trail Survivor' -Category 'Survival' -Description 'Eat your first meal.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'hunters_instinct' -Name 'Hunter''s Instinct' -Category 'Survival' -Description 'Have Hunting cover 5 meals.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'herbal_relief' -Name 'Herbal Relief' -Category 'Survival' -Description 'Use your first Laumspur potion.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'second_wind' -Name 'Second Wind' -Category 'Survival' -Description 'Restore 10 Endurance through Healing.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'loaded_purse' -Name 'Loaded Purse' -Category 'Survival' -Description 'Reach 50 Gold Crowns.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'hard_lessons' -Name 'Hard Lessons' -Category 'Survival' -Description 'Suffer your first starvation penalty.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'still_standing' -Name 'Still Standing' -Category 'Survival' -Description 'Survive 3 deaths in a single run.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'deep_draught' -Name 'Deep Draught' -Category 'Survival' -Description 'Use a dose of Concentrated Laumspur.' -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'pathfinder' -Name 'Pathfinder' -Category 'Journey' -Description 'Visit 25 sections in a single book.' -Backfill:$true -ModePool 'Exploration'),
        (New-LWAchievementDefinition -Id 'long_road' -Name 'Long Road' -Category 'Journey' -Description 'Visit 50 sections in a single book.' -Backfill:$true -ModePool 'Exploration'),
        (New-LWAchievementDefinition -Id 'no_quarter' -Name 'No Quarter' -Category 'Journey' -Description 'Win 5 combats in a single book.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'sun_sword' -Name 'Sun-sword' -Category 'Journey' -Description 'Claim the Sommerswerd.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'fully_armed' -Name 'Fully Armed' -Category 'Journey' -Description 'Carry two weapons and a Shield at the same time.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'relic_hunter' -Name 'Relic Hunter' -Category 'Journey' -Description 'Carry five Special Items at the same time.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'book_one_complete' -Name 'Book One Complete' -Category 'Journey' -Description 'Complete Book 1.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'book_two_complete' -Name 'Book Two Complete' -Category 'Journey' -Description 'Complete Book 2.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'grave_bane' -Name 'Grave-Bane' -Category 'Combat' -Description 'Defeat an undead enemy with the Sommerswerd.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'true_path' -Name 'True Path' -Category 'Legend' -Description 'Complete a book without using rewind.' -ModePool 'Exploration'),
        (New-LWAchievementDefinition -Id 'unbroken' -Name 'Unbroken' -Category 'Legend' -Description 'Complete a book without dying.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'wolf_of_sommerlund' -Name 'Wolf of Sommerlund' -Category 'Legend' -Description 'Complete a book without a combat defeat.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'iron_wolf' -Name 'Iron Wolf' -Category 'Legend' -Description 'Complete a book with no deaths, no rewinds, and no manual recovery shortcuts.' -ModePool 'Challenge' -RequiredDifficulty @('Hard', 'Veteran')),
        (New-LWAchievementDefinition -Id 'gentle_path' -Name 'A Gentle Path' -Category 'Story' -Description 'Complete a book in Story mode.' -ModePool 'Story' -RequiredDifficulty @('Story')),
        (New-LWAchievementDefinition -Id 'all_too_easy' -Name 'All Too Easy' -Category 'Story' -Description 'Win a combat in Story mode.' -ModePool 'Story' -RequiredDifficulty @('Story')),
        (New-LWAchievementDefinition -Id 'bedtime_tale' -Name 'Bedtime Tale' -Category 'Story' -Description 'Finish Book 1 in Story mode.' -ModePool 'Story' -RequiredDifficulty @('Story')),
        (New-LWAchievementDefinition -Id 'hard_road' -Name 'Hard Road' -Category 'Legend' -Description 'Complete a book on Hard.' -ModePool 'Challenge' -RequiredDifficulty @('Hard')),
        (New-LWAchievementDefinition -Id 'lean_healing' -Name 'Lean Healing' -Category 'Legend' -Description 'Complete a Hard book after pushing Healing to its 10 END cap.' -ModePool 'Challenge' -RequiredDifficulty @('Hard')),
        (New-LWAchievementDefinition -Id 'veteran_of_sommerlund' -Name 'Veteran of Sommerlund' -Category 'Legend' -Description 'Complete a book on Veteran.' -ModePool 'Challenge' -RequiredDifficulty @('Veteran')),
        (New-LWAchievementDefinition -Id 'by_the_text' -Name 'By the Text' -Category 'Legend' -Description 'Complete a Veteran book without ever using unauthorized Sommerswerd power.' -ModePool 'Challenge' -RequiredDifficulty @('Veteran')),
        (New-LWAchievementDefinition -Id 'only_one_life' -Name 'Only One Life' -Category 'Legend' -Description 'Complete a book with Permadeath enabled.' -ModePool 'Challenge' -RequiresPermadeath:$true),
        (New-LWAchievementDefinition -Id 'mortal_wolf' -Name 'Mortal Wolf' -Category 'Legend' -Description 'Complete a Hard or Veteran book with Permadeath enabled.' -ModePool 'Challenge' -RequiredDifficulty @('Hard', 'Veteran') -RequiresPermadeath:$true)
    )
}

function Get-LWPhaseTwoAchievementPlans {
    return @(
        [pscustomobject]@{ Name = 'Eyes of the Kai'; Description = 'Hidden story achievement for discovering secret sections with the right discipline or clue.' },
        [pscustomobject]@{ Name = 'Kai Specialist'; Description = 'Discipline-specific achievement for solving a situation in a uniquely Kai way.' },
        [pscustomobject]@{ Name = 'Rune-Reader'; Description = 'Hidden story achievement for following a clue chain across books and sections without losing the thread.' }
    )
}

function Ensure-LWAchievementState {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State -Name 'Achievements') -or $null -eq $State.Achievements) {
        $State | Add-Member -Force -NotePropertyName Achievements -NotePropertyValue (New-LWAchievementState)
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'Unlocked') -or $null -eq $State.Achievements.Unlocked) {
        $State.Achievements | Add-Member -Force -NotePropertyName Unlocked -NotePropertyValue @()
    }
    else {
        $State.Achievements.Unlocked = @($State.Achievements.Unlocked)
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'SeenNotifications') -or $null -eq $State.Achievements.SeenNotifications) {
        $State.Achievements | Add-Member -Force -NotePropertyName SeenNotifications -NotePropertyValue @()
    }
    else {
        $State.Achievements.SeenNotifications = @($State.Achievements.SeenNotifications | ForEach-Object { [string]$_ })
    }

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'ProgressFlags') -or $null -eq $State.Achievements.ProgressFlags) {
        $State.Achievements | Add-Member -Force -NotePropertyName ProgressFlags -NotePropertyValue (New-LWAchievementProgressFlags)
    }

    foreach ($propertyName in @('PerfectVictories', 'BrinkVictories', 'AgainstOddsVictories')) {
        if (-not (Test-LWPropertyExists -Object $State.Achievements.ProgressFlags -Name $propertyName) -or $null -eq $State.Achievements.ProgressFlags.$propertyName) {
            $State.Achievements.ProgressFlags | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue 0
        }
    }
}

function Set-LWCombatEntryBookMetadata {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [Nullable[int]]$BookNumber = $null,
        [string]$BookTitle = ''
    )

    $resolvedBookNumber = $BookNumber
    if ($null -eq $resolvedBookNumber -or [int]$resolvedBookNumber -le 0) {
        $resolvedBookNumber = Get-LWBookNumberFromTitle -Title $BookTitle
    }

    $resolvedBookTitle = $BookTitle
    if ([string]::IsNullOrWhiteSpace($resolvedBookTitle) -and $null -ne $resolvedBookNumber -and [int]$resolvedBookNumber -gt 0) {
        $resolvedBookTitle = Get-LWBookTitle -BookNumber ([int]$resolvedBookNumber)
    }

    if (-not (Test-LWPropertyExists -Object $Entry -Name 'BookNumber')) {
        $Entry | Add-Member -NotePropertyName BookNumber -NotePropertyValue $resolvedBookNumber
    }
    else {
        $Entry.BookNumber = $resolvedBookNumber
    }

    if (-not (Test-LWPropertyExists -Object $Entry -Name 'BookTitle')) {
        $Entry | Add-Member -NotePropertyName BookTitle -NotePropertyValue $resolvedBookTitle
    }
    else {
        $Entry.BookTitle = $resolvedBookTitle
    }
}

function Get-LWCurrentBookResolvedCombatCount {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State -Name 'CurrentBookStats') -or $null -eq $State.CurrentBookStats) {
        return 0
    }

    $stats = $State.CurrentBookStats
    $resolved = 0
    foreach ($propertyName in @('Victories', 'Defeats', 'Evades')) {
        if ((Test-LWPropertyExists -Object $stats -Name $propertyName) -and $null -ne $stats.$propertyName) {
            $resolved += [int]$stats.$propertyName
        }
    }

    return $resolved
}

function New-LWDeathState {
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
    return ($null -ne (Get-LWActiveDeathState))
}

function Clear-LWDeathState {
    if ($null -eq $script:GameState) {
        return
    }

    $script:GameState.DeathState = (New-LWDeathState)
}

function Normalize-LWSectionCheckpoints {
    param([object[]]$Checkpoints = @())

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

    return [pscustomobject]@{
        Version                = $State.Version
        RuleSet                = $State.RuleSet
        CurrentSection         = $State.CurrentSection
        SectionHadCombat       = $State.SectionHadCombat
        SectionHealingResolved = $State.SectionHealingResolved
        Character              = $State.Character
        Inventory              = $State.Inventory
        Combat                 = $State.Combat
        History                = $State.History
        BookHistory            = $State.BookHistory
        CurrentBookStats       = $State.CurrentBookStats
        EquipmentBonuses       = $State.EquipmentBonuses
    }
}

function Get-LWCheckpointSnapshotJson {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Get-LWCheckpointSnapshotObject -State $State) | ConvertTo-Json -Depth 20 -Compress)
}

function New-LWSectionCheckpoint {
    param([Parameter(Mandatory = $true)][object]$State)

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
    if (-not (Test-LWHasState) -or (Test-LWDeathActive)) {
        return
    }

    if (@($script:GameState.SectionCheckpoints).Count -eq 0) {
        Reset-LWSectionCheckpoints -SeedCurrentSection
    }
}

function Save-LWCurrentSectionCheckpoint {
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
    if (-not (Test-LWHasState) -or (Test-LWDeathActive)) {
        return
    }

    Ensure-LWCurrentSectionCheckpoint
    Save-LWCurrentSectionCheckpoint
}

function Get-LWBookDeathCount {
    param([int]$BookNumber)

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

function Get-LWAvailableRewindCount {
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
}

function Invoke-LWInstantDeath {
    param([string]$Cause = '')

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

function Invoke-LWFatalEnduranceCheck {
    param([string]$Cause = 'Endurance has fallen to zero.')

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

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }
    if (-not (Test-LWDeathActive)) {
        Write-LWWarn 'rewind is only available after a death.'
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
}

function Format-LWCompletedBooks {
    param([object[]]$Books)

    $books = @($Books)
    if ($books.Count -eq 0) {
        return '(none)'
    }

    return (@($books | ForEach-Object { Format-LWBookLabel -BookNumber ([int]$_) }) -join ', ')
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

function New-LWBookStats {
    param(
        [int]$BookNumber,
        [Nullable[int]]$StartSection = $null,
        [bool]$PartialTracking = $false
    )

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

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Default
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }

    return ($raw | ConvertFrom-Json)
}

function Get-LWLastUsedSavePath {
    if (-not (Test-Path -LiteralPath $script:LastUsedSavePathFile)) {
        return $null
    }

    $path = Get-Content -LiteralPath $script:LastUsedSavePathFile -Raw
    if ([string]::IsNullOrWhiteSpace($path)) {
        return $null
    }

    $trimmed = $path.Trim()
    if (-not (Test-Path -LiteralPath $trimmed)) {
        return $null
    }

    return $trimmed
}

function Set-LWLastUsedSavePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $resolvedPath = $Path.Trim()
    try {
        $resolvedPath = [System.IO.Path]::GetFullPath($resolvedPath)
    }
    catch {
    }

    $directory = Split-Path -Parent $script:LastUsedSavePathFile
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    Set-Content -LiteralPath $script:LastUsedSavePathFile -Value $resolvedPath -Encoding UTF8
}

function Get-LWPreferredSavePath {
    if ((Test-LWHasState) -and -not [string]::IsNullOrWhiteSpace($script:GameState.Settings.SavePath) -and (Test-Path -LiteralPath $script:GameState.Settings.SavePath)) {
        return $script:GameState.Settings.SavePath
    }

    return (Get-LWLastUsedSavePath)
}

function Get-LWChainmailItemNames {
    return @('Chainmail Waistcoat', 'Chainmail Wastecoat', 'Chainmail')
}

function Get-LWShieldItemNames {
    return @('Shield')
}

function Get-LWSilverHelmItemNames {
    return @('Silver Helm')
}

function Get-LWSommerswerdItemNames {
    return @('Sommerswerd')
}

function Get-LWSommerswerdWeaponskillNames {
    return @('Short Sword', 'Sword', 'Broadsword')
}

function Get-LWBoneSwordWeaponNames {
    return @('Bone Sword', 'Bone Sword +1(K)', 'Bone Sowrd', 'Bone Sowrd +1(K)')
}

function Get-LWNonEdgeKnockoutWeaponNames {
    return @('Warhammer', 'Quarterstaff', 'Mace')
}

function Get-LWHealingPotionItemNames {
    return @('Healing Potion', 'Laumspur Potion', 'Potion of Laumspur', 'Laumspur')
}

function Get-LWConcentratedHealingPotionItemNames {
    return @('Concentrated Laumspur', 'Concentrated Laumspur Potion', 'Potion of Concentrated Laumspur')
}

function Get-LWAletherPotionItemNames {
    return @('Alether', 'Alether Potion', 'Potion of Alether')
}

function Test-LWConcentratedHealingPotionName {
    param([string]$Name)

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWConcentratedHealingPotionItemNames) -Target $Name)))
}

function Get-LWStateInventoryItems {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Type = ''
    )

    switch ($Type.Trim().ToLowerInvariant()) {
        'weapon' {
            return @($State.Inventory.Weapons)
        }
        'backpack' {
            return @($State.Inventory.BackpackItems)
        }
        'special' {
            return @($State.Inventory.SpecialItems)
        }
        default {
            return @($State.Inventory.Weapons) + @($State.Inventory.BackpackItems) + @($State.Inventory.SpecialItems)
        }
    }
}

function Get-LWMatchingStateInventoryItem {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [string]$Type = ''
    )

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

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names $Names -Type $Type)))
}

function Get-LWStateChainmailEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWChainmailItemNames)) {
        return 4
    }

    return 0
}

function Get-LWStateShieldCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames)) {
        return 2
    }

    return 0
}

function Get-LWStateSilverHelmCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSilverHelmItemNames) -Type 'special') {
        return 2
    }

    return 0
}

function Test-LWWeaponIsBoneSword {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBoneSwordWeaponNames) -Target $Weapon)))
}

function Test-LWStateHasBoneSword {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBoneSwordWeaponNames) -Type 'weapon')
}

function Test-LWStateIsInKalte {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -eq 3)
}

function Test-LWCombatKnockoutAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -ge 3)
}

function Test-LWCombatAletherAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -ge 3)
}

function Test-LWWeaponIsNonEdgeForKnockout {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWNonEdgeKnockoutWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsSommerswerd {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSommerswerdItemNames) -Target $Weapon)))
}

function Test-LWStateHasSommerswerd {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatSommerswerdAvailable -State $State) -and (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special'))
}

function Test-LWStateHasSommerswerdWeaponskill {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill')) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSommerswerdWeaponskillNames) -Target ([string]$State.Character.WeaponskillWeapon))))
}

function Get-LWStateCombatWeapons {
    param([Parameter(Mandatory = $true)][object]$State)

    $choices = @($State.Inventory.Weapons)
    $sommerswerd = $null
    if (Test-LWCombatSommerswerdAvailable -State $State) {
        $sommerswerd = Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special'
    }
    if (-not [string]::IsNullOrWhiteSpace($sommerswerd) -and [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $choices -Target $sommerswerd))) {
        $choices = @($choices) + @([string]$sommerswerd)
    }

    return @($choices)
}

function Get-LWStateBoneSwordCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (-not (Test-LWWeaponIsBoneSword -Weapon $activeWeapon)) {
        return 0
    }

    if (Test-LWStateIsInKalte -State $State) {
        return 1
    }

    return 0
}

function Get-LWCombatKnockoutCombatSkillPenalty {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    if (-not [bool]$State.Combat.AttemptKnockout) {
        return 0
    }

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if ([string]::IsNullOrWhiteSpace($activeWeapon)) {
        return 0
    }
    if (Test-LWWeaponIsNonEdgeForKnockout -Weapon $activeWeapon) {
        return 0
    }

    return 2
}

function Test-LWCombatSommerswerdAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -ge 2)
}

function Get-LWStateSommerswerdCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$Suppressed
    )

    if ($Suppressed -or -not (Test-LWStateHasSommerswerd -State $State)) {
        return 0
    }

    $baseBonus = 8
    if (Test-LWStateHasSommerswerdWeaponskill -State $State) {
        $baseBonus = 10
    }

    return (Get-LWModeAdjustedSommerswerdBonus -BaseBonus $baseBonus -State $State)
}

function Get-LWStateSommerswerdFallbackWeaponskillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWCombatSommerswerdAvailable -State $State)) {
        return 0
    }

    if (Test-LWStateHasSommerswerdWeaponskill -State $State) {
        return 2
    }

    return 0
}

function Test-LWCombatUsesSommerswerd {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatSommerswerdAvailable -State $State) -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$State.Combat.EquippedWeapon)))
}

function Test-LWCombatSommerswerdPowerActive {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatUsesSommerswerd -State $State) -and -not [bool]$State.Combat.SommerswerdSuppressed)
}

function Test-LWCombatSommerswerdUndeadDoubleDamageActive {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatSommerswerdPowerActive -State $State) -and [bool]$State.Combat.EnemyIsUndead)
}

function Test-LWCombatUsesMindforce {
    param([Parameter(Mandatory = $true)][object]$State)

    return [bool]$State.Combat.EnemyUsesMindforce
}

function Test-LWCombatMindforceBlockedByMindshield {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Test-LWCombatUsesMindforce -State $State) -and (Test-LWStateHasDiscipline -State $State -Name 'Mindshield'))
}

function Ensure-LWEquipmentBonusState {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State -Name 'EquipmentBonuses') -or $null -eq $State.EquipmentBonuses) {
        $State | Add-Member -Force -NotePropertyName EquipmentBonuses -NotePropertyValue ([pscustomobject]@{
                ChainmailEndurance = 0
            })
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'ChainmailEndurance') -or $null -eq $State.EquipmentBonuses.ChainmailEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName ChainmailEndurance -NotePropertyValue 0
    }
}

function Sync-LWStateEquipmentBonuses {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$WriteMessages
    )

    Ensure-LWEquipmentBonusState -State $State

    $desiredChainmail = Get-LWStateChainmailEnduranceBonus -State $State
    $appliedChainmail = [int]$State.EquipmentBonuses.ChainmailEndurance
    $delta = $desiredChainmail - $appliedChainmail

    if ($delta -eq 0) {
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

    if ($WriteMessages) {
        $direction = if ($delta -gt 0) { 'applied' } else { 'removed' }
        Write-LWInfo ("Chainmail Waistcoat bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $delta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
    }
}

function Get-LWRandomDigit {
    return (Get-Random -Minimum 0 -Maximum 10)
}

function Read-LWYesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [bool]$Default = $true
    )

    while ($true) {
        Refresh-LWScreen
        $suffix = if ($Default) { '[Y/n]' } else { '[y/N]' }
        $raw = Read-Host "$Prompt $suffix"

        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $Default
        }

        switch ($raw.Trim().ToLowerInvariant()) {
            'y' { return $true }
            'yes' { return $true }
            'n' { return $false }
            'no' { return $false }
            default { Write-LWWarn 'Please enter y or n.' }
        }
    }
}

function Read-LWInt {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [Nullable[int]]$Default = $null,
        [Nullable[int]]$Min = $null,
        [Nullable[int]]$Max = $null
    )

    while ($true) {
        Refresh-LWScreen
        $label = if ($null -ne $Default) { "$Prompt [$Default]" } else { $Prompt }
        $raw = Read-Host $label

        if ([string]::IsNullOrWhiteSpace($raw) -and $null -ne $Default) {
            return [int]$Default
        }

        $value = 0
        if (-not [int]::TryParse($raw, [ref]$value)) {
            Write-LWWarn 'Please enter a whole number.'
            continue
        }

        if ($null -ne $Min -and $value -lt $Min) {
            Write-LWWarn "Value must be at least $Min."
            continue
        }

        if ($null -ne $Max -and $value -gt $Max) {
            Write-LWWarn "Value must be at most $Max."
            continue
        }

        return $value
    }
}

function Read-LWText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [string]$Default = ''
    )

    Refresh-LWScreen
    $label = if ([string]::IsNullOrWhiteSpace($Default)) { $Prompt } else { "$Prompt [$Default]" }
    $raw = Read-Host $label
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $Default
    }
    return $raw.Trim()
}

function New-LWCombatState {
    return [pscustomobject]@{
        Active                    = $false
        EnemyName                 = $null
        EnemyCombatSkill          = 0
        EnemyEnduranceCurrent     = 0
        EnemyEnduranceMax         = 0
        EnemyIsUndead             = $false
        EnemyUsesMindforce        = $false
        EnemyImmuneToMindblast    = $false
        UseMindblast              = $false
        AletherCombatSkillBonus   = 0
        AttemptKnockout           = $false
        CanEvade                  = $false
        EquippedWeapon            = $null
        SommerswerdSuppressed     = $false
        PlayerCombatSkillModifier = 0
        EnemyCombatSkillModifier  = 0
        Log                       = @()
    }
}

function New-LWDefaultState {
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
            WeaponskillWeapon = $null
            LastCombatWeapon = $null
            CompletedBooks   = @()
            Notes            = @()
        }
        Inventory         = [pscustomobject]@{
            Weapons       = @()
            BackpackItems = @()
            SpecialItems  = @()
            GoldCrowns    = 0
        }
        Combat            = (New-LWCombatState)
        History           = @()
        BookHistory       = @()
        RunHistory        = @()
        SectionCheckpoints = @()
        DeathState        = (New-LWDeathState)
        DeathHistory      = @()
        Run              = (New-LWRunState)
        CurrentBookStats  = (New-LWBookStats -BookNumber 1 -StartSection 1)
        Achievements      = (New-LWAchievementState)
        EquipmentBonuses  = [pscustomobject]@{
            ChainmailEndurance = 0
        }
        Settings          = [pscustomobject]@{
            CombatMode = 'ManualCRT'
            SavePath   = $null
            AutoSave   = $false
            DataDir    = $DataDir
        }
    }
}

function Initialize-LWData {
    if (-not (Test-Path -LiteralPath $DataDir)) {
        New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $SaveDir)) {
        New-Item -ItemType Directory -Path $SaveDir -Force | Out-Null
    }

    $disciplinesPath = Join-Path $DataDir 'kai-disciplines.json'
    $weaponskillPath = Join-Path $DataDir 'weaponskill-map.json'
    $crtPath = Join-Path $DataDir 'crt.json'

    $script:GameData = [pscustomobject]@{
        KaiDisciplines = @(Import-LWJson -Path $disciplinesPath -Default @())
        WeaponskillMap = (Import-LWJson -Path $weaponskillPath -Default $null)
        CRT            = (Import-LWJson -Path $crtPath -Default $null)
    }
}

function Normalize-LWState {
    param([Parameter(Mandatory = $true)][object]$State)

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
    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'BackpackItems') -or $null -eq $State.Inventory.BackpackItems) {
        $State.Inventory.BackpackItems = @()
    }
    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'SpecialItems') -or $null -eq $State.Inventory.SpecialItems) {
        $State.Inventory.SpecialItems = @()
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
    if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'AletherCombatSkillBonus') -or $null -eq $State.Combat.AletherCombatSkillBonus) {
        $State.Combat | Add-Member -Force -NotePropertyName AletherCombatSkillBonus -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'AttemptKnockout') -or $null -eq $State.Combat.AttemptKnockout) {
        $State.Combat | Add-Member -Force -NotePropertyName AttemptKnockout -NotePropertyValue $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'SommerswerdSuppressed') -or $null -eq $State.Combat.SommerswerdSuppressed) {
        $State.Combat | Add-Member -Force -NotePropertyName SommerswerdSuppressed -NotePropertyValue $false
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

function Test-LWHasState {
    return ($script:GameState -and $script:GameState.Character -and -not [string]::IsNullOrWhiteSpace($script:GameState.Character.Name))
}

function Ensure-LWCurrentBookStats {
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

    $script:GameState.CurrentBookStats = (New-LWBookStats -BookNumber $BookNumber -StartSection $StartSection -PartialTracking $PartialTracking)
    return $script:GameState.CurrentBookStats
}

function Add-LWBookSectionVisit {
    param([int]$Section)

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

    [void](Sync-LWAchievements -Context 'section')
}

function Add-LWBookEnduranceDelta {
    param([int]$Delta)

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

function Add-LWBookGoldDelta {
    param([int]$Delta)

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

function Add-LWBookNamedCount {
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Delta = 1
    )

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
                Count = [int]$entry.Count + $Delta
            }
            $matched = $true
        }
        else {
            $updatedEntries += [pscustomobject]@{
                Name  = [string]$entry.Name
                Count = [int]$entry.Count
            }
        }
    }

    if (-not $matched) {
        $updatedEntries += [pscustomobject]@{
            Name  = $Name.Trim()
            Count = $Delta
        }
    }

    $stats.$PropertyName = @(Normalize-LWNamedCountEntries -Entries $updatedEntries)
}

function Register-LWMealConsumed {
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.MealsEaten = [int]$stats.MealsEaten + 1
    [void](Sync-LWAchievements -Context 'meal')
}

function Register-LWMealCoveredByHunting {
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.MealsCoveredByHunting = [int]$stats.MealsCoveredByHunting + 1
    [void](Sync-LWAchievements -Context 'hunting')
}

function Register-LWStarvationPenalty {
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

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Count -le 0) {
        return
    }

    $stats.RewindsUsed = [int]$stats.RewindsUsed + $Count
    [void](Sync-LWAchievements -Context 'rewind')
}

function Register-LWManualRecoveryShortcut {
    param([int]$Count = 1)

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Count -le 0) {
        return
    }

    $stats.ManualRecoveryShortcuts = [int]$stats.ManualRecoveryShortcuts + $Count
    [void](Sync-LWAchievements -Context 'recovery')
}

function Register-LWHealingRestore {
    param([int]$Amount)

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats -or $Amount -le 0) {
        return
    }

    $stats.HealingTriggers = [int]$stats.HealingTriggers + 1
    $stats.HealingEnduranceRestored = [int]$stats.HealingEnduranceRestored + $Amount
    [void](Sync-LWAchievements -Context 'healing')
}

function Get-LWModeAchievementPools {
    param([object]$State = $script:GameState)

    $difficulty = Get-LWCurrentDifficulty -State $State
    switch ($difficulty) {
        'Story' { return @('Universal', 'Story') }
        'Easy' { return @('Universal') }
        'Hard' { return @('Universal', 'Combat', 'Exploration', 'Challenge') }
        'Veteran' { return @('Universal', 'Combat', 'Exploration', 'Challenge') }
        default { return @('Universal', 'Combat', 'Exploration') }
    }
}

function Get-LWModeAchievementPoolLabel {
    param([object]$State = $script:GameState)

    return ((Get-LWModeAchievementPools -State $State) -join ' + ')
}

function Resolve-LWGameplayEnduranceLoss {
    param(
        [int]$Loss,
        [string]$Source = 'damage',
        [object]$State = $script:GameState
    )

    $requestedLoss = [Math]::Max(0, [int]$Loss)
    if ($requestedLoss -le 0) {
        return [pscustomobject]@{
            RequestedLoss = 0
            AppliedLoss   = 0
            PreventedLoss = 0
            Note          = $null
        }
    }

    $difficulty = Get-LWCurrentDifficulty -State $State
    switch ($difficulty) {
        'Story' {
            return [pscustomobject]@{
                RequestedLoss = $requestedLoss
                AppliedLoss   = 0
                PreventedLoss = $requestedLoss
                Note          = 'Story mode prevents END loss from normal gameplay damage.'
            }
        }
        'Easy' {
            $appliedLoss = [int][Math]::Ceiling($requestedLoss / 2.0)
            $prevented = $requestedLoss - $appliedLoss
            return [pscustomobject]@{
                RequestedLoss = $requestedLoss
                AppliedLoss   = $appliedLoss
                PreventedLoss = $prevented
                Note          = $(if ($prevented -gt 0) { "Easy mode halves END loss: $appliedLoss instead of $requestedLoss." } else { $null })
            }
        }
        default {
            return [pscustomobject]@{
                RequestedLoss = $requestedLoss
                AppliedLoss   = $requestedLoss
                PreventedLoss = 0
                Note          = $null
            }
        }
    }
}

function Get-LWHealingRestorationCap {
    param([object]$State = $script:GameState)

    if (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State)) {
        return 10
    }

    return $null
}

function Get-LWRemainingHealingRestoration {
    param([object]$State = $script:GameState)

    $cap = Get-LWHealingRestorationCap -State $State
    if ($null -eq $cap) {
        return $null
    }

    $stats = Ensure-LWCurrentBookStats
    $used = if ($null -ne $stats -and (Test-LWPropertyExists -Object $stats -Name 'HealingEnduranceRestored')) { [int]$stats.HealingEnduranceRestored } else { 0 }
    return [Math]::Max(0, ([int]$cap - $used))
}

function Resolve-LWHealingRestoreAmount {
    param(
        [int]$RequestedAmount,
        [object]$State = $script:GameState
    )

    $requested = [Math]::Max(0, [int]$RequestedAmount)
    $remaining = Get-LWRemainingHealingRestoration -State $State
    if ($null -eq $remaining) {
        return [pscustomobject]@{
            RequestedAmount = $requested
            AppliedAmount   = $requested
            Note            = $null
        }
    }

    $applied = [Math]::Min($requested, [int]$remaining)
    $note = $null
    if ($applied -lt $requested) {
        if ($remaining -le 0) {
            $note = 'Healing is capped at 10 END restored per book in this mode.'
        }
        else {
            $note = "Healing is capped in this mode: $applied END can be restored now ($remaining remaining this book)."
        }
    }

    return [pscustomobject]@{
        RequestedAmount = $requested
        AppliedAmount   = $applied
        Note            = $note
    }
}

function Get-LWModeAdjustedSommerswerdBonus {
    param(
        [int]$BaseBonus,
        [object]$State = $script:GameState
    )

    $normalized = [Math]::Max(0, [int]$BaseBonus)
    if (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State)) {
        return [int][Math]::Floor($normalized / 2)
    }

    return $normalized
}

function Register-LWCombatStarted {
    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.CombatCount = [int]$stats.CombatCount + 1
    if ($script:GameState.Combat.UseMindblast) {
        $stats.MindblastCombats = [int]$stats.MindblastCombats + 1
    }

    if ([int]$script:GameState.Combat.EnemyCombatSkill -gt [int]$stats.HighestEnemyCombatSkillFaced) {
        $stats.HighestEnemyCombatSkillFaced = [int]$script:GameState.Combat.EnemyCombatSkill
    }
    if ([int]$script:GameState.Combat.EnemyEnduranceMax -gt [int]$stats.HighestEnemyEnduranceFaced) {
        $stats.HighestEnemyEnduranceFaced = [int]$script:GameState.Combat.EnemyEnduranceMax
    }

    $weaponName = Get-LWCombatDisplayWeapon -Weapon ([string]$script:GameState.Combat.EquippedWeapon)
    Add-LWBookNamedCount -PropertyName 'WeaponUsage' -Name $weaponName
}

function Register-LWCombatResolved {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $stats = Ensure-LWCurrentBookStats
    if ($null -eq $stats) {
        return
    }

    $stats.RoundsFought = [int]$stats.RoundsFought + [int]$Summary.RoundCount

    switch ([string]$Summary.Outcome) {
        'Victory' {
            $stats.Victories = [int]$stats.Victories + 1
            if ((Test-LWPropertyExists -Object $Summary -Name 'Mindblast') -and $Summary.Mindblast) {
                $stats.MindblastVictories = [int]$stats.MindblastVictories + 1
            }
            $weaponName = Get-LWCombatDisplayWeapon -Weapon ([string]$Summary.Weapon)
            Add-LWBookNamedCount -PropertyName 'WeaponVictories' -Name $weaponName

            $summaryRounds = if ((Test-LWPropertyExists -Object $Summary -Name 'RoundCount') -and $null -ne $Summary.RoundCount) { [int]$Summary.RoundCount } else { 0 }
            $summaryRatio = if ((Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') -and $null -ne $Summary.CombatRatio) { [int]$Summary.CombatRatio } else { $null }
            if ($null -ne $Summary.EnemyCombatSkill -and [int]$Summary.EnemyCombatSkill -gt [int]$stats.HighestEnemyCombatSkillDefeated) {
                $stats.HighestEnemyCombatSkillDefeated = [int]$Summary.EnemyCombatSkill
            }
            if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyEnduranceMax') -and $null -ne $Summary.EnemyEnduranceMax -and [int]$Summary.EnemyEnduranceMax -gt [int]$stats.HighestEnemyEnduranceDefeated) {
                $stats.HighestEnemyEnduranceDefeated = [int]$Summary.EnemyEnduranceMax
            }

            if ($summaryRounds -gt 0 -and ([int]$stats.FastestVictoryRounds -eq 0 -or $summaryRounds -lt [int]$stats.FastestVictoryRounds)) {
                $stats.FastestVictoryRounds = $summaryRounds
                $stats.FastestVictoryEnemyName = [string]$Summary.EnemyName
            }

            if ($null -ne $summaryRatio -and ($null -eq $stats.EasiestVictoryRatio -or [int]$summaryRatio -gt [int]$stats.EasiestVictoryRatio)) {
                $stats.EasiestVictoryRatio = [int]$summaryRatio
                $stats.EasiestVictoryEnemyName = [string]$Summary.EnemyName
            }
        }
        'Knockout' {
            $stats.Victories = [int]$stats.Victories + 1
            if ((Test-LWPropertyExists -Object $Summary -Name 'Mindblast') -and $Summary.Mindblast) {
                $stats.MindblastVictories = [int]$stats.MindblastVictories + 1
            }
            $weaponName = Get-LWCombatDisplayWeapon -Weapon ([string]$Summary.Weapon)
            Add-LWBookNamedCount -PropertyName 'WeaponVictories' -Name $weaponName
            if ($null -ne $Summary.EnemyCombatSkill -and [int]$Summary.EnemyCombatSkill -gt [int]$stats.HighestEnemyCombatSkillDefeated) {
                $stats.HighestEnemyCombatSkillDefeated = [int]$Summary.EnemyCombatSkill
            }
            if ((Test-LWPropertyExists -Object $Summary -Name 'EnemyEnduranceMax') -and $null -ne $Summary.EnemyEnduranceMax -and [int]$Summary.EnemyEnduranceMax -gt [int]$stats.HighestEnemyEnduranceDefeated) {
                $stats.HighestEnemyEnduranceDefeated = [int]$Summary.EnemyEnduranceMax
            }
            $summaryRounds = if ($null -ne $Summary.RoundCount) { [int]$Summary.RoundCount } else { 0 }
            if ($summaryRounds -gt 0 -and ([int]$stats.FastestVictoryRounds -eq 0 -or $summaryRounds -lt [int]$stats.FastestVictoryRounds)) {
                $stats.FastestVictoryRounds = $summaryRounds
                $stats.FastestVictoryEnemyName = [string]$Summary.EnemyName
            }
            $summaryRatio = $null
            if ((Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') -and $null -ne $Summary.CombatRatio) {
                $summaryRatio = [int]$Summary.CombatRatio
            }
            if ($null -ne $summaryRatio -and ($null -eq $stats.EasiestVictoryRatio -or [int]$summaryRatio -gt [int]$stats.EasiestVictoryRatio)) {
                $stats.EasiestVictoryRatio = [int]$summaryRatio
                $stats.EasiestVictoryEnemyName = [string]$Summary.EnemyName
            }
        }
        'Defeat' {
            $stats.Defeats = [int]$stats.Defeats + 1
        }
        'Evaded' {
            $stats.Evades = [int]$stats.Evades + 1
        }
    }

    $roundCount = if ($null -ne $Summary.RoundCount) { [int]$Summary.RoundCount } else { 0 }
    if ($roundCount -gt [int]$stats.LongestFightRounds) {
        $stats.LongestFightRounds = $roundCount
        $stats.LongestFightEnemyName = [string]$Summary.EnemyName
    }

    [void](Sync-LWAchievements -Context 'combat' -Data $Summary)
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

function Show-LWBookCompletionSummary {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$CharacterName
    )

    $completedBookLabel = Format-LWBookLabel -BookNumber ([int]$Summary.BookNumber) -IncludePrefix
    $completedBookName = if ([string]::IsNullOrWhiteSpace([string]$Summary.BookTitle)) { $completedBookLabel } else { [string]$Summary.BookTitle }
    $highestCS = if ([int]$Summary.HighestEnemyCombatSkillDefeated -gt 0) { [string]$Summary.HighestEnemyCombatSkillDefeated } else { '(none)' }
    $highestEnd = if ([int]$Summary.HighestEnemyEnduranceDefeated -gt 0) { [string]$Summary.HighestEnemyEnduranceDefeated } else { '(none)' }
    $highestCSFaced = if ((Test-LWPropertyExists -Object $Summary -Name 'HighestEnemyCombatSkillFaced') -and [int]$Summary.HighestEnemyCombatSkillFaced -gt 0) { [string]$Summary.HighestEnemyCombatSkillFaced } else { '(none)' }
    $highestEndFaced = if ((Test-LWPropertyExists -Object $Summary -Name 'HighestEnemyEnduranceFaced') -and [int]$Summary.HighestEnemyEnduranceFaced -gt 0) { [string]$Summary.HighestEnemyEnduranceFaced } else { '(none)' }
    $startSection = if ($null -ne $Summary.StartSection) { [string]$Summary.StartSection } else { '(not tracked)' }
    $endSection = if ($null -ne $Summary.LastSection) { [string]$Summary.LastSection } else { '(not tracked)' }
    $successfulPath = if ((Test-LWPropertyExists -Object $Summary -Name 'SuccessfulPathSections') -and $null -ne $Summary.SuccessfulPathSections -and [int]$Summary.SuccessfulPathSections -gt 0) { [string]$Summary.SuccessfulPathSections } else { '(not tracked)' }
    $deathCount = if ((Test-LWPropertyExists -Object $Summary -Name 'DeathCount') -and $null -ne $Summary.DeathCount) { [string]$Summary.DeathCount } else { '0' }
    $weaponUsage = if (Test-LWPropertyExists -Object $Summary -Name 'WeaponUsage') { Format-LWNamedCountSummary -Entries @($Summary.WeaponUsage) } else { '(none)' }
    $weaponVictories = if (Test-LWPropertyExists -Object $Summary -Name 'WeaponVictories') { Format-LWNamedCountSummary -Entries @($Summary.WeaponVictories) } else { '(none)' }
    $fastestVictory = if ((Test-LWPropertyExists -Object $Summary -Name 'FastestVictoryRounds') -and [int]$Summary.FastestVictoryRounds -gt 0) { "{0} ({1} round{2})" -f $Summary.FastestVictoryEnemyName, $Summary.FastestVictoryRounds, $(if ([int]$Summary.FastestVictoryRounds -eq 1) { '' } else { 's' }) } else { '(none)' }
    $easiestVictory = if ((Test-LWPropertyExists -Object $Summary -Name 'EasiestVictoryRatio') -and $null -ne $Summary.EasiestVictoryRatio) { "{0} (ratio {1})" -f $Summary.EasiestVictoryEnemyName, [int]$Summary.EasiestVictoryRatio } else { '(none)' }
    $longestFight = if ((Test-LWPropertyExists -Object $Summary -Name 'LongestFightRounds') -and [int]$Summary.LongestFightRounds -gt 0) { "{0} ({1} round{2})" -f $Summary.LongestFightEnemyName, $Summary.LongestFightRounds, $(if ([int]$Summary.LongestFightRounds -eq 1) { '' } else { 's' }) } else { '(none)' }

    Write-LWPanelHeader -Title 'Book Complete' -AccentColor 'Green'
    Write-Host '  ' -NoNewline -ForegroundColor DarkGray
    Write-Host ("Good work, {0}. You have completed {1}." -f $CharacterName, $completedBookName) -ForegroundColor White
    Write-LWKeyValue -Label 'Book' -Value $completedBookLabel -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Winning Path' -Value $successfulPath -ValueColor 'White'
    Write-LWKeyValue -Label 'Sections Visited' -Value ([string]$Summary.SectionsVisited) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Unique Sections' -Value ([string]$Summary.UniqueSectionsVisited) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Start Section' -Value $startSection -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Last Section' -Value $endSection -ValueColor 'Gray'
    Write-LWKeyValue -Label 'END Lost' -Value ([string]$Summary.EnduranceLost) -ValueColor 'Red'
    Write-LWKeyValue -Label 'END Gained' -Value ([string]$Summary.EnduranceGained) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Meals Eaten' -Value ([string]$Summary.MealsEaten) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Hunting Meals' -Value ([string]$Summary.MealsCoveredByHunting) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Starvation Hits' -Value ([string]$Summary.StarvationPenalties) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Potions Used' -Value ([string]$Summary.PotionsUsed) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Strong Potions' -Value ([string]$Summary.ConcentratedPotionsUsed) -ValueColor 'DarkGreen'
    Write-LWKeyValue -Label 'Potion END' -Value ([string]$Summary.PotionEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Rewinds Used' -Value ([string]$Summary.RewindsUsed) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Recovery Shortcuts' -Value ([string]$Summary.ManualRecoveryShortcuts) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Gold Gained' -Value ([string]$Summary.GoldGained) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Gold Spent' -Value ([string]$Summary.GoldSpent) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Healing Uses' -Value ([string]$Summary.HealingTriggers) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Healing END' -Value ([string]$Summary.HealingEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Fights' -Value ([string]$Summary.CombatCount) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Victories' -Value ([string]$Summary.Victories) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Evades' -Value ([string]$Summary.Evades) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Defeats' -Value ([string]$Summary.Defeats) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Deaths' -Value $deathCount -ValueColor 'Red'
    Write-LWKeyValue -Label 'Instant Deaths' -Value ([string]$Summary.InstantDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Combat Deaths' -Value ([string]$Summary.CombatDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Rounds Fought' -Value ([string]$Summary.RoundsFought) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Mindblast Fights' -Value ([string]$Summary.MindblastCombats) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Mindblast Wins' -Value ([string]$Summary.MindblastVictories) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Weapons Used' -Value $weaponUsage -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Weapon Wins' -Value $weaponVictories -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Highest CS Faced' -Value $highestCSFaced -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest END Faced' -Value $highestEndFaced -ValueColor 'Red'
    Write-LWKeyValue -Label 'Highest CS Defeated' -Value $highestCS -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest END Defeated' -Value $highestEnd -ValueColor 'Red'
    Write-LWKeyValue -Label 'Fastest Victory' -Value $fastestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Easiest Victory' -Value $easiestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Longest Fight' -Value $longestFight -ValueColor 'Yellow'

    if ($Summary.PartialTracking) {
        Write-Host ''
        Write-LWMessageLine -Level 'Warn' -Message 'Book stats were initialized from an older save, so some totals may be partial.'
    }

    Write-LWPanelHeader -Title 'Kai Wisdom' -AccentColor 'DarkYellow'
    Write-LWBulletItem -Text $Summary.CompletionQuote -TextColor 'Gray'
}

function Test-LWDiscipline {
    param([Parameter(Mandatory = $true)][string]$Name)
    return (@($script:GameState.Character.Disciplines) -contains $Name)
}

function Test-LWStateHasDiscipline {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return (@($State.Character.Disciplines) -contains $Name)
}

function Get-LWMatchingValue {
    param(
        [object[]]$Values = @(),
        [string]$Target
    )

    foreach ($value in @($Values)) {
        if ($value -ieq $Target) {
            return [string]$value
        }
    }

    return $null
}

function Get-LWPreferredCombatWeapon {
    param([Parameter(Mandatory = $true)][object]$State)

    $weapons = @(Get-LWStateCombatWeapons -State $State)
    if ($weapons.Count -eq 0) {
        return $null
    }

    $lastWeapon = Get-LWMatchingValue -Values $weapons -Target ([string]$State.Character.LastCombatWeapon)
    if (-not [string]::IsNullOrWhiteSpace($lastWeapon)) {
        return $lastWeapon
    }

    $sommerswerd = Get-LWMatchingValue -Values $weapons -Target 'Sommerswerd'
    if (-not [string]::IsNullOrWhiteSpace($sommerswerd)) {
        return $sommerswerd
    }

    $weaponskillWeapon = Get-LWMatchingValue -Values $weapons -Target ([string]$State.Character.WeaponskillWeapon)
    if (-not [string]::IsNullOrWhiteSpace($weaponskillWeapon)) {
        return $weaponskillWeapon
    }

    return [string]$weapons[0]
}

function Get-LWCombatStartArguments {
    param([string[]]$Arguments = @())

    if ($null -eq $Arguments) {
        $Arguments = @()
    }
    else {
        $Arguments = @($Arguments)
    }

    if ($Arguments.Count -lt 3) {
        return $null
    }

    $enemyCombatSkill = 0
    $enemyEndurance = 0
    if (-not [int]::TryParse($Arguments[$Arguments.Count - 2], [ref]$enemyCombatSkill)) {
        return $null
    }
    if (-not [int]::TryParse($Arguments[$Arguments.Count - 1], [ref]$enemyEndurance)) {
        return $null
    }

    $enemyName = (@($Arguments[0..($Arguments.Count - 3)]) -join ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($enemyName)) {
        return $null
    }

    return [pscustomobject]@{
        EnemyName        = $enemyName
        EnemyCombatSkill = $enemyCombatSkill
        EnemyEndurance   = $enemyEndurance
    }
}

function Get-LWCRTValidation {
    $requiredRatios = -11..11
    $messages = @()
    $missingEntries = @()
    $invalidEntries = @()
    $usableEntryCount = 0
    $ratioKeys = @()

    if ($null -eq $script:GameData.CRT) {
        return [pscustomobject]@{
            Present          = $false
            IsComplete       = $false
            UsableEntryCount = 0
            RatioKeys        = @()
            MissingEntries   = @('crt.json not found')
            InvalidEntries   = @()
            Messages         = @('No data/crt.json found.')
        }
    }

    foreach ($property in $script:GameData.CRT.PSObject.Properties) {
        $ratioValue = 0
        if ([int]::TryParse($property.Name, [ref]$ratioValue)) {
            $ratioKeys += $ratioValue
        }
    }

    foreach ($ratio in $requiredRatios) {
        $ratioNode = Get-LWJsonProperty -Object $script:GameData.CRT -Name ([string]$ratio)
        if ($null -eq $ratioNode) {
            foreach ($roll in 0..9) {
                $missingEntries += "$ratio/$roll"
            }
            continue
        }

        foreach ($roll in 0..9) {
            $entry = Get-LWJsonProperty -Object $ratioNode -Name ([string]$roll)
            if ($null -eq $entry) {
                $missingEntries += "$ratio/$roll"
                continue
            }

            $enemyLossRaw = Get-LWJsonProperty -Object $entry -Name 'EnemyLoss'
            $playerLossRaw = Get-LWJsonProperty -Object $entry -Name 'PlayerLoss'
            $enemyValid = $false
            $playerValid = $false

            if ([string]$enemyLossRaw -eq 'K') {
                $enemyValid = $true
            }
            else {
                $enemyLoss = 0
                $enemyValid = [int]::TryParse([string]$enemyLossRaw, [ref]$enemyLoss)
            }

            if ([string]$playerLossRaw -eq 'K') {
                $playerValid = $true
            }
            else {
                $playerLoss = 0
                $playerValid = [int]::TryParse([string]$playerLossRaw, [ref]$playerLoss)
            }

            if (-not $enemyValid -or -not $playerValid) {
                $invalidEntries += "$ratio/$roll"
                continue
            }

            $usableEntryCount += 1
        }
    }

    if ($missingEntries.Count -gt 0) {
        $messages += "CRT data is missing $($missingEntries.Count) result(s). Missing results will fall back to manual entry."
    }
    if ($invalidEntries.Count -gt 0) {
        $messages += "CRT data has $($invalidEntries.Count) invalid result(s). Invalid results will fall back to manual entry."
    }
    if ($usableEntryCount -eq 0) {
        $messages += 'CRT data does not contain any usable results yet.'
    }

    return [pscustomobject]@{
        Present          = $true
        IsComplete       = ($missingEntries.Count -eq 0 -and $invalidEntries.Count -eq 0 -and $usableEntryCount -gt 0)
        UsableEntryCount = $usableEntryCount
        RatioKeys        = @($ratioKeys | Sort-Object -Unique)
        MissingEntries   = @($missingEntries)
        InvalidEntries   = @($invalidEntries)
        Messages         = @($messages)
    }
}

function Get-LWDefaultCombatMode {
    $validation = Get-LWCRTValidation
    if ($validation.IsComplete) {
        return 'DataFile'
    }

    return 'ManualCRT'
}

function Convert-LWCRTLossValue {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][int]$CurrentEndurance
    )

    if ([string]$Value -eq 'K') {
        return $CurrentEndurance
    }

    $loss = 0
    if ([int]::TryParse([string]$Value, [ref]$loss)) {
        return $loss
    }

    return $null
}

function Get-LWWeaponskillWeapon {
    param([Parameter(Mandatory = $true)][int]$Roll)

    if ($null -eq $script:GameData.WeaponskillMap) {
        return $null
    }

    return (Get-LWJsonProperty -Object $script:GameData.WeaponskillMap -Name ([string]$Roll))
}

function Select-LWKaiDisciplines {
    param(
        [int]$Count = 5,
        [string[]]$Exclude = @()
    )

    $available = @($script:GameData.KaiDisciplines | Where-Object { $Exclude -notcontains $_.Name })
    if ($available.Count -lt $Count) {
        throw "Not enough disciplines available to choose $Count item(s)."
    }

    $previousScreen = $script:LWUi.CurrentScreen
    $previousData = $script:LWUi.ScreenData
    if ($script:LWUi.Enabled) {
        Set-LWScreen -Name 'disciplineselect' -Data ([pscustomobject]@{
                Available = @($available)
                Count     = $Count
            })
    }

    try {
        while ($true) {
            Refresh-LWScreen
            $raw = Read-Host "Enter $Count number(s) separated by commas"
            if ([string]::IsNullOrWhiteSpace($raw)) {
                Write-LWWarn 'Please choose at least one discipline.'
                continue
            }

            $pieces = @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
            $numbers = @()
            $valid = $true

            foreach ($piece in $pieces) {
                $number = 0
                if (-not [int]::TryParse($piece, [ref]$number)) {
                    $valid = $false
                    break
                }
                if ($number -lt 1 -or $number -gt $available.Count) {
                    $valid = $false
                    break
                }
                if ($numbers -contains $number) {
                    $valid = $false
                    break
                }
                $numbers += $number
            }

            if (-not $valid -or $numbers.Count -ne $Count) {
                Write-LWWarn "Enter exactly $Count unique number(s) from the list."
                continue
            }

            $selected = foreach ($number in $numbers) {
                $available[$number - 1].Name
            }
            return @($selected)
        }
    }
    finally {
        if ($script:LWUi.Enabled) {
            Set-LWScreen -Name $previousScreen -Data $previousData
        }
    }
}

function Add-LWKaiDiscipline {
    param([string]$Name = '')

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $owned = @($script:GameState.Character.Disciplines)
    $availableNames = @($script:GameData.KaiDisciplines | ForEach-Object { [string]$_.Name })
    $remainingNames = @($availableNames | Where-Object { $owned -notcontains $_ })

    if ($remainingNames.Count -eq 0) {
        Write-LWWarn 'All Kai Disciplines are already owned.'
        return
    }

    $disciplineName = $null
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $selection = Select-LWKaiDisciplines -Count 1 -Exclude $owned
        if (@($selection).Count -gt 0) {
            $disciplineName = [string]$selection[0]
        }
    }
    else {
        $disciplineName = Get-LWMatchingValue -Values $remainingNames -Target $Name.Trim()
        if ([string]::IsNullOrWhiteSpace($disciplineName)) {
            Write-LWWarn ("Unknown or already owned discipline: {0}" -f $Name.Trim())
            return
        }
    }

    if ([string]::IsNullOrWhiteSpace($disciplineName)) {
        Write-LWWarn 'No discipline was selected.'
        return
    }

    $script:GameState.Character.Disciplines = @($owned + $disciplineName)
    Set-LWScreen -Name 'disciplines'
    Write-LWInfo "Added discipline: $disciplineName."

    if ($disciplineName -eq 'Weaponskill' -and [string]::IsNullOrWhiteSpace($script:GameState.Character.WeaponskillWeapon)) {
        $weaponRoll = Get-LWRandomDigit
        $weaponName = Get-LWWeaponskillWeapon -Roll $weaponRoll
        $script:GameState.Character.WeaponskillWeapon = $weaponName
        Write-LWInfo "Weaponskill roll: $weaponRoll -> $weaponName"
    }

    Invoke-LWMaybeAutosave
}

function Get-LWSafeFileName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return 'lonewolf-save'
    }
    return ($Name -replace '[^A-Za-z0-9_-]', '_')
}

function Write-LWBanner {
    $titleLines = @(
        ' _                    __        __    _  __      _      _  ',
        '| |    ___  _ __   ___\ \      / /__ | |/ _|    / \    / \ ',
        '| |   / _ \| ''_ \ / _ \\ \ /\ / / _ \| | |_    / _ \  / _ \\',
        '| |__| (_) | | | |  __/\ V  V / (_) | |  _|   / ___ \/ ___ \\',
        '|_____\___/|_| |_|\___| \_/\_/ \___/|_|_|   /_/   \_/_/   \_\\'
    )

    Write-Host ''
    for ($i = 0; $i -lt $titleLines.Count; $i++) {
        $titleColor = if ($i -in @(0, 1, 4)) { 'Cyan' } else { 'White' }
        Write-Host ("  {0}" -f $titleLines[$i]) -ForegroundColor $titleColor
    }
    Write-Host ("               {0}" -f $script:LWAppName) -ForegroundColor DarkYellow
    Write-LWBannerFooter -VersionOnly -ShowHelpLine
}

function Show-LWDisciplines {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Write-LWPanelHeader -Title 'Kai Disciplines' -AccentColor 'DarkYellow'
    foreach ($discipline in @($script:GameState.Character.Disciplines)) {
        if ($discipline -eq 'Weaponskill' -and -not [string]::IsNullOrWhiteSpace($script:GameState.Character.WeaponskillWeapon)) {
            Write-LWBulletItem -Text "Weaponskill ($($script:GameState.Character.WeaponskillWeapon))" -TextColor 'Green'
        }
        else {
            Write-LWBulletItem -Text $discipline -TextColor 'Green'
        }
    }
}

function Show-LWNotes {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Write-LWPanelHeader -Title 'Notes' -AccentColor 'DarkCyan'
    if (@($script:GameState.Character.Notes).Count -eq 0) {
        Write-LWSubtle '  (none)'
        Write-LWSubtle '  Use note <text> to add a quick note.'
        Write-LWSubtle '  Use note remove <n> to delete by number.'
        return
    }

    for ($i = 0; $i -lt @($script:GameState.Character.Notes).Count; $i++) {
        Write-LWBulletItem -Bullet ($i + 1).ToString() -Text $script:GameState.Character.Notes[$i] -TextColor 'Gray' -BulletColor 'DarkCyan'
    }
    Write-Host ''
    Write-LWSubtle '  Use note <text> to add a quick note.'
    Write-LWSubtle '  Use note remove <n> to delete by number.'
}

function Get-LWCombatEntryBookNumber {
    param([Parameter(Mandatory = $true)][object]$Entry)

    if ((Test-LWPropertyExists -Object $Entry -Name 'BookNumber') -and $null -ne $Entry.BookNumber) {
        return [int]$Entry.BookNumber
    }

    return 0
}

function Get-LWCombatEntryBookTitle {
    param([Parameter(Mandatory = $true)][object]$Entry)

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

    return ('{0}|{1}' -f (Get-LWCombatEntryBookNumber -Entry $Entry), (Get-LWCombatEntryBookTitle -Entry $Entry))
}

function Write-LWCombatArchiveBookHeader {
    param([Parameter(Mandatory = $true)][object]$Entry)

    Write-Host ''
    Write-Host ("  {0}" -f (Get-LWCombatEntryBookLabel -Entry $Entry)) -ForegroundColor DarkYellow
    Write-LWSubtle '  ------------------------------------------------------------'
}

function Show-LWHistory {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Write-LWPanelHeader -Title 'Combat History' -AccentColor 'DarkRed'
    if (@($script:GameState.History).Count -eq 0) {
        Write-LWSubtle '  (none)'
        return
    }

    $currentBookKey = $null
    for ($i = 0; $i -lt @($script:GameState.History).Count; $i++) {
        $entry = $script:GameState.History[$i]
        $bookKey = Get-LWCombatEntryBookKey -Entry $entry
        if ($bookKey -ne $currentBookKey) {
            Write-LWCombatArchiveBookHeader -Entry $entry
            $currentBookKey = $bookKey
        }

        Write-Host ("  {0,2}. " -f ($i + 1)) -NoNewline -ForegroundColor DarkRed
        Write-Host $entry.EnemyName -NoNewline -ForegroundColor Gray
        Write-Host '  ' -NoNewline
        Write-Host $entry.Outcome -NoNewline -ForegroundColor (Get-LWOutcomeColor -Outcome $entry.Outcome)
        Write-Host ("  rounds: {0}" -f $entry.RoundCount) -ForegroundColor DarkGray
    }
}

function Get-LWLiveBookStatsSummary {
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

    $bookLabel = Format-LWBookLabel -BookNumber ([int]$Summary.BookNumber) -IncludePrefix
    $deathCount = if ((Test-LWPropertyExists -Object $Summary -Name 'DeathCount') -and $null -ne $Summary.DeathCount) { [string]$Summary.DeathCount } else { '0' }

    Write-LWPanelHeader -Title 'Current Book Stats' -AccentColor 'Cyan'
    Write-LWKeyValue -Label 'Book' -Value $bookLabel -ValueColor 'White'
    Write-LWKeyValue -Label 'Current Section' -Value ([string]$script:GameState.CurrentSection) -ValueColor 'White'
    Write-LWKeyValue -Label 'Winning Path' -Value ([string]$Summary.SuccessfulPathSections) -ValueColor 'White'
    Write-LWKeyValue -Label 'Sections Visited' -Value ([string]$Summary.SectionsVisited) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Unique Sections' -Value ([string]$Summary.UniqueSectionsVisited) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Fights' -Value ([string]$Summary.CombatCount) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Victories' -Value ([string]$Summary.Victories) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Defeats' -Value ([string]$Summary.Defeats) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Deaths' -Value $deathCount -ValueColor 'Red'
    Write-LWKeyValue -Label 'END Lost' -Value ([string]$Summary.EnduranceLost) -ValueColor 'Red'
    Write-LWKeyValue -Label 'END Gained' -Value ([string]$Summary.EnduranceGained) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Gold Gained' -Value ([string]$Summary.GoldGained) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Gold Spent' -Value ([string]$Summary.GoldSpent) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Meals Eaten' -Value ([string]$Summary.MealsEaten) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Potions Used' -Value ([string]$Summary.PotionsUsed) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Strong Potions' -Value ([string]$Summary.ConcentratedPotionsUsed) -ValueColor 'DarkGreen'
    Write-LWKeyValue -Label 'Potion END' -Value ([string]$Summary.PotionEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Rewinds Used' -Value ([string]$Summary.RewindsUsed) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Recovery Shortcuts' -Value ([string]$Summary.ManualRecoveryShortcuts) -ValueColor 'Yellow'
    Write-Host ''
    Write-LWSubtle '  Use stats combat for fight-focused numbers.'
    Write-LWSubtle '  Use stats survival for resources, healing, and death split.'
}

function Show-LWStatsCombat {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $highestCSFaced = if ([int]$Summary.HighestEnemyCombatSkillFaced -gt 0) { [string]$Summary.HighestEnemyCombatSkillFaced } else { '(none)' }
    $highestEndFaced = if ([int]$Summary.HighestEnemyEnduranceFaced -gt 0) { [string]$Summary.HighestEnemyEnduranceFaced } else { '(none)' }
    $highestCSDefeated = if ([int]$Summary.HighestEnemyCombatSkillDefeated -gt 0) { [string]$Summary.HighestEnemyCombatSkillDefeated } else { '(none)' }
    $highestEndDefeated = if ([int]$Summary.HighestEnemyEnduranceDefeated -gt 0) { [string]$Summary.HighestEnemyEnduranceDefeated } else { '(none)' }
    $weaponUsage = Format-LWNamedCountSummary -Entries @($Summary.WeaponUsage)
    $weaponVictories = Format-LWNamedCountSummary -Entries @($Summary.WeaponVictories)
    $fastestVictory = if ([int]$Summary.FastestVictoryRounds -gt 0) { "{0} ({1} round{2})" -f $Summary.FastestVictoryEnemyName, $Summary.FastestVictoryRounds, $(if ([int]$Summary.FastestVictoryRounds -eq 1) { '' } else { 's' }) } else { '(none)' }
    $easiestVictory = if ($null -ne $Summary.EasiestVictoryRatio) { "{0} (ratio {1})" -f $Summary.EasiestVictoryEnemyName, [int]$Summary.EasiestVictoryRatio } else { '(none)' }
    $longestFight = if ([int]$Summary.LongestFightRounds -gt 0) { "{0} ({1} round{2})" -f $Summary.LongestFightEnemyName, $Summary.LongestFightRounds, $(if ([int]$Summary.LongestFightRounds -eq 1) { '' } else { 's' }) } else { '(none)' }

    Write-LWPanelHeader -Title 'Combat Stats' -AccentColor 'DarkRed'
    Write-LWKeyValue -Label 'Fights' -Value ([string]$Summary.CombatCount) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Victories' -Value ([string]$Summary.Victories) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Defeats' -Value ([string]$Summary.Defeats) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Evades' -Value ([string]$Summary.Evades) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Rounds Fought' -Value ([string]$Summary.RoundsFought) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Mindblast Fights' -Value ([string]$Summary.MindblastCombats) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Mindblast Wins' -Value ([string]$Summary.MindblastVictories) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest CS Faced' -Value $highestCSFaced -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest END Faced' -Value $highestEndFaced -ValueColor 'Red'
    Write-LWKeyValue -Label 'Highest CS Defeated' -Value $highestCSDefeated -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest END Defeated' -Value $highestEndDefeated -ValueColor 'Red'
    Write-LWKeyValue -Label 'Fastest Victory' -Value $fastestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Easiest Victory' -Value $easiestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Longest Fight' -Value $longestFight -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Weapons Used' -Value $weaponUsage -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Weapon Wins' -Value $weaponVictories -ValueColor 'Gray'
}

function Show-LWStatsSurvival {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $deathCount = if ((Test-LWPropertyExists -Object $Summary -Name 'DeathCount') -and $null -ne $Summary.DeathCount) { [string]$Summary.DeathCount } else { '0' }

    Write-LWPanelHeader -Title 'Survival Stats' -AccentColor 'DarkYellow'
    Write-LWKeyValue -Label 'END Lost' -Value ([string]$Summary.EnduranceLost) -ValueColor 'Red'
    Write-LWKeyValue -Label 'END Gained' -Value ([string]$Summary.EnduranceGained) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Healing Uses' -Value ([string]$Summary.HealingTriggers) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Healing END' -Value ([string]$Summary.HealingEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Gold Gained' -Value ([string]$Summary.GoldGained) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Gold Spent' -Value ([string]$Summary.GoldSpent) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Meals Eaten' -Value ([string]$Summary.MealsEaten) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Hunting Meals' -Value ([string]$Summary.MealsCoveredByHunting) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Starvation Hits' -Value ([string]$Summary.StarvationPenalties) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Potions Used' -Value ([string]$Summary.PotionsUsed) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Strong Potions' -Value ([string]$Summary.ConcentratedPotionsUsed) -ValueColor 'DarkGreen'
    Write-LWKeyValue -Label 'Potion END' -Value ([string]$Summary.PotionEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Rewinds Used' -Value ([string]$Summary.RewindsUsed) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Recovery Shortcuts' -Value ([string]$Summary.ManualRecoveryShortcuts) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Deaths' -Value $deathCount -ValueColor 'Red'
    Write-LWKeyValue -Label 'Instant Deaths' -Value ([string]$Summary.InstantDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Combat Deaths' -Value ([string]$Summary.CombatDeaths) -ValueColor 'Red'
}

function Show-LWStatsScreen {
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

    if ($summary.PartialTracking) {
        Write-Host ''
        Write-LWMessageLine -Level 'Warn' -Message 'Some current-book totals began from an older save, so they may be partial.'
    }
}

function Merge-LWNamedCountEntries {
    param([object[]]$Entries)

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

    $currentSummary = Get-LWLiveBookStatsSummary
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

    $values = @(Merge-LWNamedCountEntries -Entries $Entries | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    if ($values.Count -eq 0) {
        return $null
    }

    return $values[0]
}

function Get-LWCampaignRunStatus {
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

function Get-LWCampaignSummary {
    if (-not (Test-LWHasState)) {
        return $null
    }

    $bookEntries = @(Get-LWCampaignBookEntries)
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
        KaiRankLabel                      = Format-LWKaiRankLabel -DisciplineCount @($script:GameState.Character.Disciplines).Count
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
    return $summary
}

function Format-LWCampaignFightHighlight {
    param(
        [string]$EnemyName,
        [object]$Value,
        [string]$Suffix = '',
        [string]$BookLabel = ''
    )

    if ([string]::IsNullOrWhiteSpace($EnemyName) -or $null -eq $Value -or ([string]$Value) -eq '' -or ([int]$Value) -le 0) {
        return '(none)'
    }

    $bookText = if ([string]::IsNullOrWhiteSpace($BookLabel)) { '' } else { " | $BookLabel" }
    return ("{0} ({1}{2}){3}" -f $EnemyName, $Value, $Suffix, $bookText)
}

function Show-LWCampaignOverview {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $favoriteWeapon = if ($null -ne $Summary.FavoriteWeapon) { "{0} x{1}" -f $Summary.FavoriteWeapon.Name, [int]$Summary.FavoriteWeapon.Count } else { '(none)' }
    $deadliestWeapon = if ($null -ne $Summary.DeadliestWeapon) { "{0} x{1}" -f $Summary.DeadliestWeapon.Name, [int]$Summary.DeadliestWeapon.Count } else { '(none)' }

    Write-LWPanelHeader -Title 'Campaign Overview' -AccentColor 'DarkCyan'
    Write-LWKeyValue -Label 'Name' -Value $Summary.CharacterName -ValueColor 'White'
    Write-LWKeyValue -Label 'Run Status' -Value $Summary.RunStatus -ValueColor $(if ([string]$Summary.RunStatus -eq 'Fallen') { 'Red' } elseif ([string]$Summary.RunStatus -eq 'In Combat') { 'Yellow' } else { 'Green' })
    Write-LWKeyValue -Label 'Run Style' -Value $Summary.RunStyle -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Current Book' -Value $Summary.CurrentBookLabel -ValueColor 'White'
    Write-LWKeyValue -Label 'Difficulty' -Value $Summary.Difficulty -ValueColor (Get-LWDifficultyColor -Difficulty ([string]$Summary.Difficulty))
    Write-LWKeyValue -Label 'Permadeath' -Value $(if ($Summary.PermadeathEnabled) { 'On' } else { 'Off' }) -ValueColor $(if ($Summary.PermadeathEnabled) { 'Red' } else { 'Gray' })
    Write-LWKeyValue -Label 'Run Integrity' -Value $Summary.RunIntegrityState -ValueColor (Get-LWIntegrityColor -IntegrityState ([string]$Summary.RunIntegrityState))
    Write-LWKeyValue -Label 'Achievement Pool' -Value $Summary.AchievementPoolLabel -ValueColor 'DarkYellow'
    Write-LWKeyValue -Label 'Kai Rank' -Value $Summary.KaiRankLabel -ValueColor 'DarkYellow'
    Write-LWKeyValue -Label 'Current Section' -Value ([string]$Summary.CurrentSection) -ValueColor 'White'
    Write-LWKeyValue -Label 'Completed Books' -Value $Summary.CompletedBooksLabel -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Books Complete' -Value ([string]$Summary.BooksCompletedCount) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Achievements' -Value ("{0}/{1}" -f $Summary.AchievementsUnlocked, $Summary.AchievementsAvailable) -ValueColor 'Magenta'
    Write-LWKeyValue -Label 'Profile Total' -Value ("{0}/{1}" -f $Summary.ProfileAchievementsUnlocked, $Summary.ProfileAchievementsAvailable) -ValueColor 'DarkMagenta'
    Write-LWKeyValue -Label 'Winning Path' -Value ([string]$Summary.TotalSuccessfulPathSections) -ValueColor 'White'
    Write-LWKeyValue -Label 'Sections Visited' -Value ([string]$Summary.TotalSectionsVisited) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Fights' -Value ([string]$Summary.TotalCombatCount) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Victories' -Value ([string]$Summary.TotalVictories) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Deaths' -Value ([string]$Summary.TotalDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Rewinds Used' -Value ([string]$Summary.TotalRewindsUsed) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Favorite Weapon' -Value $favoriteWeapon -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Deadliest Weapon' -Value $deadliestWeapon -ValueColor 'Gray'

    Write-Host ''
    Write-LWSubtle '  Use campaign books, campaign combat, campaign survival, or campaign milestones for deeper views.'
}

function Show-LWCampaignBooks {
    param([Parameter(Mandatory = $true)][object]$Summary)

    Write-LWPanelHeader -Title 'Campaign Books' -AccentColor 'DarkCyan'
    $shownBookNumbers = @()
    foreach ($entry in @($Summary.BookEntries)) {
        $bookSummary = $entry.Summary
        $bookLabel = Format-LWBookLabel -BookNumber ([int]$bookSummary.BookNumber) -IncludePrefix
        $statusText = if ([string]$entry.Status -eq 'Current') { 'Current' } else { 'Completed' }
        $statusColor = if ([string]$entry.Status -eq 'Current') { 'Yellow' } else { 'Green' }
        $shownBookNumbers += [int]$bookSummary.BookNumber

        Write-Host ("  {0}" -f $bookLabel) -ForegroundColor White
        Write-Host '    ' -NoNewline
        Write-Host $statusText -NoNewline -ForegroundColor $statusColor
        Write-Host (" | sections {0} | victories {1} | deaths {2} | rewinds {3}" -f [int]$bookSummary.SectionsVisited, [int]$bookSummary.Victories, [int]$bookSummary.DeathCount, [int]$bookSummary.RewindsUsed) -ForegroundColor Gray
        if ([bool]$bookSummary.PartialTracking) {
            Write-LWSubtle '      partial tracking from older save data'
        }
    }

    $missingCompletedBooks = @($script:GameState.Character.CompletedBooks | Where-Object { $shownBookNumbers -notcontains [int]$_ } | Sort-Object)
    foreach ($bookNumber in $missingCompletedBooks) {
        $bookLabel = Format-LWBookLabel -BookNumber ([int]$bookNumber) -IncludePrefix
        Write-Host ("  {0}" -f $bookLabel) -ForegroundColor White
        Write-Host '    ' -NoNewline
        Write-Host 'Completed' -NoNewline -ForegroundColor Green
        Write-Host ' | summary unavailable from older save history' -ForegroundColor DarkGray
    }
}

function Show-LWCampaignCombat {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $favoriteWeapon = if ($null -ne $Summary.FavoriteWeapon) { "{0} x{1}" -f $Summary.FavoriteWeapon.Name, [int]$Summary.FavoriteWeapon.Count } else { '(none)' }
    $deadliestWeapon = if ($null -ne $Summary.DeadliestWeapon) { "{0} x{1}" -f $Summary.DeadliestWeapon.Name, [int]$Summary.DeadliestWeapon.Count } else { '(none)' }
    $fastestVictory = Format-LWCampaignFightHighlight -EnemyName $Summary.FastestVictoryEnemyName -Value $Summary.FastestVictoryRounds -Suffix $(if ([int]$Summary.FastestVictoryRounds -eq 1) { ' round' } else { ' rounds' }) -BookLabel $Summary.FastestVictoryBookLabel
    $easiestVictory = Format-LWCampaignFightHighlight -EnemyName $Summary.EasiestVictoryEnemyName -Value $Summary.EasiestVictoryRatio -Suffix ' ratio' -BookLabel $Summary.EasiestVictoryBookLabel
    $longestFight = Format-LWCampaignFightHighlight -EnemyName $Summary.LongestFightEnemyName -Value $Summary.LongestFightRounds -Suffix $(if ([int]$Summary.LongestFightRounds -eq 1) { ' round' } else { ' rounds' }) -BookLabel $Summary.LongestFightBookLabel

    Write-LWPanelHeader -Title 'Campaign Combat' -AccentColor 'DarkRed'
    Write-LWKeyValue -Label 'Fights' -Value ([string]$Summary.TotalCombatCount) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Victories' -Value ([string]$Summary.TotalVictories) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Defeats' -Value ([string]$Summary.TotalDefeats) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Evades' -Value ([string]$Summary.TotalEvades) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Rounds Fought' -Value ([string]$Summary.TotalRoundsFought) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Mindblast Fights' -Value ([string]$Summary.TotalMindblastCombats) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Mindblast Wins' -Value ([string]$Summary.TotalMindblastVictories) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest CS Faced' -Value ([string]$Summary.HighestEnemyCombatSkillFaced) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest END Faced' -Value ([string]$Summary.HighestEnemyEnduranceFaced) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Highest CS Defeated' -Value ([string]$Summary.HighestEnemyCombatSkillDefeated) -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Highest END Defeated' -Value ([string]$Summary.HighestEnemyEnduranceDefeated) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Fastest Victory' -Value $fastestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Easiest Victory' -Value $easiestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Longest Fight' -Value $longestFight -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Favorite Weapon' -Value $favoriteWeapon -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Deadliest Weapon' -Value $deadliestWeapon -ValueColor 'Gray'
}

function Show-LWCampaignSurvival {
    param([Parameter(Mandatory = $true)][object]$Summary)

    Write-LWPanelHeader -Title 'Campaign Survival' -AccentColor 'DarkYellow'
    Write-LWKeyValue -Label 'END Lost' -Value ([string]$Summary.TotalEnduranceLost) -ValueColor 'Red'
    Write-LWKeyValue -Label 'END Gained' -Value ([string]$Summary.TotalEnduranceGained) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Healing Uses' -Value ([string]$Summary.TotalHealingTriggers) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Healing END' -Value ([string]$Summary.TotalHealingEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Gold Gained' -Value ([string]$Summary.TotalGoldGained) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Gold Spent' -Value ([string]$Summary.TotalGoldSpent) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Meals Eaten' -Value ([string]$Summary.TotalMealsEaten) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Hunting Meals' -Value ([string]$Summary.TotalHuntingMeals) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Starvation Hits' -Value ([string]$Summary.TotalStarvationPenalties) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Potions Used' -Value ([string]$Summary.TotalPotionsUsed) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Strong Potions' -Value ([string]$Summary.TotalStrongPotions) -ValueColor 'DarkGreen'
    Write-LWKeyValue -Label 'Potion END' -Value ([string]$Summary.TotalPotionEnduranceRestored) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Deaths' -Value ([string]$Summary.TotalDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Instant Deaths' -Value ([string]$Summary.TotalInstantDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Combat Deaths' -Value ([string]$Summary.TotalCombatDeaths) -ValueColor 'Red'
    Write-LWKeyValue -Label 'Rewinds Used' -Value ([string]$Summary.TotalRewindsUsed) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Recovery Shortcuts' -Value ([string]$Summary.TotalManualRecoveryShortcuts) -ValueColor 'Yellow'
    Write-LWKeyValue -Label 'Autosave' -Value $(if ($Summary.AutoSaveEnabled) { 'On' } else { 'Off' }) -ValueColor $(if ($Summary.AutoSaveEnabled) { 'Green' } else { 'DarkGray' })
}

function Show-LWCampaignMilestones {
    param([Parameter(Mandatory = $true)][object]$Summary)

    $recentAchievements = @($Summary.RecentAchievements)
    $fastestVictory = Format-LWCampaignFightHighlight -EnemyName $Summary.FastestVictoryEnemyName -Value $Summary.FastestVictoryRounds -Suffix $(if ([int]$Summary.FastestVictoryRounds -eq 1) { ' round' } else { ' rounds' }) -BookLabel $Summary.FastestVictoryBookLabel
    $easiestVictory = Format-LWCampaignFightHighlight -EnemyName $Summary.EasiestVictoryEnemyName -Value $Summary.EasiestVictoryRatio -Suffix ' ratio' -BookLabel $Summary.EasiestVictoryBookLabel
    $longestFight = Format-LWCampaignFightHighlight -EnemyName $Summary.LongestFightEnemyName -Value $Summary.LongestFightRounds -Suffix $(if ([int]$Summary.LongestFightRounds -eq 1) { ' round' } else { ' rounds' }) -BookLabel $Summary.LongestFightBookLabel

    Write-LWPanelHeader -Title 'Campaign Milestones' -AccentColor 'Magenta'
    Write-LWKeyValue -Label 'Books Completed' -Value ([string]$Summary.BooksCompletedCount) -ValueColor 'Green'
    Write-LWKeyValue -Label 'Achievements' -Value ("{0}/{1}" -f $Summary.AchievementsUnlocked, $Summary.AchievementsAvailable) -ValueColor 'Magenta'
    Write-LWKeyValue -Label 'Profile Total' -Value ("{0}/{1}" -f $Summary.ProfileAchievementsUnlocked, $Summary.ProfileAchievementsAvailable) -ValueColor 'DarkMagenta'
    Write-LWKeyValue -Label 'Run Style' -Value $Summary.RunStyle -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Fastest Victory' -Value $fastestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Easiest Victory' -Value $easiestVictory -ValueColor 'Green'
    Write-LWKeyValue -Label 'Longest Fight' -Value $longestFight -ValueColor 'Yellow'

    Write-LWPanelHeader -Title 'Recent Achievements' -AccentColor 'DarkYellow'
    if ($recentAchievements.Count -eq 0) {
        Write-LWSubtle '  (none yet)'
    }
    else {
        foreach ($entry in $recentAchievements) {
            $bookLabel = Format-LWBookLabel -BookNumber ([int]$entry.BookNumber) -IncludePrefix
            Write-LWBulletItem -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray' -BulletColor 'Magenta'
            Write-LWSubtle ("      unlocked at section {0} in {1}" -f [int]$entry.Section, $bookLabel)
        }
    }
}

function Show-LWCampaignScreen {
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

    if ($summary.PartialTracking) {
        Write-Host ''
        Write-LWMessageLine -Level 'Warn' -Message 'Some run totals include older save data and may be partial for the earliest books.'
    }
}

function Get-LWAchievementDefinitionById {
    param([Parameter(Mandatory = $true)][string]$Id)

    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if ([string]$definition.Id -eq $Id) {
            return $definition
        }
    }

    return $null
}

function Test-LWAchievementAvailableInCurrentMode {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [object]$State = $script:GameState
    )

    if ($null -eq $State) {
        return $true
    }

    $allowedPools = @(Get-LWModeAchievementPools -State $State)
    if ($allowedPools -notcontains [string]$Definition.ModePool) {
        return $false
    }

    $requiredDifficulty = @()
    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiredDifficulty') -and $null -ne $Definition.RequiredDifficulty) {
        $requiredDifficulty = @($Definition.RequiredDifficulty | ForEach-Object { Get-LWNormalizedDifficultyName -Difficulty ([string]$_) })
    }
    if ($requiredDifficulty.Count -gt 0 -and ($requiredDifficulty -notcontains (Get-LWCurrentDifficulty -State $State))) {
        return $false
    }

    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiresPermadeath') -and [bool]$Definition.RequiresPermadeath -and -not (Test-LWPermadeathEnabled -State $State)) {
        return $false
    }

    if ([string]$Definition.ModePool -eq 'Challenge' -and (Test-LWRunTampered -State $State)) {
        return $false
    }

    return $true
}

function Get-LWAchievementAvailabilityReason {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [object]$State = $script:GameState
    )

    if ($null -eq $State) {
        return ''
    }

    $allowedPools = @(Get-LWModeAchievementPools -State $State)
    if ($allowedPools -notcontains [string]$Definition.ModePool) {
        return ("disabled by {0} mode" -f (Get-LWCurrentDifficulty -State $State))
    }

    $requiredDifficulty = @()
    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiredDifficulty') -and $null -ne $Definition.RequiredDifficulty) {
        $requiredDifficulty = @($Definition.RequiredDifficulty | ForEach-Object { Get-LWNormalizedDifficultyName -Difficulty ([string]$_) })
    }
    if ($requiredDifficulty.Count -gt 0 -and ($requiredDifficulty -notcontains (Get-LWCurrentDifficulty -State $State))) {
        return ("requires {0}" -f ($requiredDifficulty -join ' or '))
    }

    if ((Test-LWPropertyExists -Object $Definition -Name 'RequiresPermadeath') -and [bool]$Definition.RequiresPermadeath -and -not (Test-LWPermadeathEnabled -State $State)) {
        return 'requires Permadeath'
    }

    if ([string]$Definition.ModePool -eq 'Challenge' -and (Test-LWRunTampered -State $State)) {
        return 'disabled by tampered run'
    }

    return ''
}

function Get-LWAchievementEligibleCount {
    if (-not (Test-LWHasState)) {
        return 0
    }

    return @((Get-LWAchievementDefinitions) | Where-Object { Test-LWAchievementAvailableInCurrentMode -Definition $_ }).Count
}

function Get-LWAchievementEligibleUnlockedCount {
    if (-not (Test-LWHasState)) {
        return 0
    }

    $count = 0
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition)) {
            continue
        }
        if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
            $count++
        }
    }

    return $count
}

function Get-LWRunCombatEntries {
    if (-not (Test-LWHasState)) {
        return @()
    }

    return @($script:GameState.History)
}

function Get-LWRunVictoryEntries {
    return @(Get-LWRunCombatEntries | Where-Object { @('Victory', 'Knockout') -contains [string]$_.Outcome })
}

function Get-LWRunTotalRounds {
    $total = 0
    foreach ($entry in @(Get-LWRunCombatEntries)) {
        if ((Test-LWPropertyExists -Object $entry -Name 'RoundCount') -and $null -ne $entry.RoundCount) {
            $total += [int]$entry.RoundCount
        }
    }

    return $total
}

function Get-LWAllAchievementBookSummaries {
    if (-not (Test-LWHasState)) {
        return @()
    }

    $summaries = @($script:GameState.BookHistory)
    $currentSummary = Get-LWLiveBookStatsSummary
    if ($null -ne $currentSummary) {
        $summaries += $currentSummary
    }

    return @($summaries)
}

function Get-LWCompletedAchievementBookSummaries {
    if (-not (Test-LWHasState)) {
        return @()
    }

    return @($script:GameState.BookHistory)
}

function Get-LWCombatEntryPlayerLossTotal {
    param([Parameter(Mandatory = $true)][object]$Entry)

    $total = 0
    if ((Test-LWPropertyExists -Object $Entry -Name 'Log') -and $null -ne $Entry.Log) {
        foreach ($round in @($Entry.Log)) {
            if ($null -ne $round -and (Test-LWPropertyExists -Object $round -Name 'PlayerLoss') -and $null -ne $round.PlayerLoss) {
                $total += [int]$round.PlayerLoss
            }
        }
    }

    return $total
}

function Rebuild-LWAchievementProgressFlags {
    if (-not (Test-LWHasState)) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $flags = $script:GameState.Achievements.ProgressFlags
    $flags.PerfectVictories = 0
    $flags.BrinkVictories = 0
    $flags.AgainstOddsVictories = 0

    foreach ($entry in @(Get-LWRunVictoryEntries)) {
        if ((Get-LWCombatEntryPlayerLossTotal -Entry $entry) -le 0) {
            $flags.PerfectVictories = [int]$flags.PerfectVictories + 1
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'PlayerEnd') -and $null -ne $entry.PlayerEnd -and [int]$entry.PlayerEnd -eq 1) {
            $flags.BrinkVictories = [int]$flags.BrinkVictories + 1
        }
        if ((Test-LWPropertyExists -Object $entry -Name 'CombatRatio') -and $null -ne $entry.CombatRatio -and [int]$entry.CombatRatio -le 0) {
            $flags.AgainstOddsVictories = [int]$flags.AgainstOddsVictories + 1
        }
    }
}

function Update-LWAchievementProgressFlagsFromSummary {
    param([Parameter(Mandatory = $true)][object]$Summary)

    if (-not (Test-LWHasState) -or @('Victory', 'Knockout') -notcontains [string]$Summary.Outcome) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $flags = $script:GameState.Achievements.ProgressFlags

    if ((Get-LWCombatEntryPlayerLossTotal -Entry $Summary) -le 0) {
        $flags.PerfectVictories = [int]$flags.PerfectVictories + 1
    }
    if ((Test-LWPropertyExists -Object $Summary -Name 'PlayerEnd') -and $null -ne $Summary.PlayerEnd -and [int]$Summary.PlayerEnd -eq 1) {
        $flags.BrinkVictories = [int]$flags.BrinkVictories + 1
    }
    if ((Test-LWPropertyExists -Object $Summary -Name 'CombatRatio') -and $null -ne $Summary.CombatRatio -and [int]$Summary.CombatRatio -le 0) {
        $flags.AgainstOddsVictories = [int]$flags.AgainstOddsVictories + 1
    }
}

function Test-LWAchievementUnlocked {
    param([Parameter(Mandatory = $true)][string]$Id)

    if (-not (Test-LWHasState) -or -not (Test-LWPropertyExists -Object $script:GameState -Name 'Achievements') -or $null -eq $script:GameState.Achievements) {
        return $false
    }

    foreach ($entry in @($script:GameState.Achievements.Unlocked)) {
        if ($null -ne $entry -and (Test-LWPropertyExists -Object $entry -Name 'Id') -and [string]$entry.Id -eq $Id) {
            return $true
        }
    }

    return $false
}

function Unlock-LWAchievement {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [switch]$Silent
    )

    if (-not (Test-LWHasState) -or $null -eq $Definition) {
        return $null
    }

    Ensure-LWAchievementState -State $script:GameState
    if (Test-LWAchievementUnlocked -Id ([string]$Definition.Id)) {
        return $null
    }

    $entry = [pscustomobject]@{
        Id         = [string]$Definition.Id
        Name       = [string]$Definition.Name
        Category   = [string]$Definition.Category
        Description = [string]$Definition.Description
        BookNumber = [int]$script:GameState.Character.BookNumber
        Section    = [int]$script:GameState.CurrentSection
        UnlockedOn = (Get-Date).ToString('o')
    }

    $script:GameState.Achievements.Unlocked = @($script:GameState.Achievements.Unlocked) + $entry
    if (@($script:GameState.Achievements.SeenNotifications) -notcontains [string]$Definition.Id) {
        $script:GameState.Achievements.SeenNotifications = @($script:GameState.Achievements.SeenNotifications) + [string]$Definition.Id
    }

    if (-not $Silent) {
        Write-LWInfo ("Achievement unlocked: {0} - {1}" -f [string]$Definition.Name, [string]$Definition.Description)
    }

    return $entry
}

function Get-LWMaxWeaponVictoryCount {
    $bestCount = 0
    foreach ($entry in @(Get-LWRunVictoryEntries | Group-Object -Property Weapon)) {
        if ($entry.Count -gt $bestCount) {
            $bestCount = [int]$entry.Count
        }
    }

    return $bestCount
}

function Get-LWSommerswerdUndeadVictoryCount {
    $count = 0
    foreach ($entry in @(Get-LWRunVictoryEntries)) {
        if ((Test-LWPropertyExists -Object $entry -Name 'Weapon') -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$entry.Weapon)) -and (Get-LWCombatEntryBookNumber -Entry $entry) -ge 2 -and (Test-LWPropertyExists -Object $entry -Name 'EnemyIsUndead') -and [bool]$entry.EnemyIsUndead) {
            $count++
        }
    }

    return $count
}

function Test-LWAchievementSatisfied {
    param([Parameter(Mandatory = $true)][object]$Definition)

    if (-not (Test-LWHasState)) {
        return $false
    }

    $runEntries = @(Get-LWRunCombatEntries)
    $runVictories = @(Get-LWRunVictoryEntries)
    $bookSummaries = @(Get-LWAllAchievementBookSummaries)
    $completedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
    $currentSummary = Get-LWLiveBookStatsSummary
    $flags = $script:GameState.Achievements.ProgressFlags

    switch ([string]$Definition.Id) {
        'first_blood' { return ($runVictories.Count -ge 1) }
        'swift_blade' { return (@($runVictories | Where-Object { [int]$_.RoundCount -eq 1 }).Count -ge 1) }
        'untouchable' { return ([int]$flags.PerfectVictories -ge 1) }
        'against_the_odds' { return ([int]$flags.AgainstOddsVictories -ge 1) }
        'mind_over_matter' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Mindblast') -and $_.Mindblast }).Count -ge 1) }
        'giant_slayer' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'EnemyCombatSkill') -and $null -ne $_.EnemyCombatSkill -and [int]$_.EnemyCombatSkill -ge 18 }).Count -ge 1) }
        'monster_hunter' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'EnemyEnduranceMax') -and $null -ne $_.EnemyEnduranceMax -and [int]$_.EnemyEnduranceMax -ge 30 }).Count -ge 1) }
        'back_from_the_brink' { return ([int]$flags.BrinkVictories -ge 1) }
        'kai_veteran' { return ($runVictories.Count -ge 10) }
        'weapon_master' { return ((Get-LWMaxWeaponVictoryCount) -ge 10) }
        'seasoned_fighter' { return ((Get-LWRunTotalRounds) -ge 25) }
        'endurance_duelist' { return (@($runEntries | Where-Object { [int]$_.RoundCount -ge 5 }).Count -ge 1) }
        'easy_pickings' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'CombatRatio') -and $null -ne $_.CombatRatio -and [int]$_.CombatRatio -ge 15 }).Count -ge 1) }
        'trail_survivor' { return ($null -ne $currentSummary -and [int]$currentSummary.MealsEaten -ge 1) }
        'hunters_instinct' { return ($null -ne $currentSummary -and [int]$currentSummary.MealsCoveredByHunting -ge 5) }
        'herbal_relief' { return ($null -ne $currentSummary -and [int]$currentSummary.PotionsUsed -ge 1) }
        'second_wind' { return ($null -ne $currentSummary -and [int]$currentSummary.HealingEnduranceRestored -ge 10) }
        'loaded_purse' { return ([int]$script:GameState.Inventory.GoldCrowns -ge 50) }
        'hard_lessons' { return ($null -ne $currentSummary -and [int]$currentSummary.StarvationPenalties -ge 1) }
        'still_standing' { return (@($script:GameState.DeathHistory).Count -ge 3) }
        'deep_draught' { return ($null -ne $currentSummary -and [int]$currentSummary.ConcentratedPotionsUsed -ge 1) }
        'pathfinder' { return (@($bookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'SectionsVisited') -and [int]$_.SectionsVisited -ge 25 }).Count -ge 1) }
        'long_road' { return (@($bookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'SectionsVisited') -and [int]$_.SectionsVisited -ge 50 }).Count -ge 1) }
        'no_quarter' { return (@($bookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Victories') -and [int]$_.Victories -ge 5 }).Count -ge 1) }
        'sun_sword' { return ((Test-LWStateHasSommerswerd -State $script:GameState) -or @($runEntries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Weapon') -and (Test-LWWeaponIsSommerswerd -Weapon ([string]$_.Weapon)) -and (Get-LWCombatEntryBookNumber -Entry $_) -ge 2 }).Count -ge 1) }
        'fully_armed' { return (@($script:GameState.Inventory.Weapons).Count -ge 2 -and (Get-LWStateShieldCombatSkillBonus -State $script:GameState) -ge 2) }
        'relic_hunter' { return (@($script:GameState.Inventory.SpecialItems).Count -ge 5) }
        'book_one_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 1) }
        'book_two_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 2) }
        'grave_bane' { return ((Get-LWSommerswerdUndeadVictoryCount) -ge 1) }
        'true_path' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'RewindsUsed') -and [int]$_.RewindsUsed -eq 0 }).Count -ge 1) }
        'unbroken' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'DeathCount') -and [int]$_.DeathCount -eq 0 }).Count -ge 1) }
        'wolf_of_sommerlund' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Defeats') -and [int]$_.Defeats -eq 0 }).Count -ge 1) }
        'iron_wolf' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'DeathCount') -and [int]$_.DeathCount -eq 0 -and (Test-LWPropertyExists -Object $_ -Name 'RewindsUsed') -and [int]$_.RewindsUsed -eq 0 -and (Test-LWPropertyExists -Object $_ -Name 'ManualRecoveryShortcuts') -and [int]$_.ManualRecoveryShortcuts -eq 0 }).Count -ge 1) }
        'gentle_path' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Story' }).Count -ge 1) }
        'all_too_easy' { return ((Get-LWCurrentDifficulty) -eq 'Story' -and $runVictories.Count -ge 1) }
        'bedtime_tale' { return (@($completedBookSummaries | Where-Object { [int]$_.BookNumber -eq 1 -and (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Story' }).Count -ge 1) }
        'hard_road' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Hard' }).Count -ge 1) }
        'lean_healing' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Hard' -and (Test-LWPropertyExists -Object $_ -Name 'HealingEnduranceRestored') -and [int]$_.HealingEnduranceRestored -ge 10 }).Count -ge 1) }
        'veteran_of_sommerlund' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Veteran' }).Count -ge 1) }
        'by_the_text' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Veteran' }).Count -ge 1) }
        'only_one_life' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Permadeath') -and [bool]$_.Permadeath }).Count -ge 1) }
        'mortal_wolf' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Permadeath') -and [bool]$_.Permadeath -and (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and @('Hard', 'Veteran') -contains [string]$_.Difficulty }).Count -ge 1) }
        default { return $false }
    }
}

function Get-LWAchievementProgressText {
    param([Parameter(Mandatory = $true)][object]$Definition)

    if (-not (Test-LWHasState)) {
        return ''
    }

    $currentSummary = Get-LWLiveBookStatsSummary
    $bookSummaries = @(Get-LWAllAchievementBookSummaries)
    $runVictories = @(Get-LWRunVictoryEntries)

    switch ([string]$Definition.Id) {
        'kai_veteran' { return ("{0}/10 wins" -f $runVictories.Count) }
        'weapon_master' { return ("{0}/10 wins with one weapon" -f (Get-LWMaxWeaponVictoryCount)) }
        'seasoned_fighter' { return ("{0}/25 rounds" -f (Get-LWRunTotalRounds)) }
        'giant_slayer' { return ("best defeated CS {0}/18" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HighestEnemyCombatSkillDefeated } else { 0 })) }
        'monster_hunter' { return ("best defeated END {0}/30" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HighestEnemyEnduranceDefeated } else { 0 })) }
        'hunters_instinct' { return ("{0}/5 Hunting meals" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.MealsCoveredByHunting } else { 0 })) }
        'deep_draught' { return ("{0}/1 concentrated doses used" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.ConcentratedPotionsUsed } else { 0 })) }
        'second_wind' { return ("{0}/10 END restored" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HealingEnduranceRestored } else { 0 })) }
        'loaded_purse' { return ("{0}/50 Gold" -f [int]$script:GameState.Inventory.GoldCrowns) }
        'still_standing' { return ("{0}/3 deaths survived" -f @($script:GameState.DeathHistory).Count) }
        'pathfinder' { return ("best book {0}/25 sections" -f $(if (@($bookSummaries).Count -gt 0) { (@($bookSummaries | ForEach-Object { [int]$_.SectionsVisited } | Measure-Object -Maximum).Maximum) } else { 0 })) }
        'long_road' { return ("best book {0}/50 sections" -f $(if (@($bookSummaries).Count -gt 0) { (@($bookSummaries | ForEach-Object { [int]$_.SectionsVisited } | Measure-Object -Maximum).Maximum) } else { 0 })) }
        'no_quarter' { return ("best book {0}/5 victories" -f $(if (@($bookSummaries).Count -gt 0) { (@($bookSummaries | ForEach-Object { [int]$_.Victories } | Measure-Object -Maximum).Maximum) } else { 0 })) }
        'sun_sword' { return $(if (Test-LWStateHasSommerswerd -State $script:GameState) { 'Sommerswerd carried' } else { 'Sommerswerd not yet claimed' }) }
        'fully_armed' { return ("weapons {0}/2, shield {1}" -f @($script:GameState.Inventory.Weapons).Count, $(if ((Get-LWStateShieldCombatSkillBonus -State $script:GameState) -ge 2) { 'yes' } else { 'no' })) }
        'relic_hunter' { return ("{0}/5 Special Items carried" -f @($script:GameState.Inventory.SpecialItems).Count) }
        'grave_bane' { return ("{0}/1 undead Sommerswerd wins" -f (Get-LWSommerswerdUndeadVictoryCount)) }
        'true_path' { return ("current book rewinds: {0}" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.RewindsUsed } else { 0 })) }
        'iron_wolf' { return ("current book deaths {0}, rewinds {1}, shortcuts {2}" -f $(if ($null -ne $currentSummary -and (Test-LWPropertyExists -Object $currentSummary -Name 'DeathCount')) { [int]$currentSummary.DeathCount } else { 0 }), $(if ($null -ne $currentSummary) { [int]$currentSummary.RewindsUsed } else { 0 }), $(if ($null -ne $currentSummary) { [int]$currentSummary.ManualRecoveryShortcuts } else { 0 })) }
        'gentle_path' { return 'complete any book in Story mode' }
        'all_too_easy' { return ("Story mode victories: {0}" -f $(if ((Get-LWCurrentDifficulty) -eq 'Story') { $runVictories.Count } else { 0 })) }
        'bedtime_tale' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 1) { 'Book 1 complete' } else { 'complete Book 1 in Story mode' }) }
        'hard_road' { return 'complete any book on Hard' }
        'lean_healing' { return ("current book Healing restored: {0}/10" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.HealingEnduranceRestored } else { 0 })) }
        'veteran_of_sommerlund' { return 'complete any book on Veteran' }
        'by_the_text' { return 'complete any book on Veteran' }
        'only_one_life' { return $(if (Test-LWPermadeathEnabled) { 'Permadeath active for this run' } else { 'start a Permadeath run' }) }
        'mortal_wolf' { return $(if ((Test-LWPermadeathEnabled) -and @('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty)) { 'eligible run active' } else { 'requires Hard/Veteran + Permadeath' }) }
        default { return '' }
    }
}

function Sync-LWAchievements {
    param(
        [string]$Context = 'general',
        [object]$Data = $null,
        [switch]$Silent
    )

    if (-not (Test-LWHasState)) {
        return @()
    }

    Ensure-LWAchievementState -State $script:GameState
    if ([string]$Context -eq 'load') {
        Rebuild-LWAchievementProgressFlags
    }
    elseif ([string]$Context -eq 'combat' -and $null -ne $Data) {
        Update-LWAchievementProgressFlagsFromSummary -Summary $Data
    }

    $newUnlocks = @()
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if ([string]$Context -eq 'load' -and -not [bool]$definition.Backfill) {
            continue
        }
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition)) {
            continue
        }
        if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
            continue
        }
        if (Test-LWAchievementSatisfied -Definition $definition) {
            $unlocked = Unlock-LWAchievement -Definition $definition -Silent:$Silent
            if ($null -ne $unlocked) {
                $newUnlocks += $unlocked
            }
        }
    }

    return @($newUnlocks)
}

function Get-LWAchievementUnlockedCount {
    if (-not (Test-LWHasState)) {
        return 0
    }

    Ensure-LWAchievementState -State $script:GameState
    return @($script:GameState.Achievements.Unlocked).Count
}

function Get-LWAchievementAvailableCount {
    if (-not (Test-LWHasState)) {
        return @(Get-LWAchievementDefinitions).Count
    }

    return Get-LWAchievementEligibleCount
}

function Get-LWAchievementRecentUnlocks {
    param([int]$Count = 5)

    if (-not (Test-LWHasState)) {
        return @()
    }

    Ensure-LWAchievementState -State $script:GameState
    $entries = @($script:GameState.Achievements.Unlocked)
    if ($entries.Count -le $Count) {
        return @($entries)
    }

    return @($entries[($entries.Count - $Count)..($entries.Count - 1)])
}

function Show-LWAchievementOverview {
    $definitions = @(Get-LWAchievementDefinitions)
    $profileUnlockedCount = Get-LWAchievementUnlockedCount
    $profileTotalCount = @($definitions).Count
    $eligibleUnlockedCount = Get-LWAchievementEligibleUnlockedCount
    $eligibleCount = Get-LWAchievementEligibleCount
    $plannedCount = @(Get-LWPhaseTwoAchievementPlans).Count
    $recent = @(Get-LWAchievementRecentUnlocks -Count 5)
    $poolOrder = @('Universal', 'Story', 'Combat', 'Exploration', 'Challenge')

    Write-LWPanelHeader -Title 'Achievements' -AccentColor 'Magenta'
    Write-LWKeyValue -Label 'Eligible This Run' -Value ("{0}/{1}" -f $eligibleUnlockedCount, $eligibleCount) -ValueColor 'White'
    Write-LWKeyValue -Label 'Profile Total' -Value ("{0}/{1}" -f $profileUnlockedCount, $profileTotalCount) -ValueColor 'Magenta'
    Write-LWKeyValue -Label 'Active Pool' -Value (Get-LWModeAchievementPoolLabel) -ValueColor 'DarkYellow'
    Write-LWKeyValue -Label 'Phase Two Plans' -Value $plannedCount -ValueColor 'DarkMagenta'

    foreach ($pool in $poolOrder) {
        $poolTotal = @($definitions | Where-Object { [string]$_.ModePool -eq $pool }).Count
        if ($poolTotal -le 0) {
            continue
        }

        $poolEligible = @($definitions | Where-Object {
                [string]$_.ModePool -eq $pool -and (Test-LWAchievementAvailableInCurrentMode -Definition $_)
            }).Count
        $poolUnlocked = 0
        foreach ($definition in @($definitions | Where-Object {
                    [string]$_.ModePool -eq $pool -and (Test-LWAchievementAvailableInCurrentMode -Definition $_)
                })) {
            if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
                $poolUnlocked++
            }
        }

        $label = if ($poolEligible -gt 0) {
            "{0} ({1}/{2})" -f $pool, $poolUnlocked, $poolEligible
        }
        else {
            "{0} (disabled)" -f $pool
        }
        Write-LWKeyValue -Label $pool -Value $label -ValueColor 'Gray'
    }

    if (Test-LWRunTampered) {
        Write-Host ''
        Write-LWWarn 'Challenge achievements are disabled for this run because the run integrity check was broken.'
    }

    Write-LWPanelHeader -Title 'Recent Unlocks' -AccentColor 'DarkYellow'
    if ($recent.Count -eq 0) {
        Write-LWSubtle '  (none yet)'
    }
    else {
        foreach ($entry in $recent) {
            Write-LWBulletItem -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray' -BulletColor 'Magenta'
        }
    }

    Write-Host ''
    Write-LWSubtle '  Use achievements unlocked, locked, recent, progress, or planned.'
}

function Show-LWAchievementUnlockedList {
    Write-LWPanelHeader -Title 'Unlocked Achievements' -AccentColor 'Green'
    $entries = @($script:GameState.Achievements.Unlocked)
    if ($entries.Count -eq 0) {
        Write-LWSubtle '  (none yet)'
        return
    }

    foreach ($entry in $entries) {
        Write-LWBulletItem -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray' -BulletColor 'Green'
    }
}

function Show-LWAchievementLockedList {
    Write-LWPanelHeader -Title 'Locked Achievements' -AccentColor 'DarkYellow'
    $locked = @()
    $disabled = @()
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (-not (Test-LWAchievementUnlocked -Id ([string]$definition.Id))) {
            if (Test-LWAchievementAvailableInCurrentMode -Definition $definition) {
                $locked += $definition
            }
            else {
                $disabled += $definition
            }
        }
    }

    if ($locked.Count -eq 0) {
        Write-LWSubtle '  No eligible locked achievements remain for this run.'
    }
    else {
        foreach ($definition in $locked) {
            $progress = Get-LWAchievementProgressText -Definition $definition
            Write-LWBulletItem -Text ("{0} - {1}" -f [string]$definition.Name, [string]$definition.Description) -TextColor 'Gray' -BulletColor 'DarkYellow'
            if (-not [string]::IsNullOrWhiteSpace($progress)) {
                Write-LWSubtle ("      progress: {0}" -f $progress)
            }
        }
    }

    Write-LWPanelHeader -Title 'Disabled For This Run' -AccentColor 'DarkGray'
    if ($disabled.Count -eq 0) {
        Write-LWSubtle '  (none)'
    }
    else {
        foreach ($definition in $disabled) {
            $reason = Get-LWAchievementAvailabilityReason -Definition $definition
            Write-LWBulletItem -Text ("{0} - {1}" -f [string]$definition.Name, [string]$definition.Description) -TextColor 'Gray' -BulletColor 'DarkGray'
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                Write-LWSubtle ("      {0}" -f $reason)
            }
        }
    }
}

function Show-LWAchievementProgressList {
    Write-LWPanelHeader -Title 'Achievement Progress' -AccentColor 'Cyan'
    $anyShown = $false
    $disabledCount = 0
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
            continue
        }
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition)) {
            $disabledCount++
            continue
        }

        $progress = Get-LWAchievementProgressText -Definition $definition
        if ([string]::IsNullOrWhiteSpace($progress)) {
            continue
        }

        $anyShown = $true
        Write-LWBulletItem -Text ("{0} - {1}" -f [string]$definition.Name, $progress) -TextColor 'Gray' -BulletColor 'Cyan'
    }

    if (-not $anyShown) {
        Write-LWSubtle '  No tracked progress milestones are pending for the current run.'
    }

    if ($disabledCount -gt 0) {
        Write-Host ''
        Write-LWSubtle ("  {0} achievements are currently disabled by this run's mode settings." -f $disabledCount)
    }
}

function Show-LWAchievementPlannedList {
    Write-LWPanelHeader -Title 'Phase Two Achievement Plans' -AccentColor 'DarkMagenta'
    foreach ($entry in @(Get-LWPhaseTwoAchievementPlans)) {
        Write-LWBulletItem -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray' -BulletColor 'DarkMagenta'
    }
}

function Show-LWAchievementsScreen {
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
            Write-LWPanelHeader -Title 'Recent Unlocks' -AccentColor 'DarkYellow'
            $entries = @(Get-LWAchievementRecentUnlocks -Count 10)
            if ($entries.Count -eq 0) {
                Write-LWSubtle '  (none yet)'
            }
            else {
                foreach ($entry in $entries) {
                    Write-LWBulletItem -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray' -BulletColor 'DarkYellow'
                }
            }
        }
        'progress' { Show-LWAchievementProgressList }
        'planned' { Show-LWAchievementPlannedList }
        default { Show-LWAchievementOverview }
    }
}

function Resolve-LWInventoryType {
    param([string]$Value)

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
        'special' { return 'special' }
        'specialitem' { return 'special' }
        'specialitems' { return 'special' }
        default { return $null }
    }
}

function Get-LWInventoryTypeLabel {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return 'Weapons' }
        'backpack' { return 'Backpack' }
        'special' { return 'Special Items' }
    }
}

function Get-LWInventoryTypeColor {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return 'Green' }
        'backpack' { return 'Yellow' }
        'special' { return 'DarkCyan' }
    }
}

function Get-LWInventoryTypeCapacity {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return 2 }
        'backpack' { return 8 }
        'special' { return $null }
    }
}

function Get-LWInventoryItems {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return @($script:GameState.Inventory.Weapons) }
        'backpack' { return @($script:GameState.Inventory.BackpackItems) }
        'special' { return @($script:GameState.Inventory.SpecialItems) }
    }
}

function Set-LWInventoryItems {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = @($Items) }
        'backpack' { $script:GameState.Inventory.BackpackItems = @($Items) }
        'special' { $script:GameState.Inventory.SpecialItems = @($Items) }
    }

    [void](Sync-LWAchievements -Context 'inventory')
}

function Show-LWInventorySlotsSection {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    $items = @(Get-LWInventoryItems -Type $Type)
    $label = Get-LWInventoryTypeLabel -Type $Type
    $labelColor = Get-LWInventoryTypeColor -Type $Type
    $capacity = Get-LWInventoryTypeCapacity -Type $Type

    if ($null -ne $capacity) {
        Write-Host ("  {0} ({1}/{2})" -f $label, $items.Count, $capacity) -ForegroundColor $labelColor
        for ($i = 0; $i -lt $capacity; $i++) {
            $slotText = if ($i -lt $items.Count) { [string]$items[$i] } else { '(empty)' }
            $slotColor = if ($i -lt $items.Count) { 'Gray' } else { 'DarkGray' }
            Write-Host ("    {0,2}. " -f ($i + 1)) -NoNewline -ForegroundColor DarkGray
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

function Show-LWInventorySummary {
    $weapons = @($script:GameState.Inventory.Weapons)
    $backpack = @($script:GameState.Inventory.BackpackItems)
    $special = @($script:GameState.Inventory.SpecialItems)

    Write-LWPanelHeader -Title 'Inventory' -AccentColor 'Yellow'
    Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2  {1}" -f $weapons.Count, (Format-LWList -Items $weapons)) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Backpack' -Value ("{0}/8  {1}" -f $backpack.Count, (Format-LWList -Items $backpack)) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Special Items' -Value ("{0}  {1}" -f $special.Count, (Format-LWList -Items $special)) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f $script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
}

function Show-LWInventory {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Write-LWPanelHeader -Title 'Inventory' -AccentColor 'Yellow'
    Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f $script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
    Write-Host ''
    Show-LWInventorySlotsSection -Type 'weapon'
    Write-Host ''
    Show-LWInventorySlotsSection -Type 'backpack'
    Write-Host ''
    Show-LWInventorySlotsSection -Type 'special'
    Write-Host ''
    if (Test-LWStateHasSommerswerd -State $script:GameState) {
        $sommerswerdBonus = Get-LWStateSommerswerdCombatSkillBonus -State $script:GameState
        Write-LWSubtle ("  Sommerswerd: +{0} Combat Skill in combat; undead damage x2." -f $sommerswerdBonus)
        Write-LWSubtle '  Hostile magic absorption remains story-driven and should be resolved from the book text.'
        Write-Host ''
    }
    if (Test-LWStateHasBoneSword -State $script:GameState) {
        Write-LWSubtle ('  Bone Sword: +1 Combat Skill in Book 3 / Kalte, no bonus elsewhere.')
        Write-Host ''
    }
    if ((Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState) -gt 0) {
        Write-LWSubtle '  Silver Helm: +2 Combat Skill while carried as a Special Item.'
        Write-Host ''
    }
    Write-LWSubtle '  Use add <type> <name> [qty] to add items quickly.'
    Write-LWSubtle '  Use drop <type> <slot> to remove by slot number.'
}

function Show-LWSheet {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $shieldBonus = Get-LWStateShieldCombatSkillBonus -State $script:GameState
    $silverHelmBonus = Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState
    $displayCombatSkill = [int]$script:GameState.Character.CombatSkillBase + $shieldBonus + $silverHelmBonus
    $combatSkillText = [string]$displayCombatSkill
    $combatSkillNotes = @()
    if ($shieldBonus -gt 0) {
        $combatSkillNotes += "Shield +$shieldBonus"
    }
    if ($silverHelmBonus -gt 0) {
        $combatSkillNotes += "Silver Helm +$silverHelmBonus"
    }
    if ($combatSkillNotes.Count -gt 0) {
        $combatSkillText = "{0} ({1})" -f $displayCombatSkill, ($combatSkillNotes -join ', ')
    }

    $chainmailBonus = Get-LWStateChainmailEnduranceBonus -State $script:GameState
    $enduranceText = "{0} / {1}" -f $script:GameState.Character.EnduranceCurrent, $script:GameState.Character.EnduranceMax
    if ($chainmailBonus -gt 0) {
        $enduranceText += " (Chainmail +$chainmailBonus)"
    }

    Write-LWPanelHeader -Title 'Character Sheet' -AccentColor 'Cyan'
    Write-LWKeyValue -Label 'Name' -Value $script:GameState.Character.Name -ValueColor 'White'
    Write-LWKeyValue -Label 'Rule Set' -Value $script:GameState.RuleSet -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Book' -Value (Format-LWBookLabel -BookNumber ([int]$script:GameState.Character.BookNumber)) -ValueColor 'White'
    Write-LWKeyValue -Label 'Difficulty' -Value (Get-LWCurrentDifficulty) -ValueColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty))
    Write-LWKeyValue -Label 'Permadeath' -Value $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }) -ValueColor $(if (Test-LWPermadeathEnabled) { 'Red' } else { 'Gray' })
    Write-LWKeyValue -Label 'Run Integrity' -Value ([string]$script:GameState.Run.IntegrityState) -ValueColor (Get-LWIntegrityColor -IntegrityState ([string]$script:GameState.Run.IntegrityState))
    Write-LWKeyValue -Label 'Kai Rank' -Value (Format-LWKaiRankLabel -DisciplineCount @($script:GameState.Character.Disciplines).Count) -ValueColor 'DarkYellow'
    Write-LWKeyValue -Label 'Combat Skill' -Value $combatSkillText -ValueColor 'Cyan'
    Write-LWKeyValue -Label 'Endurance' -Value $enduranceText -ValueColor (Get-LWEnduranceColor -Current $script:GameState.Character.EnduranceCurrent -Max $script:GameState.Character.EnduranceMax)
    if (Test-LWStateHasSommerswerd -State $script:GameState) {
        $sommerswerdBonus = Get-LWStateSommerswerdCombatSkillBonus -State $script:GameState
        Write-LWKeyValue -Label 'Sommerswerd' -Value ("+{0} in combat; undead x2" -f $sommerswerdBonus) -ValueColor 'DarkYellow'
    }
    if (Test-LWStateHasBoneSword -State $script:GameState) {
        Write-LWKeyValue -Label 'Bone Sword' -Value $(if (Test-LWStateIsInKalte -State $script:GameState) { '+1 in Book 3 / Kalte combat' } else { 'No bonus outside Book 3 / Kalte' }) -ValueColor 'DarkYellow'
    }
    if ($silverHelmBonus -gt 0) {
        Write-LWKeyValue -Label 'Silver Helm' -Value ("+{0} Combat Skill" -f $silverHelmBonus) -ValueColor 'DarkYellow'
    }
    Write-LWKeyValue -Label 'Combat Mode' -Value $script:GameState.Settings.CombatMode -ValueColor (Get-LWModeColor -Mode $script:GameState.Settings.CombatMode)
    Write-LWKeyValue -Label 'Completed Books' -Value (Format-LWCompletedBooks -Books @($script:GameState.Character.CompletedBooks)) -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Current Section' -Value ([string]$script:GameState.CurrentSection) -ValueColor 'White'
    Write-LWKeyValue -Label 'Achievements' -Value ("{0}/{1}" -f (Get-LWAchievementEligibleUnlockedCount), (Get-LWAchievementAvailableCount)) -ValueColor 'Magenta'
    Show-LWDisciplines
    Show-LWInventorySummary
    Write-LWPanelHeader -Title 'Quick Notes' -AccentColor 'DarkCyan'
    Write-LWKeyValue -Label 'Note Count' -Value ([string]@($script:GameState.Character.Notes).Count) -ValueColor 'Gray'
}

function Resolve-LWSectionExit {
    if (-not (Test-LWHasState)) {
        return
    }

    if ($script:GameState.SectionHealingResolved) {
        return
    }

    if ((Test-LWDiscipline -Name 'Healing') -and -not $script:GameState.SectionHadCombat) {
        if ($script:GameState.Character.EnduranceCurrent -lt $script:GameState.Character.EnduranceMax) {
            $before = [int]$script:GameState.Character.EnduranceCurrent
            $healingResolution = Resolve-LWHealingRestoreAmount -RequestedAmount 1
            $script:GameState.Character.EnduranceCurrent += [int]$healingResolution.AppliedAmount
            if ($script:GameState.Character.EnduranceCurrent -gt $script:GameState.Character.EnduranceMax) {
                $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
            }
            $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
            Add-LWBookEnduranceDelta -Delta $restored
            if ($restored -gt 0) {
                Register-LWHealingRestore -Amount $restored
                Write-LWInfo 'Healing restores 1 Endurance for a non-combat section.'
            }
            elseif (-not [string]::IsNullOrWhiteSpace([string]$healingResolution.Note)) {
                Write-LWWarn ([string]$healingResolution.Note)
            }
        }
    }

    $script:GameState.SectionHealingResolved = $true
}

function Set-LWSection {
    param([Nullable[int]]$Section = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $newSection = if ($null -ne $Section) { [int]$Section } else { Read-LWInt -Prompt 'New section number' -Default $script:GameState.CurrentSection -Min 1 }
    if ($newSection -eq $script:GameState.CurrentSection) {
        Write-LWInfo "Still in section $newSection."
        return
    }

    Save-LWCurrentSectionCheckpoint
    Resolve-LWSectionExit
    $script:GameState.CurrentSection = $newSection
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Add-LWBookSectionVisit -Section $newSection
    Write-LWInfo "Moved to section $newSection."
    Invoke-LWMaybeAutosave
}

function Invoke-LWHealingCheck {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Resolve-LWSectionExit
    Invoke-LWMaybeAutosave
}

function Add-LWNote {
    param([string]$Text)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Text = Read-LWText -Prompt 'Note text'
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        Write-LWWarn 'No note added.'
        return
    }

    $script:GameState.Character.Notes = @($script:GameState.Character.Notes) + $Text.Trim()
    Write-LWInfo 'Note added.'
    Invoke-LWMaybeAutosave
}

function Remove-LWNote {
    param([Parameter(Mandatory = $true)][int]$Index)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $notes = @($script:GameState.Character.Notes)
    if ($notes.Count -eq 0) {
        Write-LWWarn 'There are no notes to remove.'
        return
    }

    if ($Index -lt 1 -or $Index -gt $notes.Count) {
        Write-LWWarn "Note number must be between 1 and $($notes.Count)."
        return
    }

    $removedNote = [string]$notes[$Index - 1]
    $updatedNotes = @()
    for ($i = 0; $i -lt $notes.Count; $i++) {
        if ($i -ne ($Index - 1)) {
            $updatedNotes += $notes[$i]
        }
    }

    $script:GameState.Character.Notes = @($updatedNotes)
    Write-LWInfo "Removed note ${Index}: $removedNote"
    Invoke-LWMaybeAutosave
}

function Remove-LWNoteInteractive {
    param([string[]]$InputParts = @())

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    Set-LWScreen -Name 'notes'
    $noteCount = @($script:GameState.Character.Notes).Count
    if ($noteCount -eq 0) {
        Write-LWWarn 'There are no notes to remove.'
        return
    }

    $index = 0
    $hasDirectIndex = $false
    if ($null -ne $InputParts) {
        $InputParts = @($InputParts)
        if ($InputParts.Count -gt 2 -and [int]::TryParse($InputParts[2], [ref]$index)) {
            $hasDirectIndex = $true
        }
    }

    if (-not $hasDirectIndex) {
        $index = Read-LWInt -Prompt 'Note number to remove' -Min 1 -Max $noteCount
    }

    Remove-LWNote -Index $index
}

function Add-LWInventoryItem {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Write-LWWarn 'Item name cannot be empty.'
        return
    }
    if ($Quantity -lt 1) {
        Write-LWWarn 'Quantity must be at least 1.'
        return
    }

    switch ($Type) {
        'weapon' {
            $current = @($script:GameState.Inventory.Weapons)
            if (($current.Count + $Quantity) -gt 2) {
                Write-LWWarn 'You can only carry 2 weapons.'
                return
            }
            for ($i = 0; $i -lt $Quantity; $i++) {
                $current += $Name
            }
            $script:GameState.Inventory.Weapons = $current
        }
        'backpack' {
            $current = @($script:GameState.Inventory.BackpackItems)
            if (($current.Count + $Quantity) -gt 8) {
                Write-LWWarn 'You can only carry 8 backpack items.'
                return
            }
            for ($i = 0; $i -lt $Quantity; $i++) {
                $current += $Name
            }
            $script:GameState.Inventory.BackpackItems = $current
        }
        'special' {
            $current = @($script:GameState.Inventory.SpecialItems)
            for ($i = 0; $i -lt $Quantity; $i++) {
                $current += $Name
            }
            $script:GameState.Inventory.SpecialItems = $current
        }
    }

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    Write-LWInfo "Added $Quantity x $Name to $Type inventory."
    Invoke-LWMaybeAutosave
}

function Add-LWInventoryInteractive {
    param([string[]]$InputParts = @())

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
            Write-LWWarn 'Type must be weapon, backpack, or special.'
            return
        }
    }

    if ($null -eq $type) {
        $type = Resolve-LWInventoryType -Value (Read-LWText -Prompt 'Item type (weapon/backpack/special)')
        if ($null -eq $type) {
            Write-LWWarn 'Type must be weapon, backpack, or special.'
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
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )

    if ($Quantity -lt 1) {
        Write-LWWarn 'Quantity must be at least 1.'
        return
    }

    $source = switch ($Type) {
        'weapon'   { @($script:GameState.Inventory.Weapons) }
        'backpack' { @($script:GameState.Inventory.BackpackItems) }
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
        'special'  { $script:GameState.Inventory.SpecialItems = $remaining }
    }

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    Write-LWInfo "Removed $removed x $Name from $Type inventory."
    Invoke-LWMaybeAutosave
}

function Remove-LWInventoryItemBySlot {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][int]$Slot
    )

    if ($Slot -lt 1) {
        Write-LWWarn 'Slot number must be at least 1.'
        return
    }

    $items = @(Get-LWInventoryItems -Type $Type)
    $label = Get-LWInventoryTypeLabel -Type $Type
    $capacity = Get-LWInventoryTypeCapacity -Type $Type

    if ($items.Count -eq 0) {
        Write-LWWarn "$label is empty."
        return
    }

    if ($null -ne $capacity -and $Slot -gt $capacity) {
        Write-LWWarn "$label slot must be between 1 and $capacity."
        return
    }
    if ($null -eq $capacity -and $Slot -gt $items.Count) {
        Write-LWWarn "$label slot must be between 1 and $($items.Count)."
        return
    }
    if ($Slot -gt $items.Count) {
        Write-LWWarn "$label slot $Slot is empty."
        return
    }

    $removedItem = [string]$items[$Slot - 1]
    $remaining = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        if ($i -ne ($Slot - 1)) {
            $remaining += $items[$i]
        }
    }

    Set-LWInventoryItems -Type $Type -Items $remaining
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    Write-LWInfo "Removed $removedItem from $label slot $Slot."
    Invoke-LWMaybeAutosave
}

function Remove-LWInventoryInteractive {
    param([string[]]$InputParts = @())

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
            Write-LWWarn 'Type must be weapon, backpack, or special.'
            return
        }
    }

    if ($null -eq $type) {
        $type = Resolve-LWInventoryType -Value (Read-LWText -Prompt 'Item type to remove (weapon/backpack/special)')
        if ($null -eq $type) {
            Write-LWWarn 'Type must be weapon, backpack, or special.'
            return
        }
    }

    $removeLabel = Get-LWInventoryTypeLabel -Type $type

    $slot = $null
    if ($InputParts.Count -gt 2) {
        $slotValue = 0
        if (-not [int]::TryParse($InputParts[2], [ref]$slotValue)) {
            Write-LWWarn 'Slot number must be a whole number.'
            return
        }
        $slot = $slotValue
    }
    else {
        $slot = Read-LWInt -Prompt ("{0} slot to remove" -f $removeLabel) -Min 1
    }

    Remove-LWInventoryItemBySlot -Type $type -Slot $slot
}

function Set-LWGold {
    param([int]$NewValue)

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

function Update-LWGold {
    param([int]$Delta)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $oldValue = [int]$script:GameState.Inventory.GoldCrowns
    $newValue = $oldValue + $Delta
    if ($newValue -lt 0) {
        Write-LWWarn 'You cannot go below 0 Gold Crowns. Clamping to 0.'
        $newValue = 0
    }
    if ($newValue -gt 50) {
        Write-LWWarn 'Gold Crowns are capped at 50. Clamping to 50.'
        $newValue = 50
    }

    $script:GameState.Inventory.GoldCrowns = $newValue
    Add-LWBookGoldDelta -Delta ($newValue - $oldValue)
    [void](Sync-LWAchievements -Context 'gold')
    Write-LWInfo "Gold Crowns now $newValue."
    Invoke-LWMaybeAutosave
}

function Update-LWGoldInteractive {
    param([string[]]$InputParts = @())

    if ($null -eq $InputParts) {
        $InputParts = @()
    }
    else {
        $InputParts = @($InputParts)
    }

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($InputParts.Count -gt 1) {
        $delta = 0
        if ([int]::TryParse($InputParts[1], [ref]$delta)) {
            Update-LWGold -Delta $delta
            return
        }
    }

    $deltaText = Read-LWText -Prompt 'Gold change (example: 10 or -4)'
    $delta = 0
    if (-not [int]::TryParse($deltaText, [ref]$delta)) {
        Write-LWWarn 'Please enter a whole number, such as 10 or -4.'
        return
    }
    Update-LWGold -Delta $delta
}

function Get-LWBackpackItemCount {
    param([Parameter(Mandatory = $true)][string]$Name)
    return (@($script:GameState.Inventory.BackpackItems | Where-Object { $_ -ieq $Name }).Count)
}

function Use-LWMeal {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $consumeMeal = $true
    if (Test-LWDiscipline -Name 'Hunting') {
        $isWasteland = Read-LWYesNo -Prompt 'Are you in a wasteland or desert where Hunting does not help?' -Default $false
        if (-not $isWasteland) {
            Register-LWMealCoveredByHunting
            Write-LWInfo 'Hunting covers the meal. No backpack item spent.'
            return
        }
    }

    if ($consumeMeal) {
        if ((Get-LWBackpackItemCount -Name 'Meal') -gt 0) {
            Remove-LWInventoryItem -Type 'backpack' -Name 'Meal' -Quantity 1
            Register-LWMealConsumed
            Write-LWInfo 'Meal consumed.'
            return
        }

        Write-LWWarn 'No Meal available. Lose 3 Endurance.'
        Register-LWStarvationPenalty
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'starvation'
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent -= [int]$lossResolution.AppliedLoss
        if ($script:GameState.Character.EnduranceCurrent -lt 0) {
            $script:GameState.Character.EnduranceCurrent = 0
        }
        Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
            Write-LWInfo ([string]$lossResolution.Note)
        }
        Write-LWInfo "Endurance now $($script:GameState.Character.EnduranceCurrent)."
        if (Invoke-LWFatalEnduranceCheck -Cause 'Starved to death after failing to find a meal.') {
            return
        }
        Invoke-LWMaybeAutosave
    }
}

function Use-LWHealingPotion {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($script:GameState.Combat.Active) {
        Write-LWWarn 'Healing Potions cannot be used during combat.'
        return
    }

    $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWConcentratedHealingPotionItemNames) -Type 'backpack'
    $restoreAmount = 8
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWHealingPotionItemNames) -Type 'backpack'
        $restoreAmount = 4
    }

    if ([string]::IsNullOrWhiteSpace($potionName)) {
        Write-LWWarn 'No Healing, Laumspur, or Concentrated Laumspur Potion found in backpack items.'
        return
    }

    Remove-LWInventoryItem -Type 'backpack' -Name $potionName -Quantity 1
    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent += $restoreAmount
    if ($script:GameState.Character.EnduranceCurrent -gt $script:GameState.Character.EnduranceMax) {
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    }
    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
    Add-LWBookEnduranceDelta -Delta $restored
    Register-LWPotionUsed -PotionName $potionName -EnduranceRestored $restored
    Write-LWInfo "$potionName restores $restoreAmount Endurance. Current Endurance: $($script:GameState.Character.EnduranceCurrent)."
    Invoke-LWMaybeAutosave
}

function Get-LWStateAletherPotionName {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWAletherPotionItemNames) -Type 'backpack')
}

function Get-LWStateAletherCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWCombatAletherAvailable -State $State)) {
        return 0
    }

    return [int]$State.Combat.AletherCombatSkillBonus
}

function Get-LWCombatBreakdownFromState {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not $State.Combat.Active) {
        return $null
    }

    $playerCombatSkill = [int]$State.Character.CombatSkillBase
    $enemyCombatSkill = [int]$State.Combat.EnemyCombatSkill
    $notes = @()

    $shieldBonus = Get-LWStateShieldCombatSkillBonus -State $State
    if ($shieldBonus -gt 0) {
        $playerCombatSkill += $shieldBonus
        $notes += "Shield +$shieldBonus"
    }

    $silverHelmBonus = Get-LWStateSilverHelmCombatSkillBonus -State $State
    if ($silverHelmBonus -gt 0) {
        $playerCombatSkill += $silverHelmBonus
        $notes += "Silver Helm +$silverHelmBonus"
    }

    if ($State.Combat.UseMindblast) {
        $playerCombatSkill += 2
        $notes += 'Mindblast +2'
    }

    $aletherBonus = Get-LWStateAletherCombatSkillBonus -State $State
    if ($aletherBonus -gt 0) {
        $playerCombatSkill += $aletherBonus
        $notes += "Alether +$aletherBonus"
    }

    $knockoutPenalty = Get-LWCombatKnockoutCombatSkillPenalty -State $State
    if ([bool]$State.Combat.AttemptKnockout) {
        if ($knockoutPenalty -gt 0) {
            $playerCombatSkill -= $knockoutPenalty
            $notes += "Knockout attempt -$knockoutPenalty"
        }
        else {
            $notes += 'Knockout attempt (no CS penalty)'
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$State.Combat.EquippedWeapon)) {
        $playerCombatSkill -= 4
        $notes += 'Unarmed -4'
    }
    elseif (Test-LWWeaponIsSommerswerd -Weapon ([string]$State.Combat.EquippedWeapon)) {
        if (-not (Test-LWCombatSommerswerdAvailable -State $State)) {
            $notes += 'Sommerswerd unavailable before Book 2'
        }
        elseif ([bool]$State.Combat.SommerswerdSuppressed) {
            $notes += 'Sommerswerd suppressed'

            $fallbackBonus = Get-LWStateSommerswerdFallbackWeaponskillBonus -State $State
            if ($fallbackBonus -gt 0) {
                $playerCombatSkill += $fallbackBonus
                $notes += "Weaponskill +$fallbackBonus (Sommerswerd as sword)"
            }
        }
        else {
            $sommerswerdBonus = Get-LWStateSommerswerdCombatSkillBonus -State $State
            if ($sommerswerdBonus -gt 0) {
                $playerCombatSkill += $sommerswerdBonus
                if ($sommerswerdBonus -ge 10) {
                    $notes += "Sommerswerd +$sommerswerdBonus (Weaponskill)"
                }
                else {
                    $notes += "Sommerswerd +$sommerswerdBonus"
                }
            }
            if ([bool]$State.Combat.EnemyIsUndead) {
                $notes += 'Undead damage x2'
            }
        }
    }
    elseif (Test-LWWeaponIsBoneSword -Weapon ([string]$State.Combat.EquippedWeapon)) {
        $boneSwordBonus = Get-LWStateBoneSwordCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($boneSwordBonus -gt 0) {
            $playerCombatSkill += $boneSwordBonus
            $notes += "Bone Sword +$boneSwordBonus (Kalte)"
        }
        else {
            $notes += 'Bone Sword inactive outside Kalte'
        }
    }
    elseif ((Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') -and -not [string]::IsNullOrWhiteSpace([string]$State.Character.WeaponskillWeapon) -and $State.Combat.EquippedWeapon -ieq $State.Character.WeaponskillWeapon) {
        $playerCombatSkill += 2
        $notes += "Weaponskill +2 ($($State.Combat.EquippedWeapon))"
    }

    if ([bool]$State.Combat.EnemyUsesMindforce) {
        if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
            $notes += 'Mindforce blocked by Mindshield'
        }
        else {
            $notes += 'Mindforce -2 END each round'
        }
    }

    if ([int]$State.Combat.PlayerCombatSkillModifier -ne 0) {
        $playerCombatSkill += [int]$State.Combat.PlayerCombatSkillModifier
        $notes += "Player modifier $(Format-LWSigned -Value ([int]$State.Combat.PlayerCombatSkillModifier))"
    }

    if ([int]$State.Combat.EnemyCombatSkillModifier -ne 0) {
        $enemyCombatSkill += [int]$State.Combat.EnemyCombatSkillModifier
        $notes += "Enemy modifier $(Format-LWSigned -Value ([int]$State.Combat.EnemyCombatSkillModifier))"
    }

    return [pscustomobject]@{
        PlayerCombatSkill = $playerCombatSkill
        EnemyCombatSkill  = $enemyCombatSkill
        CombatRatio       = ($playerCombatSkill - $enemyCombatSkill)
        Notes             = $notes
    }
}

function Get-LWCombatBreakdown {
    if (-not $script:GameState.Combat.Active) {
        return $null
    }

    return (Get-LWCombatBreakdownFromState -State $script:GameState)
}

function Get-LWNearestSupportedValue {
    param(
        [int]$Value,
        [int[]]$Supported
    )

    if ($Supported.Count -eq 0) {
        return $Value
    }

    $sorted = @($Supported | Sort-Object)
    if ($Value -le $sorted[0]) {
        return $sorted[0]
    }
    if ($Value -ge $sorted[$sorted.Count - 1]) {
        return $sorted[$sorted.Count - 1]
    }

    foreach ($candidate in $sorted) {
        if ($candidate -eq $Value) {
            return $candidate
        }
    }

    $best = $sorted[0]
    $bestDelta = [Math]::Abs($Value - $best)
    foreach ($candidate in $sorted) {
        $delta = [Math]::Abs($Value - $candidate)
        if ($delta -lt $bestDelta) {
            $best = $candidate
            $bestDelta = $delta
        }
    }
    return $best
}

function Get-LWCRTResult {
    param(
        [Parameter(Mandatory = $true)][int]$Ratio,
        [Parameter(Mandatory = $true)][int]$Roll
    )

    if ($null -eq $script:GameData.CRT) {
        return $null
    }

    $ratioKeys = @()
    foreach ($property in $script:GameData.CRT.PSObject.Properties) {
        $value = 0
        if ([int]::TryParse($property.Name, [ref]$value)) {
            $ratioKeys += $value
        }
    }

    if ($ratioKeys.Count -eq 0) {
        return $null
    }

    $ratioKey = Get-LWNearestSupportedValue -Value $Ratio -Supported $ratioKeys
    $ratioNode = Get-LWJsonProperty -Object $script:GameData.CRT -Name ([string]$ratioKey)
    if ($null -eq $ratioNode) {
        return $null
    }

    $entry = Get-LWJsonProperty -Object $ratioNode -Name ([string]$Roll)
    if ($null -eq $entry) {
        return $null
    }

    return [pscustomobject]@{
        RatioKey      = $ratioKey
        EnemyLossRaw  = (Get-LWJsonProperty -Object $entry -Name 'EnemyLoss')
        PlayerLossRaw = (Get-LWJsonProperty -Object $entry -Name 'PlayerLoss')
    }
}

function Select-LWCombatWeapon {
    param([string]$DefaultWeapon = $null)

    $weapons = @(Get-LWStateCombatWeapons -State $script:GameState)
    if ($weapons.Count -eq 0) {
        Write-LWWarn 'No weapons carried. Combat will be unarmed unless you add one.'
        return $null
    }

    if ($weapons.Count -eq 1) {
        Write-LWInfo "Using your only available combat weapon: $($weapons[0])."
        return [string]$weapons[0]
    }

    if ([string]::IsNullOrWhiteSpace($DefaultWeapon)) {
        $DefaultWeapon = Get-LWPreferredCombatWeapon -State $script:GameState
    }

    $defaultIndex = 1
    if (-not [string]::IsNullOrWhiteSpace($DefaultWeapon)) {
        for ($i = 0; $i -lt $weapons.Count; $i++) {
            if ($weapons[$i] -ieq $DefaultWeapon) {
                $defaultIndex = $i + 1
                break
            }
        }
    }

    if ($script:LWUi.Enabled) {
        $currentData = $script:LWUi.ScreenData
        $enemyName = if ($null -ne $currentData -and (Test-LWPropertyExists -Object $currentData -Name 'EnemyName')) { $currentData.EnemyName } else { $null }
        $enemyCombatSkill = if ($null -ne $currentData -and (Test-LWPropertyExists -Object $currentData -Name 'EnemyCombatSkill')) { $currentData.EnemyCombatSkill } else { $null }
        $enemyEndurance = if ($null -ne $currentData -and (Test-LWPropertyExists -Object $currentData -Name 'EnemyEndurance')) { $currentData.EnemyEndurance } else { $null }

        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View             = 'setup'
                EnemyName        = $enemyName
                EnemyCombatSkill = $enemyCombatSkill
                EnemyEndurance   = $enemyEndurance
                Weapons          = @($weapons)
                DefaultIndex     = $defaultIndex
            })
    }

    while ($true) {
        $choice = Read-LWInt -Prompt 'Weapon number' -Default $defaultIndex -Min 0 -Max $weapons.Count
        if ($choice -eq 0) {
            return $null
        }
        return [string]$weapons[$choice - 1]
    }
}

function Get-LWCombatDisplayWeapon {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return 'Unarmed'
    }
    if (Test-LWWeaponIsBoneSword -Weapon $Weapon) {
        return 'Bone Sword'
    }

    return $Weapon
}

function Show-LWCombatPromptHint {
    if (-not $script:GameState.Combat.Active) {
        return
    }

    Write-LWPanelHeader -Title 'Next Action' -AccentColor 'DarkYellow'
    Write-LWBulletItem -Text 'Press Enter to resolve the next round.' -TextColor 'Gray' -BulletColor 'Yellow'
    Write-LWBulletItem -Text 'Use combat auto to finish the fight quickly.' -TextColor 'Gray' -BulletColor 'Cyan'
    Write-LWBulletItem -Text 'Use combat log for the full round history.' -TextColor 'Gray' -BulletColor 'DarkRed'
    if ($script:GameState.Combat.CanEvade) {
        Write-LWBulletItem -Text 'Use combat evade if you choose to break away.' -TextColor 'Gray' -BulletColor 'DarkYellow'
    }
}

function Get-LWCombatMeterText {
    param(
        [int]$Current,
        [int]$Max,
        [int]$Width = 18
    )

    $safeMax = [Math]::Max(1, $Max)
    $clampedCurrent = [Math]::Max(0, [Math]::Min($Current, $safeMax))
    $filled = [Math]::Round(($clampedCurrent / [double]$safeMax) * $Width)
    if ($filled -lt 0) {
        $filled = 0
    }
    if ($filled -gt $Width) {
        $filled = $Width
    }

    return ('[' + ('#' * $filled) + ('.' * ($Width - $filled)) + ']')
}

function Write-LWCombatMeterLine {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][int]$Current,
        [Parameter(Mandatory = $true)][int]$Max,
        [Parameter(Mandatory = $true)][int]$CombatSkill,
        [string]$LabelColor = 'White'
    )

    $displayLabel = if ($Label.Length -gt 14) { ($Label.Substring(0, 12) + '..') } else { $Label }
    $meterColor = Get-LWEnduranceColor -Current $Current -Max $Max
    $meterText = Get-LWCombatMeterText -Current $Current -Max $Max

    Write-Host ("  {0,-14}" -f $displayLabel) -NoNewline -ForegroundColor $LabelColor
    Write-Host (" CS {0,-3}" -f $CombatSkill) -NoNewline -ForegroundColor Cyan
    Write-Host (" END {0,2}/{1,-2} " -f $Current, $Max) -NoNewline -ForegroundColor $meterColor
    Write-Host $meterText -ForegroundColor $meterColor
}

function Write-LWCombatRoundLine {
    param([Parameter(Mandatory = $true)][object]$Round)

    $crtSuffix = ''
    if ((Test-LWPropertyExists -Object $Round -Name 'CRTColumn') -and $null -ne $Round.CRTColumn -and [int]$Round.CRTColumn -ne [int]$Round.Ratio) {
        $crtSuffix = " -> CRT $($Round.CRTColumn)"
    }

    Write-Host ("  R{0,-2}" -f $Round.Round) -NoNewline -ForegroundColor DarkYellow
    Write-Host (" ratio {0,3}" -f (Format-LWSigned -Value ([int]$Round.Ratio))) -NoNewline -ForegroundColor (Get-LWCombatRatioColor -Ratio ([int]$Round.Ratio))
    Write-Host ("  roll {0}{1}" -f $Round.Roll, $crtSuffix) -NoNewline -ForegroundColor Gray
    Write-Host ("  enemy -{0}" -f $Round.EnemyLoss) -NoNewline -ForegroundColor Red
    if ((Test-LWPropertyExists -Object $Round -Name 'SpecialNote') -and -not [string]::IsNullOrWhiteSpace([string]$Round.SpecialNote)) {
        Write-Host (" [{0}]" -f [string]$Round.SpecialNote) -NoNewline -ForegroundColor DarkYellow
    }
    Write-Host ("  Lone Wolf -{0}" -f $Round.PlayerLoss) -NoNewline -ForegroundColor Red
    Write-Host ("  END {0}/{1}" -f $Round.PlayerEnd, $Round.EnemyEnd) -ForegroundColor DarkGray
}

function Show-LWCombatRecentRounds {
    param(
        [object[]]$Rounds = @(),
        [int]$Count = 3,
        [string]$Title = 'Recent Rounds'
    )

    Write-LWPanelHeader -Title $Title -AccentColor 'DarkRed'
    $rounds = @($Rounds)
    if ($rounds.Count -eq 0) {
        Write-LWSubtle '  No rounds resolved yet.'
        return
    }

    $start = [Math]::Max(0, $rounds.Count - $Count)
    foreach ($round in @($rounds[$start..($rounds.Count - 1)])) {
        Write-LWCombatRoundLine -Round $round
    }
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

    Write-LWPanelHeader -Title $Title -AccentColor 'Red'
    Write-LWCombatMeterLine -Label 'Lone Wolf' -Current $PlayerCurrent -Max $PlayerMax -CombatSkill $PlayerCombatSkill -LabelColor 'White'
    Write-LWCombatMeterLine -Label $EnemyName -Current $EnemyCurrent -Max $EnemyMax -CombatSkill $EnemyCombatSkill -LabelColor 'Gray'
    Write-Host ''
    if ($null -ne $RoundCount) {
        Write-LWKeyValue -Label 'Rounds' -Value ([string]$RoundCount) -ValueColor 'Gray'
    }
    Write-LWKeyValue -Label 'Combat Ratio' -Value (Format-LWSigned -Value $CombatRatio) -ValueColor (Get-LWCombatRatioColor -Ratio $CombatRatio)
}

function Show-LWCombatTacticalPanel {
    param(
        [Parameter(Mandatory = $true)][string]$Weapon,
        [Parameter(Mandatory = $true)][bool]$UseMindblast,
        [Parameter(Mandatory = $true)][bool]$EnemyIsUndead,
        [Parameter(Mandatory = $true)][string]$MindforceStatus,
        [Parameter(Mandatory = $true)][string]$KnockoutStatus,
        [Parameter(Mandatory = $true)][bool]$CanEvade,
        [Parameter(Mandatory = $true)][string]$Mode,
        [object[]]$Notes = @(),
        [switch]$UsesSommerswerd,
        [switch]$SommerswerdSuppressed
    )

    Write-LWPanelHeader -Title 'Tactical Readout' -AccentColor 'DarkYellow'
    Write-LWKeyValue -Label 'Weapon' -Value $Weapon -ValueColor 'Gray'
    Write-LWKeyValue -Label 'Mindblast' -Value $(if ($UseMindblast) { 'On' } else { 'Off' }) -ValueColor $(if ($UseMindblast) { 'Cyan' } else { 'Gray' })
    Write-LWKeyValue -Label 'Undead Enemy' -Value $(if ($EnemyIsUndead) { 'Yes' } else { 'No' }) -ValueColor $(if ($EnemyIsUndead) { 'DarkYellow' } else { 'Gray' })
    $mindforceColor = 'Gray'
    if ($MindforceStatus -like 'Active*') {
        $mindforceColor = 'Red'
    }
    elseif ($MindforceStatus -like 'Blocked*') {
        $mindforceColor = 'Cyan'
    }
    Write-LWKeyValue -Label 'Mindforce' -Value $MindforceStatus -ValueColor $mindforceColor
    $knockoutColor = if ($KnockoutStatus -like 'Attempt*') { 'Yellow' } else { 'Gray' }
    Write-LWKeyValue -Label 'Knockout' -Value $KnockoutStatus -ValueColor $knockoutColor
    if ($UsesSommerswerd) {
        $sommerswerdStatus = if ($SommerswerdSuppressed) { 'Suppressed' } elseif ($EnemyIsUndead) { 'Active (undead x2)' } else { 'Active' }
        Write-LWKeyValue -Label 'Sommerswerd' -Value $sommerswerdStatus -ValueColor $(if ($SommerswerdSuppressed) { 'Yellow' } else { 'DarkYellow' })
    }
    Write-LWKeyValue -Label 'Evade Allowed' -Value $(if ($CanEvade) { 'Yes' } else { 'No' }) -ValueColor $(if ($CanEvade) { 'Yellow' } else { 'Gray' })
    Write-LWKeyValue -Label 'Mode' -Value $Mode -ValueColor (Get-LWModeColor -Mode $Mode)

    $notes = @($Notes)
    Write-Host ''
    if ($notes.Count -eq 0) {
        Write-LWSubtle '  No active modifiers.'
    }
    else {
        Write-LWSubtle '  Active modifiers:'
        foreach ($note in $notes) {
            Write-LWBulletItem -Text ([string]$note) -TextColor 'Gray' -BulletColor 'DarkYellow'
        }
    }
}

function Get-LWCurrentCombatLogEntry {
    if (-not $script:GameState.Combat.Active) {
        return $null
    }

    return [pscustomobject]@{
        BookNumber = [int]$script:GameState.Character.BookNumber
        BookTitle  = [string](Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber))
        EnemyName  = $script:GameState.Combat.EnemyName
        Outcome    = 'In Progress'
        RoundCount = @($script:GameState.Combat.Log).Count
        PlayerEnd  = $script:GameState.Character.EnduranceCurrent
        EnemyEnd   = $script:GameState.Combat.EnemyEnduranceCurrent
        EnemyUsesMindforce = [bool]$script:GameState.Combat.EnemyUsesMindforce
        MindforceBlockedByMindshield = [bool](Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)
        AletherCombatSkillBonus = [int]$script:GameState.Combat.AletherCombatSkillBonus
        AttemptKnockout = [bool]$script:GameState.Combat.AttemptKnockout
        Log        = @($script:GameState.Combat.Log)
    }
}

function Write-LWCombatLogEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Entry,
        [string]$TitleSuffix = ''
    )

    $title = if ([string]::IsNullOrWhiteSpace($TitleSuffix)) {
        "Combat Log: $($Entry.EnemyName)"
    }
    else {
        "Combat Log {0}: {1}" -f $TitleSuffix, $Entry.EnemyName
    }

    Write-LWPanelHeader -Title $title -AccentColor 'DarkRed'
    Write-LWKeyValue -Label 'Outcome' -Value $Entry.Outcome -ValueColor (Get-LWOutcomeColor -Outcome $Entry.Outcome)
    if (@($Entry.Log).Count -eq 0) {
        Write-LWSubtle '  (no rounds logged)'
        return
    }

    foreach ($round in @($Entry.Log)) {
        Write-LWCombatRoundLine -Round $round
    }
}

function Show-LWCombatLog {
    param(
        [object]$Entry = $null,
        [Nullable[int]]$HistoryIndex = $null,
        [Nullable[int]]$BookNumber = $null,
        [switch]$All
    )

    if ($All) {
        $history = @($script:GameState.History)
        $activeEntry = Get-LWCurrentCombatLogEntry
        $renderedCount = 0
        $currentBookKey = $null

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
                Write-LWCombatArchiveBookHeader -Entry $history[$i]
                $currentBookKey = $bookKey
            }
            Write-LWCombatLogEntry -Entry $history[$i] -TitleSuffix ("#{0}" -f ($i + 1))
            $renderedCount++
        }

        if ($null -ne $activeEntry) {
            $activeBookKey = Get-LWCombatEntryBookKey -Entry $activeEntry
            if ($activeBookKey -ne $currentBookKey) {
                Write-LWCombatArchiveBookHeader -Entry $activeEntry
            }
            Write-LWCombatLogEntry -Entry $activeEntry -TitleSuffix '(Current)'
            $renderedCount++
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
    $mindforceStatus = if (-not $enemyUsesMindforce) { 'Off' } elseif ($mindforceBlocked) { 'Blocked by Mindshield' } else { 'Active (-2 END/round)' }
    $knockoutStatus = if ((Test-LWPropertyExists -Object $Summary -Name 'AttemptKnockout') -and [bool]$Summary.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }

    Write-LWPanelHeader -Title 'Combat Summary' -AccentColor 'DarkRed'
    Write-LWKeyValue -Label 'Enemy' -Value $Summary.EnemyName -ValueColor 'White'
    Write-LWKeyValue -Label 'Outcome' -Value $Summary.Outcome -ValueColor (Get-LWOutcomeColor -Outcome $Summary.Outcome)
    Show-LWCombatDuelPanel -Title 'Aftermath' -EnemyName ([string]$Summary.EnemyName) -PlayerCurrent ([int]$Summary.PlayerEnd) -PlayerMax $playerEndMax -EnemyCurrent ([int]$Summary.EnemyEnd) -EnemyMax $enemyEndMax -PlayerCombatSkill $playerCombatSkill -EnemyCombatSkill $enemyCombatSkill -CombatRatio $ratio -RoundCount ([int]$Summary.RoundCount)
    Show-LWCombatTacticalPanel -Weapon $weapon -UseMindblast:$useMindblast -EnemyIsUndead:$enemyUndead -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -CanEvade:$canEvade -Mode $mode -Notes $notes -UsesSommerswerd:$usingSommerswerd -SommerswerdSuppressed:([bool]((Test-LWPropertyExists -Object $Summary -Name 'SommerswerdSuppressed') -and [bool]$Summary.SommerswerdSuppressed))
    Show-LWCombatRecentRounds -Rounds @($Summary.Log) -Count 5 -Title 'Round Recap'
    Write-LWSubtle '  Use combat log for the full round-by-round archive.'
}

function Show-LWCombatStatus {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return
    }

    $breakdown = Get-LWCombatBreakdown
    $mindforceStatus = if (-not [bool]$script:GameState.Combat.EnemyUsesMindforce) { 'Off' } elseif (Test-LWCombatMindforceBlockedByMindshield -State $script:GameState) { 'Blocked by Mindshield' } else { 'Active (-2 END/round)' }
    $knockoutStatus = if ([bool]$script:GameState.Combat.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }
    Write-LWPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWKeyValue -Label 'Enemy' -Value $script:GameState.Combat.EnemyName -ValueColor 'White'
    Show-LWCombatDuelPanel -EnemyName ([string]$script:GameState.Combat.EnemyName) -PlayerCurrent ([int]$script:GameState.Character.EnduranceCurrent) -PlayerMax ([int]$script:GameState.Character.EnduranceMax) -EnemyCurrent ([int]$script:GameState.Combat.EnemyEnduranceCurrent) -EnemyMax ([int]$script:GameState.Combat.EnemyEnduranceMax) -PlayerCombatSkill ([int]$breakdown.PlayerCombatSkill) -EnemyCombatSkill ([int]$breakdown.EnemyCombatSkill) -CombatRatio ([int]$breakdown.CombatRatio) -RoundCount (@($script:GameState.Combat.Log).Count)
    Show-LWCombatTacticalPanel -Weapon (Get-LWCombatDisplayWeapon -Weapon $script:GameState.Combat.EquippedWeapon) -UseMindblast:([bool]$script:GameState.Combat.UseMindblast) -EnemyIsUndead:([bool]$script:GameState.Combat.EnemyIsUndead) -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -CanEvade:([bool]$script:GameState.Combat.CanEvade) -Mode ([string]$script:GameState.Settings.CombatMode) -Notes @($breakdown.Notes) -UsesSommerswerd:(Test-LWCombatUsesSommerswerd -State $script:GameState) -SommerswerdSuppressed:([bool]$script:GameState.Combat.SommerswerdSuppressed)
    Show-LWCombatRecentRounds -Rounds @($script:GameState.Combat.Log) -Count 3
    Show-LWCombatPromptHint
}

function Resolve-LWCombatRound {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Roll,
        [Nullable[int]]$EnemyLoss = $null,
        [Nullable[int]]$PlayerLoss = $null,
        [switch]$UseCRT
    )

    if (-not $State.Combat.Active) {
        return $null
    }

    $breakdown = Get-LWCombatBreakdownFromState -State $State
    $roundNumber = @($State.Combat.Log).Count + 1
    $messages = @()
    $crtResult = $null
    $crtColumn = $null
    $usedCRT = $false

    if ($UseCRT) {
        $crtResult = Get-LWCRTResult -Ratio $breakdown.CombatRatio -Roll $Roll
        if ($null -eq $crtResult) {
            $messages += 'CRT data is missing this result. Falling back to manual entry.'
        }
        else {
            $EnemyLoss = Convert-LWCRTLossValue -Value $crtResult.EnemyLossRaw -CurrentEndurance ([int]$State.Combat.EnemyEnduranceCurrent)
            $PlayerLoss = Convert-LWCRTLossValue -Value $crtResult.PlayerLossRaw -CurrentEndurance ([int]$State.Character.EnduranceCurrent)
            if ($null -eq $EnemyLoss -or $null -eq $PlayerLoss) {
                $messages += 'CRT data contains an invalid result. Falling back to manual entry.'
                $EnemyLoss = $null
                $PlayerLoss = $null
            }
            $crtColumn = $crtResult.RatioKey
            if ($null -ne $EnemyLoss -and $null -ne $PlayerLoss) {
                $usedCRT = $true
                if ([string]$crtResult.EnemyLossRaw -eq 'K' -or [string]$crtResult.PlayerLossRaw -eq 'K') {
                    $messages += 'CRT produced an automatic kill result.'
                }
                if ($crtColumn -ne $breakdown.CombatRatio) {
                    $messages += "Combat ratio matched nearest available CRT column: $crtColumn."
                }
            }
        }
    }

    if ($null -eq $EnemyLoss -or $null -eq $PlayerLoss) {
        return [pscustomobject]@{
            RequiresManualEntry = $true
            Breakdown           = $breakdown
            RoundNumber         = $roundNumber
            Roll                = $Roll
            UsedCRT             = $usedCRT
            CRTColumn           = $crtColumn
            Messages            = @($messages)
            Outcome             = 'AwaitingInput'
        }
    }

    $playerLossResolution = Resolve-LWGameplayEnduranceLoss -Loss ([int]$PlayerLoss) -Source 'combat' -State $State
    $baseEnemyLoss = [int]$EnemyLoss
    $enemyLossApplied = $baseEnemyLoss
    $combatPlayerLossApplied = [int]$playerLossResolution.AppliedLoss
    $currentPlayerEnd = [int]$State.Character.EnduranceCurrent
    $mindforceBaseLoss = 0
    $mindforceAppliedLoss = 0
    $specialNotes = @()

    if (Test-LWCombatSommerswerdUndeadDoubleDamageActive -State $State) {
        $enemyLossApplied = [Math]::Min([int]$State.Combat.EnemyEnduranceCurrent, ($baseEnemyLoss * 2))
        if ($enemyLossApplied -gt $baseEnemyLoss) {
            $specialNotes += 'Undead x2'
            $messages += "Sommerswerd doubles damage against undead: enemy loses $enemyLossApplied instead of $baseEnemyLoss."
        }
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$playerLossResolution.Note)) {
        $messages += [string]$playerLossResolution.Note
    }

    if (Test-LWCombatUsesMindforce -State $State) {
        $mindforceBaseLoss = 2
        if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
            $specialNotes += 'Mindshield'
            $messages += 'Mindshield blocks the enemy''s Mindforce.'
        }
        else {
            $mindforceResolution = Resolve-LWGameplayEnduranceLoss -Loss $mindforceBaseLoss -Source 'mindforce' -State $State
            $remainingAfterCombat = [Math]::Max(0, ($currentPlayerEnd - $combatPlayerLossApplied))
            $mindforceAppliedLoss = [Math]::Min($remainingAfterCombat, [int]$mindforceResolution.AppliedLoss)
            if ($mindforceAppliedLoss -gt 0) {
                $specialNotes += 'Mindforce'
                $messages += "Enemy Mindforce inflicts $mindforceAppliedLoss END."
            }
            else {
                $messages += 'Enemy Mindforce surges, but no END is lost.'
            }
            if (-not [string]::IsNullOrWhiteSpace([string]$mindforceResolution.Note)) {
                $messages += [string]$mindforceResolution.Note
            }
        }
    }

    $totalPlayerLossApplied = $combatPlayerLossApplied + $mindforceAppliedLoss
    $totalPlayerLossBase = [int]$PlayerLoss + $mindforceBaseLoss
    $newEnemyEnd = [Math]::Max(0, ([int]$State.Combat.EnemyEnduranceCurrent - $enemyLossApplied))
    $newPlayerEnd = [Math]::Max(0, ($currentPlayerEnd - $totalPlayerLossApplied))
    $outcome = 'Continue'
    if ($newPlayerEnd -le 0) {
        $outcome = 'Defeat'
    }
    elseif ($newEnemyEnd -le 0) {
        if ([bool]$State.Combat.AttemptKnockout) {
            $outcome = 'Knockout'
            $messages += ("{0} is knocked unconscious." -f [string]$State.Combat.EnemyName)
            $specialNotes += 'Knockout'
        }
        else {
            $outcome = 'Victory'
        }
    }

    return [pscustomobject]@{
        RequiresManualEntry = $false
        Breakdown           = $breakdown
        RoundNumber         = $roundNumber
        Roll                = $Roll
        EnemyLoss           = $enemyLossApplied
        EnemyLossBase       = $baseEnemyLoss
        PlayerLoss          = $totalPlayerLossApplied
        PlayerLossBase      = $totalPlayerLossBase
        MindforceLoss       = $mindforceAppliedLoss
        MindforceLossBase   = $mindforceBaseLoss
        NewEnemyEnd         = $newEnemyEnd
        NewPlayerEnd        = $newPlayerEnd
        UsedCRT             = $usedCRT
        CRTColumn           = $crtColumn
        Messages            = @($messages)
        Outcome             = $outcome
        LogEntry            = [pscustomobject]@{
            Round      = $roundNumber
            Ratio      = $breakdown.CombatRatio
            Roll       = $Roll
            CRTColumn  = $crtColumn
            EnemyLoss  = $enemyLossApplied
            EnemyLossBase = $baseEnemyLoss
            PlayerLoss = $totalPlayerLossApplied
            PlayerLossBase = $totalPlayerLossBase
            MindforceLoss = $mindforceAppliedLoss
            MindforceLossBase = $mindforceBaseLoss
            EnemyEnd   = $newEnemyEnd
            PlayerEnd  = $newPlayerEnd
            SpecialNote = $(if ($specialNotes.Count -gt 0) { $specialNotes -join ', ' } else { $null })
        }
    }
}

function Apply-LWCombatRoundResolution {
    param([Parameter(Mandatory = $true)][object]$Resolution)

    $script:GameState.Combat.EnemyEnduranceCurrent = $Resolution.NewEnemyEnd
    $script:GameState.Character.EnduranceCurrent = $Resolution.NewPlayerEnd
    $script:GameState.Combat.Log = @($script:GameState.Combat.Log) + $Resolution.LogEntry
    if ([int]$Resolution.PlayerLoss -gt 0) {
        Add-LWBookEnduranceDelta -Delta (-[int]$Resolution.PlayerLoss)
    }
}

function Start-LWCombat {
    param([string[]]$Arguments = @())

    if ($null -eq $Arguments) {
        $Arguments = @()
    }
    else {
        $Arguments = @($Arguments)
    }

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return $false
    }
    if ($script:GameState.Combat.Active) {
        Write-LWWarn 'A combat is already active.'
        return $false
    }

    Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
            View = 'setup'
        })

    $quickStart = Get-LWCombatStartArguments -Arguments $Arguments
    $useQuickDefaults = $false
    if ($null -ne $quickStart) {
        $enemyName = $quickStart.EnemyName
        $enemyCombatSkill = $quickStart.EnemyCombatSkill
        $enemyEndurance = $quickStart.EnemyEndurance
        Write-LWInfo "Quick combat setup: $enemyName (CS $enemyCombatSkill, END $enemyEndurance)."
        $useQuickDefaults = Read-LWYesNo -Prompt 'Use default combat assumptions for the rest of setup?' -Default $true
    }
    else {
        $enemyName = Read-LWText -Prompt 'Enemy name'
        $enemyCombatSkill = Read-LWInt -Prompt 'Enemy Combat Skill' -Min 0
        $enemyEndurance = Read-LWInt -Prompt 'Enemy Endurance' -Min 1
    }

    Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
            View             = 'setup'
            EnemyName        = $enemyName
            EnemyCombatSkill = $enemyCombatSkill
            EnemyEndurance   = $enemyEndurance
        })

    $enemyImmune = $false
    $enemyUndead = $false
    $enemyUsesMindforce = $false
    $canEvade = $false
    if (-not $useQuickDefaults) {
        $enemyImmune = Read-LWYesNo -Prompt 'Is the enemy immune to Mindblast?' -Default $false
        $enemyUndead = Read-LWYesNo -Prompt 'Is the enemy undead?' -Default $false
        $enemyUsesMindforce = Read-LWYesNo -Prompt 'Is the enemy attacking with Mindforce each combat round?' -Default $false
        $canEvade = Read-LWYesNo -Prompt 'Can Lone Wolf evade this combat if desired?' -Default $false
    }

    $equippedWeapon = Select-LWCombatWeapon -DefaultWeapon (Get-LWPreferredCombatWeapon -State $script:GameState)
    $sommerswerdSuppressed = $false
    $aletherCombatSkillBonus = 0
    $attemptKnockout = $false
    if (Test-LWCombatAletherAvailable -State $script:GameState) {
        $aletherPotionName = Get-LWStateAletherPotionName -State $script:GameState
        if (-not [string]::IsNullOrWhiteSpace($aletherPotionName)) {
            $useAlether = Read-LWYesNo -Prompt 'Use Alether before this fight for +4 Combat Skill?' -Default $false
            if ($useAlether) {
                Remove-LWInventoryItem -Type 'backpack' -Name $aletherPotionName -Quantity 1
                $aletherCombatSkillBonus = 4
                Write-LWInfo "$aletherPotionName is used before combat and grants +4 Combat Skill for this fight."
            }
        }
    }
    if (Test-LWWeaponIsSommerswerd -Weapon $equippedWeapon) {
        if ((Get-LWCurrentDifficulty) -eq 'Veteran') {
            $textAllowsSommerswerd = Read-LWYesNo -Prompt 'Does the text explicitly allow the Sommerswerd''s power in this combat?' -Default $false
            if (-not $textAllowsSommerswerd) {
                $sommerswerdSuppressed = $true
                Write-LWWarn 'Veteran mode suppresses the Sommerswerd unless the text explicitly allows it.'
            }
        }

        if (-not $sommerswerdSuppressed -and -not $useQuickDefaults) {
            $sommerswerdSuppressed = Read-LWYesNo -Prompt 'Is the Sommerswerd suppressed or unable to function in this combat?' -Default $false
        }
    }

    if (Test-LWCombatKnockoutAvailable -State $script:GameState) {
        $attemptKnockout = Read-LWYesNo -Prompt 'Try to knock this foe unconscious?' -Default $false
        if ($attemptKnockout) {
            $knockoutPenalty = Get-LWCombatKnockoutCombatSkillPenalty -State ([pscustomobject]@{
                    Character = $script:GameState.Character
                    Combat    = [pscustomobject]@{
                        AttemptKnockout = $true
                        EquippedWeapon  = $equippedWeapon
                    }
                }) -Weapon $equippedWeapon
            if ($knockoutPenalty -gt 0) {
                Write-LWWarn "Knockout attempt will apply -$knockoutPenalty Combat Skill with $((Get-LWCombatDisplayWeapon -Weapon $equippedWeapon))."
            }
            else {
                Write-LWInfo 'Knockout attempt has no extra Combat Skill penalty with this weapon.'
            }
        }
    }

    $useMindblast = $false
    if ((Test-LWDiscipline -Name 'Mindblast') -and -not $enemyImmune) {
        if ($useQuickDefaults) {
            $useMindblast = $true
            Write-LWInfo 'Mindblast is available and enabled by default for this combat.'
        }
        else {
            $useMindblast = Read-LWYesNo -Prompt 'Use Mindblast in this combat?' -Default $true
        }
    }

    $playerMod = 0
    $enemyMod = 0
    if (-not $useQuickDefaults) {
        if (Read-LWYesNo -Prompt 'Any manual Combat Skill modifiers for this fight?' -Default $false) {
            $playerMod = Read-LWInt -Prompt 'Manual player Combat Skill modifier for this combat' -Default 0
            $enemyMod = Read-LWInt -Prompt 'Manual enemy Combat Skill modifier for this combat' -Default 0
        }
    }

    $script:GameState.Combat = [pscustomobject]@{
        Active                    = $true
        EnemyName                 = $enemyName
        EnemyCombatSkill          = $enemyCombatSkill
        EnemyEnduranceCurrent     = $enemyEndurance
        EnemyEnduranceMax         = $enemyEndurance
        EnemyIsUndead             = $enemyUndead
        EnemyUsesMindforce        = $enemyUsesMindforce
        EnemyImmuneToMindblast    = $enemyImmune
        UseMindblast              = $useMindblast
        AletherCombatSkillBonus   = $aletherCombatSkillBonus
        AttemptKnockout           = $attemptKnockout
        CanEvade                  = $canEvade
        EquippedWeapon            = $equippedWeapon
        SommerswerdSuppressed     = $sommerswerdSuppressed
        PlayerCombatSkillModifier = $playerMod
        EnemyCombatSkillModifier  = $enemyMod
        Log                       = @()
    }
    if (-not [string]::IsNullOrWhiteSpace($equippedWeapon)) {
        $script:GameState.Character.LastCombatWeapon = $equippedWeapon
    }

    $script:GameState.SectionHadCombat = $true
    Register-LWCombatStarted

    Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
            View = 'status'
        })
    Write-LWInfo "Combat started against $enemyName."
    Invoke-LWMaybeAutosave
    return $true
}

function Stop-LWCombat {
    param(
        [string]$Outcome = 'Stopped',
        [switch]$SkipAutosave
    )

    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return $null
    }

    $breakdown = Get-LWCombatBreakdown
    $summary = [pscustomobject]@{
        BookNumber        = [int]$script:GameState.Character.BookNumber
        BookTitle         = Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber)
        EnemyName         = $script:GameState.Combat.EnemyName
        Outcome           = $Outcome
        RoundCount        = @($script:GameState.Combat.Log).Count
        PlayerEnd         = $script:GameState.Character.EnduranceCurrent
        PlayerEnduranceMax = $script:GameState.Character.EnduranceMax
        EnemyEnd          = $script:GameState.Combat.EnemyEnduranceCurrent
        EnemyEnduranceMax = $script:GameState.Combat.EnemyEnduranceMax
        EnemyIsUndead     = [bool]$script:GameState.Combat.EnemyIsUndead
        EnemyUsesMindforce = [bool]$script:GameState.Combat.EnemyUsesMindforce
        MindforceBlockedByMindshield = [bool](Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)
        AletherCombatSkillBonus = [int]$script:GameState.Combat.AletherCombatSkillBonus
        AttemptKnockout   = [bool]$script:GameState.Combat.AttemptKnockout
        Weapon            = $script:GameState.Combat.EquippedWeapon
        SommerswerdSuppressed = [bool]$script:GameState.Combat.SommerswerdSuppressed
        Mindblast         = [bool]$script:GameState.Combat.UseMindblast
        CanEvade          = [bool]$script:GameState.Combat.CanEvade
        Mode              = [string]$script:GameState.Settings.CombatMode
        PlayerCombatSkill = if ($null -ne $breakdown) { $breakdown.PlayerCombatSkill } else { $null }
        EnemyCombatSkill  = if ($null -ne $breakdown) { $breakdown.EnemyCombatSkill } else { $null }
        CombatRatio       = if ($null -ne $breakdown) { $breakdown.CombatRatio } else { $null }
        Notes             = if ($null -ne $breakdown) { @($breakdown.Notes) } else { @() }
        Log               = @($script:GameState.Combat.Log)
    }
    $script:GameState.History = @($script:GameState.History) + $summary
    $script:GameState.Combat = (New-LWCombatState)
    Register-LWCombatResolved -Summary $summary
    if ($Outcome -eq 'Defeat') {
        [void](Register-LWDeath -Type 'Combat' -Cause ("Defeated by {0}." -f $summary.EnemyName))
        Set-LWScreen -Name 'death'
    }
    else {
        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View    = 'summary'
                Summary = $summary
            })
    }
    Write-LWInfo "Combat ended: $Outcome."
    if (-not $SkipAutosave) {
        Invoke-LWMaybeAutosave
    }

    return $summary
}

function Invoke-LWCombatRound {
    param(
        [switch]$Quiet,
        [switch]$SkipAutosave
    )

    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return $null
    }

    $roll = Get-LWRandomDigit
    $useCRT = ($script:GameState.Settings.CombatMode -eq 'DataFile')
    $resolution = Resolve-LWCombatRound -State $script:GameState -Roll $roll -UseCRT:$useCRT
    $needsManualEntry = $resolution.RequiresManualEntry

    if (-not $Quiet -or $needsManualEntry) {
        if ($script:LWUi.Enabled) {
            Add-LWNotification -Level 'Info' -Message ("Combat Ratio: {0}" -f $resolution.Breakdown.CombatRatio)
            Add-LWNotification -Level 'Info' -Message ("Random Number: {0}" -f $roll)
        }
        else {
            Write-Host ''
            Write-Host ("Combat Ratio: {0}" -f $resolution.Breakdown.CombatRatio)
            Write-Host ("Random Number: {0}" -f $roll)
        }
    }

    foreach ($message in @($resolution.Messages)) {
        if ($message -like 'CRT data is missing*' -or $message -like 'CRT data contains an invalid result*') {
            Write-LWWarn $message
        }
        else {
            Write-LWInfo $message
        }
    }

    if ($needsManualEntry) {
        if (-not $useCRT) {
            Write-LWInfo 'Consult your Combat Results Table and enter the losses below.'
        }
        if (Test-LWCombatSommerswerdUndeadDoubleDamageActive -State $script:GameState) {
            Write-LWInfo 'Enter the normal enemy END loss from the CRT. The Sommerswerd undead bonus will double it automatically.'
        }
        if ((Test-LWCombatUsesMindforce -State $script:GameState) -and -not (Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)) {
            Write-LWInfo 'Enter the normal Lone Wolf END loss from the CRT. Mindforce will add 2 END automatically.'
        }

        $enemyLoss = Read-LWInt -Prompt 'Enemy END loss this round' -Default 0 -Min 0
        $playerLoss = Read-LWInt -Prompt 'Lone Wolf END loss this round' -Default 0 -Min 0
        $resolution = Resolve-LWCombatRound -State $script:GameState -Roll $roll -EnemyLoss $enemyLoss -PlayerLoss $playerLoss
    }

    Apply-LWCombatRoundResolution -Resolution $resolution

    if (-not $Quiet -or $needsManualEntry) {
        Write-LWInfo ("Round {0}: enemy loses {1}, Lone Wolf loses {2}." -f $resolution.LogEntry.Round, $resolution.EnemyLoss, $resolution.PlayerLoss)
    }

    if ($resolution.Outcome -eq 'Defeat') {
        [void](Stop-LWCombat -Outcome 'Defeat' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    if ($resolution.Outcome -eq 'Victory') {
        [void](Stop-LWCombat -Outcome 'Victory' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    if ($resolution.Outcome -eq 'Knockout') {
        [void](Stop-LWCombat -Outcome 'Knockout' -SkipAutosave:$SkipAutosave)
        return $resolution
    }

    if (-not $SkipAutosave) {
        Invoke-LWMaybeAutosave
    }

    return $resolution
}

function Resolve-LWCombatToOutcome {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return
    }

    if ($script:GameState.Settings.CombatMode -eq 'DataFile') {
        Write-LWInfo 'Auto-resolving combat with CRT data where available.'
    }
    else {
        Write-LWInfo 'Auto-resolving combat. You will still enter manual CRT losses each round.'
    }

    while ($script:GameState.Combat.Active) {
        $resolution = Invoke-LWCombatRound -Quiet -SkipAutosave
        if ($null -eq $resolution -or $resolution.Outcome -ne 'Continue') {
            break
        }
    }

    Invoke-LWMaybeAutosave
}

function Invoke-LWEvade {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return
    }
    if (-not $script:GameState.Combat.CanEvade) {
        Write-LWWarn 'Evade is not marked as available for this combat.'
        return
    }

    [void](Stop-LWCombat -Outcome 'Evaded')
}

function Set-LWCombatMode {
    param([string]$Mode = '')

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($Mode)) {
        $Mode = Read-LWText -Prompt 'Combat mode (ManualCRT/DataFile)' -Default $script:GameState.Settings.CombatMode
    }

    switch ($Mode.Trim().ToLowerInvariant()) {
        'manualcrt' {
            $script:GameState.Settings.CombatMode = 'ManualCRT'
            Write-LWInfo 'Combat mode set to ManualCRT.'
        }
        'manual' {
            $script:GameState.Settings.CombatMode = 'ManualCRT'
            Write-LWInfo 'Combat mode set to ManualCRT.'
        }
        'datafile' {
            $validation = Get-LWCRTValidation
            if (-not $validation.Present -or $validation.UsableEntryCount -eq 0) {
                Write-LWWarn 'No usable data/crt.json found. Staying in ManualCRT mode.'
                return
            }
            $script:GameState.Settings.CombatMode = 'DataFile'
            Write-LWInfo 'Combat mode set to DataFile.'
            foreach ($message in @($validation.Messages)) {
                Write-LWWarn $message
            }
        }
        'data' {
            $validation = Get-LWCRTValidation
            if (-not $validation.Present -or $validation.UsableEntryCount -eq 0) {
                Write-LWWarn 'No usable data/crt.json found. Staying in ManualCRT mode.'
                return
            }
            $script:GameState.Settings.CombatMode = 'DataFile'
            Write-LWInfo 'Combat mode set to DataFile.'
            foreach ($message in @($validation.Messages)) {
                Write-LWWarn $message
            }
        }
        default {
            Write-LWWarn 'Mode must be ManualCRT or DataFile.'
            return
        }
    }

    Invoke-LWMaybeAutosave
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

function Set-LWRunDifficulty {
    param([string]$Difficulty = '')

    if (-not (Test-LWHasState)) {
        Set-LWScreen -Name 'modes'
        Write-LWWarn 'Difficulty is chosen when a new run begins.'
        return
    }

    $currentDifficulty = Get-LWCurrentDifficulty
    if ([string]::IsNullOrWhiteSpace($Difficulty)) {
        Show-LWRunDifficulty
        return
    }

    $normalized = Get-LWNormalizedDifficultyName -Difficulty $Difficulty
    Set-LWScreen -Name 'modes'
    if ($normalized -eq $currentDifficulty) {
        Write-LWInfo ("Difficulty remains {0} for this run." -f $currentDifficulty)
        return
    }

    Write-LWWarn ("Difficulty is locked to {0} for this run. Start a newrun to choose {1}." -f $currentDifficulty, $normalized)
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

function Set-LWRunPermadeath {
    param([string]$Value = '')

    if (-not (Test-LWHasState)) {
        Set-LWScreen -Name 'modes'
        Write-LWWarn 'Permadeath is chosen when a new run begins.'
        return
    }

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Show-LWRunPermadeath
        return
    }

    $target = $Value.Trim().ToLowerInvariant()
    $targetEnabled = @('on', 'true', 'yes', 'y', '1') -contains $target
    $targetDisabled = @('off', 'false', 'no', 'n', '0') -contains $target
    Set-LWScreen -Name 'modes'

    if (-not $targetEnabled -and -not $targetDisabled) {
        Write-LWWarn 'Permadeath must be on or off.'
        return
    }

    if ((Test-LWPermadeathEnabled) -and $targetDisabled) {
        Write-LWWarn 'Permadeath is locked on for this run and cannot be turned off.'
        return
    }

    if (-not (Test-LWPermadeathEnabled) -and $targetEnabled) {
        Write-LWWarn 'Permadeath can only be enabled when starting a new run.'
        return
    }

    Write-LWInfo ("Permadeath remains {0} for this run." -f $(if (Test-LWPermadeathEnabled) { 'On' } else { 'Off' }))
}

function Set-LWCombatSkillBase {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $value = Read-LWInt -Prompt 'New base Combat Skill' -Default $script:GameState.Character.CombatSkillBase -Min 0
    $script:GameState.Character.CombatSkillBase = $value
    Write-LWInfo "Base Combat Skill set to $value."
    Invoke-LWMaybeAutosave
}

function Set-LWEndurance {
    param([Nullable[int]]$Current = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $Current) {
        $Current = Read-LWInt -Prompt 'Current Endurance' -Default $script:GameState.Character.EnduranceCurrent -Min 0 -Max $script:GameState.Character.EnduranceMax
    }

    $oldCurrent = [int]$script:GameState.Character.EnduranceCurrent
    $newCurrent = [Math]::Max(0, [Math]::Min([int]$Current, [int]$script:GameState.Character.EnduranceMax))
    $script:GameState.Character.EnduranceCurrent = $newCurrent
    if ($newCurrent -gt $oldCurrent) {
        Register-LWManualRecoveryShortcut
    }
    Write-LWInfo "Current Endurance set to $newCurrent / $($script:GameState.Character.EnduranceMax)."
    if (Invoke-LWFatalEnduranceCheck -Cause 'Current Endurance was set to zero.') {
        return
    }
    Invoke-LWMaybeAutosave
}

function Update-LWEndurance {
    param([Nullable[int]]$Delta = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $Delta) {
        $Delta = Read-LWInt -Prompt 'Endurance change (+/-)' -Default 0
    }

    $current = [int]$script:GameState.Character.EnduranceCurrent
    $max = [int]$script:GameState.Character.EnduranceMax
    $requestedDelta = [int]$Delta
    $lossResolution = $null
    $effectiveDelta = $requestedDelta
    if ($requestedDelta -lt 0) {
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss ([Math]::Abs($requestedDelta)) -Source 'manualdamage'
        $effectiveDelta = -[int]$lossResolution.AppliedLoss
    }

    $newCurrent = [Math]::Max(0, [Math]::Min(($current + $effectiveDelta), $max))
    $actualDelta = $newCurrent - $current
    $script:GameState.Character.EnduranceCurrent = $newCurrent
    Add-LWBookEnduranceDelta -Delta $actualDelta
    if ($actualDelta -gt 0) {
        Register-LWManualRecoveryShortcut
    }

    $message = "Current Endurance changed by $(Format-LWSigned -Value $actualDelta). Now $newCurrent / $max."
    if ($null -ne $lossResolution -and -not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
        $message += " $($lossResolution.Note)"
    }
    if ($actualDelta -ne $requestedDelta) {
        $message += ' Adjustment was capped by 0 or max END.'
    }

    Write-LWInfo $message
    if (Invoke-LWFatalEnduranceCheck -Cause 'Endurance has fallen to zero.') {
        return
    }
    Invoke-LWMaybeAutosave
}

function Set-LWMaxEndurance {
    param([Nullable[int]]$Max = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($null -eq $Max) {
        $Max = Read-LWInt -Prompt 'Maximum Endurance' -Default $script:GameState.Character.EnduranceMax -Min 1
    }

    $oldMax = [int]$script:GameState.Character.EnduranceMax
    $oldCurrent = [int]$script:GameState.Character.EnduranceCurrent
    $newMax = [Math]::Max(1, [int]$Max)
    $script:GameState.Character.EnduranceMax = $newMax
    if ($script:GameState.Character.EnduranceCurrent -gt $newMax) {
        $script:GameState.Character.EnduranceCurrent = $newMax
    }
    if ($newMax -gt $oldMax -or [int]$script:GameState.Character.EnduranceCurrent -gt $oldCurrent) {
        Register-LWManualRecoveryShortcut
    }

    Write-LWInfo "Maximum Endurance set to $newMax. Current Endurance: $($script:GameState.Character.EnduranceCurrent) / $newMax."
    Invoke-LWMaybeAutosave
}

function Complete-LWBook {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $currentBook = [int]$script:GameState.Character.BookNumber
    $nextBook = $currentBook + 1
    $nextBookLabel = Format-LWBookLabel -BookNumber $nextBook -IncludePrefix
    $nextBookStartSection = 1
    $stats = Ensure-LWCurrentBookStats
    $bookSummary = New-LWBookHistoryEntry -Stats $stats

    if (@($script:GameState.Character.CompletedBooks) -notcontains $currentBook) {
        $script:GameState.Character.CompletedBooks = @($script:GameState.Character.CompletedBooks) + $currentBook
    }
    $script:GameState.BookHistory = @($script:GameState.BookHistory) + $bookSummary
    [void](Sync-LWAchievements -Context 'bookcomplete' -Data $bookSummary)

    Set-LWScreen -Name 'bookcomplete' -Data ([pscustomobject]@{
            Summary       = $bookSummary
            CharacterName = $script:GameState.Character.Name
        })

    $script:GameState.Character.BookNumber = $nextBook
    $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    $script:GameState.CurrentSection = $nextBookStartSection
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Clear-LWDeathState
    Reset-LWCurrentBookStats -BookNumber $nextBook -StartSection $nextBookStartSection
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Write-LWInfo "Advanced to $nextBookLabel. Current section reset to $nextBookStartSection."

    $owned = @($script:GameState.Character.Disciplines)
    $availableNames = @($script:GameData.KaiDisciplines | ForEach-Object { $_.Name })
    if ($owned.Count -lt $availableNames.Count) {
        if (Read-LWYesNo -Prompt ("Choose your bonus Kai Discipline for {0} now?" -f $nextBookLabel) -Default $true) {
            $newDisc = Select-LWKaiDisciplines -Count 1 -Exclude $owned
            $script:GameState.Character.Disciplines = @($owned + $newDisc)
            Write-LWInfo "Added discipline: $($newDisc[0])."

            if ($newDisc[0] -eq 'Weaponskill' -and [string]::IsNullOrWhiteSpace($script:GameState.Character.WeaponskillWeapon)) {
                $weaponRoll = Get-LWRandomDigit
                $weaponName = Get-LWWeaponskillWeapon -Roll $weaponRoll
                $script:GameState.Character.WeaponskillWeapon = $weaponName
                Write-LWInfo "Weaponskill roll: $weaponRoll -> $weaponName"
            }
        }
    }
    else {
        Write-LWInfo 'All Kai Disciplines are already owned.'
    }

    Invoke-LWMaybeAutosave
}

function Select-LWRunConfiguration {
    param(
        [string]$DefaultDifficulty = 'Normal',
        [bool]$DefaultPermadeath = $false
    )

    $definitions = @(Get-LWDifficultyDefinitions)
    $selectedDifficulty = Get-LWNormalizedDifficultyName -Difficulty $DefaultDifficulty
    $selectedPermadeath = [bool]$DefaultPermadeath

    while ($true) {
        $defaultIndex = 1
        for ($i = 0; $i -lt $definitions.Count; $i++) {
            if ([string]$definitions[$i].Name -eq $selectedDifficulty) {
                $defaultIndex = $i + 1
                break
            }
        }

        Set-LWScreen -Name 'modes' -Data ([pscustomobject]@{
                View       = 'setup'
                Difficulty = $selectedDifficulty
                Permadeath = $selectedPermadeath
            })

        $selection = Read-LWInt -Prompt 'Difficulty number' -Default $defaultIndex -Min 1 -Max $definitions.Count
        $selectedDifficulty = [string]$definitions[$selection - 1].Name

        if ($selectedDifficulty -eq 'Story') {
            $selectedPermadeath = $false
        }
        else {
            Set-LWScreen -Name 'modes' -Data ([pscustomobject]@{
                    View       = 'setup'
                    Difficulty = $selectedDifficulty
                    Permadeath = $selectedPermadeath
                })
            $selectedPermadeath = Read-LWYesNo -Prompt 'Enable Permadeath for this run?' -Default $selectedPermadeath
        }

        Set-LWScreen -Name 'modes' -Data ([pscustomobject]@{
                View       = 'confirm'
                Difficulty = $selectedDifficulty
                Permadeath = $selectedPermadeath
            })
        if (Read-LWYesNo -Prompt 'Start this run with these mode settings?' -Default $true) {
            return [pscustomobject]@{
                Difficulty = $selectedDifficulty
                Permadeath = $selectedPermadeath
            }
        }
    }
}

function Start-LWNewGameCore {
    param(
        [switch]$PreserveProfile
    )

    $preservedAchievements = $null
    $preservedRunHistory = @()
    $preservedSettings = $null
    $defaultName = 'Lone Wolf'

    if ($PreserveProfile -and (Test-LWHasState)) {
        $defaultName = if ([string]::IsNullOrWhiteSpace([string]$script:GameState.Character.Name)) { 'Lone Wolf' } else { [string]$script:GameState.Character.Name }
        $preservedAchievements = $script:GameState.Achievements
        $preservedRunHistory = @($script:GameState.RunHistory)
        $preservedRunHistory += @(New-LWRunArchiveEntry -State $script:GameState -Status 'Retired')
        $preservedSettings = [pscustomobject]@{
            CombatMode = [string]$script:GameState.Settings.CombatMode
            SavePath   = [string]$script:GameState.Settings.SavePath
            AutoSave   = [bool]$script:GameState.Settings.AutoSave
            DataDir    = [string]$script:GameState.Settings.DataDir
        }
    }

    $runConfig = Select-LWRunConfiguration -DefaultDifficulty 'Normal' -DefaultPermadeath $false
    if ($null -eq $runConfig) {
        return
    }

    $script:GameState = (New-LWDefaultState)
    if ($PreserveProfile -and $null -ne $preservedAchievements) {
        $script:GameState.Achievements = $preservedAchievements
        $script:GameState.RunHistory = @($preservedRunHistory)
        if ($null -ne $preservedSettings) {
            $script:GameState.Settings.CombatMode = [string]$preservedSettings.CombatMode
            $script:GameState.Settings.SavePath = [string]$preservedSettings.SavePath
            $script:GameState.Settings.AutoSave = [bool]$preservedSettings.AutoSave
            $script:GameState.Settings.DataDir = [string]$preservedSettings.DataDir
        }
    }
    else {
        $script:GameState.Settings.CombatMode = (Get-LWDefaultCombatMode)
    }

    $script:GameState.Run = (New-LWRunState -Difficulty ([string]$runConfig.Difficulty) -Permadeath ([bool]$runConfig.Permadeath))
    Set-LWScreen -Name 'sheet'

    $name = Read-LWText -Prompt 'Character name' -Default $defaultName
    $bookNumber = Read-LWInt -Prompt 'Current book number' -Default 1 -Min 1
    $startSection = Read-LWInt -Prompt 'Starting section' -Default 1 -Min 1

    $csRoll = Get-LWRandomDigit
    $endRoll = Get-LWRandomDigit
    $combatSkill = 10 + $csRoll
    $endurance = 20 + $endRoll

    Write-LWInfo "Combat Skill roll: $csRoll -> $combatSkill"
    Write-LWInfo "Endurance roll: $endRoll -> $endurance"

    $disciplines = Select-LWKaiDisciplines -Count 5
    $weaponskillWeapon = $null
    if ($disciplines -contains 'Weaponskill') {
        $weaponRoll = Get-LWRandomDigit
        $weaponskillWeapon = Get-LWWeaponskillWeapon -Roll $weaponRoll
        Write-LWInfo "Weaponskill roll: $weaponRoll -> $weaponskillWeapon"
    }

    $script:GameState.Character.Name = $name
    $script:GameState.Character.BookNumber = $bookNumber
    $script:GameState.Character.CombatSkillBase = $combatSkill
    $script:GameState.Character.EnduranceCurrent = $endurance
    $script:GameState.Character.EnduranceMax = $endurance
    $script:GameState.Character.Disciplines = $disciplines
    $script:GameState.Character.WeaponskillWeapon = $weaponskillWeapon
    $script:GameState.CurrentSection = $startSection
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Clear-LWDeathState
    Reset-LWCurrentBookStats -BookNumber $bookNumber -StartSection $startSection
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Sync-LWRunIntegrityState -State $script:GameState

    Write-LWInfo ("New {0} run created." -f [string]$script:GameState.Run.Difficulty)
    if (Test-LWPermadeathEnabled) {
        Write-LWWarn 'Permadeath is locked on for this run.'
    }

    if ($PreserveProfile -and $null -ne $preservedSettings -and -not [string]::IsNullOrWhiteSpace([string]$preservedSettings.SavePath)) {
        Save-LWGame
    }
    else {
        if (Read-LWYesNo -Prompt 'Set a default save path now?' -Default $true) {
            Save-LWGame -PromptForPath
            if (Read-LWYesNo -Prompt 'Enable autosave after state changes?' -Default $true) {
                $script:GameState.Settings.AutoSave = $true
                Write-LWInfo 'Autosave enabled.'
            }
        }
    }

    Set-LWScreen -Name 'sheet'
}

function New-LWGame {
    Start-LWNewGameCore
}

function New-LWRun {
    if ((Test-LWHasState) -and -not (Read-LWYesNo -Prompt 'Archive the current run and start a fresh one on this same profile?' -Default $true)) {
        Write-LWWarn 'newrun cancelled.'
        return
    }

    Start-LWNewGameCore -PreserveProfile
}

function Save-LWGame {
    param([switch]$PromptForPath)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }
    if ((Test-LWPermadeathEnabled) -and (Test-LWDeathActive)) {
        Write-LWWarn 'Permadeath runs cannot be saved after death.'
        return
    }

    Sync-LWCurrentSectionCheckpoint
    Sync-LWRunIntegrityState -State $script:GameState

    $path = $script:GameState.Settings.SavePath
    if ($PromptForPath -or [string]::IsNullOrWhiteSpace($path)) {
        $defaultFile = "{0}-book{1}.json" -f (Get-LWSafeFileName -Name $script:GameState.Character.Name), $script:GameState.Character.BookNumber
        $defaultPath = Join-Path $SaveDir $defaultFile
        $path = Read-LWText -Prompt 'Save path' -Default $defaultPath
    }

    $directory = Split-Path -Parent $path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $script:GameState.Settings.SavePath = $path
    $json = $script:GameState | ConvertTo-Json -Depth 20
    Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    Set-LWLastUsedSavePath -Path $path
    Write-LWInfo "Saved game to $path"
}

function Load-LWGame {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-LWWarn "Save file not found: $Path"
        return
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Write-LWWarn 'Save file is empty.'
        return
    }

    $state = $raw | ConvertFrom-Json
    $script:GameState = Normalize-LWState -State $state
    $script:GameState.Settings.SavePath = $Path
    Ensure-LWCurrentSectionCheckpoint
    Set-LWLastUsedSavePath -Path $Path
    Set-LWScreen -Name (Get-LWDefaultScreen)
    if (Test-LWRunTampered) {
        $integrityNote = if (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityNote)) { [string]$script:GameState.Run.IntegrityNote } else { 'Locked run settings were changed outside the assistant.' }
        Write-LWWarn ("Run integrity warning: {0}" -f $integrityNote)
    }
    $backfilled = @(Sync-LWAchievements -Context 'load' -Silent)
    if ($backfilled.Count -gt 0) {
        Write-LWInfo ("Backfilled {0} achievement{1} from save history." -f $backfilled.Count, $(if ($backfilled.Count -eq 1) { '' } else { 's' }))
    }
    Write-LWInfo "Loaded game from $Path"
}

function Get-LWSaveCatalog {
    $currentPath = Get-LWPreferredSavePath

    $currentFullPath = $null
    if (-not [string]::IsNullOrWhiteSpace($currentPath)) {
        try {
            $currentFullPath = [System.IO.Path]::GetFullPath($currentPath)
        }
        catch {
            $currentFullPath = $currentPath
        }
    }

    if (-not (Test-Path -LiteralPath $SaveDir)) {
        return @()
    }

    $files = @(Get-ChildItem -LiteralPath $SaveDir -Filter '*.json' | Where-Object { -not $_.PSIsContainer } | Sort-Object LastWriteTime -Descending)
    $catalog = @()
    $index = 0

    foreach ($file in $files) {
        $index++
        $characterName = $null
        $bookNumber = $null
        $currentSection = $null

        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $state = $raw | ConvertFrom-Json
                if ($null -ne $state.Character -and -not [string]::IsNullOrWhiteSpace([string]$state.Character.Name)) {
                    $characterName = [string]$state.Character.Name
                }
                if ($null -ne $state.Character -and $null -ne $state.Character.BookNumber) {
                    $bookNumber = [int]$state.Character.BookNumber
                }
                if ($null -ne $state.CurrentSection) {
                    $currentSection = [int]$state.CurrentSection
                }
            }
        }
        catch {
        }

        $fullPath = $file.FullName
        try {
            $fullPath = [System.IO.Path]::GetFullPath($file.FullName)
        }
        catch {
        }

        $isCurrent = $false
        if (-not [string]::IsNullOrWhiteSpace($currentFullPath)) {
            $isCurrent = $fullPath.Equals($currentFullPath, [System.StringComparison]::OrdinalIgnoreCase)
        }

        $catalog += [pscustomobject]@{
            Index          = $index
            Name           = $file.Name
            FullName       = $file.FullName
            LastWriteTime  = $file.LastWriteTime
            CharacterName  = $characterName
            BookNumber     = $bookNumber
            CurrentSection = $currentSection
            IsCurrent      = $isCurrent
        }
    }

    return @($catalog)
}

function Show-LWSaveCatalog {
    param([object[]]$SaveFiles)

    $saveFiles = @($SaveFiles)
    if ($saveFiles.Count -eq 0) {
        return
    }

    Write-LWPanelHeader -Title 'Available Saves' -AccentColor 'Cyan'

    foreach ($save in $saveFiles) {
        $nameColor = if ($save.IsCurrent) { 'Green' } else { 'Gray' }
        Write-Host ("  [{0}] " -f $save.Index) -NoNewline -ForegroundColor DarkGray
        Write-Host $save.Name -NoNewline -ForegroundColor $nameColor
        if ($save.IsCurrent) {
            Write-Host ' (current)' -ForegroundColor DarkYellow
        }
        else {
            Write-Host ''
        }

        $details = @()
        if (-not [string]::IsNullOrWhiteSpace($save.CharacterName)) {
            $details += $save.CharacterName
        }
        if ($null -ne $save.BookNumber -and [int]$save.BookNumber -gt 0) {
            $details += "Book $($save.BookNumber)"
        }
        if ($null -ne $save.CurrentSection -and [int]$save.CurrentSection -gt 0) {
            $details += "Section $($save.CurrentSection)"
        }
        $details += $save.LastWriteTime.ToString('g')

        Write-LWSubtle ("      " + ($details -join ' | '))
    }

    Write-LWSubtle 'Type a save number to load it, or paste a full path.'
}

function Resolve-LWSaveSelectionPath {
    param(
        [string]$Selection,
        [object[]]$SaveFiles,
        [string]$DefaultPath
    )

    $saveFiles = @($SaveFiles)
    $trimmed = $Selection.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $DefaultPath
    }

    $selectedIndex = 0
    if ([int]::TryParse($trimmed, [ref]$selectedIndex)) {
        $selectedSave = @($saveFiles | Where-Object { $_.Index -eq $selectedIndex } | Select-Object -First 1)
        if ($selectedSave.Count -eq 0) {
            Write-LWWarn "Save number must be between 1 and $($saveFiles.Count)."
            return $null
        }

        return $selectedSave[0].FullName
    }

    if (-not [System.IO.Path]::IsPathRooted($trimmed)) {
        $candidatePath = Join-Path $SaveDir $trimmed
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidatePath
        }
    }

    return $trimmed
}

function Load-LWGameInteractive {
    param([string]$Selection = '')

    $defaultPath = Get-LWPreferredSavePath
    if ([string]::IsNullOrWhiteSpace($defaultPath)) {
        $defaultPath = Join-Path $SaveDir 'lonewolf-save.json'
    }

    $saveFiles = @(Get-LWSaveCatalog)
    $path = $null

    if ([string]::IsNullOrWhiteSpace($Selection)) {
        Set-LWScreen -Name 'load' -Data ([pscustomobject]@{
                SaveFiles = @($saveFiles)
            })
        if ($saveFiles.Count -gt 0) {
            $defaultSelection = '1'
            $currentSave = @($saveFiles | Where-Object { $_.IsCurrent } | Select-Object -First 1)
            if ($currentSave.Count -gt 0) {
                $defaultSelection = [string]$currentSave[0].Index
            }

            $selection = Read-LWText -Prompt 'Save number or path' -Default $defaultSelection
            $path = Resolve-LWSaveSelectionPath -Selection $selection -SaveFiles $saveFiles -DefaultPath $defaultPath
        }
        else {
            $path = Read-LWText -Prompt 'Load path' -Default $defaultPath
        }
    }
    else {
        $path = Resolve-LWSaveSelectionPath -Selection $Selection -SaveFiles $saveFiles -DefaultPath $defaultPath
    }

    if ([string]::IsNullOrWhiteSpace($path)) {
        return
    }

    Load-LWGame -Path $path
}

function Invoke-LWMaybeAutosave {
    if (-not (Test-LWHasState)) {
        return
    }
    Sync-LWCurrentSectionCheckpoint
    if ($script:GameState.Settings.AutoSave -and -not [string]::IsNullOrWhiteSpace($script:GameState.Settings.SavePath)) {
        Save-LWGame
    }
}

function Show-LWHelp {
    Write-LWPanelHeader -Title 'Commands' -AccentColor 'Cyan'
    Write-LWKeyValue -Label 'new' -Value 'Create a new Kai character' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'newrun' -Value 'Start a fresh run on the same profile and keep achievements' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'sheet' -Value 'Show character sheet' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'modes' -Value 'Show run mode rules and locked settings' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'difficulty [name]' -Value 'Show the locked run difficulty' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'permadeath [on|off]' -Value 'Show the locked permadeath setting' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'inv' -Value 'Show inventory slots' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'disciplines' -Value 'Show disciplines' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'discipline add [name]' -Value 'Add a missed Kai discipline reward' -ValueColor 'Gray'
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
    Write-LWKeyValue -Label 'drop [type slot]' -Value 'Remove inventory item by slot' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'gold [delta]' -Value 'Gain or spend Gold Crowns' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'meal' -Value 'Resolve an eat instruction' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'potion' -Value 'Use a Healing or Laumspur Potion outside combat' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'end [delta]' -Value 'Adjust current Endurance only' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'die [cause]' -Value 'Record an instant death and open rewind options' -ValueColor 'Gray'
    Write-LWKeyValue -Label 'rewind [n]' -Value 'After death, return to an earlier safe section' -ValueColor 'Gray'
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
    Write-LWBulletItem -Text 'Use inv to see exact weapon and backpack slots, including empty spaces.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use drop backpack 2 or drop weapon 1 to remove by slot number.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use discipline add to open the Kai discipline picker, or discipline add Mindblast to grant one directly.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use end -1 for section damage and end +1 for simple recovery without touching max END.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Shield and Silver Helm each add +2 Combat Skill automatically, and Chainmail Waistcoat adds +4 END automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Bone Sword is treated as a weapon and adds +1 Combat Skill in Book 3 / Kalte only.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'From Book 2 onward, Sommerswerd is a weapon-like Special Item: +8 Combat Skill in combat, or +10 total with Sword, Short Sword, or Broadsword Weaponskill.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'When Sommerswerd is active against undead foes, their END loss is doubled automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'If an enemy is using Mindforce, the app can apply its extra END loss each round and Mindshield blocks it automatically.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'In Book 3 and later, combat can attempt a knockout: edged weapons take -2 CS, while unarmed, Warhammer, Quarterstaff, and Mace do not.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'potion works with both Healing Potion and Laumspur Potion item names.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'potion now prefers Concentrated Laumspur first and restores 8 END when one is available.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'From Book 3 onward, if Alether is in your backpack, combat start can consume it before the fight to grant +4 Combat Skill for that combat only.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use die for instant-death sections. After death, use rewind or rewind 2 to go back to earlier safe sections.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'history and combat log all now group archived fights by book for easier browsing.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use combat log book 2 to review archived fights from one book only.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use campaign to review the whole run, or campaign books/combat/survival/milestones for focused views.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use achievements, achievements progress, or achievements planned to browse the new achievement system.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use modes to review Story, Easy, Normal, Hard, Veteran, and Permadeath before starting a run.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Difficulty is locked for the whole run, and Permadeath can only be chosen at run start.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'ManualCRT gives you the ratio and roll, then asks for losses from your own CRT.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'DataFile reads those losses from data/crt.json when the file is populated.' -TextColor 'Gray'
}

function Invoke-LWCombatCommand {
    param([string[]]$Parts)

    if ($null -eq $Parts) {
        $Parts = @()
    }
    else {
        $Parts = @($Parts)
    }

    if ($Parts.Count -lt 2) {
        Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                View = if ($script:GameState.Combat.Active) { 'status' } else { 'summary' }
            })
        return
    }

    switch ($Parts[1].ToLowerInvariant()) {
        'start'  {
            if ($Parts.Count -gt 2) {
                [void](Start-LWCombat -Arguments @($Parts[2..($Parts.Count - 1)]))
            }
            else {
                [void](Start-LWCombat)
            }
        }
        'round'  { [void](Invoke-LWCombatRound) }
        'next'   { [void](Invoke-LWCombatRound) }
        'auto'   { Resolve-LWCombatToOutcome }
        'status' {
            if ($script:GameState.Combat.Active) {
                Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                        View = 'status'
                    })
            }
            elseif (@($script:GameState.History).Count -gt 0) {
                Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                        View    = 'summary'
                        Summary = $script:GameState.History[-1]
                    })
            }
            else {
                Set-LWScreen -Name 'combat' -Data ([pscustomobject]@{
                        View = 'summary'
                    })
                Write-LWWarn 'No active combat.'
            }
        }
        'log'    {
            if ($Parts.Count -gt 2) {
                $logTarget = $Parts[2].Trim()
                if ($logTarget.ToLowerInvariant() -eq 'all') {
                    Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                            All = $true
                        })
                }
                elseif ($logTarget.ToLowerInvariant() -eq 'book') {
                    if ($Parts.Count -lt 4) {
                        Write-LWWarn 'combat log book <n> expects a book number.'
                    }
                    else {
                        $bookNumber = 0
                        if ([int]::TryParse($Parts[3], [ref]$bookNumber) -and $bookNumber -ge 1) {
                            Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                                    All        = $true
                                    BookNumber = $bookNumber
                                })
                        }
                        else {
                            Write-LWWarn 'combat log book <n> expects a valid book number.'
                        }
                    }
                }
                else {
                    $historyIndex = 0
                    if ([int]::TryParse($logTarget, [ref]$historyIndex)) {
                        $history = @($script:GameState.History)
                        if ($historyIndex -lt 1 -or $historyIndex -gt $history.Count) {
                            Write-LWWarn 'combat log accepts a history number, all, or book <n>.'
                        }
                        else {
                            Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                                    Entry = $history[$historyIndex - 1]
                                })
                        }
                    }
                    else {
                        Write-LWWarn 'combat log accepts a history number, all, or book <n>.'
                    }
                }
            }
            else {
                $entry = $null
                if ($script:GameState.Combat.Active) {
                    $entry = Get-LWCurrentCombatLogEntry
                }
                elseif (@($script:GameState.History).Count -gt 0) {
                    $entry = $script:GameState.History[-1]
                }

                if ($null -eq $entry) {
                    Write-LWWarn 'No combat log available.'
                }
                else {
                    Set-LWScreen -Name 'combatlog' -Data ([pscustomobject]@{
                            Entry = $entry
                        })
                }
            }
        }
        'evade'  { Invoke-LWEvade }
        'stop'   { [void](Stop-LWCombat) }
        default  { Write-LWWarn 'Unknown combat subcommand. Use start, round, next, auto, status, log, evade, or stop.' }
    }
}

function Invoke-LWCommand {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$InputLine)

    Clear-LWNotifications
    $trimmed = $InputLine.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        if ($script:GameState -and $script:GameState.Combat.Active) {
            [void](Invoke-LWCombatRound)
        }
        return $null
    }

    $parts = @([string[]]($trimmed -split '\s+'))
    $command = $parts[0].ToLowerInvariant()
    $argumentText = if ($trimmed.Length -gt $command.Length) {
        $trimmed.Substring($command.Length).Trim()
    }
    else {
        ''
    }

    if ($command -eq 'achievement') {
        $command = 'achievements'
    }

    if (Test-LWDeathActive) {
        $allowedWhileDead = @('rewind', 'load', 'new', 'newrun', 'help', 'save', 'quit', 'exit', 'stats', 'campaign', 'achievements', 'achievement', 'modes', 'difficulty', 'permadeath')
        if ($allowedWhileDead -notcontains $command) {
            Set-LWScreen -Name 'death'
            Write-LWWarn 'You have fallen. Use rewind, load, newrun, modes, campaign, help, or quit.'
            return $null
        }
    }

    switch ($command) {
        'new'         { New-LWGame; return $null }
        'newrun'      { New-LWRun; return $null }
        'sheet'       { Set-LWScreen -Name 'sheet'; return $null }
        'modes'       { Set-LWScreen -Name 'modes'; return $null }
        'difficulty'  {
            if ($parts.Count -gt 1) {
                Set-LWRunDifficulty -Difficulty $parts[1]
            }
            else {
                Show-LWRunDifficulty
            }
            return $null
        }
        'permadeath'  {
            if ($parts.Count -gt 1) {
                Set-LWRunPermadeath -Value $parts[1]
            }
            else {
                Show-LWRunPermadeath
            }
            return $null
        }
        'inv'         { Set-LWScreen -Name 'inventory'; return $null }
        'inventory'   { Set-LWScreen -Name 'inventory'; return $null }
        'disciplines' { Set-LWScreen -Name 'disciplines'; return $null }
        'discipline'  {
            if ($parts.Count -eq 1) {
                Set-LWScreen -Name 'disciplines'
                return $null
            }

            switch ($parts[1].ToLowerInvariant()) {
                'add' {
                    $disciplineName = if ($parts.Count -gt 2) { ($parts[2..($parts.Count - 1)] -join ' ') } else { '' }
                    Add-LWKaiDiscipline -Name $disciplineName
                }
                default {
                    Write-LWWarn 'Use discipline add [name] to grant a missed Kai discipline.'
                }
            }
            return $null
        }
        'notes'       { Set-LWScreen -Name 'notes'; return $null }
        'note'        {
            if ($parts.Count -gt 1 -and @('remove', 'delete', 'drop') -contains $parts[1].ToLowerInvariant()) {
                Remove-LWNoteInteractive -InputParts $parts
            }
            else {
                Add-LWNote -Text $argumentText
            }
            return $null
        }
        'history'     { Set-LWScreen -Name 'history'; return $null }
        'stats'       {
            $view = 'overview'
            if ($parts.Count -gt 1) {
                switch ($parts[1].ToLowerInvariant()) {
                    'combat' { $view = 'combat' }
                    'survival' { $view = 'survival' }
                    'overview' { $view = 'overview' }
                    default {
                        Write-LWWarn 'Use stats, stats combat, or stats survival.'
                        return $null
                    }
                }
            }

            Set-LWScreen -Name 'stats' -Data ([pscustomobject]@{
                    View = $view
                })
            return $null
        }
        'campaign'    {
            $view = 'overview'
            if ($parts.Count -gt 1) {
                switch ($parts[1].ToLowerInvariant()) {
                    'overview' { $view = 'overview' }
                    'books' { $view = 'books' }
                    'combat' { $view = 'combat' }
                    'survival' { $view = 'survival' }
                    'milestones' { $view = 'milestones' }
                    default {
                        Write-LWWarn 'Use campaign, campaign books, campaign combat, campaign survival, or campaign milestones.'
                        return $null
                    }
                }
            }

            Set-LWScreen -Name 'campaign' -Data ([pscustomobject]@{
                    View = $view
                })
            return $null
        }
        'achievements' {
            $view = 'overview'
            if ($parts.Count -gt 1) {
                switch ($parts[1].ToLowerInvariant()) {
                    'overview' { $view = 'overview' }
                    'unlocked' { $view = 'unlocked' }
                    'locked' { $view = 'locked' }
                    'recent' { $view = 'recent' }
                    'progress' { $view = 'progress' }
                    'planned' { $view = 'planned' }
                    default {
                        Write-LWWarn 'Use achievements, achievements unlocked, achievements locked, achievements recent, achievements progress, or achievements planned.'
                        return $null
                    }
                }
            }

            Set-LWScreen -Name 'achievements' -Data ([pscustomobject]@{
                    View = $view
                })
            return $null
        }
        'roll'        { Write-LWInfo ("Random Number Table roll: {0}" -f (Get-LWRandomDigit)); return $null }
        'section'     {
            if ($parts.Count -gt 1) {
                $sectionValue = 0
                if ([int]::TryParse($parts[1], [ref]$sectionValue)) {
                    Set-LWSection -Section $sectionValue
                }
                else {
                    Write-LWWarn 'Section must be a whole number.'
                }
            }
            else {
                Set-LWSection
            }
            return $null
        }
        'healcheck'   { Invoke-LWHealingCheck; return $null }
        'add'         { Add-LWInventoryInteractive -InputParts $parts; return $null }
        'drop'        { Remove-LWInventoryInteractive -InputParts $parts; return $null }
        'gold'        { Update-LWGoldInteractive -InputParts $parts; return $null }
        'meal'        { Use-LWMeal; return $null }
        'potion'      { Use-LWHealingPotion; return $null }
        'die'         { Invoke-LWInstantDeath -Cause $argumentText; return $null }
        'rewind'      {
            if ($parts.Count -gt 1) {
                $rewindSteps = 0
                if ([int]::TryParse($parts[1], [ref]$rewindSteps)) {
                    Invoke-LWRewind -Steps $rewindSteps
                }
                else {
                    Write-LWWarn 'rewind expects a whole number, like rewind 2.'
                }
            }
            else {
                Invoke-LWRewind
            }
            return $null
        }
        'end'         {
            if ($parts.Count -gt 1) {
                $delta = 0
                if ([int]::TryParse($parts[1], [ref]$delta)) {
                    Update-LWEndurance -Delta $delta
                }
                else {
                    Write-LWWarn 'Endurance change must be a whole number, like end -1 or end +2.'
                }
            }
            else {
                Update-LWEndurance
            }
            return $null
        }
        'endurance'   {
            if ($parts.Count -gt 1) {
                $delta = 0
                if ([int]::TryParse($parts[1], [ref]$delta)) {
                    Update-LWEndurance -Delta $delta
                }
                else {
                    Write-LWWarn 'Endurance change must be a whole number, like endurance -1 or endurance +2.'
                }
            }
            else {
                Update-LWEndurance
            }
            return $null
        }
        'combat'      { Invoke-LWCombatCommand -Parts $parts; return $null }
        'fight'       {
            if ($parts.Count -gt 1) {
                $fightSubcommand = $parts[1].ToLowerInvariant()
                if (@('round', 'next', 'auto', 'status', 'log', 'evade', 'stop') -contains $fightSubcommand) {
                    Invoke-LWCombatCommand -Parts @('combat') + @($parts[1..($parts.Count - 1)])
                    return $null
                }
            }

            $started = if ($parts.Count -gt 1) { Start-LWCombat -Arguments @($parts[1..($parts.Count - 1)]) } else { Start-LWCombat }
            if ($started) {
                Resolve-LWCombatToOutcome
            }
            return $null
        }
        'mode'        {
            if ($parts.Count -gt 1) {
                Set-LWCombatMode -Mode $parts[1]
            }
            else {
                Set-LWCombatMode
            }
            return $null
        }
        'complete'    { Complete-LWBook; return $null }
        'setcs'       { Set-LWCombatSkillBase; return $null }
        'setend'      {
            if ($parts.Count -gt 1) {
                $currentValue = 0
                if ([int]::TryParse($parts[1], [ref]$currentValue)) {
                    Set-LWEndurance -Current $currentValue
                }
                else {
                    Write-LWWarn 'Current Endurance must be a whole number.'
                }
            }
            else {
                Set-LWEndurance
            }
            return $null
        }
        'setmaxend'   {
            if ($parts.Count -gt 1) {
                $maxValue = 0
                if ([int]::TryParse($parts[1], [ref]$maxValue)) {
                    Set-LWMaxEndurance -Max $maxValue
                }
                else {
                    Write-LWWarn 'Maximum Endurance must be a whole number.'
                }
            }
            else {
                Set-LWMaxEndurance
            }
            return $null
        }
        'save'        { Save-LWGame; return $null }
        'load'        {
            if ([string]::IsNullOrWhiteSpace($argumentText)) {
                Load-LWGameInteractive
            }
            else {
                Load-LWGameInteractive -Selection $argumentText
            }
            return $null
        }
        'help'        { Set-LWScreen -Name 'help'; return $null }
        'quit'        { return 'quit' }
        'exit'        { return 'quit' }
        default       { Write-LWWarn "Unknown command: $command. Type help for the command list."; return $null }
    }
}

function Start-LWTerminal {
    $script:LWUi.Enabled = $true
    Set-LWScreen -Name 'welcome'
    Clear-LWNotifications

    if (-not [string]::IsNullOrWhiteSpace($Load)) {
        Load-LWGame -Path $Load
    }
    else {
        $script:GameState = (New-LWDefaultState)
        Set-LWScreen -Name 'welcome'
        Write-LWInfo 'No save loaded. Use new to create a character or load to open a save file.'
    }

    while ($true) {
        Refresh-LWScreen
        $line = Read-Host 'lw'
        $result = Invoke-LWCommand -InputLine $line
        if ($result -eq 'quit') {
            break
        }
    }

    $script:LWUi.Enabled = $false
    Write-LWInfo 'Good luck on the Kai trail.'
}

Initialize-LWData
Start-LWTerminal
