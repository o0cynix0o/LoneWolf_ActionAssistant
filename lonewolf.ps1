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
$script:LWAchievementsModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\achievements.psm1'
$script:LWItemsModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\items.psm1'
$script:LWInventoryModulePath = Join-Path $script:LWBootstrapRoot 'modules\core\inventory.psm1'
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
        $script:LWAchievementsModulePath,
        $script:LWItemsModulePath,
        $script:LWInventoryModulePath,
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
        LWAchievementContextDefinitionsCache = $script:LWAchievementContextDefinitionsCache
        LWAchievementDisplayCountsCache = $script:LWAchievementDisplayCountsCache
        LWUi                         = $script:LWUi
        CanonicalInventoryItemResolver = ${function:Get-LWCanonicalInventoryItemName}
    }
}

function Set-LWHostGameState {
    param([object]$State)

    $script:GameState = $State
    return $script:GameState
}

function Set-LWHostGameData {
    param([object]$Data)

    $script:GameData = $Data
    return $script:GameData
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
        Set-LWScreen -Name (Get-LWDefaultScreen)
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

    $loadedState = Invoke-LWCoreLoadGameInteractive -Context (Get-LWModuleContext) -Selection $Selection
    if ($null -ne $loadedState) {
        $script:GameState = Sync-LWStateRefactorMetadata -State $loadedState
        Set-LWScreen -Name (Get-LWDefaultScreen)
        if ([int]$script:GameState.Character.BookNumber -eq 6 -and -not (Test-LWDeathActive)) {
            $bookSixInstantDeathCause = Get-LWMagnakaiBookSixInstantDeathCause -Section ([int]$script:GameState.CurrentSection)
            if (-not [string]::IsNullOrWhiteSpace($bookSixInstantDeathCause)) {
                Invoke-LWInstantDeath -Cause $bookSixInstantDeathCause
            }
        }
    }
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

