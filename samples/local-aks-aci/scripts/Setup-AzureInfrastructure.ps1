#requires -Version 7.2
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][string]$ApiServerAllowedCidr,
    [string]$AdminObjectId = '',
    [ValidateSet('User', 'Group', 'ServicePrincipal', IgnoreCase = $false)][string]$AdminPrincipalType = 'User',
    [ValidateSet('Standard_D4s_v5', 'Standard_D4as_v5', 'Standard_D4s_v6', IgnoreCase = $false)][string]$NodeVmSize = 'Standard_D4s_v5',
    [string]$KubernetesVersion = '',
    [switch]$UseDeploymentStack,
    [switch]$Deploy
)
. "$PSScriptRoot\Demo.Common.ps1"

function Assert-BootstrapCidr {
    param([string]$Cidr)
    if ($Cidr -notmatch '^((?:[0-9]{1,3}\.){3}[0-9]{1,3})/(2[4-9]|3[0-2])$') {
        throw 'Use your public IPv4 egress CIDR (/24 through /32), normally YOUR_PUBLIC_IPV4/32.'
    }
    $parts = $Matches[1].Split('.')
    $prefixLength = [int]$Matches[2]
    foreach ($part in $parts) {
        if ($part -notmatch '^(0|[1-9][0-9]{0,2})$' -or [int]$part -gt 255) { throw 'Invalid IPv4 CIDR octet.' }
    }
    $a, $b, $c, $d = @($parts | ForEach-Object { [int]$_ })
    $notPublic = $a -in @(0, 10, 127) -or $a -ge 224 -or
        ($a -eq 100 -and $b -ge 64 -and $b -le 127) -or ($a -eq 169 -and $b -eq 254) -or
        ($a -eq 172 -and $b -ge 16 -and $b -le 31) -or ($a -eq 192 -and $b -eq 168) -or
        ($a -eq 192 -and $b -eq 0 -and $c -in @(0, 2)) -or
        ($a -eq 192 -and $b -eq 88 -and $c -eq 99) -or
        ($a -eq 198 -and $b -in @(18, 19)) -or ($a -eq 198 -and $b -eq 51 -and $c -eq 100) -or
        ($a -eq 203 -and $b -eq 0 -and $c -eq 113)
    if ($notPublic) { throw 'The API CIDR must be public egress, not a private, reserved, or documentation address.' }
    $address = ([long]$a -shl 24) + ($b -shl 16) + ($c -shl 8) + $d
    if (($address -band ((1L -shl (32 - $prefixLength)) - 1)) -ne 0) {
        throw 'Use the network address for a CIDR range, or /32 for one public IP.'
    }
}

function Assert-BootstrapTags {
    param([hashtable]$Resource)
    if (-not $Resource.ContainsKey('tags') -or $Resource.tags -isnot [System.Collections.IDictionary] -or
        $Resource.tags['radiusDemoOwner'] -cne $ownerId -or
        $Resource.tags['radiusDemoTenant'] -ine $config.TenantId -or
        $Resource.tags['radiusDemoPurpose'] -cne 'aks-bootstrap') {
        throw "Refusing to adopt $($Resource.name). Its bootstrap ownership/tenant tags do not match this checkout."
    }
}

function Get-OwnedBootstrapCluster {
    $cluster = $null
    $groupExists = (Invoke-DemoAzureCommand $config @('group', 'exists', '--name', $groupName, '--output', 'tsv')).Trim()
    if ($groupExists -ceq 'true') {
        $group = Invoke-DemoAzureJson $config @('group', 'show', '--name', $groupName, '--output', 'json')
        Assert-BootstrapTags $group
        if ($group.location -ine $config.Location) { throw 'The owned platform group has a different location.' }
        $clusters = @(Invoke-DemoAzureJson $config @('aks', 'list', '--resource-group', $groupName, '--output', 'json'))
        if ($clusters.Count -gt 1 -or ($clusters.Count -eq 1 -and $clusters[0].name -ine $clusterName)) {
            throw 'The dedicated platform group contains an unexpected cluster. No resources will be adopted.'
        }
        if ($clusters.Count -eq 1) {
            $cluster = $clusters[0]
            Assert-BootstrapTags $cluster
            if ($cluster.nodeResourceGroup -ine $nodeGroupName -or $cluster.aadProfile.tenantId -ine $config.TenantId) {
                throw 'The existing cluster has a different node group or Entra tenant.'
            }
            $pools = @($cluster.agentPoolProfiles)
            if ($pools.Count -ne 1 -or $pools[0].name -cne 'system' -or $pools[0].vmSize -ine $NodeVmSize) {
                throw 'This bootstrap does not migrate existing node pools. Reuse the original VM size and dedicated cluster.'
            }
            if ($KubernetesVersion -and $KubernetesVersion -cne $cluster.kubernetesVersion) {
                throw 'Manage Kubernetes version upgrades separately; this bootstrap will not upgrade an existing cluster.'
            }
        }
    }
    elseif ($groupExists -cne 'false') { throw 'Azure returned an invalid resource-group existence result.' }
    $nodeGroupExists = (Invoke-DemoAzureCommand $config @('group', 'exists', '--name', $nodeGroupName, '--output', 'tsv')).Trim()
    if ($nodeGroupExists -ceq 'true' -and $null -eq $cluster) {
        throw 'The intended AKS node resource group already exists without this owned cluster. It will not be adopted.'
    }
    if ($nodeGroupExists -cnotin @('true', 'false')) { throw 'Azure returned an invalid node-group existence result.' }
    return $cluster
}

function Assert-BootstrapStack {
    # Stack SDK versions expose either wire-format properties or flattened fields.
    $stacks = @(Invoke-DemoAzureJson $config @('stack', 'sub', 'list',
        '--query', '[].{id:id,name:name,location:location,tags:tags,properties:{denySettings:properties.denySettings,actionOnUnmanage:properties.actionOnUnmanage,resources:properties.resources},denySettings:denySettings,actionOnUnmanage:actionOnUnmanage,resources:resources}',
        '--output', 'json') | Where-Object { $_.name -ieq $groupName })
    if ($stacks.Count -eq 0) { return }
    if ($stacks.Count -ne 1) { throw 'The target deployment stack is ambiguous.' }
    $stack = $stacks[0]
    Assert-BootstrapTags $stack
    if ($stack.id -ine $stackId -or $stack.location -ine $config.Location) {
        throw 'The deployment stack scope/location differs from this bootstrap.'
    }
    $details = if ($stack.ContainsKey('properties') -and $stack.properties -is [System.Collections.IDictionary] -and
        $stack.properties['denySettings'] -is [System.Collections.IDictionary]) { $stack.properties } else { $stack }
    if ($details.denySettings.mode -ine 'none' -or
        $details.actionOnUnmanage.resources -ine 'detach' -or
        $details.actionOnUnmanage.resourceGroups -ine 'detach' -or
        $details.actionOnUnmanage.managementGroups -ine 'detach') {
        throw 'The existing stack has different deny/unmanage policies. They will not be overwritten.'
    }
    $managedGroupId = "/subscriptions/$($config.SubscriptionId)/resourceGroups/$groupName"
    foreach ($resource in $details.resources) {
        if ($resource.id -ine $managedGroupId -and
            -not $resource.id.StartsWith("$managedGroupId/", [StringComparison]::OrdinalIgnoreCase)) {
            throw 'The stack manages resources outside the dedicated platform group. Review it before changing management.'
        }
    }
}

if (-not $IsWindows) { throw 'Use Setup-AzureInfrastructure.sh on Linux/WSL/macOS.' }
Assert-BootstrapCidr $ApiServerAllowedCidr
if ($KubernetesVersion -and $KubernetesVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw 'KubernetesVersion must be a full supported version such as 1.x.y, or omitted.'
}
if (-not $AdminObjectId -and $AdminPrincipalType -ne 'User') {
    throw 'Supply AdminObjectId when granting access to a Group or ServicePrincipal.'
}
if ($AdminObjectId -and $AdminObjectId -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$') {
    throw 'AdminObjectId must be an object GUID in the configured resource tenant, not an application/client ID.'
}
$config = Get-DemoConfig
if ($WhatIfPreference) {
    $null = $PSCmdlet.ShouldProcess("$($config.TenantId)/$($config.SubscriptionId)/$($config.Prefix)-platform",
        "Preview a two-node $NodeVmSize AKS host with API CIDR $ApiServerAllowedCidr; stacks mode stores a three-hour Azure result. Omit -WhatIf for the real preview; creation still requires -Deploy")
    return
}
foreach ($tool in @('az', 'bicep')) {
    if (-not (Resolve-DemoCommand $tool)) { throw "Install $tool and make it available on PATH; run Check-Prerequisites.ps1 for guidance." }
}
Invoke-DemoCommand 'bicep' @('--version')
if ($UseDeploymentStack) {
    $previousDynamicInstall = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
    try {
        $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
        $null = Invoke-DemoCommand 'az' @('stack-whatif', 'sub', 'create', '--help')
    }
    finally { $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $previousDynamicInstall }
}
Assert-DemoAzureScope $config
Assert-DemoSavedConfig $config
$null = Assert-DemoIdentityScope $config -AllowMissing
Initialize-DemoState
$ownerId = (Get-Content -LiteralPath (Join-Path $script:StateRoot 'owner-id.txt') -Raw).Trim()
$ownerGuid = [guid]::Empty
if (-not [guid]::TryParse($ownerId, [ref]$ownerGuid)) { throw 'The saved ownership marker is not a GUID. Preserve it for recovery.' }
$groupName = "$($config.Prefix)-platform"
$clusterName = "$($config.Prefix)-aks"
$nodeGroupName = "$($config.Prefix)-aks-nodes"
$receiptPath = Join-Path $script:StateRoot 'azure-infrastructure.json'
$deploymentMode = if ($UseDeploymentStack) { 'stack' } else { 'deployment' }
$stackId = "/subscriptions/$($config.SubscriptionId)/providers/Microsoft.Resources/deploymentStacks/$groupName"

if (-not $AdminObjectId) {
    $account = Invoke-DemoAzureJson $config @('account', 'show', '--output', 'json')
    if ($account.user.type -ine 'user') { throw 'For a non-user Azure login, supply AdminObjectId and AdminPrincipalType explicitly.' }
    $principal = Invoke-DemoAzureJson $config @('ad', 'signed-in-user', 'show', '--query', '{id:id}', '--output', 'json')
}
else {
    $kind = switch ($AdminPrincipalType) { 'User' { 'user' } 'Group' { 'group' } 'ServicePrincipal' { 'sp' } }
    $principal = Invoke-DemoAzureJson $config @('ad', $kind, 'show', '--id', $AdminObjectId, '--query', '{id:id}', '--output', 'json')
}
if ($principal.id -notmatch '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' -or
    ($AdminObjectId -and $principal.id -ine $AdminObjectId)) { throw 'The administrator object could not be verified in the resource tenant.' }
$AdminObjectId = $principal.id

if (Test-Path -LiteralPath $receiptPath) {
    $saved = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
    $savedMode = if ($saved.ContainsKey('deploymentMode')) { $saved.deploymentMode } else { 'deployment' }
    if ($savedMode -notin @('deployment', 'stack')) { throw 'Saved infrastructure has an unknown deployment mode.' }
    if ($savedMode -eq 'stack' -and (-not $UseDeploymentStack -or $saved['stackId'] -ine $stackId)) {
        throw 'Saved infrastructure is stack-managed. Reuse -UseDeploymentStack and the original scope; do not switch deployment engines implicitly.'
    }
    if ($saved.tenantId -ine $config.TenantId -or $saved.subscriptionId -ine $config.SubscriptionId -or
        $saved.ownerId -cne $ownerId -or $saved.resourceGroupName -cne $groupName -or
        $saved.adminObjectId -ine $AdminObjectId -or $saved.adminPrincipalType -cne $AdminPrincipalType) {
        throw 'Saved infrastructure scope/administrator differs. Preserve the original state; changing administrators needs a reviewed RBAC migration.'
    }
    if ($UseDeploymentStack) { Assert-BootstrapStack }
}
$cluster = Get-OwnedBootstrapCluster
$effectiveVersion = if ($cluster) { $cluster.kubernetesVersion } else { $KubernetesVersion }
$nodeAvailabilityZones = @()
if ($cluster) {
    $existingZones = $cluster.agentPoolProfiles[0]['availabilityZones']
    if ($null -ne $existingZones -and $existingZones -isnot [array]) {
        throw 'Existing node-pool availabilityZones must be an array. No zone migration will be attempted.'
    }
    foreach ($zone in $existingZones) {
        $zoneNumber = 0
        if ([string]$zone -notmatch '^[1-9][0-9]*$' -or -not [int]::TryParse([string]$zone, [ref]$zoneNumber)) {
            throw 'Existing node-pool zones must be positive numeric IDs. Automatic placement or zone migration needs separate management.'
        }
        $nodeAvailabilityZones += $zoneNumber
    }
}

$missingProviders = @()
foreach ($provider in @('Microsoft.ContainerService', 'Microsoft.Compute', 'Microsoft.Network', 'Microsoft.ManagedIdentity',
    'Microsoft.ContainerInstance', 'Microsoft.DBforPostgreSQL')) {
    $state = (Invoke-DemoAzureCommand $config @('provider', 'show', '--namespace', $provider, '--query', 'registrationState', '--output', 'tsv')).Trim()
    if ($state -cne 'Registered') {
        $missingProviders += $provider
        Write-Host "Register ($state): az provider register --namespace $provider --subscription $($config.SubscriptionId) --wait"
    }
}
if ($missingProviders.Count) {
    throw 'Register the listed providers with an authorized account, then rerun. Preview/deploy never registers providers automatically.'
}

$parameters = @{
    prefix = @{ value = $config.Prefix }; location = @{ value = $config.Location }
    tenantId = @{ value = $config.TenantId }; ownerId = @{ value = $ownerId }
    adminObjectId = @{ value = $AdminObjectId }; adminPrincipalType = @{ value = $AdminPrincipalType }
    apiServerAllowedCidr = @{ value = $ApiServerAllowedCidr }; nodeVmSize = @{ value = $NodeVmSize }
    nodeAvailabilityZones = @{ value = $nodeAvailabilityZones }
    kubernetesVersion = @{ value = $effectiveVersion }
}
$parameterPath = Join-Path $script:StateRoot 'azure-infrastructure.parameters.json'
$templatePath = Join-Path $script:StateRoot 'azure-infrastructure.template.json'
try {
    Write-DemoJson $parameterPath @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'; parameters = $parameters
    }
    # Passing compiled JSON prevents Azure CLI from silently installing its own Bicep executable.
    Invoke-DemoCommand 'bicep' @('build', (Join-Path $script:DemoRoot 'infra\main.bicep'), '--outfile', $templatePath)
    Write-Host "Tenant $($config.TenantId) | Subscription $($config.SubscriptionId) | $($config.Location)"
    Write-Host "$groupName / $clusterName | 2 x $NodeVmSize | API $ApiServerAllowedCidr"
    $placement = if ($nodeAvailabilityZones.Count) { 'zones ' + ($nodeAvailabilityZones -join ', ') } else { 'regional (non-zonal)' }
    Write-Host "Node placement: $placement"
    Write-Host "Cluster administrator: $AdminPrincipalType $AdminObjectId (resource tenant)."
    Write-Host 'AKS Free refers to the control plane only. Nodes, disks, load balancer and outbound traffic are billed.'
    $templateArguments = @('--location', $config.Location,
        '--template-file', $templatePath, '--parameters', "@$parameterPath")
    $deploymentArguments = @('--name', $groupName) + $templateArguments
    $previewId = $null
    if ($UseDeploymentStack) {
        $stackArguments = $templateArguments + @('--action-on-unmanage', 'detachAll',
            '--deny-settings-mode', 'none', '--validation-level', 'Provider', '--tags',
            "radiusDemoOwner=$ownerId", "radiusDemoTenant=$($config.TenantId)", 'radiusDemoPurpose=aks-bootstrap')
        $previewName = "$groupName-preview-$([guid]::NewGuid().ToString('N').Substring(0, 12))"
        $previewId = "/subscriptions/$($config.SubscriptionId)/providers/Microsoft.Resources/deploymentStacksWhatIfResults/$previewName"
        Write-Host 'Stacks mode: creating a stored Azure preview result (expires after three hours); infrastructure is not deployed.'
        Invoke-DemoAzureCommand $config (@('stack-whatif', 'sub', 'create', '--name', $previewName,
            '--stack-id', $stackId, '--retention-interval', 'PT3H') + $stackArguments)
        Write-DemoJson (Join-Path $script:StateRoot 'azure-infrastructure-preview.json') @{
            schemaVersion = 1; tenantId = $config.TenantId; subscriptionId = $config.SubscriptionId; ownerId = $ownerId
            stackId = $stackId; previewId = $previewId; retentionInterval = 'PT3H'; createdAt = [DateTime]::UtcNow.ToString('o')
        }
        Write-Host "Stored preview: $previewId"
    }
    else { Invoke-DemoAzureCommand $config (@('deployment', 'sub', 'what-if') + $deploymentArguments) }
    if (-not $Deploy) {
        if ($UseDeploymentStack) {
            Write-Host 'Preview only. Only preview metadata was created; no stack or AKS resources were deployed. Retain all options and add -Deploy to apply.'
        }
        else { Write-Host 'Preview only. No Azure resources were created. Rerun with the same options and -Deploy to request creation.' }
        return
    }
    if (-not $PSCmdlet.ShouldProcess("$($config.TenantId)/$($config.SubscriptionId)/$groupName",
        "Deploy/update the dedicated two-node AKS host and administrator roles using $deploymentMode management")) { return }
    Assert-DemoAzureScope $config
    $null = Get-OwnedBootstrapCluster
    if ($UseDeploymentStack) { Assert-BootstrapStack }
    Write-DemoJson (Join-Path $script:StateRoot 'setup-config.json') $config
    $receipt = @{
        schemaVersion = 1; status = 'deploying'; tenantId = $config.TenantId; subscriptionId = $config.SubscriptionId
        ownerId = $ownerId; resourceGroupName = $groupName; clusterName = $clusterName; nodeResourceGroupName = $nodeGroupName
        adminObjectId = $AdminObjectId; adminPrincipalType = $AdminPrincipalType
        nodeAvailabilityZones = $nodeAvailabilityZones
        nodeVmSize = $NodeVmSize; apiServerAllowedCidr = $ApiServerAllowedCidr; updatedAt = [DateTime]::UtcNow.ToString('o')
        deploymentMode = $deploymentMode; stackId = $(if ($UseDeploymentStack) { $stackId } else { $null })
        previewId = $previewId
    }
    Write-DemoJson $receiptPath $receipt
    if ($UseDeploymentStack) {
        $deployedStack = Invoke-DemoAzureJson $config (@('stack', 'sub', 'create', '--name', $groupName) +
            $stackArguments + @('--yes', '--query',
                '{id:id,properties:{provisioningState:properties.provisioningState,outputs:properties.outputs},provisioningState:provisioningState,outputs:outputs}',
                '--output', 'json'))
        $stackDetails = if ($deployedStack.ContainsKey('properties') -and $deployedStack.properties -is [System.Collections.IDictionary] -and
            $null -ne $deployedStack.properties['provisioningState']) { $deployedStack.properties } else { $deployedStack }
        if ($deployedStack.id -ine $stackId -or $stackDetails.provisioningState -ine 'succeeded') {
            throw 'The deployment stack did not report success in the expected scope. Preserve the receipt for recovery.'
        }
        $outputs = $stackDetails.outputs
    }
    else {
        $outputs = Invoke-DemoAzureJson $config (@('deployment', 'sub', 'create') + $deploymentArguments +
            @('--query', 'properties.outputs', '--output', 'json'))
    }
    if ($outputs.clusterName.value -cne $clusterName -or $outputs.resourceGroupName.value -cne $groupName -or
        [string]::IsNullOrWhiteSpace($outputs.clusterId.value)) { throw 'Deployment returned unexpected outputs; inspect the deployment and saved receipt.' }
    $receipt.status = 'deployed'
    $receipt['outputs'] = $outputs
    $receipt.updatedAt = [DateTime]::UtcNow.ToString('o')
    Write-DemoJson $receiptPath $receipt
    $contextLiteral = "'" + $config.AksContext.Replace("'", "''") + "'"
    $azureConfigDir = if ($env:AZURE_CONFIG_DIR) { $env:AZURE_CONFIG_DIR } else { Join-Path $HOME '.azure' }
    $azureConfigLiteral = "'" + $azureConfigDir.Replace("'", "''") + "'"
    Write-Host "`nAzure host deployed. Kubeconfig and Radius were not changed. Keep this Azure tenant/profile active."
    Write-Host "az aks get-credentials --subscription $($config.SubscriptionId) --resource-group $groupName --name $clusterName --context $contextLiteral"
    Write-Host "kubelogin convert-kubeconfig --login azurecli --context $contextLiteral --azure-config-dir $azureConfigLiteral"
    Write-Host "kubectl --context $contextLiteral get nodes"
    Write-Host "# Using Radius CLI $(Get-DemoRequiredRadiusVersion), only if Radius is not installed on this dedicated cluster:"
    Write-Host "rad install kubernetes --kubecontext $contextLiteral"
    Write-Host '.\scripts\Check-Prerequisites.ps1 -CheckClusters'
    Write-Host 'Then run 00-prepare.ps1. Existing 99-cleanup does not delete this AKS host; see the separate README cleanup.'
}
finally {
    if (Test-Path -LiteralPath $parameterPath) { Remove-Item -LiteralPath $parameterPath }
}
