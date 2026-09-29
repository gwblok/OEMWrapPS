function Get-HPDriverPackLatest {
    [CmdletBinding()]
    param(
        [string]$Platform,
        [switch]$URL,
        [switch]$Download
    )

    $platformId = if ($Platform) { $Platform } else { (Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop).Product }
    $osList = @(Get-HPOSSupport -Platform $platformId)
    foreach ($operatingSystem in 'Windows 11', 'Windows 10') {
        $osNumber = if ($operatingSystem -eq 'Windows 11') { '11.0' } else { '10.0' }
        $versions = @($osList | Where-Object { $_.OSDescription -match [regex]::Escape($operatingSystem) } | Select-Object -ExpandProperty OSReleaseIdDisplay -Unique | Sort-Object -Descending)
        foreach ($version in $versions) {
            try { $driverPack = @(Get-HPSoftPaqItems -Platform $platformId -OSVersion $version -OS $osNumber | Where-Object { $_.Category -match 'Driver Pack' } | Select-Object -First 1) }
            catch { continue }
            if ($driverPack) { break }
        }
        if ($driverPack) { break }
    }
    if (-not $driverPack) { Write-Verbose "No driver pack found for platform '$platformId'."; return $false }
    $driverPack = $driverPack[0]
    $downloadUrl = if ($driverPack.URL -match '^https?://') { $driverPack.URL } else { "https://$($driverPack.URL)" }
    if ($Download) {
        $paths = Get-OEMHPIAPaths
        $null = New-Item -Path $paths.DriverPacks -ItemType Directory -Force
        $downloadPath = Join-Path $paths.DriverPacks "$($driverPack.id).exe"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath -UseBasicParsing -ErrorAction Stop
        return Get-Item -LiteralPath $downloadPath
    }
    if ($URL) { return $downloadUrl }
    $driverPack
}