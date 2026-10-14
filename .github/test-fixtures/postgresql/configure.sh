#!/usr/bin/env bash
set -euo pipefail

flavor=$1
name=$2
evidence=$3
mkdir -p "$evidence"
case "$flavor" in
  released|edge) ;;
  *) echo "Expected compatibility flavor released or edge" >&2; exit 1 ;;
esac

# Each caller owns a disposable cluster, HOME, kubeconfig and unique namespace.
kubectl create namespace "$name"
rad group create "$name"
rad workspace create kubernetes "$name" --group "$name"
rad env create "$name" --preview --kubernetes-namespace "$name"
rad env switch "$name" --preview

if [[ "$flavor" == edge ]]; then
  expected=sha256:ca65f43501f39fc31689e8a292e9e0e3179e4ebf7a89ec0143c12b4a1dc24ddd
  source=ghcr.io/radius-project/kube-recipes/postgresqldatabases:18142182e52e19a46b0ed172037357e8e142dcd2
  actual=$(oras manifest fetch --descriptor "$source" | jq -er '.digest')
  if [[ "$actual" != "$expected" ]]; then
    echo "Pre-TLS PostgreSQL Recipe digest does not match the recorded baseline." >&2
    exit 1
  fi
  rad deploy .github/test-fixtures/postgresql/pre-tls-pack.bicep
  rad env delete "$name" --preview -y
  rad env create "$name" --preview --kubernetes-namespace "$name" --recipe-packs postgresql-compatibility
  rad env switch "$name" --preview
fi

rad version | tee "$evidence/runtime.txt"
if [[ "$flavor" == released ]]; then
  grep -Eq '^0\.61\.1[[:space:]]+v0\.61\.1' "$evidence/runtime.txt"
  grep -Eq '^Installed[[:space:]]+0\.61\.1$' "$evidence/runtime.txt"
else
  grep -Eq '^edge[[:space:]]+' "$evidence/runtime.txt"
  grep -Eq '^Installed[[:space:]]+' "$evidence/runtime.txt"
fi
rad env show "$name" --preview -o json > "$evidence/environment.json"
pack_id=$(jq -er '.properties.recipePacks | select(length == 1) | .[0]' "$evidence/environment.json")
pack_group=$(echo "$pack_id" | cut -d / -f 6)
pack_name=${pack_id##*/}
rad resource show Radius.Core/recipePacks "$pack_name" -g "$pack_group" -o json > "$evidence/pack.json"
for type in Radius.Compute/containers Radius.Data/postgreSqlDatabases Radius.Security/secrets; do
  source=$(jq -er --arg type "$type" '.properties.recipes[$type].source' "$evidence/pack.json")
  digest=$(oras manifest fetch --descriptor "$source" | jq -er '.digest')
  printf '%s %s %s\n' "$type" "$source" "$digest" | tee -a "$evidence/recipe-digests.txt"
  rad resource-type show "$type" -o json > "$evidence/${type##*/}-schema.json"
done
kubectl get pods -n radius-system -o json |
  jq '[.items[] | {name:.metadata.name, containers:[.status.containerStatuses[]? | {name,image,imageID}]}]' \
  > "$evidence/control-plane-images.json"
