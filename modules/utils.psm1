# =========================
# modules\utils.psm1
# =========================

function Write-History {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$historyFile,

        [Parameter(Mandatory = $true)]
        [string]$status,

        [Parameter(Mandatory = $true)]
        [string]$fullName,

        # message moze byc puste, wtedy damy "-"
        [Parameter(Mandatory = $false)]
        [string]$message
    )

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "-"
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp ; $status ; $fullName ; $message"
    Add-Content -Path $historyFile -Value $line -Encoding UTF8
}


function Load-Tracked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$file
    )

    if (-not (Test-Path $file)) {
        return @()
    }

    $content = Get-Content -Path $file -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    try {
        $json = $content | ConvertFrom-Json
        if ($null -eq $json) { return @() }

        if ($json -is [System.Collections.IEnumerable]) {
            return @($json)
        }

        return @($json)
    } catch {
        Write-Host "Blad podczas wczytywania tracked.json: $($_.Exception.Message)"
        return @()
    }
}

function Save-Tracked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$file,

        [Parameter(Mandatory = $true)]
        [object[]]$tracked
    )

    $json = $tracked | ConvertTo-Json -Depth 5
    Set-Content -Path $file -Value $json -Encoding UTF8
}

Export-ModuleMember -Function Write-History, Load-Tracked, Save-Tracked
