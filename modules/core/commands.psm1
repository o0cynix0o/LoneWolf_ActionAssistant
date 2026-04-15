Set-StrictMode -Version Latest

$script:GameState = $null
$script:GameData = $null
$script:LWUi = $null

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

function Clear-LWModuleNotifications {
    if ($null -eq $script:LWUi) {
        return
    }

    $script:LWUi.Notifications = @()
    if (Get-Command -Name Request-LWRender -ErrorAction SilentlyContinue) {
        Request-LWRender
    }
}

function Invoke-LWCoreShowHelpScreen {
    param([hashtable]$Context)

    Set-LWModuleContext -Context $Context

    $panelWidth = 74
    $labelWidth = 22
    $panels = @(
        [pscustomobject]@{
            Title = 'Navigation'
            Color = 'Cyan'
            Rows  = @(
                [pscustomobject]@{ Label = 'sheet'; Value = 'Main character sheet and live state' }
                [pscustomobject]@{ Label = 'inv'; Value = 'Inventory, slots, containers, and storage' }
                [pscustomobject]@{ Label = 'disciplines'; Value = 'Kai or Magnakai discipline view' }
                [pscustomobject]@{ Label = 'stats'; Value = 'Run stats and current-book numbers' }
                [pscustomobject]@{ Label = 'campaign'; Value = 'Book progress and whole-run overview' }
                [pscustomobject]@{ Label = 'achievements'; Value = 'Unlocked, locked, recent, and progress views' }
                [pscustomobject]@{ Label = 'history'; Value = 'Recent events and archived fights' }
                [pscustomobject]@{ Label = 'notes'; Value = 'Your saved reminders for the run' }
            )
        }
        [pscustomobject]@{
            Title = 'Play And Inventory'
            Color = 'DarkYellow'
            Rows  = @(
                [pscustomobject]@{ Label = 'section <n>'; Value = 'Move to the section you are reading' }
                [pscustomobject]@{ Label = 'roll'; Value = 'Run the current section random helper' }
                [pscustomobject]@{ Label = 'note <text>'; Value = 'Add a short reminder' }
                [pscustomobject]@{ Label = 'potion'; Value = 'Use a healing item outside combat' }
                [pscustomobject]@{ Label = 'meal / eat'; Value = 'Consume a meal when required' }
                [pscustomobject]@{ Label = 'add / drop'; Value = 'Add or remove carried items' }
                [pscustomobject]@{ Label = 'recover'; Value = 'Restore stashed gear from bulk drop' }
                [pscustomobject]@{ Label = 'gold / end'; Value = 'Adjust Gold Crowns or current END' }
                [pscustomobject]@{ Label = 'arrows +/-n'; Value = 'Spend or refill quiver arrows' }
            )
        }
        [pscustomobject]@{
            Title = 'Combat'
            Color = 'DarkRed'
            Rows  = @(
                [pscustomobject]@{ Label = 'combat <enemy cs end>'; Value = 'Start a tracked combat quickly' }
                [pscustomobject]@{ Label = 'combat'; Value = 'Show the active combat screen or setup' }
                [pscustomobject]@{ Label = 'combat round'; Value = 'Resolve one combat round' }
                [pscustomobject]@{ Label = 'combat auto'; Value = 'Run combat until it ends' }
                [pscustomobject]@{ Label = 'combat evade'; Value = 'Attempt to evade if allowed' }
                [pscustomobject]@{ Label = 'combat log'; Value = 'Review current or archived fight details' }
                [pscustomobject]@{ Label = 'fight <enemy cs end>'; Value = 'Quick-start combat and auto-resolve it' }
                [pscustomobject]@{ Label = 'mode manual|data'; Value = 'Switch combat between CRT and data modes' }
            )
        }
        [pscustomobject]@{
            Title = 'Run And Recovery'
            Color = 'Magenta'
            Rows  = @(
                [pscustomobject]@{ Label = 'new'; Value = 'Create a new character and run' }
                [pscustomobject]@{ Label = 'newrun'; Value = 'Restart the run, keep character progress' }
                [pscustomobject]@{ Label = 'save / load'; Value = 'Write or open a save file' }
                [pscustomobject]@{ Label = 'modes'; Value = 'Review difficulty and permadeath rules' }
                [pscustomobject]@{ Label = 'rewind [n]'; Value = 'Go back after death or failure' }
                [pscustomobject]@{ Label = 'fail / die'; Value = 'Record a terminal result and open rewind' }
                [pscustomobject]@{ Label = 'complete'; Value = 'Finish the current book and transition' }
                [pscustomobject]@{ Label = 'quit'; Value = 'Leave the app' }
            )
        }
        [pscustomobject]@{
            Title = 'Quick Examples'
            Color = 'Green'
            Rows  = @(
                [pscustomobject]@{ Label = 'section 194'; Value = 'Move to section 194' }
                [pscustomobject]@{ Label = 'combat Altan 28 50'; Value = 'Start a tracked fight against Altan' }
                [pscustomobject]@{ Label = 'arrows -1'; Value = 'Spend one arrow from the quiver' }
                [pscustomobject]@{ Label = 'load sample-save.json'; Value = 'Load a save by name' }
            )
        }
    )

    foreach ($panel in $panels) {
        Write-LWRetroPanelHeader -Title ([string]$panel.Title) -AccentColor ([string]$panel.Color) -Width $panelWidth
        foreach ($row in @($panel.Rows)) {
            Write-LWRetroPanelKeyValueRow -Label ([string]$row.Label) -Value ([string]$row.Value) -ValueColor 'Gray' -LabelWidth $labelWidth -Width $panelWidth
        }
        Write-LWRetroPanelFooter -Width $panelWidth
    }

    Write-LWRetroPanelHeader -Title 'Helpful Commands' -AccentColor 'DarkYellow' -Width $panelWidth
    foreach ($row in @(
            [pscustomobject]@{ Label = 'sheet'; Value = 'return to the main character sheet' }
            [pscustomobject]@{ Label = 'section <n>'; Value = 'move to the section you are reading' }
            [pscustomobject]@{ Label = 'load'; Value = 'open the save picker' }
            [pscustomobject]@{ Label = 'quit'; Value = 'leave the app' }
        )) {
        Write-LWRetroPanelKeyValueRow -Label ([string]$row.Label) -Value ([string]$row.Value) -LabelColor 'DarkYellow' -ValueColor 'Gray' -LabelWidth $labelWidth -Width $panelWidth
    }
    Write-LWRetroPanelFooter -Width $panelWidth
}

function Invoke-LWCoreCommand {
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$InputLine
    )

    Set-LWModuleContext -Context $Context

        Clear-LWModuleNotifications
        $trimmed = $InputLine.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            $currentState = Get-Variable -Scope Script -Name GameState -ValueOnly -ErrorAction SilentlyContinue
            if ($null -ne $currentState -and $currentState.Combat.Active) {
                [void](Invoke-LWCombatRound)
            }
            return $null
        }

        $parts = @([string[]]($trimmed -split '\s+'))
        $command = $parts[0].ToLowerInvariant()
        $argumentText = if ($trimmed.Length -gt $command.Length) {
            $trimmed.Substring($command.Length).Trim()
        }
        else {
            ''
        }

        if ($command -eq 'achievement') {
            $command = 'achievements'
        }

        if (Test-LWDeathActive) {
            $allowedWhileDead = @('rewind', 'load', 'new', 'newrun', 'help', 'save', 'quit', 'exit', 'stats', 'campaign', 'achievements', 'achievement', 'modes', 'difficulty', 'permadeath')
            if ($allowedWhileDead -notcontains $command) {
                Set-LWScreen -Name 'death'
                $terminalType = if ($null -ne (Get-LWActiveDeathState)) { [string](Get-LWActiveDeathState).Type } else { '' }
                if ([string]$terminalType -ieq 'Failure') {
                    Write-LWWarn 'The mission has failed. Use rewind, load, newrun, modes, campaign, help, or quit.'
                }
                else {
                    Write-LWWarn 'You have fallen. Use rewind, load, newrun, modes, campaign, help, or quit.'
                }
                return $null
            }
        }

        switch ($command) {
            'new'         { New-LWGame; return $null }
            'newrun'      { New-LWRun; return $null }
            'sheet'       { Set-LWScreen -Name 'sheet'; return $null }
            'modes'       { Set-LWScreen -Name 'modes'; return $null }
            'difficulty'  {
                if ($parts.Count -gt 1) {
                    Set-LWRunDifficulty -Difficulty $parts[1]
                }
                else {
                    Show-LWRunDifficulty
                }
                return $null
            }
            'permadeath'  {
                if ($parts.Count -gt 1) {
                    Set-LWRunPermadeath -Value $parts[1]
                }
                else {
                    Show-LWRunPermadeath
                }
                return $null
            }
            'inv'         { Set-LWScreen -Name 'inventory'; return $null }
            'inventory'   { Set-LWScreen -Name 'inventory'; return $null }
            'disciplines' { Set-LWScreen -Name 'disciplines'; return $null }
            'discipline'  {
                if ($parts.Count -eq 1) {
                    Set-LWScreen -Name 'disciplines'
                    return $null
                }

                switch ($parts[1].ToLowerInvariant()) {
                    'add' {
                        $disciplineName = if ($parts.Count -gt 2) { ($parts[2..($parts.Count - 1)] -join ' ') } else { '' }
                        Add-LWDiscipline -Name $disciplineName
                    }
                    default {
                        Write-LWWarn 'Use discipline add [name] to grant a missed discipline.'
                    }
                }
                return $null
            }
            'notes'       { Set-LWScreen -Name 'notes'; return $null }
            'note'        {
                if ($parts.Count -gt 1 -and @('remove', 'delete', 'drop') -contains $parts[1].ToLowerInvariant()) {
                    Remove-LWNoteInteractive -InputParts $parts
                }
                else {
                    Add-LWNote -Text $argumentText
                }
                return $null
            }
            'history'     { Set-LWScreen -Name 'history'; return $null }
            'stats'       {
                $view = 'overview'
                if ($parts.Count -gt 1) {
                    switch ($parts[1].ToLowerInvariant()) {
                        'combat' { $view = 'combat' }
                        'survival' { $view = 'survival' }
                        'overview' { $view = 'overview' }
                        default {
                            Write-LWWarn 'Use stats, stats combat, or stats survival.'
                            return $null
                        }
                    }
                }

                Set-LWScreen -Name 'stats' -Data ([pscustomobject]@{
                        View = $view
                    })
                return $null
            }
            'campaign'    {
                $view = 'overview'
                if ($parts.Count -gt 1) {
                    switch ($parts[1].ToLowerInvariant()) {
                        'overview' { $view = 'overview' }
                        'books' { $view = 'books' }
                        'combat' { $view = 'combat' }
                        'survival' { $view = 'survival' }
                        'milestones' { $view = 'milestones' }
                        default {
                            Write-LWWarn 'Use campaign, campaign books, campaign combat, campaign survival, or campaign milestones.'
                            return $null
                        }
                    }
                }

                Set-LWScreen -Name 'campaign' -Data ([pscustomobject]@{
                        View = $view
                    })
                return $null
            }
            'achievements' {
                $view = 'overview'
                if ($parts.Count -gt 1) {
                    switch ($parts[1].ToLowerInvariant()) {
                        'overview' { $view = 'overview' }
                        'unlocked' { $view = 'unlocked' }
                        'locked' { $view = 'locked' }
                        'recent' { $view = 'recent' }
                        'progress' { $view = 'progress' }
                        'planned' { $view = 'planned' }
                        default {
                            Write-LWWarn 'Use achievements, achievements unlocked, achievements locked, achievements recent, achievements progress, or achievements planned.'
                            return $null
                        }
                    }
                }

                Set-LWScreen -Name 'achievements' -Data ([pscustomobject]@{
                        View = $view
                    })
                return $null
            }
            'roll'        {
                Invoke-LWCurrentSectionRandomNumberCheck
                return $null
            }
            'section'     {
                if ($parts.Count -gt 1) {
                    $sectionValue = 0
                    if ([int]::TryParse($parts[1], [ref]$sectionValue)) {
                        Set-LWSection -Section $sectionValue
                    }
                    else {
                        Write-LWWarn 'Section must be a whole number.'
                    }
                }
                else {
                    Set-LWSection
                }
                return $null
            }
            'healcheck'   { Invoke-LWHealingCheck; return $null }
            'add'         { Add-LWInventoryInteractive -InputParts $parts; return $null }
            'drop'        { Remove-LWInventoryInteractive -InputParts $parts; return $null }
            'recover'     { Restore-LWInventoryInteractive -InputParts $parts; return $null }
            'gold'        { Update-LWGoldInteractive -InputParts $parts; return $null }
            'meal'        { Use-LWMeal; return $null }
            'eat'         { Use-LWMeal; return $null }
            'potion'      { Use-LWHealingPotion; return $null }
            'die'         { Invoke-LWInstantDeath -Cause $argumentText; return $null }
            'fail'        { Invoke-LWFailure -Cause $argumentText; return $null }
            'rewind'      {
                if ($parts.Count -gt 1) {
                    $rewindSteps = 0
                    if ([int]::TryParse($parts[1], [ref]$rewindSteps)) {
                        Invoke-LWRewind -Steps $rewindSteps
                    }
                    else {
                        Write-LWWarn 'rewind expects a whole number, like rewind 2.'
                    }
                }
                else {
                    Invoke-LWRewind
                }
                return $null
            }
            'end'         {
                if ($parts.Count -gt 1) {
                    $delta = 0
                    if ([int]::TryParse($parts[1], [ref]$delta)) {
                        Update-LWEndurance -Delta $delta
                    }
                    else {
                        Write-LWWarn 'Endurance change must be a whole number, like end -1 or end +2.'
                    }
                }
                else {
                    Update-LWEndurance
                }
                return $null
            }
        'endurance'   {
            if ($parts.Count -gt 1) {
                $delta = 0
                if ([int]::TryParse($parts[1], [ref]$delta)) {
                    Update-LWEndurance -Delta $delta
                    }
                    else {
                        Write-LWWarn 'Endurance change must be a whole number, like endurance -1 or endurance +2.'
                    }
                }
                else {
                    Update-LWEndurance
            }
            return $null
        }
        'arrow'       {
            if ($parts.Count -gt 1) {
                $delta = 0
                if ([int]::TryParse($parts[1], [ref]$delta)) {
                    Update-LWQuiverArrows -Delta $delta
                }
                else {
                    Write-LWWarn 'Arrow change must be a whole number, like arrows -1 or arrows +2.'
                }
            }
            else {
                Update-LWQuiverArrows
            }
            return $null
        }
        'arrows'      {
            if ($parts.Count -gt 1) {
                $delta = 0
                if ([int]::TryParse($parts[1], [ref]$delta)) {
                    Update-LWQuiverArrows -Delta $delta
                }
                else {
                    Write-LWWarn 'Arrow change must be a whole number, like arrows -1 or arrows +2.'
                }
            }
            else {
                Update-LWQuiverArrows
            }
            return $null
        }
        'combat'      { Invoke-LWCombatCommand -Parts $parts; return $null }
            'fight'       {
                if ($parts.Count -gt 1) {
                    $fightSubcommand = $parts[1].ToLowerInvariant()
                    if (@('round', 'next', 'potion', 'auto', 'status', 'log', 'evade', 'stop') -contains $fightSubcommand) {
                        Invoke-LWCombatCommand -Parts @('combat') + @($parts[1..($parts.Count - 1)])
                        return $null
                    }
                }

                $started = if ($parts.Count -gt 1) { Start-LWCombat -Arguments @($parts[1..($parts.Count - 1)]) } else { Start-LWCombat }
                if ($started) {
                    Resolve-LWCombatToOutcome
                }
                return $null
            }
            'mode'        {
                if ($parts.Count -gt 1) {
                    Set-LWCombatMode -Mode $parts[1]
                }
                else {
                    Set-LWCombatMode
                }
                return $null
            }
            'complete'    { Complete-LWBook; return $null }
            'setcs'       { Set-LWCombatSkillBase; return $null }
            'setend'      {
                if ($parts.Count -gt 1) {
                    $currentValue = 0
                    if ([int]::TryParse($parts[1], [ref]$currentValue)) {
                        Set-LWEndurance -Current $currentValue
                    }
                    else {
                        Write-LWWarn 'Current Endurance must be a whole number.'
                    }
                }
                else {
                    Set-LWEndurance
                }
                return $null
            }
            'setmaxend'   {
                if ($parts.Count -gt 1) {
                    $maxValue = 0
                    if ([int]::TryParse($parts[1], [ref]$maxValue)) {
                        Set-LWMaxEndurance -Max $maxValue
                    }
                    else {
                        Write-LWWarn 'Maximum Endurance must be a whole number.'
                    }
                }
                else {
                    Set-LWMaxEndurance
                }
                return $null
            }
            'save'        { Save-LWGame; return $null }
            'load'        {
                if ([string]::IsNullOrWhiteSpace($argumentText)) {
                    Load-LWGameInteractive
                }
                else {
                    Load-LWGameInteractive -Selection $argumentText
                }
                return $null
            }
            'help'        { Set-LWScreen -Name 'help'; return $null }
            'quit'        { return 'quit' }
            'exit'        { return 'quit' }
            default       { Write-LWWarn "Unknown command: $command. Type help for the command list."; return $null }
        }
}

function Invoke-LWCoreStartTerminal {
    param(
        [hashtable]$Context,
        [string]$Load
    )

    Set-LWModuleContext -Context $Context

    $script:LWUi.Enabled = $true
        Set-LWScreen -Name 'welcome'
        Clear-LWModuleNotifications

        if (-not [string]::IsNullOrWhiteSpace($Load)) {
            Load-LWGame -Path $Load
        }
        else {
            Set-LWHostGameState -State (New-LWDefaultState) | Out-Null
            Set-LWScreen -Name 'welcome'
            Write-LWInfo 'No save loaded. Use new to create a character or load to open a save file.'
        }

        while ($true) {
            $line = ''
            try {
                Refresh-LWScreen
                $line = Read-Host 'lw'
                $result = Invoke-LWCommand -InputLine $line
                if ($result -eq 'quit') {
                    break
                }
            }
            catch {
                $logPath = Write-LWCrashLog -ErrorRecord $_ -InputLine $line -Stage 'main-loop'
                Write-LWError ("The assistant hit an unexpected error and wrote details to {0}. You can keep playing after this screen refresh." -f $logPath)
            }
        }

        $script:LWUi.Enabled = $false
        Write-LWInfo 'Good luck on the Kai trail.'
}

Export-ModuleMember -Function `
    Invoke-LWCoreShowHelpScreen, `
    Invoke-LWCoreCommand, `
    Invoke-LWCoreStartTerminal


