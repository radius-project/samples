#!/bin/sh
set -e

## Create a k3d cluster
k3d cluster delete
k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

## Install Dapr and init
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr uninstall # clean if needed
dapr init -k

## Install Radius Helm chart
kubectl create namespace radius-system
helm upgrade radius oci://rynowak.azurecr.io/helm/radius --version '0.42.42-dev' -n radius-system --devel --install

## Install rad CLI
curl https://rynowakkubernetesinterop.blob.core.windows.net/kubernetes-interop/rad -o rad
chmod +x rad
sudo mv rad /usr/local/bin/rad
rad version

## Download Bicep extension
curl https://get.radapp.dev/tools/vscode-extensibility/$RADIUS_VERSION/rad-vscode-bicep.vsix --output /tmp/rad-vscode-bicep.vsix
