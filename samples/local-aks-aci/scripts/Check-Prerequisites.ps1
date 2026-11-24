#requires -Version 7.2
[CmdletBinding()]
param([switch]$CheckClusters)
. "$PSScriptRoot\Demo.Common.ps1"

if (-not $IsWindows) { throw 'Use Check-Prerequisites.sh on Linux/WSL/macOS.' }
$script:Blockers = 0
$script:Warnings = 0
$requiredRadius = Get-DemoRequiredRadiusVersion
$radiusMinor = ($requiredRadius -split '\.')[0..1] -join '.'

function Write-Prerequisite {
    param([string]$Name, [string]$Detected, [string]$Required,
        [ValidateSet('OK', 'FAIL', 'WARN', 'SKIP')][string]$Status, [string]$Advice = '')
    if ($Status -eq 'FAIL') { $script:Blockers++ }
    if ($Status -eq 'WARN') { $script:Warnings++ }
    Write-Host ('[{0,-4}] {1,-23} {2,-18} Required: {3}' -f $Status, $Name, $Detected, $Required)
    if ($Status -ne 'OK' -and $Advice) { Write-Host ('       Suggested: ' + $Advice.Replace("`n", "`n                  ")) }
}

function Read-PrerequisiteCommand {
    param([string]$Tool, [string[]]$Arguments)
    $fromDefaultLocation = $Tool -ieq 'rad' -and -not (Get-Command $Tool -ErrorAction SilentlyContinue)
    $command = Resolve-DemoCommand $Tool
    if (-not $command) {
        return @{ Success = $false; Missing = $true; Text = ''; Command = $Tool; FromDefaultLocation = $false }
    }
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $command @Arguments 2>&1)
        $code = $LASTEXITCODE
        $text = if ($code -eq 0) {
            @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) -join "`n"
        } else { $output -join "`n" }
        return @{ Success = ($code -eq 0); Missing = $false; Text = $text; Command = $command; FromDefaultLocation = $fromDefaultLocation }
    }
    catch {
        return @{ Success = $false; Missing = $false; Text = $_.Exception.Message; Command = $command; FromDefaultLocation = $fromDefaultLocation }
    }
    finally { $ErrorActionPreference = $previousPreference }
}

function Get-PrerequisiteFailureDetail {
    param([string]$Text)
    $lines = @($Text -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $specific = @($lines | Where-Object {
        $_ -match '^(ERROR:|PermissionError:|Error:)' -and $_ -notmatch 'command failed with an unexpected error|traceback:'
    })
    $detail = if ($specific.Count) { $specific[0] } elseif ($lines.Count) { $lines[0] } else { 'The command returned no diagnostic output.' }
    if ($detail.Length -gt 500) { $detail = $detail.Substring(0, 500) + '...' }
    return $detail
}

function ConvertTo-PrerequisiteVersion {
    param([string]$Text)
    $match = [regex]::Match($Text, '\d+\.\d+(?:\.\d+)?')
    if (-not $match.Success) { return $null }
    $value = $match.Value
    if (($value -split '\.').Count -eq 2) { $value += '.0' }
    return [version]$value
}

function Test-PrerequisiteTool {
    param([string]$Name, [string]$Tool, [string[]]$Arguments, [string]$Install,
        [string]$Minimum = '', [string]$Exact = '', [switch]$Optional,
        [scriptblock]$Selector = { param($text) ([regex]::Match($text, '\d+\.\d+(?:\.\d+)?')).Value })
    $requirement = if ($Exact) { $Exact } elseif ($Minimum) { ">=$Minimum" } else { 'present; version reported' }
    $failure = if ($Optional) { 'WARN' } else { 'FAIL' }
    $result = Read-PrerequisiteCommand $Tool $Arguments
    if ($result.FromDefaultLocation) {
        Write-Prerequisite 'Radius process PATH' 'installed; PATH stale' 'current shell sees the installer location' 'WARN' `
            ('Restart the terminal to inherit the updated User PATH. For this terminal only: $env:PATH = "$env:LOCALAPPDATA\radius;$env:PATH"')
        Write-Host "       Using the documented installation: $($result.Command)"
    }
    if (-not $result.Success) {
        if ($result.Missing) {
            Write-Prerequisite $Name 'not on PATH' $requirement $failure $Install
        }
        elseif ($result.Text -match '(?i)WinError 5|access is denied|access denied|permission denied|PermissionError|UnauthorizedAccess') {
            Write-Prerequisite $Name 'access denied' $requirement $failure `
                'Have the current account/application access to the reported path reviewed and legitimately restored. This is not a missing-installation result; do not reinstall or bypass permissions based on it.'
            Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $result.Text)"
        }
        elseif ($Name -eq 'Azure confcom extension' -and $result.Text -match '(?i)extension.*confcom.*not installed|confcom.*extension.*not installed') {
            Write-Prerequisite $Name 'extension not installed' $requirement $failure $Install
            Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $result.Text)"
        }
        else {
            Write-Prerequisite $Name 'version command failed' $requirement $failure "Inspect the diagnostic and rerun '$Tool $($Arguments -join ' ')' in the intended shell/account. Installation is not assumed to be missing."
            Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $result.Text)"
        }
        return $null
    }
    try {
        $detected = [string](& $Selector $result.Text)
        if ([string]::IsNullOrWhiteSpace($detected)) { throw 'No version was returned.' }
        $normalized = ConvertTo-PrerequisiteVersion $detected
        if ($null -eq $normalized) { throw 'No numeric version was returned.' }
    }
    catch {
        if ($Name -eq 'Azure confcom extension') {
            Write-Prerequisite $Name 'metadata/version unavailable' $requirement $failure `
                'In the affected terminal, run: az extension show --name confcom --output json --debug. Inspect "Unable to get extension metadata/version" and the accompanying exception before repairing anything.'
            Write-Host "       Diagnostic: $($_.Exception.Message)"
        }
        else {
            Write-Prerequisite $Name 'unrecognized version' $requirement $failure "Run '$Tool $($Arguments -join ' ')' manually; the executable exists, so inspect its output before reinstalling."
            Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $result.Text)"
        }
        return $null
    }
    $matches = if ($Exact) { $detected.TrimStart('v') -ceq $Exact } elseif ($Minimum) { $normalized -ge [version]$Minimum } else { $true }
    if ($matches) { Write-Prerequisite $Name $detected $requirement 'OK' }
    else { Write-Prerequisite $Name $detected $requirement $failure $Install }
    return $normalized
}

$radiusInstall = @'
Invoke-WebRequest 'https://raw.githubusercontent.com/radius-project/radius/v{0}/deploy/install.ps1' -OutFile "$env:TEMP\install-radius.ps1"
# Review the downloaded installer, then run:
& "$env:TEMP\install-radius.ps1" -Version {0}
# Reopen the terminal if rad is still not on PATH.
'@ -f $requiredRadius

Write-Host "Read-only prerequisites | PowerShell | Radius $requiredRadius"
Write-Host 'Commands below are suggestions only. Nothing is installed, configured, or deployed.'
Write-Host ''
Write-Prerequisite 'PowerShell' $PSVersionTable.PSVersion.ToString() '>=7.2.0' 'OK'
$null = Test-PrerequisiteTool -Name 'Radius CLI' -Tool rad -Arguments @('version', '--cli', '--output', 'json') `
    -Exact $requiredRadius -Install $radiusInstall -Selector { param($text) ($text | ConvertFrom-Json).release }
$null = Test-PrerequisiteTool -Name 'Azure CLI' -Tool az -Arguments @('version', '--output', 'json') `
    -Minimum '2.44.1' -Install 'winget install --exact --id Microsoft.AzureCLI' `
    -Selector { param($text) ($text | ConvertFrom-Json).'azure-cli' }
if (Resolve-DemoCommand az) {
    $previousDynamicInstall = $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL
    try {
        $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = 'no'
        $stackCapability = Read-PrerequisiteCommand az @('stack-whatif', 'sub', 'create', '--help')
    }
    finally { $env:AZURE_EXTENSION_USE_DYNAMIC_INSTALL = $previousDynamicInstall }
    if ($stackCapability.Success) { Write-Prerequisite 'Stack what-if (optional)' 'available' 'only for -UseDeploymentStack' 'OK' }
    else {
        Write-Prerequisite 'Stack what-if (optional)' 'unavailable/unreadable' 'only for -UseDeploymentStack' 'WARN' `
            'Inspect: az stack-whatif sub create --help. Upgrade Azure CLI if the command is unknown; inspect access errors instead of reinstalling. The default bootstrap does not need stacks.'
        Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $stackCapability.Text)"
    }
}
else { Write-Prerequisite 'Stack what-if (optional)' 'Azure CLI missing' 'only for -UseDeploymentStack' 'SKIP' }
$null = Test-PrerequisiteTool -Name 'Bicep (AKS bootstrap)' -Tool bicep -Arguments @('--version') -Optional `
    -Install 'winget install --exact --id Microsoft.Bicep'
$containerProvider = $null
$containerHelp = Read-PrerequisiteCommand docker @('version', '--help')
if ($containerHelp.Success) {
    try { $containerProvider = Get-DemoContainerProvider $containerHelp.Text }
    catch { Write-Prerequisite 'Container CLI (docker)' 'unrecognized runtime' 'Docker or Podman' 'FAIL' $_.Exception.Message }
    if ($containerProvider) {
        $containerInstall = if ($containerProvider -eq 'Podman') {
            "winget install --exact --id RedHat.Podman`n# Keep your chosen docker-to-podman link on PATH."
        } else { 'winget install --exact --id Docker.DockerDesktop' }
        $null = Test-PrerequisiteTool -Name "$containerProvider CLI (docker)" -Tool docker -Arguments @('--version') `
            -Minimum (Get-DemoContainerMinimumVersion $containerProvider) -Install $containerInstall
    }
}
else {
    $advice = if ($containerHelp.Missing) {
        "Expose your chosen Docker-compatible CLI on PATH as docker; no link is changed by this checker.`n" +
        "# Choose one runtime if none is installed:`n# Docker option: winget install --exact --id Docker.DockerDesktop`n# Podman option: winget install --exact --id RedHat.Podman"
    } else { 'Inspect: docker version --help. The selected executable could not identify itself; do not assume Docker Desktop is required.' }
    Write-Prerequisite 'Container CLI (docker)' 'unavailable/unreadable' 'Docker or Podman' 'FAIL' $advice
    if (-not $containerHelp.Missing) { Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $containerHelp.Text)" }
}
$kubectlVersion = Test-PrerequisiteTool -Name 'kubectl' -Tool kubectl -Arguments @('version', '--client', '--output', 'json') `
    -Install 'winget install --exact --id Kubernetes.kubectl' `
    -Selector { param($text) ($text | ConvertFrom-Json).clientVersion.gitVersion }
$null = Test-PrerequisiteTool -Name 'kind (cluster creation)' -Tool kind -Arguments @('version') -Minimum '0.33.0' -Optional `
    -Install 'winget install --exact --id Kubernetes.kind --version 0.33.0'
$null = Test-PrerequisiteTool -Name 'GitHub CLI' -Tool gh -Arguments @('--version') -Minimum '2.0.0' `
    -Install 'winget install --exact --id GitHub.cli'
$null = Test-PrerequisiteTool -Name 'kubelogin (AKS Entra)' -Tool kubelogin -Arguments @('--version') -Optional `
    -Install 'winget install --exact --id Microsoft.Azure.Kubelogin'
if (Get-Command az -ErrorAction SilentlyContinue) {
    $null = Test-PrerequisiteTool -Name 'Azure confcom extension' -Tool az `
        -Arguments @('extension', 'show', '--name', 'confcom', '--output', 'json') -Minimum '0.30.0' `
        -Install 'az extension add --name confcom --upgrade' -Selector {
            param($text)
            $extension = $text | ConvertFrom-Json
            if ($null -eq $extension.metadata -or [string]::IsNullOrWhiteSpace($extension.version)) {
                throw 'Azure CLI found the extension directory but returned no package metadata or version. A zero exit code does not establish a usable installation.'
            }
            $extension.version
        }
}
else { Write-Prerequisite 'Azure confcom extension' 'Azure CLI missing' '>=0.30.0' 'SKIP' 'Install Azure CLI, then: az extension add --name confcom --upgrade' }

if ($containerProvider) {
    $minimum = Get-DemoContainerMinimumVersion $containerProvider
    $engineAdvice = if ($containerProvider -eq 'Podman') {
        'Inspect: docker info; docker system connection list; docker machine list. A configured remote machine must be reachable; do not recreate it or install Docker Desktop to hide a connection error.'
    } else { 'Start the selected Docker engine in Linux-container mode; inspect: docker context ls; docker info' }
    $engineResult = Read-PrerequisiteCommand docker @('info', '--format', (Get-DemoContainerInfoFormat $containerProvider))
    if ($engineResult.Success) {
        try {
            $engine = ConvertTo-DemoContainerEngine ($engineResult.Text | ConvertFrom-Json -AsHashtable) $containerProvider
            $engineVersion = ConvertTo-PrerequisiteVersion $engine.Version
            $detected = "$($engine.Version) $($engine.OS)/$($engine.Architecture)"
            if ($engineVersion -ge [version]$minimum -and $engine.OS -ceq 'linux' -and $engine.Architecture -ceq 'amd64') {
                Write-Prerequisite "$containerProvider engine" $detected ">=$minimum; Linux/AMD64" 'OK'
            }
            else { Write-Prerequisite "$containerProvider engine" $detected ">=$minimum; Linux/AMD64" 'FAIL' $engineAdvice }
        }
        catch {
            Write-Prerequisite "$containerProvider engine" 'invalid metadata' ">=$minimum; Linux/AMD64" 'FAIL' `
                "Inspect the selected runtime's info output. $($_.Exception.Message)"
        }
    }
    else {
        Write-Prerequisite "$containerProvider engine" 'not reachable' ">=$minimum; Linux/AMD64" 'FAIL' $engineAdvice
        Write-Host "       Diagnostic: $(Get-PrerequisiteFailureDetail $engineResult.Text)"
    }
}
else { Write-Prerequisite 'Container engine' 'CLI not identified' 'Linux/AMD64' 'SKIP' 'Resolve the container CLI diagnostic first.' }

$alias = (Get-Content -LiteralPath (Join-Path $script:DemoRoot 'bicepconfig.json') -Raw | ConvertFrom-Json).extensions.radius
try {
    $recipeCommit = Get-DemoKubernetesRecipeCommit
    if ($alias -cne "br:biceptypes.azurecr.io/radius:$radiusMinor") { throw 'The Bicep extension does not match the Radius release pin.' }
    Write-Prerequisite 'Bicep/recipe pins' "$requiredRadius / $($recipeCommit.Substring(0, 7))" 'CLI/type pin and recipe lock' 'OK'
}
catch {
    Write-Prerequisite 'Bicep/recipe pins' 'inconsistent' 'CLI/type pin and recipe lock' 'FAIL' `
        "Check bicepconfig.json and kubernetes-recipes.lock.json against radius-version.txt and the release catalog; recipe tags are not CLI versions. $($_.Exception.Message)"
}

$config = $null
try {
    $config = Get-DemoConfig
    Write-Prerequisite 'Demo configuration' 'seven settings supplied' 'explicit tenant/subscription' 'OK'
}
catch {
    $advice = if ((Test-Path -LiteralPath (Join-Path $script:DemoRoot 'config.json')) -or (Test-Path -LiteralPath (Join-Path $script:DemoRoot 'config.psd1'))) {
        'Edit the existing private configuration; do not overwrite its values.'
    } else { 'Copy-Item .\config.example.json .\config.json; notepad .\config.json' }
    Write-Prerequisite 'Demo configuration' $_.Exception.Message 'valid local config' 'FAIL' $advice
}

if ($config -and (Resolve-DemoCommand az)) {
    try {
        Assert-DemoAzureScope $config
        Assert-DemoSavedConfig $config
        $null = Assert-DemoIdentityScope $config -AllowMissing
        Write-Prerequisite 'Azure tenant/subscription' 'configured pair selected' 'resource tenant and active account match' 'OK'
    }
    catch {
        Write-Prerequisite 'Azure tenant/subscription' $_.Exception.Message 'configured pair selected' 'FAIL' (Get-DemoAzureLoginHint $config)
    }
}

if ($config -and (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    $contexts = Read-PrerequisiteCommand kubectl @('config', 'get-contexts', '--output', 'name')
    foreach ($entry in @(@{ Name = 'local'; Context = $config.LocalContext }, @{ Name = 'aks'; Context = $config.AksContext })) {
        $context = $entry.Context
        if (-not $contexts.Success -or $context -cnotin ($contexts.Text -split '\r?\n')) {
            $advice = if ($entry.Name -eq 'local') {
                $providerHint = if ($containerProvider -eq 'Podman') { '$env:KIND_EXPERIMENTAL_PROVIDER = "podman"; ' } else { '' }
                $providerHint + 'kind create cluster --name radius-demo --config .\infra\kind.yaml --wait 120s; use LocalContext=kind-radius-demo'
            } else {
                "$(Get-DemoAzureLoginHint $config)`n" +
                'No AKS yet? Preview: .\scripts\Setup-AzureInfrastructure.ps1 -ApiServerAllowedCidr YOUR_PUBLIC_IPV4/32' + "`n" +
                "Existing AKS? az aks get-credentials --subscription $($config.SubscriptionId) --resource-group YOUR_AKS_GROUP --name YOUR_AKS_NAME; set AksContext to its exact kubeconfig name."
            }
            Write-Prerequisite "$($entry.Name) kube context" 'not in kubeconfig' $context 'FAIL' $advice
            continue
        }
        Write-Prerequisite "$($entry.Name) kube context" $context 'present in kubeconfig' 'OK'
        if (-not $CheckClusters) { continue }
        $server = Read-PrerequisiteCommand kubectl @('--context', $context, '--request-timeout=10s', 'version', '--output', 'json')
        $nodes = Read-PrerequisiteCommand kubectl @('--context', $context, '--request-timeout=10s', 'get', 'nodes', '--output', 'json')
        $controller = Read-PrerequisiteCommand kubectl @('--context', $context, '--request-timeout=10s', '-n', 'radius-system',
            'get', 'deployment', 'dynamic-rp', '--ignore-not-found', '--output', 'json')
        try {
            if (-not $server.Success -or -not $nodes.Success) { throw 'Kubernetes API or node read failed; check connectivity, login, and RBAC.' }
            $serverVersion = ConvertTo-PrerequisiteVersion (($server.Text | ConvertFrom-Json).serverVersion.gitVersion)
            if (-not $serverVersion) { throw 'Kubernetes did not return a server version.' }
            $items = @((($nodes.Text | ConvertFrom-Json).items))
            if ($items.Count -eq 0 -or @($items | Where-Object {
                $_.status.nodeInfo.architecture -cne 'amd64' -or $_.status.nodeInfo.operatingSystem -cne 'linux'
            }).Count -gt 0) { throw 'This demo requires Linux/AMD64 workload nodes.' }
            Write-Prerequisite "$($entry.Name) Kubernetes" "$serverVersion AMD64" 'reachable Linux/AMD64 nodes' 'OK'
            if ($kubectlVersion -and ($kubectlVersion.Major -ne $serverVersion.Major -or [math]::Abs($kubectlVersion.Minor - $serverVersion.Minor) -gt 1)) {
                Write-Prerequisite "$($entry.Name) kubectl skew" "$kubectlVersion / $serverVersion" 'within one server minor' 'FAIL' 'Install a kubectl version within one minor of both cluster servers.'
            }
        }
        catch { Write-Prerequisite "$($entry.Name) Kubernetes" $_.Exception.Message 'reachable Linux/AMD64 nodes' 'FAIL' "kubectl --context `"$context`" get nodes" }
        try {
            if (-not $controller.Success -or [string]::IsNullOrWhiteSpace($controller.Text)) { throw 'Radius dynamic-rp is not readable or not installed.' }
            $rp = $controller.Text | ConvertFrom-Json
            $images = @($rp.spec.template.spec.containers.image)
            $pattern = ':' + [regex]::Escape($requiredRadius) + '(?:@|$)'
            if ($rp.status.readyReplicas -lt 1 -or @($images | Where-Object { $_ -match $pattern }).Count -eq 0) {
                throw "Controller image/version or readiness differs: $($images -join ', ')"
            }
            Write-Prerequisite "$($entry.Name) Radius" $requiredRadius 'ready dynamic-rp at pinned release' 'OK'
        }
        catch { Write-Prerequisite "$($entry.Name) Radius" $_.Exception.Message $requiredRadius 'FAIL' "After selecting the pinned CLI: rad install kubernetes --kubecontext `"$context`" (review an existing installation before updating)." }
    }
}
elseif ($CheckClusters) {
    Write-Prerequisite 'Cluster API checks' 'config/kubectl unavailable' 'configured cluster access' 'SKIP' 'Resolve the blocking configuration/tool issues, then rerun with -CheckClusters.'
}

Write-Host ''
Write-Host 'Suggested local bootstrap, only if this named cluster does not already exist:'
if ($containerProvider -eq 'Podman') { Write-Host '  $env:KIND_EXPERIMENTAL_PROVIDER = "podman"' }
Write-Host '  kind create cluster --name radius-demo --config .\infra\kind.yaml --wait 120s'
Write-Host '  rad install kubernetes --kubecontext kind-radius-demo'
Write-Host '  kubectl --context kind-radius-demo get nodes'
Write-Host "  Use LocalContext=kind-radius-demo in config.json. Install/use Radius $requiredRadius first."
Write-Host ''
Write-Host 'Install commands require WinGet or the reviewed official installer. No suggested command was executed.'
if (-not $CheckClusters) { Write-Host 'Cluster APIs/controller versions were not checked. Rerun with -CheckClusters after configuring access.' }
Write-Host 'The configured tenant/subscription and active Azure account are checked when configuration is valid. Login is never changed automatically.'
Write-Host 'Graph permissions, RBAC, quotas, GitHub/registry login, and confidential-policy generation are not checked here; set them up separately.'
Write-Host "Result: $script:Blockers blocking issue(s), $script:Warnings optional warning(s)."
if ($script:Blockers -gt 0) { exit 1 }
exit 0
