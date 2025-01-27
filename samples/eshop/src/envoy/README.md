# Envoy for eshop

## Overview

Eshop uses an internal gateway to route requests between different services. Today in Radius, we don't support private/internal gateways (see https://github.com/radius-project/radius/issues/4789), so we created a custom image of envoy with the routing rules necessary to make eshop work.

What this means is that if we need to update the names of routes in eshop, *we likely need to update the envoy image*.

The routing configuration is in [envoy.yaml](envoy.yaml). See the `route_config` section specifically.

## Building

To build and push the image, run the following commands:
> Note: Replace `<TAG>` with the tag you want to use. By convention, we use the same tag as the external eshop image.
```bash
cd samples/eshop/src/envoy
export TAG=<TAG>
docker build . -t ghcr.io/radius-project/samples/eshop/eshop-envoy:$TAG
docker push ghcr.io/radius-project/samples/eshop/eshop-envoy:$TAG
```
