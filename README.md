# OEMWrapPS

PowerShell module wrapping OEM hardware management functions for Dell and HP devices.

## Overview

OEMWrapPS consolidates commonly used OEM hardware management functions into a single PowerShell module. It includes functions for Dell BIOS management, Dell Command Update (DCU), Dell warranty retrieval, and HP Image Assistant (HPIA) platform support.

## Installation

```powershell
# Clone the repository and import the module
Import-Module .\OEMWrapPS\OEMWrapPS.psd1
```

## Included Functions

### Dell – BIOS (via WMI/CIM)

Source: [2PintLabs/SetDellBIOSSettingsWMI-Functions.ps1](https://github.com/gwblok/2PintLabs/blob/main/DeployR/BIOSSettings/Dell/NativeWMI/SetDellBIOSSettingsWMI-Functions.ps1)

| Function | Description |
|---|---|
| `Test-DellBIOSWMISupport` | Verifies if the device supports Dell BIOS WMI management |
| `Test-DellBIOSPassword` | Checks if a BIOS Admin or System password is currently set |
| `Get-DellBIOSSetting` | Retrieves BIOS settings from the device |
| `Set-DellBIOSSetting` | Modifies BIOS settings on the device |
| `Set-DellBIOSAdminPassword` | Simplified function to set, change, or remove BIOS Admin password |

### Dell – Command Update (DCU)

Source: [garytown/Dell-EMPS.ps1](https://github.com/gwblok/garytown/blob/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPS.ps1)

| Function | Description |
|---|---|
| `Get-DellSupportedModels` | Retrieves supported Dell models from the DCU XML catalog |
| `Get-DellDriverPackXML` | Downloads and parses the Dell Driver Pack catalog XML |
| `Get-DCUVersion` | Returns the installed Dell Command Update version |
| `Get-DCUInstallDetails` | Returns DCU install details (version, app type, path) |
| `Get-DCUExitInfo` | Provides descriptions for DCU exit codes |
| `Get-DUPExitInfo` | Provides descriptions for Dell Update Package exit codes |
| `Install-DCU` | Downloads and installs the latest Dell Command Update |
| `Get-DCUAppUpdates` | Retrieves available app updates from DCU |
| `Set-DCUSettings` | Configures DCU settings via dcu-cli.exe |
| `Get-DCUSettings` | Lists current DCU settings from the registry |
| `Invoke-DCU` | Invokes DCU actions (scan, apply updates, etc.) |
| `Invoke-DCUBITS` | Invokes DCU using BITS for download |
| `New-DCUOfflineCatalog` | Creates an offline DCU catalog (Beta) |
| `New-DCUCatalogFile` | Downloads the DCU catalog file for a system model (Beta) |
| `Get-DCUUpdateList` | Retrieves the list of available updates from DCU |
| `Get-DellDeviceDetails` | Retrieves Dell device details (model, system ID) |
| `Get-DellDeviceDriverPack` | Retrieves the driver pack for a Dell device |
| `Get-DellBIOSUpdates` | Retrieves BIOS updates available for the device |
| `Invoke-DellIntuneAppPublishScript` | Invokes the Dell Intune app publish script |

### Dell – Warranty

Source: [garytown/Dell-EMPSWarranty.ps1](https://github.com/gwblok/garytown/blob/master/hardware/Dell/CommandUpdate/EMPS/Dell-EMPSWarranty.ps1)

| Function | Description |
|---|---|
| `Get-DellWarrantyInfo` | Retrieves Dell warranty information using Dell Command Integration Suite |

### HP – Image Assistant (HPIA)

Source: [garytown/Test-HPIASupport.ps1](https://github.com/gwblok/garytown/blob/master/hardware/HP/EMPS/Test-HPIASupport.ps1)

| Function | Description |
|---|---|
| `Test-HPIASupport` | Tests if a given HP platform ID is supported by HPIA |
| `Get-HPOSSupport` | Returns the list of supported OS versions for an HP platform |
| `Get-HPSoftpaqListLatest` | Retrieves the latest SoftPaq list for an HP platform |
| `Get-HPSoftPaqItems` | Retrieves SoftPaq items for a specific HP platform and OS version |
| `Get-HPDriverPackLatest` | Returns the latest driver pack available for an HP platform |
| `Invoke-HPIAOfflineSync` | Creates and syncs an offline HPIA repository for a platform |

## Requirements

- PowerShell 5.1 or higher
- For Dell BIOS functions: Dell device with WMI BIOS support (manufactured 2018 or newer), administrative privileges
- For Dell DCU functions: Dell Command Update installed (or use `Install-DCU`)
- For Dell Warranty functions: Dell Command Integration Suite (auto-downloaded if not present)
- For HP HPIA functions: HP device; HP Client Management Script Library (HPCMSL) for `Invoke-HPIAOfflineSync`

## Credits

- Gary Blok ([@gwblok](https://github.com/gwblok)) – GARYTOWN.COM
- Sven Riebe ([@SvenRiebe](https://github.com/svenriebedell)) – Original Dell BIOS WMI implementation
