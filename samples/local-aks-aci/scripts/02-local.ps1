#requires -Version 7.2
param([switch]$Plan)
. "$PSScriptRoot\Demo.Common.ps1"
Write-Host 'STEP 2 | Local Kubernetes'
Invoke-DemoDeployment -Target local -Plan:$Plan
