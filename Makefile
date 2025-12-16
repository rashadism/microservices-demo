# Makefile for building, pushing, and deploying microservices-demo images

# Variables
TAG ?= latest
REGISTRY ?= rashadxyz
CLUSTER_NAME ?= openchoreo

# Service paths
PATH.adservice = src/adservice
PATH.cartservice = src/cartservice/src
PATH.checkoutservice = src/checkoutservice
PATH.currencyservice = src/currencyservice
PATH.emailservice = src/emailservice
PATH.frontend = src/frontend
PATH.paymentservice = src/paymentservice
PATH.productcatalogservice = src/productcatalogservice
PATH.recommendationservice = src/recommendationservice
PATH.shippingservice = src/shippingservice

# Extract service names
SERVICES = adservice cartservice checkoutservice currencyservice emailservice \
           frontend paymentservice productcatalogservice recommendationservice \
           shippingservice

# Component file mapping
COMPONENT.adservice = ad-component.yaml
COMPONENT.cartservice = cart-component.yaml
COMPONENT.checkoutservice = checkout-component.yaml
COMPONENT.currencyservice = currency-component.yaml
COMPONENT.emailservice = email-component.yaml
COMPONENT.frontend = frontend-component.yaml
COMPONENT.paymentservice = payment-component.yaml
COMPONENT.productcatalogservice = productcatalog-component.yaml
COMPONENT.recommendationservice = recommendation-component.yaml
COMPONENT.shippingservice = shipping-component.yaml

.PHONY: help build push move clean release release.move release.push

# Default target
.DEFAULT_GOAL := help

help:
	@echo "Microservices Demo - Build Automation"
	@echo ""
	@echo "Usage:"
	@echo "  make build              Build all service images"
	@echo "  make push               Build and push all images to registry"
	@echo "  make move               Build and import images to k3d cluster"
	@echo "  make release            Build images and update openchoreo manifests"
	@echo "  make release.move       Release and move images to k3d cluster"
	@echo "  make release.push       Release and push images to registry"
	@echo ""
	@echo "Options:"
	@echo "  TAG=$(TAG)              Image tag (default: latest)"
	@echo "  REGISTRY=$(REGISTRY)    Docker registry (default: rashadxyz)"
	@echo "  CLUSTER_NAME=$(CLUSTER_NAME)  k3d cluster name (default: openchoreo)"
	@echo ""
	@echo "Examples:"
	@echo "  make build TAG=v1.0.0"
	@echo "  make push TAG=v1.0.0 REGISTRY=myregistry"
	@echo "  make move TAG=v1.0.0 CLUSTER_NAME=mycluster"
	@echo ""
	@echo "Individual service targets:"
	@echo "  make build-adservice"
	@echo "  make build-cartservice"
	@echo "  ... (and so on for each service)"

# Build all images
build: $(addprefix build-,$(SERVICES))
	@echo "✓ All images built successfully with tag: $(TAG)"

# Build individual services
build-adservice:
	@echo "Building adservice..."
	@docker build -t $(REGISTRY)/adservice:$(TAG) $(PATH.adservice)

build-cartservice:
	@echo "Building cartservice..."
	@docker build --platform=linux/amd64 -t $(REGISTRY)/cartservice:$(TAG) $(PATH.cartservice)

# Generic build rule for other services
build-%:
	@echo "Building $*..."
	@docker build -t $(REGISTRY)/$*:$(TAG) $(PATH.$*)

# Push all images to registry
push: build
	@echo "Pushing all images to $(REGISTRY) with tag: $(TAG)"
	@$(foreach service,$(SERVICES),docker push $(REGISTRY)/$(service):$(TAG);)
	@echo "✓ All images pushed successfully to $(REGISTRY)"

# Build and import images to k3d cluster
move: build
	@echo "Importing images to k3d cluster: $(CLUSTER_NAME)"
	@$(foreach service,$(SERVICES),k3d image import $(REGISTRY)/$(service):$(TAG) -c $(CLUSTER_NAME);)
	@echo "✓ All images imported to k3d cluster: $(CLUSTER_NAME)"

# Clean up Docker images
clean:
	@echo "Removing all built images with tag: $(TAG)"
	@$(foreach service,$(SERVICES),docker rmi $(REGISTRY)/$(service):$(TAG) || true;)
	@echo "✓ Images cleaned up"

# Release: Build and update openchoreo manifests
release: build
	@echo "Updating openchoreo manifests with registry=$(REGISTRY) and tag=$(TAG)"
	@$(foreach service,$(SERVICES),sed -i.bak 's|image: .*/$(service):.*|image: $(REGISTRY)/$(service):$(TAG)|g' openchoreo-manifests/components/$(COMPONENT.$(service)) && rm openchoreo-manifests/components/$(COMPONENT.$(service)).bak;)
	@echo "✓ All manifests updated successfully with $(REGISTRY) and tag $(TAG)"

# Release and move to k3d cluster
release.move: release
	@echo "Importing images to k3d cluster: $(CLUSTER_NAME)"
	@$(foreach service,$(SERVICES),k3d image import $(REGISTRY)/$(service):$(TAG) -c $(CLUSTER_NAME);)
	@echo "✓ All images imported to k3d cluster: $(CLUSTER_NAME)"

# Release and push to registry
release.push: release
	@echo "Pushing all images to $(REGISTRY) with tag: $(TAG)"
	@$(foreach service,$(SERVICES),docker push $(REGISTRY)/$(service):$(TAG);)
	@echo "✓ All images pushed successfully to $(REGISTRY)"

