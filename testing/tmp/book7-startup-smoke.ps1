$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()

function Set-LWBookSevenStartupSmokeQueues {
    param(
        [int[]]$Ints = @(),
        [string[]]$Texts = @(),
        [bool[]]$YesNo = @()
    )

    $script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
    foreach ($value in @($Ints)) { $script:IntQueue.Enqueue([int]$value) }

    $script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($value in @($Texts)) { $script:TextQueue.Enqueue([string]$value) }

    $script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()
    foreach ($value in @($YesNo)) { $script:YesNoQueue.Enqueue([bool]$value) }
}

function global:Read-LWPromptLine {
    param(
        [string]$Prompt = '',
        [switch]$ReturnNullOnEof
    )

    if ($script:TextQueue.Count -gt 0) { return [string]$script:TextQueue.Dequeue() }
    if ($ReturnNullOnEof) { return $null }
    return ''
}

function global:Read-LWInt {
    param(
        [string]$Prompt,
        [int]$Default = 0,
        [int]$Min = [int]::MinValue,
        [int]$Max = [int]::MaxValue,
        [switch]$NoRefresh
    )

    if ($script:IntQueue.Count -gt 0) { return [int]$script:IntQueue.Dequeue() }
    if ($PSBoundParameters.ContainsKey('Default')) { return [int]$Default }
    if ($Min -ne [int]::MinValue) { return [int]$Min }
    return 0
}

function global:Read-LWText {
    param(
        [string]$Prompt,
        [string]$Default = '',
        [switch]$NoRefresh
    )

    if ($script:TextQueue.Count -gt 0) { return [string]$script:TextQueue.Dequeue() }
    if ($PSBoundParameters.ContainsKey('Default')) { return [string]$Default }
    return ''
}

function global:Read-LWYesNo {
    param([string]$Prompt, [bool]$Default = $false, [switch]$NoRefresh)
    if ($script:YesNoQueue.Count -gt 0) { return [bool]$script:YesNoQueue.Dequeue() }
    return [bool]$Default
}

function global:Read-LWInlineYesNo {
    param([string]$Prompt, [bool]$Default = $false)
    if ($script:YesNoQueue.Count -gt 0) { return [bool]$script:YesNoQueue.Dequeue() }
    return [bool]$Default
}

function global:Read-Host {
    param([string]$Prompt)
    if ($script:TextQueue.Count -gt 0) { return [string]$script:TextQueue.Dequeue() }
    return ''
}

function global:Write-LWInfo { param([string]$Message) }
function global:Write-LWWarn { param([string]$Message) }
function global:Write-LWError { param([string]$Message) }
function global:Add-LWNotification { param([string]$Message, [string]$Level) }
function global:Request-LWRender { param() }
function global:Refresh-LWScreen { param() }
function global:Clear-LWScreenHost { param([switch]$PreserveNotifications) }

function New-LWBookSevenStartupSmokeState {
    param(
        [int]$Gold = 0,
        [switch]$CarryExistingGear,
        [switch]$BackpackLost,
        [string[]]$BackpackItems = @('Towel'),
        [string[]]$HerbPouchItems = @('Healing Potion'),
        [bool]$HasHerbPouch = $true,
        [int]$MagnakaiRank = 4,
        [string[]]$MagnakaiDisciplines = @('Weaponmastery', 'Curing', 'Nexus', 'Psi-surge'),
        [string[]]$WeaponmasteryWeapons = @('Sword', 'Bow', 'Warhammer', 'Dagger')
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Book7 Startup Smoke'
    $state.Character.BookNumber = 7
    $state.RuleSet = 'Magnakai'
    $state.Character.LegacyKaiComplete = $true
    $state.Character.MagnakaiRank = [int]$MagnakaiRank
    $state.Character.MagnakaiDisciplines = @($MagnakaiDisciplines)
    $state.Character.WeaponmasteryWeapons = @($WeaponmasteryWeapons)
    $state.Character.EnduranceCurrent = 30
    $state.Character.EnduranceMax = 30
    $state.Inventory.GoldCrowns = [int]$Gold
    $state.Inventory.SpecialItems = @('Book of the Magnakai')
    $state.Inventory.Weapons = @()
    $state.Inventory.BackpackItems = @()
    $state.Inventory.HerbPouchItems = @()
    $state.Inventory.HasHerbPouch = $false
    $state.Inventory.PocketSpecialItems = @()
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)

    if ($CarryExistingGear) {
        $state.Inventory.Weapons = @('Short Sword')
        $state.Inventory.BackpackItems = @($BackpackItems)
        $state.Inventory.HerbPouchItems = @($HerbPouchItems)
        $state.Inventory.HasHerbPouch = ([bool]$HasHerbPouch -or @($HerbPouchItems).Count -gt 0)
        $state.Storage.Confiscated.BackpackItems = @('Meal')
        $state.Storage.Confiscated.HerbPouchItems = @('Laumspur Herb')
        $state.Storage.Confiscated.HasHerbPouch = $true
        $state.RecoveryStash.Backpack.Items = @('Blanket')
        $state.RecoveryStash.HerbPouch.Items = @('Alether')
    }

    Set-LWHostGameState -State $state | Out-Null
    if ($BackpackLost) {
        Set-LWBackpackState -HasBackpack:$false
    }
    else {
        Set-LWBackpackState -HasBackpack:$true
    }
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Assert-LWBookSevenStartupSmoke {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$tests = @(
    @{
        Name = 'Fresh Book 7 startup chooses five items'
        Ints = @(1, 1, 1, 1, 1)
        BuildState = { New-LWBookSevenStartupSmokeState }
        Assert = {
            param($state)
            Assert-LWBookSevenStartupSmoke -Condition ([string]$state.RuleSet -eq 'Magnakai') -Message 'Book 7 startup did not keep the Magnakai ruleset.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Fresh Book 7 startup did not add the Sword.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Bow' }).Count -eq 1) -Message 'Fresh Book 7 startup did not add the Bow.'
            Assert-LWBookSevenStartupSmoke -Condition ([int]$state.Inventory.QuiverArrows -eq 6) -Message 'Fresh Book 7 startup did not load the Quiver with 6 Arrows.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Rope' }).Count -eq 1) -Message 'Fresh Book 7 startup did not add Rope.'
            Assert-LWBookSevenStartupSmoke -Condition (-not [string]::IsNullOrWhiteSpace((Get-LWMatchingStateInventoryItem -State $state -Names @('Potion of Laumspur', 'Healing Potion') -Type 'backpack'))) -Message 'Fresh Book 7 startup did not add the Potion of Laumspur.'
            Assert-LWBookSevenStartupSmoke -Condition ([int]$state.Inventory.GoldCrowns -ge 10 -and [int]$state.Inventory.GoldCrowns -le 19) -Message 'Fresh Book 7 startup gold roll was outside the expected +10 to +19 range.'
        }
    }
    @{
        Name = 'Carry-forward preserves gear and restores backpack'
        Texts = @('N')
        Ints = @(3, 4, 4, 5, 6)
        BuildState = { New-LWBookSevenStartupSmokeState -Gold 5 -CarryExistingGear -BackpackLost }
        CarryExistingGear = $true
        Assert = {
            param($state)
            Assert-LWBookSevenStartupSmoke -Condition (Test-LWStateHasBackpack -State $state) -Message 'Book 7 carry-forward did not restore the backpack state.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Short Sword' }).Count -eq 1) -Message 'Book 7 carry-forward did not preserve the existing Short Sword.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Towel' }).Count -eq 0) -Message 'Book 7 carry-forward incorrectly preserved a Book 6 Backpack Item.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.HerbPouchItems | Where-Object { $_ -eq 'Healing Potion' }).Count -eq 0) -Message 'Book 7 carry-forward incorrectly preserved Herb Pouch contents.'
            Assert-LWBookSevenStartupSmoke -Condition (-not [bool]$state.Inventory.HasHerbPouch) -Message 'Book 7 carry-forward incorrectly preserved the Herb Pouch.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Storage.Confiscated.BackpackItems).Count -eq 0) -Message 'Book 7 carry-forward left confiscated Backpack Items available across the handoff.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Storage.Confiscated.HerbPouchItems).Count -eq 0 -and -not [bool]$state.Storage.Confiscated.HasHerbPouch) -Message 'Book 7 carry-forward left confiscated Herb Pouch state available across the handoff.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.RecoveryStash.Backpack.Items).Count -eq 0) -Message 'Book 7 carry-forward left recovery-stashed Backpack Items available across the handoff.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.RecoveryStash.HerbPouch.Items).Count -eq 0) -Message 'Book 7 carry-forward left recovery-stashed Herb Pouch items available across the handoff.'
            Assert-LWBookSevenStartupSmoke -Condition ([int]$state.Inventory.QuiverArrows -eq 6) -Message 'Book 7 carry-forward did not add the Quiver correctly.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Lantern' }).Count -eq 1) -Message 'Book 7 carry-forward did not add the Lantern.'
            Assert-LWBookSevenStartupSmoke -Condition (Test-LWStateHasPocketSpecialItem -State $state -Names @('Fireseed', 'Fireseeds')) -Message 'Book 7 carry-forward did not add the Fireseed pocket item.'
        }
    }
    @{
        Name = 'Carry-forward preserves Book 6 Weaponmastery picks and adds one new mastery'
        Texts = @('1', '1', 'N')
        Ints = @(3, 4, 4, 5, 6)
        BuildState = {
            New-LWBookSevenStartupSmokeState -Gold 5 -CarryExistingGear -MagnakaiRank 3 -MagnakaiDisciplines @('Weaponmastery', 'Curing', 'Nexus') -WeaponmasteryWeapons @('Sword', 'Bow', 'Warhammer')
        }
        CarryExistingGear = $true
        Assert = {
            param($state)
            $ownedWeaponmasteryWeapons = @($state.Character.WeaponmasteryWeapons)
            Assert-LWBookSevenStartupSmoke -Condition ([int]$state.Character.MagnakaiRank -eq 4) -Message 'Book 7 carry-forward did not raise Magnakai rank to 4.'
            Assert-LWBookSevenStartupSmoke -Condition (@($state.Character.MagnakaiDisciplines).Count -eq 4) -Message 'Book 7 carry-forward did not add the fourth Magnakai discipline.'
            Assert-LWBookSevenStartupSmoke -Condition ($ownedWeaponmasteryWeapons.Count -eq 4) -Message 'Book 7 carry-forward did not finish with four Weaponmastery picks.'
            Assert-LWBookSevenStartupSmoke -Condition (($ownedWeaponmasteryWeapons | Select-Object -Unique).Count -eq 4) -Message 'Book 7 carry-forward duplicated a Weaponmastery weapon instead of adding a new one.'
            Assert-LWBookSevenStartupSmoke -Condition ($ownedWeaponmasteryWeapons -contains 'Sword') -Message 'Book 7 carry-forward lost the existing Sword mastery.'
            Assert-LWBookSevenStartupSmoke -Condition ($ownedWeaponmasteryWeapons -contains 'Bow') -Message 'Book 7 carry-forward lost the existing Bow mastery.'
            Assert-LWBookSevenStartupSmoke -Condition ($ownedWeaponmasteryWeapons -contains 'Warhammer') -Message 'Book 7 carry-forward lost the existing Warhammer mastery.'
        }
    }
    @{
        Name = 'Book 7 startup gold is capped at 50'
        Ints = @(0)
        BuildState = { New-LWBookSevenStartupSmokeState -Gold 45 }
        Assert = {
            param($state)
            Assert-LWBookSevenStartupSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 50) -Message 'Book 7 startup did not cap Gold Crowns at 50.'
        }
    }
)

$results = @()

foreach ($test in $tests) {
    $state = & $test.BuildState
    Set-LWHostGameState -State $state | Out-Null
    $ints = if ($test.ContainsKey('Ints')) { @($test.Ints) } else { @() }
    $texts = if ($test.ContainsKey('Texts')) { @($test.Texts) } else { @() }
    $yesNo = if ($test.ContainsKey('YesNo')) { @($test.YesNo) } else { @() }
    Set-LWBookSevenStartupSmokeQueues -Ints $ints -Texts $texts -YesNo $yesNo

    try {
        Apply-LWBookSevenStartingEquipment -CarryExistingGear:([bool]($test.ContainsKey('CarryExistingGear') -and $test.CarryExistingGear))
        & $test.Assert $state
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'ok'; Error = '' }
    }
    catch {
        $results += [pscustomobject]@{ Name = [string]$test.Name; Status = 'fail'; Error = $_.Exception.Message }
    }
}

$failures = @($results | Where-Object { $_.Status -ne 'ok' })
Write-Host ("Book 7 startup tests: {0}" -f $results.Count)
Write-Host ("Failures: {0}" -f $failures.Count)

foreach ($result in $results) {
    if ($result.Status -eq 'ok') {
        Write-Host ("[PASS] {0}" -f $result.Name)
    }
    else {
        Write-Host ("[FAIL] {0} -- {1}" -f $result.Name, $result.Error)
    }
}

if ($failures.Count -gt 0) {
    exit 1
}
