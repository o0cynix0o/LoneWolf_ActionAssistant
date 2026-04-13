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
$script:LWShellModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\shell.psm1'
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
$script:LWKaiCombatModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\combat.psm1'
$script:LWKaiRulesetModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\kai\kai.psm1'
$script:LWMagnakaiBook6ModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\book6.psm1'
$script:LWMagnakaiCombatModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\combat.psm1'
$script:LWMagnakaiRulesetModulePath = Join-Path $script:LWBootstrapRoot 'modules\rulesets\magnakai\magnakai.psm1'
foreach ($modulePath in @(
        $script:LWShellModulePath,
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
        $script:LWKaiCombatModulePath,
        $script:LWKaiRulesetModulePath,
        $script:LWMagnakaiBook6ModulePath,
        $script:LWMagnakaiCombatModulePath,
        $script:LWMagnakaiRulesetModulePath,
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
$script:LWAchievementContextDefinitionsCache = @{}
$script:LWAchievementDisplayCountsCache = $null
$script:LWUi = $script:LWBootstrap.UiState

function Write-LWInfo {
    param([string]$Message)
    Invoke-LWCoreWriteInfo -Context (Get-LWModuleContext) -Message $Message
}

function Write-LWWarn {
    param([string]$Message)
    Invoke-LWCoreWriteWarn -Context (Get-LWModuleContext) -Message $Message
}

function Write-LWError {
    param([string]$Message)
    Invoke-LWCoreWriteError -Context (Get-LWModuleContext) -Message $Message
}

function Write-LWMessageLine {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Invoke-LWCoreWriteMessageLine -Level $Level -Message $Message
}

function Add-LWNotification {
    param(
        [Parameter(Mandatory = $true)][string]$Level,
        [Parameter(Mandatory = $true)][string]$Message
    )

    Invoke-LWCoreAddNotification -Context (Get-LWModuleContext) -Level $Level -Message $Message
}

function Write-LWCrashLog {
    param(
        [Parameter(Mandatory = $true)][System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$InputLine = '',
        [string]$Stage = 'command'
    )

    return (Invoke-LWCoreWriteCrashLog -Context (Get-LWModuleContext) -ErrorRecord $ErrorRecord -InputLine $InputLine -Stage $Stage)
}

function Clear-LWNotifications {
    Invoke-LWCoreClearNotifications -Context (Get-LWModuleContext)
}

function Clear-LWAchievementDisplayCountsCache {
    Invoke-LWCoreClearAchievementDisplayCountsCache -Context (Get-LWModuleContext)
}

function Warm-LWRuntimeCaches {
    Invoke-LWCoreWarmRuntimeCaches -Context (Get-LWModuleContext)
}

function Request-LWRender {
    Invoke-LWCoreRequestRender -Context (Get-LWModuleContext)
}

function Clear-LWScreenHost {
    Invoke-LWCoreClearScreenHost
}

function Get-LWDefaultScreen {
    return (Invoke-LWCoreGetDefaultScreen -Context (Get-LWModuleContext))
}

function Set-LWScreen {
    param(
        [string]$Name = '',
        $Data = $null
    )

    Invoke-LWCoreSetScreen -Context (Get-LWModuleContext) -Name $Name -Data $Data
}

function Write-LWNotifications {
    Invoke-LWCoreWriteNotifications -Context (Get-LWModuleContext)
}

function Write-LWBannerFooter {
    param(
        [string]$ProductName = $script:LWAppName,
        [switch]$VersionOnly,
        [switch]$ShowHelpLine
    )

    Invoke-LWCoreWriteBannerFooter -Context (Get-LWModuleContext) -ProductName $ProductName -VersionOnly:$VersionOnly -ShowHelpLine:$ShowHelpLine
}

function Write-LWInventoryBanner {
    Write-LWBanner
}

function Write-LWCombatBanner {
    Write-LWBanner
}

function Write-LWStatsBanner {
    Write-LWBanner
}

function Write-LWCampaignBanner {
    Write-LWBanner
}

function Write-LWAchievementsBanner {
    Write-LWBanner
}

function Write-LWDeathBanner {
    Write-LWBanner
}

function Show-LWWelcomeScreen {
    param([switch]$NoBanner)

    Invoke-LWCoreShowWelcomeScreen -Context (Get-LWModuleContext) -NoBanner:$NoBanner
}

function Show-LWLoadScreen {
    param([object[]]$SaveFiles = @())

    Invoke-LWCoreShowLoadScreen -Context (Get-LWModuleContext) -SaveFiles $SaveFiles
}

function Show-LWDisciplineSelectionScreen {
    Invoke-LWCoreShowDisciplineSelectionScreen -Context (Get-LWModuleContext)
}

function Show-LWCombatScreen {
    Invoke-LWCoreShowCombatScreen -Context (Get-LWModuleContext)
}

function Show-LWCombatLogScreen {
    Invoke-LWCoreShowCombatLogScreen -Context (Get-LWModuleContext)
}

function Show-LWModesScreen {
    Invoke-LWCoreShowModesScreen -Context (Get-LWModuleContext)
}

function Show-LWDeathScreen {
    Invoke-LWCoreShowDeathScreen -Context (Get-LWModuleContext)
}

function Show-LWBookCompleteScreen {
    Invoke-LWCoreShowBookCompleteScreen -Context (Get-LWModuleContext)
}

function Refresh-LWScreen {
    Invoke-LWCoreRefreshScreen -Context (Get-LWModuleContext)
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

function Get-LWMagnakaiRankTitle {
    param([int]$Level)

    if ($Level -le 0) {
        return $null
    }

    $rankDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiRanks') -and $null -ne $script:GameData.MagnakaiRanks) {
        @($script:GameData.MagnakaiRanks)
    }
    else {
        @()
    }
    $rankEntry = @($rankDefinitions | Where-Object { [int]$_.Level -eq $Level } | Select-Object -First 1)
    if ($rankEntry.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$rankEntry[0].Name)) {
        return [string]$rankEntry[0].Name
    }

    switch ($Level) {
        1 { return 'Kai Master' }
        2 { return 'Kai Master Senior' }
        3 { return 'Kai Master Superior' }
        4 { return 'Primate' }
        5 { return 'Tutelary' }
        6 { return 'Principalin' }
        7 { return 'Mentora' }
        8 { return 'Scion-kai' }
        9 { return 'Archmaster' }
        default { return 'Kai Grand Master' }
    }
}

function Format-LWMagnakaiRankLabel {
    param([int]$Level)

    $rankTitle = Get-LWMagnakaiRankTitle -Level $Level
    if ([string]::IsNullOrWhiteSpace($rankTitle)) {
        return '(unranked)'
    }

    return "{0} - {1}" -f $Level, $rankTitle
}

function Get-LWKnownKaiDisciplineNames {
    if ($null -ne $script:GameData -and $null -ne $script:GameData.KaiDisciplines -and @($script:GameData.KaiDisciplines).Count -gt 0) {
        return @($script:GameData.KaiDisciplines | ForEach-Object { [string]$_.Name })
    }

    return @('Camouflage', 'Hunting', 'Sixth Sense', 'Tracking', 'Healing', 'Weaponskill', 'Mindblast', 'Mindshield', 'Animal Kinship', 'Mind Over Matter')
}

function Get-LWKnownMagnakaiDisciplineNames {
    if ($null -ne $script:GameData -and $null -ne $script:GameData.MagnakaiDisciplines -and @($script:GameData.MagnakaiDisciplines).Count -gt 0) {
        return @($script:GameData.MagnakaiDisciplines | ForEach-Object { [string]$_.Name })
    }

    return @('Weaponmastery', 'Animal Control', 'Curing', 'Invisibility', 'Huntmastery', 'Pathsmanship', 'Psi-surge', 'Psi-screen', 'Nexus', 'Divination')
}

function Test-LWStateIsMagnakaiRuleset {
    param([Parameter(Mandatory = $true)][object]$State)

    return ([string]$State.RuleSet -ieq 'Magnakai')
}

function Get-LWCurrentRankLabel {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWStateIsMagnakaiRuleset -State $State) {
        $level = if ((Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiRank') -and $null -ne $State.Character.MagnakaiRank -and [int]$State.Character.MagnakaiRank -gt 0) {
            [int]$State.Character.MagnakaiRank
        }
        else {
            [Math]::Max(1, @($State.Character.MagnakaiDisciplines).Count)
        }

        return (Format-LWMagnakaiRankLabel -Level $level)
    }

    return (Format-LWKaiRankLabel -DisciplineCount @($State.Character.Disciplines).Count)
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
        Book1Section61NoteAdded     = $false
        Book1Section255SolnarisClaimed = $false
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
        Book5Section278DamageApplied = $false
        Book5Section385ExplosionApplied = $false
        Book5BanishmentRoute        = $false
        Book5HaakonDuelRoute        = $false
        Book5BookOfMagnakaiClaimed  = $false
        Book6Section004LossApplied  = $false
        Book6Section035MealsRuined  = $false
        Book6Section040GoldClaimed  = $false
        Book6Section040WineClaimed  = $false
        Book6Section040MirrorClaimed = $false
        Book6Section048GoldClaimed  = $false
        Book6Section048MapClaimed   = $false
        Book6Section049CessUsed     = $false
        Book6Section065TaunorWaterResolved = $false
        Book6Section106TaunorWaterResolved = $false
        Book6Section109MapClaimed   = $false
        Book6Section112TaunorWaterResolved = $false
        Book6Section158SilverKeyClaimed = $false
        Book6Section158QuarterstaffClaimed = $false
        Book6Section158MealsClaimed = $false
        Book6Section158MaceClaimed  = $false
        Book6Section158WhistleClaimed = $false
        Book6Section158RopeClaimed  = $false
        Book6Section158ShortSwordClaimed = $false
        Book6Section190TaunorWaterResolved = $false
        Book6Section207Handled   = $false
        Book6Section232RoomPaid     = $false
        Book6Section232MealDeducted = $false
        Book6Section246TaunorWaterResolved = $false
        Book6Section252SilverBowClaimed = $false
        Book6Section278DamageApplied = $false
        Book6Section282DamageApplied = $false
        Book6Section293SilverKeyUsed = $false
        Book6Section304CessClaimed  = $false
        Book6Section306ColdDamageApplied = $false
        Book6Section306NexusProtected = $false
        Book6Section307Handled      = $false
        Book6Section307NoMealLossApplied = $false
        Book6Section310DamageApplied = $false
        Book6Section313DamageApplied = $false
        Book6Section315MindforceApplied = $false
        Book6Section315MindforceLossApplied = $false
        Book6Section315MindforceBlocked = $false
        Book6Section322TollPaid     = $false
        Book6Section348WarhammerLost = $false
        Book6JumpTheWagonsRoute     = $false
        Book6TaunorWaterStored      = $false
        Book6MapOfTekaroClaimed     = $false
        Book6SmallSilverKeyClaimed  = $false
        Book6SilverBowClaimed       = $false
        Book6CessClaimed            = $false
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
        (New-LWAchievementDefinition -Id 'book_six_complete' -Name 'Book Six Complete' -Category 'Journey' -Description 'Complete Book 6.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'magnakai_rising' -Name 'Magnakai Rising' -Category 'Legend' -Description 'Carry a single character through the full Books 1-6 sequence.' -Backfill:$true -ModePool 'Universal'),
        (New-LWAchievementDefinition -Id 'apothecarys_answer' -Name 'Apothecary''s Answer' -Category 'Journey' -Description 'Claim the Oede Herb and cure Limbdeath in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'prison_break' -Name 'Prison Break' -Category 'Journey' -Description 'Recover your confiscated gear in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'talons_tamed' -Name 'Talons Tamed' -Category 'Journey' -Description 'Mount the Itikar without having to subdue it in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'star_guided' -Name 'Star-Guided' -Category 'Journey' -Description 'Use the Crystal Star Pendant route in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'name_the_lost' -Name 'Name the Lost' -Category 'Journey' -Description 'Learn Soushilla''s name and ask for her in Book 5.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'shadow_on_the_sand' -Name 'Shadow on the Sand' -Category 'Journey' -Description 'Finish Book 5 through the glowing-stone endgame route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'face_to_face_with_haakon' -Name 'Face to Face with Haakon' -Category 'Journey' -Description 'Finish Book 5 through the Haakon duel route.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'jump_the_wagons' -Name 'Jump the Wagons' -Category 'Journey' -Description 'Clear the wagon jump route in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'water_bearer' -Name 'Water Bearer' -Category 'Journey' -Description 'Keep Taunor Water stored for later use in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'tekaro_cartographer' -Name 'Tekaro Cartographer' -Category 'Journey' -Description 'Claim a Map of Tekaro in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'key_to_varetta' -Name 'Key to Varetta' -Category 'Journey' -Description 'Claim the Small Silver Key in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'silver_oak_prize' -Name 'Silver Oak Prize' -Category 'Journey' -Description 'Win the Silver Bow of Duadon in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cess_to_enter' -Name 'Cess to Enter' -Category 'Journey' -Description 'Pocket a valid Cess for Amory in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'cold_comfort' -Name 'Cold Comfort' -Category 'Journey' -Description 'Let Nexus save you from the frozen river in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true),
        (New-LWAchievementDefinition -Id 'mind_over_malice_book6' -Name 'Mind Over Malice' -Category 'Journey' -Description 'Have Psi-screen block the cursed Mindforce assault in Book 6.' -Backfill:$true -ModePool 'Exploration' -Hidden:$true)
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

    foreach ($propertyName in @('Book1AimForTheBushesVisited', 'Book1ClubhouseFound', 'Book1SilverKeyClaimed', 'Book1UseTheForcePath', 'Book1StraightToTheThrone', 'Book1RoyalRecovery', 'Book1BackWayIn', 'Book1OpenSesameRoute', 'Book1HotHandsClaimed', 'Book1StarOfToranClaimed', 'Book1FieldMedicPath', 'Book1LaumspurClaimed', 'Book1VordakGem76Claimed', 'Book1VordakGem304Claimed', 'Book1VordakGemCurseTriggered', 'Book1Section61NoteAdded', 'Book1Section255SolnarisClaimed', 'Book2CoachTicketClaimed', 'Book2WhitePassClaimed', 'Book2RedPassClaimed', 'Book2PotentPotionClaimed', 'Book2MealOfLaumspurClaimed', 'Book2ForgedPapersBought', 'Book2Section106DamageApplied', 'Book2Section313Resolved', 'Book2Section337StormLossApplied', 'Book2SommerswerdClaimed', 'Book2ByAThreadRoute', 'Book2SkyfallRoute', 'Book2FightThroughTheSmokeRoute', 'Book2StormTossedSeen', 'Book2SealOfApprovalRoute', 'Book2PapersPleasePath', 'Book3SnakePitVisited', 'Book3CliffhangerSeen', 'Book3DiamondClaimed', 'Book3SnowblindSeen', 'Book3GrossKeyClaimed', 'Book3LuckyButtonTheorySeen', 'Book3WellItWorkedOnceSeen', 'Book3FirstCellAbandoned', 'Book3CellfishPathTaken', 'Book3LoiKymarRescued', 'Book3EffigyEndgameReached', 'Book3SommerswerdEndgameUsed', 'Book3LuckyEndgameUsed', 'Book3TooSlowFailureSeen', 'Book4Section12ResupplyHandled', 'Book4Section12MealsClaimed', 'Book4Section12RopeClaimed', 'Book4Section12PotionClaimed', 'Book4Section12SwordClaimed', 'Book4Section12SpearClaimed', 'Book4Section79SuppliesClaimed', 'Book4Section94LossApplied', 'Book4BadgeOfOfficePath', 'Book4OnyxMedallionClaimed', 'Book4Section117LightPath', 'Book4Section122MindAttackApplied', 'Book4Section123SuppliesClaimed', 'Book4Section158LossApplied', 'Book4Section167RecoveryClaimed', 'Book4BackpackLost', 'Book4BackpackRecovered', 'Book4WashedAway', 'Book4Section280GoldClaimed', 'Book4Section280MealClaimed', 'Book4Section280SwordClaimed', 'Book4CaptainSwordClaimed', 'Book4PotionOfRedLiquidClaimed', 'Book4ShovelReadyClaimed', 'Book4ScrollClaimed', 'Book4TorchesWillNotLight', 'Book4LightInTheDepths', 'Book4Section272LossApplied', 'Book4SteelAgainstShadowRoute', 'Book4BlessedBeTheThrowRoute', 'Book4ScrollRoute', 'Book4Section283HolyWaterApplied', 'Book4SunBelowTheEarthRoute', 'Book4OnyxBluffRoute', 'Book4Section322RestApplied', 'Book4ReturnToSenderPath', 'Book4ChasmOfDoomSeen', 'Book4DaggerOfVashnaClaimed', 'Book5Section278DamageApplied', 'Book5Section385ExplosionApplied', 'Book6Section004LossApplied', 'Book6Section035MealsRuined', 'Book6Section040GoldClaimed', 'Book6Section040WineClaimed', 'Book6Section040MirrorClaimed', 'Book6Section048GoldClaimed', 'Book6Section048MapClaimed', 'Book6Section049CessUsed', 'Book6Section065TaunorWaterResolved', 'Book6Section106TaunorWaterResolved', 'Book6Section109MapClaimed', 'Book6Section112TaunorWaterResolved', 'Book6Section158SilverKeyClaimed', 'Book6Section158QuarterstaffClaimed', 'Book6Section158MealsClaimed', 'Book6Section158MaceClaimed', 'Book6Section158WhistleClaimed', 'Book6Section158RopeClaimed', 'Book6Section158ShortSwordClaimed', 'Book6Section190TaunorWaterResolved', 'Book6Section207Handled', 'Book6Section232RoomPaid', 'Book6Section232MealDeducted', 'Book6Section246TaunorWaterResolved', 'Book6Section252SilverBowClaimed', 'Book6Section278DamageApplied', 'Book6Section282DamageApplied', 'Book6Section293SilverKeyUsed', 'Book6Section304CessClaimed', 'Book6Section306ColdDamageApplied', 'Book6Section306NexusProtected', 'Book6Section307Handled', 'Book6Section307NoMealLossApplied', 'Book6Section310DamageApplied', 'Book6Section313DamageApplied', 'Book6Section315MindforceApplied', 'Book6Section315MindforceLossApplied', 'Book6Section315MindforceBlocked', 'Book6Section322TollPaid', 'Book6Section348WarhammerLost', 'Book6JumpTheWagonsRoute', 'Book6TaunorWaterStored', 'Book6MapOfTekaroClaimed', 'Book6SmallSilverKeyClaimed', 'Book6SilverBowClaimed', 'Book6CessClaimed')) {
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

    if ([int]$script:GameState.Character.BookNumber -ge 6) {
        if ($visitedSections -contains 49) {
            if (-not (Test-LWStoryAchievementFlag -Name 'Book6Section049CessUsed')) {
                Set-LWStoryAchievementFlag -Name 'Book6Section049CessUsed'
            }

            [void](Remove-LWStateInventoryItemByNames -State $script:GameState -Names (Get-LWCessItemNames) -Types @('special'))
        }
        if ($visitedSections -contains 4) { Set-LWStoryAchievementFlag -Name 'Book6Section004LossApplied' }
        if ($visitedSections -contains 35) { Set-LWStoryAchievementFlag -Name 'Book6Section035MealsRuined' }
        if ($visitedSections -contains 65) { Set-LWStoryAchievementFlag -Name 'Book6Section065TaunorWaterResolved' }
        if ($visitedSections -contains 106) { Set-LWStoryAchievementFlag -Name 'Book6Section106TaunorWaterResolved' }
        if ($visitedSections -contains 112) { Set-LWStoryAchievementFlag -Name 'Book6Section112TaunorWaterResolved' }
        if ($visitedSections -contains 158) {
            Set-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed'
            Set-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed'
        }
        if ($visitedSections -contains 190) { Set-LWStoryAchievementFlag -Name 'Book6Section190TaunorWaterResolved' }
        if ($visitedSections -contains 232) { Set-LWStoryAchievementFlag -Name 'Book6Section232RoomPaid' }
        if ($visitedSections -contains 246) { Set-LWStoryAchievementFlag -Name 'Book6Section246TaunorWaterResolved' }
        if ($visitedSections -contains 252) {
            Set-LWStoryAchievementFlag -Name 'Book6Section252SilverBowClaimed'
            Set-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed'
        }
        if ($visitedSections -contains 278) {
            Set-LWStoryAchievementFlag -Name 'Book6Section278DamageApplied'
        }
        if ($visitedSections -contains 282) {
            Set-LWStoryAchievementFlag -Name 'Book6Section282DamageApplied'
        }
        if ($visitedSections -contains 274) {
            Set-LWStoryAchievementFlag -Name 'Book6JumpTheWagonsRoute'
        }
        if ($visitedSections -contains 293) {
            Set-LWStoryAchievementFlag -Name 'Book6Section293SilverKeyUsed'
        }
        if ($visitedSections -contains 304) {
            Set-LWStoryAchievementFlag -Name 'Book6Section304CessClaimed'
            Set-LWStoryAchievementFlag -Name 'Book6CessClaimed'
        }
        if ($visitedSections -contains 306 -and (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus')) {
            Set-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected'
        }
        if ($visitedSections -contains 307) {
            Set-LWStoryAchievementFlag -Name 'Book6Section307Handled'
        }
        if ($visitedSections -contains 310) {
            Set-LWStoryAchievementFlag -Name 'Book6Section310DamageApplied'
        }
        if ($visitedSections -contains 313) {
            Set-LWStoryAchievementFlag -Name 'Book6Section313DamageApplied'
        }
        if ($visitedSections -contains 315) {
            Set-LWStoryAchievementFlag -Name 'Book6Section315MindforceApplied'
            if (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-screen') {
                Set-LWStoryAchievementFlag -Name 'Book6Section315MindforceBlocked'
            }
        }
        if ($visitedSections -contains 348) {
            Set-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost'
        }
        if ($null -ne (Find-LWStateInventoryItemLocation -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Types @('herbpouch', 'backpack'))) {
            Set-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWMapOfTekaroItemNames) -Type 'backpack'))) {
            Set-LWStoryAchievementFlag -Name 'Book6MapOfTekaroClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSmallSilverKeyItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed'
        }
        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $script:GameState -Names (Get-LWCessItemNames) -Type 'special'))) {
            Set-LWStoryAchievementFlag -Name 'Book6CessClaimed'
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

function Test-LWAchievementStoryFlag {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$EvaluationContext = $null
    )

    if ($null -ne $EvaluationContext -and
        (Test-LWPropertyExists -Object $EvaluationContext -Name 'StoryFlags') -and
        $EvaluationContext.StoryFlags -is [System.Collections.IDictionary]) {
        return [bool]$EvaluationContext.StoryFlags[$Name]
    }

    return (Test-LWStoryAchievementFlag -Name $Name)
}

function Register-LWStoryInventoryAchievementTriggers {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
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
    Invoke-LWRuleSetSectionRandomNumberResolution -State $State -Context $context -Rolls @([int]$Roll) -EffectiveRolls @($effectiveBase) -Subtotal $effectiveBase -AdjustedTotal $adjusted
}

function Write-LWCurrentSectionRandomNumberRollSequence {
    param(
        [Parameter(Mandatory = $true)][int[]]$Rolls,
        [object]$State = $script:GameState
    )

    $context = Get-LWSectionRandomNumberContext -State $State
    if ($null -eq $context) {
        Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
        return
    }

    $bookNumber = if ($null -ne $State -and $null -ne $State.Character) { [int]$State.Character.BookNumber } else { 0 }

    if ([bool]$context.Bypassed) {
        Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
        Write-LWInfo ("Book {0} section {1}: {2}" -f $bookNumber, [int]$context.Section, [string]$context.BypassReason)
        return
    }

    $effectiveRolls = @()
    foreach ($roll in @($Rolls)) {
        $effectiveRoll = [int]$roll
        if ([bool]$context.ZeroCountsAsTen -and $effectiveRoll -eq 0) {
            $effectiveRoll = 10
        }
        $effectiveRolls += $effectiveRoll
    }

    $subtotal = ((@($effectiveRolls) | Measure-Object -Sum).Sum)
    $adjusted = [int]$subtotal + [int]$context.Modifier

    Write-LWInfo ("Random Number Table rolls: {0}" -f ((@($Rolls) | ForEach-Object { [int]$_ }) -join ', '))
    if ([bool]$context.ZeroCountsAsTen -and (@($Rolls) | Where-Object { [int]$_ -eq 0 }).Count -gt 0) {
        Write-LWInfo ("Book {0} section {1}: this check treats any 0 roll as 10." -f $bookNumber, [int]$context.Section)
    }

    Write-LWInfo ("Book {0} section {1} subtotal from {2} pick(s): {3}." -f $bookNumber, [int]$context.Section, @($Rolls).Count, $subtotal)
    if ([int]$context.Modifier -ne 0) {
        Write-LWInfo ("Book {0} section {1} modifier {2} applies once to the combined total: {3}." -f $bookNumber, [int]$context.Section, (Format-LWSigned -Value ([int]$context.Modifier)), ($(if (@($context.ModifierNotes).Count -gt 0) { (@($context.ModifierNotes) -join '; ') } else { 'context rule' })))
    }
    else {
        Write-LWInfo ("Book {0} section {1}: no automatic modifier applies." -f $bookNumber, [int]$context.Section)
    }
    Write-LWInfo ("Book {0} section {1} adjusted total: {2}. {3}" -f $bookNumber, [int]$context.Section, $adjusted, [string]$context.Description)
    Invoke-LWRuleSetSectionRandomNumberResolution -State $State -Context $context -Rolls @($Rolls) -EffectiveRolls @($effectiveRolls) -Subtotal $subtotal -AdjustedTotal $adjusted
}

function Invoke-LWCurrentSectionRandomNumberCheck {
    param([object]$State = $script:GameState)

    if ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.BookNumber -eq 6 -and [int]$State.CurrentSection -eq 284) {
        [void](Invoke-LWMagnakaiBookSixSection284BettingRound -State $State)
        return
    }

    $context = Get-LWSectionRandomNumberContext -State $State
    $rollCount = 1
    if ($null -ne $context -and (Test-LWPropertyExists -Object $context -Name 'RollCount') -and $null -ne $context.RollCount) {
        $rollCount = [Math]::Max(1, [int]$context.RollCount)
    }

    if ($rollCount -le 1) {
        Write-LWCurrentSectionRandomNumberRoll -Roll (Get-LWRandomDigit) -State $State
        return
    }

    $rolls = @()
    for ($index = 0; $index -lt $rollCount; $index++) {
        $rolls += (Get-LWRandomDigit)
    }
    Write-LWCurrentSectionRandomNumberRollSequence -Rolls $rolls -State $State
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

    Normalize-LWCombatHistorySections -State $State
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
            $entry | Add-Member -NotePropertyName 'Section' -NotePropertyValue ([int]$backfilledSection) -Force
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
    return @('Shield', 'Kai Shield')
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

function Get-LWMapOfStornlandsItemNames {
    return @('Map of the Stornlands', 'Map of Stornlands')
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

function Get-LWBowWeaponNames {
    return @('Bow')
}

function Get-LWQuiverItemNames {
    return @('Quiver')
}

function Get-LWArrowItemNames {
    return @('Arrow', 'Arrows')
}

function Get-LWQuiverArrowCapacity {
    return 6
}

function Test-LWStateHasQuiver {
    param([object]$State = $script:GameState)

    if ($null -eq $State) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWQuiverItemNames) -Type 'special')))
}

function Get-LWQuiverArrowCount {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Inventory) {
        return 0
    }

    $rawValue = 0
    if ((Test-LWPropertyExists -Object $State.Inventory -Name 'QuiverArrows') -and $null -ne $State.Inventory.QuiverArrows) {
        $rawValue = [int]$State.Inventory.QuiverArrows
    }

    if (-not (Test-LWStateHasQuiver -State $State)) {
        return 0
    }

    $capacity = Get-LWQuiverArrowCapacity
    return [Math]::Max(0, [Math]::Min($rawValue, $capacity))
}

function Sync-LWQuiverArrowState {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Inventory) {
        return 0
    }

    if (-not (Test-LWPropertyExists -Object $State.Inventory -Name 'QuiverArrows') -or $null -eq $State.Inventory.QuiverArrows) {
        $State.Inventory | Add-Member -Force -NotePropertyName QuiverArrows -NotePropertyValue 0
    }

    $normalized = if (Test-LWStateHasQuiver -State $State) {
        [Math]::Max(0, [Math]::Min([int]$State.Inventory.QuiverArrows, (Get-LWQuiverArrowCapacity)))
    }
    else {
        0
    }

    $State.Inventory.QuiverArrows = $normalized
    return $normalized
}

function Format-LWQuiverArrowCounter {
    param([object]$State = $script:GameState)

    $current = Sync-LWQuiverArrowState -State $State
    return ("{0}/{1}" -f $current, (Get-LWQuiverArrowCapacity))
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

function Get-LWMapOfTekaroItemNames {
    return @('Map of Tekaro')
}

function Get-LWTaunorWaterItemNames {
    return @('Taunor Water')
}

function Get-LWSmallSilverKeyItemNames {
    return @('Small Silver Key')
}

function Get-LWSilverBowOfDuadonItemNames {
    return @('Silver Bow of Duadon', 'Silver Bow')
}

function Get-LWCessItemNames {
    return @('Cess')
}

function Get-LWBottleOfWineItemNames {
    return @('Bottle of Wine')
}

function Get-LWMirrorItemNames {
    return @('Mirror')
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

function Get-LWSolnarisWeaponNames {
    return @('Solnaris', "Prince's Sword", 'Princes Sword', "Prince's Broadsword", 'Princes Broadsword')
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

function Get-LWBlanketItemNames {
    return @('Blanket')
}

function Get-LWHerbPouchItemNames {
    return @('Herb Pouch')
}

function Get-LWHerbPouchPotionItemNames {
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($group in @(
            (Get-LWHealingPotionItemNames),
            (Get-LWPotentHealingPotionItemNames),
            (Get-LWConcentratedHealingPotionItemNames),
            (Get-LWMinorHealingPotionItemNames),
            (Get-LWTaunorWaterItemNames),
            (Get-LWAletherPotionItemNames),
            (Get-LWGallowbrushItemNames),
            (Get-LWCalacenaItemNames),
            (Get-LWPotionOfRedLiquidItemNames),
            (Get-LWPotionOfOrangeLiquidItemNames)
        )) {
        foreach ($name in @($group)) {
            $resolvedName = [string]$name
            if ([string]::IsNullOrWhiteSpace($resolvedName)) {
                continue
            }
            if (-not $names.Contains($resolvedName)) {
                [void]$names.Add($resolvedName)
            }
        }
    }

    return @($names.ToArray())
}

function Test-LWHerbPouchPotionItemName {
    param([string]$Name = '')

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHerbPouchPotionItemNames) -Target $Name)))
}

function Test-LWStateHasHerbPouch {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and
        $null -ne $State.Inventory -and
        (Test-LWPropertyExists -Object $State.Inventory -Name 'HasHerbPouch') -and
        [bool]$State.Inventory.HasHerbPouch)
}

function Test-LWHerbPouchFeatureAvailable {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and
        (Test-LWStateIsMagnakaiRuleset -State $State) -and
        [int]$State.Character.BookNumber -ge 6 -and
        (Get-LWBookSixDECuringOption -State $State) -eq 3)
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

function Get-LWBroninWarhammerItemNames {
    return @('Bronin Warhammer')
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
    return @('Warhammer', 'Quarterstaff', 'Mace', 'Drodarin War Hammer', 'Drodarin War Hammer +1', 'Drodarin Warhammer', 'Drodarin Warhammer +1', 'Bronin Warhammer')
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

function Get-LWMinorHealingPotionItemNames {
    return @('Potion of Laumspur (3 END)')
}

function Get-LWAletherPotionItemNames {
    return @('Alether', 'Alether Potion', 'Potion of Alether')
}

function Get-LWAletherBerryItemNames {
    return @('Alether Berries')
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
        (Get-LWMapOfStornlandsItemNames),
        (Get-LWOedeHerbItemNames),
        (Get-LWBlowpipeItemNames),
        (Get-LWSleepDartItemNames),
        (Get-LWGaolersKeysItemNames),
        (Get-LWJakanBowWeaponNames),
        (Get-LWBowWeaponNames),
        (Get-LWQuiverItemNames),
        (Get-LWArrowItemNames),
        (Get-LWTowelItemNames),
        (Get-LWCopperKeyItemNames),
        (Get-LWHerbPadItemNames),
        (Get-LWSilverCombItemNames),
        (Get-LWHourglassItemNames),
        (Get-LWMapOfTekaroItemNames),
        (Get-LWTaunorWaterItemNames),
        (Get-LWSmallSilverKeyItemNames),
        (Get-LWSilverBowOfDuadonItemNames),
        (Get-LWCessItemNames),
        (Get-LWBottleOfWineItemNames),
        (Get-LWMirrorItemNames),
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
        (Get-LWSolnarisWeaponNames),
        (Get-LWDaggerOfVashnaItemNames),
        (Get-LWIronKeyItemNames),
        (Get-LWBrassKeyItemNames),
        (Get-LWWhipItemNames),
        (Get-LWPotionOfRedLiquidItemNames),
        (Get-LWMiningToolItemNames),
        (Get-LWFiresphereItemNames),
        (Get-LWTorchItemNames),
        (Get-LWTinderboxItemNames),
        (Get-LWBlanketItemNames),
        (Get-LWHerbPouchItemNames),
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
        (Get-LWBroninWarhammerItemNames),
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
        'herbpouch' {
            return @($State.Inventory.HerbPouchItems)
        }
        'special' {
            return @($State.Inventory.SpecialItems)
        }
        default {
            return @($State.Inventory.Weapons) + @($State.Inventory.BackpackItems) + @($State.Inventory.HerbPouchItems) + @($State.Inventory.SpecialItems)
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
        [string[]]$Types = @('herbpouch', 'backpack', 'special', 'weapon')
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
        [string[]]$Types = @('herbpouch', 'backpack', 'special', 'weapon')
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

    if ((Test-LWPropertyExists -Object $State -Name 'Combat') -and
        (Test-LWPropertyExists -Object $State.Combat -Name 'SuppressShieldCombatSkillBonus') -and
        [bool]$State.Combat.SuppressShieldCombatSkillBonus) {
        return 0
    }

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

function Test-LWWeaponIsBroninWarhammer {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBroninWarhammerItemNames) -Target $Weapon)))
}

function Test-LWWeaponIsBroadswordPlusOne {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWBroadswordPlusOneWeaponNames) -Target $Weapon)))
}

function Test-LWWeaponIsSolnaris {
    param([string]$Weapon)

    if ([string]::IsNullOrWhiteSpace($Weapon)) {
        return $false
    }

    return (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWSolnarisWeaponNames) -Target $Weapon)))
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

function Test-LWStateHasBroninWarhammer {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBroninWarhammerItemNames) -Type 'special')
}

function Test-LWStateHasBroadswordPlusOne {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWBroadswordPlusOneWeaponNames) -Type 'weapon')
}

function Test-LWStateHasSolnaris {
    param([Parameter(Mandatory = $true)][object]$State)

    return (Test-LWStateHasInventoryItem -State $State -Names (Get-LWSolnarisWeaponNames) -Type 'weapon')
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
    $broninWarhammer = Get-LWMatchingStateInventoryItem -State $State -Names (Get-LWBroninWarhammerItemNames) -Type 'special'
    if (-not [string]::IsNullOrWhiteSpace($broninWarhammer) -and [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values $choices -Target $broninWarhammer))) {
        $choices = @($choices) + @([string]$broninWarhammer)
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

function Get-LWStateBroninWarhammerCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (-not (Test-LWWeaponIsBroninWarhammer -Weapon $activeWeapon)) {
        return 0
    }

    $enemyName = if ($null -ne $State.Combat -and (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyName') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.EnemyName)) {
        [string]$State.Combat.EnemyName
    }
    else {
        ''
    }

    if ($enemyName -match '(?i)armou?red') {
        return 2
    }

    return 1
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

function Get-LWStateSolnarisCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if (Test-LWWeaponIsSolnaris -Weapon $activeWeapon) {
        return 2
    }

    return 0
}

function Test-LWWeaponMatchesWeaponmastery {
    param(
        [string]$Weapon,
        [string[]]$WeaponmasteryWeapons = @()
    )

    if ([string]::IsNullOrWhiteSpace($Weapon) -or @($WeaponmasteryWeapons).Count -eq 0) {
        return $false
    }

    foreach ($masteredWeapon in @($WeaponmasteryWeapons)) {
        if ($Weapon -ieq [string]$masteredWeapon) {
            return $true
        }

        if ((-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWJakanBowWeaponNames) -Target $Weapon))) -and [string]$masteredWeapon -ieq 'Bow') {
            return $true
        }
        if ((Test-LWWeaponIsDrodarinWarHammer -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Warhammer') {
            return $true
        }
        if ((Test-LWWeaponIsBroninWarhammer -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Warhammer') {
            return $true
        }
        if ((Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Broadsword') {
            return $true
        }
        if ((Test-LWWeaponIsCaptainDValSword -Weapon $Weapon) -and [string]$masteredWeapon -ieq 'Sword') {
            return $true
        }
        if ((Test-LWWeaponIsSolnaris -Weapon $Weapon) -and @('Sword', 'Broadsword') -contains [string]$masteredWeapon) {
            return $true
        }
    }

    return $false
}

function Get-LWStateWeaponmasteryCombatSkillBonus {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [string]$Weapon = $null
    )

    if (-not (Test-LWStateHasDiscipline -State $State -Name 'Weaponmastery')) {
        return 0
    }

    $activeWeapon = if ([string]::IsNullOrWhiteSpace($Weapon)) { [string]$State.Combat.EquippedWeapon } else { [string]$Weapon }
    if ([string]::IsNullOrWhiteSpace($activeWeapon)) {
        return 0
    }

    if (Test-LWWeaponMatchesWeaponmastery -Weapon $activeWeapon -WeaponmasteryWeapons @($State.Character.WeaponmasteryWeapons)) {
        return 3
    }

    return 0
}

function Test-LWCombatPsychicAttackUsesPsiSurge {
    param([Parameter(Mandatory = $true)][object]$State)

    if ((Test-LWPropertyExists -Object $State.Combat -Name 'PsychicAttackMode') -and [string]$State.Combat.PsychicAttackMode -ieq 'Psi-surge') {
        return [bool]$State.Combat.UseMindblast
    }

    return ((Test-LWStateIsMagnakaiRuleset -State $State) -and [bool]$State.Combat.UseMindblast -and (Test-LWStateHasDiscipline -State $State -Name 'Psi-surge'))
}

function Get-LWCombatPsychicAttackLabel {
    param([Parameter(Mandatory = $true)][object]$State)

    if ((Test-LWPropertyExists -Object $State.Combat -Name 'PsychicAttackMode') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.PsychicAttackMode)) {
        return [string]$State.Combat.PsychicAttackMode
    }

    if (Test-LWCombatPsychicAttackUsesPsiSurge -State $State) {
        return 'Psi-surge'
    }

    return 'Mindblast'
}

function Get-LWCombatPsychicAttackBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWCombatPsychicAttackUsesPsiSurge -State $State) {
        return 4
    }

    if ((Test-LWPropertyExists -Object $State.Combat -Name 'MindblastCombatSkillBonus') -and $null -ne $State.Combat.MindblastCombatSkillBonus) {
        return [int]$State.Combat.MindblastCombatSkillBonus
    }

    return 2
}

function Get-LWCombatPsychicAttackEnduranceDrain {
    param([Parameter(Mandatory = $true)][object]$State)

    if (Test-LWCombatPsychicAttackUsesPsiSurge -State $State) {
        return 2
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

function Get-LWStateCompletedLoreCircles {
    param([Parameter(Mandatory = $true)][object]$State)

    $definitions = @()
    if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiLoreCircles') -and $null -ne $script:GameData.MagnakaiLoreCircles) {
        $definitions = @($script:GameData.MagnakaiLoreCircles)
    }

    $owned = @()
    if ($null -ne $State.Character -and (Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiDisciplines') -and $null -ne $State.Character.MagnakaiDisciplines) {
        $owned = @($State.Character.MagnakaiDisciplines | ForEach-Object { [string]$_ })
    }
    if ($definitions.Count -eq 0 -or $owned.Count -eq 0) {
        return @()
    }

    return @(
        foreach ($definition in $definitions) {
            $required = @($definition.Disciplines | ForEach-Object { [string]$_ })
            if ($required.Count -gt 0 -and @($required | Where-Object { $owned -notcontains $_ }).Count -eq 0) {
                $definition
            }
        }
    )
}

function Get-LWStateLoreCircleCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    $bonus = 0
    foreach ($circle in @(Get-LWStateCompletedLoreCircles -State $State)) {
        $bonus += [int]$circle.CombatSkillBonus
    }

    return $bonus
}

function Get-LWStateLoreCircleEnduranceBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    $bonus = 0
    foreach ($circle in @(Get-LWStateCompletedLoreCircles -State $State)) {
        $bonus += [int]$circle.EnduranceBonus
    }

    return $bonus
}

function Sync-LWMagnakaiLoreCircleBonuses {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$WriteMessages
    )

    Ensure-LWEquipmentBonusState -State $State

    $completedCircles = @(Get-LWStateCompletedLoreCircles -State $State)
    $circleNames = @($completedCircles | ForEach-Object { [string]$_.Name })
    $desiredCombatSkill = Get-LWStateLoreCircleCombatSkillBonus -State $State
    $desiredEndurance = Get-LWStateLoreCircleEnduranceBonus -State $State
    $appliedCombatSkill = [int]$State.EquipmentBonuses.LoreCircleCombatSkill
    $appliedEndurance = [int]$State.EquipmentBonuses.LoreCircleEndurance
    $combatDelta = $desiredCombatSkill - $appliedCombatSkill
    $enduranceDelta = $desiredEndurance - $appliedEndurance

    $State.Character.LoreCirclesCompleted = @($circleNames)

    if ($combatDelta -eq 0 -and $enduranceDelta -eq 0) {
        return
    }

    $State.Character.CombatSkillBase = [Math]::Max(0, ([int]$State.Character.CombatSkillBase + $combatDelta))
    $newMax = [Math]::Max(1, ([int]$State.Character.EnduranceMax + $enduranceDelta))
    $newCurrent = [int]$State.Character.EnduranceCurrent + $enduranceDelta
    if ($newCurrent -lt 0) {
        $newCurrent = 0
    }
    if ($newCurrent -gt $newMax) {
        $newCurrent = $newMax
    }

    $State.Character.EnduranceMax = $newMax
    $State.Character.EnduranceCurrent = $newCurrent
    $State.EquipmentBonuses.LoreCircleCombatSkill = $desiredCombatSkill
    $State.EquipmentBonuses.LoreCircleEndurance = $desiredEndurance

    if ($WriteMessages) {
        $circleSummary = if ($circleNames.Count -gt 0) { $circleNames -join ', ' } else { 'none' }
        Write-LWInfo ("Lore-circle bonuses updated: CS {0}, END {1}. Circles: {2}." -f (Format-LWSigned -Value $combatDelta), (Format-LWSigned -Value $enduranceDelta), $circleSummary)
    }
}

function Get-LWLoreCircleDisplayName {
    param([string]$Name)

    return (([string]$Name) -replace '^Circle of the ', '' -replace '^Circle of ', '')
}

function Get-LWLoreCircleDisplayOrder {
    param([string]$Name)

    switch (Get-LWLoreCircleDisplayName -Name $Name) {
        'Spirit' { return 0 }
        'Fire' { return 1 }
        'Solaris' { return 2 }
        'Light' { return 3 }
        default { return 99 }
    }
}

function Format-LWLoreCirclePanelRow {
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [string[]]$OwnedDisciplines = @()
    )

    $required = @($Definition.Disciplines | ForEach-Object { [string]$_ })
    $ownedCount = @($required | Where-Object { $OwnedDisciplines -contains $_ }).Count
    $status = if ($ownedCount -ge $required.Count) { 'done' } elseif ($ownedCount -gt 0) { 'partial' } else { 'empty' }
    $circleName = Get-LWLoreCircleDisplayName -Name ([string]$Definition.Name)
    $statusText = $status

    if ($status -eq 'done') {
        $bonusParts = @()
        if ([int]$Definition.CombatSkillBonus -gt 0) {
            $bonusParts += ("+{0} CS" -f [int]$Definition.CombatSkillBonus)
        }
        if ([int]$Definition.EnduranceBonus -gt 0) {
            $bonusParts += ("+{0} E" -f [int]$Definition.EnduranceBonus)
        }
        if ($bonusParts.Count -gt 0) {
            $statusText = ("done ({0})" -f ($bonusParts -join ', '))
        }
    }

    return [pscustomobject]@{
        Name  = $circleName
        Text  = ("{0,-7}: {1}" -f $circleName, $statusText)
        Color = $(if ($status -eq 'done') { 'Green' } elseif ($status -eq 'partial') { 'Yellow' } else { 'DarkGray' })
        Order = Get-LWLoreCircleDisplayOrder -Name ([string]$Definition.Name)
    }
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

    $completedRounds = @($State.Combat.Log).Count
    $requiredRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $State.Combat.EvadeAvailableAfterRound) { [int]$State.Combat.EvadeAvailableAfterRound } else { 0 }
    if ($requiredRounds -le 0) {
        $expiryRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeExpiresAfterRound') -and $null -ne $State.Combat.EvadeExpiresAfterRound) { [int]$State.Combat.EvadeExpiresAfterRound } else { 0 }
        if ($expiryRounds -gt 0) {
            if ($completedRounds -ge $expiryRounds) {
                return 'No'
            }

            return $(if ($expiryRounds -eq 1) { 'Round 1 only' } else { "Through round $expiryRounds" })
        }

        return 'Yes'
    }

    if ($completedRounds -ge $requiredRounds) {
        return 'Yes'
    }

    return ("After round {0}" -f $requiredRounds)
}

function Test-LWCombatCanEvadeNow {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.CanEvade) {
        return $false
    }

    $completedRounds = @($State.Combat.Log).Count
    $requiredRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeAvailableAfterRound') -and $null -ne $State.Combat.EvadeAvailableAfterRound) { [int]$State.Combat.EvadeAvailableAfterRound } else { 0 }
    if ($requiredRounds -gt 0 -and $completedRounds -lt $requiredRounds) {
        return $false
    }

    $expiryRounds = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EvadeExpiresAfterRound') -and $null -ne $State.Combat.EvadeExpiresAfterRound) { [int]$State.Combat.EvadeExpiresAfterRound } else { 0 }
    if ($expiryRounds -gt 0 -and $completedRounds -ge $expiryRounds) {
        return $false
    }

    return $true
}

function Get-LWCombatMindforceStatusText {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not [bool]$State.Combat.EnemyUsesMindforce) {
        return 'Off'
    }

    if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
        $usesPsiScreen = ((Test-LWCombatPsychicAttackUsesPsiSurge -State $State) -or (Test-LWStateHasDiscipline -State $State -Name 'Psi-screen'))
        $shieldLabel = if ($usesPsiScreen) { 'Psi-screen' } else { 'Mindshield' }
        return ("Blocked by {0}" -f $shieldLabel)
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
    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'LoreCircleCombatSkill') -or $null -eq $State.EquipmentBonuses.LoreCircleCombatSkill) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName LoreCircleCombatSkill -NotePropertyValue 0
    }
    if (-not (Test-LWPropertyExists -Object $State.EquipmentBonuses -Name 'LoreCircleEndurance') -or $null -eq $State.EquipmentBonuses.LoreCircleEndurance) {
        $State.EquipmentBonuses | Add-Member -Force -NotePropertyName LoreCircleEndurance -NotePropertyValue 0
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

    $desiredLoreCircleEndurance = Get-LWStateLoreCircleEnduranceBonus -State $State
    $appliedLoreCircleEndurance = [int]$State.EquipmentBonuses.LoreCircleEndurance
    $loreCircleEnduranceDelta = $desiredLoreCircleEndurance - $appliedLoreCircleEndurance

    $delta = $chainmailDelta + $paddedLeatherDelta + $helmetDelta + $daggerOfVashnaDelta + $loreCircleEnduranceDelta

    if ($delta -eq 0) {
        $State.EquipmentBonuses.LoreCircleCombatSkill = Get-LWStateLoreCircleCombatSkillBonus -State $State
        $State.EquipmentBonuses.LoreCircleEndurance = $desiredLoreCircleEndurance
        $State.Character.LoreCirclesCompleted = @((Get-LWStateCompletedLoreCircles -State $State) | ForEach-Object { [string]$_.Name })
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
    $State.EquipmentBonuses.LoreCircleCombatSkill = Get-LWStateLoreCircleCombatSkillBonus -State $State
    $State.EquipmentBonuses.LoreCircleEndurance = $desiredLoreCircleEndurance
    $State.Character.LoreCirclesCompleted = @((Get-LWStateCompletedLoreCircles -State $State) | ForEach-Object { [string]$_.Name })

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
        if ($loreCircleEnduranceDelta -ne 0) {
            Write-LWInfo ("Lore-circle END bonus updated: {0}. Current Endurance: {1} / {2}." -f (Format-LWSigned -Value $loreCircleEnduranceDelta), $State.Character.EnduranceCurrent, $State.Character.EnduranceMax)
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

function Read-LWInlineYesNo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,
        [bool]$Default = $true
    )

    while ($true) {
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
            default { Write-LWInlineWarn 'Please enter y or n.' }
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
        PsychicAttackMode         = 'Mindblast'
        MindblastCombatSkillBonus = 2
        AletherCombatSkillBonus   = 0
        AttemptKnockout           = $false
        CanEvade                  = $false
        EvadeAvailableAfterRound  = 0
        EvadeExpiresAfterRound    = 0
        EvadeResolutionSection    = $null
        EvadeResolutionNote       = $null
        EquippedWeapon            = $null
        DeferredEquippedWeapon    = $null
        EquipDeferredWeaponAfterRound = 0
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
        UsePlayerTargetEndurance = $false
        PlayerTargetEnduranceCurrent = 0
        PlayerTargetEnduranceMax = 0
        SuppressShieldCombatSkillBonus = $false
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

    Invoke-LWCoreAddBookSectionVisit -Context (Get-LWModuleContext) -Section $Section
}

function Add-LWBookEnduranceDelta {
    param([int]$Delta)

    Invoke-LWCoreAddBookEnduranceDelta -Context (Get-LWModuleContext) -Delta $Delta
}

function Add-LWBookGoldDelta {
    param([int]$Delta)

    Invoke-LWCoreAddBookGoldDelta -Context (Get-LWModuleContext) -Delta $Delta
}

function Add-LWBookNamedCount {
    param(
        [Parameter(Mandatory = $true)][string]$PropertyName,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$Delta = 1
    )

    Invoke-LWCoreAddBookNamedCount -Context (Get-LWModuleContext) -PropertyName $PropertyName -Name $Name -Delta $Delta
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
    if (-not (Test-LWAchievementSyncSuppressed -Context 'healing')) {
        [void](Sync-LWAchievements -Context 'healing')
    }
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

    $capInfo = Get-LWHealingRestorationCapInfo -State $State
    if ($null -eq $capInfo) {
        return $null
    }

    return [int]$capInfo.Cap
}

















function Test-LWStateHasActiveWeaponskill {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Character -or [string]::IsNullOrWhiteSpace([string]$State.Character.WeaponskillWeapon)) {
        return $false
    }

    if ((Test-LWStateIsMagnakaiRuleset -State $State) -and [int]$State.Character.BookNumber -eq 6) {
        return (Test-LWBookSixDEWeaponskillEnabled -State $State)
    }

    return (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill')
}

function Get-LWHealingRestorationCapInfo {
    param([object]$State = $script:GameState)

    $capRules = @()
    if (@('Hard', 'Veteran') -contains (Get-LWCurrentDifficulty -State $State)) {
        $capRules += [pscustomobject]@{
            Cap         = 10
            ZeroNote    = 'Healing is capped at 10 END restored per book in this mode.'
            PartialNote = 'Healing is capped in this mode: {0} END can be restored now ({1} remaining this book).'
        }
    }

    if ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.BookNumber -eq 6 -and (Test-LWStateIsMagnakaiRuleset -State $State)) {
        switch (Get-LWBookSixDECuringOption -State $State) {
            1 {
                $capRules += [pscustomobject]@{
                    Cap         = 15
                    ZeroNote    = 'Book 6 DE Play Option 1 caps Curing and Healing at 15 END restored this book.'
                    PartialNote = 'Book 6 DE Play Option 1 caps Curing/Healing: {0} END can be restored now ({1} remaining this book).'
                }
            }
            2 {
                $capRules += [pscustomobject]@{
                    Cap         = 10
                    ZeroNote    = 'Book 6 DE Play Option 2 caps Healing at 10 END restored this book.'
                    PartialNote = 'Book 6 DE Play Option 2 caps Healing: {0} END can be restored now ({1} remaining this book).'
                }
            }
        }
    }

    if ($capRules.Count -eq 0) {
        return $null
    }

    $minCap = [int](($capRules | Measure-Object -Property Cap -Minimum).Minimum)
    return @($capRules | Where-Object { [int]$_.Cap -eq $minCap } | Select-Object -First 1)[0]
}

function Test-LWStateHasSectionHealing {
    param([object]$State = $script:GameState)

    if ($null -eq $State -or $null -eq $State.Character) {
        return $false
    }

    $isBookSixMagnakai = ((Test-LWStateIsMagnakaiRuleset -State $State) -and [int]$State.Character.BookNumber -eq 6)
    if (-not $isBookSixMagnakai) {
        return (Test-LWStateHasDiscipline -State $State -Name 'Healing')
    }

    if (Test-LWStateHasDiscipline -State $State -Name 'Curing') {
        return $true
    }

    return ((Get-LWBookSixDECuringOption -State $State) -eq 2 -and (Test-LWStateHasDiscipline -State $State -Name 'Healing'))
}

function Get-LWSectionHealingSourceLabel {
    param([object]$State = $script:GameState)

    if ($null -ne $State -and $null -ne $State.Character -and [int]$State.Character.BookNumber -eq 6 -and (Test-LWStateIsMagnakaiRuleset -State $State) -and (Test-LWStateHasDiscipline -State $State -Name 'Curing')) {
        return 'Curing'
    }

    return 'Healing'
}

function Test-LWCombatHerbPouchOptionActive {
    param([object]$State = $script:GameState)

    return ($null -ne $State -and
        $null -ne $State.Character -and
        (Test-LWStateIsMagnakaiRuleset -State $State) -and
        [int]$State.Character.BookNumber -ge 6 -and
        (Get-LWBookSixDECuringOption -State $State) -eq 3 -and
        (Test-LWStateHasHerbPouch -State $State))
}

function Get-LWPreferredHealingPotionChoice {
    param([object]$State = $script:GameState)

    return @((Get-LWAvailableHealingPotionChoices -State $State) | Select-Object -First 1)[0]
}

function Get-LWPreferredHerbPouchCombatPotionChoice {
    param([object]$State = $script:GameState)

    return @((Get-LWAvailableHealingPotionChoices -State $State -HerbPouchOnly) | Select-Object -First 1)[0]
}

function Get-LWAvailableHealingPotionChoices {
    param(
        [object]$State = $script:GameState,
        [switch]$HerbPouchOnly
    )

    if ($null -eq $State) {
        return @()
    }

    $definitions = @(
        [pscustomobject]@{ Names = (Get-LWConcentratedHealingPotionItemNames); RestoreAmount = 8; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWOedeHerbItemNames); RestoreAmount = 10; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWTaunorWaterItemNames); RestoreAmount = 6; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWRendalimsElixirItemNames); RestoreAmount = 6; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWPotentHealingPotionItemNames); RestoreAmount = 5; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWHealingPotionItemNames); RestoreAmount = 4; Types = @('herbpouch', 'backpack') },
        [pscustomobject]@{ Names = (Get-LWBottleOfKourshahItemNames); RestoreAmount = 4; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWMinorHealingPotionItemNames); RestoreAmount = 3; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWLaumspurHerbItemNames); RestoreAmount = 3; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWMealOfLaumspurItemNames); RestoreAmount = 3; Types = @('backpack') },
        [pscustomobject]@{ Names = (Get-LWLarnumaOilItemNames); RestoreAmount = 2; Types = @('backpack') }
    )

    $choices = New-Object System.Collections.Generic.List[object]
    foreach ($definition in $definitions) {
        $types = if ($HerbPouchOnly) { @('herbpouch') } else { @($definition.Types) }
        foreach ($type in $types) {
            if (@($definition.Types) -notcontains $type) {
                continue
            }
            if ($type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $State)) {
                continue
            }
            if ($type -eq 'backpack' -and -not (Test-LWStateHasBackpack -State $State)) {
                continue
            }

            $items = @(Get-LWStateInventoryItems -State $State -Type $type)
            $matchedItems = @($items | Where-Object {
                    -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values @($definition.Names) -Target ([string]$_)))
                })
            if ($matchedItems.Count -eq 0) {
                continue
            }

            foreach ($itemName in @($matchedItems | Select-Object -Unique)) {
                $matchCount = @($matchedItems | Where-Object { [string]$_ -eq [string]$itemName }).Count
                $choices.Add([pscustomobject]@{
                        Name          = [string]$itemName
                        RestoreAmount = [int]$definition.RestoreAmount
                        Type          = [string]$type
                        Quantity      = [int]$matchCount
                        LocationLabel = $(if ($type -eq 'herbpouch') { 'Herb Pouch' } else { 'Backpack' })
                    })
            }
        }
    }

    return @($choices.ToArray())
}

function Format-LWHealingPotionChoiceText {
    param([Parameter(Mandatory = $true)][object]$Choice)

    $countSuffix = if ((Test-LWPropertyExists -Object $Choice -Name 'Quantity') -and [int]$Choice.Quantity -gt 1) {
        " x$([int]$Choice.Quantity)"
    }
    else {
        ''
    }

    $locationLabel = if ((Test-LWPropertyExists -Object $Choice -Name 'LocationLabel') -and -not [string]::IsNullOrWhiteSpace([string]$Choice.LocationLabel)) {
        [string]$Choice.LocationLabel
    }
    elseif ((Test-LWPropertyExists -Object $Choice -Name 'Type') -and [string]$Choice.Type -eq 'herbpouch') {
        'Herb Pouch'
    }
    else {
        'Backpack'
    }

    return ("{0}{1} [{2}] +{3} END" -f [string]$Choice.Name, $countSuffix, $locationLabel, [int]$Choice.RestoreAmount)
}

function Select-LWHealingPotionChoice {
    param(
        [object]$State = $script:GameState,
        [switch]$HerbPouchOnly
    )

    $choices = @(Get-LWAvailableHealingPotionChoices -State $State -HerbPouchOnly:$HerbPouchOnly)
    if ($choices.Count -eq 0) {
        if ($HerbPouchOnly) {
            Write-LWWarn 'No usable healing potion is currently stored in the Herb Pouch.'
        }
        else {
            Write-LWWarn 'No usable healing item found in Herb Pouch or Backpack.'
        }
        return $null
    }

    if ($choices.Count -eq 1) {
        return $choices[0]
    }

    $title = if ($HerbPouchOnly) { 'Choose Combat Potion' } else { 'Choose Potion' }
    $accent = if ($HerbPouchOnly) { 'Red' } else { 'DarkGreen' }
    Write-LWRetroPanelHeader -Title $title -AccentColor $accent
    for ($i = 0; $i -lt $choices.Count; $i++) {
        Write-LWRetroPanelTextRow -Text ("{0,2}. {1}" -f ($i + 1), (Format-LWHealingPotionChoiceText -Choice $choices[$i])) -TextColor 'Gray'
    }
    Write-LWRetroPanelTextRow -Text ' 0. Cancel' -TextColor 'DarkGray'
    Write-LWRetroPanelFooter

    $choiceIndex = Read-LWInt -Prompt 'Potion number' -Default 0 -Min 0 -Max $choices.Count -NoRefresh
    if ($choiceIndex -eq 0) {
        Write-LWInfo 'Potion use cancelled.'
        return $null
    }

    return $choices[$choiceIndex - 1]
}

function Use-LWResolvedHealingPotion {
    param(
        [Parameter(Mandatory = $true)][string]$PotionName,
        [Parameter(Mandatory = $true)][int]$RestoreAmount,
        [string]$InventoryType = '',
        [switch]$SkipAutosave
    )

    if ([string]::IsNullOrWhiteSpace($PotionName)) {
        Write-LWWarn 'No usable healing item found in Herb Pouch or Backpack.'
        return $null
    }

    $removeType = if (@('backpack', 'herbpouch') -contains $InventoryType) {
        [string]$InventoryType
    }
    else {
        $location = Find-LWStateInventoryItemLocation -State $script:GameState -Names @($PotionName) -Types @('herbpouch', 'backpack')
        if ($null -ne $location) { [string]$location.Type } else { 'backpack' }
    }

    [void](Remove-LWInventoryItemSilently -Type $removeType -Name $PotionName -Quantity 1)
    $before = [int]$script:GameState.Character.EnduranceCurrent
    $script:GameState.Character.EnduranceCurrent += [int]$RestoreAmount
    if ($script:GameState.Character.EnduranceCurrent -gt $script:GameState.Character.EnduranceMax) {
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    }
    $restored = [int]$script:GameState.Character.EnduranceCurrent - $before

    $conditionMessages = @()
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWHealingPotionItemNames) -Target $PotionName)) -or
        -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWLaumspurHerbItemNames) -Target $PotionName))) {
        if (Test-LWBookFiveBloodPoisoningActive -State $script:GameState) {
            $script:GameState.Conditions.BookFiveBloodPoisoning = $false
            $conditionMessages += 'Blood poisoning cured.'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWOedeHerbItemNames) -Target $PotionName))) {
        if (Test-LWBookFiveLimbdeathActive -State $script:GameState) {
            $script:GameState.Conditions.BookFiveLimbdeath = $false
            Set-LWStoryAchievementFlag -Name 'Book5LimbdeathCured'
            $conditionMessages += 'Limbdeath cured.'
        }
    }

    Add-LWBookEnduranceDelta -Delta $restored
    Register-LWPotionUsed -PotionName $PotionName -EnduranceRestored $restored
    $message = "$PotionName restores $RestoreAmount Endurance. Current Endurance: $($script:GameState.Character.EnduranceCurrent)."
    if ($conditionMessages.Count -gt 0) {
        $message += " $($conditionMessages -join ' ')"
    }
    Write-LWInfo $message
    if (-not $SkipAutosave) {
        Invoke-LWMaybeAutosave
    }

    return [pscustomobject]@{
        PotionName    = $PotionName
        RestoreAmount = [int]$RestoreAmount
        AppliedAmount = $restored
    }
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
    $capInfo = Get-LWHealingRestorationCapInfo -State $State
    if ($applied -lt $requested) {
        if ($remaining -le 0) {
            $note = if ($null -ne $capInfo -and -not [string]::IsNullOrWhiteSpace([string]$capInfo.ZeroNote)) { [string]$capInfo.ZeroNote } else { 'Healing is capped this book.' }
        }
        else {
            $note = if ($null -ne $capInfo -and -not [string]::IsNullOrWhiteSpace([string]$capInfo.PartialNote)) {
                [string]::Format([string]$capInfo.PartialNote, $applied, $remaining)
            }
            else {
                "Healing is capped this book: $applied END can be restored now ($remaining remaining this book)."
            }
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

    $weaponName = Get-LWCombatDisplayWeapon -Weapon $(if (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.EquippedWeapon)) { [string]$script:GameState.Combat.EquippedWeapon } elseif ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'DeferredEquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.DeferredEquippedWeapon)) { [string]$script:GameState.Combat.DeferredEquippedWeapon } else { $null })
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

    $bookAchievements = @($script:GameState.Achievements.Unlocked | Where-Object { [int]$_.BookNumber -eq [int]$Summary.BookNumber } | Select-Object -Last 4)

    Write-LWRetroPanelHeader -Title 'Adventure Complete' -AccentColor 'Green'
    Write-LWRetroPanelPairRow -LeftLabel 'Character' -LeftValue $CharacterName -RightLabel 'Difficulty' -RightValue (Get-LWCurrentDifficulty) -LeftColor 'White' -RightColor (Get-LWDifficultyColor -Difficulty (Get-LWCurrentDifficulty)) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Rule Set' -LeftValue ([string]$script:GameState.RuleSet) -RightLabel 'Outcome' -RightValue 'Victory' -LeftColor 'Gray' -RightColor 'Green' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelKeyValueRow -Label 'Completed Book' -Value $completedBookLabel -ValueColor 'White'
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Book Summary' -AccentColor 'Cyan'
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Wins' -LeftValue ([string]$Summary.Victories) -RightLabel 'Combat Losses' -RightValue ([string]$Summary.Defeats) -LeftColor 'Green' -RightColor 'Red'
    Write-LWRetroPanelPairRow -LeftLabel 'Sections Seen' -LeftValue ([string]$Summary.SectionsVisited) -RightLabel 'Notes Added' -RightValue ([string]@($script:GameState.Character.Notes).Count) -LeftColor 'Gray' -RightColor 'Gray'
    Write-LWRetroPanelPairRow -LeftLabel 'Gold Crowns' -LeftValue ("{0} / 50" -f [int]$script:GameState.Inventory.GoldCrowns) -RightLabel 'Endurance' -RightValue ("{0} / {1}" -f [int]$script:GameState.Character.EnduranceCurrent, [int]$script:GameState.Character.EnduranceMax) -LeftColor 'Yellow' -RightColor (Get-LWEnduranceColor -Current ([int]$script:GameState.Character.EnduranceCurrent) -Max ([int]$script:GameState.Character.EnduranceMax))
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

function Test-LWDiscipline {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Test-LWHasState)) {
        return $false
    }

    return (Test-LWStateHasDiscipline -State $script:GameState -Name $Name)
}

function Test-LWStateHasDiscipline {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $target = [string]$Name
    if ([string]::IsNullOrWhiteSpace($target) -or $null -eq $State -or $null -eq $State.Character) {
        return $false
    }

    $kaiDisciplines = @($State.Character.Disciplines | ForEach-Object { [string]$_ })
    $magnakaiDisciplines = if ((Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiDisciplines') -and $null -ne $State.Character.MagnakaiDisciplines) {
        @($State.Character.MagnakaiDisciplines | ForEach-Object { [string]$_ })
    }
    else {
        @()
    }

    if ($kaiDisciplines -icontains $target) {
        return $true
    }
    if ($magnakaiDisciplines -icontains $target) {
        return $true
    }

    $isMagnakai = Test-LWStateIsMagnakaiRuleset -State $State
    $hasLegacyKai = (Test-LWPropertyExists -Object $State.Character -Name 'LegacyKaiComplete') -and [bool]$State.Character.LegacyKaiComplete
    if ($isMagnakai -and $hasLegacyKai -and ((Get-LWKnownKaiDisciplineNames) -icontains $target)) {
        return $true
    }

    switch -Regex ($target) {
        '^Healing$' {
            return ($magnakaiDisciplines -icontains 'Curing')
        }
        '^Hunting$' {
            return ($magnakaiDisciplines -icontains 'Huntmastery')
        }
        '^Mindshield$' {
            return ($magnakaiDisciplines -icontains 'Psi-screen')
        }
        '^Mindblast$' {
            return ($magnakaiDisciplines -icontains 'Psi-surge')
        }
        '^Weaponskill$' {
            return ($magnakaiDisciplines -icontains 'Weaponmastery')
        }
        '^Animal Kinship$' {
            return ($magnakaiDisciplines -icontains 'Animal Control')
        }
        '^Mind Over Matter$' {
            return ($magnakaiDisciplines -icontains 'Nexus')
        }
    }

    return $false
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

    if ((Test-LWWeaponIsBroninWarhammer -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Warhammer') {
        return $true
    }

    if ((Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) -and [string]$WeaponskillWeapon -ieq 'Broadsword') {
        return $true
    }

    if ((Test-LWWeaponIsSolnaris -Weapon $Weapon) -and @('Broadsword', 'Sword') -contains [string]$WeaponskillWeapon) {
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

    if (Test-LWStateHasActiveWeaponskill -State $State) {
        $weaponskillWeapon = Get-LWMatchingValue -Values $weapons -Target ([string]$State.Character.WeaponskillWeapon)
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Warhammer') {
            $weaponskillWeapon = [string]($weapons | Where-Object { (Test-LWWeaponIsDrodarinWarHammer -Weapon ([string]$_)) -or (Test-LWWeaponIsBroninWarhammer -Weapon ([string]$_)) } | Select-Object -First 1)
        }
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Broadsword') {
            $weaponskillWeapon = [string]($weapons | Where-Object { (Test-LWWeaponIsBroadswordPlusOne -Weapon ([string]$_)) -or (Test-LWWeaponIsSolnaris -Weapon ([string]$_)) } | Select-Object -First 1)
        }
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Sword') {
            $weaponskillWeapon = [string]($weapons | Where-Object { (Test-LWWeaponIsCaptainDValSword -Weapon ([string]$_)) -or (Test-LWWeaponIsSolnaris -Weapon ([string]$_)) } | Select-Object -First 1)
        }
        if ([string]::IsNullOrWhiteSpace($weaponskillWeapon) -and [string]$State.Character.WeaponskillWeapon -ieq 'Spear') {
            $weaponskillWeapon = [string]($weapons | Where-Object { Test-LWWeaponIsMagicSpear -Weapon ([string]$_) } | Select-Object -First 1)
        }
        if (-not [string]::IsNullOrWhiteSpace($weaponskillWeapon)) {
            return $weaponskillWeapon
        }
    }

    if ((Test-LWStateIsMagnakaiRuleset -State $State) -and @($State.Character.WeaponmasteryWeapons).Count -gt 0) {
        $weaponmasteryWeapon = [string]($weapons | Where-Object { Test-LWWeaponMatchesWeaponmastery -Weapon ([string]$_) -WeaponmasteryWeapons @($State.Character.WeaponmasteryWeapons) } | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($weaponmasteryWeapon)) {
            return $weaponmasteryWeapon
        }
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

function Show-LWHelpfulCommandsPanel {
    param(
        [Parameter(Mandatory = $true)][string]$ScreenName,
        [string]$View = '',
        [string]$Variant = '',
        [string]$AccentColor = 'DarkYellow'
    )

    $rows = @(Get-LWHelpfulCommandRows -ScreenName $ScreenName -View $View -Variant $Variant)
    if ($rows.Count -eq 0) {
        return
    }

    $labelWidth = 18
    foreach ($row in $rows) {
        $labelText = if ($null -eq $row.Label) { '' } else { [string]$row.Label }
        if ($labelText.Length -gt $labelWidth) {
            $labelWidth = $labelText.Length
        }
    }
    $labelWidth = [Math]::Min(24, [Math]::Max(16, $labelWidth))

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
    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $isMagnakai = Test-LWStateIsMagnakaiRuleset -State $script:GameState
    $panelTitle = if ($isMagnakai) { 'Magnakai Disciplines' } else { 'Kai Disciplines' }
    $displayDisciplines = @()
    $definitionsByName = @{}
    $kaiDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'KaiDisciplines') -and $null -ne $script:GameData.KaiDisciplines) {
        @($script:GameData.KaiDisciplines)
    }
    else {
        @()
    }
    $magnakaiDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiDisciplines') -and $null -ne $script:GameData.MagnakaiDisciplines) {
        @($script:GameData.MagnakaiDisciplines)
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

    if ($isMagnakai -and $null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiLoreCircles') -and @($script:GameData.MagnakaiLoreCircles).Count -gt 0) {
        Write-LWRetroPanelHeader -Title 'Lore Circles' -AccentColor 'Magenta'
        $owned = @($magnakaiDisciplines)
        $circleRows = @()
        foreach ($definition in @($script:GameData.MagnakaiLoreCircles | Sort-Object @{ Expression = { Get-LWLoreCircleDisplayOrder -Name ([string]$_.Name) } }, @{ Expression = { [string]$_.Name } })) {
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

function Get-LWCombatArchiveOutcomeLabel {
    param([string]$Outcome = '')

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
    Invoke-LWCoreShowStatsScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
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

    if ([string]::IsNullOrWhiteSpace($EnemyName) -or $null -eq $Value -or ([string]$Value) -eq '' -or ([int]$Value) -le 0) {
        return ("{0}: (none)" -f $Label)
    }

    return ("{0}: {1} ({2}{3}) | {4}" -f $Label, $EnemyName, $Value, $Suffix, $BookLabel)
}

function Get-LWDisplayBookHighlightTitle {
    param([string]$BookLabel)

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
            Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray'
        }
    }
    Write-LWRetroPanelFooter
}

function Show-LWCampaignScreen {
    Invoke-LWCoreShowCampaignScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
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

    return (Get-LWAchievementDisplayCounts).EligibleCount
}

function Get-LWAchievementEligibleUnlockedCount {
    if (-not (Test-LWHasState)) {
        return 0
    }

    return (Get-LWAchievementDisplayCounts).EligibleUnlockedCount
}

function Get-LWAchievementDisplayCounts {
    if (-not (Test-LWHasState)) {
        return [pscustomobject]@{
            EligibleCount         = 0
            EligibleUnlockedCount = 0
        }
    }

    Ensure-LWAchievementState -State $script:GameState
    $runId = if ($null -ne $script:GameState.Run -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.Id)) { [string]$script:GameState.Run.Id } else { 'no-run' }
    $difficulty = Get-LWCurrentDifficulty
    $permadeath = if (Test-LWPermadeathEnabled) { '1' } else { '0' }
    $integrity = if ($null -ne $script:GameState.Run -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityState)) { [string]$script:GameState.Run.IntegrityState } else { 'unknown' }
    $unlockedCount = @($script:GameState.Achievements.Unlocked).Count
    $cacheKey = '{0}|{1}|{2}|{3}|{4}' -f $runId, $difficulty, $permadeath, $integrity, $unlockedCount

    if ($null -ne $script:LWAchievementDisplayCountsCache -and
        (Test-LWPropertyExists -Object $script:LWAchievementDisplayCountsCache -Name 'Key') -and
        [string]$script:LWAchievementDisplayCountsCache.Key -eq $cacheKey) {
        return $script:LWAchievementDisplayCountsCache
    }

    $eligibleCount = 0
    $eligibleUnlockedCount = 0
    foreach ($definition in @(Get-LWAchievementDefinitions)) {
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition)) {
            continue
        }

        $eligibleCount++
        if (Test-LWAchievementUnlocked -Id ([string]$definition.Id)) {
            $eligibleUnlockedCount++
        }
    }

    $script:LWAchievementDisplayCountsCache = [pscustomobject]@{
        Key                   = $cacheKey
        EligibleCount         = $eligibleCount
        EligibleUnlockedCount = $eligibleUnlockedCount
    }

    return $script:LWAchievementDisplayCountsCache
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

function New-LWAchievementEvaluationContext {
    param([string]$Context = 'general')

    if (-not (Test-LWHasState)) {
        return $null
    }

    Ensure-LWAchievementState -State $script:GameState
    $contextName = if ([string]::IsNullOrWhiteSpace($Context)) { 'general' } else { $Context.Trim().ToLowerInvariant() }

    $unlockedById = @{}
    foreach ($entry in @($script:GameState.Achievements.Unlocked)) {
        if ($null -ne $entry -and (Test-LWPropertyExists -Object $entry -Name 'Id') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Id)) {
            $unlockedById[[string]$entry.Id] = $true
        }
    }

    $storyFlags = @{}
    if ($null -ne $script:GameState.Achievements.StoryFlags) {
        foreach ($property in @($script:GameState.Achievements.StoryFlags.PSObject.Properties)) {
            $storyFlags[[string]$property.Name] = [bool]$property.Value
        }
    }

    $contextData = [ordered]@{
        Flags        = $script:GameState.Achievements.ProgressFlags
        StoryFlags   = $storyFlags
        UnlockedById = $unlockedById
    }

    switch ($contextName) {
        'section' {
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'sectionmove' {
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'healing' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'inventory' { }
        'gold' { }
        'meal' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'hunting' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'starvation' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'potion' {
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'rewind' {
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'recovery' {
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        'death' { }
        'combat' {
            $contextData.RunEntries = @(Get-LWRunCombatEntries)
            $contextData.RunVictories = @(Get-LWRunVictoryEntries)
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
        default {
            $contextData.RunEntries = @(Get-LWRunCombatEntries)
            $contextData.RunVictories = @(Get-LWRunVictoryEntries)
            $contextData.BookSummaries = @(Get-LWAllAchievementBookSummaries)
            $contextData.CompletedBookSummaries = @(Get-LWCompletedAchievementBookSummaries)
            $contextData.CurrentSummary = Get-LWLiveBookStatsSummary
        }
    }

    return [pscustomobject]$contextData
}

function Test-LWAchievementSyncSuppressed {
    param([string]$Context = '')

    if ([string]::IsNullOrWhiteSpace($Context)) {
        return $false
    }

    if (-not (Test-Path Variable:\script:LWAchievementSyncSuppression) -or $null -eq $script:LWAchievementSyncSuppression) {
        return $false
    }

    $contextName = $Context.Trim().ToLowerInvariant()
    return ($script:LWAchievementSyncSuppression.ContainsKey($contextName) -and [bool]$script:LWAchievementSyncSuppression[$contextName])
}

function Get-LWAchievementDefinitionsForContext {
    param(
        [string]$Context = 'general',
        [object]$State = $script:GameState
    )

    $definitions = @(Get-LWAchievementDefinitions)
    $contextName = if ([string]::IsNullOrWhiteSpace($Context)) { 'general' } else { $Context.Trim().ToLowerInvariant() }
    $bookNumber = if ($null -ne $State -and $null -ne $State.Character -and $null -ne $State.Character.BookNumber) { [int]$State.Character.BookNumber } else { 0 }
    $ruleSet = if ($null -ne $State -and -not [string]::IsNullOrWhiteSpace([string]$State.RuleSet)) { [string]$State.RuleSet } else { 'none' }
    $cacheKey = '{0}|{1}|{2}' -f $contextName, $ruleSet, $bookNumber

    if ($script:LWAchievementContextDefinitionsCache.ContainsKey($cacheKey)) {
        return @($script:LWAchievementContextDefinitionsCache[$cacheKey])
    }

    $result = @()

    switch ($contextName) {
        'section' {
            $globalSectionIds = @(
                'pathfinder',
                'long_road'
            )
            $sectionIds = @($globalSectionIds + (Get-LWBookSectionContextAchievementIds -BookNumber $bookNumber))
            $result = @(
                $definitions |
                Where-Object { $sectionIds -contains [string]$_.Id }
            )
            break
        }
        'sectionmove' {
            $combinedIds = @(
                ((Get-LWAchievementDefinitionsForContext -Context 'section' -State $State) | ForEach-Object { [string]$_.Id })
                ((Get-LWAchievementDefinitionsForContext -Context 'healing' -State $State) | ForEach-Object { [string]$_.Id })
            ) | Sort-Object -Unique
            $result = @(
                $definitions |
                Where-Object { $combinedIds -contains [string]$_.Id }
            )
            break
        }
        'healing' {
            $result = @(
                $definitions |
                Where-Object { @('second_wind', 'lean_healing') -contains [string]$_.Id }
            )
            break
        }
        'inventory' {
            $result = @(
                $definitions |
                Where-Object { @('sun_sword', 'loaded_purse', 'fully_armed', 'relic_hunter') -contains [string]$_.Id }
            )
            break
        }
        'gold' {
            $result = @(
                $definitions |
                Where-Object { @('loaded_purse') -contains [string]$_.Id }
            )
            break
        }
        'meal' {
            $result = @(
                $definitions |
                Where-Object { @('trail_survivor') -contains [string]$_.Id }
            )
            break
        }
        'hunting' {
            $result = @(
                $definitions |
                Where-Object { @('hunters_instinct') -contains [string]$_.Id }
            )
            break
        }
        'starvation' {
            $result = @(
                $definitions |
                Where-Object { @('hard_lessons') -contains [string]$_.Id }
            )
            break
        }
        'potion' {
            $result = @(
                $definitions |
                Where-Object { @('herbal_relief', 'deep_draught') -contains [string]$_.Id }
            )
            break
        }
        'rewind' {
            $result = @(
                $definitions |
                Where-Object { @('true_path', 'iron_wolf') -contains [string]$_.Id }
            )
            break
        }
        'recovery' {
            $result = @(
                $definitions |
                Where-Object { @('iron_wolf') -contains [string]$_.Id }
            )
            break
        }
        'death' {
            $result = @(
                $definitions |
                Where-Object { @('still_standing', 'unbroken', 'iron_wolf') -contains [string]$_.Id }
            )
            break
        }
        default {
            $result = @($definitions)
            break
        }
    }

    $script:LWAchievementContextDefinitionsCache[$cacheKey] = @($result)
    return @($result)
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
    Clear-LWAchievementDisplayCountsCache

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
    param(
        [Parameter(Mandatory = $true)][object]$Definition,
        [object]$EvaluationContext = $null
    )

    if (-not (Test-LWHasState)) {
        return $false
    }

    $runEntries = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'RunEntries')) { @($EvaluationContext.RunEntries) } else { @(Get-LWRunCombatEntries) }
    $runVictories = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'RunVictories')) { @($EvaluationContext.RunVictories) } else { @(Get-LWRunVictoryEntries) }
    $bookSummaries = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'BookSummaries')) { @($EvaluationContext.BookSummaries) } else { @(Get-LWAllAchievementBookSummaries) }
    $completedBookSummaries = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'CompletedBookSummaries')) { @($EvaluationContext.CompletedBookSummaries) } else { @(Get-LWCompletedAchievementBookSummaries) }
    $currentSummary = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'CurrentSummary')) { $EvaluationContext.CurrentSummary } else { Get-LWLiveBookStatsSummary }
    $flags = if ($null -ne $EvaluationContext -and (Test-LWPropertyExists -Object $EvaluationContext -Name 'Flags') -and $null -ne $EvaluationContext.Flags) { $EvaluationContext.Flags } else { $script:GameState.Achievements.ProgressFlags }

    switch ([string]$Definition.Id) {
        'first_blood' { return (@($runVictories).Count -ge 1) }
        'swift_blade' { return (@($runVictories | Where-Object { [int]$_.RoundCount -eq 1 }).Count -ge 1) }
        'untouchable' { return ([int]$flags.PerfectVictories -ge 1) }
        'against_the_odds' { return ([int]$flags.AgainstOddsVictories -ge 1) }
        'mind_over_matter' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Mindblast') -and $_.Mindblast }).Count -ge 1) }
        'giant_slayer' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'EnemyCombatSkill') -and $null -ne $_.EnemyCombatSkill -and [int]$_.EnemyCombatSkill -ge 18 }).Count -ge 1) }
        'monster_hunter' { return (@($runVictories | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'EnemyEnduranceMax') -and $null -ne $_.EnemyEnduranceMax -and [int]$_.EnemyEnduranceMax -ge 30 }).Count -ge 1) }
        'back_from_the_brink' { return ([int]$flags.BrinkVictories -ge 1) }
        'kai_veteran' { return (@($runVictories).Count -ge 10) }
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
        'all_too_easy' { return ((Get-LWCurrentDifficulty) -eq 'Story' -and @($runVictories).Count -ge 1) }
        'bedtime_tale' { return (@($completedBookSummaries | Where-Object { [int]$_.BookNumber -eq 1 -and (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Story' }).Count -ge 1) }
        'hard_road' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Hard' }).Count -ge 1) }
        'lean_healing' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Hard' -and (Test-LWPropertyExists -Object $_ -Name 'HealingEnduranceRestored') -and [int]$_.HealingEnduranceRestored -ge 10 }).Count -ge 1) }
        'veteran_of_sommerlund' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Veteran' }).Count -ge 1) }
        'by_the_text' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and [string]$_.Difficulty -eq 'Veteran' }).Count -ge 1) }
        'only_one_life' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Permadeath') -and [bool]$_.Permadeath }).Count -ge 1) }
        'mortal_wolf' { return (@($completedBookSummaries | Where-Object { (Test-LWPropertyExists -Object $_ -Name 'Permadeath') -and [bool]$_.Permadeath -and (Test-LWPropertyExists -Object $_ -Name 'Difficulty') -and @('Hard', 'Veteran') -contains [string]$_.Difficulty }).Count -ge 1) }
        'aim_for_the_bushes' { return (Test-LWAchievementStoryFlag -Name 'Book1AimForTheBushesVisited' -EvaluationContext $EvaluationContext) }
        'found_the_clubhouse' { return (Test-LWAchievementStoryFlag -Name 'Book1ClubhouseFound' -EvaluationContext $EvaluationContext) }
        'kill_the_mad_butcher' { return (@($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 1 -and [string]$_.EnemyName -ieq 'Mad Butcher' }).Count -ge 1) }
        'whats_in_the_box_book1' { return (Test-LWAchievementStoryFlag -Name 'Book1SilverKeyClaimed' -EvaluationContext $EvaluationContext) }
        'use_the_force' { return (Test-LWAchievementStoryFlag -Name 'Book1UseTheForcePath' -EvaluationContext $EvaluationContext) }
        'straight_to_the_throne' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWAchievementStoryFlag -Name 'Book1StraightToTheThrone' -EvaluationContext $EvaluationContext)) }
        'royal_recovery' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWAchievementStoryFlag -Name 'Book1RoyalRecovery' -EvaluationContext $EvaluationContext)) }
        'the_back_way_in' { return ((@($script:GameState.Character.CompletedBooks) -contains 1) -and (Test-LWAchievementStoryFlag -Name 'Book1BackWayIn' -EvaluationContext $EvaluationContext)) }
        'open_sesame' { return (Test-LWAchievementStoryFlag -Name 'Book1OpenSesameRoute' -EvaluationContext $EvaluationContext) }
        'hot_hands' { return (Test-LWAchievementStoryFlag -Name 'Book1HotHandsClaimed' -EvaluationContext $EvaluationContext) }
        'star_of_toran' { return (Test-LWAchievementStoryFlag -Name 'Book1StarOfToranClaimed' -EvaluationContext $EvaluationContext) }
        'field_medic' { return (Test-LWAchievementStoryFlag -Name 'Book1FieldMedicPath' -EvaluationContext $EvaluationContext) }
        'found_the_sommerswerd' { return (Test-LWAchievementStoryFlag -Name 'Book2SommerswerdClaimed' -EvaluationContext $EvaluationContext) }
        'you_have_chosen_wisely' { return (@($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 2 -and (Test-LWPropertyExists -Object $_ -Name 'Section') -and [int]$_.Section -eq 158 -and [string]$_.EnemyName -ieq 'Priest' }).Count -ge 1) }
        'neo_link' { return (@($runVictories | Where-Object { (Get-LWCombatEntryBookNumber -Entry $_) -eq 2 -and (Test-LWPropertyExists -Object $_ -Name 'Section') -and [int]$_.Section -eq 270 -and @('Ganon + Dorier', 'Ganon & Dorier', 'Ganon and Dorier') -contains [string]$_.EnemyName }).Count -ge 1) }
        'by_a_thread' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2ByAThreadRoute' -EvaluationContext $EvaluationContext)) }
        'skyfall' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2SkyfallRoute' -EvaluationContext $EvaluationContext)) }
        'fight_through_the_smoke' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2FightThroughTheSmokeRoute' -EvaluationContext $EvaluationContext)) }
        'storm_tossed' { return ((@($script:GameState.Character.CompletedBooks) -contains 2) -and (Test-LWAchievementStoryFlag -Name 'Book2StormTossedSeen' -EvaluationContext $EvaluationContext)) }
        'seal_of_approval' { return ((Test-LWAchievementStoryFlag -Name 'Book2SealOfApprovalRoute' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book2SommerswerdClaimed' -EvaluationContext $EvaluationContext)) }
        'papers_please' { return (Test-LWAchievementStoryFlag -Name 'Book2PapersPleasePath' -EvaluationContext $EvaluationContext) }
        'snakes_why' { return (Test-LWAchievementStoryFlag -Name 'Book3SnakePitVisited' -EvaluationContext $EvaluationContext) }
        'cliffhanger' { return (Test-LWAchievementStoryFlag -Name 'Book3CliffhangerSeen' -EvaluationContext $EvaluationContext) }
        'whats_in_the_box' { return (Test-LWAchievementStoryFlag -Name 'Book3DiamondClaimed' -EvaluationContext $EvaluationContext) }
        'snowblind' { return (Test-LWAchievementStoryFlag -Name 'Book3SnowblindSeen' -EvaluationContext $EvaluationContext) }
        'you_touched_it_with_your_hands' { return (Test-LWAchievementStoryFlag -Name 'Book3GrossKeyClaimed' -EvaluationContext $EvaluationContext) }
        'lucky_button_theory' { return (Test-LWAchievementStoryFlag -Name 'Book3LuckyButtonTheorySeen' -EvaluationContext $EvaluationContext) }
        'well_it_worked_once' { return (Test-LWAchievementStoryFlag -Name 'Book3WellItWorkedOnceSeen' -EvaluationContext $EvaluationContext) }
        'cellfish' { return (Test-LWAchievementStoryFlag -Name 'Book3CellfishPathTaken' -EvaluationContext $EvaluationContext) }
        'loi_kymar_lives' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3LoiKymarRescued' -EvaluationContext $EvaluationContext)) }
        'puppet_master' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3EffigyEndgameReached' -EvaluationContext $EvaluationContext)) }
        'sun_on_the_ice' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3SommerswerdEndgameUsed' -EvaluationContext $EvaluationContext)) }
        'lucky_break' { return ((@($script:GameState.Character.CompletedBooks) -contains 3) -and (Test-LWAchievementStoryFlag -Name 'Book3LuckyEndgameUsed' -EvaluationContext $EvaluationContext)) }
        'too_slow' { return (Test-LWAchievementStoryFlag -Name 'Book3TooSlowFailureSeen' -EvaluationContext $EvaluationContext) }
        'book_four_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 4) }
        'sun_below_the_earth' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWAchievementStoryFlag -Name 'Book4SunBelowTheEarthRoute' -EvaluationContext $EvaluationContext)) }
        'blessed_be_the_throw' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWAchievementStoryFlag -Name 'Book4BlessedBeTheThrowRoute' -EvaluationContext $EvaluationContext)) }
        'steel_against_shadow' { return ((@($script:GameState.Character.CompletedBooks) -contains 4) -and (Test-LWAchievementStoryFlag -Name 'Book4SteelAgainstShadowRoute' -EvaluationContext $EvaluationContext)) }
        'badge_of_office' { return (Test-LWAchievementStoryFlag -Name 'Book4BadgeOfOfficePath' -EvaluationContext $EvaluationContext) }
        'wearing_the_enemys_colors' { return ((Test-LWAchievementStoryFlag -Name 'Book4OnyxMedallionClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4OnyxBluffRoute' -EvaluationContext $EvaluationContext)) }
        'read_the_signs' { return ((Test-LWAchievementStoryFlag -Name 'Book4ScrollClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4ScrollRoute' -EvaluationContext $EvaluationContext)) }
        'return_to_sender' { return ((Test-LWAchievementStoryFlag -Name 'Book4CaptainSwordClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4ReturnToSenderPath' -EvaluationContext $EvaluationContext)) }
        'deep_pockets_poor_timing' { return (Test-LWAchievementStoryFlag -Name 'Book4BackpackLost' -EvaluationContext $EvaluationContext) }
        'bagless_but_breathing' { return ((Test-LWAchievementStoryFlag -Name 'Book4BackpackLost' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book4BackpackRecovered' -EvaluationContext $EvaluationContext)) }
        'shovel_ready' { return (Test-LWAchievementStoryFlag -Name 'Book4ShovelReadyClaimed' -EvaluationContext $EvaluationContext) }
        'light_in_the_depths' { return (Test-LWAchievementStoryFlag -Name 'Book4LightInTheDepths' -EvaluationContext $EvaluationContext) }
        'chasm_of_doom' { return (Test-LWAchievementStoryFlag -Name 'Book4ChasmOfDoomSeen' -EvaluationContext $EvaluationContext) }
        'washed_away' { return (Test-LWAchievementStoryFlag -Name 'Book4WashedAway' -EvaluationContext $EvaluationContext) }
        'book_five_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 5) }
        'kai_master' { return ((@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5 })).Count -ge 5) }
        'apothecarys_answer' { return ((Test-LWAchievementStoryFlag -Name 'Book5OedeClaimed' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book5LimbdeathCured' -EvaluationContext $EvaluationContext)) }
        'prison_break' { return (Test-LWAchievementStoryFlag -Name 'Book5PrisonBreak' -EvaluationContext $EvaluationContext) }
        'talons_tamed' { return (Test-LWAchievementStoryFlag -Name 'Book5TalonsTamed' -EvaluationContext $EvaluationContext) }
        'star_guided' { return (Test-LWAchievementStoryFlag -Name 'Book5CrystalPendantRoute' -EvaluationContext $EvaluationContext) }
        'name_the_lost' { return ((Test-LWAchievementStoryFlag -Name 'Book5SoushillaNameHeard' -EvaluationContext $EvaluationContext) -and (Test-LWAchievementStoryFlag -Name 'Book5SoushillaAsked' -EvaluationContext $EvaluationContext)) }
        'shadow_on_the_sand' { return ((@($script:GameState.Character.CompletedBooks) -contains 5) -and (Test-LWAchievementStoryFlag -Name 'Book5BanishmentRoute' -EvaluationContext $EvaluationContext)) }
        'face_to_face_with_haakon' { return ((@($script:GameState.Character.CompletedBooks) -contains 5) -and (Test-LWAchievementStoryFlag -Name 'Book5HaakonDuelRoute' -EvaluationContext $EvaluationContext)) }
        'book_six_complete' { return (@($script:GameState.Character.CompletedBooks) -contains 6) }
        'magnakai_rising' { return ((@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5, 6 })).Count -ge 6) }
        'jump_the_wagons' { return (Test-LWAchievementStoryFlag -Name 'Book6JumpTheWagonsRoute' -EvaluationContext $EvaluationContext) }
        'water_bearer' { return (Test-LWAchievementStoryFlag -Name 'Book6TaunorWaterStored' -EvaluationContext $EvaluationContext) }
        'tekaro_cartographer' { return (Test-LWAchievementStoryFlag -Name 'Book6MapOfTekaroClaimed' -EvaluationContext $EvaluationContext) }
        'key_to_varetta' { return (Test-LWAchievementStoryFlag -Name 'Book6SmallSilverKeyClaimed' -EvaluationContext $EvaluationContext) }
        'silver_oak_prize' { return (Test-LWAchievementStoryFlag -Name 'Book6SilverBowClaimed' -EvaluationContext $EvaluationContext) }
        'cess_to_enter' { return (Test-LWAchievementStoryFlag -Name 'Book6CessClaimed' -EvaluationContext $EvaluationContext) }
        'cold_comfort' { return (Test-LWAchievementStoryFlag -Name 'Book6Section306NexusProtected' -EvaluationContext $EvaluationContext) }
        'mind_over_malice_book6' { return (Test-LWAchievementStoryFlag -Name 'Book6Section315MindforceBlocked' -EvaluationContext $EvaluationContext) }
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
        'kai_veteran' { return ("{0}/10 wins" -f @($runVictories).Count) }
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
        'book_six_complete' { return $(if (@($script:GameState.Character.CompletedBooks) -contains 6) { 'Book 6 complete' } else { 'complete Book 6' }) }
        'magnakai_rising' { return ("{0}/6 books complete" -f (@(@($script:GameState.Character.CompletedBooks) | Where-Object { $_ -in 1, 2, 3, 4, 5, 6 }).Count)) }
        'jump_the_wagons' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6JumpTheWagonsRoute') { 'wagon-jump route cleared' } else { 'clear the wagon-jump route in Book 6' }) }
        'water_bearer' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6TaunorWaterStored') { 'Taunor Water stored for later use' } else { 'store Taunor Water for later use in Book 6' }) }
        'tekaro_cartographer' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6MapOfTekaroClaimed') { 'Map of Tekaro claimed' } else { 'claim a Map of Tekaro in Book 6' }) }
        'key_to_varetta' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6SmallSilverKeyClaimed') { 'Small Silver Key claimed' } else { 'claim the Small Silver Key in Book 6' }) }
        'silver_oak_prize' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6SilverBowClaimed') { 'Silver Bow of Duadon claimed' } else { 'win the Silver Bow of Duadon in Book 6' }) }
        'cess_to_enter' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6CessClaimed') { 'Cess claimed' } else { 'pocket a valid Cess for Amory in Book 6' }) }
        'cold_comfort' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected') { 'Nexus has already protected you from the cold' } else { 'reach the frozen-river route with Nexus in Book 6' }) }
        'mind_over_malice_book6' { return $(if (Test-LWStoryAchievementFlag -Name 'Book6Section315MindforceBlocked') { 'Psi-screen blocked the Mindforce assault' } else { 'reach section 315 with Psi-screen' }) }
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

    $evaluationContext = New-LWAchievementEvaluationContext -Context $Context
    $newUnlocks = @()
    foreach ($definition in @(Get-LWAchievementDefinitionsForContext -Context $Context -State $script:GameState)) {
        if ([string]$Context -eq 'load' -and -not [bool]$definition.Backfill) {
            continue
        }
        if (-not (Test-LWAchievementAvailableInCurrentMode -Definition $definition)) {
            continue
        }
        $definitionId = [string]$definition.Id
        if ($null -ne $evaluationContext -and $null -ne $evaluationContext.UnlockedById -and $evaluationContext.UnlockedById.ContainsKey($definitionId)) {
            continue
        }
        if (Test-LWAchievementSatisfied -Definition $definition -EvaluationContext $evaluationContext) {
            $unlocked = Unlock-LWAchievement -Definition $definition -Silent:$Silent
            if ($null -ne $unlocked) {
                if ($null -ne $evaluationContext -and $null -ne $evaluationContext.UnlockedById) {
                    $evaluationContext.UnlockedById[$definitionId] = $true
                }
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

    return (Get-LWAchievementDisplayCounts).EligibleCount
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

function Get-LWAchievementBookDisplayDefinitions {
    param([int]$BookNumber)

    $completionId = switch ($BookNumber) {
        1 { 'book_one_complete' }
        2 { 'book_two_complete' }
        3 { 'book_three_complete' }
        4 { 'book_four_complete' }
        5 { 'book_five_complete' }
        6 { 'book_six_complete' }
        default { $null }
    }

    $ids = @((Get-LWBookSectionContextAchievementIds -BookNumber $BookNumber))
    if (-not [string]::IsNullOrWhiteSpace([string]$completionId)) {
        $ids += $completionId
    }

    return @(
        Get-LWAchievementDefinitions |
        Where-Object { $ids -contains [string]$_.Id }
    )
}

function Show-LWAchievementOverview {
    $definitions = @(Get-LWAchievementDefinitions)
    $profileUnlockedCount = Get-LWAchievementUnlockedCount
    $profileTotalCount = @($definitions).Count
    $eligibleUnlockedCount = Get-LWAchievementEligibleUnlockedCount
    $eligibleCount = Get-LWAchievementEligibleCount
    $recent = @(Get-LWAchievementRecentUnlocks -Count 6)
    $hiddenLockedCount = @(
        $definitions |
        Where-Object {
            (Test-LWPropertyExists -Object $_ -Name 'Hidden') -and [bool]$_.Hidden -and
            -not (Test-LWAchievementUnlocked -Id ([string]$_.Id)) -and
            (Test-LWAchievementAvailableInCurrentMode -Definition $_)
        }
    ).Count
    $currentBook = [int]$script:GameState.Character.BookNumber
    $currentBookDefinitions = @(Get-LWAchievementBookDisplayDefinitions -BookNumber $currentBook)
    $currentBookUnlocked = @($currentBookDefinitions | Where-Object { Test-LWAchievementUnlocked -Id ([string]$_.Id) }).Count
    $currentBookLocked = @($currentBookDefinitions | Where-Object { -not (Test-LWAchievementUnlocked -Id ([string]$_.Id)) }).Count

    Write-LWRetroPanelHeader -Title 'Achievement Status' -AccentColor 'Magenta'
    Write-LWRetroPanelPairRow -LeftLabel 'Unlocked' -LeftValue ("{0} / {1}" -f $eligibleUnlockedCount, $eligibleCount) -RightLabel 'Profile Total' -RightValue ("{0} / {1}" -f $profileUnlockedCount, $profileTotalCount) -LeftColor 'White' -RightColor 'Magenta' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Hidden' -LeftValue ([string]$hiddenLockedCount) -RightLabel 'Book Progress' -RightValue ("Book {0}: {1} / {2}" -f $currentBook, $currentBookUnlocked, $currentBookDefinitions.Count) -LeftColor 'DarkYellow' -RightColor 'White' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Book Totals' -AccentColor 'Cyan'
    $bookRows = @()
    foreach ($bookNumber in @(1..[Math]::Max(1, $currentBook))) {
        $bookDefinitions = @(Get-LWAchievementBookDisplayDefinitions -BookNumber $bookNumber)
        if ($bookDefinitions.Count -eq 0) {
            continue
        }
        $unlockedCount = @($bookDefinitions | Where-Object { Test-LWAchievementUnlocked -Id ([string]$_.Id) }).Count
        $bookRows += [pscustomobject]@{
            Text  = ("Book {0} : {1,2} / {2,2}" -f $bookNumber, $unlockedCount, $bookDefinitions.Count)
            Color = $(if ($bookNumber -eq $currentBook) { 'Yellow' } else { 'Gray' })
        }
    }
    if ($bookRows.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $bookRows.Count; $i += 2) {
            $left = $bookRows[$i]
            $right = if (($i + 1) -lt $bookRows.Count) { $bookRows[$i + 1] } else { $null }
            Write-LWRetroPanelTwoColumnRow -LeftText ([string]$left.Text) -RightText $(if ($null -ne $right) { [string]$right.Text } else { '' }) -LeftColor ([string]$left.Color) -RightColor $(if ($null -ne $right) { [string]$right.Color } else { 'Gray' }) -LeftWidth 28 -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Recent Unlocks' -AccentColor 'DarkYellow'
    if ($recent.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none yet)' -TextColor 'DarkGray'
    }
    else {
        for ($i = 0; $i -lt $recent.Count; $i += 2) {
            $leftText = (Get-LWAchievementUnlockedDisplayName -Entry $recent[$i])
            $rightText = if (($i + 1) -lt $recent.Count) { (Get-LWAchievementUnlockedDisplayName -Entry $recent[$i + 1]) } else { '' }
            Write-LWRetroPanelTwoColumnRow -LeftText $leftText -RightText $rightText -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Current Book Hints' -AccentColor 'Cyan'
    if ($currentBookLocked -gt 0) {
        Write-LWRetroPanelTextRow -Text ("Hidden achievement slots remain in Book {0}." -f $currentBook) -TextColor 'Gray'
        Write-LWRetroPanelTextRow -Text 'Route and DE option choices can affect unlock coverage.' -TextColor 'Gray'
    }
    else {
        Write-LWRetroPanelTextRow -Text ("Book {0} story achievements are fully cleared." -f $currentBook) -TextColor 'Green'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementUnlockedList {
    Write-LWRetroPanelHeader -Title 'Unlocked Achievements' -AccentColor 'Green'
    $entries = @($script:GameState.Achievements.Unlocked)
    if ($entries.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none yet)' -TextColor 'DarkGray'
        Write-LWRetroPanelFooter
        return
    }

    foreach ($entry in $entries) {
        Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f (Get-LWAchievementUnlockedDisplayName -Entry $entry), [string]$entry.Description) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementLockedList {
    Write-LWRetroPanelHeader -Title 'Locked Achievements' -AccentColor 'DarkYellow'
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
        Write-LWRetroPanelTextRow -Text 'No eligible locked achievements remain for this run.' -TextColor 'DarkGray'
    }
    else {
        foreach ($definition in $locked) {
            $progress = Get-LWAchievementProgressText -Definition $definition
            $displayName = Get-LWAchievementLockedDisplayName -Definition $definition
            $displayDescription = Get-LWAchievementLockedDisplayDescription -Definition $definition
            Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f $displayName, $displayDescription) -TextColor 'Gray'
            if (-not [string]::IsNullOrWhiteSpace($progress) -and $displayName -ne '???') {
                Write-LWRetroPanelTextRow -Text ("progress: {0}" -f $progress) -TextColor 'DarkGray'
            }
        }
    }
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Disabled For This Run' -AccentColor 'DarkGray'
    if ($disabled.Count -eq 0) {
        Write-LWRetroPanelTextRow -Text '(none)' -TextColor 'DarkGray'
    }
    else {
        foreach ($definition in $disabled) {
            $reason = Get-LWAchievementAvailabilityReason -Definition $definition
            $displayName = Get-LWAchievementLockedDisplayName -Definition $definition
            $displayDescription = Get-LWAchievementLockedDisplayDescription -Definition $definition
            Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f $displayName, $displayDescription) -TextColor 'Gray'
            if (-not [string]::IsNullOrWhiteSpace($reason)) {
                Write-LWRetroPanelTextRow -Text $reason -TextColor 'DarkGray'
            }
        }
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementProgressList {
    Write-LWRetroPanelHeader -Title 'Achievement Progress' -AccentColor 'Cyan'
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
        Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f (Get-LWAchievementLockedDisplayName -Definition $definition), $progress) -TextColor 'Gray'
    }

    if (-not $anyShown) {
        Write-LWRetroPanelTextRow -Text 'No tracked progress milestones are pending for the current run.' -TextColor 'DarkGray'
    }

    if ($disabledCount -gt 0) {
        Write-LWRetroPanelTextRow -Text ("{0} achievements are currently disabled by this run's mode settings." -f $disabledCount) -TextColor 'DarkGray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementPlannedList {
    Write-LWRetroPanelHeader -Title 'Planned Achievements' -AccentColor 'DarkMagenta'
    foreach ($entry in @(Get-LWPhaseTwoAchievementPlans)) {
        Write-LWRetroPanelTextRow -Text ("{0} - {1}" -f [string]$entry.Name, [string]$entry.Description) -TextColor 'Gray'
    }
    Write-LWRetroPanelFooter
}

function Show-LWAchievementsScreen {
    Invoke-LWCoreShowAchievementsScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
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

    switch ($Type) {
        'weapon' { return 'Weapons' }
        'backpack' { return 'Backpack' }
        'herbpouch' { return 'Herb Pouch' }
        'special' { return 'Special Items' }
    }
}

function Get-LWInventoryTypeColor {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return 'Green' }
        'backpack' { return 'Yellow' }
        'herbpouch' { return 'DarkGreen' }
        'special' { return 'DarkCyan' }
    }
}

function Get-LWInventoryTypeCapacity {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

    switch ($Type) {
        'weapon' { return 2 }
        'backpack' { return 8 }
        'herbpouch' { return 6 }
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
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
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
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

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

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    if (-not (Test-LWPropertyExists -Object $script:GameState.Inventory -Name 'PocketSpecialItems') -or $null -eq $script:GameState.Inventory.PocketSpecialItems) {
        $script:GameState.Inventory | Add-Member -Force -NotePropertyName PocketSpecialItems -NotePropertyValue @()
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name
    $current = @(Get-LWPocketSpecialItems)
    if (@($current | ForEach-Object { Get-LWCanonicalInventoryItemName -Name ([string]$_) }) -icontains $resolvedName) {
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
    $herbPouch = @($State.Storage.Confiscated.HerbPouchItems)
    $special = @($State.Storage.Confiscated.SpecialItems)
    $pocket = if ((Test-LWPropertyExists -Object $State.Storage.Confiscated -Name 'PocketSpecialItems') -and $null -ne $State.Storage.Confiscated.PocketSpecialItems) { @($State.Storage.Confiscated.PocketSpecialItems) } else { @() }
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
    $restoredPocketSpecialItems = if ((Test-LWPropertyExists -Object $script:GameState.Storage.Confiscated -Name 'PocketSpecialItems') -and $null -ne $script:GameState.Storage.Confiscated.PocketSpecialItems) { @($script:GameState.Storage.Confiscated.PocketSpecialItems) } else { @() }
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

    switch ($Type) {
        'weapon' { return 'Weapon' }
        'backpack' { return 'Backpack' }
        'herbpouch' { return 'HerbPouch' }
        'special' { return 'Special' }
    }
}

function Get-LWRecoveryStashEntry {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

    $propertyName = Get-LWRecoveryStashPropertyName -Type $Type
    return $script:GameState.RecoveryStash.$propertyName
}

function Save-LWInventoryRecoveryEntry {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
        [Parameter(Mandatory = $true)][object[]]$Items
    )

    $entry = Get-LWRecoveryStashEntry -Type $Type
    $entry.Items = @($Items)
    $entry.BookNumber = [int]$script:GameState.Character.BookNumber
    $entry.Section = [int]$script:GameState.CurrentSection
    $entry.SavedOn = (Get-Date).ToString('o')
}

function Clear-LWInventoryRecoveryEntry {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

    $entry = Get-LWRecoveryStashEntry -Type $Type
    $entry.Items = @()
    $entry.BookNumber = $null
    $entry.Section = $null
    $entry.SavedOn = $null
}

function Get-LWInventoryRecoveryItems {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

    return @((Get-LWRecoveryStashEntry -Type $Type).Items)
}

function Show-LWInventorySlotsSection {
    param([Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type)

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

    $items = if ($null -eq $Items) { @(Get-LWInventoryItems -Type $Type) } else { @($Items) }
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

    if ($Type -eq 'herbpouch' -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        return
    }

    $capacity = Get-LWInventoryTypeCapacity -Type $Type
    $title = Get-LWInventoryTypeLabel -Type $Type
    $accentColor = Get-LWInventoryTypeColor -Type $Type
    $items = @(Get-LWInventoryItems -Type $Type)
    $leftColumnCount = [int][Math]::Ceiling([double]$capacity / 2.0)

    Write-LWRetroPanelHeader -Title $title -AccentColor $accentColor
    for ($row = 1; $row -le $leftColumnCount; $row++) {
        $leftSlot = $row
        $rightSlot = $row + $leftColumnCount
        $leftText = ("{0,2}. {1}" -f $leftSlot, (Get-LWInventorySlotDisplayText -Type $Type -Slot $leftSlot -Items $items))
        $rightText = if ($rightSlot -le $capacity) {
            ("{0,2}. {1}" -f $rightSlot, (Get-LWInventorySlotDisplayText -Type $Type -Slot $rightSlot -Items $items))
        }
        else {
            ''
        }

        Write-LWRetroPanelTwoColumnRow `
            -LeftText $leftText `
            -RightText $rightText `
            -LeftColor $(if ($leftText -like '*. (empty)' -or $leftText -like '*. (unavailable)') { 'DarkGray' } else { 'Gray' }) `
            -RightColor $(if ([string]::IsNullOrWhiteSpace($rightText) -or $rightText -like '*. (empty)' -or $rightText -like '*. (unavailable)') { 'DarkGray' } else { 'Gray' }) `
            -LeftWidth 28 `
            -Gap 2
    }
    Write-LWRetroPanelFooter
}

function Show-LWInventorySummary {
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
        $rows += [pscustomobject]@{
            Label = 'Quiver'
            Value = ("{0} arrows for Bow" -f (Format-LWQuiverArrowCounter -State $script:GameState))
        }
    }

    return @($rows)
}

function Show-LWInventoryNotesPanel {
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
    Invoke-LWCoreShowInventoryScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
}

function Show-LWSheet {
    Invoke-LWCoreShowSheetScreen -Context @{
        GameState = $script:GameState
        LWUi      = $script:LWUi
    }
}

function Resolve-LWSectionExit {
    if (-not (Test-LWHasState)) {
        return
    }

    if ($script:GameState.SectionHealingResolved) {
        return
    }

    if ((Test-LWStateHasSectionHealing -State $script:GameState) -and -not $script:GameState.SectionHadCombat) {
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
                Write-LWInfo ("{0} restores 1 Endurance for a non-combat section." -f (Get-LWSectionHealingSourceLabel -State $script:GameState))
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
    $previousSuppression = if (Test-Path Variable:\script:LWAchievementSyncSuppression) { $script:LWAchievementSyncSuppression } else { $null }
    $script:LWAchievementSyncSuppression = @{ section = $true; healing = $true }
    try {
        Resolve-LWSectionExit
        Register-LWStorySectionTransitionAchievementTriggers -FromSection $previousSection -ToSection $newSection
        $script:GameState.CurrentSection = $newSection
        $script:GameState.SectionHadCombat = $false
        $script:GameState.SectionHealingResolved = $false
        Add-LWBookSectionVisit -Section $newSection
        [void](Sync-LWAchievements -Context 'sectionmove')
        if ([int]$script:GameState.Character.BookNumber -eq 5) {
            if (-not (Invoke-LWBookFiveBloodPoisoningSectionDamage -Section $newSection)) {
                Write-LWInfo "Moved to section $newSection."
                Invoke-LWMaybeAutosave
                return
            }
        }
        Invoke-LWSectionEntryRules
        if (Test-LWDeathActive) {
            return
        }
        Write-LWInfo "Moved to section $newSection."
        Invoke-LWMaybeAutosave
    }
    finally {
        $script:LWAchievementSyncSuppression = $previousSuppression
    }
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
        [Parameter(Mandatory = $true)][ValidateSet('weapon', 'backpack', 'herbpouch', 'special')][string]$Type,
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
    if ($Type -eq 'special' -and $Quantity -gt 1) {
        Write-LWWarn 'Special Items cannot be stacked. Add them one at a time.'
        return
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

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
    if ($Type -eq 'special' -and (@($current | ForEach-Object { Get-LWCanonicalInventoryItemName -Name ([string]$_) }) -icontains $resolvedName)) {
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

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWQuiverItemNames) -Target $resolvedName))) {
        $script:GameState.Inventory.QuiverArrows = Get-LWQuiverArrowCapacity
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

    if (-not (Test-LWHasState) -or [string]::IsNullOrWhiteSpace($Name) -or $Quantity -lt 1) {
        return $false
    }
    if ($Type -eq 'special' -and $Quantity -gt 1) {
        Write-LWWarn 'Special Items cannot be stacked. Add them one at a time.'
        return $false
    }

    $resolvedName = Get-LWCanonicalInventoryItemName -Name $Name

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
    if ($Type -eq 'special' -and (@($current | ForEach-Object { Get-LWCanonicalInventoryItemName -Name ([string]$_) }) -icontains $resolvedName)) {
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

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWQuiverItemNames) -Target $resolvedName))) {
        $script:GameState.Inventory.QuiverArrows = Get-LWQuiverArrowCapacity
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

    if ($Type -eq 'special' -and -not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWQuiverItemNames) -Target $Name)) -and -not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWQuiverItemNames) -Type 'special')) {
        $script:GameState.Inventory.QuiverArrows = 0
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

function Update-LWQuiverArrows {
    param([Nullable[int]]$Delta = $null)

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if (-not (Test-LWStateHasQuiver -State $script:GameState)) {
        Write-LWWarn 'You are not carrying a Quiver.'
        return
    }

    if ($null -eq $Delta) {
        $Delta = Read-LWInt -Prompt 'Arrow change (+/-)' -Default 0
    }

    $requestedDelta = [int]$Delta
    $current = Sync-LWQuiverArrowState -State $script:GameState
    $capacity = Get-LWQuiverArrowCapacity
    $newValue = [Math]::Max(0, [Math]::Min(($current + $requestedDelta), $capacity))
    $actualDelta = $newValue - $current
    $script:GameState.Inventory.QuiverArrows = $newValue

    $message = "Quiver arrows changed by $(Format-LWSigned -Value $actualDelta). Now $(Format-LWQuiverArrowCounter -State $script:GameState)."
    if ($actualDelta -ne $requestedDelta) {
        $message += ' Adjustment was capped by 0 or quiver capacity.'
    }

    Write-LWInfo $message
    Invoke-LWMaybeAutosave
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
        if (Test-LWCombatHerbPouchOptionActive -State $script:GameState) {
            Invoke-LWCombatPotionRound
            return
        }
        Write-LWWarn 'Healing Potions cannot be used during combat.'
        return
    }

    if (-not (Test-LWStateHasBackpack -State $script:GameState) -and -not (Test-LWStateHasHerbPouch -State $script:GameState)) {
        Write-LWWarn 'You do not currently have a Backpack or a usable Herb Pouch, so you cannot use stored healing items right now.'
        return
    }

    $choice = Select-LWHealingPotionChoice -State $script:GameState
    if ($null -eq $choice) {
        return
    }

    [void](Use-LWResolvedHealingPotion -PotionName ([string]$choice.Name) -RestoreAmount ([int]$choice.RestoreAmount) -InventoryType ([string]$choice.Type))
}

function Get-LWStateAletherPotionName {
    param([Parameter(Mandatory = $true)][object]$State)

    $location = Find-LWStateInventoryItemLocation -State $State -Names @((Get-LWAletherPotionItemNames) + (Get-LWAletherBerryItemNames)) -Types @('herbpouch', 'backpack')
    if ($null -eq $location) {
        return $null
    }

    return [string]$location.Name
}

function Get-LWStateAletherCombatSkillBonus {
    param([Parameter(Mandatory = $true)][object]$State)

    if (-not (Test-LWCombatAletherAvailable -State $State)) {
        return 0
    }

    return [int]$State.Combat.AletherCombatSkillBonus
}

function Get-LWCombatPlayerEndurancePool {
    param([Parameter(Mandatory = $true)][object]$State)

    $usesTarget = ((Test-LWPropertyExists -Object $State -Name 'Combat') -and
        (Test-LWPropertyExists -Object $State.Combat -Name 'UsePlayerTargetEndurance') -and
        [bool]$State.Combat.UsePlayerTargetEndurance)

    if ($usesTarget) {
        $current = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerTargetEnduranceCurrent') -and $null -ne $State.Combat.PlayerTargetEnduranceCurrent) { [int]$State.Combat.PlayerTargetEnduranceCurrent } else { 0 }
        $max = if ((Test-LWPropertyExists -Object $State.Combat -Name 'PlayerTargetEnduranceMax') -and $null -ne $State.Combat.PlayerTargetEnduranceMax) { [int]$State.Combat.PlayerTargetEnduranceMax } else { $current }
        return [pscustomobject]@{
            UsesTarget = $true
            Current    = $current
            Max        = $max
            Label      = 'Target'
        }
    }

    return [pscustomobject]@{
        UsesTarget = $false
        Current    = [int]$State.Character.EnduranceCurrent
        Max        = [int]$State.Character.EnduranceMax
        Label      = 'Endurance'
    }
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
    elseif ((Test-LWPropertyExists -Object $State.Combat -Name 'SuppressShieldCombatSkillBonus') -and
        [bool]$State.Combat.SuppressShieldCombatSkillBonus -and
        (Test-LWStateHasInventoryItem -State $State -Names (Get-LWShieldItemNames))) {
        $notes += 'Shield suppressed'
    }

    $silverHelmBonus = Get-LWStateSilverHelmCombatSkillBonus -State $State
    if ($silverHelmBonus -gt 0) {
        $playerCombatSkill += $silverHelmBonus
        $notes += "Silver Helm +$silverHelmBonus"
    }

    if ($State.Combat.UseMindblast) {
        $psychicBonus = Get-LWCombatPsychicAttackBonus -State $State
        $psychicLabel = Get-LWCombatPsychicAttackLabel -State $State
        $playerCombatSkill += $psychicBonus
        $notes += "$psychicLabel +$psychicBonus"
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

        $broninWarhammerBonus = Get-LWStateBroninWarhammerCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($broninWarhammerBonus -gt 0) {
            $playerCombatSkill += $broninWarhammerBonus
            $notes += "Bronin Warhammer +$broninWarhammerBonus"
        }

        $captainDValSwordBonus = Get-LWStateCaptainDValSwordCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($captainDValSwordBonus -gt 0) {
            $playerCombatSkill += $captainDValSwordBonus
            $notes += "Captain D'Val's Sword +$captainDValSwordBonus"
        }

        $solnarisBonus = Get-LWStateSolnarisCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($solnarisBonus -gt 0) {
            $playerCombatSkill += $solnarisBonus
            $notes += "Solnaris +$solnarisBonus"
        }

        $weaponmasteryBonus = Get-LWStateWeaponmasteryCombatSkillBonus -State $State -Weapon ([string]$State.Combat.EquippedWeapon)
        if ($weaponmasteryBonus -gt 0) {
            $playerCombatSkill += $weaponmasteryBonus
            $notes += "Weaponmastery +$weaponmasteryBonus"
        }

        if ((Test-LWStateHasActiveWeaponskill -State $State) -and (Test-LWWeaponMatchesWeaponskill -Weapon ([string]$State.Combat.EquippedWeapon) -WeaponskillWeapon ([string]$State.Character.WeaponskillWeapon))) {
            $playerCombatSkill += 2
            $weaponskillLabel = if ((Test-LWWeaponIsDrodarinWarHammer -Weapon ([string]$State.Combat.EquippedWeapon)) -or (Test-LWWeaponIsBroninWarhammer -Weapon ([string]$State.Combat.EquippedWeapon))) { 'Warhammer' } elseif (Test-LWWeaponIsBroadswordPlusOne -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Broadsword' } elseif (Test-LWWeaponIsCaptainDValSword -Weapon ([string]$State.Combat.EquippedWeapon)) { 'Sword' } elseif (Test-LWWeaponIsSolnaris -Weapon ([string]$State.Combat.EquippedWeapon)) { [string]$State.Character.WeaponskillWeapon } else { [string]$State.Combat.EquippedWeapon }
            $notes += "Weaponskill +2 ($weaponskillLabel)"
        }
    }

    if ([bool]$State.Combat.EnemyUsesMindforce) {
        if (Test-LWCombatMindforceBlockedByMindshield -State $State) {
            $notes += ("Mindforce blocked by {0}" -f $(if (Test-LWStateHasDiscipline -State $State -Name 'Psi-screen') { 'Psi-screen' } else { 'Mindshield' }))
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

    $playerEndurancePool = Get-LWCombatPlayerEndurancePool -State $State
    if ([bool]$playerEndurancePool.UsesTarget) {
        $notes += 'Target points combat'
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
    if (Test-LWWeaponIsBroninWarhammer -Weapon $Weapon) {
        return 'Bronin Warhammer'
    }
    if (Test-LWWeaponIsBroadswordPlusOne -Weapon $Weapon) {
        return 'Broadsword +1'
    }
    if (Test-LWWeaponIsBoneSword -Weapon $Weapon) {
        return 'Bone Sword'
    }
    if (Test-LWWeaponIsSolnaris -Weapon $Weapon) {
        return 'Solnaris'
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

    Show-LWHelpfulCommandsPanel -ScreenName 'combat'
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

function Get-LWCombatRoundSummaryText {
    param([Parameter(Mandatory = $true)][object]$Round)

    return ("R{0}  Ratio {1}   You lose {2}   Enemy loses {3}" -f [int]$Round.Round, (Format-LWSigned -Value ([int]$Round.Ratio)), [int]$Round.PlayerLoss, [int]$Round.EnemyLoss)
}

function Show-LWCombatRecentRounds {
    param(
        [object[]]$Rounds = @(),
        [int]$Count = 3,
        [string]$Title = 'Recent Rounds'
    )

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

    $notes = @($Notes | ForEach-Object { [string]$_ })
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
    if ($overflowRuleNotes.Count -gt 0) {
        Write-LWRetroPanelWrappedKeyValueRows -Label 'Notes' -Value ($overflowRuleNotes -join ' | ') -ValueColor 'Gray' -LabelWidth 13
    }
    Write-LWRetroPanelFooter
}

function Get-LWCurrentCombatLogEntry {
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

function Show-LWCombatStatus {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat.'
        return
    }

    $breakdown = Get-LWCombatBreakdown
    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $mindforceStatus = Get-LWCombatMindforceStatusText -State $script:GameState
    $knockoutStatus = if ([bool]$script:GameState.Combat.AttemptKnockout) { 'Attempt in progress' } else { 'Off' }
    $evadeStatus = Get-LWCombatEvadeStatusText -State $script:GameState

    Write-LWRetroPanelHeader -Title 'Combat Status' -AccentColor 'Red'
    Write-LWRetroPanelKeyValueRow -Label 'Enemy' -Value ([string]$script:GameState.Combat.EnemyName) -ValueColor 'White'
    Write-LWRetroPanelPairRow -LeftLabel 'Section' -LeftValue ([string]$script:GameState.CurrentSection) -RightLabel 'Combat Round' -RightValue ([string]@($script:GameState.Combat.Log).Count) -LeftColor 'White' -RightColor 'Gray' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Combat Ratio' -LeftValue (Format-LWSigned -Value ([int]$breakdown.CombatRatio)) -RightLabel 'Result' -RightValue 'In Progress' -LeftColor (Get-LWCombatRatioColor -Ratio ([int]$breakdown.CombatRatio)) -RightColor 'Cyan' -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelPairRow -LeftLabel 'Evade' -LeftValue $evadeStatus -RightLabel 'Mindforce' -RightValue $(if ($mindforceStatus -like 'Blocked*') { 'Blocked' } elseif ($mindforceStatus -like 'Active*') { 'Active' } else { $mindforceStatus }) -LeftColor $(if ($evadeStatus -eq 'No') { 'Gray' } else { 'Yellow' }) -RightColor $(if ($mindforceStatus -like 'Active*') { 'Red' } elseif ($mindforceStatus -like 'Blocked*') { 'Cyan' } else { 'Gray' }) -LeftLabelWidth 13 -RightLabelWidth 13 -LeftWidth 29 -Gap 2
    Write-LWRetroPanelFooter

    Show-LWCombatDuelPanel -Title 'Player / Enemy' -EnemyName ([string]$script:GameState.Combat.EnemyName) -PlayerCurrent ([int]$playerPool.Current) -PlayerMax ([int]$playerPool.Max) -EnemyCurrent ([int]$script:GameState.Combat.EnemyEnduranceCurrent) -EnemyMax ([int]$script:GameState.Combat.EnemyEnduranceMax) -PlayerCombatSkill ([int]$breakdown.PlayerCombatSkill) -EnemyCombatSkill ([int]$breakdown.EnemyCombatSkill) -CombatRatio ([int]$breakdown.CombatRatio) -RoundCount (@($script:GameState.Combat.Log).Count)
    Show-LWCombatTacticalPanel -Weapon (Get-LWCombatDisplayWeapon -Weapon $script:GameState.Combat.EquippedWeapon) -UseMindblast:([bool]$script:GameState.Combat.UseMindblast) -PsychicAttackLabel (Get-LWCombatPsychicAttackLabel -State $script:GameState) -EnemyIsUndead:([bool]$script:GameState.Combat.EnemyIsUndead) -MindforceStatus $mindforceStatus -KnockoutStatus $knockoutStatus -EvadeStatus $evadeStatus -Mode ([string]$script:GameState.Settings.CombatMode) -Notes @($breakdown.Notes) -BowStatus $(if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'BowRestricted') -and [bool]$script:GameState.Combat.BowRestricted) { 'Locked' } else { '' }) -PotionStatus $(if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and -not [bool]$script:GameState.Combat.CombatPotionsAllowed) { 'Locked' } else { '' }) -UsesSommerswerd:(Test-LWCombatUsesSommerswerd -State $script:GameState) -SommerswerdSuppressed:([bool]$script:GameState.Combat.SommerswerdSuppressed)
    Show-LWCombatRecentRounds -Rounds @($script:GameState.Combat.Log) -Count 4 -Title 'Round History'
    Show-LWCombatPromptHint
}

function Resolve-LWCombatRound {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [Parameter(Mandatory = $true)][int]$Roll,
        [Nullable[int]]$EnemyLoss = $null,
        [Nullable[int]]$PlayerLoss = $null,
        [switch]$IgnoreEnemyLossThisRound,
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
            $playerEndurancePool = Get-LWCombatPlayerEndurancePool -State $State
            $PlayerLoss = Convert-LWCRTLossValue -Value $crtResult.PlayerLossRaw -CurrentEndurance ([int]$playerEndurancePool.Current)
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
    $playerEndurancePool = Get-LWCombatPlayerEndurancePool -State $State
    $currentPlayerEnd = [int]$playerEndurancePool.Current
    $mindforceBaseLoss = 0
    $mindforceAppliedLoss = 0
    $specialBaseLoss = 0
    $specialAppliedLoss = 0
    $psychicBaseLoss = 0
    $psychicAppliedLoss = 0
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
    if ($IgnoreEnemyLossThisRound) {
        if ($enemyLossApplied -gt 0) {
            $messages += 'Herb Pouch action: you drink a potion instead of attacking, so enemy ENDURANCE loss is ignored this round.'
        }
        else {
            $messages += 'Herb Pouch action: you drink a potion instead of attacking this round.'
        }
        $enemyLossApplied = 0
        $specialNotes += 'Potion round'
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

    $psychicDrain = Get-LWCombatPsychicAttackEnduranceDrain -State $State
    if ([bool]$State.Combat.UseMindblast -and $psychicDrain -gt 0) {
        $psychicBaseLoss = $psychicDrain
        $psychicResolution = Resolve-LWGameplayEnduranceLoss -Loss $psychicBaseLoss -Source 'combat' -State $State
        $remainingAfterAllHazards = [Math]::Max(0, ($currentPlayerEnd - $combatPlayerLossApplied - $mindforceAppliedLoss - $specialAppliedLoss))
        $psychicAppliedLoss = [Math]::Min($remainingAfterAllHazards, [int]$psychicResolution.AppliedLoss)
        if ($psychicAppliedLoss -gt 0) {
            $specialNotes += 'Psi-surge drain'
            $messages += ("Psi-surge costs {0} END." -f $psychicAppliedLoss)
        }
        else {
            $messages += 'Psi-surge is active, but no END is lost.'
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$psychicResolution.Note)) {
            $messages += [string]$psychicResolution.Note
        }
    }

    $totalPlayerLossApplied = $combatPlayerLossApplied + $mindforceAppliedLoss + $specialAppliedLoss + $psychicAppliedLoss
    $totalPlayerLossBase = [int]$PlayerLoss + $mindforceBaseLoss + $specialBaseLoss + $psychicBaseLoss
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
        $psychicAppliedLoss = 0
        $totalPlayerLossApplied = 0
    }

    if ([bool]$State.Combat.JavekPoisonRule -and [int]$PlayerLoss -gt 0) {
        $javekRoll = Get-LWRandomDigit
        Write-LWCurrentSectionRandomNumberRoll -Roll $javekRoll -State $State
        if ($javekRoll -eq 9) {
            $combatPlayerLossApplied = $currentPlayerEnd
            $mindforceAppliedLoss = 0
            $specialAppliedLoss = 0
            $psychicAppliedLoss = 0
            $totalPlayerLossApplied = $currentPlayerEnd
            $messages += 'The Javek''s fangs pierce your padded arm. The venom stops your heart.'
            $specialNotes += 'Javek venom'
        }
        else {
            $combatPlayerLossApplied = 0
            $mindforceAppliedLoss = 0
            $specialAppliedLoss = 0
            $psychicAppliedLoss = 0
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
    elseif ((Test-LWPropertyExists -Object $State.Combat -Name 'EnemyEnduranceThreshold') -and $null -ne $State.Combat.EnemyEnduranceThreshold -and
        (Test-LWPropertyExists -Object $State.Combat -Name 'EnemyEnduranceThresholdSection') -and $null -ne $State.Combat.EnemyEnduranceThresholdSection -and
        $newEnemyEnd -le [int]$State.Combat.EnemyEnduranceThreshold) {
        $outcome = 'Special'
        $specialResolutionSection = [int]$State.Combat.EnemyEnduranceThresholdSection
        $specialResolutionNote = if ((Test-LWPropertyExists -Object $State.Combat -Name 'EnemyEnduranceThresholdNote') -and -not [string]::IsNullOrWhiteSpace([string]$State.Combat.EnemyEnduranceThresholdNote)) { [string]$State.Combat.EnemyEnduranceThresholdNote } else { ("Section result: once the enemy reaches the threshold, turn to {0}." -f $specialResolutionSection) }
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
            PsychicLoss = $psychicAppliedLoss
            PsychicLossBase = $psychicBaseLoss
            EnemyEnd   = $newEnemyEnd
            PlayerEnd  = $newPlayerEnd
            SpecialNote = $(if ($specialNotes.Count -gt 0) { $specialNotes -join ', ' } else { $null })
        }
    }
}

function Apply-LWCombatRoundResolution {
    param([Parameter(Mandatory = $true)][object]$Resolution)

    $script:GameState.Combat.EnemyEnduranceCurrent = $Resolution.NewEnemyEnd
    if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'UsePlayerTargetEndurance') -and [bool]$script:GameState.Combat.UsePlayerTargetEndurance) {
        $script:GameState.Combat.PlayerTargetEnduranceCurrent = $Resolution.NewPlayerEnd
    }
    else {
        $script:GameState.Character.EnduranceCurrent = $Resolution.NewPlayerEnd
    }
    $script:GameState.Combat.Log = @($script:GameState.Combat.Log) + $Resolution.LogEntry
    if ([int]$Resolution.PlayerLoss -gt 0 -and -not ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'UsePlayerTargetEndurance') -and [bool]$script:GameState.Combat.UsePlayerTargetEndurance)) {
        Add-LWBookEnduranceDelta -Delta (-[int]$Resolution.PlayerLoss)
    }

    $equipDeferredAfterRound = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EquipDeferredWeaponAfterRound') -and $null -ne $script:GameState.Combat.EquipDeferredWeaponAfterRound) { [int]$script:GameState.Combat.EquipDeferredWeaponAfterRound } else { 0 }
    $deferredWeapon = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'DeferredEquippedWeapon') -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.DeferredEquippedWeapon)) { [string]$script:GameState.Combat.DeferredEquippedWeapon } else { $null }
    if ($Resolution.Outcome -eq 'Continue' -and $equipDeferredAfterRound -gt 0 -and [int]$Resolution.RoundNumber -ge $equipDeferredAfterRound -and -not [string]::IsNullOrWhiteSpace($deferredWeapon)) {
        $script:GameState.Combat.EquippedWeapon = $deferredWeapon
        $script:GameState.Combat.DeferredEquippedWeapon = $null
        $script:GameState.Combat.EquipDeferredWeaponAfterRound = 0
        $script:GameState.Character.LastCombatWeapon = $deferredWeapon
        Write-LWInfo ("You draw {0} for the next round." -f (Get-LWCombatDisplayWeapon -Weapon $deferredWeapon))
    }
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

    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
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
        $beforeRestore = [int]$playerPool.Current
        $restoredTarget = [Math]::Min([int]$playerPool.Max, ($beforeRestore + $restoreHalfLoss))
        if ([bool]$playerPool.UsesTarget) {
            $script:GameState.Combat.PlayerTargetEnduranceCurrent = $restoredTarget
        }
        else {
            $script:GameState.Character.EnduranceCurrent = $restoredTarget
        }
        $actualRestore = $restoredTarget - $beforeRestore
        if ($actualRestore -gt 0) {
            if (-not [bool]$playerPool.UsesTarget) {
                Add-LWBookEnduranceDelta -Delta $actualRestore
                Register-LWManualRecoveryShortcut
            }
            Write-LWInfo ("Special combat rule restores {0} {1} after the fight." -f $actualRestore, $(if ([bool]$playerPool.UsesTarget) { 'TARGET point(s)' } else { 'ENDURANCE' }))
        }
    }

    $breakdown = Get-LWCombatBreakdown
    $playerPool = Get-LWCombatPlayerEndurancePool -State $script:GameState
    $summary = [pscustomobject]@{
        BookNumber        = [int]$script:GameState.Character.BookNumber
        BookTitle         = Get-LWBookTitle -BookNumber ([int]$script:GameState.Character.BookNumber)
        Section           = if ($null -ne $script:GameState.CurrentSection) { [int]$script:GameState.CurrentSection } else { $null }
        EnemyName         = $script:GameState.Combat.EnemyName
        Outcome           = $Outcome
        RoundCount        = @($script:GameState.Combat.Log).Count
        PlayerEnd         = [int]$playerPool.Current
        PlayerEnduranceMax = [int]$playerPool.Max
        UsesPlayerTargetEndurance = [bool]$playerPool.UsesTarget
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
        BowRestricted     = [bool]$script:GameState.Combat.BowRestricted
        CombatPotionsAllowed = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and $null -ne $script:GameState.Combat.CombatPotionsAllowed) { [bool]$script:GameState.Combat.CombatPotionsAllowed } else { $true }
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
        [switch]$SkipAutosave,
        [switch]$IgnoreEnemyLossThisRound,
        [object]$PotionChoice = $null
    )

    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return $null
    }

    $roll = Get-LWRandomDigit
    $useCRT = ($script:GameState.Settings.CombatMode -eq 'DataFile')
    $resolution = Resolve-LWCombatRound -State $script:GameState -Roll $roll -IgnoreEnemyLossThisRound:$IgnoreEnemyLossThisRound -UseCRT:$useCRT
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
        $resolution = Resolve-LWCombatRound -State $script:GameState -Roll $roll -EnemyLoss $enemyLoss -PlayerLoss $playerLoss -IgnoreEnemyLossThisRound:$IgnoreEnemyLossThisRound
    }

    Apply-LWCombatRoundResolution -Resolution $resolution

    if ($null -ne $PotionChoice) {
        $potionResult = Use-LWResolvedHealingPotion -PotionName ([string]$PotionChoice.Name) -RestoreAmount ([int]$PotionChoice.RestoreAmount) -InventoryType ([string]$PotionChoice.Type) -SkipAutosave
        if ($null -ne $potionResult) {
            $historyLog = @($script:GameState.Combat.Log)
            if ($historyLog.Count -gt 0) {
                $lastEntry = $historyLog[-1]
                $lastEntry.PlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $potionNote = ("Potion: {0}" -f [string]$potionResult.PotionName)
                if ([string]::IsNullOrWhiteSpace([string]$lastEntry.SpecialNote)) {
                    $lastEntry.SpecialNote = $potionNote
                }
                else {
                    $lastEntry.SpecialNote = ("{0}, {1}" -f [string]$lastEntry.SpecialNote, $potionNote)
                }
            }
            if ($resolution.Outcome -eq 'Defeat' -and [int]$script:GameState.Character.EnduranceCurrent -gt 0) {
                $resolution.Outcome = 'Continue'
                $resolution.NewPlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $resolution.LogEntry.PlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                Write-LWInfo ("{0} keeps Lone Wolf in the fight." -f [string]$potionResult.PotionName)
            }
            elseif ($resolution.Outcome -eq 'Special' -and [int]$resolution.NewPlayerEnd -le 0 -and [int]$script:GameState.Character.EnduranceCurrent -gt 0) {
                $resolution.Outcome = 'Continue'
                $resolution.NewPlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $resolution.LogEntry.PlayerEnd = [int]$script:GameState.Character.EnduranceCurrent
                $resolution.SpecialResolutionSection = $null
                $resolution.SpecialResolutionNote = $null
                Write-LWInfo ("{0} keeps Lone Wolf in the fight." -f [string]$potionResult.PotionName)
            }
        }
    }

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

        $expiryRounds = if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'EvadeExpiresAfterRound') -and $null -ne $script:GameState.Combat.EvadeExpiresAfterRound) { [int]$script:GameState.Combat.EvadeExpiresAfterRound } else { 0 }
        if ($expiryRounds -gt 0) {
            Write-LWWarn $(if ($expiryRounds -eq 1) { 'Evade is only available in round 1 of this combat.' } else { "Evade is only available through round $expiryRounds in this combat." })
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

    if ($currentBook -ge 6) {
        $script:GameState.Run.Status = 'Completed'
        $script:GameState.Run.CompletedOn = (Get-Date).ToString('o')
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
        Clear-LWDeathState
        Write-LWInfo 'Book 6 complete. The current Magnakai campaign is now complete.'
        Invoke-LWMaybeAutosave
        return
    }

    $nextBook = $currentBook + 1
    $nextBookLabel = Format-LWBookLabel -BookNumber $nextBook -IncludePrefix
    $nextBookStartSection = 1
    $script:GameState.Character.BookNumber = $nextBook
    if ($nextBook -le 5) {
        $script:GameState.Character.EnduranceCurrent = $script:GameState.Character.EnduranceMax
    }
    $script:GameState.CurrentSection = $nextBookStartSection
    $script:GameState.SectionHadCombat = $false
    $script:GameState.SectionHealingResolved = $false
    Clear-LWDeathState
    Reset-LWCurrentBookStats -BookNumber $nextBook -StartSection $nextBookStartSection
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Write-LWInfo "Advanced to $nextBookLabel. Current section reset to $nextBookStartSection."

    if ($nextBook -le 5) {
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
    }
    else {
        $script:GameState.RuleSet = 'Magnakai'
        $script:GameState.Character.LegacyKaiComplete = $true
        if (-not $script:GameState.Character.MagnakaiRank -or [int]$script:GameState.Character.MagnakaiRank -lt 3) {
            $script:GameState.Character.MagnakaiRank = 3
        }
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
    elseif ($nextBook -eq 6) {
        Apply-LWBookSixStartingEquipment -CarryExistingGear
    }

    Invoke-LWMaybeAutosave
}

function Invoke-LWCombatPotionRound {
    if (-not $script:GameState.Combat.Active) {
        Write-LWWarn 'No active combat. Use combat start first.'
        return $null
    }

    if ((Test-LWPropertyExists -Object $script:GameState.Combat -Name 'CombatPotionsAllowed') -and -not [bool]$script:GameState.Combat.CombatPotionsAllowed) {
        Write-LWWarn 'Potions cannot be used in this combat.'
        return $null
    }

    if (-not (Test-LWCombatHerbPouchOptionActive -State $script:GameState)) {
        Write-LWWarn 'Combat potion use is only available in Book 6 with DE Curing Option 3 and a carried Herb Pouch.'
        return $null
    }

    $choice = Select-LWHealingPotionChoice -State $script:GameState -HerbPouchOnly
    if ($null -eq $choice) {
        return $null
    }

    Write-LWInfo ("Herb Pouch action: using {0} instead of attacking this round." -f [string]$choice.Name)
    return (Invoke-LWCombatRound -IgnoreEnemyLossThisRound -PotionChoice $choice)
}

function Get-LWMagnakaiWeaponmasteryOptions {
    return @('Dagger', 'Spear', 'Mace', 'Warhammer', 'Sword', 'Axe', 'Short Sword', 'Quarterstaff', 'Broadsword', 'Bow')
}

function Select-LWMagnakaiDisciplines {
    param(
        [int]$Count = 3,
        [string[]]$Exclude = @()
    )

    $available = @($script:GameData.MagnakaiDisciplines | Where-Object { $Exclude -notcontains [string]$_.Name })
    if ($available.Count -lt $Count) {
        throw "Not enough Magnakai disciplines available to choose $Count item(s)."
    }

    $previousScreen = $script:LWUi.CurrentScreen
    $previousData = $script:LWUi.ScreenData
    if ($script:LWUi.Enabled) {
        Set-LWScreen -Name 'disciplineselect' -Data ([pscustomobject]@{
                Available = @($available)
                Count     = $Count
                RuleSet   = 'Magnakai'
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

            return @(
                foreach ($number in $numbers) {
                    [string]$available[$number - 1].Name
                }
            )
        }
    }
    finally {
        if ($script:LWUi.Enabled) {
            Set-LWScreen -Name $previousScreen -Data $previousData
        }
    }
}

function Select-LWWeaponmasteryWeapons {
    param(
        [int]$Count = 3,
        [string[]]$Exclude = @()
    )

    $available = @(Get-LWMagnakaiWeaponmasteryOptions | Where-Object { $Exclude -notcontains $_ })
    if ($available.Count -lt $Count) {
        throw "Not enough Weaponmastery weapons available to choose $Count item(s)."
    }

    while ($true) {
        Write-LWPanelHeader -Title 'Weaponmastery' -AccentColor 'DarkYellow'
        Write-LWSubtle '  Choose your mastered weapons.'
        Write-Host ''
        for ($i = 0; $i -lt $available.Count; $i++) {
            Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), [string]$available[$i]) -TextColor 'Gray' -BulletColor 'Yellow'
        }

        $raw = [string](Read-LWText -Prompt "Choose $Count mastered weapon number(s) separated by commas" -NoRefresh)
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-LWWarn 'Please choose at least one weapon.'
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
            if ($number -lt 1 -or $number -gt $available.Count -or $numbers -contains $number) {
                $valid = $false
                break
            }
            $numbers += $number
        }

        if (-not $valid -or $numbers.Count -ne $Count) {
            Write-LWWarn "Enter exactly $Count unique number(s) from the list."
            continue
        }

        return @(
            foreach ($number in $numbers) {
                [string]$available[$number - 1]
            }
        )
    }
}

function Add-LWMagnakaiDiscipline {
    param([string]$Name = '')

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    $owned = @($script:GameState.Character.MagnakaiDisciplines)
    $availableNames = @($script:GameData.MagnakaiDisciplines | ForEach-Object { [string]$_.Name })
    $remainingNames = @($availableNames | Where-Object { $owned -notcontains $_ })

    if ($remainingNames.Count -eq 0) {
        Write-LWWarn 'All Magnakai Disciplines are already owned.'
        return
    }

    $disciplineName = $null
    if ([string]::IsNullOrWhiteSpace($Name)) {
        $selection = Select-LWMagnakaiDisciplines -Count 1 -Exclude $owned
        if (@($selection).Count -gt 0) {
            $disciplineName = [string]$selection[0]
        }
    }
    else {
        $disciplineName = Get-LWMatchingValue -Values $remainingNames -Target $Name.Trim()
        if ([string]::IsNullOrWhiteSpace($disciplineName)) {
            Write-LWWarn ("Unknown or already owned Magnakai discipline: {0}" -f $Name.Trim())
            return
        }
    }

    if ([string]::IsNullOrWhiteSpace($disciplineName)) {
        Write-LWWarn 'No discipline was selected.'
        return
    }

    $script:GameState.Character.MagnakaiDisciplines = @($owned + $disciplineName)
    if (-not $script:GameState.Character.MagnakaiRank -or [int]$script:GameState.Character.MagnakaiRank -lt @($script:GameState.Character.MagnakaiDisciplines).Count) {
        $script:GameState.Character.MagnakaiRank = @($script:GameState.Character.MagnakaiDisciplines).Count
    }

    if ($disciplineName -eq 'Weaponmastery' -and @($script:GameState.Character.WeaponmasteryWeapons).Count -lt 3) {
        $script:GameState.Character.WeaponmasteryWeapons = @(Select-LWWeaponmasteryWeapons -Count 3 -Exclude @())
        Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
    }

    Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages
    Set-LWScreen -Name 'disciplines'
    Write-LWInfo "Added Magnakai discipline: $disciplineName."
    Invoke-LWMaybeAutosave
}

function Add-LWDiscipline {
    param([string]$Name = '')

    if (-not (Test-LWHasState)) {
        Write-LWWarn 'No active character. Use new or load first.'
        return
    }

    if (Test-LWStateIsMagnakaiRuleset -State $script:GameState) {
        Add-LWMagnakaiDiscipline -Name $Name
        return
    }

    Add-LWKaiDiscipline -Name $Name
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
    $bookNumber = Read-LWInt -Prompt 'Current book number' -Default 1 -Min 1 -Max 6
    $startSection = Read-LWInt -Prompt 'Starting section' -Default 1 -Min 1

    $csRoll = Get-LWRandomDigit
    $endRoll = Get-LWRandomDigit
    $combatSkill = 10 + $csRoll
    $endurance = 20 + $endRoll

    Write-LWInfo "Combat Skill roll: $csRoll -> $combatSkill"
    Write-LWInfo "Endurance roll: $endRoll -> $endurance"

    $script:GameState.Character.Name = $name
    $script:GameState.Character.BookNumber = $bookNumber
    $script:GameState.Character.CombatSkillBase = $combatSkill
    $script:GameState.Character.EnduranceCurrent = $endurance
    $script:GameState.Character.EnduranceMax = $endurance
    $script:GameState.CurrentSection = $startSection

    if ($bookNumber -ge 6) {
        $script:GameState.RuleSet = 'Magnakai'
        $script:GameState.Character.LegacyKaiComplete = $true
        $magnakaiDisciplines = Select-LWMagnakaiDisciplines -Count 3
        $script:GameState.Character.MagnakaiDisciplines = @($magnakaiDisciplines)
        $script:GameState.Character.MagnakaiRank = 3
        if ($magnakaiDisciplines -contains 'Weaponmastery') {
            $script:GameState.Character.WeaponmasteryWeapons = @(Select-LWWeaponmasteryWeapons -Count 3)
            Write-LWInfo ("Weaponmastery selection: {0}" -f (@($script:GameState.Character.WeaponmasteryWeapons) -join ', '))
        }
        Sync-LWMagnakaiLoreCircleBonuses -State $script:GameState -WriteMessages
    }
    else {
        $disciplines = Select-LWKaiDisciplines -Count 5
        $weaponskillWeapon = $null
        if ($disciplines -contains 'Weaponskill') {
            $weaponRoll = Get-LWRandomDigit
            $weaponskillWeapon = Get-LWWeaponskillWeapon -Roll $weaponRoll
            Write-LWInfo "Weaponskill roll: $weaponRoll -> $weaponskillWeapon"
        }

        $script:GameState.Character.Disciplines = $disciplines
        $script:GameState.Character.WeaponskillWeapon = $weaponskillWeapon
    }

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
    elseif ($bookNumber -eq 6) {
        Apply-LWBookSixStartingEquipment
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
        $ruleSet = $null
        $difficulty = $null

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
                if ($null -ne $state.RuleSet -and -not [string]::IsNullOrWhiteSpace([string]$state.RuleSet)) {
                    $ruleSet = [string]$state.RuleSet
                }
                if ($null -ne $state.Run -and $null -ne $state.Run.Difficulty -and -not [string]::IsNullOrWhiteSpace([string]$state.Run.Difficulty)) {
                    $difficulty = Get-LWNormalizedDifficultyName -Difficulty ([string]$state.Run.Difficulty)
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
            RuleSet        = $ruleSet
            Difficulty     = $difficulty
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

    foreach ($save in $saveFiles) {
        $bookText = if ($null -ne $save.BookNumber -and [int]$save.BookNumber -gt 0) { "Book $([int]$save.BookNumber)" } else { 'Book ?' }
        $ruleSetText = if (-not [string]::IsNullOrWhiteSpace([string]$save.RuleSet)) { [string]$save.RuleSet } else { '?' }
        $difficultyText = if (-not [string]::IsNullOrWhiteSpace([string]$save.Difficulty)) { [string]$save.Difficulty } else { '?' }
        $displayName = if ($save.IsCurrent) { "{0} (current)" -f [string]$save.Name } else { [string]$save.Name }
        Write-LWRetroPanelTextRow -Text ("{0,2}. {1}" -f [int]$save.Index, $displayName) -TextColor $(if ($save.IsCurrent) { 'Green' } else { 'Gray' })
        Write-LWRetroPanelTextRow -Text ("    {0,-20} {1,-7} {2,-10} {3}" -f $bookText, $ruleSetText, $difficultyText, $(if (-not [string]::IsNullOrWhiteSpace([string]$save.CharacterName)) { [string]$save.CharacterName } else { '' })) -TextColor 'DarkGray'
    }
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
    Invoke-LWCoreShowHelpScreen -Context (Get-LWModuleContext)
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

    $combatSubcommand = $Parts[1].ToLowerInvariant()
    switch ($combatSubcommand) {
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
        'potion' { [void](Invoke-LWCombatPotionRound) }
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
        default  {
            if ($Parts.Count -ge 4) {
                [void](Start-LWCombat -Arguments @($Parts[1..($Parts.Count - 1)]))
                return
            }

            Write-LWWarn 'Unknown combat subcommand. Use start, round, next, potion, auto, status, log, evade, or stop.'
        }
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
            Write-LWCommandPromptHint
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
        CanonicalInventoryItemResolver = ${function:Get-LWCanonicalInventoryItemName}
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

function Initialize-LWRuntimeShell {
    Invoke-LWCoreMaintainRuntime -Context (Get-LWModuleContext)
}

function New-LWDefaultState {
    $state = Invoke-LWCoreNewDefaultState -Context (Get-LWModuleContext)
    $state = Sync-LWHerbPouchState -State $state
    return (Sync-LWStateRefactorMetadata -State $state)
}

function Normalize-LWState {
    param([Parameter(Mandatory = $true)][object]$State)

    $normalized = Invoke-LWCoreNormalizeState -Context (Get-LWModuleContext) -State $State
    $normalized = Sync-LWHerbPouchState -State $normalized

    Ensure-LWAchievementState -State $normalized
    $currentBookNumber = if ($null -ne $normalized.Character -and $null -ne $normalized.Character.BookNumber) { [int]$normalized.Character.BookNumber } else { 1 }
    if ($currentBookNumber -ge 6) {
        $visitedSections = @()
        if ($null -ne $normalized.CurrentBookStats -and (Test-LWPropertyExists -Object $normalized.CurrentBookStats -Name 'VisitedSections') -and $null -ne $normalized.CurrentBookStats.VisitedSections) {
            $visitedSections = @($normalized.CurrentBookStats.VisitedSections | ForEach-Object { [int]$_ })
        }
        if ($null -ne $normalized.CurrentSection) {
            $visitedSections += [int]$normalized.CurrentSection
        }
        $visitedSections = @($visitedSections | Sort-Object -Unique)

        if ($visitedSections -contains 49) {
            if (-not (Test-LWPropertyExists -Object $normalized.Achievements.StoryFlags -Name 'Book6Section049CessUsed')) {
                $normalized.Achievements.StoryFlags | Add-Member -Force -NotePropertyName 'Book6Section049CessUsed' -NotePropertyValue $true
            }
            else {
                $normalized.Achievements.StoryFlags.Book6Section049CessUsed = $true
            }

            $latestCessEvent = Get-LWBook6LatestCessSectionEvent -State $normalized
            if ($latestCessEvent -eq 49) {
                $specialItems = @()
                if ($null -ne $normalized.Inventory -and $null -ne $normalized.Inventory.SpecialItems) {
                    $specialItems = @($normalized.Inventory.SpecialItems)
                }
                $normalized.Inventory.SpecialItems = @(
                    foreach ($item in $specialItems) {
                        if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCessItemNames) -Target ([string]$item)))) {
                            continue
                        }

                        [string]$item
                    }
                )
            }
            elseif ($latestCessEvent -in @(160, 304)) {
                $specialItems = @()
                if ($null -ne $normalized.Inventory -and $null -ne $normalized.Inventory.SpecialItems) {
                    $specialItems = @($normalized.Inventory.SpecialItems)
                }

                $hasCess = $false
                foreach ($item in $specialItems) {
                    if (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingValue -Values (Get-LWCessItemNames) -Target ([string]$item)))) {
                        $hasCess = $true
                        break
                    }
                }

                if (-not $hasCess) {
                    $normalized.Inventory.SpecialItems = @($specialItems) + @('Cess')
                }
            }
        }
    }

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
        if ([int]$script:GameState.Character.BookNumber -eq 6 -and -not (Test-LWDeathActive)) {
            $bookSixInstantDeathCause = Get-LWMagnakaiBookSixInstantDeathCause -Section ([int]$script:GameState.CurrentSection)
            if (-not [string]::IsNullOrWhiteSpace($bookSixInstantDeathCause)) {
                Invoke-LWInstantDeath -Cause $bookSixInstantDeathCause
            }
        }
    }
}

function Load-LWGameInteractive {
    param([string]$Selection)

    Invoke-LWCoreLoadGameInteractive -Context (Get-LWModuleContext) -Selection $Selection | Out-Null
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

function Apply-LWBookSixStartingEquipment {
    param([switch]$CarryExistingGear)

    Invoke-LWRuleSetStartingEquipment -State $script:GameState -BookNumber 6 -CarryExistingGear:$CarryExistingGear
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
    Initialize-LWRuntimeShell
    Initialize-LWData
    Start-LWTerminal
}
