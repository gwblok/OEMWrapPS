Function Get-DUPExitInfo {
    [CmdletBinding()]
    param(
        [ValidateRange(0,4000)]
        [int]$DUPExit
    )
    $DUPExitInfo = @(
        # Generic application return codes
        @{ExitCode = -1; DisplayName = "Unsuccessful"; Description = "DCU terminating the BIOS execution due to timeout."}
        @{ExitCode = 0; DisplayName = "Success"; Description = "The operation completed successfully."}
        @{ExitCode = 1; DisplayName = "Unsuccessful"; Description = "An error occurred during the update process; the update was not successful."}
        @{ExitCode = 2; DisplayName = "Reboot required"; Description = "Reboot the system to complete the operation."}
        @{ExitCode = 3; DisplayName = "Soft dependency error"; Description = "You attempted to update to the same version of the software or You tried to downgrade to a previous version of the software."}
        @{ExitCode = 4; DisplayName = "Hard dependency error"; Description = "The required prerequisite software was not found on your computer."}
        @{ExitCode = 5; DisplayName = "Qualification error"; Description = "A QUAL_HARD_ERROR cannot be suppressed by using the /f switch."}
        @{ExitCode = 6; DisplayName = "Rebooting computer"; Description = "The computer is being rebooted."}
        @{ExitCode = 7; DisplayName = "Password validation error"; Description = "Password not provided or incorrect password provided for BIOS execution"}
        @{ExitCode = 8; DisplayName = "Requested downgrade is not allowed"; Description = "Downgrading the BIOS to the requested version is not allowed."}
        @{ExitCode = 9; DisplayName = "RPM verification failed"; Description = "The Linux DUP framework failed RPM verification. The update was not successful."}
        @{ExitCode = 10; DisplayName = "EC unspecified error"; Description = "An unspecified error occurred, such as a battery error, embedded-controller error, or hardware failure."}
        )
    $DUPExitInfo | Where-Object {$_.ExitCode -eq $DUPExit}
}
