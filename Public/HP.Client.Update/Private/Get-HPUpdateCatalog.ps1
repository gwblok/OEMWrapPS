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

    [pscustomobject]@{
        Family = $family
        Version = $version
        Architecture = if ([Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' }
    }
}

function Get-HPUpdateCatalogProfiles {
    param([Parameter(Mandatory)][psobject]$OperatingSystem)

    $profiles = @{
        win10 = @(
            @{ Version = '22H2'; BuildNumber = '19045' }, @{ Version = '21H2'; BuildNumber = '19044' },
            @{ Version = '21H1'; BuildNumber = '19043' }, @{ Version = '2009'; BuildNumber = '19042' },
            @{ Version = '2004'; BuildNumber = '19041' }, @{ Version = '1909'; BuildNumber = '18363' },
            @{ Version = '1903'; BuildNumber = '18362' }, @{ Version = '1809'; BuildNumber = '17763' }
        )
        win11 = @(
            @{ Version = '25H2'; BuildNumber = '26200' }, @{ Version = '24H2'; BuildNumber = '26100' },
            @{ Version = '23H2'; BuildNumber = '22631' }, @{ Version = '22H2'; BuildNumber = '22621' },
            @{ Version = '21H2'; BuildNumber = '22000' }
        )
    }
    $familyProfiles = @($profiles[$OperatingSystem.Family])
    if (-not $familyProfiles.Count) { throw "HP catalog profiles are unavailable for '$($OperatingSystem.Family)'." }

    $requestedVersionIsKnown = $OperatingSystem.Version -in @($familyProfiles.Version)
    $includeCandidate = -not $requestedVersionIsKnown
    foreach ($profile in $familyProfiles) {
        if ($profile.Version -eq $OperatingSystem.Version) { $includeCandidate = $true }
        if (-not $includeCandidate) { continue }
        [pscustomobject]@{
            Family = $OperatingSystem.Family
            Version = $profile.Version
            BuildNumber = $profile.BuildNumber
            Architecture = $OperatingSystem.Architecture
            RequestedVersion = $OperatingSystem.Version
            IsFallback = $profile.Version -ne $OperatingSystem.Version
        }
    }
}

function Get-HPUpdateCatalog {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][psobject]$OperatingSystem,
        [switch]$UseCachedCatalog,
        [string]$CatalogDirectory = (Get-HPUpdatePath -Name Catalogs)
    )

    $null = New-Item -Path $CatalogDirectory -ItemType Directory -Force
    foreach ($candidate in @(Get-HPUpdateCatalogProfiles -OperatingSystem $OperatingSystem)) {
        $catalogFile = Join-Path $CatalogDirectory "$Platform-$($candidate.Family)-$($candidate.Version).json"
        $catalog = $null
        if ($UseCachedCatalog -and (Test-Path -LiteralPath $catalogFile -PathType Leaf)) {
            try { $catalog = Get-Content -LiteralPath $catalogFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
            catch { Write-Warning "Could not read cached HP update catalog '$catalogFile': $($_.Exception.Message)" }
        }
        if (-not $catalog) {
            $uri = "https://workforceexperience.hp.com/services/srs/api/1.1/recommendations/?system-id=$Platform&os-arch=$($candidate.Architecture)&os-build-number=$($candidate.BuildNumber)&is-ltsc=false"
            try { $catalog = Invoke-RestMethod -Uri $uri -Method Get -ErrorAction Stop }
            catch { Write-Verbose "HP catalog request failed for $($candidate.Family) $($candidate.Version): $($_.Exception.Message)"; continue }
            $catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $catalogFile -Encoding UTF8
        }
        if (@($catalog.softpaqs).Count) {
            $catalog | Add-Member -NotePropertyName SelectedOperatingSystem -NotePropertyValue $candidate -Force
            if ($candidate.IsFallback) { Write-Verbose "Using HP catalog for $($candidate.Family) $($candidate.Version) because $($candidate.RequestedVersion) is unavailable." }
            return $catalog
        }
    }
    throw "HP did not return a catalog for platform $Platform on $($OperatingSystem.Family) $($OperatingSystem.Version) or any older supported release."
}