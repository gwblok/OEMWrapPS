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