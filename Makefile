# OpenChoreo Microservices Demo - Makefile

# Configuration
TAG ?= latest
NAMESPACE ?= default
CLUSTER ?= openchoreo

# Services and their build contexts
SERVICES := adservice cartservice checkoutservice currencyservice emailservice \
            frontend paymentservice productcatalogservice recommendationservice shippingservice

# Build context mapping
SRC_adservice := src/adservice
SRC_cartservice := src/cartservice
SRC_checkoutservice := src/checkoutservice
SRC_currencyservice := src/currencyservice
SRC_emailservice := src/emailservice
SRC_frontend := src/frontend
SRC_paymentservice := src/paymentservice
SRC_productcatalogservice := src/productcatalogservice
SRC_recommendationservice := src/recommendationservice
SRC_shippingservice := src/shippingservice

.PHONY: all build import deploy k3d-deploy clean help

help:
	@echo "Usage:"
	@echo "  make k3d-deploy TAG=v1    - Build, import to k3d, and deploy (default tag: latest)"
	@echo "  make build TAG=v1         - Build all images"
	@echo "  make import TAG=v1        - Import images to k3d cluster"
	@echo "  make deploy TAG=v1        - Apply OpenChoreo manifests to cluster"
	@echo "  make clean                - Remove images"
	@echo ""
	@echo "Options:"
	@echo "  TAG=<tag>       Image tag (default: latest)"
	@echo "  NAMESPACE=<ns>  Kubernetes namespace (default: default)"
	@echo "  CLUSTER=<name>  k3d cluster name (default: openchoreo)"

# Main target: build, import to k3d, deploy
k3d-deploy: build import deploy
	@echo "Deployed to k3d cluster '$(CLUSTER)' with tag '$(TAG)'"

# Build all images
build:
	@echo "Building adservice:$(TAG)..."; docker build -t adservice:$(TAG) $(SRC_adservice)
	@echo "Building cartservice:$(TAG)..."; docker build -t cartservice:$(TAG) $(SRC_cartservice)
	@echo "Building checkoutservice:$(TAG)..."; docker build -t checkoutservice:$(TAG) $(SRC_checkoutservice)
	@echo "Building currencyservice:$(TAG)..."; docker build -t currencyservice:$(TAG) $(SRC_currencyservice)
	@echo "Building emailservice:$(TAG)..."; docker build -t emailservice:$(TAG) $(SRC_emailservice)
	@echo "Building frontend:$(TAG)..."; docker build -t frontend:$(TAG) $(SRC_frontend)
	@echo "Building paymentservice:$(TAG)..."; docker build -t paymentservice:$(TAG) $(SRC_paymentservice)
	@echo "Building productcatalogservice:$(TAG)..."; docker build -t productcatalogservice:$(TAG) $(SRC_productcatalogservice)
	@echo "Building recommendationservice:$(TAG)..."; docker build -t recommendationservice:$(TAG) $(SRC_recommendationservice)
	@echo "Building shippingservice:$(TAG)..."; docker build -t shippingservice:$(TAG) $(SRC_shippingservice)
	@echo "All images built with tag '$(TAG)'"

# Import images to k3d cluster
import:
	@echo "Importing images to k3d cluster '$(CLUSTER)'..."
	@for svc in $(SERVICES); do \
		echo "Importing $$svc:$(TAG)..."; \
		k3d image import $$svc:$(TAG) -c $(CLUSTER); \
	done
	@docker pull redis:alpine && k3d image import redis:alpine -c $(CLUSTER)
	@echo "All images imported"

# Deploy OpenChoreo manifests (update image tags in workloads)
deploy:
	@echo "Deploying with tag '$(TAG)' to namespace '$(NAMESPACE)'..."
	@mkdir -p manifests/generated/components
	@sed 's|image: \([a-z]*service\):latest|image: \1:$(TAG)|g; s|image: frontend:latest|image: frontend:$(TAG)|g' \
		manifests/project.yaml > manifests/generated/project.yaml
	@for f in manifests/components/*.yaml; do \
		sed 's|image: \([a-z]*service\):latest|image: \1:$(TAG)|g; s|image: frontend:latest|image: frontend:$(TAG)|g' \
			"$$f" > "manifests/generated/components/$$(basename $$f)"; \
	done
	kubectl apply -f manifests/generated/project.yaml -n $(NAMESPACE)
	kubectl apply -f manifests/generated/components/ -n $(NAMESPACE)
	@echo "Deployment complete"

# Clean up
clean:
	@for svc in $(SERVICES); do docker rmi $$svc:$(TAG) 2>/dev/null || true; done
	@rm -rf manifests/generated
	@echo "Cleanup complete"
