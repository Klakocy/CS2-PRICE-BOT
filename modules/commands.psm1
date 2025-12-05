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
            # track all -> wlacz wszystkie zapisane
            if ($parts.Count -eq 2 -and $parts[1].ToLower() -eq "all") {
                $ctx = $Global:CS2BotContext
                $res = Start-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
                break
            }

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

            # stop by index, e.g. "stop 2"
            if ($parts.Count -eq 2) {
                [int]$idx = 0
                if ([int]::TryParse($parts[1], [ref]$idx) -and $idx -gt 0) {
                    $res = Stop-Tracking -weapon "" -skin "" -wear "" -trackedFile $ctx.TrackedFile -Index $idx
                    if ($res.status -eq "ok") {
                        Write-Host $res.message
                    } else {
                        Write-Host ("Error: {0}" -f $res.message)
                    }
                } else {
                    Write-Host "Usage: stop weapon skin wear  |  stop all  |  stop <index>"
                }
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
                $idx = if ($t.PSObject.Properties.Match("index").Count -gt 0) { $t.index } else { "-" }
                Write-Host ("  {0}. {1} | {2} ({3}) every {4}s [{5}]" -f $idx, $t.weapon, $t.skin, $t.wear, $t.interval, $state)
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

        "delete" {
            $ctx = $Global:CS2BotContext
            if ($parts.Count -ne 2) {
                Write-Host "Usage: delete <index>"
                break
            }
            $arg = $parts[1].ToLower()
            if ($arg -eq "all") {
                $res = Delete-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                    $ans = Read-Host "Also clear history.txt? (y/n)"
                    if ($ans -and $ans.Trim().ToLower() -in @("y", "yes")) {
                        "" | Set-Content -Path $ctx.HistoryFile -Encoding UTF8
                        Write-Host "History cleared."
                    }
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            } else {
                [int]$delIdx = 0
                if (-not [int]::TryParse($parts[1], [ref]$delIdx)) {
                    Write-Host "Usage: delete <index>"
                    break
                }
                $res = Delete-Tracking -Index $delIdx -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            }
            break
        }

        "del" {
            $ctx = $Global:CS2BotContext
            if ($parts.Count -ne 2) {
                Write-Host "Usage: del <index>"
                break
            }
            $arg = $parts[1].ToLower()
            if ($arg -eq "all") {
                $res = Delete-AllTracking -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                    $ans = Read-Host "Also clear history.txt? (y/n)"
                    if ($ans -and $ans.Trim().ToLower() -in @("y", "yes")) {
                        "" | Set-Content -Path $ctx.HistoryFile -Encoding UTF8
                        Write-Host "History cleared."
                    }
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            } else {
                [int]$delIdx = 0
                if (-not [int]::TryParse($parts[1], [ref]$delIdx)) {
                    Write-Host "Usage: del <index>"
                    break
                }
                $res = Delete-Tracking -Index $delIdx -trackedFile $ctx.TrackedFile
                if ($res.status -eq "ok") {
                    Write-Host $res.message
                } else {
                    Write-Host ("Error: {0}" -f $res.message)
                }
            }
            break
        }

        default {
            Write-Host ("Unknown command: {0}" -f $cmd)
        }
    }
}

Export-ModuleMember -Function Handle-Command
