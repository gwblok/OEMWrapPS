function Get-DCUUpdateList {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$False)]
        [ValidateLength(4,4)]    
        [string]$SystemSKUNumber,
        [ValidateSet('bios','firmware','driver','application')]
        [String[]]$updateType,
        [ValidateSet('audio','video','network','chipset','storage','BIOS','Application')]
        [String[]]$updateDeviceCategory,
        [switch]$RAWXML,
        [switch]$Latest,
        [switch]$TLDR
    )

    
    $temproot = "$env:ProgramData\OEMWrapPS"
    #$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    $Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    $CabPathIndexModel = "$temproot\DellCabDownloads\CatalogIndexModel.cab"
    $DellCabExtractPath = "$temproot\DellCabDownloads\DellCabExtract"
    if (!(Test-Path $DellCabExtractPath)){$null = New-Item -Path $DellCabExtractPath -ItemType Directory -Force}
    
    
    if (!($SystemSKUNumber)) {
        if ($Manufacturer -notmatch "Dell"){return "This Function is only for Dell Systems"}
        $SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
    }
    $DellSKU = Get-DellSupportedModels | Where-Object {$_.systemID -match $SystemSKUNumber} | Select-Object -First 1
    if (!($DellSKU)){
        return "System SKU not found"
    }
    if (Test-Path $CabPathIndexModel){Remove-Item -Path $CabPathIndexModel -Force}
    

    Invoke-WebRequest -Uri "http://downloads.dell.com/$($DellSKU.URL)" -OutFile $CabPathIndexModel -UseBasicParsing
    if (Test-Path $CabPathIndexModel){
        $null = expand $CabPathIndexModel $DellCabExtractPath\CatalogIndexPCModel.xml
        [xml]$XMLIndexCAB = Get-Content "$DellCabExtractPath\CatalogIndexPCModel.xml"
        
        #DCUAppsAvailable = $XMLIndexCAB.Manifest.SoftwareComponent | Where-Object {$_.ComponentType.value -eq "APAC"}
        #$AppNames = $DCUAppsAvailable.name.display.'#cdata-section' | Select-Object -Unique
        $BaseURL = "https://$($XMLIndexCAB.Manifest.baseLocation)"
        $Components = $XMLIndexCAB.Manifest.SoftwareComponent
        if ($RAWXML){
            return $Components
        }
        $ComponentsObject = @()
        foreach ($Component in $Components){
            $Item = New-Object -TypeName PSObject
            $Item | Add-Member -MemberType NoteProperty -Name "PackageID" -Value "$($Component.packageID)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Category" -Value "$($Component.Category.Display.'#cdata-section')"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Type" -Value "$($component.ComponentType.Display.'#cdata-section')"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($Component.Name.Display.'#cdata-section')" -Force
            $Item | Add-Member -MemberType NoteProperty -Name "ReleaseDate" -Value $([DateTime]($Component.releaseDate)) -Force
            $Item | Add-Member -MemberType NoteProperty -Name "DellVersion" -Value "$($Component.dellVersion)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "VendorVersion" -Value "$($Component.vendorVersion)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "PackageType" -Value "$($Component.packageType)"  -Force
            $Item | Add-Member -MemberType NoteProperty -Name "Path" -Value "$BaseURL/$($Component.path)" -Force		
            $Item | Add-Member -MemberType NoteProperty -Name "Description" -Value "$($component.Description.Display.'#cdata-section')" -Force		
            $ComponentsObject += $Item 
        }
        if ($updateType){
            $ComponentsObject = $ComponentsObject | Where-Object {$_.Type -in $updateType}
        }
        if ($updateDeviceCategory){
            $ComponentsObject = $ComponentsObject | Where-Object {$_.Category -in $updateDeviceCategory}
        }
        if ($TLDR) {
            $ComponentsObject = $ComponentsObject | Select-Object -Property Name,ReleaseDate,DellVersion,Path
        }
        if ($Latest){
            $ComponentsObject = $ComponentsObject | Sort-Object -Property ReleaseDate -Descending
            $hash = @{}
            foreach ($ComponentObject in $ComponentsObject) {
                if (-not $hash.ContainsKey($ComponentObject.Name)) {
                    $hash[$ComponentObject.Name] = $ComponentObject
                }
            }
            $ComponentsObject = $hash.Values 
        }
        return $ComponentsObject
    }
}
