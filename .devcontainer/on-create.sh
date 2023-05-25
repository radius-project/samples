#!/bin/sh

## Install Dapr
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr uninstall # clean if needed
dapr init

## Create a k3d cluster
k3d cluster delete
k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

## Install rad CLI
CURRENT_BRANCH=$(git branch --show-current)

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

if [ "$RADIUS_VERSION" = "edge" ]; then
    wget -q "https://radiuspublic.blob.core.windows.net/tools/rad/install.sh" -O - | /bin/bash -s edge
    curl https://get.radapp.dev/tools/vscode-extensibility/edge/rad-vscode-bicep.vsix --output /tmp/rad-vscode-bicep.vsix
else
    wget -q "https://get.radapp.dev/tools/rad/install.sh" -O - | /bin/bash
    curl https://get.radapp.dev/tools/vscode-extensibility/stable/rad-vscode-bicep.vsix --output /tmp/rad-vscode-bicep.vsix
fi
