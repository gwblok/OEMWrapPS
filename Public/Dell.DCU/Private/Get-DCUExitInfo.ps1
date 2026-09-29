Function Get-DCUExitInfo {
    [CmdletBinding()]
    param(
        [ValidateRange(0,4000)]
        [int]$DCUExit
    )
    $DCUExitInfo = @(
        @{ExitCode = 2; Description = "None"; Resolution = "None"}
        # Generic application return codes
        @{ExitCode = 0; Description = "Success"; Resolution = "The operation completed successfully."}
        @{ExitCode = 1; Description = "A reboot was required from the execution of an operation."; Resolution = "Reboot the system to complete the operation."}
        @{ExitCode = 2; Description = "An unknown application error has occurred."; Resolution = "None"}
        @{ExitCode = 3; Description = "The current system manufacturer is not Dell."; Resolution = "Dell Command | Update can only be run on Dell systems."}
        @{ExitCode = 4; Description = "The CLI was not launched with administrative privilege"; Resolution = "Invoke the Dell Command | Update CLI with administrative privileges"}
        @{ExitCode = 5; Description = "A reboot was pending from a previous operation."; Resolution = "Reboot the system to complete the operation."}
        @{ExitCode = 6; Description = "Another instance of the same application (UI or CLI) is already running."; Resolution = "Close any running instance of Dell Command | Update UI or CLI and retry the operation."}
        @{ExitCode = 7; Description = "The application does not support the current system model."; Resolution = "Contact your administrator if the current system model in not supported by the catalog."}
        @{ExitCode = 8; Description = "No update filters have been applied or configured."; Resolution = "Supply at least one update filter."}
        # Return codes while evaluating various input validations
        @{ExitCode = 100; Description = "While evaluating the command line parameters, no parameters were detected."; Resolution = "A command must be specified on the command line."}
        @{ExitCode = 101; Description = "While evaluating the command line parameters, no commands were detected."; Resolution = "Provide a valid command and options."}
        @{ExitCode = 102; Description = "While evaluating the command line parameters, invalid commands were detected."; Resolution = "Provide a command along with the supported options for that command"}
        @{ExitCode = 103; Description = "While evaluating the command line parameters, duplicate commands were detected."; Resolution = "Remove any duplicate commands and rerun the command."}
        @{ExitCode = 104; Description = "While evaluating the command line parameters, the command syntax was incorrect."; Resolution = "Ensure that you follow the command syntax: /<command name>. "}
        @{ExitCode = 105; Description = "While evaluating the command line parameters, the option syntax was incorrect."; Resolution = "Ensure that you follow the option syntax: -<option name>."}
        @{ExitCode = 106; Description = "While evaluating the command line parameters, invalid options were detected."; Resolution = "Ensure to provide all required or only supported options."}
        @{ExitCode = 107; Description = "While evaluating the command line parameters, one or more values provided to the specific option was invalid."; Resolution = "Provide an acceptable value."}
        @{ExitCode = 108; Description = "While evaluating the command line parameters, all mandatory options were not detected."; Resolution = "If a command requires mandatory options to run, provide them."}
        @{ExitCode = 109; Description = "While evaluating the command line parameters, invalid combination of options were detected."; Resolution = "Remove any mutually exclusive options and rerun the command."}
        @{ExitCode = 110; Description = "While evaluating the command line parameters, multiple commands were detected."; Resolution = "Except for /help and /version, only one command can be specified in the command line."}
        @{ExitCode = 111; Description = "While evaluating the command line parameters, duplicate options were detected."; Resolution = "Remove any duplicate options and rerun the command"}
        @{ExitCode = 112; Description = "An invalid catalog was detected."; Resolution = "Ensure that the file path provided exists, has a valid extension type, is a valid SMB, UNC, or URL, does not have invalid characters, does not exceed 255 characters and has required permissions. "}
        @{ExitCode = 113; Description = "While evaluating the command line parameters, one or more values provided exceeds the length limit."; Resolution = "Ensure to provide the values of the options within the length limit."}
        # Return codes while running the /scan command
        @{ExitCode = 500; Description = "No updates were found for the system when a scan operation was performed."; Resolution = "The system is up to date or no updates were found for the provided filters. Modify the filters and rerun the commands."}
        @{ExitCode = 501; Description = "An error occurred while determining the available updates for the system, when a scan operation was performed."; Resolution = "Retry the operation."}
        @{ExitCode = 502; Description = "The cancellation was initiated, Hence, the scan operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 503; Description = "An error occurred while downloading a file during the scan operation."; Resolution = "Check your network connection, ensure there is Internet connectivity and Retry the command."}
        # Return codes while running the /applyUpdates command
        @{ExitCode = 1000; Description = "An error occurred when retrieving the result of the apply updates operation."; Resolution = "Retry the operation."}
        @{ExitCode = 1001; Description = "The cancellation was initiated, Hence, the apply updates operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 1002; Description = "An error occurred while downloading a file during the apply updates operation."; Resolution = "Check your network connection, ensure there is Internet connectivity, and retry the command."}
        # Return codes while running the /configure command
        @{ExitCode = 1505; Description = "An error occurred while exporting the application settings."; Resolution = "Verify that the folder exists or have permissions to write to the folder."}
        @{ExitCode = 1506; Description = "An error occurred while importing the application settings."; Resolution = "Verify that the imported file is valid."}
        # Return codes while running the /driverInstall command
        @{ExitCode = 2000; Description = "An error occurred when retrieving the result of the Advanced Driver Restore operation."; Resolution = "Retry the operation."}
        @{ExitCode = 2001; Description = "The Advanced Driver Restore process failed."; Resolution = "Retry the operation."}
        @{ExitCode = 2002; Description = "Multiple driver CABs were provided for the Advanced Driver Restore operation."; Resolution = "Ensure that you provide only one driver CAB file."}
        @{ExitCode = 2003; Description = "An invalid path for the driver CAB was provided as in input for the driver install command."; Resolution = "Ensure that the file path provided exists, has a valid extension type, is a valid SMB, UNC, or URL, does not have invalid characters, does not exceed 255 characters and has required permissions"}
        @{ExitCode = 2004; Description = "The cancellation was initiated, Hence, the driver install operation is canceled."; Resolution = "Retry the operation."}
        @{ExitCode = 2005; Description = "An error occurred while downloading a file during the driver install operation."; Resolution = "Check your network connection, ensure there is Internet connectivity, and retry the command."}
        @{ExitCode = 2006; Description = "Indicates that the Advanced Driver Restore feature is disabled."; Resolution = "Enable the feature using /configure -advancedDriverRestore=enable"}
        @{ExitCode = 2007; Description = "Indicates that the Advanced Diver Restore feature is not supported."; Resolution = "Disable FIPS mode on the system."}
        # Return codes while evaluating the inputs for password encryption
        @{ExitCode = 2500; Description = "An error occurred while encrypting the password during the generate encrypted password operation."; Resolution = "Retry the operation."}
        @{ExitCode = 2501; Description = "An error occurred while encrypting the password with the encryption key provided."; Resolution = "Provide a valid encryption key and Retry the operation. "}
        @{ExitCode = 2502; Description = "The encrypted password provided does not match the current encryption method."; Resolution = "The provided encrypted password used an older encryption method. Reencrypt the password."}
        # Return codes if there are issues with the Dell Client Management Service
        @{ExitCode = 3000; Description = "The Dell Client Management Service is not running."; Resolution = "Start the Dell Client Management Service in the Windows services if stopped."}
        @{ExitCode = 3001; Description = "The Dell Client Management Service is not installed."; Resolution = "Download and install the Dell Client Management Service from the Dell support site."}
        @{ExitCode = 3002; Description = "The Dell Client Management Service is disabled."; Resolution = "Enable the Dell Client Management Service from Windows services if disabled."}
        @{ExitCode = 3003; Description = "The Dell Client Management Service is busy."; Resolution = "Wait until the service is available to process new requests."}
        @{ExitCode = 3004; Description = "The Dell Client Management Service has initiated a self-update install of the application."; Resolution = "Wait until the service is available to process new requests."}
        @{ExitCode = 3005; Description = "The Dell Client Management Service is installing pending updates."; Resolution = "Wait until the service is available to process new requests."}
    )
    $DCUExitInfo | Where-Object {$_.ExitCode -eq $DCUExit}
}
