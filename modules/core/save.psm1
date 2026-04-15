Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

$script:LWSaveHostCommandCache = @{}
$script:LWModuleContextGeneration = -1

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    $generation = if ($Context.ContainsKey('_Generation')) { [int]$Context['_Generation'] } else { -1 }
    if ($generation -ge 0 -and $generation -eq $script:LWModuleContextGeneration) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
    $script:LWModuleContextGeneration = $generation
}

function Get-LWSaveHostCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    if ($script:LWSaveHostCommandCache.ContainsKey($Name)) {
        $cachedCommand = $script:LWSaveHostCommandCache[$Name]
        if ($null -ne $cachedCommand) {
            return $cachedCommand
        }
    }

    $command = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $script:LWSaveHostCommandCache[$Name] = $command
    }
    return $command
}

function Invoke-LWCoreSaveGame {
    param(
        [hashtable]$Context,
        [switch]$PromptForPath
    )

    Set-LWModuleContext -Context $Context

        if (-not (Test-LWHasState)) {
            Write-LWWarn 'No active character. Use new or load first.'
            return
        }
        if ((Test-LWPermadeathEnabled) -and (Test-LWDeathActive)) {
            Write-LWWarn 'Permadeath runs cannot be saved after death.'
            return
        }

        Sync-LWCurrentSectionCheckpoint
        Sync-LWRunIntegrityState -State $script:GameState -Reseal

        $path = $script:GameState.Settings.SavePath
        if ($PromptForPath -or [string]::IsNullOrWhiteSpace($path)) {
            $defaultFile = "{0}-book{1}.json" -f (Get-LWSafeFileName -Name $script:GameState.Character.Name), $script:GameState.Character.BookNumber
            $defaultPath = Join-Path $SaveDir $defaultFile
            $path = Read-LWText -Prompt 'Save path' -Default $defaultPath
        }

        $directory = Split-Path -Parent $path
        if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }

        $script:GameState.Settings.SavePath = $path
        $json = $script:GameState | ConvertTo-Json -Depth 20
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        Set-LWLastUsedSavePath -Path $path
        Write-LWInfo "Saved game to $path"
}

function Invoke-LWCoreLoadGame {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Path
    )

    Set-LWModuleContext -Context $Context

        if (-not (Test-Path -LiteralPath $Path)) {
            Write-LWWarn "Save file not found: $Path"
            return
        }

        $raw = Get-Content -LiteralPath $Path -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-LWWarn 'Save file is empty.'
            return
        }

        $gameData = Get-Variable -Scope Script -Name GameData -ValueOnly -ErrorAction SilentlyContinue
        if ($null -eq $gameData) {
            $initializeDataCommand = Get-LWSaveHostCommand -Name 'Initialize-LWData'
            if ($null -ne $initializeDataCommand) {
                & $initializeDataCommand
                $gameData = Get-Variable -Scope Script -Name GameData -ValueOnly -ErrorAction SilentlyContinue
            }
        }
        if ($null -eq $gameData) {
            $gameData = Invoke-LWCoreInitializeData -Context $Context
            if ($null -ne $gameData) {
                Set-Variable -Scope Script -Name GameData -Value $gameData -Force
                $setHostGameDataCommand = Get-LWSaveHostCommand -Name 'Set-LWHostGameData'
                if ($null -ne $setHostGameDataCommand) {
                    & $setHostGameDataCommand -Data $gameData | Out-Null
                }
            }
        }

        $state = $raw | ConvertFrom-Json
        $script:GameState = Normalize-LWState -State $state
        $setHostGameStateCommand = Get-LWSaveHostCommand -Name 'Set-LWHostGameState'
        if ($null -ne $setHostGameStateCommand) { & $setHostGameStateCommand -State $script:GameState | Out-Null }
        $script:GameState.Settings.SavePath = $Path
        Ensure-LWCurrentSectionCheckpoint
        Set-LWLastUsedSavePath -Path $Path
        Set-LWScreen -Name (Get-LWDefaultScreen)
        if (Test-LWRunTampered) {
            $integrityNote = if (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityNote)) { [string]$script:GameState.Run.IntegrityNote } else { 'Locked run settings were changed outside the assistant.' }
            Write-LWWarn ("Run integrity warning: {0}" -f $integrityNote)
        }
        $backfilled = @()
        if (-not (Test-LWAchievementLoadBackfillCurrent -State $script:GameState)) {
            $backfilled = @(Sync-LWAchievements -Context 'load' -Silent)
        }
        $backfilledCount = @($backfilled).Count
        if ($backfilledCount -gt 0) {
            Write-LWInfo ("Backfilled {0} achievement{1} from save history." -f $backfilledCount, $(if ($backfilledCount -eq 1) { '' } else { 's' }))
        }
        Write-LWInfo "Loaded game from $Path"

    return $script:GameState
}

function Invoke-LWCoreLoadGameInteractive {
    param(
        [hashtable]$Context,
        [string]$Selection
    )

    Set-LWModuleContext -Context $Context

        $defaultPath = Get-LWPreferredSavePath
        if ([string]::IsNullOrWhiteSpace($defaultPath)) {
            $defaultPath = Join-Path $SaveDir 'lonewolf-save.json'
        }

        $saveFiles = @(Get-LWSaveCatalog)
        $path = $null

        if ([string]::IsNullOrWhiteSpace($Selection)) {
            Set-LWScreen -Name 'load' -Data ([pscustomobject]@{
                    SaveFiles = @($saveFiles)
                })
            if (@($saveFiles).Count -gt 0) {
                $defaultSelection = '1'
                $currentSave = @($saveFiles | Where-Object { $_.IsCurrent } | Select-Object -First 1)
                if (@($currentSave).Count -gt 0) {
                    $defaultSelection = [string]$currentSave[0].Index
                }

                $selection = Read-LWText -Prompt 'Save number or path' -Default $defaultSelection
                $path = Resolve-LWSaveSelectionPath -Selection $selection -SaveFiles $saveFiles -DefaultPath $defaultPath
            }
            else {
                $path = Read-LWText -Prompt 'Load path' -Default $defaultPath
            }
        }
        else {
            $path = Resolve-LWSaveSelectionPath -Selection $Selection -SaveFiles $saveFiles -DefaultPath $defaultPath
        }

        if ([string]::IsNullOrWhiteSpace($path)) {
            return
        }

        return (Invoke-LWCoreLoadGame -Context $Context -Path $path)
}

Export-ModuleMember -Function `
    Invoke-LWCoreSaveGame, `
    Invoke-LWCoreLoadGame, `
    Invoke-LWCoreLoadGameInteractive

function Import-LWJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [object]$Default = $null
    )
    $contextCommand = Get-LWSaveHostCommand -Name 'Get-LWModuleContext'
    if ($null -ne $contextCommand) {
        Set-LWModuleContext -Context (& $contextCommand)
    }


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
    Set-LWModuleContext -Context (Get-LWModuleContext)
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
    Set-LWModuleContext -Context (Get-LWModuleContext)


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
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ((Test-LWHasState) -and -not [string]::IsNullOrWhiteSpace($script:GameState.Settings.SavePath) -and (Test-Path -LiteralPath $script:GameState.Settings.SavePath)) {
        return $script:GameState.Settings.SavePath
    }

    return (Get-LWLastUsedSavePath)
}

function Get-LWChainmailItemNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    return @('Chainmail Waistcoat', 'Chainmail Wastecoat', 'Chainmail')
}

function Get-LWSaveCatalog {
    Set-LWModuleContext -Context (Get-LWModuleContext)
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
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $saveFiles = @(
        foreach ($entry in @($SaveFiles)) {
            if ($null -eq $entry) {
                continue
            }

            if ((Test-LWPropertyExists -Object $entry -Name 'FullName') -or
                (Test-LWPropertyExists -Object $entry -Name 'Index') -or
                (Test-LWPropertyExists -Object $entry -Name 'BookNumber')) {
                $entry
            }
        }
    )
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
    Set-LWModuleContext -Context (Get-LWModuleContext)


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

Export-ModuleMember -Function Import-LWJson, Get-LWLastUsedSavePath, Set-LWLastUsedSavePath, Get-LWPreferredSavePath, Get-LWChainmailItemNames, Get-LWSaveCatalog, Show-LWSaveCatalog, Resolve-LWSaveSelectionPath



