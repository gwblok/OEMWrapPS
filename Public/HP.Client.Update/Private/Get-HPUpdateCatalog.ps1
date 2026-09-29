function Get-HPUpdateDeviceInfo {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    if ($computerSystem.Manufacturer -notmatch '^(HP|Hewlett-Packard)') {
        throw "Get-HPUpdate supports HP systems only. Detected '$($computerSystem.Manufacturer)'."
    }

    $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop
    $platform = ([string]$baseBoard.Product).Trim()
    if ($platform -notmatch '^[0-9A-Fa-f]{4}$') {
        throw "The device baseboard product '$platform' is not a supported HP platform ID."
    }

    [pscustomobject]@{
        Platform = $platform.ToLowerInvariant()
        Model = [string]$computerSystem.Model
    }
}

function Get-HPUpdateOperatingSystem {
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $family = if ([int]$operatingSystem.BuildNumber -ge 22000) { 'win11' } else { 'win10' }
    $version = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name DisplayVersion -ErrorAction Stop
    $buildNumbers = @{
        win10 = @{ '1809' = '17763'; '1903' = '18362'; '1909' = '18363'; '2004' = '19041'; '2009' = '19042'; '21H1' = '19043'; '21H2' = '19044'; '22H2' = '19045' }
        win11 = @{ '21H2' = '22000'; '22H2' = '22621'; '23H2' = '22631'; '24H2' = '26100'; '25H2' = '26200' }
    }
    $buildNumber = $buildNumbers[$family][$version]
    if (-not $buildNumber) { throw "HP does not provide a catalog mapping for $family $version." }

    [pscustomobject]@{
        Family = $family
        Version = $version
        BuildNumber = $buildNumber
        Architecture = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
    }
}

function Get-HPUpdateCatalog {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][psobject]$OperatingSystem,
        [switch]$UseCachedCatalog,
        [string]$CatalogDirectory = (Get-HPUpdatePath -Name Catalogs)
    )

    $catalogFile = Join-Path $CatalogDirectory "$Platform-$($OperatingSystem.Family)-$($OperatingSystem.Version).json"
    if ($UseCachedCatalog -and (Test-Path -LiteralPath $catalogFile -PathType Leaf)) {
        try { return Get-Content -LiteralPath $catalogFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch { Write-Warning "Could not read cached HP update catalog '$catalogFile': $($_.Exception.Message)" }
    }

    $uri = "https://workforceexperience.hp.com/services/srs/api/1.1/recommendations/?system-id=$Platform&os-arch=$($OperatingSystem.Architecture)&os-build-number=$($OperatingSystem.BuildNumber)&is-ltsc=false"
    $catalog = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop
    $null = New-Item -Path $CatalogDirectory -ItemType Directory -Force
    $catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $catalogFile -Encoding UTF8
    $catalog
}