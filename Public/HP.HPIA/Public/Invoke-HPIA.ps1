function Invoke-HPIA {
    [CmdletBinding()]
    param(
        [ValidateSet('Analyze', 'DownloadSoftPaqs')][string]$Operation = 'Analyze',
        [ValidateSet('All', 'BIOS', 'Drivers', 'Software', 'Firmware', 'Accessories')][string[]]$Category = @('All'),
        [ValidateSet('All', 'Critical', 'Recommended', 'Routine')][string]$Selection = 'All',
        [ValidateSet('List', 'Download', 'Extract', 'Install', 'UpdateCVA')][string]$Action = 'List',
        [string]$HPIAInstallPath = (Get-OEMHPIAPaths).Install,
        [string]$ReferenceFile,
        [switch]$SilentMode,
        [switch]$NoninteractiveMode
    )

    $paths = Get-OEMHPIAPaths
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPath = Join-Path $paths.Reports $timestamp
    $logPath = Join-Path $paths.Logs "$timestamp.log"
    $null = New-Item -Path $paths.Downloads, $paths.Logs, $reportPath -ItemType Directory -Force
    $installation = Install-HPIA -HPIAInstallPath $HPIAInstallPath
    $arguments = "/Operation:$Operation /Category:$($Category -join ',') /Selection:$Selection /Action:$Action /Debug /ReportFolder:$reportPath /IgnoreGenericOsError"
    if ($SilentMode) { $arguments += ' /Silent' } elseif ($NoninteractiveMode) { $arguments += ' /Noninteractive' }
    if ($ReferenceFile) { $arguments += " /ReferenceFile:`"$ReferenceFile`"" }
    Write-OEMHPIALog -LogPath $logPath -Component 'HPIA' -Message $arguments
    $process = Start-Process -FilePath $installation.ExecutablePath -WorkingDirectory $paths.Downloads -ArgumentList $arguments -NoNewWindow -PassThru -Wait -ErrorAction Stop
    $rebootRequired = $process.ExitCode -eq 3010
    $success = $process.ExitCode -in @(0, 256, 257, 3010, 4104)
    Write-OEMHPIALog -LogPath $logPath -Component 'HPIA' -Type $(if ($success) { 1 } else { 3 }) -Message "HPIA exited with code $($process.ExitCode)."
    [pscustomobject]@{ ExitCode = $process.ExitCode; Success = $success; RebootRequired = $rebootRequired; ReportPath = $reportPath; LogPath = $logPath; ExecutablePath = $installation.ExecutablePath }
}