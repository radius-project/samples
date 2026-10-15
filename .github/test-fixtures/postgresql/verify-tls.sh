#!/usr/bin/env bash
set -euo pipefail
work=$1
evidence=$2
mode=${3:-required}
[[ "$mode" == required || "$mode" == disabled ]]
kubectl rollout status deployment/postgresql-tutorial -n radius-tutorial --timeout=180s
kubectl rollout status deployment/demo-tutorial -n radius-tutorial --timeout=180s
host=$(cat "$evidence/expected-host.txt")
actual=$(rad resource show Radius.Data/postgreSqlDatabases postgresql-tutorial -o json | jq -er '.properties.host')
[[ "$actual" == "$host" ]]
if [[ "$mode" == required ]]; then
  kubectl exec -i -n radius-tutorial deployment/postgresql-tutorial -c postgres -- \
  sh -ec '
    ca=$(mktemp)
    trap '\''rm -f "$ca"'\'' EXIT
    cat > "$ca"
    export PGPASSWORD="$POSTGRES_PASSWORD" PGSSLMODE=verify-full PGSSLROOTCERT="$ca"
    result=$(psql --host="$1" --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" \
      -v ON_ERROR_STOP=1 -Atc "SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()")
    test "$result" = t
  ' sh "$host" < "$work/ca.crt"
  echo "Authenticated psql verify-full connection passed." | tee "$evidence/psql.txt"
  ip=$(kubectl get service postgresql-tutorial -n radius-tutorial -o jsonpath='{.spec.clusterIP}')
  kubectl exec -i -n radius-tutorial deployment/demo-tutorial -c web -- \
  node - tls "$host" "$ip" "$(base64 -w0 "$work/wrong-ca.crt")" \
  < .github/test-fixtures/postgresql/tls-probe.cjs | tee "$evidence/tls-crud.txt"
  kubectl get deployment demo-tutorial -n radius-tutorial -o json |
  jq -e '.spec.template.spec.volumes | length == 1 and .[0].secret.secretName == "postgresql-ca-tutorial"' >/dev/null
  kubectl get secret postgresql-ca-tutorial -n radius-tutorial -o json |
  jq -e '.data | keys == ["ca.crt"]' >/dev/null
else
  kubectl exec -n radius-tutorial deployment/postgresql-tutorial -c postgres -- \
    sh -ec '
      export PGPASSWORD="$POSTGRES_PASSWORD" PGSSLMODE=disable
      result=$(psql --host="$1" --username="$POSTGRES_USER" --dbname="$POSTGRES_DB" \
        -v ON_ERROR_STOP=1 -Atc "SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()")
      test "$result" = f
    ' sh "$host"
  echo "Authenticated psql plaintext connection passed (ssl=false)." | tee "$evidence/psql.txt"
  kubectl exec -i -n radius-tutorial deployment/demo-tutorial -c web -- \
    node - disabled "$host" < .github/test-fixtures/postgresql/tls-probe.cjs |
    tee "$evidence/plaintext-crud.txt"
  kubectl get deployment demo-tutorial -n radius-tutorial -o json |
    jq -e '.spec.template.spec |
      ((.volumes // []) | length == 0) and
      (.containers[] | select(.name == "web") |
        ((.volumeMounts // []) | length == 0) and
        ([.env[] | select(.name == "RADIUS_DEMO_POSTGRESQL_TLS" or .name == "RADIUS_DEMO_POSTGRESQL_CA_FILE")] | length == 0) and
        any(.env[]; .name == "PGSSLMODE" and .value == "disable"))' >/dev/null
  kubectl get deployment postgresql-tutorial -n radius-tutorial -o json |
    jq -e '.spec.template.spec |
      ([.volumes[]? | select(has("secret"))] | length == 0) and
      ([.initContainers[]? | select(.name == "prepare-tls")] | length == 0)' >/dev/null
fi
kubectl get pods -n radius-tutorial -o json |
  jq '[.items[] | {name:.metadata.name, containers:[.status.containerStatuses[]? | {name,image,imageID}]}]' \
    > "$evidence/application-images.json"
