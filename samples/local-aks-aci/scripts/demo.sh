#!/usr/bin/env bash
# jq programs, including those passed through json_write, use jq variables rather than shell expansion.
# shellcheck disable=SC2016
set -Eeuo pipefail
umask 077
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OS="$(uname -s)"
PARAM_FILE='' JSON_TMP='' SECRET_TMP='' POLL_URL='' POLL_SID=''
CONFIG='' STATE='' TARGET='' WORKSPACE='' GROUP='' CONTEXT='' AZURE_GROUP=''
YES=false WHAT_IF=false PLAN=false POLICY_BUNDLE='' LOCATION='eastus2'
TARGET_ARG='' ENDPOINT_URL='' PUBLISHED_SOURCE=''
VERIFIED_AZURE_SCOPE=''
# shellcheck source=scripts/Azure.Scope.sh
source "$ROOT/scripts/Azure.Scope.sh"
# shellcheck source=scripts/Container.Runtime.sh
source "$ROOT/scripts/Container.Runtime.sh"
# shellcheck source=scripts/Recipe.Pins.sh
source "$ROOT/scripts/Recipe.Pins.sh"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || die "Install $1 in this Linux/WSL/macOS environment first."; }
hash_file() { openssl dgst -sha256 -r "$1" | awk '{print toupper($1)}'; }
stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
required_radius() {
    [[ -f "$ROOT/radius-version.txt" ]] || die 'Restore the missing radius-version.txt release pin.'
    local version
    version="$(tr -d '\r\n' < "$ROOT/radius-version.txt")"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'radius-version.txt must contain one stable release.'
    printf '%s\n' "$version"
}

cleanup_temporary_files() {
    local status=$?
    trap - EXIT ERR
    if [[ -n "$POLL_SID" ]]; then
        if ! curl -fsS --max-time 2 -H 'Content-Type: text/plain;charset=UTF-8' \
            --data-binary '1' "$POLL_URL&sid=$POLL_SID" >/dev/null; then
            printf '%s\n' 'Warning: the polling session could not be closed cleanly.' >&2
        fi
    fi
    local file
    for file in "$PARAM_FILE" "$JSON_TMP" "$SECRET_TMP"; do
        if [[ -n "$file" ]] && ! rm -f -- "$file"; then
            printf 'Could not remove private temporary file: %s\n' "$file" >&2
            status=1
        fi
    done
    exit "$status"
}
trap cleanup_temporary_files EXIT
trap 'status=$?; printf "Command failed (exit %s). Fix the cause before you continue.\n" "$status" >&2; exit "$status"' ERR

json_write() {
    local destination=$1
    shift
    [[ ! -L "$destination" ]] || die "Refusing to replace a symlink: $destination"
    JSON_TMP="$(mktemp "${destination}.tmp.XXXXXX")"
    jq "$@" > "$JSON_TMP"
    chmod 600 "$JSON_TMP"
    mv -f -- "$JSON_TMP" "$destination"
    JSON_TMP=''
}

load_config() {
    [[ -f "$ROOT/config.json" ]] || die 'Copy config.example.json to config.json and fill in its seven settings, including TenantId.'
    [[ ! -e "$ROOT/config.psd1" ]] || die 'Keep only config.json active for Bash; move the legacy config.psd1 out of the checkout.'
    if ! jq -e '
      (keys | sort) == (["TenantId","SubscriptionId","Location","LocalContext","AksContext","Prefix","RecipeRepository"] | sort)
      and all(.[]; type == "string" and length > 0 and (contains("REPLACE_") | not))
      and (.TenantId | test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))
      and (.SubscriptionId | test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))
      and (.Prefix | test("^[a-z][a-z0-9-]{1,19}$"))
      and (.RecipeRepository | test("^ghcr\\.io/[a-z0-9-]+/[a-z0-9._/-]+$"))
      and (.LocalContext != .AksContext)
    ' "$ROOT/config.json" >/dev/null; then
        die 'Invalid config.json; use the seven-setting example with explicit TenantId.'
    fi
    CONFIG="$(jq -c . "$ROOT/config.json")"
}
cfg() { jq -er --arg key "$1" '.[$key]' <<< "$CONFIG"; }
assert_azure_context() {
    check_azure_scope "$(cfg TenantId)" "$(cfg SubscriptionId)" || die 'Azure tenant/subscription verification failed. No scope switch was performed.'
    VERIFIED_AZURE_SCOPE="$(cfg TenantId):$(cfg SubscriptionId)"
}
azcmd() {
    if [[ "$VERIFIED_AZURE_SCOPE" != "$(cfg TenantId):$(cfg SubscriptionId)" || "$1" == ad || "$1" == role ]]; then
        assert_azure_context
    fi
    if [[ "$1" == ad ]]; then
        command az "$@"
    else
        command az "$@" --subscription "$(cfg SubscriptionId)"
    fi
}
radcmd() { command rad "$@" --config "$STATE/rad.yaml"; }

radius_credential_json() {
    local operation=$1 workspace=$2 text first_line banner
    local arguments=(credential "$operation")
    case "$operation" in
        list) banner='^Listing credentials for all cloud providers for Radius installation "([^"\\]|\\.)*"\.\.\.$' ;;
        show)
            arguments+=(azure)
            banner='^Showing credential for cloud provider "azure" for Radius installation "([^"\\]|\\.)*"\.\.\.$'
            ;;
        *) printf 'Unsupported credential operation: %s\n' "$operation" >&2; return 1 ;;
    esac
    text="$(radcmd "${arguments[@]}" --workspace "$workspace" --output json)" || return
    # Radius 0.62 writes this status line to the same stream as its JSON result.
    first_line="${text%%$'\n'*}"; first_line="${first_line%$'\r'}"
    if [[ "$first_line" =~ $banner ]]; then
        printf '%s\n' "$first_line" >&2
        [[ "$text" == *$'\n'* ]] || { printf 'Radius credential %s returned a status line without JSON.\n' "$operation" >&2; return 1; }
        text="${text#*$'\n'}"
    fi
    jq -cse --arg operation "$operation" '
        if length != 1 then error("Expected one Radius credential JSON result") else .[0] end |
        if $operation == "list" then
            if type == "array" and all(.[]; type == "object" and
                (.Name | type == "string" and test("\\S")) and (.Enabled | type == "boolean"))
            then . else error("Radius credential list returned invalid provider metadata") end
        else
            if type == "object" then . else error("Radius credential show must return a JSON object") end
        end
    ' <<< "$text"
}

select_target() {
    TARGET=$1
    local prefix
    prefix="$(cfg Prefix)"
    GROUP="$prefix-$TARGET"
    case "$TARGET" in
        local) WORKSPACE="$prefix-local"; CONTEXT="$(cfg LocalContext)"; AZURE_GROUP='' ;;
        aks) WORKSPACE="$prefix-azure"; CONTEXT="$(cfg AksContext)"; AZURE_GROUP="$prefix-aks-data" ;;
        aci) WORKSPACE="$prefix-azure"; CONTEXT="$(cfg AksContext)"; AZURE_GROUP="$prefix-aci" ;;
        *) die 'Target must be local, aks, or aci.' ;;
    esac
}

initialize_state() {
    [[ ! -L "$STATE" ]] || die 'The private state directory must not be a symlink.'
    case "$STATE" in /mnt/[a-zA-Z]/*) die 'Keep XDG_STATE_HOME on the native Linux filesystem, not a Windows drive mount.' ;; esac
    mkdir -p -- "$STATE"
    local owner mode
    if [[ "$OS" == Darwin ]]; then owner="$(stat -f '%u' "$STATE")"; else owner="$(stat -c '%u' "$STATE")"; fi
    [[ "$owner" == "$(id -u)" ]] || die "You do not own $STATE."
    chmod 700 "$STATE"
    if [[ "$OS" == Darwin ]]; then mode="$(stat -f '%Lp' "$STATE")"; else mode="$(stat -c '%a' "$STATE")"; fi
    [[ "$mode" == 700 ]] || die "Cannot protect $STATE with mode 0700."
    case "$(cd -- "$STATE" && pwd -P)" in /mnt/[a-zA-Z]/*) die 'Private state resolves to a Windows drive mount.' ;; esac
    if [[ ! -f "$STATE/owner-id.json" ]]; then
        local random owner_id
        random="$(openssl rand -hex 16)"
        owner_id="${random:0:8}-${random:8:4}-${random:12:4}-${random:16:4}-${random:20:12}"
        json_write "$STATE/owner-id.json" -n --arg id "$owner_id" '{id:$id}'
    fi
}
owner_id() { jq -er '.id | select(type == "string" and length > 0)' "$STATE/owner-id.json"; }

assert_identity_scope() {
    local mode=${1:-required} subscription
    if [[ ! -f "$STATE/identity.json" ]]; then
        [[ "$mode" == optional && ! -f "$STATE/azure-credential.json" ]] \
            || die 'Saved credentials have no verifiable tenant binding. Preserve state and resolve the original tenant before reuse/cleanup.'
        return
    fi
    jq -e --arg tenant "$(cfg TenantId)" \
        '(.tenantId | ascii_downcase) == ($tenant | ascii_downcase) and
         (.clientId | type == "string" and test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$"))' \
        "$STATE/identity.json" >/dev/null || die 'Saved identity belongs to another tenant or has no valid tenant/client binding.'
    [[ "$(jq -er .roleName "$STATE/identity.json")" == "Radius-Demo-ACI-$(owner_id)" ]] || die 'Saved identity ownership differs from this demo state.'
    subscription="$(jq -r '.subscriptionId // empty' "$STATE/identity.json")"
    if [[ -z "$subscription" ]]; then
        # Older complete runs saved tenantId on the identity and SubscriptionId in setup-config.
        subscription="$(jq -er .SubscriptionId "$STATE/setup-config.json")"
    fi
    jq -en --arg saved "$subscription" --arg configured "$(cfg SubscriptionId)" \
        '($saved | ascii_downcase) == ($configured | ascii_downcase)' >/dev/null \
        || die 'Saved identity belongs to another subscription. Restore the original configuration.'
    jq --arg subscription "$subscription" '.subscriptionId = $subscription' "$STATE/identity.json"
}

assert_saved_config() {
    [[ -f "$STATE/setup-config.json" ]] || return 0
    local saved identity
    saved="$(cat "$STATE/setup-config.json")"
    if ! jq -e 'has("TenantId")' <<< "$saved" >/dev/null; then
        identity="$(assert_identity_scope)"
        saved="$(jq --arg tenant "$(jq -er .tenantId <<< "$identity")" '.TenantId = $tenant' <<< "$saved")"
    fi
    jq -e --argjson configured "$CONFIG" '
        def normalized: .TenantId |= ascii_downcase | .SubscriptionId |= ascii_downcase;
        normalized == ($configured | normalized)' <<< "$saved" >/dev/null \
        || die 'Saved setup differs. Restore its original tenant/configuration or use a separate checkout and Radius control plane.'
}

assert_radius_credential() {
    local mode=${1:-required} providers count identity registered workspace
    workspace="$(cfg Prefix)-azure"
    providers="$(radius_credential_json list "$workspace")" || return
    count="$(jq -er '[.[] | select(.Name == "azure" and .Enabled == true)] | length' <<< "$providers")"
    if [[ "$count" == 0 ]]; then
        [[ "$mode" == allow-missing ]] || die 'The selected Radius control plane has no Azure credential. Complete preparation first.'
        return
    fi
    [[ "$count" == 1 ]] || die 'The Radius Azure credential selection is ambiguous.'
    identity="$(assert_identity_scope optional)"
    [[ -n "$identity" ]] || die "Radius still has an Azure credential in workspace $workspace, but this checkout has no saved identity ownership record. An older cleanup may have left that registration behind. Verify and unregister only the stale demo credential before preparing again; an unverified credential will not be overwritten."
    registered="$(radius_credential_json show "$workspace")" || return
    jq -e --arg tenant "$(cfg TenantId)" --arg client "$(jq -er .clientId <<< "$identity")" '
        .AzureCredentials.Kind == "ServicePrincipal" and
        (.AzureCredentials.ServicePrincipal.TenantID | ascii_downcase) == ($tenant | ascii_downcase) and
        (.AzureCredentials.ServicePrincipal.ClientID | ascii_downcase) == ($client | ascii_downcase)' \
        <<< "$registered" >/dev/null \
        || die 'This Radius control plane belongs to another identity/tenant. Use a dedicated control plane; its credential will not be overwritten.'
}

remove_radius_credential() {
    local workspace providers count
    workspace="$(cfg Prefix)-azure"
    providers="$(radius_credential_json list "$workspace")" || return
    count="$(jq -er '[.[] | select(.Name == "azure" and .Enabled == true)] | length' <<< "$providers")"
    [[ "$count" != 0 ]] || return 0
    assert_radius_credential
    radcmd credential unregister azure --workspace "$workspace"
    providers="$(radius_credential_json list "$workspace")" || return
    jq -e '[.[] | select(.Name == "azure" and .Enabled == true)] | length == 0' <<< "$providers" >/dev/null \
        || die 'Radius still reports an Azure credential after unregistering it. Identity ownership records and credential backups were retained.'
}

source_hashes() {
    local kind=${1:-all} result='{}' file digest
    local files=('app.bicep' 'images.lock.json' 'platform/vote-policy-template.json' 'platform/aci-containers.bicep')
    if [[ "$kind" == all ]]; then files+=('bicepconfig.json' 'radius-version.txt' 'kubernetes-recipes.lock.json' 'config.json' 'platform/local.bicep' 'platform/cloud.bicep' 'platform/kubernetes-containers.bicep'); fi
    for file in "${files[@]}"; do
        digest="$(hash_file "$ROOT/$file")"
        result="$(jq -cn --argjson current "$result" --arg file "$file" --arg hash "$digest" '$current + {($file):$hash}')"
    done
    printf '%s\n' "$result"
}

assert_snapshot() {
    local file=$1 key=$2 kind=${3:-all} current saved_at
    current="$(source_hashes "$kind")"
    if ! jq -e --arg key "$key" --argjson current "$current" '.[$key] == $current' "$file" >/dev/null; then
        saved_at="$(jq -r '.preparedAt // .validatedAt // "unknown"' "$file")"
        die "Frozen inputs changed or are incomplete. Snapshot: $file; saved at $saved_at. Regenerate the policy if needed and let 00-prepare finish without editing inputs. A failed, cancelled, or preview-only preparation does not refresh the saved baseline."
    fi
}
baseline() {
    [[ -f "$STATE/baseline.json" ]] || die 'Run bash scripts/00-prepare.sh on this host first.'
    assert_snapshot "$STATE/baseline.json" hashes
}

ensure_password() {
    local name=$1
    if [[ ! -f "$STATE/$name.password.json" ]]; then
        SECRET_TMP="$(mktemp "$STATE/password.XXXXXX")"
        printf 'Rd!%sa' "$(openssl rand -hex 24)" > "$SECRET_TMP"
        json_write "$STATE/$name.password.json" -n --rawfile password "$SECRET_TMP" '{password:$password}'
        rm -f -- "$SECRET_TMP"
        SECRET_TMP=''
    fi
    jq -e '.password | type == "string" and length > 0' "$STATE/$name.password.json" >/dev/null
}

registry_get() {
    local repository=$1 reference=$2 destination=$3 token
    token="$(curl -fsS --connect-timeout 10 --max-time 60 --get \
        --data-urlencode "scope=repository:$repository:pull" https://ghcr.io/token |
        jq -er '.token | select(type == "string" and length > 0)')" || return 1
    curl -fsSL --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 60 \
        -H "Authorization: Bearer $token" \
        -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
        "https://ghcr.io/v2/$repository/$reference" -o "$destination" || return 1
}

check_recipes() (
    local commit name temporary
    commit="$(kubernetes_recipe_commit "$ROOT" "$(required_radius)")" || return
    temporary="$(mktemp -d "${TMPDIR:-/tmp}/radius-demo-recipes.XXXXXX")"
    trap 'rm -f -- "$temporary/recipe.json"; rmdir -- "$temporary"' EXIT
    for name in containers postgresqldatabases; do
        registry_get "radius-project/kube-recipes/$name" "manifests/$commit" "$temporary/recipe.json" \
            || die "Cannot read pinned Kubernetes recipe $name:$commit."
        jq -e '.config.mediaType == "application/vnd.ms.bicep.module.config.v1+json" and
            ([.layers[] | select(.mediaType == "application/vnd.ms.bicep.module.layer.v1+json")] | length == 1)' \
            "$temporary/recipe.json" >/dev/null || die "Pinned Kubernetes recipe $name is not a Bicep module."
        info "Public Bicep recipe verified: $name:$commit"
    done
    [[ "$(grep -Eo 'kube-recipes/containers:[a-f0-9]+' "$ROOT/platform/kubernetes-containers.bicep")" == "kube-recipes/containers:$commit" ]] \
        || die "platform/kubernetes-containers.bicep must wrap kube-recipes/containers:$commit from kubernetes-recipes.lock.json."
)

check_images() (
    local temporary name image repository digest config_digest actual
    temporary="$(mktemp -d "${TMPDIR:-/tmp}/radius-demo-images.XXXXXX")"
    trap 'rm -f -- "$temporary/manifest.json" "$temporary/config.json"; rmdir -- "$temporary"' EXIT
    jq -e '.platform == "linux/amd64" and (.images | keys | sort) == ["redis","result","vote","worker"]' \
        "$ROOT/images.lock.json" >/dev/null || die 'Expected four locked Linux/AMD64 images.'
    for name in redis vote worker result; do
        image="$(jq -er --arg name "$name" '.images[$name]' "$ROOT/images.lock.json")"
        [[ "$image" =~ ^ghcr\.io/[^@]+@sha256:[a-f0-9]{64}$ ]] || die "$name is not digest-pinned."
        repository="${image#ghcr.io/}"; repository="${repository%@*}"; digest="${image##*@}"
        registry_get "$repository" "manifests/$digest" "$temporary/manifest.json"
        actual="$(hash_file "$temporary/manifest.json" | tr '[:upper:]' '[:lower:]')"
        [[ "sha256:$actual" == "$digest" ]] || die "Registry digest mismatch for $name."
        config_digest="$(jq -er '.config.digest' "$temporary/manifest.json")"
        registry_get "$repository" "blobs/$config_digest" "$temporary/config.json"
        jq -e '.os == "linux" and .architecture == "amd64"' "$temporary/config.json" >/dev/null \
            || die "$name is not an AMD64 Linux child manifest."
        info "Public, linux/amd64, digest verified: $name"
    done
)

decode_policy() {
    local encoded_file=$1 decoded_file=$2 encoded
    encoded="$(tr -d '\r\n' < "$encoded_file")"
    [[ -n "$encoded" && "$encoded" =~ ^([A-Za-z0-9+/]{4})*([A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$ ]] \
        || die 'The policy is not valid Base64.'
    printf '%s' "$encoded" | openssl base64 -d -A > "$decoded_file"
    [[ "$(wc -c < "$decoded_file")" -ge 100 ]] || die 'The policy is unexpectedly short.'
    grep -Eq '^[[:space:]]*package[[:space:]]+policy([[:space:]]|$)' "$decoded_file" || die 'Expected a generated Rego policy.'
    if grep -Eiq '["'"'"']?allow_all["'"'"']?[[:space:]]*(:=|=|:)[[:space:]]*true' "$decoded_file"; then
        die 'An allow-all policy is not acceptable.'
    fi
}

import_bundle() {
    local bundle=$1 location=$2 expected name image
    jq -e --arg location "$location" \
        '.schemaVersion == 1 and .location == $location and .generator == "az confcom acipolicygen --diff"' \
        "$bundle" >/dev/null || die 'Policy bundle version, location, or validation record differs.'
    assert_snapshot "$bundle" sourceHashes policy
    mkdir -p -- "$ROOT/platform/generated"
    jq -er '.policy' "$bundle" > "$STATE/policy-import.b64"
    decode_policy "$STATE/policy-import.b64" "$STATE/policy-import.rego"
    expected="$(jq -er '.policyHash' "$bundle")"
    [[ "$(hash_file "$STATE/policy-import.rego")" == "$expected" ]] || die 'Policy bundle hash mismatch.'
    for name in redis vote worker; do
        image="$(jq -er --arg name "$name" '.images[$name]' "$ROOT/images.lock.json")"
        grep -Fq -- "$image" "$STATE/policy-import.rego" || die "The policy does not identify the locked $name image."
    done
    tr -d '\r\n' < "$STATE/policy-import.b64" > "$ROOT/platform/generated/vote-ccepolicy.b64"
    cp -- "$STATE/policy-import.rego" "$ROOT/platform/generated/vote-policy.rego"
    json_write "$ROOT/platform/generated/policy-bundle.json" . "$bundle"
    rm -f -- "$STATE/policy-import.b64" "$STATE/policy-import.rego"
}

assert_policy_generator() {
    [[ "$OS" == Linux ]] || die 'Generate the policy on Linux/WSL or with Generate-Policy.ps1 on Windows; macOS imports a bundle.'
    need docker; need az
    local engine version docker_host
    engine="$(read_container_engine)"
    jq -e '.os == "linux" and .architecture == "amd64"' <<< "$engine" >/dev/null \
        || die 'Policy generation needs a Linux/AMD64 container engine; inspect docker info for the selected runtime.'
    # confcom reaches the engine through the Docker API (DOCKER_HOST or the default socket), not the docker CLI.
    docker_host=${DOCKER_HOST:-unix:///var/run/docker.sock}
    if [[ "$docker_host" == unix://* && ! -S "${docker_host#unix://}" ]]; then
        if [[ "$(jq -r .provider <<< "$engine")" == Podman ]]; then
            die "confcom needs the Docker API at $docker_host, which is not available. Start Podman's API socket (for example: systemctl --user enable --now podman.socket) and set DOCKER_HOST=unix://${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/podman/podman.sock; or rerun with --policy-bundle ./platform/generated/policy-bundle.json."
        fi
        die "confcom needs the Docker API at $docker_host, which is not available. Start the Docker engine, then rerun; or rerun with --policy-bundle ./platform/generated/policy-bundle.json."
    fi
    # A damaged extension can still exit 0 here, without a version; acipolicygen then fails to load it.
    version="$(az extension show --name confcom --query version -o tsv || true)"
    [[ "$version" =~ ^[0-9]+(\.[0-9]+)+ ]] \
        || die "Azure CLI cannot load the confcom extension here, so it cannot generate the policy. Rerun with --policy-bundle ./platform/generated/policy-bundle.json, or repair the extension; 'az extension show --name confcom --output json --debug' shows the cause."
}

generate_policy() {
    assert_policy_generator
    local sources input
    sources="$(source_hashes policy)"
    input="$STATE/vote-policy-input.json"
    json_write "$input" --arg location "$LOCATION" --slurpfile lock "$ROOT/images.lock.json" \
        '.resources[0].location = $location |
         .resources[0].properties.containers |= map(.properties.image = $lock[0].images[.name])' \
        "$ROOT/platform/vote-policy-template.json"
    info 'Generating and checking the enforcement policy for the locked images.'
    az confcom acipolicygen --template-file "$input" --approve-wildcards >/dev/null
    az confcom acipolicygen --template-file "$input" --diff --approve-wildcards >/dev/null
    jq -er '.resources[0].properties.confidentialComputeProperties.ccePolicy' "$input" > "$STATE/policy-build.b64"
    decode_policy "$STATE/policy-build.b64" "$STATE/policy-build.rego"
    json_write "$STATE/policy-bundle.json" -n --slurpfile input "$input" \
        --argjson hashes "$sources" --arg location "$LOCATION" --arg hash "$(hash_file "$STATE/policy-build.rego")" --arg time "$(stamp)" \
        '{schemaVersion:1, location:$location, generator:"az confcom acipolicygen --diff",
          sourceHashes:$hashes, policy:$input[0].resources[0].properties.confidentialComputeProperties.ccePolicy,
          policyHash:$hash, validatedAt:$time}'
    import_bundle "$STATE/policy-bundle.json" "$LOCATION"
    rm -f -- "$STATE/policy-build.b64" "$STATE/policy-build.rego"
    info "Nonsecret bundle: $ROOT/platform/generated/policy-bundle.json"
}

confirm() {
    if [[ "$WHAT_IF" == true ]]; then info "What if: $1"; return 1; fi
    [[ "$YES" == true ]] && return 0
    [[ -t 0 ]] || die 'Run interactively, or use --yes only after reviewing the documented changes.'
    local answer
    printf '%s\nContinue? [y/N] ' "$1"
    IFS= read -r answer
    [[ "$answer" == y || "$answer" == Y || "$answer" == yes ]]
}

preflight() {
    need rad; need az; need kubectl
    local required release context nodes rp
    required="$(required_radius)"
    release="$(rad version --cli --output json | jq -er .release)"
    [[ "${release#v}" == "$required" ]] || die "Use Radius CLI $required from radius-version.txt."
    for context in "$(cfg LocalContext)" "$(cfg AksContext)"; do
        nodes="$(kubectl --context "$context" get nodes -o json)"
        jq -e '.items | length > 0 and all(.[]; .status.nodeInfo.architecture == "amd64" and .status.nodeInfo.operatingSystem == "linux")' \
            <<< "$nodes" >/dev/null || die "$context needs Linux/AMD64 nodes. On Apple Silicon, use an AMD64 development VM/cluster."
        rp="$(kubectl --context "$context" -n radius-system get deployment dynamic-rp -o json)"
        jq -e --arg version "$required" '.status.readyReplicas >= 1 and
            any(.spec.template.spec.containers[]; .image | endswith(":" + $version) or contains(":" + $version + "@"))' \
            <<< "$rp" >/dev/null || die "Prepare a ready Radius $required control plane on $context."
    done
    assert_azure_context
    check_images
    check_recipes
}

ensure_target() {
    if [[ "$TARGET" != aci ]]; then
        radcmd workspace create kubernetes "$WORKSPACE" --context "$CONTEXT" --force
    fi
    local namespace exists group_json
    namespace="$(kubectl --context "$CONTEXT" get namespace "$GROUP" --ignore-not-found -o name)"
    if [[ -z "$namespace" ]]; then kubectl --context "$CONTEXT" create namespace "$GROUP"; fi
    # Group creation is idempotent, so this also restores the group after a local cluster is recreated.
    radcmd group create "$GROUP" --workspace "$WORKSPACE"
    if [[ "$TARGET" != local ]]; then
        exists="$(azcmd group exists --name "$AZURE_GROUP" -o tsv)"
        case "$exists" in
            true)
                group_json="$(azcmd group show --name "$AZURE_GROUP" -o json)"
                jq -e --arg owner "$(owner_id)" --arg location "$(cfg Location)" \
                    '.tags.radiusDemoOwner == $owner and .location == $location' <<< "$group_json" >/dev/null \
                    || die "Refusing to adopt $AZURE_GROUP: ownership or location differs."
                ;;
            false) azcmd group create --name "$AZURE_GROUP" --location "$(cfg Location)" --tags "radiusDemoOwner=$(owner_id)" -o none ;;
            *) die "Unexpected group-existence response for $AZURE_GROUP." ;;
        esac
    fi
    ensure_password "$TARGET"
}

ensure_identity() {
    local prefix subscription credential client object role tenant sp_secret roles assignments identity resource_group scope
    prefix="$(cfg Prefix)"; subscription="$(cfg SubscriptionId)"; tenant="$(cfg TenantId)"
    credential="$STATE/azure-credential.json"
    role="Radius-Demo-ACI-$(owner_id)"
    assert_radius_credential allow-missing
    identity="$(assert_identity_scope optional)"
    if [[ ! -f "$credential" ]]; then
        [[ -z "$identity" ]] || die 'Saved identity exists without its credential backup. Recover/clean up that identity instead of creating another.'
        info 'Creating a demo-only service principal with Contributor on the two demo groups.'
        SECRET_TMP="$(mktemp "$STATE/identity.XXXXXX")"
        azcmd ad sp create-for-rbac --name "$prefix-$(owner_id)" --role Contributor --scopes \
            "/subscriptions/$subscription/resourceGroups/$prefix-aks-data" \
            "/subscriptions/$subscription/resourceGroups/$prefix-aci" -o json > "$SECRET_TMP"
        jq -e 'all(.appId,.password,.tenant; type == "string" and length > 0)' "$SECRET_TMP" >/dev/null
        jq -e --arg tenant "$tenant" '(.tenant | ascii_downcase) == ($tenant | ascii_downcase)' "$SECRET_TMP" >/dev/null \
            || die 'Azure created a principal in an unexpected tenant. Stop and reconcile that creation; it will not be registered.'
        client="$(jq -er .appId "$SECRET_TMP")"
        json_write "$STATE/identity.json" -n --arg client "$client" --arg role "$role" --arg tenant "$tenant" --arg subscription "$subscription" \
            '{clientId:$client,objectId:null,roleName:$role,tenantId:$tenant,subscriptionId:$subscription}'
        json_write "$credential" --arg subscription "$subscription" '.subscriptionId = $subscription' "$SECRET_TMP"
        rm -f -- "$SECRET_TMP"
        SECRET_TMP=''
    fi
    identity="$(assert_identity_scope)"
    jq -e --arg tenant "$tenant" --arg subscription "$subscription" --arg client "$(jq -er .clientId <<< "$identity")" '
        (.tenant | ascii_downcase) == ($tenant | ascii_downcase) and
        ((.subscriptionId // $subscription) | ascii_downcase) == ($subscription | ascii_downcase) and
        (.appId | ascii_downcase) == ($client | ascii_downcase)' "$credential" >/dev/null \
        || die 'Saved credential does not match the verified tenant/subscription/identity.'
    [[ "$(jq -er .roleName <<< "$identity")" == "$role" ]] || die 'Saved identity ownership differs.'
    client="$(jq -er .appId "$credential")"
    object="$(azcmd ad sp show --id "$client" --query id -o tsv)"
    jq -e --arg object "$object" '.objectId == null or (.objectId | ascii_downcase) == ($object | ascii_downcase)' <<< "$identity" >/dev/null \
        || die 'The service principal object changed; review the saved identity before reuse.'
    json_write "$STATE/identity.json" --arg object "$object" --arg subscription "$subscription" \
        '.objectId = $object | .subscriptionId = $subscription' "$STATE/identity.json"
    json_write "$STATE/aci-operation-reader.json" -n --arg role "$role" --arg scope "/subscriptions/$subscription" \
        '{Name:$role,IsCustom:true,Description:"Read location-scoped ACI operation status for the Radius demo.",
          Actions:["Microsoft.ContainerInstance/locations/*/read"],NotActions:[],AssignableScopes:[$scope]}'
    roles="$(azcmd role definition list --name "$role" -o json)"
    if [[ "$(jq -er length <<< "$roles")" == 0 ]]; then
        azcmd role definition create --role-definition "$STATE/aci-operation-reader.json" -o none
        info 'Waiting 30 seconds for the role definition to propagate.'
        sleep 30
    fi
    assignments="$(azcmd role assignment list --assignee "$object" --all --query "[?roleDefinitionName=='$role']" -o json)"
    if [[ "$(jq -er length <<< "$assignments")" == 0 ]]; then
        azcmd role assignment create --assignee-object-id "$object" --assignee-principal-type ServicePrincipal \
            --role "$role" --scope "/subscriptions/$subscription" -o none
    fi
    # Deleting a demo group also deletes its role assignments, so restore them when the group was recreated.
    for resource_group in "$prefix-aks-data" "$prefix-aci"; do
        scope="/subscriptions/$subscription/resourceGroups/$resource_group"
        assignments="$(azcmd role assignment list --assignee "$object" --role Contributor --scope "$scope" -o json)"
        if [[ "$(jq -er length <<< "$assignments")" == 0 ]]; then
            azcmd role assignment create --assignee-object-id "$object" --assignee-principal-type ServicePrincipal \
                --role Contributor --scope "$scope" -o none
        fi
    done
    radcmd workspace switch "$prefix-azure"
    assert_radius_credential allow-missing
    sp_secret="$(jq -er .password "$credential")"
    radcmd credential register azure sp --client-id "$client" --tenant-id "$tenant" --client-secret "$sp_secret" >/dev/null
    unset sp_secret
    assert_radius_credential
}

publish_platform_recipe() {
    local file=$1 tag=$2 record=$3 policy_hash=${4:-} published
    PUBLISHED_SOURCE="$(cfg RecipeRepository):$tag"
    published=''
    if [[ -f "$STATE/$record.json" ]]; then published="$(jq -r '.source // ""' "$STATE/$record.json")"; fi
    if [[ "$published" != "$PUBLISHED_SOURCE" ]]; then
        info "Publishing ${file##*/}. Radius must already have usable GHCR credentials."
        rad bicep publish --file "$file" --target "br:$PUBLISHED_SOURCE"
        json_write "$STATE/$record.json" -n --arg source "$PUBLISHED_SOURCE" --arg hash "$policy_hash" \
            '{source:$source} + (if $hash == "" then {} else {policyHash:$hash} end)'
    fi
    registry_get "$(cfg RecipeRepository | sed 's|^ghcr.io/||')" "manifests/$tag" "$STATE/$record-manifest.json" \
        || die "Make only this demo recipe package public in GitHub Packages, then rerun preparation: $PUBLISHED_SOURCE"
}

prepare() {
    local preparation_hashes current_hashes
    preparation_hashes="$(source_hashes)"
    load_config
    local action
    action="Prepare tenant $(cfg TenantId), subscription $(cfg SubscriptionId), demo scopes $(cfg Prefix)-aks-data/$(cfg Prefix)-aci, namespaces, one identity, and platform recipes in $(cfg RecipeRepository)."
    if [[ "$WHAT_IF" == true ]]; then info "What if: $action"; return; fi
    if [[ "$OS" == Darwin && -z "$POLICY_BUNDLE" ]]; then
        die 'On macOS, pass --policy-bundle from the same source files generated on Linux/WSL or Windows.'
    fi
    # Check the policy source before asking for confirmation.
    if [[ -n "$POLICY_BUNDLE" ]]; then
        [[ -f "$POLICY_BUNDLE" ]] || die "Cannot find the policy bundle $POLICY_BUNDLE."
    else
        assert_policy_generator
    fi
    assert_saved_config
    assert_identity_scope optional >/dev/null
    preflight
    if ! confirm "$action"; then info 'Preparation cancelled; nothing was written.'; return; fi
    current_hashes="$(source_hashes)"
    [[ "$current_hashes" == "$preparation_hashes" ]] || die 'Inputs changed during preparation. No new baseline was saved; rerun 00-prepare without editing inputs.'
    initialize_state
    json_write "$STATE/setup-config.json" -n --argjson config "$CONFIG" '$config'
    LOCATION="$(cfg Location)"
    if [[ -n "$POLICY_BUNDLE" ]]; then import_bundle "$POLICY_BUNDLE" "$LOCATION"; else generate_policy; fi
    local policy_hash wrapper_hash tag source kubernetes_source name
    policy_hash="$(jq -er .policyHash "$ROOT/platform/generated/policy-bundle.json")"
    wrapper_hash="$(hash_file "$ROOT/platform/aci-containers.bicep")"
    tag="policy-$(printf '%s' "${policy_hash:0:12}" | tr '[:upper:]' '[:lower:]')-$(printf '%s' "${wrapper_hash:0:12}" | tr '[:upper:]' '[:lower:]')"
    publish_platform_recipe "$ROOT/platform/aci-containers.bicep" "$tag" recipe "$policy_hash"
    source=$PUBLISHED_SOURCE
    wrapper_hash="$(hash_file "$ROOT/platform/kubernetes-containers.bicep")"
    publish_platform_recipe "$ROOT/platform/kubernetes-containers.bicep" \
        "kubernetes-$(printf '%s' "${wrapper_hash:0:12}" | tr '[:upper:]' '[:lower:]')" kubernetes-recipe
    kubernetes_source=$PUBLISHED_SOURCE
    for name in local aks aci; do select_target "$name"; ensure_target; done
    ensure_identity
    for name in local aks aci; do
        select_target "$name"
        if [[ "$name" == local ]]; then
            radcmd deploy "$ROOT/platform/local.bicep" --workspace "$WORKSPACE" --group "$GROUP" --parameters "namespace=$GROUP" \
                --parameters "kubernetesContainersRecipe=$kubernetes_source"
        else
            radcmd deploy "$ROOT/platform/cloud.bicep" --workspace "$WORKSPACE" --group "$GROUP" \
                --parameters "namespace=$GROUP" --parameters "target=$name" --parameters "subscriptionId=$(cfg SubscriptionId)" \
                --parameters "azureResourceGroup=$AZURE_GROUP" --parameters "aciRecipeSource=$source" \
                --parameters "kubernetesContainersRecipe=$kubernetes_source"
        fi
    done
    current_hashes="$(source_hashes)"
    [[ "$current_hashes" == "$preparation_hashes" ]] || die 'Inputs changed during preparation. No new baseline was saved; rerun 00-prepare without editing inputs.'
    json_write "$STATE/baseline.json" -n --argjson hashes "$preparation_hashes" --arg hash "$policy_hash" \
        --arg source "$source" --arg kubernetes "$kubernetes_source" --arg time "$(stamp)" \
        '{hashes:$hashes,policyHash:$hash,recipeSource:$source,kubernetesRecipeSource:$kubernetes,preparedAt:$time}'
    info 'Preparation finished. No voting application has been deployed yet.'
    info "Saved preparation baseline: $STATE/baseline.json"
    info "Keep private state for cleanup: $STATE (0700 directory, 0600 plaintext credentials; not encryption)."
}

kubernetes_service_url() {
    local app=$1 wait_seconds=$2 name service type expected port address deadline
    name="$app-$app-external"
    expected=LoadBalancer
    [[ "$TARGET" != local ]] || expected=NodePort
    deadline=$((SECONDS + wait_seconds))
    while true; do
        service="$(kubectl --context "$CONTEXT" -n "$GROUP" get service "$name" --ignore-not-found -o json)"
        [[ -n "$service" ]] || die "Service $name is missing in $CONTEXT/$GROUP. Rerun preparation so the $TARGET recipe pack publishes the app natively, then redeploy."
        type="$(jq -er '.spec.type' <<< "$service")"
        [[ "$type" == "$expected" ]] || die "Service $name in $CONTEXT/$GROUP is $type, not $expected. Rerun preparation, then redeploy."
        if [[ "$expected" == NodePort ]]; then
            ENDPOINT_URL="http://127.0.0.1:$(jq -er '.spec.ports[0].nodePort' <<< "$service")"
            return
        fi
        address="$(jq -r '.status.loadBalancer.ingress[0].ip // empty' <<< "$service")"
        if jq -en --arg ip "$address" '$ip | test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$") and (split(".") | all(.[]; tonumber <= 255))' >/dev/null; then
            port="$(jq -er '.spec.ports[0].port' <<< "$service")"
            if [[ "$port" == 80 ]]; then ENDPOINT_URL="http://$address"; else ENDPOINT_URL="http://$address:$port"; fi
            return
        fi
        (( SECONDS < deadline )) || die "Azure has not assigned a public IP to Service $name yet. Inspect: kubectl --context $CONTEXT -n $GROUP describe service $name"
        sleep 5
    done
}

get_urls() {
    local wait_seconds=${1:-0} role ip
    if [[ "$TARGET" != aci ]]; then
        kubernetes_service_url vote "$wait_seconds"; VOTE_URL=$ENDPOINT_URL
        kubernetes_service_url result "$wait_seconds"; RESULT_URL=$ENDPOINT_URL
        return
    fi
    for role in vote result; do
        ip="$(azcmd network public-ip show --resource-group "$AZURE_GROUP" --name "$role-inbound" --query ipAddress -o tsv)"
        jq -en --arg ip "$ip" '$ip | test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$") and (split(".") | all(.[]; tonumber <= 255))' \
            >/dev/null || die "No valid IPv4 address for $role-inbound."
        if [[ "$role" == vote ]]; then VOTE_URL="http://$ip"; else RESULT_URL="http://$ip"; fi
    done
}

endpoint_hint() {
    case "$TARGET" in
        local) printf '%s' 'The local cluster must publish the node ports of its vote and result Services on 127.0.0.1, as infra/kind.yaml does. Recreate an older kind cluster, then rerun preparation and script 02.' ;;
        aks) printf '%s' "Check the vote-vote-external and result-result-external load balancer Services and pods in $CONTEXT/$GROUP." ;;
        *) printf '%s' 'Check the ACI deployment and its public endpoints.' ;;
    esac
}

wait_endpoints() {
    local deadline=$((SECONDS + 180)) url
    for url in "$VOTE_URL" "$RESULT_URL"; do
        until curl -fs --connect-timeout 3 --max-time 5 --output /dev/null "$url"; do
            (( SECONDS < deadline )) || die "Demo endpoint $url did not answer within 180 seconds. $(endpoint_hint)"
            sleep 3
        done
    done
}

show_app() {
    info 'STEP 1 | One application contract'
    info 'vote -> Redis (localhost) -> worker -> PostgreSQL -> result'
    info 'vote + worker + Redis share one deployment unit; result is separate.'
    info "Application SHA256: $(hash_file "$ROOT/app.bicep")"
    jq -r '.images | to_entries | sort_by(.key)[] | "\(.key): \(.value)"' "$ROOT/images.lock.json"
    info 'Open app.bicep. Runtime and confidential-policy choices belong to the platform files.'
}

show_deployment_summary() {
    local pods rows name image state servers
    info 'Same inputs for every target, checked against the preparation baseline:'
    info "  app.bicep         SHA256 $(jq -er '.hashes["app.bicep"][0:16]' "$STATE/baseline.json")"
    info "  images.lock.json  SHA256 $(jq -er '.hashes["images.lock.json"][0:16]' "$STATE/baseline.json")"
    if [[ "$TARGET" != aci ]]; then
        pods="$(kubectl --context "$CONTEXT" -n "$GROUP" get pods -o json)"
        rows="$(jq -er --slurpfile lock "$ROOT/images.lock.json" --arg target "$TARGET" '
          . as $pods | $lock[0].images | to_entries | sort_by(.key)[] | . as $image |
          [$pods.items[] | select(.metadata.deletionTimestamp == null) | . as $pod |
            .spec.containers[] | select(.name == $image.key) |
            {image, ready: ([($pod.status.containerStatuses // [])[] | select(.name == $image.key) | .ready] == [true])}] |
          if length == 0 then error("No running \($image.key) container found on \($target).")
          elif any(.[]; .image != $image.value) then error("\($target)/\($image.key) does not use the locked image reference.")
          else .[] | [$image.key, (.image | sub("(?<keep>@sha256:[a-f0-9]{12})[a-f0-9]{52}$"; "\(.keep)...")),
            (if .ready then "Ready" else "Not ready" end)] | @tsv end' <<< "$pods")" \
            || die "$TARGET application containers are missing or do not use the locked image references; the deployment was not marked as successful."
        info "Application containers in $GROUP, locked image digests (no environment values):"
        while IFS=$'\t' read -r name image state; do
            printf '  %-7s %s  %s\n' "$name" "$image" "$state"
        done <<< "$rows"
    fi
    if [[ "$TARGET" != local ]]; then
        servers="$(azcmd postgres flexible-server list --resource-group "$AZURE_GROUP" --query '[].{name:name,state:state}' -o json)"
        jq -e 'length > 0' <<< "$servers" >/dev/null || die "No Azure PostgreSQL server found in $AZURE_GROUP."
        jq -r --arg group "$AZURE_GROUP" '.[] | "Azure PostgreSQL in \($group): \(.name) | \(.state)"' <<< "$servers"
    fi
}

show_policy() {
    baseline
    local generated="$ROOT/platform/generated" policy_hash
    decode_policy "$generated/vote-ccepolicy.b64" "$STATE/policy-current.rego"
    policy_hash="$(hash_file "$STATE/policy-current.rego")"
    rm -f -- "$STATE/policy-current.rego"
    [[ "$policy_hash" == "$(jq -er .policyHash "$STATE/baseline.json")" ]] \
        || die 'The generated policy no longer matches the prepared recipe. Rerun preparation, then the deployment steps.'
    [[ "$(hash_file "$generated/vote-policy.rego")" == "$policy_hash" ]] \
        || die 'vote-policy.rego is not the decoded policy that the recipe passes to Azure. Rerun preparation.'
    info 'Confidential policy for the vote group: platform/generated/vote-policy.rego'
    info "Policy SHA256: $policy_hash"
    info 'This file decodes the exact policy the ACI recipe passes to Azure. Allow-all: no.'
    sed -n 's/^containers := //p' "$generated/vote-policy.rego" |
        jq -er --slurpfile lock "$ROOT/images.lock.json" --slurpfile template "$ROOT/platform/vote-policy-template.json" '
          def short: sub("(?<keep>@sha256:[a-f0-9]{12})[a-f0-9]{52}$"; "\(.keep)...");
          def pad: (. + "       ")[0:7];
          . as $policy |
          (["redis", "vote", "worker"] | map(. as $name | [$policy[] | select(.name == $name)] |
            if length == 1 and .[0].id == $lock[0].images[$name] then .[0]
            else error("The policy does not pin the locked \($name) image.") end)) as $entries |
          [$template[0].resources[0].properties.containers[] | select(.name == "vote") |
            .properties.environmentVariables[]?.name] as $names |
          ($entries[] | select(.name == "vote")) as $vote |
          "Allowed containers, pinned to the locked images:",
          ($entries[] | "  \(.name | pad) \(.id | short)"),
          "vote startup rules (excerpt):",
          "  command  \($vote.command | join(" "))",
          ($vote.env_rules[] |
            select(.strategy == "string" and ((.pattern | split("=")[0]) as $variable | any($names[]; . == $variable))) |
            "  env      \(.pattern)")' \
        || die 'Cannot read the pinned containers from vote-policy.rego. Rerun preparation.'
}

deploy() {
    load_config; select_target "$1"
    info "rad deploy app.bicep --workspace $WORKSPACE --group $GROUP --environment $TARGET --parameters @<private-parameters.json>"
    [[ "$PLAN" != true ]] || return
    baseline
    if [[ "$TARGET" != local ]]; then
        assert_azure_context
        assert_identity_scope >/dev/null
        assert_radius_credential
    fi
    if [[ "$TARGET" == aci ]]; then
        decode_policy "$ROOT/platform/generated/vote-ccepolicy.b64" "$STATE/policy-current.rego"
        [[ "$(hash_file "$STATE/policy-current.rego")" == "$(jq -er .policyHash "$STATE/baseline.json")" ]] \
            || die 'The policy changed. Rerun preparation, then the deployment steps.'
        rm -f -- "$STATE/policy-current.rego"
    fi
    local receipt
    receipt="$STATE/$TARGET.receipt.json"
    json_write "$receipt" -n --arg target "$TARGET" --slurpfile baseline "$STATE/baseline.json" \
        '{target:$target,status:"deploying",deployedAt:null,hashes:$baseline[0].hashes,voteProof:null}'
    ensure_password "$TARGET"
    PARAM_FILE="$(mktemp "$STATE/$TARGET.parameters.XXXXXX")"
    json_write "$PARAM_FILE" -n --slurpfile secret "$STATE/$TARGET.password.json" \
        '{"$schema":"https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
          contentVersion:"1.0.0.0",parameters:{postgresPassword:{value:$secret[0].password}}}'
    radcmd deploy "$ROOT/app.bicep" --workspace "$WORKSPACE" --group "$GROUP" --environment "$TARGET" --parameters "@$PARAM_FILE"
    rm -f -- "$PARAM_FILE"; PARAM_FILE=''
    if [[ "$TARGET" != aci ]]; then
        kubectl --context "$CONTEXT" -n "$GROUP" rollout status deployment/vote --timeout=240s
        kubectl --context "$CONTEXT" -n "$GROUP" rollout status deployment/result --timeout=240s
    fi
    baseline
    show_deployment_summary
    get_urls 300
    wait_endpoints
    json_write "$receipt" --arg time "$(stamp)" '.status="deployed" | .deployedAt=$time' "$receipt"
    info "Vote:   $VOTE_URL"; info "Result: $RESULT_URL"
    info "Then: bash scripts/Test-VoteFlow.sh --target $TARGET"
}

poll_request() {
    local remaining=$((POLL_DEADLINE - SECONDS))
    [[ "$remaining" -gt 0 ]] || die 'Timed out waiting for the new vote to appear in results.'
    curl -fsS --connect-timeout 10 --max-time "$remaining" "$@"
}

next_scores() {
    local payload packet event
    while (( SECONDS < POLL_DEADLINE )); do
        payload="$(poll_request "$POLL_URL&sid=$POLL_SID&t=$SECONDS-$RANDOM")"
        while IFS= read -r packet; do
            case "$packet" in
                2) poll_request -H 'Content-Type: text/plain;charset=UTF-8' --data-binary '3' "$POLL_URL&sid=$POLL_SID" >/dev/null ;;
                1|44*) die 'The result service closed or rejected the Socket.IO connection.' ;;
                42*)
                    event="$(jq -ce 'select(type == "array" and length >= 2)' <<< "${packet:2}")"
                    if jq -e '.[0] == "scores"' <<< "$event" >/dev/null; then
                        jq -ce '.[1] | if type == "string" then fromjson else . end |
                          if (type == "object" and all(.a,.b; type == "number" and . >= 0 and floor == .))
                          then {a:.a,b:.b} else error("Invalid result scores") end' <<< "$event"
                        return
                    fi
                    ;;
            esac
        done <<< "$(printf '%s' "$payload" | tr '\036' '\n')"
        sleep 0.1
    done
    die 'Timed out waiting for the result service scores.'
}

verify_vote() {
    load_config; select_target "$TARGET_ARG"; baseline
    local receipt handshake before after voter url hint
    receipt="$STATE/$TARGET.receipt.json"
    [[ -f "$receipt" ]] || die "Deploy $TARGET before verifying its vote flow."
    jq -e '.status == "deployed"' "$receipt" >/dev/null || die "The last $TARGET deployment did not finish."
    assert_snapshot "$receipt" hashes
    json_write "$receipt" '.voteProof = null' "$receipt"
    get_urls
    info "Checking $TARGET with one new Dogs vote. Keep other users off the demo."
    hint="$(endpoint_hint)"
    for url in "$VOTE_URL" "$RESULT_URL"; do
        curl -fsS --connect-timeout 3 --max-time 5 --output /dev/null "$url" || die "Cannot reach demo endpoint $url. $hint"
    done
    POLL_DEADLINE=$((SECONDS + 60))
    POLL_URL="$RESULT_URL/socket.io/?EIO=4&transport=polling"
    handshake="$(poll_request "$POLL_URL&t=$RANDOM")"
    [[ "$handshake" == 0* ]] || die 'Expected an Engine.IO 4 handshake from the result service.'
    POLL_SID="$(jq -er '.sid | select(type == "string" and length > 0) | @uri' <<< "${handshake:1}")"
    poll_request -H 'Content-Type: text/plain;charset=UTF-8' --data-binary '40' "$POLL_URL&sid=$POLL_SID" >/dev/null
    before="$(next_scores)"
    voter="demo-$(openssl rand -hex 16)"
    poll_request -H 'Content-Type: application/x-www-form-urlencoded' -H "Cookie: voter_id=$voter" \
        --data 'vote=b' "$VOTE_URL" >/dev/null
    while true; do
        after="$(next_scores)"
        if jq -en --argjson before "$before" --argjson after "$after" \
            '$after.b >= ($before.b + 1) and ($after.a + $after.b) >= ($before.a + $before.b + 1)' >/dev/null; then break; fi
    done
    json_write "$receipt" --argjson before "$before" --argjson after "$after" --arg voter "$voter" --arg time "$(stamp)" \
        '.voteProof = {before:$before,after:$after,voterId:$voter,verifiedAt:$time}' "$receipt"
    info "PASS | $TARGET | Dogs: $(jq -r .b <<< "$before") -> $(jq -r .b <<< "$after") | vote -> Redis -> worker -> PostgreSQL -> result"
}

open_apps() {
    load_config; select_target "$TARGET_ARG"; baseline
    local receipt url opener=''
    receipt="$STATE/$TARGET.receipt.json"
    [[ -f "$receipt" ]] || die "Deploy $TARGET before opening its pages."
    jq -e '.status == "deployed"' "$receipt" >/dev/null || die "The last $TARGET deployment did not finish."
    assert_snapshot "$receipt" hashes
    get_urls
    info "Vote:   $VOTE_URL"; info "Result: $RESULT_URL"
    if [[ "$OS" == Darwin ]]; then opener=open
    elif grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
        if command -v wslview >/dev/null 2>&1; then opener=wslview
        elif command -v explorer.exe >/dev/null 2>&1; then opener=explorer.exe
        fi
    elif [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]] && command -v xdg-open >/dev/null 2>&1; then opener=xdg-open
    fi
    [[ -n "$opener" ]] || { info 'No browser opener is available here. Open the two URLs above in your browser.'; return; }
    # Open the vote page last so its tab is in front for the first browser vote.
    for url in "$RESULT_URL" "$VOTE_URL"; do
        # explorer.exe returns a nonzero code even after it hands the URL to the Windows browser.
        if [[ "$opener" == explorer.exe ]]; then explorer.exe "$url" || true
        elif ! "$opener" "$url" >/dev/null 2>&1; then info "$opener could not open $url. Open the URLs above in your browser."
        fi
    done
}

prove() {
    load_config; baseline
    assert_azure_context
    assert_identity_scope >/dev/null
    assert_radius_credential
    local name receipt pods policy_hash running_hash profile_hash server servers tls group_names group_name
    info 'STEP 5 | Verify the claim, then compare the targets'
    for name in local aks aci; do
        select_target "$name"; receipt="$STATE/$name.receipt.json"
        [[ -f "$receipt" ]] || die "Missing $name deployment receipt."
        jq -e '.status == "deployed" and (.voteProof.verifiedAt | type == "string")' "$receipt" >/dev/null \
            || die "Finish the $name deployment and vote verification before the comparison."
        assert_snapshot "$receipt" hashes
        if [[ "$name" != aci ]]; then
            pods="$(kubectl --context "$CONTEXT" -n "$GROUP" get pods -o json)"
            jq -e --slurpfile lock "$ROOT/images.lock.json" '
              . as $pods | all($lock[0].images | to_entries[];
                . as $image |
                [$pods.items[] | select(.metadata.deletionTimestamp == null) | . as $pod |
                  .spec.containers[] | select(.name == $image.key) |
                  [$pod.status.containerStatuses[] | select(.name == $image.key)] as $status |
                  (.image == $image.value and ($status | length) == 1 and $status[0].ready == true and
                    ($status[0].imageID | ascii_downcase | endswith($image.value | split("@")[1])))] |
                length > 0 and all(.[]; . == true))' <<< "$pods" >/dev/null \
                || die "$name does not have all four ready containers with the locked runtime imageIDs."
        fi
    done
    select_target aci
    decode_policy "$ROOT/platform/generated/vote-ccepolicy.b64" "$STATE/policy-current.rego"
    policy_hash="$(hash_file "$STATE/policy-current.rego")"
    [[ "$policy_hash" == "$(jq -er .policyHash "$STATE/baseline.json")" ]] || die 'The local policy changed since preparation.'
    # Keep only evidence fields: never save or display deployed environment values.
    # `az container list` leaves every container's instance view empty, so read each group with `az container show`.
    group_names="$(azcmd container list --resource-group "$AZURE_GROUP" --query '[].name' -o tsv)"
    : > "$STATE/aci-evidence.jsonl"
    while IFS= read -r group_name; do
        [[ -n "$group_name" ]] || continue
        azcmd container show --resource-group "$AZURE_GROUP" --name "$group_name" --query \
            '{name:name,sku:sku,provisioningState:provisioningState,containers:containers[].{name:name,image:image,state:instanceView.currentState.state},confidentialComputeProperties:confidentialComputeProperties}' \
            -o json >> "$STATE/aci-evidence.jsonl"
    done <<< "$group_names"
    jq -s . "$STATE/aci-evidence.jsonl" > "$STATE/aci-evidence.json"
    rm -f -- "$STATE/aci-evidence.jsonl"
    jq -e --slurpfile lock "$ROOT/images.lock.json" '
      . as $groups | all(["vote","result"][];
        . as $role | [$groups[] | select(any(.containers[]; .name == $role))] as $matches |
        ($matches | length) == 1 and
        ($matches[0] | .provisioningState == "Succeeded" and
          .sku == (if $role == "vote" then "Confidential" else "Standard" end) and
          ([.containers[].name] | sort) == (if $role == "vote" then ["redis","vote","worker"] else ["result"] end) and
          all(.containers[]; .state == "Running" and .image == $lock[0].images[.name])))' \
        "$STATE/aci-evidence.json" >/dev/null || die 'ACI group membership, SKU, immutable image reference, or Running state differs.'
    jq -er '.[] | select(any(.containers[]; .name == "vote")) | .confidentialComputeProperties.ccePolicy' \
        "$STATE/aci-evidence.json" > "$STATE/running-policy.b64"
    decode_policy "$STATE/running-policy.b64" "$STATE/running-policy.rego"
    running_hash="$(hash_file "$STATE/running-policy.rego")"
    azcmd resource show --resource-group "$AZURE_GROUP" --name vote-profile \
        --resource-type Microsoft.ContainerInstance/containerGroupProfiles --api-version 2024-11-01-preview \
        --query '{sku:properties.sku,policy:properties.confidentialComputeProperties.ccePolicy}' \
        -o json > "$STATE/profile-evidence.json"
    jq -e '.sku == "Confidential"' "$STATE/profile-evidence.json" >/dev/null || die 'The vote profile is not Confidential.'
    jq -er .policy "$STATE/profile-evidence.json" > "$STATE/profile-policy.b64"
    decode_policy "$STATE/profile-policy.b64" "$STATE/profile-policy.rego"
    profile_hash="$(hash_file "$STATE/profile-policy.rego")"
    [[ "$policy_hash" == "$running_hash" && "$policy_hash" == "$profile_hash" ]] \
        || die 'Generated policy, Azure profile, and running group differ. A profile update may leave old instances.'
    jq -r '.[] | "\(.name) | \(.sku) | \([.containers[].name] | join(", ")) | Running"' "$STATE/aci-evidence.json"
    info "Policy SHA256: $policy_hash"
    info 'Generated file = Azure profile = running group'
    for name in aks aci; do
        select_target "$name"
        servers="$(azcmd postgres flexible-server list --resource-group "$AZURE_GROUP" --query '[].{name:name,state:state}' -o json)"
        jq -e 'length == 1 and .[0].state == "Ready"' <<< "$servers" >/dev/null || die "Expected one Ready PostgreSQL server for $name."
        server="$(jq -er '.[0].name' <<< "$servers")"
        tls="$(azcmd postgres flexible-server parameter show --resource-group "$AZURE_GROUP" --server-name "$server" \
            --name require_secure_transport --query value -o tsv | tr '[:lower:]' '[:upper:]')"
        [[ "$tls" == ON ]] || die "PostgreSQL secure transport is not required for $name."
        info "$name PostgreSQL: $server | Ready | TLS required"
    done
    printf '%-7s %-18s %-18s %s\n' Target 'Application SHA256' 'Image-lock SHA256' 'Vote flow verified (UTC)'
    for name in local aks aci; do
        jq -r '[.target,.hashes["app.bicep"][0:16],.hashes["images.lock.json"][0:16],.voteProof.verifiedAt] | @tsv' "$STATE/$name.receipt.json"
    done
    info 'Kubernetes: runtime imageIDs checked. ACI: immutable references, Running state, and policy configuration checked.'
    info 'This is configuration and behavior evidence, NOT independent remote attestation.'
}

cleanup_demo() {
    load_config
    local owner prefix name exists group_json receipt applications identity role object client assignments id roles
    [[ -f "$STATE/owner-id.json" && -f "$STATE/setup-config.json" ]] || die 'No ownership record; nothing will be deleted.'
    owner="$(owner_id)"; prefix="$(cfg Prefix)"
    assert_saved_config
    assert_azure_context
    assert_identity_scope optional >/dev/null
    if [[ -f "$STATE/aks.receipt.json" || -f "$STATE/aci.receipt.json" ]]; then assert_radius_credential; fi
    if ! confirm "Delete demo resources in tenant $(cfg TenantId), subscription $(cfg SubscriptionId): owned $prefix-aks-data/$prefix-aci groups, this run's Radius Azure credential, and its identity. Keep both clusters."; then return; fi
    # Check both Azure scopes before deleting anything.
    for name in aks aci; do
        select_target "$name"
        exists="$(azcmd group exists --name "$AZURE_GROUP" -o tsv)"
        case "$exists" in
            false) continue ;;
            true)
                group_json="$(azcmd group show --name "$AZURE_GROUP" -o json)"
                jq -e --arg owner "$owner" '.tags.radiusDemoOwner == $owner' <<< "$group_json" >/dev/null \
                    || die "Ownership mismatch on $AZURE_GROUP. Nothing will be deleted."
                ;;
            *) die "Unexpected group-existence response for $AZURE_GROUP." ;;
        esac
    done
    for name in local aks aci; do
        select_target "$name"; receipt="$STATE/$name.receipt.json"
        if [[ -f "$receipt" ]]; then
            applications="$(radcmd app list --workspace "$WORKSPACE" --group "$GROUP" -o json)"
            jq -e '. == null or type == "array" or type == "object"' <<< "$applications" >/dev/null \
                || die 'Radius returned an invalid application list; cleanup stopped.'
            if jq -e '[.. | objects | select(.name? == "example-voting-app")] | length > 0' <<< "$applications" >/dev/null; then
                radcmd app delete example-voting-app --workspace "$WORKSPACE" --group "$GROUP" --yes
            fi
            rm -f -- "$receipt"
        fi
    done
    for name in aks aci; do
        select_target "$name"
        exists="$(azcmd group exists --name "$AZURE_GROUP" -o tsv)"
        case "$exists" in
            true) azcmd group delete --name "$AZURE_GROUP" --yes ;;
            false) ;;
            *) die "Unexpected group-existence response for $AZURE_GROUP." ;;
        esac
    done
    identity="$STATE/identity.json"
    if [[ -f "$identity" ]]; then
        role="$(jq -er .roleName "$identity")"
        [[ "$role" == "Radius-Demo-ACI-$owner" ]] || die 'Identity ownership record differs.'
        remove_radius_credential
        object="$(jq -r '.objectId // empty' "$identity")"; client="$(jq -er .clientId "$identity")"
        if [[ -z "$object" ]]; then object="$(azcmd ad sp show --id "$client" --query id -o tsv)"; fi
        assignments="$(azcmd role assignment list --assignee "$object" --all --query "[?roleDefinitionName=='$role']" -o json)"
        while IFS= read -r id; do
            [[ -z "$id" ]] || azcmd role assignment delete --ids "$id"
        done <<< "$(jq -r '.[].id' <<< "$assignments")"
        roles="$(azcmd role definition list --name "$role" -o json)"
        if [[ "$(jq -er length <<< "$roles")" != 0 ]]; then azcmd role definition delete --name "$role"; fi
        azcmd ad sp delete --id "$client"
        rm -f -- "$identity" "$STATE/azure-credential.json"
    fi
    info 'Cleanup finished. Clusters, namespaces/environments, recipe packages, and private password backups remain.'
    info 'Review Azure for remaining billed resources.'
}

usage() {
    cat <<'USAGE'
Native Bash demo commands:
  00-prepare.sh [--policy-bundle FILE] [--yes | --what-if]
  01-show-app.sh
  02-local.sh | 03-aks.sh | 04-aci.sh [--plan]
  Show-Policy.sh   (step 4, before 04-aci.sh: checked excerpt of the generated policy)
  Test-VoteFlow.sh --target local|aks|aci
  Open-Apps.sh --target local|aks|aci   (opens the deployed vote and results pages)
  05-proof.sh
  99-cleanup.sh [--yes | --what-if]
  Generate-Policy.sh [--location eastus2]   (Linux/WSL; Windows has a .ps1 equivalent)
  demo.sh state-path | check-images
Run each with bash. Requires jq, curl, openssl, and the platform CLIs.
USAGE
}

initialize_demo_cli() {
    case "$OS" in Linux|Darwin) ;; *) die 'Use the .ps1 track on Windows. Run .sh inside Linux/WSL or macOS, not Git Bash.' ;; esac
    need jq; need curl; need openssl
    STATE_BASE="${XDG_STATE_HOME:-$HOME/.local/state}"
    [[ "$STATE_BASE" == /* ]] || die 'XDG_STATE_HOME must be an absolute native Linux/macOS path.'
    STATE_KEY="$(printf '%s' "$ROOT" | openssl dgst -sha256 -r | awk '{print substr($1,1,16)}')"
    STATE="$STATE_BASE/radius-demo/$STATE_KEY"
}

# Bootstrap entry points may reuse the existing scope/state helpers without running a demo step.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then return 0; fi

COMMAND=${1:-help}
if [[ $# -gt 0 ]]; then shift; fi
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --yes|--what-if)
            [[ "$COMMAND" == prepare || "$COMMAND" == cleanup ]] || die "$1 is only supported for preparation or cleanup."
            if [[ "$1" == --yes ]]; then YES=true; else WHAT_IF=true; fi
            shift
            ;;
        --plan)
            [[ "$COMMAND" == local || "$COMMAND" == aks || "$COMMAND" == aci ]] || die '--plan is only supported for application deployment steps.'
            PLAN=true; shift
            ;;
        --policy-bundle|--location|--target)
            [[ $# -ge 2 ]] || die "Missing value after $1."
            case "$1" in
                --policy-bundle) [[ "$COMMAND" == prepare ]] || die '--policy-bundle is only supported for preparation.'; POLICY_BUNDLE=$2 ;;
                --location) [[ "$COMMAND" == generate-policy ]] || die '--location is only supported for policy generation.'; LOCATION=$2 ;;
                --target)
                    [[ "$COMMAND" == test-vote || "$COMMAND" == open-apps ]] || die '--target is only supported for vote verification and opening the apps.'
                    TARGET_ARG=$2
                    ;;
            esac
            shift 2
            ;;
        *) die "Unknown argument: $1. Use --help." ;;
    esac
done
if [[ "$COMMAND" == help || "$COMMAND" == --help || "$COMMAND" == -h ]]; then usage; exit 0; fi
initialize_demo_cli
case "$COMMAND" in
    prepare) prepare ;;
    show-app) show_app ;;
    show-policy) show_policy ;;
    local|aks|aci) deploy "$COMMAND" ;;
    test-vote) verify_vote ;;
    open-apps) open_apps ;;
    proof) prove ;;
    cleanup) cleanup_demo ;;
    generate-policy) [[ "$OS" == Linux ]] || die 'Generate the policy on Linux/WSL or Windows, then import it on macOS.'; initialize_state; generate_policy ;;
    check-images) check_images ;;
    state-path) info "$STATE" ;;
    *) die "Unknown command: $COMMAND." ;;
esac
