#requires -Version 7.2
param(
    [Parameter(Mandatory)][ValidateSet('local', 'aks', 'aci')][string]$Target
)
. "$PSScriptRoot\Demo.Common.ps1"
. "$PSScriptRoot\VoteFlow.ps1"
$config = Get-DemoConfig
$null = Get-DemoBaseline
$receiptPath = Join-Path $script:StateRoot "$Target.receipt.json"
if (-not (Test-Path -LiteralPath $receiptPath)) { throw "Deploy $Target before testing its vote flow." }
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
if ($receipt.status -ne 'deployed') { throw "The last $Target deployment did not finish successfully." }
Assert-DemoFingerprints $receipt.hashes
$receipt.voteProof = $null
Write-DemoJson $receiptPath $receipt
Write-Host "Testing $Target with one new, Dogs vote. Keep other users off the demo while this runs."
$urls = Get-DemoUrls $Target $config
$proof = Invoke-DemoVoteProof -VoteUrl $urls.Vote -ResultUrl $urls.Result -ConnectionHint (Get-DemoEndpointHint $Target $config)
$receipt.voteProof = $proof
Write-DemoJson $receiptPath $receipt
Write-Host "PASS | $Target | Dogs: $($proof.before.b) -> $($proof.after.b) | vote -> Redis -> worker -> PostgreSQL -> result"
