#requires -Version 7.2
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([string]$PolicyBundle)
. "$PSScriptRoot\Demo.Common.ps1"

$preparationHashes = Get-DemoFingerprints
$config = Get-DemoConfig
foreach ($tool in @('rad', 'az', 'docker', 'kubectl')) {
    if (-not (Resolve-DemoCommand $tool)) { throw "Cannot find $tool before preparation. See the prerequisite checker; this script installs no tools or clusters." }
}
$requiredRadius = Get-DemoRequiredRadiusVersion
$version = Invoke-DemoJson 'rad' @('version', '--cli', '--output', 'json')
if ($version.release.TrimStart('v') -cne $requiredRadius) { throw "Use Radius CLI $requiredRadius from radius-version.txt." }
Assert-DemoAzureScope $config
Assert-DemoSavedConfig $config
$null = Assert-DemoIdentityScope $config -AllowMissing

foreach ($context in @($config.LocalContext, $config.AksContext)) {
    $nodes = Invoke-DemoJson 'kubectl' @('--context', $context, 'get', 'nodes', '-o', 'json')
    if ($nodes.items.Count -eq 0) { throw "No nodes in $context." }
    foreach ($node in $nodes.items) {
        if ($node.status.nodeInfo.architecture -ne 'amd64' -or $node.status.nodeInfo.operatingSystem -ne 'linux') {
            throw "$context must use Linux/AMD64 nodes to keep the exact same image digests."
        }
    }
    $rp = Invoke-DemoJson 'kubectl' @('--context', $context, '-n', 'radius-system', 'get', 'deployment', 'dynamic-rp', '-o', 'json')
    $expectedImage = ':' + [regex]::Escape($requiredRadius) + '(?:@|\s|$)'
    if ($rp.status.readyReplicas -lt 1 -or ($rp.spec.template.spec.containers.image -join ' ') -notmatch $expectedImage) {
        throw "Install Radius $requiredRadius on $context before preparation. This script will not replace an existing control plane."
    }
}

Assert-DemoPublicImages
Assert-DemoPublicKubernetesRecipes
# Check the policy source before asking for confirmation.
if ($PolicyBundle) {
    if (-not (Test-Path -LiteralPath $PolicyBundle -PathType Leaf)) { throw "Cannot find the policy bundle $PolicyBundle." }
}
else { Assert-DemoPolicyGenerator }
if (-not $PSCmdlet.ShouldProcess(
    "tenant $($config.TenantId), subscription $($config.SubscriptionId), the two configured clusters, and $($config.RecipeRepository)",
    'Prepare demo namespaces/environments, two Azure resource groups, a demo service principal and scoped roles, and publish two platform recipes'
)) { return }

Assert-DemoFingerprints $preparationHashes -Context 'the start of this preparation'
Initialize-DemoState
$ownerId = (Get-Content -LiteralPath (Join-Path $script:StateRoot 'owner-id.txt') -Raw).Trim()
$setupConfigPath = Join-Path $script:StateRoot 'setup-config.json'
Write-DemoJson $setupConfigPath $config

$bundle = if ($PolicyBundle) {
    Save-DemoPolicyBundle -Location $config.Location -Bundle (Get-Content -LiteralPath $PolicyBundle -Raw | ConvertFrom-Json -AsHashtable)
} else {
    New-DemoPolicyBundle -Location $config.Location
}
$policyHash = $bundle.policyHash

$recipeFile = Join-Path $script:DemoRoot 'platform\aci-containers.bicep'
$wrapperHash = (Get-FileHash -LiteralPath $recipeFile -Algorithm SHA256).Hash
$tag = "policy-$($policyHash.Substring(0, 12).ToLowerInvariant())-$($wrapperHash.Substring(0, 12).ToLowerInvariant())"
$recipeSource = Publish-DemoPlatformRecipe -File $recipeFile -Repository $config.RecipeRepository -Tag $tag `
    -RecordName 'recipe.json' -Record @{ policyHash = $policyHash }
$kubernetesRecipeFile = Join-Path $script:DemoRoot 'platform\kubernetes-containers.bicep'
$kubernetesTag = "kubernetes-$((Get-FileHash -LiteralPath $kubernetesRecipeFile -Algorithm SHA256).Hash.Substring(0, 12).ToLowerInvariant())"
$kubernetesRecipeSource = Publish-DemoPlatformRecipe -File $kubernetesRecipeFile -Repository $config.RecipeRepository `
    -Tag $kubernetesTag -RecordName 'kubernetes-recipe.json'

foreach ($target in @('local', 'aks', 'aci')) {
    $info = Get-DemoTarget $target $config
    if ($target -ne 'aci') {
        Invoke-DemoRad @('workspace', 'create', 'kubernetes', $info.Workspace, '--context', $info.Context, '--force')
    }
    $namespace = (Invoke-DemoCommand 'kubectl' @('--context', $info.Context, 'get', 'namespace',
        $info.Namespace, '--ignore-not-found', '-o', 'name')) -join ''
    if ([string]::IsNullOrWhiteSpace($namespace)) {
        Invoke-DemoCommand 'kubectl' @('--context', $info.Context, 'create', 'namespace', $info.Namespace)
    }
    # Group creation is idempotent, so this also restores the group after a local cluster is recreated.
    Invoke-DemoRad @('group', 'create', $info.Group, '--workspace', $info.Workspace)
    if ($target -ne 'local') {
        $exists = ((Invoke-DemoAzureCommand $config @('group', 'exists',
            '--name', $info.ResourceGroup, '-o', 'tsv')) -join '').Trim()
        if ($exists -eq 'true') {
            $group = Invoke-DemoAzureJson $config @('group', 'show', '--name', $info.ResourceGroup, '-o', 'json')
            if (-not $group.ContainsKey('tags') -or $null -eq $group.tags -or $group.tags['radiusDemoOwner'] -ne $ownerId -or $group.location -ne $config.Location) {
                throw "Refusing to adopt existing resource group $($info.ResourceGroup): ownership or location differs."
            }
        }
        else {
            $null = Invoke-DemoAzureCommand $config @('group', 'create',
                '--name', $info.ResourceGroup, '--location', $config.Location, '--tags', "radiusDemoOwner=$ownerId", '-o', 'none')
        }
    }
    $null = Get-DemoPassword $target
}

$credentialPath = Join-Path $script:StateRoot 'azure-credential.xml'
$identityPath = Join-Path $script:StateRoot 'identity.json'
$aks = Get-DemoTarget aks $config
$aci = Get-DemoTarget aci $config
Assert-DemoRadiusCredential $config -AllowMissing
$identity = Assert-DemoIdentityScope $config -AllowMissing
$roleName = "Radius-Demo-ACI-$ownerId"
if (-not (Test-Path -LiteralPath $credentialPath)) {
    if ($identity) { throw 'Saved identity exists without its credential backup. Preserve it and clean up/recover that identity instead of creating another.' }
    Write-Host 'Creating a demo-only service principal. Directory application-create and Azure RBAC permissions are required.'
    $sp = Invoke-DemoAzureJson $config @('ad', 'sp', 'create-for-rbac',
        '--name', "$($config.Prefix)-$($ownerId.Substring(0, 8))", '--role', 'Contributor', '--scopes',
        "/subscriptions/$($config.SubscriptionId)/resourceGroups/$($aks.ResourceGroup)",
        "/subscriptions/$($config.SubscriptionId)/resourceGroups/$($aci.ResourceGroup)", '-o', 'json')
    if ($sp.tenant -ine $config.TenantId) {
        throw 'Azure returned a service principal from an unexpected tenant. Stop and reconcile that creation; no credential will be registered.'
    }
    $identity = @{
        clientId = $sp.appId; objectId = $null; roleName = $roleName
        tenantId = $config.TenantId; subscriptionId = $config.SubscriptionId
    }
    Write-DemoJson $identityPath $identity
    $credential = [pscredential]::new($sp.appId, (ConvertTo-SecureString $sp.password -AsPlainText -Force))
    $credential | Export-Clixml -LiteralPath $credentialPath
    $sp = $null
}
$credential = Import-Clixml -LiteralPath $credentialPath
$clientId = $credential.UserName
if ($clientId -ine $identity.clientId -or $identity.roleName -ne $roleName) { throw 'Credential and identity ownership records do not match.' }
$objectId = ((Invoke-DemoAzureCommand $config @('ad', 'sp', 'show', '--id', $clientId, '--query', 'id', '-o', 'tsv')) -join '').Trim()
if ($identity.objectId -and $identity.objectId -ine $objectId) { throw 'The service principal object changed. Review the saved identity before reusing it.' }
$identity['objectId'] = $objectId
$identity['subscriptionId'] = $config.SubscriptionId
Write-DemoJson $identityPath $identity
$rolePath = Join-Path $script:StateRoot 'aci-operation-reader.json'
Write-DemoJson $rolePath @{
    Name = $roleName; IsCustom = $true
    Description = 'Read location-scoped ACI operation status for the Radius demo.'
    Actions = @('Microsoft.ContainerInstance/locations/*/read')
    NotActions = @()
    AssignableScopes = @("/subscriptions/$($config.SubscriptionId)")
}
$roles = @(Invoke-DemoAzureJson $config @('role', 'definition', 'list', '--name', $roleName, '-o', 'json'))
if ($roles.Count -eq 0) {
    $null = Invoke-DemoAzureCommand $config @('role', 'definition', 'create', '--role-definition', $rolePath, '-o', 'none')
    Write-Host 'Waiting 30 seconds for the new role definition to propagate.'
    Start-Sleep -Seconds 30
}
$assignments = @(Invoke-DemoAzureJson $config @('role', 'assignment', 'list',
    '--assignee', $objectId, '--all', '--query', "[?roleDefinitionName=='$roleName']", '-o', 'json'))
if ($assignments.Count -eq 0) {
    $null = Invoke-DemoAzureCommand $config @('role', 'assignment', 'create',
        '--assignee-object-id', $objectId, '--assignee-principal-type', 'ServicePrincipal',
        '--role', $roleName, '--scope', "/subscriptions/$($config.SubscriptionId)", '-o', 'none')
}
# Deleting a demo group also deletes its role assignments, so restore them when the group was recreated.
foreach ($group in @($aks.ResourceGroup, $aci.ResourceGroup)) {
    $scope = "/subscriptions/$($config.SubscriptionId)/resourceGroups/$group"
    $contributor = @(Invoke-DemoAzureJson $config @('role', 'assignment', 'list',
        '--assignee', $objectId, '--role', 'Contributor', '--scope', $scope, '-o', 'json'))
    if ($contributor.Count -eq 0) {
        $null = Invoke-DemoAzureCommand $config @('role', 'assignment', 'create',
            '--assignee-object-id', $objectId, '--assignee-principal-type', 'ServicePrincipal',
            '--role', 'Contributor', '--scope', $scope, '-o', 'none')
    }
}
Invoke-DemoRad @('workspace', 'switch', $aks.Workspace)
Assert-DemoRadiusCredential $config -AllowMissing
$null = Invoke-DemoRad @('credential', 'register', 'azure', 'sp', '--client-id', $clientId,
    '--tenant-id', $config.TenantId, '--client-secret', $credential.GetNetworkCredential().Password)
$credential = $null
Assert-DemoRadiusCredential $config

foreach ($target in @('local', 'aks', 'aci')) {
    $info = Get-DemoTarget $target $config
    if ($target -eq 'local') {
        Invoke-DemoRad @('deploy', (Join-Path $script:DemoRoot 'platform\local.bicep'),
            '--workspace', $info.Workspace, '--group', $info.Group, '--parameters', "namespace=$($info.Namespace)",
            '--parameters', "kubernetesContainersRecipe=$kubernetesRecipeSource")
    }
    else {
        Invoke-DemoRad @('deploy', (Join-Path $script:DemoRoot 'platform\cloud.bicep'),
            '--workspace', $info.Workspace, '--group', $info.Group,
            '--parameters', "target=$target", '--parameters', "namespace=$($info.Namespace)",
            '--parameters', "subscriptionId=$($config.SubscriptionId)",
            '--parameters', "azureResourceGroup=$($info.ResourceGroup)", '--parameters', "aciRecipeSource=$recipeSource",
            '--parameters', "kubernetesContainersRecipe=$kubernetesRecipeSource")
    }
}
Assert-DemoFingerprints $preparationHashes -Context 'the start of this preparation'
Write-DemoJson (Join-Path $script:StateRoot 'baseline.json') @{
    hashes = $preparationHashes
    policyHash = $policyHash
    recipeSource = $recipeSource
    kubernetesRecipeSource = $kubernetesRecipeSource
    preparedAt = [DateTimeOffset]::UtcNow.ToString('o')
}
Write-Host 'Preparation finished. No voting application has been deployed yet.'
Write-Host "Saved preparation baseline: $(Join-Path $script:StateRoot 'baseline.json')"
Write-Host 'Next, run scripts 01 through 05. New Azure role assignments may need more time to propagate.'
