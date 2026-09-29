function Invoke-HPUpdateDownload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [uri]$Proxy,
        [pscredential]$ProxyCredential,
        [switch]$ProxyUseDefaultCredentials,
        [switch]$ShowProgress
    )

    Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
    $bitsParameters = @{ Source = $Source.AbsoluteUri; Destination = $Destination; TransferType = 'Download'; Priority = 'Foreground'; ErrorAction = 'Stop' }
    if ($Proxy) { $bitsParameters.ProxyUsage = 'Override'; $bitsParameters.ProxyList = @($Proxy) }
    if ($ProxyCredential -and -not $ProxyUseDefaultCredentials) { $bitsParameters.ProxyCredential = $ProxyCredential }
    if (-not $ShowProgress) { Start-BitsTransfer @bitsParameters; return }

    $job = Start-BitsTransfer @bitsParameters -Asynchronous
    $activity = "Downloading $([IO.Path]::GetFileName($Destination))"
    try {
        do {
            $job = Get-BitsTransfer -JobId $job.JobId -ErrorAction Stop
            $percent = if ($job.BytesTotal -gt 0) { [int][math]::Min(100, (100 * $job.BytesTransferred / $job.BytesTotal)) } else { 0 }
            $status = if ($job.BytesTotal -gt 0) { '{0:N1} of {1:N1} MB' -f ($job.BytesTransferred / 1MB), ($job.BytesTotal / 1MB) } else { 'Connecting...' }
            Write-Progress -Activity $activity -Status $status -PercentComplete $percent
            if ($job.JobState -in @('Transferred', 'Error', 'Cancelled')) { break }
            [Threading.Thread]::Sleep(250)
        } while ($true)
        if ($job.JobState -ne 'Transferred') { throw "Download failed ($($job.JobState)): $($job.ErrorDescription)" }
        Complete-BitsTransfer -BitsJob $job -ErrorAction Stop
        $job = $null
    }
    finally {
        Write-Progress -Activity $activity -Completed
        if ($job) { Remove-BitsTransfer -BitsJob $job -ErrorAction SilentlyContinue }
    }
}