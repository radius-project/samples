#!/bin/sh

echo "Starting Post Create Command"

k3d cluster delete

k3d cluster create -p '8081:80@loadbalancer' --k3s-arg '--disable=traefik@server:0'

echo "Ending Post Create Command"
