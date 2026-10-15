#!/usr/bin/env bash
set -euo pipefail
umask 077

work=$1
evidence=$2
image=$3
registry=$4
templates="$work/prepared/public"
: "${POSTGRESQL_TEST_CONTEXT:?Set the exact disposable cluster context before running TLS tests.}"
[[ "$(kubectl config current-context)" == "$POSTGRESQL_TEST_CONTEXT" ]]
[[ "$registry" =~ ^localhost:[0-9]+$ ]] || { echo "Only a local test registry is allowed." >&2; exit 1; }
[[ ! -e "$work" ]] || { echo "Private test directory already exists." >&2; exit 1; }
existing_namespace=$(kubectl get namespace radius-tutorial --ignore-not-found -o name)
[[ -z "$existing_namespace" ]] ||
  { echo "Refusing an existing tutorial namespace." >&2; exit 1; }
mkdir -p "$evidence"
rad version > "$evidence/runtime.txt"
rad group list -o json > "$evidence/groups-before.json"
jq -e 'all(.[]; .name != "tutorial")' "$evidence/groups-before.json" >/dev/null
rad workspace list -o json > "$evidence/workspaces-before.json"
jq -e 'length == 0' "$evidence/workspaces-before.json" >/dev/null

rad_env() {
  local command=$1
  shift
  local help
  help=$(rad env "$command" --help)
  local preview=()
  if grep -Eq -- '(^|[[:space:]])--preview([[:space:]]|$)' <<< "$help"; then
    preview=(--preview)
  fi
  rad env "$command" "${preview[@]}" "$@"
}

kubectl create namespace radius-tutorial
kubectl label namespace radius-tutorial samples.radius.io/test=postgresql-tls
rad group create tutorial
rad workspace create kubernetes tutorial --group tutorial
rad_env create tutorial --kubernetes-namespace radius-tutorial
rad_env switch tutorial
rad_env show tutorial -o json > "$evidence/environment-before.json"
jq -e '.type == "Radius.Core/environments" and
  .properties.providers.kubernetes.namespace == "radius-tutorial"' "$evidence/environment-before.json" >/dev/null ||
  { echo "Expected a Radius.Core environment in radius-tutorial; incompatible CLI/bootstrap." >&2; exit 1; }
namespace=$(jq -er '.properties.providers.kubernetes.namespace' "$evidence/environment-before.json")
[[ "$namespace" == radius-tutorial ]]
host="postgresql-tutorial.$namespace.svc.cluster.local"
printf '%s\n' "$host" > "$evidence/expected-host.txt"
mkdir -m 700 "$work"
openssl version > "$evidence/openssl-version.txt"
for ca in ca wrong-ca; do
  openssl req -x509 -newkey rsa:2048 -nodes -days 2 -subj "/CN=Radius test $ca" \
    -addext 'basicConstraints=critical,CA:TRUE' -addext 'keyUsage=critical,keyCertSign,cRLSign' \
    -keyout "$work/$ca.key" -out "$work/$ca.crt" 2>/dev/null
done
openssl req -newkey rsa:2048 -nodes -subj "/CN=$host" \
  -keyout "$work/server.key" -out "$work/server.csr" 2>/dev/null
printf 'subjectAltName=DNS:%s\nextendedKeyUsage=serverAuth\nbasicConstraints=critical,CA:FALSE\n' "$host" > "$work/server.ext"
openssl x509 -req -in "$work/server.csr" -CA "$work/ca.crt" -CAkey "$work/ca.key" \
  -CAcreateserial -days 2 -extfile "$work/server.ext" -out "$work/server.crt" 2>/dev/null
openssl verify -CAfile "$work/ca.crt" -verify_hostname "$host" "$work/server.crt"
kubectl create secret tls postgresql-tutorial-tls -n "$namespace" \
  --cert="$work/server.crt" --key="$work/server.key"
python3 .github/test-fixtures/postgresql/prepare-tls.py "$work/prepared" "$image" "$work/ca.crt" > "$evidence/recipe-sources.json"
rad bicep download
rad resource-type create -f "$work/prepared/postgresql.yaml"
bash .github/test-fixtures/postgresql/build-tls-types.sh "$work/prepared" "$evidence" "$HOME/.rad/bin/bicep"
python3 .github/test-fixtures/postgresql/check-tls-template.py "$HOME/.rad/bin/bicep" "$templates"
for recipe in postgresql containers secrets; do
  rad bicep publish --file "$work/prepared/$recipe.bicep" \
    --target "br:$registry/postgresql-tls/$recipe:candidate" --plain-http
  printf '%s %s\n' "$recipe" "$(oras manifest fetch --plain-http --descriptor "$registry/postgresql-tls/$recipe:candidate" | jq -er '.digest')" \
    >> "$evidence/recipe-digests.txt"
done
for invalid_source in 'br:sampleregistry:5000/postgresql-tls/postgresql:candidate' \
  'sampleregistry:5000/postgresql-tls/postgresql@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; do
  if rad deploy "$templates/postgresql-tls-pack.bicep" \
    -p packName=tutorial-invalid-source -p "postgresqlRecipeSource=$invalid_source" \
    -p containerRecipeSource=sampleregistry:5000/postgresql-tls/containers:candidate \
    -p secretRecipeSource=sampleregistry:5000/postgresql-tls/secrets:candidate > "$work/invalid-source.log" 2>&1; then
    echo "Invalid Recipe source was accepted." >&2
    exit 1
  fi
  grep -Fq 'Recipe sources must be raw registry/path:tag references' "$work/invalid-source.log"
done
echo "Recipe URL prefixes and digest-only sources rejected." > "$evidence/pack-inputs.txt"
rad deploy "$templates/postgresql-tls-pack.bicep" \
  -p packName=tutorial-postgresql-tls \
  -p postgresqlRecipeSource=sampleregistry:5000/postgresql-tls/postgresql:candidate \
  -p containerRecipeSource=sampleregistry:5000/postgresql-tls/containers:candidate \
  -p secretRecipeSource=sampleregistry:5000/postgresql-tls/secrets:candidate
rad_env delete tutorial -y
rad_env create tutorial --kubernetes-namespace "$namespace" --recipe-packs tutorial-postgresql-tls
rad_env switch tutorial
rad_env show tutorial -o json > "$evidence/environment.json"
jq -e '.type == "Radius.Core/environments" and .properties.providers.kubernetes.namespace == "radius-tutorial" and (.properties.recipePacks | length == 1) and (.properties.recipePacks[0] | endswith("/tutorial-postgresql-tls"))' "$evidence/environment.json" >/dev/null
rad resource show Radius.Core/recipePacks tutorial-postgresql-tls -o json > "$evidence/pack.json"
jq -e '.properties.recipes | length == 3' "$evidence/pack.json" >/dev/null
for mapping in 'Radius.Data/postgreSqlDatabases:postgresql' 'Radius.Compute/containers:containers' 'Radius.Security/secrets:secrets'; do
  type=${mapping%:*}
  recipe=${mapping##*:}
  jq -e --arg type "$type" --arg source "sampleregistry:5000/postgresql-tls/$recipe:candidate" \
    '.properties.recipes[$type] | .kind == "bicep" and .source == $source and .plainHttp == true' "$evidence/pack.json" >/dev/null
  rad resource-type show "$type" -o json > "$evidence/$recipe-schema.json"
done
jq -e '.APIVersions["2025-08-01-preview"].Schema.properties.tls |
  .type == "string" and .default == "required" and
  (.enum | index("required") != null and index("disabled") != null)' "$evidence/postgresql-schema.json" >/dev/null
"$HOME/.rad/bin/bicep" --version > "$evidence/bicep-version.txt"
cp "$templates/bicepconfig.json" "$evidence/bicepconfig.json"
sha256sum "$work/prepared/radius-extension.tgz" "$work/prepared/postgresql.yaml" > "$evidence/bicep-types-hashes.txt"
kubectl get pods -n radius-system -o json |
  jq '[.items[] | {name:.metadata.name, containers:[.status.containerStatuses[]? | {name,image,imageID}]}]' \
    > "$evidence/control-plane-images.json"

# Guard failures must precede changes to either a fresh app or the tutorial base.
snapshot_resources() {
  for type in Radius.Core/applications Radius.Compute/containers Radius.Data/postgreSqlDatabases Radius.Security/secrets; do
    rad resource list "$type" --preview -o json | jq -S 'sort_by(.id)' | sha256sum
  done
  kubectl get deployments,services,secrets -n radius-tutorial -o json |
    jq -S '[.items[] | {kind,metadata:{name:.metadata.name,uid:.metadata.uid},spec,data}] | sort_by(.kind,.metadata.name)' | sha256sum
}
for base in fresh existing; do
  if [[ "$base" == existing ]]; then
    rad deploy "$templates/app.bicep" -p "image=$image"
    kubectl rollout status deployment/demo-tutorial -n radius-tutorial --timeout=180s
  fi
  snapshot_resources > "$work/guard-before.json"
  for invalid in missing empty whitespace; do
    jq --arg invalid "$invalid" '
      if $invalid == "missing" then del(.parameters.postgresqlCaCertificate)
      else .parameters.postgresqlCaCertificate.value = (if $invalid == "empty" then "" else " \n" end) end
    ' "$work/prepared/parameters.json" > "$work/guard-parameters.json"
    if rad deploy "$templates/app-postgresql.bicep" -p "@$work/guard-parameters.json" > "$work/guard.log" 2>&1; then
      echo "Required mode accepted $invalid CA input." >&2
      exit 1
    fi
    grep -Fq 'postgresqlCaCertificate is required when postgresqlTls is required.' "$work/guard.log"
    snapshot_resources > "$work/guard-after.json"
    cmp "$work/guard-before.json" "$work/guard-after.json"
    echo "$base app: $invalid CA rejected before resource changes." >> "$evidence/ca-input-guard.txt"
  done
  for invalid in optional unknown; do
    jq --arg invalid "$invalid" '.parameters.postgresqlTls.value = $invalid' \
      "$work/prepared/parameters.json" > "$work/guard-parameters.json"
    if rad deploy "$templates/app-postgresql.bicep" -p "@$work/guard-parameters.json" > "$work/guard.log" 2>&1; then
      echo "Unsupported tutorial mode was accepted." >&2
      exit 1
    fi
    grep -Fq postgresqlTls "$work/guard.log"
    grep -Eiq 'allowed|invalid|validation' "$work/guard.log"
    snapshot_resources > "$work/guard-after.json"
    cmp "$work/guard-before.json" "$work/guard-after.json"
    echo "$base app: unsupported mode rejected before resource changes." >> "$evidence/ca-input-guard.txt"
  done
done
rad app delete demo-tutorial --preview -y
rm -f "$work/guard-parameters.json"
