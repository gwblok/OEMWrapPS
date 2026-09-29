Function Get-DellBIOSUpdates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [switch]$Latest,
        [switch]$Check, #This will find the latest BIOS update and compare it to the current BIOS version
        [switch]$Details,
        [switch]$Flash,
        [string]$Password,
        [string]$DownloadPath

    )
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems, or please provide a SKU"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }

    if ($Details){
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}

        $BiosInfo = Get-CimInstance -ClassName Win32_BIOS
        [version]$CurrentBIOSVersion = $BiosInfo.SMBIOSBIOSVersion
        $CurrentBIOSReleaseDate = $null
        if ($BiosInfo.ReleaseDate){
            try {
                $CurrentBIOSReleaseDate = [System.Management.ManagementDateTimeConverter]::ToDateTime($BiosInfo.ReleaseDate)
            }
            catch {
                $CurrentBIOSReleaseDate = $BiosInfo.ReleaseDate
            }
        }

        $AllBIOSUpdates = @(Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS)
        $LatestBIOS = $AllBIOSUpdates | Sort-Object -Property ReleaseDate -Descending | Select-Object -First 1
        if ($LatestBIOS){
            [version]$LatestBIOSVersion = $LatestBIOS.DellVersion
            $LatestBIOSReleaseDate = $LatestBIOS.ReleaseDate
            $UpdateAvailable = $CurrentBIOSVersion -lt $LatestBIOSVersion
            $BIOSIsCurrent = $CurrentBIOSVersion -ge $LatestBIOSVersion
            $ReleasesSinceCurrent = @(
                $AllBIOSUpdates |
                    Where-Object {
                        try {
                            $CandidateVersion = [version]$_.DellVersion
                            $CandidateVersion -gt $CurrentBIOSVersion
                        }
                        catch {
                            $false
                        }
                    } |
                    Select-Object -ExpandProperty DellVersion -Unique
            ).Count
        }
        else {
            $LatestBIOSVersion = $null
            $LatestBIOSReleaseDate = $null
            $UpdateAvailable = $false
            $BIOSIsCurrent = $true
            $ReleasesSinceCurrent = 0
        }

        return [PSCustomObject]@{
            CurrentBIOSVersion = $CurrentBIOSVersion
            CurrentBIOSReleaseDate = $CurrentBIOSReleaseDate
            LatestBIOSVersion = $LatestBIOSVersion
            LatestBIOSReleaseDate = $LatestBIOSReleaseDate
            UpdateAvailable = $UpdateAvailable
            BIOSIsCurrent = $BIOSIsCurrent
            ReleasesSinceCurrent = $ReleasesSinceCurrent
        }
    }
    
    if ($Check){
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        else{
            [Version]$CurrentBIOSVersion = (Get-CimInstance -ClassName Win32_BIOS).SMBIOSBIOSVersion
            $LatestBIOS = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest | Sort-Object -Property ReleaseDate -Descending
            if ($LatestBIOS.count -gt 1){
                $LatestBIOS = $LatestBIOS | Select-Object -First 1
            }
            [version]$LatestVersion = ($LatestBIOS).DellVersion

            if ($CurrentBIOSVersion -lt $LatestVersion){
                Write-Verbose "Current BIOS Version: $CurrentBIOSVersion"
                Write-Verbose "Latest BIOS Version: $LatestVersion"
                Write-Verbose "New BIOS Update Available"
                return $false
            }
            else {
                Write-Verbose "Current BIOS Version: $CurrentBIOSVersion"
                Write-Verbose "Latest BIOS Version: $LatestVersion"
                Write-Verbose "No New BIOS Update Available"
                return $true
            }
        }
    }
    if ($Flash){
        #Test for BitLocker state before downloading or flashing the BIOS update.
        try {
            $BitlockerStatus = Get-BitLockerVolume -MountPoint $env:SystemDrive
        }
        catch {
            $BitlockerStatus = $null
            Write-Host "Unable to query BitLocker status. Continuing without preflight check: $($_.Exception.Message)"
        }

        if ($BitlockerStatus -ne $null){
            Write-Host "BitLocker status: Protection=$($BitlockerStatus.ProtectionStatus) | Volume=$($BitlockerStatus.VolumeStatus) | Encryption=$($BitlockerStatus.EncryptionPercentage)%"

            if ($BitlockerStatus.VolumeStatus -in @('EncryptionInProgress','DecryptionInProgress')){
                Write-Host "BitLocker is currently encrypting or decrypting this volume. BIOS flashing is blocked until that process finishes."
                return
            }

            if ($BitlockerStatus.ProtectionStatus -eq "On"){
                if ($BitlockerStatus.VolumeStatus -eq 'FullyEncrypted'){
                    Write-Host "BitLocker protection is On and the volume is fully encrypted. Suspending BitLocker before flashing BIOS..."
                    Suspend-BitLocker -MountPoint $env:SystemDrive -RebootCount 1
                }
                else {
                    Write-Host "BitLocker protection is On, but the volume is not in a ready state for BIOS flashing. BIOS flashing will not be attempted."
                    return
                }
            }
        }
        #https://www.dell.com/support/kbdoc/en-us/000136752/command-line-switches-for-dell-bios-updates
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest
        $Update = $Updates | Select-Object -First 1
        $UpdatePath = $Update.Path
        $UpdateFileName = $UpdatePath -split "/" | Select-Object -Last 1
        $UpdateDownloadFolder = "$env:ProgramData\OEMWrapPS\DellBIOSUpdates"
        if (!(Test-Path $UpdateDownloadFolder)){$null = New-Item -Path $UpdateDownloadFolder -ItemType Directory -Force}
        $UpdateLocalPath = "$UpdateDownloadFolder\$UpdateFileName"
        Start-BitsTransfer -DisplayName $UpdateFileName -Source $UpdatePath -Destination $UpdateLocalPath -Description "Downloading $UpdateFileName" -RetryInterval 60 #-CustomHeaders "User-Agent:Bob" 
        if (Test-Path -Path $UpdateLocalPath){
            Write-Host "Installing $UpdateFileName, logfile: $($UpdateLocalPath).log"
            if ($Password){
                $BIOSArgs = "/s /l=$UpdateLocalPath.log /p=$Password"
            }
            else {
                $BIOSArgs = "/s /l=$UpdateLocalPath.log"
            }
            $InstallUpdate = Start-Process -FilePath $UpdateLocalPath -ArgumentList $BIOSArgs -Wait -PassThru
            $LogPath = "$UpdateLocalPath.log"
            $ExitInfo = Get-DUPExitInfo -DUPExit $InstallUpdate.ExitCode | Select-Object -First 1
            if (-not $ExitInfo) {
                $ExitInfo = [PSCustomObject]@{
                    ExitCode = $InstallUpdate.ExitCode
                    DisplayName = 'Unknown'
                    Description = 'No matching Dell DUP BIOS exit-code documentation was found.'
                }
            }

            if (Test-Path -Path $LogPath) {
                $LogContent = Get-Content -Path $LogPath -Raw -ErrorAction SilentlyContinue
                $LoggedExitCode = [regex]::Match($LogContent, '(?im)^\s*Exit Code\s*=\s*(?<Value>.+?)\s*$')
                $LoggedError = [regex]::Match($LogContent, '(?im)^\s*Error:\s*(?<Value>.+?)\s*$')

                if ($LoggedExitCode.Success) {
                    $ExitInfo.DisplayName = $LoggedExitCode.Groups['Value'].Value.Trim()
                }
                if ($LoggedError.Success) {
                    $ExitInfo.Description = $LoggedError.Groups['Value'].Value.Trim()
                }
            }
            Write-Host "Exit Code: $($ExitInfo.ExitCode)"
            Write-Host "Code Name: $($ExitInfo.DisplayName)"
            Write-Host "Description: $($ExitInfo.Description)"
            return [PSCustomObject]@{
                Update = $UpdateFileName
                ExitCode = $ExitInfo.ExitCode
                CodeName = $ExitInfo.DisplayName
                Description = $ExitInfo.Description
                LogPath = $LogPath
                Success = $ExitInfo.ExitCode -in @(0, 2)
                RebootRequired = $ExitInfo.ExitCode -eq 2
            }
        }
        else {
            Write-Host "File Not Found: $UpdateFileName"
            return
        }
    }
    if ($DownloadPath){
        [void][System.IO.Directory]::CreateDirectory($DownloadPath)
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest
        $Update = $Updates | Select-Object -First 1
        $UpdatePath = $Update.Path
        $UpdateFileName = $UpdatePath -split "/" | Select-Object -Last 1
        $UpdateLocalPath = "$DownloadPath\$UpdateFileName"
        Start-BitsTransfer -DisplayName $UpdateFileName -Source $UpdatePath -Destination $UpdateLocalPath -Description "Downloading $UpdateFileName" -RetryInterval 60 #-CustomHeaders "User-Agent:Bob"
        return $UpdateLocalPath
    }
    if ($Latest){
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS -Latest
    }
    else {
        $Updates = Get-DCUUpdateList -SystemSKUNumber $SystemSKUNumber -updateType BIOS
    }
    return $Updates |Select-Object -Property "PackageID","Name","ReleaseDate","DellVersion" | Sort-Object -Property ReleaseDate -Descending
}
