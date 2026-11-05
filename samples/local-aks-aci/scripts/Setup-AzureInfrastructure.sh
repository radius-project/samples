#!/usr/bin/env bash
# shellcheck disable=SC2016
# shellcheck source=scripts/demo.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/demo.sh"

API_CIDR='' ADMIN_OBJECT_ID='' ADMIN_TYPE='User' NODE_VM_SIZE='Standard_D4s_v5' KUBERNETES_VERSION=''
DEPLOY=false USE_DEPLOYMENT_STACK=false
usage_infrastructure() {
    printf '%s\n' \
        'Usage: bash scripts/Setup-AzureInfrastructure.sh --api-server-cidr PUBLIC_IPV4/32 [options]' \
        '  --deploy                     Request deployment after Azure what-if and confirmation' \
        '  --use-deployment-stack       Opt in to stack management; preview creates three-hour Azure result metadata' \
        '  --yes                        Accept deployment confirmation (still requires --deploy)' \
        '  --admin-object-id GUID       Object in the configured resource tenant; defaults to the signed-in user' \
        '  --admin-principal-type TYPE  User (default), Group, or ServicePrincipal' \
        '  --node-vm-size SIZE          Standard_D4s_v5 (default), Standard_D4as_v5, or Standard_D4s_v6; two AMD64 nodes' \
        '  --kubernetes-version X.Y.Z   Supported version for creation; not an upgrade command' \
        'Default: Azure what-if only. No automatic login, provider registration, tool install, or kubeconfig edit.'
}

assert_bootstrap_cidr() {
    [[ "$API_CIDR" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/(2[4-9]|3[0-2])$ ]] \
        || die 'Use your public IPv4 egress CIDR (/24 through /32), normally YOUR_PUBLIC_IPV4/32.'
    local ip=${API_CIDR%/*} prefix=${API_CIDR#*/} part a b c d address
    local parts=()
    IFS=. read -r -a parts <<< "$ip"
    for part in "${parts[@]}"; do
        if [[ ! "$part" =~ ^(0|[1-9][0-9]{0,2})$ ]] || (( 10#$part > 255 )); then die 'Invalid IPv4 CIDR octet.'; fi
    done
    a=${parts[0]}; b=${parts[1]}; c=${parts[2]}; d=${parts[3]}
    if (( a == 0 || a == 10 || a == 127 || a >= 224 ||
          (a == 100 && b >= 64 && b <= 127) || (a == 169 && b == 254) ||
          (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) ||
          (a == 192 && b == 0 && (c == 0 || c == 2)) ||
          (a == 192 && b == 88 && c == 99) ||
          (a == 198 && (b == 18 || b == 19)) || (a == 198 && b == 51 && c == 100) ||
          (a == 203 && b == 0 && c == 113) )); then
        die 'The API CIDR must be public egress, not a private, reserved, or documentation address.'
    fi
    address=$(( (a << 24) + (b << 16) + (c << 8) + d ))
    (( (address & ((1 << (32 - prefix)) - 1)) == 0 )) || die 'Use the network address for a range, or /32 for one IP.'
}

assert_bootstrap_tags() {
    jq -e --arg owner "$(owner_id)" --arg tenant "$(cfg TenantId)" '
        .tags.radiusDemoOwner == $owner and
        ((.tags.radiusDemoTenant // "") | ascii_downcase) == ($tenant | ascii_downcase) and
        .tags.radiusDemoPurpose == "aks-bootstrap"' <<< "$1" >/dev/null \
        || die 'Refusing to adopt a resource whose bootstrap ownership/tenant tags do not match this checkout.'
}

owned_bootstrap_cluster() {
    local exists group clusters cluster='null' node_exists
    exists="$(azcmd group exists --name "$GROUP_NAME" --output tsv)"
    if [[ "$exists" == true ]]; then
        group="$(azcmd group show --name "$GROUP_NAME" --output json)"
        assert_bootstrap_tags "$group"
        [[ "$(jq -er .location <<< "$group")" == "$(cfg Location)" ]] || die 'The owned platform group has a different location.'
        clusters="$(azcmd aks list --resource-group "$GROUP_NAME" --output json)"
        jq -e --arg name "$CLUSTER_NAME" 'length == 0 or (length == 1 and .[0].name == $name)' <<< "$clusters" >/dev/null \
            || die 'The dedicated platform group contains an unexpected cluster. No resources will be adopted.'
        cluster="$(jq -c '.[0] // null' <<< "$clusters")"
        if [[ "$cluster" != null ]]; then
            assert_bootstrap_tags "$cluster"
            jq -e --arg group "$NODE_GROUP_NAME" --arg tenant "$(cfg TenantId)" '
                .nodeResourceGroup == $group and
                ((.aadProfile.tenantId // .aadProfile.tenantID // "") | ascii_downcase) == ($tenant | ascii_downcase)' \
                <<< "$cluster" >/dev/null || die 'The existing cluster has a different node group or Entra tenant.'
            jq -e --arg size "$NODE_VM_SIZE" '
                .agentPoolProfiles | length == 1 and .[0].name == "system" and .[0].vmSize == $size' \
                <<< "$cluster" >/dev/null || die 'This bootstrap does not migrate existing node pools. Reuse the original VM size and dedicated cluster.'
            [[ -z "$KUBERNETES_VERSION" || "$KUBERNETES_VERSION" == "$(jq -er .kubernetesVersion <<< "$cluster")" ]] \
                || die 'Manage Kubernetes upgrades separately; this bootstrap will not upgrade an existing cluster.'
        fi
    elif [[ "$exists" != false ]]; then die 'Azure returned an invalid resource-group existence result.'
    fi
    node_exists="$(azcmd group exists --name "$NODE_GROUP_NAME" --output tsv)"
    [[ "$node_exists" == true || "$node_exists" == false ]] || die 'Azure returned an invalid node-group existence result.'
    [[ "$node_exists" != true || "$cluster" != null ]] \
        || die 'The intended node resource group exists without this owned cluster. It will not be adopted.'
    printf '%s\n' "$cluster"
}

assert_bootstrap_stack() {
    local stacks stack details
    stacks="$(azcmd stack sub list \
        --query '[].{id:id,name:name,location:location,tags:tags,properties:{denySettings:properties.denySettings,actionOnUnmanage:properties.actionOnUnmanage,resources:properties.resources},denySettings:denySettings,actionOnUnmanage:actionOnUnmanage,resources:resources}' \
        --output json)"
    stacks="$(jq -c --arg name "$GROUP_NAME" '[.[] | select((.name | ascii_downcase) == ($name | ascii_downcase))]' <<< "$stacks")"
    [[ "$(jq -er length <<< "$stacks")" != 0 ]] || return 0
    [[ "$(jq -er length <<< "$stacks")" == 1 ]] || die 'The target deployment stack is ambiguous.'
    stack="$(jq -c '.[0]' <<< "$stacks")"
    assert_bootstrap_tags "$stack"
    jq -e --arg id "$STACK_ID" --arg location "$(cfg Location)" '
        (.id | ascii_downcase) == ($id | ascii_downcase) and .location == $location' <<< "$stack" >/dev/null \
        || die 'The existing stack scope/location differs.'
    details="$(jq -c 'if (.properties.denySettings | type) == "object" then .properties else . end' <<< "$stack")"
    jq -e '
        (.denySettings.mode | ascii_downcase) == "none" and
        .actionOnUnmanage.resources == "detach" and .actionOnUnmanage.resourceGroups == "detach" and
        .actionOnUnmanage.managementGroups == "detach"' <<< "$details" >/dev/null \
        || die 'The existing stack deny/unmanage policies differ. They will not be overwritten.'
    jq -e --arg group "/subscriptions/$(cfg SubscriptionId)/resourceGroups/$GROUP_NAME" '
        ($group | ascii_downcase) as $group |
        (.resources | if . == null then [] else . end) |
        all(.[]; (.id | ascii_downcase) as $id | $id == $group or ($id | startswith($group + "/")))' \
        <<< "$details" >/dev/null || die 'The stack manages resources outside the dedicated platform group. Review it before changing management.'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --api-server-cidr|--admin-object-id|--admin-principal-type|--node-vm-size|--kubernetes-version)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || die "Supply a value after $1."
            case "$1" in
                --api-server-cidr) API_CIDR=$2 ;;
                --admin-object-id) ADMIN_OBJECT_ID=$2 ;;
                --admin-principal-type) ADMIN_TYPE=$2 ;;
                --node-vm-size) NODE_VM_SIZE=$2 ;;
                --kubernetes-version) KUBERNETES_VERSION=$2 ;;
            esac
            shift ;;
        --deploy) DEPLOY=true ;;
        --use-deployment-stack) USE_DEPLOYMENT_STACK=true ;;
        --yes) YES=true ;;
        --help|-h) usage_infrastructure; exit 0 ;;
        *) die "Unknown option: $1. Use --help." ;;
    esac
    shift
done
assert_bootstrap_cidr
case "$ADMIN_TYPE" in User|Group|ServicePrincipal) ;; *) die 'Administrator type must be User, Group, or ServicePrincipal.' ;; esac
case "$NODE_VM_SIZE" in Standard_D4s_v5|Standard_D4as_v5|Standard_D4s_v6) ;; *) die 'Choose an allowed four-vCPU AMD64 VM size; see --help.' ;; esac
[[ -z "$KUBERNETES_VERSION" || "$KUBERNETES_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'Kubernetes version must be X.Y.Z or omitted.'
[[ -n "$ADMIN_OBJECT_ID" || "$ADMIN_TYPE" == User ]] || die 'Supply --admin-object-id for a Group or ServicePrincipal.'
[[ -z "$ADMIN_OBJECT_ID" || "$ADMIN_OBJECT_ID" =~ ^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ ]] \
    || die 'Administrator object ID must be a GUID in the resource tenant, not an application/client ID.'
initialize_demo_cli
need az; need bicep
bicep --version
if [[ "$USE_DEPLOYMENT_STACK" == true ]]; then
    AZURE_EXTENSION_USE_DYNAMIC_INSTALL=no command az stack-whatif sub create --help >/dev/null \
        || die 'Stacks mode needs a working az stack-whatif sub create command. Inspect the CLI diagnostic; no tools were installed.'
fi
load_config
assert_azure_context
assert_saved_config
assert_identity_scope optional >/dev/null
initialize_state
OWNER_ID="$(owner_id)"
[[ "$OWNER_ID" =~ ^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$ ]] || die 'Invalid saved ownership marker; preserve it for recovery.'
GROUP_NAME="$(cfg Prefix)-platform"
CLUSTER_NAME="$(cfg Prefix)-aks"
NODE_GROUP_NAME="$(cfg Prefix)-aks-nodes"
RECEIPT="$STATE/azure-infrastructure.json"
DEPLOYMENT_MODE=deployment
[[ "$USE_DEPLOYMENT_STACK" != true ]] || DEPLOYMENT_MODE=stack
STACK_ID="/subscriptions/$(cfg SubscriptionId)/providers/Microsoft.Resources/deploymentStacks/$GROUP_NAME"

if [[ -z "$ADMIN_OBJECT_ID" ]]; then
    [[ "$(azcmd account show --query user.type --output tsv)" == user ]] \
        || die 'For a non-user Azure login, supply --admin-object-id and --admin-principal-type explicitly.'
    principal="$(azcmd ad signed-in-user show --query '{id:id}' --output json)"
else
    case "$ADMIN_TYPE" in User) kind=user ;; Group) kind=group ;; ServicePrincipal) kind=sp ;; esac
    principal="$(azcmd ad "$kind" show --id "$ADMIN_OBJECT_ID" --query '{id:id}' --output json)"
fi
jq -e --arg requested "$ADMIN_OBJECT_ID" '
    (.id | type == "string" and test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$")) and
    ($requested == "" or (.id | ascii_downcase) == ($requested | ascii_downcase))' <<< "$principal" >/dev/null \
    || die 'The administrator object could not be verified in the resource tenant.'
ADMIN_OBJECT_ID="$(jq -er .id <<< "$principal")"
if [[ -f "$RECEIPT" ]]; then
    saved_mode="$(jq -er 'if has("deploymentMode") then .deploymentMode else "deployment" end' "$RECEIPT")"
    case "$saved_mode" in deployment|stack) ;; *) die 'Saved infrastructure has an unknown deployment mode.' ;; esac
    if [[ "$saved_mode" == stack ]]; then
        [[ "$USE_DEPLOYMENT_STACK" == true ]] || die 'Saved infrastructure is stack-managed. Reuse --use-deployment-stack; do not switch engines implicitly.'
        jq -e --arg id "$STACK_ID" '(.stackId | ascii_downcase) == ($id | ascii_downcase)' "$RECEIPT" >/dev/null \
            || die 'Saved stack scope differs. Preserve the original state/configuration.'
    fi
    jq -e --arg tenant "$(cfg TenantId)" --arg subscription "$(cfg SubscriptionId)" --arg owner "$OWNER_ID" \
        --arg group "$GROUP_NAME" --arg admin "$ADMIN_OBJECT_ID" --arg type "$ADMIN_TYPE" '
        (.tenantId | ascii_downcase) == ($tenant | ascii_downcase) and
        (.subscriptionId | ascii_downcase) == ($subscription | ascii_downcase) and
        .ownerId == $owner and .resourceGroupName == $group and
        (.adminObjectId | ascii_downcase) == ($admin | ascii_downcase) and .adminPrincipalType == $type' \
        "$RECEIPT" >/dev/null || die 'Saved infrastructure scope/administrator differs. Preserve state; changing administrators needs a reviewed RBAC migration.'
fi
if [[ "$USE_DEPLOYMENT_STACK" == true ]]; then assert_bootstrap_stack; fi
cluster="$(owned_bootstrap_cluster)"
effective_version="$KUBERNETES_VERSION"
if [[ "$cluster" != null ]]; then effective_version="$(jq -er .kubernetesVersion <<< "$cluster")"; fi
node_availability_zones="$(jq -ce '
    .agentPoolProfiles[0].availabilityZones |
    if . == null then []
    elif type == "array" and all(.[]; tostring | test("^[1-9][0-9]*$")) then map(tonumber)
    else error("Existing node-pool zones must be positive numeric IDs. Zone migration needs separate management.")
    end' <<< "$cluster")"
missing=false
for provider in Microsoft.ContainerService Microsoft.Compute Microsoft.Network Microsoft.ManagedIdentity Microsoft.ContainerInstance Microsoft.DBforPostgreSQL; do
    registration="$(azcmd provider show --namespace "$provider" --query registrationState --output tsv)"
    if [[ "$registration" != Registered ]]; then
        missing=true
        printf 'Register (%s): az provider register --namespace %q --subscription %q --wait\n' "$registration" "$provider" "$(cfg SubscriptionId)"
    fi
done
[[ "$missing" == false ]] || die 'Register the listed providers with an authorized account, then rerun. Providers are never registered automatically.'

PARAM_FILE="$STATE/azure-infrastructure.parameters.json"
TEMPLATE="$STATE/azure-infrastructure.template.json"
json_write "$PARAM_FILE" -n --argjson config "$CONFIG" --arg owner "$OWNER_ID" --arg admin "$ADMIN_OBJECT_ID" \
    --arg type "$ADMIN_TYPE" --arg cidr "$API_CIDR" --arg size "$NODE_VM_SIZE" --arg version "$effective_version" \
    --argjson zones "$node_availability_zones" '{
    "$schema":"https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
    contentVersion:"1.0.0.0", parameters: {
        prefix:{value:$config.Prefix}, location:{value:$config.Location}, tenantId:{value:$config.TenantId},
        ownerId:{value:$owner}, adminObjectId:{value:$admin}, adminPrincipalType:{value:$type},
        apiServerAllowedCidr:{value:$cidr}, nodeVmSize:{value:$size}, nodeAvailabilityZones:{value:$zones},
        kubernetesVersion:{value:$version}
    }}'
# Compiled JSON avoids an implicit Azure CLI Bicep installation.
bicep build "$ROOT/infra/main.bicep" --outfile "$TEMPLATE"
info "Tenant $(cfg TenantId) | Subscription $(cfg SubscriptionId) | $(cfg Location)"
info "$GROUP_NAME / $CLUSTER_NAME | 2 x $NODE_VM_SIZE | API $API_CIDR"
if [[ "$node_availability_zones" == '[]' ]]; then info 'Node placement: regional (non-zonal)'
else info "Node placement: zones $(jq -r 'map(tostring) | join(", ")' <<< "$node_availability_zones")"
fi
info "Cluster administrator: $ADMIN_TYPE $ADMIN_OBJECT_ID (resource tenant)."
info 'AKS Free refers to the control plane only. Nodes, disks, load balancer and outbound traffic are billed.'
template_args=(--location "$(cfg Location)" --template-file "$TEMPLATE" --parameters "@$PARAM_FILE")
deployment_args=(--name "$GROUP_NAME" "${template_args[@]}")
PREVIEW_ID=''
if [[ "$USE_DEPLOYMENT_STACK" == true ]]; then
    stack_args=("${template_args[@]}" --action-on-unmanage detachAll --deny-settings-mode none --validation-level Provider
        --tags "radiusDemoOwner=$OWNER_ID" "radiusDemoTenant=$(cfg TenantId)" radiusDemoPurpose=aks-bootstrap)
    preview_name="$GROUP_NAME-preview-$(openssl rand -hex 6)"
    PREVIEW_ID="/subscriptions/$(cfg SubscriptionId)/providers/Microsoft.Resources/deploymentStacksWhatIfResults/$preview_name"
    info 'Stacks mode: creating a stored Azure preview result (expires after three hours); infrastructure is not deployed.'
    azcmd stack-whatif sub create --name "$preview_name" --stack-id "$STACK_ID" --retention-interval PT3H "${stack_args[@]}"
    json_write "$STATE/azure-infrastructure-preview.json" -n --argjson config "$CONFIG" --arg owner "$OWNER_ID" \
        --arg stack "$STACK_ID" --arg preview "$PREVIEW_ID" --arg time "$(stamp)" '{
        schemaVersion:1,tenantId:$config.TenantId,subscriptionId:$config.SubscriptionId,ownerId:$owner,
        stackId:$stack,previewId:$preview,retentionInterval:"PT3H",createdAt:$time}'
    info "Stored preview: $PREVIEW_ID"
else
    azcmd deployment sub what-if "${deployment_args[@]}"
fi
if [[ "$DEPLOY" != true ]]; then
    if [[ "$USE_DEPLOYMENT_STACK" == true ]]; then
        info 'Preview only. Only preview metadata was created; no stack or AKS resources were deployed. Retain all options and add --deploy to apply.'
    else info 'Preview only. No Azure resources were created. Rerun with the same options and --deploy to request creation.'
    fi
    exit 0
fi
confirm "Deploy/update the dedicated two-node AKS host and administrator roles using $DEPLOYMENT_MODE management in $(cfg TenantId)/$(cfg SubscriptionId)/$GROUP_NAME?" || exit 0
assert_azure_context
owned_bootstrap_cluster >/dev/null
if [[ "$USE_DEPLOYMENT_STACK" == true ]]; then assert_bootstrap_stack; fi
json_write "$STATE/setup-config.json" -n --argjson config "$CONFIG" '$config'
json_write "$RECEIPT" -n --argjson config "$CONFIG" --arg owner "$OWNER_ID" --arg group "$GROUP_NAME" \
    --arg cluster "$CLUSTER_NAME" --arg nodes "$NODE_GROUP_NAME" --arg admin "$ADMIN_OBJECT_ID" --arg type "$ADMIN_TYPE" \
    --arg size "$NODE_VM_SIZE" --arg cidr "$API_CIDR" --arg time "$(stamp)" --argjson zones "$node_availability_zones" \
    --arg mode "$DEPLOYMENT_MODE" --arg stack "$STACK_ID" --arg preview "$PREVIEW_ID" '{
    schemaVersion:1, status:"deploying", tenantId:$config.TenantId, subscriptionId:$config.SubscriptionId,
    ownerId:$owner, resourceGroupName:$group, clusterName:$cluster, nodeResourceGroupName:$nodes,
    adminObjectId:$admin, adminPrincipalType:$type, nodeVmSize:$size, nodeAvailabilityZones:$zones,
    apiServerAllowedCidr:$cidr, updatedAt:$time,deploymentMode:$mode,
    stackId:(if $mode == "stack" then $stack else null end),previewId:(if $preview == "" then null else $preview end)}'
if [[ "$USE_DEPLOYMENT_STACK" == true ]]; then
    deployed_stack="$(azcmd stack sub create --name "$GROUP_NAME" "${stack_args[@]}" --yes \
        --query '{id:id,properties:{provisioningState:properties.provisioningState,outputs:properties.outputs},provisioningState:provisioningState,outputs:outputs}' --output json)"
    deployed_stack="$(jq -c 'if .properties.provisioningState != null then
        .provisioningState = .properties.provisioningState | .outputs = .properties.outputs else . end' <<< "$deployed_stack")"
    jq -e --arg id "$STACK_ID" '
        (.id | ascii_downcase) == ($id | ascii_downcase) and (.provisioningState | ascii_downcase) == "succeeded"' \
        <<< "$deployed_stack" >/dev/null || die 'The deployment stack did not report success in the expected scope. Preserve the receipt.'
    outputs="$(jq -ce .outputs <<< "$deployed_stack")"
else
    outputs="$(azcmd deployment sub create "${deployment_args[@]}" --query properties.outputs --output json)"
fi
jq -e --arg cluster "$CLUSTER_NAME" --arg group "$GROUP_NAME" '
    .clusterName.value == $cluster and .resourceGroupName.value == $group and
    (.clusterId.value | type == "string" and length > 0)' <<< "$outputs" >/dev/null \
    || die 'Deployment returned unexpected outputs; inspect the deployment and saved receipt.'
json_write "$RECEIPT" --argjson outputs "$outputs" --arg time "$(stamp)" \
    '.status = "deployed" | .outputs = $outputs | .updatedAt = $time' "$RECEIPT"
info 'Azure host deployed. Kubeconfig and Radius were not changed. Keep this Azure tenant/profile active.'
printf 'az aks get-credentials --subscription %q --resource-group %q --name %q --context %q\n' \
    "$(cfg SubscriptionId)" "$GROUP_NAME" "$CLUSTER_NAME" "$(cfg AksContext)"
printf 'kubelogin convert-kubeconfig --login azurecli --context %q --azure-config-dir %q\n' \
    "$(cfg AksContext)" "${AZURE_CONFIG_DIR:-$HOME/.azure}"
printf 'kubectl --context %q get nodes\n' "$(cfg AksContext)"
info "# Using Radius CLI $(required_radius), only if Radius is not installed on this dedicated cluster:"
printf 'rad install kubernetes --kubecontext %q\n' "$(cfg AksContext)"
info 'bash ./scripts/Check-Prerequisites.sh --check-clusters'
info 'Then run 00-prepare.sh. Existing 99-cleanup does not delete this AKS host; see the separate README cleanup.'
