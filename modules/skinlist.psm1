# =========================
# modules\skinlist.psm1
# =========================

function Normalize-WeaponName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$weapon
    )

    $w = $weapon.Trim()

    $map = @{
        "ak47"   = "AK-47"
        "ak-47"  = "AK-47"
        "m4a4"   = "M4A4"
        "m4a1s"  = "M4A1-S"
        "m4a1-s" = "M4A1-S"
        "usp"    = "USP-S"
        "usps"   = "USP-S"
        "usp-s"  = "USP-S"
        "deagle" = "Desert Eagle"
    }

    $key = $w.ToLower()
    if ($map.ContainsKey($key)) {
        return $map[$key]
    }

    # Prosta normalizacja: zamień wiele spacji na jedną, przytnij
    return $w
}

function Load-SkinList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$file
    )

    if (-not (Test-Path $file)) {
        throw "Plik skinlist.txt nie istnieje: $file"
    }

    # Wczytaj wszystkie niepuste linie
    $lines = Get-Content -Path $file -Encoding UTF8 |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    $skinsByWeapon = @{}
    $allSkins      = @()

    foreach ($line in $lines) {
        # Oczekujemy formatu z TABAMI:
        # Weapon<TAB>Skin<TAB>Rarity<TAB>Collection<TAB>Introduced
        $parts = $line -split "`t"
        if ($parts.Count -lt 5) {
            continue
        }

        $weapon     = $parts[0].Trim()
        $skin       = $parts[1].Trim()
        $rarity     = $parts[2].Trim()
        $collection = $parts[3].Trim()
        $introduced = $parts[4].Trim()

        $entry = [PSCustomObject]@{
            weapon     = $weapon
            skin       = $skin
            rarity     = $rarity
            collection = $collection
            introduced = $introduced
        }

        $allSkins += $entry

        if (-not $skinsByWeapon.ContainsKey($weapon)) {
            $skinsByWeapon[$weapon] = @()
        }
        $skinsByWeapon[$weapon] += $entry
    }

    return @{
        skinsByWeapon = $skinsByWeapon
        allSkins      = $allSkins
    }
}

Export-ModuleMember -Function Normalize-WeaponName, Load-SkinList
