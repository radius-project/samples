#!/usr/bin/env bash
# Install commands are printed as data, not executed.
# shellcheck disable=SC2016
set -uo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/Azure.Scope.sh
source "$ROOT/scripts/Azure.Scope.sh"
# shellcheck source=scripts/Container.Runtime.sh
source "$ROOT/scripts/Container.Runtime.sh"
# shellcheck source=scripts/Recipe.Pins.sh
source "$ROOT/scripts/Recipe.Pins.sh"
OS="$(uname -s)"
CHECK_CLUSTERS=false
FAILURES=0 WARNINGS=0 OUTPUT='' VERSION='' KUBECTL_VERSION=''
CONTAINER_PROVIDER=''
IS_WSL=false
if [[ "$OS" == Linux ]] && grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then IS_WSL=true; fi
case "${1:-}" in
    '') ;;
    --check-clusters) CHECK_CLUSTERS=true ;;
    --help|-h) printf '%s\n' 'Usage: bash scripts/Check-Prerequisites.sh [--check-clusters]' 'Read-only. Reports versions and suggested install commands; never installs or deploys.'; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf '%s\n' 'Too many arguments.' >&2; exit 2; }
case "$OS" in Linux|Darwin) ;; *) printf '%s\n' 'Use Check-Prerequisites.ps1 on Windows, or run this script inside WSL.' >&2; exit 2 ;; esac
[[ -f "$ROOT/radius-version.txt" ]] || { printf '%s\n' 'Missing radius-version.txt.' >&2; exit 2; }
RADIUS_VERSION="$(tr -d '\r\n' < "$ROOT/radius-version.txt")"
[[ "$RADIUS_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf '%s\n' 'Invalid stable release in radius-version.txt.' >&2; exit 2; }
RADIUS_MINOR="${RADIUS_VERSION%.*}"

advice() {
    case "$1" in
        radius)
            printf '       curl -fsSL https://raw.githubusercontent.com/radius-project/radius/v%s/deploy/install.sh -o /tmp/install-radius.sh\n' "$RADIUS_VERSION"
            printf '%s\n' '       # Review the downloaded installer, then run:'
            printf '       bash /tmp/install-radius.sh --version %s --install-dir "$HOME/.local/bin"\n' "$RADIUS_VERSION"
            printf '%s\n' '       export PATH="$HOME/.local/bin:$PATH"'
            ;;
        kind)
            if [[ "$OS" == Darwin ]]; then
                printf '%s\n' '       brew install kind'
            else
                printf '%s\n' \
                    '       case "$(uname -m)" in x86_64) kind_arch=amd64 ;; aarch64|arm64) kind_arch=arm64 ;; *) echo "Unsupported architecture" >&2; exit 1 ;; esac' \
                    '       kind_tmp="$(mktemp -d)"' \
                    '       kind_asset="kind-linux-$kind_arch"' \
                    '       curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/$kind_asset" -o "$kind_tmp/$kind_asset" &&' \
                    '       curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/$kind_asset.sha256sum" -o "$kind_tmp/$kind_asset.sha256sum" &&' \
                    '       (cd "$kind_tmp" && sha256sum --check "$kind_asset.sha256sum") &&' \
                    '       mkdir -p "$HOME/.local/bin" &&' \
                    '       install -m 0755 "$kind_tmp/$kind_asset" "$HOME/.local/bin/kind" &&' \
                    '       rm -f -- "$kind_tmp/$kind_asset" "$kind_tmp/$kind_asset.sha256sum" && rmdir "$kind_tmp"' \
                    '       export PATH="$HOME/.local/bin:$PATH"'
            fi
            ;;
        azure)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install azure-cli'
            else
                printf '%s\n' '       # Ubuntu/Debian/WSL: review the Microsoft installer before execution.' \
                    '       curl -fsSL https://aka.ms/InstallAzureCLIDeb -o /tmp/install-azure-cli.sh' \
                    '       sudo bash /tmp/install-azure-cli.sh'
            fi
            ;;
        bicep)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install azure/bicep/bicep'
            else
                printf '%s\n' '       # After Azure CLI is installed; install its standalone Bicep binary, then expose it on PATH:' \
                    '       az bicep install' \
                    '       export PATH="${AZURE_CONFIG_DIR:-$HOME/.azure}/bin:$PATH"'
            fi
            ;;
        docker)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install --cask docker; open -a Docker'
            elif [[ "$IS_WSL" == true ]]; then
                printf '%s\n' '       # Run on the Windows host in PowerShell:' \
                    '       winget install --exact --id Docker.DockerDesktop' \
                    '       # Start Docker Desktop and enable Settings > Resources > WSL Integration for this distribution.'
            else
                printf '%s\n' '       # Review the Docker Engine convenience installer before execution (demo machines only):' \
                    '       curl -fsSL https://get.docker.com -o /tmp/get-docker.sh' \
                    '       sudo sh /tmp/get-docker.sh' \
                    '       # Configure rootless Docker or approved daemon access; do not run the whole demo as root.'
            fi
            ;;
        podman)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install podman'
            else printf '%s\n' '       sudo apt-get update && sudo apt-get install -y podman'
            fi
            printf '%s\n' '       # Keep your chosen Docker-compatible command available as docker; no link is changed by this checker.'
            ;;
        kubectl)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install kubernetes-cli'
            else printf '%s\n' '       # After Azure CLI is installed; downloads kubectl and kubelogin:' '       sudo az aks install-cli'
            fi
            ;;
        kubelogin)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install Azure/kubelogin/kubelogin'
            else printf '%s\n' '       sudo az aks install-cli'
            fi
            ;;
        gh)
            if [[ "$OS" == Darwin ]]; then printf '%s\n' '       brew install gh'
            else printf '%s\n' '       sudo apt-get update && sudo apt-get install -y gh'
            fi
            ;;
        jq|curl|openssl)
            if [[ "$OS" == Darwin ]]; then printf '       brew install %s\n' "$1"
            else printf '       sudo apt-get update && sudo apt-get install -y %s\n' "$1"
            fi
            ;;
        bash) printf '%s\n' '       # Use Bash 3.2+; on macOS: brew install bash' ;;
        confcom) printf '%s\n' '       az extension add --name confcom --upgrade' ;;
        config) printf '%s\n' '       cp ./config.example.json ./config.json' '       # Fill in seven settings, including TenantId; do not overwrite an existing private config.' ;;
        engine) printf '%s\n' '       # Start the selected Docker engine, then inspect its context/platform:' '       docker context ls' '       docker info' ;;
        podman-engine)
            printf '%s\n' '       # Inspect the selected Podman backend through the existing docker entry point:' \
                '       docker info' '       docker system connection list' \
                '       # For a configured remote machine: docker machine list' \
                '       # Do not recreate machines or install Docker Desktop to hide a connection error.'
            ;;
        local)
            if [[ "$CONTAINER_PROVIDER" == Podman ]]; then printf '%s\n' '       export KIND_EXPERIMENTAL_PROVIDER=podman'; fi
            printf '%s\n' '       kind create cluster --name radius-demo --config ./infra/kind.yaml --wait 120s' '       # Set LocalContext to kind-radius-demo.'
            ;;
        aks)
            local target_tenant target_subscription
            target_tenant="$(jq -er .TenantId "$ROOT/config.json")"
            target_subscription="$(jq -er .SubscriptionId "$ROOT/config.json")"
            printf '       az login --tenant %q\n       az account set --subscription %q\n' "$target_tenant" "$target_subscription"
            printf '%s\n' '       # No AKS yet? Preview the dedicated Azure host:' \
                '       bash ./scripts/Setup-AzureInfrastructure.sh --api-server-cidr YOUR_PUBLIC_IPV4/32' \
                '       # For an existing AKS cluster instead:'
            printf '       az aks get-credentials --subscription %q --resource-group YOUR_AKS_GROUP --name YOUR_AKS_NAME\n' "$target_subscription"
            printf '%s\n' '       kubectl config get-contexts'
            ;;
        pins) printf '%s\n' '       # Check bicepconfig.json and kubernetes-recipes.lock.json against radius-version.txt and the release catalog; recipe tags are not CLI versions.' ;;
    esac
}

report() {
    local status=$1 name=$2 detected=$3 required=$4 hint=${5:-}
    [[ "$status" != FAIL ]] || FAILURES=$((FAILURES + 1))
    [[ "$status" != WARN ]] || WARNINGS=$((WARNINGS + 1))
    printf '[%-4s] %-24s %-18s Required: %s\n' "$status" "$name" "$detected" "$required"
    if [[ -n "$hint" && "$status" != OK ]]; then advice "$hint"; fi
}

capture() {
    if OUTPUT="$("$@" 2>&1)"; then return 0; fi
    return 1
}

numeric_version() {
    if [[ "$1" =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]]; then VERSION="${BASH_REMATCH[1]}"; return 0; fi
    VERSION=''; return 1
}

at_least() {
    local major minor patch other_major other_minor other_patch
    IFS=. read -r major minor patch <<< "$1"
    IFS=. read -r other_major other_minor other_patch <<< "$2"
    patch=${patch:-0}; other_patch=${other_patch:-0}
    (( 10#$major > 10#$other_major ||
       (10#$major == 10#$other_major && 10#$minor > 10#$other_minor) ||
       (10#$major == 10#$other_major && 10#$minor == 10#$other_minor && 10#$patch >= 10#$other_patch) ))
}

failure_detail() {
    local detail
    detail="$(grep -Ei '^(ERROR:|PermissionError:|Error:)' <<< "$OUTPUT" |
        grep -Eiv 'command failed with an unexpected error|traceback:' | sed -n '1p')"
    if [[ -z "$detail" ]]; then detail="$(sed -n '/[^[:space:]]/{p;q;}' <<< "$OUTPUT")"; fi
    printf '       Diagnostic: %.500s\n' "${detail:-The command returned no diagnostic output.}"
}

check_tool() {
    local label=$1 tool=$2 requirement=$3 mode=$4 optional=$5 hint=$6 value status requirement_label
    shift 6
    requirement_label="$requirement"
    [[ "$mode" != minimum ]] || requirement_label=">=$requirement"
    status=FAIL; [[ "$optional" != true ]] || status=WARN
    if ! command -v "$tool" >/dev/null 2>&1; then report "$status" "$label" 'not on PATH' "$requirement_label" "$hint"; return; fi
    if ! capture "$tool" "$@"; then
        if grep -Eiq 'WinError 5|access is denied|access denied|permission denied|PermissionError|UnauthorizedAccess' <<< "$OUTPUT"; then
            report "$status" "$label" 'access denied' "$requirement_label"
            printf '%s\n' '       Have the account/application access to the reported path reviewed and legitimately restored. Do not reinstall or bypass permissions based on this result.'
        elif [[ "$hint" == confcom ]] && grep -Eiq 'extension.*confcom.*not installed|confcom.*extension.*not installed' <<< "$OUTPUT"; then
            report "$status" "$label" 'extension not installed' "$requirement_label" "$hint"
        else
            report "$status" "$label" 'version command failed' "$requirement_label"
            printf '%s\n' '       The executable exists. Inspect the diagnostic in the intended shell/account before reinstalling.'
        fi
        failure_detail
        return
    fi
    value="$OUTPUT"
    case "$tool" in
        rad) value="$(sed -nE 's/.*"release"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<< "$OUTPUT" | sed -n '1p')" ;;
        az)
            if [[ "$hint" == azure ]]; then
                value="$(sed -nE 's/.*"azure-cli"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<< "$OUTPUT" | sed -n '1p')"
            elif [[ "$hint" == confcom ]]; then
                if ! command -v jq >/dev/null 2>&1; then
                    report SKIP "$label" 'jq required to read metadata' "$requirement_label" jq
                    return
                fi
                if ! jq -e 'type == "object" and (.metadata | type == "object") and (.version | type == "string" and length > 0)' <<< "$OUTPUT" >/dev/null; then
                    report "$status" "$label" 'metadata/version unavailable' "$requirement_label"
                    printf '%s\n' '       Azure CLI did not return usable package metadata/version; a zero exit code is not proof of a healthy extension.' \
                        '       In the affected terminal: az extension show --name confcom --output json --debug' \
                        '       Inspect the metadata-loading exception before reinstalling or changing permissions.'
                    return
                fi
                value="$(jq -er .version <<< "$OUTPUT")"
            fi
            ;;
        kubectl) value="$(sed -nE 's/.*"gitVersion"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<< "$OUTPUT" | sed -n '1p')" ;;
    esac
    if ! numeric_version "$value"; then
        report "$status" "$label" 'unrecognized version' "$requirement_label"
        printf '%s\n' '       The executable exists. Inspect its version output before reinstalling.'
        failure_detail
        return
    fi
    if [[ "$tool" == kubectl ]]; then KUBECTL_VERSION="$VERSION"; fi
    if [[ "$mode" == exact && "${value#v}" != "$requirement" ]]; then report "$status" "$label" "$value" "$requirement" "$hint"
    elif [[ "$mode" == minimum ]] && ! at_least "$VERSION" "$requirement"; then report "$status" "$label" "$VERSION" ">=$requirement" "$hint"
    else report OK "$label" "$VERSION" "$requirement_label"
    fi
}

printf 'Read-only prerequisites | %s Bash | Radius %s\n' "$OS" "$RADIUS_VERSION"
printf '%s\n\n' 'Commands below are suggestions only. Nothing is installed, configured, or deployed.'
if numeric_version "$BASH_VERSION" && at_least "$VERSION" '3.2.0'; then report OK Bash "$VERSION" '>=3.2.0'
else report FAIL Bash "$BASH_VERSION" '>=3.2.0' bash
fi
check_tool 'Radius CLI' rad "$RADIUS_VERSION" exact false radius version --cli --output json
check_tool 'Azure CLI' az '2.44.1' minimum false azure version --output json
if command -v az >/dev/null 2>&1; then
    if AZURE_EXTENSION_USE_DYNAMIC_INSTALL=no capture az stack-whatif sub create --help; then
        report OK 'Stack what-if (optional)' 'available' 'only for --use-deployment-stack'
    else
        report WARN 'Stack what-if (optional)' 'unavailable/unreadable' 'only for --use-deployment-stack'
        printf '%s\n' '       Inspect: az stack-whatif sub create --help. Upgrade Azure CLI if unknown; investigate access errors instead of reinstalling. Default bootstrap does not need stacks.'
        failure_detail
    fi
else report SKIP 'Stack what-if (optional)' 'Azure CLI missing' 'only for --use-deployment-stack'
fi
check_tool 'Bicep (AKS bootstrap)' bicep 'present; version reported' present true bicep --version
if ! command -v docker >/dev/null 2>&1; then
    report FAIL 'Container CLI (docker)' 'not on PATH' 'Docker or Podman'
    printf '%s\n' '       Expose your chosen Docker-compatible CLI as docker. The checker does not create or replace links.'
    printf '%s\n' '       # Choose ONE runtime if none is installed. Docker option:'
    advice docker
    printf '%s\n' '       # Or the Podman option:'
    advice podman
elif ! capture docker version --help; then
    report FAIL 'Container CLI (docker)' 'provider probe failed' 'Docker or Podman'
    failure_detail
elif ! CONTAINER_PROVIDER="$(container_provider_from_help "$OUTPUT")"; then
    report FAIL 'Container CLI (docker)' 'unrecognized runtime' 'Docker or Podman'
else
    container_hint=docker; [[ "$CONTAINER_PROVIDER" != Podman ]] || container_hint=podman
    check_tool "$CONTAINER_PROVIDER CLI (docker)" docker "$(container_minimum_version "$CONTAINER_PROVIDER")" minimum false "$container_hint" --version
fi
check_tool kubectl kubectl 'present; version reported' present false kubectl version --client --output json
check_tool 'kind (cluster creation)' kind '0.33.0' minimum true kind version
check_tool 'GitHub CLI' gh '2.0.0' minimum false gh --version
check_tool 'kubelogin (AKS Entra)' kubelogin 'present; version reported' present true kubelogin --version
check_tool jq jq '1.6.0' minimum false jq --version
check_tool curl curl 'present; version reported' present false curl --version
check_tool 'OpenSSL / LibreSSL' openssl 'present; version reported' present false openssl version
if [[ "$OS" == Darwin ]]; then
    report SKIP 'confcom on macOS' 'bundle import path' 'generate on Linux/Windows'
    printf '%s\n' '       bash scripts/00-prepare.sh --policy-bundle ./platform/generated/policy-bundle.json'
elif command -v az >/dev/null 2>&1; then
    check_tool 'Azure confcom extension' az '0.30.0' minimum false confcom extension show --name confcom --output json
else report SKIP 'Azure confcom extension' 'Azure CLI missing' '>=0.30.0' confcom
fi

if [[ -n "$CONTAINER_PROVIDER" ]] && command -v jq >/dev/null 2>&1; then
    container_minimum="$(container_minimum_version "$CONTAINER_PROVIDER")"
    engine_hint=engine; [[ "$CONTAINER_PROVIDER" != Podman ]] || engine_hint=podman-engine
    # Runtime warnings belong on stderr, not in the JSON document.
    if OUTPUT="$(docker info --format "$(container_info_format "$CONTAINER_PROVIDER")")"; then
        if ! engine_details="$(container_engine_from_info "$CONTAINER_PROVIDER" "$OUTPUT")"; then
            report FAIL "$CONTAINER_PROVIDER engine" 'invalid metadata' 'valid server version/platform' "$engine_hint"
        else
            server_version="$(jq -er .version <<< "$engine_details")"
            server_os="$(jq -er .os <<< "$engine_details")"
            server_arch="$(jq -er .architecture <<< "$engine_details")"
            if numeric_version "$server_version" && at_least "$VERSION" "$container_minimum" &&
                [[ "$server_os" == linux && "$server_arch" == amd64 ]]; then
                report OK "$CONTAINER_PROVIDER engine" "$server_version linux/amd64" ">=$container_minimum; Linux/AMD64"
            else
                status=FAIL; [[ "$OS" != Darwin ]] || status=WARN
                report "$status" "$CONTAINER_PROVIDER engine" "$server_version $server_os/$server_arch" ">=$container_minimum; Linux/AMD64" "$engine_hint"
                printf '%s\n' '       An ARM64 workstation may control an existing AMD64 development cluster; do not change image digests.'
            fi
        fi
    else
        status=FAIL; [[ "$OS" != Darwin ]] || status=WARN
        report "$status" "$CONTAINER_PROVIDER engine" 'not reachable' 'running engine for local kind' "$engine_hint"
        if [[ -n "$OUTPUT" ]]; then failure_detail; fi
    fi
elif [[ -n "$CONTAINER_PROVIDER" ]]; then report SKIP "$CONTAINER_PROVIDER engine" 'jq required to read metadata' 'Linux/AMD64' jq
else report SKIP 'Container engine' 'CLI not identified' 'Linux/AMD64'
fi

if command -v jq >/dev/null 2>&1; then
    pins_ok=true
    if ! jq -e --arg alias "br:biceptypes.azurecr.io/radius:$RADIUS_MINOR" '.extensions.radius == $alias' "$ROOT/bicepconfig.json" >/dev/null; then pins_ok=false; fi
    if ! recipe_commit="$(kubernetes_recipe_commit "$ROOT" "$RADIUS_VERSION")"; then pins_ok=false; fi
    if [[ "$pins_ok" == true ]]; then report OK 'Bicep/recipe pins' "$RADIUS_VERSION / ${recipe_commit:0:7}" 'CLI/type pin and recipe lock'
    else report FAIL 'Bicep/recipe pins' inconsistent 'CLI/type pin and recipe lock' pins
    fi
fi

CONFIG_READY=false
if [[ ! -f "$ROOT/config.json" ]]; then report FAIL 'Demo configuration' 'config.json missing' 'seven configured settings' config
elif [[ -e "$ROOT/config.psd1" ]]; then
    report FAIL 'Demo configuration' 'two active config files' 'only config.json for Bash'
    printf '%s\n' '       Move the legacy config.psd1 out of the checkout after copying its values.'
elif ! command -v jq >/dev/null 2>&1; then report SKIP 'Demo configuration' 'jq missing' 'JSON validation' jq
elif jq -e '
    (keys | sort) == (["TenantId","SubscriptionId","Location","LocalContext","AksContext","Prefix","RecipeRepository"] | sort)
    and all(.[]; type == "string" and length > 0 and (contains("REPLACE_") | not))
    and (.TenantId | test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))
    and (.SubscriptionId | test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))
    and (.Prefix | test("^[a-z][a-z0-9-]{1,19}$"))
    and (.RecipeRepository | test("^ghcr\\.io/[a-z0-9-]+/[a-z0-9._/-]+$"))
    and (.LocalContext != .AksContext)' "$ROOT/config.json" >/dev/null; then
    CONFIG_READY=true
    report OK 'Demo configuration' 'seven settings supplied' 'explicit tenant/subscription'
else
    report FAIL 'Demo configuration' 'invalid/incomplete values' 'valid local config'
    printf '%s\n' '       Edit the existing config.json; do not overwrite it with the example.'
fi

if [[ "$CONFIG_READY" == true ]] && command -v az >/dev/null 2>&1; then
    tenant="$(jq -er .TenantId "$ROOT/config.json")"
    subscription="$(jq -er .SubscriptionId "$ROOT/config.json")"
    if check_azure_scope "$tenant" "$subscription"; then
        report OK 'Azure tenant/subscription' 'configured pair selected' 'resource tenant and active account match'
    else
        report FAIL 'Azure tenant/subscription' 'scope verification failed' 'configured pair selected'
        printf '       az login --tenant %q\n       az account set --subscription %q\n' "$tenant" "$subscription"
    fi
fi

if [[ "$CONFIG_READY" == true ]] && command -v kubectl >/dev/null 2>&1; then
    if capture kubectl config get-contexts --output name; then contexts="$OUTPUT"; else contexts=''; fi
    for target in local aks; do
        key=LocalContext; [[ "$target" != aks ]] || key=AksContext
        context="$(jq -er --arg key "$key" '.[$key]' "$ROOT/config.json")"
        if ! grep -Fxq -- "$context" <<< "$contexts"; then report FAIL "$target kube context" 'not in kubeconfig' "$context" "$target"; continue; fi
        report OK "$target kube context" "$context" 'present in kubeconfig'
        [[ "$CHECK_CLUSTERS" == true ]] || continue
        server_version=''
        if capture kubectl --context "$context" --request-timeout=10s version --output json; then
            if value="$(jq -er .serverVersion.gitVersion <<< "$OUTPUT")" && numeric_version "$value"; then
                server_version="$VERSION"
                report OK "$target Kubernetes" "$server_version" 'API reachable'
            else report FAIL "$target Kubernetes" 'server version unreadable' 'API reachable'
            fi
        else report FAIL "$target Kubernetes" 'API/authentication failed' 'API reachable'
        fi
        if [[ -n "$server_version" && -n "$KUBECTL_VERSION" ]]; then
            IFS=. read -r client_major client_minor _ <<< "$KUBECTL_VERSION"
            IFS=. read -r server_major server_minor _ <<< "$server_version"
            delta=$((10#$client_minor - 10#$server_minor)); [[ "$delta" -ge 0 ]] || delta=$((-delta))
            if [[ "$client_major" != "$server_major" || "$delta" -gt 1 ]]; then
                report FAIL "$target kubectl skew" "$KUBECTL_VERSION / $server_version" 'within one server minor'
                printf '%s\n' '       Install a kubectl client within one minor of both cluster servers.'
            fi
        fi
        if capture kubectl --context "$context" --request-timeout=10s get nodes --output json &&
            jq -e '.items | length > 0 and all(.[]; .status.nodeInfo.architecture == "amd64" and .status.nodeInfo.operatingSystem == "linux")' <<< "$OUTPUT" >/dev/null; then
            report OK "$target nodes" 'Linux/AMD64' 'same locked image architecture'
        else report FAIL "$target nodes" 'unreadable/incompatible' 'Linux/AMD64'
        fi
        if capture kubectl --context "$context" --request-timeout=10s -n radius-system get deployment dynamic-rp --ignore-not-found --output json &&
            [[ -n "$OUTPUT" ]] && jq -e --arg version "$RADIUS_VERSION" '.status.readyReplicas >= 1 and
              any(.spec.template.spec.containers[]; .image | endswith(":" + $version) or contains(":" + $version + "@"))' <<< "$OUTPUT" >/dev/null; then
            report OK "$target Radius" "$RADIUS_VERSION" 'ready dynamic-rp at pinned release'
        else
            if ! images="$(jq -r '[.spec.template.spec.containers[]?.image] | join(", ")' <<< "$OUTPUT" 2>/dev/null)"; then images=''; fi
            report FAIL "$target Radius" "${images:-not installed/readable}" "$RADIUS_VERSION"
            printf '       # With the pinned CLI; review an existing installation before updating:\n       rad install kubernetes --kubecontext %q\n' "$context"
        fi
    done
elif [[ "$CHECK_CLUSTERS" == true ]]; then
    report SKIP 'Cluster API checks' 'config/kubectl unavailable' 'configured cluster access'
    printf '%s\n' '       Resolve the blocking configuration/tool issues, then rerun with --check-clusters.'
fi

printf '\n%s\n' 'Suggested local bootstrap, only if this named cluster does not already exist:'
if [[ "$CONTAINER_PROVIDER" == Podman ]]; then printf '%s\n' '  export KIND_EXPERIMENTAL_PROVIDER=podman'; fi
printf '%s\n' \
    '  kind create cluster --name radius-demo --config ./infra/kind.yaml --wait 120s' \
    '  rad install kubernetes --kubecontext kind-radius-demo' \
    '  kubectl --context kind-radius-demo get nodes' \
    '  Use LocalContext=kind-radius-demo in config.json.'
printf '  Install/use Radius %s first.\n\n' "$RADIUS_VERSION"
printf '%s\n' 'No suggested command was executed. Homebrew must already be installed for brew commands; apt examples target Ubuntu/Debian.'
if [[ "$CHECK_CLUSTERS" != true ]]; then printf '%s\n' 'Cluster APIs/controller versions were not checked. Rerun with --check-clusters after configuring access.'; fi
printf '%s\n' 'The configured tenant/subscription and active Azure account are checked when configuration is valid. Login is never changed automatically.' \
    'Graph permissions, RBAC, quotas, GitHub/registry login, and confidential-policy generation are not checked here; set them up separately.'
printf 'Result: %s blocking issue(s), %s optional warning(s).\n' "$FAILURES" "$WARNINGS"
[[ "$FAILURES" -eq 0 ]]
