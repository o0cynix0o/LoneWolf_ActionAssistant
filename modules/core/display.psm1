Set-StrictMode -Version Latest

$script:LWDisplayAnsiSupport = $null
$script:LWDisplayAnsiColorMap = @{
    Black       = '30'
    DarkBlue    = '34'
    DarkGreen   = '32'
    DarkCyan    = '36'
    DarkRed     = '31'
    DarkMagenta = '35'
    DarkYellow  = '33'
    Gray        = '37'
    DarkGray    = '90'
    Blue        = '94'
    Green       = '92'
    Cyan        = '96'
    Red         = '91'
    Magenta     = '95'
    Yellow      = '93'
    White       = '97'
}

function Test-LWDisplayAnsiSupported {
    if ($null -ne $script:LWDisplayAnsiSupport) {
        return [bool]$script:LWDisplayAnsiSupport
    }

    $supportsAnsi = $false
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        try {
            if ($null -ne $PSStyle -and $null -ne $PSStyle.OutputRendering -and [string]$PSStyle.OutputRendering -ne 'PlainText') {
                $supportsAnsi = $true
            }
        }
        catch {
        }
    }

    if (-not $supportsAnsi) {
        if (-not [string]::IsNullOrWhiteSpace([string]$env:WT_SESSION) -or [string]$env:TERM_PROGRAM -eq 'vscode' -or [string]$env:ConEmuANSI -eq 'ON') {
            $supportsAnsi = $true
        }
    }

    $script:LWDisplayAnsiSupport = $supportsAnsi
    return [bool]$script:LWDisplayAnsiSupport
}

function Get-LWDisplayAnsiSequence {
    param([string]$Color = '')

    if ([string]::IsNullOrWhiteSpace($Color)) {
        return ''
    }

    $colorKey = $Color.Trim()
    if (-not $script:LWDisplayAnsiColorMap.ContainsKey($colorKey)) {
        return ''
    }

    return ("`e[{0}m" -f $script:LWDisplayAnsiColorMap[$colorKey])
}

function Write-LWDisplaySegmentedLine {
    param([object[]]$Segments = @())

    if (-not (Test-LWDisplayAnsiSupported)) {
        $segmentCount = @($Segments).Count
        for ($i = 0; $i -lt $segmentCount; $i++) {
            $segment = $Segments[$i]
            $text = if ($null -ne $segment -and $segment.PSObject.Properties['Text']) { [string]$segment.Text } else { '' }
            $color = if ($null -ne $segment -and $segment.PSObject.Properties['Color'] -and -not [string]::IsNullOrWhiteSpace([string]$segment.Color)) { [string]$segment.Color } else { $null }
            $isLast = ($i -eq ($segmentCount - 1))
            if ([string]::IsNullOrWhiteSpace($color)) {
                Write-Host $text -NoNewline:(-not $isLast)
            }
            else {
                Write-Host $text -ForegroundColor $color -NoNewline:(-not $isLast)
            }
        }
        if ($segmentCount -eq 0) {
            Write-Host ''
        }
        return
    }

    $builder = New-Object System.Text.StringBuilder
    foreach ($segment in @($Segments)) {
        $text = if ($null -ne $segment -and $segment.PSObject.Properties['Text']) { [string]$segment.Text } else { '' }
        $color = if ($null -ne $segment -and $segment.PSObject.Properties['Color'] -and -not [string]::IsNullOrWhiteSpace([string]$segment.Color)) { [string]$segment.Color } else { '' }
        if (-not [string]::IsNullOrWhiteSpace($color)) {
            [void]$builder.Append((Get-LWDisplayAnsiSequence -Color $color))
        }
        [void]$builder.Append($text)
    }
    [void]$builder.Append("`e[0m")
    Write-Host $builder.ToString()
}

function Write-LWPanelHeader {
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [string]$AccentColor = 'Cyan',
        [int]$Width = 54
    )

    $innerWidth = [Math]::Max(($Width - 4), ($Title.Length + 2))
    $border = '+' + ('-' * ($innerWidth + 2)) + '+'

    Write-Host ''
    Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $border; Color = 'DarkGray' })
    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = '| '; Color = 'DarkGray' }
        [pscustomobject]@{ Text = $Title.PadRight($innerWidth); Color = $AccentColor }
        [pscustomobject]@{ Text = ' |'; Color = 'DarkGray' }
    )
    Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $border; Color = 'DarkGray' })
}

function Write-LWKeyValue {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][string]$Value,
        [string]$ValueColor = 'Gray',
        [string]$LabelColor = 'DarkGray'
    )

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = ("  {0,-16}: " -f $Label); Color = $LabelColor }
        [pscustomobject]@{ Text = $Value; Color = $ValueColor }
    )
}

function Write-LWBulletItem {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$TextColor = 'Gray',
        [string]$BulletColor = 'DarkGray',
        [string]$Bullet = '-'
    )

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = "  $Bullet "; Color = $BulletColor }
        [pscustomobject]@{ Text = $Text; Color = $TextColor }
    )
}

function Write-LWSubtle {
    param([string]$Message)
    Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $Message; Color = 'DarkGray' })
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
    Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $line; Color = $AccentColor })
}

function Write-LWRetroPanelFooter {
    param([int]$Width = 64)

    $line = '+' + ('-' * [Math]::Max(10, ($Width - 2))) + '+'
    Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $line; Color = 'DarkGray' })
}

function Write-LWRetroPanelDivider {
    param([int]$Width = 64)

    $line = '+' + ('-' * [Math]::Max(10, ($Width - 2))) + '+'
    Write-LWDisplaySegmentedLine -Segments @([pscustomobject]@{ Text = $line; Color = 'DarkGray' })
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

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = '| '; Color = 'DarkGray' }
        [pscustomobject]@{ Text = $prefix; Color = $LabelColor }
        [pscustomobject]@{ Text = $displayValue; Color = $ValueColor }
        [pscustomobject]@{ Text = ' |'; Color = 'DarkGray' }
    )
}

function Write-LWRetroPanelWrappedKeyValueRows {
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
    $continuationPrefix = (' ' * $prefix.Length)
    $valueText = if ($null -eq $Value) { '' } else { [string]$Value }
    $wrappedLines = @()

    if ([string]::IsNullOrWhiteSpace($valueText)) {
        $wrappedLines = @('')
    }
    else {
        $remaining = $valueText.Trim()
        $firstWidth = [Math]::Max(1, ($contentWidth - $prefix.Length))
        $continuationWidth = [Math]::Max(1, ($contentWidth - $continuationPrefix.Length))

        while ($remaining.Length -gt 0) {
            $activePrefix = if ($wrappedLines.Count -eq 0) { $prefix } else { $continuationPrefix }
            $activeWidth = if ($wrappedLines.Count -eq 0) { $firstWidth } else { $continuationWidth }

            if ($remaining.Length -le $activeWidth) {
                $wrappedLines += ($activePrefix + $remaining)
                break
            }

            $slice = $remaining.Substring(0, $activeWidth)
            $breakIndex = $slice.LastIndexOf(' ')
            if ($breakIndex -lt 0) {
                $breakIndex = $activeWidth
            }

            $segment = $remaining.Substring(0, $breakIndex).TrimEnd()
            $wrappedLines += ($activePrefix + $segment)
            $remaining = $remaining.Substring($breakIndex).TrimStart()
        }
    }

    foreach ($line in $wrappedLines) {
        $displayLine = $line.PadRight($contentWidth)
        $labelText = $displayLine.Substring(0, [Math]::Min($prefix.Length, $displayLine.Length))
        $valueText = if ($displayLine.Length -gt $prefix.Length) { $displayLine.Substring($prefix.Length) } else { '' }
        Write-LWDisplaySegmentedLine -Segments @(
            [pscustomobject]@{ Text = '| '; Color = 'DarkGray' }
            [pscustomobject]@{ Text = $labelText; Color = $LabelColor }
            [pscustomobject]@{ Text = $valueText; Color = $ValueColor }
            [pscustomobject]@{ Text = ' |'; Color = 'DarkGray' }
        )
    }
}

function Write-LWRetroPanelTextRow {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$TextColor = 'Gray',
        [int]$Width = 64
    )

    $contentWidth = [Math]::Max(10, ($Width - 4))
    $displayText = Format-LWRetroPanelCellText -Text $Text -Width $contentWidth

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = '| '; Color = 'DarkGray' }
        [pscustomobject]@{ Text = $displayText; Color = $TextColor }
        [pscustomobject]@{ Text = ' |'; Color = 'DarkGray' }
    )
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

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = '| '; Color = 'DarkGray' }
        [pscustomobject]@{ Text = $leftDisplay; Color = $LeftColor }
        [pscustomobject]@{ Text = (' ' * $Gap) }
        [pscustomobject]@{ Text = $rightDisplay; Color = $RightColor }
        [pscustomobject]@{ Text = ' |'; Color = 'DarkGray' }
    )
}

function Write-LWRetroPanelThreeColumnRow {
    param(
        [string]$LeftText = '',
        [string]$MiddleText = '',
        [string]$RightText = '',
        [string]$LeftColor = 'Gray',
        [string]$MiddleColor = 'Gray',
        [string]$RightColor = 'Gray',
        [int]$Width = 64,
        [int]$Gap = 2,
        [int]$LeftWidth = 0,
        [int]$MiddleWidth = 0
    )

    $contentWidth = [Math]::Max(10, ($Width - 4))
    $gapWidth = [Math]::Max(0, [int]$Gap)
    $availableWidth = $contentWidth - ($gapWidth * 2)
    if ($availableWidth -lt 3) {
        $availableWidth = 3
    }

    if ($LeftWidth -gt 0 -and $MiddleWidth -gt 0) {
        $leftWidth = [Math]::Max(1, [int]$LeftWidth)
        $middleWidth = [Math]::Max(1, [int]$MiddleWidth)
    }
    else {
        $baseWidth = [Math]::Floor($availableWidth / 3)
        $leftWidth = [Math]::Max(1, $baseWidth)
        $middleWidth = [Math]::Max(1, $baseWidth)
    }

    $minimumRightWidth = 1
    $maxFixedWidth = [Math]::Max(1, ($availableWidth - $minimumRightWidth))
    if (($leftWidth + $middleWidth) -gt $maxFixedWidth) {
        $leftWidth = [Math]::Max(1, [Math]::Floor($maxFixedWidth / 2))
        $middleWidth = [Math]::Max(1, ($maxFixedWidth - $leftWidth))
    }

    $rightWidth = $availableWidth - $leftWidth - $middleWidth
    if ($rightWidth -lt $minimumRightWidth) {
        $rightWidth = $minimumRightWidth
        if (($leftWidth + $middleWidth + $rightWidth) -gt $availableWidth) {
            $middleWidth = [Math]::Max(1, ($availableWidth - $leftWidth - $rightWidth))
        }
    }

    $leftDisplay = Format-LWRetroPanelCellText -Text $LeftText -Width $leftWidth
    $middleDisplay = Format-LWRetroPanelCellText -Text $MiddleText -Width $middleWidth
    $rightDisplay = Format-LWRetroPanelCellText -Text $RightText -Width $rightWidth

    Write-LWDisplaySegmentedLine -Segments @(
        [pscustomobject]@{ Text = '| '; Color = 'DarkGray' }
        [pscustomobject]@{ Text = $leftDisplay; Color = $LeftColor }
        [pscustomobject]@{ Text = (' ' * $gapWidth) }
        [pscustomobject]@{ Text = $middleDisplay; Color = $MiddleColor }
        [pscustomobject]@{ Text = (' ' * $gapWidth) }
        [pscustomobject]@{ Text = $rightDisplay; Color = $RightColor }
        [pscustomobject]@{ Text = ' |'; Color = 'DarkGray' }
    )
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
    Write-LWDisplaySegmentedLine, `
    Write-LWPanelHeader, `
    Write-LWKeyValue, `
    Write-LWBulletItem, `
    Write-LWSubtle, `
    Write-LWRetroPanelHeader, `
    Write-LWRetroPanelFooter, `
    Write-LWRetroPanelDivider, `
    Write-LWRetroPanelKeyValueRow, `
    Write-LWRetroPanelWrappedKeyValueRows, `
    Write-LWRetroPanelTextRow, `
    Write-LWRetroPanelTwoColumnRow, `
    Write-LWRetroPanelThreeColumnRow, `
    Get-LWEnduranceColor, `
    Get-LWOutcomeColor, `
    Get-LWCombatRatioColor, `
    Get-LWModeColor, `
    Get-LWDifficultyColor, `
    Get-LWIntegrityColor
