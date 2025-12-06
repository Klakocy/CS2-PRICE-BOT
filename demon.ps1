# =========================
# demon.ps1 - PRICE DEMON
# =========================

$ErrorActionPreference = "Stop"

$scriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptRoot "modules"
$dataPath    = Join-Path $scriptRoot "data"
$trackedFile = Join-Path $dataPath "tracked.json"
$historyFile = Join-Path $dataPath "history.txt"
$priceCacheFile = Join-Path $dataPath "pricecache.json"

# Import modules
Import-Module (Join-Path $modulesPath "utils.psm1")   -Force
Import-Module (Join-Path $modulesPath "prices.psm1")  -Force
Import-Module (Join-Path $modulesPath "tracker.psm1") -Force

function Get-JitteredSeconds {
    param(
        [int]$BaseSeconds,
        [double]$Percent = 0.2  # ±20%
    )
    $min = [Math]::Max(1, [int]([double]$BaseSeconds * (1 - $Percent)))
    $max = [Math]::Max($min + 1, [int]([double]$BaseSeconds * (1 + $Percent)))
    return (Get-Random -Minimum $min -Maximum ($max + 1))
}

function Load-PriceCache {
    param([string]$file)
    if (-not (Test-Path $file)) { return @{} }
    $content = Get-Content -Raw -Path $file -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { return @{} }
    try {
        $obj = $content | ConvertFrom-Json
        if ($obj -is [hashtable]) { return $obj }
        if ($obj -is [System.Collections.IDictionary]) { return @{} + $obj }
        if ($obj -is [PSCustomObject]) {
            $ht = @{}
            foreach ($p in $obj.PSObject.Properties) { $ht[$p.Name] = $p.Value }
            return $ht
        }
        return @{}
    } catch { return @{} }
}

function Save-PriceCache {
    param(
        [string]$file,
        $cache
    )
    ($cache | ConvertTo-Json -Depth 5) | Set-Content -Path $file -Encoding UTF8
}

# Simple mutex so only one demon runs
$mutexName  = "Global\CS2_PRICE_DEMON_MUTEX"
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)

if (-not $createdNew) {
    Write-Host "Demon already running - exiting."
    return
}

Write-Host "========================================="
Write-Host "      CS2 PRICE DEMON - STARTED"
Write-Host "========================================="
Write-Host "Tracked file : $trackedFile"
Write-Host "History file : $historyFile"
Write-Host ""

try {
    if (-not (Test-Path $priceCacheFile)) {
        "{}" | Set-Content -Path $priceCacheFile -Encoding UTF8
    }
    $priceCache = Load-PriceCache -file $priceCacheFile
    if ($priceCache -isnot [hashtable]) { $priceCache = @{} + $priceCache }
    if (-not $priceCache) { $priceCache = @{} }
    $rateBackoff = 60
    $rateBackoffMax = 600

    while ($true) {

        $tracked = Load-Tracked -file $trackedFile
        if (-not $tracked) { $tracked = @() }

        $active = $tracked | Where-Object { $_.active -eq $true }

        if (-not $active -or $active.Count -eq 0) {
            Write-Host "[DEMON] No active trackings. Sleeping 30 seconds..."
            Start-Sleep -Seconds 30
            continue
        }

        $minInterval = [int]::MaxValue

        foreach ($t in $active) {

            $weapon   = $t.weapon
            $skin     = $t.skin
            $wear     = $t.wear
            $fullName = "{0} | {1} ({2})" -f $weapon, $skin, $wear
            $cacheKey = "{0}|{1}|{2}" -f $weapon, $skin, $wear

            $interval = [int]$t.interval
            if ($interval -le 0) { $interval = 60 }
            if ($interval -lt $minInterval) { $minInterval = $interval }

            Write-Host ("[DEMON] Getting price for: {0}" -f $fullName)

            try {
                $price = Get-SteamPrice -weapon $weapon -skin $skin -wear $wear -currency "PLN"

                if ($price -and $price.rateLimited) {
                    if ($priceCache.ContainsKey($cacheKey)) {
                        $cached = $priceCache[$cacheKey]
                        $msgParts = @()
                        if ($cached.lowest) { $msgParts += ("Lowest={0}" -f $cached.lowest) }
                        if ($cached.median) { $msgParts += ("Median={0}" -f $cached.median) }
                        if ($cached.volume) { $msgParts += ("Volume={0}" -f $cached.volume) }
                        $msgParts += ("ts={0}" -f $cached.timestamp)
                        $msg = ($msgParts -join " ; ")
                        Write-History -historyFile $historyFile -status "RATE_LIMIT_CACHE" -fullName $fullName -message $msg
                        Write-Host ("[DEMON] RATE LIMIT for {0}, using cached: {1}" -f $fullName, $msg)
                    } else {
                        Write-History -historyFile $historyFile -status "RATE_LIMIT" -fullName $fullName -message "HTTP 429 from Steam (no cache)"
                        Write-Host ("[DEMON] RATE LIMIT for {0}. No cache." -f $fullName)
                    }
                    $sleepSec = Get-JitteredSeconds -BaseSeconds $rateBackoff -Percent 0.25
                    Write-Host ("[DEMON] Backing off {0}s (base {1}s)." -f $sleepSec, $rateBackoff)
                    Start-Sleep -Seconds $sleepSec
                    $rateBackoff = [Math]::Min($rateBackoff * 2, $rateBackoffMax)
                    continue
                }

                if ($null -ne $price) {
                    $msgParts = @()
                    if ($price.lowest) { $msgParts += ("Lowest={0} PLN" -f $price.lowest) }
                    if ($price.median) { $msgParts += ("Median={0} PLN" -f $price.median) }
                    if ($price.volume) { $msgParts += ("Volume={0}" -f $price.volume) }

                    $msg = ($msgParts -join " ; ")
                    if ([string]::IsNullOrWhiteSpace($msg)) {
                        $msg = "Price data returned but no fields (lowest/median/volume) were parsed."
                    }

                    Write-History -historyFile $historyFile -status "OK" -fullName $price.fullName -message $msg
                    Write-Host ("[DEMON] OK: {0}" -f $msg)

                    # zapisz do cache
                    $priceCache[$cacheKey] = @{
                        lowest = $price.lowest
                        median = $price.median
                        volume = $price.volume
                        timestamp = (Get-Date).ToString("s")
                    }
                    Save-PriceCache -file $priceCacheFile -cache $priceCache
                    # reset backoff po sukcesie
                    $rateBackoff = 60
                }
                else {
                    Write-History -historyFile $historyFile -status "ERROR" -fullName $fullName -message "No data from Steam API"
                    Write-Host ("[DEMON] ERROR: no data for {0}" -f $fullName)
                }
            }
            catch {
                $errMsg = $_.Exception.Message
                Write-History -historyFile $historyFile -status "ERROR" -fullName $fullName -message ("Exception: {0}" -f $errMsg)
                Write-Host ("[DEMON] EXCEPTION: {0}" -f $errMsg)
            }
        }

        if ($minInterval -eq [int]::MaxValue) {
            $minInterval = 60
        }

        $sleepNormal = Get-JitteredSeconds -BaseSeconds $minInterval -Percent 0.2
        Write-Host ("[DEMON] Sleeping {0} seconds..." -f $sleepNormal)
        Start-Sleep -Seconds $sleepNormal
    }
}
finally {
    if ($mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
