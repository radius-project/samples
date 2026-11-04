@description('Radius-provided deployment context.')
param context object

@description('Kubernetes Service type that publishes the selected container ports outside the cluster.')
@allowed([
  'NodePort'
  'LoadBalancer'
])
param externalServiceType string

@description('Ports to publish, keyed by the upstream `<resource>-<container>` Service name and then by port name. A value is the node port for NodePort, or the listener port for LoadBalancer.')
param externalPorts object

extension kubernetes with {
  kubeConfig: ''
  namespace: context.runtime.kubernetes.namespace
} as kubernetes

module containers 'br:ghcr.io/radius-project/kube-recipes/containers:0c3eaf14e7acc074420e78fda4d66c51541a8145' = {
  name: 'containers-${uniqueString(context.resource.id)}'
  params: {
    context: context
  }
}

var namespace = context.runtime.kubernetes.namespace
var resourceName = context.resource.name
var normalizedName = toLower(resourceName)
var environmentSegments = context.resource.properties.?environment != null ? split(string(context.resource.properties.environment), '/') : []
var labels = {
  'radapp.io/resource': resourceName
  'radapp.io/environment': length(environmentSegments) > 0 ? last(environmentSegments) : ''
  'radapp.io/application': context.application == null ? '' : context.application.name
}

var selectedContainers = filter(items(context.resource.properties.?containers ?? {}), item => contains(externalPorts, '${normalizedName}-${toLower(item.key)}'))
var candidateServices = map(selectedContainers, item => {
  name: '${normalizedName}-${toLower(item.key)}'
  container: item.key
  ports: map(filter(items(item.value.?ports ?? {}), port => contains(externalPorts['${normalizedName}-${toLower(item.key)}'], port.key)), port => union({
    name: toLower(port.key)
    targetPort: port.value.containerPort
    protocol: port.value.?protocol ?? 'TCP'
  }, externalServiceType == 'NodePort' ? {
    port: port.value.containerPort
    nodePort: int(externalPorts['${normalizedName}-${toLower(item.key)}'][port.key])
  } : {
    port: int(externalPorts['${normalizedName}-${toLower(item.key)}'][port.key])
  }))
})
var publishedServices = filter(candidateServices, service => length(service.ports) > 0)

resource externalServices 'core/Service@v1' = [for service in publishedServices: {
  metadata: {
    name: '${service.name}-external'
    namespace: namespace
    labels: union(labels, {
      container: service.container
    })
  }
  spec: {
    type: externalServiceType
    selector: {
      'radapp.io/resource': resourceName
    }
    ports: service.ports
  }
}]

output result object = {
  resources: concat(containers.outputs.result.resources, map(publishedServices, service => '/planes/kubernetes/local/namespaces/${namespace}/providers/core/Service/${service.name}-external'))
  values: containers.outputs.result.values
}
