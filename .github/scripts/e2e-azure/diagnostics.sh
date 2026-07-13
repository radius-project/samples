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
  echo "=== Kubernetes pod details ==="
  kubectl describe pods -A || true
  echo "=== Radius control-plane logs ==="
  kubectl logs -n radius-system --all-containers --prefix \
    -l app.kubernetes.io/part-of=radius --tail=-1 || true
  echo "=== Previous Radius container logs ==="
  while IFS=$'\t' read -r pod container restarts; do
    [[ "${restarts:-0}" -gt 0 ]] || continue
    kubectl logs -n radius-system "$pod" -c "$container" --previous --prefix --tail=-1 || true
  done < <(kubectl get pods -n radius-system -o json |
    jq -r '.items[] | .metadata.name as $pod |
      (.status.containerStatuses // [])[] |
      [$pod, .name, .restartCount] | @tsv' 2>/dev/null || true)
  echo "=== Application logs ==="
  while IFS=$'\t' read -r namespace pod; do
    [[ -n "$namespace" && -n "$pod" ]] || continue
    kubectl logs -n "$namespace" "$pod" --all-containers --prefix --tail=-1 || true
  done < <(kubectl get pods -A -l radapp.io/application \
    -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}' \
    2>/dev/null || true)
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
