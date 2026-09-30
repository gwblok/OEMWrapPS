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

    $argumentAttempts = @(
        "/s /e /f `"$HPIAInstallPath`"",
        "/s /f `"$HPIAInstallPath`" /e",
        '/s /f .\ /e'
    )
    $lastExitCode = $null
    foreach ($arguments in $argumentAttempts) {
        $process = Start-Process -FilePath $downloadPath -WorkingDirectory $HPIAInstallPath -ArgumentList $arguments -NoNewWindow -PassThru -Wait -ErrorAction Stop
        $lastExitCode = $process.ExitCode
        if ($lastExitCode -eq 0 -and (Test-Path -LiteralPath $executablePath -PathType Leaf)) { break }
    }

    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
        $nestedExecutable = @(Get-ChildItem -LiteralPath $HPIAInstallPath -Filter 'HPImageAssistant.exe' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        if ($nestedExecutable) {
            Copy-Item -LiteralPath $nestedExecutable.FullName -Destination $executablePath -Force
        }
    }

    if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) { throw "HPIA extraction failed with exit code $lastExitCode." }
    [pscustomobject]@{ Version = (Get-Item -LiteralPath $executablePath).VersionInfo.FileVersion; InstallPath = $HPIAInstallPath; ExecutablePath = $executablePath; Updated = $true }
}