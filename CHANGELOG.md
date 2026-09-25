# Changelog

All notable changes to this project are documented in this file.

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
