#!/usr/bin/env bash
set -euo pipefail
work=$1
evidence=$2
kubectl rollout status deployment/postgresql-tutorial -n radius-tutorial --timeout=180s
kubectl rollout status deployment/demo-tutorial -n radius-tutorial --timeout=180s
host=$(cat "$evidence/expected-host.txt")
actual=$(rad resource show Radius.Data/postgreSqlDatabases postgresql-tutorial -o json | jq -er '.properties.host')
[[ "$actual" == "$host" ]]
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
kubectl get pods -n radius-tutorial -o json |
  jq '[.items[] | {name:.metadata.name, containers:[.status.containerStatuses[]? | {name,image,imageID}]}]' \
    > "$evidence/application-images.json"
