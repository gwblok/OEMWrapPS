function Test-HPIASupport {
    [CmdletBinding()]
    param([string]$PlatformID)

    $platform = if ($PlatformID) { $PlatformID } else { (Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop).Product }
    $platformList = Get-HPIAPlatformList
    [bool]($platform -in @($platformList.ImagePal.Platform.SystemID))
}