#!/bin/sh

## Install rad CLI
CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" = "edge" ]; then
    RADIUS_VERSION=edge
else
    ## If CURRENT_BRANCH matches a regex of the form "v0.20", set RADIUS_VERSION to the matching string minus the "v"
    if [[ "$CURRENT_BRANCH" =~ ^v[0-9]+\.[0-9]+$ ]]; then
        RADIUS_VERSION=${CURRENT_BRANCH:1}
    else
        ## Otherwise, set RADIUS_VERSION to "latest"
        RADIUS_VERSION=edge
    fi
fi

if [ "$RADIUS_VERSION" = "edge" ]; then
    curl https://get.radapp.dev/tools/vscode-extensibility/edge/rad-vscode-bicep.vsix --output rad-vscode-bicep.vsix
else
    curl https://get.radapp.dev/tools/vscode-extensibility/stable/rad-vscode-bicep.vsix --output rad-vscode-bicep.vsix
fi

code --install-extension rad-vscode-bicep.vsix
rm rad-vscode-bicep.vsix
