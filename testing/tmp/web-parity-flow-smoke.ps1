Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$sessionScript = Join-Path $repoRoot 'web\lw_api_session.ps1'
$saveDir = Join-Path $repoRoot 'testing\saves'
$savePath = Join-Path $saveDir ("web-parity-flow-smoke-{0}.json" -f $PID)

function Assert-WebFlowSmoke {
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

function Get-PendingPromptText {
    param([object]$PendingFlow)

    if ($null -eq $PendingFlow -or $null -eq $PendingFlow.Prompt) {
        return ''
    }
    if ($null -eq $PendingFlow.Prompt.Prompt) {
        return ''
    }

    return [string]$PendingFlow.Prompt.Prompt
}

function Get-PendingDefaultText {
    param([object]$PendingFlow)

    if ($null -eq $PendingFlow -or $null -eq $PendingFlow.Prompt -or $null -eq $PendingFlow.Prompt.Default) {
        return ''
    }

    return [string]$PendingFlow.Prompt.Default
}

function Complete-CombatSetupPrompts {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][object]$Response
    )

    for ($i = 0; $i -lt 10; $i++) {
        $pending = Get-PendingFlow -Response $Response
        if ($null -eq $pending) {
            return $Response
        }

        $prompt = Get-PendingPromptText -PendingFlow $pending
        $defaultText = Get-PendingDefaultText -PendingFlow $pending
        $answer = switch -Regex ($prompt) {
            '^Use default combat assumptions' { 'y'; break }
            '^Weapon number$' {
                if ([string]::IsNullOrWhiteSpace($defaultText)) { '1' } else { $defaultText }
                break
            }
            default {
                if ([string]::IsNullOrWhiteSpace($defaultText)) { '0' } else { $defaultText }
                break
            }
        }

        $Response = Invoke-WebApiAction -Process $Process -Request @{
            action = 'submitFlow'
            data   = @{ response = $answer }
        }
    }

    throw 'Combat setup did not finish within the prompt limit.'
}

function Complete-CombatAutoPrompts {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][object]$Response
    )

    for ($i = 0; $i -lt 20; $i++) {
        $pending = Get-PendingFlow -Response $Response
        if ($null -eq $pending) {
            return $Response
        }

        $prompt = Get-PendingPromptText -PendingFlow $pending
        $answer = switch -Regex ($prompt) {
            '^Enemy END loss this round$' { '1'; break }
            '^Lone Wolf END loss this round$' { '0'; break }
            default {
                $defaultText = Get-PendingDefaultText -PendingFlow $pending
                if ([string]::IsNullOrWhiteSpace($defaultText)) { '0' } else { $defaultText }
                break
            }
        }

        $Response = Invoke-WebApiAction -Process $Process -Request @{
            action = 'submitFlow'
            data   = @{ response = $answer }
        }
    }

    throw 'Combat auto-resolve did not finish within the prompt limit.'
}

New-Item -ItemType Directory -Path $saveDir -Force | Out-Null

$session = Start-WebApiSession
try {
    $state = Invoke-WebApiAction -Process $session -Request @{ action = 'state' }
    Assert-WebFlowSmoke -Condition (-not [bool]$state.payload.session.HasState) -Message 'Initial state should not have an active run.'

    $wizard = Invoke-WebApiAction -Process $session -Request @{ action = 'startNewGameWizard' }
    $pending = Get-PendingFlow -Response $wizard
    if ($null -ne $pending -and [string]$pending.Step -eq 'replaceConfirm') {
        $wizard = Invoke-WebApiAction -Process $session -Request @{
            action = 'submitFlow'
            data   = @{ confirm = $true }
        }
        $pending = Get-PendingFlow -Response $wizard
    }
    Assert-WebFlowSmoke -Condition ($null -ne $pending -and [string]$pending.Step -eq 'runConfig') -Message 'New-game wizard did not reach runConfig.'

    $config = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{
            difficulty = 'Hard'
            permadeath = $false
        }
    }
    Assert-WebFlowSmoke -Condition ([string](Get-PendingFlow -Response $config).Step -eq 'identity') -Message 'Run config did not advance to identity.'

    $identity = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{
            name         = 'Web Parity Smoke'
            bookNumber   = 1
            startSection = 1
        }
    }
    Assert-WebFlowSmoke -Condition ([string](Get-PendingFlow -Response $identity).Step -eq 'kaiDisciplines') -Message 'Identity did not advance to Kai discipline selection.'

    $kai = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ selected = @(1, 2, 3, 4, 6) }
    }
    Assert-WebFlowSmoke -Condition ([string](Get-PendingFlow -Response $kai).Step -eq 'startupEquipment') -Message 'Kai selection did not advance to startup equipment.'

    $created = Invoke-WebApiAction -Process $session -Request @{
        action = 'submitFlow'
        data   = @{ response = '1' }
    }
    Assert-WebFlowSmoke -Condition ([bool]$created.payload.session.HasState) -Message 'Startup equipment did not create an active run.'
    Assert-WebFlowSmoke -Condition ($null -eq (Get-PendingFlow -Response $created)) -Message 'New-game flow should be complete.'
    Assert-WebFlowSmoke -Condition ([string]$created.payload.character.Name -eq 'Web Parity Smoke') -Message 'Character name did not persist.'
    Assert-WebFlowSmoke -Condition ([int]$created.payload.character.BookNumber -eq 1) -Message 'Book number did not persist.'
    Assert-WebFlowSmoke -Condition ([int]$created.payload.reader.Section -eq 1) -Message 'Start section did not persist.'
    Assert-WebFlowSmoke -Condition ([string]$created.payload.modes.Difficulty -eq 'Hard') -Message 'Difficulty did not persist.'
    Assert-WebFlowSmoke -Condition (@($created.payload.disciplines.SelectedKai) -contains 'Weaponskill') -Message 'Weaponskill selection is missing.'
    Assert-WebFlowSmoke -Condition (-not [string]::IsNullOrWhiteSpace([string]$created.payload.disciplines.WeaponskillWeapon)) -Message 'Weaponskill weapon was not resolved.'
    Assert-WebFlowSmoke -Condition (@($created.payload.inventory.Sections.backpack.Slots).Count -eq 8) -Message 'Backpack slots were not shaped for the web payload.'

    $added = Invoke-WebApiAction -Process $session -Request @{
        action   = 'inventoryAdd'
        type     = 'backpack'
        name     = 'Torch'
        quantity = 1
    }
    $torchSlot = @($added.payload.inventory.Sections.backpack.Slots | Where-Object { [string]$_.DisplayText -eq 'Torch' } | Select-Object -First 1)
    Assert-WebFlowSmoke -Condition ($torchSlot.Count -eq 1) -Message 'Torch was not added to backpack.'

    $dropped = Invoke-WebApiAction -Process $session -Request @{
        action = 'inventoryDrop'
        type   = 'backpack'
        all    = $true
    }
    Assert-WebFlowSmoke -Condition (@($dropped.payload.inventory.RecoveryStash.backpack) -contains 'Torch') -Message 'Dropped backpack section was not added to the recovery stash.'

    $recovered = Invoke-WebApiAction -Process $session -Request @{
        action    = 'inventoryRecover'
        selection = 'backpack'
    }
    Assert-WebFlowSmoke -Condition (@($recovered.payload.inventory.BackpackItems) -contains 'Torch') -Message 'Backpack recovery did not restore Torch.'

    $savedGold = [int]$recovered.payload.inventory.GoldCrowns
    $saved = Invoke-WebApiAction -Process $session -Request @{
        action = 'saveGame'
        path   = [string]$savePath
    }
    Assert-WebFlowSmoke -Condition (Test-Path -LiteralPath $savePath) -Message 'Sandbox save file was not created.'
    Assert-WebFlowSmoke -Condition ([string]$saved.payload.session.SavePath -eq [string]$savePath) -Message 'Saved payload did not report the sandbox save path.'

    $mutated = Invoke-WebApiAction -Process $session -Request @{
        action = 'adjustGold'
        delta  = 7
    }
    Assert-WebFlowSmoke -Condition ([int]$mutated.payload.inventory.GoldCrowns -eq ($savedGold + 7)) -Message 'Gold mutation did not apply before load.'

    $loaded = Invoke-WebApiAction -Process $session -Request @{
        action = 'loadGame'
        path   = [string]$savePath
    }
    Assert-WebFlowSmoke -Condition ([int]$loaded.payload.inventory.GoldCrowns -eq $savedGold) -Message 'loadGame did not restore saved gold.'
    Assert-WebFlowSmoke -Condition (@($loaded.payload.inventory.BackpackItems) -contains 'Torch') -Message 'loadGame did not restore recovered backpack item.'

    $combatStart = Invoke-WebApiAction -Process $session -Request @{
        action             = 'startCombat'
        enemyName          = 'Training Dummy'
        enemyCombatSkill   = 0
        enemyEndurance     = 1
    }
    $combatReady = Complete-CombatSetupPrompts -Process $session -Response $combatStart
    Assert-WebFlowSmoke -Condition ([bool]$combatReady.payload.combat.Active) -Message 'Combat did not become active after setup prompts.'
    Assert-WebFlowSmoke -Condition ([string]$combatReady.payload.combat.EnemyName -eq 'Training Dummy') -Message 'Combat enemy name did not persist.'
    Assert-WebFlowSmoke -Condition ([int]$combatReady.payload.combat.PlayerEnduranceCurrent -gt 0) -Message 'Active combat payload is missing player END current.'
    Assert-WebFlowSmoke -Condition ([int]$combatReady.payload.combat.PlayerEnduranceMax -ge [int]$combatReady.payload.combat.PlayerEnduranceCurrent) -Message 'Active combat payload has an invalid player END meter range.'
    Assert-WebFlowSmoke -Condition ([int]$combatReady.payload.combat.EnemyEnduranceCurrent -eq 1 -and [int]$combatReady.payload.combat.EnemyEnduranceMax -eq 1) -Message 'Active combat payload is missing enemy END meter values.'
    Assert-WebFlowSmoke -Condition ([int]$combatReady.payload.combat.PlayerCombatSkill -gt 0) -Message 'Active combat payload is missing player Combat Skill.'
    Assert-WebFlowSmoke -Condition ([int]$combatReady.payload.combat.CombatRatio -eq ([int]$combatReady.payload.combat.PlayerCombatSkill - [int]$combatReady.payload.combat.EnemyCombatSkillEffective)) -Message 'Active combat payload did not expose the computed combat ratio.'

    $combatAuto = Invoke-WebApiAction -Process $session -Request @{ action = 'combatAuto' }
    $combatDone = Complete-CombatAutoPrompts -Process $session -Response $combatAuto
    Assert-WebFlowSmoke -Condition (-not [bool]$combatDone.payload.combat.Active) -Message 'Combat auto-resolve did not finish the training fight.'
    Assert-WebFlowSmoke -Condition (@($combatDone.payload.combatLog.Entries).Count -gt 0) -Message 'Combat log did not archive the completed fight.'
    $latestCombat = @($combatDone.payload.combatLog.Entries | Select-Object -First 1)
    Assert-WebFlowSmoke -Condition ($latestCombat.Count -eq 1 -and @($latestCombat[0].Log).Count -gt 0) -Message 'Archived combat entry did not expose round logs as an array.'

    $modes = Invoke-WebApiAction -Process $session -Request @{ action = 'showScreen'; name = 'modes' }
    Assert-WebFlowSmoke -Condition ([string]$modes.payload.session.CurrentScreen -eq 'modes') -Message 'Modes screen did not stick.'
    Assert-WebFlowSmoke -Condition ([bool]$modes.payload.modes.HasState) -Message 'Modes payload is missing active state.'

    $disciplines = Invoke-WebApiAction -Process $session -Request @{ action = 'showScreen'; name = 'disciplines' }
    Assert-WebFlowSmoke -Condition ([string]$disciplines.payload.session.CurrentScreen -eq 'disciplines') -Message 'Disciplines screen did not stick.'
    Assert-WebFlowSmoke -Condition (@($disciplines.payload.disciplines.Kai).Count -ge 10) -Message 'Discipline catalog is missing from active payload.'

    $combatLog = Invoke-WebApiAction -Process $session -Request @{ action = 'showScreen'; name = 'combatlog' }
    Assert-WebFlowSmoke -Condition ([string]$combatLog.payload.session.CurrentScreen -eq 'combatlog') -Message 'Combat log screen did not stick.'
    Assert-WebFlowSmoke -Condition (@($combatLog.payload.combatLog.Entries).Count -gt 0) -Message 'Combat log screen payload is missing archived entries.'

    '[PASS] Web parity flow smoke'
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
}
