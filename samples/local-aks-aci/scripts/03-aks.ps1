#requires -Version 7.2
param([switch]$Plan)
. "$PSScriptRoot\Demo.Common.ps1"
Write-Host 'STEP 3 | AKS and Azure PostgreSQL'
Invoke-DemoDeployment -Target aks -Plan:$Plan
