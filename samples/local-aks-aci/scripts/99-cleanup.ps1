#requires -Version 7.2
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param()
. "$PSScriptRoot\Demo.Common.ps1"
$config = Get-DemoConfig
Write-Host "Cleanup scope: tenant $($config.TenantId), subscription $($config.SubscriptionId)."
$ownerPath = Join-Path $script:StateRoot 'owner-id.txt'
if (-not (Test-Path -LiteralPath $ownerPath)) { throw 'No ownership record. Nothing will be deleted.' }
$ownerId = (Get-Content -LiteralPath $ownerPath -Raw).Trim()
Assert-DemoSavedConfig $config
Assert-DemoAzureScope $config
$savedIdentity = Assert-DemoIdentityScope $config -AllowMissing
if ((Test-Path -LiteralPath (Join-Path $script:StateRoot 'aks.receipt.json')) -or
    (Test-Path -LiteralPath (Join-Path $script:StateRoot 'aci.receipt.json'))) {
    Assert-DemoRadiusCredential $config
}
foreach ($target in @('local', 'aks', 'aci')) {
    $info = Get-DemoTarget $target $config
    $receipt = Join-Path $script:StateRoot "$target.receipt.json"
    if ((Test-Path -LiteralPath $receipt) -and $PSCmdlet.ShouldProcess("$($info.Workspace)/$($info.Group)/example-voting-app", 'Delete the demo application and its resources')) {
        $applications = (Invoke-DemoRad @('app', 'list', '--workspace', $info.Workspace,
            '--group', $info.Group, '-o', 'json')) -join "`n"
        $null = ConvertFrom-Json -InputObject $applications
        if ($applications -match '"name"\s*:\s*"example-voting-app"') {
            Invoke-DemoRad @('app', 'delete', 'example-voting-app', '--workspace', $info.Workspace,
                '--group', $info.Group, '--yes')
        }
        Remove-Item -LiteralPath $receipt -Force
    }
}
$allCloudGroupsRemoved = $true
foreach ($target in @('aks', 'aci')) {
    $info = Get-DemoTarget $target $config
    $exists = ((Invoke-DemoAzureCommand $config @('group', 'exists',
        '--name', $info.ResourceGroup, '-o', 'tsv')) -join '').Trim()
    if ($exists -eq 'false') { continue }
    $group = Invoke-DemoAzureJson $config @('group', 'show', '--name', $info.ResourceGroup, '-o', 'json')
    if (-not $group.ContainsKey('tags') -or $null -eq $group.tags -or $group.tags['radiusDemoOwner'] -ne $ownerId) {
        throw "Ownership mismatch on $($info.ResourceGroup). Nothing else will be deleted."
    }
    if ($PSCmdlet.ShouldProcess($info.ResourceGroup, 'Delete this owned Azure demo resource group, including any remaining billed resources')) {
        Invoke-DemoAzureCommand $config @('group', 'delete', '--name', $info.ResourceGroup, '--yes')
    }
    else { $allCloudGroupsRemoved = $false }
}
$identityPath = Join-Path $script:StateRoot 'identity.json'
if ((Test-Path -LiteralPath $identityPath) -and ($allCloudGroupsRemoved -or $WhatIfPreference)) {
    $identity = $savedIdentity
    if ($identity.roleName -ne "Radius-Demo-ACI-$ownerId") { throw 'Identity ownership record does not match this demo.' }
    if ($PSCmdlet.ShouldProcess($identity.clientId, 'Unregister the owned Radius Azure credential and delete the demo service principal and its custom ACI reader role')) {
        Remove-DemoRadiusCredential $config
        if (-not $identity.objectId) {
            $identity['objectId'] = ((Invoke-DemoAzureCommand $config @('ad', 'sp', 'show', '--id', $identity.clientId, '--query', 'id', '-o', 'tsv')) -join '').Trim()
        }
        $assignments = @(Invoke-DemoAzureJson $config @('role', 'assignment', 'list',
            '--assignee', $identity.objectId, '--all', '--query', "[?roleDefinitionName=='$($identity.roleName)']", '-o', 'json'))
        foreach ($assignment in $assignments) {
            Invoke-DemoAzureCommand $config @('role', 'assignment', 'delete', '--ids', $assignment.id)
        }
        $roles = @(Invoke-DemoAzureJson $config @('role', 'definition', 'list', '--name', $identity.roleName, '-o', 'json'))
        if ($roles.Count -gt 0) {
            Invoke-DemoAzureCommand $config @('role', 'definition', 'delete', '--name', $identity.roleName)
        }
        Invoke-DemoAzureCommand $config @('ad', 'sp', 'delete', '--id', $identity.clientId)
        Remove-Item -LiteralPath $identityPath -Force
        $credentialPath = Join-Path $script:StateRoot 'azure-credential.xml'
        if (Test-Path -LiteralPath $credentialPath) { Remove-Item -LiteralPath $credentialPath -Force }
    }
}
elseif (-not $allCloudGroupsRemoved) {
    Write-Warning 'An Azure demo group was retained. Its deployment identity was retained too, so it can still be managed.'
}
Write-Host 'Cleanup pass finished. Clusters, Radius installations, namespaces, recipe packages, and encrypted PostgreSQL password backups were not deleted.'
Write-Host 'Review Azure resource groups to confirm no demo resources remain.'
