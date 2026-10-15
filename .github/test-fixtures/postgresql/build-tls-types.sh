#!/usr/bin/env bash
set -euo pipefail

prepared=$(realpath "$1")
evidence=$(realpath "$2")
compiler=$3
source_commit=56fa47301fc5d310bcd3df032078357cf6cd3cb6
build="$prepared/type-build"
[[ ! -e "$build" ]] || { echo "Type build directory already exists." >&2; exit 1; }
mkdir -p "$build/source" "$build/emitter/src/cmd"
curl --fail --silent --show-error --location \
  "https://codeload.github.com/radius-project/radius/tar.gz/$source_commit" \
  --output "$build/source.tar.gz"
tar -xzf "$build/source.tar.gz" --strip-components=1 -C "$build/source"
cp -R "$build/source/hack/bicep-types-radius/generated" "$build/generated"
manifests="$build/source/deploy/manifest/built-in-providers/dev"
(
  cd "$build/source"
  go run ./bicep-tools/cmd/manifest-to-bicep generate \
    "$prepared/postgresql.yaml" "$manifests/mySqlDatabases.yaml" \
    "$manifests/mongoDatabases.yaml" "$manifests/redisCaches.yaml" \
    "$manifests/sqlServerDatabases.yaml" \
    "$build/generated/radius/radius.data/2025-08-01-preview"
)
emitter="$build/source/hack/bicep-types-radius/src/typespec-bicep-types"
for file in package.json tsconfig.json; do
  cp "$emitter/$file" "$build/emitter/$file"
done
cp "$emitter/src/bicep.ts" "$emitter/src/index-builder.ts" "$build/emitter/src/"
cp "$emitter/src/cmd/rebuild-index.ts" "$build/emitter/src/cmd/"
docker run --rm --mount "type=bind,source=$build,target=/build" --workdir /build/emitter \
  --env "npm_config_registry=${NPM_CONFIG_REGISTRY:-https://registry.npmjs.org}" \
  node:24 bash -euc '
    npm install --ignore-scripts --no-audit --no-fund
    npm run build
    node dist/src/cmd/rebuild-index.js --out-dir /build/generated --release-version local-disabled-candidate
  '
printf '%s  %s\n' \
  c60549dc4dd5d6ef8c930035dafb3bb7fa44bc43a203d457de75cfac8190ff43 "$build/generated/radius/radius.data/2025-08-01-preview/types.json" \
  1faacb4456df1bf30767be6c2ad6987de5f6e4609b814f22de683c4bf6367d74 "$build/generated/index.json" |
  sha256sum --check
"$compiler" publish-extension "$build/generated/index.json" --target "$prepared/radius-extension.tgz"
# Candidate generation must not change any other namespace.
while IFS= read -r file; do
  relative=${file#"$build/source/hack/bicep-types-radius/generated/"}
  if [[ "$relative" != radius/radius.data/* ]]; then
    cmp "$file" "$build/generated/$relative"
  fi
done < <(find "$build/source/hack/bicep-types-radius/generated" -name types.json -type f)
printf '%s\n' "$source_commit" > "$evidence/type-generator-commit.txt"
sha256sum "$build/source.tar.gz" "$prepared/postgresql.yaml" \
  "$build/emitter/package-lock.json" "$build/generated/index.json" "$prepared/radius-extension.tgz" \
  > "$evidence/type-generator-hashes.txt"
