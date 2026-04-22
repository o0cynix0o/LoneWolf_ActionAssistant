#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ShellLabel = 'PS',
    [string]$OutputText = '',
    [string]$OutputJson = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = 'C:\Scripts\Lone Wolf'
$testingRoot = Join-Path $repoRoot 'testing'
$logRoot = Join-Path $testingRoot 'logs'
$runtimeRoot = Join-Path $testingRoot ("runtime\prerelease-command-surface-{0}" -f $ShellLabel.ToLowerInvariant())
$runtimeDataDir = Join-Path $runtimeRoot 'data'
$playtestSaveDir = Join-Path $testingRoot ("saves\prerelease-command-surface-{0}" -f $ShellLabel.ToLowerInvariant())
$baseSavePath = Join-Path $playtestSaveDir 'playtest-cmd-surface.json'
$workSavePath = Join-Path $playtestSaveDir 'playtest-cmd-surface-work.json'
$newSavePath = Join-Path $playtestSaveDir 'playtest-cmd-surface-new.json'
$loadAlphaPath = Join-Path $playtestSaveDir 'playtest-cmd-surface-alpha.json'
$loadBetaPath = Join-Path $playtestSaveDir 'playtest-cmd-surface-beta.json'
$loadGammaPath = Join-Path $playtestSaveDir 'playtest-cmd-surface-gamma.json'

if ([string]::IsNullOrWhiteSpace($OutputText)) {
    $OutputText = Join-Path $logRoot ("COMMAND_SURFACE_PRERELEASE_{0}.txt" -f $ShellLabel.ToUpperInvariant())
}
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
    $OutputJson = Join-Path $logRoot ("COMMAND_SURFACE_PRERELEASE_{0}.json" -f $ShellLabel.ToUpperInvariant())
}

foreach ($dir in @($logRoot, $runtimeRoot, $runtimeDataDir, $playtestSaveDir)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

foreach ($item in @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'data') -File -Filter '*.json')) {
    Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $runtimeDataDir $item.Name) -Force
}
Remove-Item -LiteralPath (Join-Path $runtimeDataDir 'last-save.txt') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $runtimeDataDir 'error.log') -Force -ErrorAction SilentlyContinue

$hostScriptPath = Join-Path $repoRoot 'lonewolf.ps1'
. $hostScriptPath -SaveDir $playtestSaveDir -DataDir $runtimeDataDir
Initialize-LWData
$script:LWUi.Enabled = $true

foreach ($command in @(Get-Command -CommandType Function | Where-Object { $null -ne $_.ScriptBlock -and [string]$_.ScriptBlock.File -eq $hostScriptPath })) {
    Set-Item -Path ("Function:\global:{0}" -f $command.Name) -Value $command.ScriptBlock
}

$global:PlaytestPromptQueue = [System.Collections.Generic.Queue[string]]::new()
$global:PlaytestPromptLog = @()

function global:Read-Host {
    param([string]$Prompt = '')

    if ($global:PlaytestPromptQueue.Count -le 0) {
        throw "Unexpected prompt: $Prompt"
    }

    $response = [string]$global:PlaytestPromptQueue.Dequeue()
    $global:PlaytestPromptLog += [pscustomobject]@{
        Prompt   = $Prompt
        Response = $response
    }
    return $response
}

function Set-PlaytestPromptResponses {
    param([string[]]$Responses = @())

    $global:PlaytestPromptQueue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($response in @($Responses)) {
        $global:PlaytestPromptQueue.Enqueue([string]$response)
    }
    $global:PlaytestPromptLog = @()
}

function Invoke-WithPromptResponses {
    param(
        [string[]]$Responses = @(),
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Set-PlaytestPromptResponses -Responses @($Responses)
    & $Action
    return [pscustomobject]@{
        Prompts = @($global:PlaytestPromptLog)
        Unused  = @($global:PlaytestPromptQueue.ToArray())
    }
}

function Get-NotificationLines {
    if ($null -eq $script:LWUi -or $null -eq $script:LWUi.Notifications) {
        return @()
    }

    return @(
        foreach ($notification in @($script:LWUi.Notifications)) {
            if ($null -eq $notification) {
                continue
            }

            $level = if ((Test-LWPropertyExists -Object $notification -Name 'Level') -and -not [string]::IsNullOrWhiteSpace([string]$notification.Level)) { [string]$notification.Level } else { 'info' }
            $message = if ((Test-LWPropertyExists -Object $notification -Name 'Message') -and -not [string]::IsNullOrWhiteSpace([string]$notification.Message)) { [string]$notification.Message } else { '' }
            ("{0}: {1}" -f $level, $message.Trim())
        }
    )
}

function Copy-BaseSave {
    param([Parameter(Mandatory = $true)][string]$DestinationPath)
    Copy-Item -LiteralPath $baseSavePath -Destination $DestinationPath -Force
}

function Ensure-BaseSave {
    foreach ($path in @($baseSavePath, $workSavePath, $newSavePath, $loadAlphaPath, $loadBetaPath, $loadGammaPath)) {
        Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    }

    $script:GameState = New-LWDefaultState
    Set-LWScreen -Name 'welcome'
    Clear-LWNotifications

    $responses = @(
        '3',
        'n',
        'y',
        'Playtest Hero',
        '1',
        '1',
        '1,2,3,4,5',
        'y',
        $baseSavePath,
        'n'
    )

    Invoke-WithPromptResponses -Responses $responses -Action {
        Invoke-LWCommand -InputLine 'new' | Out-Null
        Refresh-LWScreen
    } | Out-Null

    if (-not (Test-Path -LiteralPath $baseSavePath)) {
        throw "Base playtest save was not created at $baseSavePath"
    }
}

function Ensure-LoadCatalog {
    Copy-BaseSave -DestinationPath $loadAlphaPath
    Copy-BaseSave -DestinationPath $loadBetaPath
    Copy-BaseSave -DestinationPath $loadGammaPath

    $alpha = Get-Content -LiteralPath $loadAlphaPath -Raw | ConvertFrom-Json
    $beta = Get-Content -LiteralPath $loadBetaPath -Raw | ConvertFrom-Json
    $gamma = Get-Content -LiteralPath $loadGammaPath -Raw | ConvertFrom-Json

    $alpha.Character.Name = 'Alpha'
    $alpha.CurrentSection = 7
    $alpha.Settings.SavePath = $loadAlphaPath
    Sync-LWRunIntegrityState -State $alpha -Reseal
    $alpha | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $loadAlphaPath -Encoding UTF8

    $beta.Character.Name = 'Beta'
    $beta.CurrentSection = 10
    $beta.Settings.SavePath = $loadBetaPath
    Sync-LWRunIntegrityState -State $beta -Reseal
    $beta | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $loadBetaPath -Encoding UTF8

    $gamma.Character.Name = 'Gamma'
    $gamma.CurrentSection = 14
    $gamma.Settings.SavePath = $loadGammaPath
    Sync-LWRunIntegrityState -State $gamma -Reseal
    $gamma | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $loadGammaPath -Encoding UTF8

    (Get-Item -LiteralPath $loadGammaPath).LastWriteTime = (Get-Date).AddMinutes(-1)
    (Get-Item -LiteralPath $loadBetaPath).LastWriteTime = (Get-Date)
    (Get-Item -LiteralPath $loadAlphaPath).LastWriteTime = (Get-Date).AddMinutes(-2)
}

function Prepare-NoState {
    Remove-Item -LiteralPath $workSavePath -Force -ErrorAction SilentlyContinue
    $script:GameState = New-LWDefaultState
    $script:GameState.Settings.DataDir = $runtimeDataDir
    Set-LWScreen -Name 'welcome'
    Clear-LWNotifications
}

function Prepare-LoadedState {
    Copy-BaseSave -DestinationPath $workSavePath
    Load-LWGame -Path $workSavePath
    $script:GameState.Settings.AutoSave = $false
    $script:GameState.Settings.SavePath = $workSavePath
    Set-LWScreen -Name 'sheet'
    Clear-LWNotifications
}

function Prepare-LoadedNoteState {
    Prepare-LoadedState
    $script:GameState.Character.Notes = @('Note one', 'Note two')
    Clear-LWNotifications
}

function Prepare-LoadedMealState {
    Prepare-LoadedState
    $script:GameState.Character.Disciplines = @($script:GameState.Character.Disciplines | Where-Object { [string]$_ -ine 'Hunting' })
    $script:GameState.Inventory.BackpackItems = @('Meal', 'Meal')
    Clear-LWNotifications
}

function Prepare-LoadedPotionState {
    Prepare-LoadedState
    $script:GameState.Character.EnduranceCurrent = [Math]::Max(1, ([int]$script:GameState.Character.EnduranceMax - 5))
    $script:GameState.Inventory.BackpackItems = @('Potion of Laumspur', 'Meal')
    Clear-LWNotifications
}

function Prepare-LoadedHerbPouchState {
    Prepare-LoadedState
    $script:GameState.RuleSet = 'Magnakai'
    $script:GameState.Character.BookNumber = 6
    $script:GameState.Character.LegacyKaiComplete = $true
    $script:GameState.Character.MagnakaiDisciplines = @('Curing', 'Weaponmastery', 'Animal Control')
    $script:GameState.Character.MagnakaiRank = 3
    Set-LWBookSixDECuringOption -State $script:GameState -Option 3
    $script:GameState.Inventory.HasHerbPouch = $false
    $script:GameState.Inventory.HerbPouchItems = @()
    $script:GameState.Inventory.BackpackItems = @('Potion of Laumspur')
    Clear-LWNotifications
}

function Prepare-LoadedQuiverState {
    Prepare-LoadedState
    $script:GameState.Inventory.SpecialItems = @($script:GameState.Inventory.SpecialItems | Where-Object { [string]$_ -ine 'Quiver' })
    $script:GameState.Inventory.BackpackItems = @()
    $script:GameState.Inventory.QuiverArrows = 0
    Clear-LWNotifications
}

function Prepare-LoadedRecoveryBackpackState {
    Prepare-LoadedState
    $script:GameState.Inventory.BackpackItems = @('Torch', 'Meal')
    Remove-LWInventorySection -Type 'backpack'
    Clear-LWNotifications
}

function Prepare-LoadedRecoveryWeaponState {
    Prepare-LoadedState
    $script:GameState.Inventory.Weapons = @('Short Sword', 'Broadsword')
    Remove-LWInventorySection -Type 'weapon'
    Clear-LWNotifications
}

function Prepare-LoadedRecoverySpecialState {
    Prepare-LoadedState
    $script:GameState.Inventory.SpecialItems = @('Crystal Star Pendant', 'Map of Sommerlund')
    Remove-LWInventorySection -Type 'special'
    Clear-LWNotifications
}

function Prepare-LoadedDeathState {
    Prepare-LoadedState
    if (@($script:GameState.SectionCheckpoints).Count -lt 2) {
        Save-LWCurrentSectionCheckpoint
        $script:GameState.CurrentSection = [int]$script:GameState.CurrentSection + 1
        Save-LWCurrentSectionCheckpoint
    }
    Invoke-LWInstantDeath -Cause 'Harness death'
    Clear-LWNotifications
}

function Prepare-LoadedDeathNoCheckpointsState {
    Prepare-LoadedState
    Reset-LWSectionCheckpoints -SeedCurrentSection
    Invoke-LWInstantDeath -Cause 'Harness death'
    Clear-LWNotifications
}

function Prepare-LoadedFightReadyState {
    Prepare-LoadedState
    $script:GameState.Settings.CombatMode = 'DataFile'
    $script:GameState.Inventory.Weapons = @('Short Sword')
    $script:GameState.Inventory.SpecialItems = @($script:GameState.Inventory.SpecialItems | Where-Object { [string]$_ -ine 'Quiver' })
    Clear-LWNotifications
}

function Prepare-LoadedCombatState {
    param([switch]$CanEvade)

    Prepare-LoadedFightReadyState
    Invoke-WithPromptResponses -Responses @('y') -Action {
        Start-LWCombat -Arguments @('TestEnemy', '10', '6') | Out-Null
    } | Out-Null
    if ($CanEvade) {
        $script:GameState.Combat.CanEvade = $true
    }
    Clear-LWNotifications
}

function Prepare-LoadedBackpackFullState {
    Prepare-LoadedState
    $script:GameState.Inventory.BackpackItems = @('Meal', 'Meal', 'Meal', 'Meal', 'Meal', 'Meal', 'Meal', 'Meal')
    Clear-LWNotifications
}

function Prepare-LoadedBackpackSevenState {
    Prepare-LoadedState
    $script:GameState.Inventory.BackpackItems = @('Meal', 'Meal', 'Meal', 'Meal', 'Meal', 'Meal', 'Meal')
    Clear-LWNotifications
}

function Prepare-LoadedWeaponFullState {
    Prepare-LoadedState
    $script:GameState.Inventory.Weapons = @('Sword', 'Broadsword')
    Clear-LWNotifications
}

function Prepare-LoadedWeaponOpenState {
    Prepare-LoadedState
    $script:GameState.Inventory.Weapons = @('Dagger')
    Clear-LWNotifications
}

function Prepare-LoadedNoWeaponsState {
    Prepare-LoadedState
    $script:GameState.Inventory.Weapons = @()
    Clear-LWNotifications
}

function Initialize-Scenario {
    param([string]$Scenario)

    switch ($Scenario) {
        'no-state'                    { Prepare-NoState }
        'loaded'                      { Prepare-LoadedState }
        'loaded-note'                 { Prepare-LoadedNoteState }
        'loaded-meal'                 { Prepare-LoadedMealState }
        'loaded-potion'               { Prepare-LoadedPotionState }
        'loaded-herbpouch'            { Prepare-LoadedHerbPouchState }
        'loaded-quiver'               { Prepare-LoadedQuiverState }
        'loaded-recovery-backpack'    { Prepare-LoadedRecoveryBackpackState }
        'loaded-recovery-weapon'      { Prepare-LoadedRecoveryWeaponState }
        'loaded-recovery-special'     { Prepare-LoadedRecoverySpecialState }
        'loaded-death'                { Prepare-LoadedDeathState }
        'loaded-death-no-checkpoints' { Prepare-LoadedDeathNoCheckpointsState }
        'loaded-fight-ready'          { Prepare-LoadedFightReadyState }
        'loaded-combat'               { Prepare-LoadedCombatState }
        'loaded-combat-evade'         { Prepare-LoadedCombatState -CanEvade }
        'loaded-backpack-full'        { Prepare-LoadedBackpackFullState }
        'loaded-backpack-seven'       { Prepare-LoadedBackpackSevenState }
        'loaded-weapon-full'          { Prepare-LoadedWeaponFullState }
        'loaded-weapon-open'          { Prepare-LoadedWeaponOpenState }
        'loaded-no-weapons'           { Prepare-LoadedNoWeaponsState }
        default                       { throw "Unknown scenario: $Scenario" }
    }
}

function Assert-NotificationContains {
    param(
        [Parameter(Mandatory = $true)][string[]]$Notifications,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    return (@($Notifications | Where-Object { $_ -match $Pattern }).Count -gt 0)
}

function New-Case {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Scenario,
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Responses = @(),
        [scriptblock]$Setup = $null,
        [scriptblock]$Assert = $null
    )

    return [pscustomobject]@{
        Name      = $Name
        Scenario  = $Scenario
        Command   = $Command
        Responses = @($Responses)
        Setup     = $Setup
        Assert    = $Assert
    }
}

Ensure-BaseSave
Ensure-LoadCatalog

$cases = @(
    (New-Case -Name 'new' -Scenario 'no-state' -Command 'new' -Responses @('3', 'n', 'y', 'Surface New', '1', '1', '1,2,3,4,5', 'y', $newSavePath, 'n') -Assert {
            $errors = @()
            if (-not (Test-Path -LiteralPath $newSavePath)) { $errors += 'new did not create the requested save.' }
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'New Normal run created')) { $errors += 'new did not report successful run creation.' }
            return @($errors)
        })
    (New-Case -Name 'sheet' -Scenario 'loaded' -Command 'sheet')
    (New-Case -Name 'modes' -Scenario 'loaded' -Command 'modes')
    (New-Case -Name 'difficulty' -Scenario 'loaded' -Command 'difficulty')
    (New-Case -Name 'difficulty Normal' -Scenario 'loaded' -Command 'difficulty Normal' -Assert {
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'Difficulty remains Normal')) { return @('difficulty Normal did not confirm the locked difficulty.') }
            return @()
        })
    (New-Case -Name 'disciplines' -Scenario 'loaded' -Command 'disciplines')
    (New-Case -Name 'discipline add Mindblast' -Scenario 'loaded' -Command 'discipline add Mindblast' -Assert {
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Mindblast')) { return @('Mindblast was not added.') }
            return @()
        })
    (New-Case -Name 'section 10' -Scenario 'loaded' -Command 'section 10' -Assert {
            if ([int]$script:GameState.CurrentSection -ne 10) { return @('section 10 did not update the current section.') }
            return @()
        })
    (New-Case -Name 'section 1' -Scenario 'loaded' -Command 'section 1' -Assert {
            if ([int]$script:GameState.CurrentSection -ne 1) { return @('section 1 did not update the current section.') }
            return @()
        })
    (New-Case -Name 'history' -Scenario 'loaded' -Command 'history')
    (New-Case -Name 'stats' -Scenario 'loaded' -Command 'stats')
    (New-Case -Name 'stats combat' -Scenario 'loaded' -Command 'stats combat')
    (New-Case -Name 'stats survival' -Scenario 'loaded' -Command 'stats survival')
    (New-Case -Name 'campaign' -Scenario 'loaded' -Command 'campaign')
    (New-Case -Name 'campaign books' -Scenario 'loaded' -Command 'campaign books')
    (New-Case -Name 'campaign combat' -Scenario 'loaded' -Command 'campaign combat')
    (New-Case -Name 'campaign survival' -Scenario 'loaded' -Command 'campaign survival')
    (New-Case -Name 'campaign milestones' -Scenario 'loaded' -Command 'campaign milestones')
    (New-Case -Name 'help' -Scenario 'loaded' -Command 'help')
    (New-Case -Name 'notes' -Scenario 'loaded' -Command 'notes')
    (New-Case -Name 'note add' -Scenario 'loaded' -Command 'note This is a test note' -Assert {
            if (@($script:GameState.Character.Notes | Where-Object { [string]$_ -eq 'This is a test note' }).Count -ne 1) { return @('note did not add the requested text.') }
            return @()
        })
    (New-Case -Name 'note remove 1' -Scenario 'loaded-note' -Command 'note remove 1' -Assert {
            if (@($script:GameState.Character.Notes).Count -ne 1) { return @('note remove 1 did not remove the first note.') }
            return @()
        })
    (New-Case -Name 'inv' -Scenario 'loaded' -Command 'inv')
    (New-Case -Name 'add backpack Potion of Laumspur' -Scenario 'loaded' -Command 'add backpack Potion of Laumspur' -Assert {
            $expectedName = [string](Get-LWCanonicalInventoryItemName -Name 'Potion of Laumspur')
            if (@($script:GameState.Inventory.BackpackItems | Where-Object { [string]$_ -eq $expectedName }).Count -lt 1) { return @('add backpack did not add the potion.') }
            return @()
        })
    (New-Case -Name 'add backpack Meal' -Scenario 'loaded' -Command 'add backpack Meal' -Assert {
            if (@($script:GameState.Inventory.BackpackItems | Where-Object { [string]$_ -eq 'Meal' }).Count -lt 1) { return @('add backpack Meal did not add a meal.') }
            return @()
        })
    (New-Case -Name 'add weapon Sword' -Scenario 'loaded-weapon-open' -Command 'add weapon Sword' -Assert {
            if (@($script:GameState.Inventory.Weapons | Where-Object { [string]$_ -eq 'Sword' }).Count -lt 1) { return @('add weapon Sword did not add a sword.') }
            return @()
        })
    (New-Case -Name 'add weapon Broadsword' -Scenario 'loaded' -Command 'add weapon Broadsword')
    (New-Case -Name 'add special Crystal Star Pendant' -Scenario 'loaded' -Command 'add special Crystal Star Pendant')
    (New-Case -Name 'drop backpack 1' -Scenario 'loaded' -Command 'drop backpack 1' -Setup { $script:GameState.Inventory.BackpackItems = @('Meal', 'Torch') } -Assert {
            if (@($script:GameState.Inventory.BackpackItems).Count -ne 1) { return @('drop backpack 1 did not remove one backpack item.') }
            return @()
        })
    (New-Case -Name 'drop backpack all' -Scenario 'loaded' -Command 'drop backpack all' -Setup { $script:GameState.Inventory.BackpackItems = @('Meal', 'Torch') } -Assert {
            $errors = @()
            $recoveryItems = @(Get-LWInventoryRecoveryItems -Type 'backpack')
            if (@($script:GameState.Inventory.BackpackItems).Count -ne 0) { $errors += 'drop backpack all did not clear the backpack.' }
            if ($recoveryItems.Count -lt 2) { $errors += 'drop backpack all did not stash removed items for recovery.' }
            return @($errors)
        })
    (New-Case -Name 'recover backpack' -Scenario 'loaded-recovery-backpack' -Command 'recover backpack' -Assert {
            if (@($script:GameState.Inventory.BackpackItems).Count -lt 2) { return @('recover backpack did not restore the stashed backpack items.') }
            return @()
        })
    (New-Case -Name 'add backpack overflow' -Scenario 'loaded-backpack-full' -Command 'add backpack Meal' -Assert {
            $errors = @()
            if ((Get-LWInventoryUsedCapacity -Type 'backpack' -Items @($script:GameState.Inventory.BackpackItems)) -gt 8) { $errors += 'Backpack overflowed past 8 slots.' }
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'Backpack')) { $errors += 'Overflow add did not emit a backpack warning.' }
            return @($errors)
        })
    (New-Case -Name 'add weapon third slot' -Scenario 'loaded-weapon-full' -Command 'add weapon Dagger' -Assert {
            $errors = @()
            if (@($script:GameState.Inventory.Weapons).Count -ne 2) { $errors += 'Third weapon add did not preserve the 2-weapon cap.' }
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'only carry 2 weapons|replace')) { $errors += 'Third weapon add did not warn or prompt about the 2-weapon cap.' }
            return @($errors)
        })
    (New-Case -Name 'add Long Rope with one slot left' -Scenario 'loaded-backpack-seven' -Command 'add backpack Long Rope' -Assert {
            $errors = @()
            if (@($script:GameState.Inventory.BackpackItems | Where-Object { [string]$_ -eq 'Long Rope' }).Count -gt 0) { $errors += 'Long Rope was added even though only one backpack slot remained.' }
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'needs 2 backpack slots|no free backpack slots|cannot carry')) { $errors += 'Long Rope refusal did not emit the expected capacity warning.' }
            return @($errors)
        })
    (New-Case -Name 'drop weapon 2' -Scenario 'loaded' -Command 'drop weapon 2' -Setup { $script:GameState.Inventory.Weapons = @('Sword', 'Broadsword') } -Assert {
            if (@($script:GameState.Inventory.Weapons).Count -ne 1) { return @('drop weapon 2 did not remove one weapon.') }
            return @()
        })
    (New-Case -Name 'recover weapon' -Scenario 'loaded-recovery-weapon' -Command 'recover weapon' -Assert {
            if (@($script:GameState.Inventory.Weapons).Count -lt 2) { return @('recover weapon did not restore stashed weapons.') }
            return @()
        })
    (New-Case -Name 'recover special' -Scenario 'loaded-recovery-special' -Command 'recover special' -Assert {
            if (@($script:GameState.Inventory.SpecialItems).Count -lt 2) { return @('recover special did not restore stashed special items.') }
            return @()
        })
    (New-Case -Name 'add special Quiver' -Scenario 'loaded-quiver' -Command 'add special Quiver' -Assert {
            if (-not (Test-LWStateHasQuiver -State $script:GameState)) { return @('add special Quiver did not add the quiver.') }
            return @()
        })
    (New-Case -Name 'add backpack Arrow 1' -Scenario 'loaded-quiver' -Command 'add backpack Arrow' -Setup {
            $script:GameState.Inventory.SpecialItems += 'Quiver'
            $script:GameState.Inventory.QuiverArrows = 0
        } -Assert {
            if ((Get-LWQuiverArrowCount -State $script:GameState) -lt 1) { return @('Arrow was not added to the quiver state.') }
            return @()
        })
    (New-Case -Name 'add backpack Arrow 2' -Scenario 'loaded-quiver' -Command 'add backpack Arrow' -Setup { $script:GameState.Inventory.SpecialItems += 'Quiver'; $script:GameState.Inventory.QuiverArrows = 1 } -Assert {
            if ((Get-LWQuiverArrowCount -State $script:GameState) -lt 2) { return @('Second arrow was not added to the quiver state.') }
            return @()
        })
    (New-Case -Name 'add special Herb Pouch' -Scenario 'loaded-herbpouch' -Command 'add special Herb Pouch' -Assert {
            if (-not (Test-LWStateHasHerbPouch -State $script:GameState)) { return @('Herb Pouch was not granted in the Book 6 DE scenario.') }
            return @()
        })
    (New-Case -Name 'herb pouch auto-placement' -Scenario 'loaded-herbpouch' -Command 'add backpack Potion of Laumspur' -Setup { Grant-LWHerbPouch | Out-Null } -Assert {
            $errors = @()
            $expectedName = [string](Get-LWCanonicalInventoryItemName -Name 'Potion of Laumspur')
            if (@($script:GameState.Inventory.HerbPouchItems | Where-Object { [string]$_ -eq $expectedName }).Count -lt 2) { $errors += 'Potion did not route into the Herb Pouch.' }
            return @($errors)
        })
    (New-Case -Name 'potion from herb pouch' -Scenario 'loaded-herbpouch' -Command 'potion' -Setup {
            Grant-LWHerbPouch | Out-Null
            $script:GameState.Inventory.HerbPouchItems = @('Potion of Laumspur')
            $script:GameState.Character.EnduranceCurrent = [Math]::Max(1, ([int]$script:GameState.Character.EnduranceMax - 4))
        } -Assert {
            $errors = @()
            if (@($script:GameState.Inventory.HerbPouchItems).Count -ne 0) { $errors += 'Potion command did not consume the Herb Pouch item.' }
            if ([int]$script:GameState.Character.EnduranceCurrent -le ([int]$script:GameState.Character.EnduranceMax - 4)) { $errors += 'Potion command did not restore endurance.' }
            return @($errors)
        })
    (New-Case -Name 'gold +10' -Scenario 'loaded' -Command 'gold +10' -Assert {
            if ([int]$script:GameState.Inventory.GoldCrowns -le 0) { return @('gold +10 did not update gold.') }
            return @()
        })
    (New-Case -Name 'gold -3' -Scenario 'loaded' -Command 'gold -3')
    (New-Case -Name 'gold' -Scenario 'loaded' -Command 'gold' -Responses @('0'))
    (New-Case -Name 'end -5' -Scenario 'loaded' -Command 'end -5')
    (New-Case -Name 'end +2' -Scenario 'loaded' -Command 'end +2')
    (New-Case -Name 'setend 20' -Scenario 'loaded' -Command 'setend 20' -Assert {
            if ([int]$script:GameState.Character.EnduranceCurrent -ne 20) { return @('setend 20 did not set current endurance to 20.') }
            return @()
        })
    (New-Case -Name 'setmaxend 25' -Scenario 'loaded' -Command 'setmaxend 25' -Assert {
            if ([int]$script:GameState.Character.EnduranceMax -ne 25) { return @('setmaxend 25 did not set max endurance to 25.') }
            return @()
        })
    (New-Case -Name 'setcs' -Scenario 'loaded' -Command 'setcs' -Responses @('20') -Assert {
            if ([int]$script:GameState.Character.CombatSkillBase -ne 20) { return @('setcs did not set base combat skill.') }
            return @()
        })
    (New-Case -Name 'healcheck' -Scenario 'loaded' -Command 'healcheck')
    (New-Case -Name 'meal' -Scenario 'loaded-meal' -Command 'meal')
    (New-Case -Name 'potion' -Scenario 'loaded-potion' -Command 'potion')
    (New-Case -Name 'meal second use' -Scenario 'loaded-meal' -Command 'meal' -Setup { $script:GameState.Character.EnduranceCurrent = [Math]::Max(1, ([int]$script:GameState.Character.EnduranceMax - 3)) })
    (New-Case -Name 'save' -Scenario 'loaded' -Command 'save' -Assert {
            if (-not (Test-Path -LiteralPath $workSavePath)) { return @('save did not write the active save file.') }
            return @()
        })
    (New-Case -Name 'load by number' -Scenario 'no-state' -Command 'load' -Responses @('2') -Assert {
            $errors = @()
            if ([string]$script:GameState.Character.Name -ne 'Beta') { $errors += 'Interactive load did not load the selected numbered save.' }
            if ([int]$script:GameState.CurrentSection -ne 10) { $errors += 'Interactive load did not restore the expected section from the numbered picker.' }
            return @($errors)
        })
    (New-Case -Name 'die test-cause' -Scenario 'loaded' -Command 'die test-cause' -Assert {
            if (-not (Test-LWDeathActive)) { return @('die did not enter a death state.') }
            return @()
        })
    (New-Case -Name 'rewind' -Scenario 'loaded-death' -Command 'rewind' -Assert {
            if (Test-LWDeathActive) { return @('rewind did not clear the death state.') }
            return @()
        })
    (New-Case -Name 'rewind 1' -Scenario 'loaded-death' -Command 'rewind 1' -Assert {
            if (Test-LWDeathActive) { return @('rewind 1 did not clear the death state.') }
            return @()
        })
    (New-Case -Name 'fail test-cause' -Scenario 'loaded' -Command 'fail test-cause' -Assert {
            if (-not (Test-LWDeathActive)) { return @('fail did not enter a terminal failure state.') }
            return @()
        })
    (New-Case -Name 'rewind after fail' -Scenario 'loaded-death' -Command 'rewind')
    (New-Case -Name 'rewind no checkpoint' -Scenario 'loaded-death-no-checkpoints' -Command 'rewind' -Assert {
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'No earlier safe section is available')) { return @('rewind without earlier checkpoints did not warn cleanly.') }
            return @()
        })
    (New-Case -Name 'mode data' -Scenario 'loaded' -Command 'mode data')
    (New-Case -Name 'combat start' -Scenario 'loaded-fight-ready' -Command 'combat start TestEnemy 15 20' -Responses @('y') -Assert {
            if (-not $script:GameState.Combat.Active) { return @('combat start did not begin combat.') }
            return @()
        })
    (New-Case -Name 'combat status' -Scenario 'loaded-combat' -Command 'combat status')
    (New-Case -Name 'combat round' -Scenario 'loaded-combat' -Command 'combat round')
    (New-Case -Name 'combat log' -Scenario 'loaded' -Command 'combat log')
    (New-Case -Name 'combat log all' -Scenario 'loaded' -Command 'combat log all')
    (New-Case -Name 'combat stop' -Scenario 'loaded-combat' -Command 'combat stop' -Assert {
            if ($script:GameState.Combat.Active) { return @('combat stop did not end the active combat.') }
            return @()
        })
    (New-Case -Name 'mode manual' -Scenario 'loaded' -Command 'mode manual')
    (New-Case -Name 'manual combat start' -Scenario 'loaded-fight-ready' -Command 'combat start TestEnemy 12 15' -Setup { $script:GameState.Settings.CombatMode = 'ManualCRT' } -Responses @('y') -Assert {
            if (-not $script:GameState.Combat.Active) { return @('manual combat start did not begin combat.') }
            return @()
        })
    (New-Case -Name 'combat evade' -Scenario 'loaded-combat-evade' -Command 'combat evade')
    (New-Case -Name 'fight quickstart' -Scenario 'loaded-fight-ready' -Command 'fight TestEnemy 14 18' -Responses @('y'))
    (New-Case -Name 'combat auto' -Scenario 'loaded-combat' -Command 'combat auto')
    (New-Case -Name 'combat log book 1' -Scenario 'loaded' -Command 'combat log book 1')
    (New-Case -Name 'combat log book 2' -Scenario 'loaded' -Command 'combat log book 2')
    (New-Case -Name 'combat no weapons' -Scenario 'loaded-no-weapons' -Command 'combat start TestEnemy 10 10' -Responses @('y') -Assert {
            $errors = @()
            if (-not $script:GameState.Combat.Active) { $errors += 'combat start with no weapons did not begin unarmed combat cleanly.' }
            if ($null -ne $script:GameState.Combat.EquippedWeapon -and -not [string]::IsNullOrWhiteSpace([string]$script:GameState.Combat.EquippedWeapon)) { $errors += 'combat no weapons did not stay unarmed.' }
            return @($errors)
        })
    (New-Case -Name 'discipline add Animal Kinship' -Scenario 'loaded' -Command 'discipline add Animal Kinship' -Assert {
            if (-not (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Kinship')) { return @('Animal Kinship was not added.') }
            return @()
        })
    (New-Case -Name 'modes again' -Scenario 'loaded' -Command 'modes')
    (New-Case -Name 'difficulty Hard' -Scenario 'loaded' -Command 'difficulty Hard' -Assert {
            if (-not (Assert-NotificationContains -Notifications (Get-NotificationLines) -Pattern 'Difficulty is locked to Normal')) { return @('difficulty Hard did not warn that the run is locked to Normal.') }
            return @()
        })
    (New-Case -Name 'newrun' -Scenario 'loaded' -Command 'newrun' -Responses @('y', '4', 'n', 'y', 'Playtest Hero Hard', '1', '1', '1,2,3,4,5') -Assert {
            $errors = @()
            if ([string](Get-LWCurrentDifficulty) -ne 'Hard') { $errors += 'newrun did not start a Hard run.' }
            if (@($script:GameState.RunHistory).Count -lt 1) { $errors += 'newrun did not archive the prior run.' }
            return @($errors)
        })
)

$results = @()
foreach ($case in $cases) {
    $entry = [ordered]@{
        Name          = [string]$case.Name
        Command       = [string]$case.Command
        Scenario      = [string]$case.Scenario
        Passed        = $true
        Screen        = $null
        ReturnValue   = $null
        Notifications = @()
        Prompts       = @()
        UnusedInput   = @()
        Assertion     = @()
        Exception     = $null
    }

    try {
        Initialize-Scenario -Scenario ([string]$case.Scenario)
        if ($null -ne $case.Setup) {
            & $case.Setup
        }

        $promptState = Invoke-WithPromptResponses -Responses @($case.Responses) -Action {
            $script:__surfaceReturn = Invoke-LWCommand -InputLine ([string]$case.Command)
            if ($script:__surfaceReturn -ne 'quit') {
                Refresh-LWScreen
            }
        }

        $entry.ReturnValue = $script:__surfaceReturn
        $entry.Screen = if ($null -ne $script:LWUi) { [string]$script:LWUi.CurrentScreen } else { $null }
        $entry.Notifications = @(Get-NotificationLines)
        $entry.Prompts = @($promptState.Prompts)
        $entry.UnusedInput = @($promptState.Unused)

        if (@($entry.Notifications | Where-Object { $_ -match 'Unknown command:' -or $_ -match 'Unknown combat subcommand' }).Count -gt 0) {
            $entry.Passed = $false
            $entry.Exception = 'Command routed to unknown-command handling.'
        }
        elseif (@($entry.UnusedInput).Count -gt 0) {
            $entry.Passed = $false
            $entry.Exception = ("Unused prompt input remained: {0}" -f (@($entry.UnusedInput) -join ', '))
        }
        elseif ($case.Command -notmatch '^(die|fail)\b' -and @($entry.Notifications | Where-Object { $_ -match '^error:' }).Count -gt 0) {
            $entry.Passed = $false
            $entry.Exception = 'Command emitted an error-level notification.'
        }

        if ($entry.Passed -and $null -ne $case.Assert) {
            $assertionErrors = @(& $case.Assert)
            $entry.Assertion = @($assertionErrors)
            if (@($assertionErrors).Count -gt 0) {
                $entry.Passed = $false
                $entry.Exception = (@($assertionErrors) -join ' || ')
            }
        }
    }
    catch {
        $entry.Passed = $false
        $entry.Exception = $_.Exception.Message
        $entry.Notifications = @(Get-NotificationLines)
        $entry.Screen = if ($null -ne $script:LWUi) { [string]$script:LWUi.CurrentScreen } else { $null }
        $entry.Prompts = @($global:PlaytestPromptLog)
    }

    $results += [pscustomobject]$entry
}

$summary = [pscustomobject]@{
    Timestamp    = (Get-Date).ToString('o')
    ShellVersion = $PSVersionTable.PSVersion.ToString()
    ShellLabel   = $ShellLabel
    Passed       = @($results | Where-Object { $_.Passed }).Count
    Failed       = @($results | Where-Object { -not $_.Passed }).Count
    Total        = @($results).Count
    Results      = @($results)
}

$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputJson -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add(("Command Surface Prerelease - {0}" -f $ShellLabel))
[void]$lines.Add(("Shell Version: {0}" -f $summary.ShellVersion))
[void]$lines.Add(("Passed: {0}/{1}" -f $summary.Passed, $summary.Total))
[void]$lines.Add(("Failed: {0}" -f $summary.Failed))
[void]$lines.Add('')

foreach ($result in @($results)) {
    [void]$lines.Add(("[{0}] {1}" -f $(if ($result.Passed) { 'PASS' } else { 'FAIL' }), $result.Command))
    [void]$lines.Add(("  Scenario: {0}" -f $result.Scenario))
    [void]$lines.Add(("  Screen:   {0}" -f $(if ([string]::IsNullOrWhiteSpace([string]$result.Screen)) { '(none)' } else { [string]$result.Screen })))
    if ($null -ne $result.ReturnValue) {
        [void]$lines.Add(("  Return:   {0}" -f [string]$result.ReturnValue))
    }
    if (@($result.Notifications).Count -gt 0) {
        [void]$lines.Add(("  Notices:  {0}" -f (@($result.Notifications) -join ' || ')))
    }
    if (@($result.Prompts).Count -gt 0) {
        [void]$lines.Add(("  Prompts:  {0}" -f ((@($result.Prompts) | ForEach-Object { "{0}=>{1}" -f $_.Prompt, $_.Response }) -join ' || ')))
    }
    if ($null -ne $result.Exception) {
        [void]$lines.Add(("  Error:    {0}" -f [string]$result.Exception))
    }
    [void]$lines.Add('')
}

Set-Content -LiteralPath $OutputText -Value $lines -Encoding UTF8
Write-Host ("Command surface prerelease complete: {0}/{1} passed for {2}." -f $summary.Passed, $summary.Total, $ShellLabel)
