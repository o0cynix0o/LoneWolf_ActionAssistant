Set-StrictMode -Version Latest

function Get-LWRootDirectory {
    param(
        [string]$ScriptRoot,
        [string]$MyCommandPath
    )

    if (-not [string]::IsNullOrWhiteSpace($ScriptRoot)) {
        return $ScriptRoot
    }

    if (-not [string]::IsNullOrWhiteSpace($MyCommandPath)) {
        return (Split-Path -Parent $MyCommandPath)
    }

    return (Get-Location).Path
}

function Resolve-LWDefaultPath {
    param(
        [string]$Path,
        [Parameter(Mandatory = $true)][string]$RootDir,
        [Parameter(Mandatory = $true)][string]$ChildPath
    )

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    return (Join-Path $RootDir $ChildPath)
}

function New-LWBootstrapConfiguration {
    param(
        [string]$ScriptRoot,
        [string]$MyCommandPath,
        [string]$SaveDir,
        [string]$DataDir,
        [string]$AppVersion = '0.8.0',
        [string]$StateVersion = '0.5.0'
    )

    $rootDir = Get-LWRootDirectory -ScriptRoot $ScriptRoot -MyCommandPath $MyCommandPath
    $resolvedSaveDir = Resolve-LWDefaultPath -Path $SaveDir -RootDir $rootDir -ChildPath 'saves'
    $resolvedDataDir = Resolve-LWDefaultPath -Path $DataDir -RootDir $rootDir -ChildPath 'data'

    return [pscustomobject]@{
        RootDir              = $rootDir
        SaveDir              = $resolvedSaveDir
        DataDir              = $resolvedDataDir
        AppName              = 'Lone Wolf Action Assistant'
        AppVersion           = $AppVersion
        StateVersion         = $StateVersion
        LastUsedSavePathFile = Join-Path $resolvedDataDir 'last-save.txt'
        ErrorLogFile         = Join-Path $resolvedDataDir 'error.log'
        UiState              = [pscustomobject]@{
            Enabled       = $false
            CurrentScreen = 'welcome'
            LastRenderedScreen = ''
            ScreenData    = $null
            Notifications = @()
            IsRendering   = $false
            NeedsRender   = $true
        }
    }
}

function Test-LWShouldAutoStart {
    param([string]$InvocationName)
    return $InvocationName -ne '.'
}

Export-ModuleMember -Function `
    Get-LWRootDirectory, `
    Resolve-LWDefaultPath, `
    New-LWBootstrapConfiguration, `
    Test-LWShouldAutoStart
