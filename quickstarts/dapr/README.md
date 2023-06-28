# Dapr Quickstart

This quickstart teaches how to add a Dapr sidecar to your application and use Dapr building blocks.

Visit [radapp.dev](https://docs.radapp.dev/getting-started/quickstarts/quickstart-dapr/) for instructions on deploying this quickstart app to try it out.

## Overview

You will deploy an online store where you can order items:

<img src="images/overview.png" alt="A diagram of the Dapr application" width=1000px />

## Containers

This Radius application will have two [containers](https://docs.radapp.dev/concepts/appmodel-concept/):

- A frontend UI for users to place orders. Written with .NET Blazor.
- A backend order processing microservice. Written in Node.JS.

### `frontend` container

The user-facing UI app (`frontend`) offers a portal for users to place orders. Upon creating an order, `frontend` uses [Dapr service invocation](https://docs.dapr.io/developing-applications/building-blocks/service-invocation/service-invocation-overview/) to send requests to `nodeapp`.

The `frontend` container is configured with a [Dapr sidecar extension](https://docs.radapp.dev/reference/resource-schema/link-schema/dapr-schema/extension/) to add the sidecar container.

<img src="images/frontend.png" alt="A diagram of the complete application" width=400 />

### `backend` container

The order processing microservice (`backend`) accepts HTTP requests to create or display orders. It accepts HTTP requests on two endpoints: `GET /order` and `POST /neworder`.

The `backend` container is configured with a [Dapr sidecar extension](https://docs.radapp.dev/reference/resource-schema/link-schema/dapr-schema/extension/) to add the sidecar container, along with a [Dapr Route](#routes) to model Dapr communication.

<img src="images/backend.png" alt="A diagram of the backend order processing service" width=600 />

## Routes

Radius offers communication between services via [Routes](https://docs.radapp.dev/concepts/appmodel-concept/#routes).

### Dapr service invocation

In this quickstart we will be using a [Dapr HTTP invoke route](https://docs.radapp.dev/reference/resource-schema/link-schema/dapr-schema/http/) resource to model communication from `frontend` to `backend`. This allows `frontend` to use Dapr service invocation to interact with `backend`.

<img src="images/invoke.png" alt="A diagram of the Dapr service invocation" width=500 />

## Link

A [Dapr statestore link](https://docs.radapp.dev/reference/resource-schema/link-schema/dapr-schema/dapr-secretstore/) is used to model and deploy the Dapr statestore component.

### `statestore` Dapr state store

The [Dapr state store](https://docs.radapp.dev/reference/resource-schema/link-schema/dapr-schema/dapr-statestore/) resource (`statestore`) stores information about orders. It could be any compatible [Dapr state store](https://docs.dapr.io/developing-applications/building-blocks/state-management/state-management-overview/).

The Dapr component configuration is automatically generated for the statestore based on the resource or values provided in the link definition.

#### Swappable infrastructure

In this quickstart you will be able to swap between different Dapr components, such as Azure Table Storage and a Redis container. While the backing infrastructure will change, the container definitions and connections will remain the same. This allows you to easily swap between different backing infrastructure without rewriting your service code or definition.

<img src="images/statestore.png" alt="A diagram of the Dapr state store" width=600px />