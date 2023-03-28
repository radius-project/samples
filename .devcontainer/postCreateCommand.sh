#!/bin/sh

echo "Starting Post Create Command"

k3d cluster delete

k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

RAD_VERSION=$(rad version | awk 'NR==2{print $1}')

if [ "$RAD_VERSION" = "edge" ]; then
    wget -q "https://get.radapp.dev/tools/rad/install.sh" -O - | /bin/bash -s edge
fi

rad install kubernetes --set global.rp.publicEndpointOverride=localhost:8081
rad group create default
rad workspace create kubernetes default --group default
rad group switch default
rad env create default
rad env switch default

echo "Ending Post Create Command"
