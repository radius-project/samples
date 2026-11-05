#requires -Version 7.2
param(
    [Parameter(Mandatory)][ValidateSet('local', 'aks', 'aci')][string]$Target
)
. "$PSScriptRoot\Demo.Common.ps1"
$config = Get-DemoConfig
$null = Get-DemoBaseline
$receiptPath = Join-Path $script:StateRoot "$Target.receipt.json"
if (-not (Test-Path -LiteralPath $receiptPath)) { throw "Deploy $Target before opening its pages." }
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
if ($receipt.status -ne 'deployed') { throw "The last $Target deployment did not finish successfully." }
Assert-DemoFingerprints $receipt.hashes
$urls = Get-DemoUrls $Target $config
Write-Host "Vote:   $($urls.Vote)"
Write-Host "Result: $($urls.Result)"
# Open the vote page last so its tab is in front for the first browser vote.
Start-Process $urls.Result
Start-Process $urls.Vote
