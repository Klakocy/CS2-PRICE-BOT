# =========================
# modules\search.psm1
# =========================

function Find-SkinsByWeapon {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$weapon,

        [Parameter(Mandatory = $true)]
        $skinsByWeapon
    )

    if ($skinsByWeapon.ContainsKey($weapon)) {
        return $skinsByWeapon[$weapon]
    }

    # Case-insensitive fallback
    foreach ($key in $skinsByWeapon.Keys) {
        if ($key.Equals($weapon, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $skinsByWeapon[$key]
        }
    }

    return @()
}

function Resolve-SkinName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$weapon,

        [Parameter(Mandatory = $true)]
        [string]$skinQuery,

        [Parameter(Mandatory = $true)]
        $skinsByWeapon,

        [Parameter(Mandatory = $true)]
        $allSkins
    )

    $weaponSkins = Find-SkinsByWeapon -weapon $weapon -skinsByWeapon $skinsByWeapon

    if (-not $weaponSkins -or $weaponSkins.Count -eq 0) {
        return @{
            status  = "error"
            message = "Brak skinow dla broni $weapon w bazie."
        }
    }

    $query      = $skinQuery.Trim()
    $queryLower = $query.ToLowerInvariant()

    # 1) Dokladne dopasowanie case-insensitive
    $exactCI = $weaponSkins | Where-Object {
        $_.skin.Trim().ToLowerInvariant() -eq $queryLower
    }

    if ($exactCI.Count -eq 1) {
        return @{
            status = "ok"
            skin   = $exactCI[0]
        }
    }

    # 2) Czesciowe dopasowanie (contains), case-insensitive
    $matches = $weaponSkins | Where-Object {
        $_.skin.Trim().ToLowerInvariant() -like ("*" + $queryLower + "*")
    }

    if ($matches.Count -eq 1) {
        return @{
            status = "ok"
            skin   = $matches[0]
        }
    }

    if ($matches.Count -gt 1) {
        return @{
            status  = "multi"
            matches = $matches
            message = "Znaleziono wiele dopasowan. Doprecyzuj nazwe skina."
        }
    }

    return @{
        status  = "error"
        message = "Nie znaleziono skina dla zapytania: $query"
    }
}

Export-ModuleMember -Function Find-SkinsByWeapon, Resolve-SkinName
