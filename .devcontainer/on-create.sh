#!/bin/sh

## Create a k3d cluster
k3d cluster delete
k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

## Verify cluster was created
kubectl get nodes
if [ $? -ne 0 ]; then
    echo "Failed to create k3s cluster"
    exit 1
fi

## Install Dapr and init
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr uninstall # clean if needed
dapr init -k

## Install stable rad CLI (edge conditionally downloaded in post-create script)
wget -q "https://get.radapp.dev/tools/rad/install.sh" -O - | /bin/bash
