Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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

        $state = $raw | ConvertFrom-Json
        $script:GameState = Normalize-LWState -State $state
        $script:GameState.Settings.SavePath = $Path
        Ensure-LWCurrentSectionCheckpoint
        Set-LWLastUsedSavePath -Path $Path
        Set-LWScreen -Name (Get-LWDefaultScreen)
        Rebuild-LWStoryAchievementFlagsFromState
        if (Test-LWRunTampered) {
            $integrityNote = if (-not [string]::IsNullOrWhiteSpace([string]$script:GameState.Run.IntegrityNote)) { [string]$script:GameState.Run.IntegrityNote } else { 'Locked run settings were changed outside the assistant.' }
            Write-LWWarn ("Run integrity warning: {0}" -f $integrityNote)
        }
        $backfilled = @(Sync-LWAchievements -Context 'load' -Silent)
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

        Load-LWGame -Path $path

    return $script:GameState
}

Export-ModuleMember -Function `
    Invoke-LWCoreSaveGame, `
    Invoke-LWCoreLoadGame, `
    Invoke-LWCoreLoadGameInteractive

