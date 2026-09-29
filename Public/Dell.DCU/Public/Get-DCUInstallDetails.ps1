Function Get-DCUInstallDetails {
    #Declare Variables for Universal app if RegKey AppCode is Universal or if Regkey AppCode is Classic and declares their variables otherwise reports not installed
    If((Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue) -eq "Universal"){
        $Version = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name ProductVersion -ErrorAction SilentlyContinue
        $AppType = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue
        #Add DCU-CLI.exe as Environment Variable for Universal app type
        $DCUPath = 'C:\Program Files\Dell\CommandUpdate\'
    }
    ElseIf((Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode -ErrorAction SilentlyContinue) -eq "Classic"){
        
        $Version = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name ProductVersion
        $AppType = Get-ItemPropertyValue HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings -Name AppCode
        #Add DCU-CLI.exe as Environment Variable for Classic app type
        $DCUPath = 'C:\Program Files (x86)\Dell\CommandUpdate\'
    }
    Else{
        $DCU =  "DCU is not installed"
    }
    if ($Version){
        $DCU = [PSCustomObject]@{
            Version = $Version
            AppType = $AppType
            DCUPath = $DCUPath
        }
    }
    return $DCU
}
