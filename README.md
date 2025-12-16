<!-- <p align="center">
<img src="/src/frontend/static/icons/Hipster_HeroLogoMaroon.svg" width="300" alt="Online Boutique" />
</p> -->
![Continuous Integration](https://github.com/GoogleCloudPlatform/microservices-demo/workflows/Continuous%20Integration%20-%20Main/Release/badge.svg)

**Online Boutique** is a cloud-first microservices demo application. The application is a
web-based e-commerce app where users can browse items, add them to the cart, and purchase them.

This fork demonstrates **comprehensive OpenTelemetry instrumentation** across a multi-language microservices architecture, with deployment support for [OpenChoreo](https://openchoreo.dev). The application showcases distributed tracing, context propagation, baggage usage, and observability best practices across 11 microservices written in 5 different languages (Go, Java, C#, Node.js, Python).

**Key Features:**
- Complete OpenTelemetry instrumentation across all services
- W3C TraceContext and Baggage propagation
- Real User Monitoring (RUM) with browser instrumentation
- OpenChoreo deployment manifests
- Automated build and deployment workflows

If you're using this demo, please **★Star** this repository to show your interest!

## Architecture

**Online Boutique** is composed of 11 microservices written in different
languages that talk to each other over gRPC.

[![Architecture of
microservices](/docs/img/architecture-diagram.png)](/docs/img/architecture-diagram.png)

Find **Protocol Buffers Descriptions** at the [`./protos` directory](/protos).

| Service                                              | Language      | Description                                                                                                                       |
| ---------------------------------------------------- | ------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [frontend](/src/frontend)                           | Go            | Exposes an HTTP server to serve the website. Does not require signup/login and generates session IDs for all users automatically. |
| [cartservice](/src/cartservice)                     | C#            | Stores the items in the user's shopping cart in Redis and retrieves it.                                                           |
| [productcatalogservice](/src/productcatalogservice) | Go            | Provides the list of products from a JSON file and ability to search products and get individual products.                        |
| [currencyservice](/src/currencyservice)             | Node.js       | Converts one money amount to another currency. Uses real values fetched from European Central Bank. It's the highest QPS service. |
| [paymentservice](/src/paymentservice)               | Node.js       | Charges the given credit card info (mock) with the given amount and returns a transaction ID.                                     |
| [shippingservice](/src/shippingservice)             | Go            | Gives shipping cost estimates based on the shopping cart. Ships items to the given address (mock)                                 |
| [emailservice](/src/emailservice)                   | Python        | Sends users an order confirmation email (mock).                                                                                   |
| [checkoutservice](/src/checkoutservice)             | Go            | Retrieves user cart, prepares order and orchestrates the payment, shipping and the email notification.                            |
| [recommendationservice](/src/recommendationservice) | Python        | Recommends other products based on what's given in the cart.                                                                      |
| [adservice](/src/adservice)                         | Java          | Provides text ads based on given context words.                                                                                   |
| [loadgenerator](/src/loadgenerator)                 | Python/Locust | Continuously sends requests imitating realistic user shopping flows to the frontend.                                              |

## Screenshots

| Home Page                                                                                                         | Checkout Screen                                                                                                    |
| ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| [![Screenshot of store homepage](/docs/img/online-boutique-frontend-1.png)](/docs/img/online-boutique-frontend-1.png) | [![Screenshot of checkout screen](/docs/img/online-boutique-frontend-2.png)](/docs/img/online-boutique-frontend-2.png) |

## Quickstart (OpenChoreo)

1. Ensure you have the following requirements:
   - [OpenChoreo CLI](https://openchoreo.dev) installed
   - Docker installed for building images
   - (Optional) k3d for local Kubernetes cluster

2. Clone this repository:

   ```sh
   git clone https://github.com/rashadism/microservices-demo.git
   cd microservices-demo/
   ```

3. Build all service images:

   ```sh
   make build TAG=v1.0.0
   ```

4. For local deployment with k3d, import images and deploy:

   ```sh
   # Create k3d cluster (if not already created)
   k3d cluster create openchoreo

   # Build and import images
   make release.move TAG=v1.0.0

   # Deploy OpenChoreo manifests
   kubectl apply -f openchoreo-manifests/
   ```

5. For deployment to a remote registry:

   ```sh
   # Build, update manifests, and push to registry
   make release.push TAG=v1.0.0 REGISTRY=myregistry

   # Deploy OpenChoreo manifests
   kubectl apply -f openchoreo-manifests/
   ```

6. Access the web frontend using the frontend service endpoint (configuration depends on your OpenChoreo setup).

## OpenTelemetry Instrumentation

All services in this demo are instrumented with OpenTelemetry for distributed tracing:

- **Automatic Instrumentation**: gRPC, HTTP, and framework-level tracing
- **Manual Instrumentation**: Custom spans for business logic and mock database calls
- **Context Propagation**: W3C TraceContext and Baggage headers
- **Baggage Usage**: Cross-cutting context (user_id, request_id, order_id, build_id)
- **Real User Monitoring**: Browser instrumentation for frontend tracking
- **Multi-Language Support**: Instrumentation patterns for Go, Java, C#, Node.js, and Python

## Build Automation

This repository includes an enhanced Makefile for streamlined builds and deployments. The Makefile supports building Docker images, pushing to registries, and deploying to both traditional Kubernetes and OpenChoreo environments.

### Quick Start

```sh
# Show all available targets
make help

# Build all service images
make build

# Build with specific tag
make build TAG=v1.0.0

# Push to Docker registry
make push TAG=v1.0.0 REGISTRY=myregistry

# Import to local k3d cluster
make move TAG=v1.0.0 CLUSTER_NAME=openchoreo
```

### Release Targets

The Makefile includes special `release` targets for OpenChoreo deployments that automatically update manifest files:

- `make release` - Build images and update OpenChoreo manifests with the new image references
- `make release.move` - Release and import images to a k3d cluster
- `make release.push` - Release and push images to a Docker registry

**Example:**
```sh
# Build all images, update OpenChoreo manifests, and push to registry
make release.push TAG=v1.0.0 REGISTRY=myregistry
```

### Configuration Variables

- `TAG` - Docker image tag (default: `latest`)
- `REGISTRY` - Docker registry name (default: `rashadxyz`)
- `CLUSTER_NAME` - k3d cluster name for local imports (default: `openchoreo`)

### Building Individual Services

You can also build individual services:

```sh
make build-frontend
make build-cartservice
make build-checkoutservice
# ... and so on
```

## Contributing

This is a fork of the [Google Cloud Platform microservices-demo](https://github.com/GoogleCloudPlatform/microservices-demo) focused on OpenTelemetry instrumentation and OpenChoreo deployment.

For issues or contributions related to tracing instrumentation or OpenChoreo deployment, please open an issue in this repository.
