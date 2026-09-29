function New-HPUpdateHistoryRecord {
    param(
        [Parameter(Mandatory)][psobject]$Package,
        [Parameter(Mandatory)][psobject]$Result
    )

    [pscustomobject]@{
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        Status = if ($Result.Success) { 'Success' } else { 'Failed' }
        SoftpaqID = [string]$Package.SoftpaqID
        PackageID = [string]$Package.PackageID
        Title = [string]$Package.Title
        Version = [string]$Package.Version
        Category = [string]$Package.Category
        Type = [string]$Package.Type
        ReleaseType = [string]$Package.ReleaseType
        ExitCode = $Result.ExitCode
        RebootRequired = [bool]$Result.RebootRequired
        PendingAction = [string]$Result.PendingAction
        ComputerName = [Environment]::MachineName
        UserName = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        Message = [string]$Result.FailureReason
        PackageHash = [string]$Package.Sha256
        RuntimeSeconds = [math]::Round(([timespan]$Result.Runtime).TotalSeconds, 3)
    }
}

function Write-HPUpdateHistorySession {
    param(
        [Parameter(Mandatory)][object[]]$Records,
        [string]$HistoryPath = (Get-HPUpdatePath -Name History)
    )

    if (-not $Records.Count) { return }
    $null = New-Item -Path $HistoryPath -ItemType Directory -Force
    $historyFile = Join-Path $HistoryPath "InstallHist-$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString('N')).json"
    $temporaryFile = "$historyFile.tmp"
    try {
        @($Records) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporaryFile -Encoding UTF8
        Move-Item -LiteralPath $temporaryFile -Destination $historyFile -Force
    }
    finally {
        Remove-Item -LiteralPath $temporaryFile -Force -ErrorAction SilentlyContinue
    }
    $historyFile
}