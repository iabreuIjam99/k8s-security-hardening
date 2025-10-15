# Makefile for Kubernetes Security Hardening

.PHONY: help init plan apply destroy validate test install clean

# Variables
TERRAFORM_DIR := terraform/environments/dev
SCRIPTS_DIR := scripts

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	@echo "Initializing Terraform..."
	cd $(TERRAFORM_DIR) && terraform init

plan: ## Run Terraform plan
	@echo "Running Terraform plan..."
	cd $(TERRAFORM_DIR) && terraform plan

apply: ## Apply Terraform configuration
	@echo "Applying Terraform configuration..."
	cd $(TERRAFORM_DIR) && terraform apply

destroy: ## Destroy infrastructure
	@echo "⚠️  WARNING: This will destroy all infrastructure!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd $(TERRAFORM_DIR) && terraform destroy; \
	fi

validate: ## Validate policies and manifests
	@echo "Validating policies..."
	cd $(SCRIPTS_DIR) && chmod +x validate-policies.sh && ./validate-policies.sh

test: ## Run security tests
	@echo "Running security tests..."
	cd $(SCRIPTS_DIR) && chmod +x security-tests.sh && ./security-tests.sh

install: ## Install security stack
	@echo "Installing security stack..."
	cd $(SCRIPTS_DIR) && chmod +x install-security-stack.sh && ./install-security-stack.sh

clean: ## Clean temporary files
	@echo "Cleaning temporary files..."
	find . -name "*.tfstate*" -type f -delete
	find . -name ".terraform" -type d -exec rm -rf {} +
	find . -name "*.log" -type f -delete

fmt: ## Format Terraform files
	@echo "Formatting Terraform files..."
	terraform fmt -recursive terraform/

lint: ## Lint shell scripts
	@echo "Linting shell scripts..."
	shellcheck $(SCRIPTS_DIR)/*.sh

kubeconfig: ## Update kubeconfig
	@echo "Updating kubeconfig..."
	aws eks update-kubeconfig --name $$(cd $(TERRAFORM_DIR) && terraform output -raw cluster_name) --region us-east-1

grafana: ## Port-forward Grafana
	@echo "Port-forwarding Grafana to http://localhost:3000"
	@echo "Credentials: admin/admin"
	kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

prometheus: ## Port-forward Prometheus
	@echo "Port-forwarding Prometheus to http://localhost:9090"
	kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

falco-logs: ## View Falco logs
	@echo "Viewing Falco logs..."
	kubectl logs -n falco -l app.kubernetes.io/name=falco -f

check-constraints: ## Check Gatekeeper constraints
	@echo "Checking Gatekeeper constraints..."
	kubectl get constraints

all: init plan apply install ## Run complete setup
