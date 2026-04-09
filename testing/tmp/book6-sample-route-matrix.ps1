#requires -Version 5.1
param(
    [string]$SourceSave = 'C:\Scripts\Lone Wolf\saves\sample-save.json',
    [string]$ShellLabel = 'PS',
    [string]$LogPath = '',
    [string]$JsonPath = ''
)

$ErrorActionPreference = 'Stop'

Set-Location 'C:\Scripts\Lone Wolf'
. .\lonewolf.ps1
Initialize-LWData
$script:LWUi.Enabled = $false

$script:MatrixReadHostQueue = [System.Collections.Generic.Queue[string]]::new()
$script:MatrixRandomDigitQueue = [System.Collections.Generic.Queue[int]]::new()
$script:MatrixCaseLabel = ''

function global:Read-Host {
    param([string]$Prompt = '')

    if ($script:MatrixReadHostQueue.Count -le 0) {
        throw "Read-Host queue exhausted for case '$script:MatrixCaseLabel' at prompt: $Prompt"
    }

    $value = [string]$script:MatrixReadHostQueue.Dequeue()
    Write-Host ("[{0}] PROMPT {1} => {2}" -f $script:MatrixCaseLabel, $Prompt, $value) -ForegroundColor DarkGray
    return $value
}

function global:Get-LWRandomDigit {
    if ($script:MatrixRandomDigitQueue.Count -gt 0) {
        $value = [int]$script:MatrixRandomDigitQueue.Dequeue()
        Write-Host ("[{0}] RNG => {1}" -f $script:MatrixCaseLabel, $value) -ForegroundColor DarkGray
        return $value
    }

    Write-Host ("[{0}] RNG => 4 (default)" -f $script:MatrixCaseLabel) -ForegroundColor DarkGray
    return 4
}

function Set-MatrixQueues {
    param(
        [string[]]$ReadHostValues = @(),
        [int[]]$RandomDigits = @()
    )

    $script:MatrixReadHostQueue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($value in @($ReadHostValues)) {
        [void]$script:MatrixReadHostQueue.Enqueue([string]$value)
    }

    $script:MatrixRandomDigitQueue = [System.Collections.Generic.Queue[int]]::new()
    foreach ($digit in @($RandomDigits)) {
        [void]$script:MatrixRandomDigitQueue.Enqueue([int]$digit)
    }
}

function Invoke-MatrixWithQueues {
    param(
        [string[]]$ReadHostValues = @(),
        [int[]]$RandomDigits = @(),
        [scriptblock]$Action
    )

    Set-MatrixQueues -ReadHostValues $ReadHostValues -RandomDigits $RandomDigits
    & $Action
}

function Assert-Matrix {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Set-MatrixRunDifficulty {
    param([string]$Difficulty)

    if (-not (Test-LWPropertyExists -Object $script:GameState -Name 'Run') -or $null -eq $script:GameState.Run) {
        $script:GameState | Add-Member -Force -NotePropertyName Run -NotePropertyValue (New-LWRunState)
    }
    $normalized = Get-LWNormalizedDifficultyName -Difficulty $Difficulty
    $script:GameState.Run.Difficulty = $normalized
    $script:GameState.Run.Permadeath = $false
}

function Get-MatrixTransitionResponses {
    param([Parameter(Mandatory = $true)][object]$Route)

    $responses = [System.Collections.Generic.List[string]]::new()
    $responses.Add([string]$Route.DisciplinesResponse)

    if (-not [string]::IsNullOrWhiteSpace([string]$Route.WeaponmasteryResponse)) {
        $responses.Add([string]$Route.WeaponmasteryResponse)
    }

    $responses.Add([string]$Route.DECuringResponse)
    $responses.Add([string]$Route.DEWeaponskillResponse)
    foreach ($value in @($Route.SafekeepingResponses)) {
        $responses.Add([string]$value)
    }
    foreach ($value in @($Route.StartingGearResponses)) {
        $responses.Add([string]$value)
    }

    return @($responses)
}

function Invoke-MatrixBookSixTransition {
    param(
        [Parameter(Mandatory = $true)][object]$Route,
        [Parameter(Mandatory = $true)][string]$Difficulty,
        [Parameter(Mandatory = $true)][string]$TestSave
    )

    Load-LWGame -Path $TestSave
    Set-MatrixRunDifficulty -Difficulty $Difficulty

    $beforeUnlocked = @($script:GameState.Achievements.Unlocked | ForEach-Object { [string]$_.Id })
    Invoke-MatrixWithQueues -ReadHostValues (Get-MatrixTransitionResponses -Route $Route) -RandomDigits @(4) -Action {
        Complete-LWBook
    }

    Assert-Matrix -Condition ([int]$script:GameState.Character.BookNumber -eq 6) -Message 'Book transition did not land in Book 6.'
    Assert-Matrix -Condition ([string]$script:GameState.RuleSet -eq 'Magnakai') -Message 'RuleSet did not switch to Magnakai.'

    Save-LWGame
    Load-LWGame -Path $TestSave

    Assert-Matrix -Condition ([int]$script:GameState.Character.BookNumber -eq 6) -Message 'Reload after transition did not stay in Book 6.'
    Assert-Matrix -Condition ((Get-LWBookSixDECuringOption -State $script:GameState) -eq [int]$Route.ExpectedDECuringOption) -Message 'Book 6 DE Curing option did not persist.'
    Assert-Matrix -Condition ((Get-LWBookSixDEWeaponskillOption -State $script:GameState) -eq [int]$Route.ExpectedDEWeaponskillOption) -Message 'Book 6 DE Weaponskill option did not persist.'

    foreach ($command in @('sheet', 'inv', 'campaign', 'achievements progress')) {
        Invoke-LWCommand -InputLine $command | Out-Null
    }

    $afterUnlocked = @($script:GameState.Achievements.Unlocked | ForEach-Object { [string]$_.Id })
    return [ordered]@{
        BeforeTransitionAchievements = @($beforeUnlocked)
        AfterTransitionAchievements  = @($afterUnlocked)
    }
}

function Start-MatrixCombatState {
    param(
        [string]$Weapon = 'Short Sword',
        [int]$EnemyCombatSkill = 16,
        [int]$EnemyEndurance = 20
    )

    $script:GameState.Combat = New-LWCombatState
    $script:GameState.Combat.Active = $true
    $script:GameState.Combat.EnemyName = 'Matrix Opponent'
    $script:GameState.Combat.EnemyCombatSkill = $EnemyCombatSkill
    $script:GameState.Combat.EnemyEnduranceCurrent = $EnemyEndurance
    $script:GameState.Combat.EnemyEnduranceMax = $EnemyEndurance
    $script:GameState.Combat.EquippedWeapon = $Weapon
}

function Invoke-RouteHerbWaterMapKey {
    $result = [ordered]@{}

    Assert-Matrix -Condition (Test-LWStateHasDiscipline -State $script:GameState -Name 'Curing') -Message 'Herb route should select Curing.'
    Assert-Matrix -Condition (Test-LWStateHasHerbPouch -State $script:GameState) -Message 'Herb Pouch should be active for DE Option 3.'
    $hasPotionForPouch = (
        (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Potion of Laumspur') -Type 'herbpouch') -or
        (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Potion of Laumspur') -Type 'backpack')
    )
    Assert-Matrix -Condition $hasPotionForPouch -Message 'Potion of Laumspur should be available for Herb Pouch testing.'

    Start-MatrixCombatState -Weapon 'Short Sword' -EnemyCombatSkill 14 -EnemyEndurance 18
    $potionCountBefore = @($script:GameState.Inventory.HerbPouchItems | Where-Object { [string]$_ -eq 'Potion of Laumspur' }).Count + @($script:GameState.Inventory.BackpackItems | Where-Object { [string]$_ -eq 'Potion of Laumspur' }).Count
    Invoke-LWCommand -InputLine 'combat potion' | Out-Null
    $potionCountAfter = @($script:GameState.Inventory.HerbPouchItems | Where-Object { [string]$_ -eq 'Potion of Laumspur' }).Count + @($script:GameState.Inventory.BackpackItems | Where-Object { [string]$_ -eq 'Potion of Laumspur' }).Count
    Assert-Matrix -Condition ($potionCountAfter -lt $potionCountBefore) -Message 'Herb Pouch combat action did not consume a potion.'
    $result.HerbPouchPotionUsed = $true

    Invoke-MatrixWithQueues -ReadHostValues @('n') -Action {
        Set-LWSection -Section 65
    }
    $hasTaunorWaterInBackpack = Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Type 'backpack'
    $hasTaunorWaterInHerbPouch = Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWTaunorWaterItemNames) -Type 'herbpouch'
    Assert-Matrix -Condition ($hasTaunorWaterInBackpack -or $hasTaunorWaterInHerbPouch) -Message 'Taunor Water should be stored after declining to drink it.'
    $result.StoredTaunorWater = $true
    $result.TaunorWaterStorage = if ($hasTaunorWaterInHerbPouch) { 'HerbPouch' } elseif ($hasTaunorWaterInBackpack) { 'Backpack' } else { '(missing)' }

    Invoke-MatrixWithQueues -ReadHostValues @('1', '2', '0') -Action {
        Set-LWSection -Section 48
    }
    Assert-Matrix -Condition (-not (Test-LWStoryAchievementFlag -Name 'Book6Section048GoldClaimed')) -Message 'Section 48 gold should stay unclaimed when the purse is full.'
    Assert-Matrix -Condition (Test-LWStoryAchievementFlag -Name 'Book6Section048MapClaimed') -Message 'Section 48 map should be claimed.'
    $result.Section48GoldClaimed = [bool](Test-LWStoryAchievementFlag -Name 'Book6Section048GoldClaimed')
    $result.Section48MapClaimed = [bool](Test-LWStoryAchievementFlag -Name 'Book6Section048MapClaimed')

    Invoke-MatrixWithQueues -ReadHostValues @('5', '0') -Action {
        Set-LWSection -Section 158
    }
    Assert-Matrix -Condition (Test-LWStoryAchievementFlag -Name 'Book6Section158SilverKeyClaimed') -Message 'Section 158 should auto-claim the Small Silver Key.'
    Assert-Matrix -Condition (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSmallSilverKeyItemNames) -Type 'special') -Message 'Small Silver Key should be in Special Items before section 293.'
    Assert-Matrix -Condition (Test-LWStateHasInventoryItem -State $script:GameState -Names @('Rope') -Type 'backpack') -Message 'Section 158 loot selection should add Rope.'
    $result.SmallSilverKeyClaimed = $true

    Set-LWSection -Section 293
    Assert-Matrix -Condition (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSmallSilverKeyItemNames) -Type 'special')) -Message 'Section 293 should erase the Small Silver Key.'
    $result.SmallSilverKeyUsed = [bool](Test-LWStoryAchievementFlag -Name 'Book6Section293SilverKeyUsed')

    return $result
}

function Invoke-RouteSilverBow {
    $result = [ordered]@{}

    Assert-Matrix -Condition (Test-LWStateHasDiscipline -State $script:GameState -Name 'Weaponmastery') -Message 'Silver Bow route should select Weaponmastery.'
    Assert-Matrix -Condition (@($script:GameState.Character.WeaponmasteryWeapons) -contains 'Bow') -Message 'Silver Bow route should master Bow.'
    Assert-Matrix -Condition ((Get-LWBookSixDEWeaponskillOption -State $script:GameState) -eq 0) -Message 'Silver Bow route should disable DE Weaponskill.'
    Assert-Matrix -Condition ((Get-LWBookSixDECuringOption -State $script:GameState) -eq 2) -Message 'Silver Bow route should use Healing Instead.'

    Set-LWSection -Section 252
    Assert-Matrix -Condition (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWSilverBowOfDuadonItemNames) -Type 'special') -Message 'Section 252 should grant the Silver Bow of Duadon.'

    $script:GameState.CurrentSection = 170
    $context170 = Get-LWMagnakaiBookSixSectionRandomNumberContext -State $script:GameState
    Assert-Matrix -Condition ($null -ne $context170 -and [int]$context170.Modifier -eq 7) -Message 'Section 170 should report +7 with Bow mastery, Huntmastery, and the Silver Bow.'
    $result.Random170Modifier = [int]$context170.Modifier

    Start-MatrixCombatState -Weapon 'Short Sword' -EnemyCombatSkill 15 -EnemyEndurance 18
    $breakdown = Get-LWCombatBreakdownFromState -State $script:GameState
    $notes = @($breakdown.Notes) -join ' | '
    Assert-Matrix -Condition ($notes -notlike '*Weaponskill +2*') -Message 'Disabled Book 6 DE Weaponskill should not add +2 in combat.'
    $result.CombatSkill = [int]$breakdown.PlayerCombatSkill
    $result.CombatNotes = $notes

    return $result
}

function Invoke-RouteWagonCess {
    $result = [ordered]@{}

    Assert-Matrix -Condition (Test-LWStateHasDiscipline -State $script:GameState -Name 'Animal Control') -Message 'Wagon route should select Animal Control.'
    Assert-Matrix -Condition (Test-LWStateHasDiscipline -State $script:GameState -Name 'Weaponmastery') -Message 'Wagon route should select Weaponmastery.'
    Assert-Matrix -Condition (@($script:GameState.Character.WeaponmasteryWeapons) -contains 'Short Sword') -Message 'Wagon route should master Short Sword.'
    Assert-Matrix -Condition ((Get-LWBookSixDEWeaponskillOption -State $script:GameState) -eq 1) -Message 'Wagon route should enable DE Weaponskill.'

    $script:GameState.CurrentSection = 72
    $context72 = Get-LWMagnakaiBookSixSectionRandomNumberContext -State $script:GameState
    Assert-Matrix -Condition ($null -ne $context72 -and [int]$context72.Modifier -eq 2) -Message 'Section 72 should report +2 with Animal Control.'
    $result.Random72Modifier = [int]$context72.Modifier

    Set-LWSection -Section 274
    Assert-Matrix -Condition (Test-LWStoryAchievementFlag -Name 'Book6JumpTheWagonsRoute') -Message 'Section 274 should flag the wagon-jump route.'

    Set-LWSection -Section 304
    Assert-Matrix -Condition (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWCessItemNames) -Type 'special') -Message 'Section 304 should add the Cess.'
    $result.CessClaimed = [bool](Test-LWStoryAchievementFlag -Name 'Book6Section304CessClaimed')

    Start-MatrixCombatState -Weapon 'Short Sword' -EnemyCombatSkill 17 -EnemyEndurance 20
    $breakdown = Get-LWCombatBreakdownFromState -State $script:GameState
    $notes = @($breakdown.Notes) -join ' | '
    Assert-Matrix -Condition ($notes -like '*Weaponskill +2*') -Message 'Enabled Book 6 DE Weaponskill should add +2 in combat.'
    Assert-Matrix -Condition ($notes -like '*Weaponmastery +3*') -Message 'Weaponmastery should add +3 on Short Sword.'
    Assert-Matrix -Condition ($breakdown.PlayerCombatSkill -ge 17) -Message 'Weaponmastery and DE Weaponskill should stack on Short Sword.'
    $result.CombatSkill = [int]$breakdown.PlayerCombatSkill
    $result.CombatNotes = $notes

    return $result
}

function Invoke-RouteColdPsi {
    param([string]$Difficulty)

    $result = [ordered]@{}

    Assert-Matrix -Condition (Test-LWStateHasDiscipline -State $script:GameState -Name 'Nexus') -Message 'Cold route should select Nexus.'
    Assert-Matrix -Condition (Test-LWStateHasDiscipline -State $script:GameState -Name 'Psi-screen') -Message 'Cold route should select Psi-screen.'
    Assert-Matrix -Condition (@($script:GameState.Inventory.Weapons) -contains 'Warhammer') -Message 'Cold route should carry Warhammer to test section 348.'

    $before306 = [int]$script:GameState.Character.EnduranceCurrent
    Set-LWSection -Section 306
    Assert-Matrix -Condition ([int]$script:GameState.Character.EnduranceCurrent -eq $before306) -Message 'Nexus should prevent cold damage at section 306.'
    Assert-Matrix -Condition (Test-LWStoryAchievementFlag -Name 'Book6Section306NexusProtected') -Message 'Section 306 should record Nexus protection.'

    $before315 = [int]$script:GameState.Character.EnduranceCurrent
    Set-LWSection -Section 315
    Assert-Matrix -Condition ([int]$script:GameState.Character.EnduranceCurrent -eq $before315) -Message 'Psi-screen should block section 315 mindforce damage.'
    Assert-Matrix -Condition (Test-LWStoryAchievementFlag -Name 'Book6Section315MindforceBlocked') -Message 'Section 315 should record Psi-screen protection.'

    $before310 = [int]$script:GameState.Character.EnduranceCurrent
    $expectedLoss = [int](Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage' -State $script:GameState).AppliedLoss
    Set-LWSection -Section 310
    $appliedLoss = $before310 - [int]$script:GameState.Character.EnduranceCurrent
    Assert-Matrix -Condition ($appliedLoss -eq $expectedLoss) -Message ("Section 310 should apply {0} END loss on {1}." -f $expectedLoss, $Difficulty)
    $result.Section310ExpectedLoss = $expectedLoss
    $result.Section310AppliedLoss = $appliedLoss

    Set-LWSection -Section 348
    Assert-Matrix -Condition (@($script:GameState.Inventory.Weapons) -contains 'Warhammer') -Message 'Section 348 should not remove a separately carried Warhammer.'
    Assert-Matrix -Condition (Test-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost') -Message 'Section 348 should record that the chapel Warhammer was lost.'
    $result.WarhammerLost = [bool](Test-LWStoryAchievementFlag -Name 'Book6Section348WarhammerLost')
    $result.CarriedWarhammerRetained = @($script:GameState.Inventory.Weapons) -contains 'Warhammer'

    return $result
}

$routeBundles = @(
    [pscustomobject]@{
        Name                     = 'HerbWaterMapKey'
        DisciplinesResponse      = '3,5,8'
        WeaponmasteryResponse    = ''
        DECuringResponse         = '3'
        ExpectedDECuringOption   = 3
        DEWeaponskillResponse    = 'y'
        ExpectedDEWeaponskillOption = 1
        SafekeepingResponses     = @('0')
        StartingGearResponses    = @('17', '2', '0')
    },
    [pscustomobject]@{
        Name                     = 'SilverBow'
        DisciplinesResponse      = '1,5,8'
        WeaponmasteryResponse    = '5,8,10'
        DECuringResponse         = '2'
        ExpectedDECuringOption   = 2
        DEWeaponskillResponse    = 'n'
        ExpectedDEWeaponskillOption = 0
        SafekeepingResponses     = @('0')
        StartingGearResponses    = @('5', '4', '0')
    },
    [pscustomobject]@{
        Name                     = 'WagonCess'
        DisciplinesResponse      = '1,2,8'
        WeaponmasteryResponse    = '5,7,10'
        DECuringResponse         = '0'
        ExpectedDECuringOption   = 0
        DEWeaponskillResponse    = 'y'
        ExpectedDEWeaponskillOption = 1
        SafekeepingResponses     = @('0')
        StartingGearResponses    = @('13', '6', '0')
    },
    [pscustomobject]@{
        Name                     = 'ColdPsi'
        DisciplinesResponse      = '6,8,9'
        WeaponmasteryResponse    = ''
        DECuringResponse         = '0'
        ExpectedDECuringOption   = 0
        DEWeaponskillResponse    = 'y'
        ExpectedDEWeaponskillOption = 1
        SafekeepingResponses     = @('0')
        StartingGearResponses    = @('14', '3', '0')
    }
)

$difficulties = @('Story', 'Easy', 'Normal', 'Hard', 'Veteran')
$allResults = [System.Collections.Generic.List[object]]::new()
$caseIndex = 0
$totalCases = $routeBundles.Count * $difficulties.Count

foreach ($difficulty in $difficulties) {
    foreach ($route in $routeBundles) {
        $caseIndex++
        $caseLabel = "{0}-{1}-{2}" -f $ShellLabel, $difficulty, $route.Name
        $script:MatrixCaseLabel = $caseLabel
        Write-Host ("[{0}/{1}] {2}" -f $caseIndex, $totalCases, $caseLabel) -ForegroundColor Cyan

        $testSave = "C:\Scripts\Lone Wolf\testing\saves\book6-matrix-$($ShellLabel.ToLowerInvariant())-$($difficulty.ToLowerInvariant())-$($route.Name.ToLowerInvariant()).json"
        Copy-Item -LiteralPath $SourceSave -Destination $testSave -Force

        $caseResult = [ordered]@{
            Shell            = $ShellLabel
            Difficulty       = $difficulty
            Route            = $route.Name
            SavePath         = $testSave
            Transition       = $null
            RouteDetails     = $null
            Completed        = $false
            NewAchievements  = @()
            Status           = 'Pending'
            Error            = $null
        }

        try {
            $caseResult.Transition = Invoke-MatrixBookSixTransition -Route $route -Difficulty $difficulty -TestSave $testSave
            $beforeCompletionUnlocked = @($script:GameState.Achievements.Unlocked | ForEach-Object { [string]$_.Id })

            switch ($route.Name) {
                'HerbWaterMapKey' { $caseResult.RouteDetails = Invoke-RouteHerbWaterMapKey }
                'SilverBow'      { $caseResult.RouteDetails = Invoke-RouteSilverBow }
                'WagonCess'      { $caseResult.RouteDetails = Invoke-RouteWagonCess }
                'ColdPsi'        { $caseResult.RouteDetails = Invoke-RouteColdPsi -Difficulty $difficulty }
                default          { throw "Unknown route bundle: $($route.Name)" }
            }

            Save-LWGame
            Load-LWGame -Path $testSave
            Set-LWSection -Section 350
            Complete-LWBook

            Assert-Matrix -Condition (@($script:GameState.Character.CompletedBooks) -contains 6) -Message 'Book 6 should appear in CompletedBooks after completion.'
            Assert-Matrix -Condition ([string]$script:GameState.Run.Status -eq 'Completed') -Message 'Run status should be Completed after finishing Book 6.'

            $afterCompletionUnlocked = @($script:GameState.Achievements.Unlocked | ForEach-Object { [string]$_.Id })
            $caseResult.NewAchievements = @($afterCompletionUnlocked | Where-Object { $beforeCompletionUnlocked -notcontains $_ })
            $caseResult.Completed = $true
            $caseResult.Status = 'Pass'
            Write-Host ("PASS {0}" -f $caseLabel) -ForegroundColor Green
        }
        catch {
            $caseResult.Status = 'Fail'
            $caseResult.Error = $_.Exception.Message
            Write-Host ("FAIL {0}: {1}" -f $caseLabel, $_.Exception.Message) -ForegroundColor Red
        }

        $allResults.Add([pscustomobject]$caseResult)
    }
}

$passCount = @($allResults | Where-Object { [string]$_.Status -eq 'Pass' }).Count
$failCount = @($allResults | Where-Object { [string]$_.Status -eq 'Fail' }).Count

$summaryLines = @()
$summaryLines += "# Book 6 sample Route Matrix - $ShellLabel"
$summaryLines += ''
$summaryLines += ("- Source save: {0}" -f $SourceSave)
$summaryLines += ("- Cases: {0}" -f $totalCases)
$summaryLines += ("- Passed: {0}" -f $passCount)
$summaryLines += ("- Failed: {0}" -f $failCount)
$summaryLines += ''
$summaryLines += '| Difficulty | Route | Status | New Achievements | Notes |'
$summaryLines += '| --- | --- | --- | --- | --- |'
foreach ($entry in $allResults) {
    $notes = if ([string]$entry.Status -eq 'Pass') {
        switch ([string]$entry.Route) {
            'HerbWaterMapKey' { 'Herb Pouch, Taunor Water, Map of Tekaro, Small Silver Key' }
            'SilverBow' { 'Healing Instead, Silver Bow, Bow modifier context' }
            'WagonCess' { 'Animal Control wagon route, Cess, DE Weaponskill stack' }
            'ColdPsi' { 'Nexus cold block, Psi-screen block, difficulty-scaled END loss' }
            default { '' }
        }
    }
    else {
        [string]$entry.Error
    }
    $summaryLines += ('| {0} | {1} | {2} | {3} | {4} |' -f [string]$entry.Difficulty, [string]$entry.Route, [string]$entry.Status, (@($entry.NewAchievements) -join ', '), $notes.Replace('|','/'))
}

$summaryText = $summaryLines -join [Environment]::NewLine
$summaryText

if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
    $summaryText | Set-Content -LiteralPath $LogPath -Encoding UTF8
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    $allResults | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
}

if ($failCount -gt 0) {
    throw ("{0} Book 6 matrix case(s) failed for {1}." -f $failCount, $ShellLabel)
}

