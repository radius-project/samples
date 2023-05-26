#!/bin/sh

CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" = "edge" ]; then
    RADIUS_VERSION=edge
else
    ## If CURRENT_BRANCH matches a regex of the form "v0.20", set RADIUS_VERSION to the matching string minus the "v"
    if [[ "$CURRENT_BRANCH" =~ ^v[0-9]+\.[0-9]+$ ]]; then
        RADIUS_VERSION=${CURRENT_BRANCH:1}
    else
        ## Otherwise, set RADIUS_VERSION to "edge"
        RADIUS_VERSION=edge
    fi
fi

echo "Downloading Radius with RADIUS_VERSION=$RADIUS_VERSION"
if [ "$RADIUS_VERSION" = "edge" ]; then
    wget -q "https://get.radapp.dev/tools/rad/install.sh" -O - | /bin/bash -s edge
    curl https://get.radapp.dev/tools/vscode-extensibility/edge/rad-vscode-bicep.vsix --output /workspaces/rad-vscode-bicep.vsix
else
    wget -q "https://get.radapp.dev/tools/rad/install.sh" -O - | /bin/bash
    curl https://get.radapp.dev/tools/vscode-extensibility/$RADIUS_VERSION/rad-vscode-bicep.vsix --output /workspaces/rad-vscode-bicep.vsix
fi

code --install-extension /workspaces/rad-vscode-bicep.vsix
