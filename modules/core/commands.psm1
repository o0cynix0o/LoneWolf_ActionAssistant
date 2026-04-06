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

    Write-LWPanelHeader -Title 'Commands' -AccentColor 'Cyan'
        Write-LWKeyValue -Label 'new' -Value 'Create a new Lone Wolf character' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'newrun' -Value 'Start a fresh run on the same profile and keep achievements' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'sheet' -Value 'Show character sheet' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'modes' -Value 'Show run mode rules and locked settings' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'difficulty [name]' -Value 'Show the locked run difficulty' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'permadeath [on|off]' -Value 'Show the locked permadeath setting' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'inv' -Value 'Show inventory slots' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'disciplines' -Value 'Show disciplines' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'discipline add [name]' -Value 'Add a missed discipline reward for the active ruleset' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'notes' -Value 'Show notes' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'note [text]' -Value 'Add a note' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'note remove [n]' -Value 'Remove a note by number' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'history' -Value 'Show combat history grouped by book' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'stats [combat|survival]' -Value 'Show live current-book stats' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'campaign [view]' -Value 'Show whole-run overview, books, combat, survival, or milestones' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'achievements [view]' -Value 'Show unlocked, locked, recent, progress, or planned achievements' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'roll' -Value 'Roll the random number table (0-9)' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'section [n]' -Value 'Move to a new section' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'healcheck' -Value 'Apply Healing for a non-combat section' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'add [type name [qty]]' -Value 'Add inventory item (weapon/backpack/herbpouch/special)' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'drop [type slot|all]' -Value 'Remove inventory item by slot or clear a section' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'recover [type|all]' -Value 'Restore stashed gear from a bulk drop' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'gold [delta]' -Value 'Gain or spend Gold Crowns' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'meal' -Value 'Resolve an eat instruction' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'potion' -Value 'Use a Healing or Laumspur Potion outside combat' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'end [delta]' -Value 'Adjust current Endurance only' -ValueColor 'Gray'
            Write-LWKeyValue -Label 'die [cause]' -Value 'Record an instant death and open rewind options' -ValueColor 'Gray'
            Write-LWKeyValue -Label 'fail [cause]' -Value 'Record a failed mission and open rewind options' -ValueColor 'Gray'
            Write-LWKeyValue -Label 'rewind [n]' -Value 'After death or failure, return to an earlier safe section' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat start' -Value 'Start combat' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat round' -Value 'Resolve one combat round' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat next' -Value 'Alias for combat round' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat potion' -Value 'Book 6 Herb Pouch: drink a potion instead of attacking' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat auto' -Value 'Resolve combat until it ends' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat status' -Value 'Show combat status' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat log [n|all|book n]' -Value 'Show the current, last, or archived combat log' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat evade' -Value 'Evade if allowed' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'combat stop' -Value 'Stop and archive current combat' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'fight [enemy cs end]' -Value 'Start combat, then auto-resolve it' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'mode [manual|data]' -Value 'Switch combat mode' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'complete' -Value 'Mark current book complete and advance to the next supported book' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'setcs' -Value 'Manually set base Combat Skill' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'setend [current]' -Value 'Manually set current Endurance only' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'setmaxend [max]' -Value 'Manually set maximum Endurance' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'save' -Value 'Save to JSON' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'load [n|path]' -Value 'Load from JSON' -ValueColor 'Gray'
        Write-LWKeyValue -Label 'quit' -Value 'Exit the terminal' -ValueColor 'Gray'
        Write-LWPanelHeader -Title 'Aliases' -AccentColor 'Magenta'
        Write-LWBulletItem -Text 'fight is a quick combat alias: it starts combat and auto-resolves it in one command.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'fight status/log/auto/round/next/potion/evade/stop mirror the matching combat subcommands.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'inventory is the same as inv.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'combat next is the same as combat round.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'mode manual maps to ManualCRT, and mode data maps to DataFile.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'exit is the same as quit.' -TextColor 'Gray'
        Write-LWPanelHeader -Title 'Tips' -AccentColor 'DarkYellow'
        Write-LWBulletItem -Text 'While combat is active, pressing Enter advances one round.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Quick start syntax: combat start Giak 12 10' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use inv to see exact weapon, backpack, Herb Pouch, and special-item slots, including empty spaces.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use drop backpack 2, drop herbpouch 1, or drop weapon 1 to remove by slot number, or drop backpack all to clear a section.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Bulk drop stashes that section''s contents, so recover backpack or recover all can restore them later.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use discipline add to open the current ruleset discipline picker, or discipline add <name> to grant one directly.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use end -1 for section damage and end +1 for simple recovery without touching max END.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Shield and Silver Helm each add +2 Combat Skill automatically; Chainmail Waistcoat adds +4 END, Padded Leather Waistcoat adds +2 END, and Helmet adds +2 END unless Silver Helm is also carried.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Bone Sword is treated as a weapon and adds +1 Combat Skill in Book 3 / Kalte only; Broadsword +1 adds +1 Combat Skill and still counts as a Broadsword; Drodarin War Hammer adds +1 Combat Skill and counts as a Warhammer; Captain D''Val''s Sword adds +1 Combat Skill and counts as a Sword; Solnaris adds +2 Combat Skill and counts as a Sword or Broadsword for Weaponskill.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'From Book 2 onward, Sommerswerd is a weapon-like Special Item: +8 Combat Skill in combat, or +10 total with Sword, Short Sword, or Broadsword Weaponskill.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'When Sommerswerd is active against undead foes, their END loss is doubled automatically.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'If an enemy is using Mindforce, the app can apply its extra END loss each round and Mindshield blocks it automatically.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'In Book 3 and later, combat can attempt a knockout: edged weapons take -2 CS, while unarmed, Warhammer, Quarterstaff, and Mace do not.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'potion works with Healing Potion, Laumspur Potion, and Book 1 Laumspur Herb item names.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'From Book 6 onward, if DE Curing Option 3 was chosen and Herb Pouch is carried, potion can also be used during combat and enemy END loss is ignored for that round.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'potion now prefers Concentrated Laumspur first and restores 8 END when one is available.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'From Book 3 onward, if Alether is in your backpack, combat start can consume it before the fight to grant +4 Combat Skill for that combat only.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'New Book 1 runs now seed the starting Axe, Meal, Map of Sommerlund, random Gold, and random monastery item automatically.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Book 1 section 170 now handles the Burrowcrawler''s torch darkness rule and Mindblast immunity automatically.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use die for instant-death sections and fail for dead-end story failures. Then use rewind or rewind 2 to go back to earlier safe sections.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'history and combat log all now group archived fights by book for easier browsing.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use combat log book 2 to review archived fights from one book only.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use campaign to review the whole run, or campaign books/combat/survival/milestones for focused views.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use achievements, achievements progress, or achievements planned to browse the new achievement system.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Book 3 now has hidden story achievements tied to specific sections and discoveries, including the Diamond from section 218.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Use modes to review Story, Easy, Normal, Hard, Veteran, and Permadeath before starting a run.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'Difficulty is locked for the whole run, and Permadeath can only be chosen at run start.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'ManualCRT gives you the ratio and roll, then asks for losses from your own CRT.' -TextColor 'Gray'
        Write-LWBulletItem -Text 'DataFile reads those losses from data/crt.json when the file is populated.' -TextColor 'Gray'
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
                Write-LWCurrentSectionRandomNumberRoll -Roll (Get-LWRandomDigit)
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

