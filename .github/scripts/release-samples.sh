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

set -xe

VERSION_NUMBER=$1 # (e.g. 0.1.0)
REPOSITORY="samples"

if [[ -z "$VERSION_NUMBER" ]]; then
  echo "Error: VERSION_NUMBER is not set."
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

git checkout -B "${CHANNEL_VERSION}"

# Update bicepconfig.json br:biceptypes.azurecr.io/radius with the CHANNEL
BICEPCONFIG_RADIUS_STRING_REPLACEMENT="br:biceptypes.azurecr.io/radius:${CHANNEL}"
awk -v REPLACEMENT="${BICEPCONFIG_RADIUS_STRING_REPLACEMENT}" '{gsub(/br:biceptypes\.azurecr\.io\/radius:latest/, REPLACEMENT); print}' bicepconfig.json > bicepconfig_updated.json
mv bicepconfig_updated.json bicepconfig.json

# Update bicepconfig.json br:biceptypes.azurecr.io/aws with the CHANNEL
BICEPCONFIG_AWS_STRING_REPLACEMENT="br:biceptypes.azurecr.io/aws:${CHANNEL}"
awk -v REPLACEMENT="${BICEPCONFIG_AWS_STRING_REPLACEMENT}" '{gsub(/br:biceptypes\.azurecr\.io\/aws:latest/, REPLACEMENT); print}' bicepconfig.json > bicepconfig_updated.json
mv bicepconfig_updated.json bicepconfig.json

# Push changes to GitHub
git add --all
git commit -m "Update docs for ${VERSION}"
git push origin "${CHANNEL_VERSION}"

popd
