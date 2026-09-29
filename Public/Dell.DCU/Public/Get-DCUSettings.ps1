function Get-DCUSettings {
    [CmdletBinding()]
    param (
        [switch]$ResetSettings
    )
    write-host "Note: Info is in Registry here:" -ForegroundColor Cyan
    write-Host "HKEY_LOCAL_MACHINE\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings" -ForegroundColor Yellow
    $RegPath = "HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings"
    if (!(Test-Path $RegPath)){
        Write-Output "No DCU Settings Found"
        return
    }

    $Keys = Get-ChildItem -Path $RegPath 
    Write-output $Keys
    if ($ResetSettings){
        $Items = Get-ChildItem -Path $RegPath | Get-ItemProperty
        foreach ($Item in $Items){
            $ItemName = $Item.PSChildName
            Write-Output "Deleting $ItemName"
            Remove-Item -Path $Item.PSPath -Force
        }
    }
}
