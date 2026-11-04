#requires -Version 7.2
param([switch]$Plan)
. "$PSScriptRoot\Demo.Common.ps1"
Write-Host 'STEP 4 | Confidential ACI and Azure PostgreSQL'
Invoke-DemoDeployment -Target aci -Plan:$Plan
