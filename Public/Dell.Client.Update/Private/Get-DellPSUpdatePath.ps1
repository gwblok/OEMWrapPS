function Get-DellPSUpdatePath {
    param(
        [ValidateSet('Root', 'Catalogs', 'Downloads', 'History', 'Logs')]
        [string]$Name = 'Root',
        [switch]$Create
    )

    $rootPath = Join-Path $env:ProgramData 'OEMWrapPS'
    $path = if ($Name -eq 'Root') {
        $rootPath
    }
    else {
        Join-Path $rootPath $Name
    }
    if ($Create) { $null = New-Item -Path $path -ItemType Directory -Force }
    return $path
}