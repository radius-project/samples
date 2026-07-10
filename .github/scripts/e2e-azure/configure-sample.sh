#!/usr/bin/env bash
set -euo pipefail

metadata="${1:-.github/e2e/azure-samples.json}"
sample="${2:?sample is required}"
run_id="${3:?run id is required}"
run_attempt="${4:?run attempt is required}"

entry="$(jq -ce --arg sample "$sample" '.samples[] | select(.name == $sample)' "$metadata")"
suffix="$(printf '%s' "${run_id}-${run_attempt}-${sample}" | sha256sum | cut -c1-12)"
prefix="$(jq -r '.uniqueNamePrefix' <<<"$entry")"
max_length="$(jq -r '.uniqueNameMaxLength' <<<"$entry")"
unique_name="${prefix}-${suffix}"
if [[ "$(jq -r '.uniqueNameNoHyphens // false' <<<"$entry")" == "true" ]]; then
  unique_name="${unique_name//-/}"
fi
unique_name="${unique_name:0:max_length}"

resource_name="$(jq -r --arg unique "$unique_name" \
  'if .resourceNameFromUniqueName then $unique else .resourceName end' <<<"$entry")"
resource_group="radius-e2e-${run_id}-${run_attempt}-${sample}"
resource_group="${resource_group:0:90}"

write_output() {
  printf '%s=%s\n' "$1" "$2"
}

write_output sample "$sample"
write_output sample_path "$(jq -r '.path' <<<"$entry")"
write_output resource_type "$(jq -r '.resourceType' <<<"$entry")"
write_output resource_name "$resource_name"
write_output provider "$(jq -r '.provider' <<<"$entry")"
write_output azure_resource "$(jq -r '.azureResource' <<<"$entry")"
write_output unique_name_parameter "$(jq -r '.uniqueNameParameter' <<<"$entry")"
write_output unique_name "$unique_name"
write_output needs_client_ip "$(jq -r '.needsClientIp // false' <<<"$entry")"
write_output app_name "$(jq -r '.appName' <<<"$entry")"
write_output app_parameters "$(jq -c '.appParameters' <<<"$entry")"
write_output container_resource "$(jq -r '.containerResource' <<<"$entry")"
write_output container_port "$(jq -r '.containerPort' <<<"$entry")"
write_output smoke "$(jq -r '.smoke' <<<"$entry")"
write_output resource_group "$resource_group"
