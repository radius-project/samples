#!/bin/sh

## Create a k3d cluster
while (! kubectl cluster-info ); do
  # Docker takes a few seconds to initialize
  echo "Waiting for Docker to launch..."
  k3d cluster delete
  # Map localhost port 80 on the external load balancer, and disable traefik and the internal load balancer.
  k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:*' --k3s-arg '--disable=servicelb@server:*'
  sleep 1
done

## Install Dapr and init
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr uninstall # clean if needed
dapr init -k
