function Resolve-HPUpdateBiosState {
    param([Parameter(Mandatory)][psobject]$Softpaq)

    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $installedVersion = ConvertTo-HPUpdateVersion $bios.SMBIOSBIOSVersion
    $expectedVersion = ConvertTo-HPUpdateVersion $Softpaq.version
    if (-not $installedVersion -or -not $expectedVersion) {
        return [pscustomobject]@{ IsApplicable = $false; IsInstalled = $null; WhyApplicable = 'The installed or catalog BIOS version could not be compared safely.'; Matches = @() }
    }
    [pscustomobject]@{
        IsApplicable = $true
        IsInstalled = $installedVersion -ge $expectedVersion
        WhyApplicable = if ($installedVersion -lt $expectedVersion) { 'Installed BIOS version is older than the HP catalog version.' } else { 'Installed BIOS version meets or exceeds the HP catalog version.' }
        Matches = @([pscustomobject]@{ InstalledVersion = $installedVersion; ExpectedVersion = $expectedVersion; DeviceName = 'System BIOS'; DeviceId = 'Win32_BIOS' })
    }
}

function Resolve-HPUpdateUwpState {
    param(
        [Parameter(Mandatory)][psobject]$Softpaq,
        [Parameter(Mandatory)][object[]]$AppxPackages
    )

    $apps = @($Softpaq.apps)
    if (-not $apps.Count) { return [pscustomobject]@{ IsApplicable = $false; IsInstalled = $null; WhyApplicable = 'HP marked this package as UWP-backed but did not provide app metadata.'; Matches = @() } }
    $matches = [System.Collections.Generic.List[object]]::new()
    foreach ($app in $apps) {
        $expectedVersion = ConvertTo-HPUpdateVersion $app.version
        $installedPackages = @($AppxPackages | Where-Object { $_.Name -eq $app.name -or $_.PackageFamilyName -eq $app.packageFamilyName })
        $installedVersion = @($installedPackages | ForEach-Object { ConvertTo-HPUpdateVersion $_.Version } | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1)[0]
        $matches.Add([pscustomobject]@{ DeviceName = [string]$app.name; DeviceId = [string]$app.packageFamilyName; InstalledVersion = $installedVersion; ExpectedVersion = $expectedVersion })
    }
    $outdated = @($matches | Where-Object { -not $_.InstalledVersion -or ($_.ExpectedVersion -and $_.InstalledVersion -lt $_.ExpectedVersion) })
    [pscustomobject]@{ IsApplicable = $true; IsInstalled = -not $outdated.Count; WhyApplicable = if ($outdated.Count) { 'A required HP UWP application is missing or older than the catalog version.' } else { 'Required HP UWP applications meet or exceed the catalog versions.' }; Matches = @($matches) }
}

function Resolve-HPUpdateApplicationState {
    param(
        [Parameter(Mandatory)][psobject]$Softpaq,
        [object[]]$DriverInventory = @(),
        [Parameter(Mandatory)][psobject]$OperatingSystem,
        [Parameter(Mandatory)][hashtable]$FileVersionCache
    )

    $isRequired = [string]$Softpaq.isSoftpaqRequired -match '^(?i:true|1)$'
    $deviceMatches = @(Get-HPUpdateDeviceMatches -Softpaq $Softpaq -DriverInventory $DriverInventory)
    if (@($Softpaq.devices).Count -and -not $deviceMatches.Count) {
        return [pscustomobject]@{ IsApplicable = $false; IsInstalled = $null; WhyApplicable = 'No supported installed device was found for this SoftPaq.'; Matches = @() }
    }

    $detailFiles = @(Get-HPUpdateDetailFileState -Softpaq $Softpaq -OperatingSystem $OperatingSystem -FileVersionCache $FileVersionCache)
    $fileMatches = @($detailFiles | ForEach-Object {
        [pscustomobject]@{ DeviceName = $_.FileName; DeviceId = $_.FileName; InstalledVersion = $_.InstalledVersion; ExpectedVersion = $_.ExpectedVersion }
    })
    $allMatches = @($deviceMatches) + $fileMatches

    if ($detailFiles.Count) {
        $outdatedFiles = @($detailFiles | Where-Object { $_.InstalledVersion -and $_.InstalledVersion -lt $_.ExpectedVersion })
        if ($outdatedFiles.Count) { return [pscustomobject]@{ IsApplicable = $true; IsInstalled = $false; WhyApplicable = "Installed '$($outdatedFiles[0].FileName)' version $($outdatedFiles[0].InstalledVersion) is older than the catalog version $($outdatedFiles[0].ExpectedVersion)."; Matches = $allMatches } }
        if (@($detailFiles | Where-Object { $_.InstalledVersion }).Count) { return [pscustomobject]@{ IsApplicable = $true; IsInstalled = $true; WhyApplicable = 'Installed HP package detail files meet or exceed the catalog version.'; Matches = $allMatches } }
        # Optional SoftPaqs are not reported as pending when they were never installed.
        return [pscustomobject]@{ IsApplicable = $isRequired; IsInstalled = -not $isRequired; WhyApplicable = if ($isRequired) { 'HP recommends this SoftPaq and none of its detail files are present.' } else { 'This optional HP SoftPaq is not installed.' }; Matches = $allMatches }
    }

    [pscustomobject]@{ IsApplicable = $true; IsInstalled = -not $isRequired; WhyApplicable = if ($isRequired) { 'HP recommends this SoftPaq for the current device state.' } else { 'HP reports this SoftPaq is optional for the device.' }; Matches = $allMatches }
}