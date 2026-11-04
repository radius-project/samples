#requires -Version 7.2
param([string]$Location = 'eastus2')
. "$PSScriptRoot\Demo.Common.ps1"
Initialize-DemoState
$null = New-DemoPolicyBundle -Location $Location
Write-Host 'Policy bundle: platform\generated\policy-bundle.json'
Write-Host 'To prepare on macOS, copy only this nonsecret bundle to a checkout with the same source files and Azure location.'
