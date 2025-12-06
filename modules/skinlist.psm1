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

        # Knives
        "bowie"         = "Bowie Knife"
        "bowieknife"    = "Bowie Knife"
        "bowie-knife"   = "Bowie Knife"
        "butterfly"     = "Butterfly Knife"
        "butterflyknife"= "Butterfly Knife"
        "butterfly-knife"= "Butterfly Knife"
        "falchion"      = "Falchion Knife"
        "falchionknife" = "Falchion Knife"
        "flip"          = "Flip Knife"
        "flipknife"     = "Flip Knife"
        "flip-knife"    = "Flip Knife"
        "gut"           = "Gut Knife"
        "gutknife"      = "Gut Knife"
        "gut-knife"     = "Gut Knife"
        "huntsman"      = "Huntsman Knife"
        "huntsmanknife" = "Huntsman Knife"
        "huntsman-knife"= "Huntsman Knife"
        "karambit"      = "Karambit"
        "m9"            = "M9 Bayonet"
        "m9bayonet"     = "M9 Bayonet"
        "navaja"        = "Navaja Knife"
        "nomad"         = "Nomad Knife"
        "paracord"      = "Paracord Knife"
        "shadow"        = "Shadow Daggers"
        "shadowdaggers" = "Shadow Daggers"
        "shadow-daggers"= "Shadow Daggers"
        "skeleton"      = "Skeleton Knife"
        "stiletto"      = "Stiletto Knife"
        "survival"      = "Survival Knife"
        "talon"         = "Talon Knife"
        "ursus"         = "Ursus Knife"
        "classic"       = "Classic Knife"
        "bayonet"       = "Bayonet"

        # Gloves
        "bloodhound"      = "Bloodhound Gloves"
        "driver"          = "Driver Gloves"
        "handwraps"       = "Hand Wraps"
        "hand-wraps"      = "Hand Wraps"
        "hand wraps"      = "Hand Wraps"
        "hydra"           = "Hydra Gloves"
        "moto"            = "Moto Gloves"
        "specialist"      = "Specialist Gloves"
        "sport"           = "Sport Gloves"
        "brokenfang"      = "Broken Fang Gloves"
        "broken-fang"     = "Broken Fang Gloves"
        "broken fang"     = "Broken Fang Gloves"

        # Agents
        "agent"  = "Agent"
        "agents" = "Agent"
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
    $baseDir       = Split-Path -Parent $file

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

    # Dodatkowe listy: noze, rekawice, agenci (opcjonalnie jesli pliki istnieja)
    $extraFiles = @(
        @{ path = (Join-Path $baseDir "knife_skins.txt");  rarity = "Knife";  collection = "Knife";  introduced = "-" },
        @{ path = (Join-Path $baseDir "gloves_skins.txt"); rarity = "Gloves"; collection = "Gloves"; introduced = "-" },
        @{ path = (Join-Path $baseDir "agents_skins.txt"); rarity = "Agent";  collection = "Agent";  introduced = "-" }
    )

    foreach ($extra in $extraFiles) {
        $p = $extra.path
        if (-not (Test-Path $p)) { continue }

        $linesExtra = Get-Content -Path $p -Encoding UTF8 | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        foreach ($l in $linesExtra) {
            $weaponExtra = $null
            $skinExtra   = $null

            if ($p.EndsWith("agents_skins.txt")) {
                # Format: tylko nazwa agenta
                $weaponExtra = "Agent"
                $skinExtra   = $l.Trim()
            } else {
                # Format: "Weapon | Skin"
                $split = $l -split "\|"
                if ($split.Count -lt 2) { continue }
                $weaponExtra = $split[0].Trim()
                $skinExtra   = $split[1].Trim()
            }

            $entryExtra = [PSCustomObject]@{
                weapon     = $weaponExtra
                skin       = $skinExtra
                rarity     = $extra.rarity
                collection = $extra.collection
                introduced = $extra.introduced
            }

            $allSkins += $entryExtra
            if (-not $skinsByWeapon.ContainsKey($weaponExtra)) {
                $skinsByWeapon[$weaponExtra] = @()
            }
            $skinsByWeapon[$weaponExtra] += $entryExtra
        }
    }

    return @{
        skinsByWeapon = $skinsByWeapon
        allSkins      = $allSkins
    }
}

Export-ModuleMember -Function Normalize-WeaponName, Load-SkinList
