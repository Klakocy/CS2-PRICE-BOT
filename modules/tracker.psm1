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

    if ($existing.Count -gt 0) {
        foreach ($e in $existing) {
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
        [string]$weapon,

        [Parameter(Mandatory = $true)]
        [string]$skin,

        [Parameter(Mandatory = $true)]
        [string]$wear,

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

    # stop all
    if ($skin -eq "all") {
        foreach ($t in $tracked) {
            $t.active = $false
        }
        Save-Tracked -file $trackedFile -tracked $tracked

        return @{
            status  = "ok"
            message = "All trackings turned OFF."
        }
    }

    $normalizedWeapon = Normalize-WeaponName -weapon $weapon
    $wearName         = $wear

    $matches = $tracked | Where-Object {
        $_.weapon -eq $normalizedWeapon -and
        $_.skin   -eq $skin -and
        $_.wear   -eq $wearName
    }

    if ($matches.Count -eq 0) {
        return @{
            status  = "error"
            message = ("Tracking not found for: {0} | {1} ({2})." -f $normalizedWeapon, $skin, $wearName)
        }
    }

    foreach ($m in $matches) {
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

    return $tracked
}

Export-ModuleMember -Function Wear-FromNumber, Add-Tracking, Stop-Tracking, List-Tracking
