# =========================
# main.ps1 - BOT
# =========================
# Upewnij sie, ze PowerShell dziala w UTF-8, np:
# chcp 65001

$ErrorActionPreference = "Stop"

# Ustal sciezki
$scriptRoot   = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulesPath  = Join-Path $scriptRoot "modules"
$dataPath     = Join-Path $scriptRoot "data"
$skinListFile = Join-Path $dataPath  "skinlist.txt"
$trackedFile  = Join-Path $dataPath  "tracked.json"
$historyFile  = Join-Path $dataPath  "history.txt"
$demonScript  = Join-Path $scriptRoot "demon.ps1"

# Upewnij sie, ze katalog data istnieje
if (-not (Test-Path $dataPath)) {
    New-Item -ItemType Directory -Path $dataPath | Out-Null
}

# Upewnij sie, ze pliki tracked.json i history.txt istnieja
if (-not (Test-Path $trackedFile)) {
    "[]" | Set-Content -Path $trackedFile -Encoding UTF8
}
if (-not (Test-Path $historyFile)) {
    "" | Set-Content -Path $historyFile -Encoding UTF8
}

# Import modułów
Import-Module (Join-Path $modulesPath "utils.psm1")    -Force
Import-Module (Join-Path $modulesPath "skinlist.psm1") -Force
Import-Module (Join-Path $modulesPath "search.psm1")   -Force
Import-Module (Join-Path $modulesPath "prices.psm1")   -Force
Import-Module (Join-Path $modulesPath "tracker.psm1")  -Force
Import-Module (Join-Path $modulesPath "commands.psm1") -Force

function Get-DemonProcess {
    try {
        $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like "*demon.ps1*" }
        return $procs
    } catch {
        return $null
    }
}

function Start-Demon {
    param(
        [string]$DemonScriptPath
    )
    $existing = Get-DemonProcess
    if ($null -ne $existing -and $existing.Count -gt 0) {
        Write-Host "Demon juz dziala (PID: $($existing.ProcessId -join ', '))."
        return
    }

    Write-Host "Uruchamiam demona cen..."
    $psiArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$DemonScriptPath`""
    )

    try {
        Start-Process powershell -ArgumentList $psiArgs -WindowStyle Minimized | Out-Null
        Write-Host "Demon zostal uruchomiony."
    } catch {
        Write-Host "Blad podczas uruchamiania demona: $($_.Exception.Message)"
    }
}

# Zaladuj liste skinow
if (-not (Test-Path $skinListFile)) {
    Write-Host "Brak pliku data\skinlist.txt. Dodaj plik z lista skinow i uruchom ponownie."
    exit 1
}

try {
    $skinData = Load-SkinList -file $skinListFile
} catch {
    Write-Host "Nie udalo sie wczytac skinlist.txt: $($_.Exception.Message)"
    exit 1
}

# Ustaw globalny kontekst dostepny w modulach
$Global:CS2BotContext = @{
    SkinData    = $skinData
    SkinListFile = $skinListFile
    TrackedFile = $trackedFile
    HistoryFile = $historyFile
    DataPath    = $dataPath
}

# Uruchom demona jesli trzeba
Start-Demon -DemonScriptPath $demonScript

# Powitanie
Write-Host "==============================="
Write-Host "   CS2 PRICE BOT - KONSOLE"
Write-Host "==============================="
Write-Host ""
Write-Host "Dostepne komendy (wpisz help aby zobaczyc wiecej):"
Write-Host "  help"
Write-Host "  skins weapon"
Write-Host "  track weapon skin wear [sekundy]"
Write-Host "  stop weapon skin wear"
Write-Host "  stop all"
Write-Host "  list"
Write-Host "  history"
Write-Host ""
Write-Host "Aby wyjsc wpisz: exit lub quit"
Write-Host ""

# Petla glowna
while ($true) {
    $line = Read-Host "cs2-bot"

    if ([string]::IsNullOrWhiteSpace($line)) {
        continue
    }

    if ($line -in @("exit", "quit")) {
        Write-Host "Wylaczanie bota..."
        break
    }

    try {
        Handle-Command -commandLine $line
    } catch {
        Write-Host "Blad podczas przetwarzania komendy: $($_.Exception.Message)"
    }
}

