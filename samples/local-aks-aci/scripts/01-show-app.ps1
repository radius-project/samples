#requires -Version 7.2
. "$PSScriptRoot\Demo.Common.ps1"

Write-Host 'STEP 1 | One application contract'
Write-Host 'vote -> Redis (localhost) -> worker -> PostgreSQL -> result'
Write-Host 'vote + worker + Redis share one deployment unit; result is separate.'
Write-Host ''
Get-FileHash -LiteralPath (Join-Path $script:DemoRoot 'app.bicep') -Algorithm SHA256 |
    Select-Object Algorithm, Hash | Format-Table -AutoSize
$lock = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable
$lock.images.GetEnumerator() | Sort-Object Key |
    Select-Object @{ Name = 'Component'; Expression = { $_.Key } }, @{ Name = 'Immutable image'; Expression = { $_.Value } } |
    Format-Table -Wrap
Write-Host 'Open app.bicep in the editor. There is no AKS, ACI, region, SKU, or confidential policy in this file.'
