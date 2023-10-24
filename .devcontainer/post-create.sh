#!/bin/sh

## Create a k3d cluster
k3d cluster delete
k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

## Install Dapr and init
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr uninstall # clean if needed
dapr init -k
