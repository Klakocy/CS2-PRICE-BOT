# =========================
# modules\tracker.psm1
# =========================

function Wear-FromNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$num
    )

    switch ($num) {
        1 { return "Factory New" }
        2 { return "Minimal Wear" }
        3 { return "Field-Tested" }
        4 { return "Well-Worn" }
        5 { return "Battle-Scarred" }
        default { return "Field-Tested" }
    }
}

function Format-TrackingName {
    param($t)
    return ("{0} | {1} ({2})" -f $t.weapon, $t.skin, $t.wear)
}

function Add-Tracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$weapon,

        [Parameter(Mandatory = $true)]
        [string]$skinQuery,

        [Parameter(Mandatory = $true)]
        [int]$wearNum,

        [Parameter(Mandatory = $true)]
        [int]$interval,

        [Parameter(Mandatory = $true)]
        [string]$trackedFile,

        # skinData przekazujemy z main.ps1 – tu go wykorzystamy do poprawy nazwy
        [Parameter(Mandatory = $true)]
        $skinData
    )

    $normalizedWeapon = Normalize-WeaponName -weapon $weapon
    $wearName         = Wear-FromNumber -num $wearNum
    $skinName         = $skinQuery.Trim()

    if ([string]::IsNullOrWhiteSpace($skinName)) {
        return @{
            status  = "error"
            message = "Skin name cannot be empty."
        }
    }

    # --- PROBA NAPRAWY NAZWY SKINA NA KANONICZNA Z BAZY ---

    $skinsByWeapon = $skinData.skinsByWeapon
    $weaponKey = $null

    if ($skinsByWeapon) {
        # znajdz klucz broni case-insensitive
        foreach ($k in $skinsByWeapon.Keys) {
            if ($k.Trim().ToLowerInvariant() -eq $normalizedWeapon.Trim().ToLowerInvariant()) {
                $weaponKey = $k
                break
            }
        }

        if ($weaponKey) {
            $weaponSkins = $skinsByWeapon[$weaponKey]
            $qLower      = $skinName.Trim().ToLowerInvariant()

            # 1) dokladne dopasowanie case-insensitive
            $match = $weaponSkins | Where-Object {
                $_.skin.Trim().ToLowerInvariant() -eq $qLower
            } | Select-Object -First 1

            # jak nie ma, mozna by zrobic contains, ale na razie zostajemy przy dokladnym
            if ($match) {
                # popraw nazwe skina na taka jak w bazie
                $skinName = $match.skin
            }
        }
    }

    # --------------------------------------

    # Wczytaj trackingi ZAWSZE jako tablicę
    $tracked = @(Load-Tracked -file $trackedFile)
    if ($tracked.Count -eq 1 -and $null -eq $tracked[0]) {
        $tracked = @()
    }

    # Sprawdź, czy taki tracking już istnieje
    $existing = $tracked | Where-Object {
        $_.weapon -eq $normalizedWeapon -and
        $_.skin   -eq $skinName -and
        $_.wear   -eq $wearName
    }

    if (@($existing).Count -gt 0) {
        foreach ($e in @($existing)) {
            $e.interval = $interval
            $e.active   = $true
        }

        Save-Tracked -file $trackedFile -tracked $tracked

        return @{
            status  = "ok"
            message = ("Updated tracking for {0} | {1} ({2}), interval {3}s." -f $normalizedWeapon, $skinName, $wearName, $interval)
        }
    }

    # Dodaj nowy tracking
    $new = [PSCustomObject]@{
        weapon   = $normalizedWeapon
        skin     = $skinName
        wear     = $wearName
        interval = $interval
        active   = $true
    }

    $tracked += $new
    Save-Tracked -file $trackedFile -tracked $tracked

    return @{
        status  = "ok"
        message = ("Added tracking: {0} | {1} ({2}) every {3}s." -f $normalizedWeapon, $skinName, $wearName, $interval)
    }
}

function Stop-Tracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$weapon,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$skin,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$wear,

        [Parameter(Mandatory = $true)]
        [string]$trackedFile,

        [Parameter(Mandatory = $false)]
        [int]$Index = -1
    )

    $tracked = @(Load-Tracked -file $trackedFile)
    if (-not $tracked -or $tracked.Count -eq 0 -or ($tracked.Count -eq 1 -and $null -eq $tracked[0])) {
        return @{
            status  = "error"
            message = "No entries in tracked.json."
        }
    }

    # stop all
    if ($skin -eq "all") {
        $turnedOff = @()
        foreach ($t in $tracked) {
            if ($t.active) { $turnedOff += $t }
            $t.active = $false
        }
        Save-Tracked -file $trackedFile -tracked $tracked

        $listMsg = if ($turnedOff.Count -gt 0) {
            ($turnedOff | ForEach-Object { "- " + (Format-TrackingName $_) }) -join "`n"
        } else { "No active trackings were ON." }

        return @{
            status  = "ok"
            message = ("All trackings turned OFF.`n{0}" -f $listMsg)
        }
    }

    # stop by index
    if ($Index -gt 0) {
        $idx = $Index - 1
        if ($idx -lt 0 -or $idx -ge $tracked.Count) {
            return @{
                status  = "error"
                message = ("Invalid index: {0}." -f $Index)
            }
        }
        $target = $tracked[$idx]
        $target.active = $false
        Save-Tracked -file $trackedFile -tracked $tracked

        return @{
            status  = "ok"
            message = ("Tracking turned OFF for #{0}: {1} | {2} ({3})." -f $Index, $target.weapon, $target.skin, $target.wear)
            turnedOff = @($target)
        }
    }

    $normalizedWeapon = Normalize-WeaponName -weapon $weapon
    $wearName         = $wear

    $matches = $tracked | Where-Object {
        $_.weapon -eq $normalizedWeapon -and
        $_.skin   -eq $skin -and
        $_.wear   -eq $wearName
    }

    if (@($matches).Count -eq 0) {
        return @{
            status  = "error"
            message = ("Tracking not found for: {0} | {1} ({2})." -f $normalizedWeapon, $skin, $wearName)
        }
    }

    foreach ($m in @($matches)) {
        $m.active = $false
    }

    Save-Tracked -file $trackedFile -tracked $tracked

    return @{
        status  = "ok"
        message = ("Tracking turned OFF for {0} | {1} ({2})." -f $normalizedWeapon, $skin, $wearName)
    }
}

function List-Tracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$trackedFile
    )

    $tracked = @(Load-Tracked -file $trackedFile)
    if (-not $tracked -or $tracked.Count -eq 0 -or ($tracked.Count -eq 1 -and $null -eq $tracked[0])) {
        return @()
    }

    # Dodaj indeksy w locie, jesli nie ma
    for ($i = 0; $i -lt $tracked.Count; $i++) {
        $tracked[$i] | Add-Member -MemberType NoteProperty -Name "index" -Value ($i + 1) -Force
    }

    return $tracked
}

function Start-AllTracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$trackedFile
    )

    $tracked = @(Load-Tracked -file $trackedFile)
    if (-not $tracked -or $tracked.Count -eq 0 -or ($tracked.Count -eq 1 -and $null -eq $tracked[0])) {
        return @{
            status  = "error"
            message = "No entries in tracked.json."
        }
    }

    $turnedOn = @()
    foreach ($t in $tracked) {
        if (-not $t.active) { $turnedOn += $t }
        $t.active = $true
    }

    Save-Tracked -file $trackedFile -tracked $tracked

    $listMsg = if ($turnedOn.Count -gt 0) {
        ($turnedOn | ForEach-Object { "- " + (Format-TrackingName $_) }) -join "`n"
    } else { "All trackings were already ON." }

    return @{
        status  = "ok"
        message = ("All trackings turned ON.`n{0}" -f $listMsg)
        turnedOn = $turnedOn
    }
}

function Delete-Tracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [string]$trackedFile
    )

    $tracked = @(Load-Tracked -file $trackedFile)
    if (-not $tracked -or $tracked.Count -eq 0 -or ($tracked.Count -eq 1 -and $null -eq $tracked[0])) {
        return @{
            status  = "error"
            message = "No entries in tracked.json."
        }
    }

    $idx = $Index - 1
    if ($idx -lt 0 -or $idx -ge $tracked.Count) {
        return @{
            status  = "error"
            message = ("Invalid index: {0}." -f $Index)
        }
    }

    # usun wskazany element
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($t in $tracked) { $list.Add($t) | Out-Null }
    $removed = $list[$idx]
    $list.RemoveAt($idx)

    Save-Tracked -file $trackedFile -tracked $list.ToArray()

    return @{
        status  = "ok"
        message = ("Deleted tracking #{0}: {1}" -f $Index, (Format-TrackingName $removed))
        removed = $removed
    }
}

function Delete-AllTracking {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$trackedFile
    )

    Save-Tracked -file $trackedFile -tracked @()

    return @{
        status  = "ok"
        message = "Deleted all trackings."
    }
}

Export-ModuleMember -Function Wear-FromNumber, Add-Tracking, Stop-Tracking, List-Tracking, Start-AllTracking, Delete-Tracking, Delete-AllTracking, Format-TrackingName
