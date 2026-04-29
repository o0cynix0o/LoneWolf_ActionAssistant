Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$sessionScript = Join-Path $repoRoot 'web\lw_api_session.ps1'
$saveDir = Join-Path $repoRoot 'testing\saves'
$sourceSavePath = Join-Path $saveDir ("web-parity-transition-source-{0}.json" -f $PID)
$lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
$hadLastSave = Test-Path -LiteralPath $lastSaveFile
$previousLastSave = if ($hadLastSave) { Get-Content -LiteralPath $lastSaveFile -Raw } else { $null }

Set-Location -LiteralPath $repoRoot
. (Join-Path $repoRoot 'lonewolf.ps1')
Initialize-LWData

function Assert-WebTransitionSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Start-WebApiSession {
    $pwsh = Get-Command pwsh -ErrorAction Stop
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $pwsh.Source
    $startInfo.Arguments = ('-NoLogo -NoProfile -File "{0}"' -f $sessionScript)
    $startInfo.WorkingDirectory = [string]$repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) {
        throw 'Failed to start web API session.'
    }

    return $process
}

function Invoke-WebApiAction {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][hashtable]$Request
    )

    $json = $Request | ConvertTo-Json -Compress -Depth 20
    $Process.StandardInput.WriteLine($json)
    $Process.StandardInput.Flush()

    $line = $Process.StandardOutput.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) {
        $errorText = $Process.StandardError.ReadToEnd()
        throw "No response from web API session. $errorText"
    }

    $response = $line | ConvertFrom-Json
    if (-not [bool]$response.ok) {
        throw ("API action failed: {0}" -f [string]$response.message)
    }

    return $response
}

function Get-PendingFlow {
    param([object]$Response)

    if ($null -eq $Response -or $null -eq $Response.payload -or $null -eq $Response.payload.pendingFlow) {
        return $null
    }

    return $Response.payload.pendingFlow
}

function Assert-PendingFlow {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][string]$ExpectedKind,
        [Parameter(Mandatory = $true)][string]$ExpectedPromptText,
        [string[]]$ContextContains = @()
    )

    $pending = Get-PendingFlow -Response $Response
    Assert-WebTransitionSmoke -Condition ($null -ne $pending) -Message "Expected pending flow '$ExpectedKind'."
    Assert-WebTransitionSmoke -Condition ([string]$pending.Type -eq 'continueBook') -Message "Expected continueBook flow, got '$($pending.Type)'."
    Assert-WebTransitionSmoke -Condition ([string]$pending.PromptKind -eq $ExpectedKind) -Message "Expected prompt kind '$ExpectedKind', got '$($pending.PromptKind)'."
    Assert-WebTransitionSmoke -Condition ($null -ne $pending.Prompt -and [string]$pending.Prompt.Prompt -eq $ExpectedPromptText) -Message "Expected prompt '$ExpectedPromptText', got '$($pending.Prompt.Prompt)'."

    $contextText = if ($null -ne $pending.ContextText) { [string]$pending.ContextText } else { '' }
    foreach ($needle in @($ContextContains)) {
        Assert-WebTransitionSmoke -Condition ($contextText.Contains($needle)) -Message "Pending context for '$ExpectedKind' did not include '$needle'."
    }

    return $pending
}

function New-WebTransitionSourceSave {
    New-Item -ItemType Directory -Path $saveDir -Force | Out-Null

    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.CurrentSection = 350
    $state.SectionHadCombat = $false
    $state.SectionHealingResolved = $false
    $state.Character.Name = 'Web Transition Smoke'
    $state.Character.BookNumber = 6
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 22
    $state.Character.EnduranceMax = 30
    $state.Character.Disciplines = @('Camouflage', 'Hunting', 'Sixth Sense', 'Tracking', 'Healing')
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus')
    $state.Character.MagnakaiRank = 3
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer')
    $state.Character.LegacyKaiComplete = $true
    $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    $state.Inventory.Weapons = @('Sword', 'Bow')
    $state.Inventory.BackpackItems = @('Meal', 'Rope')
    $state.Inventory.SpecialItems = @('Map of Sommerlund', 'Seal of Hammerdal')
    $state.Inventory.GoldCrowns = 12
    $state.Inventory.HasBackpack = $true
    $state.Inventory.HasHerbPouch = $true
    $state.Inventory.HerbPouchItems = @('Potion of Laumspur')
    $state.Storage.SafekeepingSpecialItems = @('Crystal Star Pendant')
    $state.Run = New-LWRunState -Difficulty 'Normal' -Permadeath:$false
    $state.Settings.SavePath = [string]$sourceSavePath
    $state.Settings.AutoSave = $false
    $state.CurrentBookStats = New-LWBookStats -BookNumber 6 -StartSection 1
    [void](Sync-LWRunIntegrityState -State $state -Reseal)

    $json = $state | ConvertTo-Json -Depth 40
    Set-Content -LiteralPath $sourceSavePath -Value $json -Encoding UTF8
}

function Restore-LastSavePointer {
    if ($hadLastSave) {
        $directory = Split-Path -Parent $lastSaveFile
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        Set-Content -LiteralPath $lastSaveFile -Value $previousLastSave -Encoding UTF8
    }
    elseif (Test-Path -LiteralPath $lastSaveFile) {
        Remove-Item -LiteralPath $lastSaveFile -Force
    }
}

New-WebTransitionSourceSave

$session = Start-WebApiSession
try {
    $loaded = Invoke-WebApiAction -Process $session -Request @{
        action = 'loadGame'
        path   = [string]$sourceSavePath
    }
    Assert-WebTransitionSmoke -Condition ([bool]$loaded.payload.session.HasState) -Message 'Transition source save did not load.'
    Assert-WebTransitionSmoke -Condition ([int]$loaded.payload.character.BookNumber -eq 6) -Message 'Transition source should be Book 6.'
    Assert-WebTransitionSmoke -Condition (@($loaded.payload.character.CompletedBooks) -contains 6) -Message 'Transition source should already record Book 6 complete.'
    Assert-WebTransitionSmoke -Condition (@($loaded.payload.character.MagnakaiDisciplines).Count -eq 3) -Message 'Transition source should start with three Magnakai Disciplines.'
    Assert-WebTransitionSmoke -Condition (@($loaded.payload.character.WeaponmasteryWeapons).Count -eq 3) -Message 'Transition source should start with three Weaponmastery weapons.'

    $bookComplete = Invoke-WebApiAction -Process $session -Request @{
        action = 'showScreen'
        name   = 'bookcomplete'
    }
    Assert-WebTransitionSmoke -Condition ([string]$bookComplete.payload.session.CurrentScreen -eq 'bookcomplete') -Message 'bookcomplete screen did not stick before continueBook.'
    Assert-WebTransitionSmoke -Condition (@($bookComplete.payload.availableScreens) -contains 'bookcomplete') -Message 'bookcomplete is missing from available screens.'

    $disciplinePrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'continueBook' }
    [void](Assert-PendingFlow -Response $disciplinePrompt -ExpectedKind 'disciplineChoice' -ExpectedPromptText 'Enter 1 number(s) separated by commas' -ContextContains @('Choose Magnakai Discipline', 'Animal Control'))

    $weaponmasteryPrompt = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ response = '1' }
    }
    [void](Assert-PendingFlow -Response $weaponmasteryPrompt -ExpectedKind 'weaponmasteryChoice' -ExpectedPromptText 'Choose 1 mastered weapon number(s) separated by commas' -ContextContains @('Weaponmastery', 'Dagger'))

    $safekeepingPrompt = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ response = '1' }
    }
    [void](Assert-PendingFlow -Response $safekeepingPrompt -ExpectedKind 'safekeepingMenu' -ExpectedPromptText 'Safekeeping choice' -ContextContains @('Book 7 Safekeeping', 'Map of Sommerlund', 'Crystal Star Pendant', 'Continue into Book 7 - Castle Death'))
    Assert-WebTransitionSmoke -Condition (-not ([string]$safekeepingPrompt.payload.pendingFlow.ContextText).Contains('Book 8 Safekeeping')) -Message 'Safekeeping context incorrectly advanced past the target book.'

    $startingGearPrompt = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ response = 'n' }
    }
    [void](Assert-PendingFlow -Response $startingGearPrompt -ExpectedKind 'startingGearChoice' -ExpectedPromptText 'Book 7 choice #1' -ContextContains @('Book 7 Starting Gear', '0. Done choosing'))

    $advanced = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ response = '0' }
    }
    Assert-WebTransitionSmoke -Condition ($null -eq (Get-PendingFlow -Response $advanced)) -Message 'Transition flow should be complete after declining starting gear.'
    Assert-WebTransitionSmoke -Condition ([bool]$advanced.payload.session.HasState) -Message 'Transition should leave an active run.'
    Assert-WebTransitionSmoke -Condition (-not [bool]$advanced.payload.session.DeathActive) -Message 'Transition should leave Lone Wolf alive.'
    Assert-WebTransitionSmoke -Condition ([string]$advanced.payload.session.CurrentScreen -eq 'sheet') -Message 'Transition should return to the sheet screen.'
    Assert-WebTransitionSmoke -Condition ([int]$advanced.payload.character.BookNumber -eq 7) -Message 'Transition did not advance to Book 7.'
    Assert-WebTransitionSmoke -Condition ([int]$advanced.payload.reader.Section -eq 1) -Message 'Transition did not reset to section 1.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.character.CompletedBooks) -contains 6) -Message 'CompletedBooks lost Book 6 during transition.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.character.MagnakaiDisciplines).Count -eq 4) -Message 'Transition did not add the fourth Magnakai Discipline.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.character.MagnakaiDisciplines) -contains 'Animal Control') -Message 'Expected first available Magnakai Discipline to be added.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.character.WeaponmasteryWeapons).Count -eq 4) -Message 'Transition did not add the fourth Weaponmastery weapon.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.character.WeaponmasteryWeapons) -contains 'Dagger') -Message 'Expected first available Weaponmastery weapon to be added.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.inventory.SpecialItems) -contains 'Map of Sommerlund') -Message 'Carried Special Items should survive when safekeeping is skipped.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.inventory.SpecialItems) -contains 'Seal of Hammerdal') -Message 'Second carried Special Item should survive when safekeeping is skipped.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.inventory.SafekeepingSpecialItems) -contains 'Crystal Star Pendant') -Message 'Stored safekeeping item should remain stored.'
    Assert-WebTransitionSmoke -Condition (-not (@($advanced.payload.inventory.BackpackItems) -contains 'Meal')) -Message 'Old Backpack Items should not carry into Book 7.'
    Assert-WebTransitionSmoke -Condition (-not (@($advanced.payload.inventory.BackpackItems) -contains 'Rope')) -Message 'Old Backpack Items should be cleared before Book 7.'
    Assert-WebTransitionSmoke -Condition (-not (@($advanced.payload.inventory.HerbPouchItems) -contains 'Potion of Laumspur')) -Message 'Old Herb Pouch contents should not carry into Book 7.'
    Assert-WebTransitionSmoke -Condition (@($advanced.payload.inventory.PocketSpecialItems | ForEach-Object { [string]$_ }) -icontains 'Power-Key') -Message 'Book 7 startup should add the Power-Key to Pocket Items.'
    Assert-WebTransitionSmoke -Condition ([int]$advanced.payload.character.EnduranceCurrent -gt 0) -Message 'Transition should leave a living ENDURANCE value.'

    '[PASS] Web parity transition smoke'
}
finally {
    if ($null -ne $session -and -not $session.HasExited) {
        try {
            $session.StandardInput.Close()
        }
        catch {
        }

        if (-not $session.WaitForExit(3000)) {
            $session.Kill()
            $session.WaitForExit()
        }
    }

    Restore-LastSavePointer
}
