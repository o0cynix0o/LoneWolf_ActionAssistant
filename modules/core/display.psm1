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

function Format-LWRetroPanelCellText {
    param(
        [string]$Text,
        [int]$Width
    )

    $value = if ($null -eq $Text) { '' } else { [string]$Text }
    if ($Width -le 0) {
        return ''
    }

    if ($value.Length -gt $Width) {
        if ($Width -le 3) {
            return $value.Substring(0, $Width)
        }
        return ($value.Substring(0, ($Width - 3)) + '...')
    }

    return $value.PadRight($Width)
}

function Write-LWRetroPanelHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$AccentColor = 'Cyan',
        [int]$Width = 64
    )

    $usableWidth = [Math]::Max(10, ($Width - 2))
    $label = (" {0} " -f $Title.ToUpperInvariant())
    if ($label.Length -gt $usableWidth) {
        $label = $label.Substring(0, $usableWidth)
    }

    $leftFill = [Math]::Floor(($usableWidth - $label.Length) / 2)
    $rightFill = $usableWidth - $label.Length - $leftFill
    $line = '+' + ('-' * $leftFill) + $label + ('-' * $rightFill) + '+'

    Write-Host ''
    Write-Host $line -ForegroundColor $AccentColor
}

function Write-LWRetroPanelFooter {
    param([int]$Width = 64)

    $line = '+' + ('-' * [Math]::Max(10, ($Width - 2))) + '+'
    Write-Host $line -ForegroundColor DarkGray
}

function Write-LWRetroPanelKeyValueRow {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value,
        [string]$ValueColor = 'Gray',
        [string]$LabelColor = 'DarkGray',
        [int]$Width = 64,
        [int]$LabelWidth = 15
    )

    $contentWidth = [Math]::Max(10, ($Width - 4))
    $prefix = ("{0,-$LabelWidth}: " -f $Label)
    $valueWidth = [Math]::Max(0, ($contentWidth - $prefix.Length))
    $displayValue = Format-LWRetroPanelCellText -Text $Value -Width $valueWidth

    Write-Host '|' -NoNewline -ForegroundColor DarkGray
    Write-Host ' ' -NoNewline
    Write-Host $prefix -NoNewline -ForegroundColor $LabelColor
    Write-Host $displayValue -NoNewline -ForegroundColor $ValueColor
    Write-Host ' |' -ForegroundColor DarkGray
}

function Write-LWRetroPanelTextRow {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$TextColor = 'Gray',
        [int]$Width = 64
    )

    $contentWidth = [Math]::Max(10, ($Width - 4))
    $displayText = Format-LWRetroPanelCellText -Text $Text -Width $contentWidth

    Write-Host '|' -NoNewline -ForegroundColor DarkGray
    Write-Host ' ' -NoNewline
    Write-Host $displayText -NoNewline -ForegroundColor $TextColor
    Write-Host ' |' -ForegroundColor DarkGray
}

function Write-LWRetroPanelTwoColumnRow {
    param(
        [string]$LeftText = '',
        [string]$RightText = '',
        [string]$LeftColor = 'Gray',
        [string]$RightColor = 'Gray',
        [int]$Width = 64,
        [int]$Gap = 3,
        [int]$LeftWidth = 0
    )

    $contentWidth = [Math]::Max(10, ($Width - 4))
    if ($LeftWidth -gt 0) {
        $leftWidth = [Math]::Min([Math]::Max(1, $LeftWidth), [Math]::Max(1, ($contentWidth - $Gap - 1)))
    }
    else {
        $leftMinimum = 16
        $rightMinimum = 12
        $maxLeftWidth = [Math]::Max($leftMinimum, ($contentWidth - $Gap - $rightMinimum))
        $leftWidth = [Math]::Max($leftMinimum, [Math]::Min(($LeftText.Length + 2), $maxLeftWidth))
    }
    $rightWidth = $contentWidth - $Gap - $leftWidth

    $leftDisplay = Format-LWRetroPanelCellText -Text $LeftText -Width $leftWidth
    $rightDisplay = Format-LWRetroPanelCellText -Text $RightText -Width $rightWidth

    Write-Host '|' -NoNewline -ForegroundColor DarkGray
    Write-Host ' ' -NoNewline
    Write-Host $leftDisplay -NoNewline -ForegroundColor $LeftColor
    Write-Host (' ' * $Gap) -NoNewline
    Write-Host $rightDisplay -NoNewline -ForegroundColor $RightColor
    Write-Host ' |' -ForegroundColor DarkGray
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
    Write-LWRetroPanelHeader, `
    Write-LWRetroPanelFooter, `
    Write-LWRetroPanelKeyValueRow, `
    Write-LWRetroPanelTextRow, `
    Write-LWRetroPanelTwoColumnRow, `
    Get-LWEnduranceColor, `
    Get-LWOutcomeColor, `
    Get-LWCombatRatioColor, `
    Get-LWModeColor, `
    Get-LWDifficultyColor, `
    Get-LWIntegrityColor
