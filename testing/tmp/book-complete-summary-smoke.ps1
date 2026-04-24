param(
    [string]$LogPath = ''
)

$ErrorActionPreference = 'Stop'

Set-Location 'C:\Scripts\Lone Wolf'
. .\lonewolf.ps1
Initialize-LWData

$results = @()

function Assert-LWBookCompleteSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

try {
    Load-LWGame -Path 'C:\Scripts\Lone Wolf\testing\saves\book6-matrix-ps7-normal-coldpsi.json'
    $script:GameState.Settings.AutoSave = $false
    $script:LWUi.Enabled = $true
    $script:GameState.Character.BookNumber = 6
    $script:GameState.RuleSet = 'Magnakai'
    $script:GameState.Character.LegacyKaiComplete = $true
    $script:GameState.Character.MagnakaiRank = 4
    $script:GameState.Character.MagnakaiDisciplines = @('Pathsmanship', 'Psi-screen', 'Huntmastery', 'Nexus')
    $script:GameState.Character.WeaponmasteryWeapons = @()
    $script:GameState.Inventory.SpecialItems = @()
    $script:GameState.Storage.SafekeepingSpecialItems = @()
    $script:GameState.Inventory.GoldCrowns = 17
    $script:GameState.Character.EnduranceCurrent = 23
    $script:GameState.Character.EnduranceMax = 31
    $script:GameState.Character.Notes = @('Recovered the silver key', 'Reached the crypt')
    $transitionTranscript = ('C:\Scripts\Lone Wolf\testing\logs\BOOK_COMPLETE_SUMMARY_TRACE_{0}.txt' -f $PID)

    Start-Transcript -LiteralPath $transitionTranscript -Force | Out-Null
    try {
        Complete-LWBook
    }
    finally {
        Stop-Transcript | Out-Null
    }

    $transitionText = Get-Content -LiteralPath $transitionTranscript -Raw
    $summaryIndex = $transitionText.IndexOf('ADVENTURE COMPLETE')
    $playthroughIndex = $transitionText.IndexOf('THIS PLAYTHROUGH')
    $noteIndex = $transitionText.IndexOf('Press Enter to continue to Book 7 - Castle Death setup.')
    $startingGearIndex = $transitionText.IndexOf('Book 7 Starting Gear')

    Assert-LWBookCompleteSmoke -Condition ($summaryIndex -ge 0) -Message 'Book 6 completion transcript did not render the Adventure Complete summary.'
    Assert-LWBookCompleteSmoke -Condition ($playthroughIndex -gt $summaryIndex) -Message 'Book 6 completion transcript did not render the This Playthrough panel after the summary header.'
    Assert-LWBookCompleteSmoke -Condition ($noteIndex -gt $playthroughIndex) -Message 'Book 6 completion transcript did not show the continue note after the recap.'
    Assert-LWBookCompleteSmoke -Condition ($startingGearIndex -gt $noteIndex) -Message 'Book 7 starting gear appeared before the Book 6 completion recap finished rendering.'
    Assert-LWBookCompleteSmoke -Condition ([int]$script:GameState.Character.BookNumber -eq 7) -Message 'Book 6 completion did not advance into Book 7.'
    Assert-LWBookCompleteSmoke -Condition ([int]$script:GameState.CurrentSection -eq 1) -Message 'Book 7 did not reset to section 1 after completion.'
    Assert-LWBookCompleteSmoke -Condition ([string]$script:LWUi.CurrentScreen -eq 'sheet') -Message 'Book 7 transition did not return the UI to the sheet screen after the recap pause.'
    Assert-LWBookCompleteSmoke -Condition (@($script:GameState.Character.CompletedBooks) -contains 6) -Message 'Book 6 was not recorded in CompletedBooks.'

    $results += [pscustomobject]@{
        Name   = 'Book 6 completion pauses on summary before Book 7 setup'
        Passed = $true
    }
}
catch {
    $results += [pscustomobject]@{
        Name   = 'Book 6 completion pauses on summary before Book 7 setup'
        Passed = $false
        Error  = $_.Exception.Message
    }
}
finally {
    $script:LWUi.Enabled = $false
}

try {
    $state = New-LWDefaultState
    $state.Character.Name = 'Final Summary Smoke'
    $state.Character.BookNumber = 7
    $state.RuleSet = 'Magnakai'
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Pathsmanship', 'Psi-screen', 'Huntmastery', 'Nexus')
    $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    $state.Inventory.GoldCrowns = 12
    $state.Character.EnduranceCurrent = 9
    $state.Character.EnduranceMax = 29
    $state.Settings.AutoSave = $false
    Set-LWHostGameState -State $state | Out-Null
    Reset-LWCurrentBookStats -BookNumber 7 -StartSection 1
    $stats = Ensure-LWCurrentBookStats
    $stats.SectionsVisited = 14
    $stats.VisitedSections = @(1, 10, 19, 44, 76, 103, 144, 173, 201, 228, 257, 289, 310, 350)
    $stats.Victories = 5
    $stats.Defeats = 1
    $stats.EnduranceLost = 18
    $stats.EnduranceGained = 11
    $stats.GoldGained = 9
    $stats.GoldSpent = 6
    $stats.RewindsUsed = 1
    $stats.LastSection = 350

    Complete-LWBook

    Assert-LWBookCompleteSmoke -Condition ([string]$script:LWUi.CurrentScreen -eq 'bookcomplete') -Message 'Final campaign completion did not remain on the book-complete screen.'
    Assert-LWBookCompleteSmoke -Condition ([int]$script:GameState.Character.BookNumber -eq 7) -Message 'Final campaign completion changed the active book unexpectedly.'
    Assert-LWBookCompleteSmoke -Condition ([string]$script:GameState.Run.Status -eq 'Completed') -Message 'Final campaign completion did not mark the run as completed.'
    Assert-LWBookCompleteSmoke -Condition (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.CompletedOn)) -Message 'Final campaign completion did not stamp CompletedOn.'
    Assert-LWBookCompleteSmoke -Condition ([int]$script:GameState.Character.EnduranceCurrent -eq [int]$script:GameState.Character.EnduranceMax) -Message 'Final campaign completion did not restore Endurance to max.'
    Assert-LWBookCompleteSmoke -Condition ([int]$script:LWUi.ScreenData.Summary.BookNumber -eq 7) -Message 'Final campaign completion summary did not record Book 7.'
    Assert-LWBookCompleteSmoke -Condition ([string]$script:LWUi.ScreenData.ContinueToBookLabel -eq '') -Message 'Final campaign completion should not advertise another continuation book.'
    Assert-LWBookCompleteSmoke -Condition ([int]$script:LWUi.ScreenData.Snapshot.GoldCrowns -eq 12) -Message 'Final campaign completion snapshot did not preserve final Gold Crowns.'

    $results += [pscustomobject]@{
        Name   = 'Book 7 final completion remains on summary screen'
        Passed = $true
    }
}
catch {
    $results += [pscustomobject]@{
        Name   = 'Book 7 final completion remains on summary screen'
        Passed = $false
        Error  = $_.Exception.Message
    }
}

$table = $results | Format-Table -AutoSize | Out-String
$table.TrimEnd()

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $table | Set-Content -LiteralPath $LogPath -Encoding UTF8
}

if (@($results | Where-Object { -not $_.Passed }).Count -gt 0) {
    throw 'One or more book-complete summary smoke checks failed.'
}
