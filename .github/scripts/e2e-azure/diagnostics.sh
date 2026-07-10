#!/usr/bin/env bash
set -euo pipefail

resource_group="${1:?resource group is required}"
sample="${2:?sample is required}"
output_dir="${3:-diagnostics}"
mkdir -p "$output_dir"

{
  echo "=== Radius resources ==="
  rad resource list -o json || true
  echo "=== Kubernetes pods ==="
  kubectl get pods -A -o wide || true
  echo "=== Kubernetes events ==="
  kubectl get events -A --sort-by=.lastTimestamp || true
  echo "=== Radius control-plane logs ==="
  kubectl logs -n radius-system --all-containers --prefix \
    -l app.kubernetes.io/part-of=radius --tail=-1 || true
  echo "=== Application logs ==="
  kubectl logs -A --all-containers --prefix \
    -l "radapp.io/application" --tail=-1 || true
  echo "=== Azure resources ==="
  az resource list --resource-group "$resource_group" -o json || true
  echo "=== ARM deployments ==="
  az deployment group list --resource-group "$resource_group" -o json || true
  while IFS= read -r deployment; do
    [[ -n "$deployment" ]] || continue
    echo "=== Failed ARM operations: $deployment ==="
    az deployment operation group list \
      --resource-group "$resource_group" \
      --name "$deployment" \
      --query "[?properties.provisioningState=='Failed']" -o json || true
  done < <(az deployment group list --resource-group "$resource_group" \
    --query '[].name' -o tsv 2>/dev/null || true)
} >"$output_dir/${sample}.log" 2>&1
