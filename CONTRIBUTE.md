## Introduction

Thank you for your interest in contributing to Scale with Simplicity, DigitalOcean's home for easily deployable Reference Architectures and Patterns. While most contributions might come from within DigitalOcean, we welcome and value input from the broader community.

## Getting Started

This section covers what you need to begin working with and the basic structure of a Reference Architecture.

### Dependencies

Before you add or deploy any Reference Architecture (RA), ensure you have the following installed and configured:

* **Terraform** (v1.5.0 or later): to author, plan, and apply IaC configurations as part of the development workflow.
* **DigitalOcean Account & API Token**: with appropriate permissions to create and destroy the resources your RA will deploy.

### Anatomy of a Reference Architecture

A **Reference Architecture (RA)** is a curated, end-to-end deployment blueprint that demonstrates how to assemble production‑grade components into a complete solution on DigitalOcean. Each RA:

* **Orchestrates Reusable Modules**: Relies on purpose‑built Terraform modules from the `modules/` directory (see [TERRAFORM-MODULE-LIBRARY.md](./TERRAFORM-MODULE-LIBRARY.md)) for common services (VPC, Load Balancers, Managed Databases, etc.).
* **Adds Composition Logic**: Encapsulates higher‑level wiring, parameter choices, and orchestration that guide a user through deploying a full solution.
* **Includes Diagrams & Documentation**: Provides a visual overview (`<ra-slug>.png`) and step‑by‑step instructions (`README.md`) so Solutions Architects and end users understand the design.

#### When to Use Existing Modules vs. Create New

Terraform modules should only be created when they provide clear value by orchestrating multiple resources or encapsulating complex logic that would otherwise be repeated across RAs. In other words, a module is justified when:

* **Cross‑cutting Composition**: It wires together several related resources (e.g., setting up multi‑region networking, global load balancer stacks, or multi‑tunnel VPN configurations) as a cohesive unit.
* **Parameter-driven Variability**: It exposes configuration inputs and outputs that let different RAs customize the same underlying pattern without duplicating HCL code (e.g., `name_prefix`, CIDR blocks, health checks).
* **Reusability Across RAs**: It would be reused by more than one RA in this repo or by our broader Solutions Architect community.

By contrast, do **not** create a module if you only need to define a handful of resources specific to a single RA. In those cases, place them directly in the RA’s `main.tf` alongside module calls.

When in doubt, ask: *“Will this code be used by multiple architectures or represent a distinct orchestration pattern?”* If yes then create a module otherwise, keep it in the RA’s Terraform files.

This guideline helps ensure our module library remains focused on widely applicable patterns, while RAs retain flexibility to implement one‑off or highly tailored resources without unnecessary abstraction.

## Contributing to Modules

Reusable Terraform modules are located in the `modules/` directory. When modifying or adding modules:

### Module Structure

Each module follows this structure:

```
modules/<module-name>/
├── main.tf           # Core module logic
├── variables.tf      # Input variables
├── outputs.tf        # Module outputs
├── terraform.tf      # Provider requirements
├── README.md         # Usage documentation
└── Makefile          # Lint targets
```

### Validating Modules

```bash
cd modules/<module-name>
make lint        # Run terraform validate, fmt, tflint
```

### Updating Modules

When updating a module:
1. Make changes to the module code
2. Run `make lint` in the module directory
3. Test affected reference architectures that use the module
4. Update the module's README.md if inputs/outputs change

### Referencing Modules from RAs

Reference modules using relative paths from your Terraform configuration:

```hcl
module "multi_region_vpc" {
  source      = "../../../modules/multi-region-vpc"
  name_prefix = var.name_prefix
  vpcs        = var.vpcs
}
```

## Adding a Reference Architecture

When you’re ready to author a new Reference Architecture (RA), follow these steps and conventions to ensure consistency across the scale‑with‑simplicity library.

### Submission Workflow

1. **Fork the repo** and create a feature branch (e.g. `<ra-slug>`).
2. **Create your RA directory** under `reference-architectures/` named `<ra-slug>/` and scaffold the files as described in the **Terraform Files and RA Layout** section.
3. **Add a Makefile** at the root of your RA folder. These Make targets will enable you and our CI system to run linting easily.

```
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))
TEST_SCRIPT_DIR := $(realpath $(MAKEFILE_DIR)/../../test/scripts)

.PHONY: tf-validate
tf-validate:
	@cd terraform && $(TEST_SCRIPT_DIR)/terraform-validate.sh

.PHONY: tflint
tflint:
	@cd terraform &&  $(TEST_SCRIPT_DIR)/tflint.sh

.PHONY: lint
lint: tf-validate tflint
```

5. **Update top-level** `README.md` to include your new RA in the index.
6. **Push branch** and open a Pull Request. Ensure CI checks pass before requesting review.

### **Terraform Files and RA Layout**

Your Reference Architecture (RA) should adhere to the following directory and file conventions under `reference-architectures/<ra-slug>/`:

```
<ra-slug>/
├── <ra-slug>.png         # Architecture diagram (visual overview)
├── README.md             # Problem statement, prerequisites, deployment steps, cleanup
├── Makefile              # Validate and lint targets
├── terraform/            # Terraform code
│   ├── main.tf           # Core resources and module invocations
│   ├── variables.tf      # Input variable definitions
│   ├── outputs.tf        # Exported outputs for documentation
│   └── terraform.tf      # Backend configuration & provider blocks
```

* Feel free to copy files from other RAs, but be sure to replace/update anything related with the original RA.
* Place any RA-specific Terraform resources (e.g., inline Droplets, certificates) directly in `main.tf` alongside module calls.
* Reference reusable modules using relative paths (e.g., `source = "../../../modules/multi-region-vpc"`).
* Ensure `variables.tf` only declares inputs required by your RA, and that `outputs.tf` exposes critical values for documentation.
* Keep the Makefile targets aligned with the folder layout so contributors can run `make lint` without modification.

#### **CI Integration**

##### PR Checks (Automatic)

**No workflow file is needed for PR checks.** A single dynamic workflow (`.github/workflows/pr-check.yaml`) automatically detects and validates any changed modules or reference architectures. When you add a new RA or module with a standard Makefile containing a `lint` target, PR checks will run automatically.
