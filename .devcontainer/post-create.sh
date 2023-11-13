#!/bin/sh

curl "https://rynowakkubernetesinterop.blob.core.windows.net/rad-cdk/rad" --output rad
chmod +x rad
sudo mv rad /usr/local/bin
rad version

## Create a k3d cluster
while (! kubectl cluster-info ); do
  # Docker takes a few seconds to initialize
  echo "Waiting for Docker to launch..."
  k3d cluster delete
  k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'
  sleep 1
done

## Install Dapr and init
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr uninstall # clean if needed
dapr init -k
