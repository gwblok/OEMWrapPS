function Install-HPIA {
    [CmdletBinding()]
    param([string]$HPIAInstallPath = (Get-OEMHPIAPaths).Install)

    $paths = Get-OEMHPIAPaths
    $latest = Get-HPIALatestVersion
    $null = New-Item -Path $HPIAInstallPath, $paths.Downloads -ItemType Directory -Force
    $executablePath = Join-Path $HPIAInstallPath 'HPImageAssistant.exe'
    if (Test-Path -LiteralPath $executablePath -PathType Leaf) {
        $installedVersion = (Get-Item -LiteralPath $executablePath).VersionInfo.FileVersion
        if ($installedVersion -match [regex]::Escape($latest.Version)) { return [pscustomobject]@{ Version = $installedVersion; InstallPath = $HPIAInstallPath; ExecutablePath = $executablePath; Updated = $false } }
    }
    $downloadPath = Join-Path $paths.Downloads $latest.FileName
    Invoke-WebRequest -Uri $latest.DownloadUri -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
    $signature = Get-AuthenticodeSignature -LiteralPath $downloadPath -ErrorAction Stop
    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) { throw "HPIA download signature validation failed: $($signature.StatusMessage)" }
    $process = Start-Process -FilePath $downloadPath -WorkingDirectory $HPIAInstallPath -ArgumentList '/s /f .\ /e' -NoNewWindow -PassThru -Wait -ErrorAction Stop
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $executablePath -PathType Leaf)) { throw "HPIA extraction failed with exit code $($process.ExitCode)." }
    [pscustomobject]@{ Version = (Get-Item -LiteralPath $executablePath).VersionInfo.FileVersion; InstallPath = $HPIAInstallPath; ExecutablePath = $executablePath; Updated = $true }
}