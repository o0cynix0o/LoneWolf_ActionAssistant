$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

function Get-LWRandomAutomationSmokeSectionRange {
    param([Parameter(Mandatory = $true)][int]$BookNumber)

    switch ($BookNumber) {
        5 { return 1..400 }
        default { return 1..350 }
    }
}

function New-LWRandomAutomationSmokeState {
    param(
        [Parameter(Mandatory = $true)][int]$BookNumber
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Automation Smoke'
    $state.Character.BookNumber = $BookNumber
    $state.CurrentSection = 1
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run.Difficulty = 'Normal'
    $state.Run.Permadeath = $false

    if ($BookNumber -ge 6) {
        $state.RuleSet = 'Magnakai'
        $state.Character.LegacyKaiComplete = $true
        $state.Character.MagnakaiRank = if ($BookNumber -ge 7) { 4 } else { 3 }
        $state.Character.MagnakaiDisciplines = @()
        $state.Character.WeaponmasteryWeapons = @()
    }
    else {
        $state.RuleSet = 'Kai'
        $state.Character.Disciplines = @()
    }

    return $state
}

$results = @()
$failures = @()

foreach ($bookNumber in 1..7) {
    foreach ($section in (Get-LWRandomAutomationSmokeSectionRange -BookNumber $bookNumber)) {
        $state = New-LWRandomAutomationSmokeState -BookNumber $bookNumber
        $state.CurrentSection = $section
        Set-LWHostGameState -State $state | Out-Null

        try {
            $context = Get-LWSectionRandomNumberContext -State $state
            if ($null -eq $context) {
                continue
            }

            Write-LWCurrentSectionRandomNumberRoll -Roll 5 -State $state

            $results += [pscustomobject]@{
                Book    = $bookNumber
                Section = $section
                Status  = 'ok'
            }
        }
        catch {
            $failures += [pscustomobject]@{
                Book      = $bookNumber
                Section   = $section
                Error     = $_.Exception.Message
                Script    = $_.InvocationInfo.ScriptName
                Line      = $_.InvocationInfo.ScriptLineNumber
            }
        }
    }
}

"Random automation contexts exercised: $(@($results).Count)"
"Failures: $(@($failures).Count)"

if (@($failures).Count -gt 0) {
    $failures | Sort-Object Book,Section | Format-Table -AutoSize | Out-String
    exit 1
}
