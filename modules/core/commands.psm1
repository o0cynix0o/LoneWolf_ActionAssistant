Set-StrictMode -Version Latest

function Set-LWModuleContext {
    param([hashtable]$Context)
    if ($null -eq $Context) { return }
    foreach ($key in @($Context.Keys)) {
        Set-Variable -Scope Script -Name $key -Value $Context[$key] -Force
    }
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

    Write-LWRetroPanelHeader -Title 'Core Commands' -AccentColor 'Cyan'
    Write-LWRetroPanelTwoColumnRow -LeftText 'sheet' -RightText 'inv' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'disciplines' -RightText 'stats' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'campaign' -RightText 'achievements' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'history' -RightText 'notes' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'save' -RightText 'load' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'help' -RightText 'quit' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Play Commands' -AccentColor 'DarkYellow'
    Write-LWRetroPanelTwoColumnRow -LeftText 'section <n>' -RightText 'combat' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'potion' -RightText 'eat / meal' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'note <text>' -RightText 'roll' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'add / drop / recover' -RightText 'gold / end' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'arrows +/-n' -RightText '' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelFooter

    Write-LWRetroPanelHeader -Title 'Run Commands' -AccentColor 'Magenta'
    Write-LWRetroPanelTwoColumnRow -LeftText 'new' -RightText 'newrun' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'modes' -RightText 'rewind' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelTwoColumnRow -LeftText 'fail / die' -RightText 'complete' -LeftColor 'Gray' -RightColor 'Gray' -LeftWidth 28 -Gap 2
    Write-LWRetroPanelFooter
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
            if ($script:GameState -and $script:GameState.Combat.Active) {
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
            $script:GameState = (New-LWDefaultState)
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

