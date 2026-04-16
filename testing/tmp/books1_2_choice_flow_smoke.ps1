$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

. "$repoRoot\lonewolf.ps1"

Initialize-LWData

$script:IntQueue = [System.Collections.Generic.Queue[int]]::new()
$script:TextQueue = [System.Collections.Generic.Queue[string]]::new()
$script:YesNoQueue = [System.Collections.Generic.Queue[bool]]::new()

function Set-LWChoiceSmokeInputQueues {
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

function global:Read-LWYesNo {
    param([string]$Prompt, [bool]$Default = $false, [switch]$NoRefresh)
    if ($script:YesNoQueue.Count -gt 0) {
        return [bool]$script:YesNoQueue.Dequeue()
    }
    return [bool]$Default
}

function global:Read-LWInlineYesNo {
    param([string]$Prompt, [bool]$Default = $false)
    if ($script:YesNoQueue.Count -gt 0) {
        return [bool]$script:YesNoQueue.Dequeue()
    }
    return [bool]$Default
}

function global:Read-LWInt {
    param(
        [string]$Prompt,
        [int]$Default = 0,
        [int]$Min = [int]::MinValue,
        [int]$Max = [int]::MaxValue,
        [switch]$NoRefresh
    )

    if ($script:IntQueue.Count -gt 0) {
        return [int]$script:IntQueue.Dequeue()
    }
    if ($PSBoundParameters.ContainsKey('Default')) {
        return [int]$Default
    }
    if ($Min -ne [int]::MinValue) {
        return [int]$Min
    }
    return 0
}

function global:Read-LWText {
    param(
        [string]$Prompt,
        [string]$Default = '',
        [switch]$NoRefresh
    )

    if ($script:TextQueue.Count -gt 0) {
        return [string]$script:TextQueue.Dequeue()
    }
    if ($PSBoundParameters.ContainsKey('Default')) {
        return [string]$Default
    }
    return ''
}

function global:Read-Host {
    param([string]$Prompt)
    if ($script:TextQueue.Count -gt 0) {
        return [string]$script:TextQueue.Dequeue()
    }
    return ''
}

function global:Write-LWInfo { param([string]$Message) }
function global:Write-LWWarn { param([string]$Message) }
function global:Write-LWError { param([string]$Message) }
function global:Add-LWNotification { param([string]$Message, [string]$Level) }
function global:Request-LWRender { param() }
function global:Refresh-LWScreen { param() }
function global:Clear-LWScreenHost { param([switch]$PreserveNotifications) }

function New-LWChoiceSmokeState {
    param(
        [Parameter(Mandatory = $true)][int]$BookNumber,
        [int]$Gold = 20,
        [bool]$HasBackpack = $true
    )

    $state = New-LWDefaultState
    $state.Character.Name = 'Choice Smoke'
    $state.Character.BookNumber = $BookNumber
    $state.Character.CombatSkillBase = 20
    $state.Character.EnduranceCurrent = 25
    $state.Character.EnduranceMax = 25
    $state.CurrentSection = 1
    $state.RuleSet = 'Kai'
    $state.Settings.SavePath = ''
    $state.Settings.AutoSave = $false
    $state.Run = (New-LWRunState -Difficulty 'Normal' -Permadeath:$false)
    $state.Inventory.Weapons = @()
    $state.Inventory.BackpackItems = @()
    $state.Inventory.SpecialItems = @()
    $state.Inventory.GoldCrowns = [int]$Gold
    $state.Character.Disciplines = @('Camouflage', 'Hunting', 'Sixth Sense', 'Tracking', 'Healing')
    $state.Character.WeaponskillWeapon = 'Sword'

    Set-LWHostGameState -State $state | Out-Null
    Set-LWBackpackState -HasBackpack:$HasBackpack
    [void](Ensure-LWCurrentBookStats -State $state)
    return $state
}

function Assert-LWChoiceSmoke {
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
        Name   = 'Book1 Section 12 fare'
        Book   = 1
        Section = 12
        Gold   = 15
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book1Section12FarePaid') -Message 'Fare flag was not set.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 5) -Message 'Gold was not reduced by 10.'
        }
    }
    @{
        Name   = 'Book1 Section 20 loot'
        Book   = 1
        Section = 20
        Gold   = 5
        HasBackpack = $false
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStateHasBackpack -State $state) -Message 'Backpack was not restored.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 2) -Message 'Meals were not added.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Dagger was not added.'
        }
    }
    @{
        Name   = 'Book1 Section 33 gold'
        Book   = 1
        Section = 33
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Section 33 did not add 3 Gold Crowns.'
        }
    }
    @{
        Name   = 'Book1 Section 46 crossing'
        Book   = 1
        Section = 46
        Gold   = 5
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book1Section46FarePaid') -Message 'Lake-crossing fare flag was not set.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Lake-crossing fare was not deducted.'
        }
    }
    @{
        Name   = 'Book1 Section 62 loot'
        Book   = 1
        Section = 62
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 28) -Message 'Section 62 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 3) -Message 'Section 62 meals missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 62 sword missing.'
        }
    }
    @{
        Name   = 'Book1 Section 94 gold'
        Book   = 1
        Section = 94
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 16) -Message 'Section 94 did not add 16 Gold Crowns.'
        }
    }
    @{
        Name   = 'Book1 Section 164 alether'
        Book   = 1
        Section = 164
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Alether' }).Count -eq 1) -Message 'Potion of Alether was not added.'
        }
    }
    @{
        Name   = 'Book1 Section 184 loot'
        Book   = 1
        Section = 184
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 40) -Message 'Section 184 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 184 sword missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 4) -Message 'Section 184 meals missing.'
        }
    }
    @{
        Name   = 'Book1 Section 193 scroll'
        Book   = 1
        Section = 193
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Scroll' }).Count -eq 1) -Message 'Section 193 scroll missing.'
        }
    }
    @{
        Name   = 'Book1 Section 197 loot'
        Book   = 1
        Section = 197
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 6) -Message 'Section 197 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Short Sword' }).Count -eq 1) -Message 'Section 197 Short Sword missing.'
        }
    }
    @{
        Name   = 'Book1 Section 199 meal'
        Book   = 1
        Section = 199
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 1) -Message 'Section 199 meal missing.'
        }
    }
    @{
        Name   = 'Book1 Section 263 gold'
        Book   = 1
        Section = 263
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Section 263 gold missing.'
        }
    }
    @{
        Name   = 'Book1 Section 269 reward'
        Book   = 1
        Section = 269
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 10) -Message 'Section 269 reward missing.'
        }
    }
    @{
        Name   = 'Book1 Section 291 exclusive weapon choice'
        Book   = 1
        Section = 291
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 6) -Message 'Section 291 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 291 did not grant the chosen weapon.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Spear' }).Count -eq 0) -Message 'Section 291 granted both exclusive weapons.'
        }
    }
    @{
        Name   = 'Book1 Section 319 loot'
        Book   = 1
        Section = 319
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 20) -Message 'Section 319 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 319 dagger missing.'
        }
    }
    @{
        Name   = 'Book2 Section 55 Broadsword +1'
        Book   = 2
        Section = 55
        Gold   = 20
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 8) -Message 'Section 55 purchase cost was not deducted.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Broadsword +1' }).Count -eq 1) -Message 'Broadsword +1 was not added.'
        }
    }
    @{
        Name   = 'Book2 Section 15 choose one gift'
        Book   = 2
        Section = 15
        Gold   = 0
        Texts  = @('7')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 12) -Message 'Section 15 gold gift missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons).Count -eq 0) -Message 'Section 15 should only grant the chosen gift.'
        }
    }
    @{
        Name   = 'Book2 Section 76 loot'
        Book   = 2
        Section = 76
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 2) -Message 'Section 76 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 76 dagger missing.'
        }
    }
    @{
        Name   = 'Book2 Section 79 Sommerswerd'
        Book   = 2
        Section = 79
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Sommerswerd' }).Count -eq 1) -Message 'Section 79 Sommerswerd missing.'
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2SommerswerdClaimed') -Message 'Section 79 Sommerswerd flag missing.'
        }
    }
    @{
        Name   = 'Book2 Section 58 lost Samor wager'
        Book   = 2
        Section = 58
        Gold   = 20
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 10) -Message 'Section 58 did not deduct the lost wager.'
        }
    }
    @{
        Name   = 'Book2 Section 72 ale and room'
        Book   = 2
        Section = 72
        Gold   = 10
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section072AlePaid') -Message 'Section 72 ale-payment flag missing.'
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section072RoomPaid') -Message 'Section 72 room-payment flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 7) -Message 'Section 72 did not deduct ale and room costs.'
        }
    }
    @{
        Name   = 'Book2 Section 75 White Pass fee'
        Book   = 2
        Section = 75
        Gold   = 15
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section075PassPaid') -Message 'Section 75 pass-payment flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 5) -Message 'Section 75 pass fee was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 86 boat loot'
        Book   = 2
        Section = 86
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Mace' }).Count -eq 1) -Message 'Section 86 mace missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Section 86 gold missing.'
        }
    }
    @{
        Name   = 'Book2 Section 91 merchant two picks'
        Book   = 2
        Section = 91
        Gold   = 0
        HasBackpack = $false
        Texts  = @('4', '3')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStateHasBackpack -State $state) -Message 'Section 91 backpack was not restored.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 2) -Message 'Section 91 meals missing.'
            Assert-LWChoiceSmoke -Condition ((@($state.Inventory.Weapons).Count + @($state.Inventory.BackpackItems).Count + @($state.Inventory.SpecialItems).Count) -eq 2) -Message 'Section 91 exceeded the two-item choice limit.'
        }
    }
    @{
        Name   = 'Book2 Section 117 inside fare'
        Book   = 2
        Section = 117
        Gold   = 10
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section117InsidePaid') -Message 'Section 117 inside-fare flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 7) -Message 'Section 117 inside fare was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 124 loot'
        Book   = 2
        Section = 124
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 42) -Message 'Section 124 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Short Sword' }).Count -eq 1) -Message 'Section 124 Short Sword missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 124 Dagger missing.'
        }
    }
    @{
        Name   = 'Book2 Section 132 spear'
        Book   = 2
        Section = 132
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Spear' }).Count -eq 1) -Message 'Section 132 spear missing.'
        }
    }
    @{
        Name   = 'Book2 Section 136 coach fare'
        Book   = 2
        Section = 136
        Gold   = 20
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section136FarePaid') -Message 'Section 136 fare flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 0) -Message 'Section 136 fare was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 144 meals'
        Book   = 2
        Section = 144
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 2) -Message 'Section 144 meals were not added.'
        }
    }
    @{
        Name   = 'Book2 Section 181 shop'
        Book   = 2
        Section = 181
        Gold   = 10
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 6) -Message 'Section 181 sword cost was not deducted.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 181 sword missing.'
        }
    }
    @{
        Name   = 'Book2 Section 195 toll'
        Book   = 2
        Section = 195
        Gold   = 5
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section195TollPaid') -Message 'Section 195 toll flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 4) -Message 'Section 195 toll was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 187 loot'
        Book   = 2
        Section = 187
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 6) -Message 'Section 187 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Spear' }).Count -eq 1) -Message 'Section 187 spear missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 187 sword missing.'
        }
    }
    @{
        Name   = 'Book2 Section 217 directions'
        Book   = 2
        Section = 217
        Gold   = 10
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section217DirectionsPaid') -Message 'Section 217 directions flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 9) -Message 'Section 217 directions cost was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 220 gold'
        Book   = 2
        Section = 220
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 23) -Message 'Section 220 gold missing.'
        }
    }
    @{
        Name   = 'Book2 Section 226 room'
        Book   = 2
        Section = 226
        Gold   = 3
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section226RoomPaid') -Message 'Section 226 room flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 1) -Message 'Section 226 room cost was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 231 loot'
        Book   = 2
        Section = 231
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 5) -Message 'Section 231 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 231 dagger missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Seal of Hammerdal' }).Count -eq 1) -Message 'Section 231 seal missing.'
        }
    }
    @{
        Name   = 'Book2 Section 233 roof fare'
        Book   = 2
        Section = 233
        Gold   = 10
        Ints   = @(2)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section233RoofPaid') -Message 'Section 233 roof-fare flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 9) -Message 'Section 233 roof fare was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 260 sword gift'
        Book   = 2
        Section = 260
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 260 sword gift missing.'
        }
    }
    @{
        Name   = 'Book2 Section 266 weaponsmith'
        Book   = 2
        Section = 266
        Gold   = 10
        Texts  = @('8')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Axe' }).Count -eq 1) -Message 'Section 266 axe missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 7) -Message 'Section 266 axe cost was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 274 loot'
        Book   = 2
        Section = 274
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 6) -Message 'Section 274 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 274 sword missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Mace' }).Count -eq 1) -Message 'Section 274 mace missing.'
        }
    }
    @{
        Name   = 'Book2 Section 283 trading post'
        Book   = 2
        Section = 283
        Gold   = 10
        Texts  = @('6')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Gold Ring' }).Count -eq 1) -Message 'Section 283 gold ring missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 2) -Message 'Section 283 gold ring cost was not deducted.'
        }
    }
    @{
        Name   = 'Book2 Section 301 loot'
        Book   = 2
        Section = 301
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Section 301 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 301 dagger missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Short Sword' }).Count -eq 1) -Message 'Section 301 Short Sword missing.'
        }
    }
    @{
        Name   = 'Book2 Section 305 winnings'
        Book   = 2
        Section = 305
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 5) -Message 'Section 305 winnings missing.'
        }
    }
    @{
        Name   = 'Book2 Section 329 winnings'
        Book   = 2
        Section = 329
        Gold   = 0
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 10) -Message 'Section 329 winnings missing.'
        }
    }
    @{
        Name   = 'Book2 Section 331 guard search'
        Book   = 2
        Section = 331
        Gold   = 0
        Texts  = @('1', '1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 331 sword missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 331 dagger missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Section 331 gold missing.'
        }
    }
    @{
        Name   = 'Book2 Section 342 bed'
        Book   = 2
        Section = 342
        Gold   = 10
        Ints   = @(2)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book2Section342RoomPaid') -Message 'Section 342 room-payment flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 8) -Message 'Section 342 room cost was not deducted.'
        }
    }
    @{
        Name   = 'Book3 Section 233 distilled laumspur'
        Book   = 3
        Section = 233
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Distilled Laumspur' }).Count -eq 1) -Message 'Section 233 Distilled Laumspur was not added.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq 25) -Message 'Section 233 should not change Endurance on entry.'
        }
    }
    @{
        Name   = 'Book3 Section 16 backpack loss'
        Book   = 3
        Section = 16
        Gold   = 0
        Arrange = {
            param($state)
            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Meal')
            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Torch')
            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Rope')
        }
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems).Count -eq 1) -Message 'Section 16 did not destroy two Backpack Items.'
        }
    }
    @{
        Name   = 'Book3 Section 25 triangle'
        Book   = 3
        Section = 25
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Blue Stone Triangle' }).Count -eq 1) -Message 'Section 25 Blue Stone Triangle missing.'
        }
    }
    @{
        Name   = 'Book3 Section 26 bone weapons'
        Book   = 3
        Section = 26
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Bone Sword' }).Count -eq 1) -Message 'Section 26 Bone Sword missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 26 Dagger missing.'
        }
    }
    @{
        Name   = 'Book3 Section 59 triangle'
        Book   = 3
        Section = 59
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Blue Stone Triangle' }).Count -eq 1) -Message 'Section 59 Blue Stone Triangle missing.'
        }
    }
    @{
        Name   = 'Book3 Section 156 gallowbrush'
        Book   = 3
        Section = 156
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Potion of Gallowbrush' }).Count -eq 1) -Message 'Section 156 Potion of Gallowbrush missing.'
        }
    }
    @{
        Name   = 'Book3 Section 157 distilled laumspur use'
        Book   = 3
        Section = 157
        Gold   = 0
        Arrange = {
            param($state)
            $state.Character.EnduranceCurrent = 10
            [void](TryAdd-LWInventoryItemSilently -Type 'backpack' -Name 'Distilled Laumspur')
        }
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Distilled Laumspur' }).Count -eq 0) -Message 'Section 157 Distilled Laumspur was not removed.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Character.EnduranceCurrent -eq 16) -Message 'Section 157 did not restore 6 ENDURANCE.'
        }
    }
    @{
        Name   = 'Book3 Section 177 graveweed'
        Book   = 3
        Section = 177
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Vial of Graveweed' }).Count -eq 1) -Message 'Section 177 Vial of Graveweed missing.'
        }
    }
    @{
        Name   = 'Book3 Section 210 bone sword'
        Book   = 3
        Section = 210
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Bone Sword' }).Count -eq 1) -Message 'Section 210 Bone Sword missing.'
        }
    }
    @{
        Name   = 'Book3 Section 218 diamond'
        Book   = 3
        Section = 218
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Diamond' }).Count -eq 1) -Message 'Section 218 Diamond missing.'
        }
    }
    @{
        Name   = 'Book3 Section 311 alether'
        Book   = 3
        Section = 311
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Potion of Alether' }).Count -eq 1) -Message 'Section 311 Potion of Alether missing.'
        }
    }
    @{
        Name   = 'Book3 Section 316 gold bracelet'
        Book   = 3
        Section = 316
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Gold Bracelet' }).Count -eq 1) -Message 'Section 316 Gold Bracelet missing.'
        }
    }
    @{
        Name   = 'Book3 Section 334 glowing crystal'
        Book   = 3
        Section = 334
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Glowing Crystal' }).Count -eq 1) -Message 'Section 334 Glowing Crystal missing.'
        }
    }
    @{
        Name   = 'Book4 Section 102 strangers loot'
        Book   = 4
        Section = 102
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 12) -Message 'Section 102 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 2) -Message 'Section 102 meals missing.'
        }
    }
    @{
        Name   = 'Book4 Section 261 corpse loot'
        Book   = 4
        Section = 261
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 8) -Message 'Section 261 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Meal' }).Count -eq 1) -Message 'Section 261 meal missing.'
        }
    }
    @{
        Name   = 'Book5 Section 111 armourer'
        Book   = 5
        Section = 111
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 3) -Message 'Section 111 gold missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Copper Key' }).Count -eq 1) -Message 'Section 111 Copper Key missing.'
        }
    }
    @{
        Name   = 'Book5 Section 56 Jakan case'
        Book   = 5
        Section = 56
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Jakan Bow' }).Count -eq 1) -Message 'Section 56 Jakan Bow missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Arrow' }).Count -eq 1) -Message 'Section 56 Arrow missing.'
        }
    }
    @{
        Name   = 'Book5 Section 248 waistcoat payment'
        Book   = 5
        Section = 248
        Gold   = 20
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book5Section248WaistcoatPaid') -Message 'Section 248 payment flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 15) -Message 'Section 248 cost was not deducted.'
        }
    }
    @{
        Name   = 'Book5 Section 265 begging bowl payment'
        Book   = 5
        Section = 265
        Gold   = 20
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book5Section265GoldPaid') -Message 'Section 265 payment flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 19) -Message 'Section 265 cost was not deducted.'
        }
    }
    @{
        Name   = 'Book5 Section 276 Soushilla payment'
        Book   = 5
        Section = 276
        Gold   = 20
        Ints   = @(1)
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (Test-LWStoryAchievementFlag -Name 'Book5Section276GoldPaid') -Message 'Section 276 payment flag missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 15) -Message 'Section 276 cost was not deducted.'
        }
    }
    @{
        Name   = 'Book5 Section 290 cube'
        Book   = 5
        Section = 290
        Gold   = 0
        Texts  = @('1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Black Crystal Cube' }).Count -eq 1) -Message 'Section 290 Black Crystal Cube missing.'
        }
    }
    @{
        Name   = 'Book5 Section 310 guardroom'
        Book   = 5
        Section = 310
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Copper Key' }).Count -eq 1) -Message 'Section 310 Copper Key missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Canteen of Water' }).Count -eq 1) -Message 'Section 310 Canteen of Water missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Broadsword' }).Count -eq 1) -Message 'Section 310 Broadsword missing.'
        }
    }
    @{
        Name   = 'Book5 Section 341 guardroom'
        Book   = 5
        Section = 341
        Gold   = 0
        Texts  = @('1', '1')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.SpecialItems | Where-Object { $_ -eq 'Copper Key' }).Count -eq 1) -Message 'Section 341 Copper Key missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.BackpackItems | Where-Object { $_ -eq 'Canteen of Water' }).Count -eq 1) -Message 'Section 341 Canteen of Water missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Broadsword' }).Count -eq 1) -Message 'Section 341 Broadsword missing.'
        }
    }
    @{
        Name   = 'Book5 Section 388 weapon market'
        Book   = 5
        Section = 388
        Gold   = 20
        Texts  = @('1', '1', '0')
        Assert = {
            param($state)
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Sword' }).Count -eq 1) -Message 'Section 388 Sword missing.'
            Assert-LWChoiceSmoke -Condition (@($state.Inventory.Weapons | Where-Object { $_ -eq 'Dagger' }).Count -eq 1) -Message 'Section 388 Dagger missing.'
            Assert-LWChoiceSmoke -Condition ([int]$state.Inventory.GoldCrowns -eq 12) -Message 'Section 388 shop costs were not deducted correctly.'
        }
    }
)

$results = @()

foreach ($test in $tests) {
    $state = New-LWChoiceSmokeState -BookNumber ([int]$test.Book) -Gold ([int]$test.Gold) -HasBackpack $(if ($test.ContainsKey('HasBackpack')) { [bool]$test.HasBackpack } else { $true })
    $state.CurrentSection = [int]$test.Section
    Set-LWHostGameState -State $state | Out-Null
    if ($test.ContainsKey('Arrange') -and $null -ne $test.Arrange) {
        & $test.Arrange $state
    }
    Set-LWChoiceSmokeInputQueues -Ints $(if ($test.ContainsKey('Ints')) { [int[]]$test.Ints } else { @() }) -Texts $(if ($test.ContainsKey('Texts')) { [string[]]$test.Texts } else { @() }) -YesNo $(if ($test.ContainsKey('YesNo')) { [bool[]]$test.YesNo } else { @() })

    try {
        Invoke-LWRuleSetSectionEntryRules -State $state
        & $test.Assert $state
        $results += [pscustomobject]@{
            Name   = [string]$test.Name
            Book   = [int]$test.Book
            Section = [int]$test.Section
            Status = 'ok'
            Error  = ''
        }
    }
    catch {
        $results += [pscustomobject]@{
            Name   = [string]$test.Name
            Book   = [int]$test.Book
            Section = [int]$test.Section
            Status = 'fail'
            Error  = $_.Exception.Message
        }
    }
}

$failures = @($results | Where-Object { $_.Status -ne 'ok' })
Write-Host ("Choice flow tests: {0}" -f $results.Count)
Write-Host ("Failures: {0}" -f $failures.Count)

foreach ($result in $results) {
    if ($result.Status -eq 'ok') {
        Write-Host ("[PASS] Book {0} Section {1}: {2}" -f $result.Book, $result.Section, $result.Name)
    }
    else {
        Write-Host ("[FAIL] Book {0} Section {1}: {2} -- {3}" -f $result.Book, $result.Section, $result.Name, $result.Error)
    }
}

if ($failures.Count -gt 0) {
    exit 1
}
