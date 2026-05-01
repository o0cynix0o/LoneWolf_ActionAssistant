Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$testSaveRoot = Join-Path $repoRoot 'testing\saves'
$sourceSavePath = Join-Path $testSaveRoot ("web-browser-dom-source-{0}.json" -f $PID)
$lastSaveFile = Join-Path $repoRoot 'data\last-save.txt'
$hadLastSave = Test-Path -LiteralPath $lastSaveFile
$previousLastSave = if ($hadLastSave) { Get-Content -LiteralPath $lastSaveFile -Raw } else { $null }
$serverScript = Join-Path $repoRoot 'web\app_server.py'
$chromeUserDataDir = Join-Path $repoRoot ("testing\tmp\chrome-web-dom-{0}" -f $PID)

Set-Location -LiteralPath $repoRoot
. (Join-Path $repoRoot 'lonewolf.ps1')
Initialize-LWData

function Assert-WebDomSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), 0)
    $listener.Start()
    try {
        return [int]$listener.LocalEndpoint.Port
    }
    finally {
        $listener.Stop()
    }
}

function Get-ChromePath {
    $commands = @(Get-Command chrome, chromium, msedge -ErrorAction SilentlyContinue)
    if ($commands.Count -gt 0) {
        return [string]$commands[0].Source
    }

    $candidates = @(
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
    )
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    throw 'Chrome, Chromium, or Edge is required for the browser DOM smoke.'
}

function New-WebDomSourceSave {
    New-Item -ItemType Directory -Path $testSaveRoot -Force | Out-Null

    $state = New-LWDefaultState
    $state.RuleSet = 'Magnakai'
    $state.CurrentSection = 73
    $state.Character.Name = 'Web DOM Smoke'
    $state.Character.BookNumber = 7
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 27
    $state.Character.EnduranceMax = 30
    $state.Character.CompletedBooks = @(1, 2, 3, 4, 5, 6)
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = 4
    $state.Character.MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Animal Control')
    $state.Character.WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    $state.Inventory.Weapons = @('Sword', 'Bow')
    $state.Inventory.BackpackItems = @('Meal', 'Rope')
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Inventory.PocketSpecialItems = @('Diamond')
    $state.Inventory.GoldCrowns = 17
    $state.Combat.Active = $true
    $state.Combat.EnemyName = 'Meter Dummy'
    $state.Combat.EnemyCombatSkill = 16
    $state.Combat.EnemyEnduranceCurrent = 12
    $state.Combat.EnemyEnduranceMax = 20
    $state.Combat.EquippedWeapon = 'Sword'
    $state.Combat.UseMindblast = $true
    $state.Combat.MindblastCombatSkillBonus = 2
    $state.Combat.CanEvade = $true
    $state.Combat.Log = @()
    $state.Run = New-LWRunState -Difficulty 'Normal' -Permadeath:$false
    $state.Settings.SavePath = [string]$sourceSavePath
    $state.Settings.AutoSave = $false
    $state.CurrentBookStats = New-LWBookStats -BookNumber 7 -StartSection 1

    Set-LWHostGameState -State $state | Out-Null
    Add-LWBookSectionVisit -Section 73
    Rebuild-LWStoryAchievementFlagsFromState
    Sync-LWAchievements -Silent | Out-Null
    [void](Sync-LWRunIntegrityState -State $state -Reseal)

    $json = $state | ConvertTo-Json -Depth 40
    Set-Content -LiteralPath $sourceSavePath -Value $json -Encoding UTF8

    $lastSaveDir = Split-Path -Parent $lastSaveFile
    if (-not (Test-Path -LiteralPath $lastSaveDir)) {
        New-Item -ItemType Directory -Path $lastSaveDir -Force | Out-Null
    }
    Set-Content -LiteralPath $lastSaveFile -Value ([string]$sourceSavePath) -Encoding UTF8
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

function Stop-WebDomServer {
    param([System.Diagnostics.Process]$Process)

    if ($null -eq $Process) {
        return
    }

    $processIds = @()
    try {
        $processIds += @(Get-WebDomChildProcessIds -ProcessId ([int]$Process.Id))
    }
    catch {
    }

    try {
        if (-not $Process.HasExited) {
            $processIds += [int]$Process.Id
        }
    }
    catch {
    }

    foreach ($processId in ($processIds | Select-Object -Unique)) {
        try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
        }
        catch {
        }
    }
}

function Get-WebDomChildProcessIds {
    param([Parameter(Mandatory = $true)][int]$ProcessId)

    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) {
        Get-WebDomChildProcessIds -ProcessId ([int]$child.ProcessId)
        [int]$child.ProcessId
    }
}

function ConvertTo-WebDomArgumentString {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    return (($Arguments | ForEach-Object {
                if ($null -eq $_) {
                    '""'
                }
                else {
                    '"{0}"' -f (($_ -replace '\\(?=")', '\\') -replace '"', '\"')
                }
            }) -join ' ')
}

function Invoke-ChromeDumpDom {
    param(
        [Parameter(Mandatory = $true)][string]$ChromePath,
        [Parameter(Mandatory = $true)][string]$Url
    )

    $arguments = @(
        '--headless=new',
        '--disable-gpu',
        '--disable-extensions',
        '--no-first-run',
        '--no-default-browser-check',
        '--allow-insecure-localhost',
        ("--user-data-dir={0}" -f $chromeUserDataDir),
        '--virtual-time-budget=10000',
        '--dump-dom',
        $Url
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ChromePath
    $startInfo.Arguments = ConvertTo-WebDomArgumentString -Arguments $arguments
    $startInfo.WorkingDirectory = [string]$repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($startInfo)
    if ($null -eq $process) {
        throw 'Failed to start headless browser.'
    }

    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    if (-not $process.WaitForExit(30000)) {
        try {
            $process.Kill()
        }
        catch {
        }
        throw 'Headless browser DOM dump timed out.'
    }

    if ($process.ExitCode -ne 0) {
        throw ("Headless browser exited with {0}: {1}" -f [int]$process.ExitCode, $stderr)
    }

    return [string]$stdout
}

function Remove-ChromeUserDataDir {
    $tmpRoot = (Resolve-Path (Join-Path $repoRoot 'testing\tmp')).Path
    if (-not (Test-Path -LiteralPath $chromeUserDataDir)) {
        return
    }

    $resolved = (Resolve-Path -LiteralPath $chromeUserDataDir).Path
    if (-not $resolved.StartsWith($tmpRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove Chrome profile outside testing tmp: $resolved"
    }

    Remove-Item -LiteralPath $resolved -Recurse -Force
}

New-WebDomSourceSave

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
}
Assert-WebDomSmoke -Condition ($null -ne $python) -Message 'Python 3 is required for the browser DOM smoke.'
Assert-WebDomSmoke -Condition (Test-Path -LiteralPath $serverScript) -Message 'Web app server script is missing.'

$port = Get-FreeTcpPort
$baseUrl = "http://127.0.0.1:$port"
$server = $null

try {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = [string]$python.Source
    $startInfo.Arguments = ('"{0}" --host 127.0.0.1 --port {1}' -f $serverScript, $port)
    $startInfo.WorkingDirectory = [string]$repoRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $server = [System.Diagnostics.Process]::Start($startInfo)

    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Milliseconds 250
        try {
            $stateResponse = Invoke-RestMethod -Method Get -Uri "$baseUrl/api/state" -TimeoutSec 2
            if ([bool]$stateResponse.ok) {
                $ready = $true
                break
            }
        }
        catch {
        }
    }
    Assert-WebDomSmoke -Condition $ready -Message 'Web app server did not become ready for DOM smoke.'

    $loadResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/action" -ContentType 'application/json' -Body (@{ action = 'loadGame'; path = [string]$sourceSavePath } | ConvertTo-Json -Compress)
    Assert-WebDomSmoke -Condition ([bool]$loadResponse.ok) -Message 'Could not load the DOM smoke source save through the API.'
    Assert-WebDomSmoke -Condition ([int]$loadResponse.payload.character.BookNumber -eq 7) -Message 'DOM smoke source save should load as Book 7.'
    Assert-WebDomSmoke -Condition ([bool]$loadResponse.payload.combat.Active) -Message 'DOM smoke source save should include active combat.'
    Assert-WebDomSmoke -Condition ([int]$loadResponse.payload.combat.PlayerEnduranceCurrent -eq 27) -Message 'Combat payload did not expose player END current.'
    Assert-WebDomSmoke -Condition ([int]$loadResponse.payload.combat.PlayerEnduranceMax -eq 30) -Message 'Combat payload did not expose player END max.'
    Assert-WebDomSmoke -Condition ([int]$loadResponse.payload.combat.EnemyEnduranceCurrent -eq 12) -Message 'Combat payload did not expose enemy END current.'
    Assert-WebDomSmoke -Condition ([int]$loadResponse.payload.combat.EnemyEnduranceMax -eq 20) -Message 'Combat payload did not expose enemy END max.'

    $screenResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/action" -ContentType 'application/json' -Body (@{ action = 'showScreen'; name = 'achievements' } | ConvertTo-Json -Compress)
    Assert-WebDomSmoke -Condition ([bool]$screenResponse.ok) -Message 'Could not switch the server session to achievements before DOM capture.'
    $rollResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/action" -ContentType 'application/json' -Body (@{ action = 'safeCommand'; command = 'roll' } | ConvertTo-Json -Compress)
    Assert-WebDomSmoke -Condition ([bool]$rollResponse.ok) -Message 'Could not run the roll command before DOM capture.'
    $rollNotifications = @($rollResponse.payload.session.Notifications | ForEach-Object { [string]$_.Message })
    Assert-WebDomSmoke -Condition (($rollNotifications -join "`n").Contains('Random Number Table roll')) -Message 'Roll command did not return a random-number notification before DOM capture.'

    $rootHtml = [string](Invoke-RestMethod -Method Get -Uri "$baseUrl/" -TimeoutSec 5)
    Assert-WebDomSmoke -Condition ($rootHtml.Contains('Lone Wolf Action Assistant')) -Message 'The web server root did not return the frontend shell.'

    $chromePath = Get-ChromePath
    New-Item -ItemType Directory -Path $chromeUserDataDir -Force | Out-Null
    $dom = Invoke-ChromeDumpDom -ChromePath $chromePath -Url "$baseUrl/"
    $domPreview = if ($dom.Length -gt 500) { $dom.Substring(0, 500) } else { $dom }

    Assert-WebDomSmoke -Condition ($dom.Contains('Lone Wolf Action Assistant')) -Message ("Browser DOM did not include the web app shell. DOM preview: {0}" -f $domPreview)
    Assert-WebDomSmoke -Condition ($dom.Contains('Roll Command')) -Message 'Browser DOM did not render the roll command panel.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Command Results')) -Message 'Browser DOM did not render the command result notification panel.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Achievement Commands')) -Message 'Browser DOM did not render achievement command buttons.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Last Roll')) -Message 'Browser DOM did not render the roll panel result label.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Random Number Table roll')) -Message 'Browser DOM did not render the latest roll result inside the roll panel.'
    Assert-WebDomSmoke -Condition ($dom.Contains('No section-specific random-number rule')) -Message 'Browser DOM did not render the current roll context text.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Web DOM Smoke')) -Message 'Browser DOM did not render the loaded character summary.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Book 7 - Castle Death')) -Message 'Browser DOM did not render the loaded Book 7 context.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Current Book Progress')) -Message 'Browser DOM did not render the achievements tab content.'
    Assert-WebDomSmoke -Condition ($dom.Contains('Snake Eyes')) -Message 'Browser DOM did not render the unlocked achievement name.'
    Assert-WebDomSmoke -Condition ($dom.Contains('achievement-card')) -Message 'Browser DOM did not include achievement card markup.'

    $combatScreenResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/api/action" -ContentType 'application/json' -Body (@{ action = 'showScreen'; name = 'combat' } | ConvertTo-Json -Compress)
    Assert-WebDomSmoke -Condition ([bool]$combatScreenResponse.ok) -Message 'Could not switch the server session to combat before DOM capture.'

    $combatDom = Invoke-ChromeDumpDom -ChromePath $chromePath -Url "$baseUrl/"
    $combatDomPreview = if ($combatDom.Length -gt 500) { $combatDom.Substring(0, 500) } else { $combatDom }
    Assert-WebDomSmoke -Condition ($combatDom.Contains('Life Meters')) -Message ("Browser DOM did not render the combat life meter panel. DOM preview: {0}" -f $combatDomPreview)
    Assert-WebDomSmoke -Condition ($combatDom.Contains('Meter Dummy')) -Message 'Browser DOM did not render the active combat enemy name.'
    Assert-WebDomSmoke -Condition ($combatDom.Contains('combat-meter-card')) -Message 'Browser DOM did not include combat meter card markup.'
    Assert-WebDomSmoke -Condition ($combatDom.Contains('combat-meter-fill')) -Message 'Browser DOM did not render the combat meter bar.'
    Assert-WebDomSmoke -Condition ($combatDom.Contains('27 / 30')) -Message 'Browser DOM did not render the player END meter value.'
    Assert-WebDomSmoke -Condition ($combatDom.Contains('12 / 20')) -Message 'Browser DOM did not render the enemy END meter value.'
    Assert-WebDomSmoke -Condition (-not $combatDom.Contains('[################--]')) -Message 'Browser DOM should not render the old CLI-style meter text.'

    '[PASS] Web browser DOM smoke'
}
finally {
    Stop-WebDomServer -Process $server
    Restore-LastSavePointer
    Remove-ChromeUserDataDir
}
