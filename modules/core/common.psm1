Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
}
function Format-LWSigned {
    param([int]$Value)
    if ($Value -gt 0) {
        return "+$Value"
    }
    return [string]$Value
}

function Format-LWList {
    param([object[]]$Items)
    if (@($Items).Count -gt 0) {
        return (@($Items) -join ', ')
    }
    return '(none)'
}

function Get-LWJsonProperty {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $null
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) {
        return $prop.Value
    }

    return $null
}

function Test-LWPropertyExists {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }

    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }

    return ($null -ne $Object.PSObject.Properties[$Name])
}

function Normalize-LWNamedCountEntries {
    param([object[]]$Entries)

    $normalized = @()
    foreach ($entry in @($Entries)) {
        if ($null -eq $entry) {
            continue
        }

        $name = if ((Test-LWPropertyExists -Object $entry -Name 'Name') -and -not [string]::IsNullOrWhiteSpace([string]$entry.Name)) {
            [string]$entry.Name
        }
        else {
            [string]$entry
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        $count = 0
        $entryCountValue = Get-LWJsonProperty -Object $entry -Name 'Count'
        if ($null -ne $entryCountValue) {
            $count = [int]$entryCountValue
        }

        if ($count -lt 0) {
            $count = 0
        }

        $normalized += [pscustomobject]@{
            Name  = $name
            Count = $count
        }
    }

    return @($normalized)
}

function Format-LWNamedCountSummary {
    param([object[]]$Entries)

    $values = @(Normalize-LWNamedCountEntries -Entries $Entries | Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false })
    if (@($values).Count -eq 0) {
        return '(none)'
    }

    return (@($values | ForEach-Object { "{0} x{1}" -f $_.Name, ([int]$_.Count) }) -join ', ')
}

function Format-LWCompactInventorySummary {
    param(
        [object[]]$Items,
        [int]$MaxGroups = 3
    )

    $values = @($Items | Where-Object { $null -ne $_ -and -not [string]::IsNullOrWhiteSpace([string]$_) })
    if (@($values).Count -eq 0) {
        return '(none)'
    }

    $order = New-Object System.Collections.Generic.List[string]
    $counts = @{}
    foreach ($item in $values) {
        $name = [string]$item
        if (-not $counts.ContainsKey($name)) {
            $counts[$name] = 0
            [void]$order.Add($name)
        }
        $counts[$name] = [int]$counts[$name] + 1
    }

    $labels = @()
    foreach ($name in $order) {
        $count = [int]$counts[$name]
        if ($count -gt 1) {
            $labels += ("{0} x{1}" -f $name, $count)
        }
        else {
            $labels += $name
        }
    }

    if (@($labels).Count -le $MaxGroups) {
        return ($labels -join ', ')
    }

    $visible = @($labels[0..($MaxGroups - 1)])
    return ("{0} +{1} more" -f ($visible -join ', '), (@($labels).Count - $MaxGroups))
}

function Get-LWBookTitle {
    param([int]$BookNumber)

    switch ($BookNumber) {
        1 { return 'Flight from the Dark' }
        2 { return 'Fire on the Water' }
        3 { return 'The Caverns of Kalte' }
        4 { return 'The Chasm of Doom' }
        5 { return 'Shadow on the Sand' }
        6 { return 'The Kingdoms of Terror' }
        7 { return 'Castle Death' }
        8 { return 'The Jungle of Horrors' }
        9 { return 'The Cauldron of Fear' }
        10 { return 'The Dungeons of Torgar' }
        11 { return 'The Prisoners of Time' }
        12 { return 'The Masters of Darkness' }
        13 { return 'The Plague Lords of Ruel' }
        14 { return 'The Captives of Kaag' }
        15 { return 'The Darke Crusade' }
        16 { return 'The Legacy of Vashna' }
        17 { return 'Deathlord of Ixia' }
        18 { return 'Dawn of the Dragons' }
        19 { return 'Wolf''s Bane' }
        20 { return 'The Curse of Naar' }
        21 { return 'Voyage of the Moonstone' }
        22 { return 'The Buccaneers of Shadaki' }
        23 { return 'Mydnight''s Hero' }
        24 { return 'Rune War' }
        25 { return 'Trail of the Wolf' }
        26 { return 'The Fall of Blood Mountain' }
        27 { return 'Vampire Trail' }
        28 { return 'The Hunger of Sejanoz' }
        default { return $null }
    }
}

function Get-LWBookNumberFromTitle {
    param([string]$Title)

    if ([string]::IsNullOrWhiteSpace($Title)) {
        return $null
    }

    for ($bookNumber = 1; $bookNumber -le 5; $bookNumber++) {
        if ((Get-LWBookTitle -BookNumber $bookNumber) -ieq $Title) {
            return $bookNumber
        }
    }

    return $null
}

function Format-LWBookLabel {
    param(
        [int]$BookNumber,
        [switch]$IncludePrefix
    )

    $title = Get-LWBookTitle -BookNumber $BookNumber
    if ([string]::IsNullOrWhiteSpace($title)) {
        if ($IncludePrefix) {
            return "Book $BookNumber"
        }
        return [string]$BookNumber
    }

    if ($IncludePrefix) {
        return "Book $BookNumber - $title"
    }

    return "$BookNumber - $title"
}

function Get-LWDifficultyDefinitions {
    return @(
        [pscustomobject]@{
            Name              = 'Story'
            Description       = 'No normal END loss. Story and universal achievements only.'
            AchievementNote   = 'Universal + Story achievements'
            PermadeathAllowed = $false
        },
        [pscustomobject]@{
            Name              = 'Easy'
            Description       = 'Incoming END loss is halved.'
            AchievementNote   = 'Universal achievements only'
            PermadeathAllowed = $true
        },
        [pscustomobject]@{
            Name              = 'Normal'
            Description       = 'Standard Lone Wolf rules.'
            AchievementNote   = 'Universal + Combat achievements'
            PermadeathAllowed = $true
        },
        [pscustomobject]@{
            Name              = 'Hard'
            Description       = 'Sommerswerd bonus halved. Healing capped at 10 END per book.'
            AchievementNote   = 'Universal + Combat + Challenge achievements'
            PermadeathAllowed = $true
        },
        [pscustomobject]@{
            Name              = 'Veteran'
            Description       = 'Hard rules plus Sommerswerd only when the text allows it.'
            AchievementNote   = 'Universal + Combat + Challenge achievements'
            PermadeathAllowed = $true
        }
    )
}

function Get-LWNormalizedDifficultyName {
    param([string]$Difficulty = '')

    $target = if ([string]::IsNullOrWhiteSpace($Difficulty)) { 'Normal' } else { $Difficulty.Trim() }
    foreach ($entry in @(Get-LWDifficultyDefinitions)) {
        if ([string]$entry.Name -ieq $target) {
            return [string]$entry.Name
        }
    }

    switch ($target.ToLowerInvariant()) {
        'storymode' { return 'Story' }
        'easymode' { return 'Easy' }
        'hardmode' { return 'Hard' }
        default { return 'Normal' }
    }
}

function Get-LWDifficultyDefinition {
    param([string]$Difficulty = '')

    $normalized = Get-LWNormalizedDifficultyName -Difficulty $Difficulty
    foreach ($entry in @(Get-LWDifficultyDefinitions)) {
        if ([string]$entry.Name -eq $normalized) {
            return $entry
        }
    }

    return $null
}

function Get-LWCanonicalDateText {
    param([object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [DateTimeOffset]) {
        return $Value.ToString('o')
    }

    if ($Value -is [DateTime]) {
        return $Value.ToString('o')
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ''
    }

    $dateTimeOffsetValue = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$dateTimeOffsetValue)) {
        return $dateTimeOffsetValue.ToString('o')
    }

    $dateTimeValue = [DateTime]::MinValue
    if ([DateTime]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$dateTimeValue)) {
        return $dateTimeValue.ToString('o')
    }

    return $text
}

function Get-LWStringHash {
    param([string]$Text = '')

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }

    return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
}

Export-ModuleMember -Function `
    Format-LWSigned, `
    Format-LWList, `
    Get-LWJsonProperty, `
    Test-LWPropertyExists, `
    Normalize-LWNamedCountEntries, `
    Format-LWNamedCountSummary, `
    Format-LWCompactInventorySummary, `
    Get-LWBookTitle, `
    Get-LWBookNumberFromTitle, `
    Format-LWBookLabel, `
    Get-LWDifficultyDefinitions, `
    Get-LWNormalizedDifficultyName, `
    Get-LWDifficultyDefinition, `
    Get-LWCanonicalDateText, `
    Get-LWStringHash

function Get-LWKaiRankTitle {
    param([int]$DisciplineCount)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($DisciplineCount -le 0) {
        return $null
    }

    switch ($DisciplineCount) {
        1 { return 'Novice' }
        2 { return 'Intuite' }
        3 { return 'Doan' }
        4 { return 'Acolyte' }
        5 { return 'Initiate' }
        6 { return 'Aspirant' }
        7 { return 'Guardian' }
        8 { return 'Warmarn / Journeyman' }
        9 { return 'Savant' }
        default { return 'Master' }
    }
}

function Format-LWKaiRankLabel {
    param([int]$DisciplineCount)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $rankTitle = Get-LWKaiRankTitle -DisciplineCount $DisciplineCount
    if ([string]::IsNullOrWhiteSpace($rankTitle)) {
        return '(unranked)'
    }

    $displayCount = if ($DisciplineCount -gt 10) { '10+' } else { [string]$DisciplineCount }
    return "{0} - {1}" -f $displayCount, $rankTitle
}

function Get-LWMagnakaiRankTitle {
    param([int]$Level)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if ($Level -le 0) {
        return $null
    }

    $rankDefinitions = if ($null -ne $script:GameData -and (Test-LWPropertyExists -Object $script:GameData -Name 'MagnakaiRanks') -and $null -ne $script:GameData.MagnakaiRanks) {
        @($script:GameData.MagnakaiRanks)
    }
    else {
        @()
    }
    $rankEntry = @($rankDefinitions | Where-Object { [int]$_.Level -eq $Level } | Select-Object -First 1)
    if ($rankEntry.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$rankEntry[0].Name)) {
        return [string]$rankEntry[0].Name
    }

    switch ($Level) {
        1 { return 'Kai Master' }
        2 { return 'Kai Master Senior' }
        3 { return 'Kai Master Superior' }
        4 { return 'Primate' }
        5 { return 'Tutelary' }
        6 { return 'Principalin' }
        7 { return 'Mentora' }
        8 { return 'Scion-kai' }
        9 { return 'Archmaster' }
        default { return 'Kai Grand Master' }
    }
}

function Format-LWMagnakaiRankLabel {
    param([int]$Level)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    $rankTitle = Get-LWMagnakaiRankTitle -Level $Level
    if ([string]::IsNullOrWhiteSpace($rankTitle)) {
        return '(unranked)'
    }

    return "{0} - {1}" -f $Level, $rankTitle
}

function Get-LWKnownKaiDisciplineNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ($null -ne $script:GameData -and $null -ne $script:GameData.KaiDisciplines -and @($script:GameData.KaiDisciplines).Count -gt 0) {
        return @($script:GameData.KaiDisciplines | ForEach-Object { [string]$_.Name })
    }

    return @('Camouflage', 'Hunting', 'Sixth Sense', 'Tracking', 'Healing', 'Weaponskill', 'Mindblast', 'Mindshield', 'Animal Kinship', 'Mind Over Matter')
}

function Get-LWKnownMagnakaiDisciplineNames {
    Set-LWModuleContext -Context (Get-LWModuleContext)
    if ($null -ne $script:GameData -and $null -ne $script:GameData.MagnakaiDisciplines -and @($script:GameData.MagnakaiDisciplines).Count -gt 0) {
        return @($script:GameData.MagnakaiDisciplines | ForEach-Object { [string]$_.Name })
    }

    return @('Weaponmastery', 'Animal Control', 'Curing', 'Invisibility', 'Huntmastery', 'Pathsmanship', 'Psi-surge', 'Psi-screen', 'Nexus', 'Divination')
}

function Test-LWStateIsMagnakaiRuleset {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    return ([string]$State.RuleSet -ieq 'Magnakai')
}

function Get-LWCurrentRankLabel {
    param([Parameter(Mandatory = $true)][object]$State)
    Set-LWModuleContext -Context (Get-LWModuleContext)


    if (Test-LWStateIsMagnakaiRuleset -State $State) {
        $level = if ((Test-LWPropertyExists -Object $State.Character -Name 'MagnakaiRank') -and $null -ne $State.Character.MagnakaiRank -and [int]$State.Character.MagnakaiRank -gt 0) {
            [int]$State.Character.MagnakaiRank
        }
        else {
            [Math]::Max(1, @($State.Character.MagnakaiDisciplines).Count)
        }

        return (Format-LWMagnakaiRankLabel -Level $level)
    }

    return (Format-LWKaiRankLabel -DisciplineCount @($State.Character.Disciplines).Count)
}

Export-ModuleMember -Function Get-LWKaiRankTitle, Format-LWKaiRankLabel, Get-LWMagnakaiRankTitle, Format-LWMagnakaiRankLabel, Get-LWKnownKaiDisciplineNames, Get-LWKnownMagnakaiDisciplineNames, Test-LWStateIsMagnakaiRuleset, Get-LWCurrentRankLabel


