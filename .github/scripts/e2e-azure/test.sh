#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
metadata="$repo_root/.github/e2e/azure-samples.json"
scripts="$repo_root/.github/scripts/e2e-azure"
workflow="$repo_root/.github/workflows/e2e-azure.yaml"

all="$("$scripts/prepare-matrix.sh" "$metadata" all)"
[[ "$(jq '.include | length' <<<"$all")" == "10" ]]
single="$("$scripts/prepare-matrix.sh" "$metadata" kafka-ui)"
[[ "$(jq -r '.include[0].name' <<<"$single")" == "kafka-ui" ]]
if "$scripts/prepare-matrix.sh" "$metadata" does-not-exist >/dev/null 2>&1; then
  echo "prepare-matrix accepted an unknown sample" >&2
  exit 1
fi

config="$("$scripts/configure-sample.sh" "$metadata" drakkan-sftpgo 123 2)"
name="$(sed -n 's/^unique_name=//p' <<<"$config")"
[[ "$name" =~ ^[a-z0-9]+$ ]]
(( ${#name} <= 24 ))

config="$("$scripts/configure-sample.sh" "$metadata" mongo-express-mongo-express 123 2)"
unique="$(sed -n 's/^unique_name=//p' <<<"$config")"
resource="$(sed -n 's/^resource_name=//p' <<<"$config")"
[[ "$unique" == "$resource" ]]

grep -Fq 'default: ffc2344fc42366581090539346d68a831862cb7d' "$workflow"
grep -Fq 'default: cf57799dfa1cf3ff64db767555d78d0bb3266eb3' "$workflow"
if grep -Eq 'build_radius_images|radius_image_(registry|tag|contrib_ref)|prebuilt' "$workflow"; then
  echo "Unverifiable prebuilt Radius image mode must not be present" >&2
  exit 1
fi
grep -Fq "radius-e2e-control-plane-\${GITHUB_RUN_ID}-\${GITHUB_RUN_ATTEMPT}" "$workflow"
grep -Fq "radius-e2e-samples-\${GITHUB_RUN_ID}-\${GITHUB_RUN_ATTEMPT}" "$workflow"
grep -Fq "containerImagesRegistry=\$SAMPLE_IMAGE_REGISTRY" "$workflow"
if grep -Fq "containerImagesRegistry=\$CONTROL_PLANE_REGISTRY" "$workflow"; then
  echo "Sample image builds must not use the control-plane registry" >&2
  exit 1
fi

export E2E_AZURE_SMOKE_TEST_SOURCE_ONLY=true
# shellcheck source=.github/scripts/e2e-azure/smoke-test.sh
source "$scripts/smoke-test.sh"
unset E2E_AZURE_SMOKE_TEST_SOURCE_ONLY

[[ "$(sqlpad_connection_id <<<'[{"id":"connection-1","name":"Azure SQL"}]')" == "connection-1" ]]
[[ "$(sqlpad_connection_id <<<'{"connections":[{"id":"connection-2","name":"Azure SQL"}]}')" == "connection-2" ]]
[[ "$(sqlpad_connection_id <<<'{"data":[{"id":"connection-3","name":"Azure SQL"}]}')" == "connection-3" ]]
if sqlpad_connection_id <<<'{"unexpected":[]}' >/dev/null 2>&1; then
  echo "SQLPad connection parser accepted an unexpected response shape" >&2
  exit 1
fi

# shellcheck disable=SC2329
curl() {
  local arg payload="" url=""
  for arg in "$@"; do
    [[ "$arg" == http://* ]] && url="$arg"
  done
  for ((i = 1; i <= $#; i++)); do
    if [[ "${!i}" == "-d" ]]; then
      ((i++))
      payload="${!i}"
    fi
  done

  case "$url" in
    http://sqlpad/api/batches)
      jq -e '.connectionId == "connection-1" and
        .batchText == "SELECT 1 AS radius_e2e" and
        (has("queryText") | not)' <<<"$payload" >/dev/null
      printf '{"id":"batch-1","status":"started"}\n'
      ;;
    http://sqlpad/api/batches/batch-1)
      if [[ "${SQLPAD_FIXTURE_MODE:-success}" == "error" ]]; then
        printf '{"id":"batch-1","status":"error","error":{"title":"fixture failure"}}\n'
      else
        printf '{"id":"batch-1","status":"finished"}\n'
      fi
      ;;
    http://sqlpad/api/batches/batch-1/statements)
      printf '[{"id":"statement-1","status":"finished","columns":[{"name":"radius_e2e"}]}]\n'
      ;;
    http://sqlpad/api/statements/statement-1/results)
      printf '[[1]]\n'
      ;;
    *)
      echo "Unexpected SQLPad fixture URL: $url" >&2
      return 1
      ;;
  esac
}

SQLPAD_FIXTURE_MODE=success smoke_sqlpad http://sqlpad connection-1
sqlpad_error_log="${TMPDIR:-/tmp}/sqlpad-error-fixture-$$.log"
if SQLPAD_FIXTURE_MODE=error smoke_sqlpad http://sqlpad connection-1 \
  >"$sqlpad_error_log" 2>&1; then
  echo "SQLPad error fixture unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq "SQLPad batch failed with status 'error'" \
  "$sqlpad_error_log"
rm "$sqlpad_error_log"
unset -f curl

echo "e2e-azure script tests passed"
