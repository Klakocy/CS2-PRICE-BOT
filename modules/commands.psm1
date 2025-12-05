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
    Write-Host "  skins weapon               - list skins for given weapon"
    Write-Host "  track weapon skin wear [seconds]"
    Write-Host "       wear: 1-5 (1=FN, 5=BS)"
    Write-Host "  stop weapon skin wear      - disable tracking"
    Write-Host "  stop all                   - disable all trackings"
    Write-Host "  list                       - show current trackings"
    Write-Host "  history                    - show last history entries"
}

function Show-Skins {
    param(
        [string]$weapon
    )

    $ctx = $Global:CS2BotContext
    $skinData = $ctx.SkinData
    $normalizedWeapon = Normalize-WeaponName -weapon $weapon

    $skins = Find-SkinsByWeapon -weapon $normalizedWeapon -skinsByWeapon $skinData.skinsByWeapon

    if (-not $skins -or $skins.Count -eq 0) {
        Write-Host ("No skins found for weapon: {0}" -f $normalizedWeapon)
        return
    }

    Write-Host ("Skins for {0}:" -f $normalizedWeapon)
    foreach ($s in $skins) {
        Write-Host ("  - {0} [{1}] ({2})" -f $s.skin, $s.rarity, $s.collection)
    }
}

function Parse-TrackCommand {
    param(
        [string[]]$parts
    )

    if ($parts.Count -lt 4) {
        return @{
            ok      = $false
            message = "Usage: track weapon skin wear [seconds]"
        }
    }

    $weapon = $parts[1]

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

    # first number is wear
    $wearIndex = $nums[0].index
    $wearNum   = $nums[0].value

    # optional interval
    $interval = 60
    if ($nums.Count -gt 1) {
        $interval = $nums[1].value
    } elseif ($parts.Count -gt ($wearIndex + 1)) {
        [int]$tmp2 = 0
        if ([int]::TryParse($parts[$wearIndex + 1], [ref]$tmp2)) {
            $interval = $tmp2
        }
    }

    if ($interval -le 0) { $interval = 60 }

    # skin name is everything between weapon and wear
    $skinParts = $parts[2..($wearIndex - 1)]
    $skinQuery = ($skinParts -join " ")

    return @{
        ok        = $true
        weapon    = $weapon
        skinQuery = $skinQuery
        wearNum   = $wearNum
        interval  = $interval
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
                Show-Skins -weapon $parts[1]
            }
        }

        "track" {
            $parsed = Parse-TrackCommand -parts $parts

            if (-not $parsed.ok) {
                Write-Host $parsed.message
                break
            }

            $ctx = $Global:CS2BotContext

            $res = Add-Tracking `
                -weapon      $parsed.weapon `
                -skinQuery   $parsed.skinQuery `
                -wearNum     $parsed.wearNum `
                -interval    $parsed.interval `
                -trackedFile $ctx.TrackedFile `
                -skinData    $ctx.SkinData

            switch ($res.status) {
                "ok"    { Write-Host $res.message }
                "multi" { Write-Host $res.message }
                "error" { Write-Host ("Error: {0}" -f $res.message) }
                default { Write-Host "Unknown status from Add-Tracking." }
            }
        }

        "stop" {
            $ctx = $Global:CS2BotContext

            if ($parts.Count -eq 2 -and $parts[1].ToLower() -eq "all") {
                $res = Stop-Tracking -weapon "" -skin "all" -wear "" -trackedFile $ctx.TrackedFile
                Write-Host $res.message
                break
            }

            if ($parts.Count -lt 4) {
                Write-Host "Usage: stop weapon skin wear"
                break
            }

            $weapon = $parts[1]
            $wearRaw = $parts[-1]

            # allow numeric wear, e.g. "3" => "Field-Tested"
            $wearName = $wearRaw
            [int]$wearNum = 0
            if ([int]::TryParse($wearRaw, [ref]$wearNum)) {
                $wearName = Wear-FromNumber -num $wearNum
            }

            $skinParts = $parts[2..($parts.Count - 2)]
            $skinName  = ($skinParts -join " ")

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
                Write-Host ("  - {0} | {1} ({2}) every {3}s [{4}]" -f $t.weapon, $t.skin, $t.wear, $t.interval, $state)
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

        default {
            Write-Host ("Unknown command: {0}" -f $cmd)
        }
    }
}

Export-ModuleMember -Function Handle-Command
