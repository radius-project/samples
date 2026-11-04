#requires -Version 7.2
. "$PSScriptRoot\Demo.Common.ps1"
$config = Get-DemoConfig
$baseline = Get-DemoBaseline
Assert-DemoAzureScope $config
$null = Assert-DemoIdentityScope $config
Assert-DemoRadiusCredential $config
$images = (Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable).images
Write-Host 'STEP 5 | Verify the claim, then compare the targets'
$rows = @()

foreach ($target in @('local', 'aks', 'aci')) {
    $info = Get-DemoTarget $target $config
    $receiptPath = Join-Path $script:StateRoot "$target.receipt.json"
    if (-not (Test-Path -LiteralPath $receiptPath)) { throw "Missing $target deployment receipt." }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json -AsHashtable
    if ($receipt.status -ne 'deployed') { throw "The last $target deployment did not finish successfully." }
    Assert-DemoFingerprints $receipt.hashes
    if ($null -eq $receipt.voteProof) { throw "Run Test-VoteFlow.ps1 -Target $target before the final comparison." }
    if ($target -ne 'aci') {
        $pods = Invoke-DemoJson 'kubectl' @('--context', $info.Context, '-n', $info.Namespace, 'get', 'pods', '-o', 'json')
        foreach ($name in $images.Keys) {
            $found = @()
            foreach ($pod in $pods.items) {
                if ($pod.metadata.ContainsKey('deletionTimestamp')) { continue }
                $specs = @($pod.spec.containers | Where-Object { $_.name -eq $name })
                foreach ($spec in $specs) {
                    $status = @($pod.status.containerStatuses | Where-Object { $_.name -eq $name })
                    $digest = ($images[$name] -split '@')[1]
                    if ($spec.image -ne $images[$name] -or $status.Count -ne 1 -or -not $status[0].ready -or
                        -not $status[0].imageID.EndsWith($digest, [StringComparison]::OrdinalIgnoreCase)) {
                        throw "$target/$name is not ready with the locked runtime imageID. Inspect the pod; do not substitute the spec for runtime evidence."
                    }
                    $found += $name
                }
            }
            if ($found.Count -eq 0) { throw "No running $name container found on $target." }
        }
    }
    $rows += [pscustomobject]@{
        Target = $target
        'Application SHA256' = $receipt.hashes['app.bicep'].Substring(0, 16)
        'Image-lock SHA256' = $receipt.hashes['images.lock.json'].Substring(0, 16)
        'Vote flow verified (UTC)' = $receipt.voteProof.verifiedAt
    }
}

$aci = Get-DemoTarget aci $config
# `az container list` leaves every container's instance view empty, so read each group with `az container show`.
# Keep only evidence fields: deployed environment values are never read or displayed.
$groupQuery = '{name:name,sku:sku,provisioningState:provisioningState,containers:containers[].{name:name,image:image,state:instanceView.currentState.state},confidentialComputeProperties:confidentialComputeProperties}'
$groupNames = @(Invoke-DemoAzureCommand $config @('container', 'list',
    '--resource-group', $aci.ResourceGroup, '--query', '[].name', '-o', 'tsv') | Where-Object { $_.Trim() })
$groups = @(foreach ($groupName in $groupNames) {
    Invoke-DemoAzureJson $config @('container', 'show', '--resource-group', $aci.ResourceGroup,
        '--name', $groupName.Trim(), '--query', $groupQuery, '-o', 'json')
})
$expectedPolicy = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'platform\generated\vote-ccepolicy.b64') -Raw
$expectedHash = Get-DemoPolicyHash $expectedPolicy
if ($expectedHash -ne $baseline.policyHash) { throw 'The local policy no longer matches the prepared recipe.' }
foreach ($role in @('vote', 'result')) {
    $expectedNames = @(if ($role -eq 'vote') { 'redis'; 'vote'; 'worker' } else { 'result' })
    $matching = @($groups | Where-Object { $role -in $_.containers.name })
    if ($matching.Count -ne 1) { throw "Expected exactly one ACI group containing $role; found $($matching.Count)." }
    $group = $matching[0]
    $expectedSku = if ($role -eq 'vote') { 'Confidential' } else { 'Standard' }
    if ($group.sku -ne $expectedSku -or $group.provisioningState -ne 'Succeeded') {
        throw "$role does not have the expected $expectedSku SKU and successful provisioning state."
    }
    if (@($group.containers).Count -ne $expectedNames.Count) { throw "Unexpected container membership in ACI $role group." }
    foreach ($name in $expectedNames) {
        $container = @($group.containers | Where-Object { $_.name -eq $name })
        if ($container.Count -ne 1 -or $container[0].image -ne $images[$name] -or $container[0].state -ne 'Running') {
            throw "ACI $name is not Running with the locked immutable image reference."
        }
    }
    if ($role -eq 'vote') {
        $runningHash = Get-DemoPolicyHash $group.confidentialComputeProperties.ccePolicy
        $profile = Invoke-DemoAzureJson $config @('resource', 'show',
            '--resource-group', $aci.ResourceGroup, '--name', 'vote-profile',
            '--resource-type', 'Microsoft.ContainerInstance/containerGroupProfiles', '--api-version', '2024-11-01-preview', '-o', 'json')
        $profileHash = Get-DemoPolicyHash $profile.properties.confidentialComputeProperties.ccePolicy
        if ($profile.properties.sku -ne 'Confidential' -or $runningHash -ne $expectedHash -or $profileHash -ne $expectedHash) {
            throw 'The running group, profile, and generated policy do not match. Updating an NGroup profile alone may leave old instances running.'
        }
        Write-Host "Confidential group: $($group.name)"
        Write-Host "Policy SHA256: $expectedHash"
        Write-Host 'Generated file = Azure profile = running group'
    }
    Write-Host "$role | $expectedSku | $($expectedNames -join ', ') | Running"
}

foreach ($target in @('aks', 'aci')) {
    $info = Get-DemoTarget $target $config
    $servers = @(Invoke-DemoAzureJson $config @('postgres', 'flexible-server', 'list',
        '--resource-group', $info.ResourceGroup, '-o', 'json'))
    if ($servers.Count -ne 1 -or $servers[0].state -ne 'Ready') { throw "Expected one Ready PostgreSQL server for $target." }
    $tls = ((Invoke-DemoAzureCommand $config @('postgres', 'flexible-server', 'parameter', 'show',
        '--resource-group', $info.ResourceGroup,
        '--server-name', $servers[0].name, '--name', 'require_secure_transport', '--query', 'value', '-o', 'tsv')) -join '').Trim()
    if ($tls -ne 'ON') { throw "PostgreSQL secure transport is not required on $target." }
    Write-Host "$target PostgreSQL: $($servers[0].name) | Ready | TLS required"
}
$rows | Format-Table -AutoSize
Write-Host 'Full hashes are in the deployment receipts; this table abbreviates them.'
Write-Host 'Kubernetes: runtime imageIDs checked. ACI: immutable image references, Running state, and policy configuration checked.'
Write-Host 'This is configuration and behavior evidence, NOT independent remote attestation or a production-security certification.'
