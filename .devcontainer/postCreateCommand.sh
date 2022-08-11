#!/bin/sh

echo "Starting Post Create Command"

k3d cluster delete

k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

RAD_VERSION=$(rad version | awk 'NR==2{print $1}')

if [ "$RAD_VERSION" = "edge" ]; then
    wget -q "https://radiuspublic.blob.core.windows.net/tools/rad/install.sh" -O - | /bin/bash -s edge
fi

rad env init kubernetes --public-endpoint-override 'http://localhost:8081'

echo "Ending Post Create Command"
