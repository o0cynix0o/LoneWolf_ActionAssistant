Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$sessionScript = Join-Path $repoRoot 'web\lw_api_session.ps1'
$testSaveRoot = Join-Path $repoRoot 'testing\saves'
$lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
$hadLastSave = Test-Path -LiteralPath $lastSaveFile
$previousLastSave = if ($hadLastSave) { Get-Content -LiteralPath $lastSaveFile -Raw } else { $null }

Set-Location -LiteralPath $repoRoot
. (Join-Path $repoRoot 'lonewolf.ps1')
Initialize-LWData

function Assert-WebAutomationSmoke {
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

function Assert-PendingPrompt {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][string]$ExpectedPrompt,
        [string[]]$ContextContains = @(),
        [string]$ExpectedKind = ''
    )

    $pending = Get-PendingFlow -Response $Response
    Assert-WebAutomationSmoke -Condition ($null -ne $pending) -Message "Expected pending prompt '$ExpectedPrompt'."
    Assert-WebAutomationSmoke -Condition ([string]$pending.Type -eq 'setSection') -Message "Expected setSection flow, got '$($pending.Type)'."
    Assert-WebAutomationSmoke -Condition ($null -ne $pending.Prompt -and [string]$pending.Prompt.Prompt -eq $ExpectedPrompt) -Message "Expected prompt '$ExpectedPrompt', got '$($pending.Prompt.Prompt)'."
    if (-not [string]::IsNullOrWhiteSpace($ExpectedKind)) {
        Assert-WebAutomationSmoke -Condition ([string]$pending.PromptKind -eq $ExpectedKind) -Message "Expected prompt kind '$ExpectedKind', got '$($pending.PromptKind)'."
    }

    $contextText = if ($null -ne $pending.ContextText) { [string]$pending.ContextText } else { '' }
    foreach ($needle in @($ContextContains)) {
        Assert-WebAutomationSmoke -Condition ($contextText.Contains($needle)) -Message "Pending context for '$ExpectedPrompt' did not include '$needle'."
    }

    return $pending
}

function New-WebAutomationStateSave {
    param(
        [Parameter(Mandatory = $true)][int]$BookNumber,
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$FullBackpack
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null

    $state = New-LWDefaultState
    $state.Character.Name = ('Web Automation Smoke Book {0}' -f $BookNumber)
    $state.Character.BookNumber = $BookNumber
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.CurrentSection = 1
    $state.SectionHadCombat = $false
    $state.SectionHealingResolved = $false
    $state.Settings.SavePath = [string]$Path
    $state.Settings.AutoSave = $false
    $state.Run = New-LWRunState -Difficulty 'Normal' -Permadeath:$false

    if ($BookNumber -ge 6) {
        $state.RuleSet = 'Magnakai'
        $state.Character.LegacyKaiComplete = $true
        $state.Character.CompletedBooks = @(1, 2, 3, 4, 5)
        $state.Character.MagnakaiRank = if ($BookNumber -ge 7) { 4 } else { 3 }
        $state.Character.MagnakaiDisciplines = @($script:GameData.MagnakaiDisciplines | ForEach-Object { [string]$_.Name })
        $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    }
    else {
        $state.RuleSet = 'Kai'
        $state.Character.Disciplines = @($script:GameData.KaiDisciplines | ForEach-Object { [string]$_.Name })
        $state.Character.WeaponskillWeapon = 'Sword'
    }

    Set-LWHostGameState -State $state | Out-Null
    Set-LWBackpackState -HasBackpack $true
    [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Sword')
    [void](TryAdd-LWInventoryItemSilently -Type 'weapon' -Name 'Bow')
    [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Book of the Magnakai')
    [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Shield')
    [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Helmet')
    if ($BookNumber -eq 7) {
        [void](TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Sommerswerd')
    }
    $state.Inventory.GoldCrowns = 50

    $backpackItems = if ($FullBackpack) {
        @('Meal', 'Rope', 'Lantern', 'Tinderbox', 'Blanket', 'Bottle of Water', 'Sabito', 'Fireseed')
    }
    else {
        @('Meal', 'Rope', 'Tinderbox')
    }
    foreach ($item in $backpackItems) {
        [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name $item)
    }

    if ($BookNumber -eq 7) {
        [void](TryAdd-LWPocketSpecialItemSilently -Name 'Power-key')
    }

    $state.CurrentBookStats = New-LWBookStats -BookNumber $BookNumber -StartSection 1
    [void](Sync-LWRunIntegrityState -State $state -Reseal)
    $json = $state | ConvertTo-Json -Depth 40
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
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

$book6SavePath = Join-Path $testSaveRoot ("web-parity-automation-book6-{0}.json" -f $PID)
$book7SavePath = Join-Path $testSaveRoot ("web-parity-automation-book7-{0}.json" -f $PID)
$book7FullSavePath = Join-Path $testSaveRoot ("web-parity-automation-book7-full-{0}.json" -f $PID)
New-WebAutomationStateSave -BookNumber 6 -Path $book6SavePath
New-WebAutomationStateSave -BookNumber 7 -Path $book7SavePath
New-WebAutomationStateSave -BookNumber 7 -Path $book7FullSavePath -FullBackpack

$session = Start-WebApiSession
try {
    $loadedBook6 = Invoke-WebApiAction -Process $session -Request @{ action = 'loadGame'; path = [string]$book6SavePath }
    Assert-WebAutomationSmoke -Condition ([int]$loadedBook6.payload.character.BookNumber -eq 6) -Message 'Book 6 automation source did not load.'

    $lootPrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 8 }
    [void](Assert-PendingPrompt -Response $lootPrompt -ExpectedPrompt 'Section 8 choice' -ExpectedKind 'choiceTable' -ContextContains @('Section 8 Loot', '0. Done choosing', 'Gold Crowns'))
    $lootDone = Invoke-WebApiAction -Process $session -Request @{ action = 'submitFlow'; data = @{ response = 0 } }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $lootDone)) -Message 'Book 6 loot prompt did not complete after choosing 0.'

    $shopPrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 98 }
    [void](Assert-PendingPrompt -Response $shopPrompt -ExpectedPrompt 'Section 98 shop choice' -ExpectedKind 'choiceMenu' -ContextContains @('Section 98 Weapons Shop', '1. Buy gear', '2. Sell gear', '0. Leave the shop'))
    $shopDone = Invoke-WebApiAction -Process $session -Request @{ action = 'submitFlow'; data = @{ response = 0 } }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $shopDone)) -Message 'Book 6 shop prompt did not complete after leaving shop.'

    $paymentPrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 137 }
    [void](Assert-PendingPrompt -Response $paymentPrompt -ExpectedPrompt 'Section 137: pay the 3 Gold Crown levy now?' -ContextContains @('Section 137'))
    Assert-WebAutomationSmoke -Condition ([string](Get-PendingFlow -Response $paymentPrompt).Prompt.PromptType -eq 'yesno') -Message 'Book 6 payment prompt should stay typed as yes/no.'
    $paymentDone = Invoke-WebApiAction -Process $session -Request @{ action = 'submitFlow'; data = @{ response = $false } }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $paymentDone)) -Message 'Book 6 payment prompt did not complete after declining.'

    $loadedBook7 = Invoke-WebApiAction -Process $session -Request @{ action = 'loadGame'; path = [string]$book7SavePath }
    Assert-WebAutomationSmoke -Condition ([int]$loadedBook7.payload.character.BookNumber -eq 7) -Message 'Book 7 automation source did not load.'

    $sectionChoicePrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 333 }
    [void](Assert-PendingPrompt -Response $sectionChoicePrompt -ExpectedPrompt 'Section 333 choice' -ExpectedKind 'choiceTable' -ContextContains @('Section 333 Door Rack', 'Spear', 'Quarterstaff', '0. Done choosing'))
    $sectionChoiceDone = Invoke-WebApiAction -Process $session -Request @{ action = 'submitFlow'; data = @{ response = 0 } }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $sectionChoiceDone)) -Message 'Book 7 section-choice prompt did not complete after choosing 0.'

    $nestLootPrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 148 }
    [void](Assert-PendingPrompt -Response $nestLootPrompt -ExpectedPrompt 'Section 148 choice' -ExpectedKind 'choiceTable' -ContextContains @('Section 148 Nest Loot', 'Mace', 'Padded Leather Waistcoat', 'Potion of Laumspur', '0. Done choosing'))
    Assert-WebAutomationSmoke -Condition ([int]$nestLootPrompt.payload.reader.Section -eq 148) -Message 'Pending Book 7 section 148 loot prompt should still advance the reader pane to section 148.'
    Assert-WebAutomationSmoke -Condition ([int]$nestLootPrompt.payload.randomNumber.Section -eq 148) -Message 'Pending Book 7 section 148 should expose roll context for the reader section.'
    Assert-WebAutomationSmoke -Condition (-not [bool]$nestLootPrompt.payload.randomNumber.CanRoll) -Message 'Roll panel should wait until the section 148 loot prompt completes.'
    Assert-WebAutomationSmoke -Condition ([string]$nestLootPrompt.payload.randomNumber.Description -like '*0-4 -> 63; 5-9 -> 346*') -Message 'Book 7 section 148 roll context is missing destination ranges while the loot prompt is pending.'
    $nestLootDone = Invoke-WebApiAction -Process $session -Request @{ action = 'submitFlow'; data = @{ response = 0 } }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $nestLootDone)) -Message 'Book 7 section 148 loot prompt did not complete after choosing 0.'
    Assert-WebAutomationSmoke -Condition ([bool]$nestLootDone.payload.randomNumber.CanRoll) -Message 'Roll panel should enable after the section 148 loot prompt completes.'
    Assert-WebAutomationSmoke -Condition ([int]$nestLootDone.payload.randomNumber.Modifier -eq 0) -Message 'Book 7 section 148 roll context should report no automatic modifier.'
    $rollResult = Invoke-WebApiAction -Process $session -Request @{ action = 'safeCommand'; command = 'roll' }
    Assert-WebAutomationSmoke -Condition ([string]$rollResult.message -eq 'Ran command: roll') -Message 'Web safe command roll did not run.'
    Assert-WebAutomationSmoke -Condition ($null -ne $rollResult.payload.randomNumber.LastRoll) -Message 'Roll panel payload did not remember the latest roll.'
    Assert-WebAutomationSmoke -Condition ([int]$rollResult.payload.randomNumber.LastRoll.Section -eq 148) -Message 'Roll panel payload remembered the latest roll for the wrong section.'
    $rollNotifications = @($rollResult.payload.session.Notifications | ForEach-Object { [string]$_.Message })
    Assert-WebAutomationSmoke -Condition (($rollNotifications -join "`n").Contains('Random Number Table roll')) -Message 'Web safe command roll did not return the random-number notification.'
    Assert-WebAutomationSmoke -Condition (($rollNotifications -join "`n").Contains('0-4 -> 63; 5-9 -> 346')) -Message 'Book 7 section 148 roll notification did not include the destination ranges.'

    $book7EnduranceBeforeConfiscation = [int]$rollResult.payload.character.EnduranceCurrent
    $confiscated = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 335 }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $confiscated)) -Message 'Book 7 section 335 confiscation should complete without a pending prompt.'
    Assert-WebAutomationSmoke -Condition ([int]$confiscated.payload.reader.Section -eq 335) -Message 'Book 7 section 335 confiscation should leave the reader on section 335.'
    Assert-WebAutomationSmoke -Condition ([int]$confiscated.payload.character.EnduranceCurrent -le ($book7EnduranceBeforeConfiscation - 1)) -Message 'Book 7 section 335 should apply at least the 1 ENDURANCE loss.'
    Assert-WebAutomationSmoke -Condition (@($confiscated.payload.inventory.Weapons).Count -eq 0) -Message 'Book 7 section 335 should remove all carried Weapons.'
    Assert-WebAutomationSmoke -Condition (@($confiscated.payload.inventory.BackpackItems).Count -eq 0) -Message 'Book 7 section 335 should remove Backpack Items.'
    Assert-WebAutomationSmoke -Condition (@($confiscated.payload.inventory.SpecialItems).Count -eq 0) -Message 'Book 7 section 335 should remove carried Special Items.'
    Assert-WebAutomationSmoke -Condition (@($confiscated.payload.inventory.PocketSpecialItems).Count -eq 0) -Message 'Book 7 section 335 should empty Pocket Items.'
    Assert-WebAutomationSmoke -Condition ([int]$confiscated.payload.inventory.GoldCrowns -eq 0) -Message 'Book 7 section 335 should remove carried Gold Crowns.'
    Assert-WebAutomationSmoke -Condition (-not [bool]$confiscated.payload.inventory.HasBackpack) -Message 'Book 7 section 335 should leave the Backpack unavailable.'
    Assert-WebAutomationSmoke -Condition ((@($confiscated.payload.inventory.Confiscated.Weapons) -contains 'Sword' -and @($confiscated.payload.inventory.Confiscated.Weapons) -contains 'Bow')) -Message 'Book 7 section 335 should stash removed Weapons as confiscated gear.'
    Assert-WebAutomationSmoke -Condition ((@($confiscated.payload.inventory.Confiscated.SpecialItems) -contains 'Sommerswerd' -and @($confiscated.payload.inventory.Confiscated.SpecialItems) -contains 'Helmet')) -Message 'Book 7 section 335 should stash removed Special Items as confiscated gear.'
    Assert-WebAutomationSmoke -Condition ((@($confiscated.payload.inventory.Confiscated.BackpackItems) -contains 'Meal')) -Message 'Book 7 section 335 should stash removed Backpack Items as confiscated gear.'
    Assert-WebAutomationSmoke -Condition ((@($confiscated.payload.inventory.Confiscated.PocketSpecialItems) -contains 'Power-key')) -Message 'Book 7 section 335 should stash removed Pocket Items as confiscated gear.'
    Assert-WebAutomationSmoke -Condition ([int]$confiscated.payload.inventory.Confiscated.GoldCrowns -eq 50) -Message 'Book 7 section 335 should stash removed Gold Crowns as confiscated gear.'
    $confiscationNotifications = @($confiscated.payload.session.Notifications | ForEach-Object { [string]$_.Message })
    Assert-WebAutomationSmoke -Condition (($confiscationNotifications -join "`n").Contains('all carried gear confiscated for later recovery')) -Message 'Book 7 section 335 should report confiscated gear.'

    $loadedFullBook7 = Invoke-WebApiAction -Process $session -Request @{ action = 'loadGame'; path = [string]$book7FullSavePath }
    Assert-WebAutomationSmoke -Condition (@($loadedFullBook7.payload.inventory.BackpackItems).Count -ge 8) -Message 'Full-backpack automation source did not load as full.'

    $recoveryPrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'setSection'; section = 15 }
    [void](Assert-PendingPrompt -Response $recoveryPrompt -ExpectedPrompt 'Section 15 choice' -ExpectedKind 'choiceTable' -ContextContains @('Section 15 Recovery', 'Concentrated Laumspur', 'Kazan-Oud Platinum Amulet'))

    $makeRoomPrompt = Invoke-WebApiAction -Process $session -Request @{ action = 'submitFlow'; data = @{ response = 1 } }
    [void](Assert-PendingPrompt -Response $makeRoomPrompt -ExpectedPrompt 'Review inventory and make room now?' -ExpectedKind 'makeRoomConfirm' -ContextContains @('Section 15 Recovery'))
    Assert-WebAutomationSmoke -Condition ([bool]$makeRoomPrompt.payload.session.HasState) -Message 'Make-room prompt should keep the run active.'
    Assert-WebAutomationSmoke -Condition (@($makeRoomPrompt.payload.inventory.Sections.backpack.Slots).Count -eq 8) -Message 'Make-room prompt payload should include backpack slot shape for the browser companion panel.'

    $cancelled = Invoke-WebApiAction -Process $session -Request @{ action = 'cancelFlow' }
    Assert-WebAutomationSmoke -Condition ($null -eq (Get-PendingFlow -Response $cancelled)) -Message 'cancelFlow did not clear the make-room prompt.'

    '[PASS] Web parity automation smoke'
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
