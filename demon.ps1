# =========================
# demon.ps1 - PRICE DEMON
# =========================

$ErrorActionPreference = "Stop"

$scriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath = Join-Path $scriptRoot "modules"
$dataPath    = Join-Path $scriptRoot "data"
$trackedFile = Join-Path $dataPath "tracked.json"
$historyFile = Join-Path $dataPath "history.txt"

# Import modules
Import-Module (Join-Path $modulesPath "utils.psm1")   -Force
Import-Module (Join-Path $modulesPath "prices.psm1")  -Force
Import-Module (Join-Path $modulesPath "tracker.psm1") -Force

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

            $interval = [int]$t.interval
            if ($interval -le 0) { $interval = 60 }
            if ($interval -lt $minInterval) { $minInterval = $interval }

            Write-Host ("[DEMON] Getting price for: {0}" -f $fullName)

            try {
                $price = Get-SteamPrice -weapon $weapon -skin $skin -wear $wear -currency "PLN"

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

        Write-Host ("[DEMON] Sleeping {0} seconds..." -f $minInterval)
        Start-Sleep -Seconds $minInterval
    }
}
finally {
    if ($mutex) {
        $mutex.ReleaseMutex() | Out-Null
        $mutex.Dispose()
    }
}
