function Install-HPUpdate {
    <#
    .SYNOPSIS
        Downloads, validates, and installs applicable HP SoftPaq updates.

    .EXAMPLE
        Get-HPUpdate | Install-HPUpdate

    .EXAMPLE
        Install-HPUpdate -PackageIds sp173903 -Force
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Search', ConfirmImpact = 'Medium')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Search')]
        [Alias('PackageId', 'SoftpaqId')][string[]]$PackageIds,
        [Parameter(Position = 0, ValueFromPipeline, ParameterSetName = 'Packages')]
        [Alias('Package', 'Update')][psobject[]]$Packages,
        [string[]]$ExcludePackageIds,
        [string[]]$Category,
        [string[]]$Type,
        [string[]]$ReleaseType,
        [switch]$Force,
        [switch]$NoLog,
        [uri]$Proxy,
        [pscredential]$ProxyCredential,
        [switch]$ProxyUseDefaultCredentials,
        [string]$Path
    )

    begin {
        $pipelinePackages = [System.Collections.Generic.List[object]]::new()
        $historyRecords = [System.Collections.Generic.List[object]]::new()
        $results = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($package in @($Packages)) { if ($null -ne $package) { $pipelinePackages.Add($package) } }
    }

    end {
        function Expand-HPUpdatePackageIdList {
            param([string[]]$Values)
            @($Values | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }
        function Write-HPUpdateInstallationLog {
            param([string]$Message)
            if ($NoLog -or -not $logPath) { return }
            Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" -Encoding UTF8
        }
        function Set-HPUpdateInstallResultDisplay {
            param([Parameter(Mandatory)][psobject]$Result)
            $Result.PSObject.TypeNames.Insert(0, 'HP.Client.Update.HPInstallResult')
            $properties = [string[]]@('ID', 'Title', 'Success', 'RebootRequired', 'PendingAction', 'ExitCode', 'FailureReason', 'LogPath', 'Runtime')
            $propertySet = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', $properties)
            $members = [System.Management.Automation.PSMemberSet]::new('PSStandardMembers', [System.Management.Automation.PSMemberInfo[]]@($propertySet))
            $Result.PSObject.Members.Add($members)
        }
        function New-HPUpdateInstallResult {
            param([psobject]$Package, [bool]$Success, [bool]$RebootRequired, $ExitCode, [string]$FailureReason, [timespan]$Runtime)
            $result = [pscustomobject]@{ ID = $Package.ID; SoftpaqID = $Package.SoftpaqID; Title = $Package.Title; Success = $Success; RebootRequired = $RebootRequired; PendingAction = if ($RebootRequired) { 'REBOOT_MANDATORY' } else { 'NONE' }; ExitCode = $ExitCode; FailureReason = $FailureReason; LogPath = $logPath; Runtime = $Runtime }
            Set-HPUpdateInstallResultDisplay -Result $result
            $historyRecords.Add((New-HPUpdateHistoryRecord -Package $Package -Result $result))
            $results.Add($result)
            $result
        }

        $requestedIds = @(Expand-HPUpdatePackageIdList -Values $PackageIds)
        $excludedIds = @(Expand-HPUpdatePackageIdList -Values $ExcludePackageIds)
        $selectedPackages = if ($PSCmdlet.ParameterSetName -eq 'Packages') { @($pipelinePackages) } elseif ($requestedIds.Count) { @(Get-HPUpdate -All | Where-Object { $_.ID -in $requestedIds -or $_.SoftpaqID -in $requestedIds -or $_.PackageID -in $requestedIds }) } else { @(Get-HPUpdate) }
        if ($excludedIds.Count) { $selectedPackages = @($selectedPackages | Where-Object { $_.ID -notin $excludedIds -and $_.SoftpaqID -notin $excludedIds -and $_.PackageID -notin $excludedIds }) }
        if ($PSBoundParameters.ContainsKey('Category')) { $selectedPackages = @($selectedPackages | Where-Object { $_.Category -in $Category }) }
        if ($PSBoundParameters.ContainsKey('Type')) { $selectedPackages = @($selectedPackages | Where-Object { $_.Type -in $Type }) }
        if ($PSBoundParameters.ContainsKey('ReleaseType')) { $selectedPackages = @($selectedPackages | Where-Object { $_.ReleaseType -in $ReleaseType }) }
        $selectedPackages = @($selectedPackages | Sort-Object ID -Unique)

        # BIOS flashing carries the highest failure risk, so it is never automated here.
        $skippedBiosPackages = @($selectedPackages | Where-Object { $_.Type -eq 'ROMPAQ' -or $_.Category -like 'BIOS -*' })
        if ($skippedBiosPackages.Count) {
            $selectedPackages = @($selectedPackages | Where-Object { $_ -notin $skippedBiosPackages })
            foreach ($biosPackage in $skippedBiosPackages) {
                Write-Host "Skipping BIOS update $($biosPackage.ID) ($($biosPackage.Name) $($biosPackage.Version)) to reduce risk. Apply it separately."
            }
        }

        if (-not $selectedPackages.Count) { Write-Verbose 'No applicable HP updates matched the specified criteria.'; return }

        foreach ($package in $selectedPackages) {
            if ($package.PSObject.TypeNames -notcontains 'HP.Client.Update.HPUpdate') { throw 'Install-HPUpdate requires update objects returned by Get-HPUpdate.' }
            if ($package.IsApplicable -ne $true -or $package.IsInstalled -ne $false) { throw "Refusing to install '$($package.Title)': it is not positively marked applicable and not installed." }
            if (-not $package.DownloadUri -or -not $package.Sha256 -or -not $package.Installer.Unattended) { throw "HP catalog metadata is incomplete for '$($package.Title)'." }
        }
        if (-not $Force -and -not $WhatIfPreference) {
            Write-Host 'The following HP updates will be installed:'
            $selectedPackages | Select-Object SoftpaqID, Name, Version, Category | Format-Table -AutoSize | Out-Host
            if (-not $PSCmdlet.ShouldContinue("Install $($selectedPackages.Count) HP update package(s)?", 'Install HP updates')) { return }
        }
        $isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $WhatIfPreference -and -not $isAdministrator) { throw 'Install-HPUpdate must be run from an elevated PowerShell session.' }

        $payloadDirectory = if ([string]::IsNullOrWhiteSpace($Path)) { Get-HPUpdatePath -Name Downloads } else { $Path }
        $logPath = $null
        if (-not $NoLog -and -not $WhatIfPreference) {
            $logDirectory = Get-HPUpdatePath -Name Logs -Create
            $logPath = Join-Path $logDirectory "$(Get-Date -Format 'yyyyMMdd_HHmmss_fff')-$([guid]::NewGuid().ToString('N')).log"
            Write-HPUpdateInstallationLog "Selected $($selectedPackages.Count) HP update package(s)."
            foreach ($biosPackage in $skippedBiosPackages) { Write-HPUpdateInstallationLog "Skipped BIOS update $($biosPackage.ID) ($($biosPackage.Name) $($biosPackage.Version)) by policy." }
        }
        try {
            Write-Host "Preparing $($selectedPackages.Count) HP update package(s)..."
            $downloadedPackages = [System.Collections.Generic.List[object]]::new()
            $downloadNumber = 0
            foreach ($package in $selectedPackages) {
                $downloadNumber++
                if (-not $PSCmdlet.ShouldProcess($package.Title, 'Download, verify, and install HP update')) { continue }
                $startedAt = Get-Date
                try {
                    Write-Host "Downloading update $downloadNumber of $($selectedPackages.Count): $($package.Title)"
                    $sourceUri = [uri]$package.DownloadUri
                    if ($sourceUri.Scheme -ne 'https') { throw "Refusing non-HTTPS catalog payload URI: '$sourceUri'." }
                    $null = New-Item -Path $payloadDirectory -ItemType Directory -Force
                    $installerPath = Join-Path $payloadDirectory ([IO.Path]::GetFileName($sourceUri.AbsolutePath))
                    $actualDigest = if (Test-Path -LiteralPath $installerPath -PathType Leaf) { (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash }
                    if ($actualDigest -ine [string]$package.Sha256) {
                        Write-HPUpdateInstallationLog "Downloading $($package.SoftpaqID) from $sourceUri"
                        Invoke-HPUpdateDownload -Source $sourceUri -Destination $installerPath -Proxy $Proxy -ProxyCredential $ProxyCredential -ProxyUseDefaultCredentials:$ProxyUseDefaultCredentials -ShowProgress
                    }
                    else {
                        Write-Host "Using previously downloaded payload for $($package.SoftpaqID)."
                    }
                    $null = Test-HPUpdatePackage -Path $installerPath -ExpectedSha256 $package.Sha256
                    $downloadedPackages.Add([pscustomobject]@{ Package = $package; InstallerPath = $installerPath; StartedAt = $startedAt })
                }
                catch {
                    Write-HPUpdateInstallationLog "Failed to download or validate $($package.SoftpaqID): $($_.Exception.Message)"
                    $result = New-HPUpdateInstallResult -Package $package -Success $false -RebootRequired $false -ExitCode $null -FailureReason $_.Exception.Message -Runtime ((Get-Date) - $startedAt)
                    Write-Host "Download failed: $($package.Title) - $($result.FailureReason)"
                    $result
                }
            }
            if (-not $downloadedPackages.Count -and -not $results.Count) { return }
            if ($downloadedPackages.Count) { Write-Host 'Starting installation phase...' }
            $installNumber = 0
            foreach ($downloadedPackage in $downloadedPackages) {
                $installNumber++
                $package = $downloadedPackage.Package
                $startedAt = $downloadedPackage.StartedAt
                try {
                    Write-Host "Installing Update $($package.Title) ($installNumber of $($downloadedPackages.Count))"
                    Write-HPUpdateInstallationLog "Starting $($package.SoftpaqID): $($downloadedPackage.InstallerPath)"
                    $process = Start-Process -FilePath $downloadedPackage.InstallerPath -ArgumentList '-s', '-e cmd.exe', "/f `"$payloadDirectory`"", '-a', "/c $($package.Installer.Arguments)" -WorkingDirectory $payloadDirectory -Wait -PassThru
                    $successCodes = if (@($package.SuccessCodes).Count) { @($package.SuccessCodes) } else { @(0) }
                    $success = $process.ExitCode -in $successCodes
                    $rebootRequired = $process.ExitCode -in @($package.RebootCodes)
                    Write-HPUpdateInstallationLog "Completed $($package.SoftpaqID) with exit code $($process.ExitCode)."
                    New-HPUpdateInstallResult -Package $package -Success $success -RebootRequired $rebootRequired -ExitCode $process.ExitCode -FailureReason $(if ($success) { '' } else { "HP SoftPaq exited with code $($process.ExitCode)." }) -Runtime ($process.ExitTime - $process.StartTime)
                }
                catch {
                    Write-HPUpdateInstallationLog "Failed $($package.SoftpaqID): $($_.Exception.Message)"
                    New-HPUpdateInstallResult -Package $package -Success $false -RebootRequired $false -ExitCode $null -FailureReason $_.Exception.Message -Runtime ((Get-Date) - $startedAt)
                }
            }
            if ($results.Count) {
                $succeeded = @($results | Where-Object Success).Count
                $rebootCount = @($results | Where-Object RebootRequired).Count
                Write-Host "Installation summary: $succeeded succeeded ($rebootCount require reboot), $($results.Count - $succeeded) failed."
                $results | Select-Object Title, @{ Name = 'Status'; Expression = { if (-not $_.Success) { 'Failed' } elseif ($_.RebootRequired) { 'Reboot required' } else { 'Success' } } }, ExitCode, FailureReason | Format-Table -AutoSize -Wrap | Out-Host
            }
        }
        finally {
            if (-not $WhatIfPreference -and $historyRecords.Count) {
                try { Write-HPUpdateHistorySession -Records @($historyRecords) | Out-Null }
                catch { Write-Warning "Could not save HP update installation history: $($_.Exception.Message)" }
            }
        }
    }
}