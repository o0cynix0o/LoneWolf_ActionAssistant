Set-StrictMode -Version Latest

function Write-LWPanelHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$AccentColor = 'Cyan',
        [int]$Width = 54
    )

    $innerWidth = [Math]::Max(($Width - 4), ($Title.Length + 2))
    $border = '+' + ('-' * ($innerWidth + 2)) + '+'

    Write-Host ''
    Write-Host $border -ForegroundColor DarkGray
    Write-Host '| ' -NoNewline -ForegroundColor DarkGray
    Write-Host $Title.PadRight($innerWidth) -NoNewline -ForegroundColor $AccentColor
    Write-Host ' |' -ForegroundColor DarkGray
    Write-Host $border -ForegroundColor DarkGray
}

function Write-LWKeyValue {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value,
        [string]$ValueColor = 'Gray',
        [string]$LabelColor = 'DarkGray'
    )

    Write-Host ("  {0,-16}: " -f $Label) -NoNewline -ForegroundColor $LabelColor
    Write-Host $Value -ForegroundColor $ValueColor
}

function Write-LWBulletItem {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$TextColor = 'Gray',
        [string]$BulletColor = 'DarkGray',
        [string]$Bullet = '-'
    )

    Write-Host "  $Bullet " -NoNewline -ForegroundColor $BulletColor
    Write-Host $Text -ForegroundColor $TextColor
}

function Write-LWSubtle {
    param([string]$Message)
    Write-Host $Message -ForegroundColor DarkGray
}

function Get-LWEnduranceColor {
    param(
        [int]$Current,
        [int]$Max
    )

    if ($Max -le 0) {
        return 'Gray'
    }

    $ratio = $Current / [double]$Max
    if ($ratio -le 0.25) {
        return 'Red'
    }
    if ($ratio -le 0.60) {
        return 'Yellow'
    }

    return 'Green'
}

function Get-LWOutcomeColor {
    param([string]$Outcome)

    switch ($Outcome) {
        'Victory' { return 'Green' }
        'Knockout' { return 'Green' }
        'Defeat' { return 'Red' }
        'Evaded' { return 'Yellow' }
        'In Progress' { return 'Cyan' }
        'Special' { return 'DarkYellow' }
        'Stopped' { return 'DarkYellow' }
        default { return 'Gray' }
    }
}

function Get-LWCombatRatioColor {
    param([int]$Ratio)

    if ($Ratio -ge 4) {
        return 'Green'
    }
    if ($Ratio -ge 0) {
        return 'Yellow'
    }

    return 'Red'
}

function Get-LWModeColor {
    param([string]$Mode)

    switch ($Mode) {
        'DataFile' { return 'Green' }
        'ManualCRT' { return 'Yellow' }
        default { return 'Gray' }
    }
}

function Get-LWDifficultyColor {
    param([string]$Difficulty)

    switch ([string]$Difficulty) {
        'Story' { return 'Magenta' }
        'Easy' { return 'Green' }
        'Normal' { return 'Cyan' }
        'Hard' { return 'Yellow' }
        'Veteran' { return 'Red' }
        default { return 'Gray' }
    }
}

function Get-LWIntegrityColor {
    param([string]$IntegrityState)

    switch ([string]$IntegrityState) {
        'Clean' { return 'Green' }
        'Tampered' { return 'Red' }
        default { return 'Gray' }
    }
}

Export-ModuleMember -Function `
    Write-LWPanelHeader, `
    Write-LWKeyValue, `
    Write-LWBulletItem, `
    Write-LWSubtle, `
    Get-LWEnduranceColor, `
    Get-LWOutcomeColor, `
    Get-LWCombatRatioColor, `
    Get-LWModeColor, `
    Get-LWDifficultyColor, `
    Get-LWIntegrityColor
