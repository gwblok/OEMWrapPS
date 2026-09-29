function Get-OEMHPIAPaths {
    $root = Join-Path $env:ProgramData 'OEMWrapPS'
    [pscustomobject]@{
        Install = Join-Path $root 'HPIA\bin'
        Downloads = Join-Path $root 'Downloads\HPIA'
        DriverPacks = Join-Path $root 'Downloads\HPDriverPacks'
        Catalogs = Join-Path $root 'Catalogs\HPIA'
        Logs = Join-Path $root 'Logs\HPIA'
        Reports = Join-Path $root 'Reports\HPIA'
    }
}

function Write-OEMHPIALog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$LogPath,
        [ValidateSet(1, 2, 3)][int]$Type = 1,
        [string]$Component = 'HPIA'
    )

    $time = Get-Date -Format 'HH:mm:ss.ffffff'
    $date = Get-Date -Format 'MM-dd-yyyy'
    $entry = "<![LOG[$Message]LOG]!><time=`"$time`" date=`"$date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
    Add-Content -LiteralPath $LogPath -Value $entry -Encoding UTF8
}

function Get-HPIALatestVersion {
    $paths = Get-OEMHPIAPaths
    $null = New-Item -Path $paths.Catalogs -ItemType Directory -Force
    $messageCab = Join-Path $paths.Catalogs 'HPIAMsg.cab'
    $messageDirectory = Join-Path $paths.Catalogs 'HPIAMsg'
    $messageXmlPath = Join-Path $paths.Catalogs 'HPIAMsg.xml'
    try { Invoke-WebRequest -Uri 'https://hpia.hpcloud.hp.com/HPIAMsg.cab' -OutFile $messageCab -UseBasicParsing -ErrorAction Stop }
    catch { Invoke-WebRequest -Uri 'https://ftp.hp.com/pub/caps-softpaq/cmit/imagepal/HPIAMsg.cab' -OutFile $messageCab -UseBasicParsing -ErrorAction Stop }
    Remove-Item -LiteralPath $messageDirectory, $messageXmlPath -Recurse -Force -ErrorAction SilentlyContinue
    $null = New-Item -Path $messageDirectory -ItemType Directory -Force
    & "$env:SystemRoot\System32\expand.exe" '-F:*' $messageCab $messageDirectory | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not expand '$messageCab' (exit code $LASTEXITCODE)." }
    $innerCab = Get-ChildItem -LiteralPath $messageDirectory -Filter '*.cab' -File -Recurse | Select-Object -First 1
    if (-not $innerCab) { throw "HPIA message CAB '$messageCab' did not contain the expected inner CAB." }
    & "$env:SystemRoot\System32\expand.exe" $innerCab.FullName $messageXmlPath | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $messageXmlPath -PathType Leaf)) { throw "HPIA version metadata XML was not found in '$messageCab'." }
    [xml]$metadata = Get-Content -LiteralPath $messageXmlPath -Raw -ErrorAction Stop
    $downloadUrl = [string]$metadata.ImagePal.HPIALatest.SoftpaqURL
    $version = [string]$metadata.ImagePal.HPIALatest.Version
    if (-not $downloadUrl -or -not $version) { throw 'HPIA version metadata is incomplete.' }
    [pscustomobject]@{ Version = $version; DownloadUri = [uri]$downloadUrl; FileName = [IO.Path]::GetFileName(([uri]$downloadUrl).AbsolutePath) }
}

function Get-HPIAPlatformList {
    $paths = Get-OEMHPIAPaths
    $platformDirectory = Join-Path $paths.Catalogs 'PlatformList'
    $cabPath = Join-Path $platformDirectory 'platformList.cab'
    $xmlPath = Join-Path $platformDirectory 'platformList.xml'
    $null = New-Item -Path $platformDirectory -ItemType Directory -Force
    if (-not (Test-Path -LiteralPath $xmlPath -PathType Leaf)) {
        Invoke-WebRequest -Uri 'https://hpia.hpcloud.hp.com/ref/platformList.cab' -OutFile $cabPath -UseBasicParsing -ErrorAction Stop
        & "$env:SystemRoot\System32\expand.exe" $cabPath $xmlPath | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not expand '$cabPath' (exit code $LASTEXITCODE)." }
    }
    [xml](Get-Content -LiteralPath $xmlPath -Raw -ErrorAction Stop)
}

function Get-HPOSSupport {
    param([string]$Platform)

    $platformId = if ($Platform) { $Platform } else { (Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop).Product }
    $platformList = Get-HPIAPlatformList
    @($platformList.ImagePal.Platform | Where-Object { $_.SystemID -match "^$([regex]::Escape($platformId))$" }).OS | Select-Object OSReleaseIdDisplay, OSBuildId, OSDescription
}

function Get-HPSoftPaqItems {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][string]$OSVersion,
        [Parameter(Mandatory)][ValidateSet('10.0', '11.0')][string]$OS
    )

    $paths = Get-OEMHPIAPaths
    $architecture = if ([Environment]::Is64BitOperatingSystem) { '64' } else { '32' }
    $catalogPlatform = $Platform.ToLowerInvariant()
    $referenceName = "${catalogPlatform}_${architecture}_${OS}.${OSVersion}".ToLowerInvariant()
    $referenceDirectory = Join-Path $paths.Catalogs 'Reference'
    $cabPath = Join-Path $referenceDirectory "$referenceName.cab"
    $xmlPath = Join-Path $referenceDirectory "$referenceName.xml"
    $null = New-Item -Path $referenceDirectory -ItemType Directory -Force
    Invoke-WebRequest -Uri "https://hpia.hpcloud.hp.com/ref/$catalogPlatform/$referenceName.cab" -OutFile $cabPath -UseBasicParsing -ErrorAction Stop
    & "$env:SystemRoot\System32\expand.exe" $cabPath $xmlPath | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not expand '$cabPath' (exit code $LASTEXITCODE)." }
    [xml]$catalog = Get-Content -LiteralPath $xmlPath -Raw -ErrorAction Stop
    $catalog.ImagePal.Solutions.UpdateInfo
}