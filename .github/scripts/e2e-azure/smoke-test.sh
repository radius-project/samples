#!/usr/bin/env bash
set -euo pipefail

smoke_sqlpad() {
  local base_url="${1:?SQLPad base URL is required}"
  local connection_id="${2:?SQLPad connection ID is required}"
  local batch batch_id status statements statement_id statement_status results

  # SQLPad v7.5.7 API contract:
  # server/routes/batches.js and server/routes/statements.js at
  # ab1f0c03269f0178b9449d34505ce3462271f340.
  batch="$(curl --fail --silent "$base_url/api/batches" \
    -H 'Content-Type: application/json' \
    -d "{\"connectionId\":\"$connection_id\",\"batchText\":\"SELECT 1 AS radius_e2e\"}")"
  batch_id="$(jq -er '.id' <<<"$batch")"

  for _ in {1..60}; do
    batch="$(curl --fail --silent "$base_url/api/batches/$batch_id")"
    status="$(jq -r '.status' <<<"$batch")"
    case "$status" in
      finished)
        statements="$(curl --fail --silent "$base_url/api/batches/$batch_id/statements")"
        statement_status="$(jq -r '.[0].status' <<<"$statements")"
        if [[ "$statement_status" == "finished" ]]; then
          statement_id="$(jq -er '.[0].id' <<<"$statements")"
          results="$(curl --fail --silent "$base_url/api/statements/$statement_id/results")"
          jq -e '(.[0][0] | tostring) == "1"' <<<"$results" >/dev/null
          return 0
        fi
        if [[ "$statement_status" =~ ^(error|errored|failed|cancelled)$ ]]; then
          echo "SQLPad statement failed with status '$statement_status': $statements" >&2
          return 1
        fi
        ;;
      error|errored|failed|cancelled)
        echo "SQLPad batch failed with status '$status': $batch" >&2
        return 1
        ;;
    esac
    sleep 5
  done

  echo "SQLPad batch did not complete: $batch" >&2
  return 1
}

sqlpad_connection_id() {
  jq -er '
    (if type == "array" then .
     elif (.connections? | type) == "array" then .connections
     elif (.data? | type) == "array" then .data
     else error("unexpected SQLPad connections response")
     end)
    | map(select(.name == "Azure SQL"))[0].id
  '
}

if [[ "${E2E_AZURE_SMOKE_TEST_SOURCE_ONLY:-false}" == "true" ]]; then
  return 0
fi

metadata="${1:-.github/e2e/azure-samples.json}"
sample="${2:?sample is required}"
resource_group="${3:?resource group is required}"
unique_name="${4:?unique Azure name is required}"

entry="$(jq -ce --arg sample "$sample" '.samples[] | select(.name == $sample)' "$metadata")"
resource_type="$(jq -r '.resourceType' <<<"$entry")"
resource_name="$(jq -r --arg unique "$unique_name" \
  'if .resourceNameFromUniqueName then $unique else .resourceName end' <<<"$entry")"
azure_resource="$(jq -r '.azureResource' <<<"$entry")"
app_name="$(jq -r '.appName' <<<"$entry")"
port="$(jq -r '.containerPort' <<<"$entry")"
smoke="$(jq -r '.smoke' <<<"$entry")"

radius_json="$(rad resource show "$resource_type" "$resource_name" -o json)"
jq -e '.properties | type == "object"' <<<"$radius_json" >/dev/null
case "$smoke" in
  kafka-ui|bento) jq -e '.properties.host and .properties.secrets.name' <<<"$radius_json" >/dev/null ;;
  litellm|mongo-express|search-api) jq -e '.properties.endpoint and .properties.secrets.name' <<<"$radius_json" >/dev/null ;;
  todo|pgweb|sqlpad) jq -e '.properties.host' <<<"$radius_json" >/dev/null ;;
  redis-demo) jq -e '.properties.host and .properties.port and .properties.secrets.name' <<<"$radius_json" >/dev/null ;;
  sftpgo) jq -e '.properties.endpoint and .properties.accountName and .properties.secrets.name' <<<"$radius_json" >/dev/null ;;
  *) echo "Unsupported Radius output verifier: $smoke" >&2; exit 1 ;;
esac

case "$azure_resource" in
  eventhubs) az eventhubs namespace show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  cognitiveservices) az cognitiveservices account show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  cosmosdb) az cosmosdb show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  mysql) az mysql flexible-server show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  postgresql) az postgres flexible-server show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  servicebus) az servicebus namespace show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  redis) az resource show -g "$resource_group" -n "$unique_name" --resource-type Microsoft.Cache/redisEnterprise >/dev/null ;;
  sql) az sql server show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  search) az search service show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  storage) az storage account show -g "$resource_group" -n "$unique_name" >/dev/null ;;
  *) echo "Unsupported Azure resource verifier: $azure_resource" >&2; exit 1 ;;
esac

if [[ "$smoke" == "bento" ]]; then
  namespace="$(kubectl get pods -A -l "radapp.io/application=$app_name" \
    -o jsonpath='{.items[0].metadata.namespace}')"
  pod="$(kubectl get pods -n "$namespace" -l "radapp.io/application=$app_name" \
    -o jsonpath='{.items[0].metadata.name}')"
  for _ in {1..24}; do
    if kubectl logs -n "$namespace" "$pod" -c consumer --tail=100 | grep -q '"message":"radius-bento"'; then
      exit 0
    fi
    sleep 5
  done
  echo "Bento consumer did not log the producer marker" >&2
  exit 1
fi

namespace="$(kubectl get pods -A -l "radapp.io/application=$app_name" \
  -o jsonpath='{.items[0].metadata.namespace}')"
pod="$(kubectl get pods -n "$namespace" -l "radapp.io/application=$app_name" \
  -o jsonpath='{.items[0].metadata.name}')"
kubectl wait -n "$namespace" --for=condition=Ready "pod/$pod" --timeout=10m
port_forward_pid=""
start_port_forward() {
  kubectl port-forward -n "$namespace" "pod/$pod" "${port}:${port}" \
    >"/tmp/${sample}-port-forward.log" 2>&1 &
  port_forward_pid=$!
}
start_port_forward
trap '[[ -n "${port_forward_pid:-}" ]] && kill "$port_forward_pid" 2>/dev/null || true' EXIT

base_url="http://127.0.0.1:${port}"
readiness_path="/"
case "$smoke" in
  litellm) readiness_path="/health/liveliness" ;;
  mongo-express) readiness_path="/status" ;;
  search-api) readiness_path="/healthz" ;;
esac
ready=false
for _ in {1..60}; do
  if ! kill -0 "$port_forward_pid" 2>/dev/null; then
    start_port_forward
  fi
  if curl --fail --silent --show-error "$base_url$readiness_path" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
if [[ "$ready" != "true" ]]; then
  echo "Application did not become ready at $base_url$readiness_path" >&2
  cat "/tmp/${sample}-port-forward.log" >&2 || true
  kubectl logs -n "$namespace" "$pod" --all-containers --prefix --tail=200 >&2 || true
  exit 1
fi

case "$smoke" in
  kafka-ui)
    curl --fail --silent "$base_url/api/clusters" |
      jq -e 'map(select(.name == "event-hubs")) | length == 1' >/dev/null
    curl --fail --silent "$base_url/api/clusters/event-hubs/topics" | grep -q events
    ;;
  litellm)
    curl --fail-with-body --silent --show-error "$base_url/v1/chat/completions" \
      -H 'Authorization: Bearer sk-radius-verify' \
      -H 'Content-Type: application/json' \
      -d '{"model":"chat","messages":[{"role":"user","content":"Reply with radius"}],"max_tokens":16}' |
      jq -e '.choices[0].message.content | length > 0' >/dev/null
    ;;
  mongo-express)
    curl --fail --silent "$base_url/status" |
      jq -e '.status == "ok"' >/dev/null
    ! kubectl logs -n "$namespace" "$pod" --all-containers --tail=200 |
      grep -Eqi 'connection (error|failed)|ECONNREFUSED|MongoServerSelectionError'
    ;;
  todo)
    marker="radius-${GITHUB_RUN_ID:-local}"
    curl --fail --silent "$base_url/api/items" -H 'Content-Type: application/json' \
      -d "{\"name\":\"$marker\"}" >/dev/null
    curl --fail --silent "$base_url/api/items" | jq -e --arg marker "$marker" \
      'map(select(.name == $marker)) | length > 0' >/dev/null
    ;;
  pgweb)
    curl --fail --silent "$base_url/api/query" \
      --data-urlencode 'query=SELECT 1 AS radius_e2e' | grep -q radius_e2e
    ;;
  redis-demo)
    marker="radius-${GITHUB_RUN_ID:-local}"
    curl --fail --silent "$base_url/api/todos" -H 'Content-Type: application/json' \
      -d "{\"title\":\"$marker\"}" >/dev/null
    curl --fail --silent "$base_url/api/todos" |
      jq -e --arg marker "$marker" '.items | map(select(.title == $marker)) | length > 0' >/dev/null
    ;;
  sqlpad)
    connection_id="$(curl --fail --silent "$base_url/api/connections" |
      sqlpad_connection_id)"
    test -n "$connection_id"
    smoke_sqlpad "$base_url" "$connection_id"
    ;;
  search-api)
    curl --fail --silent "$base_url/healthz" >/dev/null
    marker="radius-${GITHUB_RUN_ID:-local}"
    curl --fail --silent "$base_url/documents" -H 'Content-Type: application/json' \
      -d "{\"id\":\"$marker\",\"content\":\"manual azure e2e\"}" >/dev/null
    for _ in {1..30}; do
      curl --fail --silent "$base_url/search?q=manual" | grep -q "$marker" && exit 0
      sleep 5
    done
    exit 1
    ;;
  sftpgo)
    curl --fail --silent "$base_url/healthz" >/dev/null
    namespace="$(kubectl get pods -A -l "radapp.io/application=$app_name" -o jsonpath='{.items[0].metadata.namespace}')"
    kubectl port-forward -n "$namespace" "pod/$pod" 2022:2022 >/tmp/sftpgo-sftp.log 2>&1 &
    sftp_pid=$!
    trap 'kill "$port_forward_pid" "$sftp_pid" 2>/dev/null || true' EXIT
    printf 'radius-e2e\n' >/tmp/radius-e2e.txt
    sshpass -p 'radius-verify-Pass1!' sftp -P 2022 \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null radius@127.0.0.1 \
      <<< $'put /tmp/radius-e2e.txt radius-e2e.txt\nget radius-e2e.txt /tmp/radius-e2e.out'
    cmp /tmp/radius-e2e.txt /tmp/radius-e2e.out
    ! kubectl logs -n "$namespace" "$pod" --tail=200 | grep -Eqi 'blob.*(error|failed)'
    ;;
  *) echo "Unsupported smoke test: $smoke" >&2; exit 1 ;;
esac
