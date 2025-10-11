.PHONY: help lint test test-unit test-integration fmt validate docs clean install-tools

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install-tools: ## Install required development tools
	@echo "Installing development tools..."
	@command -v terraform >/dev/null 2>&1 || { echo "Please install Terraform"; exit 1; }
	@command -v go >/dev/null 2>&1 || { echo "Please install Go"; exit 1; }
	@command -v tflint >/dev/null 2>&1 || { echo "Installing tflint..."; curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; }
	@command -v pre-commit >/dev/null 2>&1 || { echo "Please install pre-commit: pip install pre-commit"; exit 1; }
	@pre-commit install

fmt: ## Format all Terraform files
	@echo "Formatting Terraform files..."
	@find . -name "*.tf" -exec terraform fmt {} \;

validate: ## Validate all Terraform configurations
	@echo "Validating Terraform configurations..."
	@find . -name "*.tf" -execdir terraform init -backend=false \; -execdir terraform validate \;

lint: ## Run linting on all files
	@echo "Running linting..."
	@./test/scripts/tflint.sh
	@pre-commit run --all-files

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	@cd test && go test -v ./...

test-integration: ## Run integration tests (requires DO token)
	@echo "Running integration tests..."
	@if [ -z "$$DIGITALOCEAN_ACCESS_TOKEN" ]; then echo "DIGITALOCEAN_ACCESS_TOKEN is required"; exit 1; fi
	@cd test && go test -v -tags=integration ./...

test: test-unit ## Run all tests

docs: ## Generate documentation
	@echo "Generating documentation..."
	@find . -name "*.tf" -execdir terraform-docs markdown table --output-file README.md . \;

clean: ## Clean up temporary files
	@echo "Cleaning up..."
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfstate*" -delete 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true

check: fmt validate lint test ## Run all checks (format, validate, lint, test)
