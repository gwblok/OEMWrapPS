#Requires -Version 5.1
<#
.SYNOPSIS
    OEMWrapPS - PowerShell Module for OEM Hardware Management

.DESCRIPTION
    OEMWrapPS is a PowerShell module that wraps OEM-specific hardware management functions
    for Dell and HP devices. It includes functions for Dell BIOS management via WMI,
    Dell Command Update (DCU) management, Dell warranty retrieval, and HP Image Assistant
    (HPIA) platform support.

    Sources:
    - Dell BIOS Functions: https://github.com/gwblok/2PintLabs/blob/main/DeployR/BIOSSettings/Dell/NativeWMI/SetDellBIOSSettingsWMI-Functions.ps1
    - Dell DCU Functions:  https://github.com/gwblok/garytown/blob/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPS.ps1
    - Dell Warranty Functions: https://github.com/gwblok/garytown/blob/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPSWarranty.ps1
    - HP HPIA Functions:   https://github.com/gwblok/garytown/blob/master/hardware/HP/EMPS/Test-HPIASupport.ps1

.NOTES
    Author: Gary Blok (@gwblok) - GARYTOWN.COM
#>

# Dot-source all function files from the Public directory
$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'

if (Test-Path $PublicPath) {
    $PublicFiles = Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse
    foreach ($File in $PublicFiles) {
        . $File.FullName
    }
}
