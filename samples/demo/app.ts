import { ApplicationStack, ContainerResource, RedisCacheResource } from "rad-cdk";

const stack = ApplicationStack.createDefault("demo");

// Add more resources here to include them in the application.

// Update here to configure a container.
new ContainerResource(stack, "webapp", {
  properties: {
    container: {
      image: "ghcr.io/radius-project/samples/demo:latest",
      ports: {
        web: {
          containerPort: 3000,
        }
      }
    }
  }
});
stack.writeTemplate();
