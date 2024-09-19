#!/bin/bash

# ------------------------------------------------------------
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------

set -xe

# VERSION is the version of the rad CLI to download
# e.g. 0.1, 0.1.0, 0.1.0-rc1, edge
VERSION=$1
RAD_CLI_URL=https://raw.githubusercontent.com/radius-project/radius/main/deploy/install.sh
RAD_CLI_EDGE_URL=ghcr.io/radius-project/rad/linux-amd64:latest

if [[ $VERSION == "edge" ]]; then
    echo Downloading rad CLI edge version
    oras pull $RAD_CLI_EDGE_URL
    chmod +x ./rad
    mv ./rad /usr/local/bin/rad
elif [[ -n $VERSION ]]; then
    RADIUS_VERSION=$VERSION
    # if version is a channel, e.g. 0.1
    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
        echo "Querying the most recent version of the specified channel: $VERSION"
        RADIUS_VERSION=$(curl -L -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/radius-project/radius/releases | jq -r  '.[] | .tag_name | select(startswith("v'$VERSION'"))' | head -n 1)
        echo "Found version $RADIUS_VERSION"
        if [[ -z "$RADIUS_VERSION" ]]; then
            echo "No releases found for channel $VERSION"
            exit 1
        fi
    else
        echo "The string does not match the pattern [anynumber].[anynumber]"
    fi

    # remove the 'v' prefix
    RADIUS_VERSION=$(echo $RADIUS_VERSION | cut -d "v" -f 2)

    echo Downloading rad CLI version $RADIUS_VERSION
    wget -q $RAD_CLI_URL -O - | /bin/bash -s $RADIUS_VERSION
else
    echo Downloading latest rad CLI
    wget -q $RAD_CLI_URL -O - | /bin/bash
fi
