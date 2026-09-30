function Get-HPUpdate {
    <#
    .SYNOPSIS
        Gets HP-recommended SoftPaq updates applicable to this computer.

    .DESCRIPTION
        Queries HP's platform-specific recommendation API and evaluates local
        device, file, BIOS, UWP, and component state without HP CMSL.

    .PARAMETER Type
        Returns updates in the specified HP update class. The default is All.

    .PARAMETER ReleaseType
        Returns updates matching the specified HP release type. The default is All.

    .EXAMPLE
        Get-HPUpdate -Type Drivers
    #>
    [CmdletBinding()]
    param(
        [switch]$All,
        [switch]$NoTestInstalled,
        [switch]$UseCachedCatalog,
        [switch]$Details,
        [ValidateSet('All', 'BIOS', 'Drivers', 'Software', 'Firmware', 'Accessories')]
        [string]$Type = 'All',
        [ValidateSet('All', 'Critical', 'Recommended', 'Routine')]
        [string]$ReleaseType = 'All',
        [string]$CatalogDirectory = (Get-HPUpdatePath -Name Catalogs)
    )

    if ($NoTestInstalled -and -not $All) { throw '-NoTestInstalled can only be used with -All.' }
    $device = Get-HPUpdateDeviceInfo
    $operatingSystem = Get-HPUpdateOperatingSystem
    $catalog = Get-HPUpdateCatalog -Platform $device.Platform -OperatingSystem $operatingSystem -UseCachedCatalog:$UseCachedCatalog -CatalogDirectory $CatalogDirectory
    $operatingSystem = $catalog.SelectedOperatingSystem
    $softpaqs = @($catalog.softpaqs)
    $driverInventory = @()
    $referenceCatalog = $null
    $fileVersionCache = @{}
    $appxPackages = @()
    if (-not $NoTestInstalled) {
        $driverInventory = Get-HPUpdateDriverInventory
        if (@($softpaqs | Where-Object { $_.type -eq 'Driver' }).Count) {
            $referenceCatalog = Get-HPUpdateReferenceCatalog -Platform $device.Platform -OperatingSystem $operatingSystem -CatalogDirectory $CatalogDirectory
            # -AllUsers needs elevation; fall back to the current user's packages otherwise.
            $appxPackages = @(try { Get-AppxPackage -AllUsers -ErrorAction Stop } catch { Get-AppxPackage -ErrorAction Stop })
        }
    }

    Write-Host "Evaluating HP update catalog for platform $($device.Platform) ($($device.Model)) ..."
    $candidateUpdates = [System.Collections.Generic.List[object]]::new()
    foreach ($softpaq in $softpaqs) {
        $state = if ($NoTestInstalled) {
            [pscustomobject]@{ IsApplicable = $true; IsInstalled = $null; WhyApplicable = 'Installed state was not evaluated.'; Matches = @() }
        }
        elseif ($softpaq.type -eq 'Driver') {
            $driverState = Resolve-HPUpdateState -Softpaq $softpaq -DriverInventory $driverInventory -ReferenceCatalog $referenceCatalog -OperatingSystem $operatingSystem -FileVersionCache $fileVersionCache
            # The UWP companion app is only a supplementary signal once the device itself matched.
            if ($driverState.IsApplicable -and $driverState.IsInstalled -and [string]$softpaq.isUwpApp -match '^(?i:true|1)$') {
                $uwpState = Resolve-HPUpdateUwpState -Softpaq $softpaq -AppxPackages $appxPackages
                if ($uwpState.IsApplicable -and $uwpState.IsInstalled -eq $false) { $uwpState } else { $driverState }
            }
            else { $driverState }
        }
        elseif ($softpaq.type -eq 'ROMPAQ') {
            Resolve-HPUpdateBiosState -Softpaq $softpaq
        }
        else {
            Resolve-HPUpdateApplicationState -Softpaq $softpaq -DriverInventory $driverInventory -OperatingSystem $operatingSystem -FileVersionCache $fileVersionCache
        }
        $releaseDate = [datetime]::MinValue
        $null = [datetime]::TryParse([string]$softpaq.effectivityDate, [ref]$releaseDate)
        $update = [pscustomobject]@{
            ID = "sp$($softpaq.softpaqId)"
            SoftpaqID = "sp$($softpaq.softpaqId)"
            PackageID = [string]$softpaq.softpaqId
            Title = [string]$softpaq.title
            Name = [string]$softpaq.title
            Version = [string]$softpaq.version
            VendorVersion = [string]$softpaq.vendorVersion
            Type = [string]$softpaq.type
            Category = [string]$softpaq.categoryName
            ReleaseType = [string]$softpaq.releaseType
            Severity = [string]$softpaq.recommendedType
            ReleaseDate = $releaseDate
            Size = [long]$softpaq.softpaqBinarySize
            FileSize = [long]$softpaq.softpaqBinarySize
            DownloadUri = [uri]$softpaq.downloadUrl
            URL = [uri]$softpaq.downloadUrl
            MetadataUri = [uri]$softpaq.metadataUrl
            Sha256 = [string]$softpaq.softpaqSha256
            Installer = [pscustomobject]@{ Program = "sp$($softpaq.softpaqId).exe"; Arguments = [string]$softpaq.silentInstall; Unattended = -not [string]::IsNullOrWhiteSpace([string]$softpaq.silentInstall) }
            SuccessCodes = @($softpaq.successCodes)
            RebootCodes = @($softpaq.rebootCodes)
            IsApplicable = [bool]$state.IsApplicable
            IsInstalled = $state.IsInstalled
            WhyApplicable = [string]$state.WhyApplicable
            ApplicabilityRuleStatus = 1
            InstallRuleStatus = if ($NoTestInstalled) { $null } elseif ($state.IsInstalled) { 1 } else { 0 }
            MatchedDevices = @($state.Matches)
            ComponentFamily = [string]$state.FamilyKey
            PnpOutdated = [bool]$state.PnpOutdated
            CatalogPackage = $softpaq
        }
        $update.PSObject.TypeNames.Insert(0, 'HP.Client.Update.HPUpdate')
        if (-not $Details) {
            $properties = [string[]]@('ID', 'Name', 'Version', 'ReleaseDate', 'Type', 'Category', 'ReleaseType', 'URL', 'WhyApplicable')
            $propertySet = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', $properties)
            $members = [System.Management.Automation.PSMemberSet]::new('PSStandardMembers', [System.Management.Automation.PSMemberInfo[]]@($propertySet))
            $update.PSObject.Members.Add($members)
        }
        $candidateUpdates.Add($update)
    }

    foreach ($family in ($candidateUpdates | Where-Object { $_.PnpOutdated -and $_.ComponentFamily } | Group-Object ComponentFamily | Where-Object Count -gt 1)) {
        $winner = $family.Group | Sort-Object ReleaseDate, PackageID -Descending | Select-Object -First 1
        if ($winner.IsInstalled -ne $false) {
            $winner.IsApplicable = $true
            $winner.IsInstalled = $false
            $winner.InstallRuleStatus = 0
            $winner.WhyApplicable = 'The active device component is below the HP reference version; this is the newest SoftPaq for that component family.'
        }
        foreach ($superseded in @($family.Group | Where-Object { $_ -ne $winner })) {
            $superseded.IsInstalled = $true
            $superseded.InstallRuleStatus = 1
            $superseded.WhyApplicable = "Superseded by $($winner.ID) for the same active device component family."
        }
    }

    $returnedCount = 0
    foreach ($update in $candidateUpdates) {
        if (-not $All -and $update.IsInstalled -ne $false) { continue }
        $matchesType = switch ($Type) {
            'All' { $true }
            'BIOS' { $update.Category -like 'BIOS -*' }
            'Drivers' { $update.Category -like 'Driver -*' -or $update.Category -eq 'Manageability - Driver Pack' }
            'Software' { $update.Category -like 'Software -*' -or $update.Type -eq 'Application' }
            'Firmware' { $update.Category -match '(?i)firmware' -and $update.Category -notlike 'BIOS -*' }
            'Accessories' { $update.Category -match '^(?i)(dock|accessor)' }
        }
        if (-not $matchesType) { continue }
        if ($ReleaseType -ne 'All' -and $update.ReleaseType -ne $ReleaseType) { continue }
        $returnedCount++
        $update
    }

    if (-not $returnedCount) {
        $scope = @(
            if ($Type -ne 'All') { "type '$Type'" }
            if ($ReleaseType -ne 'All') { "release type '$ReleaseType'" }
        ) -join ' and '
        $scopeSuffix = if ($scope) { " matching $scope" } else { '' }
        $emptyMessage = if ($All) { "No applicable HP SoftPaqs$scopeSuffix were found for platform $($device.Platform)." } else { "No HP SoftPaqs$scopeSuffix are pending for platform $($device.Platform). All applicable packages are current." }
        Write-Host $emptyMessage
    }
}