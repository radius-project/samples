#!/usr/bin/env bash
# Tenant-level `az ad` uses the active account and does not accept --subscription.
azure_account_matches() {
    local tenant=$1 subscription=$2 account=$3
    jq -e --arg tenant "$tenant" --arg subscription "$subscription" '
        (.id | ascii_downcase) == ($subscription | ascii_downcase) and
        (.tenantId | ascii_downcase) == ($tenant | ascii_downcase) and .state == "Enabled"' <<< "$account" >/dev/null
}

check_azure_scope() {
    local tenant=$1 subscription=$2 selected active
    if ! selected="$(command az account show --subscription "$subscription" --output json)"; then
        printf '%s\n' 'Cannot verify the configured Azure subscription. Inspect the Azure CLI diagnostic before continuing.' >&2
        return 1
    fi
    if ! azure_account_matches "$tenant" "$subscription" "$selected"; then
        printf '%s\n' 'SubscriptionId must be enabled and belong to TenantId, the resource directory rather than a guest home tenant.' >&2
        return 1
    fi
    if ! active="$(command az account show --output json)"; then
        printf '%s\n' 'Cannot verify the active Azure account for Microsoft Graph operations.' >&2
        return 1
    fi
    if ! azure_account_matches "$tenant" "$subscription" "$active"; then
        printf '%s\n' 'The active Azure account does not match the configured tenant/subscription. No account switch was performed.' >&2
        printf 'Select it explicitly: az login --tenant %s; az account set --subscription %s\n' "$tenant" "$subscription" >&2
        return 1
    fi
}
