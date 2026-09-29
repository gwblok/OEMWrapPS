function Get-DellDriverPackXML {
    [CmdletBinding()]
    
    $CabPathIndex = "$env:ProgramData\OEMWrapPS\DellCabDownloads\CatalogIndexPC.cab"
    $DellCabExtractPath = "$env:ProgramData\OEMWrapPS\DellCabDownloads\DellCabExtract"
    
    # Pull down Dell XML CAB used in Dell Command Update ,extract and Load
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    Write-Verbose "Downloading Dell Cab"
    Invoke-WebRequest -Uri "https://downloads.dell.com/catalog/DriverPackCatalog.cab" -OutFile $CabPathIndex -UseBasicParsing -Proxy $ProxyServer
    If(Test-Path "$DellCabExtractPath\DellSDPCatalogPC.xml"){Remove-Item -Path "$DellCabExtractPath\DellSDPCatalogPC.xml" -Force}
    Start-Sleep -Seconds 1
    if (test-path $DellCabExtractPath){Remove-Item -Path $DellCabExtractPath -Force -Recurse}
    $null = New-Item -Path $DellCabExtractPath -ItemType Directory
    Write-Verbose "Expanding the Cab File..." 
    $null = expand $CabPathIndex $DellCabExtractPath\DriverPackCatalog.xml
    
    Write-Verbose "Loading Dell Catalog XML.... can take awhile"
    [xml]$XMLIndex = Get-Content "$DellCabExtractPath\DriverPackCatalog.xml"
    
    return $XMLIndex
}
