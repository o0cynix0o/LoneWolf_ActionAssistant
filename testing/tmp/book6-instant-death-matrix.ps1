#requires -Version 5.1
param(
    [string]$ShellLabel = 'PS7',
    [string]$LogPath = '',
    [string]$JsonPath = ''
)

$ErrorActionPreference = 'Stop'

Set-Location 'C:\Scripts\Lone Wolf'
. .\lonewolf.ps1
Initialize-LWData
$script:LWUi.Enabled = $false

function Write-LWInfo {
    param([string]$Message)
    Add-LWNotification -Level 'Info' -Message $Message
}

function Write-LWWarn {
    param([string]$Message)
    Add-LWNotification -Level 'Warn' -Message $Message
}

function Write-LWError {
    param([string]$Message)
    Add-LWNotification -Level 'Error' -Message $Message
}

$instantDeathSections = @(
    29, 36, 52, 57, 80, 84, 90, 99, 128, 129, 161, 192, 218, 242, 257, 311, 323, 329, 349
)

function Assert-InstantDeathMatrix {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Reset-InstantDeathHarnessState {
    if ($null -eq $script:GameState.Combat) {
        $script:GameState | Add-Member -Force -NotePropertyName Combat -NotePropertyValue (New-LWCombatState)
    }
    else {
        $script:GameState.Combat = New-LWCombatState
    }

    if ($null -eq $script:GameState.DeathState) {
        $script:GameState | Add-Member -Force -NotePropertyName DeathState -NotePropertyValue (New-LWDeathState)
    }
    else {
        $script:GameState.DeathState = New-LWDeathState
    }

    if (Test-LWPropertyExists -Object $script:GameState -Name 'SectionHadCombat') {
        $script:GameState.SectionHadCombat = $false
    }

    if ($null -ne $script:GameState.Run) {
        $script:GameState.Run.Status = 'Active'
    }

    if ($null -ne $script:GameState.Settings) {
        $script:GameState.Settings.AutoSave = $false
    }
}

function Initialize-InstantDeathSourceState {
    param(
        [Parameter(Mandatory = $true)][string]$SourceJson,
        [Parameter(Mandatory = $true)][string]$SavePath
    )

    $script:GameState = Normalize-LWState -State ($SourceJson | ConvertFrom-Json)
    $script:GameState.Settings.SavePath = $SavePath
    Ensure-LWCurrentSectionCheckpoint
    Rebuild-LWStoryAchievementFlagsFromState
    Reset-InstantDeathHarnessState
}

function Get-MatrixCaseMeta {
    param([Parameter(Mandatory = $true)][string]$Path)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $match = [regex]::Match($name, '^book6-matrix-(?<shell>[^-]+)-(?<difficulty>[^-]+)-(?<route>.+)$')
    if (-not $match.Success) {
        throw "Could not parse matrix save name: $name"
    }

    return [pscustomobject]@{
        Shell      = [string]$match.Groups['shell'].Value
        Difficulty = [string]$match.Groups['difficulty'].Value
        Route      = [string]$match.Groups['route'].Value
    }
}

function Test-InstantDeathEntry {
    param(
        [Parameter(Mandatory = $true)][string]$SourceJson,
        [Parameter(Mandatory = $true)][int]$Section,
        [Parameter(Mandatory = $true)][string]$TempSave
    )

    Initialize-InstantDeathSourceState -SourceJson $SourceJson -SavePath $TempSave

    Assert-InstantDeathMatrix -Condition ([int]$script:GameState.Character.BookNumber -eq 6) -Message "Expected Book 6 save for entry test at section $Section."
    Assert-InstantDeathMatrix -Condition (-not (Test-LWDeathActive)) -Message "Source save was already dead before section $Section entry test."

    Set-LWSection -Section $Section

    Assert-InstantDeathMatrix -Condition (Test-LWDeathActive) -Message "Section $Section did not record instant death on entry."
    Assert-InstantDeathMatrix -Condition ([int]$script:GameState.Character.EnduranceCurrent -eq 0) -Message "Section $Section entry death did not reduce ENDURANCE to zero."
}

function Test-InstantDeathLoadRepair {
    param(
        [Parameter(Mandatory = $true)][string]$SourceJson,
        [Parameter(Mandatory = $true)][int]$Section,
        [Parameter(Mandatory = $true)][string]$TempSave
    )

    Initialize-InstantDeathSourceState -SourceJson $SourceJson -SavePath $TempSave

    Assert-InstantDeathMatrix -Condition ([int]$script:GameState.Character.BookNumber -eq 6) -Message "Expected Book 6 save for load test at section $Section."
    Assert-InstantDeathMatrix -Condition (-not (Test-LWDeathActive)) -Message "Source save was already dead before section $Section load test."

    $script:GameState.CurrentSection = [int]$Section
    $script:GameState.Character.EnduranceCurrent = [Math]::Max(1, [int]$script:GameState.Character.EnduranceCurrent)

    Save-LWGame
    Load-LWGame -Path $TempSave

    Assert-InstantDeathMatrix -Condition (Test-LWDeathActive) -Message "Section $Section did not record instant death on load."
    Assert-InstantDeathMatrix -Condition ([int]$script:GameState.Character.EnduranceCurrent -eq 0) -Message "Section $Section load death did not reduce ENDURANCE to zero."
}

$savePattern = "book6-matrix-$($ShellLabel.ToLowerInvariant())-*.json"
$matrixSaves = @(
    Get-ChildItem 'C:\Scripts\Lone Wolf\testing\saves' -Filter $savePattern |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject]@{
                FullName = $_.FullName
                Name     = $_.Name
                RawJson  = Get-Content -LiteralPath $_.FullName -Raw
            }
        }
)
if ($matrixSaves.Count -le 0) {
    throw "No Book 6 matrix saves found for shell label '$ShellLabel'."
}

$results = [System.Collections.Generic.List[object]]::new()
$caseIndex = 0
$totalCases = $matrixSaves.Count * $instantDeathSections.Count

foreach ($save in $matrixSaves) {
    $meta = Get-MatrixCaseMeta -Path $save.FullName
    foreach ($section in $instantDeathSections) {
        $caseIndex++
        $caseLabel = "{0}-{1}-{2}-section{3}" -f $meta.Difficulty, $meta.Route, $meta.Shell, $section
        Write-Host ("[{0}/{1}] {2}" -f $caseIndex, $totalCases, $caseLabel) -ForegroundColor Cyan

        $entryTempSave = "C:\Scripts\Lone Wolf\testing\tmp\book6-instantdeath-$($ShellLabel.ToLowerInvariant())-$($meta.Difficulty)-$($meta.Route)-section$section-entry.json"
        $loadTempSave = "C:\Scripts\Lone Wolf\testing\tmp\book6-instantdeath-$($ShellLabel.ToLowerInvariant())-$($meta.Difficulty)-$($meta.Route)-section$section-load.json"

        $result = [ordered]@{
            Shell      = $ShellLabel
            Difficulty = $meta.Difficulty
            Route      = $meta.Route
            Section    = $section
            Entry      = 'Pending'
            LoadRepair = 'Pending'
            Status     = 'Pending'
            Error      = $null
        }

        try {
            Test-InstantDeathEntry -SourceJson $save.RawJson -Section $section -TempSave $entryTempSave
            $result.Entry = 'Pass'

            Test-InstantDeathLoadRepair -SourceJson $save.RawJson -Section $section -TempSave $loadTempSave
            $result.LoadRepair = 'Pass'
            $result.Status = 'Pass'
            Write-Host ("PASS {0}" -f $caseLabel) -ForegroundColor Green
        }
        catch {
            $result.Status = 'Fail'
            $result.Error = $_.Exception.Message
            Write-Host ("FAIL {0}: {1}" -f $caseLabel, $_.Exception.Message) -ForegroundColor Red
        }

        $results.Add([pscustomobject]$result)
    }
}

$passCount = @($results | Where-Object { [string]$_.Status -eq 'Pass' }).Count
$failCount = @($results | Where-Object { [string]$_.Status -eq 'Fail' }).Count

$summaryLines = @()
$summaryLines += "# Book 6 Instant-Death Matrix - $ShellLabel"
$summaryLines += ''
$summaryLines += ("- Saves: {0}" -f $matrixSaves.Count)
$summaryLines += ("- Sections: {0}" -f $instantDeathSections.Count)
$summaryLines += ("- Cases: {0}" -f $totalCases)
$summaryLines += ("- Passed: {0}" -f $passCount)
$summaryLines += ("- Failed: {0}" -f $failCount)
$summaryLines += ''
$summaryLines += '| Difficulty | Route | Section | Entry | Load Repair | Status | Notes |'
$summaryLines += '| --- | --- | --- | --- | --- | --- | --- |'
foreach ($entry in $results) {
    $summaryLines += ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f `
        [string]$entry.Difficulty,
        [string]$entry.Route,
        [int]$entry.Section,
        [string]$entry.Entry,
        [string]$entry.LoadRepair,
        [string]$entry.Status,
        ([string]$entry.Error).Replace('|','/'))
}

$summaryText = $summaryLines -join [Environment]::NewLine
$summaryText

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $summaryText | Set-Content -LiteralPath $LogPath -Encoding UTF8
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    $results | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
}

if ($failCount -gt 0) {
    throw ("{0} Book 6 instant-death matrix case(s) failed for {1}." -f $failCount, $ShellLabel)
}
