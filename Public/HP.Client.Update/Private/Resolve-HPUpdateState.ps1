function Get-HPUpdateReferenceCatalog {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][psobject]$OperatingSystem,
        [string]$CatalogDirectory = (Get-HPUpdatePath -Name Catalogs)
    )

    $architecture = if ([Environment]::Is64BitOperatingSystem) { '64' } else { '32' }
    $referenceVersion = if ($OperatingSystem.Family -eq 'win11') { "11.0.$($OperatingSystem.Version)" } else { "10.0.$($OperatingSystem.Version)" }
    $cabReferenceVersion = $referenceVersion.ToLowerInvariant()
    $referenceName = "${Platform}_${architecture}_${referenceVersion}"
    $cabReferenceName = "${Platform}_${architecture}_${cabReferenceVersion}"
    $referenceDirectory = Join-Path $CatalogDirectory 'Reference'
    $cabPath = Join-Path $referenceDirectory "$cabReferenceName.cab"
    $extractDirectory = "$cabPath.dir"
    $xmlPath = @(Get-ChildItem -LiteralPath $extractDirectory -Filter '*.xml' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)

    if (-not $xmlPath) {
        $null = New-Item -Path $referenceDirectory -ItemType Directory -Force
        Invoke-WebRequest -Uri "https://hpia.hpcloud.hp.com/ref/$Platform/$cabReferenceName.cab" -OutFile $cabPath -ErrorAction Stop
        Remove-Item -LiteralPath $extractDirectory -Recurse -Force -ErrorAction SilentlyContinue
        $null = New-Item -Path $extractDirectory -ItemType Directory -Force
        $shell = New-Object -ComObject Shell.Application
        try {
            $sourceCab = $shell.Namespace($cabPath).Items()
            $destination = $shell.Namespace($extractDirectory)
            $destination.CopyHere($sourceCab)
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$shell) | Out-Null
        }
        $xmlPath = @(Get-ChildItem -LiteralPath $extractDirectory -Filter '*.xml' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName)
    }

    if (-not $xmlPath) { throw "HP reference XML was not created from '$cabPath'." }
    $catalog = [System.Xml.XmlDocument]::new()
    $catalog.XmlResolver = $null
    $catalog.Load($xmlPath)
    $catalog
}

function Get-HPUpdateDriverInventory {
    @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceID -and $_.DriverVersion })
}

function ConvertTo-HPUpdateVersion {
    param([object]$Value)

    $match = [regex]::Match([string]$Value, '\d+(?:[.,]\d+){1,3}')
    if (-not $match.Success) { return $null }
    $version = $null
    if ([version]::TryParse(($match.Value -replace ',', '.'), [ref]$version)) { return $version }
    $null
}

function Get-HPUpdateDetailFileState {
    param(
        [Parameter(Mandatory)][psobject]$Softpaq,
        [Parameter(Mandatory)][psobject]$OperatingSystem,
        [Parameter(Mandatory)][hashtable]$FileVersionCache
    )

    $osCode = ('{0}_{1}' -f $OperatingSystem.Family.ToUpperInvariant().Replace('WIN', 'W'), $OperatingSystem.Version)
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($detailFile in @($Softpaq.detailFileInfo | Where-Object { $_.cvaOsCode -eq $osCode })) {
        $expectedVersion = ConvertTo-HPUpdateVersion "$($detailFile.majorVersion).$($detailFile.minorVersion).$($detailFile.majorBuild).$($detailFile.minorBuild)"
        if (-not $expectedVersion -or -not $detailFile.fileName) { continue }

        $cacheKey = [string]$detailFile.fileName
        if (-not $FileVersionCache.ContainsKey($cacheKey)) {
            $candidates = [System.Collections.Generic.List[object]]::new()
            $expandedPath = ([string]$detailFile.path).Replace('<WINSYSDIR>', (Join-Path $env:windir 'System32')).Replace('<DRIVERS>', (Join-Path $env:windir 'System32\drivers')).Replace('<ProgramFilesDir>', $env:ProgramFiles)
            $directPath = Join-Path $expandedPath $detailFile.fileName
            if (Test-Path -LiteralPath $directPath -PathType Leaf) {
                $candidates.Add((Get-Item -LiteralPath $directPath))
            }
            elseif ($expandedPath -match '(?i)DriverStore\\FileRepository') {
                $driverStore = Join-Path $env:windir 'System32\DriverStore\FileRepository'
                foreach ($file in (Get-ChildItem -LiteralPath $driverStore -Filter $detailFile.fileName -File -Recurse -ErrorAction SilentlyContinue)) { $candidates.Add($file) }
            }
            $FileVersionCache[$cacheKey] = @($candidates)
        }

        $files = @($FileVersionCache[$cacheKey])
        $installedVersions = @($files | ForEach-Object { ConvertTo-HPUpdateVersion $_.VersionInfo.FileVersion } | Where-Object { $_ })
        $results.Add([pscustomobject]@{
            FileName = [string]$detailFile.fileName
            ExpectedVersion = $expectedVersion
            InstalledVersions = $installedVersions
            InstalledVersion = @($installedVersions | Sort-Object -Descending | Select-Object -First 1)[0]
            FilesFound = $files.Count
            UsesDriverBinaryPath = ([string]$detailFile.path) -match '(?i)<DRIVERS>'
        })
    }
    @($results)
}

function Get-HPUpdateWindowsUpdateVersions {
    param([Parameter(Mandatory)][psobject]$Softpaq)

    @($Softpaq.windowsUpdates | Where-Object { $_ -match '(?i)SoftwareComponent' } | ForEach-Object {
        [regex]::Matches([string]$_, '\d+(?:\.\d+){1,3}') | ForEach-Object { ConvertTo-HPUpdateVersion $_.Value }
    } | Where-Object { $_ } | Sort-Object -Descending -Unique)
}

function Resolve-HPUpdateState {
    param(
        [Parameter(Mandatory)][psobject]$Softpaq,
        [Parameter(Mandatory)][object[]]$DriverInventory,
        [Parameter(Mandatory)][System.Xml.XmlDocument]$ReferenceCatalog,
        [Parameter(Mandatory)][psobject]$OperatingSystem,
        [Parameter(Mandatory)][hashtable]$FileVersionCache
    )

    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($device in @($Softpaq.devices)) {
        $deviceId = ([string]$device.matchId).Trim().Trim('*')
        if ([string]::IsNullOrWhiteSpace($deviceId)) { continue }
        $installedDevice = @($DriverInventory | Where-Object { $_.DeviceID.IndexOf($deviceId, [StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object -First 1)
        if (-not $installedDevice) { continue }
        $referenceDevice = @($ReferenceCatalog.SelectNodes('ImagePal/Devices/Device') | Where-Object { ([string]$_.DeviceID).IndexOf($deviceId, [StringComparison]::OrdinalIgnoreCase) -ge 0 } | Select-Object -First 1)
        $matches.Add([pscustomobject]@{
            DeviceName = [string]$installedDevice.DeviceName
            DeviceId = [string]$installedDevice.DeviceID
            InstalledVersion = [string]$installedDevice.DriverVersion
            ExpectedVersion = if ($referenceDevice) { [string]$referenceDevice.DriverVersion } else { '' }
            ReferenceMatched = [bool]$referenceDevice
        })
    }

    if (-not $matches.Count) { return [pscustomobject]@{ IsApplicable = $false; IsInstalled = $null; WhyApplicable = 'No supported installed device was found.'; Matches = @() } }

    $driverBinaryMatches = @($matches | Where-Object {
        $installedVersion = $null; $expectedVersion = $null
        [version]::TryParse($_.InstalledVersion, [ref]$installedVersion) -and [version]::TryParse($_.ExpectedVersion, [ref]$expectedVersion) -and $installedVersion -lt $expectedVersion
    })
    $driverCurrentMatches = @($matches | Where-Object {
        $installedVersion = $null; $expectedVersion = $null
        [version]::TryParse($_.InstalledVersion, [ref]$installedVersion) -and [version]::TryParse($_.ExpectedVersion, [ref]$expectedVersion) -and $installedVersion -ge $expectedVersion
    })
    $familyKey = @($matches.DeviceId | Sort-Object -Unique) -join '|'
    $detailFiles = @(Get-HPUpdateDetailFileState -Softpaq $Softpaq -OperatingSystem $OperatingSystem -FileVersionCache $FileVersionCache)
    $outdatedFiles = @($detailFiles | Where-Object { $_.InstalledVersion -and $_.InstalledVersion -lt $_.ExpectedVersion })
    $currentFiles = @($detailFiles | Where-Object { $_.InstalledVersion -and $_.InstalledVersion -ge $_.ExpectedVersion })
    if ($currentFiles.Count) { return [pscustomobject]@{ IsApplicable = $true; IsInstalled = $true; WhyApplicable = 'Installed HP package detail files meet or exceed the catalog version.'; Matches = @($matches); PnpOutdated = [bool]$driverBinaryMatches.Count; FamilyKey = $familyKey } }

    $windowsUpdateVersions = @(Get-HPUpdateWindowsUpdateVersions -Softpaq $Softpaq)
    $hasNewerWindowsUpdateComponent = [bool]($driverCurrentMatches | Where-Object {
        $installedVersion = ConvertTo-HPUpdateVersion $_.InstalledVersion
        $installedVersion -and @($windowsUpdateVersions | Where-Object { $_ -gt $installedVersion }).Count
    } | Select-Object -First 1)
    if ($hasNewerWindowsUpdateComponent) { return [pscustomobject]@{ IsApplicable = $true; IsInstalled = $false; WhyApplicable = 'An HP Windows Update component version is newer than the active driver version.'; Matches = @($matches); PnpOutdated = $true; FamilyKey = $familyKey } }
    if ($driverCurrentMatches.Count) { return [pscustomobject]@{ IsApplicable = $true; IsInstalled = $true; WhyApplicable = 'The active PnP driver version meets or exceeds the HP reference catalog version.'; Matches = @($matches); PnpOutdated = [bool]$driverBinaryMatches.Count; FamilyKey = $familyKey } }

    $unresolvedPackageDetails = @($detailFiles | Where-Object { $_.FilesFound -eq 0 -and -not $_.UsesDriverBinaryPath })
    if ($detailFiles.Count -and $unresolvedPackageDetails.Count -eq $detailFiles.Count) { return [pscustomobject]@{ IsApplicable = $false; IsInstalled = $null; WhyApplicable = 'HP package-specific detail files are absent, so the associated PnP device alone is insufficient to establish an update requirement.'; Matches = @($matches); PnpOutdated = [bool]$driverBinaryMatches.Count; FamilyKey = $familyKey } }
    if ($outdatedFiles.Count) { return [pscustomobject]@{ IsApplicable = $true; IsInstalled = $false; WhyApplicable = 'An installed HP package detail file is older than the catalog version.'; Matches = @($matches); PnpOutdated = [bool]$driverBinaryMatches.Count; FamilyKey = $familyKey } }
    [pscustomobject]@{ IsApplicable = $true; IsInstalled = -not $driverBinaryMatches.Count; WhyApplicable = if ($driverBinaryMatches.Count) { 'Installed driver version is older than the HP reference catalog version.' } else { 'No local package detail file was found for this supported device.' }; Matches = @($matches); PnpOutdated = [bool]$driverBinaryMatches.Count; FamilyKey = $familyKey }
}