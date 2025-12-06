# =========================
# modules\prices.psm1
# =========================

function Get-WearName {
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

function Get-SteamPrice {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$weapon,

        [Parameter(Mandatory = $true)]
        [string]$skin,

        [Parameter(Mandatory = $true)]
        [string]$wear,

        [string]$currency = "PLN"
    )

    # Steam API używa kodu 6 dla PLN
    $currencyCode = 6
    if ($currency -ne "PLN") {
        # W przyszłości można dodać mapowanie innych walut
        $currencyCode = 6
    }

    $fullName = if ([string]::IsNullOrWhiteSpace($wear)) { "$weapon | $skin" } else { "$weapon | $skin ($wear)" }

    # Zakoduj nazwę do URL
    $encodedName = [System.Uri]::EscapeDataString($fullName)

    $url = "https://steamcommunity.com/market/priceoverview/?appid=730&currency=$currencyCode&market_hash_name=$encodedName"

    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -UseBasicParsing -ErrorAction Stop -Headers @{
            "User-Agent" = "Mozilla/5.0"
        }

        if (-not $resp.success) {
            return $null
        }

        $lowest = $null
        $median = $null
        $volume = $null

        if ($resp.lowest_price) {
            # Ceny przychodzą np. "22,50 zl" lub "zł22,50"
            $lp = ($resp.lowest_price -replace "[^0-9,\.]", "").Replace(",", ".")
            [decimal]::TryParse($lp, [ref]$null) | Out-Null
            $lowest = $lp
        }

        if ($resp.median_price) {
            $mp = ($resp.median_price -replace "[^0-9,\.]", "").Replace(",", ".")
            [decimal]::TryParse($mp, [ref]$null) | Out-Null
            $median = $mp
        }

        if ($resp.volume) {
            $volume = $resp.volume
        }

        return @{
            fullName = $fullName
            lowest   = $lowest
            median   = $median
            volume   = $volume
        }
    } catch {
        # ObsĹ‚uga limitu zapytaĹ„ (429)
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 429) {
            # Zwroc specjalny status do demona, ĹĽeby wiedzieÄ‡, ĹĽe to rate limit
            return @{
                fullName = $fullName
                lowest   = $null
                median   = $null
                volume   = $null
                rateLimited = $true
            }
        }
        return $null
    }
}

Export-ModuleMember -Function Get-WearName, Get-SteamPrice
