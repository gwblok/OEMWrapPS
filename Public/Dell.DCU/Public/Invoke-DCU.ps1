function Invoke-DCU {
    [CmdletBinding()]
    
    param (
    [ValidateSet('security','critical','recommended','optional')]
    [String[]]$updateSeverity,
    [ValidateSet('bios','firmware','driver','application','others')]
    [String[]]$updateType,
    [ValidateSet('audio','video','network','chipset','storage','input','others')]
    [String[]]$updateDeviceCategory,
    [ValidateSet('Enable','Disable')]
    [string]$autoSuspendBitLocker = 'Enable',
    [ValidateSet('Enable','Disable')]
    [string]$reboot = 'Disable',
    [ValidateSet('Enable','Disable')]
    [string]$forceupdate = 'Disable',
    [switch]$scan,
    [switch]$applyUpdates
    )
    $DCUPath = (Get-DCUInstallDetails).DCUPath
    $LogPath = "$env:ProgramData\OEMWrapPS\Logs"
    if (!(Test-Path $LogPath)){$null = New-Item -Path $LogPath -ItemType Directory -Force}
    #Build Argument Strings for each parameter
    if ($updateSeverity){
        [String]$updateSeverity = $($updateSeverity -join ",").ToString()
        $updateSeverityVar = "-updateSeverity=$updateSeverity"
    }
    if ($updateType){
        [String]$updateType = $($updateType -join ",").ToString()
        $updateTypeVar = "-updateType=$updateType"
    }
    if ($updateDeviceCategory){
        [String]$updateDeviceCategory = $($updateDeviceCategory -join ",").ToString()
        $updateDeviceCategoryVar = "-updateDeviceCategory=$updateDeviceCategory"
    }

    #Pick Action, Scan or ApplyUpdates if both are selected, ApplyUpdates will be the action, if neither are selected, Scan will be the action
    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
    if ($scan){
        $ActionVar = "/scan -report=$LogPath"
        $Action = "Scan"
    }
    if ($applyUpdates){
        $ActionVar = "/applyUpdates"
        $Action = "ApplyUpdates"
    }
    else {
        $ActionVar = "/scan -report=$LogPath"
        $Action = "Scan"
    }
    

    #Create Arugment List for Dell Command Update CLI
    $ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`""
    Write-Verbose $ArgList
    $DCUApply = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
    if ($DCUApply.ExitCode -ne 0){
        $ExitInfo = Get-DCUExitInfo -DCUExit $DCUApply.ExitCode
        Write-Verbose "Exit: $($DCUApply.ExitCode)"
        Write-Verbose "Description: $($ExitInfo.Description)"
        Write-Verbose "Resolution: $($ExitInfo.Resolution)"
    }
}
