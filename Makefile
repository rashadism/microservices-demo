# Makefile for building, pushing, and deploying microservices-demo images

# Variables
TAG ?= latest
REGISTRY ?= rashadxyz
CLUSTER_NAME ?= openchoreo

# Service definitions
SERVICES = adservice cartservice checkoutservice currencyservice emailservice \
           frontend paymentservice productcatalogservice recommendationservice \
           shippingservice

# Service paths
ADSERVICE_PATH = src/adservice
CARTSERVICE_PATH = src/cartservice/src
CHECKOUTSERVICE_PATH = src/checkoutservice
CURRENCYSERVICE_PATH = src/currencyservice
EMAILSERVICE_PATH = src/emailservice
FRONTEND_PATH = src/frontend
PAYMENTSERVICE_PATH = src/paymentservice
PRODUCTCATALOGSERVICE_PATH = src/productcatalogservice
RECOMMENDATIONSERVICE_PATH = src/recommendationservice
SHIPPINGSERVICE_PATH = src/shippingservice

# Image names
ADSERVICE_IMAGE = $(REGISTRY)/adservice:$(TAG)
CARTSERVICE_IMAGE = $(REGISTRY)/cartservice:$(TAG)
CHECKOUTSERVICE_IMAGE = $(REGISTRY)/checkoutservice:$(TAG)
CURRENCYSERVICE_IMAGE = $(REGISTRY)/currencyservice:$(TAG)
EMAILSERVICE_IMAGE = $(REGISTRY)/emailservice:$(TAG)
FRONTEND_IMAGE = $(REGISTRY)/frontend:$(TAG)
PAYMENTSERVICE_IMAGE = $(REGISTRY)/paymentservice:$(TAG)
PRODUCTCATALOGSERVICE_IMAGE = $(REGISTRY)/productcatalogservice:$(TAG)
RECOMMENDATIONSERVICE_IMAGE = $(REGISTRY)/recommendationservice:$(TAG)
SHIPPINGSERVICE_IMAGE = $(REGISTRY)/shippingservice:$(TAG)

.PHONY: help build push move clean \
        build-adservice build-cartservice build-checkoutservice \
        build-currencyservice build-emailservice build-frontend \
        build-paymentservice build-productcatalogservice \
        build-recommendationservice build-shippingservice

# Default target
.DEFAULT_GOAL := help

help:
	@echo "Microservices Demo - Build Automation"
	@echo ""
	@echo "Usage:"
	@echo "  make build              Build all service images"
	@echo "  make push               Build and push all images to registry"
	@echo "  make move               Build and import images to k3d cluster"
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
build: build-adservice build-cartservice build-checkoutservice \
       build-currencyservice build-emailservice build-frontend \
       build-paymentservice build-productcatalogservice \
       build-recommendationservice build-shippingservice
	@echo "✓ All images built successfully with tag: $(TAG)"

# Build individual services
build-adservice:
	@echo "Building adservice..."
	docker build -t $(ADSERVICE_IMAGE) $(ADSERVICE_PATH)

build-cartservice:
	@echo "Building cartservice..."
	docker build --platform=linux/amd64 -t $(CARTSERVICE_IMAGE) $(CARTSERVICE_PATH)

build-checkoutservice:
	@echo "Building checkoutservice..."
	docker build -t $(CHECKOUTSERVICE_IMAGE) $(CHECKOUTSERVICE_PATH)

build-currencyservice:
	@echo "Building currencyservice..."
	docker build -t $(CURRENCYSERVICE_IMAGE) $(CURRENCYSERVICE_PATH)

build-emailservice:
	@echo "Building emailservice..."
	docker build -t $(EMAILSERVICE_IMAGE) $(EMAILSERVICE_PATH)

build-frontend:
	@echo "Building frontend..."
	docker build -t $(FRONTEND_IMAGE) $(FRONTEND_PATH)

build-paymentservice:
	@echo "Building paymentservice..."
	docker build -t $(PAYMENTSERVICE_IMAGE) $(PAYMENTSERVICE_PATH)

build-productcatalogservice:
	@echo "Building productcatalogservice..."
	docker build -t $(PRODUCTCATALOGSERVICE_IMAGE) $(PRODUCTCATALOGSERVICE_PATH)

build-recommendationservice:
	@echo "Building recommendationservice..."
	docker build -t $(RECOMMENDATIONSERVICE_IMAGE) $(RECOMMENDATIONSERVICE_PATH)

build-shippingservice:
	@echo "Building shippingservice..."
	docker build -t $(SHIPPINGSERVICE_IMAGE) $(SHIPPINGSERVICE_PATH)

# Push all images to registry
push: build
	@echo "Pushing all images to $(REGISTRY) with tag: $(TAG)"
	docker push $(ADSERVICE_IMAGE)
	docker push $(CARTSERVICE_IMAGE)
	docker push $(CHECKOUTSERVICE_IMAGE)
	docker push $(CURRENCYSERVICE_IMAGE)
	docker push $(EMAILSERVICE_IMAGE)
	docker push $(FRONTEND_IMAGE)
	docker push $(PAYMENTSERVICE_IMAGE)
	docker push $(PRODUCTCATALOGSERVICE_IMAGE)
	docker push $(RECOMMENDATIONSERVICE_IMAGE)
	docker push $(SHIPPINGSERVICE_IMAGE)
	@echo "✓ All images pushed successfully to $(REGISTRY)"

# Build and import images to k3d cluster
move: build
	@echo "Importing images to k3d cluster: $(CLUSTER_NAME)"
	k3d image import $(ADSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(CARTSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(CHECKOUTSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(CURRENCYSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(EMAILSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(FRONTEND_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(PAYMENTSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(PRODUCTCATALOGSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(RECOMMENDATIONSERVICE_IMAGE) -c $(CLUSTER_NAME)
	k3d image import $(SHIPPINGSERVICE_IMAGE) -c $(CLUSTER_NAME)
	@echo "✓ All images imported to k3d cluster: $(CLUSTER_NAME)"

# Clean up Docker images
clean:
	@echo "Removing all built images with tag: $(TAG)"
	docker rmi $(ADSERVICE_IMAGE) || true
	docker rmi $(CARTSERVICE_IMAGE) || true
	docker rmi $(CHECKOUTSERVICE_IMAGE) || true
	docker rmi $(CURRENCYSERVICE_IMAGE) || true
	docker rmi $(EMAILSERVICE_IMAGE) || true
	docker rmi $(FRONTEND_IMAGE) || true
	docker rmi $(PAYMENTSERVICE_IMAGE) || true
	docker rmi $(PRODUCTCATALOGSERVICE_IMAGE) || true
	docker rmi $(RECOMMENDATIONSERVICE_IMAGE) || true
	docker rmi $(SHIPPINGSERVICE_IMAGE) || true
	@echo "✓ Images cleaned up"
