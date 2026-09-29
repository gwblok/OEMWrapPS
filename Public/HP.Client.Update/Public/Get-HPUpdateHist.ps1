function Get-HPUpdateHist {
    <#
    .SYNOPSIS
        Gets HP update installation history.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Success', 'Failed')][string[]]$Status,
        [string[]]$Category,
        [string[]]$Type,
        [ValidateRange(1, [int]::MaxValue)][int]$Last
    )

    $historyPath = Get-HPUpdatePath -Name History
    if (-not (Test-Path -LiteralPath $historyPath -PathType Container)) { return }
    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($historyFile in (Get-ChildItem -LiteralPath $historyPath -Filter 'InstallHist-*.json' -File -ErrorAction Stop)) {
        try { $fileRecords = @(Get-Content -LiteralPath $historyFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop) }
        catch { Write-Warning "Could not read HP update history file '$($historyFile.FullName)': $($_.Exception.Message)"; continue }
        foreach ($record in $fileRecords) {
            $timestamp = [datetime]::MinValue
            if (-not [datetime]::TryParse([string]$record.Timestamp, [ref]$timestamp)) { Write-Warning "Could not read a record in HP update history file '$($historyFile.FullName)': invalid Timestamp."; continue }
            $record.Timestamp = $timestamp
            $record.PSObject.TypeNames.Insert(0, 'HP.Client.Update.HPUpdateHistory')
            $records.Add($record)
        }
    }
    $results = @($records | Sort-Object Timestamp -Descending)
    if ($PSBoundParameters.ContainsKey('Status')) { $results = @($results | Where-Object { $_.Status -in $Status }) }
    if ($PSBoundParameters.ContainsKey('Category')) { $results = @($results | Where-Object { $_.Category -in $Category }) }
    if ($PSBoundParameters.ContainsKey('Type')) { $results = @($results | Where-Object { $_.Type -in $Type }) }
    if ($PSBoundParameters.ContainsKey('Last')) { $results = @($results | Select-Object -First $Last) }
    $results
}