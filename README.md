# OEMWrapPS

PowerShell module wrapping OEM hardware management functions for Dell and HP devices.

## Overview

OEMWrapPS consolidates commonly used OEM hardware management functions into a single PowerShell module. It includes functions for Dell BIOS management, Dell Command Update (DCU), Dell warranty retrieval, and HP Image Assistant (HPIA) platform support.

## Installation

```powershell
# Install from PowerShell Gallery
Install-Module -Name OEMWrapPS -Repository PSGallery
Import-Module OEMWrapPS

# Or clone this repository and import the local module
Import-Module .\OEMWrapPS.psd1
```

## Included Functions

### Dell – BIOS (via WMI/CIM)

Source: [Public/Dell-BIOS-Functions.ps1](https://github.com/gwblok/OEMWrapPS/blob/main/Public/Dell-BIOS-Functions.ps1)

| Function | Description |
|---|---|
| `Test-DellBIOSWMISupport` | Verifies if the device supports Dell BIOS WMI management |
| `Test-DellBIOSPassword` | Checks if a BIOS Admin or System password is currently set |
| `Get-DellBIOSSetting` | Retrieves BIOS settings from the device |
| `Set-DellBIOSSetting` | Modifies BIOS settings on the device |
| `Set-DellBIOSAdminPassword` | Simplified function to set, change, or remove BIOS Admin password |

### Dell – Command Update (DCU)

Source: [Public/Dell-DCU-Functions.ps1](https://github.com/gwblok/OEMWrapPS/blob/main/Public/Dell-DCU-Functions.ps1)

| Function | Description |
|---|---|
| `Get-DellSupportedModels` | Retrieves supported Dell models from the DCU XML catalog |
| `Get-DellDriverPackXML` | Downloads and parses the Dell Driver Pack catalog XML |
| `Get-DCUVersion` | Returns the installed Dell Command Update version |
| `Get-DCUInstallDetails` | Returns DCU install details (version, app type, path) |
| `Get-DCUExitInfo` | Provides descriptions for DCU exit codes |
| `Get-DUPExitInfo` | Provides descriptions for Dell Update Package exit codes |
| `Get-DCUAppUpdates` | Retrieves available app updates from DCU |
| `Set-DCUSettings` | Configures DCU settings via dcu-cli.exe |
| `Get-DCUSettings` | Lists current DCU settings from the registry |
| `Invoke-DCU` | Invokes DCU actions (scan, apply updates, etc.) |
| `Get-DCUUpdateList` | Retrieves the list of available updates from DCU |
| `Get-DellDeviceDetails` | Retrieves Dell device details (model, system ID) |
| `Get-DellDeviceDriverPack` | Retrieves the driver pack for a Dell device |
| `Get-DellBIOSUpdates` | Retrieves BIOS updates available for the device |
| `Invoke-DellIntuneAppPublishScript` | Invokes the Dell Intune app publish script |

### Dell – DCU Prerequisites

Source: [Public/Get-DCUPreReqDOTNet.ps1](https://github.com/gwblok/OEMWrapPS/blob/main/Public/Get-DCUPreReqDOTNet.ps1)

| Function | Description |
|---|---|
| `Test-UrlExists` | Tests whether a URL returns a successful response |
| `Get-LatestDotNetVersion` | Finds the latest available .NET runtime version for a major and minor version |
| `Install-DCUPreReqDOTNet` | Downloads and installs the required .NET Desktop Runtime prerequisite |

### Dell – Warranty

Source: [Public/Dell-Warranty-Functions.ps1](https://github.com/gwblok/OEMWrapPS/blob/main/Public/Dell-Warranty-Functions.ps1)

| Function | Description |
|---|---|
| `Get-DellWarrantyInfo` | Retrieves Dell warranty information using Dell Command Integration Suite |

### HP – Image Assistant (HPIA)

Source: [Public/HP-HPIA-Functions.ps1](https://github.com/gwblok/OEMWrapPS/blob/main/Public/HP-HPIA-Functions.ps1)

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
- For Dell DCU functions: Dell Command Update installed
- For Dell Warranty functions: Dell Command Integration Suite (auto-downloaded if not present)
- For HP HPIA functions: HP device; HP Client Management Script Library (HPCMSL) for `Invoke-HPIAOfflineSync`

## Changelog

Version history and release details are tracked in [CHANGELOG.md](CHANGELOG.md).

## Credits

- Gary Blok ([@gwblok](https://github.com/gwblok)) – GARYTOWN.COM
- Sven Riebe ([@SvenRiebe](https://github.com/svenriebedell)) – Original Dell BIOS WMI implementation
