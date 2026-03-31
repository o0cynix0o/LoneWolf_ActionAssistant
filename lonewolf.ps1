#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Load,
    [string]$SaveDir,
    [string]$DataDir
)

$script:LWBootstrapRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

$script:LWBootstrapModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\bootstrap.psm1'
if (-not (Test-Path -LiteralPath $script:LWBootstrapModulePath)) {
    throw "Bootstrap module not found at $script:LWBootstrapModulePath"
}

Import-Module $script:LWBootstrapModulePath -Force -DisableNameChecking
$script:LWDisplayModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\display.psm1'
$script:LWCommonModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\common.psm1'
$script:LWStateModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\state.psm1'
$script:LWSaveModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\save.psm1'
$script:LWCommandsModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\commands.psm1'
$script:LWCombatModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\combat.psm1'
$script:LWRulesetCoreModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\ruleset.psm1'
$script:LWKaiBook1ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book1.psm1'
$script:LWKaiBook2ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book2.psm1'
$script:LWKaiBook3ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book3.psm1'
$script:LWKaiBook4ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book4.psm1'
$script:LWKaiBook5ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\book5.psm1'
$script:LWKaiRulesetModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\kai.psm1'
foreach ($modulePath in @(
        $script:LWDisplayModulePath,
        $script:LWCommonModulePath,
        $script:LWStateModulePath,
        $script:LWSaveModulePath,
        $script:LWCommandsModulePath,
        $script:LWCombatModulePath,
        $script:LWKaiBook1ModulePath,
        $script:LWKaiBook2ModulePath,
        $script:LWKaiBook3ModulePath,
        $script:LWKaiBook4ModulePath,
        $script:LWKaiBook5ModulePath,
        $script:LWKaiRulesetModulePath,
        $script:LWRulesetCoreModulePath
    )) {
    if (-not (Test-Path -LiteralPath $modulePath)) {
        throw "Core module not found at $modulePath"
    }

    Import-Module $modulePath -Force -DisableNameChecking
}

$script:LWBootstrap = New-LWBootstrapConfiguration -ScriptRoot $PSScriptRoot -MyCommandPath $MyInvocation.MyCommand.Path -SaveDir $SaveDir -DataDir $DataDir

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:LWRootDir = $script:LWBootstrap.RootDir
$SaveDir = $script:LWBootstrap.SaveDir
$DataDir = $script:LWBootstrap.DataDir
$script:LWAppName = $script:LWBootstrap.AppName
$script:LWAppVersion = $script:LWBootstrap.AppVersion
$script:LWStateVersion = $script:LWBootstrap.StateVersion
$script:LastUsedSavePathFile = $script:LWBootstrap.LastUsedSavePathFile
$script:LWErrorLogFile = $script:LWBootstrap.ErrorLogFile
$script:GameState = $null
$script:GameData = $null
$script:LWAchievementDefinitionsCache = $null
$script:LWUi = $script:LWBootstrap.UiState

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
    Request-LWRender
}

function Write-LWCrashLog {
    param(
        [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$InputLine = '',
        [string]$Stage = 'command'
    )

    $logPath = $script:LWErrorLogFile
    $logDir = Split-Path -Parent $logPath
    if (-not [string]::IsNullOrWhiteSpace($logDir) -and -not (Test-Path $logDir)) {
        [void](New-Item -ItemType Directory -Path $logDir -Force)
    }

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

function Clear-LWNotifications {
    $script:LWUi.Notifications = @()
    Request-LWRender
}

function Request-LWRender {
    if ($null -eq $script:LWUi) {
        return
    }

    if (-not (Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender')) {
        $script:LWUi | Add-Member -Force -NotePropertyName NeedsRender -NotePropertyValue $true
        return
    }

    $script:LWUi.NeedsRender = $true
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
    Request-LWRender
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

    $deathTitle = if ([string]$deathType -ieq 'Failure') {
        'Mission Failed'
    }
    elseif (Test-LWPermadeathEnabled) {
        'Tragically, your life and this save end here!'
    }
    else {
        'You Have Fallen'
    }
    Write-LWPanelHeader -Title $deathTitle -AccentColor 'Red'
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
        Write-LWBulletItem -Text 'No rewind checkpoints are available for this death or failed mission.' -TextColor 'Gray'
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

    if ((Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender') -and -not [bool]$script:LWUi.NeedsRender) {
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
        if (Test-LWPropertyExists -Object $script:LWUi -Name 'NeedsRender') {
            $script:LWUi.NeedsRender = $false
        }
    }

    Write-LWNotifications
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
        (Get-LWCanonicalDateText -Value $State.Run.StartedOn),
        [string]([int]$State.Character.BookNumber),
        [string]([int]$State.CurrentSection),
        ($completedBooks -join ',')
    ) -join '|'
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
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$Reseal
    )

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

function New-LWStoryAchievementFlags {
    return [pscustomobject]@{
        Book1AimForTheBushesVisited = $false
        Book1ClubhouseFound         = $false
        Book1SilverKeyClaimed       = $false
        Book1UseTheForcePath        = $false
        Book1StraightToTheThrone    = $false
        Book1RoyalRecovery          = $false
        Book1BackWayIn              = $false
        Book1OpenSesameRoute        = $false
        Book1HotHandsClaimed        = $false
        Book1StarOfToranClaimed     = $false
        Book1FieldMedicPath         = $false
        Book1LaumspurClaimed        = $false
        Book1VordakGem76Claimed     = $false
        Book1VordakGem304Claimed    = $false
        Book1VordakGemCurseTriggered = $false
        Book2CoachTicketClaimed     = $false
        Book2WhitePassClaimed       = $false
        Book2RedPassClaimed         = $false
        Book2PotentPotionClaimed    = $false
        Book2MealOfLaumspurClaimed  = $false
        Book2ForgedPapersBought     = $false
        Book2Section106DamageApplied = $false
        Book2Section313Resolved     = $false
        Book2Section337StormLossApplied = $false
        Book2SommerswerdClaimed     = $false
        Book2ByAThreadRoute         = $false
        Book2SkyfallRoute           = $false
        Book2FightThroughTheSmokeRoute = $false
        Book2StormTossedSeen        = $false
        Book2SealOfApprovalRoute    = $false
        Book2PapersPleasePath       = $false
        Book3SnakePitVisited        = $false
        Book3CliffhangerSeen        = $false
        Book3DiamondClaimed         = $false
        Book3SnowblindSeen          = $false
        Book3GrossKeyClaimed        = $false
        Book3LuckyButtonTheorySeen  = $false
        Book3WellItWorkedOnceSeen   = $false
        Book3FirstCellAbandoned     = $false
        Book3CellfishPathTaken      = $false
        Book3LoiKymarRescued        = $false
        Book3EffigyEndgameReached   = $false
        Book3SommerswerdEndgameUsed = $false
        Book3LuckyEndgameUsed       = $false
        Book3TooSlowFailureSeen     = $false
        Book4Section12ResupplyHandled = $false
        Book4Section12MealsClaimed   = $false
        Book4Section12RopeClaimed    = $false
        Book4Section12PotionClaimed  = $false
        Book4Section12SwordClaimed   = $false
        Book4Section12SpearClaimed   = $false
        Book4Section79SuppliesClaimed = $false
        Book4Section94LossApplied   = $false
        Book4BadgeOfOfficePath      = $false
        Book4OnyxMedallionClaimed   = $false
        Book4Section117LightPath    = $false
        Book4Section122MindAttackApplied = $false
        Book4Section123SuppliesClaimed = $false
        Book4Section158LossApplied  = $false
        Book4Section167RecoveryClaimed = $false
        Book4BackpackLost           = $false
        Book4BackpackRecovered      = $false
        Book4WashedAway             = $false
        Book4Section280GoldClaimed  = $false
        Book4Section280MealClaimed  = $false
        Book4Section280SwordClaimed = $false
        Book4CaptainSwordClaimed    = $false
        Book4PotionOfRedLiquidClaimed = $false
        Book4ShovelReadyClaimed     = $false
        Book4ScrollClaimed          = $false
        Book4TorchesWillNotLight    = $false
        Book4LightInTheDepths       = $false
        Book4Section272LossApplied  = $false
        Book4SteelAgainstShadowRoute = $false
        Book4BlessedBeTheThrowRoute = $false
        Book4ScrollRoute            = $false
        Book4Section283HolyWaterApplied = $false
        Book4SunBelowTheEarthRoute  = $false
        Book4OnyxBluffRoute         = $false
        Book4Section322RestApplied  = $false
        Book4ReturnToSenderPath     = $false
        Book4ChasmOfDoomSeen        = $false
        Book4DaggerOfVashnaClaimed  = $false
        Book5OedeClaimed            = $false
        Book5LimbdeathCured         = $false
        Book5PrisonBreak            = $false
        Book5TalonsTamed            = $false
        Book5CrystalPendantRoute    = $false
        Book5SoushillaNameHeard     = $false
        Book5SoushillaAsked         = $false
        Book5BanishmentRoute        = $false
        Book5HaakonDuelRoute        = $false
        Book5BookOfMagnakaiClaimed  = $false
    }
}

function New-LWAchievementState {
    return [pscustomobject]@{
        Unlocked          = @()
        SeenNotifications = @()
        ProgressFlags     = (New-LWAchievementProgressFlags)
        StoryFlags        = (New-LWStoryAchievementFlags)
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
        [bool]$RequiresPermadeath = $false,
        [bool]$Hidden = $false
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
        Hidden             = [bool]$Hidden
    }
}

function Get-LWAchievementDefinitions {
    if ($null -ne $script:LWAchievementDefinitionsCache) {
        return @($script:LWAchievementDefinitionsCache)
    }

    $script:LWAchievementDefinitionsCache = @(
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
        (New-LWAchievementDefinition -Id 'book_three_complete' -Name 'Book Three Complete' -Category 'Journey' -Description 'Complete Book 3.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'grave_bane' -Name 'Grave-Bane' -Category 'Combat' -Description 'Defeat an undead enemy with the Sommerswerd.' -Backfill:$true -ModePool 'Combat'),
        (New-LWAchievementDefinition -Id 'true_path' -Name 'True Path' -Category 'Legend' -Description 'Complete a book without using rewind.' -Backfill:$true -ModePool 'Exploration'),
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
        (New-LWAchievementDefinition -Id 'mortal_wolf' -Name 'Mortal Wolf' -Category 'Legend' -Description 'Complete a Hard or Veteran book with Permadeath enabled.' -ModePool 'Challenge' -RequiredDifficulty @('Hard', 'Veteran') -RequiresPermadeath:$true),
        (New-LWAchievementDefinition -Id 'aim_for_the_bushes' -Name 'Aim for the Bushes' -Category 'Journey' -Description 'Reach section 7 in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'found_the_clubhouse' -Name 'Found the Clubhouse' -Category 'Journey' -Description 'Reach section 13 in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'kill_the_mad_butcher' -Name 'Kill the Mad Butcher' -Category 'Journey' -Description 'Defeat the Mad Butcher in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'whats_in_the_box_book1' -Name 'What''s in the Box?' -Category 'Journey' -Description 'Claim the Silver Key from the box in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'use_the_force' -Name 'Use the Force' -Category 'Journey' -Description 'Take the hidden path from section 131 to 302 in Book 1.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'straight_to_the_throne' -Name 'Straight to the Throne' -Category 'Journey' -Description 'Finish Book 1 through the palace courtyard route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'royal_recovery' -Name 'Royal Recovery' -Category 'Journey' -Description 'Finish Book 1 through the recovery route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'the_back_way_in' -Name 'The Back Way In' -Category 'Journey' -Description 'Finish Book 1 through the Guildhall secret passage route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'open_sesame' -Name 'Open Sesame' -Category 'Journey' -Description 'Use the Golden Key route in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'hot_hands' -Name 'Hot Hands' -Category 'Journey' -Description 'Claim a Vordak Gem in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'star_of_toran' -Name 'Star of Toran' -Category 'Journey' -Description 'Claim the Crystal Star Pendant in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'field_medic' -Name 'Field Medic' -Category 'Journey' -Description 'Use Healing to save the wounded soldier in Book 1.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'found_the_sommerswerd' -Name 'Found the Sommerswerd' -Category 'Journey' -Description 'Claim the Sommerswerd in Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'you_have_chosen_wisely' -Name 'You Have Chosen Wisely' -Category 'Journey' -Description 'Defeat the Priest in section 158 of Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'neo_link' -Name 'Neo Link' -Category 'Journey' -Description 'Defeat Ganon + Dorier in section 270 of Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'by_a_thread' -Name 'By a Thread' -Category 'Journey' -Description 'Finish Book 2 through the rope-swing route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'skyfall' -Name 'Skyfall' -Category 'Journey' -Description 'Finish Book 2 through the Sommerswerd-and-Kraan skyfall route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'fight_through_the_smoke' -Name 'Fight Through the Smoke' -Category 'Journey' -Description 'Finish Book 2 by fighting back through the flagship deck.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'storm_tossed' -Name 'Storm-Tossed' -Category 'Journey' -Description 'Reach section 337 and still complete Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'seal_of_approval' -Name 'Seal of Approval' -Category 'Journey' -Description 'Reach the king''s audience route and claim the Sommerswerd in Book 2.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'papers_please' -Name 'Papers, Please' -Category 'Journey' -Description 'Trust forged access papers in Book 2 and pay the price.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'snakes_why' -Name 'Snakes, Why Did It Have to Be Snakes?' -Category 'Journey' -Description 'Reach the Javek ledge in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cliffhanger' -Name 'Cliffhanger' -Category 'Journey' -Description 'Witness Dyce''s fatal fall in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'whats_in_the_box' -Name 'What''s in the Box?' -Category 'Journey' -Description 'Claim the Diamond from the bone box in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'snowblind' -Name 'Snowblind' -Category 'Journey' -Description 'Suffer snow-blindness in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'you_touched_it_with_your_hands' -Name 'You Touched It With Your Hands?!' -Category 'Journey' -Description 'Claim the Ornate Silver Key as a Special Item in section 280 of Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'lucky_button_theory' -Name 'Lucky Button Theory' -Category 'Journey' -Description 'Press the right button sequence and reach section 102 in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'well_it_worked_once' -Name 'Well, It Worked Once' -Category 'Journey' -Description 'Reach section 65 after already reaching section 102 in Book 3.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cellfish' -Name 'Cellfish' -Category 'Journey' -Description 'Leave both prisoners to their fate in Book 3 by taking the cold path from section 13 to 254 and then walking away again at section 276.' -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'loi_kymar_lives' -Name 'Loi-Kymar Lives' -Category 'Journey' -Description 'Rescue Loi-Kymar and still complete Book 3.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'puppet_master' -Name 'Puppet Master' -Category 'Journey' -Description 'Finish Book 3 by turning the Effigy path against Vonotar.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'sun_on_the_ice' -Name 'Sun on the Ice' -Category 'Journey' -Description 'Finish Book 3 through the Sommerswerd endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'lucky_break' -Name 'Lucky Break' -Category 'Journey' -Description 'Finish Book 3 through the no-Effigy, no-Sommerswerd lucky route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'too_slow' -Name 'Too Slow' -Category 'Journey' -Description 'Watch the Book 3 endgame collapse after taking too long to stop Vonotar.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'book_four_complete' -Name 'Book Four Complete' -Category 'Journey' -Description 'Complete Book 4.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'sun_below_the_earth' -Name 'Sun Below The Earth' -Category 'Journey' -Description 'Finish Book 4 through the Sommerswerd endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'blessed_be_the_throw' -Name 'Blessed Be The Throw' -Category 'Journey' -Description 'Finish Book 4 through the Holy Water route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'steel_against_shadow' -Name 'Steel Against Shadow' -Category 'Journey' -Description 'Finish Book 4 through the direct Barraka duel route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'badge_of_office' -Name 'Badge of Office' -Category 'Journey' -Description 'Use the Badge of Rank trust route in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'wearing_the_enemys_colors' -Name 'Wearing the Enemy''s Colors' -Category 'Journey' -Description 'Claim the Onyx Medallion and use it to bluff your way deeper in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'read_the_signs' -Name 'Read the Signs' -Category 'Journey' -Description 'Use the Scroll route in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'return_to_sender' -Name 'Return to Sender' -Category 'Journey' -Description 'Claim Captain D''Val''s Sword and return it in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'deep_pockets_poor_timing' -Name 'Deep Pockets, Poor Timing' -Category 'Journey' -Description 'Lose your Backpack in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'bagless_but_breathing' -Name 'Bagless but Breathing' -Category 'Journey' -Description 'Lose your Backpack and recover a new one in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'shovel_ready' -Name 'Shovel Ready' -Category 'Journey' -Description 'Take a two-slot mining tool in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'light_in_the_depths' -Name 'Light in the Depths' -Category 'Journey' -Description 'Follow the lit mine path in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'chasm_of_doom' -Name 'Chasm of Doom' -Category 'Journey' -Description 'Reach the signature failure ending at section 347 in Book 4.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'washed_away' -Name 'Washed Away' -Category 'Journey' -Description 'Survive the Book 4 waterfall route that costs you your Backpack.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'book_five_complete' -Name 'Book Five Complete' -Category 'Journey' -Description 'Complete Book 5.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'kai_master' -Name 'Kai Master' -Category 'Legend' -Description 'Complete the full Kai sequence through Book 5.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'apothecarys_answer' -Name 'Apothecary''s Answer' -Category 'Journey' -Description 'Claim the Oede Herb and cure Limbdeath in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'prison_break' -Name 'Prison Break' -Category 'Journey' -Description 'Recover your confiscated gear in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'talons_tamed' -Name 'Talons Tamed' -Category 'Journey' -Description 'Mount the Itikar without having to subdue it in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'star_guided' -Name 'Star-Guided' -Category 'Journey' -Description 'Use the Crystal Star Pendant route in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'name_the_lost' -Name 'Name the Lost' -Category 'Journey' -Description 'Learn Soushilla''s name and ask for her in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'shadow_on_the_sand' -Name 'Shadow on the Sand' -Category 'Journey' -Description 'Finish Book 5 through the glowing-stone endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'face_to_face_with_haakon' -Name 'Face to Face with Haakon' -Category 'Journey' -Description 'Finish Book 5 through the Haakon duel route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true)
    )

    return @($script:LWAchievementDefinitionsCache)
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

    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'StoryFlags') -or $null -eq $State.Achievements.StoryFlags) {
        $State.Achievements | Add-Member -Force -NotePropertyName StoryFlags -NotePropertyValue (New-LWStoryAchievementFlags)
    }

    foreach ($propertyName in @('Book1AimForTheBushesVisited', 'Book1ClubhouseFound', 'Book1SilverKeyClaimed', 'Book1UseTheForcePath', 'Book1StraightToTheThrone', 'Book1RoyalRecovery', 'Book1BackWayIn', 'Book1OpenSesameRoute', 'Book1HotHandsClaimed', 'Book1StarOfToranClaimed', 'Book1FieldMedicPath', 'Book1LaumspurClaimed', 'Book1VordakGem76Claimed', 'Book1VordakGem304Claimed', 'Book1VordakGemCurseTriggered', 'Book2CoachTicketClaimed', 'Book2WhitePassClaimed', 'Book2RedPassClaimed', 'Book2PotentPotionClaimed', 'Book2MealOfLaumspurClaimed', 'Book2ForgedPapersBought', 'Book2Section106DamageApplied', 'Book2Section313Resolved', 'Book2Section337StormLossApplied', 'Book2SommerswerdClaimed', 'Book2ByAThreadRoute', 'Book2SkyfallRoute', 'Book2FightThroughTheSmokeRoute', 'Book2StormTossedSeen', 'Book2SealOfApprovalRoute', 'Book2PapersPleasePath', 'Book3SnakePitVisited', 'Book3CliffhangerSeen', 'Book3DiamondClaimed', 'Book3SnowblindSeen', 'Book3GrossKeyClaimed', 'Book3LuckyButtonTheorySeen', 'Book3WellItWorkedOnceSeen', 'Book3FirstCellAbandoned', 'Book3CellfishPathTaken', 'Book3LoiKymarRescued', 'Book3EffigyEndgameReached', 'Book3SommerswerdEndgameUsed', 'Book3LuckyEndgameUsed', 'Book3TooSlowFailureSeen', 'Book4Section12ResupplyHandled', 'Book4Section12MealsClaimed', 'Book4Section12RopeClaimed', 'Book4Section12PotionClaimed', 'Book4Section12SwordClaimed', 'Book4Section12SpearClaimed', 'Book4Section79SuppliesClaimed', 'Book4Section94LossApplied', 'Book4BadgeOfOfficePath', 'Book4OnyxMedallionClaimed', 'Book4Section117LightPath', 'Book4Section122MindAttackApplied', 'Book4Section123SuppliesClaimed', 'Book4Section158LossApplied', 'Book4Section167RecoveryClaimed', 'Book4BackpackLost', 'Book4BackpackRecovered', 'Book4WashedAway', 'Book4Section280GoldClaimed', 'Book4Section280MealClaimed', 'Book4Section280SwordClaimed', 'Book4CaptainSwordClaimed', 'Book4PotionOfRedLiquidClaimed', 'Book4ShovelReadyClaimed', 'Book4ScrollClaimed', 'Book4TorchesWillNotLight', 'Book4LightInTheDepths', 'Book4Section272LossApplied', 'Book4SteelAgainstShadowRoute', 'Book4BlessedBeTheThrowRoute', 'Book4ScrollRoute', 'Book4Section283HolyWaterApplied', 'Book4SunBelowTheEarthRoute', 'Book4OnyxBluffRoute', 'Book4Section322RestApplied', 'Book4ReturnToSenderPath', 'Book4ChasmOfDoomSeen', 'Book4DaggerOfVashnaClaimed')) {
        if (-not (Test-LWPropertyExists -Object $State.Achievements.StoryFlags -Name $propertyName) -or $null -eq $State.Achievements.StoryFlags.$propertyName) {
            $State.Achievements.StoryFlags | Add-Member -Force -NotePropertyName $propertyName -NotePropertyValue $false
        }
    }
}

function Rebuild-LWStoryAchievementFlagsFromState {
    if (-not (Test-LWHasState)) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    $visitedSections = @()
    if ($null -ne $script:GameState.CurrentBookStats -and (Test-LWPropertyExists -Object $script:GameState.CurrentBookStats -Name 'VisitedSections') -and $null -ne $script:GameState.CurrentBookStats.VisitedSections) {
        $visitedSections = @($script:GameState.CurrentBookStats.VisitedSections | ForEach-Object { [int]$_ })
    }
    if ($null -ne $script:GameState.CurrentSection) {
        $visitedSections += [int]$script:GameState.CurrentSection
    }
    $visitedSections = @($visitedSections | Sort-Object -Unique)

    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Type 'special'))) {
        Set-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed'
    }

    if ([int]$script:GameState.Character.BookNumber -eq 1) {
        if ($visitedSections -contains 66) {
            Set-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone'
        }
        if ($visitedSections -contains 212) {
            Set-LWStoryAchievementFlag -Name 'Book1RoyalRecovery'
        }
        if ($visitedSections -contains 332) {
            Set-LWStoryAchievementFlag -Name 'Book1BackWayIn'
        }
        if ($visitedSections -contains 326) {
            Set-LWStoryAchievementFlag -Name 'Book1OpenSesameRoute'
        }
        if ($visitedSections -contains 216) {
            Set-LWStoryAchievementFlag -Name 'Book1FieldMedicPath'
        }
        if ($visitedSections -contains 76) {
            Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
            Set-LWStoryAchievementFlag -Name 'Book1VordakGem76Claimed'
        }
        if ($visitedSections -contains 304) {
            Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
            Set-LWStoryAchievementFlag -Name 'Book1VordakGem304Claimed'
        }
        if ($visitedSections -contains 113) {
            Set-LWStoryAchievementFlag -Name 'Book1LaumspurClaimed'
        }
        if ($visitedSections -contains 236) {
            Set-LWStoryAchievementFlag -Name 'Book1VordakGemCurseTriggered'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCrystalStarPendantItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 2) {
        if ($visitedSections -contains 10) {
            Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed'
        }
        if ($visitedSections -contains 40) {
            Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed'
        }
        if ($visitedSections -contains 103) {
            Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed'
        }
        if ($visitedSections -contains 105) {
            Set-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute'
        }
        if ($visitedSections -contains 109) {
            Set-LWStoryAchievementFlag -Name 'Book2SkyfallRoute'
        }
        if ($visitedSections -contains 126 -and (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought')) {
            Set-LWStoryAchievementFlag -Name 'Book2PapersPleasePath'
        }
        if ($visitedSections -contains 142) {
            Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed'
        }
        if ($visitedSections -contains 185) {
            Set-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute'
        }
        if ($visitedSections -contains 196) {
            Set-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute'
        }
        if ($visitedSections -contains 263) {
            Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed'
        }
        if ($visitedSections -contains 337) {
            Set-LWStoryAchievementFlag -Name 'Book2StormTossedSeen'
            Set-LWStoryAchievementFlag -Name 'Book2Section337StormLossApplied'
        }
        if ($visitedSections -contains 313) {
            Set-LWStoryAchievementFlag -Name 'Book2Section313Resolved'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 3) {
        if ($visitedSections -contains 56) {
            Set-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued'
        }
        if ($visitedSections -contains 34) {
            Set-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached'
        }
        if ($visitedSections -contains 213) {
            Set-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed'
        }
        if ($visitedSections -contains 58) {
            Set-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed'
        }
        if ($visitedSections -contains 324) {
            Set-LWStoryAchievementFlag -Name 'Book3TooSlowFailureSeen'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 4) {
        if ($visitedSections -contains 22) {
            Set-LWStoryAchievementFlag -Name 'Book4LightInTheDepths'
            Set-LWStoryAchievementFlag -Name 'Book4Section117LightPath'
        }
        if ($visitedSections -contains 94) {
            Set-LWStoryAchievementFlag -Name 'Book4BackpackLost'
            Set-LWStoryAchievementFlag -Name 'Book4Section94LossApplied'
        }
        if ($visitedSections -contains 158) {
            Set-LWStoryAchievementFlag -Name 'Book4BackpackLost'
            Set-LWStoryAchievementFlag -Name 'Book4Section158LossApplied'
            Set-LWStoryAchievementFlag -Name 'Book4WashedAway'
        }
        if ($visitedSections -contains 167) {
            Set-LWStoryAchievementFlag -Name 'Book4BackpackRecovered'
            Set-LWStoryAchievementFlag -Name 'Book4Section167RecoveryClaimed'
        }
        if ($visitedSections -contains 195) {
            Set-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath'
        }
        if ($visitedSections -contains 279) {
            Set-LWStoryAchievementFlag -Name 'Book4ScrollRoute'
        }
        if ($visitedSections -contains 283) {
            Set-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute'
            Set-LWStoryAchievementFlag -Name 'Book4Section283HolyWaterApplied'
        }
        if ($visitedSections -contains 305) {
            Set-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute'
        }
        if ($visitedSections -contains 325) {
            Set-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute'
        }
        if ($visitedSections -contains 347) {
            Set-LWStoryAchievementFlag -Name 'Book4ChasmOfDoomSeen'
        }
        if ($visitedSections -contains 122) {
            Set-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute'
            Set-LWStoryAchievementFlag -Name 'Book4Section122MindAttackApplied'
        }
        if ($visitedSections -contains 322) {
            Set-LWStoryAchievementFlag -Name 'Book4Section322RestApplied'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWOnyxMedallionItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWScrollItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book4ScrollClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWDaggerOfVashnaItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMiningToolItemNames) -Type 'backpack'))) {
            Set-LWStoryAchievementFlag -Name 'Book4ShovelReadyClaimed'
        }
    }

    if ([int]$script:GameState.Character.BookNumber -eq 5) {
        if ($visitedSections -contains 2) {
            Set-LWStoryAchievementFlag -Name 'Book5OedeClaimed'
            Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
        }
        if ($visitedSections -contains 14) {
            Set-LWStoryAchievementFlag -Name 'Book5PrisonBreak'
        }
        if (@(308, 319) | Where-Object { $visitedSections -contains $_ }) {
            Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed'
        }
        if ($visitedSections -contains 336) {
            Set-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute'
        }
        if ($visitedSections -contains 356) {
            Set-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard'
        }
        if ($visitedSections -contains 307) {
            Set-LWStoryAchievementFlag -Name 'Book5SoushillaAsked'
        }
        if ($visitedSections -contains 268) {
            Set-LWStoryAchievementFlag -Name 'Book5BanishmentRoute'
        }
        if ($visitedSections -contains 353) {
            Set-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWBookOfMagnakaiItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book5BookOfMagnakaiClaimed'
        }
    }
}

function Test-LWStoryAchievementFlag {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Test-LWHasState)) {
        return $false
    }

    Ensure-LWAchievementState -State $script:GameState
    if (-not (Test-LWPropertyExists -Object $script:GameState.Achievements.StoryFlags -Name $Name)) {
        return $false
    }

    return [bool]$script:GameState.Achievements.StoryFlags.$Name
}

function Set-LWStoryAchievementFlag {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [bool]$Value = $true
    )

    if (-not (Test-LWHasState)) {
        return
    }

    Ensure-LWAchievementState -State $script:GameState
    if (-not (Test-LWPropertyExists -Object $script:GameState.Achievements.StoryFlags -Name $Name)) {
        $script:GameState.Achievements.StoryFlags | Add-Member -Force -NotePropertyName $Name -NotePropertyValue ([bool]$Value)
        return
    }

    $script:GameState.Achievements.StoryFlags.$Name = [bool]$Value
}

function Register-LWStorySectionAchievementTriggers {
    param([Parameter(Mandatory = $true)][int]$Section)

    if (-not (Test-LWHasState)) {
        return
    }

    switch ([int]$script:GameState.Character.BookNumber) {
        1 {
            switch ($Section) {
                7 { Set-LWStoryAchievementFlag -Name 'Book1AimForTheBushesVisited' }
                13 { Set-LWStoryAchievementFlag -Name 'Book1ClubhouseFound' }
                66 { Set-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone' }
                212 { Set-LWStoryAchievementFlag -Name 'Book1RoyalRecovery' }
                332 { Set-LWStoryAchievementFlag -Name 'Book1BackWayIn' }
            }
        }
        2 {
            switch ($Section) {
                10 { Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed' }
                40 { Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed' }
                103 { Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed' }
                105 { Set-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute' }
                109 { Set-LWStoryAchievementFlag -Name 'Book2SkyfallRoute' }
                126 {
                    if (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought') {
                        Set-LWStoryAchievementFlag -Name 'Book2PapersPleasePath'
                    }
                }
                142 { Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed' }
                185 { Set-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute' }
                196 { Set-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute' }
                263 { Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed' }
                337 { Set-LWStoryAchievementFlag -Name 'Book2StormTossedSeen' }
            }
        }
        3 {
            switch ($Section) {
                19 { Set-LWStoryAchievementFlag -Name 'Book3CliffhangerSeen' }
                34 { Set-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached' }
                56 { Set-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued' }
                58 { Set-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed' }
                65 {
                    if (Test-LWStoryAchievementFlag -Name 'Book3LuckyButtonTheorySeen') {
                        Set-LWStoryAchievementFlag -Name 'Book3WellItWorkedOnceSeen'
                    }
                }
                102 { Set-LWStoryAchievementFlag -Name 'Book3LuckyButtonTheorySeen' }
                213 { Set-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed' }
                276 {
                    if (Test-LWStoryAchievementFlag -Name 'Book3FirstCellAbandoned') {
                        Set-LWStoryAchievementFlag -Name 'Book3CellfishPathTaken'
                    }
                }
                324 { Set-LWStoryAchievementFlag -Name 'Book3TooSlowFailureSeen' }
                88 { Set-LWStoryAchievementFlag -Name 'Book3SnakePitVisited' }
                251 { Set-LWStoryAchievementFlag -Name 'Book3SnowblindSeen' }
            }
        }
        4 {
            switch ($Section) {
                22 {
                    Set-LWStoryAchievementFlag -Name 'Book4LightInTheDepths'
                    Set-LWStoryAchievementFlag -Name 'Book4Section117LightPath'
                }
                122 { Set-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute' }
                279 { Set-LWStoryAchievementFlag -Name 'Book4ScrollRoute' }
                283 {
                    Set-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute'
                }
                305 { Set-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute' }
                325 { Set-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute' }
                347 { Set-LWStoryAchievementFlag -Name 'Book4ChasmOfDoomSeen' }
            }
        }
        5 {
            switch ($Section) {
                2 {
                    Set-LWStoryAchievementFlag -Name 'Book5OedeClaimed'
                    Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
                }
                14 { Set-LWStoryAchievementFlag -Name 'Book5PrisonBreak' }
                307 { Set-LWStoryAchievementFlag -Name 'Book5SoushillaAsked' }
                308 { Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed' }
                319 { Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed' }
                336 { Set-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute' }
                353 { Set-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute' }
                356 { Set-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard' }
            }
        }
    }
}

function Register-LWStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    if (-not (Test-LWHasState)) {
        return
    }

    if ([int]$script:GameState.Character.BookNumber -eq 1 -and $FromSection -eq 131 -and $ToSection -eq 302) {
        Set-LWStoryAchievementFlag -Name 'Book1UseTheForcePath'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 1 -and $FromSection -eq 23 -and $ToSection -eq 326) {
        Set-LWStoryAchievementFlag -Name 'Book1OpenSesameRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 1 -and $FromSection -eq 88 -and $ToSection -eq 216) {
        Set-LWStoryAchievementFlag -Name 'Book1FieldMedicPath'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 2 -and $FromSection -eq 62 -and $ToSection -eq 126 -and (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought')) {
        Set-LWStoryAchievementFlag -Name 'Book2PapersPleasePath'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 2 -and $FromSection -eq 299 -and $ToSection -eq 118) {
        $magicSpearName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMagicSpearItemNames) -Type 'special'
        if (-not [string]::IsNullOrWhiteSpace($magicSpearName)) {
            [void](Remove-LWInventoryItemSilently -Type 'special' -Name $magicSpearName -Quantity 1)
            Write-LWInfo 'Section 299: Rhygar keeps the Magic Spear.'
        }
    }
    if ([int]$script:GameState.Character.BookNumber -eq 2 -and $FromSection -eq 338 -and $ToSection -eq 349) {
        $magicSpearName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMagicSpearItemNames) -Type 'special'
        if (-not [string]::IsNullOrWhiteSpace($magicSpearName)) {
            [void](Remove-LWInventoryItemSilently -Type 'special' -Name $magicSpearName -Quantity 1)
            Write-LWInfo 'Section 338: you leave the Magic Spear behind.'
        }
    }
    if ([int]$script:GameState.Character.BookNumber -eq 3 -and $FromSection -eq 13 -and $ToSection -eq 254) {
        Set-LWStoryAchievementFlag -Name 'Book3FirstCellAbandoned'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 95 -and $ToSection -eq 195) {
        Set-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 117 -and $ToSection -eq 22) {
        Set-LWStoryAchievementFlag -Name 'Book4LightInTheDepths'
        Set-LWStoryAchievementFlag -Name 'Book4Section117LightPath'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 258 -and $ToSection -eq 305) {
        Set-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 4 -and $FromSection -eq 296 -and $ToSection -eq 122) {
        Set-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 4 -and @(
            73,
            274
        ) -contains $FromSection -and $ToSection -eq 283) {
        Set-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 4 -and @(
            73,
            274
        ) -contains $FromSection -and $ToSection -eq 325) {
        Set-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 5 -and $FromSection -eq 221 -and $ToSection -eq 336) {
        Set-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 5 -and @(
            204,
            335
        ) -contains $FromSection -and $ToSection -eq 268) {
        Set-LWStoryAchievementFlag -Name 'Book5BanishmentRoute'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 5 -and $FromSection -eq 224 -and @(
            308,
            319
        ) -contains $ToSection) {
        Set-LWStoryAchievementFlag -Name 'Book5TalonsTamed'
    }
    if ([int]$script:GameState.Character.BookNumber -eq 5 -and $FromSection -eq 397 -and $ToSection -eq 307) {
        Set-LWStoryAchievementFlag -Name 'Book5SoushillaAsked'
    }
}

function Register-LWStoryInventoryAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-LWHasState)) {
        return
    }

    switch ([int]$script:GameState.Character.BookNumber) {
        1 {
            if (@('backpack', 'special') -contains $Type -and [int]$script:GameState.CurrentSection -eq 124 -and [string]$Name -match 'silver key') {
                Set-LWStoryAchievementFlag -Name 'Book1SilverKeyClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 76 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWVordakGemItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
                Set-LWStoryAchievementFlag -Name 'Book1VordakGem76Claimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 304 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWVordakGemItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed'
                Set-LWStoryAchievementFlag -Name 'Book1VordakGem304Claimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 349 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCrystalStarPendantItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed'
            }
        }
        2 {
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 79 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSommerswerdItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 10 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCoachTicketItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 142 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWWhitePassItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 263 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWRedPassItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 40 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWPotentHealingPotionItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 103 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMealOfLaumspurItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed'
            }
        }
        3 {
            if (@('backpack', 'special') -contains $Type -and [int]$script:GameState.CurrentSection -eq 218 -and [string]$Name -match 'diamond') {
                Set-LWStoryAchievementFlag -Name 'Book3DiamondClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 280 -and [string]$Name -match 'ornate silver key') {
                Set-LWStoryAchievementFlag -Name 'Book3GrossKeyClaimed'
            }
        }
        4 {
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 10 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOnyxMedallionItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 84 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWScrollItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4ScrollClaimed'
            }
            if ($Type -eq 'special' -and [int]$script:GameState.CurrentSection -eq 350 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWDaggerOfVashnaItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed'
            }
            if ($Type -eq 'weapon' -and [int]$script:GameState.CurrentSection -eq 222 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCaptainDValSwordWeaponNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed'
            }
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 268 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWPotionOfRedLiquidItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4PotionOfRedLiquidClaimed'
            }
            if ($Type -eq 'backpack' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMiningToolItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book4ShovelReadyClaimed'
            }
        }
        5 {
            if ($Type -eq 'backpack' -and [int]$script:GameState.CurrentSection -eq 2 -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOedeHerbItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book5OedeClaimed'
                Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
            }
            if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBookOfMagnakaiItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book5BookOfMagnakaiClaimed'
            }
            if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBlackCrystalCubeItemNames) -Target $Name))) {
                Set-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute'
            }
        }
    }
}

function Test-LWStateHasTorch {
    param([Parameter(Mandatory = $true)][object]$State)

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWTorchItemNames) -Type 'backpack')))
}

function Test-LWStateHasTinderbox {
    param([Parameter(Mandatory = $true)][object]$State)

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWTinderboxItemNames) -Type 'backpack')))
}

function Test-LWStateCanRelightTorch {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasFiresphere -State $State) {
        return $true
    }

    if (Test-LWStoryAchievementFlag -Name 'Book4TorchesWillNotLight') {
        return $false
    }

    return ((Test-LWStateHasTorch -State $State) -and (Test-LWStateHasTinderbox -State $State))
}

function Invoke-LWBookFourBackpackLoss {
    param([Parameter(Mandatory = $true)][string]$Reason)

    Set-LWStoryAchievementFlag -Name 'Book4BackpackLost'
    Lose-LWBackpack -WriteMessages -Reason $Reason
}

function Invoke-LWBookFourForcedPackOrWeaponLoss {
    param([string]$Reason = 'You lose an item while fumbling in the dark.')

    $backpackItems = @(Get-LWInventoryItems -Type 'backpack')
    if ($backpackItems.Count -gt 0) {
        Show-LWInventorySlotsSection -Type 'backpack'
        $slotMap = @(Get-LWBackpackSlotMap -Items $backpackItems | Where-Object { [bool]$_.IsPrimary })
        $validSlots = @($slotMap | ForEach-Object { [int]$_.Slot })
        $slot = if ($validSlots.Count -eq 1) { $validSlots[0] } else { $null }
        while ($null -eq $slot) {
            $candidate = Read-LWInt -Prompt ("Backpack slot to lose ({0})" -f (($validSlots -join ', '))) -Min ($validSlots | Measure-Object -Minimum).Minimum -Max ($validSlots | Measure-Object -Maximum).Maximum
            if ($validSlots -contains [int]$candidate) {
                $slot = [int]$candidate
            }
            else {
                Write-LWWarn ("Choose one of the occupied Backpack slots: {0}." -f ($validSlots -join ', '))
            }
        }

        $slotEntry = @($slotMap | Where-Object { [int]$_.Slot -eq $slot } | Select-Object -First 1)
        if ($slotEntry.Count -eq 0) {
            $slotEntry = @($slotMap | Select-Object -First 1)
        }
        $itemName = [string]$slotEntry[0].ItemName
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $itemName -Quantity 1)
        Write-LWInfo ("{0} Lost: {1}." -f $Reason, $itemName)
        return
    }

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($weapons.Count -gt 0) {
        Show-LWInventorySlotsSection -Type 'weapon'
        $slot = if ($weapons.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Weapon slot to lose' -Min 1 -Max $weapons.Count }
        $itemName = [string]$weapons[$slot - 1]
        [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $itemName -Quantity 1)
        Write-LWInfo ("{0} Lost weapon: {1}." -f $Reason, $itemName)
        return
    }

    Write-LWWarn $Reason
}

function Invoke-LWBookFourLoseOneWeapon {
    param([string]$Reason = 'You lose one Weapon.')

    $weapons = @(Get-LWInventoryItems -Type 'weapon')
    if ($weapons.Count -eq 0) {
        Write-LWWarn $Reason
        return
    }

    Show-LWInventorySlotsSection -Type 'weapon'
    $slot = if ($weapons.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Weapon slot to lose' -Min 1 -Max $weapons.Count }
    $itemName = [string]$weapons[$slot - 1]
    [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $itemName -Quantity 1)
    Write-LWInfo ("{0} Lost weapon: {1}." -f $Reason, $itemName)
}

function Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem {
    param([string]$Reason = 'You lose one Weapon or weapon-like Special Item.')

    $choices = @()
    foreach ($weapon in @(Get-LWInventoryItems -Type 'weapon')) {
        $choices += [pscustomobject]@{ Type = 'weapon'; Name = [string]$weapon; Display = ("Weapon: {0}" -f [string]$weapon) }
    }

    foreach ($specialName in @((Get-LWSommerswerdItemNames) + (Get-LWMagicSpearItemNames))) {
        $matching = Get-LWMatchingStateInventoryItem -State $script:GameState -Names @($specialName) -Type 'special'
        if (-not [string]::IsNullOrWhiteSpace($matching)) {
            $choices += [pscustomobject]@{ Type = 'special'; Name = [string]$matching; Display = ("Special Item: {0}" -f [string]$matching) }
        }
    }

    if ($choices.Count -eq 0) {
        Write-LWWarn $Reason
        return
    }

    Write-LWPanelHeader -Title 'Choose Lost Weapon' -AccentColor 'DarkYellow'
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$choices[$i].Display) -TextColor 'Gray' -BulletColor 'Yellow'
    }

    $choiceIndex = if ($choices.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Lost item number' -Min 1 -Max $choices.Count }
    $choice = $choices[$choiceIndex - 1]
    [void](Remove-LWInventoryItemSilently -Type ([string]$choice.Type) -Name ([string]$choice.Name) -Quantity 1)
    Write-LWInfo ("{0} Lost: {1}." -f $Reason, [string]$choice.Name)
}

function Invoke-LWBookFourTorchSupplies {
    param(
        [Parameter(Mandatory = $true)][int]$ExtraTorchCount,
        [Parameter(Mandatory = $true)][int]$Section
    )

    $supplyFlag = if ($Section -eq 79) { 'Book4Section79SuppliesClaimed' } else { 'Book4Section123SuppliesClaimed' }
    if (Test-LWStoryAchievementFlag -Name $supplyFlag) {
        return
    }

    Set-LWStoryAchievementFlag -Name $supplyFlag
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState
    $hasRelightSource = (Test-LWStateHasTinderbox -State $script:GameState) -or (Test-LWStateHasFiresphere -State $script:GameState)

    if (-not $hasRelightSource -and $hasBackpack) {
        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Tinderbox') {
            Write-LWInfo ("Section {0}: Tinderbox added from the mine stores." -f $Section)
        }
    }

    if (-not $hasBackpack) {
        Write-LWWarn ("Section {0}: you can use the lit Torch here, but without a Backpack you cannot keep the spare Torches or Tinderbox." -f $Section)
        return
    }

    $freeSlots = 8 - (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack'))
    $maxTake = [Math]::Min($ExtraTorchCount, [Math]::Max(0, $freeSlots))
    if ($maxTake -le 0) {
        Write-LWWarn ("Section {0}: no Backpack space remains for the spare Torches." -f $Section)
        return
    }

    $takeTorches = Read-LWInt -Prompt ("How many spare Torches keep from section {0}? (0-{1})" -f $Section, $maxTake) -Default $maxTake -Min 0 -Max $maxTake
    if ($takeTorches -gt 0) {
        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Torch' -Quantity $takeTorches)
        Write-LWInfo ("Section {0}: added {1} spare Torch{2}. The currently lit Torch is not recorded." -f $Section, $takeTorches, $(if ($takeTorches -eq 1) { '' } else { 'es' }))
    }
}

function Get-LWBookFourSectionChoiceLine {
    param([Parameter(Mandatory = $true)][object]$Choice)

    return (Format-LWBookFourStartingChoiceLine -Choice $Choice)
}

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

function Grant-LWBookFourGenericChoice {
    param(
        [Parameter(Mandatory = $true)][object]$Choice,
        [Parameter(Mandatory = $true)][string]$ContextLabel
    )

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

function Invoke-LWBookFourChoiceTable {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$PromptLabel,
        [Parameter(Mandatory = $true)][string]$ContextLabel,
        [Parameter(Mandatory = $true)][object[]]$Choices,
        [string]$Intro = ''
    )

    $availableChoices = @($Choices | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.FlagName) -or -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
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
            $availableChoices = @($Choices | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.FlagName) -or -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
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
        if (-not (Grant-LWBookFourGenericChoice -Choice $choice -ContextLabel $ContextLabel) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
            Invoke-LWBookFourStartingInventoryManagement
        }

        $availableChoices = @($Choices | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.FlagName) -or -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
    }
}

function Invoke-LWBookFourSectionEnduranceDelta {
    param(
        [Parameter(Mandatory = $true)][string]$FlagName,
        [Parameter(Mandatory = $true)][int]$Delta,
        [Parameter(Mandatory = $true)][string]$MessagePrefix,
        [string]$FatalCause = ''
    )

    if (Test-LWStoryAchievementFlag -Name $FlagName) {
        return $false
    }

    Set-LWStoryAchievementFlag -Name $FlagName
    if ($Delta -eq 0) {
        Write-LWInfo $MessagePrefix
        return $true
    }

    if ($Delta -lt 0) {
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss ([Math]::Abs([int]$Delta)) -Source 'sectiondamage'
        $appliedLoss = [int]$lossResolution.AppliedLoss
        if ($appliedLoss -gt 0) {
            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
        }

        $message = $MessagePrefix
        if ($appliedLoss -gt 0) {
            $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
        }
        else {
            $message += ' No ENDURANCE is lost.'
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
            $message += " $($lossResolution.Note)"
        }
        Write-LWInfo $message

        if (-not [string]::IsNullOrWhiteSpace($FatalCause)) {
            [void](Invoke-LWFatalEnduranceCheck -Cause $FatalCause)
        }

        return $true
    }

    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + [int]$Delta))
    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
    if ($restored -gt 0) {
        Add-LWBookEnduranceDelta -Delta $restored
        Register-LWManualRecoveryShortcut
    }

    $message = $MessagePrefix
    if ($restored -gt 0) {
        $message += " Restore $restored ENDURANCE point$(if ($restored -eq 1) { '' } else { 's' })."
    }
    else {
        $message += ' No ENDURANCE is restored because you are already at maximum.'
    }
    Write-LWInfo $message
    return $true
}

function New-LWSectionRandomNumberContext {
    param(
        [Parameter(Mandatory = $true)][int]$Section,
        [string]$Description = 'Plain random-number check.',
        [int]$Modifier = 0,
        [string[]]$ModifierNotes = @(),
        [bool]$ZeroCountsAsTen = $false,
        [bool]$Bypassed = $false,
        [string]$BypassReason = $null
    )

    return [pscustomobject]@{
        Section         = $Section
        Description     = $Description
        Modifier        = $Modifier
        ModifierNotes   = @($ModifierNotes)
        ZeroCountsAsTen = $ZeroCountsAsTen
        Bypassed        = $Bypassed
        BypassReason    = $BypassReason
    }
}

function Get-LWBookOneSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or [int]$State.Character.BookNumber -ne 1) {
        return $null
    }

    $section = [int]$State.CurrentSection
    if (@(2, 7, 17, 21, 22, 36, 44, 49, 89, 158, 160, 188, 205, 226, 237, 275, 279, 294, 302, 314, 337, 350) -contains $section) {
        return (New-LWSectionRandomNumberContext -Section $section)
    }

    return $null
}

function Get-LWBookTwoSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or [int]$State.Character.BookNumber -ne 2) {
        return $null
    }

    $section = [int]$State.CurrentSection
    if (@(10, 12, 21, 22, 31, 45, 57, 81, 99, 105, 114, 116, 122, 151, 152, 169, 175, 183, 197, 201, 210, 238, 278, 280, 300, 308, 316, 350) -contains $section) {
        return (New-LWSectionRandomNumberContext -Section $section)
    }

    return $null
}

function Get-LWBookThreeSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or [int]$State.Character.BookNumber -ne 3) {
        return $null
    }

    $section = [int]$State.CurrentSection
    switch ($section) {
        29 { return (New-LWSectionRandomNumberContext -Section $section) }
        54 {
            $modifier = 0
            $notes = @()
            if ((Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') -or (Test-LWStateHasDiscipline -State $State -Name 'Mindblast')) {
                $modifier += 3
                $notes += 'Mind Over Matter or Mindblast'
            }
            return (New-LWSectionRandomNumberContext -Section $section -Description 'Book 3 snowfield reaction check.' -Modifier $modifier -ModifierNotes $notes)
        }
        73 { return (New-LWSectionRandomNumberContext -Section $section) }
        74 { return (New-LWSectionRandomNumberContext -Section $section) }
        80 { return (New-LWSectionRandomNumberContext -Section $section) }
        86 { return (New-LWSectionRandomNumberContext -Section $section) }
        88 { return (New-LWSectionRandomNumberContext -Section $section -Description 'Javek venom survival check. Only a 9 is fatal.') }
        94 { return (New-LWSectionRandomNumberContext -Section $section -Description 'Icy-water survival check.') }
        96 { return (New-LWSectionRandomNumberContext -Section $section) }
        134 { return (New-LWSectionRandomNumberContext -Section $section) }
        142 { return (New-LWSectionRandomNumberContext -Section $section) }
        146 { return (New-LWSectionRandomNumberContext -Section $section) }
        149 {
            $modifier = 0
            $notes = @()
            if ((Test-LWStateHasDiscipline -State $State -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                $modifier += 2
                $notes += 'Tracking, Hunting, or Sixth Sense'
            }
            return (New-LWSectionRandomNumberContext -Section $section -Description 'Book 3 route-finding check.' -Modifier $modifier -ModifierNotes $notes)
        }
        152 { return (New-LWSectionRandomNumberContext -Section $section) }
        155 { return (New-LWSectionRandomNumberContext -Section $section) }
        167 { return (New-LWSectionRandomNumberContext -Section $section) }
        179 { return (New-LWSectionRandomNumberContext -Section $section) }
        183 { return (New-LWSectionRandomNumberContext -Section $section) }
        185 { return (New-LWSectionRandomNumberContext -Section $section) }
        211 { return (New-LWSectionRandomNumberContext -Section $section) }
        232 { return (New-LWSectionRandomNumberContext -Section $section) }
        258 {
            $modifier = 0
            $notes = @()
            if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                $modifier -= 2
                $notes += 'Hunting or Sixth Sense'
            }
            return (New-LWSectionRandomNumberContext -Section $section -Description 'Gold Bracelet backlash check.' -Modifier $modifier -ModifierNotes $notes -ZeroCountsAsTen:$true)
        }
        262 { return (New-LWSectionRandomNumberContext -Section $section) }
        272 { return (New-LWSectionRandomNumberContext -Section $section) }
        281 {
            $modifier = 0
            $notes = @()
            if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                $modifier -= 2
                $notes += 'Hunting or Sixth Sense'
            }
            return (New-LWSectionRandomNumberContext -Section $section -Description 'Baknar avoidance check.' -Modifier $modifier -ModifierNotes $notes -ZeroCountsAsTen:$true)
        }
        283 { return (New-LWSectionRandomNumberContext -Section $section) }
        284 { return (New-LWSectionRandomNumberContext -Section $section) }
        291 { return (New-LWSectionRandomNumberContext -Section $section) }
        302 { return (New-LWSectionRandomNumberContext -Section $section) }
        322 { return (New-LWSectionRandomNumberContext -Section $section) }
        323 { return (New-LWSectionRandomNumberContext -Section $section) }
        327 { return (New-LWSectionRandomNumberContext -Section $section) }
        331 { return (New-LWSectionRandomNumberContext -Section $section) }
        346 { return (New-LWSectionRandomNumberContext -Section $section) }
        350 { return (New-LWSectionRandomNumberContext -Section $section) }
        default { return $null }
    }
}

function Get-LWBookFiveSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or [int]$State.Character.BookNumber -ne 5) {
        return $null
    }

    $section = [int]$State.CurrentSection
    $disciplineCount = @($State.Character.Disciplines).Count
    $modifier = 0
    $modifierNotes = @()
    $description = $null
    $zeroCountsAsTen = $false
    $bypassed = $false
    $bypassReason = $null

    switch ($section) {
        11 {
            $description = 'Stealth-around-the-pillars check.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Camouflage') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                $modifier -= 2
                $modifierNotes += 'Camouflage or Hunting'
            }
        }
        15 {
            $description = 'Hide-in-the-tunnel check.'
            if ($disciplineCount -ge 7) {
                $modifier -= 1
                $modifierNotes += 'Kai rank Guardian+'
            }
        }
        23 {
            $description = 'Steam-shaft climb check.'
            if (Test-LWBookFiveLimbdeathActive) {
                $modifier -= 3
                $modifierNotes += 'Limbdeath'
            }
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 2
                $modifierNotes += 'Hunting'
            }
        }
        48 {
            $description = 'Kai lock-opening check.'
            if ($disciplineCount -ge 7) {
                $modifier += 3
                $modifierNotes += 'Kai rank Guardian+'
            }
        }
        49 {
            $description = 'Courier ambush check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 1
                $modifierNotes += 'Hunting'
            }
            if ($disciplineCount -ge 9) {
                $modifier += 3
                $modifierNotes += 'Kai rank Savant+'
            }
        }
        56 {
            $description = 'Harbour bow-shot check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                $modifier += 2
                $modifierNotes += 'Weaponskill'
            }
        }
        118 {
            $description = 'Blowpipe dodge check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 2
                $modifierNotes += 'Hunting'
            }
            if ($disciplineCount -ge 8) {
                $modifier += 1
                $modifierNotes += 'Kai rank Warmarn+'
            }
        }
        125 {
            $description = 'Leap-from-the-oars balance check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 2
                $modifierNotes += 'Hunting'
            }
        }
        127 {
            $description = 'Smash-the-door check. Add 10 and compare against Combat Skill.'
        }
        146 {
            $description = 'Forge stealth check.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Camouflage') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                $modifier -= 2
                $modifierNotes += 'Camouflage or Hunting'
            }
        }
        152 {
            $description = 'Outer-ledge balance check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 2
                $modifierNotes += 'Hunting'
            }
            if ($disciplineCount -ge 9) {
                $modifier += 2
                $modifierNotes += 'Kai rank Savant+'
            }
        }
        162 {
            $description = 'Steamspider climb damage roll. 0 counts as 10 if you cannot fight.'
            $zeroCountsAsTen = $true
        }
        180 {
            $description = 'Dagger-throw escape check.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                $modifier += 3
                $modifierNotes += 'Sixth Sense or Hunting'
            }
        }
        198 {
            $description = 'Maouk dart dodge check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 3
                $modifierNotes += 'Hunting'
            }
        }
        205 {
            $description = 'Freefall landing check.'
        }
        222 {
            $description = 'Vordak detection check.'
        }
        224 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Animal Kinship') {
                $bypassed = $true
                $bypassReason = 'Animal Kinship bypasses this Itikar random-number check.'
            }
            elseif (Test-LWStateHasInventoryItem -State $State -Names (Get-LWOnyxMedallionItemNames) -Type 'special') {
                $bypassed = $true
                $bypassReason = 'The Onyx Medallion bypasses this Itikar random-number check.'
            }
            else {
                $description = 'Itikar approach check.'
                if ($disciplineCount -ge 6) {
                    $modifier += 2
                    $modifierNotes += 'Kai rank Aspirant+'
                }
            }
        }
        229 {
            $description = 'Black Crystal Cube backlash check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') {
                $modifier += 3
                $modifierNotes += 'Sixth Sense'
            }
        }
        239 {
            if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWGraveweedItemNames) -Type 'backpack') {
                $bypassed = $true
                $bypassReason = 'A Tincture of Graveweed bypasses this check.'
            }
            else {
                $description = 'Hidden-door discovery check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $State -Name 'Camouflage')) {
                    $modifier += 2
                    $modifierNotes += 'Hunting, Tracking, or Camouflage'
                }
                if ($disciplineCount -ge 7) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Guardian+'
                }
            }
        }
        242 {
            $description = 'Hide-from-the-Vordak check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                $modifier += 2
                $modifierNotes += 'Camouflage'
            }
            if (Test-LWStateHasDiscipline -State $State -Name 'Mindshield') {
                $modifier += 3
                $modifierNotes += 'Mindshield'
            }
        }
        247 { $description = 'Approach-to-Ikaresh check.' }
        275 { $description = 'Falling-Itikar landing check.' }
        282 {
            if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                $bypassed = $true
                $bypassReason = 'Mind Over Matter bypasses this gangplank stealth check.'
            }
            else {
                $description = 'Gangplank stealth check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Camouflage')) {
                    $modifier += 2
                    $modifierNotes += 'Hunting or Camouflage'
                }
                if ($disciplineCount -ge 8) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Warmarn+'
                }
            }
        }
        301 {
            $description = 'Gate-spike climb check.'
            if ($disciplineCount -ge 7) {
                $modifier -= 2
                $modifierNotes += 'Kai rank Guardian+'
            }
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier -= 1
                $modifierNotes += 'Hunting'
            }
        }
        305 { $description = 'Falling-rope landing check.' }
        312 {
            if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                $bypassed = $true
                $bypassReason = 'Hunting or Sixth Sense bypasses this thrown-axe random-number check.'
            }
            else {
                $description = 'Thrown-axe survival check.'
            }
        }
        323 { $description = 'Skyship escape check.' }
        325 {
            $description = 'Blowpipe shot check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                $modifier += 2
                $modifierNotes += 'Weaponskill'
            }
        }
            336 {
                $description = 'Falling-Itikar landing check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Animal Kinship') {
                    $modifier -= 1
                    $modifierNotes += 'Animal Kinship'
                }
            }
        357 {
            $description = 'Platform fight fall check. Picking a 1 makes you fall.'
        }
        360 {
            $description = 'Twin-roll surprise check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 1
                $modifierNotes += 'Hunting'
            }
        }
        372 {
            $description = 'Crossbow-bolt exposure check.'
            if ($disciplineCount -ge 6) {
                $modifier += 2
                $modifierNotes += 'Kai rank Aspirant+'
            }
        }
        381 {
            $description = 'Axe-feint reaction check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 2
                $modifierNotes += 'Hunting'
            }
        }
        392 {
            $description = 'Ale-drinking balance check.'
            if ([int]$State.Character.EnduranceCurrent -lt 15) {
                $modifier -= 2
                $modifierNotes += 'Current END below 15'
            }
            elseif ([int]$State.Character.EnduranceCurrent -gt 25) {
                $modifier += 2
                $modifierNotes += 'Current END above 25'
            }
            if ($disciplineCount -ge 9) {
                $modifier += 3
                $modifierNotes += 'Kai rank Savant+'
            }
        }
        default { return $null }
    }

    return [pscustomobject]@{
        Section         = $section
        Description     = $description
        Modifier        = $modifier
        ModifierNotes   = @($modifierNotes)
        ZeroCountsAsTen = $zeroCountsAsTen
        Bypassed        = $bypassed
        BypassReason    = $bypassReason
    }
}

function Get-LWSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Character) {
        return $null
    }

    switch ([int]$State.Character.BookNumber) {
        1 { return (Get-LWBookOneSectionRandomNumberContext -State $State) }
        2 { return (Get-LWBookTwoSectionRandomNumberContext -State $State) }
        3 { return (Get-LWBookThreeSectionRandomNumberContext -State $State) }
        4 { return (Get-LWBookFourSectionRandomNumberContext -State $State) }
        5 { return (Get-LWBookFiveSectionRandomNumberContext -State $State) }
        default { return $null }
    }
}

function Get-LWBookFourSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or [int]$State.Character.BookNumber -ne 4) {
        return $null
    }

    $section = [int]$State.CurrentSection
    $disciplineCount = @($State.Character.Disciplines).Count
    $modifier = 0
    $modifierNotes = @()
    $description = $null
    $zeroCountsAsTen = $false
    $bypassed = $false
    $bypassReason = $null

    switch ($section) {
        11 { $description = 'Plain random-number check.' }
        13 { $description = 'Plain random-number check.' }
        31 { $description = 'Plain random-number check.' }
        35 {
            $description = 'Bridge-guard dash check.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or $disciplineCount -ge 7) {
                $modifier += 3
                $modifierNotes += 'Hunting or Kai rank Guardian+'
            }
        }
        43 {
            $description = 'Speed-and-accuracy check.'
            if ((Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') -or (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill')) {
                $modifier += 1
                $modifierNotes += 'Mind Over Matter or Weaponskill'
            }
            if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                $modifier += 2
                $modifierNotes += 'Hunting or Sixth Sense'
            }
        }
        50 { $description = 'Plain random-number check.' }
        59 { $description = 'Plain random-number check.' }
        63 { $description = 'Plain random-number check.' }
        67 {
            if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special') {
                $bypassed = $true
                $bypassReason = 'The Sommerswerd bypasses this random-number check here.'
            }
            else {
                $description = 'Disc-ambush escape check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter')) {
                    $modifier += 2
                    $modifierNotes += 'Hunting or Mind Over Matter'
                }
            }
        }
        75 {
            $description = 'Escape-from-the-melee check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                $modifier += 3
                $modifierNotes += 'Camouflage'
            }
        }
        96 { $description = 'Plain random-number check.' }
        112 {
            $description = 'Bridge impact survival check.'
            if ([int]$State.Character.EnduranceCurrent -lt 10) {
                $modifier -= 3
                $modifierNotes += 'Current END below 10'
            }
            elseif ([int]$State.Character.EnduranceCurrent -gt 20) {
                $modifier += 3
                $modifierNotes += 'Current END above 20'
            }
        }
        117 {
            if (Test-LWStateCanRelightTorch -State $State) {
                $bypassed = $true
                $bypassReason = 'A spare Torch and Tinderbox let you avoid this darkness roll.'
            }
            elseif (Test-LWStateHasFiresphere -State $State) {
                $bypassed = $true
                $bypassReason = 'A Kalte Firesphere lets you avoid this darkness roll.'
            }
            else {
                $description = 'Dark-bridge balance check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') -or (Test-LWStateHasDiscipline -State $State -Name 'Tracking')) {
                    $modifier += 3
                    $modifierNotes += 'Sixth Sense or Tracking'
                }
            }
        }
        126 { $description = 'Plain random-number check.' }
        128 {
            $description = 'Trapdoor escape check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 3
                $modifierNotes += 'Hunting'
            }
        }
        154 { $description = 'Plain random-number check.' }
        173 {
            if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSommerswerdItemNames) -Type 'special') {
                $bypassed = $true
                $bypassReason = 'The Sommerswerd bypasses this pillar-smash roll.'
            }
            else {
                $description = 'Pillar-smash check.'
                if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWMiningToolItemNames) -Type 'backpack') {
                    $modifier += 2
                    $modifierNotes += 'Pick or Shovel'
                }
            }
        }
        183 {
            $description = 'Crypt password bluff check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                $modifier += 4
                $modifierNotes += 'Camouflage'
            }
        }
        189 { $description = 'Plain random-number check.' }
        194 {
            $description = 'Underwater combat oxygen-threshold roll.'
            $zeroCountsAsTen = $true
            if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                $modifier += 2
                $modifierNotes += 'Mind Over Matter'
            }
        }
        207 {
            $description = 'Shot-saving check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                $modifier += 2
                $modifierNotes += 'Weaponskill'
            }
        }
        211 { $description = 'Plain random-number check.' }
        225 { $description = 'Plain random-number check.' }
        234 {
            $description = 'Underwater combat oxygen-threshold roll.'
            $zeroCountsAsTen = $true
            if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                $modifier += 2
                $modifierNotes += 'Mind Over Matter'
            }
        }
        240 { $description = 'Plain random-number check.' }
        247 { $description = 'Plain random-number check.' }
        249 {
            $description = 'Bow-shot leadership check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                $modifier += 2
                $modifierNotes += 'Weaponskill'
            }
        }
        271 {
            $description = 'Collapsing-bridge check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                $modifier += 2
                $modifierNotes += 'Hunting'
            }
        }
        309 {
            $description = 'Mine-ramp dash check.'
            if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                $modifier += 4
                $modifierNotes += 'Camouflage'
            }
        }
        319 { $description = 'Plain random-number check.' }
        343 {
            $description = 'Boat-capsize avoidance check.'
            if ([int]$State.Character.EnduranceCurrent -ge 20) {
                $modifier += 3
                $modifierNotes += 'Current END 20 or higher'
            }
            elseif ([int]$State.Character.EnduranceCurrent -le 12) {
                $modifier -= 2
                $modifierNotes += 'Current END 12 or lower'
            }
        }
        345 { $description = 'Plain random-number check.' }
        default { return $null }
    }

    return [pscustomobject]@{
        Section         = $section
        Description     = $description
        Modifier        = $modifier
        ModifierNotes   = @($modifierNotes)
        ZeroCountsAsTen = $zeroCountsAsTen
        Bypassed        = $bypassed
        BypassReason    = $bypassReason
    }
}

function Write-LWCurrentSectionRandomNumberRoll {
    param(
        [Parameter(Mandatory = $true)][int]$Roll,
        [object]$State = $script:GameState
    )

    $context = Get-LWSectionRandomNumberContext -State $State
    if ($null -eq $context) {
        Write-LWInfo ("Random Number Table roll: {0}" -f $Roll)
        return
    }

    $bookNumber = if ($null -ne $State -and $null -ne $State.Character) { [int]$State.Character.BookNumber } else { 0 }

    if ([bool]$context.Bypassed) {
        Write-LWInfo ("Random Number Table roll: {0}" -f $Roll)
        Write-LWInfo ("Book {0} section {1}: {2}" -f $bookNumber, [int]$context.Section, [string]$context.BypassReason)
        return
    }

    $effectiveBase = [int]$Roll
    if ([bool]$context.ZeroCountsAsTen -and $effectiveBase -eq 0) {
        $effectiveBase = 10
    }
    $adjusted = $effectiveBase + [int]$context.Modifier

    Write-LWInfo ("Random Number Table roll: {0}" -f $Roll)
    if ([bool]$context.ZeroCountsAsTen -and $Roll -eq 0) {
        Write-LWInfo ("Book {0} section {1}: this check treats 0 as 10." -f $bookNumber, [int]$context.Section)
    }
    if ([int]$context.Modifier -ne 0) {
        Write-LWInfo ("Book {0} section {1} modifier {2}: {3}." -f $bookNumber, [int]$context.Section, (Format-LWSigned -Value ([int]$context.Modifier)), ($(if (@($context.ModifierNotes).Count -gt 0) { (@($context.ModifierNotes) -join '; ') } else { 'context rule' })))
    }
    else {
        Write-LWInfo ("Book {0} section {1}: no automatic modifier applies." -f $bookNumber, [int]$context.Section)
    }
    Write-LWInfo ("Book {0} section {1} adjusted total: {2}. {3}" -f $bookNumber, [int]$context.Section, $adjusted, [string]$context.Description)
}

function Invoke-LWSectionEntryRules {
    if (-not (Test-LWHasState)) {
        return
    }

    $bookNumber = [int]$script:GameState.Character.BookNumber
    $section = [int]$script:GameState.CurrentSection

    switch ($bookNumber) {
        1 {
            switch ($section) {
                76 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1VordakGem76Claimed')) {
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss

                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }

                        $message = 'Section 76: the Vordak Gem burns your hand.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        Write-LWInfo $message

                        if (Invoke-LWFatalEnduranceCheck -Cause 'The heat of the Vordak Gem reduced your Endurance to zero.') {
                            return
                        }

                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Vordak Gem') {
                            Write-LWInfo 'Vordak Gem added to backpack.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Vordak Gem automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                113 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1LaumspurClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Laumspur Herb' -Quantity 2) {
                            Set-LWStoryAchievementFlag -Name 'Book1LaumspurClaimed'
                            Write-LWInfo 'Section 113: added 2 x Laumspur Herb. Each use restores 3 ENDURANCE and can also satisfy a Meal.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Laumspur Herb automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                124 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 124 Box' -PromptLabel 'Section 124 choice' -ContextLabel 'Section 124' -Choices (Get-LWBookOneSection124ChoiceDefinitions) -Intro 'Section 124: take the Gold Crowns and keep the Silver Key if you want it.'
                }
                137 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section137GemsClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Tomb Guardian Gems') {
                            Set-LWStoryAchievementFlag -Name 'Book1Section137GemsClaimed'
                            Write-LWInfo 'Section 137: Tomb Guardian Gems added as a single Backpack Item.'
                        }
                        else {
                            Write-LWWarn 'No room to add Tomb Guardian Gems automatically. Make room and add them manually if you are keeping them.'
                        }
                    }
                }
                144 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section144Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book1Section144Resolved'
                        Invoke-LWBookFourForcedPackOrWeaponLoss -Reason 'Section 144: something is stolen in the crush.'
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book1Section144DamageApplied' -Delta -2 -MessagePrefix 'Section 144: the runaway cart leaves you badly stunned.' -FatalCause 'The impact at section 144 reduced your Endurance to zero.')
                    }
                }
                146 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book1Section146DamageApplied' -Delta -3 -MessagePrefix 'Section 146: the ambush arrow grazes your forehead.' -FatalCause 'The ambush at section 146 reduced your Endurance to zero.')
                }
                188 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section188Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book1Section188Resolved'
                        $roll = Get-LWRandomDigit
                        Write-LWCurrentSectionRandomNumberRoll -Roll $roll
                        if ($roll -le 6) {
                            Lose-LWBackpack -WriteMessages -Reason 'Section 188: the Kraan rips away your Backpack'
                        }
                        else {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book1Section188DamageApplied' -Delta -3 -MessagePrefix 'Section 188: the Kraan''s attack leaves both your arms badly wounded.' -FatalCause 'The Kraan assault at section 188 reduced your Endurance to zero.')
                        }
                    }
                }
                205 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section205LossApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book1Section205LossApplied'
                        Save-LWInventoryRecoveryEntry -Type 'weapon' -Items @(Get-LWInventoryItems -Type 'weapon')
                        Save-LWInventoryRecoveryEntry -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')
                        Set-LWInventoryItems -Type 'weapon' -Items @()
                        Set-LWInventoryItems -Type 'backpack' -Items @()
                        Write-LWInfo 'Section 205: all Weapons and Backpack Items are taken from you.'
                    }
                }
                267 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 267 Saddlebag' -PromptLabel 'Section 267 choice' -ContextLabel 'Section 267' -Choices (Get-LWBookOneSection267ChoiceDefinitions) -Intro 'Section 267: keep the Message and Dagger if you want them.'
                }
                277 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section277BrokenWeapon')) {
                        Set-LWStoryAchievementFlag -Name 'Book1Section277BrokenWeapon'
                        Invoke-LWBookFourLoseOneWeapon -Reason 'Section 277: one Weapon is broken in the fall.'
                    }
                }
                236 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1VordakGemCurseTriggered')) {
                        $vordakGemName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWVordakGemItemNames) -Type 'backpack'
                        if (-not [string]::IsNullOrWhiteSpace($vordakGemName)) {
                            Set-LWStoryAchievementFlag -Name 'Book1VordakGemCurseTriggered'
                            [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $vordakGemName -Quantity 1)

                            $before = [int]$script:GameState.Character.EnduranceCurrent
                            $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 6 -Source 'sectiondamage'
                            $appliedLoss = [int]$lossResolution.AppliedLoss
                            if ($appliedLoss -gt 0) {
                                $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                                Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                            }

                            $oldBaseCs = [int]$script:GameState.Character.CombatSkillBase
                            $script:GameState.Character.CombatSkillBase = [Math]::Max(0, ([int]$script:GameState.Character.CombatSkillBase - 1))

                            $message = 'Section 236: the Vordak Gem curses you.'
                            if ($appliedLoss -gt 0) {
                                $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                            }
                            if ($script:GameState.Character.CombatSkillBase -lt $oldBaseCs) {
                                $message += ' Base Combat Skill is permanently reduced by 1.'
                            }
                            $message += ' One Vordak Gem is erased.'
                            if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                                $message += " $($lossResolution.Note)"
                            }
                            Write-LWInfo $message

                            [void](Invoke-LWFatalEnduranceCheck -Cause 'The curse of the Vordak Gem reduced your Endurance to zero.')
                        }
                    }
                }
                338 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section338RecoveryShown')) {
                        Set-LWStoryAchievementFlag -Name 'Book1Section338RecoveryShown'
                        $recoverWeapons = @((Get-LWInventoryRecoveryItems -Type 'weapon')).Count -gt 0
                        $recoverBackpack = @((Get-LWInventoryRecoveryItems -Type 'backpack')).Count -gt 0
                        if ($recoverWeapons -or $recoverBackpack) {
                            if ($recoverWeapons) {
                                Restore-LWInventorySection -Type 'weapon'
                            }
                            if ($recoverBackpack) {
                                Restore-LWInventorySection -Type 'backpack'
                            }
                            Write-LWInfo 'Section 338: recovered dropped Weapons and Backpack gear from the slope.'
                        }
                        else {
                            Write-LWInfo 'Section 338: recover any dropped Weapons and Backpack items if this route made you lose them earlier.'
                        }
                    }
                }
                347 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 347 Cabin' -PromptLabel 'Section 347 choice' -ContextLabel 'Section 347' -Choices (Get-LWBookOneSection347ChoiceDefinitions) -Intro 'Section 347: take the Torch, Short Sword, and Tinderbox if you want them.'
                }
                349 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1Section349PendantClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Crystal Star Pendant') {
                            Set-LWStoryAchievementFlag -Name 'Book1Section349PendantClaimed'
                            Set-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed'
                            Write-LWInfo 'Section 349: Crystal Star Pendant added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Crystal Star Pendant automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                304 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book1VordakGem304Claimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Vordak Gem') {
                            Write-LWInfo 'Section 304: Vordak Gem added to backpack.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Vordak Gem automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                315 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 315 Purse' -PromptLabel 'Section 315 choice' -ContextLabel 'Section 315' -Choices (Get-LWBookOneSection315ChoiceDefinitions) -Intro 'Section 315: take the purse contents if you want them before moving on.'
                }
            }
        }
        2 {
            switch ($section) {
                10 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Coach Ticket') {
                            Set-LWStoryAchievementFlag -Name 'Book2CoachTicketClaimed'
                            Write-LWInfo 'Section 10: Coach Ticket added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Coach Ticket automatically. Make room and add it manually if needed.'
                        }
                    }
                }
                31 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section31Restored')) {
                        Set-LWStoryAchievementFlag -Name 'Book2Section31Restored'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($before + 6))
                        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
                        if ($restored -gt 0) {
                            Add-LWBookEnduranceDelta -Delta $restored
                            Register-LWManualRecoveryShortcut
                        }
                        if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
                            Restore-LWBackpackState -WriteMessages
                            Write-LWInfo 'Section 31: if you had lost your Backpack, Rhygar outfits you with one here.'
                        }
                        Write-LWInfo ("Section 31: the physician restores {0} ENDURANCE." -f $restored)
                    }
                }
                40 {
                    $before = [int]$script:GameState.Character.EnduranceCurrent
                    $script:GameState.Character.EnduranceCurrent = [int]$script:GameState.Character.EnduranceMax
                    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
                    if ($restored -gt 0) {
                        Add-LWBookEnduranceDelta -Delta $restored
                        Write-LWInfo ('Section 40: Madin Rendalim restores all ENDURANCE lost so far.')
                    }

                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Potent Laumspur Potion') {
                            Set-LWStoryAchievementFlag -Name 'Book2PotentPotionClaimed'
                            Write-LWInfo 'Section 40: added Potent Laumspur Potion (+5 ENDURANCE after combat).'
                        }
                        else {
                            Write-LWWarn 'No room to add the Potent Laumspur Potion automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                103 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal of Laumspur') {
                            Set-LWStoryAchievementFlag -Name 'Book2MealOfLaumspurClaimed'
                            Write-LWInfo 'Section 103: added Meal of Laumspur. It can satisfy a Meal and restore 3 ENDURANCE, or be used any time for 3 ENDURANCE.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Meal of Laumspur automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                106 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section106DamageApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book2Section106DamageApplied'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss
                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }

                        $message = 'Section 106: the Magic Spear burns your mind as you pull it free.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        $message += ' The Helghast fight here is immune to Mindblast, uses Mindforce every round, and can only be harmed by the Magic Spear.'
                        Write-LWInfo $message

                        [void](Invoke-LWFatalEnduranceCheck -Cause 'The shock of the Magic Spear reduced your Endurance to zero.')
                    }
                }
                142 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'White Pass') {
                            Set-LWStoryAchievementFlag -Name 'Book2WhitePassClaimed'
                            Write-LWInfo 'Section 142: White Pass added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the White Pass automatically. Make room and add it manually if needed.'
                        }
                    }
                }
                196 {
                    Set-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute'
                    $sealName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSealOfHammerdalItemNames) -Type 'special'
                    if (-not [string]::IsNullOrWhiteSpace($sealName)) {
                        [void](Remove-LWInventoryItemSilently -Type 'special' -Name $sealName -Quantity 1)
                        Write-LWInfo 'Section 196: the Seal of Hammerdal is removed from your Special Items.'
                    }
                }
                69 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section69MindforceApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book2Section69MindforceApplied'
                        if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindshield')) {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book2Section69DamageApplied' -Delta -2 -MessagePrefix 'Section 69: the Helghast''s Mindforce tears at your thoughts.' -FatalCause 'The Helghast Mindforce at section 69 reduced your Endurance to zero.')
                        }
                        else {
                            Write-LWInfo 'Section 69: Mindshield blocks the Helghast''s Mindforce attack.'
                        }
                    }
                }
                263 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2RedPassClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Red Pass') {
                            Set-LWStoryAchievementFlag -Name 'Book2RedPassClaimed'
                            Write-LWInfo 'Section 263: Red Pass added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Red Pass automatically. Make room and add it manually if needed.'
                        }
                    }
                }
                289 {
                    if ([string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSealOfHammerdalItemNames) -Type 'special'))) {
                        Write-LWWarn 'Section 289 continuity note: if you no longer possess the Seal of Hammerdal, you should leave immediately for section 186.'
                    }
                }
                313 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section313Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book2Section313Resolved'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 4 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss
                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }
                        $magicSpearName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMagicSpearItemNames) -Type 'special'
                        if (-not [string]::IsNullOrWhiteSpace($magicSpearName)) {
                            [void](Remove-LWInventoryItemSilently -Type 'special' -Name $magicSpearName -Quantity 1)
                        }

                        $message = 'Section 313: the Helghast''s burnt claws tear into your neck.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                        }
                        $message += ' The Magic Spear is erased.'
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        Write-LWInfo $message

                        [void](Invoke-LWFatalEnduranceCheck -Cause 'The Helghast''s burnt claws reduced your Endurance to zero.')
                    }
                }
                327 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought')) {
                        $buyPapers = Read-LWYesNo -Prompt 'Buy the forged access papers here?' -Default $false
                        if ($buyPapers) {
                            $currentGold = [int]$script:GameState.Inventory.GoldCrowns
                            $pricePaid = [Math]::Min(6, $currentGold)
                            if ($pricePaid -gt 0) {
                                $script:GameState.Inventory.GoldCrowns = [int]($currentGold - $pricePaid)
                                Add-LWBookGoldDelta -Delta (-$pricePaid)
                            }
                            Set-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought'
                            Write-LWInfo ("Section 327: forged access papers acquired for the Red Pass route. Gold paid: {0}." -f $pricePaid)
                        }
                    }
                }
                337 {
                    Set-LWStoryAchievementFlag -Name 'Book2StormTossedSeen'
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section337StormLossApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book2Section337StormLossApplied'
                        $lostWeapons = @(Get-LWInventoryItems -Type 'weapon')
                        $lostBackpack = @(Get-LWInventoryItems -Type 'backpack')
                        if ($lostWeapons.Count -gt 0) {
                            Save-LWInventoryRecoveryEntry -Type 'weapon' -Items @($lostWeapons)
                            Set-LWInventoryItems -Type 'weapon' -Items @()
                        }
                        if ($lostBackpack.Count -gt 0) {
                            Save-LWInventoryRecoveryEntry -Type 'backpack' -Items @($lostBackpack)
                            Set-LWInventoryItems -Type 'backpack' -Items @()
                        }
                        Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
                        Write-LWInfo 'Section 337: the storm strips away all Weapons and Backpack Items. Gold, your Backpack, and surviving Special Items are kept.'
                    }
                }
                145 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book2Section145PoisonApplied' -Delta -5 -MessagePrefix 'Section 145: the tainted Laumspur purges the poison but leaves you violently ill.' -FatalCause 'The poisoned Laumspur at section 145 reduced your Endurance to zero.')
                }
                194 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book2Section194TheftApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book2Section194TheftApplied'
                        $script:GameState.Inventory.GoldCrowns = 0
                        Set-LWInventoryItems -Type 'weapon' -Items @()
                        Set-LWInventoryItems -Type 'backpack' -Items @()
                        Set-LWInventoryItems -Type 'special' -Items @()
                        Set-LWBackpackState -HasBackpack:$false
                        Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
                        Write-LWInfo 'Section 194: your Gold, Backpack, Weapons, and Special Items are stolen.'
                    }
                }
                262 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 262 Storeroom' -PromptLabel 'Section 262 choice' -ContextLabel 'Section 262' -Choices (Get-LWBookTwoSection262ChoiceDefinitions) -Intro 'Section 262: take whatever you want from the storeroom before you flee.'
                }
                302 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 302 Watchtower' -PromptLabel 'Section 302 choice' -ContextLabel 'Section 302' -Choices (Get-LWBookTwoSection302ChoiceDefinitions) -Intro 'Section 302: take whatever you want from the watchtower quarters before you leave.'
                }
            }
        }
        3 {
            switch ($section) {
                4 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 4 Search' -PromptLabel 'Section 4 choice' -ContextLabel 'Section 4' -Choices (Get-LWBookThreeSection004ChoiceDefinitions) -Intro 'Section 4: search the body and keep whatever you want.'
                }
                8 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied'
                        Write-LWInfo 'Section 8: Baknar oil applied. It lasts for the rest of Book 3 and protects you against some cold-based losses.'
                    }
                }
                91 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied'
                        Write-LWInfo 'Section 91: Baknar oil applied. It lasts for the rest of Book 3 and protects you against some cold-based losses.'
                    }
                }
                10 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section10BackpackHandled')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section10BackpackHandled'
                        Write-LWInfo 'Section 10: each liquid may only be examined once.'
                        if (-not (Test-LWStateHasBackpack -State $script:GameState) -and (Read-LWYesNo -Prompt 'Use the abandoned pack as your Backpack here?' -Default $true)) {
                            Restore-LWBackpackState -WriteMessages
                        }
                    }
                }
                12 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 12 Expedition Gear' -PromptLabel 'Section 12 choice' -ContextLabel 'Section 12' -Choices (Get-LWBookThreeSection012ChoiceDefinitions) -Intro 'Section 12: pack your share of the expedition gear now.'
                }
                18 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section18LossApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section18LossApplied'
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section18DamageApplied' -Delta -3 -MessagePrefix 'Section 18: the Ice Demon''s freezing blast rakes your arm.' -FatalCause 'The freezing blast at section 18 reduced your Endurance to zero.')
                        Invoke-LWLoseOneWeaponOrWeaponLikeSpecialItem -Reason 'Section 18: the freezing cyclone tears your weapon away.'
                    }
                }
                38 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 38 Supplies' -PromptLabel 'Section 38 choice' -ContextLabel 'Section 38' -Choices (Get-LWBookThreeSection038ChoiceDefinitions) -Intro 'Section 38: search the junk-filled room for anything useful.'
                }
                49 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section49BackpackLost')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section49BackpackLost'
                        Lose-LWBackpack -WriteMessages -Reason 'Section 49: your Backpack remains behind in the tent after the fall'
                    }
                }
                55 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section55Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section55Resolved'
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section55DamageApplied' -Delta -5 -MessagePrefix 'Section 55: the return climb leaves you badly frostbitten.' -FatalCause 'The frostbite at section 55 reduced your Endurance to zero.')
                        $oldBaseCs = [int]$script:GameState.Character.CombatSkillBase
                        $script:GameState.Character.CombatSkillBase = [Math]::Max(0, ($oldBaseCs - 2))
                        if ($script:GameState.Character.CombatSkillBase -lt $oldBaseCs) {
                            Write-LWWarn 'Section 55: base Combat Skill is permanently reduced by 2.'
                        }
                    }
                }
                79 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section79Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section79Resolved'
                        $graveweedName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWGraveweedItemNames) -Type 'backpack'
                        if (-not [string]::IsNullOrWhiteSpace($graveweedName)) {
                            [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $graveweedName -Quantity 1)
                            Write-LWInfo 'Section 79: Vial of Graveweed erased after poisoning the gruel.'
                        }
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section79RecoveryApplied' -Delta 6 -MessagePrefix 'Section 79: the herbs Loi-Kymar mixes restore your strength.')
                    }
                }
                84 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 84 Trophy' -PromptLabel 'Section 84 choice' -ContextLabel 'Section 84' -Choices (Get-LWBookThreeSection084ChoiceDefinitions) -Intro 'Section 84: keep the Blue Stone Triangle if you want it.'
                }
                102 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 102 Effigy' -PromptLabel 'Section 102 choice' -ContextLabel 'Section 102' -Choices (Get-LWBookThreeSection102ChoiceDefinitions) -Intro 'Section 102: keep the Stone Effigy if you want it before leaving the temple.'
                }
                129 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section129Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section129Resolved'
                        if (-not (Test-LWStateHasBaknarOilApplied -State $script:GameState)) {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section129DamageApplied' -Delta -3 -MessagePrefix 'Section 129: without Baknar oil, the winds of Kalte bite deep.' -FatalCause 'The cold at section 129 reduced your Endurance to zero.')
                        }
                        else {
                            Write-LWInfo 'Section 129: Baknar oil protects you from the cold-based ENDURANCE loss here.'
                        }
                    }
                }
                150 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section150Resolved')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section150Resolved'
                        if (-not (Test-LWStateHasBaknarOilApplied -State $script:GameState)) {
                            [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section150DamageApplied' -Delta -2 -MessagePrefix 'Section 150: the sudden cold from the Ice Demon punishes you.' -FatalCause 'The sudden cold at section 150 reduced your Endurance to zero.')
                        }
                        else {
                            Write-LWInfo 'Section 150: Baknar oil protects you from the sudden cold here.'
                        }
                    }
                }
                170 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section170DamageApplied')) {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section170DamageApplied' -Delta -6 -MessagePrefix 'Section 170: the Helghast tears at your throat before the fight begins.' -FatalCause 'The Helghast''s surprise attack at section 170 reduced your Endurance to zero.')
                    }
                }
                187 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section187BraceletClaimed') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Type 'special')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Gold Bracelet') {
                            Set-LWStoryAchievementFlag -Name 'Book3Section187BraceletClaimed'
                            Write-LWInfo 'Section 187: Gold Bracelet added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Gold Bracelet automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                231 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 231 Bracelet' -PromptLabel 'Section 231 choice' -ContextLabel 'Section 231' -Choices (Get-LWBookThreeSection231ChoiceDefinitions) -Intro 'Section 231: take a Gold Bracelet if you want it.'
                }
                236 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section236BraceletClaimed') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Type 'special')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Gold Bracelet') {
                            Set-LWStoryAchievementFlag -Name 'Book3Section236BraceletClaimed'
                            Write-LWInfo 'Section 236: Gold Bracelet added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Gold Bracelet automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                237 {
                    Write-LWInfo 'Section 237: this is still a meal section. Use meal here to resolve it before moving on.'
                }
                258 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section258BraceletRemoved')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section258BraceletRemoved'
                        [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Types @('special'))
                        Write-LWInfo 'Section 258: Gold Bracelet erased after you tear it away.'
                    }
                }
                280 {
                    $before = [int]$script:GameState.Character.EnduranceCurrent
                    $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 1 -Source 'sectiondamage'
                    $appliedLoss = [int]$lossResolution.AppliedLoss

                    if ($appliedLoss -gt 0) {
                        $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                        Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                    }

                    $message = 'Section 280: the Ornate Silver Key''s corrosive acid burns your hand.'
                    if ($appliedLoss -gt 0) {
                        $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
                    }
                    if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                        $message += " $($lossResolution.Note)"
                    }
                    $message += " Current Endurance: $($script:GameState.Character.EnduranceCurrent) / $($script:GameState.Character.EnduranceMax)."
                    Write-LWInfo $message

                    [void](Invoke-LWFatalEnduranceCheck -Cause 'The corrosive acid on the Ornate Silver Key reduced your Endurance to zero.')
                }
                282 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 282 Loot' -PromptLabel 'Section 282 choice' -ContextLabel 'Section 282' -Choices (Get-LWBookThreeSection282ChoiceDefinitions) -Intro 'Section 282: take the Spear and Blue Stone Disc if you want them.'
                }
                295 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 295 Firesphere' -PromptLabel 'Section 295 choice' -ContextLabel 'Section 295' -Choices (Get-LWBookThreeSection295ChoiceDefinitions) -Intro 'Section 295: keep the Firesphere if you want it before leaving the chamber.'
                }
                298 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 298 Trophy' -PromptLabel 'Section 298 choice' -ContextLabel 'Section 298' -Choices (Get-LWBookThreeSection298ChoiceDefinitions) -Intro 'Section 298: keep the Blue Stone Triangle if you want it.'
                }
                303 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section303KeyErased')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section303KeyErased'
                        [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWOrnateSilverKeyItemNames) -Types @('special', 'backpack'))
                        Write-LWInfo 'Section 303: Ornate Silver Key erased after opening the helm chamber.'
                    }
                }
                308 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section308SilverHelmClaimed') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSilverHelmItemNames) -Type 'special')) {
                        $helmetName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWHelmetItemNames) -Type 'special'
                        if (-not [string]::IsNullOrWhiteSpace($helmetName)) {
                            [void](Remove-LWInventoryItemSilently -Type 'special' -Name $helmetName -Quantity 1)
                            Write-LWInfo 'Section 308: ordinary Helmet discarded to keep the Silver Helm.'
                        }
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Silver Helm') {
                            Set-LWStoryAchievementFlag -Name 'Book3Section308SilverHelmClaimed'
                            Write-LWInfo 'Section 308: Silver Helm added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Silver Helm automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                }
                309 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 309 Finds' -PromptLabel 'Section 309 choice' -ContextLabel 'Section 309' -Choices (Get-LWBookThreeSection309ChoiceDefinitions) -Intro 'Section 309: keep the Blue Stone Triangle and Firesphere if you want them before returning to the tunnel.'
                }
                321 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 321 Stream' -PromptLabel 'Section 321 choice' -ContextLabel 'Section 321' -Choices (Get-LWBookThreeSection321ChoiceDefinitions) -Intro 'Section 321: keep the Blue Stone Triangle if you want it before moving on.'
                }
                326 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section326DamageApplied' -Delta -1 -MessagePrefix 'Section 326: forcing the lock with Kai skill leaves you badly fatigued.' -FatalCause 'The strain at section 326 reduced your Endurance to zero.')
                }
                328 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section328DamageApplied')) {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book3Section328DamageApplied' -Delta -6 -MessagePrefix 'Section 328: the Helghast tears at your throat before the fight begins.' -FatalCause 'The Helghast''s surprise attack at section 328 reduced your Endurance to zero.')
                    }
                }
                345 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book3Section345BraceletRemoved')) {
                        Set-LWStoryAchievementFlag -Name 'Book3Section345BraceletRemoved'
                        [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWGoldBraceletItemNames) -Types @('special'))
                        Write-LWInfo 'Section 345: Gold Bracelet erased after you tear it from your wrist.'
                    }
                }
            }
        }
        4 {
            switch ($section) {
                2 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 2 Loot' -PromptLabel 'Section 2 choice' -ContextLabel 'Section 2' -Choices (Get-LWBookFourSection002ChoiceDefinitions) -Intro 'Section 2: search the bodies and keep whatever you want before leaving the mines.'
                }
                3 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section003DamageApplied' -Delta -1 -MessagePrefix 'Section 3: the feigned-dead bandit lashes out and clips your legs.' -FatalCause 'The surprise attack at section 3 reduced your Endurance to zero.')
                }
                22 {
                    Invoke-LWBookFourForcedPackOrWeaponLoss -Reason 'Section 22: you fumble in the darkness and drop gear.'
                }
                44 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 44 Loot' -PromptLabel 'Section 44 choice' -ContextLabel 'Section 44' -Choices (Get-LWBookFourSection044ChoiceDefinitions) -Intro 'Section 44: search the fallen strangers and keep whatever you want.'
                }
                52 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section052DamageApplied' -Delta -1 -MessagePrefix 'Section 52: an arrow passes so close that it grazes your eye.' -FatalCause 'The arrow graze at section 52 reduced your Endurance to zero.')
                }
                67 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section067DamageApplied')) {
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section067DamageApplied' -Delta -1 -MessagePrefix 'Section 67: a razor disc grazes the back of your hand and hurls you from your horse.' -FatalCause 'The ambush at section 67 reduced your Endurance to zero.')
                    }
                }
                74 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section074RestApplied' -Delta 1 -MessagePrefix 'Section 74: the quiet night refreshes you.')
                }
                75 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section075DamageApplied' -Delta -2 -MessagePrefix 'Section 75: a spear thrust gashes your arm in the crush of battle.' -FatalCause 'The wound at section 75 reduced your Endurance to zero.')
                }
                10 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed')) {
                        if (Read-LWYesNo -Prompt 'Take the Onyx Medallion?' -Default $true) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Onyx Medallion') {
                                Set-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed'
                                Write-LWInfo 'Section 10: Onyx Medallion added to Special Items.'
                            }
                            else {
                                Write-LWWarn 'No room to add the Onyx Medallion automatically. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                }
                12 {
                    if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
                        Restore-LWBackpackState -WriteMessages
                        Set-LWStoryAchievementFlag -Name 'Book4BackpackRecovered'
                        Write-LWInfo 'Section 12: Captain D''Val outfits you with a fresh empty Backpack.'
                    }

                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section12ResupplyHandled')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section12ResupplyHandled'
                    }

                    $availableChoices = @(Get-LWBookFourSection12ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                    if ($availableChoices.Count -gt 0) {
                        Write-LWInfo 'Section 12: Captain D''Val offers you supplies from the wagon. Take whatever you want to keep.'
                    }

                    while ($availableChoices.Count -gt 0) {
                        Write-LWPanelHeader -Title 'Section 12 Supplies' -AccentColor 'DarkYellow'
                        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
                        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
                        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
                        Write-Host ''

                        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
                        }
                        Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
                        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

                        $choiceText = [string](Read-LWText -Prompt 'Section 12 choice' -Default '0' -NoRefresh)
                        if ([string]::IsNullOrWhiteSpace($choiceText)) {
                            $choiceText = '0'
                        }
                        $choiceText = $choiceText.Trim()

                        if ($choiceText -eq '0') {
                            break
                        }

                        if ($choiceText -match '^[dD]$') {
                            Remove-LWInventoryInteractive -InputParts @('drop')
                            $availableChoices = @(Get-LWBookFourSection12ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
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
                        if (-not (Grant-LWBookFourSection12Choice -Choice $choice) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
                            Invoke-LWBookFourStartingInventoryManagement
                        }

                        $availableChoices = @(Get-LWBookFourSection12ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                    }
                }
                78 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 78 Loot' -PromptLabel 'Section 78 choice' -ContextLabel 'Section 78' -Choices @(
                        [pscustomobject]@{ Id = 'holy_water'; FlagName = 'Book4Section078HolyWaterClaimed'; DisplayName = 'Flask of Holy Water'; Type = 'backpack'; Name = 'Flask of Holy Water'; Quantity = 1; Description = 'Flask of Holy Water' }
                    ) -Intro 'Section 78: claim the Flask of Holy Water if you want to keep it.'
                }
                79 {
                    Invoke-LWBookFourTorchSupplies -ExtraTorchCount 4 -Section 79
                }
                84 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4ScrollClaimed')) {
                        if (Read-LWYesNo -Prompt 'Take the Scroll?' -Default $true) {
                            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Scroll') {
                                Set-LWStoryAchievementFlag -Name 'Book4ScrollClaimed'
                                Write-LWInfo 'Section 84: Scroll added to Special Items.'
                            }
                        }
                    }
                }
                94 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section94LossApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section94LossApplied'
                        Invoke-LWBookFourBackpackLoss -Reason 'Section 94'
                    }
                }
                103 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section103DamageApplied' -Delta -4 -MessagePrefix 'Section 103: the scimitar wound bites deep as you escape.' -FatalCause 'The scimitar wound at section 103 reduced your Endurance to zero.')
                }
                109 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 109 Loot' -PromptLabel 'Section 109 choice' -ContextLabel 'Section 109' -Choices (Get-LWBookFourSection109ChoiceDefinitions) -Intro 'Section 109: search the dead bandit and keep whatever you want.'
                }
                117 {
                    if (Test-LWStateCanRelightTorch -State $script:GameState) {
                        Write-LWInfo 'Section 117: you have the means to relight and follow the lit path to section 22.'
                    }
                    elseif (Test-LWStateHasFiresphere -State $script:GameState) {
                        Write-LWInfo 'Section 117: your Kalte Firesphere can guide the way onward.'
                    }
                    else {
                        Write-LWWarn 'Section 117: without another Torch and Tinderbox, or a Kalte Firesphere, you cannot follow the lit path.'
                    }
                }
                122 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section122MindAttackApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section122MindAttackApplied'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 1 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss
                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }
                        $message = 'Section 122: Barraka''s mind assault strikes before the duel.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        Write-LWInfo $message
                        [void](Invoke-LWFatalEnduranceCheck -Cause 'Barraka''s opening mind assault reduced your Endurance to zero.')
                    }
                }
                123 {
                    Invoke-LWBookFourTorchSupplies -ExtraTorchCount 5 -Section 123
                }
                137 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section137RecoveryApplied' -Delta 6 -MessagePrefix 'Section 137: Laumspur treatment restores your strength.')
                }
                152 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 152 Loot' -PromptLabel 'Section 152 choice' -ContextLabel 'Section 152' -Choices (Get-LWBookFourSection152ChoiceDefinitions) -Intro 'Section 152: search the dead guard and keep whatever you want.'
                }
                157 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section157RestApplied' -Delta 1 -MessagePrefix 'Section 157: the forced sleep leaves you refreshed.')
                }
                158 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section158LossApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section158LossApplied'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss
                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }
                        Invoke-LWBookFourBackpackLoss -Reason 'Section 158'
                        $message = 'Section 158: the river batters you as your Backpack is swept away.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        Write-LWInfo $message
                        if (-not (Invoke-LWFatalEnduranceCheck -Cause 'The river route reduced your Endurance to zero.')) {
                            Set-LWStoryAchievementFlag -Name 'Book4WashedAway'
                        }
                    }
                }
                176 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section176DamageApplied' -Delta -3 -MessagePrefix 'Section 176: the mounted crash hurls you down and a blade bites into your shoulder.' -FatalCause 'The crash at section 176 reduced your Endurance to zero.')
                }
                167 {
                    if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
                        Restore-LWBackpackState -WriteMessages
                    }
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section167RecoveryClaimed')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section167RecoveryClaimed'
                        Set-LWStoryAchievementFlag -Name 'Book4BackpackRecovered'
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal') {
                            Write-LWInfo 'Section 167: the miner''s Backpack contains 1 Meal.'
                        }
                        if (Read-LWYesNo -Prompt 'Take the Shovel here? (2 Backpack slots)' -Default $false) {
                            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Shovel')
                        }
                    }
                }
                213 {
                    $availableChoices = @(Get-LWBookFourSection213ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                    if ($availableChoices.Count -gt 0) {
                        Write-LWInfo 'Section 213: choose any loot you want to keep from the supply table.'
                    }

                    while ($availableChoices.Count -gt 0) {
                        Write-LWPanelHeader -Title 'Section 213 Loot' -AccentColor 'DarkYellow'
                        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
                        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
                        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
                        Write-Host ''

                        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
                        }
                        Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
                        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

                        $choiceText = [string](Read-LWText -Prompt 'Section 213 choice' -Default '0' -NoRefresh)
                        if ([string]::IsNullOrWhiteSpace($choiceText)) {
                            $choiceText = '0'
                        }
                        $choiceText = $choiceText.Trim()

                        if ($choiceText -eq '0') {
                            break
                        }

                        if ($choiceText -match '^[dD]$') {
                            Remove-LWInventoryInteractive -InputParts @('drop')
                            $availableChoices = @(Get-LWBookFourSection213ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
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
                        if (-not (Grant-LWBookFourSection213Choice -Choice $choice) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
                            Invoke-LWBookFourStartingInventoryManagement
                        }

                        $availableChoices = @(Get-LWBookFourSection213ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                    }
                }
                222 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed')) {
                        if (Read-LWYesNo -Prompt 'Take Captain D''Val''s Sword?' -Default $true) {
                            if (Add-LWWeaponWithOptionalReplace -Name "Captain D'Val's Sword" -PromptLabel "Captain D'Val's Sword") {
                                Set-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed'
                            }
                        }
                    }
                }
                230 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 230 Loot' -PromptLabel 'Section 230 choice' -ContextLabel 'Section 230' -Choices (Get-LWBookFourSection230ChoiceDefinitions) -Intro 'Section 230: search the bodies and keep whatever you want before fleeing.'
                }
                231 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 231 Loot' -PromptLabel 'Section 231 choice' -ContextLabel 'Section 231' -Choices (Get-LWBookFourSection231ChoiceDefinitions) -Intro 'Section 231: search the dead guard and keep whatever you want before you cross the bridge.'
                }
                236 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section236DamageApplied' -Delta -4 -MessagePrefix 'Section 236: a thrown knife buries itself in your arm.' -FatalCause 'The knife wound at section 236 reduced your Endurance to zero.')
                }
                268 {
                    Write-LWInfo 'Section 268: loot here can include Spear, Broadsword, Iron Key, Brass Key, 2 Meals, and Potion of Red Liquid.'
                    if (Read-LWYesNo -Prompt 'Take the Spear?' -Default $false) {
                        [void](Add-LWWeaponWithOptionalReplace -Name 'Spear' -PromptLabel 'Spear')
                    }
                    if (Read-LWYesNo -Prompt 'Take the Broadsword?' -Default $false) {
                        [void](Add-LWWeaponWithOptionalReplace -Name 'Broadsword' -PromptLabel 'Broadsword')
                    }
                    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWIronKeyItemNames) -Type 'special') -and (Read-LWYesNo -Prompt 'Take the Iron Key?' -Default $true)) {
                        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Iron Key')
                    }
                    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBrassKeyItemNames) -Type 'special') -and (Read-LWYesNo -Prompt 'Take the Brass Key?' -Default $true)) {
                        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Brass Key')
                    }
                    if (Read-LWYesNo -Prompt 'Take the 2 Meals?' -Default $true) {
                        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 2)
                    }
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4PotionOfRedLiquidClaimed') -and (Read-LWYesNo -Prompt 'Take the Potion of Red Liquid?' -Default $true)) {
                        if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Potion of Red Liquid') {
                            Set-LWStoryAchievementFlag -Name 'Book4PotionOfRedLiquidClaimed'
                            Write-LWInfo 'Section 268: Potion of Red Liquid added to Backpack.'
                        }
                    }
                }
                270 {
                    if (Test-LWStateHasFiresphere -State $script:GameState) {
                        Write-LWInfo 'Section 270: your Kalte Firesphere can guide you through the vault.'
                    }
                    elseif (Test-LWStateCanRelightTorch -State $script:GameState) {
                        Write-LWInfo 'Section 270: you have Torch + Tinderbox to take the lit vault path.'
                    }
                    else {
                        Write-LWWarn 'Section 270: without Torch + Tinderbox, or a Kalte Firesphere, the lit vault path is unavailable.'
                    }
                }
                269 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 269 Loot' -PromptLabel 'Section 269 choice' -ContextLabel 'Section 269' -Choices @(
                        [pscustomobject]@{ Id = 'shovel'; FlagName = 'Book4Section269ShovelClaimed'; DisplayName = 'Shovel'; Type = 'backpack'; Name = 'Shovel'; Quantity = 1; Description = 'Shovel' }
                    ) -Intro 'Section 269: you may take one of the discarded Shovels if you want to keep it.'
                }
                272 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section272LossApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section272LossApplied'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 5 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss
                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }
                        Invoke-LWBookFourLoseOneWeapon -Reason 'Section 272 forces you to lose one Weapon.'
                        $message = 'Section 272: you are battered by the fall.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        Write-LWInfo $message
                        [void](Invoke-LWFatalEnduranceCheck -Cause 'The fall at section 272 reduced your Endurance to zero.')
                    }
                }
                263 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section263DamageApplied' -Delta -4 -MessagePrefix 'Section 263: the razor disc bites deeply into your shoulder.' -FatalCause 'The disc wound at section 263 reduced your Endurance to zero.')
                }
                275 {
                    if (Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section275DamageApplied' -Delta -1 -MessagePrefix 'Section 275: the cave-in blast throws you to the floor as the tunnel collapses.' -FatalCause 'The cave-in at section 275 reduced your Endurance to zero.') {
                        Write-LWInfo 'Section 275: all Torches are extinguished and must be relit if the text later allows it.'
                    }
                }
                280 {
                    $availableChoices = @(Get-LWBookFourSection280ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                    if ($availableChoices.Count -gt 0) {
                        Write-LWInfo 'Section 280: search the Bridge Guard and keep whatever you want before crossing the bridge.'
                    }

                    while ($availableChoices.Count -gt 0) {
                        Write-LWPanelHeader -Title 'Section 280 Loot' -AccentColor 'DarkYellow'
                        Write-LWKeyValue -Label 'Gold Crowns' -Value ("{0}/50" -f [int]$script:GameState.Inventory.GoldCrowns) -ValueColor 'Yellow'
                        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
                        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
                        Write-Host ''

                        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                            $choice = $availableChoices[$i]
                            $line = switch ([string]$choice.Type) {
                                'gold' { [string]$choice.DisplayName }
                                'weapon' { ("{0} [Weapon]" -f [string]$choice.DisplayName) }
                                'backpack' { ("{0} [Backpack, 1 slot]" -f [string]$choice.DisplayName) }
                                default { [string]$choice.DisplayName }
                            }
                            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), $line) -TextColor 'Gray' -BulletColor 'Yellow'
                        }
                        Write-LWBulletItem -Text 'D. Drop an item by number' -TextColor 'Gray' -BulletColor 'Yellow'
                        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

                        $choiceText = [string](Read-LWText -Prompt 'Section 280 choice' -Default '0' -NoRefresh)
                        if ([string]::IsNullOrWhiteSpace($choiceText)) {
                            $choiceText = '0'
                        }
                        $choiceText = $choiceText.Trim()

                        if ($choiceText -eq '0') {
                            break
                        }

                        if ($choiceText -match '^[dD]$') {
                            Remove-LWInventoryInteractive -InputParts @('drop')
                            $availableChoices = @(Get-LWBookFourSection280ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
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
                        if (-not (Grant-LWBookFourSection280Choice -Choice $choice) -and [string]$choice.Type -ne 'gold' -and (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true)) {
                            Invoke-LWBookFourStartingInventoryManagement
                        }

                        $availableChoices = @(Get-LWBookFourSection280ChoiceDefinitions | Where-Object { -not (Test-LWStoryAchievementFlag -Name ([string]$_.FlagName)) })
                    }
                }
                283 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section283HolyWaterApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section283HolyWaterApplied'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'sectiondamage'
                        $appliedLoss = [int]$lossResolution.AppliedLoss
                        if ($appliedLoss -gt 0) {
                            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
                            Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
                        }
                        [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWFlaskOfHolyWaterItemNames) -Types @('backpack', 'special'))
                        $message = 'Section 283: the Flask of Holy Water is used in the final assault.'
                        if ($appliedLoss -gt 0) {
                            $message += " Lose $appliedLoss ENDURANCE."
                        }
                        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
                            $message += " $($lossResolution.Note)"
                        }
                        Write-LWInfo $message
                        [void](Invoke-LWFatalEnduranceCheck -Cause 'The final assault at section 283 reduced your Endurance to zero.')
                    }
                }
                302 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 302 Satchel' -PromptLabel 'Section 302 choice' -ContextLabel 'Section 302' -Choices (Get-LWBookFourSection302ChoiceDefinitions) -Intro 'Section 302: the herbwarden''s satchel holds whatever you want to keep.'
                }
                303 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section303DamageApplied' -Delta -2 -MessagePrefix 'Section 303: the climb out of the bridge shaft leaves your knees and knuckles badly bruised.' -FatalCause 'The climb at section 303 reduced your Endurance to zero.')
                }
                29 {
                    Set-LWStoryAchievementFlag -Name 'Book4TorchesWillNotLight'
                    Write-LWInfo 'Section 29: torches no longer relight in these tunnels.'
                }
                118 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 118 Loot' -PromptLabel 'Section 118 choice' -ContextLabel 'Section 118' -Choices @(
                        [pscustomobject]@{ Id = 'whip'; FlagName = 'Book4Section118WhipClaimed'; DisplayName = 'Whip'; Type = 'backpack'; Name = 'Whip'; Quantity = 1; Description = 'Whip' }
                    ) -Intro 'Section 118: take the Whip if you want to keep it.'
                }
                322 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4Section322RestApplied')) {
                        Set-LWStoryAchievementFlag -Name 'Book4Section322RestApplied'
                        $before = [int]$script:GameState.Character.EnduranceCurrent
                        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ([int]$script:GameState.Character.EnduranceCurrent + 2))
                        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
                        if ($restored -gt 0) {
                            Add-LWBookEnduranceDelta -Delta $restored
                            Write-LWInfo ("Section 322: the rest restores {0} ENDURANCE." -f $restored)
                        }

                        Write-LWPanelHeader -Title 'Book 4 Mine Tools' -AccentColor 'DarkYellow'
                        Write-LWBulletItem -Text '0. Take nothing' -TextColor 'DarkGray' -BulletColor 'Yellow'
                        Write-LWBulletItem -Text '1. Pick' -TextColor 'Gray' -BulletColor 'Yellow'
                        Write-LWBulletItem -Text '2. Shovel' -TextColor 'Gray' -BulletColor 'Yellow'
                        $toolChoice = Read-LWInt -Prompt 'Choose a tool to take from section 322' -Default 0 -Min 0 -Max 2
                        if ($toolChoice -eq 1) {
                            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Pick')
                        }
                        elseif ($toolChoice -eq 2) {
                            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Shovel')
                        }
                    }
                }
                340 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section340DamageApplied' -Delta -2 -MessagePrefix 'Section 340: lack of oxygen makes your head spin and your legs turn to lead.' -FatalCause 'The suffocating water at section 340 reduced your Endurance to zero.')
                }
                341 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book4Section341DamageApplied' -Delta -4 -MessagePrefix 'Section 341: the arrow wound in your thigh is treated, but it still costs you dearly.' -FatalCause 'The arrow wound aftermath at section 341 reduced your Endurance to zero.')
                }
                327 {
                    $captainSwordName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCaptainDValSwordWeaponNames) -Type 'weapon'
                    if (-not [string]::IsNullOrWhiteSpace($captainSwordName)) {
                        [void](Remove-LWInventoryItemSilently -Type 'weapon' -Name $captainSwordName -Quantity 1)
                        Set-LWStoryAchievementFlag -Name 'Book4ReturnToSenderPath'
                        Write-LWInfo 'Section 327: Captain D''Val''s Sword is handed back and erased from your Weapons.'
                    }
                }
                350 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Dagger of Vashna') {
                            Set-LWStoryAchievementFlag -Name 'Book4DaggerOfVashnaClaimed'
                            Write-LWInfo 'Section 350: Dagger of Vashna added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Dagger of Vashna automatically. Make room and add it manually if needed.'
                        }
                    }
                }
            }
        }
        5 {
            switch ($section) {
                2 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 2 Herbal Cache' -PromptLabel 'Section 2 choice' -ContextLabel 'Section 2' -Choices (Get-LWBookFiveSection002ChoiceDefinitions) -Intro 'Section 2: take the Oede Herb if you want to keep it.'
                    if ((Test-LWStoryAchievementFlag -Name 'Book5Section002OedeClaimed') -and (Test-LWBookFiveLimbdeathActive -State $script:GameState)) {
                        $script:GameState.Conditions.BookFiveLimbdeath = $false
                        Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
                        Write-LWInfo 'Section 2: the Oede Herb cures your Limbdeath. Your Shield can be used again.'
                    }
                }
                3 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 3 Loot' -PromptLabel 'Section 3 choice' -ContextLabel 'Section 3' -Choices (Get-LWBookFiveSection003ChoiceDefinitions) -Intro 'Section 3: search the dead guards and keep whatever you want.'
                }
                10 {
                    if (-not (Test-LWStateHasConfiscatedEquipment)) {
                        Save-LWConfiscatedEquipment -WriteMessages -Reason 'Section 10: your captors strip you of all carried gear'
                    }
                }
                14 {
                    if (Restore-LWConfiscatedEquipment -WriteMessages) {
                        Set-LWStoryAchievementFlag -Name 'Book5PrisonBreak'
                    }
                }
                19 {
                    [void](Invoke-LWBookFiveLoseBackpackItems -Count 2 -Reason 'Section 19: the guards seize part of your kit.' -ExcludeMeals)
                }
                27 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 27 Apothecary' -PromptLabel 'Section 27 choice' -ContextLabel 'Section 27' -Choices (Get-LWBookFiveSection027ChoiceDefinitions) -Intro 'Section 27: buy whatever remedies you want before you move on.'
                }
                29 {
                    if ((Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Rope' -Quantity 1) -gt 0) {
                        Write-LWInfo 'Section 29: the Rope is used here and erased from your Backpack.'
                    }
                }
                35 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 35 Chamber Loot' -PromptLabel 'Section 35 choice' -ContextLabel 'Section 35' -Choices (Get-LWBookFiveSection035ChoiceDefinitions) -Intro 'Section 35: keep the Jewelled Mace and Copper Key if you want them.'
                }
                40 {
                    [void](Invoke-LWBookFiveLoseBackpackItems -Count 1 -Reason 'Section 40: the crowd strips one Backpack Item from you.')
                    if ([int]$script:GameState.Inventory.GoldCrowns -gt 0) {
                        Add-LWBookGoldDelta -Delta (-[int]$script:GameState.Inventory.GoldCrowns)
                        $script:GameState.Inventory.GoldCrowns = 0
                        Write-LWInfo 'Section 40: all Gold Crowns are taken from you.'
                    }
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section040DamageApplied' -Delta -2 -MessagePrefix 'Section 40: the beating leaves you dazed and aching.' -FatalCause 'The beating at section 40 reduced your Endurance to zero.')
                }
                52 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 52 Loot' -PromptLabel 'Section 52 choice' -ContextLabel 'Section 52' -Choices (Get-LWBookFiveSection052ChoiceDefinitions) -Intro 'Section 52: search the dead guards and keep whatever you want.'
                }
                63 {
                    if (-not (Test-LWBookFiveBloodPoisoningActive -State $script:GameState)) {
                        $script:GameState.Conditions.BookFiveBloodPoisoning = $true
                        Write-LWInfo 'Section 63: blood poisoning sets in. Lose 2 ENDURANCE at each new section until you swallow a Potion of Laumspur.'
                    }
                }
                67 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section067QuarterstaffClaimed')) {
                        if (Read-LWYesNo -Prompt 'Take the Quarterstaff?' -Default $true) {
                            if (Add-LWWeaponWithOptionalReplace -Name 'Quarterstaff' -PromptLabel 'Quarterstaff') {
                                Set-LWStoryAchievementFlag -Name 'Book5Section067QuarterstaffClaimed'
                            }
                        }
                    }
                }
                69 {
                    if (-not (Test-LWStateHasConfiscatedEquipment)) {
                        Save-LWConfiscatedEquipment -WriteMessages -Reason 'Section 69: you are imprisoned and all your gear is confiscated'
                    }
                }
                71 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section071TowelClaimed')) {
                        if (Read-LWYesNo -Prompt 'Keep the Towel? (2 Backpack slots)' -Default $false) {
                            if (TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Towel') {
                                Set-LWStoryAchievementFlag -Name 'Book5Section071TowelClaimed'
                                Write-LWInfo 'Section 71: Towel added to Backpack (2 slots).'
                            }
                            else {
                                Write-LWWarn 'No room to keep the Towel. Make room and add it manually if you are keeping it.'
                            }
                        }
                    }
                }
                100 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 100 Finds' -PromptLabel 'Section 100 choice' -ContextLabel 'Section 100' -Choices (Get-LWBookFiveSection100ChoiceDefinitions) -Intro 'Section 100: keep the Copper Key and Prism if you want them.'
                }
                101 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 101 Loot' -PromptLabel 'Section 101 choice' -ContextLabel 'Section 101' -Choices (Get-LWBookFiveSection003ChoiceDefinitions) -Intro 'Section 101: search the dead guards and keep whatever you want.'
                }
                102 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 102 Armoury Loot' -PromptLabel 'Section 102 choice' -ContextLabel 'Section 102' -Choices (Get-LWBookFiveSection102ChoiceDefinitions) -Intro 'Section 102: take whatever gear you want from the armoury.'
                }
                103 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section103RecoveryApplied' -Delta 2 -MessagePrefix 'Section 103: the soothing purple oil restores your strength.')
                }
                108 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section108DamageApplied' -Delta -2 -MessagePrefix 'Section 108: the corrosive gas burns your lungs and eyes.' -FatalCause 'The gas at section 108 reduced your Endurance to zero.')
                }
                130 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section130HerbPadClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Herb Pad') {
                            Set-LWStoryAchievementFlag -Name 'Book5Section130HerbPadClaimed'
                            Write-LWInfo 'Section 130: Herb Pad added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Herb Pad automatically. Make room and add it manually if you are keeping it.'
                        }
                    }
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section130RecoveryApplied' -Delta 1 -MessagePrefix 'Section 130: the poultice refreshes you.')
                }
                131 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 131 Chamber Loot' -PromptLabel 'Section 131 choice' -ContextLabel 'Section 131' -Choices (Get-LWBookFiveSection131ChoiceDefinitions) -Intro 'Section 131: take whatever you want from the chamber.'
                }
                154 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 154 Apothecary' -PromptLabel 'Section 154 choice' -ContextLabel 'Section 154' -Choices (Get-LWBookFiveSection154ChoiceDefinitions) -Intro 'Section 154: buy whatever potions you want before moving on.'
                }
                159 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section159DamageApplied' -Delta -2 -MessagePrefix 'Section 159: you crash through the door and take the brunt of the impact.' -FatalCause 'The crash at section 159 reduced your Endurance to zero.')
                }
                166 {
                    if (-not (Test-LWBookFiveLimbdeathActive -State $script:GameState)) {
                        $script:GameState.Conditions.BookFiveLimbdeath = $true
                        Write-LWInfo 'Section 166: Limbdeath cripples your sword-arm. Shield use is lost and your Combat Skill suffers -3 until cured.'
                    }
                }
                169 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 169 Market Stall' -PromptLabel 'Section 169 choice' -ContextLabel 'Section 169' -Choices (Get-LWBookFiveSection169ChoiceDefinitions) -Intro 'Section 169: buy the Black Sash if you want it.'
                }
                176 {
                    if (-not (Test-LWStateHasConfiscatedEquipment)) {
                        Save-LWConfiscatedEquipment -WriteMessages -Reason 'Section 176: surrender leaves you stripped of all your gear'
                    }
                }
                207 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 207 Loot' -PromptLabel 'Section 207 choice' -ContextLabel 'Section 207' -Choices (Get-LWBookFiveSection207ChoiceDefinitions) -Intro 'Section 207: take the purse and Brass Whistle if you want them.'
                }
                211 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section211RecoveryApplied' -Delta 2 -MessagePrefix 'Section 211: the rest and food restore your strength.')
                    Invoke-LWBookFourChoiceTable -Title 'Section 211 Market' -PromptLabel 'Section 211 choice' -ContextLabel 'Section 211' -Choices (Get-LWBookFiveSection211ChoiceDefinitions) -Intro 'Section 211: buy the Bottle of Kourshah if you want it.'
                }
                254 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section254DamageApplied' -Delta -2 -MessagePrefix 'Section 254: the brutal climb tears at your hands and knees.' -FatalCause 'The climb at section 254 reduced your Endurance to zero.')
                }
                255 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 255 Discovery' -PromptLabel 'Section 255 choice' -ContextLabel 'Section 255' -Choices (Get-LWBookFiveSection255ChoiceDefinitions) -Intro 'Section 255: keep the Black Crystal Cube if you want it.'
                }
                270 {
                    $backpackCount = @(Get-LWInventoryItems -Type 'backpack').Count
                    if ($backpackCount -gt 0) {
                        $lossCount = [Math]::Min(2, $backpackCount)
                        [void](Invoke-LWBookFiveLoseBackpackItems -Count $lossCount -Reason 'Section 270: the chaos costs you Backpack gear.')
                    }
                    else {
                        Invoke-LWBookFourLoseOneWeapon -Reason 'Section 270 forces you to lose one Weapon.'
                        $specialItems = @(Get-LWInventoryItems -Type 'special')
                        if ($specialItems.Count -gt 0) {
                            Show-LWInventorySlotsSection -Type 'special'
                            $slot = if ($specialItems.Count -eq 1) { 1 } else { Read-LWInt -Prompt 'Special Item slot to lose' -Min 1 -Max $specialItems.Count }
                            $lostSpecial = [string]$specialItems[$slot - 1]
                            [void](Remove-LWInventoryItemSilently -Type 'special' -Name $lostSpecial -Quantity 1)
                            Write-LWInfo ("Section 270: lost Special Item {0}." -f $lostSpecial)
                        }
                    }
                }
                281 {
                    Invoke-LWBookFourChoiceTable -Title 'Section 281 Treasure' -PromptLabel 'Section 281 choice' -ContextLabel 'Section 281' -Choices (Get-LWBookFiveSection281ChoiceDefinitions) -Intro 'Section 281: keep the Jewelled Mace if you want it.'
                }
                302 {
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section302RecoveryApplied' -Delta 3 -MessagePrefix 'Section 302: the food and rest restore your strength.')
                    Write-LWInfo 'Section 302: if you accept the drugged ale here, move to section 392.'
                }
                350 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section350SommerswerdLost')) {
                        $removed = Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Types @('special')
                        if ($removed -gt 0) {
                            Set-LWStoryAchievementFlag -Name 'Book5Section350SommerswerdLost'
                            Write-LWInfo 'Section 350: the Sommerswerd is torn from your grasp and lost in the abyss.'
                        }
                    }
                    [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section350DamageApplied' -Delta -3 -MessagePrefix 'Section 350: the battle with the shadow drains you badly.' -FatalCause 'The confrontation at section 350 reduced your Endurance to zero.')
                }
                393 {
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section393MindAttackApplied') -and -not (Test-LWStateHasMindshield -State $script:GameState)) {
                        Set-LWStoryAchievementFlag -Name 'Book5Section393MindAttackApplied'
                        [void](Invoke-LWBookFourSectionEnduranceDelta -FlagName 'Book5Section393DamageApplied' -Delta -2 -MessagePrefix 'Section 393: the mental assault hits before steel is drawn.' -FatalCause 'The mental assault at section 393 reduced your Endurance to zero.')
                    }
                }
                400 {
                    if ((Test-LWStoryAchievementFlag -Name 'Book5Section350SommerswerdLost') -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSommerswerdItemNames) -Type 'special')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Sommerswerd') {
                            Write-LWInfo 'Section 400: the Sommerswerd is recovered from the ruins.'
                        }
                        else {
                            Write-LWWarn 'No room to restore the Sommerswerd automatically. Make room and add it manually if needed.'
                        }
                    }
                    if (-not (Test-LWStoryAchievementFlag -Name 'Book5Section400MagnakaiClaimed')) {
                        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Book of the Magnakai') {
                            Set-LWStoryAchievementFlag -Name 'Book5Section400MagnakaiClaimed'
                            Write-LWInfo 'Section 400: Book of the Magnakai added to Special Items.'
                        }
                        else {
                            Write-LWWarn 'No room to add the Book of the Magnakai automatically. Make room and add it manually if needed.'
                        }
                    }
                }
            }
        }
    }

    Show-LWSectionGateHints
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

function Register-LWFailureState {
    param([string]$Cause = '')

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

function Invoke-LWFailure {
    param([string]$Cause = '')

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

function Get-LWBookOneStartingExtraItemDefinition {
    param([Parameter(Mandatory = $true)][ValidateRange(0, 9)][int]$Roll)

    switch ($Roll) {
        1 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Sword'; Quantity = 1; Gold = 0; Description = 'Sword' } }
        2 { return [pscustomobject]@{ Type = 'special'; Name = 'Helmet'; Quantity = 1; Gold = 0; Description = 'Helmet' } }
        3 { return [pscustomobject]@{ Type = 'backpack'; Name = 'Meal'; Quantity = 2; Gold = 0; Description = 'Two Meals' } }
        4 { return [pscustomobject]@{ Type = 'special'; Name = 'Chainmail Waistcoat'; Quantity = 1; Gold = 0; Description = 'Chainmail Waistcoat' } }
        5 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Mace'; Quantity = 1; Gold = 0; Description = 'Mace' } }
        6 { return [pscustomobject]@{ Type = 'backpack'; Name = 'Healing Potion'; Quantity = 1; Gold = 0; Description = 'Healing Potion' } }
        7 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Gold = 0; Description = 'Quarterstaff' } }
        8 { return [pscustomobject]@{ Type = 'weapon'; Name = 'Spear'; Quantity = 1; Gold = 0; Description = 'Spear' } }
        9 { return [pscustomobject]@{ Type = 'gold'; Name = ''; Quantity = 0; Gold = 12; Description = '12 Gold Crowns' } }
        default { return [pscustomobject]@{ Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Gold = 0; Description = 'Broadsword' } }
    }
}

function Apply-LWBookOneStartingEquipment {
    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 1) {
        return
    }

    $startingGoldRoll = Get-LWRandomDigit
    $extraItemRoll = Get-LWRandomDigit
    $extraItem = Get-LWBookOneStartingExtraItemDefinition -Roll $extraItemRoll

    $weapons = @('Axe')
    $backpackItems = @('Meal')
    $specialItems = @('Map of Sommerlund')
    $goldCrowns = [int]$startingGoldRoll

    switch ([string]$extraItem.Type) {
        'weapon' {
            for ($i = 0; $i -lt [int]$extraItem.Quantity; $i++) {
                $weapons += [string]$extraItem.Name
            }
        }
        'backpack' {
            for ($i = 0; $i -lt [int]$extraItem.Quantity; $i++) {
                $backpackItems += [string]$extraItem.Name
            }
        }
        'special' {
            for ($i = 0; $i -lt [int]$extraItem.Quantity; $i++) {
                $specialItems += [string]$extraItem.Name
            }
        }
        'gold' {
            $goldCrowns += [int]$extraItem.Gold
        }
    }

    $script:GameState.Inventory.Weapons = @($weapons)
    $script:GameState.Inventory.BackpackItems = @($backpackItems)
    $script:GameState.Inventory.SpecialItems = @($specialItems)
    $script:GameState.Inventory.GoldCrowns = [Math]::Min(50, [Math]::Max(0, $goldCrowns))

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages

    Write-LWInfo ("Book 1 starting gold roll: {0} Gold Crowns." -f $startingGoldRoll)
    Write-LWInfo ("Book 1 monastery find roll: {0} -> {1}." -f $extraItemRoll, [string]$extraItem.Description)
}

function Get-LWBookTwoArmoryChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'short_sword'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'two_meals'; DisplayName = 'Two Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = 'Two Meals' },
        [pscustomobject]@{ Id = 'chainmail'; DisplayName = 'Chainmail Waistcoat'; Type = 'special'; Name = 'Chainmail Waistcoat'; Quantity = 1; Description = 'Chainmail Waistcoat' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'healing_potion'; DisplayName = 'Healing Potion'; Type = 'backpack'; Name = 'Healing Potion'; Quantity = 1; Description = 'Healing Potion' },
        [pscustomobject]@{ Id = 'quarterstaff'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'shield'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' },
        [pscustomobject]@{ Id = 'broadsword'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' }
    )
}

function Grant-LWBookTwoArmoryChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return
    }

    if ([string]$Choice.Type -eq 'weapon' -and @($script:GameState.Inventory.Weapons).Count -ge 2) {
        Write-LWInfo 'Book 2 allows you to exchange one of your carried weapons for an armory choice.'
        Show-LWInventorySlotsSection -Type 'weapon'
        $slot = Read-LWInt -Prompt ("Replace which weapon with {0}?" -f [string]$Choice.DisplayName) -Min 1 -Max 2
        $weapons = @(Get-LWInventoryItems -Type 'weapon')
        $replacedWeapon = [string]$weapons[$slot - 1]
        $weapons[$slot - 1] = [string]$Choice.Name
        Set-LWInventoryItems -Type 'weapon' -Items @($weapons)
        Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
        Write-LWInfo ("Exchanged {0} for {1}." -f $replacedWeapon, [string]$Choice.DisplayName)
        return
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 2 armory choice added: {0}." -f [string]$Choice.Description)
        return
    }

    Write-LWWarn ("Could not add the Book 2 armory choice '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
}

function Apply-LWBookTwoStartingEquipment {
    param([switch]$CarryExistingGear)

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 2) {
        return
    }

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold

    Write-LWInfo ("Book 2 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 2 starting gold is lost.'
    }

    foreach ($specialItem in @('Map of Sommerlund', 'Seal of Hammerdal')) {
        $names = if ($specialItem -eq 'Map of Sommerlund') { Get-LWMapOfSommerlundItemNames } else { Get-LWSealOfHammerdalItemNames }
        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names $names -Type 'special')) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name $specialItem) {
                Write-LWInfo ("Book 2 starting Special Item added: {0}." -f $specialItem)
            }
            else {
                Write-LWWarn ("No room to add {0} automatically. Make room and add it manually if needed." -f $specialItem)
            }
        }
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose two Book 2 armory items now. You may exchange one or both carried weapons.' } else { 'Choose two Book 2 armory items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 2) {
        $availableChoices = @(Get-LWBookTwoArmoryChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 2 Armory' -AccentColor 'DarkYellow'
        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$availableChoices[$i].DisplayName) -TextColor 'Gray' -BulletColor 'Yellow'
        }

        $choiceIndex = Read-LWInt -Prompt ("Armory choice #{0}" -f ($selectedIds.Count + 1)) -Min 1 -Max $availableChoices.Count
        $choice = $availableChoices[$choiceIndex - 1]
        $selectedIds += [string]$choice.Id
        Grant-LWBookTwoArmoryChoice -Choice $choice
    }
}

function Get-LWBookThreeStartingChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'short_sword'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'padded_leather'; DisplayName = 'Padded Leather Waistcoat'; Type = 'special'; Name = 'Padded Leather Waistcoat'; Quantity = 1; Description = 'Padded Leather Waistcoat' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'warhammer'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'axe'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'laumspur_potion'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'quarterstaff'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'special_rations'; DisplayName = 'Special Rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 1; Description = 'Special Rations' },
        [pscustomobject]@{ Id = 'broadsword'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' }
    )
}

function Grant-LWBookThreeStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 3 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 3 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Apply-LWBookThreeStartingEquipment {
    param([switch]$CarryExistingGear)

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 3) {
        return
    }

    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfKalteItemNames) -Type 'special')) {
        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of Kalte') {
            Write-LWInfo 'Book 3 starting Special Item added: Map of Kalte.'
        }
        else {
            Write-LWWarn 'No room to add Map of Kalte automatically. Make room and add it manually if needed.'
        }
    }

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold

    Write-LWInfo ("Book 3 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 3 starting gold is lost.'
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose two Book 3 starting items now. You may exchange carried weapons if needed.' } else { 'Choose two Book 3 starting items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 2) {
        $availableChoices = @(Get-LWBookThreeStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 3 Expedition Gear' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/2" -f $selectedIds.Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        Write-Host ''
        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        $manageIndex = $availableChoices.Count + 1
        Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt ("Book 3 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }
        if ($choiceIndex -eq $manageIndex) {
            Invoke-LWBookFourStartingInventoryManagement
            continue
        }

        $choice = $availableChoices[$choiceIndex - 1]
        $granted = Grant-LWBookThreeStartingChoice -Choice $choice
        if ($granted) {
            $selectedIds += [string]$choice.Id
        }
        elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
            Invoke-LWBookFourStartingInventoryManagement
        }
    }
}

function Get-LWBookFourStartingChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'warhammer'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'dagger'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'two_potions'; DisplayName = '2 Potions of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 2; Description = '2 Potions of Laumspur' },
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'special_rations'; DisplayName = '5 Special Rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 5; Description = '5 Special Rations' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'chainmail'; DisplayName = 'Chainmail Waistcoat'; Type = 'special'; Name = 'Chainmail Waistcoat'; Quantity = 1; Description = 'Chainmail Waistcoat' },
        [pscustomobject]@{ Id = 'shield'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' }
    )
}

function Get-LWBookFourSection12ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section12MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book4Section12RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' },
        [pscustomobject]@{ Id = 'potion'; FlagName = 'Book4Section12PotionClaimed'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section12SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book4Section12SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' }
    )
}

function Grant-LWBookFourStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 4 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 4 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Grant-LWBookFourSection12Choice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    $granted = $false
    if ([string]$Choice.Type -eq 'weapon') {
        $granted = Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName)
    }
    else {
        $granted = TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)
    }

    if (-not $granted) {
        Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Make room and try again if you are keeping it.'
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    Write-LWInfo ("Section 12: added {0}." -f [string]$Choice.Description)
    return $true
}

function Get-LWBookFourSection213ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'pickaxe'; FlagName = 'Book4Section213PickaxeClaimed'; DisplayName = 'Pickaxe'; Type = 'backpack'; Name = 'Pickaxe'; Quantity = 1; Description = 'Pickaxe' },
        [pscustomobject]@{ Id = 'shovel'; FlagName = 'Book4Section213ShovelClaimed'; DisplayName = 'Shovel'; Type = 'backpack'; Name = 'Shovel'; Quantity = 1; Description = 'Shovel' },
        [pscustomobject]@{ Id = 'axe'; FlagName = 'Book4Section213AxeClaimed'; DisplayName = 'Axe'; Type = 'weapon'; Name = 'Axe'; Quantity = 1; Description = 'Axe' },
        [pscustomobject]@{ Id = 'torch'; FlagName = 'Book4Section213TorchClaimed'; DisplayName = 'Torch'; Type = 'backpack'; Name = 'Torch'; Quantity = 1; Description = 'Torch' },
        [pscustomobject]@{ Id = 'tinderbox'; FlagName = 'Book4Section213TinderboxClaimed'; DisplayName = 'Tinderbox'; Type = 'backpack'; Name = 'Tinderbox'; Quantity = 1; Description = 'Tinderbox' },
        [pscustomobject]@{ Id = 'hourglass'; FlagName = 'Book4Section213HourglassClaimed'; DisplayName = 'Hourglass'; Type = 'backpack'; Name = 'Hourglass'; Quantity = 1; Description = 'Hourglass' }
    )
}

function Get-LWBookFourSection280ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section280GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book4Section280MealClaimed'; DisplayName = 'Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = 'Meal' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section280SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFourSection002ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section002SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book4Section002MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book4Section002DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'warhammer'; FlagName = 'Book4Section002WarhammerClaimed'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section002GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' },
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book4Section002BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section002MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWBookFourSection044ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section044GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section044MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWBookFourSection109ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section109GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book4Section109DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section109SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFourSection152ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section152SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section152GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section152MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' },
        [pscustomobject]@{ Id = 'brass_key'; FlagName = 'Book4Section152BrassKeyClaimed'; DisplayName = 'Brass Key'; Type = 'special'; Name = 'Brass Key'; Quantity = 1; Description = 'Brass Key' }
    )
}

function Get-LWBookFourSection230ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section230SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book4Section230DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section230GoldClaimed'; DisplayName = '9 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 9; Description = '9 Gold Crowns' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book4Section230MealsClaimed'; DisplayName = '2 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 2; Description = '2 Meals' }
    )
}

function Get-LWBookFourSection231ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book4Section231GoldClaimed'; DisplayName = '3 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 3; Description = '3 Gold Crowns' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book4Section231SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book4Section231MealClaimed'; DisplayName = 'Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = 'Meal' }
    )
}

function Get-LWBookFourSection302ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book4Section302LaumspurClaimed'; DisplayName = '2 Potions of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 2; Description = '2 Potions of Laumspur' },
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book4Section302AletherClaimed'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Alether'; Quantity = 1; Description = 'Potion of Alether' },
        [pscustomobject]@{ Id = 'holy_water'; FlagName = 'Book4Section302HolyWaterClaimed'; DisplayName = 'Flask of Holy Water'; Type = 'backpack'; Name = 'Flask of Holy Water'; Quantity = 1; Description = 'Flask of Holy Water' }
    )
}

function Get-LWBookOneSection124ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section124GoldClaimed'; DisplayName = '15 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 15; Description = '15 Gold Crowns' },
        [pscustomobject]@{ Id = 'silver_key'; FlagName = 'Book1Section124SilverKeyClaimed'; DisplayName = 'Silver Key'; Type = 'special'; Name = 'Silver Key'; Quantity = 1; Description = 'Silver Key' }
    )
}

function Get-LWBookOneSection267ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'message'; FlagName = 'Book1Section267MessageClaimed'; DisplayName = 'Prince Pelathar''s Message'; Type = 'special'; Name = 'Prince Pelathar''s Message'; Quantity = 1; Description = 'Prince Pelathar''s Message' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book1Section267DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' }
    )
}

function Get-LWBookOneSection315ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book1Section315GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'soap'; FlagName = 'Book1Section315SoapClaimed'; DisplayName = 'Tablet of Perfumed Soap'; Type = 'backpack'; Name = 'Tablet of Perfumed Soap'; Quantity = 1; Description = 'Tablet of Perfumed Soap' }
    )
}

function Get-LWBookOneSection347ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'torch'; FlagName = 'Book1Section347TorchClaimed'; DisplayName = 'Torch'; Type = 'backpack'; Name = 'Torch'; Quantity = 1; Description = 'Torch' },
        [pscustomobject]@{ Id = 'short_sword'; FlagName = 'Book1Section347ShortSwordClaimed'; DisplayName = 'Short Sword'; Type = 'weapon'; Name = 'Short Sword'; Quantity = 1; Description = 'Short Sword' },
        [pscustomobject]@{ Id = 'tinderbox'; FlagName = 'Book1Section347TinderboxClaimed'; DisplayName = 'Tinderbox'; Type = 'backpack'; Name = 'Tinderbox'; Quantity = 1; Description = 'Tinderbox' }
    )
}

function Get-LWBookTwoSection262ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book2Section262SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book2Section262MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'quarterstaff'; FlagName = 'Book2Section262QuarterstaffClaimed'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'meal'; FlagName = 'Book2Section262MealClaimed'; DisplayName = 'Meal'; Type = 'backpack'; Name = 'Meal'; Quantity = 1; Description = 'Meal' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section262GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'orange_potion'; FlagName = 'Book2Section262OrangePotionClaimed'; DisplayName = 'Potion of Orange Liquid'; Type = 'backpack'; Name = 'Potion of Orange Liquid'; Quantity = 1; Description = 'Potion of Orange Liquid' }
    )
}

function Get-LWBookTwoSection302ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'mace'; FlagName = 'Book2Section302MaceClaimed'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'broadsword'; FlagName = 'Book2Section302BroadswordClaimed'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' },
        [pscustomobject]@{ Id = 'quarterstaff'; FlagName = 'Book2Section302QuarterstaffClaimed'; DisplayName = 'Quarterstaff'; Type = 'weapon'; Name = 'Quarterstaff'; Quantity = 1; Description = 'Quarterstaff' },
        [pscustomobject]@{ Id = 'healing_potion'; FlagName = 'Book2Section302HealingPotionClaimed'; DisplayName = 'Healing Potion'; Type = 'backpack'; Name = 'Healing Potion'; Quantity = 1; Description = 'Healing Potion' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book2Section302MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book2Section302BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book2Section302GoldClaimed'; DisplayName = '12 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 12; Description = '12 Gold Crowns' }
    )
}

function Get-LWBookThreeSection004ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'bone_sword'; FlagName = 'Book3Section004BoneSwordClaimed'; DisplayName = 'Bone Sword'; Type = 'weapon'; Name = 'Bone Sword'; Quantity = 1; Description = 'Bone Sword' },
        [pscustomobject]@{ Id = 'blue_stone_disc'; FlagName = 'Book3Section004BlueStoneDiscClaimed'; DisplayName = 'Blue Stone Disc'; Type = 'special'; Name = 'Blue Stone Disc'; Quantity = 1; Description = 'Blue Stone Disc' }
    )
}

function Get-LWBookThreeSection012ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book3Section012MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' },
        [pscustomobject]@{ Id = 'sleeping_furs'; FlagName = 'Book3Section012SleepingFursClaimed'; DisplayName = 'Sleeping Furs'; Type = 'backpack'; Name = 'Sleeping Furs'; Quantity = 1; Description = 'Sleeping Furs' },
        [pscustomobject]@{ Id = 'rope'; FlagName = 'Book3Section012RopeClaimed'; DisplayName = 'Rope'; Type = 'backpack'; Name = 'Rope'; Quantity = 1; Description = 'Rope' }
    )
}

function Get-LWBookThreeSection038ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'backpack'; FlagName = 'Book3Section038BackpackClaimed'; DisplayName = 'Backpack'; Type = 'backpack_restore'; Name = 'Backpack'; Quantity = 1; Description = 'Backpack' },
        [pscustomobject]@{ Id = 'long_rope'; FlagName = 'Book3Section038LongRopeClaimed'; DisplayName = 'Long Rope'; Type = 'backpack'; Name = 'Long Rope'; Quantity = 1; Description = 'Long Rope' }
    )
}

function Get-LWBookThreeSection084ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section084TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection102ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'stone_effigy'; FlagName = 'Book3Section102EffigyClaimed'; DisplayName = 'Stone Effigy'; Type = 'special'; Name = 'Stone Effigy'; Quantity = 1; Description = 'Stone Effigy' }
    )
}

function Get-LWBookThreeSection231ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold_bracelet'; FlagName = 'Book3Section231BraceletClaimed'; DisplayName = 'Gold Bracelet'; Type = 'special'; Name = 'Gold Bracelet'; Quantity = 1; Description = 'Gold Bracelet' }
    )
}

function Get-LWBookThreeSection295ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'firesphere'; FlagName = 'Book3Section295FiresphereClaimed'; DisplayName = 'Firesphere'; Type = 'special'; Name = 'Firesphere'; Quantity = 1; Description = 'Firesphere' }
    )
}

function Get-LWBookThreeSection298ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section298TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookThreeSection282ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'spear'; FlagName = 'Book3Section282SpearClaimed'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'blue_stone_disc'; FlagName = 'Book3Section282BlueStoneDiscClaimed'; DisplayName = 'Blue Stone Disc'; Type = 'special'; Name = 'Blue Stone Disc'; Quantity = 1; Description = 'Blue Stone Disc' }
    )
}

function Get-LWBookThreeSection309ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section309TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' },
        [pscustomobject]@{ Id = 'firesphere'; FlagName = 'Book3Section309FiresphereClaimed'; DisplayName = 'Firesphere'; Type = 'special'; Name = 'Firesphere'; Quantity = 1; Description = 'Firesphere' }
    )
}

function Get-LWBookThreeSection321ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'blue_stone_triangle'; FlagName = 'Book3Section321TriangleClaimed'; DisplayName = 'Blue Stone Triangle'; Type = 'special'; Name = 'Blue Stone Triangle'; Quantity = 1; Description = 'Blue Stone Triangle' }
    )
}

function Get-LWBookFiveSection002ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'oede_herb'; FlagName = 'Book5Section002OedeClaimed'; DisplayName = 'Oede Herb'; Type = 'backpack'; Name = 'Oede Herb'; Quantity = 1; Description = 'Oede Herb' }
    )
}

function Get-LWBookFiveSection003ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section003GoldClaimed'; DisplayName = '4 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 4; Description = '4 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section003DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section003SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book5Section003AletherClaimed'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Potion of Alether'; Quantity = 1; Description = 'Potion of Alether' },
        [pscustomobject]@{ Id = 'blowpipe'; FlagName = 'Book5Section003BlowpipeClaimed'; DisplayName = 'Blowpipe'; Type = 'backpack'; Name = 'Blowpipe'; Quantity = 1; Description = 'Blowpipe' },
        [pscustomobject]@{ Id = 'sleep_dart'; FlagName = 'Book5Section003SleepDartClaimed'; DisplayName = 'Sleep Dart'; Type = 'backpack'; Name = 'Sleep Dart'; Quantity = 1; Description = 'Sleep Dart' }
    )
}

function Get-LWBookFiveSection004ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section004SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFiveSection027ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'larnuma_oil'; FlagName = 'Book5Section027LarnumaOilBought'; DisplayName = 'Larnuma Oil'; Type = 'backpack'; Name = 'Larnuma Oil'; Quantity = 1; Description = 'Larnuma Oil'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book5Section027LaumspurBought'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'rendalims_elixir'; FlagName = 'Book5Section027RendalimsElixirBought'; DisplayName = 'Rendalim''s Elixir'; Type = 'backpack'; Name = 'Rendalim''s Elixir'; Quantity = 1; Description = 'Rendalim''s Elixir'; GoldCost = 7 }
    )
}

function Get-LWBookFiveSection035ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'jewelled_mace'; FlagName = 'Book5Section035JewelledMaceClaimed'; DisplayName = 'Jewelled Mace'; Type = 'special'; Name = 'Jewelled Mace'; Quantity = 1; Description = 'Jewelled Mace' },
        [pscustomobject]@{ Id = 'copper_key'; FlagName = 'Book5Section035CopperKeyClaimed'; DisplayName = 'Copper Key'; Type = 'special'; Name = 'Copper Key'; Quantity = 1; Description = 'Copper Key' }
    )
}

function Get-LWBookFiveSection052ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section052GoldClaimed'; DisplayName = '4 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 4; Description = '4 Gold Crowns' },
        [pscustomobject]@{ Id = 'gaolers_keys'; FlagName = 'Book5Section052GaolersKeysClaimed'; DisplayName = 'Gaoler''s Keys'; Type = 'special'; Name = 'Gaoler''s Keys'; Quantity = 1; Description = 'Gaoler''s Keys' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section052DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section052SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFiveSection100ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'copper_key'; FlagName = 'Book5Section100CopperKeyClaimed'; DisplayName = 'Copper Key'; Type = 'special'; Name = 'Copper Key'; Quantity = 1; Description = 'Copper Key' },
        [pscustomobject]@{ Id = 'prism'; FlagName = 'Book5Section100PrismClaimed'; DisplayName = 'Prism'; Type = 'backpack'; Name = 'Prism'; Quantity = 1; Description = 'Prism' }
    )
}

function Get-LWBookFiveSection102ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section102SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section102DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'warhammer'; FlagName = 'Book5Section102WarhammerClaimed'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section102GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'gaolers_keys'; FlagName = 'Book5Section102GaolersKeysClaimed'; DisplayName = 'Gaoler''s Keys'; Type = 'special'; Name = 'Gaoler''s Keys'; Quantity = 1; Description = 'Gaoler''s Keys' }
    )
}

function Get-LWBookFiveSection131ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'silver_comb'; FlagName = 'Book5Section131SilverCombClaimed'; DisplayName = 'Silver Comb'; Type = 'backpack'; Name = 'Silver Comb'; Quantity = 1; Description = 'Silver Comb' },
        [pscustomobject]@{ Id = 'hourglass'; FlagName = 'Book5Section131HourglassClaimed'; DisplayName = 'Hourglass'; Type = 'backpack'; Name = 'Hourglass'; Quantity = 1; Description = 'Hourglass' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section131DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book5Section131LaumspurClaimed'; DisplayName = 'Healing Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Healing Potion of Laumspur' },
        [pscustomobject]@{ Id = 'prism'; FlagName = 'Book5Section131PrismClaimed'; DisplayName = 'Prism'; Type = 'backpack'; Name = 'Prism'; Quantity = 1; Description = 'Prism' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book5Section131MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' }
    )
}

function Get-LWBookFiveSection154ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book5Section154AletherBought'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Potion of Alether'; Quantity = 1; Description = 'Potion of Alether'; GoldCost = 4 },
        [pscustomobject]@{ Id = 'gallowbrush'; FlagName = 'Book5Section154GallowbrushBought'; DisplayName = 'Potion of Gallowbrush'; Type = 'backpack'; Name = 'Potion of Gallowbrush'; Quantity = 1; Description = 'Potion of Gallowbrush'; GoldCost = 2 },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book5Section154LaumspurBought'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'larnuma_oil'; FlagName = 'Book5Section154LarnumaBought'; DisplayName = 'Vial of Larnuma Oil'; Type = 'backpack'; Name = 'Vial of Larnuma Oil'; Quantity = 1; Description = 'Vial of Larnuma Oil'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'graveweed'; FlagName = 'Book5Section154GraveweedBought'; DisplayName = 'Tincture of Graveweed'; Type = 'backpack'; Name = 'Tincture of Graveweed'; Quantity = 1; Description = 'Tincture of Graveweed'; GoldCost = 1 },
        [pscustomobject]@{ Id = 'calacena'; FlagName = 'Book5Section154CalacenaBought'; DisplayName = 'Tincture of Calacena'; Type = 'backpack'; Name = 'Tincture of Calacena'; Quantity = 1; Description = 'Tincture of Calacena'; GoldCost = 2 }
    )
}

function Get-LWBookFiveSection169ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'black_sash'; FlagName = 'Book5Section169BlackSashBought'; DisplayName = 'Black Sash'; Type = 'special'; Name = 'Black Sash'; Quantity = 1; Description = 'Black Sash'; GoldCost = 2 }
    )
}

function Get-LWBookFiveSection207ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section207GoldClaimed'; DisplayName = '8 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 8; Description = '8 Gold Crowns' },
        [pscustomobject]@{ Id = 'brass_whistle'; FlagName = 'Book5Section207WhistleClaimed'; DisplayName = 'Brass Whistle'; Type = 'special'; Name = 'Brass Whistle'; Quantity = 1; Description = 'Brass Whistle' }
    )
}

function Get-LWBookFiveSection211ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'kourshah'; FlagName = 'Book5Section211KourshahBought'; DisplayName = 'Bottle of Kourshah'; Type = 'backpack'; Name = 'Bottle of Kourshah'; Quantity = 1; Description = 'Bottle of Kourshah'; GoldCost = 5 }
    )
}

function Get-LWBookFiveSection255ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'black_crystal_cube'; FlagName = 'Book5Section255CubeClaimed'; DisplayName = 'Black Crystal Cube'; Type = 'special'; Name = 'Black Crystal Cube'; Quantity = 1; Description = 'Black Crystal Cube' }
    )
}

function Get-LWBookFiveSection281ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'jewelled_mace'; FlagName = 'Book5Section281JewelledMaceClaimed'; DisplayName = 'Jewelled Mace'; Type = 'special'; Name = 'Jewelled Mace'; Quantity = 1; Description = 'Jewelled Mace' }
    )
}

function Grant-LWBookFourSection213Choice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    $granted = $false
    if ([string]$Choice.Type -eq 'weapon') {
        $granted = Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName)
    }
    else {
        $granted = TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)
    }

    if (-not $granted) {
        Write-LWLootNoRoomWarning -DisplayName ([string]$Choice.DisplayName) -ExtraMessage 'Make room and try again if you are keeping it.'
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    Write-LWInfo ("Section 213: added {0}." -f [string]$Choice.Description)
    return $true
}

function Grant-LWBookFourSection280Choice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    $granted = $false
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
                Write-LWWarn 'Gold Crowns are capped at 50. Excess gold from section 280 is lost.'
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

    if (-not [string]::IsNullOrWhiteSpace([string]$Choice.FlagName)) {
        Set-LWStoryAchievementFlag -Name ([string]$Choice.FlagName)
    }

    Write-LWInfo ("Section 280: added {0}." -f [string]$Choice.Description)
    return $true
}

function Format-LWBookFourStartingChoiceLine {
    param([Parameter(Mandatory = $true)][object]$Choice)

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

function Get-LWBookFiveStartingChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'dagger'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'laumspur'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'special_rations'; DisplayName = '2 Special Rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 2; Description = '2 Special Rations' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'shield'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' }
    )
}

function Grant-LWBookFiveStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 5 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 5 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Invoke-LWBookFiveSafekeepingSelection {
    if (-not (Test-LWHasState)) {
        return
    }

    $selected = @()
    while ($true) {
        $available = @($script:GameState.Inventory.SpecialItems | Where-Object { $selected -notcontains [string]$_ })
        if ($available.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 5 Safekeeping' -AccentColor 'DarkYellow'
        Write-LWSubtle '  Leave carried Special Items at the Kai Monastery if you do not want to take them into Book 5.'
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

function Apply-LWBookFiveStartingEquipment {
    param([switch]$CarryExistingGear)

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 5) {
        return
    }

    if ($CarryExistingGear -and @($script:GameState.Inventory.SpecialItems).Count -gt 0) {
        if (Read-LWYesNo -Prompt 'Leave any carried Special Items in monastery safekeeping before Book 5?' -Default $false) {
            Invoke-LWBookFiveSafekeepingSelection
        }
    }

    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfVassagoniaItemNames) -Type 'special')) {
        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of Vassagonia') {
            Write-LWInfo 'Book 5 starting Special Item added: Map of Vassagonia.'
        }
        else {
            Write-LWWarn 'No room to add the Book 5 map automatically. Make room and add it manually if needed.'
        }
    }

    Restore-LWBackpackState

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold

    Write-LWInfo ("Book 5 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 5 starting gold is lost.'
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to four Book 5 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to four Book 5 starting items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 4) {
        $availableChoices = @(Get-LWBookFiveStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 5 Starting Gear' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/4" -f $selectedIds.Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        Write-Host ''
        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        $manageIndex = $availableChoices.Count + 1
        Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt ("Book 5 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }
        if ($choiceIndex -eq $manageIndex) {
            Invoke-LWBookFourStartingInventoryManagement
            continue
        }

        $choice = $availableChoices[$choiceIndex - 1]
        $granted = Grant-LWBookFiveStartingChoice -Choice $choice
        if ($granted) {
            $selectedIds += [string]$choice.Id
        }
        elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
            Invoke-LWBookFourStartingInventoryManagement
        }
    }
}

function Apply-LWBookFourStartingEquipment {
    param([switch]$CarryExistingGear)

    if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 4) {
        return
    }

    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfSouthlandsItemNames) -Type 'special')) {
        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of the Southlands') {
            Write-LWInfo 'Book 4 starting Special Item added: Map of the Southlands.'
        }
        else {
            Write-LWWarn 'No room to add Map of the Southlands automatically. Make room and add it manually if needed.'
        }
    }

    if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWBadgeOfRankItemNames) -Type 'special')) {
        if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Badge of Rank') {
            Write-LWInfo 'Book 4 starting Special Item added: Badge of Rank.'
        }
        else {
            Write-LWWarn 'No room to add Badge of Rank automatically. Make room and add it manually if needed.'
        }
    }

    Restore-LWBackpackState

    $startingGoldRoll = Get-LWRandomDigit
    $goldGain = 10 + [int]$startingGoldRoll
    $oldGold = [int]$script:GameState.Inventory.GoldCrowns
    $newGold = [Math]::Min(50, ($oldGold + $goldGain))
    $script:GameState.Inventory.GoldCrowns = $newGold

    Write-LWInfo ("Book 4 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
    if ($newGold -ne ($oldGold + $goldGain)) {
        Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 4 starting gold is lost.'
    }

    Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to six Book 4 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to six Book 4 starting items now.' })

    $selectedIds = @()
    while ($selectedIds.Count -lt 6) {
        $availableChoices = @(Get-LWBookFourStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
        if ($availableChoices.Count -eq 0) {
            break
        }

        Write-LWPanelHeader -Title 'Book 4 Starting Gear' -AccentColor 'DarkYellow'
        Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/6" -f $selectedIds.Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
        Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
        Write-Host ''
        for ($i = 0; $i -lt $availableChoices.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
        }
        $manageIndex = $availableChoices.Count + 1
        Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
        Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

        $choiceIndex = Read-LWInt -Prompt ("Book 4 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
        if ($choiceIndex -eq 0) {
            break
        }
        if ($choiceIndex -eq $manageIndex) {
            Invoke-LWBookFourStartingInventoryManagement
            continue
        }

        $choice = $availableChoices[$choiceIndex - 1]
        $granted = Grant-LWBookFourStartingChoice -Choice $choice
        if ($granted) {
            $selectedIds += [string]$choice.Id
        }
        elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
            Invoke-LWBookFourStartingInventoryManagement
        }
    }
}

function Get-LWChainmailItemNames {
    return @('Chainmail Waistcoat', 'Chainmail Wastecoat', 'Chainmail')
}

function Get-LWPaddedLeatherItemNames {
    return @('Padded Leather Waistcoat', 'Padded Leather Wastecoat', 'Padded Leather Waste Coat', 'Padded Leather')
}

function Get-LWHelmetItemNames {
    return @('Helmet')
}

function Get-LWShieldItemNames {
    return @('Shield')
}

function Get-LWSilverHelmItemNames {
    return @('Silver Helm')
}

function Get-LWMapOfSommerlundItemNames {
    return @('Map of Sommerlund')
}

function Get-LWGoldenKeyItemNames {
    return @('Golden Key')
}

function Get-LWSealOfHammerdalItemNames {
    return @('Seal of Hammerdal')
}

function Get-LWCoachTicketItemNames {
    return @('Coach Ticket', 'Ticket')
}

function Get-LWWhitePassItemNames {
    return @('White Pass')
}

function Get-LWRedPassItemNames {
    return @('Red Pass')
}

function Get-LWVordakGemItemNames {
    return @('Vordak Gem', 'Vordak Gems')
}

function Get-LWCrystalStarPendantItemNames {
    return @('Crystal Star Pendant')
}

function Get-LWMapOfKalteItemNames {
    return @('Map of Kalte')
}

function Get-LWSilverKeyItemNames {
    return @('Silver Key')
}

function Get-LWTombGuardianGemsItemNames {
    return @('Tomb Guardian Gems')
}

function Get-LWPrincePelatharMessageItemNames {
    return @("Prince Pelathar's Message", 'Prince Pelathar Message', 'Message')
}

function Get-LWTabletOfPerfumedSoapItemNames {
    return @('Tablet of Perfumed Soap')
}

function Get-LWMapOfSouthlandsItemNames {
    return @('Map of the Southlands')
}

function Get-LWMapOfVassagoniaItemNames {
    return @('Map of Vassagonia', 'Map of the Desert Empire', 'Map of Vassagonia / Desert Empire')
}

function Get-LWOedeHerbItemNames {
    return @('Oede Herb')
}

function Get-LWBlowpipeItemNames {
    return @('Blowpipe')
}

function Get-LWSleepDartItemNames {
    return @('Sleep Dart', 'Sleep Darts')
}

function Get-LWGaolersKeysItemNames {
    return @("Gaoler's Keys", "Gaoler's Keys", 'Gaolers Keys')
}

function Get-LWJakanBowWeaponNames {
    return @('Jakan Bow')
}

function Get-LWArrowItemNames {
    return @('Arrow', 'Arrows')
}

function Get-LWTowelItemNames {
    return @('Towel')
}

function Get-LWCopperKeyItemNames {
    return @('Copper Key')
}

function Get-LWHerbPadItemNames {
    return @('Herb Pad')
}

function Get-LWSilverCombItemNames {
    return @('Silver Comb')
}

function Get-LWHourglassItemNames {
    return @('Hourglass')
}

function Get-LWPrismItemNames {
    return @('Prism')
}

function Get-LWLarnumaOilItemNames {
    return @('Larnuma Oil', 'Vial of Larnuma Oil')
}

function Get-LWRendalimsElixirItemNames {
    return @("Rendalim's Elixir", 'Rendalims Elixir')
}

function Get-LWGallowbrushItemNames {
    return @('Potion of Gallowbrush', 'Gallowbrush')
}

function Get-LWCalacenaItemNames {
    return @('Tincture of Calacena', 'Calacena')
}

function Get-LWBlackSashItemNames {
    return @('Black Sash')
}

function Get-LWBrassWhistleItemNames {
    return @('Brass Whistle')
}

function Get-LWBottleOfKourshahItemNames {
    return @('Bottle of Kourshah', 'Kourshah')
}

function Get-LWBlackCrystalCubeItemNames {
    return @('Black Crystal Cube')
}

function Get-LWJewelledMaceItemNames {
    return @('Jewelled Mace')
}

function Get-LWBookOfMagnakaiItemNames {
    return @('Book of the Magnakai')
}

function Get-LWBadgeOfRankItemNames {
    return @('Badge of Rank')
}

function Get-LWSpecialRationsItemNames {
    return @('Special Rations', 'Special Ration')
}

function Get-LWOnyxMedallionItemNames {
    return @('Onyx Medallion')
}

function Get-LWFlaskOfHolyWaterItemNames {
    return @('Flask of Holy Water', 'Holy Water')
}

function Get-LWScrollItemNames {
    return @('Scroll')
}

function Get-LWCaptainDValSwordWeaponNames {
    return @("Captain D'Val's Sword", 'Captain DVal Sword')
}

function Get-LWDaggerOfVashnaItemNames {
    return @('Dagger of Vashna')
}

function Get-LWIronKeyItemNames {
    return @('Iron Key')
}

function Get-LWBrassKeyItemNames {
    return @('Brass Key')
}

function Get-LWWhipItemNames {
    return @('Whip')
}

function Get-LWPotionOfRedLiquidItemNames {
    return @('Potion of Red Liquid')
}

function Get-LWMiningToolItemNames {
    return @('Shovel', 'Pick', 'Pickaxe')
}

function Get-LWFiresphereItemNames {
    return @('Kalte Firesphere', 'Firesphere')
}

function Get-LWTorchItemNames {
    return @('Torch', 'Torches')
}

function Get-LWTinderboxItemNames {
    return @('Tinderbox')
}

function Get-LWBaknarOilItemNames {
    return @('Baknar Oil')
}

function Get-LWSleepingFursItemNames {
    return @('Sleeping Furs')
}

function Get-LWBlueStoneTriangleItemNames {
    return @('Blue Stone Triangle')
}

function Get-LWBlueStoneDiscItemNames {
    return @('Blue Stone Disc')
}

function Get-LWStoneEffigyItemNames {
    return @('Stone Effigy', 'Effigy')
}

function Get-LWGoldBraceletItemNames {
    return @('Gold Bracelet')
}

function Get-LWOrnateSilverKeyItemNames {
    return @('Ornate Silver Key')
}

function Get-LWPotionOfOrangeLiquidItemNames {
    return @('Potion of Orange Liquid')
}

function Get-LWLaumspurHerbItemNames {
    return @('Laumspur Herb', 'Laumspur Herbs')
}

function Get-LWDrodarinWarHammerWeaponNames {
    return @('Drodarin War Hammer', 'Drodarin War Hammer +1', 'Drodarin Warhammer', 'Drodarin Warhammer +1')
}

function Get-LWBroadswordPlusOneWeaponNames {
    return @('Broadsword +1')
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
    return @('Warhammer', 'Quarterstaff', 'Mace', 'Drodarin War Hammer', 'Drodarin War Hammer +1', 'Drodarin Warhammer', 'Drodarin Warhammer +1')
}

function Get-LWHealingPotionItemNames {
    return @('Healing Potion', 'Laumspur Potion', 'Potion of Laumspur', 'Laumspur', 'Potion of Red Liquid')
}

function Get-LWPotentHealingPotionItemNames {
    return @('Potent Laumspur Potion')
}

function Get-LWConcentratedHealingPotionItemNames {
    return @('Concentrated Laumspur', 'Concentrated Laumspur Potion', 'Potion of Concentrated Laumspur')
}

function Get-LWAletherPotionItemNames {
    return @('Alether', 'Alether Potion', 'Potion of Alether')
}

function Get-LWMealOfLaumspurItemNames {
    return @('Meal of Laumspur')
}

function Get-LWGraveweedItemNames {
    return @('Vial of Graveweed', 'Graveweed')
}

function Get-LWMagicSpearItemNames {
    return @('Magic Spear')
}

function Get-LWKnownInventoryNameGroups {
    return @(
        @('Axe'),
        @('Sword'),
        @('Short Sword'),
        @('Dagger'),
        @('Spear'),
        @('Mace'),
        @('Warhammer'),
        @('Quarterstaff'),
        @('Broadsword'),
        @('Rope'),
        @('Meal'),
        @('Backpack'),
        (Get-LWChainmailItemNames),
        (Get-LWPaddedLeatherItemNames),
        (Get-LWHelmetItemNames),
        (Get-LWShieldItemNames),
        (Get-LWSilverHelmItemNames),
        (Get-LWMapOfSommerlundItemNames),
        (Get-LWGoldenKeyItemNames),
        (Get-LWSealOfHammerdalItemNames),
        (Get-LWCoachTicketItemNames),
        (Get-LWWhitePassItemNames),
        (Get-LWRedPassItemNames),
        (Get-LWVordakGemItemNames),
        (Get-LWCrystalStarPendantItemNames),
        (Get-LWMapOfKalteItemNames),
        (Get-LWSilverKeyItemNames),
        (Get-LWTombGuardianGemsItemNames),
        (Get-LWPrincePelatharMessageItemNames),
        (Get-LWTabletOfPerfumedSoapItemNames),
        (Get-LWMapOfSouthlandsItemNames),
        (Get-LWMapOfVassagoniaItemNames),
        (Get-LWOedeHerbItemNames),
        (Get-LWBlowpipeItemNames),
        (Get-LWSleepDartItemNames),
        (Get-LWGaolersKeysItemNames),
        (Get-LWJakanBowWeaponNames),
        (Get-LWArrowItemNames),
        (Get-LWTowelItemNames),
        (Get-LWCopperKeyItemNames),
        (Get-LWHerbPadItemNames),
        (Get-LWSilverCombItemNames),
        (Get-LWHourglassItemNames),
        (Get-LWPrismItemNames),
        (Get-LWLarnumaOilItemNames),
        (Get-LWRendalimsElixirItemNames),
        (Get-LWGallowbrushItemNames),
        (Get-LWCalacenaItemNames),
        (Get-LWBlackSashItemNames),
        (Get-LWBrassWhistleItemNames),
        (Get-LWBottleOfKourshahItemNames),
        (Get-LWBlackCrystalCubeItemNames),
        (Get-LWJewelledMaceItemNames),
        (Get-LWBookOfMagnakaiItemNames),
        (Get-LWBadgeOfRankItemNames),
        (Get-LWSpecialRationsItemNames),
        (Get-LWOnyxMedallionItemNames),
        (Get-LWFlaskOfHolyWaterItemNames),
        (Get-LWScrollItemNames),
        (Get-LWCaptainDValSwordWeaponNames),
        (Get-LWDaggerOfVashnaItemNames),
        (Get-LWIronKeyItemNames),
        (Get-LWBrassKeyItemNames),
        (Get-LWWhipItemNames),
        (Get-LWPotionOfRedLiquidItemNames),
        (Get-LWMiningToolItemNames),
        (Get-LWFiresphereItemNames),
        (Get-LWTorchItemNames),
        (Get-LWTinderboxItemNames),
        (Get-LWBaknarOilItemNames),
        (Get-LWSleepingFursItemNames),
        (Get-LWBlueStoneTriangleItemNames),
        (Get-LWBlueStoneDiscItemNames),
        (Get-LWStoneEffigyItemNames),
        (Get-LWGoldBraceletItemNames),
        (Get-LWOrnateSilverKeyItemNames),
        (Get-LWPotionOfOrangeLiquidItemNames),
        (Get-LWLaumspurHerbItemNames),
        (Get-LWDrodarinWarHammerWeaponNames),
        (Get-LWBroadswordPlusOneWeaponNames),
        (Get-LWSommerswerdItemNames),
        (Get-LWBoneSwordWeaponNames),
        (Get-LWHealingPotionItemNames),
        (Get-LWPotentHealingPotionItemNames),
        (Get-LWConcentratedHealingPotionItemNames),
        (Get-LWAletherPotionItemNames),
        (Get-LWMealOfLaumspurItemNames),
        (Get-LWGraveweedItemNames),
        (Get-LWMagicSpearItemNames),
        (Get-LWLongRopeItemNames)
    )
}

function Convert-LWInventoryNameToDisplayCase {
    param([Parameter(Mandatory = $true)][string]$Name)

    $text = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $text
    }

    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo
    $displayName = $textInfo.ToTitleCase($text.ToLowerInvariant())
    $displayName = [regex]::Replace($displayName, "\b(Of|The|And|Or|To|In|On|For|With|From|A|An)\b", { param($match) $match.Value.ToLowerInvariant() })
    $displayName = [regex]::Replace($displayName, "(?<=\b[A-Za-z])'([a-z])", { param($match) "'" + $match.Groups[1].Value.ToUpperInvariant() })

    if ($displayName.Length -gt 0) {
        $displayName = $displayName.Substring(0, 1).ToUpperInvariant() + $displayName.Substring(1)
    }

    return $displayName
}

function Get-LWCanonicalInventoryItemName {
    param([string]$Name = '')

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $Name
    }

    $trimmedName = $Name.Trim()
    foreach ($group in @(Get-LWKnownInventoryNameGroups)) {
        $match = Get-LWMatchingValue -Values @($group) -Target $trimmedName
        if (-not [string]::IsNullOrWhiteSpace($match)) {
            return [string]$match
        }
    }

    return (Convert-LWInventoryNameToDisplayCase -Name $trimmedName)
}

function Test-LWPotentHealingPotionName {
    param([string]$Name)

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWPotentHealingPotionItemNames) -Target $Name)))
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

function Find-LWStateInventoryItemLocation {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [string[]]$Types = @('backpack', 'special', 'weapon')
    )

    foreach ($type in @($Types)) {
        $match = Get-LWMatchingStateInventoryItem -State $State -Names $Names -Type $type
        if (-not [string]::IsNullOrWhiteSpace($match)) {
            return [pscustomobject]@{
                Type = [string]$type
                Name = [string]$match
            }
        }
    }

    return $null
}

function Remove-LWStateInventoryItemByNames {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [int]$Quantity = 1,
        [string[]]$Types = @('backpack', 'special', 'weapon')
    )

    if ($Quantity -lt 1) {
        return 0
    }

    $location = Find-LWStateInventoryItemLocation -State $State -Names $Names -Types $Types
    if ($null -eq $location) {
        return 0
    }

    return (Remove-LWInventoryItemSilently -Type ([string]$location.Type) -Name ([string]$location.Name) -Quantity $Quantity)
}

function Get-LWStateChainmailEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWChainmailItemNames)) {
        return 4
    }

    return 0
}

function Get-LWStatePaddedLeatherEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWPaddedLeatherItemNames) -Type 'special') {
        return 2
    }

    return 0
}

function Get-LWStateHelmetEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if ((Get-LWStateSilverHelmCombatSkillBonus -State $State) -gt 0) {
        return 0
    }

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWHelmetItemNames) -Type 'special') {
        return 2
    }

    return 0
}

function Get-LWStateShieldCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWBookFiveLimbdeathActive -State $State) {
        return 0
    }

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

function Test-LWWeaponIsDrodarinWarHammer {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWDrodarinWarHammerWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsBroadswordPlusOne {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBroadswordPlusOneWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsMagicSpear {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMagicSpearItemNames) -Target $Weapon)))
}

function Test-LWStateHasBoneSword {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBoneSwordWeaponNames) -Type 'weapon')
}

function Test-LWStateHasDrodarinWarHammer {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWDrodarinWarHammerWeaponNames) -Type 'weapon')
}

function Test-LWStateHasBroadswordPlusOne {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBroadswordPlusOneWeaponNames) -Type 'weapon')
}

function Test-LWStateHasMagicSpear {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWMagicSpearItemNames) -Type 'special')
}

function Test-LWWeaponIsCaptainDValSword {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCaptainDValSwordWeaponNames) -Target $Weapon)))
}

function Test-LWStateHasBackpack {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Inventory) {
        return $true
    }

    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasBackpack') -or $null -eq $State.Inventory.HasBackpack) {
        return $true
    }

    return [bool]$State.Inventory.HasBackpack
}

function Test-LWStateHasFiresphere {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWFiresphereItemNames))
}

function Test-LWStateHasBaknarOilApplied {
    param([object]$State = $script:GameState)

    if ($null -eq $State) {
        return $false
    }

    if ($State -eq $script:GameState) {
        return (Test-LWStoryAchievementFlag -Name 'Book3BaknarOilApplied')
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'Achievements') -or $null -eq $State.Achievements) {
        return $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Achievements -Name 'StoryFlags') -or $null -eq $State.Achievements.StoryFlags) {
        return $false
    }
    if (-not (Test-LWPropertyExists -Object $State.Achievements.StoryFlags -Name 'Book3BaknarOilApplied')) {
        return $false
    }

    return [bool]$State.Achievements.StoryFlags.Book3BaknarOilApplied
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
                346 {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWCoachTicketItemNames) -Type 'special') {
                        Write-LWInfo 'Section 346: coach ticket continuity route is available here.'
                    }
                }
            }
        }
        3 {
            switch ($section) {
                15 {
                    $names = @('Dagger') + (Get-LWBoneSwordWeaponNames)
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names $names -Type 'weapon') {
                        Write-LWInfo 'Section 15: Dagger / Bone Sword route is available here.'
                    }
                }
                { @(45, 303) -contains $_ } {
                    if (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWOrnateSilverKeyItemNames) -Type 'special') {
                        Write-LWInfo ("Section {0}: Ornate Silver Key route is available here." -f $section)
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
            }
        }
        5 {
            switch ($section) {
                31 {
                    if ((Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWFiresphereItemNames) -Type 'special') -or (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWTinderboxItemNames) -Type 'backpack')) {
                        Write-LWInfo 'Section 31: your Firesphere or Tinderbox opens the lit-market route here.'
                    }
                }
                137 {
                    if ((Test-LWStateHasDiscipline -State $script:GameState -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $script:GameState -Name 'Sixth Sense')) {
                        Write-LWInfo 'Section 137: Tracking / Sixth Sense can guide you onto the safer route here.'
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

function Test-LWStateIsInKalte {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([int]$State.Character.BookNumber -eq 3)
}

function Get-LWStateHuntingMealRestrictionReason {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateIsInKalte -State $State) {
        return 'Hunting cannot be used for meals anywhere in Kalte (Book 3).'
    }

    if ([int]$State.Character.BookNumber -eq 2 -and [int]$State.CurrentSection -eq 346) {
        return 'Hunting cannot be used when instructed to eat a Meal on your journey through the Wildlands.'
    }

    if ([int]$State.Character.BookNumber -eq 4 -and @(
            25,
            129,
            171,
            185,
            269
        ) -contains [int]$State.CurrentSection) {
        return 'Hunting cannot be used for meals here in Book 4.'
    }

    if ([int]$State.Character.BookNumber -eq 5 -and [int]$State.CurrentSection -eq 320) {
        return 'Hunting cannot be used for meals in the middle of this wasteland.'
    }

    return $null
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

function Test-LWWeaponIsMagicalForCombat {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    if (Test-LWWeaponIsSommerswerd -Weapon $Weapon) {
        return $true
    }

    if (Test-LWWeaponIsMagicSpear -Weapon $Weapon) {
        return $true
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWDaggerOfVashnaItemNames) -Target $Weapon)))
}

function Test-LWCombatMagicSpearAvailable {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasMagicSpear -State $State) {
        return $true
    }

    return ([int]$State.Character.BookNumber -eq 2 -and [int]$State.CurrentSection -eq 106)
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
    $magicSpear = $null
    if (Test-LWCombatMagicSpearAvailable -State $State) {
        $magicSpear = if ([int]$State.Character.BookNumber -eq 2 -and [int]$State.CurrentSection -eq 106) { 'Magic Spear' } else { Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWMagicSpearItemNames) -Type 'special' }
    }
    if (-not [string]::IsNullOrWhiteSpace($magicSpear) -and [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $choices -Target $magicSpear))) {
        $choices = @($choices) + @([string]$magicSpear)
    }
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

function Get-LWStateDrodarinWarHammerCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsDrodarinWarHammer -Weapon $activeWeapon) {
        return 1
    }

    return 0
}

function Get-LWStateBroadswordPlusOneCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsBroadswordPlusOne -Weapon $activeWeapon) {
        return 1
    }

    return 0
}

function Get-LWStateDaggerOfVashnaEndurancePenalty {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWDaggerOfVashnaItemNames) -Type 'special') {
        return -3
    }

    return 0
}

function Get-LWStateCaptainDValSwordCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsCaptainDValSword -Weapon $activeWeapon) {
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

function Get-LWCombatMindforceLossPerRound {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State.Combat -Name 'MindforceLossPerRound') -or $null -eq $State.Combat.MindforceLossPerRound) {
        return 2
    }

    return [Math]::Max(0, [int]$State.Combat.MindforceLossPerRound)
}

function Get-LWCombatCurrentRoundNumber {
    param([Parameter(Mandatory = $true)][object]$State)

    return (@($State.Combat.Log).Count + 1)
}

function Get-LWCombatActivePlayerCombatSkillModifier {
    param([Parameter(Mandatory = $true)][object]$State)

    $modifier = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifier') -and $null -ne $State.Combat.PlayerCombatSkillModifier) { [int]$State.Combat.PlayerCombatSkillModifier } else { 0 }
    $currentRound = Get-LWCombatCurrentRoundNumber -State $State
    $durationRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierRounds) { [int]$State.Combat.PlayerCombatSkillModifierRounds } else { 0 }
    if ($durationRounds -gt 0 -and $currentRound -gt $durationRounds) {
        $modifier = 0
    }

    $afterModifier = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRounds) { [int]$State.Combat.PlayerCombatSkillModifierAfterRounds } else { 0 }
    $afterStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRoundStart') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRoundStart) { [int]$State.Combat.PlayerCombatSkillModifierAfterRoundStart } else { 0 }
    if ($afterModifier -ne 0 -and $afterStartRound -gt 0 -and $currentRound -ge $afterStartRound) {
        $modifier += $afterModifier
    }

    return $modifier
}

function Get-LWCombatEvadeStatusText {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.CanEvade) {
        return 'No'
    }

    $requiredRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $State.Combat.EvadeAvailableAfterRound) { [int]$State.Combat.EvadeAvailableAfterRound } else { 0 }
    if ($requiredRounds -le 0) {
        return 'Yes'
    }

    $completedRounds = @($State.Combat.Log).Count
    if ($completedRounds -ge $requiredRounds) {
        return 'Yes'
    }

    return ("After round {0}" -f $requiredRounds)
}

function Test-LWCombatCanEvadeNow {
    param([Parameter(Mandatory = $true)][object]$State)

    return ((Get-LWCombatEvadeStatusText -State $State) -eq 'Yes')
}

function Get-LWCombatMindforceStatusText {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.EnemyUsesMindforce) {
        return 'Off'
    }

    if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
        return 'Blocked by Mindshield'
    }

    $loss = Get-LWCombatMindforceLossPerRound -State $State
    return ("Active (-{0} END/round)" -f $loss)
}

function Ensure-LWEquipmentBonusState {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWPropertyExists -Object $State -Name 'EquipmentBonuses') -or $null -eq $State.EquipmentBonuses) {
        $State | Add-Member -Force -NotePropertyName EquipmentBonuses -NotePropertyValue ([pscustomobject]@{
                ChainmailEndurance = 0
                PaddedLeatherEndurance = 0
                HelmetEndurance = 0
            })
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'ChainmailEndurance') -or $null -eq $State.EquipmentBonuses.ChainmailEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName ChainmailEndurance -NotePropertyValue 0
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'PaddedLeatherEndurance') -or $null -eq $State.EquipmentBonuses.PaddedLeatherEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName PaddedLeatherEndurance -NotePropertyValue 0
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'HelmetEndurance') -or $null -eq $State.EquipmentBonuses.HelmetEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName HelmetEndurance -NotePropertyValue 0
    }

    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'DaggerOfVashnaEndurance') -or $null -eq $State.EquipmentBonuses.DaggerOfVashnaEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName DaggerOfVashnaEndurance -NotePropertyValue 0
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
    $chainmailDelta = $desiredChainmail - $appliedChainmail

    $desiredPaddedLeather = Get-LWStatePaddedLeatherEnduranceBonus -State $State
    $appliedPaddedLeather = [int]$State.EquipmentBonuses.PaddedLeatherEndurance
    $paddedLeatherDelta = $desiredPaddedLeather - $appliedPaddedLeather

    $desiredHelmet = Get-LWStateHelmetEnduranceBonus -State $State
    $appliedHelmet = [int]$State.EquipmentBonuses.HelmetEndurance
    $helmetDelta = $desiredHelmet - $appliedHelmet

    $desiredDaggerOfVashna = Get-LWStateDaggerOfVashnaEndurancePenalty -State $State
    $appliedDaggerOfVashna = [int]$State.EquipmentBonuses.DaggerOfVashnaEndurance
    $daggerOfVashnaDelta = $desiredDaggerOfVashna - $appliedDaggerOfVashna

    $delta = $chainmailDelta + $paddedLeatherDelta + $helmetDelta + $daggerOfVashnaDelta

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
    $State.EquipmentBonuses.PaddedLeatherEndurance = $desiredPaddedLeather
    $State.EquipmentBonuses.HelmetEndurance = $desiredHelmet
    $State.EquipmentBonuses.DaggerOfVashnaEndurance = $desiredDaggerOfVashna

    if ($WriteMessages) {
        if ($chainmailDelta -ne 0) {
            $direction = if ($chainmailDelta -gt 0) { 'applied' } else { 'removed' }
            Write-LWInfo ("Chainmail Waistcoat bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $chainmailDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($paddedLeatherDelta -ne 0) {
            $direction = if ($paddedLeatherDelta -gt 0) { 'applied' } else { 'removed' }
            Write-LWInfo ("Padded Leather Waistcoat bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $paddedLeatherDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($helmetDelta -ne 0) {
            $direction = if ($helmetDelta -gt 0) { 'applied' } else { 'removed' }
            Write-LWInfo ("Helmet bonus {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $helmetDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
        if ($daggerOfVashnaDelta -ne 0) {
            $direction = if ($daggerOfVashnaDelta -lt 0) { 'applied' } else { 'removed' }
            Write-LWWarn ("Dagger of Vashna drain {0}: {1} END. Current Endurance: {2} / {3}." -f $direction, (Format-LWSigned -Value $daggerOfVashnaDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
        }
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
        [Nullable[int]]$Max = $null,
        [switch]$NoRefresh
    )

    while ($true) {
        if (-not $NoRefresh) {
            Refresh-LWScreen
        }
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
        [string]$Default = '',
        [switch]$NoRefresh
    )

    if (-not $NoRefresh) {
        Refresh-LWScreen
    }
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
        MindforceLossPerRound     = 2
        EnemyRequiresMagicSpear   = $false
        EnemyRequiresMagicalWeapon = $false
        EnemyImmuneToMindblast    = $false
        UseMindblast              = $false
        MindblastCombatSkillBonus = 2
        AletherCombatSkillBonus   = 0
        AttemptKnockout           = $false
        CanEvade                  = $false
        EvadeAvailableAfterRound  = 0
        EvadeResolutionSection    = $null
        EvadeResolutionNote       = $null
        EquippedWeapon            = $null
        SommerswerdSuppressed     = $false
        IgnoreFirstRoundEnduranceLoss = $false
        IgnorePlayerEnduranceLossRounds = 0
        IgnoreEnemyEnduranceLossRounds = 0
        DoubleEnemyEnduranceLoss  = $false
        OneRoundOnly              = $false
        SpecialResolutionSection  = $null
        SpecialResolutionNote     = $null
        VictoryResolutionSection  = $null
        VictoryResolutionNote     = $null
        VictoryWithoutLossSection = $null
        VictoryWithoutLossNote    = $null
        VictoryWithinRoundsSection = $null
        VictoryWithinRoundsMax    = $null
        VictoryWithinRoundsNote   = $null
        OngoingFailureAfterRoundsSection = $null
        OngoingFailureAfterRoundsThreshold = $null
        OngoingFailureAfterRoundsNote = $null
        PlayerLossResolutionSection = $null
        PlayerLossResolutionNote  = $null
        DefeatResolutionSection   = $null
        DefeatResolutionNote      = $null
        JavekPoisonRule           = $false
        FallOnRollValue           = $null
        FallOnRollResolutionSection = $null
        FallOnRollResolutionNote  = $null
        RestoreHalfEnduranceLossOnVictory = $false
        RestoreHalfEnduranceLossOnEvade = $false
        PlayerCombatSkillModifier = 0
        PlayerCombatSkillModifierRounds = 0
        PlayerCombatSkillModifierAfterRounds = 0
        PlayerCombatSkillModifierAfterRoundStart = $null
        EnemyCombatSkillModifier  = 0
        SpecialPlayerEnduranceLossAmount = 0
        SpecialPlayerEnduranceLossStartRound = 1
        SpecialPlayerEnduranceLossReason = $null
        Log                       = @()
    }
}

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
        Weapon   = (New-LWInventoryRecoveryEntry)
        Backpack = (New-LWInventoryRecoveryEntry)
        Special  = (New-LWInventoryRecoveryEntry)
    }
}

function New-LWStorageState {
    return [pscustomobject]@{
        SafekeepingSpecialItems = @()
        Confiscated             = [pscustomobject]@{
            Weapons       = @()
            BackpackItems = @()
            SpecialItems  = @()
            GoldCrowns    = 0
            BookNumber    = $null
            Section       = $null
            SavedOn       = $null
        }
    }
}

function New-LWConditionState {
    return [pscustomobject]@{
        BookFiveBloodPoisoning = $false
        BookFiveLimbdeath      = $false
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
            HasBackpack   = $true
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

    if (-not (Test-LWPropertyExists -Object $State -Name 'Storage') -or $null -eq $State.Storage) {
        $State | Add-Member -Force -NotePropertyName Storage -NotePropertyValue (New-LWStorageState)
    }
    if (-not (Test-LWPropertyExists -Object $State.Storage -Name 'SafekeepingSpecialItems') -or $null -eq $State.Storage.SafekeepingSpecialItems) {
        $State.Storage | Add-Member -Force -NotePropertyName SafekeepingSpecialItems -NotePropertyValue @()
    }
    else {
        $State.Storage.SafekeepingSpecialItems = @($State.Storage.SafekeepingSpecialItems)
    }
    if (-not (Test-LWPropertyExists -Object $State.Storage -Name 'Confiscated') -or $null -eq $State.Storage.Confiscated) {
        $State.Storage | Add-Member -Force -NotePropertyName Confiscated -NotePropertyValue (New-LWStorageState).Confiscated
    }
    foreach ($entryName in @('Weapons', 'BackpackItems', 'SpecialItems')) {
        if (-not (Test-LWPropertyExists -Object $State.Storage.Confiscated -Name $entryName) -or $null -eq $State.Storage.Confiscated.$entryName) {
            $State.Storage.Confiscated | Add-Member -Force -NotePropertyName $entryName -NotePropertyValue @()
        }
        else {
            $State.Storage.Confiscated.$entryName = @($State.Storage.Confiscated.$entryName)
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
            $State.RecoveryStash.$entryName.Items = @($State.RecoveryStash.$entryName.Items)
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
    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'HasBackpack') -or $null -eq $State.Inventory.HasBackpack) {
        $State.Inventory | Add-Member -Force -NotePropertyName HasBackpack -NotePropertyValue $true
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

    Register-LWStorySectionAchievementTriggers -Section $Section
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

function Test-LWWeaponMatchesWeaponskill {
    param(
        [string]$Weapon,
        [string]$WeaponskillWeapon
    )

    if ([string]::IsNullOrWhiteSpace($Weapon) -or [string]::IsNullOrWhiteSpace($WeaponskillWeapon)) {
        return $false
    }

    if ($Weapon -ieq $WeaponskillWeapon) {
        return $true
    }

    if ((Test-LWWeaponIsDrodarinWarHammer -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Warhammer') {
        return $true
    }

    if ((Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Broadsword') {
        return $true
    }

    if ((Test-LWWeaponIsMagicSpear -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Spear') {
        return $true
    }

    if ((Test-LWWeaponIsCaptainDValSword -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Sword') {
        return $true
    }

    return $false
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
    if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Warhammer') {
        $weaponskillWeapon = [string]($weapons | Where-Object { Test-LWWeaponIsDrodarinWarHammer -Weapon ([string]$_) } | Select-Object -First 1)
    }
    if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Broadsword') {
        $weaponskillWeapon = [string]($weapons | Where-Object { Test-LWWeaponIsBroadswordPlusOne -Weapon ([string]$_) } | Select-Object -First 1)
    }
    if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Spear') {
        $weaponskillWeapon = [string]($weapons | Where-Object { Test-LWWeaponIsMagicSpear -Weapon ([string]$_) } | Select-Object -First 1)
    }
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
    $displayDisciplines = @()
    foreach ($discipline in @($script:GameState.Character.Disciplines)) {
        if ($discipline -eq 'Weaponskill' -and -not [string]::IsNullOrWhiteSpace($script:GameState.Character.WeaponskillWeapon)) {
            $displayDisciplines += "Weaponskill ($($script:GameState.Character.WeaponskillWeapon))"
        }
        else {
            $displayDisciplines += [string]$discipline
        }
    }

    if ($displayDisciplines.Count -eq 0) {
        Write-LWSubtle '  (none)'
        return
    }

    $leftColumnWidth = [Math]::Max(22, [Math]::Min(34, ((($displayDisciplines | Measure-Object -Property Length -Maximum).Maximum) + 4)))
    for ($i = 0; $i -lt $displayDisciplines.Count; $i += 2) {
        $leftLabel = [string]$displayDisciplines[$i]
        $rightLabel = if (($i + 1) -lt $displayDisciplines.Count) { [string]$displayDisciplines[$i + 1] } else { '' }

        Write-Host '  - ' -NoNewline -ForegroundColor DarkGray
        Write-Host $leftLabel.PadRight($leftColumnWidth) -NoNewline -ForegroundColor Green

        if (-not [string]::IsNullOrWhiteSpace($rightLabel)) {
            Write-Host '  - ' -NoNewline -ForegroundColor DarkGray
            Write-Host $rightLabel -ForegroundColor Green
        }
        else {
            Write-Host ''
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
            Write-LWBulletItem -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray' -BulletColor 'Magenta'
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

function Get-LWAchievementDisplayNameById {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$DefaultName
    )

    switch ([string]$Id) {
        'whats_in_the_box' {
            if (Test-LWAchievementUnlocked -Id 'whats_in_the_box_book1') {
                return 'What''s also in the Box?'
            }
        }
    }

    return $DefaultName
}

function Get-LWAchievementLockedDisplayName {
    param([Parameter(Mandatory = $true)][object]$Definition)

    if ((Test-LWPropertyExists -Object $Definition -Name 'Hidden') -and [bool]$Definition.Hidden -and -not (Test-LWAchievementUnlocked -Id ([string]$Definition.Id))) {
        return '???'
    }

    return (Get-LWAchievementDisplayNameById -Id ([string]$Definition.Id) -DefaultName ([string]$Definition.Name))
}

function Get-LWAchievementUnlockedDisplayName {
    param([Parameter(Mandatory = $true)][object]$Entry)

    return (Get-LWAchievementDisplayNameById -Id ([string]$Entry.Id) -DefaultName ([string]$Entry.Name))
}

function Get-LWAchievementLockedDisplayDescription {
    param([Parameter(Mandatory = $true)][object]$Definition)

    if ((Test-LWPropertyExists -Object $Definition -Name 'Hidden') -and [bool]$Definition.Hidden -and -not (Test-LWAchievementUnlocked -Id ([string]$Definition.Id))) {
        return 'Hidden story achievement.'
    }

    return [string]$Definition.Description
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
        Name       = (Get-LWAchievementDisplayNameById -Id ([string]$Definition.Id) -DefaultName ([string]$Definition.Name))
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
        Write-LWInfo ("Achievement unlocked: {0} - {1}" -f (Get-LWAchievementDisplayNameById -Id ([string]$Definition.Id) -DefaultName ([string]$Definition.Name)), [string]$Definition.Description)
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
        'book_three_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 3) }
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
        'aim_for_the_bushes' { return (Test-LWStoryAchievementFlag -Name 'Book1AimForTheBushesVisited') }
        'found_the_clubhouse' { return (Test-LWStoryAchievementFlag -Name 'Book1ClubhouseFound') }
        'kill_the_mad_butcher' { return (@($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 1 -and [string]$_.EnemyName -ieq 'Mad Butcher' }).Count -ge 1) }
        'whats_in_the_box_book1' { return (Test-LWStoryAchievementFlag -Name 'Book1SilverKeyClaimed') }
        'use_the_force' { return (Test-LWStoryAchievementFlag -Name 'Book1UseTheForcePath') }
        'straight_to_the_throne' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone')) }
        'royal_recovery' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWStoryAchievementFlag -Name 'Book1RoyalRecovery')) }
        'the_back_way_in' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWStoryAchievementFlag -Name 'Book1BackWayIn')) }
        'open_sesame' { return (Test-LWStoryAchievementFlag -Name 'Book1OpenSesameRoute') }
        'hot_hands' { return (Test-LWStoryAchievementFlag -Name 'Book1HotHandsClaimed') }
        'star_of_toran' { return (Test-LWStoryAchievementFlag -Name 'Book1StarOfToranClaimed') }
        'field_medic' { return (Test-LWStoryAchievementFlag -Name 'Book1FieldMedicPath') }
        'found_the_sommerswerd' { return (Test-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed') }
        'you_have_chosen_wisely' { return (@($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 2 -and (Test-LWPropertyExists -Object $_ -Name 'Section') -and [int]$_.Section -eq 158 -and [string]$_.EnemyName -ieq 'Priest' }).Count -ge 1) }
        'neo_link' { return (@($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 2 -and (Test-LWPropertyExists -Object $_ -Name 'Section') -and [int]$_.Section -eq 270 -and @('Ganon + Dorier', 'Ganon & Dorier', 'Ganon and Dorier') -contains [string]$_.EnemyName }).Count -ge 1) }
        'by_a_thread' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute')) }
        'skyfall' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWStoryAchievementFlag -Name 'Book2SkyfallRoute')) }
        'fight_through_the_smoke' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute')) }
        'storm_tossed' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWStoryAchievementFlag -Name 'Book2StormTossedSeen')) }
        'seal_of_approval' { return ((Test-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute') -and (Test-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed')) }
        'papers_please' { return (Test-LWStoryAchievementFlag -Name 'Book2PapersPleasePath') }
        'snakes_why' { return (Test-LWStoryAchievementFlag -Name 'Book3SnakePitVisited') }
        'cliffhanger' { return (Test-LWStoryAchievementFlag -Name 'Book3CliffhangerSeen') }
        'whats_in_the_box' { return (Test-LWStoryAchievementFlag -Name 'Book3DiamondClaimed') }
        'snowblind' { return (Test-LWStoryAchievementFlag -Name 'Book3SnowblindSeen') }
        'you_touched_it_with_your_hands' { return (Test-LWStoryAchievementFlag -Name 'Book3GrossKeyClaimed') }
        'lucky_button_theory' { return (Test-LWStoryAchievementFlag -Name 'Book3LuckyButtonTheorySeen') }
        'well_it_worked_once' { return (Test-LWStoryAchievementFlag -Name 'Book3WellItWorkedOnceSeen') }
        'cellfish' { return (Test-LWStoryAchievementFlag -Name 'Book3CellfishPathTaken') }
        'loi_kymar_lives' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued')) }
        'puppet_master' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached')) }
        'sun_on_the_ice' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed')) }
        'lucky_break' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed')) }
        'too_slow' { return (Test-LWStoryAchievementFlag -Name 'Book3TooSlowFailureSeen') }
        'book_four_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 4) }
        'sun_below_the_earth' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute')) }
        'blessed_be_the_throw' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute')) }
        'steel_against_shadow' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute')) }
        'badge_of_office' { return (Test-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath') }
        'wearing_the_enemys_colors' { return ((Test-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed') -and (Test-LWStoryAchievementFlag -Name 'Book4OnyxBluffRoute')) }
        'read_the_signs' { return ((Test-LWStoryAchievementFlag -Name 'Book4ScrollClaimed') -and (Test-LWStoryAchievementFlag -Name 'Book4ScrollRoute')) }
        'return_to_sender' { return ((Test-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed') -and (Test-LWStoryAchievementFlag -Name 'Book4ReturnToSenderPath')) }
        'deep_pockets_poor_timing' { return (Test-LWStoryAchievementFlag -Name 'Book4BackpackLost') }
        'bagless_but_breathing' { return ((Test-LWStoryAchievementFlag -Name 'Book4BackpackLost') -and (Test-LWStoryAchievementFlag -Name 'Book4BackpackRecovered')) }
        'shovel_ready' { return (Test-LWStoryAchievementFlag -Name 'Book4ShovelReadyClaimed') }
        'light_in_the_depths' { return (Test-LWStoryAchievementFlag -Name 'Book4LightInTheDepths') }
        'chasm_of_doom' { return (Test-LWStoryAchievementFlag -Name 'Book4ChasmOfDoomSeen') }
        'washed_away' { return (Test-LWStoryAchievementFlag -Name 'Book4WashedAway') }
        'book_five_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 5) }
        'kai_master' { return ((@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5 })).Count -ge 5) }
        'apothecarys_answer' { return ((Test-LWStoryAchievementFlag -Name 'Book5OedeClaimed') -and (Test-LWStoryAchievementFlag -Name 'Book5LimbdeathCured')) }
        'prison_break' { return (Test-LWStoryAchievementFlag -Name 'Book5PrisonBreak') }
        'talons_tamed' { return (Test-LWStoryAchievementFlag -Name 'Book5TalonsTamed') }
        'star_guided' { return (Test-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute') }
        'name_the_lost' { return ((Test-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard') -and (Test-LWStoryAchievementFlag -Name 'Book5SoushillaAsked')) }
        'shadow_on_the_sand' { return ((@($script:GameState.Character.CompletedBooks) -contains 5) -and (Test-LWStoryAchievementFlag -Name 'Book5BanishmentRoute')) }
        'face_to_face_with_haakon' { return ((@($script:GameState.Character.CompletedBooks) -contains 5) -and (Test-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute')) }
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
        'true_path' {
            $bestCompletedRewinds = @(
                $bookSummaries |
                Where-Object { (Test-LWPropertyExists -Object $_ -Name 'RewindsUsed') } |
                ForEach-Object { [int]$_.RewindsUsed }
            )
            if ($bestCompletedRewinds.Count -gt 0) {
                return ("best completed book rewinds: {0}" -f (($bestCompletedRewinds | Measure-Object -Minimum).Minimum))
            }
            return ("current book rewinds: {0}" -f $(if ($null -ne $currentSummary) { [int]$currentSummary.RewindsUsed } else { 0 }))
        }
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
        'aim_for_the_bushes' { return '' }
        'found_the_clubhouse' { return '' }
        'kill_the_mad_butcher' { return '' }
        'whats_in_the_box_book1' { return '' }
        'use_the_force' { return '' }
        'straight_to_the_throne' { return $(if (Test-LWStoryAchievementFlag -Name 'Book1StraightToTheThrone') { 'palace route found; finish Book 1' } else { 'finish Book 1 through 139 -> 66 -> 350' }) }
        'royal_recovery' { return $(if (Test-LWStoryAchievementFlag -Name 'Book1RoyalRecovery') { 'recovery route found; finish Book 1' } else { 'finish Book 1 through 165 -> 212 -> 350' }) }
        'the_back_way_in' { return $(if (Test-LWStoryAchievementFlag -Name 'Book1BackWayIn') { 'Guildhall route found; finish Book 1' } else { 'finish Book 1 through 196/210 -> 332 -> 350' }) }
        'open_sesame' { return '' }
        'hot_hands' { return '' }
        'star_of_toran' { return '' }
        'field_medic' { return '' }
        'found_the_sommerswerd' { return '' }
        'you_have_chosen_wisely' { return '' }
        'neo_link' { return '' }
        'by_a_thread' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2ByAThreadRoute') { 'rope-swing route found; finish Book 2' } else { 'finish Book 2 through 218 -> 105 -> 120 -> 225 -> 350' }) }
        'skyfall' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2SkyfallRoute') { 'skyfall route found; finish Book 2' } else { 'finish Book 2 through 336 -> 109 -> 120 -> 225 -> 350' }) }
        'fight_through_the_smoke' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2FightThroughTheSmokeRoute') { 'smoke route found; finish Book 2' } else { 'finish Book 2 through 336 -> 185 -> 120 -> 225 -> 350' }) }
        'storm_tossed' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2StormTossedSeen') { 'storm route found; finish Book 2' } else { 'reach section 337 and still complete Book 2' }) }
        'seal_of_approval' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2SealOfApprovalRoute') { 'king''s audience route found; claim the Sommerswerd' } else { 'reach section 196 and claim the Sommerswerd' }) }
        'papers_please' { return $(if (Test-LWStoryAchievementFlag -Name 'Book2ForgedPapersBought') { 'forged papers bought; present them at the Red Pass counter' } else { 'buy the forged access papers at section 327' }) }
        'book_three_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 3) { 'Book 3 complete' } else { 'complete Book 3' }) }
        'snakes_why' { return '' }
        'cliffhanger' { return '' }
        'whats_in_the_box' { return '' }
        'snowblind' { return '' }
        'you_touched_it_with_your_hands' { return '' }
        'lucky_button_theory' { return '' }
        'well_it_worked_once' { return '' }
        'cellfish' { return '' }
        'loi_kymar_lives' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3LoiKymarRescued') { 'Loi-Kymar rescued; finish Book 3' } else { 'rescue Loi-Kymar and finish Book 3' }) }
        'puppet_master' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3EffigyEndgameReached') { 'Effigy route found; finish Book 3' } else { 'finish Book 3 through the Effigy route' }) }
        'sun_on_the_ice' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3SommerswerdEndgameUsed') { 'Sommerswerd route found; finish Book 3' } else { 'finish Book 3 through the Sommerswerd route' }) }
        'lucky_break' { return $(if (Test-LWStoryAchievementFlag -Name 'Book3LuckyEndgameUsed') { 'Lucky endgame route found; finish Book 3' } else { 'finish Book 3 through the lucky endgame route' }) }
        'too_slow' { return '' }
        'book_four_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 4) { 'Book 4 complete' } else { 'complete Book 4' }) }
        'sun_below_the_earth' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4SunBelowTheEarthRoute') { 'Sommerswerd route found; finish Book 4' } else { 'finish Book 4 through 296 -> 122 -> 350' }) }
        'blessed_be_the_throw' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4BlessedBeTheThrowRoute') { 'Holy Water route found; finish Book 4' } else { 'finish Book 4 through 283 -> 350' }) }
        'steel_against_shadow' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4SteelAgainstShadowRoute') { 'Barraka duel route found; finish Book 4' } else { 'finish Book 4 through 325 -> 350' }) }
        'badge_of_office' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4BadgeOfOfficePath') { 'Badge route found' } else { 'use the Badge of Rank route at section 95' }) }
        'wearing_the_enemys_colors' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4OnyxMedallionClaimed') { 'Onyx Medallion claimed; use it at section 305' } else { 'claim the Onyx Medallion and bluff your way to section 305' }) }
        'read_the_signs' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4ScrollClaimed') { 'Scroll claimed; use it to reach section 279' } else { 'claim the Scroll and use it to reach section 279' }) }
        'return_to_sender' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4CaptainSwordClaimed') { 'Captain D''Val''s Sword claimed; return it at section 327' } else { 'claim Captain D''Val''s Sword and return it at section 327' }) }
        'deep_pockets_poor_timing' { return '' }
        'bagless_but_breathing' { return $(if (Test-LWStoryAchievementFlag -Name 'Book4BackpackLost') { 'Backpack lost; recover one at section 167 or 12' } else { 'lose your Backpack in Book 4 and recover a new one' }) }
        'shovel_ready' { return '' }
        'light_in_the_depths' { return '' }
        'chasm_of_doom' { return '' }
        'washed_away' { return '' }
        'book_five_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 5) { 'Book 5 complete' } else { 'complete Book 5' }) }
        'kai_master' { return ("{0}/5 Kai books complete" -f (@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5 })).Count) }
        'apothecarys_answer' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5OedeClaimed') { 'Oede Herb claimed; cure Limbdeath with it' } else { 'claim the Oede Herb and use it to cure Limbdeath' }) }
        'prison_break' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5PrisonBreak') { 'confiscated gear recovered' } else { 'recover your confiscated gear in Book 5' }) }
        'talons_tamed' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5TalonsTamed') { 'Itikar route found' } else { 'mount the Itikar through the special route in Book 5' }) }
        'star_guided' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5CrystalPendantRoute') { 'Crystal Star Pendant route found; finish Book 5' } else { 'use the Crystal Star Pendant route in Book 5' }) }
        'name_the_lost' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5SoushillaNameHeard') { 'Soushilla name learned; ask for her later' } else { 'learn Soushilla''s name and ask for her in Book 5' }) }
        'shadow_on_the_sand' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5BanishmentRoute') { 'banishment route found; finish Book 5' } else { 'finish Book 5 through the glowing-stone route' }) }
        'face_to_face_with_haakon' { return $(if (Test-LWStoryAchievementFlag -Name 'Book5HaakonDuelRoute') { 'Haakon duel route found; finish Book 5' } else { 'finish Book 5 through the Haakon duel route' }) }
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
        Rebuild-LWStoryAchievementFlagsFromState
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
            Write-LWBulletItem -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray' -BulletColor 'Magenta'
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
        Write-LWBulletItem -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray' -BulletColor 'Green'
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
            $displayName = Get-LWAchievementLockedDisplayName -Definition $definition
            $displayDescription = Get-LWAchievementLockedDisplayDescription -Definition $definition
            Write-LWBulletItem -Text ("{0} - {1}" -f $displayName, $displayDescription) -TextColor 'Gray' -BulletColor 'DarkYellow'
            if (-not [string]::IsNullOrWhiteSpace($progress) -and $displayName -ne '???') {
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
            $displayName = Get-LWAchievementLockedDisplayName -Definition $definition
            $displayDescription = Get-LWAchievementLockedDisplayDescription -Definition $definition
            Write-LWBulletItem -Text ("{0} - {1}" -f $displayName, $displayDescription) -TextColor 'Gray' -BulletColor 'DarkGray'
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
        Write-LWBulletItem -Text ("{0} - {1}" -f (Get-LWAchievementLockedDisplayName -Definition $definition), $progress) -TextColor 'Gray' -BulletColor 'Cyan'
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
                    Write-LWBulletItem -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray' -BulletColor 'DarkYellow'
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
        'special' { return 12 }
    }
}

function Get-LWLongRopeItemNames {
    return @('Long Rope')
}

function Get-LWBackpackItemSlotSize {
    param([string]$Name = '')

    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWLongRopeItemNames) -Target $Name))) {
        return 2
    }

    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWMiningToolItemNames) -Target $Name))) {
        return 2
    }

    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSleepingFursItemNames) -Target $Name))) {
        return 2
    }

    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWTowelItemNames) -Target $Name))) {
        return 2
    }

    return 1
}

function Get-LWBackpackOccupiedSlotCount {
    param([object[]]$Items = $null)

    $resolvedItems = if ($null -eq $Items) { @($script:GameState.Inventory.BackpackItems) } else { @($Items) }
    $slotCount = 0
    foreach ($item in $resolvedItems) {
        $slotCount += (Get-LWBackpackItemSlotSize -Name ([string]$item))
    }

    return $slotCount
}

function Get-LWInventoryUsedCapacity {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [object[]]$Items = $null
    )

    $resolvedItems = if ($null -eq $Items) { @(Get-LWInventoryItems -Type $Type) } else { @($Items) }
    if ($Type -eq 'backpack') {
        return (Get-LWBackpackOccupiedSlotCount -Items $resolvedItems)
    }

    return @($resolvedItems).Count
}

function Get-LWBackpackSlotMap {
    param([object[]]$Items = $null)

    $resolvedItems = if ($null -eq $Items) { @($script:GameState.Inventory.BackpackItems) } else { @($Items) }
    $slotMap = @()
    $slotNumber = 1
    $itemIndex = 0
    foreach ($resolvedItem in @($resolvedItems)) {
        $itemName = [string]$resolvedItem
        $slotSize = Get-LWBackpackItemSlotSize -Name $itemName
        $slotMap += [pscustomobject]@{
            Slot        = $slotNumber
            ItemIndex   = $itemIndex
            ItemName    = $itemName
            DisplayText = $(if ($slotSize -gt 1) { "$itemName [2 slots]" } else { $itemName })
            IsPrimary   = $true
        }

        for ($extraSlot = 2; $extraSlot -le $slotSize; $extraSlot++) {
            $slotMap += [pscustomobject]@{
                Slot        = ($slotNumber + $extraSlot - 1)
                ItemIndex   = $itemIndex
                ItemName    = $itemName
                DisplayText = "(occupied by $itemName)"
                IsPrimary   = $false
            }
        }

        $slotNumber += $slotSize
        $itemIndex++
    }

    return @($slotMap)
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
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Items
    )

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

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = @($normalizedItems) }
        'backpack' { $script:GameState.Inventory.BackpackItems = @($normalizedItems) }
        'special' { $script:GameState.Inventory.SpecialItems = @($normalizedItems) }
    }

    [void](Sync-LWAchievements -Context 'inventory')
}

function Set-LWBackpackState {
    param(
        [Parameter(Mandatory = $true)][bool]$HasBackpack,
        [switch]$ClearContents,
        [switch]$WriteMessages
    )

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

    if (-not (Test-LWHasState)) {
        return
    }

    Set-LWBackpackState -HasBackpack:$true -WriteMessages:$WriteMessages
}

function Get-LWConfiscatedInventorySummaryText {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Storage -or $null -eq $State.Storage.Confiscated) {
        return '(none)'
    }

    $parts = @()
    $weapons = @($State.Storage.Confiscated.Weapons)
    $backpack = @($State.Storage.Confiscated.BackpackItems)
    $special = @($State.Storage.Confiscated.SpecialItems)
    $gold = if ($null -ne $State.Storage.Confiscated.GoldCrowns) { [int]$State.Storage.Confiscated.GoldCrowns } else { 0 }

    if ($weapons.Count -gt 0) {
        $parts += ('Weapons: {0}' -f (Format-LWCompactInventorySummary -Items $weapons -MaxGroups 2))
    }
    if ($backpack.Count -gt 0) {
        $parts += ('Backpack: {0}' -f (Format-LWCompactInventorySummary -Items $backpack -MaxGroups 3))
    }
    if ($special.Count -gt 0) {
        $parts += ('Special: {0}' -f (Format-LWCompactInventorySummary -Items $special -MaxGroups 3))
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

    if ($null -eq $State -or $null -eq $State.Storage -or $null -eq $State.Storage.Confiscated) {
        return $false
    }

    return (
        @($State.Storage.Confiscated.Weapons).Count -gt 0 -or
        @($State.Storage.Confiscated.BackpackItems).Count -gt 0 -or
        @($State.Storage.Confiscated.SpecialItems).Count -gt 0 -or
        [int]$State.Storage.Confiscated.GoldCrowns -gt 0
    )
}

function Save-LWConfiscatedEquipment {
    param(
        [switch]$WriteMessages,
        [string]$Reason = ''
    )

    if (-not (Test-LWHasState)) {
        return
    }

    $script:GameState.Storage.Confiscated.Weapons = @($script:GameState.Inventory.Weapons)
    $script:GameState.Storage.Confiscated.BackpackItems = @($script:GameState.Inventory.BackpackItems)
    $script:GameState.Storage.Confiscated.SpecialItems = @($script:GameState.Inventory.SpecialItems)
    $script:GameState.Storage.Confiscated.GoldCrowns = [int]$script:GameState.Inventory.GoldCrowns
    $script:GameState.Storage.Confiscated.BookNumber = [int]$script:GameState.Character.BookNumber
    $script:GameState.Storage.Confiscated.Section = [int]$script:GameState.CurrentSection
    $script:GameState.Storage.Confiscated.SavedOn = (Get-Date).ToString('o')

    $script:GameState.Inventory.Weapons = @()
    $script:GameState.Inventory.SpecialItems = @()
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

    if (-not (Test-LWHasState) -or -not (Test-LWStateHasConfiscatedEquipment)) {
        return $false
    }

    $currentWeapons = @($script:GameState.Inventory.Weapons)
    $currentBackpackItems = @($script:GameState.Inventory.BackpackItems)
    $currentSpecialItems = @($script:GameState.Inventory.SpecialItems)
    $currentGoldCrowns = [int]$script:GameState.Inventory.GoldCrowns

    $restoredWeapons = @($script:GameState.Storage.Confiscated.Weapons)
    $restoredBackpackItems = @($script:GameState.Storage.Confiscated.BackpackItems)
    $restoredSpecialItems = @($script:GameState.Storage.Confiscated.SpecialItems)
    $restoredGoldCrowns = [int]$script:GameState.Storage.Confiscated.GoldCrowns

    Set-LWInventoryItems -Type 'weapon' -Items @($currentWeapons + $restoredWeapons)
    Set-LWInventoryItems -Type 'backpack' -Items @($currentBackpackItems + $restoredBackpackItems)
    Set-LWInventoryItems -Type 'special' -Items @($currentSpecialItems + $restoredSpecialItems)
    $totalGoldCrowns = $currentGoldCrowns + $restoredGoldCrowns
    $script:GameState.Inventory.GoldCrowns = [Math]::Min(50, $totalGoldCrowns)
    $script:GameState.Inventory.HasBackpack = $true

    $script:GameState.Storage.Confiscated.Weapons = @()
    $script:GameState.Storage.Confiscated.BackpackItems = @()
    $script:GameState.Storage.Confiscated.SpecialItems = @()
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
        $specialCount = @($script:GameState.Inventory.SpecialItems).Count
        $overLimitWarnings = @()
        if ($weaponCount -gt 2) {
            $overLimitWarnings += ("Weapons {0}/2" -f $weaponCount)
        }
        if ($backpackUsedCapacity -gt 8) {
            $overLimitWarnings += ("Backpack {0}/8" -f $backpackUsedCapacity)
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
        Write-LWInfo ("Placed in monastery safekeeping: {0}." -f (Format-LWList -Items @($Items)))
    }
}

function Test-LWBookFiveBloodPoisoningActive {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and $null -ne $State.Conditions -and [bool]$State.Conditions.BookFiveBloodPoisoning)
}

function Test-LWBookFiveLimbdeathActive {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and $null -ne $State.Conditions -and [bool]$State.Conditions.BookFiveLimbdeath)
}

function Get-LWStateLimbdeathCombatSkillPenalty {
    param([object]$State = $script:GameState)

    if (Test-LWBookFiveLimbdeathActive -State $State) {
        return 3
    }

    return 0
}

function Invoke-LWBookFiveLoseBackpackItems {
    param(
        [int]$Count = 1,
        [string]$Reason = 'You lose Backpack gear.',
        [switch]$ExcludeMeals
    )

    if (-not (Test-LWHasState)) {
        return @()
    }

    $lostItems = @()
    $remainingToLose = [Math]::Max(0, [int]$Count)
    while ($remainingToLose -gt 0) {
        $backpackItems = @(Get-LWInventoryItems -Type 'backpack')
        if ($backpackItems.Count -le 0) {
            break
        }

        $slotMap = @(Get-LWBackpackSlotMap -Items $backpackItems | Where-Object { [bool]$_.IsPrimary })
        if ($ExcludeMeals) {
            $slotMap = @($slotMap | Where-Object { [string]$_.ItemName -cne 'Meal' })
        }

        if ($slotMap.Count -le 0) {
            if ($ExcludeMeals) {
                Write-LWInfo ("{0} No non-Meal Backpack Items remain to lose." -f $Reason)
            }
            break
        }

        Show-LWInventorySlotsSection -Type 'backpack'
        $validSlots = @($slotMap | ForEach-Object { [int]$_.Slot })
        $slot = if ($validSlots.Count -eq 1) { $validSlots[0] } else { $null }
        while ($null -eq $slot) {
            $candidate = Read-LWInt -Prompt ("Backpack slot to lose ({0})" -f ($validSlots -join ', ')) -Min ($validSlots | Measure-Object -Minimum).Minimum -Max ($validSlots | Measure-Object -Maximum).Maximum
            if ($validSlots -contains [int]$candidate) {
                $slot = [int]$candidate
            }
            else {
                Write-LWWarn ("Choose one of the eligible Backpack slots: {0}." -f ($validSlots -join ', '))
            }
        }

        $slotEntry = @($slotMap | Where-Object { [int]$_.Slot -eq $slot } | Select-Object -First 1)
        if ($slotEntry.Count -eq 0) {
            break
        }

        $itemName = [string]$slotEntry[0].ItemName
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $itemName -Quantity 1)
        $lostItems += $itemName
        Write-LWInfo ("{0} Lost: {1}." -f $Reason, $itemName)
        $remainingToLose--
    }

    return @($lostItems)
}

function Invoke-LWBookFiveBloodPoisoningSectionDamage {
    param([int]$Section)

    if (-not (Test-LWHasState) -or -not (Test-LWBookFiveBloodPoisoningActive -State $script:GameState) -or [int]$Section -eq 63) {
        return $true
    }

    $before = [int]$script:GameState.Character.EnduranceCurrent
    $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage'
    $appliedLoss = [int]$lossResolution.AppliedLoss
    if ($appliedLoss -gt 0) {
        $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
        Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
    }

    $message = 'Book 5 blood poisoning weakens you as you press on.'
    if ($appliedLoss -gt 0) {
        $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
    }
    else {
        $message += ' No ENDURANCE is lost.'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
        $message += " $($lossResolution.Note)"
    }
    Write-LWInfo $message

    if (Invoke-LWFatalEnduranceCheck -Cause 'Blood poisoning reduced your Endurance to zero.') {
        return $false
    }

    return $true
}

function Add-LWWeaponWithOptionalReplace {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$PromptLabel = '',
        [switch]$Silent
    )

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
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return 'Weapon' }
        'backpack' { return 'Backpack' }
        'special' { return 'Special' }
    }
}

function Get-LWRecoveryStashEntry {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    $propertyName = Get-LWRecoveryStashPropertyName -Type $Type
    return $script:GameState.RecoveryStash.$propertyName
}

function Save-LWInventoryRecoveryEntry {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    $entry = Get-LWRecoveryStashEntry -Type $Type
    $entry.Items = @($Items)
    $entry.BookNumber = [int]$script:GameState.Character.BookNumber
    $entry.Section = [int]$script:GameState.CurrentSection
    $entry.SavedOn = (Get-Date).ToString('o')
}

function Clear-LWInventoryRecoveryEntry {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    $entry = Get-LWRecoveryStashEntry -Type $Type
    $entry.Items = @()
    $entry.BookNumber = $null
    $entry.Section = $null
    $entry.SavedOn = $null
}

function Get-LWInventoryRecoveryItems {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    return @((Get-LWRecoveryStashEntry -Type $Type).Items)
}

function Show-LWInventorySlotsSection {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

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

function Show-LWInventorySummary {
    $weapons = @($script:GameState.Inventory.Weapons)
    $backpack = @($script:GameState.Inventory.BackpackItems)
    $special = @($script:GameState.Inventory.SpecialItems)
    $safekeeping = @($script:GameState.Storage.SafekeepingSpecialItems)
    $backpackUsedCapacity = Get-LWInventoryUsedCapacity -Type 'backpack' -Items $backpack
    $hasBackpack = Test-LWStateHasBackpack -State $script:GameState

    Write-LWPanelHeader -Title 'Inventory' -AccentColor 'Yellow'
    Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2  {1}" -f $weapons.Count, (Format-LWCompactInventorySummary -Items $weapons -MaxGroups 2)) -ValueColor 'Gray'
    if ($hasBackpack) {
        Write-LWKeyValue -Label 'Backpack' -Value ("{0}/8  {1}" -f $backpackUsedCapacity, (Format-LWCompactInventorySummary -Items $backpack -MaxGroups 3)) -ValueColor 'Gray'
    }
    else {
        Write-LWKeyValue -Label 'Backpack' -Value 'unavailable (lost)' -ValueColor 'DarkGray'
    }
    Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12  {1}" -f $special.Count, (Format-LWCompactInventorySummary -Items $special -MaxGroups 3)) -ValueColor 'Gray'
    if ($safekeeping.Count -gt 0) {
        Write-LWKeyValue -Label 'Safekeeping' -Value (Format-LWCompactInventorySummary -Items $safekeeping -MaxGroups 3) -ValueColor 'DarkGray'
    }
    if (Test-LWStateHasConfiscatedEquipment) {
        Write-LWKeyValue -Label 'Confiscated' -Value (Get-LWConfiscatedInventorySummaryText) -ValueColor 'DarkGray'
    }
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
    if (@($script:GameState.Storage.SafekeepingSpecialItems).Count -gt 0) {
        Write-LWKeyValue -Label 'Safekeeping' -Value (Format-LWCompactInventorySummary -Items @($script:GameState.Storage.SafekeepingSpecialItems) -MaxGroups 4) -ValueColor 'DarkGray'
        Write-Host ''
    }
    if (Test-LWStateHasConfiscatedEquipment) {
        Write-LWKeyValue -Label 'Confiscated' -Value (Get-LWConfiscatedInventorySummaryText) -ValueColor 'DarkGray'
        Write-Host ''
    }
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
    if (Test-LWStateHasBroadswordPlusOne -State $script:GameState) {
        Write-LWSubtle '  Broadsword +1: +1 Combat Skill in combat and still counts as a Broadsword.'
        Write-Host ''
    }
    if (Test-LWStateHasMagicSpear -State $script:GameState) {
        Write-LWSubtle '  Magic Spear: weapon-like Special Item that counts as a Spear and matters in specific Book 2 Helghast fights.'
        Write-Host ''
    }
    if (Test-LWStateHasDrodarinWarHammer -State $script:GameState) {
        Write-LWSubtle '  Drodarin War Hammer: +1 Combat Skill in combat and counts as a Warhammer.'
        Write-Host ''
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCaptainDValSwordWeaponNames) -Type 'weapon'))) {
        Write-LWSubtle '  Captain D''Val''s Sword: +1 Combat Skill in combat and counts as a Sword.'
        Write-Host ''
    }
    if ((Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState) -gt 0) {
        Write-LWSubtle '  Silver Helm: +2 Combat Skill while carried as a Special Item.'
        Write-Host ''
    }
    if ((Get-LWStateHelmetEnduranceBonus -State $script:GameState) -gt 0) {
        Write-LWSubtle '  Helmet: +2 Endurance while carried as a Special Item.'
        Write-Host ''
    }
    elseif ((Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWHelmetItemNames) -Type 'special') -and (Get-LWStateSilverHelmCombatSkillBonus -State $script:GameState) -gt 0) {
        Write-LWSubtle '  Helmet: no Endurance bonus while Silver Helm is carried.'
        Write-Host ''
    }
    if ((Get-LWStatePaddedLeatherEnduranceBonus -State $script:GameState) -gt 0) {
        Write-LWSubtle '  Padded Leather Waistcoat: +2 Endurance while carried as a Special Item.'
        Write-Host ''
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWVordakGemItemNames) -Type 'backpack'))) {
        Write-LWSubtle '  Vordak Gem: cursed Book 1 loot; some routes punish carrying it.'
        Write-Host ''
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCrystalStarPendantItemNames) -Type 'special'))) {
        Write-LWSubtle '  Crystal Star Pendant: carry-forward Special Item that later books may reference.'
        Write-Host ''
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMealOfLaumspurItemNames) -Type 'backpack'))) {
        Write-LWSubtle '  Meal of Laumspur: satisfies a Meal and restores 3 Endurance, or restores 3 Endurance when consumed normally.'
        Write-Host ''
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWPotentHealingPotionItemNames) -Type 'backpack'))) {
        Write-LWSubtle '  Potent Laumspur Potion: restores 5 Endurance.'
        Write-Host ''
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWLongRopeItemNames) -Type 'backpack'))) {
        Write-LWSubtle '  Long Rope: occupies 2 backpack slots.'
        Write-Host ''
    }
    Write-LWSubtle '  Use add <type> <name> [qty] to add items quickly.'
    Write-LWSubtle '  Use drop <type> <slot> to remove by slot number, or drop <type> all to clear a section.'
    Write-LWSubtle '  Use recover <type> or recover all to restore stashed gear from a bulk drop.'
    $recoveryNotes = @()
    foreach ($type in @('weapon', 'backpack', 'special')) {
        $recoveryItems = @(Get-LWInventoryRecoveryItems -Type $type)
        if ($recoveryItems.Count -gt 0) {
            $recoveryNotes += ("{0} {1}" -f (Get-LWInventoryTypeLabel -Type $type), $recoveryItems.Count)
        }
    }
    if ($recoveryNotes.Count -gt 0) {
        Write-LWSubtle ("  Recovery stash: {0}" -f ($recoveryNotes -join ' | '))
    }
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
    if (Test-LWBookFiveLimbdeathActive -State $script:GameState) {
        $displayCombatSkill -= 3
        $combatSkillNotes += 'Limbdeath -3'
        if ($shieldBonus -gt 0) {
            $combatSkillNotes += 'Shield unusable'
        }
    }
    if ($combatSkillNotes.Count -gt 0) {
        $combatSkillText = "{0} ({1})" -f $displayCombatSkill, ($combatSkillNotes -join ', ')
    }

    $chainmailBonus = Get-LWStateChainmailEnduranceBonus -State $script:GameState
    $paddedLeatherBonus = Get-LWStatePaddedLeatherEnduranceBonus -State $script:GameState
    $helmetBonus = Get-LWStateHelmetEnduranceBonus -State $script:GameState
    $daggerPenalty = Get-LWStateDaggerOfVashnaEndurancePenalty -State $script:GameState
    $enduranceText = "{0} / {1}" -f $script:GameState.Character.EnduranceCurrent, $script:GameState.Character.EnduranceMax
    $enduranceNotes = @()
    if ($chainmailBonus -gt 0) {
        $enduranceNotes += "Chainmail +$chainmailBonus"
    }
    if ($paddedLeatherBonus -gt 0) {
        $enduranceNotes += "Padded Leather +$paddedLeatherBonus"
    }
    if ($helmetBonus -gt 0) {
        $enduranceNotes += "Helmet +$helmetBonus"
    }
    if ($daggerPenalty -lt 0) {
        $enduranceNotes += "Dagger of Vashna $daggerPenalty"
    }
    if ($enduranceNotes.Count -gt 0) {
        $enduranceText += " ({0})" -f ($enduranceNotes -join ', ')
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
    if (Test-LWStateHasMagicSpear -State $script:GameState) {
        Write-LWKeyValue -Label 'Magic Spear' -Value 'Weapon-like Special Item; counts as a Spear in combat.' -ValueColor 'DarkYellow'
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

    $previousSection = [int]$script:GameState.CurrentSection
    Save-LWCurrentSectionCheckpoint
    Resolve-LWSectionExit
    Register-LWStorySectionTransitionAchievementTriggers -FromSection $previousSection -ToSection $newSection
    $script:GameState.CurrentSection = $newSection
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Add-LWBookSectionVisit -Section $newSection
    if ([int]$script:GameState.Character.BookNumber -eq 5) {
        if (-not (Invoke-LWBookFiveBloodPoisoningSectionDamage -Section $newSection)) {
            Write-LWInfo "Moved to section $newSection."
            Invoke-LWMaybeAutosave
            return
        }
    }
    Invoke-LWSectionEntryRules
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
    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack. Recover one before adding Backpack items.'
        return
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $label = Get-LWInventoryTypeLabel -Type $Type
    $current = @(Get-LWInventoryItems -Type $Type)
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

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = $current }
        'backpack' { $script:GameState.Inventory.BackpackItems = $current }
        'special' { $script:GameState.Inventory.SpecialItems = $current }
    }

    Register-LWStoryInventoryAchievementTriggers -Type $Type -Name $resolvedName
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    Write-LWInfo "Added $Quantity x $resolvedName to $Type inventory."
    Invoke-LWMaybeAutosave
}

function TryAdd-LWInventoryItemSilently {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return $false
    }
    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack. Recover one before adding Backpack items.'
        return $false
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $current = @(Get-LWInventoryItems -Type $Type)
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

    switch ($Type) {
        'weapon' { $script:GameState.Inventory.Weapons = @($current) }
        'backpack' { $script:GameState.Inventory.BackpackItems = @($current) }
        'special' { $script:GameState.Inventory.SpecialItems = @($current) }
    }

    Register-LWStoryInventoryAchievementTriggers -Type $Type -Name $resolvedName
    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    return $true
}

function Remove-LWInventoryItemSilently {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Quantity = 1
    )

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return 0
    }

    $source = switch ($Type) {
        'weapon' { @($script:GameState.Inventory.Weapons) }
        'backpack' { @($script:GameState.Inventory.BackpackItems) }
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
        'special' { $script:GameState.Inventory.SpecialItems = @($remaining) }
    }

    Sync-LWStateEquipmentBonuses -State $script:GameState -WriteMessages
    [void](Sync-LWAchievements -Context 'inventory')
    return $removed
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
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type
    )

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
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
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
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'special')][string]$Type)

    if ($Type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack. Recover one before restoring Backpack items.'
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
    $recoverableTypes = @('weapon', 'backpack', 'special') | Where-Object { @(Get-LWInventoryRecoveryItems -Type $_).Count -gt 0 }
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
        $selection = Read-LWText -Prompt 'Recover which section? (weapon/backpack/special/all)'
    }

    if ([string]::IsNullOrWhiteSpace($selection)) {
        Write-LWWarn 'Type must be weapon, backpack, special, or all.'
        return
    }

    if ($selection.Trim().ToLowerInvariant() -eq 'all') {
        Restore-LWAllInventorySections
        return
    }

    $type = Resolve-LWInventoryType -Value $selection
    if ($null -eq $type) {
        Write-LWWarn 'Type must be weapon, backpack, special, or all.'
        return
    }

    Restore-LWInventorySection -Type $type
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

    if (Test-LWDiscipline -Name 'Hunting') {
        $huntingRestrictionReason = Get-LWStateHuntingMealRestrictionReason -State $script:GameState
        if (-not [string]::IsNullOrWhiteSpace($huntingRestrictionReason)) {
            Write-LWInfo $huntingRestrictionReason
        }
        else {
            $isWasteland = Read-LWYesNo -Prompt 'Are you in a wasteland or desert where Hunting does not help?' -Default $false
            if (-not $isWasteland) {
                Register-LWMealCoveredByHunting
                Write-LWInfo 'Hunting covers the meal. No backpack item spent.'
                return
            }
        }
    }

    if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack, so you cannot eat stored meals right now.'
        $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 3 -Source 'starvation'
        $appliedLoss = [int]$lossResolution.AppliedLoss
        if ($appliedLoss -gt 0) {
            $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ([int]$script:GameState.Character.EnduranceCurrent - $appliedLoss))
            Add-LWBookEnduranceDelta -Delta (-$appliedLoss)
        }
        Register-LWStarvationPenalty
        $message = if ($appliedLoss -gt 0) { "No meal available. Lose $appliedLoss ENDURANCE." } else { 'No meal available, but your current mode prevents the ENDURANCE loss.' }
        if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
            $message += " $($lossResolution.Note)"
        }
        Write-LWInfo $message
        Write-LWInfo "Endurance now $($script:GameState.Character.EnduranceCurrent)."
        if (Invoke-LWFatalEnduranceCheck -Cause 'Starved to death after failing to find a meal.') {
            return
        }
        Invoke-LWMaybeAutosave
        return
    }

    if ((Get-LWBackpackItemCount -Name 'Meal') -gt 0) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name 'Meal' -Quantity 1)
        Register-LWMealConsumed
        Write-LWInfo 'Meal consumed.'
        Invoke-LWMaybeAutosave
        return
    }

    $specialRationsName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSpecialRationsItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($specialRationsName)) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $specialRationsName -Quantity 1)
        Register-LWMealConsumed
        Write-LWInfo 'Special Rations consumed.'
        Invoke-LWMaybeAutosave
        return
    }

    $laumspurHerbName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWLaumspurHerbItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($laumspurHerbName)) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $laumspurHerbName -Quantity 1)
        Register-LWMealConsumed
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ([int]$script:GameState.Character.EnduranceCurrent + 3))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
            Write-LWInfo ("Laumspur Herb satisfies the meal and restores {0} ENDURANCE." -f $restored)
        }
        else {
            Write-LWInfo 'Laumspur Herb satisfies the meal.'
        }
        Invoke-LWMaybeAutosave
        return
    }

    $mealOfLaumspurName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMealOfLaumspurItemNames) -Type 'backpack'
    if (-not [string]::IsNullOrWhiteSpace($mealOfLaumspurName)) {
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $mealOfLaumspurName -Quantity 1)
        Register-LWMealConsumed
        $before = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ([int]$script:GameState.Character.EnduranceCurrent + 3))
        $restored = [int]$script:GameState.Character.EnduranceCurrent - $before
        if ($restored -gt 0) {
            Add-LWBookEnduranceDelta -Delta $restored
            Write-LWInfo ("Meal of Laumspur satisfies the meal and restores {0} ENDURANCE." -f $restored)
        }
        else {
            Write-LWInfo 'Meal of Laumspur satisfies the meal.'
        }
        Invoke-LWMaybeAutosave
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

function Use-LWHealingPotion {
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if ($script:GameState.Combat.Active) {
        Write-LWWarn 'Healing Potions cannot be used during combat.'
        return
    }

    if (-not (Test-LWStateHasBackpack -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack, so you cannot use stored healing items right now.'
        return
    }

    $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWConcentratedHealingPotionItemNames) -Type 'backpack'
    $restoreAmount = 8
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWPotentHealingPotionItemNames) -Type 'backpack'
        $restoreAmount = 5
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWHealingPotionItemNames) -Type 'backpack'
        $restoreAmount = 4
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWLaumspurHerbItemNames) -Type 'backpack'
        $restoreAmount = 3
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMealOfLaumspurItemNames) -Type 'backpack'
        $restoreAmount = 3
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWOedeHerbItemNames) -Type 'backpack'
        $restoreAmount = 10
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWLarnumaOilItemNames) -Type 'backpack'
        $restoreAmount = 2
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWRendalimsElixirItemNames) -Type 'backpack'
        $restoreAmount = 6
    }
    if ([string]::IsNullOrWhiteSpace($potionName)) {
        $potionName = Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWBottleOfKourshahItemNames) -Type 'backpack'
        $restoreAmount = 4
    }

    if ([string]::IsNullOrWhiteSpace($potionName)) {
        Write-LWWarn 'No usable healing potion or Laumspur Herb found in backpack items.'
        return
    }

    [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $potionName -Quantity 1)
    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent += $restoreAmount
    if ($script:GameState.Character.EnduranceCurrent -gt $script:GameState.Character.EnduranceMax) {
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    }
    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before

    $conditionMessages = @()
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHealingPotionItemNames) -Target $potionName)) -or
        -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWLaumspurHerbItemNames) -Target $potionName))) {
        if (Test-LWBookFiveBloodPoisoningActive -State $script:GameState) {
            $script:GameState.Conditions.BookFiveBloodPoisoning = $false
            $conditionMessages += 'Blood poisoning cured.'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOedeHerbItemNames) -Target $potionName))) {
        if (Test-LWBookFiveLimbdeathActive -State $script:GameState) {
            $script:GameState.Conditions.BookFiveLimbdeath = $false
            Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
            $conditionMessages += 'Limbdeath cured.'
        }
    }

    Add-LWBookEnduranceDelta -Delta $restored
    Register-LWPotionUsed -PotionName $potionName -EnduranceRestored $restored
    $message = "$potionName restores $restoreAmount Endurance. Current Endurance: $($script:GameState.Character.EnduranceCurrent)."
    if ($conditionMessages.Count -gt 0) {
        $message += " $($conditionMessages -join ' ')"
    }
    Write-LWInfo $message
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
        $mindblastBonus = if ((Test-LWPropertyExists -Object $State.Combat -Name 'MindblastCombatSkillBonus') -and $null -ne $State.Combat.MindblastCombatSkillBonus) { [int]$State.Combat.MindblastCombatSkillBonus } else { 2 }
        $playerCombatSkill += $mindblastBonus
        $notes += "Mindblast +$mindblastBonus"
    }

    $aletherBonus = Get-LWStateAletherCombatSkillBonus -State $State
    if ($aletherBonus -gt 0) {
        $playerCombatSkill += $aletherBonus
        $notes += "Alether +$aletherBonus"
    }

    if (Test-LWBookFiveLimbdeathActive -State $State) {
        $playerCombatSkill -= 3
        $notes += 'Limbdeath -3'
        if ((Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames)) -and (Get-LWStateShieldCombatSkillBonus -State $State) -eq 0) {
            $notes += 'Shield unusable'
        }
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
    else {
        $broadswordPlusOneBonus = Get-LWStateBroadswordPlusOneCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($broadswordPlusOneBonus -gt 0) {
            $playerCombatSkill += $broadswordPlusOneBonus
            $notes += "Broadsword +$broadswordPlusOneBonus"
        }

        $drodarinWarHammerBonus = Get-LWStateDrodarinWarHammerCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($drodarinWarHammerBonus -gt 0) {
            $playerCombatSkill += $drodarinWarHammerBonus
            $notes += "Drodarin War Hammer +$drodarinWarHammerBonus"
        }

        $captainDValSwordBonus = Get-LWStateCaptainDValSwordCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($captainDValSwordBonus -gt 0) {
            $playerCombatSkill += $captainDValSwordBonus
            $notes += "Captain D'Val's Sword +$captainDValSwordBonus"
        }

        if ((Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') -and -not [string]::IsNullOrWhiteSpace([string]$State.Character.WeaponskillWeapon) -and (Test-LWWeaponMatchesWeaponskill -Weapon ([string]$State.Combat.EquippedWeapon) -WeaponskillWeapon ([string]$State.Character.WeaponskillWeapon))) {
            $playerCombatSkill += 2
            $weaponskillLabel = if (Test-LWWeaponIsDrodarinWarHammer -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Warhammer' } elseif (Test-LWWeaponIsBroadswordPlusOne -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Broadsword' } elseif (Test-LWWeaponIsCaptainDValSword -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Sword' } else { [string]$State.Combat.EquippedWeapon }
            $notes += "Weaponskill +2 ($weaponskillLabel)"
        }
    }

    if ([bool]$State.Combat.EnemyUsesMindforce) {
        if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
            $notes += 'Mindforce blocked by Mindshield'
        }
        else {
            $notes += ("Mindforce -{0} END each round" -f (Get-LWCombatMindforceLossPerRound -State $State))
        }
    }
    if ([bool]$State.Combat.EnemyRequiresMagicSpear) {
        if (Test-LWWeaponIsMagicSpear -Weapon ([string]$State.Combat.EquippedWeapon)) {
            $notes += 'Only Magic Spear can wound this foe'
        }
        else {
            $notes += 'Enemy can only be harmed by Magic Spear'
        }
    }
    elseif ((Test-LWPropertyExists -Object $State.Combat -Name 'EnemyRequiresMagicalWeapon') -and [bool]$State.Combat.EnemyRequiresMagicalWeapon) {
        if (Test-LWWeaponIsMagicalForCombat -Weapon ([string]$State.Combat.EquippedWeapon)) {
            $notes += 'Only a magical weapon can wound this foe'
        }
        else {
            $notes += 'Enemy can only be harmed by a magical weapon'
        }
    }

    $activePlayerModifier = Get-LWCombatActivePlayerCombatSkillModifier -State $State
    if ($activePlayerModifier -ne 0) {
        $playerCombatSkill += $activePlayerModifier
        $modifierRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierRounds) { [int]$State.Combat.PlayerCombatSkillModifierRounds } else { 0 }
        $afterModifier = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRounds') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRounds) { [int]$State.Combat.PlayerCombatSkillModifierAfterRounds } else { 0 }
        $afterStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerCombatSkillModifierAfterRoundStart') -and $null -ne $State.Combat.PlayerCombatSkillModifierAfterRoundStart) { [int]$State.Combat.PlayerCombatSkillModifierAfterRoundStart } else { 0 }
        if ($modifierRounds -gt 0 -and $afterModifier -ne 0 -and $afterStartRound -gt 0) {
            $notes += "Player modifier changes after round $($afterStartRound - 1)"
        }
        elseif ($modifierRounds -gt 0) {
            $notes += "Player modifier $(Format-LWSigned -Value $activePlayerModifier) (rounds 1-$modifierRounds)"
        }
        elseif ($afterModifier -ne 0 -and $afterStartRound -gt 0) {
            $notes += "Player modifier $(Format-LWSigned -Value $activePlayerModifier) (round $afterStartRound+)"
        }
        else {
            $notes += "Player modifier $(Format-LWSigned -Value $activePlayerModifier)"
        }
    }

    if ([int]$State.Combat.EnemyCombatSkillModifier -ne 0) {
        $enemyCombatSkill += [int]$State.Combat.EnemyCombatSkillModifier
        $notes += "Enemy modifier $(Format-LWSigned -Value ([int]$State.Combat.EnemyCombatSkillModifier))"
    }

    $specialLossAmount = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossAmount) { [int]$State.Combat.SpecialPlayerEnduranceLossAmount } else { 0 }
    if ($specialLossAmount -gt 0) {
        $specialLossStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$State.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
        $specialLossReason = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossReason') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.SpecialPlayerEnduranceLossReason)) { [string]$State.Combat.SpecialPlayerEnduranceLossReason } else { 'Special hazard' }
        $notes += ("{0} -{1} END from round {2}" -f $specialLossReason, $specialLossAmount, $specialLossStartRound)
    }

    if ([bool]$State.Combat.CanEvade) {
        $evadeStatus = Get-LWCombatEvadeStatusText -State $State
        if ($evadeStatus -ne 'Yes') {
            $notes += ("Evade {0}" -f $evadeStatus.ToLowerInvariant())
        }
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
    if (Test-LWWeaponIsDrodarinWarHammer -Weapon $Weapon) {
        return 'Drodarin War Hammer'
    }
    if (Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) {
        return 'Broadsword +1'
    }
    if (Test-LWWeaponIsBoneSword -Weapon $Weapon) {
        return 'Bone Sword'
    }
    if (Test-LWWeaponIsMagicSpear -Weapon $Weapon) {
        return 'Magic Spear'
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
    if (Test-LWCombatCanEvadeNow -State $script:GameState) {
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
        [Parameter(Mandatory = $true)][string]$EvadeStatus,
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
    $evadeColor = if ($EvadeStatus -eq 'No') { 'Gray' } else { 'Yellow' }
    Write-LWKeyValue -Label 'Evade Allowed' -Value $EvadeStatus -ValueColor $evadeColor
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
    $evadeStatus = if (-not $canEvade) { 'No' } elseif ((Test-LWPropertyExists -Object $Summary -Name 'EvadeAvailableAfterRound') -and [int]$Summary.EvadeAvailableAfterRound -gt 0 -and [int]$Summary.RoundCount -lt [int]$Summary.EvadeAvailableAfterRound) { "After round $([int]$Summary.EvadeAvailableAfterRound)" } else { 'Yes' }
    $mindforceLossPerRound = if ((Test-LWPropertyExists -Object $Summary -Name 'MindforceLossPerRound') -and $null -ne $Summary.MindforceLossPerRound) { [int]$Summary.MindforceLossPerRound } else { 2 }
    $mindforceStatus = if (-not $enemyUsesMindforce) { 'Off' } elseif ($mindforceBlocked) { 'Blocked by Mindshield' } else { "Active (-$mindforceLossPerRound END/round)" }
    $knockoutStatus = if ((Test-LWPropertyExists -Object $Summary -Name 'AttemptKnockout') -and [bool]$Summary.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }

    Write-LWPanelHeader -Title 'Combat Summary' -AccentColor 'DarkRed'
    Write-LWKeyValue -Label 'Enemy' -Value $Summary.EnemyName -ValueColor 'White'
    Write-LWKeyValue -Label 'Outcome' -Value $Summary.Outcome -ValueColor (Get-LWOutcomeColor -Outcome $Summary.Outcome)
    if ((Test-LWPropertyExists -Object $Summary -Name 'SpecialResolutionSection') -and $null -ne $Summary.SpecialResolutionSection) {
        Write-LWKeyValue -Label 'Next Section' -Value ([string]$Summary.SpecialResolutionSection) -ValueColor 'Yellow'
    }
    Show-LWCombatDuelPanel -Title 'Aftermath' -EnemyName ([string]$Summary.EnemyName) -PlayerCurrent ([int]$Summary.PlayerEnd) -PlayerMax $playerEndMax -EnemyCurrent ([int]$Summary.EnemyEnd) -EnemyMax $enemyEndMax -PlayerCombatSkill $playerCombatSkill -EnemyCombatSkill $enemyCombatSkill -CombatRatio $ratio -RoundCount ([int]$Summary.RoundCount)
    Show-LWCombatTacticalPanel -Weapon $weapon -UseMindblast:$useMindblast -EnemyIsUndead:$enemyUndead -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -EvadeStatus $evadeStatus -Mode $mode -Notes $notes -UsesSommerswerd:$usingSommerswerd -SommerswerdSuppressed:([bool]((Test-LWPropertyExists -Object $Summary -Name 'SommerswerdSuppressed') -and [bool]$Summary.SommerswerdSuppressed))
    Show-LWCombatRecentRounds -Rounds @($Summary.Log) -Count 5 -Title 'Round Recap'
    if ((Test-LWPropertyExists -Object $Summary -Name 'SpecialResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$Summary.SpecialResolutionNote)) {
        Write-LWSubtle ("  {0}" -f [string]$Summary.SpecialResolutionNote)
    }
    Write-LWSubtle '  Use combat log for the full round-by-round archive.'
}

function Show-LWCombatStatus {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return
    }

    $breakdown = Get-LWCombatBreakdown
    $mindforceStatus = Get-LWCombatMindforceStatusText -State $script:GameState
    $knockoutStatus = if ([bool]$script:GameState.Combat.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }
    Write-LWPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWKeyValue -Label 'Enemy' -Value $script:GameState.Combat.EnemyName -ValueColor 'White'
    Show-LWCombatDuelPanel -EnemyName ([string]$script:GameState.Combat.EnemyName) -PlayerCurrent ([int]$script:GameState.Character.EnduranceCurrent) -PlayerMax ([int]$script:GameState.Character.EnduranceMax) -EnemyCurrent ([int]$script:GameState.Combat.EnemyEnduranceCurrent) -EnemyMax ([int]$script:GameState.Combat.EnemyEnduranceMax) -PlayerCombatSkill ([int]$breakdown.PlayerCombatSkill) -EnemyCombatSkill ([int]$breakdown.EnemyCombatSkill) -CombatRatio ([int]$breakdown.CombatRatio) -RoundCount (@($script:GameState.Combat.Log).Count)
    Show-LWCombatTacticalPanel -Weapon (Get-LWCombatDisplayWeapon -Weapon $script:GameState.Combat.EquippedWeapon) -UseMindblast:([bool]$script:GameState.Combat.UseMindblast) -EnemyIsUndead:([bool]$script:GameState.Combat.EnemyIsUndead) -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -EvadeStatus (Get-LWCombatEvadeStatusText -State $script:GameState) -Mode ([string]$script:GameState.Settings.CombatMode) -Notes @($breakdown.Notes) -UsesSommerswerd:(Test-LWCombatUsesSommerswerd -State $script:GameState) -SommerswerdSuppressed:([bool]$script:GameState.Combat.SommerswerdSuppressed)
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
    $specialBaseLoss = 0
    $specialAppliedLoss = 0
    $specialNotes = @()

    if ([bool]$State.Combat.EnemyRequiresMagicSpear -and -not (Test-LWWeaponIsMagicSpear -Weapon ([string]$State.Combat.EquippedWeapon))) {
        if ($baseEnemyLoss -gt 0) {
            $messages += 'Only the Magic Spear can wound this foe. Your attack deals no damage.'
        }
        $enemyLossApplied = 0
        $specialNotes += 'Needs Magic Spear'
    }
    elseif ([bool]$State.Combat.EnemyRequiresMagicalWeapon -and -not (Test-LWWeaponIsMagicalForCombat -Weapon ([string]$State.Combat.EquippedWeapon))) {
        if ($baseEnemyLoss -gt 0) {
            $messages += 'Only a magical weapon can wound this foe. Your attack deals no damage.'
        }
        $enemyLossApplied = 0
        $specialNotes += 'Needs magical weapon'
    }

    if ($enemyLossApplied -gt 0 -and (Test-LWCombatSommerswerdUndeadDoubleDamageActive -State $State)) {
        $enemyLossApplied = [Math]::Min([int]$State.Combat.EnemyEnduranceCurrent, ($baseEnemyLoss * 2))
        if ($enemyLossApplied -gt $baseEnemyLoss) {
            $specialNotes += 'Undead x2'
            $messages += "Sommerswerd doubles damage against undead: enemy loses $enemyLossApplied instead of $baseEnemyLoss."
        }
    }
    if ($enemyLossApplied -gt 0 -and (Test-LWPropertyExists -Object $State.Combat -Name 'DoubleEnemyEnduranceLoss') -and [bool]$State.Combat.DoubleEnemyEnduranceLoss) {
        $doubledLoss = [Math]::Min([int]$State.Combat.EnemyEnduranceCurrent, ($enemyLossApplied * 2))
        if ($doubledLoss -gt $enemyLossApplied) {
            $messages += "Special rule doubles the enemy's ENDURANCE loss to $doubledLoss."
            $enemyLossApplied = $doubledLoss
            $specialNotes += 'Enemy loss x2'
        }
    }
    $ignoreEnemyLossRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'IgnoreEnemyEnduranceLossRounds') -and $null -ne $State.Combat.IgnoreEnemyEnduranceLossRounds) { [int]$State.Combat.IgnoreEnemyEnduranceLossRounds } else { 0 }
    if ($enemyLossApplied -gt 0 -and $ignoreEnemyLossRounds -gt 0 -and $roundNumber -le $ignoreEnemyLossRounds) {
        $messages += ("Special rule: ignore all enemy ENDURANCE loss in round {0}." -f $roundNumber)
        $enemyLossApplied = 0
        $specialNotes += 'Enemy loss ignored'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$playerLossResolution.Note)) {
        $messages += [string]$playerLossResolution.Note
    }

    if (Test-LWCombatUsesMindforce -State $State) {
        $mindforceBaseLoss = Get-LWCombatMindforceLossPerRound -State $State
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

    $specialLossAmount = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossAmount) { [int]$State.Combat.SpecialPlayerEnduranceLossAmount } else { 0 }
    $specialLossStartRound = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $State.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$State.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
    $specialLossReason = if ((Test-LWPropertyExists -Object $State.Combat -Name 'SpecialPlayerEnduranceLossReason') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.SpecialPlayerEnduranceLossReason)) { [string]$State.Combat.SpecialPlayerEnduranceLossReason } else { 'Special hazard' }
    if ($specialLossAmount -gt 0 -and $roundNumber -ge $specialLossStartRound) {
        $specialBaseLoss = $specialLossAmount
        $specialResolution = Resolve-LWGameplayEnduranceLoss -Loss $specialBaseLoss -Source 'combat' -State $State
        $remainingAfterCombatAndMindforce = [Math]::Max(0, ($currentPlayerEnd - $combatPlayerLossApplied - $mindforceAppliedLoss))
        $specialAppliedLoss = [Math]::Min($remainingAfterCombatAndMindforce, [int]$specialResolution.AppliedLoss)
        if ($specialAppliedLoss -gt 0) {
            $specialNotes += $specialLossReason
            $messages += ("{0} inflicts {1} END." -f $specialLossReason, $specialAppliedLoss)
        }
        else {
            $messages += ("{0} surges, but no END is lost." -f $specialLossReason)
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$specialResolution.Note)) {
            $messages += [string]$specialResolution.Note
        }
    }

    $totalPlayerLossApplied = $combatPlayerLossApplied + $mindforceAppliedLoss + $specialAppliedLoss
    $totalPlayerLossBase = [int]$PlayerLoss + $mindforceBaseLoss + $specialBaseLoss
    $ignorePlayerLossRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'IgnorePlayerEnduranceLossRounds') -and $null -ne $State.Combat.IgnorePlayerEnduranceLossRounds) { [int]$State.Combat.IgnorePlayerEnduranceLossRounds } else { 0 }
    if ([bool]$State.Combat.IgnoreFirstRoundEnduranceLoss -and $ignorePlayerLossRounds -lt 1) {
        $ignorePlayerLossRounds = 1
    }
    if ($ignorePlayerLossRounds -gt 0 -and $roundNumber -le $ignorePlayerLossRounds -and $totalPlayerLossApplied -gt 0) {
        if ($ignorePlayerLossRounds -eq 1) {
            $messages += 'Surprise attack advantage: ignore all Lone Wolf END loss in the first round.'
        }
        else {
            $messages += ("Surprise attack advantage: ignore all Lone Wolf END loss in rounds 1-{0}." -f $ignorePlayerLossRounds)
        }
        $specialNotes += 'First-round loss ignored'
        $combatPlayerLossApplied = 0
        $mindforceAppliedLoss = 0
        $specialAppliedLoss = 0
        $totalPlayerLossApplied = 0
    }

    if ([bool]$State.Combat.JavekPoisonRule -and [int]$PlayerLoss -gt 0) {
        $javekRoll = Get-LWRandomDigit
        Write-LWCurrentSectionRandomNumberRoll -Roll $javekRoll -State $State
        if ($javekRoll -eq 9) {
            $combatPlayerLossApplied = $currentPlayerEnd
            $mindforceAppliedLoss = 0
            $specialAppliedLoss = 0
            $totalPlayerLossApplied = $currentPlayerEnd
            $messages += 'The Javek''s fangs pierce your padded arm. The venom stops your heart.'
            $specialNotes += 'Javek venom'
        }
        else {
            $combatPlayerLossApplied = 0
            $mindforceAppliedLoss = 0
            $specialAppliedLoss = 0
            $totalPlayerLossApplied = 0
            $messages += 'The Javek''s fangs sink harmlessly into your padded arm. You lose no ENDURANCE.'
            $specialNotes += 'Padded arm'
        }
    }

    $newEnemyEnd = [Math]::Max(0, ([int]$State.Combat.EnemyEnduranceCurrent - $enemyLossApplied))
    $newPlayerEnd = [Math]::Max(0, ($currentPlayerEnd - $totalPlayerLossApplied))
    $outcome = 'Continue'
    $specialResolutionSection = $null
    $specialResolutionNote = $null
    $fallOnRollValue = if ((Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollValue') -and $null -ne $State.Combat.FallOnRollValue) { [int]$State.Combat.FallOnRollValue } else { $null }
    if ($null -ne $fallOnRollValue -and [int]$Roll -eq $fallOnRollValue -and (Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollResolutionSection') -and $null -ne $State.Combat.FallOnRollResolutionSection) {
        $outcome = 'Special'
        $specialResolutionSection = [int]$State.Combat.FallOnRollResolutionSection
        $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'FallOnRollResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.FallOnRollResolutionNote)) { [string]$State.Combat.FallOnRollResolutionNote } else { ("Section result: this roll makes you fall. Turn to {0}." -f $specialResolutionSection) }
        $messages += $specialResolutionNote
    }
    elseif ($newPlayerEnd -le 0) {
        if ((Test-LWPropertyExists -Object $State.Combat -Name 'DefeatResolutionSection') -and $null -ne $State.Combat.DefeatResolutionSection) {
            $outcome = 'Special'
            $specialResolutionSection = [int]$State.Combat.DefeatResolutionSection
            $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'DefeatResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.DefeatResolutionNote)) { [string]$State.Combat.DefeatResolutionNote } else { ("Section result: losing this combat sends you to {0}." -f $specialResolutionSection) }
            $messages += $specialResolutionNote
        }
        else {
            $outcome = 'Defeat'
        }
    }
    elseif ($totalPlayerLossApplied -gt 0 -and (Test-LWPropertyExists -Object $State.Combat -Name 'PlayerLossResolutionSection') -and $null -ne $State.Combat.PlayerLossResolutionSection) {
        $outcome = 'Special'
        $specialResolutionSection = [int]$State.Combat.PlayerLossResolutionSection
        $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerLossResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.PlayerLossResolutionNote)) { [string]$State.Combat.PlayerLossResolutionNote } else { ("Section result: losing ENDURANCE sends you to {0}." -f $specialResolutionSection) }
        $messages += $specialResolutionNote
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
        SpecialLoss         = $specialAppliedLoss
        SpecialLossBase     = $specialBaseLoss
        NewEnemyEnd         = $newEnemyEnd
        NewPlayerEnd        = $newPlayerEnd
        UsedCRT             = $usedCRT
        CRTColumn           = $crtColumn
        Messages            = @($messages)
        Outcome             = $outcome
        SpecialResolutionSection = $specialResolutionSection
        SpecialResolutionNote = $specialResolutionNote
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
            SpecialLoss = $specialAppliedLoss
            SpecialLossBase = $specialBaseLoss
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

    $bookTwoSection106Helghast = ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 106)
    $bookTwoSection332Helghast = ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 332)
    $quickStart = Get-LWCombatStartArguments -Arguments $Arguments
    $useQuickDefaults = $false
    if ($null -ne $quickStart) {
        $enemyName = $quickStart.EnemyName
        $enemyCombatSkill = $quickStart.EnemyCombatSkill
        $enemyEndurance = $quickStart.EnemyEndurance
        Write-LWInfo "Quick combat setup: $enemyName (CS $enemyCombatSkill, END $enemyEndurance)."
        $useQuickDefaults = Read-LWYesNo -Prompt 'Use default combat assumptions for the rest of setup?' -Default $true
    }
    elseif ($bookTwoSection106Helghast) {
        $enemyName = 'Helghast'
        $enemyCombatSkill = 22
        $enemyEndurance = 30
        Write-LWInfo 'Book 2 section 106 combat detected: Helghast (CS 22, END 30).'
    }
    elseif ($bookTwoSection332Helghast) {
        $enemyName = 'Helghast'
        $enemyCombatSkill = 21
        $enemyEndurance = 30
        Write-LWInfo 'Book 2 section 332 combat detected: Helghast (CS 21, END 30).'
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

    if ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 344 -and [string]$enemyName -ieq 'Helghast') {
        Write-LWWarn 'Section 344 is not a combat. The correct route there is to flee to section 183.'
        return $false
    }

    $enemyImmune = $false
    $enemyUndead = $false
    $enemyUsesMindforce = $false
    $enemyRequiresMagicSpear = $false
    $enemyRequiresMagicalWeapon = $false
    $canEvade = $false
    $evadeAvailableAfterRound = 0
    $evadeResolutionSection = $null
    $evadeResolutionNote = $null
    $oneRoundOnly = $false
    $mindforceLossPerRound = 2
    $playerModRounds = 0
    $playerModAfterRounds = 0
    $playerModAfterRoundStart = $null
    $mindblastCombatSkillBonus = 2
    $victoryResolutionSection = $null
    $victoryResolutionNote = $null
    $victoryWithoutLossSection = $null
    $victoryWithoutLossNote = $null
    $victoryWithinRoundsSection = $null
    $victoryWithinRoundsMax = $null
    $victoryWithinRoundsNote = $null
    $ongoingFailureAfterRoundsSection = $null
    $ongoingFailureAfterRoundsThreshold = $null
    $ongoingFailureAfterRoundsNote = $null
    $playerLossResolutionSection = $null
    $playerLossResolutionNote = $null
    $useJavekPoisonRule = $false
    $allowAletherBeforeCombat = $true
    $specialPlayerLossAmount = 0
    $specialPlayerLossStartRound = 1
    $specialPlayerLossReason = $null
    $ignorePlayerEnduranceLossRounds = 0
    $ignoreEnemyEnduranceLossRounds = 0
    $doubleEnemyEnduranceLoss = $false
    $defeatResolutionSection = $null
    $defeatResolutionNote = $null
    $fallOnRollValue = $null
    $fallOnRollResolutionSection = $null
    $fallOnRollResolutionNote = $null
    $restoreHalfEnduranceLossOnVictory = $false
    $restoreHalfEnduranceLossOnEvade = $false
    if (-not $useQuickDefaults) {
        $enemyImmune = Read-LWYesNo -Prompt 'Is the enemy immune to Mindblast?' -Default $false
        $enemyUndead = Read-LWYesNo -Prompt 'Is the enemy undead?' -Default $false
        $enemyUsesMindforce = Read-LWYesNo -Prompt 'Is the enemy attacking with Mindforce each combat round?' -Default $false
        $canEvade = Read-LWYesNo -Prompt 'Can Lone Wolf evade this combat if desired?' -Default $false
    }

    if ($bookTwoSection106Helghast) {
        $enemyImmune = $true
        $enemyUsesMindforce = $true
        $enemyRequiresMagicSpear = $true
        $canEvade = $false
        Write-LWInfo 'Book 2 section 106: this Helghast is immune to Mindblast, attacks with Mindforce each round, and can only be harmed by the Magic Spear.'
    }
    elseif ($bookTwoSection332Helghast) {
        $enemyImmune = $true
        $enemyUsesMindforce = $true
        $canEvade = $true
        Write-LWInfo 'Book 2 section 332: this Helghast is immune to Mindblast and attacks with a Mindforce-style assault each round.'
    }

    $equippedWeapon = Select-LWCombatWeapon -DefaultWeapon (Get-LWPreferredCombatWeapon -State $script:GameState)
    $sommerswerdSuppressed = $false
    $aletherCombatSkillBonus = 0
    $attemptKnockout = $false
    if ([int]$script:GameState.Character.BookNumber -eq 3 -and @(170, 328) -contains [int]$script:GameState.CurrentSection) {
        $allowAletherBeforeCombat = $false
    }
    if ($allowAletherBeforeCombat -and (Test-LWCombatAletherAvailable -State $script:GameState)) {
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

    $playerMod = 0
    $enemyMod = 0
    $ignoreFirstRoundEnduranceLoss = $false
    if ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 29 -and [string]$enemyName -ieq 'Vordak') {
        $enemyUndead = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 2
            Write-LWWarn 'Book 1 section 29: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        $victoryResolutionSection = 270
        $victoryResolutionNote = 'Section 29 result: victory sends you to 270.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 34 -and [string]$enemyName -ieq 'Vordak') {
        $enemyUndead = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 2
            Write-LWWarn 'Book 1 section 34: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        $victoryResolutionSection = 328
        $victoryResolutionNote = 'Section 34 result: victory sends you to 328.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 43 -and [string]$enemyName -ieq 'Black Bear') {
        $canEvade = $true
        $evadeAvailableAfterRound = 3
        $evadeResolutionSection = 106
        $evadeResolutionNote = 'Section 43 result: after round 3 you may flee downhill to 106.'
        $victoryResolutionSection = 195
        $victoryResolutionNote = 'Section 43 result: victory sends you to 195.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 55 -and [string]$enemyName -ieq 'Giak') {
        $playerMod += 4
        Write-LWInfo 'Book 1 section 55: surprise attack grants +4 Combat Skill for the whole fight.'
        $victoryResolutionSection = 325
        $victoryResolutionNote = 'Section 55 result: victory sends you to 325.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 133 -and [string]$enemyName -ieq 'Winged Serpent') {
        $enemyImmune = $true
        Write-LWInfo 'Book 1 section 133: Winged Serpent is immune to Mindblast.'
        $victoryResolutionSection = 266
        $victoryResolutionNote = 'Section 133 result: victory sends you to 266.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 170 -and [string]$enemyName -ieq 'Burrowcrawler') {
        $enemyImmune = $true
        Write-LWInfo 'Book 1 section 170: Burrowcrawler is immune to Mindblast.'

        $hasTorch = -not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWTorchItemNames) -Type 'backpack'))
        $hasTinderbox = -not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWTinderboxItemNames) -Type 'backpack'))
        $torchLit = $false
        if ($hasTorch -and $hasTinderbox) {
            if ($useQuickDefaults) {
                $torchLit = $true
            }
            else {
                $torchLit = Read-LWYesNo -Prompt 'Light a Torch to avoid the darkness penalty?' -Default $true
            }
        }

        if ($torchLit) {
            Write-LWInfo 'Torch lit. No darkness penalty applies in this fight.'
        }
        else {
            $playerMod -= 3
            Write-LWWarn 'Book 1 section 170: fighting in darkness applies -3 Combat Skill.'
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and @(180, 343) -contains [int]$script:GameState.CurrentSection) {
        Write-LWInfo ("Book 1 section {0}: fight these enemies one at a time." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and @(191, 220) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Bodyguard') {
        $canEvade = $true
        $evadeResolutionSection = 234
        $evadeResolutionNote = ("Section {0} result: evading means jumping from the caravan to 234." -f [int]$script:GameState.CurrentSection)
        $victoryResolutionSection = 24
        $victoryResolutionNote = ("Section {0} result: victory sends you to 24." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 231 -and [string]$enemyName -ieq 'Robber') {
        $canEvade = $true
        $evadeAvailableAfterRound = 2
        $evadeResolutionSection = 7
        $evadeResolutionNote = 'Section 231 result: after round 2 you may flee through the front door to 7.'
        $victoryWithinRoundsSection = 94
        $victoryWithinRoundsMax = 4
        $victoryWithinRoundsNote = 'Section 231 result: kill the robber within 4 rounds and turn to 94.'
        $ongoingFailureAfterRoundsSection = 203
        $ongoingFailureAfterRoundsThreshold = 4
        $ongoingFailureAfterRoundsNote = 'Section 231 result: if you are still fighting after 4 rounds, turn to 203.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 255 -and [string]$enemyName -ieq 'Gourgaz') {
        $enemyImmune = $true
        Write-LWInfo 'Book 1 section 255: Gourgaz is immune to Mindblast.'
        $victoryResolutionSection = 82
        $victoryResolutionNote = 'Section 255 result: victory sends you to 82.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 283 -and [string]$enemyName -ieq 'Vordak') {
        $enemyUndead = $true
        $playerMod += 2
        $playerModRounds = 1
        Write-LWInfo 'Book 1 section 283: surprise grants +2 Combat Skill in round 1.'
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerModAfterRounds -= 2
            $playerModAfterRoundStart = 2
            Write-LWWarn 'Book 1 section 283: Vordak Mindforce applies -2 Combat Skill from round 2 onward unless you possess Mindshield.'
        }
        $victoryResolutionSection = 123
        $victoryResolutionNote = 'Section 283 result: victory sends you to 123.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 339 -and [string]$enemyName -ieq 'Robber') {
        $canEvade = $true
        $evadeResolutionSection = 7
        $evadeResolutionNote = 'Section 339 result: you may flee through the front door to 7.'
        $victoryWithinRoundsSection = 94
        $victoryWithinRoundsMax = 4
        $victoryWithinRoundsNote = 'Section 339 result: kill the robber within 4 rounds and turn to 94.'
        $ongoingFailureAfterRoundsSection = 203
        $ongoingFailureAfterRoundsThreshold = 4
        $ongoingFailureAfterRoundsNote = 'Section 339 result: if you are still fighting after 4 rounds, turn to 203.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 1 -and [int]$script:GameState.CurrentSection -eq 342 -and [string]$enemyName -ieq 'Vordak') {
        $enemyUndead = $true
        $enemyImmune = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 2
            Write-LWWarn 'Book 1 section 342: Vordak Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        Write-LWInfo 'Book 1 section 342: Vordak is immune to Mindblast.'
        $victoryResolutionSection = 123
        $victoryResolutionNote = 'Section 342 result: victory sends you to 123.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 5 -and [string]$enemyName -ieq 'Wounded Helghast') {
        $enemyUndead = $true
        $enemyImmune = $true
        Write-LWInfo 'Book 2 section 5: Wounded Helghast is undead and immune to Mindblast.'
        $victoryResolutionSection = 166
        $victoryResolutionNote = 'Section 5 result: victory sends you to 166.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and @(7, 270) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -match 'Ganon|Dorier') {
        $enemyImmune = $true
        $playerMod += 2
        $playerModRounds = 1
        Write-LWInfo ("Book 2 section {0}: surprise grants +2 Combat Skill in round 1 and the brothers are immune to Mindblast." -f [int]$script:GameState.CurrentSection)
        $victoryResolutionSection = 33
        $victoryResolutionNote = ("Section {0} result: victory sends you to 33." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 17 -and [string]$enemyName -ieq 'Helghast') {
        $enemyUndead = $true
        $enemyImmune = $true
        Write-LWInfo 'Book 2 section 17: Helghast is undead and immune to Mindblast.'
        $victoryResolutionSection = 166
        $victoryResolutionNote = 'Section 17 result: victory sends you to 166.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 59 -and [string]$enemyName -ieq 'Helghast') {
        $enemyImmune = $true
        $enemyRequiresMagicalWeapon = $true
        $canEvade = $true
        $evadeResolutionSection = 311
        $evadeResolutionNote = 'Section 59 result: without a magical weapon you must evade and dive into the forest to 311.'
        Write-LWInfo 'Book 2 section 59: this Helghast is immune to Mindblast and can only be wounded by a magical weapon.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 66 -and [string]$enemyName -ieq 'Zombie Captain') {
        $enemyUndead = $true
        $enemyImmune = $true
        Write-LWInfo 'Book 2 section 66: Zombie Captain is undead and immune to Mindblast.'
        $victoryResolutionSection = 218
        $victoryResolutionNote = 'Section 66 result: victory sends you to 218.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 128 -and [string]$enemyName -ieq 'Zombie Crew') {
        $enemyUndead = $true
        Write-LWInfo 'Book 2 section 128: Zombie Crew is undead.'
        $victoryResolutionSection = 237
        $victoryResolutionNote = 'Section 128 result: victory sends you to 237.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 268 -and [string]$enemyName -ieq 'Harbour Thugs') {
        $canEvade = $true
        $evadeAvailableAfterRound = 2
        $evadeResolutionSection = 125
        $evadeResolutionNote = 'Section 268 result: after round 2 you may run through the side door to 125.'
        $victoryResolutionSection = 333
        $victoryResolutionNote = 'Section 268 result: victory sends you to 333.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 332 -and [string]$enemyName -ieq 'Helghast') {
        $enemyImmune = $true
        $enemyUsesMindforce = $true
        $canEvade = $true
        $evadeResolutionSection = 183
        $evadeResolutionNote = 'Section 332 result: evading sends you into the forest to 183.'
        $victoryResolutionSection = 92
        $victoryResolutionNote = 'Section 332 result: victory sends you to 92.'
        Write-LWInfo 'Book 2 section 332: Helghast is immune to Mindblast and its Mindforce costs 2 END per round unless Mindshield blocks it.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 83) {
        $enemyImmune = $true
        $enemyUsesMindforce = $true
        $mindforceLossPerRound = 2
        Write-LWInfo 'Book 3 section 83: the mutants are immune to Mindblast and their controller attacks with Mindforce for 2 END each round unless blocked by Mindshield.'
        $victoryResolutionSection = 313
        $victoryResolutionNote = 'Section 83 result: victory sends you to 313.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 88 -and [string]$enemyName -ieq 'Javek') {
        $enemyImmune = $true
        $useJavekPoisonRule = $true
        Write-LWInfo 'Book 3 section 88: Javek is immune to Mindblast and uses the special venom-survival rule instead of normal END loss.'
        $victoryResolutionSection = 269
        $victoryResolutionNote = 'Section 88 result: victory sends you to 269.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 106) {
        $enemyImmune = $true
        $canEvade = $true
        $evadeResolutionSection = 145
        $evadeResolutionNote = 'Section 106 result: evading sends you back to the chamber and north passage at 145.'
        Write-LWInfo 'Book 3 section 106: Ice Barbarians are immune to Mindblast.'
        $victoryResolutionSection = 338
        $victoryResolutionNote = 'Section 106 result: victory sends you to 338.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 137) {
        $mindblastCombatSkillBonus = 1
        Write-LWInfo 'Book 3 section 137: Mindblast only grants +1 Combat Skill in this fight.'
        $victoryResolutionSection = 28
        $victoryResolutionNote = 'Section 137 result: victory sends you to 28.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 138) {
        $canEvade = $true
        $evadeResolutionSection = 277
        $evadeResolutionNote = 'Section 138 result: you may evade by turning to 277.'
        $playerLossResolutionSection = 66
        $playerLossResolutionNote = 'Section 138 result: if you lose any ENDURANCE, turn immediately to 66.'
        $victoryWithoutLossSection = 25
        $victoryWithoutLossNote = 'Section 138 result: if you win without losing any ENDURANCE, turn to 25.'
        Write-LWInfo 'Book 3 section 138: the Kalkoths attack one at a time.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 147) {
        $canEvade = $false
        $playerLossResolutionSection = 66
        $playerLossResolutionNote = 'Section 147 result: if you lose any ENDURANCE, turn immediately to 66.'
        $victoryWithoutLossSection = 84
        $victoryWithoutLossNote = 'Section 147 result: if you win without losing any ENDURANCE, turn to 84.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 161 -and [string]$enemyName -ieq 'Ice Barbarian') {
        $enemyImmune = $true
        Write-LWInfo 'Book 3 section 161: Ice Barbarian is immune to Mindblast.'
        $victoryResolutionSection = 210
        $victoryResolutionNote = 'Section 161 result: victory sends you to 210.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 164) {
        $enemyUndead = $true
        $victoryWithinRoundsSection = 272
        $victoryWithinRoundsMax = 5
        $victoryWithinRoundsNote = 'Section 164 result: defeat the Akraa''Neonor in 5 rounds or less and turn to 272.'
        $ongoingFailureAfterRoundsSection = 324
        $ongoingFailureAfterRoundsThreshold = 5
        $ongoingFailureAfterRoundsNote = 'Section 164 result: if the combat takes longer than 5 rounds, turn to 324.'
        Write-LWInfo 'Book 3 section 164: Akraa''Neonor is undead and must be defeated in 5 rounds or less.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and @(170, 328) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Helghast') {
        $enemyUndead = $true
        $enemyImmune = $true
        Write-LWWarn ("Book 3 section {0}: no potions may be taken before this combat." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 263) {
        $canEvade = $true
        $evadeResolutionSection = 277
        $evadeResolutionNote = 'Section 263 result: you may evade at any time by turning to 277.'
        $playerLossResolutionSection = 66
        $playerLossResolutionNote = 'Section 263 result: if you lose any ENDURANCE, turn immediately to 66.'
        $victoryWithoutLossSection = 25
        $victoryWithoutLossNote = 'Section 263 result: if you win without losing any ENDURANCE, turn to 25.'
        Write-LWInfo 'Book 3 section 263: the Kalkoths attack one at a time.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 3 -and [int]$script:GameState.CurrentSection -eq 343) {
        if ([string]$enemyName -ieq 'Ice Barbarian') {
            $enemyImmune = $true
            Write-LWInfo 'Book 3 section 343: the final Ice Barbarian is immune to Mindblast.'
        }
        else {
            Write-LWInfo 'Book 3 section 343: fight these enemies one at a time in the listed order.'
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [string]$enemyName -match '^Barraka') {
        $enemyImmune = $true
        if ([int]$script:GameState.CurrentSection -eq 122) {
            Write-LWInfo 'Book 4 section 122: Barraka is immune to Mindblast.'
            if (-not (Test-LWDiscipline -Name 'Mindshield')) {
                $playerMod -= 4
                Write-LWWarn 'Book 4 section 122: Barraka''s mind attack applies -4 Combat Skill unless you possess Mindshield.'
            }
            else {
                Write-LWInfo 'Mindshield blocks Barraka''s Combat Skill penalty in section 122.'
            }
        }
        elseif ([int]$script:GameState.CurrentSection -eq 325) {
            Write-LWInfo 'Book 4 section 325: Barraka is immune to Mindblast.'
            $canEvade = $false
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 26 -and [string]$enemyName -ieq 'Stoneworm') {
        $enemyImmune = $true
        Write-LWInfo 'Book 4 section 26: Stoneworm is immune to Mindblast.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 62 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $playerMod -= 2
        $playerModRounds = 3
        $canEvade = $false
        Write-LWInfo 'Book 4 section 62: you fight from the ground at -2 Combat Skill for the first 3 rounds and cannot evade.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 65 -and [string]$enemyName -ieq 'Tunnel Fiends') {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 65: Tunnel Fiends combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 77 -and [string]$enemyName -ieq 'Vassagonian Captain') {
        $enemyImmune = $true
        $enemyUsesMindforce = $true
        $mindforceLossPerRound = 1
        $canEvade = $true
        $evadeAvailableAfterRound = 2
        Write-LWInfo 'Book 4 section 77: the captain is immune to Mindblast, attacks your mind for 1 END each round unless blocked by Mindshield, and can only be evaded after 2 rounds.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 88 -and [string]$enemyName -ieq 'Stoneworm') {
        $enemyImmune = $true
        $canEvade = $false
        Write-LWInfo 'Book 4 section 88: Stoneworm is immune to Mindblast and the combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 89 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 89: mounted combat here cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 147 -and [string]$enemyName -ieq 'Bridge Guard') {
        $ignoreFirstRoundEnduranceLoss = $true
        Write-LWInfo 'Book 4 section 147: surprise attack lets you ignore all Lone Wolf END loss in the first round.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 176 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 176: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and @(
            194,
            234
        ) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Giant Meresquid') {
        $oxygenRoll = Get-LWRandomDigit
        $oxygenRounds = if ($oxygenRoll -eq 0) { 10 } else { $oxygenRoll }
        if (Test-LWDiscipline -Name 'Mind Over Matter') {
            $oxygenRounds += 2
        }
        $specialPlayerLossAmount = 2
        $specialPlayerLossStartRound = $oxygenRounds + 1
        $specialPlayerLossReason = 'Lack of oxygen'
        Write-LWInfo ("Book 4 section {0}: underwater oxygen threshold roll {1} gives you {2} safe round{3} before lack-of-oxygen loss begins." -f [int]$script:GameState.CurrentSection, $oxygenRoll, $oxygenRounds, $(if ($oxygenRounds -eq 1) { '' } else { 's' }))
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 196 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 196: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 233) {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 233: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 308 -and [string]$enemyName -ieq 'Elix') {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 308: Elix combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 310 -and [string]$enemyName -ieq 'Vassagonian Warrior') {
        $canEvade = $false
        Write-LWInfo 'Book 4 section 310: this combat cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 316 -and [string]$enemyName -ieq 'Bandit Warrior') {
        $playerMod -= 2
        $canEvade = $true
        Write-LWInfo 'Book 4 section 316: bad footing applies -2 Combat Skill, but you may evade by diving into the River Xane.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 4 -and [int]$script:GameState.CurrentSection -eq 333 -and [string]$enemyName -ieq 'Vassagonian Horseman') {
        $oneRoundOnly = $true
        Write-LWInfo 'Book 4 section 333: this mounted pass lasts exactly one combat round before the horseman rushes past.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 4 -and [string]$enemyName -ieq 'Palace Gaoler') {
        $ignoreEnemyEnduranceLossRounds = 1
        $victoryWithinRoundsSection = 165
        $victoryWithinRoundsMax = 4
        $victoryWithinRoundsNote = 'Section 4 result: win within 4 rounds and turn to 165.'
        $victoryResolutionSection = 180
        $victoryResolutionNote = 'Section 4 result: if the fight lasts longer than 4 rounds, victory sends you to 180.'
        Write-LWInfo 'Book 5 section 4: enemy ENDURANCE loss is ignored in round 1.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 12 -and [string]$enemyName -ieq 'Bloodlug') {
        $enemyImmune = $true
        $playerMod -= 2
        $victoryResolutionSection = 95
        $victoryResolutionNote = 'Section 12 result: victory sends you to 95.'
        Write-LWInfo 'Book 5 section 12: Bloodlug is immune to Mindblast and you fight at -2 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 20 -and [string]$enemyName -ieq 'Horseman') {
        $canEvade = $true
        $restoreHalfEnduranceLossOnVictory = $true
        $restoreHalfEnduranceLossOnEvade = $true
        $victoryWithinRoundsSection = 125
        $victoryWithinRoundsMax = 3
        $victoryWithinRoundsNote = 'Section 20 result: win in 3 rounds or less and turn to 125.'
        $ongoingFailureAfterRoundsSection = 82
        $ongoingFailureAfterRoundsThreshold = 4
        $ongoingFailureAfterRoundsNote = 'Section 20 result: if the fight lasts longer than 3 rounds, stop and turn to 82.'
        $defeatResolutionSection = 161
        $defeatResolutionNote = 'Section 20 result: losing this fight sends you to 161, where half your lost ENDURANCE is restored.'
        Write-LWInfo 'Book 5 section 20: you may evade manually to 142 or surrender to 176, and half END lost is restored after the clash.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 57 -and [string]$enemyName -ieq 'Elix') {
        if (@($script:GameState.History | Where-Object { [string]$_.EnemyName -ieq 'Elix' }).Count -gt 0) {
            $playerMod += 2
            Write-LWInfo 'Book 5 section 57: prior Elix experience grants +2 Combat Skill.'
        }
        $canEvade = $false
        $victoryResolutionSection = 2
        $victoryResolutionNote = 'Section 57 result: victory sends you to 2.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and @(64, 110) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Kwaraz') {
        $mindblastCombatSkillBonus = 4
        Write-LWInfo ("Book 5 section {0}: Kwaraz is unusually susceptible to Mindblast, which grants +4 Combat Skill here." -f [int]$script:GameState.CurrentSection)
        if ([int]$script:GameState.CurrentSection -eq 64) {
            $victoryResolutionSection = 177
            $victoryResolutionNote = 'Section 64 result: victory sends you to 177.'
        }
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 91 -and [string]$enemyName -ieq 'Palace Gaoler') {
        $playerMod -= 4
        $victoryWithinRoundsSection = 65
        $victoryWithinRoundsMax = 4
        $victoryWithinRoundsNote = 'Section 91 result: win within 4 rounds and turn to 65.'
        $victoryResolutionSection = 180
        $victoryResolutionNote = 'Section 91 result: if the fight lasts longer than 4 rounds, victory sends you to 180.'
        Write-LWInfo 'Book 5 section 91: fighting unarmed applies -4 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 106 -and [string]$enemyName -ieq 'Courier') {
        $playerMod -= 2
        $playerModRounds = 3
        $canEvade = $false
        $victoryResolutionSection = 189
        $victoryResolutionNote = 'Section 106 result: victory sends you to 189.'
        Write-LWInfo 'Book 5 section 106: you fight at -2 Combat Skill for the first 3 rounds and cannot evade.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 119 -and [string]$enemyName -ieq 'Palace Gate Guardians') {
        $ignorePlayerEnduranceLossRounds = 3
        $victoryResolutionSection = 137
        $victoryResolutionNote = 'Section 119 result: victory sends you to 137.'
        Write-LWInfo 'Book 5 section 119: ignore Lone Wolf ENDURANCE loss in the first 3 rounds.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 123 -and [string]$enemyName -ieq 'Sharnazim Underlord') {
        $canEvade = $true
        $evadeResolutionSection = 51
        $evadeResolutionNote = 'Section 123 result: evading sends you through the trapdoor to 51.'
        $victoryResolutionSection = 198
        $victoryResolutionNote = 'Section 123 result: victory sends you to 198.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 135 -and [string]$enemyName -ieq 'Sharnazim Warrior') {
        $playerMod -= 2
        $defeatResolutionSection = 161
        $defeatResolutionNote = 'Section 135 result: losing this combat sends you to 161, where half your lost ENDURANCE is restored.'
        $victoryResolutionSection = 130
        $victoryResolutionNote = 'Section 135 result: victory sends you to 130 after half your lost ENDURANCE is restored.'
        $restoreHalfEnduranceLossOnVictory = $true
        Write-LWInfo 'Book 5 section 135: the noxious fumes apply -2 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 159 -and [string]$enemyName -ieq 'Armoury Guard') {
        $playerMod -= 2
        $playerModRounds = 3
        $canEvade = $false
        $victoryResolutionSection = 52
        $victoryResolutionNote = 'Section 159 result: victory sends you to 52.'
        Write-LWInfo 'Book 5 section 159: you fight from the floor at -2 Combat Skill for the first 3 rounds and cannot evade.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 168 -and [string]$enemyName -ieq 'Vestibule Guard') {
        $victoryWithinRoundsSection = 101
        $victoryWithinRoundsMax = 3
        $victoryWithinRoundsNote = 'Section 168 result: win in 3 rounds or less and turn to 101.'
        $victoryResolutionSection = 46
        $victoryResolutionNote = 'Section 168 result: if the fight lasts longer than 3 rounds, victory sends you to 46.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 178 -and [string]$enemyName -ieq 'Armoury Guard') {
        $canEvade = $false
        Write-LWInfo 'Book 5 section 178: this combat cannot be evaded. On victory, choose manually between searching the body (52) or entering the armoury (140).'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 190 -and [string]$enemyName -ieq 'Hammerfist the Armourer') {
        $playerMod -= 2
        $victoryResolutionSection = 111
        $victoryResolutionNote = 'Section 190 result: victory sends you to 111.'
        Write-LWInfo 'Book 5 section 190: the heat of the forge room applies -2 Combat Skill.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 194 -and [string]$enemyName -ieq 'Yas') {
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 3
            Write-LWWarn 'Book 5 section 194: the Yas hypnotizes you for -3 Combat Skill unless you possess Mindshield.'
        }
        $victoryResolutionSection = 35
        $victoryResolutionNote = 'Section 194 result: victory sends you to 35.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 223 -and [string]$enemyName -ieq 'Crypt Spawn') {
        $victoryResolutionSection = 353
        $victoryResolutionNote = 'Section 223 result: victory sends you to 353.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and @(240, 370) -contains [int]$script:GameState.CurrentSection -and [string]$enemyName -ieq 'Itikar') {
        $doubleEnemyEnduranceLoss = $true
        if ([int]$script:GameState.CurrentSection -eq 240) {
            $victoryResolutionSection = 217
            $victoryResolutionNote = 'Section 240 result: subduing the Itikar sends you to 217.'
        }
        else {
            $victoryResolutionSection = 267
            $victoryResolutionNote = 'Section 370 result: subduing the Itikar sends you to 267.'
        }
        Write-LWInfo ("Book 5 section {0}: double all ENDURANCE lost by the Itikar." -f [int]$script:GameState.CurrentSection)
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 299 -and [string]$enemyName -ieq 'Vordak') {
        $enemyImmune = $true
        $canEvade = $false
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 2
            Write-LWWarn 'Book 5 section 299: the Vordak''s Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        Write-LWInfo 'Book 5 section 299: the Vordak is immune to Mindblast.'
        $victoryResolutionSection = 203
        $victoryResolutionNote = 'Section 299 result: victory sends you to 203.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 316 -and [string]$enemyName -ieq 'Drakkar') {
        $playerMod -= 2
        $playerModRounds = 3
        $canEvade = $false
        $victoryResolutionSection = 333
        $victoryResolutionNote = 'Section 316 result: victory sends you to 333.'
        Write-LWInfo 'Book 5 section 316: surprise attack applies -2 Combat Skill for the first 3 rounds and the fight cannot be evaded.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 330 -and [string]$enemyName -ieq 'Drakkar') {
        $victoryWithinRoundsSection = 243
        $victoryWithinRoundsMax = 2
        $victoryWithinRoundsNote = 'Section 330 result: win in 2 rounds or less and turn to 243.'
        $ongoingFailureAfterRoundsSection = 394
        $ongoingFailureAfterRoundsThreshold = 3
        $ongoingFailureAfterRoundsNote = 'Section 330 result: if the combat lasts longer than 2 rounds, stop and turn to 394.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 353 -and [string]$enemyName -ieq 'Darklord Haakon') {
        if (Test-LWWeaponIsSommerswerd -Weapon $equippedWeapon) {
            $sommerswerdSuppressed = $true
            Write-LWWarn 'Book 5 section 353: underground, the Sommerswerd cannot discharge its power.'
        }
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 2
            Write-LWWarn 'Book 5 section 353: Haakon''s psychic assault applies -2 Combat Skill unless you possess Mindshield.'
        }
        $victoryResolutionSection = 400
        $victoryResolutionNote = 'Section 353 result: victory sends you to 400.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 355 -and [string]$enemyName -ieq 'Vordak') {
        $enemyImmune = $true
        if (-not (Test-LWDiscipline -Name 'Mindshield')) {
            $playerMod -= 2
            Write-LWWarn 'Book 5 section 355: the Vordak''s Mindforce applies -2 Combat Skill unless you possess Mindshield.'
        }
        Write-LWInfo 'Book 5 section 355: the Vordak is immune to Mindblast.'
        $victoryWithinRoundsSection = 249
        $victoryWithinRoundsMax = 4
        $victoryWithinRoundsNote = 'Section 355 result: win in 4 rounds or less and turn to 249.'
        $victoryResolutionSection = 304
        $victoryResolutionNote = 'Section 355 result: if the fight lasts longer than 4 rounds, victory sends you to 304.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 357 -and [string]$enemyName -ieq 'Platform Sentry') {
        $canEvade = $false
        $playerMod -= 2
        $fallOnRollValue = 1
        $fallOnRollResolutionSection = 293
        $fallOnRollResolutionNote = 'Section 357 result: a Random Number Table roll of 1 makes you lose your balance and fall to 293.'
        Write-LWInfo 'Book 5 section 357: unstable footing applies -2 Combat Skill and a roll of 1 makes you fall.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 361 -and [string]$enemyName -ieq 'Drakkar') {
        $victoryWithinRoundsSection = 288
        $victoryWithinRoundsMax = 3
        $victoryWithinRoundsNote = 'Section 361 result: win in 3 rounds or less and turn to 288.'
        $ongoingFailureAfterRoundsSection = 382
        $ongoingFailureAfterRoundsThreshold = 4
        $ongoingFailureAfterRoundsNote = 'Section 361 result: if the fight reaches round 4, stop and turn to 382.'
    }
    elseif ([int]$script:GameState.Character.BookNumber -eq 5 -and [int]$script:GameState.CurrentSection -eq 393 -and [string]$enemyName -ieq 'Drakkar') {
        $playerMod -= 2
        $playerModRounds = 1
        $canEvade = $true
        $evadeAvailableAfterRound = 3
        $evadeResolutionSection = 228
        $evadeResolutionNote = 'Section 393 result: you may evade after round 3 by turning to 228.'
        $victoryResolutionSection = 255
        $victoryResolutionNote = 'Section 393 result: victory sends you to 255.'
        Write-LWInfo 'Book 5 section 393: surprise attack applies -2 Combat Skill in round 1.'
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

    if (-not $useQuickDefaults) {
        if (Read-LWYesNo -Prompt 'Any manual Combat Skill modifiers for this fight?' -Default $false) {
            $playerMod += Read-LWInt -Prompt 'Manual player Combat Skill modifier for this combat' -Default 0
            $enemyMod += Read-LWInt -Prompt 'Manual enemy Combat Skill modifier for this combat' -Default 0
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
        EnemyRequiresMagicSpear   = $enemyRequiresMagicSpear
        EnemyRequiresMagicalWeapon = $enemyRequiresMagicalWeapon
        EnemyImmuneToMindblast    = $enemyImmune
        UseMindblast              = $useMindblast
        MindblastCombatSkillBonus = $mindblastCombatSkillBonus
        AletherCombatSkillBonus   = $aletherCombatSkillBonus
        AttemptKnockout           = $attemptKnockout
        CanEvade                  = $canEvade
        EvadeAvailableAfterRound  = $evadeAvailableAfterRound
        EvadeResolutionSection    = $evadeResolutionSection
        EvadeResolutionNote       = $evadeResolutionNote
        EquippedWeapon            = $equippedWeapon
        SommerswerdSuppressed     = $sommerswerdSuppressed
        IgnoreFirstRoundEnduranceLoss = $ignoreFirstRoundEnduranceLoss
        IgnorePlayerEnduranceLossRounds = $(if ($ignorePlayerEnduranceLossRounds -gt 0) { $ignorePlayerEnduranceLossRounds } elseif ($ignoreFirstRoundEnduranceLoss) { 1 } else { 0 })
        IgnoreEnemyEnduranceLossRounds = $ignoreEnemyEnduranceLossRounds
        DoubleEnemyEnduranceLoss  = $doubleEnemyEnduranceLoss
        OneRoundOnly              = $oneRoundOnly
        SpecialResolutionSection  = $null
        SpecialResolutionNote     = $null
        VictoryResolutionSection  = $victoryResolutionSection
        VictoryResolutionNote     = $victoryResolutionNote
        VictoryWithoutLossSection = $victoryWithoutLossSection
        VictoryWithoutLossNote    = $victoryWithoutLossNote
        VictoryWithinRoundsSection = $victoryWithinRoundsSection
        VictoryWithinRoundsMax    = $victoryWithinRoundsMax
        VictoryWithinRoundsNote   = $victoryWithinRoundsNote
        OngoingFailureAfterRoundsSection = $ongoingFailureAfterRoundsSection
        OngoingFailureAfterRoundsThreshold = $ongoingFailureAfterRoundsThreshold
        OngoingFailureAfterRoundsNote = $ongoingFailureAfterRoundsNote
        PlayerLossResolutionSection = $playerLossResolutionSection
        PlayerLossResolutionNote  = $playerLossResolutionNote
        DefeatResolutionSection   = $defeatResolutionSection
        DefeatResolutionNote      = $defeatResolutionNote
        JavekPoisonRule           = $useJavekPoisonRule
        FallOnRollValue           = $fallOnRollValue
        FallOnRollResolutionSection = $fallOnRollResolutionSection
        FallOnRollResolutionNote  = $fallOnRollResolutionNote
        RestoreHalfEnduranceLossOnVictory = $restoreHalfEnduranceLossOnVictory
        RestoreHalfEnduranceLossOnEvade = $restoreHalfEnduranceLossOnEvade
        MindforceLossPerRound     = $mindforceLossPerRound
        PlayerCombatSkillModifier = $playerMod
        PlayerCombatSkillModifierRounds = $playerModRounds
        PlayerCombatSkillModifierAfterRounds = $playerModAfterRounds
        PlayerCombatSkillModifierAfterRoundStart = $playerModAfterRoundStart
        EnemyCombatSkillModifier  = $enemyMod
        SpecialPlayerEnduranceLossAmount = $specialPlayerLossAmount
        SpecialPlayerEnduranceLossStartRound = $specialPlayerLossStartRound
        SpecialPlayerEnduranceLossReason = $specialPlayerLossReason
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

    $combatLossMeasure = @(@($script:GameState.Combat.Log) | Measure-Object -Property PlayerLoss -Sum)
    $combatTotalPlayerLoss = if ($combatLossMeasure.Count -gt 0) { $combatLossMeasure[0].Sum } else { $null }
    if ($null -eq $combatTotalPlayerLoss) {
        $combatTotalPlayerLoss = 0
    }
    $restoreHalfLoss = 0
    if (([string]$Outcome -eq 'Victory' -and (Test-LWPropertyExists -Object $script:GameState.Combat -Name 'RestoreHalfEnduranceLossOnVictory') -and [bool]$script:GameState.Combat.RestoreHalfEnduranceLossOnVictory) -or
        ([string]$Outcome -eq 'Evaded' -and (Test-LWPropertyExists -Object $script:GameState.Combat -Name 'RestoreHalfEnduranceLossOnEvade') -and [bool]$script:GameState.Combat.RestoreHalfEnduranceLossOnEvade) -or
        ([string]$Outcome -eq 'Special' -and $null -ne $script:GameState.Combat.SpecialResolutionSection -and [int]$script:GameState.Combat.SpecialResolutionSection -eq 161)) {
        $restoreHalfLoss = [math]::Floor(([int]$combatTotalPlayerLoss) / 2)
    }
    if ($restoreHalfLoss -gt 0) {
        $beforeRestore = [int]$script:GameState.Character.EnduranceCurrent
        $script:GameState.Character.EnduranceCurrent = [Math]::Min([int]$script:GameState.Character.EnduranceMax, ($beforeRestore + $restoreHalfLoss))
        $actualRestore = [int]$script:GameState.Character.EnduranceCurrent - $beforeRestore
        if ($actualRestore -gt 0) {
            Add-LWBookEnduranceDelta -Delta $actualRestore
            Register-LWManualRecoveryShortcut
            Write-LWInfo ("Special combat rule restores {0} ENDURANCE after the fight." -f $actualRestore)
        }
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
        MindforceLossPerRound = [int](Get-LWCombatMindforceLossPerRound -State $script:GameState)
        EnemyRequiresMagicSpear = [bool]$script:GameState.Combat.EnemyRequiresMagicSpear
        MindforceBlockedByMindshield = [bool](Test-LWCombatMindforceBlockedByMindshield -State $script:GameState)
        AletherCombatSkillBonus = [int]$script:GameState.Combat.AletherCombatSkillBonus
        AttemptKnockout   = [bool]$script:GameState.Combat.AttemptKnockout
        Weapon            = $script:GameState.Combat.EquippedWeapon
        SommerswerdSuppressed = [bool]$script:GameState.Combat.SommerswerdSuppressed
        Mindblast         = [bool]$script:GameState.Combat.UseMindblast
        CanEvade          = [bool]$script:GameState.Combat.CanEvade
        EvadeAvailableAfterRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $script:GameState.Combat.EvadeAvailableAfterRound) { [int]$script:GameState.Combat.EvadeAvailableAfterRound } else { 0 }
        Mode              = [string]$script:GameState.Settings.CombatMode
        PlayerCombatSkill = if ($null -ne $breakdown) { $breakdown.PlayerCombatSkill } else { $null }
        EnemyCombatSkill  = if ($null -ne $breakdown) { $breakdown.EnemyCombatSkill } else { $null }
        CombatRatio       = if ($null -ne $breakdown) { $breakdown.CombatRatio } else { $null }
        Notes             = if ($null -ne $breakdown) { @($breakdown.Notes) } else { @() }
        SpecialPlayerEnduranceLossAmount = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossAmount) { [int]$script:GameState.Combat.SpecialPlayerEnduranceLossAmount } else { 0 }
        SpecialPlayerEnduranceLossStartRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$script:GameState.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
        SpecialPlayerEnduranceLossReason = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossReason') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossReason) { [string]$script:GameState.Combat.SpecialPlayerEnduranceLossReason } else { $null }
        RestoredAfterCombat = $restoreHalfLoss
        SpecialResolutionSection = $script:GameState.Combat.SpecialResolutionSection
        SpecialResolutionNote = $script:GameState.Combat.SpecialResolutionNote
        Log               = @($script:GameState.Combat.Log)
    }

    if (@('Victory', 'Knockout') -contains [string]$Outcome -and [int]$script:GameState.Character.BookNumber -eq 2 -and [int]$script:GameState.CurrentSection -eq 106) {
        if (-not (Test-LWStateHasMagicSpear -State $script:GameState)) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Magic Spear') {
                Write-LWInfo 'The Magic Spear is kept as a Special Item.'
            }
            else {
                Write-LWWarn 'No room to keep the Magic Spear automatically. Make room and add it manually if you are keeping it.'
            }
        }
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
            Write-LWInfo ("Enter the normal Lone Wolf END loss from the CRT. Mindforce will add {0} END automatically." -f (Get-LWCombatMindforceLossPerRound -State $script:GameState))
        }
        if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossAmount') -and [int]$script:GameState.Combat.SpecialPlayerEnduranceLossAmount -gt 0) {
            $specialStartRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossStartRound') -and $null -ne $script:GameState.Combat.SpecialPlayerEnduranceLossStartRound) { [int]$script:GameState.Combat.SpecialPlayerEnduranceLossStartRound } else { 1 }
            $specialReason = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'SpecialPlayerEnduranceLossReason') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.SpecialPlayerEnduranceLossReason)) { [string]$script:GameState.Combat.SpecialPlayerEnduranceLossReason } else { 'special hazard' }
            Write-LWInfo ("Enter the normal Lone Wolf END loss from the CRT. {0} will add {1} END from round {2} onward." -f $specialReason, [int]$script:GameState.Combat.SpecialPlayerEnduranceLossAmount, $specialStartRound)
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
    if ($resolution.Outcome -eq 'Special') {
        $script:GameState.Combat.SpecialResolutionSection = $resolution.SpecialResolutionSection
        $script:GameState.Combat.SpecialResolutionNote = $resolution.SpecialResolutionNote
        [void](Stop-LWCombat -Outcome 'Special' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    if ([bool]$script:GameState.Combat.OneRoundOnly -and [int]$resolution.RoundNumber -eq 1) {
        $nextSection = 344
        $branchMessage = ''
        if ([int]$resolution.EnemyLoss -gt [int]$resolution.PlayerLoss) {
            $nextSection = 220
            $branchMessage = 'Section 333 result: the horseman loses more ENDURANCE than you. Turn to 220.'
        }
        elseif ([int]$resolution.PlayerLoss -gt [int]$resolution.EnemyLoss) {
            $nextSection = 209
            $branchMessage = 'Section 333 result: you lose more ENDURANCE than the horseman. Turn to 209.'
        }
        else {
            $nextSection = 344
            $branchMessage = 'Section 333 result: you both lose the same ENDURANCE. Turn to 344.'
        }

        $script:GameState.Combat.SpecialResolutionSection = $nextSection
        $script:GameState.Combat.SpecialResolutionNote = $branchMessage
        Write-LWInfo $branchMessage
        [void](Stop-LWCombat -Outcome 'Special' -SkipAutosave:$SkipAutosave)
        return $resolution
    }
    $combatLossMeasure = @(@($script:GameState.Combat.Log) | Measure-Object -Property PlayerLoss -Sum)
    $combatTotalPlayerLoss = if ($combatLossMeasure.Count -gt 0) { $combatLossMeasure[0].Sum } else { $null }
    if ($null -eq $combatTotalPlayerLoss) {
        $combatTotalPlayerLoss = 0
    }
    if ($resolution.Outcome -eq 'Continue' -and (Test-LWPropertyExists -Object $script:GameState.Combat -Name 'OngoingFailureAfterRoundsSection') -and $null -ne $script:GameState.Combat.OngoingFailureAfterRoundsSection) {
        $failureThreshold = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'OngoingFailureAfterRoundsThreshold') -and $null -ne $script:GameState.Combat.OngoingFailureAfterRoundsThreshold) { [int]$script:GameState.Combat.OngoingFailureAfterRoundsThreshold } else { 0 }
        if ($failureThreshold -gt 0 -and [int]$resolution.RoundNumber -ge $failureThreshold) {
            $script:GameState.Combat.SpecialResolutionSection = [int]$script:GameState.Combat.OngoingFailureAfterRoundsSection
            $script:GameState.Combat.SpecialResolutionNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'OngoingFailureAfterRoundsNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.OngoingFailureAfterRoundsNote)) { [string]$script:GameState.Combat.OngoingFailureAfterRoundsNote } else { ("Section result: after round {0}, turn to {1}." -f $failureThreshold, [int]$script:GameState.Combat.OngoingFailureAfterRoundsSection) }
            Write-LWInfo $script:GameState.Combat.SpecialResolutionNote
            [void](Stop-LWCombat -Outcome 'Special' -SkipAutosave:$SkipAutosave)
            return $resolution
        }
    }
    if ($resolution.Outcome -eq 'Victory') {
        $specialVictorySection = $null
        $specialVictoryNote = $null
        if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithoutLossSection') -and $null -ne $script:GameState.Combat.VictoryWithoutLossSection -and [int]$combatTotalPlayerLoss -eq 0) {
            $specialVictorySection = [int]$script:GameState.Combat.VictoryWithoutLossSection
            $specialVictoryNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithoutLossNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.VictoryWithoutLossNote)) { [string]$script:GameState.Combat.VictoryWithoutLossNote } else { ("Section result: perfect victory sends you to {0}." -f $specialVictorySection) }
        }
        elseif ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithinRoundsSection') -and $null -ne $script:GameState.Combat.VictoryWithinRoundsSection) {
            $victoryMaxRounds = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithinRoundsMax') -and $null -ne $script:GameState.Combat.VictoryWithinRoundsMax) { [int]$script:GameState.Combat.VictoryWithinRoundsMax } else { 0 }
            if ($victoryMaxRounds -le 0 -or [int]$resolution.RoundNumber -le $victoryMaxRounds) {
                $specialVictorySection = [int]$script:GameState.Combat.VictoryWithinRoundsSection
                $specialVictoryNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryWithinRoundsNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.VictoryWithinRoundsNote)) { [string]$script:GameState.Combat.VictoryWithinRoundsNote } else { ("Section result: victory sends you to {0}." -f $specialVictorySection) }
            }
        }
        elseif ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryResolutionSection') -and $null -ne $script:GameState.Combat.VictoryResolutionSection) {
            $specialVictorySection = [int]$script:GameState.Combat.VictoryResolutionSection
            $specialVictoryNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'VictoryResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.VictoryResolutionNote)) { [string]$script:GameState.Combat.VictoryResolutionNote } else { ("Section result: victory sends you to {0}." -f $specialVictorySection) }
        }
        if ($null -ne $specialVictorySection) {
            $script:GameState.Combat.SpecialResolutionSection = $specialVictorySection
            $script:GameState.Combat.SpecialResolutionNote = $specialVictoryNote
            Write-LWInfo $specialVictoryNote
        }
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
    if (-not (Test-LWCombatCanEvadeNow -State $script:GameState)) {
        $requiredRounds = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $script:GameState.Combat.EvadeAvailableAfterRound) { [int]$script:GameState.Combat.EvadeAvailableAfterRound } else { 0 }
        if ($requiredRounds -gt 0) {
            Write-LWWarn ("Evade is only available after round {0} in this combat." -f $requiredRounds)
            return
        }
    }

    if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeResolutionSection') -and $null -ne $script:GameState.Combat.EvadeResolutionSection) {
        $script:GameState.Combat.SpecialResolutionSection = [int]$script:GameState.Combat.EvadeResolutionSection
        $script:GameState.Combat.SpecialResolutionNote = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeResolutionNote') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.EvadeResolutionNote)) { [string]$script:GameState.Combat.EvadeResolutionNote } else { ("Evading sends you to {0}." -f [int]$script:GameState.Combat.EvadeResolutionSection) }
        Write-LWInfo $script:GameState.Combat.SpecialResolutionNote
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

    if ($currentBook -ge 5) {
        $script:GameState.Run.Status = 'Completed'
        $script:GameState.Run.CompletedOn = (Get-Date).ToString('o')
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
        Clear-LWDeathState
        Write-LWInfo 'Book 5 complete. The Kai ruleset campaign is now complete.'
        Invoke-LWMaybeAutosave
        return
    }

    $nextBook = $currentBook + 1
    $nextBookLabel = Format-LWBookLabel -BookNumber $nextBook -IncludePrefix
    $nextBookStartSection = 1
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
            $newDiscName = $null
            $newDiscSelection = @(Select-LWKaiDisciplines -Count 1 -Exclude $owned)
            if ($newDiscSelection.Count -gt 0) {
                $newDiscName = [string]$newDiscSelection[0]
                $script:GameState.Character.Disciplines = @($owned + $newDiscName)
                Write-LWInfo "Added discipline: $newDiscName."
            }

            if ($newDiscName -eq 'Weaponskill' -and [string]::IsNullOrWhiteSpace($script:GameState.Character.WeaponskillWeapon)) {
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

    if ($currentBook -eq 4 -and -not (Test-LWStateHasBackpack -State $script:GameState)) {
        Restore-LWBackpackState -WriteMessages
        Write-LWInfo 'Book 4 completed without a Backpack recovery. An empty Backpack is restored for the next book.'
    }

    if ($nextBook -eq 2) {
        Apply-LWBookTwoStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 3) {
        Apply-LWBookThreeStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 4) {
        Apply-LWBookFourStartingEquipment -CarryExistingGear
    }
    elseif ($nextBook -eq 5) {
        Apply-LWBookFiveStartingEquipment -CarryExistingGear
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
    if ($bookNumber -eq 1) {
        Apply-LWBookOneStartingEquipment
    }
    elseif ($bookNumber -eq 2) {
        Apply-LWBookTwoStartingEquipment
    }
    elseif ($bookNumber -eq 3) {
        Apply-LWBookThreeStartingEquipment
    }
    elseif ($bookNumber -eq 4) {
        Apply-LWBookFourStartingEquipment
    }
    elseif ($bookNumber -eq 5) {
        Apply-LWBookFiveStartingEquipment
    }
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Clear-LWDeathState
    Reset-LWCurrentBookStats -BookNumber $bookNumber -StartSection $startSection
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Sync-LWRunIntegrityState -State $script:GameState -Reseal

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
    Sync-LWRunIntegrityState -State $script:GameState -Reseal

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
    Write-LWBulletItem -Text 'Use discipline add to open the Kai discipline picker, or discipline add Mindblast to grant one directly.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Use end -1 for section damage and end +1 for simple recovery without touching max END.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Shield and Silver Helm each add +2 Combat Skill automatically; Chainmail Waistcoat adds +4 END, Padded Leather Waistcoat adds +2 END, and Helmet adds +2 END unless Silver Helm is also carried.' -TextColor 'Gray'
    Write-LWBulletItem -Text 'Bone Sword is treated as a weapon and adds +1 Combat Skill in Book 3 / Kalte only; Broadsword +1 adds +1 Combat Skill and still counts as a Broadsword; Drodarin War Hammer adds +1 Combat Skill and counts as a Warhammer; Captain D''Val''s Sword adds +1 Combat Skill and counts as a Sword.' -TextColor 'Gray'
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
            $terminalType = if ($null -ne (Get-LWActiveDeathState)) { [string](Get-LWActiveDeathState).Type } else { '' }
            if ([string]$terminalType -ieq 'Failure') {
                Write-LWWarn 'The mission has failed. Use rewind, load, newrun, modes, campaign, help, or quit.'
            }
            else {
                Write-LWWarn 'You have fallen. Use rewind, load, newrun, modes, campaign, help, or quit.'
            }
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
        'roll'        {
            Write-LWCurrentSectionRandomNumberRoll -Roll (Get-LWRandomDigit)
            return $null
        }
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
        'recover'     { Restore-LWInventoryInteractive -InputParts $parts; return $null }
        'gold'        { Update-LWGoldInteractive -InputParts $parts; return $null }
        'meal'        { Use-LWMeal; return $null }
        'potion'      { Use-LWHealingPotion; return $null }
        'die'         { Invoke-LWInstantDeath -Cause $argumentText; return $null }
        'fail'        { Invoke-LWFailure -Cause $argumentText; return $null }
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
        $line = ''
        try {
            Refresh-LWScreen
            $line = Read-Host 'lw'
            $result = Invoke-LWCommand -InputLine $line
            if ($result -eq 'quit') {
                break
            }
        }
        catch {
            $logPath = Write-LWCrashLog -ErrorRecord $_ -InputLine $line -Stage 'main-loop'
            Write-LWError ("The assistant hit an unexpected error and wrote details to {0}. You can keep playing after this screen refresh." -f $logPath)
        }
    }

    $script:LWUi.Enabled = $false
    Write-LWInfo 'Good luck on the Kai trail.'
}

function Get-LWModuleContext {
    return @{
        LWRootDir                    = $script:LWRootDir
        SaveDir                      = $SaveDir
        DataDir                      = $DataDir
        LWAppName                    = $script:LWAppName
        LWAppVersion                 = $script:LWAppVersion
        LWStateVersion               = $script:LWStateVersion
        LastUsedSavePathFile         = $script:LastUsedSavePathFile
        LWErrorLogFile               = $script:LWErrorLogFile
        GameState                    = $script:GameState
        GameData                     = $script:GameData
        LWAchievementDefinitionsCache = $script:LWAchievementDefinitionsCache
        LWUi                         = $script:LWUi
    }
}

function Sync-LWStateRefactorMetadata {
    param([object]$State)

    if ($null -eq $State) {
        return $null
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'RuleSet') -or [string]::IsNullOrWhiteSpace([string]$State.RuleSet)) {
        $State | Add-Member -Force -NotePropertyName RuleSet -NotePropertyValue 'Kai'
    }

    $rulesetVersion = Get-LWActiveRuleSetVersion -State $State
    if (-not (Test-LWPropertyExists -Object $State -Name 'EngineVersion')) {
        $State | Add-Member -Force -NotePropertyName EngineVersion -NotePropertyValue $script:LWAppVersion
    }
    else {
        $State.EngineVersion = $script:LWAppVersion
    }

    if (-not (Test-LWPropertyExists -Object $State -Name 'RuleSetVersion')) {
        $State | Add-Member -Force -NotePropertyName RuleSetVersion -NotePropertyValue $rulesetVersion
    }
    else {
        $State.RuleSetVersion = $rulesetVersion
    }

    return $State
}

function Initialize-LWData {
    $script:GameData = Invoke-LWCoreInitializeData -Context (Get-LWModuleContext)
}

function New-LWDefaultState {
    $state = Invoke-LWCoreNewDefaultState -Context (Get-LWModuleContext)
    return (Sync-LWStateRefactorMetadata -State $state)
}

function Normalize-LWState {
    param([Parameter(Mandatory = $true)][object]$State)

    $normalized = Invoke-LWCoreNormalizeState -Context (Get-LWModuleContext) -State $State
    return (Sync-LWStateRefactorMetadata -State $normalized)
}

function Save-LWGame {
    param([switch]$PromptForPath)

    if ($null -ne $script:GameState) {
        [void](Sync-LWStateRefactorMetadata -State $script:GameState)
    }

    Invoke-LWCoreSaveGame -Context (Get-LWModuleContext) -PromptForPath:$PromptForPath
}

function Load-LWGame {
    param([Parameter(Mandatory = $true)][string]$Path)

    $loadedState = Invoke-LWCoreLoadGame -Context (Get-LWModuleContext) -Path $Path
    if ($null -ne $loadedState) {
        $script:GameState = Sync-LWStateRefactorMetadata -State $loadedState
    }
}

function Load-LWGameInteractive {
    param([string]$Selection)

    Invoke-LWCoreLoadGameInteractive -Context (Get-LWModuleContext) -Selection $Selection | Out-Null
}

function Show-LWHelp {
    Invoke-LWCoreShowHelpScreen -Context (Get-LWModuleContext)
}

function Invoke-LWCommand {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$InputLine)

    return (Invoke-LWCoreCommand -Context (Get-LWModuleContext) -InputLine $InputLine)
}

function Start-LWCombat {
    param([string[]]$Arguments = @())

    return (Invoke-LWCoreStartCombat -Context (Get-LWModuleContext) -Arguments $Arguments)
}

function Register-LWStorySectionAchievementTriggers {
    param([Parameter(Mandatory = $true)][int]$Section)

    if (-not (Test-LWHasState)) {
        return
    }

    Invoke-LWRuleSetStorySectionAchievementTriggers -State $script:GameState -Section $Section
}

function Register-LWStorySectionTransitionAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][int]$FromSection,
        [Parameter(Mandatory = $true)][int]$ToSection
    )

    if (-not (Test-LWHasState)) {
        return
    }

    Invoke-LWRuleSetStorySectionTransitionAchievementTriggers -State $script:GameState -FromSection $FromSection -ToSection $ToSection
}

function Get-LWSectionRandomNumberContext {
    param([object]$State = $script:GameState)

    return (Get-LWRuleSetSectionRandomNumberContext -State $State)
}

function Invoke-LWSectionEntryRules {
    if (-not (Test-LWHasState)) {
        return
    }

    Invoke-LWRuleSetSectionEntryRules -State $script:GameState
}

function Apply-LWBookOneStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 1 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookTwoStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 2 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookThreeStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 3 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookFourStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 4 -CarryExistingGear:$CarryExistingGear
}

function Apply-LWBookFiveStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 5 -CarryExistingGear:$CarryExistingGear
}

function Publish-LWScriptFunctionsToSession {
    $scriptPath = if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
        $PSCommandPath
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $MyInvocation.MyCommand.Path
    }
    else {
        $null
    }

    $functions = @(Get-Command -CommandType Function | Where-Object {
            $_.Name -like '*-LW*' -and
            $null -ne $_.ScriptBlock -and
            (
                [string]::IsNullOrWhiteSpace($scriptPath) -or
                [string]$_.ScriptBlock.File -eq $scriptPath
            )
        })

    foreach ($functionInfo in $functions) {
        Set-Item -Path ("Function:\global:{0}" -f $functionInfo.Name) -Value $functionInfo.ScriptBlock -Force
    }
}

if (Test-LWShouldAutoStart -InvocationName $MyInvocation.InvocationName) {
    Publish-LWScriptFunctionsToSession
    Initialize-LWData
    Start-LWTerminal
}
