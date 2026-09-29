function Set-DCUSettings {
    [CmdletBinding()]
    param (
    [ValidateSet('Enable','Disable')]
    [string]$advancedDriverRestore,
    [ValidateSet('Enable','Disable')]
    [string]$autoSuspendBitLocker = 'Enable',
    [ValidateSet('Enable','Disable')]
    [string]$installationDeferral,
    [ValidateRange(0,99)]
    [int]$deferralInstallInterval = 3,
    [ValidateRange(0,9)]
    [int]$deferralInstallCount = 5,

    [ValidateSet('Enable','Disable')]
    [string]$systemRestartDeferral,
    [ValidateRange(0,99)]
    [int]$deferralRestartInterval = 3,
    [ValidateRange(0,9)]
    [int]$deferralRestartCount = 5,

    #[ValidateSet('Enable','Disable')]
    #[string]$reboot = 'Disable',
    [ValidateSet('NotifyAvailableUpdates','DownloadAndNotify','DownloadInstallAndNotify')]
    [string]$scheduleAction = 'DownloadInstallAndNotify',
    [switch]$scheduleAuto,
    [string]$CustomCatalogPath, #Path to a custom catalog file for Offline DCU or just to lock in a specific catalog
    [ValidateRange(1,45)]
    [int]$ExcludeUpdatesFromLastNDays, #Excludes updates released within the last N days from being applied
    [ValidateSet('scheduleAuto','scheduleManual','scheduleDaily','scheduleWeekly','scheduleMonthly')]
    [string]$Schedule,
    [string]$ScheduleDaily,
    [string]$ScheduleWeekly,
    [string]$ScheduleMonthly,
    [ValidateSet('Enable','Disable')]
    [string]$UpdateDeviceCategoryFilter = 'Disable',
    [string[]]$UpdateDeviceCategories,
    [ValidateSet('Enable','Disable')]
    [string]$UpdateSeverityFilter = 'Disable',
    [string[]]$UpdateSeverities,
    [ValidateSet('Enable','Disable')]
    [string]$UpdateTypeFilter = 'Disable',
    [string[]]$UpdateTypes
    )
    
    $DCUPath = (Get-DCUInstallDetails).DCUPath
    Write-Verbose "DCU Path: $DCUPath"
    $LogPath = "$env:ProgramData\OEMWrapPS\Logs"
    if (!(Test-Path $LogPath)){$null = New-Item -Path $LogPath -ItemType Directory -Force}
    Write-Verbose "Log Path: $LogPath"
    $DateTimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"

    function Invoke-DCUConfigure {
        param(
            [Parameter(Mandatory)]
            [string]$Setting,
            [string]$LogName = $Setting
        )

        $configureArgs = "/configure $Setting -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-$LogName.log`""
        Write-Verbose $configureArgs
        $configureProcess = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $configureArgs -NoNewWindow -PassThru -Wait
        if ($configureProcess.ExitCode -ne 0) {
            $exitInfo = Get-DCUExitInfo -DCUExit $configureProcess.ExitCode
            Write-Verbose "Exit: $($configureProcess.ExitCode)"
            Write-Verbose "Description: $($exitInfo.Description)"
            Write-Verbose "Resolution: $($exitInfo.Resolution)"
        }
        return $configureProcess
    }
    #$ArgList = "$ActionVar $updateSeverityVar $updateTypeVar $updateDeviceCategoryVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-$Action.log`""

    if ($advancedDriverRestore){
        $advancedDriverRestoreVar = "-advancedDriverRestore=$advancedDriverRestore -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-advancedDriverRestore.log`""
        $ArgList = "/configure $advancedDriverRestoreVar"
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($autoSuspendBitLocker){ 
        $autoSuspendBitLockerVar = "-autoSuspendBitLocker=$autoSuspendBitLocker -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-autoSuspendBitLocker.log`""
        $ArgList = "/configure $autoSuspendBitLockerVar"
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($scheduleAction){
        $scheduleActionVar = "-scheduleAction=$scheduleAction"
        $ArgList = "/configure $scheduleActionVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-scheduleAction.log`""
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($scheduleAuto){
        $scheduleAutoVar = "-scheduleAuto"
        $ArgList = "/configure $scheduleAutoVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-scheduleAuto.log`""
        Write-Verbose $ArgList
        $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    #Installation Deferral
    if ($installationDeferral){
        if ($scheduleAction -ne 'DownloadInstallAndNotify'){
            Write-Verbose "Schedule Action must be set to DownloadInstallAndNotify to use Installation Deferral"
            
        }
        else {
            if ($installationDeferral -eq 'Enable'){
                $installationDeferralVar = "-installationDeferral=$installationDeferral"
                if ($deferralInstallInterval){
                    [string]$deferralInstallIntervalVar = "-deferralInstallInterval=$deferralInstallInterval"
                }
                else {
                    [string]$deferralInstallIntervalVar = "-deferralInstallInterval=5"
                }
                if ($deferralInstallCount){
                    [string]$deferralInstallCountVar = "-deferralInstallCount=$deferralInstallCount"
                }
                else {
                    [string]$deferralInstallCountVar = "-deferralInstallCount=5"
                }
                $ArgList = "/configure $installationDeferralVar $deferralInstallIntervalVar $deferralInstallCountVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-installationDeferral.log`""
                Write-Verbose $ArgList
                $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
                if ($DCUConfig.ExitCode -ne 0){
                    $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                    Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                    Write-Verbose "Description: $($ExitInfo.Description)"
                    Write-Verbose "Resolution: $($ExitInfo.Resolution)"
                }
                
            }
            else {
                [string]$installationDeferralVar = "-installationDeferral=$installationDeferral"
                $ArgList = "/configure $installationDeferralVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-installationDeferral.log`""
                Write-Verbose $ArgList
                $DCUCOnfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
                if ($DCUConfig.ExitCode -ne 0){
                    $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                    Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                    Write-Verbose "Description: $($ExitInfo.Description)"
                    Write-Verbose "Resolution: $($ExitInfo.Resolution)"
                }
            }
        }
    }
    #System Reboot Deferral
    if ($systemRestartDeferral){
        if ($scheduleAction -ne 'DownloadInstallAndNotify'){
            Write-Verbose "Schedule Action must be set to DownloadInstallAndNotify to use Installation Deferral"
            
        }
        else {
            if ($systemRestartDeferral -eq 'Enable'){
                $systemRestartDeferralVar = "-systemRestartDeferral=$systemRestartDeferral"
                if ($deferralRestartInterval){
                    [string]$deferralRestartIntervalVar = "-deferralRestartInterval=$deferralRestartInterval"
                }
                else {
                    [string]$deferralRestartIntervalVar = "-deferralRestartInterval=5"
                }
                if ($deferralRestartCount){
                    [string]$deferralRestartCountVar = "-deferralRestartCount=$deferralRestartCount"
                }
                else {
                    [string]$deferralRestartCountVar = "-deferralRestartCount=5"
                }
                $ArgList = "/configure $systemRestartDeferralVar $deferralRestartIntervalVar $deferralRestartCountVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-RestartDeferral.log`""
                Write-Verbose $ArgList
                $DCUConfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
                if ($DCUConfig.ExitCode -ne 0){
                    $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                    Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                    Write-Verbose "Description: $($ExitInfo.Description)"
                    Write-Verbose "Resolution: $($ExitInfo.Resolution)"
                }
                
            }
            else {
                [string]$systemRestartDeferralVar = "-systemRestartDeferral=$systemRestartDeferral"
                $ArgList = "/configure $systemRestartDeferralVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-RestartDeferral.log`""
                Write-Verbose $ArgList
                $DCUConfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
                if ($DCUConfig.ExitCode -ne 0){
                    $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
                    Write-Verbose "Exit: $($DCUConfig.ExitCode)"
                    Write-Verbose "Description: $($ExitInfo.Description)"
                    Write-Verbose "Resolution: $($ExitInfo.Resolution)"
                }
            }
        }
    }
    if ($CustomCatalogPath){
        $CustomCatalogPathVar = "-catalogLocation=`"$CustomCatalogPath`" -allowXML=enable"
        $ArgList = "/configure $CustomCatalogPathVar -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-CustomCatalogPath.log`""
        Write-Verbose $ArgList
        $DCUConfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }
    if ($ExcludeUpdatesFromLastNDays){
        $ExcludeUpdatesFromLastNDaysVar = "-delaydays=$ExcludeUpdatesFromLastNDays -outputlog=`"$LogPath\DCU-CLI-$($DateTimeStamp)-Configure-ExcludeUpdatesFromLastNDays.log`""
        $ArgList = "/configure $ExcludeUpdatesFromLastNDaysVar"
        Write-Verbose $ArgList
        $DCUConfig = Start-Process -FilePath "$DCUPath\dcu-cli.exe" -ArgumentList $ArgList -NoNewWindow -PassThru -Wait
        if ($DCUConfig.ExitCode -ne 0){
            $ExitInfo = Get-DCUExitInfo -DCUExit $DCUConfig.ExitCode
            Write-Verbose "Exit: $($DCUConfig.ExitCode)"
            Write-Verbose "Description: $($ExitInfo.Description)"
            Write-Verbose "Resolution: $($ExitInfo.Resolution)"
        }
    }

    if ($Schedule) {
        switch ($Schedule) {
            'scheduleAuto' { $scheduleSetting = '-scheduleAuto' }
            'scheduleManual' { $scheduleSetting = '-scheduleManual' }
            'scheduleDaily' { $scheduleSetting = "-scheduleDaily=$ScheduleDaily" }
            'scheduleWeekly' { $scheduleSetting = "-scheduleWeekly=$ScheduleWeekly,$ScheduleDaily" }
            'scheduleMonthly' { $scheduleSetting = "-scheduleMonthly=$ScheduleMonthly,$ScheduleWeekly,$ScheduleDaily" }
        }
        Invoke-DCUConfigure -Setting $scheduleSetting -LogName 'schedule'
    }

    if ($UpdateDeviceCategoryFilter -eq 'Enable' -and $UpdateDeviceCategories) {
        Invoke-DCUConfigure -Setting "-updateDeviceCategory=$($UpdateDeviceCategories -join ',')" -LogName 'updateDeviceCategory'
    }
    if ($UpdateSeverityFilter -eq 'Enable' -and $UpdateSeverities) {
        Invoke-DCUConfigure -Setting "-updateSeverity=$($UpdateSeverities -join ',')" -LogName 'updateSeverity'
    }
    if ($UpdateTypeFilter -eq 'Enable' -and $UpdateTypes) {
        Invoke-DCUConfigure -Setting "-updateType=$($UpdateTypes -join ',')" -LogName 'updateType'
    }
}
