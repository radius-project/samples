#requires -Version 7.2
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$script:DemoRoot = Split-Path $PSScriptRoot -Parent
$script:StateRoot = Join-Path $script:DemoRoot '.state'
$script:VerifiedAzureScope = ''

function Get-DemoRequiredRadiusVersion {
    $path = Join-Path $script:DemoRoot 'radius-version.txt'
    if (-not (Test-Path -LiteralPath $path)) { throw 'Restore the missing radius-version.txt release pin.' }
    $version = (Get-Content -LiteralPath $path -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'radius-version.txt must contain one stable release, such as 0.62.0.' }
    return $version
}

function Get-DemoKubernetesRecipeCommit {
    $path = Join-Path $script:DemoRoot 'kubernetes-recipes.lock.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Restore the missing kubernetes-recipes.lock.json.' }
    $pin = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    if ($pin -isnot [System.Collections.IDictionary] -or $pin['radiusVersion'] -cne (Get-DemoRequiredRadiusVersion) -or
        $pin['sourceCommit'] -isnot [string] -or $pin['sourceCommit'] -cnotmatch '^[a-f0-9]{40}$') {
        throw 'kubernetes-recipes.lock.json must bind the pinned Radius release to a full upstream source commit, not a CLI version or floating tag.'
    }
    return $pin.sourceCommit
}

function Get-DemoConfigPath {
    $jsonPath = Join-Path $script:DemoRoot 'config.json'
    $legacyPath = Join-Path $script:DemoRoot 'config.psd1'
    if ((Test-Path -LiteralPath $jsonPath) -and (Test-Path -LiteralPath $legacyPath)) {
        throw 'Both config.json and legacy config.psd1 exist. Keep only one active configuration.'
    }
    if (Test-Path -LiteralPath $jsonPath) { return $jsonPath }
    if (Test-Path -LiteralPath $legacyPath) { return $legacyPath }
    throw 'Copy config.example.json to config.json and fill in its seven settings, including TenantId.'
}

function Get-DemoConfig {
    $path = Get-DemoConfigPath
    $config = if ([IO.Path]::GetExtension($path) -eq '.json') {
        Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    } else {
        Import-PowerShellDataFile -LiteralPath $path
    }
    foreach ($key in @('TenantId', 'SubscriptionId', 'Location', 'LocalContext', 'AksContext', 'Prefix', 'RecipeRepository')) {
        if (-not $config.ContainsKey($key) -or $config[$key] -isnot [string] -or [string]::IsNullOrWhiteSpace($config[$key]) -or $config[$key] -match 'REPLACE_') {
            throw "Set $key in $([IO.Path]::GetFileName($path))."
        }
    }
    foreach ($key in @('TenantId', 'SubscriptionId')) {
        $id = [guid]::Empty
        if (-not [guid]::TryParse($config[$key], [ref]$id)) { throw "$key must be a GUID." }
    }
    if ($config.Prefix -notmatch '^[a-z][a-z0-9-]{1,19}$') { throw 'Prefix must be 2-20 lowercase letters, digits, or hyphens.' }
    if ($config.RecipeRepository -cnotmatch '^ghcr\.io/[a-z0-9-]+/[a-z0-9._/-]+$') {
        throw 'RecipeRepository must be a lowercase GHCR repository without a tag or br: prefix.'
    }
    if ($config.LocalContext -eq $config.AksContext) { throw 'LocalContext and AksContext must be different clusters.' }
    return $config
}

function Initialize-DemoState {
    if (-not $IsWindows) { throw 'Use the Bash track on Linux/WSL/macOS. This PowerShell track uses Windows DPAPI for credentials.' }
    $null = New-Item -ItemType Directory -Path $script:StateRoot -Force
    $stateDirectory = Get-Item -LiteralPath $script:StateRoot
    if ($stateDirectory.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw '.state must be a real directory inside this checkout, not a link.'
    }
    # Only update the DACL; copying audit/owner sections can require unrelated elevation on reruns.
    $acl = [IO.FileSystemAclExtensions]::GetAccessControl(
        $stateDirectory, [Security.AccessControl.AccessControlSections]::Access
    )
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    )
    $acl.SetAccessRule($rule)
    [IO.FileSystemAclExtensions]::SetAccessControl($stateDirectory, $acl)
    $ownerPath = Join-Path $script:StateRoot 'owner-id.txt'
    if (-not (Test-Path -LiteralPath $ownerPath)) {
        [IO.File]::WriteAllText($ownerPath, [guid]::NewGuid().ToString())
    }
}

function Write-DemoJson {
    param([string]$Path, [object]$Value)
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 40), [Text.UTF8Encoding]::new($false))
}

function Resolve-DemoCommand {
    param([string]$Name)
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        if ($command.CommandType -in @('Application', 'ExternalScript')) { return $command.Source }
        return $command.Name
    }
    if ($IsWindows -and $Name -ieq 'rad' -and $env:LOCALAPPDATA) {
        $installedRadius = Join-Path $env:LOCALAPPDATA 'radius\rad.exe'
        if (Test-Path -LiteralPath $installedRadius -PathType Leaf) { return $installedRadius }
    }
    return $null
}

function Invoke-DemoCommand {
    param([string]$File, [string[]]$Arguments)
    $command = Resolve-DemoCommand $File
    if (-not $command) { throw "Cannot find $File. Run the prerequisite checker for installation/PATH guidance." }
    & $command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$File failed with exit code $LASTEXITCODE. Fix the cause before you continue." }
}

function Invoke-DemoJson {
    param([string]$File, [string[]]$Arguments)
    $text = (Invoke-DemoCommand $File $Arguments) -join "`n"
    return ConvertFrom-Json -InputObject $text -AsHashtable
}

function Get-DemoContainerProvider {
    param([string]$HelpText)
    # Podman uses the executable name in --version, even for a docker hard link.
    if ($HelpText -match '(?i)\bpodman version information\b') { return 'Podman' }
    if ($HelpText -match '(?i)\bdocker version information\b') { return 'Docker' }
    throw 'Cannot identify the Docker-compatible CLI. Inspect: docker version --help'
}

function Get-DemoContainerMinimumVersion {
    param([ValidateSet('Docker', 'Podman')][string]$Provider)
    if ($Provider -eq 'Podman') { return '3.0.0' }
    return '20.10.5'
}

function Get-DemoContainerInfoFormat {
    param([ValidateSet('Docker', 'Podman')][string]$Provider)
    if ($Provider -eq 'Podman') { return 'json' }
    return '{{json .}}'
}

function ConvertTo-DemoContainerEngine {
    param([hashtable]$Info, [ValidateSet('Docker', 'Podman')][string]$Provider)
    if ($Provider -eq 'Podman') {
        if ($Info['host'] -isnot [System.Collections.IDictionary] -or $Info['version'] -isnot [System.Collections.IDictionary]) {
            throw 'Podman info did not return host and server-version metadata.'
        }
        $os = $Info.host['os']
        $architecture = $Info.host['arch']
        $version = $Info.version['Version']
    }
    else {
        $os = $Info['OSType']
        $architecture = $Info['Architecture']
        $version = $Info['ServerVersion']
    }
    foreach ($value in @($os, $architecture, $version)) {
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
            throw "$Provider info is missing valid server version, OS, or architecture metadata."
        }
    }
    if ($version -notmatch '^\d+\.\d+(?:\.\d+)?') { throw "$Provider returned an unrecognized server version." }
    $architecture = $architecture.ToLowerInvariant()
    if ($architecture -eq 'x86_64') { $architecture = 'amd64' }
    elseif ($architecture -eq 'aarch64') { $architecture = 'arm64' }
    return @{ Provider = $Provider; Version = $version; OS = $os.ToLowerInvariant(); Architecture = $architecture }
}

function Get-DemoContainerEngine {
    $helpText = (Invoke-DemoCommand 'docker' @('version', '--help')) -join "`n"
    $provider = Get-DemoContainerProvider $helpText
    $info = Invoke-DemoJson 'docker' @('info', '--format', (Get-DemoContainerInfoFormat $provider))
    return ConvertTo-DemoContainerEngine $info $provider
}

function Get-DemoAzureLoginHint {
    param([hashtable]$Config)
    return "az login --tenant $($Config.TenantId); az account set --subscription $($Config.SubscriptionId)"
}

function Test-DemoAzureAccountScope {
    param([hashtable]$Config, [hashtable]$Account)
    return $Account.ContainsKey('id') -and $Account.ContainsKey('tenantId') -and $Account.ContainsKey('state') -and
        $Account.id -ieq $Config.SubscriptionId -and $Account.tenantId -ieq $Config.TenantId -and $Account.state -ieq 'Enabled'
}

function Assert-DemoAzureScope {
    param([hashtable]$Config)
    $selected = Invoke-DemoJson 'az' @('account', 'show', '--subscription', $Config.SubscriptionId, '--output', 'json')
    if (-not (Test-DemoAzureAccountScope $Config $selected)) {
        throw "SubscriptionId must be enabled and belong to TenantId. Select the resource tenant, not your guest account's home tenant. $(Get-DemoAzureLoginHint $Config)"
    }
    # Tenant-level `az ad` operations use the active account and do not accept --subscription.
    $active = Invoke-DemoJson 'az' @('account', 'show', '--output', 'json')
    if (-not (Test-DemoAzureAccountScope $Config $active)) {
        throw "The active Azure account does not match this demo's tenant/subscription. No account switch was performed. $(Get-DemoAzureLoginHint $Config)"
    }
    $script:VerifiedAzureScope = "$($Config.TenantId):$($Config.SubscriptionId)".ToLowerInvariant()
}

function Invoke-DemoAzureCommand {
    param([hashtable]$Config, [string[]]$Arguments)
    $scope = "$($Config.TenantId):$($Config.SubscriptionId)".ToLowerInvariant()
    if ($script:VerifiedAzureScope -ne $scope -or $Arguments[0] -in @('ad', 'role')) {
        Assert-DemoAzureScope $Config
    }
    if ($Arguments[0] -ine 'ad') {
        $Arguments += @('--subscription', $Config.SubscriptionId)
    }
    Invoke-DemoCommand 'az' $Arguments
}

function Invoke-DemoAzureJson {
    param([hashtable]$Config, [string[]]$Arguments)
    $text = (Invoke-DemoAzureCommand $Config $Arguments) -join "`n"
    return ConvertFrom-Json -InputObject $text -AsHashtable
}

function Assert-DemoIdentityScope {
    param([hashtable]$Config, [switch]$AllowMissing)
    $path = Join-Path $script:StateRoot 'identity.json'
    if (-not (Test-Path -LiteralPath $path)) {
        if ((Test-Path -LiteralPath (Join-Path $script:StateRoot 'azure-credential.xml')) -or -not $AllowMissing) {
            throw 'Saved credentials have no verifiable tenant binding. Preserve the state and resolve its original tenant before reuse or cleanup.'
        }
        return $null
    }
    $identity = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    if (-not $identity.ContainsKey('tenantId') -or $identity.tenantId -ine $Config.TenantId) {
        throw 'Saved identity belongs to another tenant or has no tenant binding. Use the original configuration and state; do not overwrite it.'
    }
    if (-not $identity.ContainsKey('subscriptionId')) {
        # Older complete runs recorded the tenant on the identity and subscription in setup-config.
        $saved = Get-Content -LiteralPath (Join-Path $script:StateRoot 'setup-config.json') -Raw | ConvertFrom-Json -AsHashtable
        $identity['subscriptionId'] = $saved.SubscriptionId
    }
    if ($identity.subscriptionId -ine $Config.SubscriptionId -or [string]::IsNullOrWhiteSpace($identity.clientId)) {
        throw 'Saved identity does not match this subscription or has no client ID. No credential will be reused or deleted.'
    }
    $client = [guid]::Empty
    if (-not [guid]::TryParse($identity.clientId, [ref]$client)) { throw 'Saved identity clientId is not a GUID.' }
    $ownerPath = Join-Path $script:StateRoot 'owner-id.txt'
    if (-not (Test-Path -LiteralPath $ownerPath) -or
        $identity.roleName -ne "Radius-Demo-ACI-$((Get-Content -LiteralPath $ownerPath -Raw).Trim())") {
        throw 'Saved identity ownership does not match this demo state.'
    }
    return $identity
}

function Assert-DemoSavedConfig {
    param([hashtable]$Config)
    $path = Join-Path $script:StateRoot 'setup-config.json'
    if (-not (Test-Path -LiteralPath $path)) { return }
    $saved = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    foreach ($key in $Config.Keys) {
        if ($key -eq 'TenantId' -and -not $saved.ContainsKey($key)) {
            $null = Assert-DemoIdentityScope $Config
        }
        elseif (-not $saved.ContainsKey($key) -or
            ($key -in @('TenantId', 'SubscriptionId') -and $saved[$key] -ine $Config[$key]) -or
            ($key -notin @('TenantId', 'SubscriptionId') -and $saved[$key] -cne $Config[$key])) {
            throw "Saved setup differs at $key. Restore the original tenant/configuration or use a separate checkout and Radius control plane."
        }
    }
}

function Invoke-DemoRad {
    param([string[]]$Arguments)
    Invoke-DemoCommand 'rad' ($Arguments + @('--config', (Join-Path $script:StateRoot 'rad.yaml')))
}

function Invoke-DemoRadiusCredentialJson {
    param([ValidateSet('list', 'show')][string]$Operation, [string]$Workspace)
    $arguments = @('credential', $Operation)
    $banner = '^Listing credentials for all cloud providers for Radius installation "([^"\\]|\\.)*"\.\.\.$'
    if ($Operation -eq 'show') {
        $arguments += 'azure'
        $banner = '^Showing credential for cloud provider "azure" for Radius installation "([^"\\]|\\.)*"\.\.\.$'
    }
    $text = (Invoke-DemoRad ($arguments + @('--workspace', $Workspace, '--output', 'json'))) -join "`n"
    # Radius 0.62 writes this status line to the same stream as its JSON result.
    $lines = $text -split '\r?\n', 2
    if ($lines[0] -cmatch $banner) {
        Write-Host $lines[0]
        if ($lines.Count -ne 2) { throw "Radius credential $Operation returned a status line without JSON." }
        $text = $lines[1]
    }
    try { $result = ConvertFrom-Json -InputObject $text -AsHashtable -NoEnumerate }
    catch { throw "Radius credential $Operation returned invalid JSON. The control-plane credential check cannot continue." }
    if ($Operation -eq 'list') {
        if ($result -isnot [array]) { throw 'Radius credential list must return a JSON array.' }
        foreach ($provider in $result) {
            if ($provider -isnot [System.Collections.IDictionary] -or
                $provider['Name'] -isnot [string] -or [string]::IsNullOrWhiteSpace($provider['Name']) -or
                $provider['Enabled'] -isnot [bool]) {
                throw 'Radius credential list returned invalid provider metadata.'
            }
        }
    }
    elseif ($result -isnot [System.Collections.IDictionary]) { throw 'Radius credential show must return a JSON object.' }
    return ,$result
}

function Assert-DemoRadiusCredential {
    param([hashtable]$Config, [switch]$AllowMissing)
    $workspace = (Get-DemoTarget aks $Config).Workspace
    $providers = Invoke-DemoRadiusCredentialJson -Operation list -Workspace $workspace
    $azure = @($providers | Where-Object { $null -ne $_ -and $_.Name -eq 'azure' -and $_.Enabled })
    if ($azure.Count -eq 0) {
        if ($AllowMissing) { return }
        throw 'The selected Radius control plane has no Azure credential. Complete preparation for this tenant first.'
    }
    if ($azure.Count -ne 1) { throw 'The Radius Azure credential selection is ambiguous.' }
    $identity = Assert-DemoIdentityScope $Config -AllowMissing
    if (-not $identity) {
        throw "Radius still has an Azure credential in workspace $workspace, but this checkout has no saved identity ownership record. An older cleanup may have left that registration behind. Verify and unregister only the stale demo credential before preparing again; an unverified credential will not be overwritten."
    }
    $registered = Invoke-DemoRadiusCredentialJson -Operation show -Workspace $workspace
    $credential = $registered.AzureCredentials
    if ($credential.Kind -ne 'ServicePrincipal' -or $credential.ServicePrincipal.TenantID -ine $Config.TenantId -or
        $credential.ServicePrincipal.ClientID -ine $identity.clientId) {
        throw 'This Radius control plane is bound to another identity/tenant. Use a dedicated control plane; its credential will not be overwritten.'
    }
}

function Remove-DemoRadiusCredential {
    param([hashtable]$Config)
    $workspace = (Get-DemoTarget aks $Config).Workspace
    $providers = Invoke-DemoRadiusCredentialJson -Operation list -Workspace $workspace
    if (@($providers | Where-Object { $_.Name -eq 'azure' -and $_.Enabled }).Count -eq 0) { return }
    Assert-DemoRadiusCredential $Config
    Invoke-DemoRad @('credential', 'unregister', 'azure', '--workspace', $workspace)
    $remaining = Invoke-DemoRadiusCredentialJson -Operation list -Workspace $workspace
    if (@($remaining | Where-Object { $_.Name -eq 'azure' -and $_.Enabled }).Count -ne 0) {
        throw 'Radius still reports an Azure credential after unregistering it. Identity ownership records and credential backups were retained.'
    }
}

function Get-DemoTarget {
    param([ValidateSet('local', 'aks', 'aci')][string]$Target, [hashtable]$Config)
    return @{
        Name = $Target
        Workspace = "$($Config.Prefix)-$(if ($Target -eq 'local') { 'local' } else { 'azure' })"
        Group = "$($Config.Prefix)-$Target"
        Namespace = "$($Config.Prefix)-$Target"
        Context = $(if ($Target -eq 'local') { $Config.LocalContext } else { $Config.AksContext })
        ResourceGroup = $(if ($Target -eq 'aks') { "$($Config.Prefix)-aks-data" } elseif ($Target -eq 'aci') { "$($Config.Prefix)-aci" } else { '' })
    }
}

function Get-DemoFingerprints {
    $hashes = [ordered]@{}
    $configFile = [IO.Path]::GetFileName((Get-DemoConfigPath))
    foreach ($file in @('app.bicep', 'images.lock.json', 'bicepconfig.json', 'radius-version.txt', 'kubernetes-recipes.lock.json', $configFile,
        'platform\local.bicep', 'platform\cloud.bicep', 'platform\kubernetes-containers.bicep', 'platform\aci-containers.bicep', 'platform\vote-policy-template.json')) {
        $hashes[$file] = (Get-FileHash -LiteralPath (Join-Path $script:DemoRoot $file) -Algorithm SHA256).Hash
    }
    return $hashes
}

function Assert-DemoFingerprints {
    param([System.Collections.IDictionary]$Expected, [string]$Context = 'preparation')
    $actual = Get-DemoFingerprints
    foreach ($file in $actual.Keys) {
        if (-not $Expected.Contains($file) -or $actual[$file] -ne $Expected[$file]) {
            $saved = if ($Expected.Contains($file)) { $Expected[$file] } else { '<missing>' }
            throw "$file changed since $Context. Expected SHA256: $saved. Actual SHA256: $($actual[$file]). Update the policy template if needed and let 00-prepare finish without editing inputs. A failed, cancelled, or preview-only preparation does not refresh the saved baseline."
        }
    }
}

function Get-DemoBaseline {
    $path = Join-Path $script:StateRoot 'baseline.json'
    if (-not (Test-Path -LiteralPath $path)) { throw 'Run .\scripts\00-prepare.ps1 before deploying.' }
    $baseline = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    $preparedAt = ([DateTimeOffset]$baseline.preparedAt).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Assert-DemoFingerprints $baseline.hashes -Context "preparation recorded at $preparedAt in $path"
    return $baseline
}

function Get-DemoPassword {
    param([ValidateSet('local', 'aks', 'aci')][string]$Target)
    $path = Join-Path $script:StateRoot "$Target.password"
    if (-not (Test-Path -LiteralPath $path)) {
        $value = 'Rd!' + [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)) + 'a'
        $secure = ConvertTo-SecureString $value -AsPlainText -Force
        [IO.File]::WriteAllText($path, (ConvertFrom-SecureString $secure))
    }
    $secure = Get-Content -LiteralPath $path -Raw | ConvertTo-SecureString
    return [Net.NetworkCredential]::new('', $secure).Password
}

function Get-DemoPolicyHash {
    param([string]$Policy)
    if ([string]::IsNullOrWhiteSpace($Policy)) { throw 'The confidential policy is missing.' }
    $bytes = [Convert]::FromBase64String($Policy.Trim())
    if ($bytes.Length -lt 100) { throw 'The confidential policy is unexpectedly short.' }
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
}

function Get-DemoPolicySourceHashes {
    $hashes = [ordered]@{}
    foreach ($file in @('app.bicep', 'images.lock.json', 'platform/vote-policy-template.json', 'platform/aci-containers.bicep')) {
        $path = Join-Path $script:DemoRoot ($file.Replace('/', [IO.Path]::DirectorySeparatorChar))
        $hashes[$file] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    return $hashes
}

function Save-DemoPolicyBundle {
    param([hashtable]$Bundle, [string]$Location)
    if ($Bundle.schemaVersion -ne 1 -or $Bundle.location -ne $Location -or $Bundle.generator -ne 'az confcom acipolicygen --diff') {
        throw 'Policy bundle version, location, or validation record does not match this preparation.'
    }
    $expectedSources = Get-DemoPolicySourceHashes
    if ($Bundle.sourceHashes.Count -ne $expectedSources.Count) { throw 'Policy bundle source set is incomplete.' }
    foreach ($file in $expectedSources.Keys) {
        if ($Bundle.sourceHashes[$file] -ne $expectedSources[$file]) { throw "Policy bundle is stale: $file differs." }
    }
    $policy = $Bundle.policy.Trim()
    $policyHash = Get-DemoPolicyHash $policy
    if ($policyHash -ne $Bundle.policyHash) { throw 'Policy bundle hash does not match its policy.' }
    $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($policy))
    if ($decoded -notmatch '(?m)^\s*package\s+policy\b' -or $decoded -match '(?i)["'']?allow_all["'']?\s*(?::=|=|:)\s*true') {
        throw 'The bundle must contain a generated Rego enforcement policy, not an allow-all policy.'
    }
    $images = (Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable).images
    foreach ($name in @('redis', 'vote', 'worker')) {
        if (-not $decoded.Contains($images[$name])) { throw "The policy does not contain the locked $name image." }
    }
    $generated = Join-Path $script:DemoRoot 'platform\generated'
    $null = New-Item -ItemType Directory -Path $generated -Force
    [IO.File]::WriteAllText((Join-Path $generated 'vote-ccepolicy.b64'), $policy, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $generated 'vote-policy.rego'), $decoded, [Text.UTF8Encoding]::new($false))
    Write-DemoJson (Join-Path $generated 'policy-bundle.json') $Bundle
    return $Bundle
}

function Assert-DemoPolicyGenerator {
    if (-not $IsWindows) { throw 'Generate the policy with the Bash script on Linux/WSL, or this script on Windows.' }
    $engine = Get-DemoContainerEngine
    if ($engine.OS -cne 'linux' -or $engine.Architecture -cne 'amd64') {
        throw "Policy generation requires a Linux/AMD64 container engine; detected $($engine.Provider) $($engine.OS)/$($engine.Architecture)."
    }
    # confcom reaches the engine through the Docker API (DOCKER_HOST or the docker_engine pipe), not the docker CLI.
    $dockerHost = if ([string]::IsNullOrWhiteSpace($env:DOCKER_HOST)) { 'npipe:////./pipe/docker_engine' } else { $env:DOCKER_HOST }
    if ($dockerHost -match '^npipe:/*\./pipe/(?<pipe>[^/]+)$' -and
        [IO.Directory]::GetFiles('\\.\pipe\') -notcontains "\\.\pipe\$($Matches.pipe)") {
        $restore = if ($engine.Provider -eq 'Podman') {
            "Podman serves it through its machine's API forwarding (win-sshproxy.exe), which is not running. Restart the machine (podman machine stop; podman machine start) and then the kind node; see the README."
        } else { 'Start Docker Desktop, then rerun.' }
        throw "confcom needs the Docker API at $dockerHost, which is not available. $restore Or rerun with -PolicyBundle .\platform\generated\policy-bundle.json."
    }
    $az = Resolve-DemoCommand 'az'
    if (-not $az) { throw 'Cannot find az. Run the prerequisite checker for installation/PATH guidance.' }
    # A damaged extension can still exit 0 here, without a version; acipolicygen then fails to load it.
    $version = ((& $az extension show --name confcom --query version -o tsv) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^\d+(\.\d+)+') {
        throw "Azure CLI cannot load the confcom extension in this terminal, so it cannot generate the policy. Rerun with -PolicyBundle .\platform\generated\policy-bundle.json, or repair the extension; 'az extension show --name confcom --output json --debug' shows the cause."
    }
}

function New-DemoPolicyBundle {
    param([string]$Location = 'eastus2')
    Assert-DemoPolicyGenerator
    $sourceHashes = Get-DemoPolicySourceHashes
    $templatePath = Join-Path $script:StateRoot 'vote-policy-input.json'
    $template = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'platform\vote-policy-template.json') -Raw | ConvertFrom-Json -AsHashtable
    $images = (Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable).images
    $template.resources[0].location = $Location
    foreach ($container in $template.resources[0].properties.containers) { $container.properties.image = $images[$container.name] }
    Write-DemoJson $templatePath $template
    Write-Host 'Generating and checking an enforcement policy for the three pinned images.'
    $null = Invoke-DemoCommand 'az' @('confcom', 'acipolicygen', '--template-file', $templatePath, '--approve-wildcards')
    $null = Invoke-DemoCommand 'az' @('confcom', 'acipolicygen', '--template-file', $templatePath, '--diff', '--approve-wildcards')
    $template = Get-Content -LiteralPath $templatePath -Raw | ConvertFrom-Json -AsHashtable
    $policy = $template.resources[0].properties.confidentialComputeProperties.ccePolicy.Trim()
    return Save-DemoPolicyBundle -Location $Location -Bundle @{
        schemaVersion = 1
        location = $Location
        generator = 'az confcom acipolicygen --diff'
        sourceHashes = $sourceHashes
        policy = $policy
        policyHash = Get-DemoPolicyHash $policy
        validatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    }
}

function Get-PublicOciManifest {
    param([string]$Repository, [string]$Reference)
    $token = (Invoke-RestMethod -Uri "https://ghcr.io/token?scope=repository:${Repository}:pull").token
    $headers = @{
        Authorization = "Bearer $token"
        Accept = 'application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json'
    }
    return Invoke-WebRequest -Uri "https://ghcr.io/v2/$Repository/manifests/$Reference" -Headers $headers
}

function ConvertFrom-DemoWebJson {
    param([object]$Response)
    $text = if ($Response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($Response.Content) } else { [string]$Response.Content }
    return ConvertFrom-Json -InputObject $text -AsHashtable
}

function Assert-DemoPublicKubernetesRecipes {
    $commit = Get-DemoKubernetesRecipeCommit
    foreach ($name in @('containers', 'postgresqldatabases')) {
        try {
            $manifest = ConvertFrom-DemoWebJson (Get-PublicOciManifest "radius-project/kube-recipes/$name" $commit)
        }
        catch { throw "Cannot read pinned Kubernetes recipe ${name}:${commit}. $($_.Exception.Message)" }
        if ($manifest.config.mediaType -cne 'application/vnd.ms.bicep.module.config.v1+json' -or
            @($manifest.layers | Where-Object { $_.mediaType -ceq 'application/vnd.ms.bicep.module.layer.v1+json' }).Count -ne 1) {
            throw "Pinned Kubernetes recipe $name is not a Bicep module."
        }
        Write-Host "Public Bicep recipe verified: ${name}:${commit}"
    }
    $wrapper = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'platform\kubernetes-containers.bicep') -Raw
    $references = [regex]::Matches($wrapper, 'kube-recipes/containers:([a-f0-9]+)')
    if ($references.Count -ne 1 -or $references[0].Groups[1].Value -cne $commit) {
        throw "platform\kubernetes-containers.bicep must wrap kube-recipes/containers:$commit from kubernetes-recipes.lock.json."
    }
}

function Publish-DemoPlatformRecipe {
    param([string]$File, [string]$Repository, [string]$Tag, [string]$RecordName, [hashtable]$Record = @{})
    $source = "${Repository}:$Tag"
    $recordPath = Join-Path $script:StateRoot $RecordName
    $published = if (Test-Path -LiteralPath $recordPath) { Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    if ($published['source'] -ne $source) {
        Write-Host "Publishing $([IO.Path]::GetFileName($File)). Radius must already have usable GHCR credentials."
        Invoke-DemoCommand 'rad' @('bicep', 'publish', '--file', $File, '--target', "br:$source") | Out-Host
        Write-DemoJson $recordPath ($Record + @{ source = $source })
    }
    try {
        $null = Get-PublicOciManifest $Repository.Substring('ghcr.io/'.Length) $Tag
    }
    catch {
        throw "The published recipe is not anonymously readable. Make only this demo package public in GitHub Packages, then rerun preparation. Source: $source. Details: $($_.Exception.Message)"
    }
    return $source
}

function Assert-DemoPublicImages {
    $lock = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($name in $lock.images.Keys) {
        $image = $lock.images[$name]
        if ($image -notmatch '^ghcr\.io/(?<repository>[^@]+)@(?<digest>sha256:[a-f0-9]{64})$') {
            throw "$name is not pinned to a GHCR image digest."
        }
        $repository = $Matches.repository
        $digest = $Matches.digest
        $response = Get-PublicOciManifest $repository $digest
        $actual = [string]($response.Headers['Docker-Content-Digest'] | Select-Object -First 1)
        if ($actual -ne $digest) { throw "Registry digest mismatch for $name." }
        $manifest = ConvertFrom-DemoWebJson $response
        if (-not $manifest.ContainsKey('config')) { throw "$name is an image index. Lock its linux/amd64 child manifest instead." }
        $token = (Invoke-RestMethod -Uri "https://ghcr.io/token?scope=repository:${repository}:pull").token
        $blob = Invoke-WebRequest -Uri "https://ghcr.io/v2/$repository/blobs/$($manifest.config.digest)" -Headers @{ Authorization = "Bearer $token" }
        $configuration = ConvertFrom-DemoWebJson $blob
        if ($configuration.os -ne 'linux' -or $configuration.architecture -ne 'amd64') {
            throw "$name must be a linux/amd64 manifest, not a platform index or another architecture."
        }
        Write-Host "Public, linux/amd64, digest verified: $name"
    }
}

function Get-DemoKubernetesServiceUrl {
    param([hashtable]$Info, [ValidateSet('vote', 'result')][string]$App, [int]$WaitSeconds)
    $name = "$App-$App-external"
    $expectedType = if ($Info.Name -eq 'local') { 'NodePort' } else { 'LoadBalancer' }
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($WaitSeconds)
    while ($true) {
        $text = (Invoke-DemoCommand 'kubectl' @('--context', $Info.Context, '-n', $Info.Namespace,
            'get', 'service', $name, '--ignore-not-found', '-o', 'json')) -join "`n"
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "Service $name is missing in $($Info.Context)/$($Info.Namespace). Rerun preparation so the $($Info.Name) recipe pack publishes the app natively, then redeploy."
        }
        $service = ConvertFrom-Json -InputObject $text -AsHashtable
        if ($service.spec.type -cne $expectedType) {
            throw "Service $name in $($Info.Context)/$($Info.Namespace) is $($service.spec.type), not $expectedType. Rerun preparation, then redeploy."
        }
        $port = @($service.spec.ports)[0]
        if ($expectedType -eq 'NodePort') { return "http://127.0.0.1:$($port.nodePort)" }
        $ingress = @()
        if ($service.ContainsKey('status') -and $service.status.ContainsKey('loadBalancer') -and
            $service.status.loadBalancer -is [System.Collections.IDictionary] -and $service.status.loadBalancer.ContainsKey('ingress')) {
            $ingress = @($service.status.loadBalancer.ingress)
        }
        $address = $null
        if ($ingress.Count -gt 0 -and $ingress[0].ContainsKey('ip') -and [Net.IPAddress]::TryParse([string]$ingress[0].ip, [ref]$address)) {
            if ($port.port -eq 80) { return "http://$($ingress[0].ip)" }
            return "http://$($ingress[0].ip):$($port.port)"
        }
        if ([DateTimeOffset]::UtcNow -ge $deadline) {
            throw "Azure has not assigned a public IP to Service $name yet. Inspect: kubectl --context $($Info.Context) -n $($Info.Namespace) describe service $name"
        }
        Start-Sleep -Seconds 5
    }
}

function Get-DemoUrls {
    param([ValidateSet('local', 'aks', 'aci')][string]$Target, [hashtable]$Config, [ValidateRange(0, 900)][int]$WaitSeconds = 0)
    $targetInfo = Get-DemoTarget $Target $Config
    if ($Target -ne 'aci') {
        return @{
            Vote = Get-DemoKubernetesServiceUrl $targetInfo 'vote' $WaitSeconds
            Result = Get-DemoKubernetesServiceUrl $targetInfo 'result' $WaitSeconds
        }
    }
    $urls = @{}
    foreach ($role in @('vote', 'result')) {
        $ip = ((Invoke-DemoAzureCommand $Config @('network', 'public-ip', 'show',
            '--resource-group', $targetInfo.ResourceGroup, '--name', "$role-inbound", '--query', 'ipAddress', '-o', 'tsv')) -join '').Trim()
        $address = $null
        if (-not [Net.IPAddress]::TryParse($ip, [ref]$address)) { throw "No public IP was returned for $role-inbound." }
        $urls[$role] = "http://$ip"
    }
    return $urls
}

function Get-DemoEndpointHint {
    param([ValidateSet('local', 'aks', 'aci')][string]$Target, [hashtable]$Config)
    $info = Get-DemoTarget $Target $Config
    switch ($Target) {
        'local' { return 'The local cluster must publish the node ports of its vote and result Services on 127.0.0.1, as infra/kind.yaml does. Recreate an older kind cluster, then rerun preparation and script 02.' }
        'aks' { return "Check the vote-vote-external and result-result-external load balancer Services and pods in $($info.Context)/$($info.Namespace)." }
        default { return 'Check the ACI deployment and its public endpoints.' }
    }
}

function Wait-DemoEndpoints {
    param([hashtable]$Urls, [string]$Hint, [ValidateRange(10, 900)][int]$TimeoutSeconds = 180)
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    foreach ($url in @($Urls.Vote, $Urls.Result)) {
        while ($true) {
            try {
                $response = Invoke-WebRequest -Uri $url -TimeoutSec 5
                if ($response.StatusCode -eq 200) { break }
                $detail = "HTTP $($response.StatusCode)"
            }
            catch { $detail = $_.Exception.GetBaseException().Message }
            if ([DateTimeOffset]::UtcNow -ge $deadline) {
                throw "Demo endpoint $url did not answer within $TimeoutSeconds seconds. $Hint Last error: $detail"
            }
            Start-Sleep -Seconds 3
        }
    }
}

function Format-DemoImageReference {
    param([string]$Image)
    # Keep the repository and enough of the digest to compare by eye.
    return $Image -replace '(@sha256:[a-f0-9]{12})[a-f0-9]{52}$', '$1...'
}

function Show-DemoDeploymentSummary {
    param([ValidateSet('local', 'aks', 'aci')][string]$Target, [hashtable]$Config, [System.Collections.IDictionary]$Hashes)
    $info = Get-DemoTarget $Target $Config
    Write-Host 'Same inputs for every target, checked against the preparation baseline:'
    Write-Host "  app.bicep         SHA256 $($Hashes['app.bicep'].Substring(0, 16))"
    Write-Host "  images.lock.json  SHA256 $($Hashes['images.lock.json'].Substring(0, 16))"
    if ($Target -ne 'aci') {
        $images = (Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable).images
        $pods = Invoke-DemoJson 'kubectl' @('--context', $info.Context, '-n', $info.Namespace, 'get', 'pods', '-o', 'json')
        Write-Host "Application containers in $($info.Namespace), locked image digests (no environment values):"
        foreach ($name in @($images.Keys | Sort-Object)) {
            $found = 0
            foreach ($pod in $pods.items) {
                if ($pod.metadata.ContainsKey('deletionTimestamp')) { continue }
                foreach ($spec in @($pod.spec.containers | Where-Object { $_.name -eq $name })) {
                    if ($spec.image -ne $images[$name]) {
                        throw "$Target/$name does not use the locked image reference; the deployment was not marked as successful."
                    }
                    $statuses = if ($pod.status.ContainsKey('containerStatuses')) { @($pod.status.containerStatuses) } else { @() }
                    $status = @($statuses | Where-Object { $_.name -eq $name })
                    $state = if ($status.Count -eq 1 -and $status[0].ready) { 'Ready' } else { 'Not ready' }
                    Write-Host ('  {0,-7} {1}  {2}' -f $name, (Format-DemoImageReference $spec.image), $state)
                    $found++
                }
            }
            if ($found -eq 0) { throw "No running $name container found on $Target." }
        }
    }
    if ($Target -ne 'local') {
        $servers = @(Invoke-DemoAzureJson $Config @('postgres', 'flexible-server', 'list',
            '--resource-group', $info.ResourceGroup, '-o', 'json'))
        if ($servers.Count -eq 0) { throw "No Azure PostgreSQL server found in $($info.ResourceGroup)." }
        foreach ($server in $servers) { Write-Host "Azure PostgreSQL in $($info.ResourceGroup): $($server.name) | $($server.state)" }
    }
}

function Show-DemoPolicyExcerpt {
    $baseline = Get-DemoBaseline
    $generated = Join-Path $script:DemoRoot 'platform\generated'
    $policyHash = Get-DemoPolicyHash (Get-Content -LiteralPath (Join-Path $generated 'vote-ccepolicy.b64') -Raw)
    if ($policyHash -ne $baseline.policyHash) { throw 'The generated policy no longer matches the prepared recipe. Rerun preparation, then the deployment steps.' }
    $regoBytes = [IO.File]::ReadAllBytes((Join-Path $generated 'vote-policy.rego'))
    if ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($regoBytes)) -ne $policyHash) {
        throw 'vote-policy.rego is not the decoded policy that the recipe passes to Azure. Rerun preparation.'
    }
    $rego = [Text.Encoding]::UTF8.GetString($regoBytes)
    if ($rego -match '(?i)["'']?allow_all["'']?\s*(?::=|=|:)\s*true') { throw 'An allow-all policy is not acceptable.' }
    $rule = @($rego -split '\r?\n' | Where-Object { $_.StartsWith('containers := ') })
    if ($rule.Count -ne 1) { throw 'Cannot find the containers rule in vote-policy.rego.' }
    $containers = @(ConvertFrom-Json -InputObject $rule[0].Substring('containers := '.Length) -AsHashtable)
    $images = (Get-Content -LiteralPath (Join-Path $script:DemoRoot 'images.lock.json') -Raw | ConvertFrom-Json -AsHashtable).images
    $template = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'platform\vote-policy-template.json') -Raw | ConvertFrom-Json -AsHashtable
    $voteTemplate = @($template.resources[0].properties.containers | Where-Object { $_.name -eq 'vote' })
    $appVariables = @($voteTemplate[0].properties.environmentVariables | ForEach-Object { $_.name })
    $entries = foreach ($name in @('redis', 'vote', 'worker')) {
        $entry = @($containers | Where-Object { $_.name -eq $name })
        if ($entry.Count -ne 1 -or $entry[0].id -ne $images[$name]) { throw "The policy does not pin the locked $name image." }
        $entry[0]
    }
    Write-Host 'Confidential policy for the vote group: platform/generated/vote-policy.rego'
    Write-Host "Policy SHA256: $policyHash"
    Write-Host 'This file decodes the exact policy the ACI recipe passes to Azure. Allow-all: no.'
    Write-Host 'Allowed containers, pinned to the locked images:'
    foreach ($entry in $entries) { Write-Host ('  {0,-7} {1}' -f $entry.name, (Format-DemoImageReference $entry.id)) }
    $vote = @($entries | Where-Object { $_.name -eq 'vote' })[0]
    Write-Host 'vote startup rules (excerpt):'
    Write-Host "  command  $($vote.command -join ' ')"
    foreach ($envRule in @($vote.env_rules | Where-Object { $_.strategy -eq 'string' -and ($_.pattern -split '=', 2)[0] -in $appVariables })) {
        Write-Host "  env      $($envRule.pattern)"
    }
}

function Invoke-DemoDeployment {
    param([ValidateSet('local', 'aks', 'aci')][string]$Target, [switch]$Plan)
    $config = Get-DemoConfig
    $targetInfo = Get-DemoTarget $Target $config
    Write-Host "rad deploy app.bicep --workspace $($targetInfo.Workspace) --group $($targetInfo.Group) --environment $Target --parameters @<private-parameters.json>"
    if ($Plan) { return }
    $baseline = Get-DemoBaseline
    if ($Target -ne 'local') {
        Assert-DemoAzureScope $config
        $null = Assert-DemoIdentityScope $config
        Assert-DemoRadiusCredential $config
    }
    if ($Target -eq 'aci') {
        $policy = Get-Content -LiteralPath (Join-Path $script:DemoRoot 'platform\generated\vote-ccepolicy.b64') -Raw
        if ((Get-DemoPolicyHash $policy) -ne $baseline.policyHash) { throw 'The policy changed. Rerun preparation, then the deployment steps.' }
    }
    Write-DemoJson (Join-Path $script:StateRoot "$Target.receipt.json") @{
        target = $Target
        status = 'deploying'
        deployedAt = $null
        hashes = $baseline.hashes
        voteProof = $null
    }
    $parameterPath = Join-Path $script:StateRoot "$Target-$([guid]::NewGuid().ToString('N')).parameters.json"
    try {
        Write-DemoJson $parameterPath @{
            '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
            contentVersion = '1.0.0.0'
            parameters = @{ postgresPassword = @{ value = (Get-DemoPassword $Target) } }
        }
        Invoke-DemoRad @('deploy', (Join-Path $script:DemoRoot 'app.bicep'),
            '--workspace', $targetInfo.Workspace, '--group', $targetInfo.Group, '--environment', $Target,
            '--parameters', "@$parameterPath")
    }
    finally {
        if (Test-Path -LiteralPath $parameterPath) { Remove-Item -LiteralPath $parameterPath -Force }
    }
    if ($Target -ne 'aci') {
        foreach ($deployment in @('vote', 'result')) {
            Invoke-DemoCommand 'kubectl' @('--context', $targetInfo.Context, '-n', $targetInfo.Namespace,
                'rollout', 'status', "deployment/$deployment", '--timeout=240s')
        }
    }
    Assert-DemoFingerprints $baseline.hashes
    Show-DemoDeploymentSummary -Target $Target -Config $config -Hashes $baseline.hashes
    $urls = Get-DemoUrls $Target $config -WaitSeconds 300
    Wait-DemoEndpoints $urls (Get-DemoEndpointHint $Target $config)
    Write-DemoJson (Join-Path $script:StateRoot "$Target.receipt.json") @{
        target = $Target
        status = 'deployed'
        deployedAt = [DateTimeOffset]::UtcNow.ToString('o')
        hashes = $baseline.hashes
        voteProof = $null
    }
    Write-Host "Vote:   $($urls.Vote)"
    Write-Host "Result: $($urls.Result)"
    Write-Host "Then run .\scripts\Test-VoteFlow.ps1 -Target $Target and make a browser vote."
}
