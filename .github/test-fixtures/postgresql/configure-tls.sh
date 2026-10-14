#!/usr/bin/env bash
set -euo pipefail
umask 077

work=$1
evidence=$2
image=$3
registry=$4
: "${POSTGRESQL_TEST_CONTEXT:?Set the exact disposable cluster context before running TLS tests.}"
[[ "$(kubectl config current-context)" == "$POSTGRESQL_TEST_CONTEXT" ]]
[[ "$registry" =~ ^localhost:[0-9]+$ ]] || { echo "Only a local test registry is allowed." >&2; exit 1; }
[[ ! -e "$work" ]] || { echo "Private test directory already exists." >&2; exit 1; }
[[ -z "$(kubectl get namespace radius-tutorial --ignore-not-found -o name)" ]] ||
  { echo "Refusing an existing tutorial namespace." >&2; exit 1; }
mkdir -p "$evidence"
rad group list -o json > "$evidence/groups-before.json"
jq -e 'all(.[]; .name != "tutorial")' "$evidence/groups-before.json" >/dev/null
rad workspace list -o json > "$evidence/workspaces-before.json"
jq -e 'length == 0' "$evidence/workspaces-before.json" >/dev/null

kubectl create namespace radius-tutorial
kubectl label namespace radius-tutorial samples.radius.io/test=postgresql-tls
rad group create tutorial
rad workspace create kubernetes tutorial --group tutorial
rad env create tutorial --preview --kubernetes-namespace radius-tutorial
rad env switch tutorial --preview
rad env show tutorial --preview -o json > "$evidence/environment-before.json"
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
python3 .github/test-fixtures/postgresql/check-tls-template.py "$HOME/.rad/bin/bicep"
for recipe in postgresql containers secrets; do
  rad bicep publish --file "$work/prepared/$recipe.bicep" \
    --target "br:$registry/postgresql-tls/$recipe:candidate" --plain-http
  printf '%s %s\n' "$recipe" "$(oras manifest fetch --plain-http --descriptor "$registry/postgresql-tls/$recipe:candidate" | jq -er '.digest')" \
    >> "$evidence/recipe-digests.txt"
done
for invalid_source in 'br:sampleregistry:5000/postgresql-tls/postgresql:candidate' \
  'sampleregistry:5000/postgresql-tls/postgresql@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; do
  if rad deploy samples/demo/postgresql-tls-pack.bicep \
    -p packName=tutorial-invalid-source -p "postgresqlRecipeSource=$invalid_source" \
    -p containerRecipeSource=sampleregistry:5000/postgresql-tls/containers:candidate \
    -p secretRecipeSource=sampleregistry:5000/postgresql-tls/secrets:candidate > "$work/invalid-source.log" 2>&1; then
    echo "Invalid Recipe source was accepted." >&2
    exit 1
  fi
  grep -Fq 'Recipe sources must be raw registry/path:tag references' "$work/invalid-source.log"
done
echo "Recipe URL prefixes and digest-only sources rejected." > "$evidence/pack-inputs.txt"
rad deploy samples/demo/postgresql-tls-pack.bicep \
  -p packName=tutorial-postgresql-tls \
  -p postgresqlRecipeSource=sampleregistry:5000/postgresql-tls/postgresql:candidate \
  -p containerRecipeSource=sampleregistry:5000/postgresql-tls/containers:candidate \
  -p secretRecipeSource=sampleregistry:5000/postgresql-tls/secrets:candidate
rad env delete tutorial --preview -y
rad env create tutorial --preview --kubernetes-namespace "$namespace" --recipe-packs tutorial-postgresql-tls
rad env switch tutorial --preview
rad env show tutorial --preview -o json > "$evidence/environment.json"
jq -e '.properties.providers.kubernetes.namespace == "radius-tutorial" and (.properties.recipePacks | length == 1) and (.properties.recipePacks[0] | endswith("/tutorial-postgresql-tls"))' "$evidence/environment.json" >/dev/null
rad resource show Radius.Core/recipePacks tutorial-postgresql-tls -o json > "$evidence/pack.json"
jq -e '.properties.recipes | length == 3' "$evidence/pack.json" >/dev/null
for mapping in 'Radius.Data/postgreSqlDatabases:postgresql' 'Radius.Compute/containers:containers' 'Radius.Security/secrets:secrets'; do
  type=${mapping%:*}
  recipe=${mapping##*:}
  jq -e --arg type "$type" --arg source "sampleregistry:5000/postgresql-tls/$recipe:candidate" \
    '.properties.recipes[$type] | .kind == "bicep" and .source == $source and .plainHttp == true' "$evidence/pack.json" >/dev/null
  rad resource-type show "$type" -o json > "$evidence/$recipe-schema.json"
done
jq -e '.APIVersions["2025-08-01-preview"].Schema.properties.tls | .type == "string" and (.enum | index("required") != null)' "$evidence/postgresql-schema.json" >/dev/null
rad version > "$evidence/runtime.txt"
"$HOME/.rad/bin/bicep" --version > "$evidence/bicep-version.txt"
cache="$HOME/.bicep/br/biceptypes.azurecr.io/radius/latest\$"
cp "$cache/manifest" "$evidence/bicep-types-manifest.json"
sha256sum "$cache/manifest" "$cache/types.tgz" > "$evidence/bicep-types-hashes.txt"
kubectl get pods -n radius-system -o json |
  jq '[.items[] | {name:.metadata.name, containers:[.status.containerStatuses[]? | {name,image,imageID}]}]' \
    > "$evidence/control-plane-images.json"
