#!/usr/bin/env bash
set -euo pipefail
work=$1
evidence=$2
: "${POSTGRESQL_TEST_CONTEXT:?Expected owned test context.}"
[[ "$(kubectl config current-context)" == "$POSTGRESQL_TEST_CONTEXT" ]]
[[ "$(kubectl get namespace radius-tutorial -o jsonpath='{.metadata.labels.samples\.radius\.io/test}')" == postgresql-tls ]]
params="$work/prepared/parameters.json"

server_identity() {
  kubectl get secret postgresql-tutorial-tls -n radius-tutorial -o json |
    python3 -c 'import hashlib,json,sys; s=json.load(sys.stdin); print(s["metadata"]["uid"], hashlib.sha256(json.dumps(s["data"],sort_keys=True).encode()).hexdigest())'
}

delete_and_verify() {
  rad app delete demo-tutorial --preview -y
  [[ "$(server_identity)" == "$identity" ]]
  [[ -z "$(kubectl get secret postgresql-ca-tutorial -n radius-tutorial --ignore-not-found -o name)" ]]
}

identity=$(server_identity)
printf '%s\n' "$identity" > "$evidence/operator-secret-before.txt"
delete_and_verify
echo "Application deletion removed CA and preserved operator Secret UID/data." | tee "$evidence/lifecycle.txt"
rad deploy "$work/prepared/omitted-policy.bicep" -p "@$params"
mkdir -p "$evidence/omitted"
cp "$evidence/expected-host.txt" "$evidence/omitted/expected-host.txt"
bash .github/test-fixtures/postgresql/verify-tls.sh "$work" "$evidence/omitted"
delete_and_verify
server_identity > "$evidence/operator-secret-after.txt"
cmp "$evidence/operator-secret-before.txt" "$evidence/operator-secret-after.txt"

# Only after the preservation assertion, deliberately damage this test-owned Secret.
for scenario in missing missing-key invalid-certificate; do
  kubectl delete secret postgresql-tutorial-tls -n radius-tutorial --ignore-not-found
  case "$scenario" in
    missing) ;;
    missing-key)
      kubectl create secret generic postgresql-tutorial-tls -n radius-tutorial \
        --from-file=tls.crt="$work/server.crt" ;;
    invalid-certificate)
      printf 'invalid test certificate\n' > "$work/invalid.crt"
      kubectl create secret generic postgresql-tutorial-tls -n radius-tutorial \
        --from-file=tls.crt="$work/invalid.crt" --from-file=tls.key="$work/server.key" ;;
  esac
  rad deploy samples/demo/app-postgresql.bicep -p "@$params"
  if kubectl rollout status deployment/postgresql-tutorial -n radius-tutorial --timeout=30s >/dev/null 2>&1; then
    echo "Database became ready with $scenario server material." >&2
    exit 1
  fi
  kubectl get pods -n radius-tutorial -l radapp.io/resource=postgresql-tutorial -o json > "$work/pods.json"
  if [[ "$scenario" == invalid-certificate ]]; then
    kubectl logs -n radius-tutorial deployment/postgresql-tutorial -c postgres > "$work/postgresql.log"
    grep -Eq 'could not load server certificate|Unable to load server certificate' "$work/postgresql.log"
  else
    pod_uid=$(jq -er '.items | select(length == 1) | .[0].metadata.uid' "$work/pods.json")
    kubectl get events -n radius-tutorial --field-selector "involvedObject.uid=$pod_uid" -o json |
      jq -e '.items[] | select(.reason == "FailedMount") | .message | contains("postgresql-tutorial-tls") or contains("tls.key")' >/dev/null
  fi
  echo "$scenario server material: database not Ready, expected failure verified." | tee -a "$evidence/server-rejections.txt"
  rad app delete demo-tutorial --preview -y
done
kubectl delete secret postgresql-tutorial-tls -n radius-tutorial
kubectl create secret tls postgresql-tutorial-tls -n radius-tutorial --cert="$work/server.crt" --key="$work/server.key"

baseline=ghcr.io/radius-project/kube-recipes/postgresqldatabases:18142182e52e19a46b0ed172037357e8e142dcd2
[[ "$(oras manifest fetch --descriptor "$baseline" | jq -er '.digest')" == sha256:ca65f43501f39fc31689e8a292e9e0e3179e4ebf7a89ec0143c12b4a1dc24ddd ]]
rad deploy samples/demo/postgresql-tls-pack.bicep \
  -p packName=tutorial-postgresql-tls -p "postgresqlRecipeSource=$baseline" \
  -p containerRecipeSource=sampleregistry:5000/postgresql-tls/containers:candidate \
  -p secretRecipeSource=sampleregistry:5000/postgresql-tls/secrets:candidate
rad deploy samples/demo/app-postgresql.bicep -p "@$params"
kubectl rollout status deployment/postgresql-tutorial -n radius-tutorial --timeout=180s
kubectl rollout status deployment/demo-tutorial -n radius-tutorial --timeout=180s
kubectl exec -i -n radius-tutorial deployment/demo-tutorial -c web -- \
  node - old-server "$(cat "$evidence/expected-host.txt")" \
  < .github/test-fixtures/postgresql/tls-probe.cjs | tee "$evidence/old-server.txt"
rad app delete demo-tutorial --preview -y
kubectl delete secret postgresql-tutorial-tls -n radius-tutorial
echo "TLS required/default, client/server rejection, CA mount, and lifecycle checks passed."
