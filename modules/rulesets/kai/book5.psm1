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

function Get-LWKaiBookFiveSectionRandomNumberContext {
    param([object]$State = $null)

    if ($null -ne $State) { $script:GameState = $State; if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null } }

        if ($null -eq $State -or [int]$State.Character.BookNumber -ne 5) {
            return $null
        }

        $section = [int]$State.CurrentSection
        $disciplineCount = @($State.Character.Disciplines).Count
        $modifier = 0
        $modifierNotes = @()
        $description = $null
        $zeroCountsAsTen = $false
        $bypassed = $false
        $bypassReason = $null

        switch ($section) {
            11 {
                $description = 'Stealth-around-the-pillars check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Camouflage') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                    $modifier -= 2
                    $modifierNotes += 'Camouflage or Hunting'
                }
            }
            15 {
                $description = 'Hide-in-the-tunnel check.'
                if ($disciplineCount -ge 7) {
                    $modifier -= 1
                    $modifierNotes += 'Kai rank Guardian+'
                }
            }
            23 {
                $description = 'Steam-shaft climb check.'
                if (Test-LWBookFiveLimbdeathActive) {
                    $modifier -= 3
                    $modifierNotes += 'Limbdeath'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            48 {
                $description = 'Kai lock-opening check.'
                if ($disciplineCount -ge 7) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Guardian+'
                }
            }
            49 {
                $description = 'Courier ambush check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 1
                    $modifierNotes += 'Hunting'
                }
                if ($disciplineCount -ge 9) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Savant+'
                }
            }
            56 {
                $description = 'Harbour bow-shot check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                    $modifier += 2
                    $modifierNotes += 'Weaponskill'
                }
            }
            118 {
                $description = 'Blowpipe dodge check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
                if ($disciplineCount -ge 8) {
                    $modifier += 1
                    $modifierNotes += 'Kai rank Warmarn+'
                }
            }
            125 {
                $description = 'Leap-from-the-oars balance check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            127 {
                $description = 'Smash-the-door check. Add 10 and compare against Combat Skill.'
            }
            146 {
                $description = 'Forge stealth check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Camouflage') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                    $modifier -= 2
                    $modifierNotes += 'Camouflage or Hunting'
                }
            }
            152 {
                $description = 'Outer-ledge balance check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
                if ($disciplineCount -ge 9) {
                    $modifier += 2
                    $modifierNotes += 'Kai rank Savant+'
                }
            }
            162 {
                $description = 'Steamspider climb damage roll. 0 counts as 10 if you cannot fight.'
                $zeroCountsAsTen = $true
            }
            180 {
                $description = 'Dagger-throw escape check.'
                if ((Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') -or (Test-LWStateHasDiscipline -State $State -Name 'Hunting')) {
                    $modifier += 3
                    $modifierNotes += 'Sixth Sense or Hunting'
                }
            }
            198 {
                $description = 'Maouk dart dodge check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 3
                    $modifierNotes += 'Hunting'
                }
            }
            205 {
                $description = 'Freefall landing check.'
            }
            222 {
                $description = 'Vordak detection check.'
            }
            224 {
                if (Test-LWStateHasDiscipline -State $State -Name 'Animal Kinship') {
                    $bypassed = $true
                    $bypassReason = 'Animal Kinship bypasses this Itikar random-number check.'
                }
                elseif (Test-LWStateHasInventoryItem -State $State -Names (Get-LWOnyxMedallionItemNames) -Type 'special') {
                    $bypassed = $true
                    $bypassReason = 'The Onyx Medallion bypasses this Itikar random-number check.'
                }
                else {
                    $description = 'Itikar approach check.'
                    if ($disciplineCount -ge 6) {
                        $modifier += 2
                        $modifierNotes += 'Kai rank Aspirant+'
                    }
                }
            }
            229 {
                $description = 'Black Crystal Cube backlash check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense') {
                    $modifier += 3
                    $modifierNotes += 'Sixth Sense'
                }
            }
            239 {
                if (Test-LWStateHasInventoryItem -State $State -Names (Get-LWGraveweedItemNames) -Type 'backpack') {
                    $bypassed = $true
                    $bypassReason = 'A Tincture of Graveweed bypasses this check.'
                }
                else {
                    $description = 'Hidden-door discovery check.'
                    if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Tracking') -or (Test-LWStateHasDiscipline -State $State -Name 'Camouflage')) {
                        $modifier += 2
                        $modifierNotes += 'Hunting, Tracking, or Camouflage'
                    }
                    if ($disciplineCount -ge 7) {
                        $modifier += 3
                        $modifierNotes += 'Kai rank Guardian+'
                    }
                }
            }
            242 {
                $description = 'Hide-from-the-Vordak check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Camouflage') {
                    $modifier += 2
                    $modifierNotes += 'Camouflage'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Mindshield') {
                    $modifier += 3
                    $modifierNotes += 'Mindshield'
                }
            }
            247 { $description = 'Approach-to-Ikaresh check.' }
            275 { $description = 'Falling-Itikar landing check.' }
            282 {
                if (Test-LWStateHasDiscipline -State $State -Name 'Mind Over Matter') {
                    $bypassed = $true
                    $bypassReason = 'Mind Over Matter bypasses this gangplank stealth check.'
                }
                else {
                    $description = 'Gangplank stealth check.'
                    if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Camouflage')) {
                        $modifier += 2
                        $modifierNotes += 'Hunting or Camouflage'
                    }
                    if ($disciplineCount -ge 8) {
                        $modifier += 3
                        $modifierNotes += 'Kai rank Warmarn+'
                    }
                }
            }
            301 {
                $description = 'Gate-spike climb check.'
                if ($disciplineCount -ge 7) {
                    $modifier -= 2
                    $modifierNotes += 'Kai rank Guardian+'
                }
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier -= 1
                    $modifierNotes += 'Hunting'
                }
            }
            305 { $description = 'Falling-rope landing check.' }
            312 {
                if ((Test-LWStateHasDiscipline -State $State -Name 'Hunting') -or (Test-LWStateHasDiscipline -State $State -Name 'Sixth Sense')) {
                    $bypassed = $true
                    $bypassReason = 'Hunting or Sixth Sense bypasses this thrown-axe random-number check.'
                }
                else {
                    $description = 'Thrown-axe survival check.'
                }
            }
            323 { $description = 'Skyship escape check.' }
            325 {
                $description = 'Blowpipe shot check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Weaponskill') {
                    $modifier += 2
                    $modifierNotes += 'Weaponskill'
                }
            }
            336 {
                $description = 'Falling-Itikar landing check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Animal Kinship') {
                    $modifier -= 1
                    $modifierNotes += 'Animal Kinship'
                }
            }
            357 {
                $description = 'Platform fight fall check. Picking a 1 makes you fall.'
            }
            360 {
                $description = 'Twin-roll surprise check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 1
                    $modifierNotes += 'Hunting'
                }
            }
            372 {
                $description = 'Crossbow-bolt exposure check.'
                if ($disciplineCount -ge 6) {
                    $modifier += 2
                    $modifierNotes += 'Kai rank Aspirant+'
                }
            }
            381 {
                $description = 'Axe-feint reaction check.'
                if (Test-LWStateHasDiscipline -State $State -Name 'Hunting') {
                    $modifier += 2
                    $modifierNotes += 'Hunting'
                }
            }
            392 {
                $description = 'Ale-drinking balance check.'
                if ([int]$State.Character.EnduranceCurrent -lt 15) {
                    $modifier -= 2
                    $modifierNotes += 'Current END below 15'
                }
                elseif ([int]$State.Character.EnduranceCurrent -gt 25) {
                    $modifier += 2
                    $modifierNotes += 'Current END above 25'
                }
                if ($disciplineCount -ge 9) {
                    $modifier += 3
                    $modifierNotes += 'Kai rank Savant+'
                }
            }
            default { return $null }
        }

        return [pscustomobject]@{
            Section         = $section
            Description     = $description
            Modifier        = $modifier
            ModifierNotes   = @($modifierNotes)
            ZeroCountsAsTen = $zeroCountsAsTen
            Bypassed        = $bypassed
            BypassReason    = $bypassReason
        }
}

function Get-LWBookFiveSimpleSectionEffectDefinitions {
    return @{
        22  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section022EnduranceHandled'; Delta = -8; MessagePrefix = 'Section 22: apply the section ENDURANCE loss.'; FatalCause = 'Section 22 reduced your Endurance to zero.' })
        23  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section023EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 23: apply the section ENDURANCE loss.'; FatalCause = 'Section 23 reduced your Endurance to zero.' })
        34  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section034EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 34: apply the section ENDURANCE loss.'; FatalCause = 'Section 34 reduced your Endurance to zero.' })
        38  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section038EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 38: apply the section ENDURANCE loss.'; FatalCause = 'Section 38 reduced your Endurance to zero.' })
        50  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section050EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 50: apply the section ENDURANCE loss.'; FatalCause = 'Section 50 reduced your Endurance to zero.' })
        51  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section051EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 51: apply the section ENDURANCE loss.'; FatalCause = 'Section 51 reduced your Endurance to zero.' })
        72  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section072EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 72: apply the section ENDURANCE loss.'; FatalCause = 'Section 72 reduced your Endurance to zero.' })
        86  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section086EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 86: apply the section ENDURANCE loss.'; FatalCause = 'Section 86 reduced your Endurance to zero.' })
        93  = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section093EnduranceHandled'; Delta = 1; MessagePrefix = 'Section 93: apply the section ENDURANCE recovery.' })
        127 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section127EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 127: apply the section ENDURANCE loss.'; FatalCause = 'Section 127 reduced your Endurance to zero.' })
        137 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book5Section137MealHandled'; NoMealFlagName = 'Book5Section137NoMealLossApplied'; SectionLabel = 'Section 137'; Loss = 3; NoMealMessagePrefix = 'Section 137: the section meal requirement is not met.'; FatalCause = 'Hunger at section 137 reduced your Endurance to zero.' })
        162 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section162EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 162: apply the section ENDURANCE loss.'; FatalCause = 'Section 162 reduced your Endurance to zero.' })
        164 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section164EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 164: apply the section ENDURANCE loss.'; FatalCause = 'Section 164 reduced your Endurance to zero.' })
        183 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section183EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 183: apply the section ENDURANCE loss.'; FatalCause = 'Section 183 reduced your Endurance to zero.' })
        192 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section192EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 192: apply the section ENDURANCE loss.'; FatalCause = 'Section 192 reduced your Endurance to zero.' })
        200 = @([pscustomobject]@{ Type = 'instantdeath'; FlagName = 'Book5Section200DeathApplied'; Cause = 'Section 200: instant death.' })
        237 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section237EnduranceHandled'; Delta = 1; MessagePrefix = 'Section 237: apply the section ENDURANCE recovery.' })
        238 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section238EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 238: apply the section ENDURANCE loss.'; FatalCause = 'Section 238 reduced your Endurance to zero.' })
        251 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section251EnduranceHandled'; Delta = -6; MessagePrefix = 'Section 251: apply the section ENDURANCE loss.'; FatalCause = 'Section 251 reduced your Endurance to zero.' })
        264 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section264EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 264: apply the section ENDURANCE loss.'; FatalCause = 'Section 264 reduced your Endurance to zero.'; RequiresMissingDiscipline = 'Mindshield' })
        273 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section273EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 273: apply the section ENDURANCE loss.'; FatalCause = 'Section 273 reduced your Endurance to zero.' })
        278 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section278EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 278: apply the section ENDURANCE loss.'; FatalCause = 'Section 278 reduced your Endurance to zero.' })
        284 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section284EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 284: apply the section ENDURANCE loss.'; FatalCause = 'Section 284 reduced your Endurance to zero.' })
        285 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section285EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 285: apply the section ENDURANCE loss.'; FatalCause = 'Section 285 reduced your Endurance to zero.' })
        287 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section287EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 287: apply the section ENDURANCE loss.'; FatalCause = 'Section 287 reduced your Endurance to zero.' })
        297 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section297EnduranceHandled'; Delta = -4; MessagePrefix = 'Section 297: apply the section ENDURANCE loss.'; FatalCause = 'Section 297 reduced your Endurance to zero.' })
        320 = @([pscustomobject]@{ Type = 'meal'; ResolvedFlagName = 'Book5Section320MealHandled'; NoMealFlagName = 'Book5Section320NoMealLossApplied'; SectionLabel = 'Section 320'; Loss = 3; NoMealMessagePrefix = 'Section 320: the section meal requirement is not met.'; FatalCause = 'Hunger at section 320 reduced your Endurance to zero.' })
        354 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section354EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 354: apply the section ENDURANCE loss.'; FatalCause = 'Section 354 reduced your Endurance to zero.' })
        359 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section359EnduranceHandled'; Delta = 2; MessagePrefix = 'Section 359: apply the section ENDURANCE recovery.' })
        368 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section368EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 368: apply the section ENDURANCE loss.'; FatalCause = 'Section 368 reduced your Endurance to zero.' })
        369 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section369EnduranceHandled'; Delta = -6; MessagePrefix = 'Section 369: apply the section ENDURANCE loss.'; FatalCause = 'Section 369 reduced your Endurance to zero.' })
        370 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section370EnduranceHandled'; Delta = -3; MessagePrefix = 'Section 370: apply the section ENDURANCE loss.'; FatalCause = 'Section 370 reduced your Endurance to zero.' })
        371 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section371EnduranceHandled'; Delta = -4; MessagePrefix = 'Section 371: apply the section ENDURANCE loss.'; FatalCause = 'Section 371 reduced your Endurance to zero.' })
        372 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section372EnduranceHandled'; Delta = -1; MessagePrefix = 'Section 372: apply the section ENDURANCE loss.'; FatalCause = 'Section 372 reduced your Endurance to zero.' })
        379 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section379EnduranceHandled'; Delta = -6; MessagePrefix = 'Section 379: apply the section ENDURANCE loss.'; FatalCause = 'Section 379 reduced your Endurance to zero.' })
        380 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section380EnduranceHandled'; Delta = -2; MessagePrefix = 'Section 380: apply the section ENDURANCE loss.'; FatalCause = 'Section 380 reduced your Endurance to zero.' })
        385 = @([pscustomobject]@{ Type = 'end'; FlagName = 'Book5Section385EnduranceHandled'; Delta = -12; MessagePrefix = 'Section 385: apply the section ENDURANCE loss.'; FatalCause = 'Section 385 reduced your Endurance to zero.' })
    }
}

function Get-LWBookFiveSimpleCombatRuleDefinitions {
    return @{
        46  = [pscustomobject]@{ CanEvade = $false; Info = 'Book 5 section 46: this fight cannot be evaded.' }
        166 = [pscustomobject]@{ PlayerMod = -3; Info = 'Book 5 section 166: without a shield, this fight applies -3 Combat Skill.' }
        231 = [pscustomobject]@{ CanEvade = $false; Info = 'Book 5 section 231: this fight cannot be evaded.' }
    }
}

function Apply-LWKaiBookFiveStartingEquipment {
    param(
        [Parameter(Mandatory = $true)][object]$State,
        [switch]$CarryExistingGear
    )

    $script:GameState = $State

    if (Get-Command -Name 'Set-LWHostGameState' -ErrorAction SilentlyContinue) { Set-LWHostGameState -State $script:GameState | Out-Null }

        if (-not (Test-LWHasState) -or [int]$script:GameState.Character.BookNumber -ne 5) {
            return
        }

        if ($CarryExistingGear -and ((@($script:GameState.Inventory.SpecialItems).Count -gt 0) -or (@($script:GameState.Storage.SafekeepingSpecialItems).Count -gt 0))) {
            Invoke-LWBookTransitionSafekeepingPrompt -BookNumber 5
        }

        if (-not (Test-LWStateHasInventoryItem -State $script:GameState -Names (Get-LWMapOfVassagoniaItemNames) -Type 'special')) {
            if (TryAdd-LWInventoryItemSilently -Type 'special' -Name 'Map of Vassagonia') {
                Write-LWInfo 'Book 5 starting Special Item added: Map of Vassagonia.'
            }
            else {
                Write-LWWarn 'No room to add the Book 5 map automatically. Make room and add it manually if needed.'
            }
        }

        Restore-LWBackpackState

        $startingGoldRoll = Get-LWRandomDigit
        $goldGain = 10 + [int]$startingGoldRoll
        $oldGold = [int]$script:GameState.Inventory.GoldCrowns
        $newGold = [Math]::Min(50, ($oldGold + $goldGain))
        $script:GameState.Inventory.GoldCrowns = $newGold

        Write-LWInfo ("Book 5 starting gold roll: {0} -> +{1} Gold Crowns." -f $startingGoldRoll, $goldGain)
        if ($newGold -ne ($oldGold + $goldGain)) {
            Write-LWWarn 'Gold Crowns are capped at 50. Excess Book 5 starting gold is lost.'
        }

        Write-LWInfo $(if ($CarryExistingGear) { 'Choose up to four Book 5 starting items now. You may exchange carried weapons if needed.' } else { 'Choose up to four Book 5 starting items now.' })

        $selectedIds = @()
        while ($selectedIds.Count -lt 4) {
            $availableChoices = @(Get-LWBookFiveStartingChoiceDefinitions | Where-Object { $selectedIds -notcontains [string]$_.Id })
            if ($availableChoices.Count -eq 0) {
                break
            }

            Write-LWPanelHeader -Title 'Book 5 Starting Gear' -AccentColor 'DarkYellow'
            Write-LWKeyValue -Label 'Choices Made' -Value ("{0}/4" -f $selectedIds.Count) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Weapons' -Value ("{0}/2" -f @($script:GameState.Inventory.Weapons).Count) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Backpack' -Value $(if (Test-LWStateHasBackpack -State $script:GameState) { "{0}/8 used" -f (Get-LWInventoryUsedCapacity -Type 'backpack' -Items @(Get-LWInventoryItems -Type 'backpack')) } else { 'lost' }) -ValueColor 'Gray'
            Write-LWKeyValue -Label 'Special Items' -Value ("{0}/12" -f @($script:GameState.Inventory.SpecialItems).Count) -ValueColor 'Gray'
            Write-Host ''
            for ($i = 0; $i -lt $availableChoices.Count; $i++) {
                Write-LWBulletItem -Text ("{0}. {1}" -f ($i + 1), (Format-LWBookFourStartingChoiceLine -Choice $availableChoices[$i])) -TextColor 'Gray' -BulletColor 'Yellow'
            }
            $manageIndex = $availableChoices.Count + 1
            Write-LWBulletItem -Text ("{0}. Review inventory / make room" -f $manageIndex) -TextColor 'Gray' -BulletColor 'Yellow'
            Write-LWBulletItem -Text '0. Done choosing' -TextColor 'DarkGray' -BulletColor 'Yellow'

            $choiceIndex = Read-LWInt -Prompt ("Book 5 choice #{0}" -f ($selectedIds.Count + 1)) -Default 0 -Min 0 -Max $manageIndex -NoRefresh
            if ($choiceIndex -eq 0) {
                break
            }
            if ($choiceIndex -eq $manageIndex) {
                Invoke-LWBookFourStartingInventoryManagement
                continue
            }

            $choice = $availableChoices[$choiceIndex - 1]
            $granted = Grant-LWBookFiveStartingChoice -Choice $choice
            if ($granted) {
                $selectedIds += [string]$choice.Id
            }
            elseif (Read-LWYesNo -Prompt 'Review inventory and make room now?' -Default $true) {
                Invoke-LWBookFourStartingInventoryManagement
            }
        }
}

function Get-LWBookFiveStartingChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'dagger'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'laumspur'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur' },
        [pscustomobject]@{ Id = 'sword'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'spear'; DisplayName = 'Spear'; Type = 'weapon'; Name = 'Spear'; Quantity = 1; Description = 'Spear' },
        [pscustomobject]@{ Id = 'special_rations'; DisplayName = '2 Special Rations'; Type = 'backpack'; Name = 'Special Rations'; Quantity = 2; Description = '2 Special Rations' },
        [pscustomobject]@{ Id = 'mace'; DisplayName = 'Mace'; Type = 'weapon'; Name = 'Mace'; Quantity = 1; Description = 'Mace' },
        [pscustomobject]@{ Id = 'shield'; DisplayName = 'Shield'; Type = 'special'; Name = 'Shield'; Quantity = 1; Description = 'Shield' }
    )
}

function Grant-LWBookFiveStartingChoice {
    param([Parameter(Mandatory = $true)][object]$Choice)

    if ($null -eq $Choice) {
        return $false
    }

    if ([string]$Choice.Type -eq 'weapon') {
        return (Add-LWWeaponWithOptionalReplace -Name ([string]$Choice.Name) -PromptLabel ([string]$Choice.DisplayName))
    }

    if (TryAdd-LWInventoryItemSilently -Type ([string]$Choice.Type) -Name ([string]$Choice.Name) -Quantity ([int]$Choice.Quantity)) {
        Write-LWInfo ("Book 5 starting item added: {0}." -f [string]$Choice.Description)
        return $true
    }

    Write-LWWarn ("Could not add the Book 5 starting item '{0}' automatically. Make room and add it manually if you are keeping it." -f [string]$Choice.DisplayName)
    return $false
}

function Test-LWBookFiveBloodPoisoningActive {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    return ($null -ne $State -and $null -ne $State.Conditions -and [bool]$State.Conditions.BookFiveBloodPoisoning)
}

function Test-LWBookFiveLimbdeathActive {
    param([object]$State = $script:GameState)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    return ($null -ne $State -and $null -ne $State.Conditions -and [bool]$State.Conditions.BookFiveLimbdeath)
}

function Invoke-LWBookFiveLoseBackpackItems {
    param(
        [int]$Count = 1,
        [string]$Reason = 'You lose Backpack gear.',
        [switch]$ExcludeMeals
    )

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState)) {
        return @()
    }

    $lostItems = @()
    $remainingToLose = [Math]::Max(0, [int]$Count)
    while ($remainingToLose -gt 0) {
        $backpackItems = @(Get-LWInventoryItems -Type 'backpack')
        if ($backpackItems.Count -le 0) {
            break
        }

        $slotMap = @(Get-LWBackpackSlotMap -Items $backpackItems | Where-Object { [bool]$_.IsPrimary })
        if ($ExcludeMeals) {
            $slotMap = @($slotMap | Where-Object { [string]$_.ItemName -cne 'Meal' })
        }

        if ($slotMap.Count -le 0) {
            if ($ExcludeMeals) {
                Write-LWInfo ("{0} No non-Meal Backpack Items remain to lose." -f $Reason)
            }
            break
        }

        Show-LWInventorySlotsSection -Type 'backpack'
        $validSlots = @($slotMap | ForEach-Object { [int]$_.Slot })
        $slot = if ($validSlots.Count -eq 1) { $validSlots[0] } else { $null }
        while ($null -eq $slot) {
            $candidate = Read-LWInt -Prompt ("Backpack slot to lose ({0})" -f ($validSlots -join ', ')) -Min ($validSlots | Measure-Object -Minimum).Minimum -Max ($validSlots | Measure-Object -Maximum).Maximum
            if ($validSlots -contains [int]$candidate) {
                $slot = [int]$candidate
            }
            else {
                Write-LWWarn ("Choose one of the eligible Backpack slots: {0}." -f ($validSlots -join ', '))
            }
        }

        $slotEntry = @($slotMap | Where-Object { [int]$_.Slot -eq $slot } | Select-Object -First 1)
        if ($slotEntry.Count -eq 0) {
            break
        }

        $itemName = [string]$slotEntry[0].ItemName
        [void](Remove-LWInventoryItemSilently -Type 'backpack' -Name $itemName -Quantity 1)
        $lostItems += $itemName
        Write-LWInfo ("{0} Lost: {1}." -f $Reason, $itemName)
        $remainingToLose--
    }

    return @($lostItems)
}

function Invoke-LWBookFiveBloodPoisoningSectionDamage {
    param([int]$Section)

    Set-LWModuleContext -Context (Get-LWModuleContext)

    if (-not (Test-LWHasState) -or -not (Test-LWBookFiveBloodPoisoningActive -State $script:GameState) -or [int]$Section -eq 63) {
        return $true
    }

    $before = [int]$script:GameState.Character.EnduranceCurrent
    $lossResolution = Resolve-LWGameplayEnduranceLoss -Loss 2 -Source 'sectiondamage'
    $appliedLoss = [int]$lossResolution.AppliedLoss
    if ($appliedLoss -gt 0) {
        $script:GameState.Character.EnduranceCurrent = [Math]::Max(0, ($before - $appliedLoss))
        Add-LWBookEnduranceDelta -Delta ($script:GameState.Character.EnduranceCurrent - $before)
    }

    $message = 'Book 5 blood poisoning weakens you as you press on.'
    if ($appliedLoss -gt 0) {
        $message += " Lose $appliedLoss ENDURANCE point$(if ($appliedLoss -eq 1) { '' } else { 's' })."
    }
    else {
        $message += ' No ENDURANCE is lost.'
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$lossResolution.Note)) {
        $message += " $($lossResolution.Note)"
    }
    Write-LWInfo $message

    if (Invoke-LWFatalEnduranceCheck -Cause 'Blood poisoning reduced your Endurance to zero.') {
        return $false
    }

    return $true
}

function Get-LWBookFiveSection002ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'oede_herb'; FlagName = 'Book5Section002OedeClaimed'; DisplayName = 'Oede Herb'; Type = 'backpack'; Name = 'Oede Herb'; Quantity = 1; Description = 'Oede Herb' }
    )
}

function Get-LWBookFiveSection003ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section003GoldClaimed'; DisplayName = '4 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 4; Description = '4 Gold Crowns' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section003DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section003SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book5Section003AletherClaimed'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Potion of Alether'; Quantity = 1; Description = 'Potion of Alether' },
        [pscustomobject]@{ Id = 'blowpipe'; FlagName = 'Book5Section003BlowpipeClaimed'; DisplayName = 'Blowpipe'; Type = 'backpack'; Name = 'Blowpipe'; Quantity = 1; Description = 'Blowpipe' },
        [pscustomobject]@{ Id = 'sleep_dart'; FlagName = 'Book5Section003SleepDartClaimed'; DisplayName = 'Sleep Dart'; Type = 'backpack'; Name = 'Sleep Dart'; Quantity = 1; Description = 'Sleep Dart' }
    )
}

function Get-LWBookFiveSection004ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section004SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFiveSection027ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'larnuma_oil'; FlagName = 'Book5Section027LarnumaOilBought'; DisplayName = 'Larnuma Oil'; Type = 'backpack'; Name = 'Larnuma Oil'; Quantity = 1; Description = 'Larnuma Oil'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book5Section027LaumspurBought'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'rendalims_elixir'; FlagName = 'Book5Section027RendalimsElixirBought'; DisplayName = 'Rendalim''s Elixir'; Type = 'backpack'; Name = 'Rendalim''s Elixir'; Quantity = 1; Description = 'Rendalim''s Elixir'; GoldCost = 7 }
    )
}

function Get-LWBookFiveSection035ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'jewelled_mace'; FlagName = 'Book5Section035JewelledMaceClaimed'; DisplayName = 'Jewelled Mace'; Type = 'special'; Name = 'Jewelled Mace'; Quantity = 1; Description = 'Jewelled Mace' },
        [pscustomobject]@{ Id = 'copper_key'; FlagName = 'Book5Section035CopperKeyClaimed'; DisplayName = 'Copper Key'; Type = 'special'; Name = 'Copper Key'; Quantity = 1; Description = 'Copper Key' }
    )
}

function Get-LWBookFiveSection052ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section052GoldClaimed'; DisplayName = '4 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 4; Description = '4 Gold Crowns' },
        [pscustomobject]@{ Id = 'gaolers_keys'; FlagName = 'Book5Section052GaolersKeysClaimed'; DisplayName = 'Gaoler''s Keys'; Type = 'special'; Name = 'Gaoler''s Keys'; Quantity = 1; Description = 'Gaoler''s Keys' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section052DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section052SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' }
    )
}

function Get-LWBookFiveSection056ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'jakan_bow'; FlagName = 'Book5Section056JakanBowClaimed'; DisplayName = 'Jakan Bow'; Type = 'weapon'; Name = 'Jakan Bow'; Quantity = 1; Description = 'Jakan Bow' },
        [pscustomobject]@{ Id = 'arrow'; FlagName = 'Book5Section056ArrowClaimed'; DisplayName = '1 Arrow'; Type = 'backpack'; Name = 'Arrow'; Quantity = 1; Description = '1 Arrow' }
    )
}

function Get-LWBookFiveSection100ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'copper_key'; FlagName = 'Book5Section100CopperKeyClaimed'; DisplayName = 'Copper Key'; Type = 'special'; Name = 'Copper Key'; Quantity = 1; Description = 'Copper Key' },
        [pscustomobject]@{ Id = 'prism'; FlagName = 'Book5Section100PrismClaimed'; DisplayName = 'Prism'; Type = 'backpack'; Name = 'Prism'; Quantity = 1; Description = 'Prism' }
    )
}

function Get-LWBookFiveSection102ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section102SwordClaimed'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section102DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'warhammer'; FlagName = 'Book5Section102WarhammerClaimed'; DisplayName = 'Warhammer'; Type = 'weapon'; Name = 'Warhammer'; Quantity = 1; Description = 'Warhammer' },
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section102GoldClaimed'; DisplayName = '6 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 6; Description = '6 Gold Crowns' },
        [pscustomobject]@{ Id = 'gaolers_keys'; FlagName = 'Book5Section102GaolersKeysClaimed'; DisplayName = 'Gaoler''s Keys'; Type = 'special'; Name = 'Gaoler''s Keys'; Quantity = 1; Description = 'Gaoler''s Keys' }
    )
}

function Get-LWBookFiveSection111ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'copper_key'; FlagName = 'Book5Section111CopperKeyClaimed'; DisplayName = 'Copper Key'; Type = 'special'; Name = 'Copper Key'; Quantity = 1; Description = 'Copper Key' }
    )
}

function Get-LWBookFiveSection131ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'silver_comb'; FlagName = 'Book5Section131SilverCombClaimed'; DisplayName = 'Silver Comb'; Type = 'backpack'; Name = 'Silver Comb'; Quantity = 1; Description = 'Silver Comb' },
        [pscustomobject]@{ Id = 'hourglass'; FlagName = 'Book5Section131HourglassClaimed'; DisplayName = 'Hourglass'; Type = 'backpack'; Name = 'Hourglass'; Quantity = 1; Description = 'Hourglass' },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section131DaggerClaimed'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger' },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book5Section131LaumspurClaimed'; DisplayName = 'Healing Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Healing Potion of Laumspur' },
        [pscustomobject]@{ Id = 'prism'; FlagName = 'Book5Section131PrismClaimed'; DisplayName = 'Prism'; Type = 'backpack'; Name = 'Prism'; Quantity = 1; Description = 'Prism' },
        [pscustomobject]@{ Id = 'meals'; FlagName = 'Book5Section131MealsClaimed'; DisplayName = '3 Meals'; Type = 'backpack'; Name = 'Meal'; Quantity = 3; Description = '3 Meals' }
    )
}

function Get-LWBookFiveSection154ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'alether'; FlagName = 'Book5Section154AletherBought'; DisplayName = 'Potion of Alether'; Type = 'backpack'; Name = 'Potion of Alether'; Quantity = 1; Description = 'Potion of Alether'; GoldCost = 4 },
        [pscustomobject]@{ Id = 'gallowbrush'; FlagName = 'Book5Section154GallowbrushBought'; DisplayName = 'Potion of Gallowbrush'; Type = 'backpack'; Name = 'Potion of Gallowbrush'; Quantity = 1; Description = 'Potion of Gallowbrush'; GoldCost = 2 },
        [pscustomobject]@{ Id = 'laumspur'; FlagName = 'Book5Section154LaumspurBought'; DisplayName = 'Potion of Laumspur'; Type = 'backpack'; Name = 'Potion of Laumspur'; Quantity = 1; Description = 'Potion of Laumspur'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'larnuma_oil'; FlagName = 'Book5Section154LarnumaBought'; DisplayName = 'Vial of Larnuma Oil'; Type = 'backpack'; Name = 'Vial of Larnuma Oil'; Quantity = 1; Description = 'Vial of Larnuma Oil'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'graveweed'; FlagName = 'Book5Section154GraveweedBought'; DisplayName = 'Tincture of Graveweed'; Type = 'backpack'; Name = 'Tincture of Graveweed'; Quantity = 1; Description = 'Tincture of Graveweed'; GoldCost = 1 },
        [pscustomobject]@{ Id = 'calacena'; FlagName = 'Book5Section154CalacenaBought'; DisplayName = 'Tincture of Calacena'; Type = 'backpack'; Name = 'Tincture of Calacena'; Quantity = 1; Description = 'Tincture of Calacena'; GoldCost = 2 }
    )
}

function Get-LWBookFiveSection169ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'black_sash'; FlagName = 'Book5Section169BlackSashBought'; DisplayName = 'Black Sash'; Type = 'special'; Name = 'Black Sash'; Quantity = 1; Description = 'Black Sash'; GoldCost = 2 }
    )
}

function Get-LWBookFiveSection207ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'gold'; FlagName = 'Book5Section207GoldClaimed'; DisplayName = '8 Gold Crowns'; Type = 'gold'; Name = 'Gold Crowns'; Quantity = 8; Description = '8 Gold Crowns' },
        [pscustomobject]@{ Id = 'brass_whistle'; FlagName = 'Book5Section207WhistleClaimed'; DisplayName = 'Brass Whistle'; Type = 'special'; Name = 'Brass Whistle'; Quantity = 1; Description = 'Brass Whistle' }
    )
}

function Get-LWBookFiveSection211ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'kourshah'; FlagName = 'Book5Section211KourshahBought'; DisplayName = 'Bottle of Kourshah'; Type = 'backpack'; Name = 'Bottle of Kourshah'; Quantity = 1; Description = 'Bottle of Kourshah'; GoldCost = 5 }
    )
}

function Get-LWBookFiveSection255ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'black_crystal_cube'; FlagName = 'Book5Section255CubeClaimed'; DisplayName = 'Black Crystal Cube'; Type = 'special'; Name = 'Black Crystal Cube'; Quantity = 1; Description = 'Black Crystal Cube' }
    )
}

function Get-LWBookFiveSection290ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'black_crystal_cube'; FlagName = 'Book5Section290CubeClaimed'; DisplayName = 'Black Crystal Cube'; Type = 'special'; Name = 'Black Crystal Cube'; Quantity = 1; Description = 'Black Crystal Cube' }
    )
}

function Get-LWBookFiveSection310ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'canteen'; FlagName = 'Book5Section310CanteenClaimed'; DisplayName = 'Canteen of Water'; Type = 'backpack'; Name = 'Canteen of Water'; Quantity = 1; Description = 'Canteen of Water' },
        [pscustomobject]@{ Id = 'broadsword'; FlagName = 'Book5Section310BroadswordClaimed'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' }
    )
}

function Get-LWBookFiveSection341ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'canteen'; FlagName = 'Book5Section341CanteenClaimed'; DisplayName = 'Canteen of Water'; Type = 'backpack'; Name = 'Canteen of Water'; Quantity = 1; Description = 'Canteen of Water' },
        [pscustomobject]@{ Id = 'broadsword'; FlagName = 'Book5Section341BroadswordClaimed'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword' }
    )
}

function Get-LWBookFiveSection388ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'sword'; FlagName = 'Book5Section388SwordBought'; DisplayName = 'Sword'; Type = 'weapon'; Name = 'Sword'; Quantity = 1; Description = 'Sword'; GoldCost = 5 },
        [pscustomobject]@{ Id = 'dagger'; FlagName = 'Book5Section388DaggerBought'; DisplayName = 'Dagger'; Type = 'weapon'; Name = 'Dagger'; Quantity = 1; Description = 'Dagger'; GoldCost = 3 },
        [pscustomobject]@{ Id = 'broadsword'; FlagName = 'Book5Section388BroadswordBought'; DisplayName = 'Broadsword'; Type = 'weapon'; Name = 'Broadsword'; Quantity = 1; Description = 'Broadsword'; GoldCost = 9 }
    )
}

function Get-LWBookFiveSection281ChoiceDefinitions {
    return @(
        [pscustomobject]@{ Id = 'jewelled_mace'; FlagName = 'Book5Section281JewelledMaceClaimed'; DisplayName = 'Jewelled Mace'; Type = 'special'; Name = 'Jewelled Mace'; Quantity = 1; Description = 'Jewelled Mace' }
    )
}

function Get-LWBookFiveSectionContextAchievementIds {
    return @(
        'apothecarys_answer',
        'prison_break',
        'talons_tamed',
        'star_guided',
        'name_the_lost',
        'shadow_on_the_sand',
        'face_to_face_with_haakon'
    )
}


Export-ModuleMember -Function `
    Get-LWKaiBookFiveSectionRandomNumberContext, `
    Get-LWBookFiveSimpleSectionEffectDefinitions, `
    Get-LWBookFiveSimpleCombatRuleDefinitions, `
    Apply-LWKaiBookFiveStartingEquipment, `
    Test-LWBookFiveBloodPoisoningActive, `
    Test-LWBookFiveLimbdeathActive, `
    Invoke-LWBookFiveLoseBackpackItems, `
    Invoke-LWBookFiveBloodPoisoningSectionDamage, `
    Get-LWBookFiveSection002ChoiceDefinitions, `
    Get-LWBookFiveSection003ChoiceDefinitions, `
    Get-LWBookFiveSection004ChoiceDefinitions, `
    Get-LWBookFiveSection027ChoiceDefinitions, `
    Get-LWBookFiveSection035ChoiceDefinitions, `
    Get-LWBookFiveSection052ChoiceDefinitions, `
    Get-LWBookFiveSection056ChoiceDefinitions, `
    Get-LWBookFiveSection100ChoiceDefinitions, `
    Get-LWBookFiveSection102ChoiceDefinitions, `
    Get-LWBookFiveSection111ChoiceDefinitions, `
    Get-LWBookFiveSection131ChoiceDefinitions, `
    Get-LWBookFiveSection154ChoiceDefinitions, `
    Get-LWBookFiveSection169ChoiceDefinitions, `
    Get-LWBookFiveSection207ChoiceDefinitions, `
    Get-LWBookFiveSection211ChoiceDefinitions, `
    Get-LWBookFiveSection255ChoiceDefinitions, `
    Get-LWBookFiveSection290ChoiceDefinitions, `
    Get-LWBookFiveSection310ChoiceDefinitions, `
    Get-LWBookFiveSection341ChoiceDefinitions, `
    Get-LWBookFiveSection388ChoiceDefinitions, `
    Get-LWBookFiveSection281ChoiceDefinitions, `
    Get-LWBookFiveSectionContextAchievementIds


