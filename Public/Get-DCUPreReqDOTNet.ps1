#DeployR 1.2+

# Function to check if a URL exists
function Test-UrlExists {
    param (
        [string]$Url
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Head -UseBasicParsing -ErrorAction Stop
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

# Function to get the latest .NET version by checking URLs starting from the supplied base version
function Get-LatestDotNetVersion {
    param (
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^\d+\.\d+$')]
        [string]$BaseVersion
    )

    $baseUrl = "https://builds.dotnet.microsoft.com/dotnet/Runtime/{0}/dotnet-runtime-{0}-win-x64.exe"
    $baseVersionWithPatch = "$BaseVersion.0"
    $latestVersion = $baseVersionWithPatch
    $maxAttempts = 100  # Limit to avoid infinite loop

    Write-Host "Searching for the latest .NET $BaseVersion version starting from $baseVersionWithPatch..."

    # Extract the patch number and increment
    $versionParts = $baseVersionWithPatch.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]

    for ($i = 0; $i -lt $maxAttempts; $i++) {
        $currentPatch = $patch + $i
        $currentVersion = "$major.$minor.$currentPatch"
        $url = $baseUrl -f $currentVersion

        if (Test-UrlExists -Url $url) {
            $latestVersion = $currentVersion
            Write-Host "Found valid version: $latestVersion"
        } else {
            # If the URL doesn't exist and we've found at least one valid version, stop
            if ($currentPatch -gt $patch) {
                break
            }
        }
    }

    return $latestVersion
}

# Function to download a file using Start-BitsTransfer with fallback to Invoke-WebRequest
function Download-File {
    param (
        [string]$Url,
        [string]$FilePath
    )
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Host "Attempting to download from $Url using BITS..."
            Start-BitsTransfer -Source $Url -Destination $FilePath -ErrorAction Stop
            Write-Host "Download completed using BITS: $FilePath"
        } else {
            Write-Host "File already exists: $FilePath"
        }
    } catch {
        Write-Host "BITS transfer failed, falling back to Invoke-WebRequest for $Url..."
        if (-not (Test-Path $FilePath)) {
            Invoke-WebRequest -Uri $Url -OutFile $FilePath -UseBasicParsing -ErrorAction Stop
            Write-Host "Download completed using Invoke-WebRequest: $FilePath"
        } else {
            Write-Host "File already exists: $FilePath"
        }
    }
}

function Install-DCUPreReqDOTNet {
    [CmdletBinding()]
    param (
        [ValidatePattern('^\d+\.\d+$')]
        [string]$BaseVersion = '10.0',
        [string]$DownloadPath = "$env:TEMP\.NETInstallers"
    )

    # Get the latest version
    $latestVersion = Get-LatestDotNetVersion -BaseVersion $BaseVersion
    Write-Host "Latest version detected: $latestVersion"

# Construct download URLs
$netRuntimeUrl = "https://builds.dotnet.microsoft.com/dotnet/Runtime/$latestVersion/dotnet-runtime-$latestVersion-win-x64.exe"
$aspNetUrl = "https://builds.dotnet.microsoft.com/dotnet/aspnetcore/Runtime/$latestVersion/aspnetcore-runtime-$latestVersion-win-x64.exe"
$desktopRuntimeUrl = "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/$latestVersion/windowsdesktop-runtime-$latestVersion-win-x64.exe"

# Log the identified URLs
Write-Host "Identified URLs for download:"
Write-Host "- ASP.NET Core Runtime: $aspNetUrl"
Write-Host "- .NET Runtime: $netRuntimeUrl"
Write-Host "- .NET Desktop Runtime: $desktopRuntimeUrl"

    # Define local file paths
    if (-not (Test-Path $DownloadPath)) {
        New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
    }

    $aspNetFile = "$DownloadPath\aspnetcore-runtime-$latestVersion-win-x64.exe"
    $netRuntimeFile = "$DownloadPath\dotnet-runtime-$latestVersion-win-x64.exe"
    $desktopRuntimeFile = "$DownloadPath\windowsdesktop-runtime-$latestVersion-win-x64.exe"

    # Download files
    Download-File -Url $aspNetUrl -FilePath $aspNetFile
    Download-File -Url $netRuntimeUrl -FilePath $netRuntimeFile
    Download-File -Url $desktopRuntimeUrl -FilePath $desktopRuntimeFile

    # Install ASP.NET Core Runtime - /quiet /norestart
    Write-Host "Installing ASP.NET Core Runtime $latestVersion..."
    if (Test-Path $aspNetFile) {
        Start-Process -FilePath $aspNetFile -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow
        Write-Host "ASP.NET Core Runtime installation completed."
    } else {
        Write-Host "ASP.NET Core Runtime installer not found. Skipping installation."
    }

    # Install .NET Runtime
    Write-Host "Installing .NET Runtime $latestVersion..."
    if (Test-Path $netRuntimeFile) {
        Start-Process -FilePath $netRuntimeFile -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow
        Write-Host ".NET Runtime installation completed."
    } else {
        Write-Host ".NET Runtime installer not found. Skipping installation."
    }

    # Install .NET Desktop Runtime
    Write-Host "Installing .NET Desktop Runtime $latestVersion..."
    if (Test-Path $desktopRuntimeFile) {
        Start-Process -FilePath $desktopRuntimeFile -ArgumentList "/quiet", "/norestart" -Wait -NoNewWindow
        Write-Host ".NET Desktop Runtime installation completed."
    } else {
        Write-Host ".NET Desktop Runtime installer not found. Skipping installation."
    }

    # Optional: Clean up temp files
    # Remove-Item -Path $DownloadPath -Recurse -Force

    Write-Host "All .NET 10 runtimes installation process completed!"
}