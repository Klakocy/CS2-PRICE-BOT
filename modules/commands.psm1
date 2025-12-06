# =========================
# modules\commands.psm1
# =========================

# Global context is set in main.ps1:
# $Global:CS2BotContext = @{
#   SkinData
#   SkinListFile
#   TrackedFile
#   HistoryFile
#   DataPath
# }

function Show-Help {
    Write-Host "Available commands:"
    Write-Host "  help                       - show this help"
    Write-Host "  skins weapon               - list skins for given weapon (knife/gloves: indeksy)"
    Write-Host "  track weapon skin wear [seconds]   (agents/gloves: track weapon skin [seconds] lub indeksy)"
    Write-Host "  stop weapon skin wear      - disable tracking (agents/gloves: stop weapon skin)"
    Write-Host "  stop all                   - disable all trackings"
    Write-Host "  list                       - show current trackings"
    Write-Host "  history                    - show last history entries"
}

function Show-Skins {
    param(
        [string]$weapon,
        [int]$KnifeIndex = -1,
        [int]$GloveIndex = -1
    )

    $ctx = $Global:CS2BotContext
    $skinData = $ctx.SkinData
    $normalizedWeapon = Normalize-WeaponName -weapon $weapon
    $weaponLower = $weapon.ToLower()

    # Specjalna obsluga dla knife
    if ($normalizedWeapon -eq "Knife") {
        if ($KnifeIndex -le 0) {
            Show-KnifeMenu -skinData $skinData
            return
        } else {
            Show-KnifeByIndex -skinData $skinData -Index $KnifeIndex
            return
        }
    }

    # Specjalna obsluga dla gloves
    if ($weaponLower -eq "gloves") {
        if ($GloveIndex -le 0) {
            Show-GloveMenu -skinData $skinData
            return
        } else {
            Show-GloveByIndex -skinData $skinData -Index $GloveIndex
            return
        }
    }

    $skins = Find-SkinsByWeapon -weapon $normalizedWeapon -skinsByWeapon $skinData.skinsByWeapon

    if (-not $skins -or $skins.Count -eq 0) {
        Write-Host ("No skins found for weapon: {0}" -f $normalizedWeapon)
        return
    }

    Write-Host ("Skins for {0}:" -f $normalizedWeapon)
    for ($i = 0; $i -lt $skins.Count; $i++) {
        $s = $skins[$i]
        if ($normalizedWeapon -eq "Agent") {
            Write-Host ("  {0}. {1}" -f ($i + 1), $s.skin)
        } else {
            Write-Host ("  {0}. {1} [{2}] ({3})" -f ($i + 1), $s.skin, $s.rarity, $s.collection)
        }
    }
}

function Get-KnifeWeapons {
    param($skinData)
    $knifeSkins = $skinData.allSkins | Where-Object { $_.rarity -eq "Knife" }
    $weapons = $knifeSkins | Select-Object -ExpandProperty weapon -Unique | Sort-Object
    return $weapons
}

function Get-GloveWeapons {
    param($skinData)
    $gloveSkins = $skinData.allSkins | Where-Object { $_.rarity -eq "Gloves" }
    $weapons = $gloveSkins | Select-Object -ExpandProperty weapon -Unique | Sort-Object
    return $weapons
}

function Show-KnifeMenu {
    param($skinData)
    $weapons = Get-KnifeWeapons -skinData $skinData
    if (-not $weapons -or $weapons.Count -eq 0) {
        Write-Host "No knife data found."
        return
    }
    Write-Host "Knife types:"
    for ($i = 0; $i -lt $weapons.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $weapons[$i])
    }
    Write-Host ("Wpisz: skins knife <nr 1-{0}> aby zobaczyc skiny danego noza." -f $weapons.Count)
}

function Show-GloveMenu {
    param($skinData)
    $weapons = Get-GloveWeapons -skinData $skinData
    if (-not $weapons -or $weapons.Count -eq 0) {
        Write-Host "No gloves data found."
        return
    }
    Write-Host "Glove types:"
    for ($i = 0; $i -lt $weapons.Count; $i++) {
        Write-Host ("  {0}. {1}" -f ($i + 1), $weapons[$i])
    }
    Write-Host ("Wpisz: skins gloves <nr 1-{0}> aby zobaczyc skiny danej rekawicy." -f $weapons.Count)
}

function Show-KnifeByIndex {
    param(
        $skinData,
        [int]$Index
    )
    $weapons = Get-KnifeWeapons -skinData $skinData
    if (-not $weapons -or $weapons.Count -eq 0) {
        Write-Host "No knife data found."
        return
    }
    if ($Index -le 0 -or $Index -gt $weapons.Count) {
        Write-Host ("Nieprawidlowy numer noza. Wybierz 1-{0}." -f $weapons.Count)
        return
    }

    $weaponName = $weapons[$Index - 1]
    $skins = Find-SkinsByWeapon -weapon $weaponName -skinsByWeapon $skinData.skinsByWeapon
    if (-not $skins -or $skins.Count -eq 0) {
        Write-Host ("Brak skinow dla {0}." -f $weaponName)
        return
    }

    Write-Host ("Skins for {0}:" -f $weaponName)
    for ($i = 0; $i -lt $skins.Count; $i++) {
        $s = $skins[$i]
        Write-Host ("  {0}. {1} [{2}] ({3})" -f ($i + 1), $s.skin, $s.rarity, $s.collection)
    }
}

function Show-GloveByIndex {
    param(
        $skinData,
        [int]$Index
    )
    $weapons = Get-GloveWeapons -skinData $skinData
    if (-not $weapons -or $weapons.Count -eq 0) {
        Write-Host "No gloves data found."
        return
    }
    if ($Index -le 0 -or $Index -gt $weapons.Count) {
        Write-Host ("Nieprawidlowy numer rekawic. Wybierz 1-{0}." -f $weapons.Count)
        return
    }

    $weaponName = $weapons[$Index - 1]
    $skins = Find-SkinsByWeapon -weapon $weaponName -skinsByWeapon $skinData.skinsByWeapon
    if (-not $skins -or $skins.Count -eq 0) {
        Write-Host ("Brak skinow dla {0}." -f $weaponName)
        return
    }

    Write-Host ("Skins for {0}:" -f $weaponName)
    for ($i = 0; $i -lt $skins.Count; $i++) {
        $s = $skins[$i]
        Write-Host ("  {0}. {1} [{2}] ({3})" -f ($i + 1), $s.skin, $s.rarity, $s.collection)
    }
}

function Parse-TrackCommand {
    param(
        [string[]]$parts,
        $skinData
    )

    if ($parts.Count -lt 2) {
        return @{
            ok      = $false
            message = "Usage: track weapon skin wear [seconds]"
        }
    }

    $weapon = $parts[1]
    $weaponLower = $weapon.ToLower()

    # AGENT (no wear, required skin or indeks)
    if ($weaponLower -eq "agent" -or $weaponLower -eq "agents") {
        $agents = $skinData.skinsByWeapon["Agent"]
        if (-not $agents) {
            return @{ ok=$false; message="Brak agentow w bazie." }
        }

        # track agent <index> [sek]
        [int]$idxAgent = 0
        if ($parts.Count -ge 3 -and [int]::TryParse($parts[2], [ref]$idxAgent) -and $idxAgent -gt 0 -and $idxAgent -le $agents.Count) {
            $interval = 60
            if ($parts.Count -ge 4) {
                [int]$tmpInt = 0
                if ([int]::TryParse($parts[-1], [ref]$tmpInt)) {
                    $interval = $tmpInt
                }
            }
            return @{
                ok        = $true
                weapon    = "Agent"
                skinQuery = $agents[$idxAgent - 1].skin
                wearNum   = 0
                interval  = $interval
                noWear    = $true
            }
        }

        if ($parts.Count -lt 3) {
            return @{
                ok      = $false
                message = "Wybierz agenta: track agent <nazwa> lub track agent <indeks>. Lista: skins agent."
                askList = "agent"
            }
        }

        $interval = 60
        $skinParts = $parts[2..($parts.Count - 1)]
        [int]$tmp = 0
        if ([int]::TryParse($skinParts[-1], [ref]$tmp)) {
            $interval = $tmp
            $skinParts = $skinParts[0..($skinParts.Count - 2)]
        }
        $skinQuery = ($skinParts -join " ")
        return @{
            ok        = $true
            weapon    = "Agent"
            skinQuery = $skinQuery
            wearNum   = 0
            interval  = $interval
            noWear    = $true
        }
    }

    # KNIFE: track knife <typeIdx> <skinIdx> <wear> [seconds]
    if ($weaponLower -eq "knife") {
        $knifeWeapons = Get-KnifeWeapons -skinData $skinData
        if (-not $knifeWeapons -or $knifeWeapons.Count -eq 0) {
            return @{ ok=$false; message="Brak nozy w bazie." }
        }
        [int]$tIdx = 0; [int]$sIdx = 0; [int]$wearNum=0; [int]$interval=60
        if ($parts.Count -ge 5 -and [int]::TryParse($parts[2],[ref]$tIdx) -and [int]::TryParse($parts[3],[ref]$sIdx) -and [int]::TryParse($parts[4],[ref]$wearNum)) {
            if ($tIdx -lt 1 -or $tIdx -gt $knifeWeapons.Count) {
                return @{ ok=$false; message=("Nieprawidlowy indeks noza. Wpisz: skins knife.") }
            }
            $weaponName = $knifeWeapons[$tIdx-1]
            $skins = $skinData.skinsByWeapon[$weaponName]
            if (-not $skins -or $sIdx -lt 1 -or $sIdx -gt $skins.Count) {
                return @{ ok=$false; message=("Nieprawidlowy indeks skina dla {0}. Wpisz: skins knife {1}." -f $weaponName,$tIdx) }
            }
            if ($parts.Count -ge 6) {
                [int]$tmpI=0
                if ([int]::TryParse($parts[-1],[ref]$tmpI)) { $interval=$tmpI }
            }
            return @{
                ok=$true; weapon=$weaponName; skinQuery=$skins[$sIdx-1].skin; wearNum=$wearNum; interval=$interval; noWear=$false
            }
        }
    }

    # GLOVES alias "gloves <typeIdx> <skinIdx> [seconds]" lub nazwy
    if ($weaponLower -eq "gloves") {
        $gloveWeapons = Get-GloveWeapons -skinData $skinData
        if (-not $gloveWeapons -or $gloveWeapons.Count -eq 0) {
            return @{ ok=$false; message="Brak rekawic w bazie." }
        }

        # indeksy
        [int]$typeIdx = 0
        [int]$skinIdx = 0
        if ($parts.Count -ge 4 -and
            [int]::TryParse($parts[2], [ref]$typeIdx) -and
            [int]::TryParse($parts[3], [ref]$skinIdx)) {

            if ($typeIdx -le 0 -or $typeIdx -gt $gloveWeapons.Count) {
                return @{ ok=$false; message=("Nieprawidlowy indeks rekawic. Wpisz: skins gloves.") }
            }
            $weaponName = $gloveWeapons[$typeIdx - 1]
            $skins = $skinData.skinsByWeapon[$weaponName]
            if (-not $skins -or $skinIdx -le 0 -or $skinIdx -gt $skins.Count) {
                return @{ ok=$false; message=("Nieprawidlowy indeks skina dla {0}. Wpisz: skins gloves {1}." -f $weaponName, $typeIdx) }
            }

            $interval = 60
            if ($parts.Count -ge 5) {
                [int]$tmpInt = 0
                if ([int]::TryParse($parts[-1], [ref]$tmpInt)) {
                    $interval = $tmpInt
                }
            }

            return @{
                ok        = $true
                weapon    = $weaponName
                skinQuery = $skins[$skinIdx - 1].skin
                wearNum   = 0
                interval  = $interval
                noWear    = $true
            }
        }

        if ($parts.Count -lt 3) {
            return @{
                ok      = $false
                message = "Podaj rekawice: track gloves <weapon> | <skin> [seconds] lub track gloves <typIdx> <skinIdx>."
                askList = "gloves"
            }
        }

        $restTokens = $parts[2..($parts.Count - 1)]
        $interval = 60
        [int]$tmp = 0
        if ($restTokens.Count -gt 0 -and [int]::TryParse($restTokens[-1], [ref]$tmp)) {
            $interval = $tmp
            $restTokens = $restTokens[0..($restTokens.Count - 2)]
        }

        $weaponName = $null
        $skinQuery  = $null

        $restStr = ($restTokens -join " ")
        if ($restStr -like "*|*") {
            $split = $restStr.Split("|",2)
            $weaponName = $split[0].Trim()
            $skinQuery  = $split[1].Trim()
        } else {
            # spróbuj wydzielić nazwę rękawic z listy
            $restLower = $restStr.ToLowerInvariant()
            $matchWeapon = $gloveWeapons | Where-Object { $restLower.StartsWith($_.ToLowerInvariant()) } | Sort-Object Length -Descending | Select-Object -First 1
            if ($matchWeapon) {
                $weaponName = $matchWeapon
                $skinQuery  = $restStr.Substring($matchWeapon.Length).Trim()
            }
        }

        if (-not $weaponName -or [string]::IsNullOrWhiteSpace($skinQuery)) {
            return @{
                ok      = $false
                message = "Uzyj formatu: track gloves <weapon> | <skin> [seconds] albo indeksy: track gloves <typIdx> <skinIdx>."
            }
        }

        return @{
            ok        = $true
            weapon    = $weaponName
            skinQuery = $skinQuery
            wearNum   = 0
            interval  = $interval
            noWear    = $true
        }
    }

    # Standard broni z wear (obsługa skin index)
    $skinsForWeapon = Find-SkinsByWeapon -weapon (Normalize-WeaponName -weapon $weapon) -skinsByWeapon $skinData.skinsByWeapon

    # wariant z indeksem skina
    [int]$skinIdx = 0
    [int]$wearNum = 0
    [int]$interval = 60
    if ($parts.Count -ge 4 -and [int]::TryParse($parts[2],[ref]$skinIdx) -and [int]::TryParse($parts[3],[ref]$wearNum)) {
        if (-not $skinsForWeapon -or $skinIdx -lt 1 -or $skinIdx -gt $skinsForWeapon.Count) {
            return @{ ok=$false; message=("Nieprawidlowy indeks skina. Wpisz: skins {0}." -f (Normalize-WeaponName -weapon $weapon)) }
        }
        if ($parts.Count -ge 5) {
            [int]$tmp3=0
            if ([int]::TryParse($parts[4],[ref]$tmp3)) { $interval=$tmp3 }
        }
        return @{
            ok=$true; weapon=(Normalize-WeaponName -weapon $weapon); skinQuery=$skinsForWeapon[$skinIdx-1].skin; wearNum=$wearNum; interval=$interval; noWear=$false
        }
    }

    if ($parts.Count -lt 4) {
        return @{
            ok      = $false
            message = "Usage: track weapon skin wear [seconds]"
        }
    }

    # find numbers in arguments (wear and optional interval)
    $nums = @()
    for ($i = 2; $i -lt $parts.Count; $i++) {
        [int]$tmp = 0
        if ([int]::TryParse($parts[$i], [ref]$tmp)) {
            $nums += [PSCustomObject]@{ index = $i; value = $tmp }
        }
    }

    if ($nums.Count -eq 0) {
        return @{
            ok      = $false
            message = "Please provide wear number 1-5."
        }
    }

    $wearIndex = $nums[0].index
    $wearNum   = $nums[0].value
    $interval  = 60

    if ($nums.Count -gt 1) {
        $interval = $nums[1].value
    } elseif ($parts.Count -gt ($wearIndex + 1)) {
        [int]$tmp2 = 0
        if ([int]::TryParse($parts[$wearIndex + 1], [ref]$tmp2)) {
            $interval = $tmp2
        }
    }

    if ($interval -le 0) { $interval = 60 }

    $skinParts = $parts[2..($wearIndex - 1)]
    $skinQuery = ($skinParts -join " ")

    return @{
        ok        = $true
        weapon    = $weapon
        skinQuery = $skinQuery
        wearNum   = $wearNum
        interval  = $interval
        noWear    = $false
    }
}

function Handle-Command {
    [CmdletBinding()]
    param(
        [string]$commandLine
    )

    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        return
    }

    $parts = $commandLine.Trim().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($parts.Count -eq 0) { return }

    # allow both "help" and "!help" just in case:
    $cmdRaw = $parts[0]
    if ($cmdRaw.StartsWith("!")) {
        $cmdRaw = $cmdRaw.Substring(1)
    }
    $cmd = $cmdRaw.ToLower()

    switch ($cmd) {

        "help" {
            Show-Help
        }

        "skins" {
            if ($parts.Count -lt 2) {
                Write-Host "Usage: skins weapon"
            } else {
                $weapon = $parts[1]
                $weaponLower = $weapon.ToLower()
                $knifeIndex = -1
                $gloveIndex = -1
                if ($weaponLower -eq "knife" -and $parts.Count -ge 3) {
                    [int]$tmp = 0
                    if ([int]::TryParse($parts[2], [ref]$tmp)) {
                        $knifeIndex = $tmp
                    }
                }
                if ($weaponLower -eq "gloves" -and $parts.Count -ge 3) {
                    [int]$tmpG = 0
                    if ([int]::TryParse($parts[2], [ref]$tmpG)) {
                        $gloveIndex = $tmpG
                    }
                }
                Show-Skins -weapon $weapon -KnifeIndex $knifeIndex -GloveIndex $gloveIndex
            }
        }

        "track" {
            # track all -> wlacz wszystkie zapisane
            if ($parts.Count -eq 2 -and $parts[1].ToLower() -eq "all") {
                $ctx = $Global:CS2BotContext
                $res = Start-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
                break
            }

            $ctx = $Global:CS2BotContext
            $parsed = Parse-TrackCommand -parts $parts -skinData $ctx.SkinData

            if (-not $parsed.ok) {
                Write-Host $parsed.message
                if ($parsed.ContainsKey("askList")) {
                    $ans = Read-Host "Pokazac liste teraz? (y/n)"
                    if ($ans -and $ans.Trim().ToLower() -in @("y","yes")) {
                        if ($parsed.askList -eq "agent") { Show-Skins -weapon "agent" }
                        elseif ($parsed.askList -eq "gloves") { Show-Skins -weapon "gloves" }
                    }
                }
                break
            }

            $res = Add-Tracking `
                -weapon      $parsed.weapon `
                -skinQuery   $parsed.skinQuery `
                -wearNum     $parsed.wearNum `
                -interval    $parsed.interval `
                -trackedFile $ctx.TrackedFile `
                -skinData    $ctx.SkinData `
                -NoWear:$parsed.noWear

            switch ($res.status) {
                "ok"    { Write-Host $res.message }
                "multi" { Write-Host $res.message }
                "error" { Write-Host ("Error: {0}" -f $res.message) }
                default { Write-Host "Unknown status from Add-Tracking." }
            }
        }

        "start" {
            $ctx = $Global:CS2BotContext

            if ($parts.Count -eq 2 -and $parts[1].ToLower() -eq "all") {
                $res = Start-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
                break
            }

            if ($parts.Count -eq 2) {
                [int]$idx = 0
                if ([int]::TryParse($parts[1], [ref]$idx) -and $idx -gt 0) {
                    $res = Start-TrackingByIndex -Index $idx -trackedFile $ctx.TrackedFile
                    if ($res.status -eq "ok") {
                        Write-Host $res.message
                    } else {
                        Write-Host ("Error: {0}" -f $res.message)
                    }
                } else {
                    Write-Host "Usage: start <index>  |  start all"
                }
                break
            }

            Write-Host "Usage: start <index>  |  start all"
        }

        "set" {
            $ctx = $Global:CS2BotContext
            if ($parts.Count -eq 4 -and $parts[2].ToLower() -in @("-s", "--seconds", "interval")) {
                [int]$idx = 0
                [int]$sec = 0
                if ([int]::TryParse($parts[1], [ref]$idx) -and [int]::TryParse($parts[3], [ref]$sec)) {
                    $res = Set-TrackingInterval -Index $idx -Seconds $sec -trackedFile $ctx.TrackedFile
                    if ($res.status -eq "ok") {
                        Write-Host $res.message
                    } else {
                        Write-Host ("Error: {0}" -f $res.message)
                    }
                } else {
                    Write-Host "Usage: set <index> -s <seconds>"
                }
                break
            }
            Write-Host "Usage: set <index> -s <seconds>"
        }

        "stop" {
            $ctx = $Global:CS2BotContext

            if ($parts.Count -eq 2 -and $parts[1].ToLower() -eq "all") {
                $res = Stop-Tracking -weapon "" -skin "all" -wear "" -trackedFile $ctx.TrackedFile
                Write-Host $res.message
                break
            }

            # stop by index, e.g. "stop 2"
            if ($parts.Count -eq 2) {
                [int]$idx = 0
                if ([int]::TryParse($parts[1], [ref]$idx) -and $idx -gt 0) {
                    $res = Stop-Tracking -weapon "" -skin "" -wear "" -trackedFile $ctx.TrackedFile -Index $idx
                    if ($res.status -eq "ok") {
                        Write-Host $res.message
                    } else {
                        Write-Host ("Error: {0}" -f $res.message)
                    }
                } else {
                    Write-Host "Usage: stop weapon skin wear  |  stop all  |  stop <index>"
                }
                break
            }

            if ($parts.Count -lt 3) {
                Write-Host "Usage: stop weapon skin wear"
                break
            }

            $weapon = $parts[1]
            $weaponLower = $weapon.ToLower()
            $noWearWeapon = ($weaponLower -like "*glove*") -or ($weaponLower -like "*agent*")

            $skinName = $null
            $wearName = ""

            if ($weaponLower -eq "agent" -or $weaponLower -eq "agents") {
                $agents = $ctx.SkinData.skinsByWeapon["Agent"]
                [int]$aIdx = 0
                if ($parts.Count -eq 3 -and $agents -and [int]::TryParse($parts[2], [ref]$aIdx)) {
                    if ($aIdx -ge 1 -and $aIdx -le $agents.Count) {
                        $skinName = $agents[$aIdx - 1].skin
                    }
                }
                if (-not $skinName) {
                    $skinParts = $parts[2..($parts.Count - 1)]
                    $skinName  = ($skinParts -join " ")
                }
                $wearName = ""
                $weapon   = "Agent"
            }
            elseif ($weaponLower -eq "gloves") {
                $gloveWeapons = Get-GloveWeapons -skinData $ctx.SkinData
                [int]$tIdx = 0
                [int]$sIdx = 0
                if ($parts.Count -ge 4 -and [int]::TryParse($parts[2], [ref]$tIdx) -and [int]::TryParse($parts[3], [ref]$sIdx)) {
                    if ($tIdx -ge 1 -and $tIdx -le $gloveWeapons.Count) {
                        $weapon = $gloveWeapons[$tIdx - 1]
                        $skins = $ctx.SkinData.skinsByWeapon[$weapon]
                        if ($skins -and $sIdx -ge 1 -and $sIdx -le $skins.Count) {
                            $skinName = $skins[$sIdx - 1].skin
                        }
                    }
                }
                if (-not $skinName) {
                    if ($parts.Count -lt 4) {
                        Write-Host "Usage: stop gloves <typIdx> <skinIdx> lub stop gloves <weapon> | <skin>"
                        break
                    }
                    $skinParts = $parts[2..($parts.Count - 1)]
                    $skinName  = ($skinParts -join " ")
                }
                $wearName = ""
            }
            else {
                if ($parts.Count -lt 4) {
                    Write-Host "Usage: stop weapon skin wear"
                    break
                }
                $wearRaw = $parts[-1]
                $wearName = $wearRaw
                [int]$wearNum = 0
                if ([int]::TryParse($wearRaw, [ref]$wearNum)) {
                    $wearName = Wear-FromNumber -num $wearNum
                }
                $skinParts = $parts[2..($parts.Count - 2)]
                $skinName  = ($skinParts -join " ")
            }

            $res = Stop-Tracking `
                -weapon $weapon `
                -skin   $skinName `
                -wear   $wearName `
                -trackedFile $ctx.TrackedFile

            if ($res.status -eq "ok") {
                Write-Host $res.message
            } else {
                Write-Host ("Error: {0}" -f $res.message)
            }
        }

        "list" {
            $ctx = $Global:CS2BotContext
            $list = List-Tracking -trackedFile $ctx.TrackedFile

            if (-not $list -or $list.Count -eq 0) {
                Write-Host "No trackings."
                break
            }

            Write-Host "Current trackings:"
            foreach ($t in $list) {
                $state = if ($t.active) { "ON" } else { "OFF" }
                $idx = if ($t.PSObject.Properties.Match("index").Count -gt 0) { $t.index } else { "-" }
                if ([string]::IsNullOrWhiteSpace($t.wear)) {
                    Write-Host ("  {0}. {1} | {2} every {3}s [{4}]" -f $idx, $t.weapon, $t.skin, $t.interval, $state)
                } else {
                    Write-Host ("  {0}. {1} | {2} ({3}) every {4}s [{5}]" -f $idx, $t.weapon, $t.skin, $t.wear, $t.interval, $state)
                }
            }
        }

        "history" {
            $ctx = $Global:CS2BotContext
            $file = $ctx.HistoryFile

            if (-not (Test-Path $file)) {
                Write-Host "History file not found."
                break
            }

            $lines = Get-Content -Path $file -Tail 10 -ErrorAction SilentlyContinue

            if (-not $lines -or $lines.Count -eq 0) {
                Write-Host "No history entries."
                break
            }

            Write-Host "Last history entries:"
            foreach ($l in $lines) {
                Write-Host ("  {0}" -f $l)
            }
        }

        "delete" {
            $ctx = $Global:CS2BotContext
            if ($parts.Count -ne 2) {
                Write-Host "Usage: delete <index>"
                break
            }
            $arg = $parts[1].ToLower()
            if ($arg -eq "all") {
                $res = Delete-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                    $ans = Read-Host "Also clear history.txt? (y/n)"
                    if ($ans -and $ans.Trim().ToLower() -in @("y", "yes")) {
                        "" | Set-Content -Path $ctx.HistoryFile -Encoding UTF8
                        Write-Host "History cleared."
                    }
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            } else {
                [int]$delIdx = 0
                if (-not [int]::TryParse($parts[1], [ref]$delIdx)) {
                    Write-Host "Usage: delete <index>"
                    break
                }
                $res = Delete-Tracking -Index $delIdx -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            }
            break
        }

        "del" {
            $ctx = $Global:CS2BotContext
            if ($parts.Count -ne 2) {
                Write-Host "Usage: del <index>"
                break
            }
            $arg = $parts[1].ToLower()
            if ($arg -eq "all") {
                $res = Delete-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                    $ans = Read-Host "Also clear history.txt? (y/n)"
                    if ($ans -and $ans.Trim().ToLower() -in @("y", "yes")) {
                        "" | Set-Content -Path $ctx.HistoryFile -Encoding UTF8
                        Write-Host "History cleared."
                    }
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            } else {
                [int]$delIdx = 0
                if (-not [int]::TryParse($parts[1], [ref]$delIdx)) {
                    Write-Host "Usage: del <index>"
                    break
                }
                $res = Delete-Tracking -Index $delIdx -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            }
            break
        }

        default {
            Write-Host ("Unknown command: {0}" -f $cmd)
        }
    }
}

Export-ModuleMember -Function Handle-Command
