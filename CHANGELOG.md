# Changelog

All notable changes to this project are documented in this file.

## [1.1.2] - 2026-09-28

### Fixed

- Removed the `IGNOREOOBE="1"` property from the Dell Command Update installer command line in `Get-DCUAppUpdates -Install`. The Dell Update Package wrapper only accepts `/s`, `/l=`, `/e=`, `/f`, `/passthrough`, and `/bls`, so the extra `/v` argument caused the package to display its usage text and return a failure exit code instead of installing.
- The installer now runs with `/s /l="<log>"`, and OOBE support is applied only through the `IgnoreOOBE` registry value after a successful install of Dell Command Update 5.7.1 or later.

### References

- [How to Allow Dell Command Update to Run During the Windows Out-of-Box Experience](https://www.dell.com/support/kbdoc/en-us/000497911/how-to-allow-dell-command-update-to-run-during-the-windows-out-of-box-experience?lang=en)

## [1.1.1] - 2026-09-28

### Fixed

- `Get-DCUAppUpdates -Install` now throws when the Dell Command Update installer returns a failure exit code. Previously a failed install (for example Dell DUP exit code 10) was only written to the console, so calling scripts and task sequences reported success.
- Dell DUP exit codes `0` and `2` are treated as success; exit code `2` reports that a reboot is required.
- A failed Dell Command Update download now throws instead of continuing silently.

### Added

- `Get-DCUAppUpdates -Install` returns an install result object with `Version`, `ExitCode`, `CodeName`, `Description`, `LogPath`, `Success`, and `RebootRequired`.

### Changed

- All module working files, downloads, and logs are now written under `C:\ProgramData\OEMWrapPS`, replacing the previous `ProgramData\EMPS`, `C:\Users\Dell\EMPS\Logs`, `%windir%\temp`, `%TEMP%`, and `C:\OSDCloud\Logs` locations.
- Dell catalog and cab downloads use `C:\ProgramData\OEMWrapPS\DellCabDownloads`; Dell BIOS update downloads use `C:\ProgramData\OEMWrapPS\DellBIOSUpdates`.
- Dell Command Update CLI logs are written to `C:\ProgramData\OEMWrapPS\Logs`, and the log directory is created when missing.
- Dell warranty export files use `C:\ProgramData\OEMWrapPS\Dell`, and .NET prerequisite installers use `C:\ProgramData\OEMWrapPS\.NETInstallers`.
- HP platform and HPIA catalog files use `C:\ProgramData\OEMWrapPS\HP`, and the HPIA offline sync log is written to `C:\ProgramData\OEMWrapPS\Logs`.
- `Get-DellUpdate`, `Install-DellUpdate`, and `Get-DellUpdateHist` store catalogs, downloads, history, and logs under `C:\ProgramData\OEMWrapPS`.

## [1.1.0] - 2026-09-27

### Added
- Merged the `Get-DellUpdate`, `Install-DellUpdate`, and `Get-DellUpdateHist` commands and their private helpers from Dell.Client.Update.
- Added native Dell model-catalog scanning, update package verification and installation, and local installation history support.
- Exported the three Dell Client Update commands from OEMWrapPS and documented their requirements and behavior.

## [1.0.12] - 2026-09-26

### Added

- Updated `Get-DCUAppUpdates -Install` to pass Dell's `IGNOREOOBE="1"` installer property when installing Dell Command Update 5.7.1 or later.
- After a successful DCU 5.7.1+ installation, verify `HKLM\SOFTWARE\DELL\UpdateService\Service\UpdateScheduler\IgnoreOOBE` is a DWORD set to `1`; create or correct it when needed.
- Re-verify the OOBE registry setting after a successful prerequisite-triggered installer retry.

### References

- [How to Allow Dell Command Update to Run During the Windows Out-of-Box Experience](https://www.dell.com/support/kbdoc/en-us/000497911/how-to-allow-dell-command-update-to-run-during-the-windows-out-of-box-experience?lang=en)


## [1.0.11] - 2026-09-25

### Removed
- Removed `Invoke-DellIntuneAppPublishScript` from the module because Intune application publishing is outside OEMWrapPS's hardware-management scope.

## [1.0.10] - 2026-09-25

### Added
- Extended `Set-DCUSettings` with schedule frequency and time configuration.
- Added delay-days configuration for excluding recently released updates.
- Added device category, severity, and update type filter configuration.
- Added support for scripted configuration of the expanded DCU settings surface.

## [1.0.9] - 2026-09-25

### Changed
- Updated `Get-DellBIOSUpdates -Flash` so Dell DUP exit code 2 is reported as a successful update with reboot required.
- Added the `RebootRequired` property to flash results.

## [1.0.8] - 2026-09-25

### Added
- Added the `-Details` parameter to `Get-DellBIOSUpdates`.
- Added BIOS status properties for current/latest versions and release dates, update availability, current-state status, and `ReleasesSinceCurrent`.
- `ReleasesSinceCurrent` counts distinct BIOS releases newer than the installed BIOS version.

## [1.0.7] - 2026-09-24

### Changed
- Updated `Get-DellBIOSUpdates -Flash` to decode Dell DUP BIOS exit codes for successful, reboot-required, dependency, password, downgrade, RPM verification, and unspecified hardware/EC errors.
- Added parsing of the Dell BIOS installer log so `Error:` text is returned as the result description and `Exit Code =` text is returned as the code name.
- `Get-DellBIOSUpdates -Flash` now returns structured flash results including the update name, numeric exit code, code name, description, log path, and success status.
- Corrected the documented mappings for Dell DUP exit codes 8, 9, and 10.

## [1.0.6] - 2026-09-08

### Changed
- Reduced prerequisite logging in `Get-DCUAppUpdates` to report the first human-readable missing-prerequisite message instead of every detailed MSI diagnostic line.
- Changed intermediate .NET version discovery messages in `Get-LatestDotNetVersion` to verbose output so normal runs show only the final version selected for installation.

## [1.0.5] - 2026-09-08

### Changed
- Added `-Install`, `-AutoInstallPreReqs`, `-UseWebRequest`, `-CheckPreReqs`, and `-DownloadPath` parameters to `Get-DCUAppUpdates` for DCU installation and prerequisite handling.
- Added `Install-DCUPreReqDOTNet` to install the required .NET Desktop Runtime.
- When a DCU installation first fails because a prerequisite is missing, `Get-DCUAppUpdates -AutoInstallPreReqs` now detects the required .NET version, installs it, and retries the DCU installation.

## [1.0.4] - 2026-08-19

### Changed
- Added BitLocker preflight handling to `Get-DellBIOSUpdates -Flash` so BIOS flashing is blocked when the volume is encrypting or decrypting.
- When BitLocker protection is on and the drive is fully encrypted, the flash path now suspends BitLocker before flashing.
- Improved BIOS flash messaging so the function reports why a flash is skipped before attempting the update.

## [1.0.3] - 2026-08-18

### Changed
- Updated `Set-DellBIOSSetting` informational output to include setting context in success messages.
- Updated `Set-DellBIOSSetting` action messages to include the target setting name and value.
- Updated `Get-DellBIOSSetting` specific-setting retrieval message for clearer output.
- Added support for array input in `Get-DellBIOSSetting -SettingName` via `[String[]]`.
- Added per-setting lookup handling for array input, including warnings when requested setting names are not found.

## [1.0.2] - 2026-07-17

### Added
- Initial published module manifest and command export set for Dell and HP wrapper functions.
