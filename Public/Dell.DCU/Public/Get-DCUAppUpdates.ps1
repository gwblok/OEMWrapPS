Function Get-DCUAppUpdates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [switch]$Latest,
        [switch]$Install,
        [switch]$AutoInstallPreReqs,
        [switch]$UseWebRequest,
        [switch]$CheckPreReqs,
        [string]$DownloadPath = "$env:ProgramData\OEMWrapPS\DellCabDownloads"
    )
    
    $DownloadPathSpecified = $PSBoundParameters.ContainsKey('DownloadPath')
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    $temproot = "$env:ProgramData\OEMWrapPS"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    
    $Apps = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType application | Select-Object -Property PackageID, Name, ReleaseDate, DellVersion, VendorVersion, Path
    $CommandUpdateApps = $Apps | Where-Object {$_.Name -like "*Command | Update*"} | Sort-Object -Property VendorVersion
    $CommandUpdateAppsLatest = $CommandUpdateApps | Select-Object -Last 1
    if ($CommandUpdateAppsLatest){
        if ($Install){
            [Version]$DCUVersion = $CommandUpdateAppsLatest.vendorVersion
            Write-Output "Found DCU Version $DCUVersion"
            $DCUVersionInstalled = Get-DCUVersion
            If ($DCUVersionInstalled -ne $false){[Version]$CurrentVersion = $DCUVersionInstalled}
            Else {[Version]$CurrentVersion = 0.0.0.0}
            if ($DCUVersion -gt $CurrentVersion){
                $DellCabDownloadsPath = $DownloadPath
                [void][System.IO.Directory]::CreateDirectory($DellCabDownloadsPath)
                if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
                $TargetFileName = ($CommandUpdateAppsLatest.path).Split("/") | Select-Object -Last 1
                $TargetLink = $CommandUpdateAppsLatest.path
                $TargetFilePathName = "$($DellCabDownloadsPath)\$($TargetFileName)"
                if ($UseWebRequest){
                    Write-Output "Using WebRequest to download the file"
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                else{
                    Write-Output "Using BITS to download the file"
                    Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Description "Downloading Dell Command Update" -ErrorAction SilentlyContinue
                }
                
                if (!(Test-Path $TargetFilePathName)){
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                #Confirm Download
                if (Test-Path $TargetFilePathName){
                    $LogFileName = ($TargetFilePathName.replace(".exe",".log")).Replace(".EXE",".log")
                    # The Dell Update Package wrapper only accepts /s, /l=, /e=, /f, /passthrough and /bls. IgnoreOOBE is applied via the registry after install.
                    $Arguments = "/s /l=`"$LogFileName`""
                    Write-Output "Starting DCU Install"
                    Write-Verbose "DCU installer arguments: $Arguments"
                    write-output "Log file = $LogFileName"
                    $Process = Start-Process "$TargetFilePathName" $Arguments -Wait -PassThru
                    write-output "Update Complete with Exitcode: $($Process.ExitCode)"
                    $ExitInfo = Get-DUPExitInfo -DUPExit $Process.ExitCode
                    if ($ExitInfo){
                        Write-Output "Exit Status: $($ExitInfo.DisplayName) - $($ExitInfo.Description)"
                    }
                    else{
                        Write-Output "Exit Status: Unknown - No matching DUP exit code information was found."
                    }
                    if ($Process.ExitCode -eq 4){
                        if (Test-Path -LiteralPath $LogFileName){
                            $PrerequisiteMessages = Get-Content -LiteralPath $LogFileName | Where-Object {
                                $_ -match '(?i)(needs to be installed|prerequisite|dependency)'
                            } | ForEach-Object {
                                ($_.Trim() -replace '^\d+:\s*','')
                            } | Select-Object -Unique
                            if ($PrerequisiteMessages){
                                $PrerequisiteSummary = $PrerequisiteMessages |
                                    Where-Object { $_ -match '(?i)needs to be installed' } |
                                    Select-Object -First 1
                                if (-not $PrerequisiteSummary){
                                    $PrerequisiteSummary = $PrerequisiteMessages | Select-Object -First 1
                                }
                                $PrerequisiteSummary = $PrerequisiteSummary -replace '(?i)^Missing prerequisite:\s*',''
                                Write-Output "Missing prerequisite: $PrerequisiteSummary"
                                $PrereqVersionMatch = [regex]::Match(($PrerequisiteMessages -join "`n"), 'Microsoft \.NET Desktop Runtime\s+(?<Version>\d+\.\d+)')
                                if ($PrereqVersionMatch.Success){
                                    $PrereqVersion = $PrereqVersionMatch.Groups['Version'].Value
                                    if ($AutoInstallPreReqs){
                                        Write-Output "Installing missing .NET prerequisite version $PrereqVersion"
                                        Install-DCUPreReqDOTNet -BaseVersion $PrereqVersion
                                        Write-Output "Retrying DCU installation after installing the prerequisite"
                                        $Process = Start-Process "$TargetFilePathName" $Arguments -Wait -PassThru
                                        Write-Output "DCU retry completed with Exitcode: $($Process.ExitCode)"
                                        $RetryExitInfo = Get-DUPExitInfo -DUPExit $Process.ExitCode
                                        if ($RetryExitInfo){
                                            Write-Output "Retry Exit Status: $($RetryExitInfo.DisplayName) - $($RetryExitInfo.Description)"
                                        }
                                        else{
                                            Write-Output "Retry Exit Status: Unknown - No matching DUP exit code information was found."
                                        }
                                    }
                                    else{
                                        Write-Output "Automatic prerequisite installation is disabled. Use -AutoInstallPreReqs to install it and retry DCU."
                                    }
                                }
                            }
                            else{
                                Write-Output "Missing prerequisite: The installer log did not identify the required prerequisite."
                            }
                        }
                        else{
                            Write-Output "Missing prerequisite: Installer log not found at $LogFileName"
                        }
                    }
                    If($Process -ne $null -and $Process.ExitCode -eq '2'){
                        Write-Verbose "Reboot Required"
                    }
                    if ($DCUVersion -ge [version]'5.7.1' -and $Process -and $Process.ExitCode -in @(0, 2)) {
                        Write-Output "DCU $DCUVersion supports OOBE deployment; configuring the IgnoreOOBE registry value."
                        $IgnoreOOBEKey = 'HKLM:\SOFTWARE\DELL\UpdateService\Service\UpdateScheduler'
                        $IgnoreOOBEValue = $null
                        $IgnoreOOBEKind = $null

                        if (Test-Path -LiteralPath $IgnoreOOBEKey) {
                            $IgnoreOOBEValue = Get-ItemPropertyValue -LiteralPath $IgnoreOOBEKey -Name 'IgnoreOOBE' -ErrorAction SilentlyContinue -ErrorVariable IgnoreOOBEReadError 2>$null
                            try {
                                $IgnoreOOBEKind = (Get-Item -LiteralPath $IgnoreOOBEKey).GetValueKind('IgnoreOOBE')
                            }
                            catch {
                                $IgnoreOOBEKind = $null
                            }
                        }

                        if ($IgnoreOOBEValue -ne 1 -or $IgnoreOOBEKind -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
                            Write-Output 'Setting Dell UpdateScheduler\IgnoreOOBE to DWORD 1.'
                            $null = New-Item -Path $IgnoreOOBEKey -Force -ErrorAction Stop
                            if ($null -ne $IgnoreOOBEKind) {
                                Remove-ItemProperty -LiteralPath $IgnoreOOBEKey -Name 'IgnoreOOBE' -Force -ErrorAction SilentlyContinue
                            }
                            $null = New-ItemProperty -LiteralPath $IgnoreOOBEKey -Name 'IgnoreOOBE' -Value 1 -PropertyType DWord -Force -ErrorAction Stop
                        }
                        else {
                            Write-Output 'Dell UpdateScheduler\IgnoreOOBE is already set to DWORD 1.'
                        }

                        $VerifiedIgnoreOOBEValue = Get-ItemPropertyValue -LiteralPath $IgnoreOOBEKey -Name 'IgnoreOOBE' -ErrorAction Stop
                        $VerifiedIgnoreOOBEKind = (Get-Item -LiteralPath $IgnoreOOBEKey).GetValueKind('IgnoreOOBE')
                        if ($VerifiedIgnoreOOBEValue -ne 1 -or $VerifiedIgnoreOOBEKind -ne [Microsoft.Win32.RegistryValueKind]::DWord) {
                            throw 'Dell UpdateScheduler\IgnoreOOBE registry verification failed.'
                        }
                        Write-Output 'Verified Dell UpdateScheduler\IgnoreOOBE is DWORD 1.'
                    }

                    # Dell DUP: 0 = success, 2 = success/reboot required. Everything else failed to install.
                    $FinalExitInfo = Get-DUPExitInfo -DUPExit $Process.ExitCode | Select-Object -First 1
                    $FinalCodeName = if ($FinalExitInfo) { $FinalExitInfo.DisplayName } else { 'Unknown' }
                    $FinalDescription = if ($FinalExitInfo) { $FinalExitInfo.Description } else { 'No matching DUP exit code information was found.' }
                    $InstallSucceeded = $Process.ExitCode -in @(0, 2)

                    if (-not $InstallSucceeded){
                        throw "Dell Command Update $DCUVersion install failed with exit code $($Process.ExitCode) ($FinalCodeName - $FinalDescription). Log: $LogFileName"
                    }

                    return [PSCustomObject]@{
                        Version        = $DCUVersion
                        ExitCode       = $Process.ExitCode
                        CodeName       = $FinalCodeName
                        Description    = $FinalDescription
                        LogPath        = $LogFileName
                        Success        = $true
                        RebootRequired = ($Process.ExitCode -eq 2)
                    }
                }
                else{
                    throw "Failed to download Dell Command Update from $TargetLink"
                }
            }
            else{
                Write-Output "Installed DCU: $CurrentVersion, Skipping Install"

            }
        }
        else{
            if ($DownloadPathSpecified){
                [void][System.IO.Directory]::CreateDirectory($DownloadPath)
                $TargetFileName = ($CommandUpdateAppsLatest.path).Split("/") | Select-Object -Last 1
                $TargetLink = $CommandUpdateAppsLatest.path
                $TargetFilePathName = Join-Path -Path $DownloadPath -ChildPath $TargetFileName
                if ($UseWebRequest){
                    Write-Verbose "Using WebRequest to download the file"
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                else{
                    Write-Verbose "Using BITS to download the file"
                    Start-BitsTransfer -Source $TargetLink -Destination $TargetFilePathName -DisplayName $TargetFileName -Description "Downloading Dell Command Update" -ErrorAction SilentlyContinue
                }
                if (!(Test-Path $TargetFilePathName)){
                    Invoke-WebRequest -Uri $TargetLink -OutFile $TargetFilePathName -UseBasicParsing -Verbose
                }
                if (Test-Path $TargetFilePathName){
                    return $TargetFilePathName
                }
                Write-Verbose "FAILED TO DOWNLOAD DCU"
                return
            }
            if ($Latest){
                Return $CommandUpdateAppsLatest
            }
            else{
                return $CommandUpdateApps
            }
        }
    }
    else{
        return "No DCU Found"
    }

}
