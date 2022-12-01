# Envoy for eshop

Eshop uses an internal gateway to route requests between different services. Today in Radius, we don't support private/internal gateways (see https://github.com/project-radius/radius/issues/4789), so we created a custom image of envoy with the routing rules necessary to make eshop work.

What this means is that if we need to update the names of routes in eshop, *we likely need to update the envoy image*.

The routing configuration is in [envoy.yaml](envoy.yaml). See the `route_config` section specifically.

To build the docker image, run `docker build . -t radius.azurecr.io/eshop-envoy:0.1.<NUMBER>`.

Where NUMBER is one greater than the latest version made. To view versions, see https://ms.portal.azure.com/#view/Microsoft_Azure_ContainerRegistries/RepositoryBlade/id/%2Fsubscriptions%2F66d1209e-1382-45d3-99bb-650e6bf63fc0%2FresourceGroups%2Fassets%2Fproviders%2FMicrosoft.ContainerRegistry%2Fregistries%2Fradius/repository/eshop-envoy.

To push the image, run `az acr login -n radius` and then `docker push radius.azurecr.io/eshop-envoy:0.1.<NUMBER>`.

