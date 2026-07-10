#!/usr/bin/env bash
set -euo pipefail

metadata="${1:-.github/e2e/azure-samples.json}"
selection="${2:-all}"

jq -e '.samples | type == "array" and length == 10' "$metadata" >/dev/null

if [[ "$selection" == "all" ]]; then
  jq -c '{include: [.samples[] | {name, path}]}' "$metadata"
else
  jq -ce --arg sample "$selection" \
    '{include: [.samples[] | select(.name == $sample) | {name, path}]} |
     if (.include | length) == 1 then . else error("unknown sample: \($sample)") end' \
    "$metadata"
fi
