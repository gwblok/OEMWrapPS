# Changelog

All notable changes to this project are documented in this file.

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
