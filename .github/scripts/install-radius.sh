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

VERSION=$1
RAD_CLI_URL=https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh
RAD_CLI_EDGE_URL=ghcr.io/radius-project/rad/linux-amd64:latest

if [[ $VERSION == "edge" ]]; then
    echo Downloading rad CLI edge version
    oras pull $RAD_CLI_EDGE_URL
    # TEMP: https://github.com/radius-project/radius/issues/6633
    mv ./dist/linux_amd64/release/rad ./rad
    chmod +x ./rad
    mv ./rad /usr/local/bin/rad
elif [[ -n $VERSION && $VERSION != *"rc"* ]]; then
    INPUT_CHANNEL=$(echo $VERSION | cut -d '.' -f 1,2)
    echo "Downloading rad CLI version $INPUT_CHANNEL"
    wget -q $RAD_CLI_URL -O - | /bin/bash -s $INPUT_CHANNEL
elif [[ -n $VERSION ]]; then
    echo Downloading rad CLI version $VERSION
    wget -q $RAD_CLI_URL -O - | /bin/bash -s $VERSION
else
    echo Downloading latest rad CLI
    wget -q $RAD_CLI_URL -O - | /bin/bash
fi
