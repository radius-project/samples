#!/bin/bash

# ------------------------------------------------------------
# Copyright 2023 The Radius Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#    
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------

set -xeo pipefail

VERSION_NUMBER=$1 # (e.g. 0.1.0)
REPOSITORY="samples"

if [[ -z "$VERSION_NUMBER" ]]; then
  echo "Error: VERSION_NUMBER is not set."
  exit 1
fi

# The release commit is created through the GitHub API in GITHUB_REPOSITORY (owner/name) using GH_TOKEN,
# which must be a GitHub App installation token. BOT_NAME and BOT_EMAIL identify the App's bot user for
# the DCO sign-off.
if [[ -z "${GITHUB_REPOSITORY}" || -z "${BOT_NAME}" || -z "${BOT_EMAIL}" ]]; then
  echo "Error: GITHUB_REPOSITORY, BOT_NAME, and BOT_EMAIL must be set."
  exit 1
fi

# CHANNEL is the major and minor version of the VERSION_NUMBER (e.g. 0.1)
CHANNEL="$(echo $VERSION_NUMBER | cut -d '.' -f 1,2)"

# CHANNEL_VERSION is the version with the 'v' prefix (e.g. v0.1)
CHANNEL_VERSION="v${CHANNEL}"

echo "Version number: ${VERSION_NUMBER}"
echo "Channel: ${CHANNEL}"
echo "Channel version: ${CHANNEL_VERSION}"

echo "Creating release branch for ${REPOSITORY}..."

pushd $REPOSITORY

# The release branch starts from the checked-out commit
BASE_SHA="$(git rev-parse HEAD)"

# Update bicepconfig.json br:biceptypes.azurecr.io/radius with the CHANNEL
BICEPCONFIG_RADIUS_STRING_REPLACEMENT="br:biceptypes.azurecr.io/radius:${CHANNEL}"
awk -v REPLACEMENT="${BICEPCONFIG_RADIUS_STRING_REPLACEMENT}" '{gsub(/br:biceptypes\.azurecr\.io\/radius:latest/, REPLACEMENT); print}' bicepconfig.json > bicepconfig_updated.json
mv bicepconfig_updated.json bicepconfig.json

# Update bicepconfig.json br:biceptypes.azurecr.io/aws with the CHANNEL
BICEPCONFIG_AWS_STRING_REPLACEMENT="br:biceptypes.azurecr.io/aws:${CHANNEL}"
awk -v REPLACEMENT="${BICEPCONFIG_AWS_STRING_REPLACEMENT}" '{gsub(/br:biceptypes\.azurecr\.io\/aws:latest/, REPLACEMENT); print}' bicepconfig.json > bicepconfig_updated.json
mv bicepconfig_updated.json bicepconfig.json
echo "View updated bicepconfig..."
cat bicepconfig.json

echo "Running git diff..."
git diff
git add --all

if git diff --cached --quiet; then
  echo "Error: No changes to commit for ${CHANNEL_VERSION}."
  exit 1
fi

# Create the release commit with the GitHub API instead of pushing a local commit. GitHub signs commits that a
# GitHub App creates this way when the request has no custom author, committer, or signature:
# https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#signature-verification-for-bots
echo "Uploading changed files..."
TREE_ENTRIES=""
while IFS= read -r -d '' CHANGE && IFS= read -r -d '' CHANGED_PATH; do
  read -r OLD_MODE NEW_MODE _ NEW_SHA CHANGE_TYPE <<<"${CHANGE#:}"
  case "${CHANGE_TYPE}" in
  A | M | T)
    BLOB_SHA="$(git cat-file blob "${NEW_SHA}" | base64 --wrap=0 |
      jq --raw-input --slurp '{content: ., encoding: "base64"}' |
      gh api --method POST "repos/${GITHUB_REPOSITORY}/git/blobs" --input - --jq '.sha')"
    TREE_ENTRIES+="$(jq --null-input --compact-output --arg path "${CHANGED_PATH}" --arg mode "${NEW_MODE}" \
      --arg sha "${BLOB_SHA}" '{path: $path, mode: $mode, type: "blob", sha: $sha}')"$'\n'
    ;;
  D)
    TREE_ENTRIES+="$(jq --null-input --compact-output --arg path "${CHANGED_PATH}" --arg mode "${OLD_MODE}" \
      '{path: $path, mode: $mode, type: "blob", sha: null}')"$'\n'
    ;;
  *)
    echo "Error: Unsupported change type ${CHANGE_TYPE} for ${CHANGED_PATH}."
    exit 1
    ;;
  esac
done < <(git diff-index --cached --no-renames -z HEAD)

TREE_SHA="$(jq --slurp --arg base_tree "$(git rev-parse 'HEAD^{tree}')" '{base_tree: $base_tree, tree: .}' <<<"${TREE_ENTRIES}" |
  gh api --method POST "repos/${GITHUB_REPOSITORY}/git/trees" --input - --jq '.sha')"

# The commit must contain exactly the staged changes, like a local `git commit`
if [[ "${TREE_SHA}" != "$(git write-tree)" ]]; then
  echo "Error: GitHub tree ${TREE_SHA} does not match the local changes."
  exit 1
fi

echo "Creating commit..."
COMMIT="$(jq --null-input \
  --arg message "$(printf 'Update samples for %s\n\nSigned-off-by: %s <%s>' "${CHANNEL_VERSION}" "${BOT_NAME}" "${BOT_EMAIL}")" \
  --arg tree "${TREE_SHA}" \
  --arg parent "${BASE_SHA}" \
  '{message: $message, tree: $tree, parents: [$parent]}' |
  gh api --method POST "repos/${GITHUB_REPOSITORY}/git/commits" --input -)"
COMMIT_SHA="$(jq --raw-output '.sha' <<<"${COMMIT}")"

# Nothing has been published yet, so stop here if GitHub did not sign the commit
if [[ "$(jq --raw-output '.verification.verified' <<<"${COMMIT}")" != "true" ]]; then
  echo "Error: GitHub did not verify commit ${COMMIT_SHA} ($(jq --raw-output '.verification.reason' <<<"${COMMIT}")). GH_TOKEN must be a GitHub App installation token."
  exit 1
fi

# Publish the commit. An existing release branch is only fast-forwarded, like `git push`.
echo "Pushing ${COMMIT_SHA} to ${CHANNEL_VERSION}..."
if gh api "repos/${GITHUB_REPOSITORY}/git/ref/heads/${CHANNEL_VERSION}" --silent 2>/dev/null; then
  gh api --method PATCH "repos/${GITHUB_REPOSITORY}/git/refs/heads/${CHANNEL_VERSION}" -f sha="${COMMIT_SHA}" -F force=false --silent
else
  gh api --method POST "repos/${GITHUB_REPOSITORY}/git/refs" -f ref="refs/heads/${CHANNEL_VERSION}" -f sha="${COMMIT_SHA}" --silent
fi

popd
